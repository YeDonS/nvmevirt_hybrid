#!/bin/bash

# Hypothetical workloads for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

source ../commonvariable.sh

log_info "Starting hypothetical workload evaluation"

# Function to run sequential write test
run_sequential_write() {
    local scenario=$1
    local result_file="$RESULTS_DIR/sequential_write_${scenario}.json"
    
    log_performance "Running sequential write test for scenario: $scenario"
    
    # Create fio job file
    cat > /tmp/sequential_write.fio << EOF
[global]
ioengine=libaio
direct=1
size=10G
runtime=300
group_reporting
output-format=json
output=$result_file

[sequential_write]
filename=/dev/$DATA_NAME
rw=write
bs=4k
iodepth=32
numjobs=4
EOF
    
    # Run fio test
    fio /tmp/sequential_write.fio
    
    # Extract results
    local throughput=$(cat $result_file | jq -r '.jobs[0].write.bw')
    local iops=$(cat $result_file | jq -r '.jobs[0].write.iops')
    local latency=$(cat $result_file | jq -r '.jobs[0].write.lat_ns.mean')
    
    log_performance "Sequential write results - Throughput: ${throughput}KB/s, IOPS: $iops, Latency: ${latency}ns"
    
    echo "$scenario,sequential_write,$throughput,$iops,$latency" >> $METRICS_FILE
}

# Function to run random write test
run_random_write() {
    local scenario=$1
    local result_file="$RESULTS_DIR/random_write_${scenario}.json"
    
    log_performance "Running random write test for scenario: $scenario"
    
    # Create fio job file
    cat > /tmp/random_write.fio << EOF
[global]
ioengine=libaio
direct=1
size=10G
runtime=300
group_reporting
output-format=json
output=$result_file

[random_write]
filename=/dev/$DATA_NAME
rw=randwrite
bs=4k
iodepth=32
numjobs=4
EOF
    
    # Run fio test
    fio /tmp/random_write.fio
    
    # Extract results
    local throughput=$(cat $result_file | jq -r '.jobs[0].write.bw')
    local iops=$(cat $result_file | jq -r '.jobs[0].write.iops')
    local latency=$(cat $result_file | jq -r '.jobs[0].write.lat_ns.mean')
    
    log_performance "Random write results - Throughput: ${throughput}KB/s, IOPS: $iops, Latency: ${latency}ns"
    
    echo "$scenario,random_write,$throughput,$iops,$latency" >> $METRICS_FILE
}

# Function to run sequential read test
run_sequential_read() {
    local scenario=$1
    local result_file="$RESULTS_DIR/sequential_read_${scenario}.json"
    
    log_performance "Running sequential read test for scenario: $scenario"
    
    # Create fio job file
    cat > /tmp/sequential_read.fio << EOF
[global]
ioengine=libaio
direct=1
size=10G
runtime=300
group_reporting
output-format=json
output=$result_file

[sequential_read]
filename=/dev/$DATA_NAME
rw=read
bs=4k
iodepth=32
numjobs=4
EOF
    
    # Run fio test
    fio /tmp/sequential_read.fio
    
    # Extract results
    local throughput=$(cat $result_file | jq -r '.jobs[0].read.bw')
    local iops=$(cat $result_file | jq -r '.jobs[0].read.iops')
    local latency=$(cat $result_file | jq -r '.jobs[0].read.lat_ns.mean')
    
    log_performance "Sequential read results - Throughput: ${throughput}KB/s, IOPS: $iops, Latency: ${latency}ns"
    
    echo "$scenario,sequential_read,$throughput,$iops,$latency" >> $METRICS_FILE
}

# Function to run random read test
run_random_read() {
    local scenario=$1
    local result_file="$RESULTS_DIR/random_read_${scenario}.json"
    
    log_performance "Running random read test for scenario: $scenario"
    
    # Create fio job file
    cat > /tmp/random_read.fio << EOF
[global]
ioengine=libaio
direct=1
size=10G
runtime=300
group_reporting
output-format=json
output=$result_file

[random_read]
filename=/dev/$DATA_NAME
rw=randread
bs=4k
iodepth=32
numjobs=4
EOF
    
    # Run fio test
    fio /tmp/random_read.fio
    
    # Extract results
    local throughput=$(cat $result_file | jq -r '.jobs[0].read.bw')
    local iops=$(cat $result_file | jq -r '.jobs[0].read.iops')
    local latency=$(cat $result_file | jq -r '.jobs[0].read.lat_ns.mean')
    
    log_performance "Random read results - Throughput: ${throughput}KB/s, IOPS: $iops, Latency: ${latency}ns"
    
    echo "$scenario,random_read,$throughput,$iops,$latency" >> $METRICS_FILE
}

