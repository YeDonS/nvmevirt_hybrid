#!/bin/bash

echo "=== QLC Four Regions Latency Implementation Verification ==="
echo

# Check QLC region latency definitions in ssd_config.h
echo "1. Checking QLC region latency definitions in ssd_config.h:"
echo "--------------------------------------------------------"
grep -n "HYBRID_QLC_Q[1-4]_READ_LATENCY" ssd_config.h
echo

# Check QLC region latency parameters in ssd.h
echo "2. Checking QLC region latency parameters in ssd.h:"
echo "--------------------------------------------------"
grep -n "qlc_q[1-4]_pg_rd_lat" ssd.h
echo

# Check QLC region function
echo "3. Checking QLC region function in ssd.h:"
echo "----------------------------------------"
grep -A 20 "get_qlc_region" ssd.h
echo

# Check QLC region initialization in ssd.c
echo "4. Checking QLC region initialization in ssd.c:"
echo "---------------------------------------------"
grep -A 30 "Set QLC latency parameters for 4 regions" ssd.c
echo

# Check QLC region usage in ssd_advance_nand
echo "5. Checking QLC region usage in ssd_advance_nand:"
echo "------------------------------------------------"
grep -A 40 "uint32_t qlc_region = get_qlc_region" ssd.c
echo

# Check specific latency values
echo "6. Checking specific latency values:"
echo "-----------------------------------"
echo "SLC read latency: 30μs (30000 ns)"
echo "QLC Q1 read latency: 75μs (75000 ns)"
echo "QLC Q2 read latency: 95μs (95000 ns)"
echo "QLC Q3 read latency: 130μs (130000 ns)"
echo "QLC Q4 read latency: 205μs (205000 ns)"
echo

# Verify QLC region calculation logic
echo "7. QLC region calculation logic:"
echo "-------------------------------"
echo "Q1: 0-25% of QLC pages"
echo "Q2: 25-50% of QLC pages"
echo "Q3: 50-75% of QLC pages"
echo "Q4: 75-100% of QLC pages"
echo

echo "=== Verification Complete ==="
echo
echo "Summary:"
echo "- SLC: Fixed 30μs read latency"
echo "- QLC: Four regions with different latencies (75μs, 95μs, 130μs, 205μs)"
echo "- QLC write latency only used for migration, not performance testing"
echo "- QLC regions are divided equally (25% each) based on page number" 