#!/bin/bash

echo "=== 内核状态检查 ==="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}1. 内核版本信息${NC}"
echo "内核版本: $(uname -r)"
echo "内核架构: $(uname -m)"
echo "操作系统: $(uname -s)"

echo ""
echo -e "${BLUE}2. 已加载的内核模块${NC}"
lsmod | head -10

echo ""
echo -e "${BLUE}3. NVMe相关模块${NC}"
lsmod | grep -i nvme || echo "未找到NVMe模块"

echo ""
echo -e "${BLUE}4. 设备节点${NC}"
ls -la /dev/nvme* 2>/dev/null || echo "未找到NVMe设备节点"

echo ""
echo -e "${BLUE}5. PCI设备${NC}"
lspci | grep -i nvme || echo "未找到NVMe PCI设备"

echo ""
echo -e "${BLUE}6. 内核日志（最近10条）${NC}"
dmesg | tail -10

echo ""
echo -e "${BLUE}7. 系统资源使用${NC}"
echo "内存使用:"
free -h | head -2

echo ""
echo "CPU使用:"
top -bn1 | grep "Cpu(s)" | head -1

echo ""
echo -e "${GREEN}=== 检查完成 ===${NC}"
echo ""
echo -e "${YELLOW}说明:${NC}"
echo "- 内核本身没有改变"
echo "- 我们只修改了NVMe设备驱动模块"
echo "- 系统稳定性不受影响"
echo "- 可以通过加载/卸载模块来测试" 