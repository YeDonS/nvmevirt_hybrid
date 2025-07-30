#!/bin/bash

echo "=== Rsync同步部署脚本 ==="

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

# 检查rsync是否安装
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}❌ rsync未安装，请先安装: brew install rsync (macOS) 或 apt install rsync (Linux)${NC}"
    exit 1
fi

# 创建排除文件
echo -e "${BLUE}创建排除文件...${NC}"
cat > .rsync-exclude << EOF
.git/
*.ko
*.o
*.mod.c
*.mod
*.cmd
.tmp_versions/
evaluation/results/
evaluation/configs/
evaluation/workloads/
*.tar.gz
*.log
EOF

# 同步文件
echo -e "${BLUE}同步文件到远程服务器...${NC}"
rsync -avz --progress \
    --exclude-from=.rsync-exclude \
    --delete \
    ./ ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${PROJECT_NAME}/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 文件同步成功${NC}"
else
    echo -e "${RED}❌ 文件同步失败${NC}"
    rm -f .rsync-exclude
    exit 1
fi

# 在远程服务器上设置权限
echo -e "${BLUE}设置远程文件权限...${NC}"
ssh ${REMOTE_USER}@${REMOTE_HOST} << EOF
    cd ${REMOTE_PATH}/${PROJECT_NAME}
    
    # 设置权限
    chmod +x *.sh
    chmod +x evaluation/*.sh
    chmod +x evaluation/scripts/*.sh
    
    # 创建必要目录
    mkdir -p evaluation/results
    mkdir -p evaluation/configs
    mkdir -p evaluation/workloads
    
    echo "✅ 权限设置完成"
EOF

# 清理排除文件
rm -f .rsync-exclude

echo -e "${GREEN}=== Rsync同步完成 ===${NC}"
echo -e "${YELLOW}下一步操作:${NC}"
echo "1. SSH到远程服务器: ssh ${REMOTE_USER}@${REMOTE_HOST}"
echo "2. 进入项目目录: cd ${REMOTE_PATH}/${PROJECT_NAME}"
echo "3. 运行部署脚本: ./complete_deployment.sh" 