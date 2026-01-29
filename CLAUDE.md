# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a pure Lua implementation of the BTHome BLE advertisement parser with zero external dependencies. It supports both BTHome V1 and V2 formats, including encrypted advertisements using AES-128-CCM.

**Key Characteristics:**
- Pure Lua implementation (5.1+ and LuaJIT compatible)
- Zero dependencies for maximum portability
- Complete BTHome V1/V2 parsing
- AES-128-CCM decryption for encrypted payloads
- Extensive test coverage with official bthome-ble test vectors

## Development Guide

## Project Structure

```
lua-bthome-ble/
├── src/bthome/
│   ├── init.lua           # Module aggregator with version()
│   ├── const.lua          # Object IDs, data types, factors, units
│   ├── event.lua          # Button/dimmer event definitions
│   ├── parser.lua         # BLE advertisement parsing
│   └── crypto/
│       ├── init.lua       # Crypto aggregator
│       └── aes_ccm.lua    # AES-128 + AES-CCM AEAD for BTHome encryption
├── vendor/
│   └── bitn.lua           # Vendored bitwise operations library
├── .github/workflows/
│   ├── build.yml          # CI: lint, test matrix, build
│   └── release.yml        # Release automation
├── run_tests.sh           # Main test runner
├── run_tests_matrix.sh    # Multi-version test runner
└── Makefile               # Build automation
```

## Key Commands

```bash
# Run tests
make test

# Run specific module tests
make test-bthome
make test-parser
make test-crypto

# Run across Lua versions
make test-matrix

# Format code
make format

# Lint code
make lint

# Run all quality checks
make check

# Build single-file distributions
make build
# Output: build/bthome.lua (full) and build/bthome-core.lua (without vendor)

# Install development dependencies
make install-deps
```

## Architecture

### Module Design

The BTHome library provides parsing for BTHome V1 and V2 BLE advertisements:

- **const.lua**: 78+ sensor object IDs from bthome.io/format spec
- **event.lua**: Button events (press, double_press, long_press, etc.) and dimmer events
- **parser.lua**: Main parsing logic for device info, object IDs, and encrypted payloads
- **crypto/aes_ccm.lua**: AES-128 block cipher and AES-CCM AEAD for encrypted BTHome advertisements

### BTHome Protocol

- **Service UUIDs**:
  - `0x181C` - V1 unencrypted
  - `0x181E` - V1 encrypted
  - `0xFCD2` - V2 (encryption determined by device_info byte)
- **V2 Device Info Byte**: Bit 0=encrypted, Bit 2=trigger, Bits 5-7=version
- **Data Format**: Object ID followed by little-endian value bytes
- **Encryption**: AES-128-CCM, 16-byte key, 4-byte MIC

### Public API

```lua
local bthome = require("bthome")

-- Parse V2 unencrypted advertisement
local result = bthome.parse(bthome.UUID_V2, service_data)

-- Parse V2 encrypted advertisement
local result = bthome.parse(bthome.UUID_V2, service_data, bind_key, mac_address)

-- Parse V1 unencrypted advertisement
local result = bthome.parse(bthome.UUID_V1_UNENCRYPTED, service_data)

-- Parse V1 encrypted advertisement
local result = bthome.parse(bthome.UUID_V1_ENCRYPTED, service_data, bind_key, mac_address)

-- Result structure:
-- {
--   device_info = { encrypted = bool, trigger_based = bool, version = 1|2 },
--   packet_id = number|nil,
--   readings = {
--     { name = "temperature", value = 25.06, unit = "°C", id = 0x02, instance = 1 },
--     { name = "humidity", value = 50.55, unit = "%", id = 0x03, instance = 1 },
--   }
-- }
```

### Error Handling

All functions return `result` or `nil, error_message` (no thrown exceptions):

```lua
local result, err = bthome.parse(data)
if not result then
  print("Parse error: " .. err)
end
```

## Testing

Tests use the selftest() pattern with inline test vectors:

```lua
function module.selftest()
  local passed = 0
  local total = 0

  -- Test cases...
  total = total + 1
  if condition then
    passed = passed + 1
  end

  return passed == total
end
```

Run with: `./run_tests.sh` or `make test`

Available test modules: bthome, const, event, crypto, parser

## Building

The build process uses `amalg` to create single-file distributions:

```bash
make build
# Output:
#   build/bthome.lua      - Full library (includes bitn)
#   build/bthome-core.lua - Core only (requires external bitn)
```

Version is automatically injected from git tags during release.

## CI/CD

- **build.yml**: Runs on push/PR to main
  - Format check with stylua
  - Lint with luacheck
  - Test matrix (Lua 5.1-5.4, LuaJIT 2.0/2.1)
  - Build both single-file distributions

- **release.yml**: Runs on version tags (v*)
  - Builds and publishes release with bthome.lua and bthome-core.lua artifacts

## Code Style

- 2-space indentation
- 120 column width
- Double quotes preferred
- LuaDoc annotations for all public functions

## Dependencies

- **vendor/bitn.lua**: Vendored bitwise operations library (pure Lua)
  - Provides bit32 operations needed for AES and parsing
  - Included in bthome.lua build, excluded from bthome-core.lua
