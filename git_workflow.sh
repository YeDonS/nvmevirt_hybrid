#!/bin/bash

echo "=== Git工作流脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 1 ]; then
    echo -e "${RED}用法: $0 <command> [options]${NC}"
    echo ""
    echo "命令:"
    echo "  setup <username> [repo-name]     - 设置GitHub仓库"
    echo "  status                           - 检查Git状态"
    echo "  commit <message>                 - 提交更改"
    echo "  push                             - 推送到GitHub"
    echo "  pull                             - 从GitHub拉取"
    echo "  deploy <user> <host>            - 部署到远程服务器"
    echo "  update <message> <user> <host>  - 更新并部署"
    echo ""
    echo "示例:"
    echo "  $0 setup your-username"
    echo "  $0 commit \"Update QLC parameters\""
    echo "  $0 deploy ubuntu 192.168.1.100"
    echo "  $0 update \"Fix migration logic\" ubuntu 192.168.1.100"
    exit 1
fi

COMMAND=$1

case $COMMAND in
    "setup")
        if [ $# -lt 2 ]; then
            echo -e "${RED}用法: $0 setup <username> [repo-name]${NC}"
            exit 1
        fi
        USERNAME=$2
        REPO_NAME=${3:-"nvmevirt_DA_hybrid"}
        echo -e "${BLUE}设置GitHub仓库...${NC}"
        ./github_setup.sh $USERNAME $REPO_NAME
        ;;
        
    "status")
        echo -e "${BLUE}检查Git状态...${NC}"
        git status
        ;;
        
    "commit")
        if [ $# -lt 2 ]; then
            echo -e "${RED}用法: $0 commit <message>${NC}"
            exit 1
        fi
        MESSAGE=$2
        echo -e "${BLUE}提交更改...${NC}"
        git add .
        git commit -m "$MESSAGE"
        ;;
        
    "push")
        echo -e "${BLUE}推送到GitHub...${NC}"
        git push origin main
        ;;
        
    "pull")
        echo -e "${BLUE}从GitHub拉取...${NC}"
        git pull origin main
        ;;
        
    "deploy")
        if [ $# -lt 3 ]; then
            echo -e "${RED}用法: $0 deploy <user> <host>${NC}"
            exit 1
        fi
        USER=$2
        HOST=$3
        echo -e "${BLUE}部署到远程服务器...${NC}"
        ./git_deploy.sh $USER $HOST https://github.com/$(git config user.name)/nvmevirt_DA_hybrid.git
        ;;
        
    "update")
        if [ $# -lt 4 ]; then
            echo -e "${RED}用法: $0 update <message> <user> <host>${NC}"
            exit 1
        fi
        MESSAGE=$2
        USER=$3
        HOST=$4
        echo -e "${BLUE}更新并部署...${NC}"
        ./update_and_deploy.sh "$MESSAGE" $USER $HOST
        ;;
        
    *)
        echo -e "${RED}未知命令: $COMMAND${NC}"
        echo "可用命令: setup, status, commit, push, pull, deploy, update"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 操作成功完成${NC}"
else
    echo -e "${RED}❌ 操作失败${NC}"
    exit 1
fi 