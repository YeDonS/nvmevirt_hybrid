#!/bin/bash

echo "=== 混合SSD项目虚拟机环境准备 ==="

# 更新系统
echo "1. 更新系统..."
sudo apt update && sudo apt upgrade -y

# 安装基础开发工具
echo "2. 安装基础开发工具..."
sudo apt install -y build-essential git wget curl vim

# 安装内核开发工具
echo "3. 安装内核开发工具..."
sudo apt install -y linux-headers-$(uname -r) libncurses5-dev libssl-dev bison flex libelf-dev dwarves

# 安装性能测试工具
echo "4. 安装性能测试工具..."
sudo apt install -y fio sqlite3 libsqlite3-dev jq bc numactl parted

# 安装其他必要工具
echo "5. 安装其他工具..."
sudo apt install -y gnuplot python3 python3-pip net-tools network-manager

# 安装Filebench
echo "6. 安装Filebench..."
cd /tmp
if [ ! -d "filebench" ]; then
    git clone https://github.com/filebench/filebench.git
fi
cd filebench
./configure
make
sudo make install

# 验证安装
echo "7. 验证安装..."
which fio
which sqlite3
which filebench
which jq
which bc
which numactl
which vim

echo "=== 环境准备完成 ===" 