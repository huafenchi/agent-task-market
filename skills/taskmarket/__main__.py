#!/usr/bin/env python3
"""
AgentTaskMarket CLI - Decentralized AI Agent Task Marketplace

Usage:
    python -m skills.taskmarket create --title "Task Title" --reward 10 --deadline 7
    python -m skills.taskmarket list
    python -m skills.taskmarket bid --task-id 0 --proposal "My proposal"
"""

import argparse
import json
import os
from web3 import Web3

from .cli import TaskMarketCLI

def main():
    parser = argparse.ArgumentParser(description='AgentTaskMarket CLI')
    parser.add_argument('--config', type=str, help='Config file path')
    parser.add_argument('--network', type=str, default='base-mainnet', help='Network')
    
    subparsers = parser.add_subparsers(dest='command')
    
    # Create command
    create_parser = subparsers.add_parser('create', help='Create a new task')
    create_parser.add_argument('--title', type=str, required=True, help='Task title')
    create_parser.add_argument('--description', type=str, help='Task description')
    create_parser.add_argument('--reward', type=float, required=True, help='CLAWNCH reward amount')
    create_parser.add_argument('--deadline', type=int, required=True, help='Deadline in days')
    
    # List command
    subparsers.add_parser('list', help='List available tasks')
    
    # Bid command
    bid_parser = subparsers.add_parser('bid', help='Submit a bid')
    bid_parser.add_argument('--task-id', type=int, required=True)
    bid_parser.add_argument('--proposal', type=str, required=True)
    
    # Stats command
    subparsers.add_parser('stats', help='Show agent statistics')
    
    args = parser.parse_args()
    
    if args.command == 'create':
        cli = TaskMarketCLI(args.config)
        cli.create_task(args.title, args.description or '', args.reward, args.deadline)
    elif args.command == 'list':
        cli = TaskMarketCLI(args.config)
        cli.list_tasks()
    elif args.command == 'bid':
        cli = TaskMarketCLI(args.config)
        cli.submit_bid(args.task_id, args.proposal)
    elif args.command == 'stats':
        cli = TaskMarketCLI(args.config)
        cli.show_stats()
    else:
        parser.print_help()

if __name__ == '__main__':
    main()
