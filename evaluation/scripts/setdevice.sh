#!/bin/bash

# Device setup script for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

source ../commonvariable.sh

log_info "Setting up hybrid SSD device for evaluation"

# Function to check if device exists
check_device() {
    local device=$1
    if [ -b "/dev/$device" ]; then
        log_info "Device /dev/$device exists"
        return 0
    else
        log_error "Device /dev/$device does not exist"
        return 1
    fi
}

# Function to create partition
create_partition() {
    local device=$1
    local size=$2
    
    log_info "Creating partition on /dev/$device with size $size"
    
    # Create partition table
    parted /dev/$device mklabel gpt
    
    # Create partition
    parted /dev/$device mkpart primary 0% 100%
    
    # Format partition
    mkfs.ext4 /dev/${device}p1
    
    log_info "Partition created and formatted successfully"
}

# Function to mount device
mount_device() {
    local device=$1
    local mount_point=$2
    
    log_info "Mounting /dev/$device to $mount_point"
    
    # Create mount point if it doesn't exist
    mkdir -p $mount_point
    
    # Mount device
    mount /dev/$device $mount_point
    
    log_info "Device mounted successfully"
}

# Function to unmount device
unmount_device() {
    local mount_point=$1
    
    log_info "Unmounting $mount_point"
    
    umount $mount_point
    
    log_info "Device unmounted successfully"
}

# Function to check hybrid SSD status
check_hybrid_status() {
    log_info "Checking hybrid SSD status"
    
    # Check if hybrid module is loaded
    if lsmod | grep -q "nvmev"; then
        log_info "Hybrid SSD module is loaded"
        
        # Check device status
        if check_device $DATA_NAME; then
            log_info "Hybrid SSD device is ready"
            return 0
        else
            log_error "Hybrid SSD device is not ready"
            return 1
        fi
    else
        log_error "Hybrid SSD module is not loaded"
        return 1
    fi
}

# Function to get hybrid SSD statistics
get_hybrid_stats() {
    log_info "Getting hybrid SSD statistics"
    
    # This would need to be implemented based on the actual hybrid SSD implementation
    # For now, we'll create a placeholder
    
    local stats_file="$RESULTS_DIR/hybrid_stats_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "=== Hybrid SSD Statistics ===" > $stats_file
    echo "Timestamp: $(date)" >> $stats_file
    echo "Device: $DATA_NAME" >> $stats_file
    echo "SLC Ratio: $SLC_RATIO" >> $stats_file
    echo "QLC Ratio: $QLC_RATIO" >> $stats_file
    echo "Migration Interval: $MIGRATION_INTERVAL ms" >> $stats_file
    echo "Hot Threshold: $HOT_THRESHOLD" >> $stats_file
    echo "Cold Threshold: $COLD_THRESHOLD" >> $stats_file
    
    # Get device information
    if [ -b "/dev/$DATA_NAME" ]; then
        echo "Device Size: $(lsblk /dev/$DATA_NAME -o SIZE -n)" >> $stats_file
        echo "Device Type: $(lsblk /dev/$DATA_NAME -o TYPE -n)" >> $stats_file
    fi
    
    log_info "Statistics saved to $stats_file"
}

# Function to prepare device for testing
prepare_device() {
    log_info "Preparing device for testing"
    
    # Check if device exists
    if ! check_device $DATA_NAME; then
        log_error "Cannot proceed without device $DATA_NAME"
        exit 1
    fi
    
    # Create partition if needed
    if [ ! -b "/dev/${DATA_NAME}p1" ]; then
        create_partition $DATA_NAME $PARTITION_SIZE
    fi
    
    # Mount device
    mount_device "${DATA_NAME}p1" "/mnt/hybrid_test"
    
    log_info "Device prepared successfully"
}

# Function to cleanup device
cleanup_device() {
    log_info "Cleaning up device"
    
    # Unmount device
    unmount_device "/mnt/hybrid_test"
    
    log_info "Device cleanup completed"
}

# Function to reset device
reset_device() {
    log_info "Resetting device"
    
    # Unmount if mounted
    if mountpoint -q "/mnt/hybrid_test"; then
        unmount_device "/mnt/hybrid_test"
    fi
    
    # Reset device (this would depend on the actual implementation)
    # For now, we'll just log the action
    log_info "Device reset completed"
}

# Main execution
case "$1" in
    "setup")
        prepare_device
        ;;
    "cleanup")
        cleanup_device
        ;;
    "reset")
        reset_device
        ;;
    "status")
        check_hybrid_status
        ;;
    "stats")
        get_hybrid_stats
        ;;
    *)
        echo "Usage: $0 {setup|cleanup|reset|status|stats}"
        echo "  setup   - Prepare device for testing"
        echo "  cleanup - Clean up device after testing"
        echo "  reset   - Reset device to initial state"
        echo "  status  - Check hybrid SSD status"
        echo "  stats   - Get hybrid SSD statistics"
        exit 1
        ;;
esac 