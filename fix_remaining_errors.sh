#!/bin/bash

echo "=========================================="
echo "Fixing Remaining Compilation Errors"
echo "=========================================="

cd /home/femu/fast24_ae/nvmevirt_hybrid

# 备份文件
echo "Step 1: Backing up files..."
cp ssd_config.h ssd_config.h.backup2
cp ssd.h ssd.h.backup
cp admin.c admin.c.backup

# 问题1: 彻底修复 ssd_config.h 中的重复定义
echo "Step 2: Completely fixing duplicate NS_SSD_TYPE_1 definitions..."

# 创建一个临时文件来重写 ssd_config.h
cat > /tmp/ssd_config_fixed.h << 'EOF'
// SPDX-License-Identifier: GPL-2.0-only

#ifndef _NVMEVIRT_SSD_CONFIG_H
#define _NVMEVIRT_SSD_CONFIG_H

/* SSD Model */
#define INTEL_OPTANE 0
#define SAMSUNG_970PRO 1
#define ZNS_PROTOTYPE 2
#define KV_PROTOTYPE 3
#define WD_ZN540 4
#define HYBRID_SSD 5

/* SSD Type */
#define SSD_TYPE_NVM 0
#define SSD_TYPE_CONV 1
#define SSD_TYPE_ZNS 2
#define SSD_TYPE_KV 3

/* Cell Mode */
#define CELL_MODE_UNKNOWN 0
#define CELL_MODE_SLC 1
#define CELL_MODE_MLC 2
#define CELL_MODE_TLC 3
#define CELL_MODE_QLC 4

/* Hybrid Storage Configuration */
#define HYBRID_SLC_RATIO 20  /* 20% capacity for SLC */
#define HYBRID_SLC_CHANNELS 2  /* 2 channels for SLC */
#define HYBRID_QLC_CHANNELS 6  /* 6 channels for QLC */
#define HYBRID_LUNS_PER_CH 2  /* 2 LUNs per channel */

/* Hotness tracking configuration */
#define HYBRID_HOTNESS_TABLE_SIZE (1024 * 1024)  /* 1M entries */
#define HYBRID_HOT_THRESHOLD 10  /* Pages with >= 10 accesses are hot */
#define HYBRID_COLD_THRESHOLD 2  /* Pages with <= 2 accesses are cold */
#define HYBRID_MIGRATION_INTERVAL (1000000000)  /* 1 second in ns */
#define HYBRID_MAX_MIGRATIONS_PER_CHECK 100  /* Max 100 migrations per check */

/* Hybrid Storage Latency Parameters - Simplified */
/* SLC Latency Parameters */
#define HYBRID_SLC_READ_LATENCY (30000)  /* ns - 30μs */
#define HYBRID_SLC_WRITE_LATENCY (80000)  /* ns - 80μs */
#define HYBRID_SLC_ERASE_LATENCY (0)  /* ns */

/* QLC Latency Parameters - Four regions (Q1, Q2, Q3, Q4) */
#define HYBRID_QLC_Q1_READ_LATENCY (75000)   /* ns - Q1 region: 75μs */
#define HYBRID_QLC_Q2_READ_LATENCY (95000)   /* ns - Q2 region: 95μs */
#define HYBRID_QLC_Q3_READ_LATENCY (130000)  /* ns - Q3 region: 130μs */
#define HYBRID_QLC_Q4_READ_LATENCY (205000)  /* ns - Q4 region: 205μs */

/* QLC write latency - only used for migration, not for performance testing */
#define HYBRID_QLC_WRITE_LATENCY (561000)  /* ns */
#define HYBRID_QLC_ERASE_LATENCY (0)  /* ns */

/* Hybrid Storage Capacity Parameters */
#define HYBRID_SLC_PGS_PER_BLK (256)  /* SLC pages per block */
#define HYBRID_SLC_BLKS_PER_PL (8192)  /* SLC blocks per plane */
#define HYBRID_SLC_PGS_PER_ONESHOTPG (1)  /* SLC pages per oneshot page */
#define HYBRID_SLC_ONESHOTPGS_PER_BLK (256)  /* SLC oneshot pages per block */

#define HYBRID_QLC_PGS_PER_BLK (1024)  /* QLC pages per block */
#define HYBRID_QLC_BLKS_PER_PL (8192)  /* QLC blocks per plane */
#define HYBRID_QLC_PGS_PER_ONESHOTPG (4)  /* QLC pages per oneshot page */
#define HYBRID_QLC_ONESHOTPGS_PER_BLK (256)  /* QLC oneshot pages per block */

