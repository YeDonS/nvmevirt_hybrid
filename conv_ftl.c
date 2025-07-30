// SPDX-License-Identifier: GPL-2.0-only

#include <linux/ktime.h>
#include <linux/sched/clock.h>

#include "nvmev.h"
#include "conv_ftl.h"

void enqueue_writeback_io_req(int sqid, unsigned long long nsecs_target,
			      struct buffer *write_buffer, unsigned int buffs_to_release);

static inline bool last_pg_in_wordline(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	return (ppa->g.pg % spp->pgs_per_oneshotpg) == (spp->pgs_per_oneshotpg - 1);
}

static bool should_gc(struct conv_ftl *conv_ftl)
{
	return (conv_ftl->lm.free_line_cnt <= conv_ftl->cp.gc_thres_lines);
}

static inline bool should_gc_high(struct conv_ftl *conv_ftl)
{
	return conv_ftl->lm.free_line_cnt <= conv_ftl->cp.gc_thres_lines_high;
}

static inline struct ppa get_maptbl_ent(struct conv_ftl *conv_ftl, uint64_t lpn)
{
	return conv_ftl->maptbl[lpn];
}

static inline void set_maptbl_ent(struct conv_ftl *conv_ftl, uint64_t lpn, struct ppa *ppa)
{
	NVMEV_ASSERT(lpn < conv_ftl->ssd->sp.tt_pgs);
	conv_ftl->maptbl[lpn] = *ppa;
}

static uint64_t ppa2pgidx(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	uint64_t pgidx;

	NVMEV_DEBUG("ppa2pgidx: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d\n", ppa->g.ch, ppa->g.lun,
		    ppa->g.pl, ppa->g.blk, ppa->g.pg);

	pgidx = ppa->g.ch * spp->pgs_per_ch + ppa->g.lun * spp->pgs_per_lun +
		ppa->g.pl * spp->pgs_per_pl + ppa->g.blk * spp->pgs_per_blk + ppa->g.pg;

	NVMEV_ASSERT(pgidx < spp->tt_pgs);

	return pgidx;
}

static inline uint64_t get_rmap_ent(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	uint64_t pgidx = ppa2pgidx(conv_ftl, ppa);

	return conv_ftl->rmap[pgidx];
}

/* set rmap[page_no(ppa)] -> lpn */
static inline void set_rmap_ent(struct conv_ftl *conv_ftl, uint64_t lpn, struct ppa *ppa)
{
	uint64_t pgidx = ppa2pgidx(conv_ftl, ppa);

	conv_ftl->rmap[pgidx] = lpn;
}

static inline int victim_line_cmp_pri(pqueue_pri_t next, pqueue_pri_t curr)
{
	return (next > curr);
}

static inline pqueue_pri_t victim_line_get_pri(void *a)
{
	return ((struct line *)a)->vpc;
}

static inline void victim_line_set_pri(void *a, pqueue_pri_t pri)
{
	((struct line *)a)->vpc = pri;
}

static inline size_t victim_line_get_pos(void *a)
{
	return ((struct line *)a)->pos;
}

static inline void victim_line_set_pos(void *a, size_t pos)
{
	((struct line *)a)->pos = pos;
}

static inline void consume_write_credit(struct conv_ftl *conv_ftl)
{
	conv_ftl->wfc.write_credits--;
}

static void forground_gc(struct conv_ftl *conv_ftl);

static inline void check_and_refill_write_credit(struct conv_ftl *conv_ftl)
{
	struct write_flow_control *wfc = &(conv_ftl->wfc);
	if (wfc->write_credits <= 0) {
		forground_gc(conv_ftl);

		wfc->write_credits += wfc->credits_to_refill;
	}
}

static void init_lines(struct conv_ftl *conv_ftl)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct line_mgmt *lm = &conv_ftl->lm;
	struct line *line;
	int i;

	lm->tt_lines = spp->blks_per_pl;
	NVMEV_ASSERT(lm->tt_lines == spp->tt_lines);
	lm->lines = vmalloc(sizeof(struct line) * lm->tt_lines);

	INIT_LIST_HEAD(&lm->free_line_list);
	INIT_LIST_HEAD(&lm->full_line_list);

	lm->victim_line_pq = pqueue_init(spp->tt_lines, victim_line_cmp_pri, victim_line_get_pri,
					 victim_line_set_pri, victim_line_get_pos,
					 victim_line_set_pos);

	lm->free_line_cnt = 0;
	for (i = 0; i < lm->tt_lines; i++) {
		lm->lines[i] = (struct line) {
			.id = i,
			.ipc = 0,
			.vpc = 0,
			.pos = 0,
			.entry = LIST_HEAD_INIT(lm->lines[i].entry),
		};

		/* initialize all the lines as free lines */
		list_add_tail(&lm->lines[i].entry, &lm->free_line_list);
		lm->free_line_cnt++;
	}

	NVMEV_ASSERT(lm->free_line_cnt == lm->tt_lines);
	lm->victim_line_cnt = 0;
	lm->full_line_cnt = 0;
}

//66f1
static void init_lines_DA(struct conv_ftl *conv_ftl)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	uint32_t luncount = conv_ftl->ssd->sp.luns_per_ch * conv_ftl->ssd->sp.nchs;
	uint32_t lun=0;
	for( lun=0; lun < luncount; lun++ )
	{
		struct line_mgmt *lm = (conv_ftl->lunlm+lun);
		struct line *line;
		int i;

		lm->tt_lines = spp->blks_per_pl;
		NVMEV_ASSERT(lm->tt_lines == spp->tt_lines);
		lm->lines = vmalloc(sizeof(struct line) * lm->tt_lines);

		INIT_LIST_HEAD(&lm->free_line_list);
		INIT_LIST_HEAD(&lm->full_line_list);

		lm->victim_line_pq = pqueue_init(spp->tt_lines, victim_line_cmp_pri, victim_line_get_pri,
						victim_line_set_pri, victim_line_get_pos,
						victim_line_set_pos);

		lm->free_line_cnt = 0;
		for (i = 0; i < lm->tt_lines; i++) {
			lm->lines[i] = (struct line) {
				.id = i,
				.ipc = 0,
				.vpc = 0,
				.pos = 0,
				.entry = LIST_HEAD_INIT(lm->lines[i].entry),
			};

			/* initialize all the lines as free lines */
			list_add_tail(&lm->lines[i].entry, &lm->free_line_list);
			lm->free_line_cnt++;
		}

		NVMEV_ASSERT(lm->free_line_cnt == lm->tt_lines);
		lm->victim_line_cnt = 0;
		lm->full_line_cnt = 0;

	}
}
//66f1

static void remove_lines(struct conv_ftl *conv_ftl)
{
	pqueue_free(conv_ftl->lm.victim_line_pq);
	vfree(conv_ftl->lm.lines);
}

static void remove_lines_DA(struct conv_ftl *conv_ftl)
{
	uint32_t luncount = conv_ftl->ssd->sp.luns_per_ch * conv_ftl->ssd->sp.nchs;
	uint32_t lun=0;
	for( lun=0; lun < luncount; lun++ )
	{
		struct line_mgmt *lm = (conv_ftl->lunlm+lun);
		pqueue_free(lm->victim_line_pq);
		vfree(lm->lines);
	}
}

static void init_write_flow_control(struct conv_ftl *conv_ftl)
{
	struct write_flow_control *wfc = &(conv_ftl->wfc);
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	wfc->write_credits = spp->pgs_per_line;
	wfc->credits_to_refill = spp->pgs_per_line;
}

static inline void check_addr(int a, int max)
{
	NVMEV_ASSERT(a >= 0 && a < max);
}

static struct line *get_next_free_line(struct conv_ftl *conv_ftl)
{
	struct line_mgmt *lm = &conv_ftl->lm;
	struct line *curline = list_first_entry_or_null(&lm->free_line_list, struct line, entry);

