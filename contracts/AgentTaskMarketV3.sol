// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title AgentTaskMarketV3 - Enhanced Reputation with Badges & Anti-Sybil
contract AgentTaskMarketV3 is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    
    // ============ Constants ============
    uint256 public constant MIN_REWARD = 1 * 10**18;
    uint256 public constant MAX_DEADLINE = 30 days;
    uint8 public constant MIN_RATING = 1;
    uint8 public constant MAX_RATING = 5;
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    uint256 public constant MIN_TASKS_FOR_REP = 3;
    uint256 public constant COUNCIL_QUORUM = 3;
    
    // ============ Enums ============
    enum TaskStatus { Open, InProgress, Submitted, Completed, Cancelled, Disputed, Escalated }
    enum BadgeType { None, TrustedPro, QuickSolver, QualityMaster, Consistent, RisingStar, CouncilMember }
    
    // ============ Structs ============
    struct Task {
        uint256 id;
        address creator;
        address runner;
        string title;
        string description;
        uint256 reward;
        uint256 deadline;
        TaskStatus status;
        string deliverables;
        uint256 createdAt;
        uint256 completedAt;
        uint8 rating;
    }
    
    struct Bid {
        uint256 taskId;
        address bidder;
        uint256 timestamp;
        string proposal;
    }
    
    struct AgentProfile {
        uint256 reputationScore; // 100-1000
        uint256 totalTasksCompleted;
        uint256 totalTasksCreated;
        uint256 averageRating; // *100 存储
        uint256 totalEarned;
        uint256 successfulDisputes;
        uint256 failedDisputes;
        uint256 earlyCompletions;
        uint256 accountAge;
        BadgeType[] badges;
        uint256 lastTaskCompletion;
        bool isCouncilMember;
    }
    
    struct DisputeCase {
        uint256 taskId;
        address initiator;
        address respondent;
        string evidence;
        uint256 createdAt;
        uint256 votingEndsAt;
        uint256 votesForRunner;
        uint256 votesForCreator;
        mapping(address => bool) hasVoted;
        bool resolved;
    }
    
    // ============ State ============
    IERC20 public clawnchToken;
    uint256 private _nextTaskId;
    Task[] public tasks;
    uint256 public feeRate;
    address public feeRecipient;
    uint256 public accumulatedFees;
    
    mapping(uint256 => Bid[]) public taskBids;
    mapping(address => AgentProfile) public agentProfiles;
    mapping(uint256 => DisputeCase) public disputeCases;
    mapping(uint256 => uint256) public taskDisputeId;
    address[] public councilMembers;
    bool public antiSybilEnabled;
    
    // ============ Events ============
    event TaskCreated(uint256 indexed taskId, address indexed creator, string title, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed creator, address indexed runner);
    event TaskSubmitted(uint256 indexed taskId, address indexed runner);
    event TaskCompleted(uint256 indexed taskId, address indexed creator, address indexed runner, uint256 reward, uint256 fee, uint8 rating);
    event TaskCancelled(uint256 indexed taskId, address indexed creator, string reason);
    event BadgeEarned(address indexed agent, BadgeType badge);
    event ReputationUpdated(address indexed agent, uint256 oldScore, uint256 newScore);
    event DisputeRaised(uint256 indexed taskId, uint256 indexed disputeId);
    event DisputeResolved(uint256 indexed disputeId, address winner, uint256 amount);
    event FeeRateChanged(uint256 oldRate, uint256 newRate);
    event FeesWithdrawn(uint256 amount);
    
    // ============ Errors ============
    error InvalidReward();
    error InvalidDeadline();
    error TaskNotOpen(uint256 taskId);
    error NotTaskCreator(uint256 taskId);
    error NotTaskRunner(uint256 taskId);
    error InvalidRating();
    error TransferFailed();
    error InvalidFeeRate();
    error NoFeesToWithdraw();
    error InsufficientReputation();
    error AlreadyVoted();
    error VotingNotEnded();
    error NoQuorum();
    
    // ============ Modifiers ============
    modifier onlyCouncil() {
        require(agentProfiles[msg.sender].isCouncilMember, "Not council member");
        _;
    }
    
    // ============ Initializer ============
    constructor() { _disableInitializers(); }
    
    function initialize(
        address _clawnchToken,
        address _feeRecipient,
        uint256 _initialFeeRate,
        address[] memory _initialCouncil
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        clawnchToken = IERC20(_clawnchToken);
        feeRecipient = _feeRecipient;
        feeRate = _initialFeeRate;
        _nextTaskId = 0;
        antiSybilEnabled = false;
        
        for (uint256 i = 0; i < _initialCouncil.length; i++) {
            _addCouncilMember(_initialCouncil[i]);
        }
    }
    
    function _authorizeUpgrade(address) internal override onlyOwner {}
    function _addCouncilMember(address member) internal {
        agentProfiles[member].isCouncilMember = true;
        agentProfiles[member].reputationScore = 700;
        councilMembers.push(member);
    }
    
    // ============ Core Functions ============
    function createTask(string memory title, string memory description, uint256 reward, uint256 deadlineDays)
        external returns (uint256 taskId) {
        if (reward < MIN_REWARD) revert InvalidReward();
        if (deadlineDays == 0 || deadlineDays > 30) revert InvalidDeadline();
        
        if (!clawnchToken.transferFrom(msg.sender, address(this), reward)) revert TransferFailed();
        
        taskId = _nextTaskId++;
        tasks.push(Task({
            id: taskId, creator: msg.sender, runner: address(0), title: title,
            description: description, reward: reward, deadline: block.timestamp + (deadlineDays * 1 days),
            status: TaskStatus.Open, deliverables: "", createdAt: block.timestamp, completedAt: 0, rating: 0
        }));
        
        AgentProfile storage p = agentProfiles[msg.sender];
        if (p.totalTasksCreated == 0) p.accountAge = block.timestamp;
        p.totalTasksCreated++;
        
        emit TaskCreated(taskId, msg.sender, title, reward);
    }
    
    function submitBid(uint256 taskId, string memory proposal) external {
        require(tasks[taskId].status == TaskStatus.Open, "Task not open");
        if (antiSybilEnabled) {
            require(agentProfiles[msg.sender].totalTasksCompleted >= MIN_TASKS_FOR_REP, "Insufficient reputation");
        }
        taskBids[taskId].push(Bid({taskId: taskId, bidder: msg.sender, timestamp: block.timestamp, proposal: proposal}));
    }
    
    function acceptBid(uint256 taskId, uint256 bidIndex) external {
        require(tasks[taskId].creator == msg.sender, NotTaskCreator(taskId));
        require(tasks[taskId].runner == address(0), "Already assigned");
        Bid[] storage bids = taskBids[taskId];
        require(bidIndex < bids.length, "Invalid bid");
        address runner = bids[bidIndex].bidder;
        tasks[taskId].runner = runner;
        tasks[taskId].status = TaskStatus.InProgress;
        if (agentProfiles[runner].totalTasksCompleted == 0) agentProfiles[runner].accountAge = block.timestamp;
        emit TaskAssigned(taskId, msg.sender, runner);
    }
    
    function submitTask(uint256 taskId, string memory deliverables) external {
        require(tasks[taskId].runner == msg.sender, NotTaskRunner(taskId));
        require(tasks[taskId].status == TaskStatus.InProgress, "Not in progress");
        tasks[taskId].status = TaskStatus.Submitted;
        tasks[taskId].deliverables = deliverables;
        emit TaskSubmitted(taskId, msg.sender);
    }
    
    function completeTask(uint256 taskId, uint8 rating) external nonReentrant {
        require(tasks[taskId].creator == msg.sender, NotTaskCreator(taskId));
        require(tasks[taskId].status == TaskStatus.Submitted, "Not submitted");
        require(rating >= MIN_RATING && rating <= MAX_RATING, InvalidRating());
        
        address runner = tasks[taskId].runner;
        uint256 reward = tasks[taskId].reward;
        uint256 fee = (reward * feeRate) / 10000;
        uint256 runnerReward = reward - fee;
        
        tasks[taskId].status = TaskStatus.Completed;
        tasks[taskId].completedAt = block.timestamp;
        tasks[taskId].rating = rating;
        accumulatedFees += fee;
        
        if (!clawnchToken.transfer(runner, runnerReward)) revert TransferFailed();
        
        _updateReputation(runner, rating);
        AgentProfile storage rp = agentProfiles[runner];
        rp.totalTasksCompleted++;
        rp.totalEarned += runnerReward;
        rp.lastTaskCompletion = block.timestamp;
        if (block.timestamp < tasks[taskId].deadline) rp.earlyCompletions++;
        _checkBadges(runner);
        
        emit TaskCompleted(taskId, msg.sender, runner, runnerReward, fee, rating);
    }
    
    function cancelTask(uint256 taskId, string memory reason) external {
        require(tasks[taskId].creator == msg.sender, NotTaskCreator(taskId));
        require(tasks[taskId].status == TaskStatus.Open, "Not open");
        tasks[taskId].status = TaskStatus.Cancelled;
        uint256 refund = tasks[taskId].reward;
        if (!clawnchToken.transfer(msg.sender, refund)) revert TransferFailed();
        emit TaskCancelled(taskId, msg.sender, reason);
    }
    
    // ============ Reputation System ============
    function _updateReputation(address agent, uint256 rating) internal {
        AgentProfile storage p = agentProfiles[agent];
        uint256 oldScore = p.reputationScore;
        
        if (p.totalTasksCompleted == 0) {
            p.reputationScore = 250 + (rating - 3) * 50;
            p.averageRating = rating * 100;
        } else {
            p.averageRating = (p.averageRating * (p.totalTasksCompleted - 1) + rating * 100) / p.totalTasksCompleted;
            uint256 baseScore = p.averageRating * 2;
            uint256 taskBonus = _min(p.totalTasksCompleted * 5, 200);
            uint256 timeBonus = _min((block.timestamp - p.accountAge) / 1 days, 100);
            uint256 newScore = baseScore + taskBonus + timeBonus;
            p.reputationScore = _clamp(newScore, 100, 1000);
        }
        
        emit ReputationUpdated(agent, oldScore, p.reputationScore);
    }
    
    function _checkBadges(address agent) internal {
        AgentProfile storage p = agentProfiles[agent];
        if (p.totalTasksCompleted >= 100 && p.averageRating >= 450) _awardBadge(agent, BadgeType.TrustedPro);
        if (p.totalTasksCompleted >= 10 && (p.earlyCompletions * 100 / p.totalTasksCompleted) >= 80) _awardBadge(agent, BadgeType.QuickSolver);
        if (p.totalTasksCompleted >= 5 && p.totalTasksCompleted <= 20 && p.averageRating >= 400) _awardBadge(agent, BadgeType.RisingStar);
    }
    
    function _awardBadge(address agent, BadgeType badge) internal {
        AgentProfile storage p = agentProfiles[agent];
        for (uint256 i = 0; i < p.badges.length; i++) if (p.badges[i] == badge) return;
        p.badges.push(badge);
        emit BadgeEarned(agent, badge);
    }
    
    // ============ Dispute Resolution ============
    function raiseDispute(uint256 taskId, string memory reason) external {
        require(tasks[taskId].creator == msg.sender || tasks[taskId].runner == msg.sender, "Not authorized");
        require(taskDisputeId[taskId] == 0, "Dispute exists");
        
        uint256 disputeId = uint256(keccak256(abi.encodePacked(taskId, msg.sender, block.timestamp)));
        DisputeCase storage d = disputeCases[disputeId];
        d.taskId = taskId;
        d.initiator = msg.sender;
        d.respondent = tasks[taskId].creator == msg.sender ? tasks[taskId].runner : tasks[taskId].creator;
        d.evidence = reason;
        d.createdAt = block.timestamp;
        d.votingEndsAt = block.timestamp + 3 days;
        d.votesForRunner = 0;
        d.votesForCreator = 0;
        d.resolved = false;
        taskDisputeId[taskId] = disputeId;
        tasks[taskId].status = TaskStatus.Disputed;
        emit DisputeRaised(taskId, disputeId);
    }
    
    function voteOnDispute(uint256 disputeId, bool voteForRunner) external onlyCouncil {
        DisputeCase storage d = disputeCases[disputeId];
        require(!d.resolved, "Resolved");
        require(block.timestamp < d.votingEndsAt, VotingNotEnded());
        require(!d.hasVoted[msg.sender], AlreadyVoted());
        d.hasVoted[msg.sender] = true;
        if (voteForRunner) d.votesForRunner++; else d.votesForCreator++;
    }
    
    function resolveDispute(uint256 disputeId) external {
        DisputeCase storage d = disputeCases[disputeId];
        require(!d.resolved, "Already resolved");
        require(block.timestamp >= d.votingEndsAt, VotingNotEnded());
        require(d.votesForRunner + d.votesForCreator >= COUNCIL_QUORUM, NoQuorum());
        
        uint256 reward = tasks[d.taskId].reward;
        uint256 fee = (reward * feeRate) / 10000;
        address winner;
        
        if (d.votesForRunner > d.votesForCreator) {
            winner = tasks[d.taskId].runner;
            agentProfiles[winner].successfulDisputes++;
            if (!clawnchToken.transfer(winner, reward - fee)) revert TransferFailed();
        } else {
            winner = tasks[d.taskId].creator;
            agentProfiles[winner].failedDisputes++;
            if (!clawnchToken.transfer(winner, reward)) revert TransferFailed();
        }
        
        accumulatedFees += fee;
        tasks[d.taskId].status = TaskStatus.Completed;
        d.resolved = true;
        emit DisputeResolved(disputeId, winner, reward);
    }
    
    // ============ Admin Functions ============
    function setFeeRate(uint256 newRate) external onlyOwner {
        if (newRate > MAX_FEE_RATE) revert InvalidFeeRate();
        emit FeeRateChanged(feeRate, newRate);
        feeRate = newRate;
    }
    
    function setFeeRecipient(address newRecipient) external onlyOwner {
        feeRecipient = newRecipient;
    }
    
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        accumulatedFees = 0;
        if (!clawnchToken.transfer(feeRecipient, amount)) revert TransferFailed();
        emit FeesWithdrawn(amount);
    }
    
    function enableAntiSybil() external onlyOwner {
        antiSybilEnabled = true;
    }
    
    function addCouncilMember(address member) external onlyOwner {
        _addCouncilMember(member);
    }
    
    // ============ View Functions ============
    function getAgentProfile(address agent) external view returns (
        uint256 reputation, uint256 tasksCompleted, uint256 avgRating,
        uint256 totalEarned, BadgeType[] memory badges, bool isCouncil
    ) {
        AgentProfile storage p = agentProfiles[agent];
        return (p.reputationScore, p.totalTasksCompleted, p.averageRating, p.totalEarned, p.badges, p.isCouncilMember);
    }
    
    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
    
    function getTaskCount() external view returns (uint256) {
        return tasks.length;
    }
    
    function version() external pure returns (string memory) {
        return "3.0.0";
    }
    
    // ============ Helpers ============
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function _clamp(uint256 value, uint256 minVal, uint256 maxVal) internal pure returns (uint256) {
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    }
}
