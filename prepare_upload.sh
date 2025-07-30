#!/bin/bash

echo "=== 准备GitHub上传 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}检查项目文件...${NC}"

# 检查核心文件
echo -e "${YELLOW}核心文件:${NC}"
ls -la *.c *.h Makefile 2>/dev/null || echo "核心文件不存在"

# 检查评估框架
echo -e "${YELLOW}评估框架:${NC}"
ls -la evaluation/ 2>/dev/null || echo "评估框架不存在"

# 检查验证脚本
echo -e "${YELLOW}验证脚本:${NC}"
ls -la verify_*.sh 2>/dev/null || echo "验证脚本不存在"

# 检查部署脚本
echo -e "${YELLOW}部署脚本:${NC}"
ls -la *_deploy.sh *_setup.sh 2>/dev/null || echo "部署脚本不存在"

# 检查文档
echo -e "${YELLOW}文档文件:${NC}"
ls -la *.md 2>/dev/null || echo "文档文件不存在"

echo ""
echo -e "${GREEN}=== 上传准备完成 ===${NC}"
echo ""
echo -e "${BLUE}下一步操作:${NC}"
echo "1. 访问 https://github.com/new"
echo "2. 创建仓库: nvmevirt_DA_hybrid"
echo "3. 上传上述文件到GitHub"
echo ""
echo -e "${YELLOW}或者使用自动脚本:${NC}"
echo "./github_setup.sh your-username nvmevirt_DA_hybrid" 