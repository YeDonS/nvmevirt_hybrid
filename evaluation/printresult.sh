#!/bin/bash

# Result analysis script for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

source commonvariable.sh

log_info "Analyzing hybrid SSD evaluation results"

# Function to print hypothetical workload results
print_hypothetical_results() {
    echo ""
    echo "==== Hypothetical Workload ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        # Get contiguous baseline
        local contiguous_throughput=$(grep "^contiguous," $METRICS_FILE | grep "sequential_write" | awk -F',' '{print $3}')
        if [ ! -z "$contiguous_throughput" ]; then
            echo "Contiguous file: ${contiguous_throughput} KB/s"
            echo ""
        fi
        
        # Get fragmented results
        local fragmented_slc_throughput=$(grep "^fragmented_slc," $METRICS_FILE | grep "sequential_write" | awk -F',' '{print $3}')
        local fragmented_qlc_throughput=$(grep "^fragmented_qlc," $METRICS_FILE | grep "sequential_write" | awk -F',' '{print $3}')
        
        if [ ! -z "$fragmented_slc_throughput" ]; then
            echo "Fragmented SLC without Approach: ${fragmented_slc_throughput} KB/s"
        fi
        if [ ! -z "$fragmented_qlc_throughput" ]; then
            echo "Fragmented QLC without Approach: ${fragmented_qlc_throughput} KB/s"
        fi
        
        # Get migration results
        local migration_throughput=$(grep "^migration_test," $METRICS_FILE | awk -F',' '{print $3}')
        if [ ! -z "$migration_throughput" ]; then
            echo "Migration test: ${migration_throughput} KB/s"
        fi
        
        # Get mixed workload results
        local mixed_throughput=$(grep "^mixed_workload," $METRICS_FILE | grep "mixed_workload" | awk -F',' '{print $3}')
        if [ ! -z "$mixed_throughput" ]; then
            echo "Mixed workload: ${mixed_throughput} KB/s"
        fi
    else
        echo "No metrics file found"
    fi
}

# Function to print SQLite workload results
print_sqlite_results() {
    echo ""
    echo "==== SQLite Workload ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        # Get SQLite results
        local sqlite_contiguous=$(grep "^contiguous," $METRICS_FILE | grep "sqlite" | awk -F',' '{print $3}')
        local sqlite_fragmented=$(grep "^fragmented," $METRICS_FILE | grep "sqlite" | awk -F',' '{print $3}')
        local sqlite_migration=$(grep "^sqlite_migration," $METRICS_FILE | awk -F',' '{print $3}')
        
        if [ ! -z "$sqlite_contiguous" ]; then
            echo "SQLite contiguous: ${sqlite_contiguous} ops/s"
        fi
        if [ ! -z "$sqlite_fragmented" ]; then
            echo "SQLite fragmented: ${sqlite_fragmented} ops/s"
        fi
        if [ ! -z "$sqlite_migration" ]; then
            echo "SQLite migration: ${sqlite_migration} ops/s"
        fi
    else
        echo "No metrics file found"
    fi
}

# Function to print Filebench workload results
print_filebench_results() {
    echo ""
    echo "==== Filebench Workload ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        # Get Filebench results for different workloads
        local fileserver_contiguous=$(grep "^contiguous," $METRICS_FILE | grep "filebench_fileserver" | awk -F',' '{print $3}')
        local fileserver_fragmented=$(grep "^fragmented," $METRICS_FILE | grep "filebench_fileserver" | awk -F',' '{print $3}')
        local fileserver_migration=$(grep "^filebench_migration," $METRICS_FILE | awk -F',' '{print $3}')
        
        local webserver_contiguous=$(grep "^contiguous," $METRICS_FILE | grep "filebench_webserver" | awk -F',' '{print $3}')
        local webserver_fragmented=$(grep "^fragmented," $METRICS_FILE | grep "filebench_webserver" | awk -F',' '{print $3}')
        
        local varmail_contiguous=$(grep "^contiguous," $METRICS_FILE | grep "filebench_varmail" | awk -F',' '{print $3}')
        local varmail_fragmented=$(grep "^fragmented," $METRICS_FILE | grep "filebench_varmail" | awk -F',' '{print $3}')
        
        if [ ! -z "$fileserver_contiguous" ]; then
            echo "FileServer contiguous: ${fileserver_contiguous} ops/s"
        fi
        if [ ! -z "$fileserver_fragmented" ]; then
            echo "FileServer fragmented: ${fileserver_fragmented} ops/s"
        fi
        if [ ! -z "$fileserver_migration" ]; then
            echo "FileServer migration: ${fileserver_migration} ops/s"
        fi
        
        if [ ! -z "$webserver_contiguous" ]; then
            echo "WebServer contiguous: ${webserver_contiguous} ops/s"
        fi
        if [ ! -z "$webserver_fragmented" ]; then
            echo "WebServer fragmented: ${webserver_fragmented} ops/s"
        fi
        
        if [ ! -z "$varmail_contiguous" ]; then
            echo "Varmail contiguous: ${varmail_contiguous} ops/s"
        fi
        if [ ! -z "$varmail_fragmented" ]; then
            echo "Varmail fragmented: ${varmail_fragmented} ops/s"
        fi
    else
        echo "No metrics file found"
    fi
}