# Function to run mixed workload test
run_mixed_workload() {
    local scenario=$1
    local result_file="$RESULTS_DIR/mixed_workload_${scenario}.json"
    
    log_performance "Running mixed workload test for scenario: $scenario"
    
    # Create fio job file with mixed read/write
    cat > /tmp/mixed_workload.fio << EOF
[global]
ioengine=libaio
direct=1
size=10G
runtime=300
group_reporting
output-format=json
output=$result_file

[mixed_read]
filename=/dev/$DATA_NAME
rw=randread
bs=4k
iodepth=16
numjobs=2
runtime=300

[mixed_write]
filename=/dev/$DATA_NAME
rw=randwrite
bs=4k
iodepth=16
numjobs=2
runtime=300
EOF
    
    # Run fio test
    fio /tmp/mixed_workload.fio
    
    # Extract results
    local read_throughput=$(cat $result_file | jq -r '.jobs[0].read.bw')
    local write_throughput=$(cat $result_file | jq -r '.jobs[1].write.bw')
    local total_throughput=$((read_throughput + write_throughput))
    
    log_performance "Mixed workload results - Read: ${read_throughput}KB/s, Write: ${write_throughput}KB/s, Total: ${total_throughput}KB/s"
    
    echo "$scenario,mixed_workload,$total_throughput,0,0" >> $METRICS_FILE
}

# Function to create fragmentation
create_fragmentation() {
    local level=$1
    local result_file="$RESULTS_DIR/fragmentation_${level}.log"
    
    log_info "Creating fragmentation level: $level"
    
    case $level in
        "low")
            # Create some fragmentation
            dd if=/dev/zero of=/mnt/hybrid_test/file1 bs=1M count=100
            dd if=/dev/zero of=/mnt/hybrid_test/file2 bs=1M count=100
            rm /mnt/hybrid_test/file1
            ;;
        "medium")
            # Create moderate fragmentation
            for i in {1..10}; do
                dd if=/dev/zero of=/mnt/hybrid_test/file$i bs=1M count=50
            done
            for i in {1..5}; do
                rm /mnt/hybrid_test/file$i
            done
            ;;
        "high")
            # Create high fragmentation
            for i in {1..20}; do
                dd if=/dev/zero of=/mnt/hybrid_test/file$i bs=1M count=25
            done
            for i in {1..15}; do
                rm /mnt/hybrid_test/file$i
            done
            ;;
    esac
    
    log_info "Fragmentation created: $level"
}

# Function to run all tests for a scenario
run_scenario_tests() {
    local scenario=$1
    
    log_info "Running tests for scenario: $scenario"
    
    # Setup device
    ./setdevice.sh setup
    
    # Create fragmentation if needed
    if [[ $scenario == *"fragmented"* ]]; then
        create_fragmentation $FRAGMENTATION_LEVEL
    fi
    
    # Run all workload tests
    run_sequential_write $scenario
    run_random_write $scenario
    run_sequential_read $scenario
    run_random_read $scenario
    run_mixed_workload $scenario
    
    # Cleanup
    ./setdevice.sh cleanup
    
    log_info "Completed tests for scenario: $scenario"
}

# Function to run migration test
run_migration_test() {
    local result_file="$RESULTS_DIR/migration_test.json"
    
    log_info "Running migration performance test"
    
    # Setup device
    ./setdevice.sh setup
    
    # Run workload that triggers migration
    cat > /tmp/migration_test.fio << EOF
[global]
ioengine=libaio
direct=1
size=5G
runtime=600
group_reporting
output-format=json
output=$result_file

[migration_write]
filename=/dev/$DATA_NAME
rw=randwrite
bs=4k
iodepth=32
numjobs=4
runtime=600
EOF
    
    # Run test and monitor migration
    fio /tmp/migration_test.fio &
    local fio_pid=$!
    
    # Monitor migration for 600 seconds
    monitor_migration 600 "$RESULTS_DIR/migration_stats.txt"
    
    wait $fio_pid
    
    # Extract results
    local throughput=$(cat $result_file | jq -r '.jobs[0].write.bw')
    log_performance "Migration test results - Throughput: ${throughput}KB/s"
    
    echo "migration_test,mixed_workload,$throughput,0,0" >> $METRICS_FILE
    
    # Cleanup
    ./setdevice.sh cleanup
}

# Main execution
case "$1" in
    "contiguous")
        run_scenario_tests "contiguous"
        ;;
    "fragmented_slc")
        run_scenario_tests "fragmented_slc"
        ;;
    "fragmented_qlc")
        run_scenario_tests "fragmented_qlc"
        ;;
    "migration")
        run_migration_test
        ;;
    "mixed")
        run_scenario_tests "mixed_workload"
        ;;
    "all")
        log_info "Running all hypothetical workload tests"
        
        # Initialize metrics file
        echo "scenario,workload_type,throughput,iops,latency" > $METRICS_FILE
        
        # Run all scenarios
        run_scenario_tests "contiguous"
        run_scenario_tests "fragmented_slc"
        run_scenario_tests "fragmented_qlc"
        run_migration_test
        run_scenario_tests "mixed_workload"
        
        log_info "All hypothetical workload tests completed"
        ;;
    *)
        echo "Usage: $0 {contiguous|fragmented_slc|fragmented_qlc|migration|mixed|all}"
        echo "  contiguous      - Baseline contiguous workload"
        echo "  fragmented_slc  - Fragmented workload on SLC"
        echo "  fragmented_qlc  - Fragmented workload on QLC"
        echo "  migration       - Migration performance test"
        echo "  mixed           - Mixed SLC/QLC workload"
        echo "  all             - Run all tests"
        exit 1
        ;;
esac 