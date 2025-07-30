// SPDX-License-Identifier: GPL-2.0-only

#include <linux/ktime.h>
#include <linux/sched/clock.h>

#include "nvmev.h"
#include "ssd.h"

static inline uint64_t __get_ioclock(struct ssd *ssd)
{
	return cpu_clock(ssd->cpu_nr_dispatcher);
}

void buffer_init(struct buffer *buf, size_t size)
{
	spin_lock_init(&buf->lock);
	buf->size = size;
	buf->remaining = size;
}

uint32_t buffer_allocate(struct buffer *buf, size_t size)
{
	while (!spin_trylock(&buf->lock)) {
		cpu_relax();
	}

	if (buf->remaining < size) {
		size = 0;
	}

	buf->remaining -= size;

	spin_unlock(&buf->lock);
	return size;
}

bool buffer_release(struct buffer *buf, size_t size)
{
	while (!spin_trylock(&buf->lock))
		;
	buf->remaining += size;
	spin_unlock(&buf->lock);

	return true;
}

void buffer_refill(struct buffer *buf)
{
	while (!spin_trylock(&buf->lock))
		;
	buf->remaining = buf->size;
	spin_unlock(&buf->lock);
}

static void check_params(struct ssdparams *spp)
{
	/*
     * we are using a general write pointer increment method now, no need to
     * force luns_per_ch and nchs to be power of 2
     */

	//ftl_assert(is_power_of_2(spp->luns_per_ch));
	//ftl_assert(is_power_of_2(spp->nchs));
}

