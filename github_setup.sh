#!/bin/bash

echo "=== GitHub仓库设置脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查Git是否安装
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git未安装，请先安装Git${NC}"
    exit 1
fi

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}用法: $0 <github-username> [repo-name]${NC}"
    echo "示例: $0 your-username"
    echo "示例: $0 your-username nvmevirt_DA_hybrid"
    exit 1
fi

GITHUB_USERNAME=$1
REPO_NAME=${2:-"nvmevirt_DA_hybrid"}

echo -e "${BLUE}GitHub配置:${NC}"
echo "用户名: $GITHUB_USERNAME"
echo "仓库名: $REPO_NAME"

# 步骤1: 初始化Git仓库
echo -e "${BLUE}步骤1: 初始化Git仓库${NC}"
if [ ! -d ".git" ]; then
    git init
    echo -e "${GREEN}✅ Git仓库初始化成功${NC}"
else
    echo -e "${YELLOW}⚠️  Git仓库已存在${NC}"
fi

# 步骤2: 创建.gitignore文件
echo -e "${BLUE}步骤2: 创建.gitignore文件${NC}"
cat > .gitignore << EOF
# 编译文件
*.ko
*.o
*.mod.c
*.mod
*.cmd
.tmp_versions/
*.tar.gz

# 测试结果
evaluation/results/
evaluation/configs/
evaluation/workloads/

# 日志文件
*.log

# 系统文件
.DS_Store
Thumbs.db

# IDE文件
.vscode/
.idea/
*.swp
*.swo

# 临时文件
*~
*.tmp
EOF

echo -e "${GREEN}✅ .gitignore文件创建成功${NC}"

# 步骤3: 添加文件到Git
echo -e "${BLUE}步骤3: 添加文件到Git${NC}"
git add .
git status

# 步骤4: 创建初始提交
echo -e "${BLUE}步骤4: 创建初始提交${NC}"
git commit -m "Initial commit: Hybrid SSD implementation with QLC four regions"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 初始提交成功${NC}"
else
    echo -e "${RED}❌ 提交失败${NC}"
    exit 1
fi

# 步骤5: 创建GitHub仓库
echo -e "${BLUE}步骤5: 创建GitHub仓库${NC}"
echo -e "${YELLOW}请在GitHub上手动创建仓库: https://github.com/new${NC}"
echo -e "${YELLOW}仓库名: $REPO_NAME${NC}"
echo -e "${YELLOW}描述: Hybrid SSD implementation with QLC four regions${NC}"
echo -e "${YELLOW}选择: Public 或 Private${NC}"
echo ""
read -p "按回车键继续..."

# 步骤6: 添加远程仓库
echo -e "${BLUE}步骤6: 添加远程仓库${NC}"
git remote add origin https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git

# 步骤7: 推送到GitHub
echo -e "${BLUE}步骤7: 推送到GitHub${NC}"
git branch -M main
git push -u origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 推送到GitHub成功${NC}"
    echo -e "${GREEN}仓库地址: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
else
    echo -e "${RED}❌ 推送失败${NC}"
    echo "请检查:"
    echo "1. GitHub仓库是否已创建"
    echo "2. 网络连接是否正常"
    echo "3. GitHub认证是否正确"
    exit 1
fi

echo -e "${GREEN}=== GitHub仓库设置完成 ===${NC}"
echo -e "${YELLOW}现在可以使用Git进行版本控制和远程部署了！${NC}" 