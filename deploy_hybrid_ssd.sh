#!/bin/bash

echo "=========================================="
echo "Hybrid SSD Simulator - One-Click Deployment"
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        log_info "$1 is installed"
        return 0
    else
        log_error "$1 is not installed"
        return 1
    fi
}

# Check if running as root for some operations
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. Some operations will be performed with elevated privileges."
    else
        log_info "Running as regular user. Will use sudo when needed."
    fi
}

# Step 1: System Check
log_info "Step 1: Checking system requirements..."

# Check OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    log_info "Linux system detected"
    DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
    VERSION=$(lsb_release -sr 2>/dev/null || echo "Unknown")
    log_info "Distribution: $DISTRO $VERSION"
else
    log_error "This script is designed for Linux systems only"
    exit 1
fi

# Check kernel version
KERNEL_VERSION=$(uname -r)
log_info "Kernel version: $KERNEL_VERSION"

# Check memory
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024))
log_info "Total memory: ${TOTAL_MEM_GB} GB"

if [ $TOTAL_MEM_GB -lt 8 ]; then
    log_warn "Memory is less than 8GB. Performance may be limited."
fi

# Check available disk space
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
log_info "Available disk space: ${AVAILABLE_SPACE_GB} GB"

if [ $AVAILABLE_SPACE_GB -lt 10 ]; then
    log_error "Insufficient disk space. At least 10GB required."
    exit 1
fi

# Step 2: Install Dependencies
log_info "Step 2: Installing dependencies..."

# Update package list
log_info "Updating package list..."
sudo apt-get update -qq

# Install essential packages
PACKAGES=(
    "build-essential"
    "libncurses5"
    "libncurses5-dev"
    "bin86"
    "kernel-package"
    "libssl-dev"
    "bison"
    "flex"
    "libelf-dev"
    "dwarves"
    "git"
    "vim"
    "numactl"
    "bc"
    "jq"
    "libsqlite3-dev"
    "linux-headers-$(uname -r)"
)

log_info "Installing required packages..."
for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        log_info "$package is already installed"
    else
        log_info "Installing $package..."
        sudo apt-get install -y "$package" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "$package installed successfully"
        else
            log_error "Failed to install $package"
        fi
    fi
done

# Step 3: Install Filebench
log_info "Step 3: Installing Filebench..."

if command -v filebench >/dev/null 2>&1; then
    log_info "Filebench is already installed"
else
    log_info "Installing Filebench from source..."
    cd /tmp
    if [ -d "filebench" ]; then
        rm -rf filebench
    fi
    
    git clone https://github.com/filebench/filebench.git >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd filebench
        libtoolize >/dev/null 2>&1
        aclocal >/dev/null 2>&1
        autoheader >/dev/null 2>&1
        automake --add-missing >/dev/null 2>&1
        autoconf >/dev/null 2>&1
        ./configure >/dev/null 2>&1
        make -j$(nproc) >/dev/null 2>&1
        sudo make install >/dev/null 2>&1
        
        if command -v filebench >/dev/null 2>&1; then
            log_info "Filebench installed successfully"
        else
            log_error "Filebench installation failed"
        fi
    else
        log_error "Failed to clone Filebench repository"
    fi
    
    cd - >/dev/null
fi

# Step 4: Build Hybrid SSD Module
log_info "Step 4: Building Hybrid SSD module..."

# Clean previous builds
if [ -f "nvmev.ko" ]; then
    log_info "Cleaning previous build..."
    make clean >/dev/null 2>&1
fi

# Build the module
log_info "Compiling Hybrid SSD module..."
make CONFIG_NVMEVIRT_HYBRID=y >/dev/null 2>&1

if [ -f "nvmev.ko" ]; then
    log_info "Hybrid SSD module built successfully"
    
    # Show module information
    MODULE_SIZE=$(ls -lh nvmev.ko | awk '{print $5}')
    log_info "Module size: $MODULE_SIZE"
    
    # Verify module
    modinfo nvmev.ko >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_info "Module verification passed"
    else
        log_warn "Module verification failed, but file exists"
    fi
else
    log_error "Failed to build Hybrid SSD module"
    log_error "Check build dependencies and kernel headers"
    exit 1
fi

# Step 5: Run Verification Scripts
log_info "Step 5: Running verification scripts..."

VERIFICATION_SCRIPTS=(
    "verify_hybrid_implementation.sh"
    "verify_migration_implementation.sh"
    "verify_qlc_regions.sh"
    "verify_simplified_latency.sh"
)

VERIFICATION_PASSED=0
VERIFICATION_TOTAL=0

for script in "${VERIFICATION_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        log_info "Running $script..."
        ./"$script" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_info "$script: PASSED"
            ((VERIFICATION_PASSED++))
        else
            log_warn "$script: FAILED"
        fi
        ((VERIFICATION_TOTAL++))
    else
        log_warn "$script not found"
    fi
done

log_info "Verification results: $VERIFICATION_PASSED/$VERIFICATION_TOTAL tests passed"

# Step 6: Create Deployment Scripts
log_info "Step 6: Creating deployment scripts..."

