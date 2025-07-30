#!/bin/bash

# Main evaluation script for hybrid SSD
# Based on FAST '24 Artifacts Evaluation methodology

source commonvariable.sh

log_info "Starting comprehensive hybrid SSD evaluation"

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites"
    
    # Check if fio is installed
    if ! command -v fio &> /dev/null; then
        log_error "fio is not installed. Please install fio first."
        exit 1
    fi
    
    # Check if sqlite3 is installed
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 is not installed. Please install sqlite3 first."
        exit 1
    fi
    
    # Check if filebench is installed
    if ! command -v filebench &> /dev/null; then
        log_error "filebench is not installed. Please install filebench first."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq first."
        exit 1
    fi
    
    # Check if bc is installed
    if ! command -v bc &> /dev/null; then
        log_error "bc is not installed. Please install bc first."
        exit 1
    fi
    
    log_info "All prerequisites are satisfied"
}

# Function to get system information
get_system_info() {
    log_info "Getting system information"
    get_system_info
    
    # Save system info to file
    local sysinfo_file="$RESULTS_DIR/system_info.txt"
    echo "=== System Information ===" > $sysinfo_file
    echo "CPU: $(nproc) cores" >> $sysinfo_file
    echo "Memory: $(free -h | grep Mem | awk '{print $2}')" >> $sysinfo_file
    echo "NUMA nodes: $(numactl -H | grep available | wc -l)" >> $sysinfo_file
    echo "Kernel: $(uname -r)" >> $sysinfo_file
    echo "OS: $(lsb_release -d | cut -f2)" >> $sysinfo_file
    echo "Date: $(date)" >> $sysinfo_file
    
    log_info "System information saved to $sysinfo_file"
}

# Function to initialize evaluation
initialize_evaluation() {
    log_info "Initializing evaluation"
    
    # Create results directory
    mkdir -p $RESULTS_DIR
    
    # Initialize metrics file
    echo "scenario,workload_type,throughput,iops,latency" > $METRICS_FILE
    
    # Get system information
    get_system_info
    
    # Get hybrid SSD statistics
    ./scripts/setdevice.sh stats
    
    log_info "Evaluation initialized"
}

# Function to run hypothetical workloads
run_hypothetical_workloads() {
    log_info "Running hypothetical workloads"
    
    cd scripts
    ./hypothetical_workloads.sh all
    cd ..
    
    log_info "Hypothetical workloads completed"
}

# Function to run SQLite workloads
run_sqlite_workloads() {
    log_info "Running SQLite workloads"
    
    cd scripts
    ./sqlite_workload.sh all
    cd ..
    
    log_info "SQLite workloads completed"
}

# Function to run Filebench workloads
run_filebench_workloads() {
    log_info "Running Filebench workloads"
    
    cd scripts
    ./filebench_workload.sh all
    cd ..
    
    log_info "Filebench workloads completed"
}

# Function to generate summary report
generate_summary_report() {
    log_info "Generating summary report"
    
    local report_file="$RESULTS_DIR/summary_report.txt"
    
    echo "=== Hybrid SSD Evaluation Summary Report ===" > $report_file
    echo "Date: $(date)" >> $report_file
    echo "" >> $report_file
    
    echo "=== System Configuration ===" >> $report_file
    echo "SLC Ratio: $SLC_RATIO" >> $report_file
    echo "QLC Ratio: $QLC_RATIO" >> $report_file
    echo "Migration Interval: $MIGRATION_INTERVAL ms" >> $report_file
    echo "Hot Threshold: $HOT_THRESHOLD" >> $report_file
    echo "Cold Threshold: $COLD_THRESHOLD" >> $report_file
    echo "" >> $report_file
    
    echo "=== Test Scenarios ===" >> $report_file
    for scenario in "${SCENARIOS[@]}"; do
        echo "- $scenario" >> $report_file
    done
    echo "" >> $report_file
    
    echo "=== Workload Types ===" >> $report_file
    for workload in "${WORKLOAD_TYPES[@]}"; do
        echo "- $workload" >> $report_file
    done
    echo "" >> $report_file
    
    echo "=== Results Summary ===" >> $report_file
    if [ -f $METRICS_FILE ]; then
        echo "Total tests run: $(wc -l < $METRICS_FILE)" >> $report_file
        echo "" >> $report_file
        
        # Calculate averages for each scenario
        for scenario in "${SCENARIOS[@]}"; do
            echo "--- $scenario ---" >> $report_file
            grep "^$scenario," $METRICS_FILE | awk -F',' '{
                sum_throughput += $3
                sum_iops += $4
                sum_latency += $5
                count++
            } END {
                if (count > 0) {
                    printf "Average Throughput: %.2f KB/s\n", sum_throughput/count
                    printf "Average IOPS: %.2f\n", sum_iops/count
                    printf "Average Latency: %.2f ns\n", sum_latency/count
                }
            }' >> $report_file
            echo "" >> $report_file
        done
    fi
    
    log_info "Summary report generated: $report_file"
}

