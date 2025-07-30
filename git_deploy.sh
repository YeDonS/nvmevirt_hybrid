#!/bin/bash

echo "=== Git仓库部署脚本 ==="

# 配置变量
REMOTE_USER="your-username"
REMOTE_HOST="your-vm-ip"
REMOTE_PATH="/home/$REMOTE_USER"
PROJECT_NAME="nvmevirt_DA"
GIT_REPO="your-git-repo-url"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 3 ]; then
    echo -e "${RED}用法: $0 <remote-user> <remote-host> <git-repo-url> [remote-path]${NC}"
    echo "示例: $0 ubuntu 192.168.1.100 https://github.com/your-username/nvmevirt_DA.git"
    exit 1
fi

REMOTE_USER=$1
REMOTE_HOST=$2
GIT_REPO=$3
REMOTE_PATH=${4:-"/home/$REMOTE_USER"}

echo -e "${BLUE}远程配置:${NC}"
echo "用户: $REMOTE_USER"
echo "主机: $REMOTE_HOST"
echo "Git仓库: $GIT_REPO"
echo "路径: $REMOTE_PATH"

# 在远程服务器上克隆和部署
echo -e "${BLUE}在远程服务器上部署...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    cd ${REMOTE_PATH}
    
    # 备份现有项目（如果存在）
    if [ -d "${PROJECT_NAME}" ]; then
        echo "备份现有项目..."
        mv ${PROJECT_NAME} ${PROJECT_NAME}_backup_\$(date +%Y%m%d_%H%M%S)
    fi
    
    # 克隆Git仓库
    echo "克隆Git仓库..."
    git clone ${GIT_REPO} ${PROJECT_NAME}
    
    if [ \$? -eq 0 ]; then
        echo "✅ Git仓库克隆成功"
        
        # 设置权限
        echo "设置权限..."
        chmod +x ${PROJECT_NAME}/*.sh
        chmod +x ${PROJECT_NAME}/evaluation/*.sh
        chmod +x ${PROJECT_NAME}/evaluation/scripts/*.sh
        
        # 创建必要目录
        echo "创建目录..."
        mkdir -p ${PROJECT_NAME}/evaluation/results
        mkdir -p ${PROJECT_NAME}/evaluation/configs
        mkdir -p ${PROJECT_NAME}/evaluation/workloads
        
        # 检查项目文件
        echo "检查项目文件..."
        ls -la ${PROJECT_NAME}/
        
        echo "✅ Git部署完成"
    else
        echo "❌ Git仓库克隆失败"
        exit 1
    fi
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Git部署成功${NC}"
else
    echo -e "${RED}❌ Git部署失败${NC}"
    exit 1
fi

echo -e "${GREEN}=== Git部署完成 ===${NC}"
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. SSH到远程服务器: ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "2. 进入项目目录: cd ${REMOTE_PATH}/${PROJECT_NAME}"
echo "3. 运行部署脚本: ./complete_deployment.sh" 