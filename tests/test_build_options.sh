#!/bin/bash
# Build Script Option Tests
# Tests that build.sh handles command line options correctly

# This file is sourced by run_tests.sh, so helpers are already loaded

# Test: --help option shows usage and exits successfully
test_help_option() {
    cd "$PROJECT_ROOT"

    output=$(./build.sh --help 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "--help option" "Expected exit code 0, got $exit_code"
        return
    fi

    if [[ ! "$output" =~ "Usage:" ]]; then
        fail "--help option" "Expected 'Usage:' in output"
        return
    fi

    if [[ ! "$output" =~ "--compile" ]]; then
        fail "--help option" "Expected '--compile' in help output"
        return
    fi

    pass "--help shows usage and exits 0"
}

# Test: -h option (short form) also works
test_short_help_option() {
    cd "$PROJECT_ROOT"

    output=$(./build.sh -h 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "-h option" "Expected exit code 0, got $exit_code"
        return
    fi

    if [[ ! "$output" =~ "Usage:" ]]; then
        fail "-h option" "Expected 'Usage:' in output"
        return
    fi

    pass "-h (short help) works"
}

# Test: Invalid option returns error
test_invalid_option() {
    cd "$PROJECT_ROOT"

    output=$(./build.sh --invalid-option 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        fail "Invalid option handling" "Expected non-zero exit code"
        return
    fi

    if [[ ! "$output" =~ "Unknown option" ]]; then
        fail "Invalid option handling" "Expected 'Unknown option' error message"
        return
    fi

    pass "Invalid option returns error"
}

# Test: --skip-submodules skips git submodule update
test_skip_submodules() {
    cd "$PROJECT_ROOT"

    # Run with --skip-submodules and check output
    output=$(./build.sh --skip-submodules 2>&1)

    # Should NOT contain "Initializing git submodules"
    if [[ "$output" =~ "Initializing git submodules" ]]; then
        fail "--skip-submodules" "Should not initialize submodules when skip flag is set"
        return
    fi

    pass "--skip-submodules skips git operations"
}

# Test: No options runs setup only (shows "Setup complete!")
test_no_options_setup() {
    cd "$PROJECT_ROOT"

    output=$(./build.sh --skip-submodules 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "No compile options" "Expected exit code 0, got $exit_code"
        return
    fi

    # Without --compile or --upload, should show setup message
    if [[ ! "$output" =~ "Setup complete" ]]; then
        fail "No compile options" "Expected 'Setup complete' message"
        return
    fi

    pass "No options shows setup complete message"
}

# Test: Configuration is loaded and displayed
test_config_display() {
    cd "$PROJECT_ROOT"

    output=$(./build.sh --skip-submodules 2>&1)

    # Check that config values are displayed (from test fixture)
    if [[ ! "$output" =~ "test-garage-door" ]]; then
        fail "Config display" "Device name not displayed"
        return
    fi

    if [[ ! "$output" =~ "TX Pin:" ]]; then
        fail "Config display" "TX Pin not displayed"
        return
    fi

    pass "Configuration values displayed"
}

# Test: gdolib-c6 component is set up
test_component_setup() {
    cd "$PROJECT_ROOT"

    # Run setup
    ./build.sh --skip-submodules > /dev/null 2>&1

    # Check that component files exist
    if [[ ! -f "esphome/components/gdolib-c6/libgdolib.a" ]]; then
        fail "Component setup" "libgdolib.a not copied to component directory"
        return
    fi

    if [[ ! -f "esphome/components/gdolib-c6/include/gdo.h" ]]; then
        fail "Component setup" "gdo.h not copied to component directory"
        return
    fi

    pass "gdolib-c6 component files set up"
}

# Run all build options tests
test_help_option
test_short_help_option
test_invalid_option
test_skip_submodules
test_no_options_setup
test_config_display
test_component_setup