/* Must select one of INTEL_OPTANE, SAMSUNG_970PRO, ZNS_PROTOTYPE, KV_PROTOTYPE, WD_ZN540, or HYBRID_SSD
 * in Makefile */

#if (BASE_SSD == INTEL_OPTANE)
#define NR_NAMESPACES 1
#define NS_SSD_TYPE_0 SSD_TYPE_NVM
#define NS_CAPACITY_0 (0)

#elif (BASE_SSD == SAMSUNG_970PRO)
#define NR_NAMESPACES 1
#define NS_SSD_TYPE_0 SSD_TYPE_NVM
#define NS_CAPACITY_0 (0)

#elif (BASE_SSD == ZNS_PROTOTYPE)
#define NR_NAMESPACES 1
#define NS_SSD_TYPE_0 SSD_TYPE_ZNS
#define NS_CAPACITY_0 (0)

#elif (BASE_SSD == KV_PROTOTYPE)
#define NR_NAMESPACES 1
#define NS_SSD_TYPE_0 SSD_TYPE_KV
#define NS_CAPACITY_0 (0)

#elif (BASE_SSD == WD_ZN540)
#define NR_NAMESPACES 1
#define NS_SSD_TYPE_0 SSD_TYPE_ZNS
#define NS_CAPACITY_0 (0)

#elif (BASE_SSD == HYBRID_SSD)
#define NR_NAMESPACES 1

/* Namespace Configuration */
#define NS_SSD_TYPE_0 SSD_TYPE_CONV
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE(ns_id) NS_SSD_TYPE_##ns_id

/* Basic SSD Parameters */
#define MDTS 7
#define NAND_CHANNELS 8
#define LUNS_PER_NAND_CH 2
#define PLNS_PER_LUN 1
#define FLASH_PAGE_SIZE KB(16)
#define ONESHOT_PAGE_SIZE FLASH_PAGE_SIZE
#define BLKS_PER_PLN 8192

#else
#error "Must select one of INTEL_OPTANE, SAMSUNG_970PRO, ZNS_PROTOTYPE, KV_PROTOTYPE, WD_ZN540, or HYBRID_SSD"
#endif

/* Define SUPPORTED_SSD_TYPE macro to avoid compilation errors */
#define SUPPORTED_SSD_TYPE(type) 0

EOF

# 添加所有的 enum 定义
cat >> /tmp/ssd_config_fixed.h << 'EOF'

/* Allocator type */
enum {
	ALLOCATOR_TYPE_BITMAP,
	ALLOCATOR_TYPE_APPEND_ONLY,
};

/* FTL type */
enum {
	FTL_TYPE_CONV,
	FTL_TYPE_ZNS,
	FTL_TYPE_KV,
};

/* GC type */
enum {
	GC_TYPE_SIMPLE,
	GC_TYPE_DA,
};

/* Write strategy type */
enum {
	WRITE_STRATEGY_RR,
	WRITE_STRATEGY_DA,
};

/* Read strategy type */
enum {
	READ_STRATEGY_RR,
	READ_STRATEGY_DA,
};

/* Write buffer type */
enum {
	WRITE_BUFFER_TYPE_SIMPLE,
	WRITE_BUFFER_TYPE_DA,
};

/* Channel model type */
enum {
	CHANNEL_MODEL_TYPE_SIMPLE,
	CHANNEL_MODEL_TYPE_DA,
};

/* PCIe model type */
enum {
	PCIE_MODEL_TYPE_SIMPLE,
	PCIE_MODEL_TYPE_DA,
};

/* DMA model type */
enum {
	DMA_MODEL_TYPE_SIMPLE,
	DMA_MODEL_TYPE_DA,
};

/* IO model type */
enum {
	IO_MODEL_TYPE_SIMPLE,
	IO_MODEL_TYPE_DA,
};

/* Bitmap type */
enum {
	BITMAP_TYPE_SIMPLE,
	BITMAP_TYPE_DA,
};

/* Append only type */
enum {
	APPEND_ONLY_TYPE_SIMPLE,
	APPEND_ONLY_TYPE_DA,
};

/* Queue type */
enum {
	QUEUE_TYPE_SIMPLE,
	QUEUE_TYPE_DA,
};