# Function to print detailed analysis
print_detailed_analysis() {
    echo ""
    echo "==== Detailed Analysis ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        echo "Total tests completed: $(wc -l < $METRICS_FILE)"
        echo ""
        
        # Analyze by scenario
        echo "Performance by Scenario:"
        for scenario in "${SCENARIOS[@]}"; do
            local count=$(grep "^$scenario," $METRICS_FILE | wc -l)
            if [ $count -gt 0 ]; then
                echo "  $scenario: $count tests"
                
                # Calculate average throughput for this scenario
                local avg_throughput=$(grep "^$scenario," $METRICS_FILE | awk -F',' '{
                    sum += $3
                    count++
                } END {
                    if (count > 0) printf "%.2f", sum/count
                }')
                echo "    Average throughput: ${avg_throughput} KB/s"
            fi
        done
        echo ""
        
        # Analyze by workload type
        echo "Performance by Workload Type:"
        for workload in "${WORKLOAD_TYPES[@]}"; do
            local count=$(grep ",$workload," $METRICS_FILE | wc -l)
            if [ $count -gt 0 ]; then
                echo "  $workload: $count tests"
                
                # Calculate average throughput for this workload
                local avg_throughput=$(grep ",$workload," $METRICS_FILE | awk -F',' '{
                    sum += $3
                    count++
                } END {
                    if (count > 0) printf "%.2f", sum/count
                }')
                echo "    Average throughput: ${avg_throughput} KB/s"
            fi
        done
    else
        echo "No metrics file found for detailed analysis"
    fi
}

# Function to print migration analysis
print_migration_analysis() {
    echo ""
    echo "==== Migration Analysis ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        # Get migration-related results
        local migration_tests=$(grep "migration" $METRICS_FILE | wc -l)
        echo "Migration tests completed: $migration_tests"
        
        if [ $migration_tests -gt 0 ]; then
            echo ""
            echo "Migration Performance:"
            grep "migration" $METRICS_FILE | while IFS=',' read -r scenario workload throughput iops latency; do
                echo "  $scenario: ${throughput} KB/s"
            done
        fi
    else
        echo "No metrics file found for migration analysis"
    fi
}

# Function to print hybrid SSD statistics
print_hybrid_stats() {
    echo ""
    echo "==== Hybrid SSD Statistics ===="
    echo ""
    
    # Check if hybrid stats file exists
    local stats_file=$(ls $RESULTS_DIR/hybrid_stats_*.txt 2>/dev/null | tail -n 1)
    if [ ! -z "$stats_file" ] && [ -f "$stats_file" ]; then
        cat "$stats_file"
    else
        echo "No hybrid SSD statistics available"
    fi
}

# Function to print system information
print_system_info() {
    echo ""
    echo "==== System Information ===="
    echo ""
    
    local sysinfo_file="$RESULTS_DIR/system_info.txt"
    if [ -f "$sysinfo_file" ]; then
        cat "$sysinfo_file"
    else
        echo "No system information available"
    fi
}

# Function to print summary
print_summary() {
    echo ""
    echo "==== Summary ===="
    echo ""
    
    if [ -f $METRICS_FILE ]; then
        local total_tests=$(wc -l < $METRICS_FILE)
        echo "Total tests completed: $total_tests"
        
        # Calculate overall average throughput
        local avg_throughput=$(tail -n +2 $METRICS_FILE | awk -F',' '{
            sum += $3
            count++
        } END {
            if (count > 0) printf "%.2f", sum/count
        }')
        echo "Overall average throughput: ${avg_throughput} KB/s"
        
        # Count scenarios
        local scenario_count=$(tail -n +2 $METRICS_FILE | awk -F',' '{print $1}' | sort | uniq | wc -l)
        echo "Scenarios tested: $scenario_count"
        
        # Count workload types
        local workload_count=$(tail -n +2 $METRICS_FILE | awk -F',' '{print $2}' | sort | uniq | wc -l)
        echo "Workload types tested: $workload_count"
    else
        echo "No test results available"
    fi
}

# Main execution
case "$1" in
    "hypothetical")
        print_hypothetical_results
        ;;
    "sqlite")
        print_sqlite_results
        ;;
    "filebench")
        print_filebench_results
        ;;
    "migration")
        print_migration_analysis
        ;;
    "detailed")
        print_detailed_analysis
        ;;
    "stats")
        print_hybrid_stats
        ;;
    "system")
        print_system_info
        ;;
    "summary")
        print_summary
        ;;
    "all")
        print_hypothetical_results
        print_sqlite_results
        print_filebench_results
        print_migration_analysis
        print_hybrid_stats
        print_system_info
        print_summary
        ;;
    *)
        echo "Usage: $0 {hypothetical|sqlite|filebench|migration|detailed|stats|system|summary|all}"
        echo "  hypothetical  - Print hypothetical workload results"
        echo "  sqlite        - Print SQLite workload results"
        echo "  filebench     - Print Filebench workload results"
        echo "  migration     - Print migration analysis"
        echo "  detailed      - Print detailed analysis"
        echo "  stats         - Print hybrid SSD statistics"
        echo "  system        - Print system information"
        echo "  summary       - Print summary"
        echo "  all           - Print all results (default)"
        exit 1
        ;;
esac 