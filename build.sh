#!/bin/bash
#
# ESP32-C6 Security+ Garage Door Opener Build Script
#
# This script handles:
# - Git submodule initialization/update
# - Optional gdolib rebuild from source
# - ESPHome YAML generation from template
# - ESPHome firmware compilation and upload
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Allow CONFIG_FILE and SECRETS_FILE to be overridden via environment variables (useful for testing)
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config.env}"
SECRETS_FILE="${SECRETS_FILE:-${SCRIPT_DIR}/esphome/secrets.yaml}"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Parse command line arguments
REBUILD_LIB=false
SKIP_SUBMODULES=false
COMPILE_ONLY=false
UPLOAD=false
LOGS=false
CLEAN=false
CLEAN_ALL=false
DEVICE_IP=""

print_usage() {
    echo "ESP32-C6 Security+ Garage Door Opener Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --rebuild-lib     Rebuild libgdolib.a from source (requires ESP-IDF)"
    echo "  --skip-submodules Skip git submodule update"
    echo "  --compile         Compile ESPHome firmware"
    echo "  --upload          Compile and upload firmware to device"
    echo "  --device <IP>     Device IP address for OTA upload (bypasses mDNS)"
    echo "  --logs            Show device logs after upload"
    echo "  --clean           Remove ESPHome build artifacts (.esphome/)"
    echo "  --clean-all       Remove all build artifacts (ESPHome + ESP-IDF + generated files)"
    echo "  --help            Show this help message"
    echo ""
    echo "First-time setup:"
    echo "  1. Copy config.env.example to config.env"
    echo "  2. Edit config.env with your GPIO pins and settings"
    echo "  3. Copy esphome/secrets.yaml.example to esphome/secrets.yaml"
    echo "  4. Edit secrets.yaml with your WiFi credentials"
    echo "  5. Run: ./build.sh --compile"
    echo ""
    echo "ESP-IDF setup (only needed for --rebuild-lib):"
    echo "  Install ESP-IDF v5.5.2 using the ESP-IDF Installation Manager:"
    echo "    Linux (Debian/Ubuntu): sudo apt install eim && eim install --idf-versions v5.5.2"
    echo "    macOS: brew tap espressif/eim && brew install --cask eim-gui"
    echo "    Windows: winget install Espressif.EIM"
    echo "  Or download from: https://dl.espressif.com/dl/eim/"
    echo "  Before building: source ~/.espressif/v5.5.2/esp-idf/export.sh"
    echo ""
    echo "Examples:"
    echo "  ./build.sh --compile              # Build firmware"
    echo "  ./build.sh --upload               # Build and flash via mDNS"
    echo "  ./build.sh --upload --device 192.168.1.100  # Flash to specific IP"
    echo "  ./build.sh --upload --logs        # Build, flash, and show logs"
    echo "  ./build.sh --rebuild-lib --compile  # Rebuild library and compile"
    echo "  ./build.sh --clean                # Clean ESPHome build cache"
    echo "  ./build.sh --clean-all            # Full clean of all artifacts"
    echo "  ./build.sh --clean --compile      # Clean then rebuild"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild-lib)
            REBUILD_LIB=true
            shift
            ;;
        --skip-submodules)
            SKIP_SUBMODULES=true
            shift
            ;;
        --compile)
            COMPILE_ONLY=true
            shift
            ;;
        --upload)
            UPLOAD=true
            shift
            ;;
        --logs)
            LOGS=true
            shift
            ;;
        --device)
            DEVICE_IP="$2"
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --clean-all)
            CLEAN_ALL=true
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1\nRun '$0 --help' for usage."
            ;;
    esac
done

# Check for config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "config.env not found. Creating from example..."
    cp "${SCRIPT_DIR}/config.env.example" "$CONFIG_FILE"
    info "Created config.env. Please edit it with your settings, then run again."
    exit 0
fi

# Load configuration
source "$CONFIG_FILE"

# Set defaults
GDO_TX_PIN=${GDO_TX_PIN:-16}
GDO_RX_PIN=${GDO_RX_PIN:-17}
DEVICE_NAME=${DEVICE_NAME:-garage-door}
FRIENDLY_NAME=${FRIENDLY_NAME:-"Garage Door"}

