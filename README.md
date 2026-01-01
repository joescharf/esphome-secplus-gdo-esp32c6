# esphome-secplus-gdo-esp32c6

ESP32-C6 (RISC-V) support for Security+ garage door openers using ESPHome.

This project builds upon the excellent work of [Konnected](https://github.com/konnected-io):
- [gdolib](https://github.com/konnected-io/gdolib) - Garage door opener library
- [esphome-secplus-gdo](https://github.com/konnected-io/esphome-secplus-gdo) - ESPHome component

## Why This Project?

The official Konnected ESPHome component includes precompiled libraries for Xtensa-based ESP32 chips (ESP32, S2, S3). The ESP32-C6 uses a **RISC-V architecture**, which requires recompiling the gdolib library.

This repository provides:
- Pre-compiled `libgdolib.a` for ESP32-C6 RISC-V
- A [forked esphome-secplus-gdo](https://github.com/joescharf/esphome-secplus-gdo) with ESPHome API compatibility fixes
- Simple build script for easy deployment
- Generic ESP32-C6 configuration with customizable GPIO pins

## Quick Start

### Prerequisites

- Python 3.10-3.13 with `pip` or `uv` (Python 3.14+ not supported by ESP-IDF)
- ESPHome installed (`pip install esphome` or `uv tool install esphome`)
- Git
- USB cable (data-capable, not power-only)

### Installation

1. **Clone this repository with submodules:**
   ```bash
   git clone --recursive https://github.com/joescharf/esphome-secplus-gdo-esp32c6.git
   cd esphome-secplus-gdo-esp32c6
   ```

2. **Configure your GPIO pins:**
   ```bash
   cp config.env.example config.env
   # Edit config.env with your pin assignments
   ```

3. **Set up WiFi credentials:**
   ```bash
   cp esphome/secrets.yaml.example esphome/secrets.yaml
   # Edit esphome/secrets.yaml with your credentials
   ```

   Generate an API encryption key:
   ```bash
   python3 -c "import secrets, base64; print(base64.b64encode(secrets.token_bytes(32)).decode())"
   ```

4. **Build and upload:**
   ```bash
   ./build.sh --compile   # Build firmware
   ./build.sh --upload    # Build and flash to device
   ```

5. **Verify successful flash:**
   ```bash
   ./build.sh --logs      # Watch device output
   ```

   Look for "WiFi connected" and "API client connected" messages.

## Hardware Wiring

### Connecting to the Garage Door Opener

The ESP32-C6 communicates with your garage door opener via a serial (UART) connection using the Security+ protocol. You need to connect:

| ESP32-C6 Pin | Connection | Description |
|--------------|------------|-------------|
| GPIO TX (default 16) | Opener RX | Data TO the opener |
| GPIO RX (default 17) | Opener TX | Data FROM the opener |
| GND | Opener GND | Common ground |

**Important:** TX and RX are crossed - ESP32's TX connects to opener's RX and vice versa.

### Finding the Security+ Header

On most Security+ compatible openers (LiftMaster, Chamberlain, Craftsman):
- Look for a red/white/black wire connector on the opener's control board
- This is typically labeled as the "Serial" or "Security+" port
- Consult your opener's manual for the exact location

### Power Supply

- The ESP32-C6 can be powered via USB during development
- For permanent installation, use a 5V power supply connected to the 5V/VIN and GND pins
- Do NOT power from the garage door opener's low-voltage terminals without checking voltage compatibility

## Configuration

### GPIO Pins (config.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `GDO_TX_PIN` | 16 | UART TX pin (to garage door opener) |
| `GDO_RX_PIN` | 17 | UART RX pin (from garage door opener) |
| `STATUS_LED_PIN` | 23 | Status LED (optional, comment out to disable) |
| `OBSTRUCTION_PIN` | - | Obstruction sensor (optional, uses protocol detection if not set) |
| `DEVICE_NAME` | garage-door | ESPHome device name |
| `FRIENDLY_NAME` | Garage Door | Display name in Home Assistant |

**Note:** Avoid using GPIO12 and GPIO13 on ESP32-C6 as they are used for flash memory.

### Secrets (esphome/secrets.yaml)

| Variable | Description |
|----------|-------------|
| `wifi_ssid` | Your WiFi network name |
| `wifi_password` | Your WiFi password |
| `api_encryption_key` | Base64-encoded 32-byte key for Home Assistant API |
| `ota_password` | Password for OTA updates |

## Build Script Options

```bash
./build.sh --help                       # Show help
./build.sh --compile                    # Compile firmware only
./build.sh --upload                     # Compile and flash to device
./build.sh --upload --device <IP>       # Flash to specific IP (bypasses mDNS)
./build.sh --upload --logs              # Compile, flash, and show logs
./build.sh --clean                      # Remove ESPHome build artifacts
./build.sh --clean-all                  # Remove all build artifacts
./build.sh --clean --compile            # Clean then rebuild
./build.sh --rebuild-lib                # Rebuild gdolib from source (requires ESP-IDF)
./build.sh --skip-submodules            # Skip git submodule update
```

## First Boot and Initial Setup

### What Happens on First Boot

1. The device attempts to connect to your configured WiFi network
2. If WiFi connection fails, the device creates a fallback hotspot:
   - **SSID:** `{device-name}-fallback` (e.g., `garage-door-fallback`)
   - **Password:** `garagedoor`
3. Connect to the fallback hotspot to access the captive portal
4. Configure WiFi credentials through the portal

### Expected Boot Time

- First boot (with compilation): ~30-60 seconds to connect
- Subsequent boots: ~5-10 seconds to WiFi connection

### LED Status (if configured)

If you have a status LED configured (`STATUS_LED_PIN`):
- **Blinking:** Connecting to WiFi
- **Solid:** Connected and ready

## Home Assistant Integration

### Automatic Discovery

Once the device is connected to WiFi and Home Assistant API:
1. Home Assistant should automatically discover the device
2. Go to **Settings > Devices & Services > Integrations**
3. Look for the new ESPHome device and click "Configure"
4. Enter your API encryption key when prompted

### Manual Integration

If auto-discovery doesn't work:
1. Go to **Settings > Devices & Services > Add Integration**
2. Search for "ESPHome"
3. Enter the device IP address or hostname (e.g., `garage-door.local`)
4. Enter the API encryption key

### Expected Entities

After successful integration, you'll see these entities in Home Assistant:

| Entity | Type | Description |
|--------|------|-------------|
| `cover.garage_door` | Cover | Main garage door control (open/close/stop) |
| `light.garage_door_light` | Light | Garage opener light control |
| `lock.garage_door_lock_remotes` | Lock | Lock/unlock remote controls |
| `binary_sensor.garage_door_motion` | Binary Sensor | Motion detection from opener |
| `binary_sensor.garage_door_obstruction` | Binary Sensor | Obstruction detected |
| `binary_sensor.garage_door_motor` | Binary Sensor | Motor running (diagnostic) |
| `binary_sensor.garage_door_button` | Binary Sensor | Wall button pressed (diagnostic) |
| `sensor.garage_door_openings` | Sensor | Door opening counter |
| `number.garage_door_open_duration` | Number | Open duration timing (config) |
| `number.garage_door_close_duration` | Number | Close duration timing (config) |
| `select.garage_door_protocol` | Select | Protocol selection (auto/manual) |
| `switch.garage_door_learn_mode` | Switch | Enable pairing new remotes |
| `button.garage_door_factory_reset` | Button | Factory reset device |

**Note:** Entity names use your configured `DEVICE_NAME` and `FRIENDLY_NAME`.

## Web Interface

The device runs a web server for local access and debugging:

- **URL:** `http://{device-name}.local` (e.g., `http://garage-door.local`)
- **Port:** 80

### Available Features

- View current status of all entities
- Control door, light, and lock
- View sensor states
- Access diagnostic information
- Useful when Home Assistant is unavailable

## Log Output Examples

### Successful Boot
```
[I][app:029]: ESPHome version 2024.x.x compiled
[C][wifi:037]: Setting up WiFi...
[I][wifi:256]: WiFi Connected!
[C][api:025]: Setting up Home Assistant API server...
[I][api.connection:099]: API client connected
[I][secplus_gdo:123]: GDO initialized
[I][secplus_gdo:125]: Protocol: Security+ 2.0
```

### Successful Door Operation
```
[I][secplus_gdo:200]: Door command: OPEN
[I][secplus_gdo:210]: Door state: OPENING
[I][secplus_gdo:215]: Door state: OPEN
```

### Protocol Detection
```
[I][secplus_gdo:100]: Detecting protocol...
[I][secplus_gdo:110]: Protocol detected: Security+ 2.0
```

## Rebuilding gdolib (Advanced)

If you need to rebuild the gdolib library from source (e.g., after upstream updates):

1. **Install ESP-IDF v5.5.2 using the Installation Manager (Recommended):**

   Install using [ESP-IDF Installation Manager](https://dl.espressif.com/dl/eim/):
   ```bash
   # Linux (Debian/Ubuntu)
   sudo apt install eim && eim install --idf-versions v5.5.2

   # macOS
   brew tap espressif/eim && brew install --cask eim-gui

   # Windows
   winget install Espressif.EIM
   ```

   After installation, activate ESP-IDF:
   ```bash
   source ~/.espressif/v5.5.2/esp-idf/export.sh
   ```

2. **Rebuild:**
   ```bash
   ./build.sh --rebuild-lib --compile
   ```

## Running Tests

This project includes build verification tests to ensure everything works correctly:

```bash
# Run all tests
./tests/run_tests.sh

# Run with verbose output
./tests/run_tests.sh --verbose

# Run including full ESPHome compile (slow, ~15 minutes)
./tests/run_tests.sh --full-compile
```

### What Tests Verify

- YAML template generation and substitution
- Build script options work correctly
- ESPHome configuration validates
- All required sections are present

### Test Isolation

Tests use their own configuration files from `tests/fixtures/` and do not modify your `config.env`. The test framework temporarily uses a test `secrets.yaml` during ESPHome validation, which is restored after tests complete.

## Environment Variables

The build script supports environment variable overrides for advanced use cases:

| Variable | Default | Description |
|----------|---------|-------------|
| `CONFIG_FILE` | `./config.env` | Path to configuration file |
| `SECRETS_FILE` | `./esphome/secrets.yaml` | Path to secrets file |

Example usage:
```bash
# Use alternative config files
CONFIG_FILE=./my-config.env SECRETS_FILE=./my-secrets.yaml ./build.sh --compile
```

## Fork Maintenance

This project uses a [forked esphome-secplus-gdo](https://github.com/joescharf/esphome-secplus-gdo) repository. To sync with upstream changes:

```bash
cd upstream/esphome-secplus-gdo
git remote add upstream https://github.com/konnected-io/esphome-secplus-gdo.git
git fetch upstream
git merge upstream/master
# Resolve any conflicts, then push to your fork
git push origin master
```

## Changes from Upstream

The fork includes these fixes for ESPHome API compatibility:

| File | Change |
|------|--------|
| `cover/__init__.py` | Updated to `cover.cover_schema()` API |
| `lock/__init__.py` | Updated to `lock.lock_schema()` API |
| `light/gdo_light.h` | Replaced deprecated `BinaryLightOutput` with `LightOutput` |
| `__init__.py` | Added CODEOWNERS, fixed obstruction pin default |
| `secplus_gdo.cpp` | Fixed typos in event names |

## Hardware Compatibility

Tested with:
- Sparkfun Qwiic Pocket ESP32-C6
- Generic ESP32-C6-DevKitC-1

Should work with any ESP32-C6 board.

## Supported Protocols

- Security+ 1.0
- Security+ 2.0
- Security+ 1.0 with Smart Panel

## Troubleshooting

### Build fails with "binary/light/binary_light_output.h not found"
Make sure you're using the forked esphome-secplus-gdo submodule, not the original. Run:
```bash
git submodule update --init --recursive
```

### Device not found during upload
- Check USB connection
- Try a different USB cable (some are power-only)
- On Linux, ensure you have permission to access the serial port:
  ```bash
  sudo usermod -a -G dialout $USER
  # Log out and back in for changes to take effect
  ```

### Device boots into fallback AP mode repeatedly
- Check your WiFi credentials in `esphome/secrets.yaml`
- Verify the WiFi network is 2.4GHz (ESP32-C6 supports 2.4GHz only)
- Ensure the device is within WiFi range

### "Protocol not detected" in logs
- Verify TX/RX wiring (they should be crossed)
- Ensure the garage door opener supports Security+ protocol
- Check that the opener is powered on and functioning
- Try manually setting the protocol via the select entity

### Entities show "unavailable" in Home Assistant
- Check that the device is connected to WiFi (`./build.sh --logs`)
- Verify API encryption key matches between device and Home Assistant
- Restart the Home Assistant ESPHome integration

### Garage door not responding
- Verify TX/RX pins are correctly connected (TX to opener's RX, RX to opener's TX)
- Check that the Security+ protocol is compatible with your opener
- Review logs: `./build.sh --logs`

### OTA updates fail
- Ensure the device has a stable WiFi connection
- Check that the OTA password matches
- Try uploading via USB if OTA consistently fails

### Factory reset
To reset the device to defaults:
1. Use the "Factory Reset" button in Home Assistant, or
2. Use the web interface at `http://{device-name}.local`, or
3. Re-flash the firmware via USB

## License

GPL-3.0 (matching upstream projects)

## Credits

- [Konnected](https://konnected.io/) for the original gdolib and ESPHome component
- [ratgdo](https://github.com/ratgdo) project for inspiration