# Function to create performance comparison
create_performance_comparison() {
    log_info "Creating performance comparison"
    
    local comparison_file="$RESULTS_DIR/performance_comparison.csv"
    
    echo "scenario,workload_type,throughput,iops,latency" > $comparison_file
    
    if [ -f $METRICS_FILE ]; then
        # Copy metrics to comparison file
        tail -n +2 $METRICS_FILE >> $comparison_file
    fi
    
    log_info "Performance comparison saved: $comparison_file"
}

# Function to create charts (if gnuplot is available)
create_charts() {
    if command -v gnuplot &> /dev/null; then
        log_info "Creating performance charts"
        
        # Create throughput comparison chart
        cat > /tmp/throughput_chart.gp << EOF
set terminal png size 800,600
set output '$RESULTS_DIR/throughput_comparison.png'
set title 'Hybrid SSD Throughput Comparison'
set xlabel 'Scenario'
set ylabel 'Throughput (KB/s)'
set style data histogram
set style histogram clustered
set style fill solid border -1
set boxwidth 0.8
plot '$METRICS_FILE' using 3:xtic(1) title 'Throughput'
EOF
        
        gnuplot /tmp/throughput_chart.gp
        
        # Create IOPS comparison chart
        cat > /tmp/iops_chart.gp << EOF
set terminal png size 800,600
set output '$RESULTS_DIR/iops_comparison.png'
set title 'Hybrid SSD IOPS Comparison'
set xlabel 'Scenario'
set ylabel 'IOPS'
set style data histogram
set style histogram clustered
set style fill solid border -1
set boxwidth 0.8
plot '$METRICS_FILE' using 4:xtic(1) title 'IOPS'
EOF
        
        gnuplot /tmp/iops_chart.gp
        
        log_info "Performance charts created"
    else
        log_info "gnuplot not available, skipping charts"
    fi
}

# Function to cleanup temporary files
cleanup_temp_files() {
    log_info "Cleaning up temporary files"
    
    # Remove temporary fio files
    rm -f /tmp/*.fio
    
    # Remove temporary gnuplot files
    rm -f /tmp/*.gp
    
    log_info "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting comprehensive hybrid SSD evaluation"
    
    # Check prerequisites
    check_prerequisites
    
    # Initialize evaluation
    initialize_evaluation
    
    # Run all workload tests
    run_hypothetical_workloads
    run_sqlite_workloads
    run_filebench_workloads
    
    # Generate reports
    generate_summary_report
    create_performance_comparison
    create_charts
    
    # Cleanup
    cleanup_temp_files
    
    log_info "Comprehensive hybrid SSD evaluation completed"
    log_info "Results available in: $RESULTS_DIR"
}

# Check command line arguments
case "$1" in
    "hypothetical")
        log_info "Running hypothetical workloads only"
        check_prerequisites
        initialize_evaluation
        run_hypothetical_workloads
        generate_summary_report
        ;;
    "sqlite")
        log_info "Running SQLite workloads only"
        check_prerequisites
        initialize_evaluation
        run_sqlite_workloads
        generate_summary_report
        ;;
    "filebench")
        log_info "Running Filebench workloads only"
        check_prerequisites
        initialize_evaluation
        run_filebench_workloads
        generate_summary_report
        ;;
    "all")
        main
        ;;
    *)
        echo "Usage: $0 {hypothetical|sqlite|filebench|all}"
        echo "  hypothetical  - Run hypothetical workloads only"
        echo "  sqlite        - Run SQLite workloads only"
        echo "  filebench     - Run Filebench workloads only"
        echo "  all           - Run all workloads (default)"
        exit 1
        ;;
esac 