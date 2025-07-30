#!/bin/bash

# Filebench workload for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

source ../commonvariable.sh

log_info "Starting Filebench workload evaluation"

# Function to create Filebench workload file
create_filebench_workload() {
    local workload_type=$1
    local workload_file="/tmp/filebench_${workload_type}.f"
    
    log_info "Creating Filebench workload: $workload_type"
    
    case $workload_type in
        "fileserver")
            cat > $workload_file << EOF
# FileServer workload
define fileset name=bigfileset,path=/mnt/hybrid_test/fileserver,filesize=10k,entries=1000
define fileset name=logfileset,path=/mnt/hybrid_test/fileserver,filesize=50k,entries=100

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=4
  {
    flowop createfile name=createfile1,filesetname=bigfileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=10k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile1,fd=1,iosize=10k
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=bigfileset
    flowop statfile name=statfile1,filesetname=bigfileset
  }
}

run 60
EOF
            ;;
        "webserver")
            cat > $workload_file << EOF
# WebServer workload
define fileset name=webfileset,path=/mnt/hybrid_test/webserver,filesize=15k,entries=1000

define process name=webreader,instances=1
{
  thread name=webreaderthread,memsize=10m,instances=4
  {
    flowop createfile name=createfile1,filesetname=webfileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=15k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=webfileset,fd=1
    flowop readwholefile name=readfile1,fd=1,iosize=15k
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=webfileset
  }
}

run 60
EOF
            ;;
        "varmail")
            cat > $workload_file << EOF
# Varmail workload
define fileset name=varmailfileset,path=/mnt/hybrid_test/varmail,filesize=16k,entries=1000

define process name=varmailreader,instances=1
{
  thread name=varmailreaderthread,memsize=10m,instances=4
  {
    flowop createfile name=createfile1,filesetname=varmailfileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=16k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=varmailfileset,fd=1
    flowop readwholefile name=readfile1,fd=1,iosize=16k
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=varmailfileset
  }
}

run 60
EOF
            ;;
        "randomread")
            cat > $workload_file << EOF
# Random Read workload
define fileset name=randomfileset,path=/mnt/hybrid_test/randomread,filesize=50k,entries=1000

define process name=randomreader,instances=1
{
  thread name=randomreaderthread,memsize=10m,instances=4
  {
    flowop createfile name=createfile1,filesetname=randomfileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=50k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=randomfileset,fd=1
    flowop readrandom name=readrandom1,fd=1,iosize=4k,iters=1000
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=randomfileset
  }
}

run 60
EOF
            ;;
        "randomwrite")
            cat > $workload_file << EOF
# Random Write workload
define fileset name=randomwritefileset,path=/mnt/hybrid_test/randomwrite,filesize=50k,entries=1000

define process name=randomwriter,instances=1
{
  thread name=randomwriterthread,memsize=10m,instances=4
  {
    flowop createfile name=createfile1,filesetname=randomwritefileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=50k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=randomwritefileset,fd=1
    flowop writerandom name=writerandom1,fd=1,iosize=4k,iters=1000
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=randomwritefileset
  }
}

run 60
EOF
            ;;
    esac
    
    echo $workload_file
}

# Function to run Filebench workload
run_filebench_workload() {
    local workload_type=$1
    local scenario=$2
    local result_file="$RESULTS_DIR/filebench_${workload_type}_${scenario}.txt"
    
    log_performance "Running Filebench $workload_type workload for scenario: $scenario"
    
    # Create workload file
    local workload_file=$(create_filebench_workload $workload_type)
    
    # Create directories
    mkdir -p /mnt/hybrid_test/fileserver
    mkdir -p /mnt/hybrid_test/webserver
    mkdir -p /mnt/hybrid_test/varmail
    mkdir -p /mnt/hybrid_test/randomread
    mkdir -p /mnt/hybrid_test/randomwrite
    
    # Run Filebench
    filebench -f $workload_file > $result_file 2>&1
    
    # Extract results
    local throughput=$(grep "IO Summary" $result_file | awk '{print $4}')
    local iops=$(grep "IO Summary" $result_file | awk '{print $6}')
    
    log_performance "Filebench $workload_type results - Throughput: ${throughput} ops/s, IOPS: $iops"
    
    echo "$scenario,filebench_${workload_type},$throughput,$iops,0" >> $METRICS_FILE
    
    # Cleanup
    rm -f $workload_file
}

