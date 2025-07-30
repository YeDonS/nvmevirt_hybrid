#!/bin/bash

# Common variables for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

# System Configuration
export SYSTEM_MEMORY="128G"
export EMULATED_SSD_SIZE="60G"
export MEMORY_START="256G"
export NUMA_DOMAIN="2"
export CPU_CORES="131,132,135,136"

# Device Configuration
export DATA_NAME="nvme4n1"
export JOURNAL_NAME="sdb"
export PARTITION_SIZE="50G"

# Test Configuration
export TEST_DURATION="300"  # 5 minutes per test
export WARMUP_TIME="60"     # 1 minute warmup
export COOLDOWN_TIME="30"   # 30 seconds cooldown

# Workload Configuration
export WORKLOAD_THREADS="4"
export WORKLOAD_SIZE="10G"
export FRAGMENTATION_LEVEL="high"  # low, medium, high

# Hybrid SSD Configuration
export SLC_RATIO="0.2"      # 20% SLC
export QLC_RATIO="0.8"      # 80% QLC
export MIGRATION_INTERVAL="1000"  # milliseconds
export HOT_THRESHOLD="10"
export COLD_THRESHOLD="2"

# Performance Metrics
export METRICS_FILE="evaluation/results/metrics.csv"
export LOG_FILE="evaluation/results/hybrid_ssd_test.log"

# Test Scenarios
export SCENARIOS=(
    "contiguous"           # Baseline: contiguous writes
    "fragmented_slc"       # Fragmented writes to SLC
    "fragmented_qlc"       # Fragmented writes to QLC
    "migration_test"       # Migration performance test
    "mixed_workload"       # Mixed SLC/QLC workload
)

# Workload Types
export WORKLOAD_TYPES=(
    "sequential_write"
    "random_write"
    "sequential_read"
    "random_read"
    "mixed_io"
)

# Results Directory
export RESULTS_DIR="evaluation/results"
export WORKLOADS_DIR="evaluation/workloads"
export SCRIPTS_DIR="evaluation/scripts"
export CONFIGS_DIR="evaluation/configs"

# Create directories if they don't exist
mkdir -p $RESULTS_DIR
mkdir -p $WORKLOADS_DIR
mkdir -p $SCRIPTS_DIR
mkdir -p $CONFIGS_DIR

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log_performance() {
    echo "[PERF] $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Performance measurement functions
measure_throughput() {
    local operation=$1
    local size=$2
    local duration=$3
    local result_file=$4
    
    log_performance "Measuring $operation throughput: $size bytes in $duration seconds"
    
    # Use fio for accurate measurement
    fio --name=$operation \
        --filename=/dev/$DATA_NAME \
        --size=$size \
        --time_based \
        --runtime=$duration \
        --ioengine=libaio \
        --direct=1 \
        --bs=4k \
        --iodepth=32 \
        --numjobs=4 \
        --group_reporting \
        --output-format=json \
        --output=$result_file
    
    # Extract throughput from fio output
    local throughput=$(cat $result_file | jq -r '.jobs[0].write.bw')
    echo $throughput
}

measure_latency() {
    local operation=$1
    local size=$2
    local duration=$3
    local result_file=$4
    
    log_performance "Measuring $operation latency: $size bytes in $duration seconds"
    
    fio --name=$operation \
        --filename=/dev/$DATA_NAME \
        --size=$size \
        --time_based \
        --runtime=$duration \
        --ioengine=libaio \
        --direct=1 \
        --bs=4k \
        --iodepth=1 \
        --numjobs=1 \
        --group_reporting \
        --output-format=json \
        --output=$result_file
    
    # Extract latency from fio output
    local latency=$(cat $result_file | jq -r '.jobs[0].write.lat_ns.mean')
    echo $latency
}

# Migration monitoring functions
monitor_migration() {
    local duration=$1
    local result_file=$2
    
    log_performance "Monitoring migration for $duration seconds"
    
    # Monitor migration statistics
    # This would need to be implemented based on the actual migration tracking
    # For now, we'll create a placeholder
    echo "migration_stats" > $result_file
}

# System information
get_system_info() {
    log_info "System Information:"
    log_info "CPU: $(nproc) cores"
    log_info "Memory: $(free -h | grep Mem | awk '{print $2}')"
    log_info "NUMA nodes: $(numactl -H | grep available | wc -l)"
    log_info "Kernel: $(uname -r)"
}

# Export all variables
export -f log_info log_error log_performance
export -f measure_throughput measure_latency monitor_migration
export -f get_system_info 