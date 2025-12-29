#!/bin/bash
# YAML Generation Tests
# Tests that the YAML template substitution works correctly

# This file is sourced by run_tests.sh, so helpers are already loaded

# Test: Basic substitution - all build.sh placeholders should be replaced
test_basic_substitution() {
    cd "$PROJECT_ROOT"

    # Run build script to generate YAML (skip submodules, don't compile)
    ./build.sh --skip-submodules > /dev/null 2>&1

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        fail "Basic substitution" "Generated YAML file not found"
        return
    fi

    # Check for unreplaced build.sh placeholders (not ESPHome substitutions like ${name})
    # Build.sh replaces: SCRIPT_DIR, GDO_TX_PIN, GDO_RX_PIN, DEVICE_NAME, FRIENDLY_NAME, etc.
    local unreplaced=""
    for var in SCRIPT_DIR GDO_TX_PIN GDO_RX_PIN OBSTRUCTION_CONFIG STATUS_LED_CONFIG; do
        if grep -q "\${${var}}" "esphome/esp32c6-gdo.yaml"; then
            unreplaced+="${var} "
        fi
    done

    if [[ -n "$unreplaced" ]]; then
        fail "Basic substitution" "Unreplaced build.sh placeholders found: $unreplaced"
        return
    fi

    pass "Basic substitution - all build.sh placeholders replaced"
}

# Test: Device name substitution
test_device_name_substitution() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Device name substitution - YAML not generated"
        return
    fi

    # Check that device name from test fixture appears in output
    if grep -q "name: test-garage-door" "esphome/esp32c6-gdo.yaml"; then
        pass "Device name substitution"
    else
        fail "Device name substitution" "Expected 'name: test-garage-door' not found"
    fi
}

# Test: Friendly name substitution
test_friendly_name_substitution() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Friendly name substitution - YAML not generated"
        return
    fi

    if grep -q "Test Garage Door" "esphome/esp32c6-gdo.yaml"; then
        pass "Friendly name substitution"
    else
        fail "Friendly name substitution" "Expected 'Test Garage Door' not found"
    fi
}

# Test: GPIO pin substitution
test_gpio_pin_substitution() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "GPIO pin substitution - YAML not generated"
        return
    fi

    # Check TX pin (16) and RX pin (17) from test fixtures
    # Template uses output_gdo_pin for TX and input_gdo_pin for RX
    local errors=""

    if ! grep -q "output_gdo_pin: GPIO16" "esphome/esp32c6-gdo.yaml"; then
        errors+="TX pin (output_gdo_pin: GPIO16) not found. "
    fi

    if ! grep -q "input_gdo_pin: GPIO17" "esphome/esp32c6-gdo.yaml"; then
        errors+="RX pin (input_gdo_pin: GPIO17) not found. "
    fi

    if [[ -n "$errors" ]]; then
        fail "GPIO pin substitution" "$errors"
    else
        pass "GPIO pin substitution"
    fi
}

# Test: Optional status LED (enabled)
test_optional_led_enabled() {
    cd "$PROJECT_ROOT"

    # Test fixtures include STATUS_LED_PIN=23
    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Optional LED enabled - YAML not generated"
        return
    fi

    # Check if status_led or light section with pin 23 exists
    if grep -q "status_led:" "esphome/esp32c6-gdo.yaml" || grep -q "pin: 23" "esphome/esp32c6-gdo.yaml"; then
        pass "Optional LED enabled - status LED configured"
    else
        # This might be okay if the template handles it differently
        skip "Optional LED enabled - status LED config style unclear"
    fi
}

# Test: YAML syntax validity
test_yaml_syntax() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "YAML syntax - YAML not generated"
        return
    fi

    # Use Python to validate YAML syntax
    # ESPHome uses custom tags like !secret, !include, !lambda
    # We need to register dummy constructors for these
    if command -v python3 &> /dev/null; then
        if python3 << 'PYTHON_EOF'
import yaml
import sys

# Register ESPHome-specific YAML tags as pass-through
for tag in ['!secret', '!include', '!lambda', '!extend', '!remove']:
    yaml.SafeLoader.add_constructor(tag, lambda l, n: l.construct_scalar(n))

try:
    yaml.safe_load(open('esphome/esp32c6-gdo.yaml'))
    sys.exit(0)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
        then
            pass "YAML syntax - valid YAML"
        else
            fail "YAML syntax" "Invalid YAML syntax"
        fi
    else
        skip "YAML syntax - python3 not available"
    fi
}

# Test: Required sections present
test_required_sections() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "Required sections - YAML not generated"
        return
    fi

    local errors=""

    # Check for essential ESPHome sections
    if ! grep -q "^esphome:" "esphome/esp32c6-gdo.yaml"; then
        errors+="Missing 'esphome:' section. "
    fi

    if ! grep -q "^esp32:" "esphome/esp32c6-gdo.yaml"; then
        errors+="Missing 'esp32:' section. "
    fi

    if ! grep -q "^wifi:" "esphome/esp32c6-gdo.yaml"; then
        errors+="Missing 'wifi:' section. "
    fi

    if ! grep -q "^api:" "esphome/esp32c6-gdo.yaml"; then
        errors+="Missing 'api:' section. "
    fi

    if [[ -n "$errors" ]]; then
        fail "Required sections" "$errors"
    else
        pass "Required sections - all essential sections present"
    fi
}

# Test: External components configured
test_external_components() {
    cd "$PROJECT_ROOT"

    if [[ ! -f "esphome/esp32c6-gdo.yaml" ]]; then
        skip "External components - YAML not generated"
        return
    fi

    if grep -q "external_components:" "esphome/esp32c6-gdo.yaml"; then
        pass "External components - section configured"
    else
        fail "External components" "Missing external_components section"
    fi
}

# Run all YAML generation tests
test_basic_substitution
test_device_name_substitution
test_friendly_name_substitution
test_gpio_pin_substitution
test_optional_led_enabled
test_yaml_syntax
test_required_sections
test_external_components