	if (!curline) {
		NVMEV_ERROR("No free line left in VIRT !!!!\n");
		return NULL;
	}

	list_del_init(&curline->entry);
	lm->free_line_cnt--;
	NVMEV_DEBUG("[%s] free_line_cnt %d\n", __FUNCTION__, lm->free_line_cnt);
	return curline;
}

//66f1
static struct line *get_next_free_line_DA(struct conv_ftl *conv_ftl, uint32_t lun)
{
	struct line_mgmt *lm = conv_ftl->lunlm+lun;
	struct line *curline = list_first_entry_or_null(&lm->free_line_list, struct line, entry);

	if (!curline) {
		NVMEV_ERROR("No free line left in VIRT !!!!\n");
		return NULL;
	}

	list_del_init(&curline->entry);
	lm->free_line_cnt--;
	NVMEV_DEBUG("[%s] free_line_cnt %d\n", __FUNCTION__, lm->free_line_cnt);
	return curline;
}
//66f1

static struct write_pointer *__get_wp(struct conv_ftl *ftl, uint32_t io_type)
{
	if (io_type == USER_IO) {
		return &ftl->wp;
	} else if (io_type == GC_IO) {
		return &ftl->gc_wp;
	}

	NVMEV_ASSERT(0);
	return NULL;
}
//66f1
static struct write_pointer *__get_wp_DA(struct conv_ftl *ftl, uint32_t io_type, uint32_t lun)
{
	if (io_type == USER_IO) {
		return (ftl->lunwp+lun);
	} else if (io_type == GC_IO) {
		return &ftl->gc_wp;
	}

	NVMEV_ASSERT(0);
	return NULL;
}
//66f1

static void prepare_write_pointer(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	struct write_pointer *wp = __get_wp(conv_ftl, io_type);
	struct line *curline = get_next_free_line(conv_ftl);

	NVMEV_ASSERT(wp);
	NVMEV_ASSERT(curline);

	/* wp->curline is always our next-to-write super-block */
	*wp = (struct write_pointer) {
		.curline = curline,
		.ch = 0,
		.lun = 0,
		.pg = 0,
		.blk = curline->id,
		.pl = 0,
	};
}

//66f1
static void prepare_write_pointer_DA(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	uint32_t luncount = conv_ftl->ssd->sp.luns_per_ch * conv_ftl->ssd->sp.nchs;
	uint32_t lun=0;
	for( lun=0; lun < luncount; lun++ )
	{
		struct line *curline = get_next_free_line_DA(conv_ftl, lun);
		struct write_pointer *wp = __get_wp_DA(conv_ftl, io_type, lun);
		uint32_t localch = lun % conv_ftl->ssd->sp.nchs;
		uint32_t locallun = lun / conv_ftl->ssd->sp.nchs;

		NVMEV_ASSERT(wp);
		NVMEV_ASSERT(curline);

		/* wp->curline is always our next-to-write super-block */
		*wp = (struct write_pointer) {
			.curline = curline,
			.ch = localch,
			.lun = locallun,
			.pg = 0,
			.blk = curline->id,
			.pl = 0,
			};		
	}

	//debug wpp
	for( lun=0; lun < luncount; lun++ )
	{
		struct write_pointer *wp = __get_wp_DA(conv_ftl, io_type, lun);

		//NVMEV_ERROR("wpp lun:%d, ch: %d, lun: %d\n", lun, wp->ch, wp->lun);
	}

}
//66f1

static void advance_write_pointer(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct line_mgmt *lm = &conv_ftl->lm;
	struct write_pointer *wpp = __get_wp(conv_ftl, io_type);

	NVMEV_DEBUG("current wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d\n", wpp->ch, wpp->lun,
		    wpp->pl, wpp->blk, wpp->pg);

	check_addr(wpp->pg, spp->pgs_per_blk);
	wpp->pg++;
	if ((wpp->pg % spp->pgs_per_oneshotpg) != 0)
		goto out;

	wpp->pg -= spp->pgs_per_oneshotpg;
	check_addr(wpp->ch, spp->nchs);
	wpp->ch++;
	if (wpp->ch != spp->nchs)
		goto out;

	wpp->ch = 0;
	check_addr(wpp->lun, spp->luns_per_ch);
	wpp->lun++;
	/* in this case, we should go to next lun */
	if (wpp->lun != spp->luns_per_ch)
		goto out;

	wpp->lun = 0;
	/* go to next wordline in the block */
	wpp->pg += spp->pgs_per_oneshotpg;
	if (wpp->pg != spp->pgs_per_blk)
		goto out;

	wpp->pg = 0;
	/* move current line to {victim,full} line list */
	if (wpp->curline->vpc == spp->pgs_per_line) {
		/* all pgs are still valid, move to full line list */
		NVMEV_ASSERT(wpp->curline->ipc == 0);
		list_add_tail(&wpp->curline->entry, &lm->full_line_list);
		lm->full_line_cnt++;
		NVMEV_DEBUG("wpp: move line to full_line_list\n");
	} else {
		NVMEV_DEBUG("wpp: line is moved to victim list\n");
		NVMEV_ASSERT(wpp->curline->vpc >= 0 && wpp->curline->vpc < spp->pgs_per_line);
		/* there must be some invalid pages in this line */
		NVMEV_ASSERT(wpp->curline->ipc > 0);
		pqueue_insert(lm->victim_line_pq, wpp->curline);
		lm->victim_line_cnt++;
	}
	/* current line is used up, pick another empty line */
	check_addr(wpp->blk, spp->blks_per_pl);
	wpp->curline = get_next_free_line(conv_ftl);
	NVMEV_DEBUG("wpp: got new clean line %d\n", wpp->curline->id);

	wpp->blk = wpp->curline->id;
	check_addr(wpp->blk, spp->blks_per_pl);

	/* make sure we are starting from page 0 in the super block */
	NVMEV_ASSERT(wpp->pg == 0);
	NVMEV_ASSERT(wpp->lun == 0);
	NVMEV_ASSERT(wpp->ch == 0);
	/* TODO: assume # of pl_per_lun is 1, fix later */
	NVMEV_ASSERT(wpp->pl == 0);
out:
	NVMEV_DEBUG("advanced wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d (curline %d)\n", wpp->ch,
		    wpp->lun, wpp->pl, wpp->blk, wpp->pg, wpp->curline->id);
}