void ssd_init_params(struct ssdparams *spp, uint64_t capacity, uint32_t nparts)
{
	uint64_t blk_size, total_size;

	spp->secsz = 512;
	spp->secs_per_pg = 8;
	spp->pgsz = spp->secsz * spp->secs_per_pg;

	spp->nchs = NAND_CHANNELS;
	spp->pls_per_lun = PLNS_PER_LUN;
	spp->luns_per_ch = LUNS_PER_NAND_CH;
	spp->cell_mode = CELL_MODE;

	/* Hybrid storage configuration */
#if (BASE_SSD == HYBRID_SSD)
	spp->slc_ratio = HYBRID_SLC_RATIO;
	spp->slc_channels = HYBRID_SLC_CHANNELS;
	spp->qlc_channels = HYBRID_QLC_CHANNELS;
	spp->slc_luns_per_ch = HYBRID_LUNS_PER_CH;
	spp->qlc_luns_per_ch = HYBRID_LUNS_PER_CH;
	
	/* Hotness tracking parameters */
	spp->hotness_table_size = HYBRID_HOTNESS_TABLE_SIZE;
	spp->hot_threshold = HYBRID_HOT_THRESHOLD;
	spp->cold_threshold = HYBRID_COLD_THRESHOLD;
	spp->migration_interval = HYBRID_MIGRATION_INTERVAL;
	spp->max_migrations_per_check = HYBRID_MAX_MIGRATIONS_PER_CHECK;
	
	/* SLC specific parameters */
	spp->slc_pgs_per_blk = HYBRID_SLC_PGS_PER_BLK;
	spp->slc_blks_per_pl = HYBRID_SLC_BLKS_PER_PL;
	spp->slc_pgs_per_oneshotpg = HYBRID_SLC_PGS_PER_ONESHOTPG;
	spp->slc_oneshotpgs_per_blk = HYBRID_SLC_ONESHOTPGS_PER_BLK;
	
	/* QLC specific parameters */
	spp->qlc_pgs_per_blk = HYBRID_QLC_PGS_PER_BLK;
	spp->qlc_blks_per_pl = HYBRID_QLC_BLKS_PER_PL;
	spp->qlc_pgs_per_oneshotpg = HYBRID_QLC_PGS_PER_ONESHOTPG;
	spp->qlc_oneshotpgs_per_blk = HYBRID_QLC_ONESHOTPGS_PER_BLK;
	
	/* Set simplified latency parameters */
	spp->slc_read_latency = HYBRID_SLC_READ_LATENCY;
	spp->slc_write_latency = HYBRID_SLC_WRITE_LATENCY;
	spp->slc_erase_latency = HYBRID_SLC_ERASE_LATENCY;
	
	/* Set QLC latency parameters for 4 regions */
	spp->qlc_q1_read_latency = HYBRID_QLC_Q1_READ_LATENCY;
	spp->qlc_q2_read_latency = HYBRID_QLC_Q2_READ_LATENCY;
	spp->qlc_q3_read_latency = HYBRID_QLC_Q3_READ_LATENCY;
	spp->qlc_q4_read_latency = HYBRID_QLC_Q4_READ_LATENCY;
	spp->qlc_write_latency = HYBRID_QLC_WRITE_LATENCY;
	spp->qlc_erase_latency = HYBRID_QLC_ERASE_LATENCY;
#endif

	/* partitioning SSD by dividing channel*/
	NVMEV_ASSERT((spp->nchs % nparts) == 0);
	spp->nchs /= nparts;
	capacity /= nparts;

	if (BLKS_PER_PLN > 0) {
		/* flashpgs_per_blk depends on capacity */
		spp->blks_per_pl = BLKS_PER_PLN;
		blk_size = DIV_ROUND_UP(capacity, spp->blks_per_pl * spp->pls_per_lun *
							  spp->luns_per_ch * spp->nchs);
	} else {
		NVMEV_ASSERT(BLK_SIZE > 0);
		blk_size = BLK_SIZE;
		spp->blks_per_pl = DIV_ROUND_UP(capacity, blk_size * spp->pls_per_lun *
								  spp->luns_per_ch * spp->nchs);
	}

	NVMEV_ASSERT((ONESHOT_PAGE_SIZE % spp->pgsz) == 0 && (FLASH_PAGE_SIZE % spp->pgsz) == 0);
	NVMEV_ASSERT((ONESHOT_PAGE_SIZE % FLASH_PAGE_SIZE) == 0);

	spp->pgs_per_oneshotpg = ONESHOT_PAGE_SIZE / (spp->pgsz);
	spp->oneshotpgs_per_blk = DIV_ROUND_UP(blk_size, ONESHOT_PAGE_SIZE);

#if (BASE_SSD == HYBRID_SSD)
	/* Calculate hybrid storage parameters with proper channel allocation */
	uint64_t total_channels = spp->slc_channels + spp->qlc_channels;
	uint64_t slc_capacity = capacity * spp->slc_channels / total_channels;
	uint64_t qlc_capacity = capacity * spp->qlc_channels / total_channels;
	
	/* Calculate SLC parameters based on channel allocation */
	/* SLC capacity per channel */
	uint64_t slc_capacity_per_ch = slc_capacity / spp->slc_channels;
	/* SLC capacity per LUN */
	uint64_t slc_capacity_per_lun = slc_capacity_per_ch / spp->slc_luns_per_ch;
	/* SLC pages per LUN */
	uint64_t slc_pgs_per_lun = slc_capacity_per_lun / spp->pgsz;
	
	spp->slc_tt_pgs = spp->slc_channels * spp->slc_luns_per_ch * slc_pgs_per_lun;
	spp->slc_tt_blks = spp->slc_tt_pgs / spp->slc_pgs_per_blk;
	spp->slc_tt_lines = spp->slc_tt_blks / spp->slc_blks_per_pl;
	spp->slc_pgs_per_ch = slc_pgs_per_lun * spp->slc_luns_per_ch;
	spp->slc_blks_per_ch = spp->slc_pgs_per_ch / spp->slc_pgs_per_blk;
	
	/* Calculate QLC parameters based on channel allocation */
	/* QLC capacity per channel */
	uint64_t qlc_capacity_per_ch = qlc_capacity / spp->qlc_channels;
	/* QLC capacity per LUN */
	uint64_t qlc_capacity_per_lun = qlc_capacity_per_ch / spp->qlc_luns_per_ch;
	/* QLC pages per LUN */
	uint64_t qlc_pgs_per_lun = qlc_capacity_per_lun / spp->pgsz;
	
	spp->qlc_tt_pgs = spp->qlc_channels * spp->qlc_luns_per_ch * qlc_pgs_per_lun;
	spp->qlc_tt_blks = spp->qlc_tt_pgs / spp->qlc_pgs_per_blk;
	spp->qlc_tt_lines = spp->qlc_tt_blks / spp->qlc_blks_per_pl;
	spp->qlc_pgs_per_ch = qlc_pgs_per_lun * spp->qlc_luns_per_ch;
	spp->qlc_blks_per_ch = spp->qlc_pgs_per_ch / spp->qlc_pgs_per_blk;
	
	/* Update total pages to reflect actual hybrid allocation */
	spp->tt_pgs = spp->slc_tt_pgs + spp->qlc_tt_pgs;
	
	/* Set PPA ranges for SLC and QLC */
	spp->slc_start_ppa = 0;
	spp->slc_end_ppa = spp->slc_tt_pgs;
	spp->qlc_start_ppa = spp->slc_tt_pgs;
	spp->qlc_end_ppa = spp->tt_pgs;
	
	/* Set LPN ranges for SLC and QLC */
	spp->slc_start_lpn = 0;
	spp->slc_end_lpn = spp->slc_tt_pgs;
	spp->qlc_start_lpn = spp->slc_tt_pgs;
	spp->qlc_end_lpn = spp->tt_pgs;
	
	/* Print capacity information for debugging */
	NVMEV_INFO("Hybrid SSD Capacity Allocation:\n");
	NVMEV_INFO("  Total Capacity: %llu MB\n", capacity / (1024 * 1024));
	NVMEV_INFO("  SLC Capacity: %llu MB (%d channels, %d LUNs per channel)\n", 
		   slc_capacity / (1024 * 1024), spp->slc_channels, spp->slc_luns_per_ch);
	NVMEV_INFO("  QLC Capacity: %llu MB (%d channels, %d LUNs per channel)\n", 
		   qlc_capacity / (1024 * 1024), spp->qlc_channels, spp->qlc_luns_per_ch);
	NVMEV_INFO("  SLC Total Pages: %llu\n", spp->slc_tt_pgs);
	NVMEV_INFO("  QLC Total Pages: %llu\n", spp->qlc_tt_pgs);
	NVMEV_INFO("  SLC Pages per Block: %d, QLC Pages per Block: %d\n", 
		   spp->slc_pgs_per_blk, spp->qlc_pgs_per_blk);
#endif

	spp->pgs_per_flashpg = FLASH_PAGE_SIZE / (spp->pgsz);
	spp->pgs_per_blk = spp->pgs_per_oneshotpg * spp->oneshotpgs_per_blk;

	spp->write_unit_size = WRITE_UNIT_SIZE;

	spp->pg_4kb_rd_lat[CELL_TYPE_LSB] = NAND_4KB_READ_LATENCY_LSB;
	spp->pg_4kb_rd_lat[CELL_TYPE_MSB] = NAND_4KB_READ_LATENCY_MSB;
	spp->pg_4kb_rd_lat[CELL_TYPE_CSB] = NAND_4KB_READ_LATENCY_CSB;
	spp->pg_rd_lat[CELL_TYPE_LSB] = NAND_READ_LATENCY_LSB;
	spp->pg_rd_lat[CELL_TYPE_MSB] = NAND_READ_LATENCY_MSB;
	spp->pg_rd_lat[CELL_TYPE_CSB] = NAND_READ_LATENCY_CSB;
	spp->pg_wr_lat = NAND_PROG_LATENCY;
	spp->blk_er_lat = NAND_ERASE_LATENCY;
	spp->max_ch_xfer_size = MAX_CH_XFER_SIZE;

	spp->fw_4kb_rd_lat = FW_4KB_READ_LATENCY;
	spp->fw_rd_lat = FW_READ_LATENCY;
	spp->fw_ch_xfer_lat = FW_CH_XFER_LATENCY;
	spp->fw_wbuf_lat0 = FW_WBUF_LATENCY0;
	spp->fw_wbuf_lat1 = FW_WBUF_LATENCY1;

	spp->ch_bandwidth = NAND_CHANNEL_BANDWIDTH;
	spp->pcie_bandwidth = PCIE_BANDWIDTH;

	spp->write_buffer_size = GLOBAL_WB_SIZE;
	spp->write_early_completion = WRITE_EARLY_COMPLETION;

	/* calculated values */
	spp->secs_per_blk = spp->secs_per_pg * spp->pgs_per_blk;
	spp->secs_per_pl = spp->secs_per_blk * spp->blks_per_pl;
	spp->secs_per_lun = spp->secs_per_pl * spp->pls_per_lun;
	spp->secs_per_ch = spp->secs_per_lun * spp->luns_per_ch;
	spp->tt_secs = spp->secs_per_ch * spp->nchs;

	spp->pgs_per_pl = spp->pgs_per_blk * spp->blks_per_pl;
	spp->pgs_per_lun = spp->pgs_per_pl * spp->pls_per_lun;
	spp->pgs_per_ch = spp->pgs_per_lun * spp->luns_per_ch;
	spp->tt_pgs = spp->pgs_per_ch * spp->nchs;

	spp->blks_per_lun = spp->blks_per_pl * spp->pls_per_lun;
	spp->blks_per_ch = spp->blks_per_lun * spp->luns_per_ch;
	spp->tt_blks = spp->blks_per_ch * spp->nchs;

	spp->pls_per_ch = spp->pls_per_lun * spp->luns_per_ch;
	spp->tt_pls = spp->pls_per_ch * spp->nchs;

	spp->tt_luns = spp->luns_per_ch * spp->nchs;

	/* line is special, put it at the end */
	spp->blks_per_line = spp->tt_luns; /* TODO: to fix under multiplanes */
	spp->pgs_per_line = spp->blks_per_line * spp->pgs_per_blk;
	spp->secs_per_line = spp->pgs_per_line * spp->secs_per_pg;
	spp->tt_lines = spp->blks_per_lun;
	/* TODO: to fix under multiplanes */ // lun size is super-block(line) size
	
	//66f1 die line option
	spp->blks_per_lun_line = spp->pls_per_lun;
	spp->pgs_per_lun_line = spp->blks_per_lun_line * spp->pgs_per_blk;
	spp->secs_per_lun_line = spp->pgs_per_lun_line * spp->secs_per_pg;
	spp->tt_lun_lines = spp->blks_per_lun_line;
	//66f1


	check_params(spp);

	total_size = (unsigned long)spp->tt_luns * spp->blks_per_lun * spp->pgs_per_blk *
		     spp->secsz * spp->secs_per_pg;
	blk_size = spp->pgs_per_blk * spp->secsz * spp->secs_per_pg;
	NVMEV_INFO(
		"Total Capacity(GiB,MiB)=%llu,%llu chs=%u luns=%lu lines=%lu blk-size(MiB,KiB)=%u,%u line-size(MiB,KiB)=%lu,%lu",
		BYTE_TO_GB(total_size), BYTE_TO_MB(total_size), spp->nchs, spp->tt_luns,
		spp->tt_lines, BYTE_TO_MB(spp->pgs_per_blk * spp->pgsz),
		BYTE_TO_KB(spp->pgs_per_blk * spp->pgsz), BYTE_TO_MB(spp->pgs_per_line * spp->pgsz),
		BYTE_TO_KB(spp->pgs_per_line * spp->pgsz));
}

