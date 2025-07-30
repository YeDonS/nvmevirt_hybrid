#!/bin/bash

# SQLite workload for hybrid SSD evaluation
# Based on FAST '24 Artifacts Evaluation methodology

source ../commonvariable.sh

log_info "Starting SQLite workload evaluation"

# Function to create SQLite database
create_sqlite_db() {
    local db_file="/mnt/hybrid_test/test.db"
    
    log_info "Creating SQLite database: $db_file"
    
    # Create database and tables
    sqlite3 $db_file << EOF
CREATE TABLE IF NOT EXISTS test_table (
    id INTEGER PRIMARY KEY,
    data TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON test_table(timestamp);
CREATE INDEX IF NOT EXISTS idx_data ON test_table(data);
EOF
    
    log_info "SQLite database created successfully"
}

# Function to populate database
populate_database() {
    local db_file="/mnt/hybrid_test/test.db"
    local num_records=$1
    
    log_info "Populating database with $num_records records"
    
    # Generate random data
    for i in $(seq 1 $num_records); do
        local random_data=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 100 | head -n 1)
        sqlite3 $db_file "INSERT INTO test_table (id, data) VALUES ($i, '$random_data');"
    done
    
    log_info "Database populated successfully"
}

# Function to run SQLite read test
run_sqlite_read() {
    local scenario=$1
    local result_file="$RESULTS_DIR/sqlite_read_${scenario}.json"
    
    log_performance "Running SQLite read test for scenario: $scenario"
    
    local db_file="/mnt/hybrid_test/test.db"
    local start_time=$(date +%s.%N)
    
    # Run read queries
    sqlite3 $db_file << EOF
SELECT COUNT(*) FROM test_table;
SELECT * FROM test_table WHERE id % 100 = 0;
SELECT * FROM test_table WHERE data LIKE '%test%';
SELECT timestamp, COUNT(*) FROM test_table GROUP BY DATE(timestamp);
EOF
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Calculate throughput (queries per second)
    local throughput=$(echo "scale=2; 4 / $duration" | bc)
    
    log_performance "SQLite read results - Duration: ${duration}s, Throughput: ${throughput} queries/s"
    
    echo "$scenario,sqlite_read,$throughput,0,$duration" >> $METRICS_FILE
}

# Function to run SQLite write test
run_sqlite_write() {
    local scenario=$1
    local result_file="$RESULTS_DIR/sqlite_write_${scenario}.json"
    
    log_performance "Running SQLite write test for scenario: $scenario"
    
    local db_file="/mnt/hybrid_test/test.db"
    local start_time=$(date +%s.%N)
    
    # Run write operations
    sqlite3 $db_file << EOF
BEGIN TRANSACTION;
INSERT INTO test_table (data) VALUES ('write_test_1');
INSERT INTO test_table (data) VALUES ('write_test_2');
INSERT INTO test_table (data) VALUES ('write_test_3');
INSERT INTO test_table (data) VALUES ('write_test_4');
INSERT INTO test_table (data) VALUES ('write_test_5');
COMMIT;

BEGIN TRANSACTION;
UPDATE test_table SET data = 'updated_data' WHERE id % 100 = 0;
COMMIT;

BEGIN TRANSACTION;
DELETE FROM test_table WHERE id % 1000 = 0;
COMMIT;
EOF
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Calculate throughput (operations per second)
    local throughput=$(echo "scale=2; 7 / $duration" | bc)
    
    log_performance "SQLite write results - Duration: ${duration}s, Throughput: ${throughput} ops/s"
    
    echo "$scenario,sqlite_write,$throughput,0,$duration" >> $METRICS_FILE
}

# Function to run SQLite mixed test
run_sqlite_mixed() {
    local scenario=$1
    local result_file="$RESULTS_DIR/sqlite_mixed_${scenario}.json"
    
    log_performance "Running SQLite mixed test for scenario: $scenario"
    
    local db_file="/mnt/hybrid_test/test.db"
    local start_time=$(date +%s.%N)
    
    # Run mixed read/write operations
    sqlite3 $db_file << EOF
-- Read operations
SELECT COUNT(*) FROM test_table;
SELECT * FROM test_table WHERE id % 100 = 0;

-- Write operations
BEGIN TRANSACTION;
INSERT INTO test_table (data) VALUES ('mixed_test_1');
INSERT INTO test_table (data) VALUES ('mixed_test_2');
COMMIT;

-- More read operations
SELECT * FROM test_table WHERE data LIKE '%test%';
SELECT timestamp, COUNT(*) FROM test_table GROUP BY DATE(timestamp);

-- More write operations
BEGIN TRANSACTION;
UPDATE test_table SET data = 'mixed_updated' WHERE id % 200 = 0;
COMMIT;

-- Final read
SELECT COUNT(*) FROM test_table;
EOF
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Calculate throughput (operations per second)
    local throughput=$(echo "scale=2; 10 / $duration" | bc)
    
    log_performance "SQLite mixed results - Duration: ${duration}s, Throughput: ${throughput} ops/s"
    
    echo "$scenario,sqlite_mixed,$throughput,0,$duration" >> $METRICS_FILE
}

