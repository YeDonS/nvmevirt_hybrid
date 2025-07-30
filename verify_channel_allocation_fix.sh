#!/bin/bash

echo "=== 验证混合SSD通道分配修正 ==="
echo

# 检查SLC通道限制
echo "1. 检查SLC DA策略是否限制在指定通道..."
if grep -A 20 "advance_write_pointer_DA" conv_ftl.c | grep -q "max_slc_luns = spp->slc_channels \* spp->slc_luns_per_ch"; then
    echo "   ✓ SLC DA策略正确限制到SLC LUN数量"
else
    echo "   ✗ SLC DA策略未正确限制通道"
fi

# 检查QLC专用函数
echo "2. 检查QLC专用写入指针函数..."
if grep -q "advance_write_pointer_QLC" conv_ftl.c; then
    echo "   ✓ QLC专用写入指针函数已创建"
else
    echo "   ✗ QLC专用写入指针函数未找到"
fi

# 检查get_new_page_DA的SLC通道限制
echo "3. 检查get_new_page_DA是否限制SLC通道..."
if grep -A 10 "get_new_page_DA" conv_ftl.c | grep -q "ppa.g.ch = wp->ch % spp->slc_channels"; then
    echo "   ✓ get_new_page_DA正确限制SLC通道"
else
    echo "   ✗ get_new_page_DA未正确限制SLC通道"
fi

# 检查get_new_page的QLC通道分配
echo "4. 检查get_new_page是否正确分配QLC通道..."
if grep -A 10 "get_new_page" conv_ftl.c | grep -q "ppa.g.ch = spp->slc_channels + (wp->ch % spp->qlc_channels)"; then
    echo "   ✓ get_new_page正确分配QLC通道"
else
    echo "   ✗ get_new_page未正确分配QLC通道"
fi

# 检查容量计算修正
echo "5. 检查容量计算是否按通道分配..."
if grep -A 5 "Calculate hybrid storage parameters" ssd.c | grep -q "total_channels = spp->slc_channels + spp->qlc_channels"; then
    echo "   ✓ 容量计算已修正为按通道分配"
else
    echo "   ✗ 容量计算未修正"
fi

# 检查写入函数是否使用DA策略
echo "6. 检查写入函数是否使用get_new_page_DA..."
if grep -A 5 "Use DA strategy to get SLC page" conv_ftl.c | grep -q "ppa = get_new_page_DA(conv_ftl, USER_IO)"; then
    echo "   ✓ 写入函数正确使用DA策略获取SLC页面"
else
    echo "   ✗ 写入函数未使用DA策略"
fi

# 检查迁移函数是否使用QLC策略
echo "7. 检查迁移函数是否使用QLC写入策略..."
if grep -A 5 "Advance QLC write pointer" conv_ftl.c | grep -q "advance_write_pointer_QLC"; then
    echo "   ✓ 迁移函数正确使用QLC写入策略"
else
    echo "   ✗ 迁移函数未使用QLC策略"
fi

# 检查容量信息打印
echo "8. 检查是否添加了容量信息打印..."
if grep -q "Hybrid SSD Capacity Allocation" ssd.c; then
    echo "   ✓ 已添加容量信息打印用于调试"
else
    echo "   ✗ 未添加容量信息打印"
fi

echo
echo "=== 通道分配修正验证完成 ==="

# 检查QLC四个区域
echo
echo "=== QLC四个区域验证 ==="
echo "QLC四个区域在 ssd.h 中的 get_qlc_region 函数中分配："

if grep -A 15 "get_qlc_region" ssd.h | grep -q "region_size = spp->qlc_tt_pgs / 4"; then
    echo "   ✓ QLC被正确划分为4个相等区域"
    echo "   - Q1区域: 读取延迟 75μs"
    echo "   - Q2区域: 读取延迟 95μs" 
    echo "   - Q3区域: 读取延迟 130μs"
    echo "   - Q4区域: 读取延迟 205μs"
else
    echo "   ✗ QLC四个区域划分未找到"
fi

echo
echo "=== 验证完成 ===" 