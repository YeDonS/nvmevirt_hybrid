#!/bin/bash

echo "=== 内核和内存配置 ==="

# 备份原始GRUB配置
echo "1. 备份GRUB配置..."
sudo cp /etc/default/grub /etc/default/grub.backup

# 配置内存预留
echo "2. 配置内存预留..."
sudo tee -a /etc/default/grub > /dev/null << EOF
# 内存预留配置
GRUB_CMDLINE_LINUX="memmap=16G\\\$16G intremap=off"
EOF

# 更新GRUB
echo "3. 更新GRUB..."
sudo update-grub

# 检查NUMA配置
echo "4. 检查NUMA配置..."
numactl -H

# 检查系统信息
echo "5. 检查系统信息..."
echo "CPU核心数: $(nproc)"
echo "内存大小: $(free -h | grep Mem | awk '{print $2}')"
echo "当前内核: $(uname -r)"

echo "=== 需要重启系统以应用内存配置 ==="
echo "请运行: sudo reboot" 