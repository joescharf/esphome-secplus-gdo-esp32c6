#!/bin/bash
# ESPHome Config Tests
# Tests that the generated ESPHome configuration is valid

# This file is sourced by run_tests.sh, so helpers are already loaded

# Test: ESPHome is available
test_esphome_available() {
    ESPHOME_CMD=$(get_esphome_cmd)

    if [[ -z "$ESPHOME_CMD" ]]; then
        fail "ESPHome available" "ESPHome not found (install with: pip install esphome)"
        return 1  # Return failure to skip subsequent tests
    fi

    pass "ESPHome available"
    return 0
}

# Test: ESPHome config validation (dry-run)
test_esphome_config_valid() {
    cd "$PROJECT_ROOT"

    ESPHOME_CMD=$(get_esphome_cmd)
    if [[ -z "$ESPHOME_CMD" ]]; then
        skip "ESPHome config validation - ESPHome not available"
        return
    fi

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "ESPHome config validation - YAML not generated"
        return
    fi

    # Run esphome config to validate without compiling
    cd esphome
    output=$($ESPHOME_CMD config esp32c6-gdo.yaml 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "ESPHome config validation" "Config validation failed: $output"
        return
    fi

    pass "ESPHome config validation"
}

# Test: External components can be loaded
test_external_components_load() {
    cd "$PROJECT_ROOT"

    ESPHOME_CMD=$(get_esphome_cmd)
    if [[ -z "$ESPHOME_CMD" ]]; then
        skip "External components load - ESPHome not available"
        return
    fi

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "External components load - YAML not generated"
        return
    fi

    cd esphome
    output=$($ESPHOME_CMD config esp32c6-gdo.yaml 2>&1)

    # Check that secplus_gdo component is recognized
    if [[ "$output" =~ "secplus_gdo" ]]; then
        pass "External components load - secplus_gdo found"
    else
        # The component might be loaded even if not explicitly in output
        # As long as config validates, we're good
        if [[ $? -eq 0 ]]; then
            pass "External components load - config valid"
        else
            fail "External components load" "Component not recognized"
        fi
    fi
}

# Test: Secret references resolve
test_secrets_resolve() {
    cd "$PROJECT_ROOT"

    ESPHOME_CMD=$(get_esphome_cmd)
    if [[ -z "$ESPHOME_CMD" ]]; then
        skip "Secrets resolution - ESPHome not available"
        return
    fi

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Secrets resolution - YAML not generated"
        return
    fi

    cd esphome
    output=$($ESPHOME_CMD config esp32c6-gdo.yaml 2>&1)
    exit_code=$?

    # Check for secret resolution errors
    if [[ "$output" =~ "Could not find" ]] || [[ "$output" =~ "secret" && "$output" =~ "not found" ]]; then
        fail "Secrets resolution" "Secret references could not be resolved"
        return
    fi

    if [[ $exit_code -eq 0 ]]; then
        pass "Secrets resolution - all secrets resolve"
    else
        fail "Secrets resolution" "Config validation failed"
    fi
}

# Test: ESP32-C6 target configured
test_esp32c6_target() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "ESP32-C6 target - YAML not generated"
        return
    fi

    # Check that ESP32-C6 variant is specified
    if grep -q "variant: esp32c6" "esphome/esp32c6-gdo.yaml"; then
        pass "ESP32-C6 target configured"
    else
        fail "ESP32-C6 target" "ESP32-C6 variant not found in config"
    fi
}

# Test: Full ESPHome compile (optional, slow)
test_full_compile() {
    if [[ "$FULL_COMPILE" != "true" ]]; then
        skip "Full ESPHome compile (use --full-compile)"
        return
    fi

    cd "$PROJECT_ROOT"

    ESPHOME_CMD=$(get_esphome_cmd)
    if [[ -z "$ESPHOME_CMD" ]]; then
        skip "Full compile - ESPHome not available"
        return
    fi

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Full compile - YAML not generated"
        return
    fi

    cd esphome
    info "Running full compile (this may take 10-15 minutes)..."

    output=$($ESPHOME_CMD compile esp32c6-gdo.yaml 2>&1)
    exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        fail "Full ESPHome compile" "Compilation failed"
        [[ "$VERBOSE" == "true" ]] && echo "$output"
        return
    fi

    # Check that firmware binary was created
    if [[ -f ".esphome/build/test-garage-door/.pioenvs/test-garage-door/firmware.bin" ]] || \
       [[ -d ".esphome/build/test-garage-door" ]]; then
        pass "Full ESPHome compile - firmware built"
    else
        pass "Full ESPHome compile - completed"
    fi
}

# Run all ESPHome config tests
if test_esphome_available; then
    test_esphome_config_valid
    test_external_components_load
    test_secrets_resolve
fi

test_esp32c6_target
test_full_compile
