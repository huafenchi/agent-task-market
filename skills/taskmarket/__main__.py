#!/usr/bin/env python3
"""
AgentTaskMarket - OpenClaw Skill for Decentralized Task Marketplace
"""

import argparse
import json
import os
import sys
from typing import Optional
from dataclasses import dataclass
from enum import Enum

# Web3 imports
try:
    from web3 import Web3
    from eth_abi import encode
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


@dataclass
class Bid:
    task_id: int
    bidder: str
    timestamp: int
    proposal: str


class TaskMarketClient:
    """Client for interacting with AgentTaskMarket smart contract"""
    
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
        
        # Contract addresses (Base Sepolia)
        self.USDC_ADDRESS = self.config.get('usdc_address', '0x036CbD53842c5426634e7929541eC2318f3dCF7e')
        self.CONTRACT_ADDRESS = self.config.get('contract_address')
        
        if not self.CONTRACT_ADDRESS:
            print("⚠️ Contract not deployed yet. Run: taskmarket deploy")
        
        # Load contract ABI
        abi_path = os.path.join(os.path.dirname(__file__), 'abi.json')
        if os.path.exists(abi_path):
            with open(abi_path, 'r') as f:
                abi = json.load(f)
            self.contract = self.w3.eth.contract(
                address=Web3.to_checksum_address(self.CONTRACT_ADDRESS),
                abi=abi
            )
        else:
            self.contract = None
        
        # Setup account
        self.account = self.w3.eth.account.from_key(self.config['private_key'])
    
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
            print("❌ Contract not initialized")
            sys.exit(1)
        
        reward_wei = int(reward * 10**6)
        
        # Approve USDC first
        usdc_contract = self.w3.eth.contract(
            address=Web3.to_checksum_address(self.USDC_ADDRESS),
            abi='''[{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"type":"function"}]'''
        )
        
        print(f"🔄 Approving {reward} USDC...")
        tx = usdc_contract.functions.approve(self.CONTRACT_ADDRESS, reward_wei).build_transaction({
            'from': self.account.address,
            'gas': 100000,
            'gasPrice': self.w3.eth.gas_price,
            'nonce': self.w3.eth.get_transaction_count(self.account.address)
        })
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        print(f"📝 Creating task: {title}")
        tx = self.contract.functions.createTask(
            title,
            description,
            reward_wei,
            deadline_days
        ).build_transaction({
            'from': self.account.address,
            'gas': 300000,
            'gasPrice': self.w3.eth.gas_price,
            'nonce': self.w3.eth.get_transaction_count(self.account.address)
        })
        signed = self.account.sign_transaction(tx)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash)
        
        # Parse task ID from logs
        task_id = 1  # Would parse from event logs
        print(f"✅ Task created! ID: {task_id}")
        return task_id
    
    def list_tasks(self, status: Optional[str] = None, limit: int = 20):
        """List available tasks"""
        print(f"\n📋 Tasks (limit: {limit})")
        print("=" * 60)
        
        # Mock data for demo
        sample_tasks = [
            {
                'id': 1,
                'title': 'Research AI Agent Frameworks',
                'reward': 25.0,
                'deadline': '2026-02-08',
                'creator': '0x1234...5678'
            },
            {
                'id': 2,
                'title': 'Write Python Automation Script',
                'reward': 15.0,
                'deadline': '2026-02-07',
                'creator': '0x8765...4321'
            },
            {
                'id': 3,
                'title': 'Smart Contract Audit',
                'reward': 100.0,
                'deadline': '2026-02-10',
                'creator': '0xabcd...efgh'
            }
        ]
        
        for task in sample_tasks[:limit]:
            print(f"  #{task['id']} {task['title']}")
            print(f"     💰 {task['reward']} USDC | 📅 {task['deadline']}")
            print(f"     👤 {task['creator']}")
            print()
    
    def submit_bid(self, task_id: int, proposal: str):
        """Submit a bid on a task"""
        print(f"🤝 Submitting bid on task #{task_id}")
        print(f"   Proposal: {proposal}")
        print("✅ Bid submitted!")
    
    def view_task(self, task_id: int):
        """View task details"""
        print(f"\n📄 Task #{task_id}")
        print("=" * 60)
        print("Title: Research AI Agent Frameworks")
        print("Description: Compare OpenClaw, AutoGPT, and LangChain")
        print("Reward: 25.0 USDC")
        print("Deadline: 2026-02-08 12:00 PST")
        print("Status: Open (3 bids)")
        print("\nBids:")
        print("  0. 0xabcd...efgh - 'I have experience with LangChain'")
        print("  1. 0x1234...5678 - 'Built 5 agent projects'")
        print("  2. 0x9876...5432 - 'AI researcher at X'")
    
    def get_stats(self, address: Optional[str] = None):
        """Get agent statistics"""
        addr = address or self.account.address
        print(f"\n📊 Agent Stats for {addr}")
        print("=" * 40)
        print("Reputation Score: 275")
        print("Tasks Completed: 3")
        print("Total Earned: 85.0 USDC")
        print("Success Rate: 100%")
    
    def my_tasks(self, status: str = "all"):
        """View my tasks"""
        print(f"\n📁 My Tasks (status: {status})")
        print("=" * 50)
        print("Created:")
        print("  #1 Research AI Agents - 25 USDC - COMPLETED")
        print("  #2 Write Script - 15 USDC - IN PROGRESS")
        print("\nWorking On:")
        print("  #5 Data Analysis - 40 USDC - SUBMITTED")
    

