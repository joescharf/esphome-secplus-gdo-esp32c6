#!/bin/bash
# Main test runner for esphome-secplus-gdo-esp32c6
#
# Usage: ./tests/run_tests.sh [--full-compile] [--verbose] [--help]
#
# Options:
#   --full-compile  Run full ESPHome compile (slow, ~15 min)
#   --verbose       Show detailed output from each test
#   --help          Show this help message

# Don't use set -e since we want to continue on test failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test helpers
source "$SCRIPT_DIR/lib/test_helpers.sh"

# Parse command line arguments
FULL_COMPILE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full-compile)
            FULL_COMPILE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--full-compile] [--verbose] [--help]"
            echo ""
            echo "Options:"
            echo "  --full-compile  Run full ESPHome compile (slow, ~15 min)"
            echo "  --verbose       Show detailed output from each test"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

export FULL_COMPILE VERBOSE PROJECT_ROOT

echo ""
echo "================================"
echo "ESP32-C6 GDO Build Verification"
echo "================================"
echo ""

# Setup test environment
info "Setting up test environment..."
setup_test_env

# Trap to ensure cleanup on exit
trap teardown_test_env EXIT

echo ""

# Run YAML Generation Tests
echo "Running YAML Generation Tests..."
echo "--------------------------------"
source "$SCRIPT_DIR/test_yaml_generation.sh"
echo ""

# Run Build Script Option Tests
echo "Running Build Script Option Tests..."
echo "------------------------------------"
source "$SCRIPT_DIR/test_build_options.sh"
echo ""

# Run ESPHome Config Tests
echo "Running ESPHome Config Tests..."
echo "-------------------------------"
source "$SCRIPT_DIR/test_esphome_config.sh"
echo ""

# Print summary
print_summary

# Exit with appropriate code
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
exit 0
