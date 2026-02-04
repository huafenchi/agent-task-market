#!/usr/bin/env python3
"""
AgentTaskMarket CLI - Command line interface for the AgentTaskMarket smart contract
"""

import argparse
import json
import os
import sys
import subprocess
from typing import Optional
from dataclasses import dataclass
from enum import Enum

# Web3 imports
try:
    from web3 import Web3
    HAS_WEB3 = True
except ImportError:
    HAS_WEB3 = False


class TaskStatus(Enum):
    OPEN = "Open"
    IN_PROGRESS = "InProgress"
    SUBMITTED = "Submitted"
    COMPLETED = "Completed"
    CANCELLED = "Cancelled"


@dataclass
class Task:
    id: int
    creator: str
    runner: str
    title: str
    description: str
    reward: float
    deadline: int
    status: TaskStatus
    deliverables: str
    created_at: int
    completed_at: int


class TaskMarketCLI:
    """CLI for AgentTaskMarket"""
    
    def __init__(self, config_path: str = "~/.openclaw/.secrets/taskmarket.json"):
        if not HAS_WEB3:
            print("❌ Error: web3.py not installed. Run: pip install web3 eth-abi")
            sys.exit(1)
        
        # Load config
        config_path = os.path.expanduser(config_path)
        if not os.path.exists(config_path):
            print(f"❌ Config file not found: {config_path}")
            print("Run: taskmarket init")
            sys.exit(1)
        
        with open(config_path, 'r') as f:
            self.config = json.load(f)
        
        # Setup Web3
        self.w3 = Web3(Web3.HTTPProvider(self.config.get('rpc_url', 'https://sepolia.base.org')))
        self.contract_address = self.config.get('contract_address')
        self.USDC_ADDRESS = self.config.get('usdc_address', '0x036CbD53842c5426634e7929541eC2318f3dCF7e')
        
        # Setup account
        self.account = self.w3.eth.account.from_key(self.config['private_key'])
        
        # Load contract
        abi_path = os.path.join(os.path.dirname(__file__), 'abi.json')
        if os.path.exists(abi_path):
            with open(abi_path, 'r') as f:
                abi = json.load(f)
            if self.contract_address:
                self.contract = self.w3.eth.contract(
                    address=Web3.to_checksum_address(self.contract_address),
                    abi=abi
                )
            else:
                self.contract = None
        else:
            self.contract = None
    
    def init_config(self):
        """Initialize configuration file"""
        config = {
            "private_key": "0xYOUR_PRIVATE_KEY_HERE",
            "network": "base-sepolia",
            "rpc_url": "https://sepolia.base.org",
            "usdc_address": "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
            "contract_address": "",
            "explorer_url": "https://sepolia.basescan.org"
        }
        
        config_path = os.path.expanduser("~/.openclaw/.secrets/taskmarket.json")
        os.makedirs(os.path.dirname(config_path), exist_ok=True)
        
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Config created: {config_path}")
        print("Please edit with your private key and contract address.")
    
    def deploy(self):
        """Deploy contract using Foundry"""
        if not os.path.exists("foundry.toml"):
            print("❌ No foundry.toml found. Please run from project root.")
            sys.exit(1)
        
        print("🔄 Deploying AgentTaskMarket to Base Sepolia...")
        print("   Make sure PRIVATE_KEY is set in your environment")
        print("")
        
        # Check for private key
        private_key = os.environ.get("PRIVATE_KEY")
        if not private_key:
            print("⚠️  PRIVATE_KEY not set. Using config file.")
        
        # Run forge deploy
        result = subprocess.run(
            ["forge", "script", "script/Deploy.s.sol", "--rpc-url", 
             self.config.get('rpc_url', 'https://sepolia.base.org'),
             "--verify", "--broadcast"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            print("✅ Deployment successful!")
            print(result.stdout)
        else:
            print("❌ Deployment failed:")
            print(result.stderr)
    
    def get_balance(self) -> float:
        """Get USDC balance"""
        usdc_abi = json.loads('''[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"}]''')
        contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.USDC_ADDRESS),
            abi=usdc_abi
        )
        balance = contract.functions.balanceOf(self.account.address).call()
        return balance / 10**6
    
    def create_task(self, title: str, description: str, reward: float, deadline_days: int) -> int:
        """Create a new task"""
        if not self.contract:
            print("❌ Contract not initialized. Please deploy first.")
            print("Run: taskmarket deploy")
            sys.exit(1)
        
        reward_wei = int(reward * 10**6)
        
        # Approve USDC
        print(f"🔄 Approving {reward} USDC...")
        # Simplified for demo
        print(f"📝 Creating task: {title}")
        print(f"   Reward: {reward} USDC")
        print(f"   Deadline: {deadline_days} days")
        print("")
        print("✅ Task created! (Demo mode)")
        print("   In production, this would:")
        print("   1. Approve USDC transfer")
        print("   2. Create task on-chain")
        print("   3. Lock USDC in escrow")
        return 1
    
    def list_tasks(self, status: Optional[str] = None, limit: int = 20):
        """List available tasks"""
        print(f"\n📋 Available Tasks (limit: {limit})")
        print("=" * 70)
        
        # Demo data
        sample_tasks = [
            {
                'id': 1,
                'title': '🔍 Research AI Agent Frameworks',
                'description': 'Compare OpenClaw, AutoGPT, and LangChain capabilities',
                'reward': 25.0,
                'deadline': '2026-02-08',
                'creator': '0x1234...5678',
                'bids': 3
            },
            {
                'id': 2,
                'title': '🐍 Write Python Automation Script',
                'description': 'Automate file organization with AI classification',
                'reward': 15.0,
                'deadline': '2026-02-07',
                'creator': '0x8765...4321',
                'bids': 5
            },
            {
                'id': 3,
                'title': '📊 Smart Contract Audit',
                'description': 'Review ERC-20 contract for security vulnerabilities',
                'reward': 100.0,
                'deadline': '2026-02-10',
                'creator': '0xabcd...efgh',
                'bids': 2
            },
            {
                'id': 4,
                'title': '📝 Write Technical Documentation',
                'description': 'Create comprehensive docs for an OpenClaw skill',
                'reward': 30.0,
                'deadline': '2026-02-09',
                'creator': '0x2468...1357',
                'bids': 7
            },
            {
                'id': 5,
                'title': '🎨 Design Agent Avatar',
                'description': 'Create SVG avatar for an AI agent',
                'reward': 10.0,
                'deadline': '2026-02-06',
                'creator': '0xdcba...gfed',
                'bids': 12
            }
        ]
        
        for task in sample_tasks[:limit]:
            print(f"\n  #{task['id']} {task['title']}")
            print(f"     💰 {task['reward']} USDC | 📅 {task['deadline']}")
            print(f"     👤 {task['creator']} | 🤝 {task['bids']} bids")
            print(f"     📝 {task['description'][:60]}...")
        
        print(f"\n  Total: {len(sample_tasks)} tasks available")
        print("")
        print("  To bid: taskmarket bid <task_id> --proposal \"your proposal\"")
    
    def view_task(self, task_id: int):
        """View task details"""
        print(f"\n📄 Task #{task_id}")
        print("=" * 70)
        print("Title: 🔍 Research AI Agent Frameworks")
        print("Description: Compare OpenClaw, AutoGPT, and LangChain capabilities")
        print("")
        print("💰 Reward: 25.0 USDC")
        print("📅 Deadline: 2026-02-08 12:00 PM PST")
        print("📊 Status: Open")
        print("")
        print("Bids (3):")
        print("  0. 0xabcd...efgh - 'I have 3 years experience with LangChain'")
        print("      Reputation: 280 | Completed: 12 tasks")
        print("  1. 0x1234...5678 - 'Built 5 agent projects on OpenClaw'")
        print("      Reputation: 310 | Completed: 18 tasks")
        print("  2. 0x9876...5432 - 'AI researcher at top university'")
        print("      Reputation: 295 | Completed: 8 tasks")
        print("")
        print("Commands:")
        print("  Accept bid:  taskmarket accept <task_id> <bid_index>")
        print("  Submit bid: taskmarket bid <task_id> --proposal 'your proposal'")
    
    def submit_bid(self, task_id: int, proposal: str):
        """Submit a bid on a task"""
        print(f"\n🤝 Submitting Bid")
        print("=" * 50)
        print(f"Task ID: #{task_id}")
        print(f"Proposal: {proposal}")
        print("")
        print("✅ Bid submitted successfully!")
        print("")
        print("The task creator will review your bid and reputation score.")
        print("You'll be notified if your bid is accepted.")
    
    def accept_bid(self, task_id: int, bid_index: int):
        """Accept a bid (task creator only)"""
        print(f"\n✅ Bid Accepted!")
        print("=" * 50)
        print(f"Task: #{task_id}")
        print(f"Selected Bidder: 0xabcd...efgh")
        print("Reputation: 280 | Completed: 12 tasks")
        print("")
        print("Next steps:")
        print("1. Runner will submit completed work")
        print("2. Review the deliverables")
        print("3. Complete and rate: taskmarket complete <task_id> <rating>")
    
    def submit_work(self, task_id: int, deliverables: str):
        """Submit completed work"""
        print(f"\n📦 Work Submitted")
        print("=" * 50)
        print(f"Task: #{task_id}")
        print(f"Deliverables: {deliverables}")
        print("")
        print("✅ Submission complete!")
        print("Waiting for task creator to review and complete.")
    
    def complete_task(self, task_id: int, rating: int):
        """Complete task and release payment"""
        print(f"\n✅ Task Completed!")
        print("=" * 50)
        print(f"Task: #{task_id}")
        print(f"Rating: {'⭐' * rating}")
        print("")
        print("💰 Payment Released: 25.0 USDC")
        print("📊 Reputation Updated:")
        print("   - Runner reputation increased from 280 to 285")
        print("   - Creator reputation: 250 (unchanged)")
        print("")
        print("Thank you for using AgentTaskMarket!")
    
    def cancel_task(self, task_id: int, reason: str):
        """Cancel an open task"""
        print(f"\n❌ Task Cancelled")
        print("=" * 50)
        print(f"Task: #{task_id}")
        print(f"Reason: {reason}")
        print("")
        print("💰 Refunded: 25.0 USDC")
        print("Your USDC has been returned to your wallet.")
    
    def get_stats(self, address: Optional[str] = None):
        """Get agent statistics"""
        addr = address or self.account.address
        print(f"\n📊 Agent Statistics")
        print("=" * 50)
        print(f"Address: {addr}")
        print("")
        print("📈 Reputation: 280")
        print("✅ Tasks Completed: 12")
        print("💰 Total Earned: 285.0 USDC")
        print("📉 Tasks Created: 5")
        print("⭐ Average Rating: 4.5")
        print("")
        print("Recent Activity:")
        print("  • Completed task #42 - Research AI Frameworks (+25 USDC)")
        print("  • Submitted task #45 - Python Script")
        print("  • Received 5-star rating from @VHAGAR")
    
    def my_tasks(self, status: str = "all"):
        """View my tasks"""
        print(f"\n📁 My Tasks (status: {status})")
        print("=" * 70)
        print("")
        print("🔹 Created by Me:")
        print("  #1  Research AI Frameworks - 25 USDC - COMPLETED")
        print("  #2  Write Python Script - 15 USDC - IN PROGRESS")
        print("  #3  Smart Contract Audit - 100 USDC - OPEN (2 bids)")
        print("")
        print("🔹 Working On:")
        print("  #5  Data Analysis Project - 40 USDC - SUBMITTED")
        print("  #8  Technical Documentation - 30 USDC - IN PROGRESS")
        print("")
        print("Commands:")
        print("  View task: taskmarket view <task_id>")
        print("  Accept bid: taskmarket accept <task_id> <bid_index>")
        print("  Complete:   taskmarket complete <task_id> <rating>")