//66f1
static void advance_write_pointer_DA(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	uint32_t glun=conv_ftl->lunpointer;	
	struct ssdparams *spp = &conv_ftl->ssd->sp;	
	struct line_mgmt *lm = NULL;
	struct write_pointer *wpp = NULL;

#if (BASE_SSD == HYBRID_SSD)
	/* For hybrid SSD, limit DA strategy to SLC channels only */
	uint32_t max_slc_luns = spp->slc_channels * spp->slc_luns_per_ch;
#endif

	lm = conv_ftl->lunlm+conv_ftl->lunpointer;
	wpp = __get_wp_DA(conv_ftl, io_type, conv_ftl->lunpointer);

	NVMEV_DEBUG("current wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d, glun:%d\n", wpp->ch, wpp->lun,
		    wpp->pl, wpp->blk, wpp->pg, conv_ftl->lunpointer);

	
#if (BASE_SSD == HYBRID_SSD)
	/* Use SLC-specific parameters for page checking */
	check_addr(wpp->pg, spp->slc_pgs_per_blk);
#else
	check_addr(wpp->pg, spp->pgs_per_blk);
#endif
	wpp->pg++; //map page 4k
#if (BASE_SSD == HYBRID_SSD)
	if ((wpp->pg % spp->slc_pgs_per_oneshotpg) != 0)
#else
	if ((wpp->pg % spp->pgs_per_oneshotpg) != 0)
#endif
	{
		goto out;
	}
	NVMEV_DEBUG("page : %u, oneshotpg limit %d\n", spp->pgsz, spp->pgs_per_oneshotpg);

#if (BASE_SSD == HYBRID_SSD)
	if (wpp->pg == spp->slc_pgs_per_blk)
#else
	if (wpp->pg == spp->pgs_per_blk)
#endif
	{//move to next blk
#if (BASE_SSD == HYBRID_SSD)
		NVMEV_DEBUG("SLC block limit, slc_pgs_per_blk = %d\n", spp->slc_pgs_per_blk);
#else
		NVMEV_DEBUG("block limit, pgs_per_blk = %d\n", spp->pgs_per_blk);
#endif

		if (wpp->curline->vpc == spp->pgs_per_lun_line) {
			/* all pgs are still valid, move to full line list */
			NVMEV_ASSERT(wpp->curline->ipc == 0);
			list_add_tail(&wpp->curline->entry, &lm->full_line_list);
			lm->full_line_cnt++;
			NVMEV_DEBUG("wpp: move line to full_line_list\n");
			//NVMEV_ERROR("wpp: move line to full_line_list\n");
		} else {
			NVMEV_DEBUG("wpp: line is moved to victim list\n");
			//NVMEV_ERROR("wpp: line is moved to victim list\n");
			NVMEV_ASSERT(wpp->curline->vpc >= 0 && wpp->curline->vpc < spp->pgs_per_lun_line);
			/* there must be some invalid pages in this line */
			//NVMEV_ERROR("wpp: curline ipc= %d\n", wpp->curline->ipc);
			NVMEV_ASSERT(wpp->curline->ipc > 0);
			pqueue_insert(lm->victim_line_pq, wpp->curline);
			lm->victim_line_cnt++;
		}
		/* current line is used up, pick another empty line */
#if (BASE_SSD == HYBRID_SSD)
		check_addr(wpp->blk, spp->slc_blks_per_pl);
#else
		check_addr(wpp->blk, spp->blks_per_pl);
#endif
		wpp->curline = get_next_free_line_DA(conv_ftl, conv_ftl->lunpointer);
		NVMEV_DEBUG("wpp: got new clean line %d\n", wpp->curline->id);
		//NVMEV_ERROR("wpp: got new clean line %d\n", wpp->curline->id);

		wpp->blk = wpp->curline->id;
#if (BASE_SSD == HYBRID_SSD)
		check_addr(wpp->blk, spp->slc_blks_per_pl);
#else
		check_addr(wpp->blk, spp->blks_per_pl);
#endif
		wpp->pg =0;
	}

	//ch die interleaving - Modified for hybrid SSD
	glun++;
#if (BASE_SSD == HYBRID_SSD)
	/* For hybrid SSD, only cycle through SLC LUNs */
	if (glun != max_slc_luns)
#else
	if (glun != conv_ftl->ssd->sp.nchs * conv_ftl->ssd->sp.luns_per_ch)
#endif
	{
		conv_ftl->lunpointer = glun; //next write lun 
		lm = conv_ftl->lunlm+conv_ftl->lunpointer;
		wpp = __get_wp_DA(conv_ftl, io_type, conv_ftl->lunpointer);
		
		//NVMEV_ERROR("wpp ch : %u, lun %d\n", wpp->ch, wpp->lun);
		goto out;
	}

	//NVMEV_ERROR("lun limit\n");
	glun=0;	
	conv_ftl->lunpointer = glun; //next write lun 
	lm = conv_ftl->lunlm+conv_ftl->lunpointer;
	wpp = __get_wp_DA(conv_ftl, io_type, conv_ftl->lunpointer);
	
out:
	NVMEV_DEBUG("advanced wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d (curline %d)\n", wpp->ch,
		    wpp->lun, wpp->pl, wpp->blk, wpp->pg, wpp->curline->id);
}

/* New function: QLC-specific write pointer advancement using traditional round-robin */
static void advance_write_pointer_QLC(struct conv_ftl *conv_ftl, uint32_t io_type)
{
#if (BASE_SSD == HYBRID_SSD)
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct write_pointer *wpp = __get_wp(conv_ftl, io_type);

	NVMEV_DEBUG("QLC current wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d\n", wpp->ch, wpp->lun,
		    wpp->pl, wpp->blk, wpp->pg);

	/* Use QLC-specific parameters */
	check_addr(wpp->pg, spp->qlc_pgs_per_blk);
	wpp->pg++;
	if ((wpp->pg % spp->qlc_pgs_per_oneshotpg) != 0) {
		goto out;
	}

	if (wpp->pg == spp->qlc_pgs_per_blk) {
		NVMEV_DEBUG("QLC block limit, qlc_pgs_per_blk = %d\n", spp->qlc_pgs_per_blk);
		wpp->blk++;
		check_addr(wpp->blk, spp->qlc_blks_per_pl);
		wpp->pg = 0;
		if (wpp->blk == spp->qlc_blks_per_pl) {
			wpp->blk = 0;
			wpp->pl++;
			check_addr(wpp->pl, spp->pls_per_lun);
			if (wpp->pl == spp->pls_per_lun) {
				wpp->pl = 0;
				wpp->lun++;
				check_addr(wpp->lun, spp->qlc_luns_per_ch);
				if (wpp->lun == spp->qlc_luns_per_ch) {
					wpp->lun = 0;
					wpp->ch++;
					/* QLC channels start after SLC channels */
					if (wpp->ch >= (spp->slc_channels + spp->qlc_channels)) {
						wpp->ch = spp->slc_channels; /* Reset to first QLC channel */
					}
				}
			}
		}
	}

out:
	NVMEV_DEBUG("QLC advanced wpp: ch:%d, lun:%d, pl:%d, blk:%d, pg:%d\n", wpp->ch, wpp->lun,
		    wpp->pl, wpp->blk, wpp->pg);
#endif
}
//66f1

static struct ppa get_new_page(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	struct ppa ppa;
	struct write_pointer *wp = __get_wp(conv_ftl, io_type);
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	ppa.ppa = 0;
#if (BASE_SSD == HYBRID_SSD)
	/* For hybrid storage, this function is used for QLC migration */
	/* QLC channels start after SLC channels (channels 2-7) */
	ppa.g.ch = spp->slc_channels + (wp->ch % spp->qlc_channels);
	ppa.g.lun = wp->lun % spp->qlc_luns_per_ch;
	
	/* Ensure we're in QLC channel range */
	NVMEV_ASSERT(ppa.g.ch >= spp->slc_channels);
	NVMEV_ASSERT(ppa.g.ch < (spp->slc_channels + spp->qlc_channels));
#else
	ppa.g.ch = wp->ch;
	ppa.g.lun = wp->lun;
#endif
	ppa.g.pl = wp->pl;
	ppa.g.blk = wp->blk;
	ppa.g.pg = wp->pg;

	return ppa;
}

static struct ppa get_new_page_DA(struct conv_ftl *conv_ftl, uint32_t io_type)
{
	struct ppa ppa;
	struct write_pointer *wp = __get_wp_DA(conv_ftl, io_type, conv_ftl->lunpointer);
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	ppa.ppa = 0;
#if (BASE_SSD == HYBRID_SSD)
	/* For hybrid SSD, DA strategy is used for SLC only (channels 0-1) */
	ppa.g.ch = wp->ch % spp->slc_channels;  /* Ensure SLC channels only */
	ppa.g.lun = wp->lun % spp->slc_luns_per_ch;
	
	/* Ensure we're in SLC channel range */
	NVMEV_ASSERT(ppa.g.ch < spp->slc_channels);
#else
	ppa.g.ch = wp->ch;
	ppa.g.lun = wp->lun;
#endif
	ppa.g.pg = wp->pg;
	ppa.g.blk = wp->blk;
	ppa.g.pl = wp->pl;