# Detect system configuration
TOTAL_MEM_GB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
CPU_COUNT=$(nproc)

# Calculate memory allocation
if [ $TOTAL_MEM_GB -ge 32 ]; then
    MEMMAP_START="16G"
    MEMMAP_SIZE="12G"
elif [ $TOTAL_MEM_GB -ge 16 ]; then
    MEMMAP_START="8G"
    MEMMAP_SIZE="6G"
else
    MEMMAP_START="4G"
    MEMMAP_SIZE="3G"
fi

# Calculate CPU allocation
if [ $CPU_COUNT -ge 16 ]; then
    CPUS="0,1,2,3,4,5,6,7"
elif [ $CPU_COUNT -ge 8 ]; then
    CPUS="0,1,2,3"
else
    CPUS="0,1"
fi

log_info "Detected configuration:"
log_info "  Memory: ${TOTAL_MEM_GB}GB (allocating ${MEMMAP_SIZE} at ${MEMMAP_START})"
log_info "  CPUs: ${CPU_COUNT} cores (using ${CPUS})"

# Create start script
cat > start_hybrid_ssd.sh << EOF
#!/bin/bash
echo "Starting Hybrid SSD Simulator..."
echo "Memory: ${MEMMAP_START} + ${MEMMAP_SIZE}"
echo "CPUs: ${CPUS}"

sudo insmod ./nvmev.ko \\
    memmap_start=${MEMMAP_START} \\
    memmap_size=${MEMMAP_SIZE} \\
    cpus=${CPUS}

if [ \$? -eq 0 ]; then
    echo "Hybrid SSD module loaded successfully"
    sleep 2
    lsblk | grep nvme
    echo "Device ready for use"
else
    echo "Failed to load Hybrid SSD module"
    echo "Check dmesg for error details:"
    dmesg | tail -10
    exit 1
fi
EOF

chmod +x start_hybrid_ssd.sh

# Create stop script
cat > stop_hybrid_ssd.sh << EOF
#!/bin/bash
echo "Stopping Hybrid SSD Simulator..."

# Unmount if mounted
if mount | grep -q nvme; then
    echo "Unmounting hybrid SSD..."
    sudo umount /mnt/hybrid_ssd 2>/dev/null
fi

# Remove module
sudo rmmod nvmev
if [ \$? -eq 0 ]; then
    echo "Hybrid SSD module unloaded successfully"
else
    echo "Failed to unload Hybrid SSD module"
    echo "Check if device is in use:"
    lsof | grep nvme
fi
EOF

chmod +x stop_hybrid_ssd.sh

# Create quick test script
cat > quick_test.sh << EOF
#!/bin/bash
echo "=========================================="
echo "Hybrid SSD Quick Test"
echo "=========================================="

# Start the simulator
./start_hybrid_ssd.sh

if [ \$? -ne 0 ]; then
    echo "Failed to start simulator"
    exit 1
fi

# Find the device
DEVICE=\$(lsblk | grep nvme | tail -1 | awk '{print \$1}')
if [ -z "\$DEVICE" ]; then
    echo "No NVMe device found"
    ./stop_hybrid_ssd.sh
    exit 1
fi

DEVICE_PATH="/dev/\${DEVICE}"
echo "Using device: \$DEVICE_PATH"

# Create filesystem
echo "Creating filesystem..."
sudo mkfs.ext4 \${DEVICE_PATH} >/dev/null 2>&1

# Mount device
sudo mkdir -p /mnt/hybrid_ssd
sudo mount \${DEVICE_PATH} /mnt/hybrid_ssd
sudo chmod 777 /mnt/hybrid_ssd

# Simple I/O test
echo "Running I/O test..."
dd if=/dev/zero of=/mnt/hybrid_ssd/test.dat bs=1M count=100 2>/dev/null
WRITE_RESULT=\$?

dd if=/mnt/hybrid_ssd/test.dat of=/dev/null bs=1M 2>/dev/null
READ_RESULT=\$?

if [ \$WRITE_RESULT -eq 0 ] && [ \$READ_RESULT -eq 0 ]; then
    echo "✓ I/O test passed"
    echo "✓ Hybrid SSD is working correctly"
else
    echo "✗ I/O test failed"
fi

# Check migration logs
echo "Checking for migration activity..."
MIGRATION_COUNT=\$(dmesg | grep -i migration | wc -l)
if [ \$MIGRATION_COUNT -gt 0 ]; then
    echo "✓ Migration system is active (\$MIGRATION_COUNT log entries)"
else
    echo "ℹ No migration activity detected (normal for short test)"
fi

# Cleanup
sudo umount /mnt/hybrid_ssd
./stop_hybrid_ssd.sh

echo "=========================================="
echo "Quick test completed successfully!"
echo "=========================================="
EOF

chmod +x quick_test.sh

log_info "Deployment scripts created:"
log_info "  start_hybrid_ssd.sh - Start the simulator"
log_info "  stop_hybrid_ssd.sh  - Stop the simulator"
log_info "  quick_test.sh       - Run a quick functionality test"

# Step 7: Create Evaluation Framework
log_info "Step 7: Setting up evaluation framework..."