info "Configuration loaded:"
echo "  Device: ${DEVICE_NAME} (\"${FRIENDLY_NAME}\")"
echo "  TX Pin: GPIO${GDO_TX_PIN}"
echo "  RX Pin: GPIO${GDO_RX_PIN}"
[[ -n "$STATUS_LED_PIN" ]] && echo "  LED Pin: GPIO${STATUS_LED_PIN}"
[[ -n "$OBSTRUCTION_PIN" ]] && echo "  Obstruction Pin: GPIO${OBSTRUCTION_PIN}"
echo ""

# Clean build artifacts if requested
if [[ "$CLEAN_ALL" == "true" ]]; then
    step "Performing full clean..."
    rm -rf "${SCRIPT_DIR}/esphome/.esphome"
    rm -rf "${SCRIPT_DIR}/esp-idf-build/build"
    rm -f "${SCRIPT_DIR}/esphome/esp32c6-gdo.yaml"
    rm -f "${SCRIPT_DIR}/esphome/components/gdolib-c6/libgdolib.a"
    rm -rf "${SCRIPT_DIR}/esphome/components/gdolib-c6/include"
    info "Full clean complete."
    # Exit if no build action requested
    if [[ "$COMPILE_ONLY" != "true" && "$UPLOAD" != "true" && "$REBUILD_LIB" != "true" ]]; then
        exit 0
    fi
elif [[ "$CLEAN" == "true" ]]; then
    step "Cleaning ESPHome build artifacts..."
    rm -rf "${SCRIPT_DIR}/esphome/.esphome"
    info "ESPHome clean complete."
    # Exit if no build action requested
    if [[ "$COMPILE_ONLY" != "true" && "$UPLOAD" != "true" && "$REBUILD_LIB" != "true" ]]; then
        exit 0
    fi
fi

# Step 1: Initialize/update git submodules
if [[ "$SKIP_SUBMODULES" != "true" ]]; then
    step "Initializing git submodules..."
    cd "$SCRIPT_DIR"
    git submodule update --init --recursive
    info "Submodules updated."
fi

# Check library version against upstream gdolib
VERSION_FILE="${SCRIPT_DIR}/lib/esp32c6/VERSION"
if [[ -f "$VERSION_FILE" && -d "${SCRIPT_DIR}/upstream/gdolib/.git" ]]; then
    BUILT_COMMIT=$(grep "^GDOLIB_COMMIT=" "$VERSION_FILE" | cut -d= -f2)
    CURRENT_COMMIT=$(git -C "${SCRIPT_DIR}/upstream/gdolib" rev-parse HEAD)
    if [[ -n "$BUILT_COMMIT" && "$BUILT_COMMIT" != "$CURRENT_COMMIT" ]]; then
        warn "Library version mismatch detected!"
        echo "  Built with:  ${BUILT_COMMIT:0:7}"
        echo "  Upstream is: ${CURRENT_COMMIT:0:7}"
        echo "  Consider running: ./build.sh --rebuild-lib"
    fi
fi

# Step 2: Rebuild library if requested
if [[ "$REBUILD_LIB" == "true" ]]; then
    step "Rebuilding libgdolib.a for ESP32-C6..."

    # Check for ESP-IDF
    if [[ -z "$IDF_PATH" ]]; then
        # Try common locations
        for idf_candidate in \
            "$HOME/.espressif/esp-idf" \
            "$HOME/esp/esp-idf" \
            "/opt/esp-idf" \
            "$HOME/.espressif/v5.5.2/esp-idf" \
            "$HOME/.espressif/v5.4/esp-idf" \
            "$HOME/.espressif/v5.3/esp-idf"; do
            if [[ -f "$idf_candidate/export.sh" ]]; then
                IDF_PATH="$idf_candidate"
                break
            fi
        done
    fi

    if [[ -z "$IDF_PATH" || ! -d "$IDF_PATH" ]]; then
        error "ESP-IDF not found. Please install ESP-IDF v5.x.

Install using ESP-IDF Installation Manager (recommended):
  Linux (Debian/Ubuntu): sudo apt install eim && eim install --idf-versions v5.5.2
  macOS: brew tap espressif/eim && brew install --cask eim-gui
  Windows: winget install Espressif.EIM
  Download: https://dl.espressif.com/dl/eim/

Then source the environment:
  source ~/.espressif/v5.5.2/esp-idf/export.sh"
    fi

    info "Using ESP-IDF at: $IDF_PATH"

    # Check if ESP-IDF Python environment is set up
    if [[ ! -d "$HOME/.espressif/python_env" ]]; then
        error "ESP-IDF Python environment not found.