	NVMEV_ASSERT(ppa.g.pl == 0);

	return ppa;
}


static void init_maptbl(struct conv_ftl *conv_ftl)
{
	int i;
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	conv_ftl->maptbl = vmalloc(sizeof(struct ppa) * spp->tt_pgs);
	for (i = 0; i < spp->tt_pgs; i++) {
		conv_ftl->maptbl[i].ppa = UNMAPPED_PPA;
	}
}

static void remove_maptbl(struct conv_ftl *conv_ftl)
{
	vfree(conv_ftl->maptbl);
}

static void init_rmap(struct conv_ftl *conv_ftl)
{
	int i;
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	conv_ftl->rmap = vmalloc(sizeof(uint64_t) * spp->tt_pgs);
	for (i = 0; i < spp->tt_pgs; i++) {
		conv_ftl->rmap[i] = INVALID_LPN;
	}
}

static void remove_rmap(struct conv_ftl *conv_ftl)
{
	vfree(conv_ftl->rmap);
}

static void conv_init_ftl(struct conv_ftl *conv_ftl, struct convparams *cpp, struct ssd *ssd)
{
	struct ssdparams *spp = &ssd->sp;

	conv_ftl->ssd = ssd;
	conv_ftl->cp = *cpp;

	/* initialize maptbl */
	init_maptbl(conv_ftl);

	/* initialize rmap */
	init_rmap(conv_ftl);

	/* initialize write pointer */
	conv_ftl->wp = (struct write_pointer) {
		.curline = NULL,
		.ch = 0,
		.lun = 0,
		.pg = 0,
		.blk = 0,
		.pl = 0,
	};

	conv_ftl->gc_wp = (struct write_pointer) {
		.curline = NULL,
		.ch = 0,
		.lun = 0,
		.pg = 0,
		.blk = 0,
		.pl = 0,
	};

	/* initialize line management */
	init_lines(conv_ftl);

	/* initialize write flow control */
	init_write_flow_control(conv_ftl);

#if (BASE_SSD == HYBRID_SSD)
	/* Initialize hotness tracking */
	init_hotness_tracking(conv_ftl);
	
	/* Initialize DA strategy for hybrid storage */
	init_lines_DA(conv_ftl);
	conv_ftl->lunpointer = 0;
#endif

	/* prepare write pointer */
	prepare_write_pointer(conv_ftl, USER_IO);
	prepare_write_pointer(conv_ftl, GC_IO);
}

static void conv_remove_ftl(struct conv_ftl *conv_ftl)
{
	remove_maptbl(conv_ftl);
	remove_rmap(conv_ftl);
	remove_lines(conv_ftl);

#if (BASE_SSD == HYBRID_SSD)
	/* Remove hotness tracking */
	remove_hotness_tracking(conv_ftl);
	
	/* Remove DA strategy resources */
	remove_lines_DA(conv_ftl);
#endif
}

static void conv_init_params(struct convparams *cpp)
{
	cpp->op_area_pcent = OP_AREA_PERCENT;
	cpp->gc_thres_lines = 2; /* Need only two lines.(host write, gc)*/
	cpp->gc_thres_lines_high = 2; /* Need only two lines.(host write, gc)*/
	cpp->enable_gc_delay = 1;
	cpp->pba_pcent = (int)((1 + cpp->op_area_pcent) * 100);
}

void conv_init_namespace(struct nvmev_ns *ns, uint32_t id, uint64_t size, void *mapped_addr,
			 uint32_t cpu_nr_dispatcher)
{
	struct ssdparams spp;
	struct convparams cpp;
	struct conv_ftl *conv_ftls;
	struct ssd *ssd;
	uint32_t i;
	const uint32_t nr_parts = SSD_PARTITIONS;

	ssd_init_params(&spp, size, nr_parts);
	conv_init_params(&cpp);

	conv_ftls = kmalloc(sizeof(struct conv_ftl) * nr_parts, GFP_KERNEL);

	for (i = 0; i < nr_parts; i++) {
//66f1
		conv_ftls[i].lunlm = kmalloc(sizeof(struct line_mgmt) * NAND_CHANNELS * LUNS_PER_NAND_CH, GFP_KERNEL);
		conv_ftls[i].lunwp = kmalloc(sizeof(struct write_pointer) * NAND_CHANNELS * LUNS_PER_NAND_CH, GFP_KERNEL);
//66f1
		ssd = kmalloc(sizeof(struct ssd), GFP_KERNEL);
		ssd_init(ssd, &spp, cpu_nr_dispatcher);
		conv_init_ftl(&conv_ftls[i], &cpp, ssd);
	}

	/* PCIe, Write buffer are shared by all instances*/
	for (i = 1; i < nr_parts; i++) {
		kfree(conv_ftls[i].ssd->pcie->perf_model);
		kfree(conv_ftls[i].ssd->pcie);
		kfree(conv_ftls[i].ssd->write_buffer);

		conv_ftls[i].ssd->pcie = conv_ftls[0].ssd->pcie;
		conv_ftls[i].ssd->write_buffer = conv_ftls[0].ssd->write_buffer;
	}

	ns->id = id;
	ns->csi = NVME_CSI_NVM;
	ns->nr_parts = nr_parts;
	ns->ftls = (void *)conv_ftls;
	ns->size = (uint64_t)((size * 100) / cpp.pba_pcent);
	ns->mapped = mapped_addr;
	/*register io command handler*/
	ns->proc_io_cmd = conv_proc_nvme_io_cmd;

	NVMEV_INFO("FTL physical space: %lld, logical space: %lld (physical/logical * 100 = %d)\n",
		   size, ns->size, cpp.pba_pcent);

	return;
}

void conv_remove_namespace(struct nvmev_ns *ns)
{
	struct conv_ftl *conv_ftls = (struct conv_ftl *)ns->ftls;
	const uint32_t nr_parts = SSD_PARTITIONS;
	uint32_t i;

	/* PCIe, Write buffer are shared by all instances*/
	for (i = 1; i < nr_parts; i++) {
		/*
		 * These were freed from conv_init_namespace() already.
		 * Mark these NULL so that ssd_remove() skips it.
		 */
		conv_ftls[i].ssd->pcie = NULL;
		conv_ftls[i].ssd->write_buffer = NULL;
		
		//66f1
		kfree(conv_ftls[i].lunlm);
		kfree(conv_ftls[i].lunwp);
		//66f1
	}

	for (i = 0; i < nr_parts; i++) {
		conv_remove_ftl(&conv_ftls[i]);
		ssd_remove(conv_ftls[i].ssd);
		kfree(conv_ftls[i].ssd);
	}

	kfree(conv_ftls);
	ns->ftls = NULL;
}

static inline bool valid_ppa(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	int ch = ppa->g.ch;
	int lun = ppa->g.lun;
	int pl = ppa->g.pl;
	int blk = ppa->g.blk;
	int pg = ppa->g.pg;
	//int sec = ppa->g.sec;

	if (ch < 0 || ch >= spp->nchs)
		return false;
	if (lun < 0 || lun >= spp->luns_per_ch)
		return false;
	if (pl < 0 || pl >= spp->pls_per_lun)
		return false;
	if (blk < 0 || blk >= spp->blks_per_pl)
		return false;
	if (pg < 0 || pg >= spp->pgs_per_blk)
		return false;

	return true;
}

static inline bool valid_lpn(struct conv_ftl *conv_ftl, uint64_t lpn)
{
	return (lpn < conv_ftl->ssd->sp.tt_pgs);
}

static inline bool mapped_ppa(struct ppa *ppa)
{
	return !(ppa->ppa == UNMAPPED_PPA);
}

static inline uint32_t get_glun(struct conv_ftl *conv_ftl, struct ppa *ppa)
{	
	return (ppa->g.lun * conv_ftl->ssd->sp.nchs + ppa->g.ch);
}

