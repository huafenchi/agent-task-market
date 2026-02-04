#!/bin/bash
# Script to generate ABI and deploy AgentTaskMarket

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  AgentTaskMarket Deployment Script${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${YELLOW}Installing Foundry...${NC}"
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
fi

# Build contracts
echo -e "${GREEN}[1/4] Building contracts...${NC}"
forge build

# Generate ABI
echo -e "${GREEN}[2/4] Generating ABI...${NC}"
if [ -f "out/AgentTaskMarket.sol/AgentTaskMarket.json" ]; then
    # Extract just the ABI
    cat out/AgentTaskMarket.sol/AgentTaskMarket.json | jq -r '.abi' > skills/taskmarket/abi.json
    echo -e "${GREEN}   ABI saved to skills/taskmarket/abi.json${NC}"
else
    echo -e "${YELLOW}   Warning: Contract build output not found${NC}"
fi

echo ""
echo -e "${GREEN}[3/4] Contract Information:${NC}"
echo "   Network: Base Sepolia Testnet"
echo "   USDC Address: 0x036CbD53842c5426634e7929541eC2318f3dCF7e"
echo ""
echo "To deploy, run:"
echo "   forge script script/Deploy.s.sol --rpc-url \$BASE_SEPOLIA_RPC --broadcast"
echo ""
echo -e "${GREEN}[4/4] Deployment Ready!${NC}"
echo ""
echo "Next steps:"
echo "1. Set BASE_SEPOLIA_RPC environment variable"
echo "2. Set PRIVATE_KEY environment variable (use a test account!)"
echo "3. Run: forge script script/Deploy.s.sol --rpc-url \$BASE_SEPOLIA_RPC --broadcast"
echo ""
echo "Or use the Deploy task in TaskMarketSkill for easier deployment."
