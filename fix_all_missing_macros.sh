#!/bin/bash

echo "=========================================="
echo "Fixing ALL Missing Macro Definitions"
echo "=========================================="

cd /home/femu/fast24_ae/nvmevirt_hybrid

# 备份文件
echo "Step 1: Backing up files..."
cp ssd_config.h ssd_config.h.backup_final
cp ssd.c ssd.c.backup_final
cp ssd.h ssd.h.backup_final

# 问题1: 在 ssd_config.h 中添加所有缺失的宏定义
echo "Step 2: Adding ALL missing macro definitions to ssd_config.h..."

# 在 HYBRID_SSD 块中添加所有缺失的宏
sed -i '/^#define BLKS_PER_PLN 8192/a\
\
/* Additional SSD Parameters */\
#define CELL_MODE CELL_MODE_QLC\
#define PCIE_BANDWIDTH (32000)  /* 32 GB/s */\
#define NAND_CHANNEL_BANDWIDTH (800)  /* 800 MB/s */\
#define FW_4KB_RD_LATENCY (100000)  /* 100μs */\
#define FW_RD_LATENCY (150000)  /* 150μs */\
#define FW_WR_LATENCY (200000)  /* 200μs */\
#define FW_CH_XFER_LATENCY (50000)  /* 50μs */\
#define FW_WBUF_LATENCY0 (10000)  /* 10μs */\
#define FW_WBUF_LATENCY1 (20000)  /* 20μs */\
#define GLOBAL_WB_SIZE (64)  /* 64MB */\
#define WRITE_EARLY_COMPLETION (1)  /* Enable early completion */\
#define MAX_CH_XFER_SIZE (128)  /* 128KB */\
\
/* Namespace SSD Type Configuration */\
#define NS_SSD_TYPE_1 SSD_TYPE_CONV\
#define NS_SSD_TYPE_2 SSD_TYPE_CONV\
#define NS_SSD_TYPE_3 SSD_TYPE_CONV\
\
#define NS_CAPACITY_1 (0)\
#define NS_CAPACITY_2 (0)\
#define NS_CAPACITY_3 (0)' ssd_config.h

# 问题2: 在 ssd.h 中确保所有结构体成员都存在
echo "Step 3: Adding missing members to ssdparams struct in ssd.h..."

# 检查并添加缺失的结构体成员
if ! grep -q "fw_4kb_rd_lat" ssd.h; then
    sed -i '/int max_ch_xfer_size;/a\
\
	/* Additional firmware latency parameters */\
	int fw_4kb_rd_lat;\
	int fw_rd_lat;\
	int fw_wr_lat;\
	int fw_ch_xfer_lat;\
	int fw_wbuf_lat0;\
	int fw_wbuf_lat1;\
\
	/* Bandwidth parameters */\
	int ch_bandwidth;\
	int pcie_bandwidth;\
\
	/* Write buffer parameters */\
	int write_buffer_size;\
	int write_early_completion;' ssd.h
fi

# 问题3: 在 ssd.c 中初始化所有新增的参数
echo "Step 4: Adding initialization for all missing parameters in ssd.c..."

# 在 ssd_init_params 函数中添加所有缺失参数的初始化
sed -i '/spp->max_ch_xfer_size = 128;/a\
\
	/* Initialize additional firmware latency parameters */\
	spp->fw_4kb_rd_lat = FW_4KB_RD_LATENCY;\
	spp->fw_rd_lat = FW_RD_LATENCY;\
	spp->fw_wr_lat = FW_WR_LATENCY;\
	spp->fw_ch_xfer_lat = FW_CH_XFER_LATENCY;\
	spp->fw_wbuf_lat0 = FW_WBUF_LATENCY0;\
	spp->fw_wbuf_lat1 = FW_WBUF_LATENCY1;\
\
	/* Initialize bandwidth parameters */\
	spp->ch_bandwidth = NAND_CHANNEL_BANDWIDTH;\
	spp->pcie_bandwidth = PCIE_BANDWIDTH;\
\
	/* Initialize write buffer parameters */\
	spp->write_buffer_size = GLOBAL_WB_SIZE;\
	spp->write_early_completion = WRITE_EARLY_COMPLETION;' ssd.c

# 问题4: 确保 max_ch_xfer_size 使用正确的宏
echo "Step 5: Updating max_ch_xfer_size initialization..."
sed -i 's/spp->max_ch_xfer_size = 128;/spp->max_ch_xfer_size = MAX_CH_XFER_SIZE;/' ssd.c

echo "Step 6: Verifying all changes..."
echo "Checking ssd_config.h for new macros:"
grep -E "FW_.*_LATENCY|NAND_CHANNEL_BANDWIDTH|PCIE_BANDWIDTH|GLOBAL_WB_SIZE" ssd_config.h

echo "Checking ssd.h for new struct members:"
grep -A 10 -B 2 "fw_4kb_rd_lat\|ch_bandwidth\|write_buffer_size" ssd.h

echo "Checking ssd.c for initialization:"
grep -A 5 -B 1 "fw_4kb_rd_lat\|ch_bandwidth\|write_buffer_size" ssd.c

echo "=========================================="
echo "All macro fixes applied! Now compiling..."
echo "=========================================="

# 清理并重新编译
make clean
make CONFIG_NVMEVIRT_HYBRID=y 2>&1 | tee compile_final_fix.log

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "Module compiled successfully!"
    ls -la nvmev.ko
    echo ""
    echo "🎉 SUCCESS! The hybrid SSD module has been compiled successfully!"
    echo "You can now load the module with: sudo insmod nvmev.ko"
else
    echo "❌ Compilation failed. Checking errors..."
    echo "Last 30 lines of compilation output:"
    tail -30 compile_final_fix.log
    
    echo ""
    echo "Remaining errors:"
    grep -i "error:" compile_final_fix.log | tail -15
    
    echo ""
    echo "Missing macros (if any):"
    grep -i "undeclared\|undefined" compile_final_fix.log | cut -d"'" -f2 | sort | uniq
fi 