static inline struct line *get_line(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	return &(conv_ftl->lm.lines[ppa->g.blk]);
}

static inline struct line *get_line_DA(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	uint32_t glun = get_glun(conv_ftl, ppa);
	struct line_mgmt *lm = conv_ftl->lunlm+glun;

	return &(lm->lines[ppa->g.blk]);
}

/* update SSD status about one page from PG_VALID -> PG_VALID */
static void mark_page_invalid(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct line_mgmt *lm = &conv_ftl->lm;
	//66f1
	uint32_t glun = get_glun(conv_ftl, ppa);
	struct line_mgmt *lunlm = conv_ftl->lunlm+glun;
	//66f1
	struct nand_block *blk = NULL;
	struct nand_page *pg = NULL;
	bool was_full_line = false;
	struct line *line;

	/* update corresponding page status */
	pg = get_pg(conv_ftl->ssd, ppa);
	NVMEV_ASSERT(pg->status == PG_VALID);
	pg->status = PG_INVALID;

	/* update corresponding block status */
	blk = get_blk(conv_ftl->ssd, ppa);
	NVMEV_ASSERT(blk->ipc >= 0 && blk->ipc < spp->pgs_per_blk);
	blk->ipc++;
	NVMEV_ASSERT(blk->vpc > 0 && blk->vpc <= spp->pgs_per_blk);
	blk->vpc--;

	/* update corresponding line status */
	line = get_line(conv_ftl, ppa);
	NVMEV_ASSERT(line->ipc >= 0 && line->ipc < spp->pgs_per_line);
	if (line->vpc == spp->pgs_per_line) {
		NVMEV_ASSERT(line->ipc == 0);
		was_full_line = true;
	}
	line->ipc++;
	NVMEV_ASSERT(line->vpc > 0 && line->vpc <= spp->pgs_per_line);
	/* Adjust the position of the victime line in the pq under over-writes */
	if (line->pos) {
		/* Note that line->vpc will be updated by this call */
		pqueue_change_priority(lm->victim_line_pq, line->vpc - 1, line);
	} else {
		line->vpc--;
	}

	if (was_full_line) {
		/* move line: "full" -> "victim" */
		list_del_init(&line->entry);
		lm->full_line_cnt--;
		pqueue_insert(lm->victim_line_pq, line);
		lm->victim_line_cnt++;
	}

	//66f1 lunlm update
	was_full_line = false;
	/* update corresponding line status */
	line = get_line_DA(conv_ftl, ppa);
	NVMEV_ASSERT(line->ipc >= 0 && line->ipc < spp->pgs_per_line);
	if (line->vpc == spp->pgs_per_line) {
		NVMEV_ASSERT(line->ipc == 0);
		was_full_line = true;
	}
	line->ipc++;
	NVMEV_ASSERT(line->vpc > 0 && line->vpc <= spp->pgs_per_line);
	/* Adjust the position of the victime line in the pq under over-writes */
	if (line->pos) {
		/* Note that line->vpc will be updated by this call */
		pqueue_change_priority(lunlm->victim_line_pq, line->vpc - 1, line);
	} else {
		line->vpc--;
	}

	if (was_full_line) {
		/* move line: "full" -> "victim" */
		list_del_init(&line->entry);
		lunlm->full_line_cnt--;
		pqueue_insert(lunlm->victim_line_pq, line);
		lunlm->victim_line_cnt++;
	}
	//66f1
}

static void mark_page_valid(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct nand_block *blk = NULL;
	struct nand_page *pg = NULL;
	struct line *line;

	/* update page status */
	pg = get_pg(conv_ftl->ssd, ppa);
	NVMEV_ASSERT(pg->status == PG_FREE);
	pg->status = PG_VALID;

	/* update corresponding block status */
	blk = get_blk(conv_ftl->ssd, ppa);
	NVMEV_ASSERT(blk->vpc >= 0 && blk->vpc < spp->pgs_per_blk);
	blk->vpc++;

	/* update corresponding line status */
	line = get_line(conv_ftl, ppa);
	NVMEV_ASSERT(line->vpc >= 0 && line->vpc < spp->pgs_per_line);
	line->vpc++;

	//66f1
	line = get_line_DA(conv_ftl, ppa);
	NVMEV_ASSERT(line->vpc >= 0 && line->vpc < spp->pgs_per_line);
	line->vpc++;
	//66f1
}

static void mark_block_free(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct nand_block *blk = get_blk(conv_ftl->ssd, ppa);
	struct nand_page *pg = NULL;
	int i;

	for (i = 0; i < spp->pgs_per_blk; i++) {
		/* reset page status */
		pg = &blk->pg[i];
		NVMEV_ASSERT(pg->nsecs == spp->secs_per_pg);
		pg->status = PG_FREE;
	}

	/* reset block status */
	NVMEV_ASSERT(blk->npgs == spp->pgs_per_blk);
	blk->ipc = 0;
	blk->vpc = 0;
	blk->erase_cnt++;
}

static void gc_read_page(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct convparams *cpp = &conv_ftl->cp;
	/* advance conv_ftl status, we don't care about how long it takes */
	if (cpp->enable_gc_delay) {
		struct nand_cmd gcr = {
			.type = GC_IO,
			.cmd = NAND_READ,
			.stime = 0,
			.xfer_size = spp->pgsz,
			.interleave_pci_dma = false,
			.ppa = ppa,
		};
		ssd_advance_nand(conv_ftl->ssd, &gcr);
	}
}

/* move valid page data (already in DRAM) from victim line to a new page */
static uint64_t gc_write_page(struct conv_ftl *conv_ftl, struct ppa *old_ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct convparams *cpp = &conv_ftl->cp;
	struct ppa new_ppa;
	uint64_t lpn = get_rmap_ent(conv_ftl, old_ppa);

	NVMEV_ASSERT(valid_lpn(conv_ftl, lpn));
	new_ppa = get_new_page(conv_ftl, GC_IO);
	/* update maptbl */
	set_maptbl_ent(conv_ftl, lpn, &new_ppa);
	/* update rmap */
	set_rmap_ent(conv_ftl, lpn, &new_ppa);

	mark_page_valid(conv_ftl, &new_ppa);

	/* need to advance the write pointer here */
	advance_write_pointer(conv_ftl, GC_IO);

	if (cpp->enable_gc_delay) {
		struct nand_cmd gcw = {
			.type = GC_IO,
			.cmd = NAND_NOP,
			.stime = 0,
			.interleave_pci_dma = false,
			.ppa = &new_ppa,
		};
		if (last_pg_in_wordline(conv_ftl, &new_ppa)) {
			gcw.cmd = NAND_WRITE;
			gcw.xfer_size = spp->pgsz * spp->pgs_per_oneshotpg;
		}

		ssd_advance_nand(conv_ftl->ssd, &gcw);
	}

	/* advance per-ch gc_endtime as well */
#if 0
	new_ch = get_ch(conv_ftl, &new_ppa);
	new_ch->gc_endtime = new_ch->next_ch_avail_time;

	new_lun = get_lun(conv_ftl, &new_ppa);
	new_lun->gc_endtime = new_lun->next_lun_avail_time;
#endif

	return 0;
}

static struct line *select_victim_line(struct conv_ftl *conv_ftl, bool force)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct line_mgmt *lm = &conv_ftl->lm;
	struct line *victim_line = NULL;

	victim_line = pqueue_peek(lm->victim_line_pq);
	if (!victim_line) {
		return NULL;
	}

	if (!force && (victim_line->vpc > (spp->pgs_per_line / 8))) {
		return NULL;
	}

	pqueue_pop(lm->victim_line_pq);
	victim_line->pos = 0;
	lm->victim_line_cnt--;

	/* victim_line is a danggling node now */
	return victim_line;
}

