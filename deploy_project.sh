#!/bin/bash

echo "=== 混合SSD项目部署 ==="

# 设置项目目录
PROJECT_DIR="/home/$(whoami)/nvmevirt_DA"
echo "项目目录: $PROJECT_DIR"

# 创建项目目录
echo "1. 创建项目目录..."
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 下载项目（如果是从GitHub）
echo "2. 下载项目..."
if [ ! -d ".git" ]; then
    echo "请将项目文件复制到 $PROJECT_DIR"
    echo "或者运行: git clone <your-repo-url> $PROJECT_DIR"
fi

# 设置权限
echo "3. 设置文件权限..."
chmod +x *.sh
chmod +x evaluation/*.sh
chmod +x evaluation/scripts/*.sh

# 创建必要目录
echo "4. 创建必要目录..."
mkdir -p evaluation/results
mkdir -p evaluation/configs
mkdir -p evaluation/workloads

# 配置Makefile
echo "5. 配置Makefile..."
if [ -f "Makefile" ]; then
    # 启用混合SSD配置
    sed -i 's/#CONFIG_NVMEVIRT_HYBRID := y/CONFIG_NVMEVIRT_HYBRID := y/' Makefile
    echo "已启用混合SSD配置"
fi

# 检查项目文件
echo "6. 检查项目文件..."
ls -la
echo "核心文件:"
ls -la *.c *.h Makefile 2>/dev/null || echo "核心文件不存在"
echo "评估框架:"
ls -la evaluation/ 2>/dev/null || echo "评估框架不存在"

echo "=== 项目部署完成 ===" 