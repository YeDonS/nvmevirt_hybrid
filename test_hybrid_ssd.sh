#!/bin/bash

# Test script for hybrid SSD functionality
# This script compiles and tests the hybrid SSD implementation

echo "=== Hybrid SSD Test Script ==="

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "Error: Makefile not found. Please run this script from the project root directory."
    exit 1
fi

# Backup original Makefile
cp Makefile Makefile.backup

# Configure for hybrid SSD
echo "Configuring for hybrid SSD..."
sed -i 's/CONFIG_NVMEVIRT_SSD := y/#CONFIG_NVMEVIRT_SSD := y/' Makefile
sed -i 's/#CONFIG_NVMEVIRT_HYBRID := y/CONFIG_NVMEVIRT_HYBRID := y/' Makefile

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Compile the module
echo "Compiling hybrid SSD module..."
make

if [ $? -ne 0 ]; then
    echo "Error: Compilation failed!"
    # Restore original Makefile
    cp Makefile.backup Makefile
    exit 1
fi

echo "Compilation successful!"

# Check if module was created
if [ ! -f "nvmev.ko" ]; then
    echo "Error: nvmev.ko not found after compilation!"
    # Restore original Makefile
    cp Makefile.backup Makefile
    exit 1
fi

echo "Module nvmev.ko created successfully!"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Note: Module loading requires root privileges."
    echo "To load the module, run: sudo insmod nvmev.ko"
    echo "To unload the module, run: sudo rmmod nvmev"
else
    # Try to load the module
    echo "Loading hybrid SSD module..."
    insmod nvmev.ko
    
    if [ $? -eq 0 ]; then
        echo "Module loaded successfully!"
        echo "Checking module info:"
        lsmod | grep nvmev
        
        echo "Checking dmesg for module messages:"
        dmesg | tail -10
        
        echo "Unloading module..."
        rmmod nvmev
        echo "Module unloaded successfully!"
    else
        echo "Error: Failed to load module!"
        echo "Check dmesg for error messages:"
        dmesg | tail -10
    fi
fi

# Restore original Makefile
echo "Restoring original Makefile..."
cp Makefile.backup Makefile
rm Makefile.backup

echo "=== Test completed ==="
echo ""
echo "Summary of changes made to support hybrid SSD:"
echo "1. Added hybrid storage parameters to ssd.h"
echo "2. Added SLC/QLC latency parameters to ssd_config.h"
echo "3. Modified ssd_init_params() to initialize hybrid storage"
echo "4. Modified ssd_advance_nand() to use different latencies for SLC/QLC"
echo "5. Modified conv_ftl.c to support hybrid storage address mapping"
echo "6. Added hybrid SSD configuration to Makefile"
echo ""
echo "Key features implemented:"
echo "- SLC: 20% capacity, faster latency (25μs read, 80μs write)"
echo "- QLC: 80% capacity, slower latency (50μs read, 561μs write)"
echo "- Automatic storage type selection based on LPN"
echo "- Separate write pointers for SLC and QLC regions"
echo ""
echo "To use hybrid SSD:"
echo "1. Uncomment CONFIG_NVMEVIRT_HYBRID in Makefile"
echo "2. Comment out CONFIG_NVMEVIRT_SSD"
echo "3. Run: make clean && make"
echo "4. Load module: sudo insmod nvmev.ko" 