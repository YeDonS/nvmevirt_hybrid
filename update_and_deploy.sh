#!/bin/bash

echo "=== 更新和部署脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 3 ]; then
    echo -e "${RED}用法: $0 <commit-message> <remote-user> <remote-host> [remote-path]${NC}"
    echo "示例: $0 \"Update QLC latency parameters\" ubuntu 192.168.1.100"
    echo "示例: $0 \"Fix migration logic\" ubuntu 192.168.1.100 /home/ubuntu"
    exit 1
fi

COMMIT_MESSAGE=$1
REMOTE_USER=$2
REMOTE_HOST=$3
REMOTE_PATH=${4:-"/home/$REMOTE_USER"}

echo -e "${BLUE}更新配置:${NC}"
echo "提交信息: $COMMIT_MESSAGE"
echo "远程用户: $REMOTE_USER"
echo "远程主机: $REMOTE_HOST"
echo "远程路径: $REMOTE_PATH"

# 步骤1: 检查Git状态
echo -e "${BLUE}步骤1: 检查Git状态${NC}"
git status

# 步骤2: 添加更改
echo -e "${BLUE}步骤2: 添加更改${NC}"
git add .

# 步骤3: 提交更改
echo -e "${BLUE}步骤3: 提交更改${NC}"
git commit -m "$COMMIT_MESSAGE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 提交成功${NC}"
else
    echo -e "${RED}❌ 提交失败${NC}"
    exit 1
fi

# 步骤4: 推送到GitHub
echo -e "${BLUE}步骤4: 推送到GitHub${NC}"
git push origin main

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 推送到GitHub成功${NC}"
else
    echo -e "${RED}❌ 推送到GitHub失败${NC}"
    exit 1
fi

# 步骤5: 更新远程服务器
echo -e "${BLUE}步骤5: 更新远程服务器${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    cd ${REMOTE_PATH}/nvmevirt_DA
    
    # 检查Git状态
    echo "检查远程Git状态..."
    git status
    
    # 拉取最新更改
    echo "拉取最新更改..."
    git pull origin main
    
    if [ \$? -eq 0 ]; then
        echo "✅ 远程更新成功"
        
        # 重新编译（如果需要）
        echo "重新编译模块..."
        make clean
        make -j\$(nproc)
        
        # 重新加载模块（如果已加载）
        if lsmod | grep nvmev > /dev/null; then
            echo "重新加载模块..."
            sudo rmmod nvmev
            sudo insmod nvmev.ko memmap_start=16G memmap_size=13G cpus=0,1,2,3
        fi
        
        echo "✅ 远程部署完成"
    else
        echo "❌ 远程更新失败"
        exit 1
    fi
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 远程更新成功${NC}"
else
    echo -e "${RED}❌ 远程更新失败${NC}"
    exit 1
fi

echo -e "${GREEN}=== 更新和部署完成 ===${NC}"
echo -e "${YELLOW}本地和远程都已更新到最新版本！${NC}" 