static void ssd_init_nand_page(struct nand_page *pg, struct ssdparams *spp)
{
	int i;
	pg->nsecs = spp->secs_per_pg;
	pg->sec = kmalloc(sizeof(nand_sec_status_t) * pg->nsecs, GFP_KERNEL);
	for (i = 0; i < pg->nsecs; i++) {
		pg->sec[i] = SEC_FREE;
	}
	pg->status = PG_FREE;
}

static void ssd_remove_nand_page(struct nand_page *pg)
{
	kfree(pg->sec);
}

static void ssd_init_nand_blk(struct nand_block *blk, struct ssdparams *spp)
{
	int i;
	blk->npgs = spp->pgs_per_blk;
	blk->pg = kmalloc(sizeof(struct nand_page) * blk->npgs, GFP_KERNEL);
	for (i = 0; i < blk->npgs; i++) {
		ssd_init_nand_page(&blk->pg[i], spp);
	}
	blk->ipc = 0;
	blk->vpc = 0;
	blk->erase_cnt = 0;
	blk->wp = 0;
}

static void ssd_remove_nand_blk(struct nand_block *blk)
{
	int i;

	for (i = 0; i < blk->npgs; i++)
		ssd_remove_nand_page(&blk->pg[i]);

	kfree(blk->pg);
}