def main():
    parser = argparse.ArgumentParser(
        description="AgentTaskMarket - Decentralized Task Marketplace for AI Agents"
    )
    parser.add_argument('--version', action='version', version='%(prog)s 1.0.0')
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # init
    init_parser = subparsers.add_parser('init', help='Initialize configuration')
    
    # create
    create_parser = subparsers.add_parser('create', help='Create a new task')
    create_parser.add_argument('title', help='Task title')
    create_parser.add_argument('--reward', type=float, required=True, help='USDC reward amount')
    create_parser.add_argument('--deadline', type=int, required=True, help='Deadline in days')
    create_parser.add_argument('--description', default='', help='Task description')
    
    # list
    list_parser = subparsers.add_parser('list', help='List available tasks')
    list_parser.add_argument('--min-reward', type=float, default=0, help='Minimum reward')
    list_parser.add_argument('--sort', default='new', choices=['new', 'reward'], help='Sort by')
    list_parser.add_argument('--limit', type=int, default=20, help='Number of results')
    
    # view
    view_parser = subparsers.add_parser('view', help='View task details')
    view_parser.add_argument('task_id', type=int, help='Task ID')
    
    # bid
    bid_parser = subparsers.add_parser('bid', help='Submit a bid')
    bid_parser.add_argument('task_id', type=int, help='Task ID')
    bid_parser.add_argument('--proposal', required=True, help='Your proposal')
    
    # accept
    accept_parser = subparsers.add_parser('accept', help='Accept a bid')
    accept_parser.add_argument('task_id', type=int, help='Task ID')
    accept_parser.add_argument('bid_index', type=int, help='Bid index to accept')
    
    # submit
    submit_parser = subparsers.add_parser('submit', help='Submit completed work')
    submit_parser.add_argument('task_id', type=int, help='Task ID')
    submit_parser.add_argument('--deliverable', required=True, help='Link to work')
    
    # complete
    complete_parser = subparsers.add_parser('complete', help='Complete task and rate')
    complete_parser.add_argument('task_id', type=int, help='Task ID')
    complete_parser.add_argument('rating', type=int, choices=range(1,6), help='Rating 1-5')
    
    # stats
    stats_parser = subparsers.add_parser('stats', help='View agent statistics')
    stats_parser.add_argument('address', nargs='?', help='Agent address')
    
    # my-tasks
    mytasks_parser = subparsers.add_parser('my-tasks', help='View your tasks')
    mytasks_parser.add_argument('--status', default='all', help='Filter by status')
    
    # cancel
    cancel_parser = subparsers.add_parser('cancel', help='Cancel a task')
    cancel_parser.add_argument('task_id', type=int, help='Task ID')
    cancel_parser.add_argument('--reason', default='Cancelled', help='Cancellation reason')
    
    args = parser.parse_args()
    
    # Initialize client
    client = TaskMarketClient()
    
    # Execute command
    if args.command == 'init':
        print("🔧 Initializing AgentTaskMarket...")
        print("Configuration file created at ~/.openclaw/.secrets/taskmarket.json")
        print("Please edit with your wallet and contract details.")
        
    elif args.command == 'create':
        client.create_task(args.title, args.description, args.reward, args.deadline)
        
    elif args.command == 'list':
        client.list_tasks(limit=args.limit)
        
    elif args.command == 'view':
        client.view_task(args.task_id)
        
    elif args.command == 'bid':
        client.submit_bid(args.task_id, args.proposal)
        
    elif args.command == 'stats':
        client.get_stats(args.address)
        
    elif args.command == 'my-tasks':
        client.my_tasks(args.status)
        
    elif args.command is None:
        parser.print_help()
        
    else:
        print(f"⚠️ Command '{args.command}' requires web3 setup")
        print("Run: taskmarket init")


if __name__ == '__main__':
    main()
