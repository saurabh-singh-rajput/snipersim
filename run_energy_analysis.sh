#!/bin/bash

# Energy Analysis Script for Sniper Simulator
# This script runs Sniper on a given workload and then analyzes energy consumption using McPAT

set -e  # Exit on any error

# Default values
CONFIG_FILE="config/epyc_9554p.cfg"
OUTPUT_DIR="output_dir"
WORKLOAD=""
WORKLOAD_ARGS=""
JOB_ID=0
NO_GRAPH=false
POWER_TYPE="total"
VERBOSE=false
WORKLOAD_FILE="./test_simple"

# Function to print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [-- <WORKLOAD> [WORKLOAD_ARGS...]]

Run Sniper simulation and energy analysis on a given workload.

OPTIONS:
    -c, --config FILE        Sniper configuration file (default: $CONFIG_FILE)
    -d, --output-dir DIR    Output directory (default: $OUTPUT_DIR)
    -j, --job-id ID         Job ID for McPAT analysis (default: $JOB_ID)
    -t, --power-type TYPE   Power type: total, dynamic, static, peak, area (default: $POWER_TYPE)
    --no-graph              Disable graph generation in McPAT
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Uses default workload: $WORKLOAD_FILE
    $0 -- ./test_simple     # Specify custom workload
    $0 -c config/nehalem.cfg -- ./benchmark -n 1000
    $0 -d my_output --no-graph -- ./workload arg1 arg2

POWER TYPES:
    total     - Total power (dynamic + static)
    dynamic   - Dynamic power only
    static    - Static power only
    peak      - Peak power
    area      - Area analysis

EOF
    exit 1
}

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    case $color in
        "green") echo -e "\033[32m[INFO]\033[0m $message" ;;
        "yellow") echo -e "\033[33m[WARN]\033[0m $message" ;;
        "red") echo -e "\033[31m[ERROR]\033[0m $message" ;;
        "blue") echo -e "\033[34m[STEP]\033[0m $message" ;;
        *) echo "[INFO] $message" ;;
    esac
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_status "blue" "Checking prerequisites..."
    
    # Check if we're in the Sniper directory
    if [[ ! -f "run-sniper" ]]; then
        print_status "red" "Error: This script must be run from the Sniper root directory"
        exit 1
    fi
    
    # Check if run-sniper is executable
    if [[ ! -x "run-sniper" ]]; then
        print_status "red" "Error: run-sniper is not executable"
        exit 1
    fi
    
    # Check if mcpat.py exists
    if [[ ! -f "tools/mcpat.py" ]]; then
        print_status "red" "Error: tools/mcpat.py not found"
        exit 1
    fi
    
    # Check if Python3 is available
    if ! command_exists python3; then
        print_status "red" "Error: python3 is not installed"
        exit 1
    fi
    
    print_status "green" "Prerequisites check passed"
}

# Function to clean up output directory
cleanup_output() {
    if [[ -d "$OUTPUT_DIR" ]]; then
        print_status "yellow" "Cleaning up existing output directory: $OUTPUT_DIR"
        rm -rf "$OUTPUT_DIR"
    fi
}

# Function to run Sniper simulation
run_sniper() {
    print_status "blue" "Starting Sniper simulation..."
    print_status "blue" "Config: $CONFIG_FILE"
    print_status "blue" "Output: $OUTPUT_DIR"
    print_status "blue" "Workload: $WORKLOAD $WORKLOAD_ARGS"
    
    local start_time=$(date +%s)
    
    # Run Sniper
    if [[ $VERBOSE == true ]]; then
        ./run-sniper -c "$CONFIG_FILE" -d "$OUTPUT_DIR" -- "$WORKLOAD" $WORKLOAD_ARGS
    else
        ./run-sniper -c "$CONFIG_FILE" -d "$OUTPUT_DIR" -- "$WORKLOAD" $WORKLOAD_ARGS > /dev/null 2>&1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $? -eq 0 ]]; then
        print_status "green" "Sniper simulation completed successfully in ${duration}s"
        
        # Create the directory structure that McPAT expects
        print_status "blue" "Setting up directory structure for McPAT..."
        mkdir -p "$OUTPUT_DIR/config"
        cp "$CONFIG_FILE" "$OUTPUT_DIR/config/"
        
        # Create a sim.info file that McPAT can parse
        if [[ ! -f "$OUTPUT_DIR/sim.info" ]]; then
            print_status "blue" "Creating sim.info file..."
            echo "config_file = $CONFIG_FILE" > "$OUTPUT_DIR/sim.info"
        fi
    else
        print_status "red" "Sniper simulation failed"
        exit 1
    fi
}

