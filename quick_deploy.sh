#!/bin/bash

echo "=== 快速远程部署脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}用法: $0 <remote-user> <remote-host> [method]${NC}"
    echo "方法选项:"
    echo "  scp    - SCP压缩包传输 (默认)"
    echo "  rsync  - Rsync增量同步"
    echo "  git    - Git仓库部署"
    echo ""
    echo "示例:"
    echo "  $0 ubuntu 192.168.1.100"
    echo "  $0 ubuntu 192.168.1.100 rsync"
    echo "  $0 ubuntu 192.168.1.100 git https://github.com/your-username/nvmevirt_DA.git"
    exit 1
fi

REMOTE_USER=$1
REMOTE_HOST=$2
METHOD=${3:-"scp"}

echo -e "${BLUE}部署配置:${NC}"
echo "用户: $REMOTE_USER"
echo "主机: $REMOTE_HOST"
echo "方法: $METHOD"

case $METHOD in
    "scp")
        echo -e "${BLUE}使用SCP传输...${NC}"
        ./remote_deploy.sh $REMOTE_USER $REMOTE_HOST
        ;;
    "rsync")
        echo -e "${BLUE}使用Rsync同步...${NC}"
        ./rsync_deploy.sh $REMOTE_USER $REMOTE_HOST
        ;;
    "git")
        if [ $# -lt 4 ]; then
            echo -e "${RED}Git方法需要提供仓库URL${NC}"
            echo "示例: $0 ubuntu 192.168.1.100 git https://github.com/your-username/nvmevirt_DA.git"
            exit 1
        fi
        GIT_REPO=$4
        echo -e "${BLUE}使用Git部署...${NC}"
        ./git_deploy.sh $REMOTE_USER $REMOTE_HOST $GIT_REPO
        ;;
    *)
        echo -e "${RED}未知方法: $METHOD${NC}"
        echo "支持的方法: scp, rsync, git"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 部署成功！${NC}"
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "1. SSH到远程服务器: ssh $REMOTE_USER@$REMOTE_HOST"
    echo "2. 进入项目目录: cd /home/$REMOTE_USER/nvmevirt_DA"
    echo "3. 运行部署脚本: ./complete_deployment.sh"
else
    echo -e "${RED}❌ 部署失败${NC}"
    exit 1
fi 