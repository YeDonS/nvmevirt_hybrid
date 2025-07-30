#!/bin/bash

echo "=== LSB、MSB、CSB 验证脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. 检查CELL_TYPE定义${NC}"
if grep -q "CELL_TYPE_LSB\|CELL_TYPE_MSB\|CELL_TYPE_CSB" ssd.h; then
    echo -e "${GREEN}✓ 找到CELL_TYPE定义${NC}"
    grep -n "CELL_TYPE" ssd.h
else
    echo -e "${RED}✗ 未找到CELL_TYPE定义${NC}"
fi

echo ""
echo -e "${BLUE}2. 检查延迟参数定义${NC}"
if grep -q "READ_LATENCY_LSB\|READ_LATENCY_MSB\|READ_LATENCY_CSB" ssd_config.h; then
    echo -e "${GREEN}✓ 找到延迟参数定义${NC}"
    grep -n "READ_LATENCY" ssd_config.h | head -10
else
    echo -e "${RED}✗ 未找到延迟参数定义${NC}"
fi

echo ""
echo -e "${BLUE}3. 检查延迟数组定义${NC}"
if grep -q "qlc_q.*_pg_.*_lat\[MAX_CELL_TYPES\]" ssd.h; then
    echo -e "${GREEN}✓ 找到延迟数组定义${NC}"
    grep -n "qlc_q.*_pg_.*_lat\[MAX_CELL_TYPES\]" ssd.h
else
    echo -e "${RED}✗ 未找到延迟数组定义${NC}"
fi

echo ""
echo -e "${BLUE}4. 检查get_cell函数${NC}"
if grep -q "get_cell" ssd.h; then
    echo -e "${GREEN}✓ 找到get_cell函数${NC}"
    grep -A5 -B5 "get_cell" ssd.h
else
    echo -e "${RED}✗ 未找到get_cell函数${NC}"
fi

echo ""
echo -e "${BLUE}5. 检查延迟初始化${NC}"
if grep -q "CELL_TYPE_LSB\|CELL_TYPE_MSB\|CELL_TYPE_CSB" ssd.c; then
    echo -e "${GREEN}✓ 找到延迟初始化代码${NC}"
    grep -n "CELL_TYPE" ssd.c | head -5
else
    echo -e "${RED}✗ 未找到延迟初始化代码${NC}"
fi

echo ""
echo -e "${BLUE}6. 检查延迟使用${NC}"
if grep -q "get_cell" ssd.c; then
    echo -e "${GREEN}✓ 找到get_cell函数使用${NC}"
    grep -n "get_cell" ssd.c
else
    echo -e "${RED}✗ 未找到get_cell函数使用${NC}"
fi

echo ""
echo -e "${BLUE}7. 统计延迟参数数量${NC}"
lsb_count=$(grep -c "LSB" ssd_config.h)
msb_count=$(grep -c "MSB" ssd_config.h)
csb_count=$(grep -c "CSB" ssd_config.h)

echo "LSB参数数量: $lsb_count"
echo "MSB参数数量: $msb_count"
echo "CSB参数数量: $csb_count"

echo ""
echo -e "${GREEN}=== 验证完成 ===${NC}"
echo ""
echo -e "${YELLOW}说明:${NC}"
echo "- LSB: 最低有效位，读取最快"
echo "- MSB: 最高有效位，读取中等"
echo "- CSB: 中心有效位，读取最慢"
echo "- 三个参数模拟NAND Flash的真实物理特性" 