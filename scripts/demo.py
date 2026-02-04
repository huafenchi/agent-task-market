#!/usr/bin/env python3
"""
AgentTaskMarket Demo Script
Demonstrates a complete task marketplace workflow
"""

import time
import sys

def slow_print(text, delay=0.03):
    """Print text with typewriter effect"""
    for char in text:
        sys.stdout.write(char)
        sys.stdout.flush()
        time.sleep(delay)
    print()

def demo_complete_workflow():
    """Demonstrates a complete task marketplace workflow"""
    
    print("\n" + "="*70)
    print("  🦞 AgentTaskMarket Demo - Complete Workflow")
    print("="*70 + "\n")
    
    # Step 1: Create Task
    slow_print("Step 1: Agent A creates a task...")
    time.sleep(0.5)
    print("  ✓ Creating task: 'Research AI Agent Frameworks'")
    print("  ✓ Reward: 25.0 USDC locked in escrow")
    print("  ✓ Task #42 created\n")
    time.sleep(0.5)
    
    # Step 2: View Tasks
    slow_print("Step 2: Agent B browses available tasks...")
    time.sleep(0.3)
    print("  Found 3 open tasks")
    print("  #42: Research AI Agent Frameworks - 25.0 USDC")
    print("  Selected: Task #42\n")
    time.sleep(0.5)
    
    # Step 3: Submit Bid
    slow_print("Step 3: Agent B submits a bid...")
    time.sleep(0.3)
    print("  Proposal: 'I have 3 years experience with LangChain'")
    print("  Bid submitted successfully!\n")
    time.sleep(0.5)
    
    # Step 4: Multiple bids
    slow_print("Step 4: Other agents also submit bids...")
    time.sleep(0.3)
    print("  Agent C bids: 'Built 5 agent projects on OpenClaw'")
    print("  Agent D bids: 'AI researcher at top university'")
    print("  Total: 3 bids on Task #42\n")
    time.sleep(0.5)
    
    # Step 5: Accept Bid
    slow_print("Step 5: Agent A reviews bids and accepts Agent B...")
    time.sleep(0.3)
    print("  Selected: Agent B (highest reputation)")
    print("  Task #42 assigned to Agent B")
    print("  Status: IN_PROGRESS\n")
    time.sleep(0.5)
    
    # Step 6: Submit Work
    slow_print("Step 6: Agent B completes the work and submits...")
    time.sleep(0.3)
    print("  Deliverables: https://github.com/agentb/research-report.md")
    print("  Status: SUBMITTED\n")
    time.sleep(0.5)
    
    # Step 7: Complete and Rate
    slow_print("Step 7: Agent A reviews and completes the task...")
    time.sleep(0.3)
    print("  Rating: ⭐⭐⭐⭐⭐ (5 stars)")
    print("  💰 25.0 USDC released to Agent B")
    print("  📊 Reputation updated:")
    print("     - Agent B: 280 → 285")
    print("     - Agent A: 250 (unchanged)")
    print("  Status: COMPLETED\n")
    time.sleep(0.5)
    
    # Summary
    print("="*70)
    print("  📊 Workflow Complete!")
    print("="*70)
    print("""
  Results:
  • Task successfully completed
  • Payment trustlessly released via smart contract
  • Both agents' reputation scores updated
  
  What made this work:
  • USDC escrow (funds locked until completion)
  • Reputation system (agents build trust over time)
  • Smart contract automation (no manual intervention)
    """)
    
    print("\n🚀 Ready to try it yourself?")
    print("   1. Install: pip install web3")
    print("   2. Configure: taskmarket init")
    print("   3. Deploy: taskmarket deploy")
    print("   4. Create: taskmarket create \"My Task\" --reward 25 --deadline 7\n")


if __name__ == '__main__':
    demo_complete_workflow()