/* here ppa identifies the block we want to clean */
static void clean_one_block(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct nand_page *pg_iter = NULL;
	int cnt = 0;
	int pg;

	for (pg = 0; pg < spp->pgs_per_blk; pg++) {
		ppa->g.pg = pg;
		pg_iter = get_pg(conv_ftl->ssd, ppa);
		/* there shouldn't be any free page in victim blocks */
		NVMEV_ASSERT(pg_iter->status != PG_FREE);
		if (pg_iter->status == PG_VALID) {
			gc_read_page(conv_ftl, ppa);
			/* delay the maptbl update until "write" happens */
			gc_write_page(conv_ftl, ppa);
			cnt++;
		}
	}

	NVMEV_ASSERT(get_blk(conv_ftl->ssd, ppa)->vpc == cnt);
}

/* here ppa identifies the block we want to clean */
static void clean_one_flashpg(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct convparams *cpp = &conv_ftl->cp;
	struct nand_page *pg_iter = NULL;
	int cnt = 0, i = 0;
	uint64_t completed_time = 0;
	struct ppa ppa_copy = *ppa;

	for (i = 0; i < spp->pgs_per_flashpg; i++) {
		pg_iter = get_pg(conv_ftl->ssd, &ppa_copy);
		/* there shouldn't be any free page in victim blocks */
		NVMEV_ASSERT(pg_iter->status != PG_FREE);
		if (pg_iter->status == PG_VALID)
			cnt++;

		ppa_copy.g.pg++;
	}

	ppa_copy = *ppa;

	if (cnt <= 0)
		return;

	if (cpp->enable_gc_delay) {
		struct nand_cmd gcr = {
			.type = GC_IO,
			.cmd = NAND_READ,
			.stime = 0,
			.xfer_size = spp->pgsz * cnt,
			.interleave_pci_dma = false,
			.ppa = &ppa_copy,
		};
		completed_time = ssd_advance_nand(conv_ftl->ssd, &gcr);
	}

	for (i = 0; i < spp->pgs_per_flashpg; i++) {
		pg_iter = get_pg(conv_ftl->ssd, &ppa_copy);

		/* there shouldn't be any free page in victim blocks */
		if (pg_iter->status == PG_VALID) {
			/* delay the maptbl update until "write" happens */
			gc_write_page(conv_ftl, &ppa_copy);
		}

		ppa_copy.g.pg++;
	}
}

static void mark_line_free(struct conv_ftl *conv_ftl, struct ppa *ppa)
{
	struct line_mgmt *lm = &conv_ftl->lm;
	struct line *line = get_line(conv_ftl, ppa);
	line->ipc = 0;
	line->vpc = 0;
	/* move this line to free line list */
	list_add_tail(&line->entry, &lm->free_line_list);
	lm->free_line_cnt++;
}

static int do_gc(struct conv_ftl *conv_ftl, bool force)
{
	struct line *victim_line = NULL;
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct ppa ppa;
	int flashpg;

	victim_line = select_victim_line(conv_ftl, force);
	if (!victim_line) {
		return -1;
	}

	ppa.g.blk = victim_line->id;
	NVMEV_DEBUG("GC-ing line:%d,ipc=%d(%d),victim=%d,full=%d,free=%d\n", ppa.g.blk,
		    victim_line->ipc, victim_line->vpc, conv_ftl->lm.victim_line_cnt,
		    conv_ftl->lm.full_line_cnt, conv_ftl->lm.free_line_cnt);

	conv_ftl->wfc.credits_to_refill = victim_line->ipc;

	/* copy back valid data */
	for (flashpg = 0; flashpg < spp->flashpgs_per_blk; flashpg++) {
		int ch, lun;

		ppa.g.pg = flashpg * spp->pgs_per_flashpg;
		for (ch = 0; ch < spp->nchs; ch++) {
			for (lun = 0; lun < spp->luns_per_ch; lun++) {
				struct nand_lun *lunp;

				ppa.g.ch = ch;
				ppa.g.lun = lun;
				ppa.g.pl = 0;
				lunp = get_lun(conv_ftl->ssd, &ppa);
				clean_one_flashpg(conv_ftl, &ppa);

				if (flashpg == (spp->flashpgs_per_blk - 1)) {
					struct convparams *cpp = &conv_ftl->cp;

					mark_block_free(conv_ftl, &ppa);

					if (cpp->enable_gc_delay) {
						struct nand_cmd gce = {
							.type = GC_IO,
							.cmd = NAND_ERASE,
							.stime = 0,
							.interleave_pci_dma = false,
							.ppa = &ppa,
						};
						ssd_advance_nand(conv_ftl->ssd, &gce);
					}

					lunp->gc_endtime = lunp->next_lun_avail_time;
				}
			}
		}
	}

	/* update line status */
	mark_line_free(conv_ftl, &ppa);

	return 0;
}

static void forground_gc(struct conv_ftl *conv_ftl)
{
	if (should_gc_high(conv_ftl)) {
		NVMEV_DEBUG("should_gc_high passed");
		NVMEV_ERROR("should_gc_high passed, FGGC");
		/* perform GC here until !should_gc(conv_ftl) */
		do_gc(conv_ftl, true);
	}
}

static bool is_same_flash_page(struct conv_ftl *conv_ftl, struct ppa ppa1, struct ppa ppa2)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	uint32_t ppa1_page = ppa1.g.pg / spp->pgs_per_flashpg;
	uint32_t ppa2_page = ppa2.g.pg / spp->pgs_per_flashpg;

	return (ppa1.h.blk_in_ssd == ppa2.h.blk_in_ssd) && (ppa1_page == ppa2_page);
}

static bool conv_read(struct nvmev_ns *ns, struct nvmev_request *req, struct nvmev_result *ret)
{
	struct conv_ftl *conv_ftls = (struct conv_ftl *)ns->ftls;
	struct conv_ftl *conv_ftl = &conv_ftls[0];
	/* spp are shared by all instances*/
	struct ssdparams *spp = &conv_ftl->ssd->sp;

	struct nvme_command *cmd = req->cmd;
	uint64_t lba = cmd->rw.slba;
	uint64_t nr_lba = (cmd->rw.length + 1);
	uint64_t start_lpn = lba / spp->secs_per_pg;
	uint64_t end_lpn = (lba + nr_lba - 1) / spp->secs_per_pg;
	uint64_t lpn;
	uint64_t nsecs_start = req->nsecs_start;
	uint64_t nsecs_completed, nsecs_latest = nsecs_start;
	uint32_t xfer_size, i;
	uint32_t nr_parts = ns->nr_parts;

	struct ppa prev_ppa;
	struct nand_cmd srd = {
		.type = USER_IO,
		.cmd = NAND_READ,
		.stime = nsecs_start,
		.interleave_pci_dma = true,
	};

	NVMEV_ASSERT(conv_ftls);
	NVMEV_DEBUG("conv_read: start_lpn=%lld, len=%lld, end_lpn=%lld", start_lpn, nr_lba, end_lpn);
	if ((end_lpn / nr_parts) >= spp->tt_pgs) {
		NVMEV_ERROR("conv_read: lpn passed FTL range(start_lpn=%lld,tt_pgs=%ld)\n",
			    start_lpn, spp->tt_pgs);
		return false;
	}

	if (LBA_TO_BYTE(nr_lba) <= (KB(4) * nr_parts)) {
		srd.stime += spp->fw_4kb_rd_lat;
	} else {
		srd.stime += spp->fw_rd_lat;
	}

	for (i = 0; (i < nr_parts) && (start_lpn <= end_lpn); i++, start_lpn++) {
		conv_ftl = &conv_ftls[start_lpn % nr_parts];
		xfer_size = 0;
		prev_ppa = get_maptbl_ent(conv_ftl, start_lpn / nr_parts);

		/* normal IO read path */
		for (lpn = start_lpn; lpn <= end_lpn; lpn += nr_parts) {
			uint64_t local_lpn;
			struct ppa cur_ppa;

			local_lpn = lpn / nr_parts;
			cur_ppa = get_maptbl_ent(conv_ftl, local_lpn);
			if (!mapped_ppa(&cur_ppa) || !valid_ppa(conv_ftl, &cur_ppa)) {
				NVMEV_DEBUG("lpn 0x%llx not mapped to valid ppa\n", local_lpn);
				NVMEV_DEBUG("Invalid ppa,ch:%d,lun:%d,blk:%d,pl:%d,pg:%d\n",
					    cur_ppa.g.ch, cur_ppa.g.lun, cur_ppa.g.blk,
					    cur_ppa.g.pl, cur_ppa.g.pg);
				continue;
			}

			// aggregate read io in same flash page
			if (mapped_ppa(&prev_ppa) &&
			    is_same_flash_page(conv_ftl, cur_ppa, prev_ppa)) {
				xfer_size += spp->pgsz;
				continue;
			}

			if (xfer_size > 0) {
				srd.xfer_size = xfer_size;
				srd.ppa = &prev_ppa;
				nsecs_completed = ssd_advance_nand(conv_ftl->ssd, &srd);
				nsecs_latest = max(nsecs_completed, nsecs_latest);
			}

			xfer_size = spp->pgsz;
			prev_ppa = cur_ppa;
		}

		// issue remaining io
		if (xfer_size > 0) {
			srd.xfer_size = xfer_size;
			srd.ppa = &prev_ppa;
			nsecs_completed = ssd_advance_nand(conv_ftl->ssd, &srd);
			nsecs_latest = max(nsecs_completed, nsecs_latest);
		}
	}

	ret->nsecs_target = nsecs_latest;
	ret->status = NVME_SC_SUCCESS;
	return true;
}