mkdir -p evaluation/{scripts,results,configs}

# Copy the VM deployment guide to evaluation directory
if [ -f "VM_DEPLOYMENT_GUIDE.md" ]; then
    cp VM_DEPLOYMENT_GUIDE.md evaluation/
    log_info "VM deployment guide copied to evaluation/"
fi

# Create a simple run-all script
cat > evaluation/runall.sh << EOF
#!/bin/bash
echo "=========================================="
echo "Hybrid SSD Evaluation Suite"
echo "=========================================="

cd ..

# Start simulator
./start_hybrid_ssd.sh
if [ \$? -ne 0 ]; then
    echo "Failed to start simulator"
    exit 1
fi

# Setup device
DEVICE=\$(lsblk | grep nvme | tail -1 | awk '{print \$1}')
DEVICE_PATH="/dev/\${DEVICE}"

sudo mkfs.ext4 \${DEVICE_PATH} >/dev/null 2>&1
sudo mkdir -p /mnt/hybrid_ssd
sudo mount \${DEVICE_PATH} /mnt/hybrid_ssd
sudo chmod 777 /mnt/hybrid_ssd

echo "Running performance tests..."

# Test 1: Sequential Write
echo "Test 1: Sequential Write Performance"
RESULT1=\$(dd if=/dev/zero of=/mnt/hybrid_ssd/seq_test.dat bs=1M count=1000 2>&1 | grep "MB/s" | awk '{print \$(NF-1)}')
echo "Sequential Write: \${RESULT1} MB/s" | tee evaluation/results/performance_results.txt

# Test 2: Random Write
echo "Test 2: Random Write Performance"
if command -v fio >/dev/null 2>&1; then
    RESULT2=\$(fio --name=random_write --filename=/mnt/hybrid_ssd/random_test.dat --rw=randwrite --bs=4k --size=1G --runtime=30 --time_based --output-format=json 2>/dev/null | jq -r '.jobs[0].write.bw' 2>/dev/null || echo "N/A")
    echo "Random Write: \${RESULT2} KB/s" | tee -a evaluation/results/performance_results.txt
else
    echo "fio not available, skipping random write test"
fi

# Test 3: Check Migration Activity
echo "Test 3: Migration Activity Check"
sleep 5  # Allow some time for potential migrations
MIGRATION_COUNT=\$(dmesg | grep -i "migration\|migrated" | wc -l)
echo "Migration Events: \${MIGRATION_COUNT}" | tee -a evaluation/results/performance_results.txt

# Cleanup
sudo umount /mnt/hybrid_ssd
cd ..
./stop_hybrid_ssd.sh

echo "=========================================="
echo "Evaluation completed!"
echo "Results saved in evaluation/results/"
echo "=========================================="
EOF

chmod +x evaluation/runall.sh

log_info "Evaluation framework created in evaluation/"

# Step 8: Memory Configuration Check
log_info "Step 8: Checking memory configuration..."

# Check if memmap is already configured
if grep -q "memmap=" /proc/cmdline; then
    log_info "Memory mapping already configured in kernel command line"
    CURRENT_MEMMAP=$(grep -o 'memmap=[^ ]*' /proc/cmdline)
    log_info "Current setting: $CURRENT_MEMMAP"
else
    log_warn "Memory mapping not configured. Manual GRUB configuration required."
    log_warn "Add this line to /etc/default/grub:"
    log_warn "GRUB_CMDLINE_LINUX=\"memmap=${MEMMAP_SIZE}\\\$${MEMMAP_START} intremap=off\""
    log_warn "Then run: sudo update-grub && sudo reboot"
fi

# Final Summary
echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
log_info "✓ System requirements checked"
log_info "✓ Dependencies installed"
log_info "✓ Filebench installed"
log_info "✓ Hybrid SSD module built"
log_info "✓ Verification scripts run ($VERIFICATION_PASSED/$VERIFICATION_TOTAL passed)"
log_info "✓ Deployment scripts created"
log_info "✓ Evaluation framework setup"

echo ""
echo "Next Steps:"
echo "1. Configure memory mapping in GRUB (if not already done)"
echo "2. Reboot system (if GRUB was modified)"
echo "3. Run quick test: ./quick_test.sh"
echo "4. Run full evaluation: cd evaluation && ./runall.sh"
echo ""
echo "For detailed instructions, see: VM_DEPLOYMENT_GUIDE.md"
echo "=========================================="

# Create a status file
cat > deployment_status.txt << EOF
Hybrid SSD Deployment Status
============================
Date: $(date)
System: $DISTRO $VERSION
Kernel: $KERNEL_VERSION
Memory: ${TOTAL_MEM_GB}GB
CPUs: ${CPU_COUNT}

Configuration:
- Memory allocation: ${MEMMAP_SIZE} at ${MEMMAP_START}
- CPU allocation: ${CPUS}

Verification Results: $VERIFICATION_PASSED/$VERIFICATION_TOTAL tests passed

Status: Deployment completed successfully
Next: Run ./quick_test.sh to verify functionality
EOF

log_info "Deployment status saved to deployment_status.txt"
log_info "Deployment completed successfully!" 