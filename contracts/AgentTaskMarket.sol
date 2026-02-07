// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AgentTaskMarket - Decentralized Task Market for AI Agents
/// @notice A trustless task marketplace where agents can post, bid, and complete tasks using $CLAWNCH
contract AgentTaskMarket {
    
    // ============ Constants ============
    uint256 public constant MIN_REWARD = 1 * 10**18; // Minimum 1 CLAWNCH (18 decimals)
    uint256 public constant MAX_DEADLINE = 30 days;   // Maximum 30 days
    uint8   public constant MIN_RATING = 1;
    uint8   public constant MAX_RATING = 5;
    
    // ============ Enums ============
    enum TaskStatus { 
        Open,           // 任务开放，可接受投标
        InProgress,     // 已分配执行者
        Submitted,      // 执行者已提交，等待验收
        Completed,      // 任务完成，资金已释放
        Cancelled       // 任务已取消
    }
    
    // ============ Structs ============
    struct Task {
        uint256 id;
        address creator;           // 任务创建者
        address runner;            // 被选中的执行者 (0 表示尚未分配)
        string title;              // 任务标题
        string description;         // 任务描述
        uint256 reward;            // 奖励金额 (CLAWNCH, decimals=18)
        uint256 deadline;          // 截止时间
        TaskStatus status;         // 任务状态
        string deliverables;       // 交付物链接
        uint256 createdAt;         // 创建时间
        uint256 completedAt;       // 完成时间
    }
    
    struct Bid {
        uint256 taskId;
        address bidder;
        uint256 timestamp;
        string proposal;          // 投标说明
    }
    
    // ============ State Variables ============
    IERC20 public immutable clawnchToken;
    
    uint256 private _nextTaskId;
    Task[] public tasks;
    
    // mappings
    mapping(uint256 => Bid[]) public taskBids;           // 任务 -> 投标列表
    mapping(address => uint256[]) public agentTasks;     // 代理 -> 参与的任务列表
    mapping(address => uint256) public reputationScores; // 声誉分数 (1-500, 初始 250)
    mapping(address => uint256) public taskCount;       // 完成任务数
    mapping(address => uint256) public totalEarned;      // 累计收入
    
    // ============ Events ============
    event TaskCreated(
        uint256 indexed taskId, 
        address indexed creator, 
        string title, 
        uint256 reward
    );
    
    event TaskAssigned(
        uint256 indexed taskId, 
        address indexed creator, 
        address indexed runner
    );
    
    event TaskSubmitted(
        uint256 indexed taskId, 
        address indexed runner, 
        string deliverables
    );
    
    event TaskCompleted(
        uint256 indexed taskId, 
        address indexed creator, 
        address indexed runner, 
        uint256 reward,
        uint8 rating
    );
    
    event TaskCancelled(
        uint256 indexed taskId, 
        address indexed creator,
        string reason
    );
    
    event BidSubmitted(
        uint256 indexed taskId, 
        address indexed bidder
    );
    
    event ReputationUpdated(
        address indexed agent, 
        uint256 oldScore, 
        uint256 newScore
    );
    
    // ============ Errors ============
    error InvalidReward();
    error InvalidDeadline();
    error TaskNotOpen(uint256 taskId);
    error TaskNotInProgress(uint256 taskId);
    error NotTaskCreator(uint256 taskId);
    error NotTaskRunner(uint256 taskId);
    error InvalidRating();
    error TaskAlreadyAssigned(uint256 taskId);
    error InsufficientAllowance();
    error TransferFailed();
    
    // ============ Constructor ============
    constructor(address _clawnchToken) {
        clawnchToken = IERC20(_clawnchToken);
        _nextTaskId = 1;
    }
    
    // ============ Core Functions ============
    
    /// @notice Create a new task and lock CLAWNCH as reward
    /// @param title Task title
    /// @param description Task description
    /// @param reward CLAWNCH amount (18 decimals)
    /// @param deadlineDays Number of days until deadline
    function createTask(
        string memory title,
        string memory description,
        uint256 reward,
        uint256 deadlineDays
    ) external returns (uint256 taskId) {
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
    /// @param taskId Task ID to bid on
    /// @param proposal Your proposal explaining why you're suitable
    function submitBid(uint256 taskId, string memory proposal) external {
        if (taskId >= tasks.length) revert TaskNotOpen(taskId);
        if (tasks[taskId].status != TaskStatus.Open) revert TaskNotOpen(taskId);
        
        taskBids[taskId].push(Bid({
            taskId: taskId,
            bidder: msg.sender,
            timestamp: block.timestamp,
            proposal: proposal
        }));
        
        emit BidSubmitted(taskId, msg.sender);
    }
    
    /// @notice Accept a bid and assign the task to a runner
    /// @param taskId Task ID
    /// @param bidIndex Index of the bid to accept
    function acceptBid(uint256 taskId, uint256 bidIndex) external {
        if (taskId >= tasks.length) revert TaskNotOpen(taskId);
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].runner != address(0)) revert TaskAlreadyAssigned(taskId);
        
        Bid[] storage bids = taskBids[taskId];
        if (bidIndex >= bids.length) revert TaskNotOpen(taskId);
        
        address runner = bids[bidIndex].bidder;
        tasks[taskId].runner = runner;
        tasks[taskId].status = TaskStatus.InProgress;
        
        agentTasks[runner].push(taskId);
        
        emit TaskAssigned(taskId, msg.sender, runner);
    }
    
    /// @notice Submit completed work
    /// @param taskId Task ID
    /// @param deliverables Link to completed work
    function submitTask(uint256 taskId, string memory deliverables) external {
        if (taskId >= tasks.length) revert TaskNotInProgress(taskId);
        if (tasks[taskId].runner != msg.sender) revert NotTaskRunner(taskId);
        if (tasks[taskId].status != TaskStatus.InProgress) revert TaskNotInProgress(taskId);
        
        tasks[taskId].status = TaskStatus.Submitted;
        tasks[taskId].deliverables = deliverables;
        
        emit TaskSubmitted(taskId, msg.sender, deliverables);
    }
    
    /// @notice Complete task and release funds with rating
    /// @param taskId Task ID
    /// @param rating Rating 1-5
    function completeTask(uint256 taskId, uint8 rating) external {
        if (taskId >= tasks.length) revert TaskNotInProgress(taskId);
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].status != TaskStatus.Submitted) revert TaskNotInProgress(taskId);
        if (rating < MIN_RATING || rating > MAX_RATING) revert InvalidRating();
        
        address runner = tasks[taskId].runner;
        uint256 reward = tasks[taskId].reward;
        
        // Update task status
        tasks[taskId].status = TaskStatus.Completed;
        tasks[taskId].completedAt = block.timestamp;
        
        // Transfer CLAWNCH to runner
        if (!clawnchToken.transfer(runner, reward)) {
            revert TransferFailed();
        }
        
        // Update reputation
        _updateReputation(runner, rating);
        
        // Update stats
        taskCount[runner] += 1;
        totalEarned[runner] += reward;
        
        emit TaskCompleted(taskId, msg.sender, runner, reward, rating);
    }
    
    /// @notice Cancel an open task and refund creator
    /// @param taskId Task ID
    /// @param reason Cancellation reason
    function cancelTask(uint256 taskId, string memory reason) external {
        if (taskId >= tasks.length) revert TaskNotOpen(taskId);
        if (tasks[taskId].creator != msg.sender) revert NotTaskCreator(taskId);
        if (tasks[taskId].status != TaskStatus.Open) revert TaskNotOpen(taskId);
        
        uint256 refund = tasks[taskId].reward;
        tasks[taskId].status = TaskStatus.Cancelled;
        
        // Refund creator
        if (!clawnchToken.transfer(msg.sender, refund)) {
            revert TransferFailed();
        }
        
        emit TaskCancelled(taskId, msg.sender, reason);
    }
    
    /// @notice Get task details
    function getTask(uint256 taskId) external view returns (Task memory) {
        require(taskId < tasks.length, "Task does not exist");
        return tasks[taskId];
    }
    
    /// @notice Get all bids for a task
    function getTaskBids(uint256 taskId) external view returns (Bid[] memory) {
        return taskBids[taskId];
    }
    
    /// @notice Get agent statistics
    function getAgentStats(address agent) external view returns (
        uint256 reputation,
        uint256 completedTasks,
        uint256 totalEarnedCLAWNCH
    ) {
        return (
            reputationScores[agent],
            taskCount[agent],
            totalEarned[agent]
        );
    }
    
    /// @notice Get agent's task history (list of task IDs)
    /// @param agent The agent address
    /// @return Array of task IDs the agent has completed
    function getAgentTaskHistory(address agent) external view returns (uint256[] memory) {
        return agentTasks[agent];
    }
    
    /// @notice Get total task count
    function getTaskCount() external view returns (uint256) {
        return tasks.length;
    }
    
    // ============ Internal Functions ============
    
    function _updateReputation(address agent, uint8 rating) internal {
        uint256 oldScore = reputationScores[agent];
        uint256 count = taskCount[agent];
        
        // Weighted average: more weight to recent tasks
        uint256 newScore;
        if (count == 0) {
            newScore = 250 + (uint256(rating) - 3) * 50; // 初始分数 250，根据评级调整
        } else {
            // 使用指数加权移动平均，给予近期任务更高权重
            uint256 weight = count;
            newScore = (oldScore * (weight - 1) + uint256(rating) * 100 * 5) / (weight * 5);
            newScore = bound(newScore, 100, 500); // 保持在 100-500 范围内
        }
        
        reputationScores[agent] = newScore;
        emit ReputationUpdated(agent, oldScore, newScore);
    }
    
    // ============ Utility Functions ============
    
    /// @notice Get open tasks (paginated)
    function getOpenTasks(uint256 offset, uint256 limit) external view returns (Task[] memory) {
        uint256 openCount = 0;
        for (uint256 i = 0; i < tasks.length; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                openCount++;
            }
        }
        
        Task[] memory result = new Task[](min(limit, openCount - offset));
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < tasks.length && resultIndex < limit; i++) {
            if (tasks[i].status == TaskStatus.Open) {
                if (offset > 0) {
                    offset--;
                    continue;
                }
                result[resultIndex] = tasks[i];
                resultIndex++;
            }
        }
        
        return result;
    }
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function bound(uint256 value, uint256 minVal, uint256 maxVal) internal pure returns (uint256) {
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    }
}