# Function to create fragmentation for SQLite
create_sqlite_fragmentation() {
    local level=$1
    
    log_info "Creating SQLite fragmentation level: $level"
    
    local db_file="/mnt/hybrid_test/test.db"
    
    case $level in
        "low")
            # Create some fragmentation
            sqlite3 $db_file "DELETE FROM test_table WHERE id % 10 = 0;"
            sqlite3 $db_file "VACUUM;"
            ;;
        "medium")
            # Create moderate fragmentation
            sqlite3 $db_file "DELETE FROM test_table WHERE id % 5 = 0;"
            sqlite3 $db_file "VACUUM;"
            ;;
        "high")
            # Create high fragmentation
            sqlite3 $db_file "DELETE FROM test_table WHERE id % 2 = 0;"
            sqlite3 $db_file "VACUUM;"
            ;;
    esac
    
    log_info "SQLite fragmentation created: $level"
}

# Function to run all SQLite tests for a scenario
run_sqlite_scenario() {
    local scenario=$1
    
    log_info "Running SQLite tests for scenario: $scenario"
    
    # Setup device
    ./setdevice.sh setup
    
    # Create database
    create_sqlite_db
    
    # Populate database
    populate_database 10000
    
    # Create fragmentation if needed
    if [[ $scenario == *"fragmented"* ]]; then
        create_sqlite_fragmentation $FRAGMENTATION_LEVEL
    fi
    
    # Run all SQLite tests
    run_sqlite_read $scenario
    run_sqlite_write $scenario
    run_sqlite_mixed $scenario
    
    # Cleanup
    ./setdevice.sh cleanup
    
    log_info "Completed SQLite tests for scenario: $scenario"
}

# Function to run SQLite migration test
run_sqlite_migration_test() {
    local result_file="$RESULTS_DIR/sqlite_migration_test.json"
    
    log_info "Running SQLite migration performance test"
    
    # Setup device
    ./setdevice.sh setup
    
    # Create database
    create_sqlite_db
    
    # Populate database
    populate_database 50000
    
    # Run SQLite workload that triggers migration
    local start_time=$(date +%s.%N)
    
    # Run intensive SQLite operations
    sqlite3 /mnt/hybrid_test/test.db << EOF
-- Intensive read operations
SELECT COUNT(*) FROM test_table;
SELECT * FROM test_table WHERE id % 10 = 0;
SELECT * FROM test_table WHERE data LIKE '%test%';

-- Intensive write operations
BEGIN TRANSACTION;
INSERT INTO test_table (data) SELECT 'migration_test_' || id FROM test_table WHERE id % 100 = 0;
COMMIT;

-- More operations to trigger migration
SELECT COUNT(*) FROM test_table;
UPDATE test_table SET data = 'migration_updated' WHERE id % 50 = 0;
SELECT * FROM test_table WHERE id % 20 = 0;
EOF
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Calculate throughput
    local throughput=$(echo "scale=2; 8 / $duration" | bc)
    
    log_performance "SQLite migration test results - Duration: ${duration}s, Throughput: ${throughput} ops/s"
    
    echo "sqlite_migration,sqlite_mixed,$throughput,0,$duration" >> $METRICS_FILE
    
    # Cleanup
    ./setdevice.sh cleanup
}

# Main execution
case "$1" in
    "contiguous")
        run_sqlite_scenario "contiguous"
        ;;
    "fragmented")
        run_sqlite_scenario "fragmented"
        ;;
    "migration")
        run_sqlite_migration_test
        ;;
    "all")
        log_info "Running all SQLite workload tests"
        
        # Initialize metrics file if not exists
        if [ ! -f $METRICS_FILE ]; then
            echo "scenario,workload_type,throughput,iops,latency" > $METRICS_FILE
        fi
        
        # Run all scenarios
        run_sqlite_scenario "contiguous"
        run_sqlite_scenario "fragmented"
        run_sqlite_migration_test
        
        log_info "All SQLite workload tests completed"
        ;;
    *)
        echo "Usage: $0 {contiguous|fragmented|migration|all}"
        echo "  contiguous  - Baseline SQLite workload"
        echo "  fragmented  - Fragmented SQLite workload"
        echo "  migration   - SQLite migration performance test"
        echo "  all         - Run all SQLite tests"
        exit 1
        ;;
esac 