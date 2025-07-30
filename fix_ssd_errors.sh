#!/bin/bash

echo "=========================================="
echo "Fixing SSD.c Compilation Errors"
echo "=========================================="

cd /home/femu/fast24_ae/nvmevirt_hybrid

# 备份文件
echo "Step 1: Backing up ssd.c and ssd.h..."
cp ssd.c ssd.c.backup3
cp ssd.h ssd.h.backup3

# 问题1: 修复 ssd.h 中缺少的结构体成员
echo "Step 2: Adding missing members to ssdparams struct..."

# 在 ssd.h 中的 ssdparams 结构体中添加缺少的成员
sed -i '/int qlc_erase_latency;/a\
\
	/* Legacy latency parameters for compatibility */\
	int slc_pg_wr_lat;\
	int qlc_pg_wr_lat;\
	int slc_blk_er_lat;\
	int qlc_blk_er_lat;\
	int max_ch_xfer_size;' ssd.h

# 问题2: 修复 ssd.c 中的初始化
echo "Step 3: Adding initialization for missing parameters..."

# 在 ssd_init_params 函数中添加初始化
sed -i '/spp->qlc_erase_latency = HYBRID_QLC_ERASE_LATENCY;/a\
\
	/* Initialize legacy latency parameters for compatibility */\
	spp->slc_pg_wr_lat = spp->slc_write_latency;\
	spp->qlc_pg_wr_lat = spp->qlc_write_latency;\
	spp->slc_blk_er_lat = spp->slc_erase_latency;\
	spp->qlc_blk_er_lat = spp->qlc_erase_latency;\
	spp->max_ch_xfer_size = 128;  /* Default 128KB */' ssd.c

# 问题3: 修复 min() 宏的类型不匹配
echo "Step 4: Fixing min() macro type mismatch..."

# 修复 ssd.c 中的类型不匹配问题
sed -i 's/xfer_size = min(remaining, (uint64_t)spp->max_ch_xfer_size);/xfer_size = min((uint64_t)remaining, (uint64_t)spp->max_ch_xfer_size);/' ssd.c

# 问题4: 确保所有必要的宏都在 ssd_config.h 中定义
echo "Step 5: Ensuring all necessary macros are defined..."

# 检查并添加 KB 宏定义（如果不存在）
if ! grep -q "#define KB(" ssd_config.h; then
    sed -i '/#define HYBRID_SSD 5/a\
\
/* Size macros */\
#define KB(x) ((x) * 1024ULL)\
#define MB(x) ((x) * 1024ULL * 1024ULL)\
#define GB(x) ((x) * 1024ULL * 1024ULL * 1024ULL)' ssd_config.h
fi

echo "Step 6: Verifying changes..."
echo "Checking ssd.h for added members:"
grep -A 5 -B 1 "slc_pg_wr_lat\|max_ch_xfer_size" ssd.h

echo "Checking ssd.c for initialization:"
grep -A 3 -B 1 "slc_pg_wr_lat\|max_ch_xfer_size" ssd.c

echo "=========================================="
echo "SSD fixes applied! Now compiling..."
echo "=========================================="

# 清理并重新编译
make clean
make CONFIG_NVMEVIRT_HYBRID=y 2>&1 | tee compile_ssd_fix.log

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "Module compiled successfully!"
    ls -la nvmev.ko
else
    echo "❌ Compilation failed. Checking errors..."
    echo "Last 20 lines of compilation output:"
    tail -20 compile_ssd_fix.log
    
    echo ""
    echo "Remaining errors (if any):"
    grep -i "error:" compile_ssd_fix.log | tail -10
fi 