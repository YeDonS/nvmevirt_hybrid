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

/* Must select one of INTEL_OPTANE, SAMSUNG_970PRO, or ZNS_PROTOTYPE
 * in Makefile */

#if (BASE_SSD == INTEL_OPTANE)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_NVM
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#elif (BASE_SSD == SAMSUNG_970PRO)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_NVM
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#elif (BASE_SSD == ZNS_PROTOTYPE)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_ZNS
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#elif (BASE_SSD == KV_PROTOTYPE)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_KV
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#elif (BASE_SSD == WD_ZN540)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_ZNS
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#elif (BASE_SSD == HYBRID_SSD)
#define NR_NAMESPACES 1

#define NS_SSD_TYPE_0 SSD_TYPE_CONV
#define NS_CAPACITY_0 (0)
#define NS_SSD_TYPE_1 NS_SSD_TYPE_0
#define NS_CAPACITY_1 (0)

#else
#error "Must select one of INTEL_OPTANE, SAMSUNG_970PRO, ZNS_PROTOTYPE, KV_PROTOTYPE, WD_ZN540, or HYBRID_SSD"
#endif

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
