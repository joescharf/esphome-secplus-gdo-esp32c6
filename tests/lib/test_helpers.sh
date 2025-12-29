#!/bin/bash
# Test helper functions for esphome-secplus-gdo-esp32c6

# Colors (can be disabled)
setup_colors() {
    if [[ "${NO_COLOR:-}" != "true" ]] && [[ -t 1 ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        NC='\033[0m' # No Color
    else
        RED='' GREEN='' YELLOW='' BLUE='' NC=''
    fi
}

# Test result tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
FAILED_TESTS=()

pass() {
    ((TESTS_RUN++))
    ((TESTS_PASSED++))
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    ((TESTS_RUN++))
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
    echo -e "${RED}[FAIL]${NC} $1"
    [[ -n "${2:-}" ]] && echo -e "       ${RED}$2${NC}"
}

skip() {
    ((TESTS_SKIPPED++))
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Setup test environment
setup_test_env() {
    export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    export TEST_DIR="$PROJECT_ROOT/tests"
    export TEST_FIXTURES="$TEST_DIR/fixtures"

    # Set environment variables to use test fixtures (build.sh respects these)
    # This avoids modifying user's actual config.env and secrets.yaml
    export CONFIG_FILE="$TEST_FIXTURES/test_config.env"

    # For ESPHome validation, we need secrets.yaml in the esphome directory
    # We'll use a test-specific secrets file that we manage
    export TEST_SECRETS_FILE="$PROJECT_ROOT/esphome/secrets.yaml"
    export SECRETS_FILE="$TEST_SECRETS_FILE"

    # Backup existing secrets.yaml if present, then copy test secrets
    if [[ -f "$TEST_SECRETS_FILE" ]]; then
        cp "$TEST_SECRETS_FILE" "$TEST_SECRETS_FILE.backup"
        BACKED_UP_SECRETS=true
    fi
    cp "$TEST_FIXTURES/test_secrets.yaml" "$TEST_SECRETS_FILE"

    # Track generated YAML for cleanup
    export TEST_GENERATED_YAML="$PROJECT_ROOT/esphome/esp32c6-gdo.yaml"

    info "Test environment set up (using test fixtures)"
}

# Teardown test environment
teardown_test_env() {
    # Restore original secrets.yaml if we backed it up
    if [[ "${BACKED_UP_SECRETS:-}" == "true" ]] && [[ -f "$TEST_SECRETS_FILE.backup" ]]; then
        mv "$TEST_SECRETS_FILE.backup" "$TEST_SECRETS_FILE"
    else
        rm -f "$TEST_SECRETS_FILE"
    fi

    # Clean up generated YAML
    rm -f "$TEST_GENERATED_YAML"

    info "Test environment cleaned up"
}

# Print test summary
print_summary() {
    echo ""
    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Total:   $TESTS_RUN"
    echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"

    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  - $test"
        done
    fi

    echo ""
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Get ESPHome command (supports uv or direct)
get_esphome_cmd() {
    if command_exists uv; then
        echo "uv tool run esphome"
    elif command_exists esphome; then
        echo "esphome"
    else
        echo ""
    fi
}

# Initialize colors by default
setup_colors