static bool conv_write(struct nvmev_ns *ns, struct nvmev_request *req, struct nvmev_result *ret)
{
	struct conv_ftl *conv_ftls = (struct conv_ftl *)ns->ftls;
	struct conv_ftl *conv_ftl = &conv_ftls[0];
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct buffer *wbuf = conv_ftl->ssd->write_buffer;

	struct nvme_command *cmd = req->cmd;
	struct nvme_rw_command *rw = (struct nvme_rw_command *)cmd;
	uint64_t lba = rw->slba;
	uint64_t nsecs_start = __get_wallclock();
	uint64_t nsecs_completed;
	uint64_t lpn;
	uint64_t remaining_lpns;
	uint64_t cur_lpn;
	uint64_t nsecs_used = 0;
	uint64_t completed_time = nsecs_start;
	struct ppa ppa;
	struct nand_cmd swr = {
		.type = USER_IO,
		.cmd = NAND_WRITE,
		.stime = nsecs_start,
		.interleave_pci_dma = true,
		.ppa = &ppa,
	};

	NVMEV_DEBUG("%s: write request. req->status = %d, req->nsecs_start = %llu, "
		    "req->nsecs_budget = %llu\n",
		    __func__, req->status, req->nsecs_start, req->nsecs_budget);

	NVMEV_DEBUG("%s: lba = %llu, length = %d\n", __func__, lba, rw->length);

	/* write buffer is full, schedule writeback */
	if (buffer_allocate(wbuf, (rw->length + 1) << 9) == 0) {
		enqueue_writeback_io_req(req->sqid, completed_time, wbuf, 0);
		ret->nsecs_target = completed_time;
		return true;
	}

	/* write buffer is not full, schedule write */
	lpn = lba / spp->secs_per_pg;
	remaining_lpns = ((rw->length + 1) << 9) / spp->pgsz;

	NVMEV_DEBUG("%s: lpn = %llu, remaining_lpns = %llu\n", __func__, lpn, remaining_lpns);

	while (remaining_lpns > 0) {
		cur_lpn = lpn;
		check_and_refill_write_credit(conv_ftl);

#if (BASE_SSD == HYBRID_SSD)
		/* For hybrid storage, all new writes go to SLC initially */
		/* Update page hotness on write */
		update_page_hotness(conv_ftl, cur_lpn, ACCESS_WRITE);
		
		/* Check for migrations */
		check_and_perform_migrations(conv_ftl);
		
		/* For new writes, always use SLC initially with DA strategy and lunpointer */
		/* Only SLC writes use lunpointer, QLC uses pure traditional strategy */
		conv_ftl->lunpointer = cur_lpn % (spp->slc_channels * spp->slc_luns_per_ch);
		
		/* Use DA strategy to get SLC page */
		ppa = get_new_page_DA(conv_ftl, USER_IO);
#else
		ppa = get_new_page(conv_ftl, USER_IO);
#endif

		swr.stime = completed_time;
		swr.xfer_size = spp->pgsz;

		/* advance ssd status by one page write */
		completed_time = ssd_advance_nand(conv_ftl->ssd, &swr);
		completed_time = ssd_advance_write_buffer(conv_ftl->ssd, completed_time, spp->pgsz);

		/* update maptbl */
		set_maptbl_ent(conv_ftl, cur_lpn, &ppa);
		/* update rmap */
		set_rmap_ent(conv_ftl, cur_lpn, &ppa);

#if (BASE_SSD == HYBRID_SSD)
		/* For hybrid storage, use DA strategy for SLC writes with lunpointer */
		/* SLC uses DA strategy, QLC uses pure traditional strategy */
		advance_write_pointer_DA(conv_ftl, USER_IO);
#else
		/* update write pointer */
		advance_write_pointer(conv_ftl, USER_IO);
#endif

		/* update per-io status */
		--remaining_lpns;
		++lpn;
	}

	/* GC if needed */
	if (should_gc(conv_ftl)) {
		do_gc(conv_ftl, false);
	}

	ret->nsecs_target = completed_time;
	return true;
}

static void conv_flush(struct nvmev_ns *ns, struct nvmev_request *req, struct nvmev_result *ret)
{
	uint64_t start, latest;
	uint32_t i;
	struct conv_ftl *conv_ftls = (struct conv_ftl *)ns->ftls;

	start = local_clock();
	latest = start;
	for (i = 0; i < ns->nr_parts; i++) {
		latest = max(latest, ssd_next_idle_time(conv_ftls[i].ssd));
	}

	NVMEV_DEBUG("%s latency=%llu\n", __FUNCTION__, latest - start);

	ret->status = NVME_SC_SUCCESS;
	ret->nsecs_target = latest;
	return;
}

bool conv_proc_nvme_io_cmd(struct nvmev_ns *ns, struct nvmev_request *req, struct nvmev_result *ret)
{
	struct nvme_command *cmd = req->cmd;

	NVMEV_ASSERT(ns->csi == NVME_CSI_NVM);

	switch (cmd->common.opcode) {
	case nvme_cmd_write:
		if (!conv_write(ns, req, ret))
			return false;
		break;
	case nvme_cmd_read:
		if (!conv_read(ns, req, ret))
			return false;
		break;
	case nvme_cmd_flush:
		conv_flush(ns, req, ret);
		break;
	default:
		NVMEV_ERROR("%s: unimplemented command: %s(%d)\n", __func__,
			   nvme_opcode_string(cmd->common.opcode), cmd->common.opcode);
		break;
	}

	return true;
}

/* Hotness tracking and migration functions */
#if (BASE_SSD == HYBRID_SSD)

