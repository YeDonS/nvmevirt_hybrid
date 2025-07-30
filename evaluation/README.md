# Hybrid SSD Evaluation Framework

## Title: Hybrid SSD with Unidirectional Migration: Performance Evaluation and Analysis

Contact: [Your Contact Information]

This repository provides a comprehensive evaluation framework for hybrid SSD (SLC/QLC) with unidirectional migration, based on the methodology from [FAST '24 Artifacts Evaluation](https://github.com/yuhun-Jun/fast24_ae). The evaluation workload set consists of 'hypothetical,' 'sqlite,' and 'filebench' workloads, adapted for hybrid SSD characteristics.

## Contents

* 1. Configurations
* 2. Getting Started
* 3. Kernel Build
* 4. Hybrid SSD Build
* 5. Analysis of Hybrid SSD Performance
* 6. Conducting Evaluation
* 7. Adaptation for Systems with Limited Resources

## 1. Configurations

The experimental environment was designed for the following hardware configurations:

| **Component** | **Specification**                      |
| ------------- | -------------------------------------- |
| Processor     | Intel Xeon Gold 6138 2.0 GHz, 160-Core |
| Chipset       | Intel C621                             |
| Memory        | DDR4 2666 MHz, 512 GB (32 GB x16)      |
| OS            | Ubuntu 20.04 Server (kernel v5.15.0)   |

However, it is expected that the evaluation can be reproduced on a different hardware setup as long as it has a sufficiently large amount of DRAM space.

**Note:** The hybrid SSD simulator functions in DRAM and is performance-sensitive. For optimal performance, a setup with at least 128 GB of free space in a single NUMA node is recommended.

## 2. Getting Started

We assume that "/" is the working directory.

```bash
cd /
git clone https://github.com/yuhun-Jun/nvmevirt_DA.git
cd nvmevirt_DA
```

For the experiment, it's necessary to build a modified version of the kernel and the hybrid SSD simulator, as well as install sqlite and filebench. The evaluation framework will be downloaded into the evaluation directory.

## 3. Kernel Build

Before building the kernel, ensure the following packages are installed:

```bash
apt-get update
apt-get install build-essential libncurses5 libncurses5-dev bin86 kernel-package libssl-dev bison flex libelf-dev dwarves
```

Configure the kernel:

```bash
cd kernel
make olddefconfig
```

For building, modify the `.config` file by setting `CONFIG_SYSTEM_TRUSTED_KEYS` and `CONFIG_SYSTEM_REVOCATION_KEYS` to empty strings (""). These settings are typically located around line 10477.

```
CONFIG_SYSTEM_TRUSTED_KEYS=""
CONFIG_SYSTEM_REVOCATION_KEYS=""
```

Build the kernel:

```bash
make -j$(nproc) LOCALVERSION=
sudo make INSTALL_MOD_STRIP=1 modules_install  
make install
```

Reboot and boot into the newly built kernel.

## 4. Hybrid SSD Build

Verify the kernel version:

```bash
uname -r
```

Once the correct kernel version is confirmed, proceed as follows:

Move to the project directory:

```bash
cd /nvmevirt_DA
```

Navigate to the evaluation directory and execute the build command:

```bash
cd evaluation
chmod +x scripts/*.sh
chmod +x *.sh
```

## 5. Analysis of Hybrid SSD Performance

The evaluation framework analyzes hybrid SSD performance in the following areas:

### 5.1 Unidirectional Migration Performance
- **SLC to QLC Migration**: Cold data migration from high-performance SLC to high-capacity QLC
- **Migration Efficiency**: Performance impact of migration operations
- **Migration Timing**: Optimal migration intervals and thresholds

### 5.2 Write Strategy Performance
- **SLC DA Strategy**: Die-affinity strategy for SLC writes
- **QLC Traditional Strategy**: Round-robin strategy for QLC writes
- **Strategy Effectiveness**: Performance comparison between strategies

### 5.3 Fragmentation Impact
- **SLC Fragmentation**: Performance degradation in SLC region
- **QLC Fragmentation**: Performance degradation in QLC region
- **Migration with Fragmentation**: Migration performance under fragmented conditions

## 6. Conducting Evaluation

### 6.1 Prerequisites Installation

Install required packages:

```bash
# Install fio for performance testing
apt-get install fio

# Install sqlite3 for database workloads
apt-get install sqlite3 libsqlite3-dev

# Install filebench for file system workloads
git clone https://github.com/filebench/filebench.git
cd filebench
./configure
make
make install

# Install additional tools
apt-get install jq bc numactl
```

### 6.2 Running Hypothetical Workloads

Execute the script below to perform hypothetical workloads, including append and overwrite tasks:

```bash
./scripts/hypothetical_workloads.sh all
```

Results will be saved in the `results` directory, starting with "sequential_write", "random_write", etc.

### 6.3 Running SQLite Workloads

The execution of the SQLite workload is performed by running the following script:

```bash
./scripts/sqlite_workload.sh all
```

Results will be in the `results` directory, starting with "sqlite".

### 6.4 Running Filebench Workloads

Execute the script below once Filebench is installed:

```bash
./scripts/filebench_workload.sh all
```

Results will be in the `results` directory, starting with "filebench".

### 6.5 Running All Tests

Of course, all the above tests can be integrated into a single script below and executed at once:

```bash
./runall.sh all
```

### 6.6 Results Analysis

Once the evaluation is complete, you can check the results all at once with the following command:

```bash
./printresult.sh all
```

## 7. Adaptation for Systems with Limited Resources

In our standard experiments, we use 128 GB of memory to accurately emulate a 60 GB hybrid SSD. For systems with limited memory capacity, such as using 16 GB to emulate a 10 GB hybrid SSD in a single NUMA node system equipped with 32 GB of memory, specific adjustments are required.

### 7.1 Memory Configuration

Reserve memory for the emulated hybrid SSD device's storage by modifying `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX="memmap=16G\\\$16G intremap=off"
```

### 7.2 Device Configuration

Modify the device configuration in `commonvariable.sh`:

```bash
export SYSTEM_MEMORY="16G"
export EMULATED_SSD_SIZE="10G"
export MEMORY_START="16G"
export PARTITION_SIZE="8G"
```

### 7.3 NUMA Configuration

For limited resource systems, set `NUMADOMAIN` to `0` in `commonvariable.sh`:

```bash
export NUMA_DOMAIN="0"
```

## 8. Evaluation Framework Structure

```
evaluation/
├── commonvariable.sh          # Common variables and functions
├── runall.sh                  # Main evaluation script
├── printresult.sh             # Results analysis script
├── scripts/
│   ├── setdevice.sh           # Device setup and management
│   ├── hypothetical_workloads.sh  # Hypothetical workload tests
│   ├── sqlite_workload.sh     # SQLite workload tests
│   └── filebench_workload.sh  # Filebench workload tests
├── configs/                   # Configuration files
├── workloads/                 # Workload definitions
└── results/                   # Test results and reports
```

## 9. Key Features

### 9.1 Hybrid SSD Characteristics
- **SLC Region**: 20% of total capacity, high performance
- **QLC Region**: 80% of total capacity, high capacity
- **Unidirectional Migration**: SLC to QLC only
- **Differentiated Write Strategies**: DA for SLC, traditional for QLC

### 9.2 Test Scenarios
- **Contiguous**: Baseline performance measurement
- **Fragmented SLC**: Performance under SLC fragmentation
- **Fragmented QLC**: Performance under QLC fragmentation
- **Migration Test**: Migration performance evaluation
- **Mixed Workload**: Combined SLC/QLC workload

### 9.3 Workload Types
- **Sequential Write/Read**: Large block sequential operations
- **Random Write/Read**: Small block random operations
- **Mixed I/O**: Combined read/write operations
- **Database Workloads**: SQLite-based database operations
- **File System Workloads**: Filebench-based file system operations

## 10. Performance Metrics

The evaluation framework measures the following performance metrics:

- **Throughput**: Operations per second (KB/s)
- **IOPS**: Input/Output operations per second
- **Latency**: Response time in nanoseconds
- **Migration Efficiency**: Migration operations per second
- **Fragmentation Impact**: Performance degradation due to fragmentation

## 11. Expected Results

Based on the hybrid SSD design, expected results include:

- **SLC Performance**: High throughput and low latency for hot data
- **QLC Performance**: Moderate throughput and higher latency for cold data
- **Migration Performance**: Efficient cold data migration from SLC to QLC
- **Fragmentation Resilience**: Better performance under fragmented conditions
- **Strategy Effectiveness**: Optimal performance with differentiated write strategies

## 12. Troubleshooting

### 12.1 Common Issues
- **Memory Allocation**: Ensure sufficient memory is reserved
- **NUMA Configuration**: Verify NUMA node configuration
- **Device Detection**: Check device naming and permissions
- **Dependencies**: Verify all required packages are installed

### 12.2 Debug Information
- Check log files in `results/` directory
- Verify device status with `./scripts/setdevice.sh status`
- Monitor system resources during testing
- Review error messages in console output

## 13. Contributing

To contribute to this evaluation framework:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 14. License

This evaluation framework is based on the [FAST '24 Artifacts Evaluation](https://github.com/yuhun-Jun/fast24_ae) methodology and is provided under the same license terms.

## 15. Contact

For questions or issues related to this evaluation framework, please contact:

[Your Contact Information]

---

**Note**: This evaluation framework is designed to work with the hybrid SSD implementation in the nvmevirt_DA project. Ensure that the hybrid SSD module is properly built and loaded before running the evaluation tests. 