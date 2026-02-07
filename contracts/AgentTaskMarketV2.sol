// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @title AgentTaskMarketV2 - Upgradeable Decentralized Task Market for AI Agents
/// @notice A trustless task marketplace with fee mechanism and upgrade capability
/// @dev Uses UUPS proxy pattern for upgradeability
contract AgentTaskMarketV2 is 
    Initializable, 
    UUPSUpgradeable, 
    OwnableUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    // ============ Constants ============
    uint256 public constant MIN_REWARD = 1 * 10**18; // Minimum 1 CLAWNCH (18 decimals)
    uint256 public constant MAX_DEADLINE = 30 days;
    uint8 public constant MIN_RATING = 1;
    uint8 public constant MAX_RATING = 5;
    uint256 public constant MAX_FEE_RATE = 1000; // Max 10% (1000 basis points)
    
    // ============ Enums ============
    enum TaskStatus { 
        Open,           // 任务开放，可接受投标
        InProgress,     // 已分配执行者
        Submitted,      // 执行者已提交，等待验收
        Completed,      // 任务完成，资金已释放
        Cancelled,      // 任务已取消
        Disputed        // 争议中
    }
    
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
    }
    
    struct Bid {
        uint256 taskId;
        address bidder;
        uint256 timestamp;
        string proposal;
    }
    
    // ============ State Variables ============
    IERC20 public clawnchToken;
    
    uint256 private _nextTaskId;
    Task[] public tasks;
    
    // Fee mechanism
    uint256 public feeRate; // in basis points (200 = 2%)
    address public feeRecipient;
    uint256 public accumulatedFees;
    uint256 public totalFeesCollected;
    
    // Mappings
    mapping(uint256 => Bid[]) public taskBids;
    mapping(address => uint256[]) public agentTasks;
    mapping(address => uint256) public reputationScores;
    mapping(address => uint256) public taskCount;
    mapping(address => uint256) public totalEarned;
    
    // ============ Events ============
    event TaskCreated(uint256 indexed taskId, address indexed creator, string title, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed creator, address indexed runner);
    event TaskSubmitted(uint256 indexed taskId, address indexed runner, string deliverables);
    event TaskCompleted(uint256 indexed taskId, address indexed creator, address indexed runner, uint256 reward, uint256 fee, uint8 rating);
    event TaskCancelled(uint256 indexed taskId, address indexed creator, string reason);
    event TaskDisputed(uint256 indexed taskId, address indexed initiator, string reason);
    event DisputeResolved(uint256 indexed taskId, address indexed winner, uint256 amount);
    event BidSubmitted(uint256 indexed taskId, address indexed bidder);
    event ReputationUpdated(address indexed agent, uint256 oldScore, uint256 newScore);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    
    // ============ Errors ============
    error InvalidReward();
    error InvalidDeadline();
    error TaskNotOpen(uint256 taskId);
    error TaskNotInProgress(uint256 taskId);
    error NotTaskCreator(uint256 taskId);
    error NotTaskRunner(uint256 taskId);
    error InvalidRating();
    error TaskAlreadyAssigned(uint256 taskId);
    error TransferFailed();
    error InvalidFeeRate();
    error NoFeesToWithdraw();
    error InvalidAddress();
    
    // ============ Modifiers ============
    modifier validTaskId(uint256 taskId) {
        require(taskId < tasks.length, "Invalid task ID");
        _;
    }
    
    // ============ Initializer ============
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice Initialize the contract (replaces constructor for upgradeable contracts)
    /// @param _clawnchToken Address of the CLAWNCH token
    /// @param _feeRecipient Address to receive fees
    /// @param _initialFeeRate Initial fee rate in basis points (200 = 2%)
    function initialize(
        address _clawnchToken,
        address _feeRecipient,
        uint256 _initialFeeRate
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        if (_clawnchToken == address(0)) revert InvalidAddress();
        if (_feeRecipient == address(0)) revert InvalidAddress();
        if (_initialFeeRate > MAX_FEE_RATE) revert InvalidFeeRate();
        
        clawnchToken = IERC20(_clawnchToken);
        feeRecipient = _feeRecipient;
        feeRate = _initialFeeRate;
        _nextTaskId = 0;
    }
    
    // ============ UUPS Upgrade Authorization ============
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ============ Admin Functions ============
    
    /// @notice Update fee rate (max 10%)
    function setFeeRate(uint256 newRate) external onlyOwner {
        if (newRate > MAX_FEE_RATE) revert InvalidFeeRate();
        emit FeeRateUpdated(feeRate, newRate);
        feeRate = newRate;
    }
    
    /// @notice Update fee recipient
    function setFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidAddress();
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }
    
    /// @notice Withdraw accumulated fees
    function withdrawFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoFeesToWithdraw();
        
        accumulatedFees = 0;
        
        if (!clawnchToken.transfer(feeRecipient, amount)) {
            revert TransferFailed();
        }
        
        emit FeesWithdrawn(feeRecipient, amount);
    }
    
    /// @notice Pause contract (emergency)
    function pause() external onlyOwner {
        _pause();
    }
    
    /// @notice Unpause contract
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /// @notice Resolve dispute (owner arbitration)
    function resolveDispute(uint256 taskId, bool favorRunner) external onlyOwner validTaskId(taskId) {
        require(tasks[taskId].status == TaskStatus.Disputed, "Not in dispute");
        
        uint256 reward = tasks[taskId].reward;
        address winner;
        
        if (favorRunner) {
            // Pay runner (with fee)
            uint256 fee = (reward * feeRate) / 10000;
            uint256 runnerReward = reward - fee;
            
            winner = tasks[taskId].runner;
            accumulatedFees += fee;
            totalFeesCollected += fee;
            
            if (!clawnchToken.transfer(winner, runnerReward)) {
                revert TransferFailed();
            }
            
            taskCount[winner] += 1;
            totalEarned[winner] += runnerReward;
        } else {
            // Refund creator
            winner = tasks[taskId].creator;
            if (!clawnchToken.transfer(winner, reward)) {
                revert TransferFailed();
            }
        }
        
        tasks[taskId].status = TaskStatus.Completed;
        tasks[taskId].completedAt = block.timestamp;
        
        emit DisputeResolved(taskId, winner, reward);
    }
    
    // ============ Core Functions ============
    
    /// @notice Create a new task and lock CLAWNCH as reward
    function createTask(
        string memory title,
        string memory description,
        uint256 reward,
        uint256 deadlineDays
    ) external whenNotPaused nonReentrant returns (uint256 taskId) {
        if (reward < MIN_REWARD) revert InvalidReward();
        if (deadlineDays == 0 || deadlineDays > 30) revert InvalidDeadline();
        
        // Transfer CLAWNCH to contract
        if (!clawnchToken.transferFrom(msg.sender, address(this), reward)) {
            revert TransferFailed();
        }
        
        taskId = _nextTaskId++;
        
        Task memory newTask = Task({
            id: taskId,
            creator: msg.sender,
            runner: address(0),
            title: title,
            description: description,
            reward: reward,
            deadline: block.timestamp + (deadlineDays * 1 days),
            status: TaskStatus.Open,
            deliverables: "",
            createdAt: block.timestamp,
            completedAt: 0
        });
        
        tasks.push(newTask);
        agentTasks[msg.sender].push(taskId);
        
        emit TaskCreated(taskId, msg.sender, title, reward);
        return taskId;
    }
    
    /// @notice Submit a bid for a task
    function submitBid(uint256 taskId, string memory proposal) external whenNotPaused validTaskId(taskId) {
        if (tasks[taskId].status != TaskStatus.Open) revert TaskNotOpen(taskId);
        
        taskBids[taskId].push(Bid({
            taskId: taskId,
            bidder: msg.sender,
            timestamp: block.timestamp,
            proposal: proposal
        }));
        
        emit BidSubmitted(taskId, msg.sender);
    }
    
    /// @notice Accept a bid and assign the task
    function acceptBid(uint256 taskId, uint256 bidIndex) external whenNotPaused validTaskId(taskId) {
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].runner != address(0)) revert TaskAlreadyAssigned(taskId);
        
        Bid[] storage bids = taskBids[taskId];
        require(bidIndex < bids.length, "Invalid bid index");
        
        address runner = bids[bidIndex].bidder;
        tasks[taskId].runner = runner;
        tasks[taskId].status = TaskStatus.InProgress;
        
        agentTasks[runner].push(taskId);
        
        emit TaskAssigned(taskId, msg.sender, runner);
    }
    
    /// @notice Submit completed work
    function submitTask(uint256 taskId, string memory deliverables) external whenNotPaused validTaskId(taskId) {
        if (tasks[taskId].runner != msg.sender) revert NotTaskRunner(taskId);
        if (tasks[taskId].status != TaskStatus.InProgress) revert TaskNotInProgress(taskId);
        
        tasks[taskId].status = TaskStatus.Submitted;
        tasks[taskId].deliverables = deliverables;
        
        emit TaskSubmitted(taskId, msg.sender, deliverables);
    }
    
    /// @notice Complete task, collect fee, and release funds
    function completeTask(uint256 taskId, uint8 rating) external whenNotPaused nonReentrant validTaskId(taskId) {
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].status != TaskStatus.Submitted) revert TaskNotInProgress(taskId);
        if (rating < MIN_RATING || rating > MAX_RATING) revert InvalidRating();
        
        address runner = tasks[taskId].runner;
        uint256 reward = tasks[taskId].reward;
        
        // Calculate fee
        uint256 fee = (reward * feeRate) / 10000;
        uint256 runnerReward = reward - fee;
        
        // Update task status
        tasks[taskId].status = TaskStatus.Completed;
        tasks[taskId].completedAt = block.timestamp;
        
        // Accumulate fee
        accumulatedFees += fee;
        totalFeesCollected += fee;
        
        // Transfer to runner
        if (!clawnchToken.transfer(runner, runnerReward)) {
            revert TransferFailed();
        }
        
        // Update reputation and stats
        _updateReputation(runner, rating);
        taskCount[runner] += 1;
        totalEarned[runner] += runnerReward;
        
        emit TaskCompleted(taskId, msg.sender, runner, runnerReward, fee, rating);
    }
    
    /// @notice Cancel an open task and refund creator
    function cancelTask(uint256 taskId, string memory reason) external whenNotPaused nonReentrant validTaskId(taskId) {
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].status != TaskStatus.Open) revert TaskNotOpen(taskId);
        
        uint256 refund = tasks[taskId].reward;
        tasks[taskId].status = TaskStatus.Cancelled;
        
        if (!clawnchToken.transfer(msg.sender, refund)) {
            revert TransferFailed();
        }
        
        emit TaskCancelled(taskId, msg.sender, reason);
    }
    
    /// @notice Raise a dispute (by creator or runner)
    function raiseDispute(uint256 taskId, string memory reason) external whenNotPaused validTaskId(taskId) {
        require(
            tasks[taskId].status == TaskStatus.InProgress || 
            tasks[taskId].status == TaskStatus.Submitted,
            "Cannot dispute"
        );
        require(
            msg.sender == tasks[taskId].creator || 
            msg.sender == tasks[taskId].runner,
            "Not authorized"
        );
        
        tasks[taskId].status = TaskStatus.Disputed;
        
        emit TaskDisputed(taskId, msg.sender, reason);
    }
    
    // ============ View Functions ============
    
    function getTask(uint256 taskId) external view validTaskId(taskId) returns (Task memory) {
        return tasks[taskId];
    }
    
    function getTaskBids(uint256 taskId) external view returns (Bid[] memory) {
        return taskBids[taskId];
    }
    
    function getTaskCount() external view returns (uint256) {
        return tasks.length;
    }
    
    function getAgentStats(address agent) external view returns (
        uint256 reputation,
        uint256 completedTasks,
        uint256 totalEarnedAmount
    ) {
        return (reputationScores[agent], taskCount[agent], totalEarned[agent]);
    }
    
    function getAgentTaskHistory(address agent) external view returns (uint256[] memory) {
        return agentTasks[agent];
    }
    
    function getFeeInfo() external view returns (
        uint256 currentFeeRate,
        address currentFeeRecipient,
        uint256 pendingFees,
        uint256 totalCollected
    ) {
        return (feeRate, feeRecipient, accumulatedFees, totalFeesCollected);
    }
    
    function getOpenTasks(uint256 offset, uint256 limit) external view returns (Task[] memory) {
        uint256 openCount = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].status == TaskStatus.Open) openCount++;
        }
        
        uint256 resultSize = _min(limit, openCount > offset ? openCount - offset : 0);
        Task[] memory result = new Task[](resultSize);
        
        uint256 found = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < tasks.length && resultIndex < resultSize; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                if (found >= offset) {
                    result[resultIndex++] = tasks[i];
                }
                found++;
            }
        }
        
        return result;
    }
    
    // ============ Internal Functions ============
    
    function _updateReputation(address agent, uint8 rating) internal {
        uint256 oldScore = reputationScores[agent];
        uint256 completed = taskCount[agent];
        
        uint256 newScore;
        if (completed == 0) {
            // First task: base score + rating bonus
            newScore = 250 + (uint256(rating) - 3) * 50;
        } else {
            // Weighted average with new rating
            uint256 ratingScore = uint256(rating) * 100;
            newScore = ((oldScore * completed * 5) + (ratingScore * 5)) / ((completed + 1) * 5);
            newScore = _clamp(newScore, 100, 500);
        }
        
        reputationScores[agent] = newScore;
        emit ReputationUpdated(agent, oldScore, newScore);
    }
    
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function _clamp(uint256 value, uint256 minVal, uint256 maxVal) internal pure returns (uint256) {
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    }
    
    // ============ Version ============
    function version() external pure returns (string memory) {
        return "2.0.0";
    }
}