static void ssd_init_nand_plane(struct nand_plane *pl, struct ssdparams *spp)
{
	int i;
	pl->nblks = spp->blks_per_pl;
	pl->blk = kmalloc(sizeof(struct nand_block) * pl->nblks, GFP_KERNEL);
	for (i = 0; i < pl->nblks; i++) {
		ssd_init_nand_blk(&pl->blk[i], spp);
	}
}

static void ssd_remove_nand_plane(struct nand_plane *pl)
{
	int i;

	for (i = 0; i < pl->nblks; i++)
		ssd_remove_nand_blk(&pl->blk[i]);

	kfree(pl->blk);
}

static void ssd_init_nand_lun(struct nand_lun *lun, struct ssdparams *spp)
{
	int i;
	lun->npls = spp->pls_per_lun;
	lun->pl = kmalloc(sizeof(struct nand_plane) * lun->npls, GFP_KERNEL);
	for (i = 0; i < lun->npls; i++) {
		ssd_init_nand_plane(&lun->pl[i], spp);
	}
	lun->next_lun_avail_time = 0;
	lun->busy = false;
}

static void ssd_remove_nand_lun(struct nand_lun *lun)
{
	int i;

	for (i = 0; i < lun->npls; i++)
		ssd_remove_nand_plane(&lun->pl[i]);

	kfree(lun->pl);
}

