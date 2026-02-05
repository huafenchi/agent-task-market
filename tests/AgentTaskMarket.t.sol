// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/AgentTaskMarket.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AgentTaskMarketTest is Test {
    AgentTaskMarket public taskMarket;
    address public usdc;
    address public creator;
    address public runner1;
    address public runner2;
    
    uint256 constant MIN_REWARD = 1 * 10**6;
    
    function setUp() public {
        // Setup addresses
        creator = makeAddr("creator");
        runner1 = makeAddr("runner1");
        runner2 = makeAddr("runner2");
        
        // Deploy mock USDC
        usdc = address(new MockUSDC());
        
        // Deploy task market
        taskMarket = new AgentTaskMarket(usdc);
        
        // Give addresses some USDC
        MockUSDC(usdc).mint(creator, 1000 * 10**6);
        MockUSDC(usdc).mint(runner1, 100 * 10**6);
        MockUSDC(usdc).mint(runner2, 100 * 10**6);
        
        // Approve task market to spend USDC
        vm.prank(creator);
        MockUSDC(usdc).approve(address(taskMarket), type(uint256).max);
        
        vm.prank(runner1);
        MockUSDC(usdc).approve(address(taskMarket), type(uint256).max);
        
        vm.prank(runner2);
        MockUSDC(usdc).approve(address(taskMarket), type(uint256).max);
    }
    
    // ============ Test: Create Task ============
    function testCreateTask() public {
        vm.prank(creator);
        uint256 taskId = taskMarket.createTask(
            "Test Task",
            "Test Description",
            50 * 10**6,  // 50 USDC
            7
        );
        
        assertEq(taskId, 1);
        
        AgentTaskMarket.Task memory task = taskMarket.getTask(0);
        
        assertEq(task.id, 1);
        assertEq(task.creator, creator);
        assertEq(task.title, "Test Task");
        assertEq(task.reward, 50 * 10**6);
        assertEq(uint(task.status), uint(AgentTaskMarket.TaskStatus.Open));
    }
    
    function testCreateTaskWithInvalidReward() public {
        vm.prank(creator);
        vm.expectRevert(AgentTaskMarket.InvalidReward.selector);
        taskMarket.createTask(
            "Invalid Task",
            "Description",
            0.5 * 10**6,  // Less than minimum
            7
        );
    }
    
    function testCreateTaskWithInvalidDeadline() public {
        vm.prank(creator);
        vm.expectRevert(AgentTaskMarket.InvalidDeadline.selector);
        taskMarket.createTask(
            "Invalid Task",
            "Description",
            50 * 10**6,
            0  // Zero days
        );
    }
    
    // ============ Test: Submit Bid ============
    function testSubmitBid() public {
        // Create task first
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        // Submit bid
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        AgentTaskMarket.Bid[] memory bids = taskMarket.getTaskBids(0);
        assertEq(bids.length, 1);
        assertEq(bids[0].bidder, runner1);
        assertEq(bids[0].proposal, "I can do this task!");
    }
    
    function testSubmitBidOnClosedTask() public {
        // Create and assign task
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        // Try to bid on assigned task
        vm.prank(runner2);
        vm.expectRevert(abi.encodeWithSelector(AgentTaskMarket.TaskNotOpen.selector, 0));
        taskMarket.submitBid(0, "Too late!");
    }
    
    // ============ Test: Accept Bid ============
    function testAcceptBid() public {
        // Create task and submit bid
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        // Accept bid
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        AgentTaskMarket.Task memory task = taskMarket.getTask(0);
        assertEq(task.runner, runner1);
        assertEq(uint(task.status), uint(AgentTaskMarket.TaskStatus.InProgress));
    }
    
    function testAcceptBidByNonCreator() public {
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        // Try to accept by non-creator
        vm.prank(runner2);
        vm.expectRevert(abi.encodeWithSelector(AgentTaskMarket.NotTaskCreator.selector, 0));
        taskMarket.acceptBid(0, 0);
    }
    
    // ============ Test: Submit Work ============
    function testSubmitWork() public {
        // Setup
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        // Submit work
        vm.prank(runner1);
        taskMarket.submitTask(0, "https://github.com/user/repo");
        
        AgentTaskMarket.Task memory task = taskMarket.getTask(0);
        assertGt(task.completedAt, 0);
    }
    
    // ============ Test: Complete Task ============
    function testCompleteTask() public {
        // Setup - creator creates task
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        // Runner bids
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        // Creator accepts
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        // Runner submits work
        vm.prank(runner1);
        taskMarket.submitTask(0, "https://github.com/user/repo");
        
        // Check balance before
        uint256 balanceBefore = MockUSDC(usdc).balanceOf(runner1);
        
        // Creator completes and rates
        vm.prank(creator);
        taskMarket.completeTask(0, 5);
        
        // Check balance after
        uint256 balanceAfter = MockUSDC(usdc).balanceOf(runner1);
        assertEq(balanceAfter - balanceBefore, 50 * 10**6);
        
        // Check reputation updated
        (uint256 reputation, , ) = taskMarket.getAgentStats(runner1);
        assertGt(reputation, 250);  // Should increase from initial 250
    }
    
    function testCompleteTaskWithLowRating() public {
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        vm.prank(runner1);
        taskMarket.submitTask(0, "https://github.com/user/repo");
        
        vm.prank(creator);
        taskMarket.completeTask(0, 1);  // Rating 1
        
        (uint256 reputation, , ) = taskMarket.getAgentStats(runner1);
        assertLt(reputation, 250);  // Should decrease from initial 250
    }
    
    function testCompleteTaskInvalidRating() public {
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "I can do this task!");
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        vm.prank(runner1);
        taskMarket.submitTask(0, "https://github.com/user/repo");
        
        vm.prank(creator);
        vm.expectRevert(AgentTaskMarket.InvalidRating.selector);
        taskMarket.completeTask(0, 0);  // Rating 0 is invalid
    }
    
    // ============ Test: Cancel Task ============
    function testCancelTask() public {
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        uint256 balanceBefore = MockUSDC(usdc).balanceOf(creator);
        
        vm.prank(creator);
        taskMarket.cancelTask(0, "Changed my mind");
        
        uint256 balanceAfter = MockUSDC(usdc).balanceOf(creator);
        assertEq(balanceAfter - balanceBefore, 50 * 10**6);
        
        AgentTaskMarket.Task memory task = taskMarket.getTask(0);
        assertEq(uint(task.status), uint(AgentTaskMarket.TaskStatus.Cancelled));
    }
    
    function testCancelTaskByNonCreator() public {
        vm.prank(creator);
        taskMarket.createTask("Test Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        vm.expectRevert(abi.encodeWithSelector(AgentTaskMarket.NotTaskCreator.selector, 0));
        taskMarket.cancelTask(0, "Not my task");
    }
    
    // ============ Test: Reputation System ============
    function testReputationUpdate() public {
        vm.prank(creator);
        taskMarket.createTask("Task 1", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "Bid 1");
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        vm.prank(runner1);
        taskMarket.submitTask(0, "https://example.com/1");
        
        vm.prank(creator);
        taskMarket.completeTask(0, 5);
        
        // Complete second task
        vm.prank(creator);
        taskMarket.createTask("Task 2", "Description", 60 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(1, "Bid 2");
        
        vm.prank(creator);
        taskMarket.acceptBid(1, 1);
        
        vm.prank(runner1);
        taskMarket.submitTask(1, "https://example.com/2");
        
        vm.prank(creator);
        taskMarket.completeTask(1, 4);
        
        // Check final reputation
        (uint256 reputation, uint256 completed, uint256 earned) = taskMarket.getAgentStats(runner1);
        
        assertEq(completed, 2);
        assertEq(earned, 110 * 10**6);  // 50 + 60
        assertGt(reputation, 250);  // Should be higher than initial
    }
    
    // ============ Test: Multiple Bids ============
    function testMultipleBids() public {
        vm.prank(creator);
        taskMarket.createTask("Task", "Description", 50 * 10**6, 7);
        
        vm.prank(runner1);
        taskMarket.submitBid(0, "Runner 1 bid");
        
        vm.prank(runner2);
        taskMarket.submitBid(0, "Runner 2 bid");
        
        AgentTaskMarket.Bid[] memory bids = taskMarket.getTaskBids(0);
        assertEq(bids.length, 2);
        assertEq(bids[0].bidder, runner1);
        assertEq(bids[1].bidder, runner2);
    }
    
    // ============ Test: Task History ============
    function testTaskHistory() public {
        // Creator creates task
        vm.prank(creator);
        taskMarket.createTask("Task 1", "Desc", 50 * 10**6, 7);
        
        // Runner1 bids and completes
        vm.prank(runner1);
        taskMarket.submitBid(0, "Bid");
        
        vm.prank(creator);
        taskMarket.acceptBid(0, 0);
        
        vm.prank(runner1);
        taskMarket.submitTask(0, "Done");
        
        vm.prank(creator);
        taskMarket.completeTask(0, 5);
        
        // Check runner's task history
        uint256[] memory history = taskMarket.getAgentTaskHistory(runner1);
        assertEq(history.length, 1);
        assertEq(history[0], 0);
    }
}

// ============ Mock USDC Contract ============
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}
    
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
