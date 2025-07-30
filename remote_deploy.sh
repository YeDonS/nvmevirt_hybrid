#!/bin/bash

echo "=== 远程虚拟机部署脚本 ==="

# 配置变量
REMOTE_USER="your-username"
REMOTE_HOST="your-vm-ip"
REMOTE_PATH="/home/$REMOTE_USER"
PROJECT_NAME="nvmevirt_DA"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}用法: $0 <remote-user> <remote-host> [remote-path]${NC}"
    echo "示例: $0 ubuntu 192.168.1.100"
    echo "示例: $0 ubuntu 192.168.1.100 /home/ubuntu"
    exit 1
fi

REMOTE_USER=$1
REMOTE_HOST=$2
REMOTE_PATH=${3:-"/home/$REMOTE_USER"}

echo -e "${BLUE}远程配置:${NC}"
echo "用户: $REMOTE_USER"
echo "主机: $REMOTE_HOST"
echo "路径: $REMOTE_PATH"

# 步骤1: 创建本地压缩包
echo -e "${BLUE}步骤1: 创建项目压缩包${NC}"
tar -czf ${PROJECT_NAME}.tar.gz \
    --exclude='.git' \
    --exclude='*.ko' \
    --exclude='*.o' \
    --exclude='*.mod.c' \
    --exclude='*.mod' \
    --exclude='*.cmd' \
    --exclude='.tmp_versions' \
    --exclude='evaluation/results/*' \
    --exclude='evaluation/configs/*' \
    --exclude='evaluation/workloads/*' \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 压缩包创建成功: ${PROJECT_NAME}.tar.gz${NC}"
else
    echo -e "${RED}❌ 压缩包创建失败${NC}"
    exit 1
fi

# 步骤2: 传输到远程服务器
echo -e "${BLUE}步骤2: 传输到远程服务器${NC}"
scp ${PROJECT_NAME}.tar.gz ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 文件传输成功${NC}"
else
    echo -e "${RED}❌ 文件传输失败${NC}"
    echo "请检查:"
    echo "1. SSH连接是否正常"
    echo "2. 远程路径是否存在"
    echo "3. 用户权限是否正确"
    exit 1
fi

# 步骤3: 在远程服务器上解压和部署
echo -e "${BLUE}步骤3: 远程部署${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    cd ${REMOTE_PATH}
    
    # 备份现有项目（如果存在）
    if [ -d "${PROJECT_NAME}" ]; then
        echo "备份现有项目..."
        mv ${PROJECT_NAME} ${PROJECT_NAME}_backup_\$(date +%Y%m%d_%H%M%S)
    fi
    
    # 解压项目
    echo "解压项目..."
    tar -xzf ${PROJECT_NAME}.tar.gz
    
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
    
    echo "✅ 远程部署完成"
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 远程部署成功${NC}"
else
    echo -e "${RED}❌ 远程部署失败${NC}"
    exit 1
fi

# 步骤4: 清理本地压缩包
echo -e "${BLUE}步骤4: 清理本地文件${NC}"
rm -f ${PROJECT_NAME}.tar.gz
echo -e "${GREEN}✅ 清理完成${NC}"

echo -e "${GREEN}=== 远程部署完成 ===${NC}"
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. SSH到远程服务器: ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "2. 进入项目目录: cd ${REMOTE_PATH}/${PROJECT_NAME}"
echo "3. 运行部署脚本: ./complete_deployment.sh" 