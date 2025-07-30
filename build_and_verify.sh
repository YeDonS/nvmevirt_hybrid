#!/bin/bash

echo "=== 编译和验证混合SSD项目 ==="

# 检查内核源码
echo "1. 检查内核源码..."
if [ ! -d "/usr/src/linux" ]; then
    echo "下载内核源码..."
    cd /usr/src
    sudo wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.0.tar.xz
    sudo tar -xf linux-5.15.0.tar.xz
    sudo ln -s linux-5.15.0 linux
fi

# 配置内核
echo "2. 配置内核..."
cd /usr/src/linux
sudo make olddefconfig

# 修改内核配置
echo "3. 修改内核配置..."
sudo tee -a .config > /dev/null << EOF
CONFIG_SYSTEM_TRUSTED_KEYS=""
CONFIG_SYSTEM_REVOCATION_KEYS=""
EOF

# 编译内核
echo "4. 编译内核..."
sudo make -j$(nproc) LOCALVERSION=
sudo make INSTALL_MOD_STRIP=1 modules_install
sudo make install
sudo update-grub

echo "5. 编译混合SSD模块..."
cd /home/$(whoami)/nvmevirt_DA
make clean
make -j$(nproc)

# 检查编译结果
echo "6. 检查编译结果..."
if [ -f "nvmev.ko" ]; then
    echo "✅ 模块编译成功"
    ls -la *.ko
else
    echo "❌ 模块编译失败"
    exit 1
fi

# 运行验证脚本
echo "7. 运行验证脚本..."
./verify_hybrid_implementation.sh
./verify_migration_implementation.sh
./verify_traditional_strategy.sh
./verify_unidirectional_migration.sh
./verify_qlc_regions.sh

echo "=== 编译和验证完成 ===" 