static void ssd_init_ch(struct ssd_channel *ch, struct ssdparams *spp)
{
	int i;
	ch->nluns = spp->luns_per_ch;
	ch->lun = kmalloc(sizeof(struct nand_lun) * ch->nluns, GFP_KERNEL);
	for (i = 0; i < ch->nluns; i++) {
		ssd_init_nand_lun(&ch->lun[i], spp);
	}

	ch->perf_model = kmalloc(sizeof(struct channel_model), GFP_KERNEL);
	chmodel_init(ch->perf_model, spp->ch_bandwidth);

	/* Add firmware overhead */
	ch->perf_model->xfer_lat += (spp->fw_ch_xfer_lat * UNIT_XFER_SIZE / KB(4));
}

static void ssd_remove_ch(struct ssd_channel *ch)
{
	int i;

	kfree(ch->perf_model);

	for (i = 0; i < ch->nluns; i++)
		ssd_remove_nand_lun(&ch->lun[i]);

	kfree(ch->lun);
}

static void ssd_init_pcie(struct ssd_pcie *pcie, struct ssdparams *spp)
{
	pcie->perf_model = kmalloc(sizeof(struct channel_model), GFP_KERNEL);
	chmodel_init(pcie->perf_model, spp->pcie_bandwidth);
}

static void ssd_remove_pcie(struct ssd_pcie *pcie)
{
	kfree(pcie->perf_model);
}

void ssd_init(struct ssd *ssd, struct ssdparams *spp, uint32_t cpu_nr_dispatcher)
{
	uint32_t i;
	/* copy spp */
	ssd->sp = *spp;

	/* initialize conv_ftl internal layout architecture */
	ssd->ch = kmalloc(sizeof(struct ssd_channel) * spp->nchs, GFP_KERNEL); // 40 * 8 = 320
	for (i = 0; i < spp->nchs; i++) {
		ssd_init_ch(&(ssd->ch[i]), spp);
	}

	/* Set CPU number to use same cpuclock as io.c */
	ssd->cpu_nr_dispatcher = cpu_nr_dispatcher;

	ssd->pcie = kmalloc(sizeof(struct ssd_pcie), GFP_KERNEL);
	ssd_init_pcie(ssd->pcie, spp);

	ssd->write_buffer = kmalloc(sizeof(struct buffer), GFP_KERNEL);
	buffer_init(ssd->write_buffer, spp->write_buffer_size);

	return;
}