Please complete ESP-IDF installation:
  1. Run: ${IDF_PATH}/install.sh esp32c6
  2. Then: source ${IDF_PATH}/export.sh

Or reinstall using ESP-IDF Installation Manager:
  eim install --idf-versions v5.5.2"
    fi

    # Create symlinks for gdolib source
    BUILD_DIR="${SCRIPT_DIR}/esp-idf-build"
    GDOLIB_COMPONENT="${BUILD_DIR}/components/gdolib"
    UPSTREAM_GDOLIB="${SCRIPT_DIR}/upstream/gdolib"

    info "Linking gdolib source files..."
    rm -f "${GDOLIB_COMPONENT}/gdo.c" "${GDOLIB_COMPONENT}/gdo_utils.c" \
           "${GDOLIB_COMPONENT}/secplus.c" "${GDOLIB_COMPONENT}/secplus.h" \
           "${GDOLIB_COMPONENT}/gdo_priv.h"
    rm -rf "${GDOLIB_COMPONENT}/include"

    ln -sf "${UPSTREAM_GDOLIB}/gdo.c" "${GDOLIB_COMPONENT}/"
    ln -sf "${UPSTREAM_GDOLIB}/gdo_utils.c" "${GDOLIB_COMPONENT}/"
    ln -sf "${UPSTREAM_GDOLIB}/secplus.c" "${GDOLIB_COMPONENT}/"
    ln -sf "${UPSTREAM_GDOLIB}/secplus.h" "${GDOLIB_COMPONENT}/"
    ln -sf "${UPSTREAM_GDOLIB}/gdo_priv.h" "${GDOLIB_COMPONENT}/"
    ln -sf "${UPSTREAM_GDOLIB}/include" "${GDOLIB_COMPONENT}/"

    # Build gdolib
    info "Building gdolib for ESP32-C6 (RISC-V)..."
    cd "$BUILD_DIR"

    # Check if ESP-IDF environment is activated (IDF_PYTHON_ENV_PATH is set by activate script)
    if [[ -z "$IDF_PYTHON_ENV_PATH" ]]; then
        error "ESP-IDF environment not activated. Please activate it first:

  source ~/.espressif/tools/activate_idf_v5.5.2.sh

Then run this command again."
    fi

    info "Using activated ESP-IDF environment"
    python "$IDF_PATH/tools/idf.py" set-target esp32c6
    python "$IDF_PATH/tools/idf.py" build

    # Copy built library
    info "Copying built library..."
    cp "${BUILD_DIR}/build/esp-idf/gdolib/libgdolib.a" "${SCRIPT_DIR}/lib/esp32c6/"
    cp "${UPSTREAM_GDOLIB}/include/gdo.h" "${SCRIPT_DIR}/lib/esp32c6/include/"

    # Update VERSION file with current gdolib commit
    CURRENT_COMMIT=$(git -C "${UPSTREAM_GDOLIB}" rev-parse HEAD)
    cat > "${SCRIPT_DIR}/lib/esp32c6/VERSION" <<EOF
# gdolib version tracking
# This file records the gdolib commit used to build libgdolib.a
# If upstream/gdolib is at a different commit, rebuild with: ./build.sh --rebuild-lib
GDOLIB_COMMIT=${CURRENT_COMMIT}
EOF
    info "Updated VERSION file with commit ${CURRENT_COMMIT:0:7}"

    info "Library rebuilt successfully!"
    cd "$SCRIPT_DIR"
fi

# Step 3: Set up gdolib-c6 component
step "Setting up gdolib-c6 component..."
GDOLIB_C6="${SCRIPT_DIR}/esphome/components/gdolib-c6"
cp "${SCRIPT_DIR}/lib/esp32c6/libgdolib.a" "$GDOLIB_C6/"
mkdir -p "${GDOLIB_C6}/include"
cp "${SCRIPT_DIR}/lib/esp32c6/include/gdo.h" "${GDOLIB_C6}/include/"
info "gdolib-c6 component ready."

# Step 4: Generate ESPHome YAML from template
step "Generating ESPHome configuration..."
ESPHOME_DIR="${SCRIPT_DIR}/esphome"
TEMPLATE="${ESPHOME_DIR}/esp32c6-gdo.yaml.template"
OUTPUT="${ESPHOME_DIR}/esp32c6-gdo.yaml"