/* Initialize hotness tracking table */
static void init_hotness_tracking(struct conv_ftl *conv_ftl)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct migration_mgmt *mm = &conv_ftl->migration_mgmt;
	
	mm->hotness_table_size = spp->hotness_table_size;
	mm->hot_threshold = spp->hot_threshold;
	mm->cold_threshold = spp->cold_threshold;
	mm->migration_interval = spp->migration_interval;
	mm->max_migrations_per_check = spp->max_migrations_per_check;
	mm->last_migration_check = 0;
	mm->current_migrations = 0;
	
	/* Allocate hotness tracking table */
	mm->hotness_table = vmalloc(sizeof(struct page_hotness) * mm->hotness_table_size);
	if (!mm->hotness_table) {
		NVMEV_ERROR("Failed to allocate hotness tracking table\n");
		return;
	}
	
	/* Initialize hotness table */
	for (uint64_t i = 0; i < mm->hotness_table_size; i++) {
		mm->hotness_table[i].lpn = INVALID_LPN;
		mm->hotness_table[i].access_count = 0;
		mm->hotness_table[i].recent_access = 0;
		mm->hotness_table[i].last_access_time = 0;
		mm->hotness_table[i].storage_type = STORAGE_TYPE_SLC; /* Start in SLC */
		mm->hotness_table[i].is_migrating = false;
	}
	
	/* Initialize page counters */
	conv_ftl->total_slc_pages = spp->slc_tt_pgs;
	conv_ftl->used_slc_pages = 0;
	conv_ftl->total_qlc_pages = spp->qlc_tt_pgs;
	conv_ftl->used_qlc_pages = 0;
}

/* Remove hotness tracking table */
static void remove_hotness_tracking(struct conv_ftl *conv_ftl)
{
	struct migration_mgmt *mm = &conv_ftl->migration_mgmt;
	
	if (mm->hotness_table) {
		vfree(mm->hotness_table);
		mm->hotness_table = NULL;
	}
}

/* Find or create hotness entry for LPN */
static struct page_hotness *get_hotness_entry(struct conv_ftl *conv_ftl, uint64_t lpn)
{
	struct migration_mgmt *mm = &conv_ftl->migration_mgmt;
	uint64_t hash = lpn % mm->hotness_table_size;
	
	/* Linear probing for collision resolution */
	for (uint64_t i = 0; i < mm->hotness_table_size; i++) {
		uint64_t idx = (hash + i) % mm->hotness_table_size;
		struct page_hotness *entry = &mm->hotness_table[idx];
		
		if (entry->lpn == INVALID_LPN || entry->lpn == lpn) {
			if (entry->lpn == INVALID_LPN) {
				entry->lpn = lpn;
				entry->access_count = 0;
				entry->recent_access = 0;
				entry->last_access_time = 0;
				entry->storage_type = STORAGE_TYPE_SLC; /* New pages start in SLC */
				entry->is_migrating = false;
			}
			return entry;
		}
	}
	
	NVMEV_ERROR("Hotness table full, cannot track LPN %llu\n", lpn);
	return NULL;
}

/* Update page hotness on access */
static void update_page_hotness(struct conv_ftl *conv_ftl, uint64_t lpn, uint32_t access_type)
{
	struct page_hotness *entry = get_hotness_entry(conv_ftl, lpn);
	if (!entry) return;
	
	uint64_t current_time = __get_wallclock();
	
	entry->access_count++;
	entry->recent_access++;
	entry->last_access_time = current_time;
	
	/* Aging: reduce recent access count over time */
	if (current_time - entry->last_access_time > 1000000000) { /* 1 second */
		entry->recent_access = entry->recent_access > 0 ? entry->recent_access - 1 : 0;
	}
}

/* Check if page should be migrated */
static bool should_migrate_page(struct conv_ftl *conv_ftl, struct page_hotness *entry)
{
	struct migration_mgmt *mm = &conv_ftl->migration_mgmt;
	
	/* Skip if already migrating */
	if (entry->is_migrating) return false;
	
	/* Skip if not mapped */
	if (entry->lpn == INVALID_LPN) return false;
	
	/* Only migrate from SLC to QLC (cold data migration) */
	/* Temporarily disable QLC to SLC migration */
	if (entry->storage_type == STORAGE_TYPE_SLC) {
		/* Cold SLC page -> migrate to QLC */
		return (entry->recent_access <= mm->cold_threshold);
	} else {
		/* QLC pages stay in QLC - no migration back to SLC */
		return false;
	}
}

/* Execute page migration */
static uint64_t migrate_page(struct conv_ftl *conv_ftl, uint64_t lpn, uint32_t target_storage)
{
	struct ssdparams *spp = &conv_ftl->ssd->sp;
	struct page_hotness *entry = get_hotness_entry(conv_ftl, lpn);
	if (!entry) return 0;
	
	uint64_t migration_time = 0;
	struct ppa old_ppa, new_ppa;
	struct nand_cmd read_cmd, write_cmd;
	
	/* Get current PPA */
	old_ppa = get_maptbl_ent(conv_ftl, lpn);
	if (!mapped_ppa(&old_ppa)) {
		NVMEV_ERROR("Cannot migrate unmapped LPN %llu\n", lpn);
		return 0;
	}
	
	/* Mark as migrating */
	entry->is_migrating = true;
	
	/* Read from current location */
	read_cmd.type = GC_IO;
	read_cmd.cmd = NAND_READ;
	read_cmd.stime = __get_wallclock();
	read_cmd.xfer_size = spp->pgsz;
	read_cmd.ppa = &old_ppa;
	
	migration_time = ssd_advance_nand(conv_ftl->ssd, &read_cmd);
	
	/* Get new PPA in target storage */
	/* Only migrate from SLC to QLC - use traditional round-robin strategy */
	new_ppa = get_new_page(conv_ftl, GC_IO);
	conv_ftl->used_qlc_pages++;
	entry->storage_type = STORAGE_TYPE_QLC;
	
	/* Write to new location */
	write_cmd.type = GC_IO;
	write_cmd.cmd = NAND_WRITE;
	write_cmd.stime = migration_time;
	write_cmd.xfer_size = spp->pgsz;
	write_cmd.ppa = &new_ppa;
	
	migration_time = ssd_advance_nand(conv_ftl->ssd, &write_cmd);
	
	/* Update mapping table */
	set_maptbl_ent(conv_ftl, lpn, &new_ppa);
	set_rmap_ent(conv_ftl, lpn, &new_ppa);
	
	/* Advance QLC write pointer using traditional strategy */
	advance_write_pointer_QLC(conv_ftl, GC_IO);
	
	/* Mark old page as invalid */
	mark_page_invalid(conv_ftl, &old_ppa);
	
	/* Update page counters */
	conv_ftl->used_slc_pages--;
	
	/* Mark migration complete */
	entry->is_migrating = false;
	
	return migration_time;
}

/* Check and perform migrations */
static void check_and_perform_migrations(struct conv_ftl *conv_ftl)
{
	struct migration_mgmt *mm = &conv_ftl->migration_mgmt;
	uint64_t current_time = __get_wallclock();
	
	/* Check if it's time for migration check */
	if (current_time - mm->last_migration_check < mm->migration_interval) {
		return;
	}
	
	mm->last_migration_check = current_time;
	mm->current_migrations = 0;
	
	/* Scan hotness table for migration candidates */
	for (uint64_t i = 0; i < mm->hotness_table_size && mm->current_migrations < mm->max_migrations_per_check; i++) {
		struct page_hotness *entry = &mm->hotness_table[i];
		
		if (entry->lpn == INVALID_LPN) continue;
		
		if (should_migrate_page(conv_ftl, entry)) {
			/* Only migrate from SLC to QLC (cold data migration) */
			uint32_t target_storage = STORAGE_TYPE_QLC;
			
			/* Perform migration */
			uint64_t migration_time = migrate_page(conv_ftl, entry->lpn, target_storage);
			if (migration_time > 0) {
				mm->current_migrations++;
				NVMEV_DEBUG("Migrated LPN %llu from SLC to QLC (cold data migration)\n", entry->lpn);
			}
		}
	}
}

#endif /* BASE_SSD == HYBRID_SSD */