void ssd_remove(struct ssd *ssd)
{
	uint32_t i;

	kfree(ssd->write_buffer);
	if (ssd->pcie) {
		kfree(ssd->pcie->perf_model);
		kfree(ssd->pcie);
	}

	for (i = 0; i < ssd->sp.nchs; i++) {
		ssd_remove_ch(&(ssd->ch[i]));
	}

	kfree(ssd->ch);
}

uint64_t ssd_advance_pcie(struct ssd *ssd, uint64_t request_time, uint64_t length)
{
	struct channel_model *perf_model = ssd->pcie->perf_model;
	return chmodel_request(perf_model, request_time, length);
}

/* Write buffer Performance Model
  Y = A + (B * X)
  Y : latency (ns)
  X : transfer size (4KB unit)
  A : fw_wbuf_lat0
  B : fw_wbuf_lat1 + pcie dma transfer
*/
uint64_t ssd_advance_write_buffer(struct ssd *ssd, uint64_t request_time, uint64_t length)
{
	uint64_t nsecs_latest = request_time;
	struct ssdparams *spp = &ssd->sp;

	nsecs_latest += spp->fw_wbuf_lat0;
	nsecs_latest += spp->fw_wbuf_lat1 * DIV_ROUND_UP(length, KB(4));

	nsecs_latest = ssd_advance_pcie(ssd, nsecs_latest, length);

	return nsecs_latest;
}

uint64_t ssd_advance_nand(struct ssd *ssd, struct nand_cmd *ncmd)
{
	int c = ncmd->cmd;
	uint64_t cmd_stime = (ncmd->stime == 0) ? __get_ioclock(ssd) : ncmd->stime;
	uint64_t nand_stime, nand_etime;
	uint64_t chnl_stime, chnl_etime;
	uint64_t remaining, xfer_size, completed_time;
	struct ssdparams *spp;
	struct nand_lun *lun;
	struct ssd_channel *ch;
	struct ppa *ppa = ncmd->ppa;
	uint32_t cell;
	uint32_t storage_type;
	NVMEV_DEBUG(
		"SSD: %p, Enter stime: %lld, ch %d lun %d blk %d page %d command %d ppa 0x%llx\n",
		ssd, ncmd->stime, ppa->g.ch, ppa->g.lun, ppa->g.blk, ppa->g.pg, c, ppa->ppa);

	if (ppa->ppa == UNMAPPED_PPA) {
		NVMEV_ERROR("Error ppa 0x%llx\n", ppa->ppa);
		return cmd_stime;
	}

	spp = &ssd->sp;
	lun = get_lun(ssd, ppa);
	ch = get_ch(ssd, ppa);
#if (BASE_SSD == HYBRID_SSD)
	storage_type = get_storage_type(ssd, ppa);
#else
	storage_type = STORAGE_TYPE_SLC; /* Default for non-hybrid */
#endif
	
	remaining = ncmd->xfer_size;

	switch (c) {
	case NAND_READ:
		/* read: perform NAND cmd first */
		nand_stime = max(lun->next_lun_avail_time, cmd_stime);

#if (BASE_SSD == HYBRID_SSD)
		if (storage_type == STORAGE_TYPE_SLC) {
			/* SLC read latency */
			nand_etime = nand_stime + spp->slc_read_latency;
		} else { /* QLC */
			uint32_t qlc_region = get_qlc_region(ssd, ppa);
			
			/* QLC read latency based on region */
			switch (qlc_region) {
			case 0: /* Q1 */
				nand_etime = nand_stime + spp->qlc_q1_read_latency;
				break;
			case 1: /* Q2 */
				nand_etime = nand_stime + spp->qlc_q2_read_latency;
				break;
			case 2: /* Q3 */
				nand_etime = nand_stime + spp->qlc_q3_read_latency;
				break;
			case 3: /* Q4 */
				nand_etime = nand_stime + spp->qlc_q4_read_latency;
				break;
			default:
				nand_etime = nand_stime + spp->qlc_q1_read_latency; /* fallback to Q1 */
				break;
			}
		}
#else
		/* Default latency for non-hybrid SSDs */
		nand_etime = nand_stime + spp->slc_read_latency;
#endif

		/* read: then data transfer through channel */
		chnl_stime = nand_etime;

		while (remaining) {
			xfer_size = min(remaining, (uint64_t)spp->max_ch_xfer_size);
			chnl_etime = chmodel_request(ch->perf_model, chnl_stime, xfer_size);

			if (ncmd->interleave_pci_dma) { /* overlap pci transfer with nand ch transfer*/
				completed_time = ssd_advance_pcie(ssd, chnl_etime, xfer_size);
			} else {
				completed_time = chnl_etime;
			}

			remaining -= xfer_size;
			chnl_stime = chnl_etime;
		}

		lun->next_lun_avail_time = chnl_etime;
		break;

	case NAND_WRITE:
		/* write: transfer data through channel first */
		chnl_stime = max(lun->next_lun_avail_time, cmd_stime);

		chnl_etime = chmodel_request(ch->perf_model, chnl_stime, ncmd->xfer_size);

		/* write: then do NAND program */
		nand_stime = chnl_etime;
#if (BASE_SSD == HYBRID_SSD)
		if (storage_type == STORAGE_TYPE_SLC) {
			nand_etime = nand_stime + spp->slc_pg_wr_lat;
		} else { /* QLC */
			nand_etime = nand_stime + spp->qlc_pg_wr_lat;
		}
#else
		nand_etime = nand_stime + spp->pg_wr_lat;
#endif
		lun->next_lun_avail_time = nand_etime;
		completed_time = nand_etime;
		break;

	case NAND_ERASE:
		/* erase: only need to advance NAND status */
		nand_stime = max(lun->next_lun_avail_time, cmd_stime);
#if (BASE_SSD == HYBRID_SSD)
		if (storage_type == STORAGE_TYPE_SLC) {
			nand_etime = nand_stime + spp->slc_blk_er_lat;
		} else { /* QLC */
			nand_etime = nand_stime + spp->qlc_blk_er_lat;
		}
#else
		nand_etime = nand_stime + spp->blk_er_lat;
#endif
		lun->next_lun_avail_time = nand_etime;
		completed_time = nand_etime;
		break;

	case NAND_NOP:
		/* no operation: just return last completed time of lun */
		nand_stime = max(lun->next_lun_avail_time, cmd_stime);
		lun->next_lun_avail_time = nand_stime;
		completed_time = nand_stime;
		break;

	default:
		NVMEV_ERROR("Unsupported NAND command: 0x%x\n", c);
		return 0;
	}

	return completed_time;
}

