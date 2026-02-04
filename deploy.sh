#!/bin/bash
# AgentTaskMarket Deployment Script
# Uses free public RPC and environment variable for private key

set -e

echo "======================================"
echo "  AgentTaskMarket Deployment"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Network Configuration (Base Sepolia Testnet)
RPC_URL="https://sepolia.base.org"
CHAIN_ID=84532
USDC_ADDRESS="0x036CbD53842c5426634e7929541eC2318f3dCF7e"
EXPLORER_URL="https://sepolia.basescan.org"

echo -e "${BLUE}网络: Base Sepolia Testnet${NC}"
echo "RPC: $RPC_URL"
echo "USDC: $USDC_ADDRESS"
echo ""

# Check for private key
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ PRIVATE_KEY 环境变量未设置${NC}"
    echo ""
    echo "设置方式:"
    echo '  export PRIVATE_KEY="0xYourPrivateKeyHere"'
    echo ""
    echo "注意:"
    echo "  - 使用测试钱包，不要使用主网钱包"
    echo "  - 确保钱包有少量 ETH 支付 gas"
    echo ""
    read -p "请粘贴你的私钥 (0x...): " PRIVATE_KEY
    export PRIVATE_KEY
fi

# Show deployer address
echo -e "${GREEN}部署者地址:${NC}"
DEPLOYER=$(cast wallet address "$PRIVATE_KEY")
echo "$DEPLOYER"
echo ""

# Check balance
echo "检查余额..."
ETH_BALANCE=$(cast balance "$DEPLOYER" --rpc-url "$RPC_URL")
USDC_BALANCE=$(cast call "$USDC_ADDRESS" "balanceOf(address)(uint256)" "$DEPLOYER" --rpc-url "$RPC_URL" | cast to-decimal --decimals 6)

echo "ETH: $(echo "$ETH_BALANCE" | cast to-decimal --decimals 18) ETH"
echo "USDC: $USDC_BALANCE USDC"
echo ""

if [ "$(echo "$ETH_BALANCE" | cast to-unit ether)" = "0" ]; then
    echo -e "${YELLOW}⚠️ ETH 余额为 0${NC}"
    echo "请从 faucet 获取测试 ETH:"
    echo "  https://www.alchemy.com/faucets/base-sepolia"
    exit 1
fi

if [ "$USDC_BALANCE" = "0" ]; then
    echo -e "${YELLOW}⚠️ USDC 余额为 0${NC}"
    echo "请获取测试 USDC:"
    echo "  https://www.circle.com/en/testnets"
fi

echo ""
echo "开始部署..."
echo ""

# Build first
echo -e "${GREEN}[1/3] 编译合约...${NC}"
forge build

# Generate ABI
echo -e "${GREEN}[2/3] 生成 ABI...${NC}"
if [ -f "out/AgentTaskMarket.sol/AgentTaskMarket.json" ]; then
    cat out/AgentTaskMarket.sol/AgentTaskMarket.json | jq -r '.abi' > skills/taskmarket/abi.json
    echo "   ABI 已保存到 skills/taskmarket/abi.json"
fi

# Deploy
echo -e "${GREEN}[3/3] 部署合约...${NC}"
echo ""

# Create deployment command
DEPLOY_CMD="forge script script/Deploy.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key placeholder"

echo "执行: forge script script/Deploy.s.sol --broadcast --verify"
echo ""

# Run deployment
eval "$DEPLOY_CMD"

echo ""
echo "======================================"
echo -e "${GREEN}✅ 部署完成!${NC}"
echo "======================================"
echo ""
echo "合约地址将显示在输出中。"
echo ""
echo "验证:"
echo "  1. 访问 $EXPLORER_URL"
echo "  2. 搜索合约地址"
echo ""
echo "下一步:"
echo "  1. 更新 config 中的 contract_address"
echo "  2. 测试 CLI: taskmarket create"