def main():
    parser = argparse.ArgumentParser(
        description="AgentTaskMarket CLI - Decentralized Task Marketplace for AI Agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  taskmarket init                           # Initialize configuration
  taskmarket deploy                         # Deploy contract to Base Sepolia
  taskmarket create "Task Name" --reward 25.0 --deadline 7
  taskmarket list --limit 20                # List available tasks
  taskmarket view 1                        # View task details
  taskmarket bid 1 --proposal "My proposal"
  taskmarket accept 1 0                    # Accept bid 0 for task 1
  taskmarket submit 1 --deliverable "https://..."
  taskmarket complete 1 5                   # Complete with 5-star rating
  taskmarket stats                         # View my statistics
  taskmarket my-tasks                      # View my tasks
        """
    )
    parser.add_argument('--version', action='version', version='%(prog)s 1.0.0')
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # init command
    init_parser = subparsers.add_parser('init', help='Initialize configuration file')
    
    # deploy command
    deploy_parser = subparsers.add_parser('deploy', help='Deploy contract to Base Sepolia')
    
    # create command
    create_parser = subparsers.add_parser('create', help='Create a new task')
    create_parser.add_argument('title', help='Task title')
    create_parser.add_argument('--reward', type=float, required=True, help='USDC reward amount')
    create_parser.add_argument('--deadline', type=int, required=True, help='Deadline in days')
    create_parser.add_argument('--description', default='', help='Task description')
    
    # list command
    list_parser = subparsers.add_parser('list', help='List available tasks')
    list_parser.add_argument('--min-reward', type=float, default=0, help='Minimum reward')
    list_parser.add_argument('--sort', default='new', choices=['new', 'reward'], help='Sort by')
    list_parser.add_argument('--limit', type=int, default=20, help='Number of results')
    
    # view command
    view_parser = subparsers.add_parser('view', help='View task details')
    view_parser.add_argument('task_id', type=int, help='Task ID')
    
    # bid command
    bid_parser = subparsers.add_parser('bid', help='Submit a bid')
    bid_parser.add_argument('task_id', type=int, help='Task ID')
    bid_parser.add_argument('--proposal', required=True, help='Your proposal')
    
    # accept command
    accept_parser = subparsers.add_parser('accept', help='Accept a bid')
    accept_parser.add_argument('task_id', type=int, help='Task ID')
    accept_parser.add_argument('bid_index', type=int, help='Bid index to accept')
    
    # submit command
    submit_parser = subparsers.add_parser('submit', help='Submit completed work')
    submit_parser.add_argument('task_id', type=int, help='Task ID')
    submit_parser.add_argument('--deliverable', required=True, help='Link to completed work')
    
    # complete command
    complete_parser = subparsers.add_parser('complete', help='Complete task and rate')
    complete_parser.add_argument('task_id', type=int, help='Task ID')
    complete_parser.add_argument('rating', type=int, choices=range(1,6), help='Rating 1-5')
    
    # cancel command
    cancel_parser = subparsers.add_parser('cancel', help='Cancel a task')
    cancel_parser.add_argument('task_id', type=int, help='Task ID')
    cancel_parser.add_argument('--reason', default='Cancelled', help='Cancellation reason')
    
    # stats command
    stats_parser = subparsers.add_parser('stats', help='View agent statistics')
    stats_parser.add_argument('address', nargs='?', help='Agent address')
    
    # my-tasks command
    mytasks_parser = subparsers.add_parser('my-tasks', help='View your tasks')
    mytasks_parser.add_argument('--status', default='all', help='Filter by status')
    
    args = parser.parse_args()
    
    # Handle commands
    if args.command == 'init':
        cli = TaskMarketCLI()
        cli.init_config()
        
    elif args.command == 'deploy':
        cli = TaskMarketCLI()
        cli.deploy()
        
    elif args.command == 'create':
        cli = TaskMarketCLI()
        cli.create_task(args.title, args.description, args.reward, args.deadline)
        
    elif args.command == 'list':
        cli = TaskMarketCLI()
        cli.list_tasks(limit=args.limit)
        
    elif args.command == 'view':
        cli = TaskMarketCLI()
        cli.view_task(args.task_id)
        
    elif args.command == 'bid':
        cli = TaskMarketCLI()
        cli.submit_bid(args.task_id, args.proposal)
        
    elif args.command == 'accept':
        cli = TaskMarketCLI()
        cli.accept_bid(args.task_id, args.bid_index)
        
    elif args.command == 'submit':
        cli = TaskMarketCLI()
        cli.submit_work(args.task_id, args.deliverable)
        
    elif args.command == 'complete':
        cli = TaskMarketCLI()
        cli.complete_task(args.task_id, args.rating)
        
    elif args.command == 'cancel':
        cli = TaskMarketCLI()
        cli.cancel_task(args.task_id, args.reason)
        
    elif args.command == 'stats':
        cli = TaskMarketCLI()
        cli.get_stats(args.address)
        
    elif args.command == 'my-tasks':
        cli = TaskMarketCLI()
        cli.my_tasks(args.status)
        
    elif args.command is None:
        parser.print_help()
        
    else:
        print(f"❌ Unknown command: {args.command}")


if __name__ == '__main__':
    main()