uint64_t ssd_next_idle_time(struct ssd *ssd)
{
	struct ssdparams *spp = &ssd->sp;
	uint32_t i, j;
	uint64_t latest = __get_ioclock(ssd);

	for (i = 0; i < spp->nchs; i++) {
		struct ssd_channel *ch = &ssd->ch[i];

		for (j = 0; j < spp->luns_per_ch; j++) {
			struct nand_lun *lun = &ch->lun[j];
			latest = max(latest, lun->next_lun_avail_time);
		}
	}

	return latest;
}

void adjust_ftl_latency(int target, int lat)
{
/* TODO ..*/
#if 0
    struct ssdparams *spp;
    int i;

    for (i = 0; i < SSD_PARTITIONS; i++) {
        spp = &(g_conv_ftls[i].sp);
        NVMEV_INFO("Before latency: %d %d %d, change to %d\n", spp->pg_rd_lat, spp->pg_wr_lat, spp->blk_er_lat, lat);
        switch (target) {
            case NAND_READ:
                spp->pg_rd_lat = lat;
                break;

            case NAND_WRITE:
                spp->pg_wr_lat = lat;
                break;

            case NAND_ERASE:
                spp->blk_er_lat = lat;
                break;

            default:
                NVMEV_ERROR("Unsupported NAND command\n");
        }
        NVMEV_INFO("After latency: %d %d %d\n", spp->pg_rd_lat, spp->pg_wr_lat, spp->blk_er_lat);
    }
#endif
}