# Function to create fragmentation for Filebench
create_filebench_fragmentation() {
    local level=$1
    
    log_info "Creating Filebench fragmentation level: $level"
    
    case $level in
        "low")
            # Create some fragmentation
            for i in {1..10}; do
                dd if=/dev/zero of=/mnt/hybrid_test/file$i bs=1M count=10
            done
            for i in {1..5}; do
                rm /mnt/hybrid_test/file$i
            done
            ;;
        "medium")
            # Create moderate fragmentation
            for i in {1..20}; do
                dd if=/dev/zero of=/mnt/hybrid_test/file$i bs=1M count=5
            done
            for i in {1..10}; do
                rm /mnt/hybrid_test/file$i
            done
            ;;
        "high")
            # Create high fragmentation
            for i in {1..40}; do
                dd if=/dev/zero of=/mnt/hybrid_test/file$i bs=1M count=2
            done
            for i in {1..30}; do
                rm /mnt/hybrid_test/file$i
            done
            ;;
    esac
    
    log_info "Filebench fragmentation created: $level"
}

# Function to run all Filebench tests for a scenario
run_filebench_scenario() {
    local scenario=$1
    
    log_info "Running Filebench tests for scenario: $scenario"
    
    # Setup device
    ./setdevice.sh setup
    
    # Create fragmentation if needed
    if [[ $scenario == *"fragmented"* ]]; then
        create_filebench_fragmentation $FRAGMENTATION_LEVEL
    fi
    
    # Run all Filebench workloads
    run_filebench_workload "fileserver" $scenario
    run_filebench_workload "webserver" $scenario
    run_filebench_workload "varmail" $scenario
    run_filebench_workload "randomread" $scenario
    run_filebench_workload "randomwrite" $scenario
    
    # Cleanup
    ./setdevice.sh cleanup
    
    log_info "Completed Filebench tests for scenario: $scenario"
}

# Function to run Filebench migration test
run_filebench_migration_test() {
    local result_file="$RESULTS_DIR/filebench_migration_test.txt"
    
    log_info "Running Filebench migration performance test"
    
    # Setup device
    ./setdevice.sh setup
    
    # Create intensive Filebench workload that triggers migration
    cat > /tmp/filebench_migration.f << EOF
# Migration test workload
define fileset name=migrationfileset,path=/mnt/hybrid_test/migration,filesize=100k,entries=500

define process name=migrationreader,instances=1
{
  thread name=migrationreaderthread,memsize=10m,instances=8
  {
    flowop createfile name=createfile1,filesetname=migrationfileset,fd=1
    flowop writewholefile name=writefile1,src=createfile1,fd=1,iosize=100k
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile1,filesetname=migrationfileset,fd=1
    flowop readwholefile name=readfile1,fd=1,iosize=100k
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=migrationfileset
    flowop statfile name=statfile1,filesetname=migrationfileset
  }
}

run 300
EOF
    
    # Create directory
    mkdir -p /mnt/hybrid_test/migration
    
    # Run Filebench
    filebench -f /tmp/filebench_migration.f > $result_file 2>&1
    
    # Extract results
    local throughput=$(grep "IO Summary" $result_file | awk '{print $4}')
    local iops=$(grep "IO Summary" $result_file | awk '{print $6}')
    
    log_performance "Filebench migration test results - Throughput: ${throughput} ops/s, IOPS: $iops"
    
    echo "filebench_migration,filebench_mixed,$throughput,$iops,0" >> $METRICS_FILE
    
    # Cleanup
    rm -f /tmp/filebench_migration.f
    ./setdevice.sh cleanup
}

# Main execution
case "$1" in
    "contiguous")
        run_filebench_scenario "contiguous"
        ;;
    "fragmented")
        run_filebench_scenario "fragmented"
        ;;
    "migration")
        run_filebench_migration_test
        ;;
    "fileserver")
        run_filebench_workload "fileserver" "standalone"
        ;;
    "webserver")
        run_filebench_workload "webserver" "standalone"
        ;;
    "varmail")
        run_filebench_workload "varmail" "standalone"
        ;;
    "randomread")
        run_filebench_workload "randomread" "standalone"
        ;;
    "randomwrite")
        run_filebench_workload "randomwrite" "standalone"
        ;;
    "all")
        log_info "Running all Filebench workload tests"
        
        # Initialize metrics file if not exists
        if [ ! -f $METRICS_FILE ]; then
            echo "scenario,workload_type,throughput,iops,latency" > $METRICS_FILE
        fi
        
        # Run all scenarios
        run_filebench_scenario "contiguous"
        run_filebench_scenario "fragmented"
        run_filebench_migration_test
        
        log_info "All Filebench workload tests completed"
        ;;
    *)
        echo "Usage: $0 {contiguous|fragmented|migration|fileserver|webserver|varmail|randomread|randomwrite|all}"
        echo "  contiguous   - Baseline Filebench workload"
        echo "  fragmented   - Fragmented Filebench workload"
        echo "  migration    - Filebench migration performance test"
        echo "  fileserver   - FileServer workload only"
        echo "  webserver    - WebServer workload only"
        echo "  varmail      - Varmail workload only"
        echo "  randomread   - Random read workload only"
        echo "  randomwrite  - Random write workload only"
        echo "  all          - Run all Filebench tests"
        exit 1
        ;;
esac 