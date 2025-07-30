#!/bin/bash

echo "=== 混合SSD项目完整部署 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}请不要以root用户运行此脚本${NC}"
    exit 1
fi

# 步骤1: 环境准备
echo -e "${BLUE}步骤1: 环境准备${NC}"
./vm_setup.sh

# 步骤2: 内核配置
echo -e "${BLUE}步骤2: 内核配置${NC}"
./kernel_setup.sh

echo -e "${YELLOW}请重启系统以应用内存配置${NC}"
echo -e "${YELLOW}重启后请运行: ./complete_deployment.sh continue${NC}"
read -p "是否现在重启? (y/n): " choice
if [ "$choice" = "y" ]; then
    sudo reboot
    exit 0
fi

# 检查是否继续部署
if [ "$1" != "continue" ]; then
    echo -e "${YELLOW}部署暂停，重启后运行: ./complete_deployment.sh continue${NC}"
    exit 0
fi

# 步骤3: 项目部署
echo -e "${BLUE}步骤3: 项目部署${NC}"
./deploy_project.sh

# 步骤4: 编译和验证
echo -e "${BLUE}步骤4: 编译和验证${NC}"
./build_and_verify.sh

# 步骤5: 调试和测试
echo -e "${BLUE}步骤5: 调试和测试${NC}"
./debug_and_test.sh

echo -e "${GREEN}=== 部署完成 ===${NC}"
echo -e "${GREEN}项目已成功部署到虚拟机${NC}"
echo -e "${GREEN}可以使用 vim_debug_guide.md 进行调试${NC}" 