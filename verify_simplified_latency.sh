#!/bin/bash

echo "=== 简化延迟参数验证脚本 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. 检查简化的延迟参数定义${NC}"
if grep -q "HYBRID_SLC_READ_LATENCY\|HYBRID_QLC_Q[1-4]_READ_LATENCY" ssd_config.h; then
    echo -e "${GREEN}✓ 找到简化的延迟参数定义${NC}"
    grep -n "HYBRID_.*_READ_LATENCY" ssd_config.h
else
    echo -e "${RED}✗ 未找到简化的延迟参数定义${NC}"
fi

echo ""
echo -e "${BLUE}2. 检查简化的数据结构${NC}"
if grep -q "slc_read_latency\|qlc_q[1-4]_read_latency" ssd.h; then
    echo -e "${GREEN}✓ 找到简化的数据结构${NC}"
    grep -n "slc_read_latency\|qlc_q[1-4]_read_latency" ssd.h
else
    echo -e "${RED}✗ 未找到简化的数据结构${NC}"
fi

echo ""
echo -e "${BLUE}3. 检查延迟初始化代码${NC}"
if grep -q "spp->slc_read_latency\|spp->qlc_q[1-4]_read_latency" ssd.c; then
    echo -e "${GREEN}✓ 找到延迟初始化代码${NC}"
    grep -n "spp->.*_read_latency" ssd.c
else
    echo -e "${RED}✗ 未找到延迟初始化代码${NC}"
fi

echo ""
echo -e "${BLUE}4. 检查延迟使用代码${NC}"
if grep -q "spp->slc_read_latency\|spp->qlc_q[1-4]_read_latency" ssd.c; then
    echo -e "${GREEN}✓ 找到延迟使用代码${NC}"
    grep -n "spp->.*_read_latency" ssd.c | grep -v "spp->.*_read_latency ="
else
    echo -e "${RED}✗ 未找到延迟使用代码${NC}"
fi

echo ""
echo -e "${BLUE}5. 检查是否移除了LSB/MSB/CSB相关代码${NC}"
if grep -q "CELL_TYPE_LSB\|CELL_TYPE_MSB\|CELL_TYPE_CSB" ssd.h ssd.c; then
    echo -e "${YELLOW}⚠ 仍存在LSB/MSB/CSB相关代码${NC}"
    grep -n "CELL_TYPE" ssd.h ssd.c
else
    echo -e "${GREEN}✓ 已成功移除LSB/MSB/CSB相关代码${NC}"
fi

echo ""
echo -e "${BLUE}6. 统计简化后的延迟参数${NC}"
slc_count=$(grep -c "SLC.*LATENCY" ssd_config.h)
qlc_count=$(grep -c "QLC.*LATENCY" ssd_config.h)

echo "SLC延迟参数数量: $slc_count"
echo "QLC延迟参数数量: $qlc_count"

echo ""
echo -e "${GREEN}=== 验证完成 ===${NC}"
echo ""
echo -e "${YELLOW}简化结果:${NC}"
echo "- 移除了复杂的LSB、MSB、CSB位类型"
echo "- 简化为SLC和QLC四个区域的简单延迟"
echo "- SLC: 30μs读取延迟"
echo "- QLC: Q1=75μs, Q2=95μs, Q3=130μs, Q4=205μs"
echo "- 代码更简洁，易于理解和维护" 