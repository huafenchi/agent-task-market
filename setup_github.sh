#!/bin/bash
# AgentTaskMarket GitHub Setup Script
# Usage: ./setup_github.sh

set -e

echo "======================================"
echo "  GitHub Repository Setup"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if GitHub token is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}GitHub Token 未设置${NC}"
    echo ""
    echo "获取方式:"
    echo "1. 访问 https://github.com/settings/tokens"
    echo "2. 点击 'Generate new token (classic)'"
    echo "3. 选择 scopes: repo, delete_repo"
    echo "4. 复制 token"
    echo ""
    read -p "请粘贴你的 GitHub Token: " GITHUB_TOKEN
    export GITHUB_TOKEN
    echo ""
fi

# Get repository name
REPO_NAME=${1:-"agent-task-market"}
echo -e "${BLUE}仓库名称: $REPO_NAME${NC}"
echo ""

# Get GitHub username
GITHUB_USER=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/user | jq -r '.login')

echo -e "${GREEN}GitHub 用户: $GITHUB_USER${NC}"
echo ""

# Create repository using API
echo "创建 GitHub 仓库..."

RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/user/repos \
    -d '{
      "name": "'"$REPO_NAME"'",
      "description": "Decentralized Task Marketplace for AI Agents using USDC",
      "private": false,
      "auto_init": false
    }')

# Check if repo was created or already exists
if echo "$RESPONSE" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 仓库创建成功!${NC}"
elif echo "$RESPONSE" | jq -e '.errors[].code' | grep -q "already_exists"; then
    echo -e "${YELLOW}⚠️ 仓库已存在，跳过创建${NC}"
else
    echo "❌ 创建失败:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

# Add remote and push
echo ""
echo "添加 Git 远程仓库..."

# Get the clone URL
CLONE_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"

# Check if remote exists
if git remote get-url origin > /dev/null 2>&1; then
    echo "远程仓库已存在"
else
    git remote add origin "$CLONE_URL"
fi

# Push to GitHub
echo ""
echo "推送到 GitHub..."

# Set branch to main
git branch -M main

# Push
git push -u origin main

echo ""
echo "======================================"
echo -e "${GREEN}✅ 完成!${NC}"
echo "======================================"
echo ""
echo "仓库链接: https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""
echo "下一步:"
echo "1. 访问仓库页面"
echo "2. 设置 Deploy Key (如果需要)"
echo "3. 部署合约需要设置 PRIVATE_KEY 环境变量"