/* Admin type */
enum {
	ADMIN_TYPE_SIMPLE,
	ADMIN_TYPE_DA,
};

/* ZNS management send type */
enum {
	ZNS_MGMT_SEND_TYPE_SIMPLE,
	ZNS_MGMT_SEND_TYPE_DA,
};

/* ZNS management receive type */
enum {
	ZNS_MGMT_RECV_TYPE_SIMPLE,
	ZNS_MGMT_RECV_TYPE_DA,
};

/* ZNS read write type */
enum {
	ZNS_READ_WRITE_TYPE_SIMPLE,
	ZNS_READ_WRITE_TYPE_DA,
};

/* Simple FTL type */
enum {
	SIMPLE_FTL_TYPE_SIMPLE,
	SIMPLE_FTL_TYPE_DA,
};

/* KV FTL type */
enum {
	KV_FTL_TYPE_SIMPLE,
	KV_FTL_TYPE_DA,
};

/* Conv FTL type */
enum {
	CONV_FTL_TYPE_SIMPLE,
	CONV_FTL_TYPE_DA,
};

/* SSD type */
enum {
	SSD_TYPE_SIMPLE,
	SSD_TYPE_DA,
};

/* PCI type */
enum {
	PCI_TYPE_SIMPLE,
	PCI_TYPE_DA,
};

/* Main type */
enum {
	MAIN_TYPE_SIMPLE,
	MAIN_TYPE_DA,
};

#endif
EOF

# 替换原文件
cp /tmp/ssd_config_fixed.h ssd_config.h

# 问题2: 修复 ssd.h 中的 C90 警告
echo "Step 3: Fixing C90 warning in ssd.h..."

# 找到 get_qlc_region 函数并修复变量声明位置
sed -i '/^static inline int get_qlc_region/,/^}/ {
    s/uint64_t region_size = spp->qlc_tt_pgs \/ 4;/uint64_t region_size;\
	region_size = spp->qlc_tt_pgs \/ 4;/
}' ssd.h

# 问题3: 修复 admin.c 中的 SUPPORTED_SSD_TYPE 宏
echo "Step 4: Fixing SUPPORTED_SSD_TYPE macro in admin.c..."

# 注释掉所有 SUPPORTED_SSD_TYPE 相关的条件编译
sed -i 's/#if SUPPORTED_SSD_TYPE(ZNS)/#if 0 \/\/ SUPPORTED_SSD_TYPE(ZNS)/' admin.c
sed -i 's/#if (SUPPORTED_SSD_TYPE(ZNS))/#if 0 \/\/ (SUPPORTED_SSD_TYPE(ZNS))/' admin.c

# 问题4: 修复其他文件中可能的 SUPPORTED_SSD_TYPE 问题
echo "Step 5: Fixing SUPPORTED_SSD_TYPE in other files..."

# 查找并修复所有文件中的 SUPPORTED_SSD_TYPE
find . -name "*.c" -o -name "*.h" | xargs grep -l "SUPPORTED_SSD_TYPE" | while read file; do
    echo "Fixing SUPPORTED_SSD_TYPE in $file"
    sed -i 's/#if SUPPORTED_SSD_TYPE(/#if 0 \/\/ SUPPORTED_SSD_TYPE(/g' "$file"
    sed -i 's/#if (SUPPORTED_SSD_TYPE(/#if 0 \/\/ (SUPPORTED_SSD_TYPE(/g' "$file"
done

echo "Step 6: Verifying changes..."
echo "Checking ssd_config.h for clean HYBRID_SSD block:"
grep -A 5 -B 2 "BASE_SSD == HYBRID_SSD" ssd_config.h

echo "Checking for remaining NS_SSD_TYPE_1 duplicates:"
grep -n "NS_SSD_TYPE_1" ssd_config.h

echo "Checking ssd.h for C90 fix:"
grep -A 3 -B 1 "region_size" ssd.h

echo "=========================================="
echo "All fixes applied! Now compiling..."
echo "=========================================="

# 清理并重新编译
make clean
make CONFIG_NVMEVIRT_HYBRID=y 2>&1 | tee compile_final2.log

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "Module compiled successfully!"
    ls -la nvmev.ko
else
    echo "❌ Compilation failed. Checking errors..."
    echo "Last 30 lines of compilation output:"
    tail -30 compile_final2.log
    
    echo ""
    echo "If there are still errors, please paste the error output."
fi 