# Build optional config sections
OBSTRUCTION_CONFIG=""
if [[ -n "$OBSTRUCTION_PIN" ]]; then
    OBSTRUCTION_CONFIG="  input_obst_pin: GPIO${OBSTRUCTION_PIN}"
fi

# For multi-line substitutions, we need special handling
# Status LED config spans multiple lines
STATUS_LED_CONFIG=""
if [[ -n "$STATUS_LED_PIN" ]]; then
    # Use escaped newlines for sed
    STATUS_LED_CONFIG="# Status LED\\
status_led:\\
  pin: GPIO${STATUS_LED_PIN}"
fi

# Generate from template
# Use sed for substitution (more portable than envsubst)
# For multi-line replacements, use escaped newlines
sed -e "s|\${GDO_TX_PIN}|${GDO_TX_PIN}|g" \
    -e "s|\${GDO_RX_PIN}|${GDO_RX_PIN}|g" \
    -e "s|\${DEVICE_NAME}|${DEVICE_NAME}|g" \
    -e "s|\${FRIENDLY_NAME}|${FRIENDLY_NAME}|g" \
    -e "s|\${OBSTRUCTION_CONFIG}|${OBSTRUCTION_CONFIG}|g" \
    -e "s|\${STATUS_LED_CONFIG}|${STATUS_LED_CONFIG}|g" \
    "$TEMPLATE" > "$OUTPUT"

info "Generated: $OUTPUT"

# Step 5: Check for secrets.yaml
if [[ ! -f "$SECRETS_FILE" ]]; then
    warn "secrets.yaml not found at $SECRETS_FILE"
    cp "${ESPHOME_DIR}/secrets.yaml.example" "$SECRETS_FILE"
    info "Created secrets.yaml from example."
    info "Please edit $SECRETS_FILE with your WiFi credentials and API key."
    echo ""
    echo "To generate an API encryption key, run:"
    echo "  python3 -c \"import secrets, base64; print(base64.b64encode(secrets.token_bytes(32)).decode())\""
    exit 0
fi

# Validate secrets.yaml has required keys
SECRETS_VALID=true
for key in wifi_ssid wifi_password api_encryption_key ota_password; do
    if ! grep -q "^${key}:" "$SECRETS_FILE"; then
        warn "Missing required key '$key' in secrets.yaml"
        SECRETS_VALID=false
    fi
done
if [[ "$SECRETS_VALID" != "true" ]]; then
    warn "Please update $SECRETS_FILE with all required keys before building."
fi

# Step 6: Compile/Upload/Logs ESPHome firmware
if [[ "$COMPILE_ONLY" == "true" || "$UPLOAD" == "true" || "$LOGS" == "true" ]]; then
    # Determine ESPHome command
    if command -v uv &> /dev/null; then
        # Use Python 3.13 (ESP-IDF requires Python 3.10-3.13, not 3.14+)
        ESPHOME_CMD="uv tool run --python 3.13 esphome"
    elif command -v esphome &> /dev/null; then
        ESPHOME_CMD="esphome"
    else
        error "ESPHome not found. Install with: pip install esphome"
    fi

    cd "$ESPHOME_DIR"

    if [[ "$UPLOAD" == "true" ]]; then
        step "Compiling and uploading ESPHome firmware..."
        if [[ -n "$DEVICE_IP" ]]; then
            info "Using device IP: $DEVICE_IP"
            $ESPHOME_CMD run esp32c6-gdo.yaml --device "$DEVICE_IP"
        else
            $ESPHOME_CMD run esp32c6-gdo.yaml
        fi
        info "Build complete!"
    elif [[ "$COMPILE_ONLY" == "true" ]]; then
        step "Compiling ESPHome firmware..."
        $ESPHOME_CMD compile esp32c6-gdo.yaml
        info "Build complete!"
    fi

    if [[ "$LOGS" == "true" ]]; then
        step "Showing device logs..."
        if [[ -n "$DEVICE_IP" ]]; then
            $ESPHOME_CMD logs esp32c6-gdo.yaml --device "$DEVICE_IP"
        else
            $ESPHOME_CMD logs esp32c6-gdo.yaml
        fi
    fi
else
    info "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Edit esphome/secrets.yaml with your WiFi/API credentials"
    echo "  2. Run: ./build.sh --compile   # Build firmware"
    echo "  3. Run: ./build.sh --upload    # Build and flash to device"
fi