# Function to run McPAT energy analysis
run_mcpat() {
    print_status "blue" "Starting McPAT energy analysis..."
    
    # Since the standard McPAT approach has issues, use the working method directly
    print_status "blue" "Using direct McPAT approach for compatibility..."
    
    local mcpat_args="-d ../$OUTPUT_DIR -o ../$OUTPUT_DIR/energy_report -t $POWER_TYPE"
    
    if [[ $NO_GRAPH == true ]]; then
        mcpat_args="$mcpat_args --no-graph"
    fi
    
    if [[ $JOB_ID -ne 0 ]]; then
        mcpat_args="$mcpat_args -j $JOB_ID"
    fi
    
    print_status "blue" "McPAT args: $mcpat_args"
    
    # Use the working approach: run from tools directory with relative paths
    cd tools
    python3 mcpat.py $mcpat_args
    local mcpat_exit_code=$?
    cd ..
    
    if [[ $mcpat_exit_code -eq 0 ]]; then
        print_status "green" "McPAT energy analysis completed successfully"
        print_status "green" "Energy report saved to: $OUTPUT_DIR/energy_report.py"
        if [[ $NO_GRAPH == false ]]; then
            print_status "green" "Energy graph saved to: $OUTPUT_DIR/energy_report.png"
        fi
    else
        print_status "red" "McPAT energy analysis failed with exit code $mcpat_exit_code"
        exit 1
    fi
}

# Function to display summary
display_summary() {
    print_status "blue" "=== Energy Analysis Summary ==="
    print_status "blue" "Configuration: $CONFIG_FILE"
    print_status "blue" "Output Directory: $OUTPUT_DIR"
    print_status "blue" "Workload: $WORKLOAD $WORKLOAD_ARGS"
    print_status "blue" "Power Type: $POWER_TYPE"
    print_status "blue" "Job ID: $JOB_ID"
    
    if [[ -f "$OUTPUT_DIR/energy_report.py" ]]; then
        print_status "green" "Energy report: $OUTPUT_DIR/energy_report.py"
    fi
    
    if [[ -f "$OUTPUT_DIR/energy_report.png" ]]; then
        print_status "green" "Energy graph: $OUTPUT_DIR/energy_report.png"
    fi
    
    print_status "green" "Analysis completed successfully!"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -j|--job-id)
            JOB_ID="$2"
            shift 2
            ;;
        -t|--power-type)
            POWER_TYPE="$2"
            shift 2
            ;;
        --no-graph)
            NO_GRAPH=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            WORKLOAD="$1"
            shift
            WORKLOAD_ARGS="$@"
            break
            ;;
        *)
            print_status "red" "Unknown option: $1"
            usage
            ;;
    esac
done

# Use default workload if none provided
if [[ -z "$WORKLOAD" ]]; then
    print_status "yellow" "No workload specified, using default: $WORKLOAD_FILE"
    WORKLOAD="$WORKLOAD_FILE"
fi

# Validate power type
case $POWER_TYPE in
    total|dynamic|static|peak|area)
        ;;
    *)
        print_status "red" "Error: Invalid power type: $POWER_TYPE"
        usage
        ;;
esac

# Validate config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    print_status "red" "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Main execution
main() {
    print_status "blue" "=== Sniper Energy Analysis Script ==="
    print_status "blue" "Starting at: $(date)"
    
    # Check prerequisites
    check_prerequisites
    
    # Clean up existing output
    cleanup_output
    
    # Run Sniper simulation
    run_sniper
    
    # Run McPAT energy analysis
    run_mcpat
    
    # Display summary
    display_summary
    
    print_status "blue" "Completed at: $(date)"
}

# Run main function
main "$@"
