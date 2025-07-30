#!/bin/bash

echo "=== 调试和测试混合SSD ==="

# 加载模块
echo "1. 加载混合SSD模块..."
sudo insmod nvmev.ko memmap_start=16G memmap_size=13G cpus=0,1,2,3

# 检查设备
echo "2. 检查设备..."
lsblk
dmesg | grep nvme | tail -10

# 检查模块状态
echo "3. 检查模块状态..."
lsmod | grep nvmev

# 运行设备设置测试
echo "4. 运行设备设置测试..."
cd evaluation
./scripts/setdevice.sh status

# 运行单个测试
echo "5. 运行单个测试..."
./scripts/hypothetical_workloads.sh contiguous
./scripts/sqlite_workload.sh contiguous
./scripts/filebench_workload.sh fileserver

# 运行完整测试套件
echo "6. 运行完整测试套件..."
./runall.sh all

# 查看结果
echo "7. 查看测试结果..."
./printresult.sh all

echo "=== 调试和测试完成 ===" 