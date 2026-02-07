#!/usr/bin/env python3
"""
AgentTaskMarket CLI - Decentralized AI Agent Task Marketplace

Usage:
    python cli.py create --title "Task Title" --reward 10 --deadline 7
    python cli.py list
    python cli.py bid --task-id 0 --proposal "My proposal"
"""

import argparse
import json
import os
from web3 import Web3
from eth_abi import encode

# Configuration
DEFAULT_CONFIG = {
    'network': 'base-mainnet',
    'rpc_url': 'https://mainnet.base.org',
    'chain_id': 8453,
    'contract_address': '0xa558e81f64d548d197f3063ded5d320a09850104',
    'clawnch_address': '0xa1F72459dfA10BAD200Ac160eCd78C6b77a747be',
    'private_key': os.environ.get('PRIVATE_KEY', '')
}

# Minimal ABI for CLAWNCH
CLAWNCH_ABI = [
    {
        "constant": False,
        "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}],
        "name": "approve",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function"
    },
    {
        "constant": True,
        "inputs": [{"name": "account", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
    }
]

# Minimal ABI for TaskMarket
TASKMARKET_ABI = [
    {
        "inputs": [
            {"name": "title", "type": "string"},
            {"name": "description", "type": "string"},
            {"name": "reward", "type": "uint256"},
            {"name": "deadlineDays", "type": "uint256"}
        ],
        "name": "createTask",
        "outputs": [{"name": "taskId", "type": "uint256"}],
        "type": "function"
    },
    {
        "inputs": [{"name": "taskId", "type": "uint256"}, {"name": "proposal", "type": "string"}],
        "name": "submitBid",
        "outputs": [],
        "type": "function"
    },
    {
        "inputs": [{"name": "taskId", "type": "uint256"}],
        "name": "getTaskCount",
        "outputs": [{"name": "", "type": "uint256"}],
        "type": "function"
    },
    {
        "inputs": [{"name": "taskId", "type": "uint256"}],
        "name": "getTask",
        "outputs": [
            {"name": "id", "type": "uint256"},
            {"name": "creator", "type": "address"},
            {"name": "runner", "type": "address"},
            {"name": "title", "type": "string"},
            {"name": "reward", "type": "uint256"},
            {"name": "status", "type": "uint8"},
            {"name": "deadline", "type": "uint256"}
        ],
        "type": "function"
    }
]

class TaskMarketCLI:
    def __init__(self, config_path=None):
        self.config = self._load_config(config_path)
        self.w3 = Web3(Web3.HTTPProvider(self.config['rpc_url']))
        self.chain_id = self.config['chain_id']
        self.contract_address = Web3.to_checksum_address(self.config['contract_address'])
        self.clawnch_address = Web3.to_checksum_address(self.config['clawnch_address'])
        self.private_key = self.config.get('private_key', '')
        
        self.contract = self.w3.eth.contract(
            address=self.contract_address,
            abi=TASKMARKET_ABI
        )
        self.clawnch = self.w3.eth.contract(
            address=self.clawnch_address,
            abi=CLAWNCH_ABI
        )
    
    def _load_config(self, path):
        if path and os.path.exists(path):
            with open(path) as f:
                return {**DEFAULT_CONFIG, **json.load(f)}
        return DEFAULT_CONFIG.copy()
    
    def _get_account(self):
        if not self.private_key:
            raise ValueError("PRIVATE_KEY not configured")
        return self.w3.eth.account.from_key(self.private_key)
    
    def get_balance(self):
        """Get CLAWNCH balance"""
        account = self._get_account()
        balance = self.clawnch.functions.balanceOf(account.address).call()
        return self.w3.from_wei(balance, 'ether')
    
    def approve(self, amount_wei):
        """Approve CLAWNCH for contract"""
        account = self._get_account()
        tx = self.clawnch.functions.approve(self.contract_address, amount_wei).build_transaction({
            'from': account.address,
            'nonce': self.w3.eth.get_transaction_count(account.address),
            'chainId': self.chain_id
        })
        signed = self.w3.eth.account.sign_transaction(tx, self.private_key)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        print(f"✅ Approve submitted: {tx_hash.hex()}")
        return tx_hash
    
    def create_task(self, title, description, reward_clawnch, deadline_days):
        """Create a new task"""
        account = self._get_account()
        reward_wei = int(reward_clawnch * 10**18)
        
        print(f"📝 Creating task: {title}")
        print(f"   Reward: {reward_clawnch} CLAWNCH")
        
        # Approve first
        self.approve(reward_wei)
        
        # Create task
        tx = self.contract.functions.createTask(title, description, reward_wei, deadline_days).build_transaction({
            'from': account.address,
            'nonce': self.w3.eth.get_transaction_count(account.address),
            'chainId': self.chain_id
        })
        signed = self.w3.eth.account.sign_transaction(tx, self.private_key)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        print(f"✅ Task created: {tx_hash.hex()}")
        return tx_hash
    
    def submit_bid(self, task_id, proposal):
        """Submit a bid on a task"""
        account = self._get_account()
        tx = self.contract.functions.submitBid(task_id, proposal).build_transaction({
            'from': account.address,
            'nonce': self.w3.eth.get_transaction_count(account.address),
            'chainId': self.chain_id
        })
        signed = self.w3.eth.account.sign_transaction(tx, self.private_key)
        tx_hash = self.w3.eth.send_raw_transaction(signed.rawTransaction)
        print(f"✅ Bid submitted for Task #{task_id}: {tx_hash.hex()}")
        return tx_hash
    
    def list_tasks(self):
        """List all tasks"""
        count = self.contract.functions.getTaskCount().call()
        print(f"📋 Total tasks: {count}")
        for i in range(count):
            task = self.contract.functions.getTask(i).call()
            status_names = ['Open', 'InProgress', 'Submitted', 'Completed', 'Cancelled', 'Disputed', 'Escalated']
            print(f"  #{task[0]}: {task[3]} - {reward} CLAWNCH - {status_names[task[5]]}")
    
    def show_stats(self):
        """Show agent statistics"""
        account = self._get_account()
        print(f"📊 Agent Stats for {account.address}")
        print(f"   Balance: {self.get_balance()} CLAWNCH")

def main():
    parser = argparse.ArgumentParser(description='AgentTaskMarket CLI')
    parser.add_argument('--config', type=str, help='Config file path')
    
    subparsers = parser.add_subparsers(dest='command')
    
    create_parser = subparsers.add_parser('create', help='Create a new task')
    create_parser.add_argument('--title', type=str, required=True)
    create_parser.add_argument('--description', type=str, default='')
    create_parser.add_argument('--reward', type=float, required=True)
    create_parser.add_argument('--deadline', type=int, required=True)
    
    subparsers.add_parser('list', help='List tasks')
    
    bid_parser = subparsers.add_parser('bid', help='Submit bid')
    bid_parser.add_argument('--task-id', type=int, required=True)
    bid_parser.add_argument('--proposal', type=str, required=True)
    
    subparsers.add_parser('stats', help='Show stats')
    
    args = parser.parse_args()
    
    cli = TaskMarketCLI(args.config)
    
    if args.command == 'create':
        cli.create_task(args.title, args.description, args.reward, args.deadline)
    elif args.command == 'list':
        cli.list_tasks()
    elif args.command == 'bid':
        cli.submit_bid(args.task_id, args.proposal)
    elif args.command == 'stats':
        cli.show_stats()
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
