# lua-bthome-ble

A pure Lua [BTHome](https://bthome.io) BLE advertisement parser with **zero external dependencies**. Supports both V1
and V2 formats, including encrypted advertisements with AES-128-CCM decryption. This library provides a complete,
cross-platform implementation that runs on Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT.

## Features

- **Zero Dependencies**: Pure Lua implementation, no C extensions required
- **Portable**: Runs on Lua 5.1, 5.2, 5.3, 5.4, and LuaJIT
- **Complete**: Supports 78+ sensor types from the BTHome specification
- **Encryption**: AES-128-CCM decryption for encrypted advertisements
- **Well-tested**: 70+ self-tests with vectors from the official bthome-ble implementation

## Installation

Download the single-file distribution from the
[releases page](https://github.com/finitelabs/lua-bthome-ble/releases):

- **`bthome.lua`** - Full library (includes bitn for bitwise operations)
- **`bthome-core.lua`** - Core library only (requires external bitn)

Or clone this repository:

```bash
git clone https://github.com/finitelabs/lua-bthome-ble.git
cd lua-bthome-ble
```

Add the `src` and `vendor` directories to your Lua path.

## Usage

### Basic Example

```lua
local bthome = require("bthome")

-- Check version
print(bthome.version())

-- Parse an unencrypted V2 advertisement (UUID 0xFCD2)
-- Example: Temperature 25.06°C + Humidity 50.55%
local service_data = "\x40\x02\xca\x09\x03\xbf\x13"
local result, err = bthome.parse(bthome.UUID_V2, service_data)

if result then
  print("BTHome Version:", result.device_info.version)
  print("Encrypted:", result.device_info.encrypted)

  for _, reading in ipairs(result.readings) do
    print(string.format("%s: %s %s",
      reading.name,
      reading.value,
      reading.unit or ""))
  end
else
  print("Parse error:", err)
end
```

Output:

```
BTHome Version: 2
Encrypted: false
temperature: 25.06 °C
humidity: 50.55 %
```

### Encrypted Advertisements

```lua
local bthome = require("bthome")

-- 16-byte encryption key (bind_key)
local bind_key = "\x23\x1d\x39\xc1\xd7\xcc\x1a\xb1\xae\xe2\x24\xcd\x09\x6d\xb9\x32"

-- 6-byte MAC address
local mac_address = "\x54\x48\xe6\x8f\x80\xa5"

-- V2 encrypted service data (UUID 0xFCD2)
local service_data = "\x41..." -- encrypted payload
local result, err = bthome.parse(bthome.UUID_V2, service_data, bind_key, mac_address)

-- V1 encrypted service data (UUID 0x181E)
local v1_service_data = "\xfb..." -- encrypted payload
local result, err = bthome.parse(bthome.UUID_V1_ENCRYPTED, v1_service_data, bind_key, mac_address)

if result then
  for _, reading in ipairs(result.readings) do
    print(reading.name, reading.value)
  end
end
```

### Result Structure

```lua
{
  device_info = {
    encrypted = false,      -- true if advertisement was encrypted
    trigger_based = false,  -- true for button/event devices
    version = 2             -- BTHome version (1 or 2)
  },
  packet_id = 5,            -- optional packet counter
  readings = {
    {
      name = "temperature",
      value = 25.06,
      unit = "°C",
      id = 0x02,
      instance = 1          -- instance number for duplicate sensors
    },
    {
      name = "humidity",
      value = 50.55,
      unit = "%",
      id = 0x03,
      instance = 1
    }
  }
}
```

### Supported Sensor Types

| Category      | Sensors                                                                      |
|---------------|------------------------------------------------------------------------------|
| Environmental | temperature, humidity, pressure, illuminance, dewpoint, uv_index             |
| Air Quality   | co2, tvoc, pm2_5, pm10                                                       |
| Power         | battery, voltage, current, power, energy                                     |
| Motion        | motion, acceleration, gyroscope, rotation, speed                             |
| Binary        | opening, door, window, lock, smoke, tamper, vibration, moisture_detected     |
| Volume        | volume_liters, volume_ml, volume_flow_rate, gas_volume                       |
| Distance      | distance_mm, distance_m                                                      |
| Mass          | mass_kg, mass_lb                                                             |
| Events        | button (press, double_press, long_press), dimmer (rotate_left, rotate_right) |

## Testing

```bash
# Run all tests
make test

# Run specific module tests
make test-parser
make test-crypto

# Run test matrix across Lua versions
make test-matrix

# Check formatting and linting
make check
```

## Building

```bash
# Build single-file distributions
make build

# Output:
#   build/bthome.lua      - Full library (includes bitn)
#   build/bthome-core.lua - Core only (requires external bitn)
```

## BTHome Protocol

BTHome is an open standard for broadcasting sensor data over Bluetooth Low
Energy. Key characteristics:

- **Service UUIDs**:
    - `0x181C` - V1 unencrypted
    - `0x181E` - V1 encrypted
    - `0xFCD2` - V2 (encryption determined by device_info byte)
- **V2 Device Info Byte**: Bit 0 = encrypted, Bit 2 = trigger-based, Bits 5-7 = version
- **Data Format**: Object ID followed by little-endian value bytes
- **Encryption**: AES-128-CCM with 4-byte MIC

For full specification, see [bthome.io](https://bthome.io).

## Current Limitations

- Pure Lua performance is slower than native implementations
- No constant-time guarantees for cryptographic operations

## Security Warning

This is a pure Lua implementation intended for portability and ease of use.
While we implement the algorithms correctly and pass all test vectors, the
implementation:

- Cannot guarantee constant-time operations
- Has not been independently audited
- Is significantly slower than native implementations

For production use with encrypted advertisements, consider using native
cryptographic libraries for the AES-CCM decryption.

## License

GNU Affero General Public License v3.0 - see LICENSE file for details.

## Contributing

Contributions are welcome! Please ensure all tests pass (`make test`) and
code passes linting (`make check`).

## Acknowledgments

- [BTHome specification](https://bthome.io) by the BTHome community
- [bthome-ble](https://github.com/Bluetooth-Devices/bthome-ble) Python reference implementation
- Test vectors derived from the official bthome-ble test suite

---

<a href="https://www.buymeacoffee.com/derek.miller" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
