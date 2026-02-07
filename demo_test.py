#!/usr/bin/env python3
"""
AgentTaskMarket Demo Script
Tests the deployed contract on Base Sepolia
"""

from web3 import Web3
import json
import os

# Configuration
RPC_URL = "https://sepolia.base.org"
CONTRACT_ADDRESS = "0x7e5c0b4168C389672d9C9A158d6EF4eeEf8ea377"
USDC_ADDRESS = "0x036CbD53842c5426634e7929541eC2318f3dCF7e"
PRIVATE_KEY = os.getenv("PRIVATE_KEY", "0x05973d2570d872f0da3939ba19279d7645c74505aa8fd33f19e9e306cf0655cc")

# Load ABI from compiled file
with open('/Users/jj/.openclaw/workspace/usdc-hackathon/out/AgentTaskMarket.sol/AgentTaskMarket.json', 'r') as f:
    contract_data = json.load(f)
    ABI = contract_data['abi']

def main():
    print("=" * 60)
    print("  AgentTaskMarket Demo")
    print("=" * 60)
    print()
    
    # Connect to network
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print("❌ Failed to connect to Base Sepolia")
        return
    
    print(f"✅ Connected to Base Sepolia")
    print(f"   Block: {w3.eth.block_number}")
    print()
    
    # Load account
    account = w3.eth.account.from_key(PRIVATE_KEY)
    print(f"📁 Account: {account.address}")
    print()
    
    # Load contract
    contract = w3.eth.contract(address=CONTRACT_ADDRESS, abi=ABI)
    
    # Check USDC balance
    usdc_abi = [
        {
            "constant": True,
            "inputs": [{"name": "_owner", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"name": "balance", "type": "uint256"}],
            "type": "function"
        }
    ]
    usdc_contract = w3.eth.contract(address=USDC_ADDRESS, abi=usdc_abi)
    usdc_balance = usdc_contract.functions.balanceOf(account.address).call()
    print(f"💰 USDC Balance: {usdc_balance / 1e6:.2f} USDC")
    print()
    
    # Check current task count
    task_count = contract.functions.getTaskCount().call()
    print(f"📋 Current Tasks: {task_count}")
    print()
    
    # Demo: Create a task
    print("🎯 Creating a demo task...")
    print("   Title: AI Agent Task Demo")
    print("   Reward: 1 USDC")
    print()
    
    # Approve USDC for contract
    print("1️⃣  Approving USDC for contract...")
    approve_abi = [
        {
            "name": "approve",
            "inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}]
        }
    ]
    usdc_approve = w3.eth.contract(address=USDC_ADDRESS, abi=approve_abi)
    tx = usdc_approve.functions.approve(CONTRACT_ADDRESS, 1_000_000).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 100000,
        'gasPrice': w3.eth.gas_price
    })
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
    print(f"   ✅ Approval sent: {tx_hash.hex()}")
    print()
    
    # Create task
    print("2️⃣  Creating task...")
    tx = contract.functions.createTask(
        "AI Agent Task Demo",
        "This is a demo task for the AgentTaskMarket",
        1_000_000,  # 1 USDC
        7  # 7 days deadline
    ).build_transaction({
        'from': account.address,
        'nonce': w3.eth.get_transaction_count(account.address),
        'gas': 200000,
        'gasPrice': w3.eth.gas_price
    })
    signed = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
    print(f"   ✅ Task created: {tx_hash.hex()}")
    print()
    
    # Get task info
    task = contract.functions.getTask(0).call()
    print("📋 Task Details:")
    print(f"   ID: {task[0]}")
    print(f"   Creator: {task[1]}")
    print(f"   Title: {task[2]}")
    print(f"   Reward: {task[4] / 1e6:.2f} USDC")
    print(f"   Status: {['Open', 'InProgress', 'Completed', 'Cancelled'][task[7]]}")
    print()
    
    print("=" * 60)
    print("✅ Demo completed successfully!")
    print("=" * 60)
    print()
    print("📝 Next Steps:")
    print("   1. View on Basescan: https://sepolia.basescan.org/address/" + CONTRACT_ADDRESS)
    print("   2. Submit a bid (from another address)")
    print("   3. Accept the bid and complete the task")
    print("   4. Record a demo video!")

if __name__ == "__main__":
    main()
