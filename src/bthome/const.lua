--- @module "bthome.const"
--- BTHome object ID definitions and data format constants.
--- Contains all 78+ sensor object IDs from the BTHome specification.
--- @see https://bthome.io/format
---
--- @class bthome.const
local const = {}

--- @class BTHomeObjectDefinition
--- @field name string Sensor name (e.g., "temperature", "humidity")
--- @field display_name string Human-readable display name (e.g., "Temperature", "Humidity")
--- @field format BTHomeFormat Data format type (e.g., "uint8", "sint16", "string")
--- @field factor number Scaling factor to apply to raw value
--- @field unit string|nil Unit of measurement (e.g., "°C", "%", nil)
--- @field length integer Byte length of the value (0 for variable-length)
--- @field is_event boolean|nil True if this is an event type (button, dimmer)

--- Data format types for encoding values.
--- @enum BTHomeFormat
const.FORMAT = {
  UINT8 = "uint8",
  SINT8 = "sint8",
  UINT16 = "uint16",
  SINT16 = "sint16",
  UINT24 = "uint24",
  SINT24 = "sint24",
  UINT32 = "uint32",
  SINT32 = "sint32",
  UINT48 = "uint48",
  STRING = "string",
  MAC = "mac",
}

--- Object ID definitions.
--- @type table<integer, BTHomeObjectDefinition?>
const.OBJECT_IDS = {
  -- Sensors
  [0x01] = {
    name = "battery",
    display_name = "Battery",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = "%",
    length = 1,
  },
  [0x02] = {
    name = "temperature",
    display_name = "Temperature",
    format = const.FORMAT.SINT16,
    factor = 0.01,
    unit = "°C",
    length = 2,
  },
  [0x03] = {
    name = "humidity",
    display_name = "Humidity",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "%",
    length = 2,
  },
  [0x04] = {
    name = "pressure",
    display_name = "Pressure",
    format = const.FORMAT.UINT24,
    factor = 0.01,
    unit = "hPa",
    length = 3,
  },
  [0x05] = {
    name = "illuminance",
    display_name = "Illuminance",
    format = const.FORMAT.UINT24,
    factor = 0.01,
    unit = "lx",
    length = 3,
  },
  [0x06] = {
    name = "mass_kg",
    display_name = "Mass",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "kg",
    length = 2,
  },
  [0x07] = {
    name = "mass_lb",
    display_name = "Mass",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "lb",
    length = 2,
  },
  [0x08] = {
    name = "dewpoint",
    display_name = "Dew Point",
    format = const.FORMAT.SINT16,
    factor = 0.01,
    unit = "°C",
    length = 2,
  },
  [0x09] = { name = "count", display_name = "Count", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x0A] = {
    name = "energy",
    display_name = "Energy",
    format = const.FORMAT.UINT24,
    factor = 0.001,
    unit = "kWh",
    length = 3,
  },
  [0x0B] = {
    name = "power",
    display_name = "Power",
    format = const.FORMAT.UINT24,
    factor = 0.01,
    unit = "W",
    length = 3,
  },
  [0x0C] = {
    name = "voltage",
    display_name = "Voltage",
    format = const.FORMAT.UINT16,
    factor = 0.001,
    unit = "V",
    length = 2,
  },
  [0x0D] = {
    name = "pm2_5",
    display_name = "PM2.5",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "µg/m³",
    length = 2,
  },
  [0x0E] = {
    name = "pm10",
    display_name = "PM10",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "µg/m³",
    length = 2,
  },
  [0x12] = { name = "co2", display_name = "CO₂", format = const.FORMAT.UINT16, factor = 1, unit = "ppm", length = 2 },
  [0x13] = {
    name = "tvoc",
    display_name = "TVOC",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "µg/m³",
    length = 2,
  },
  [0x14] = {
    name = "moisture",
    display_name = "Moisture",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "%",
    length = 2,
  },
  [0x2E] = {
    name = "humidity",
    display_name = "Humidity",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = "%",
    length = 1,
  },
  [0x2F] = {
    name = "moisture",
    display_name = "Moisture",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = "%",
    length = 1,
  },
  [0x3D] = { name = "count", display_name = "Count", format = const.FORMAT.UINT16, factor = 1, unit = nil, length = 2 },
  [0x3E] = { name = "count", display_name = "Count", format = const.FORMAT.UINT32, factor = 1, unit = nil, length = 4 },
  [0x3F] = {
    name = "rotation",
    display_name = "Rotation",
    format = const.FORMAT.SINT16,
    factor = 0.1,
    unit = "°",
    length = 2,
  },
  [0x40] = {
    name = "distance_mm",
    display_name = "Distance",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "mm",
    length = 2,
  },
  [0x41] = {
    name = "distance_m",
    display_name = "Distance",
    format = const.FORMAT.UINT16,
    factor = 0.1,
    unit = "m",
    length = 2,
  },
  [0x42] = {
    name = "duration",
    display_name = "Duration",
    format = const.FORMAT.UINT24,
    factor = 0.001,
    unit = "s",
    length = 3,
  },
  [0x43] = {
    name = "current",
    display_name = "Current",
    format = const.FORMAT.UINT16,
    factor = 0.001,
    unit = "A",
    length = 2,
  },
  [0x44] = {
    name = "speed",
    display_name = "Speed",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "m/s",
    length = 2,
  },
  [0x45] = {
    name = "temperature",
    display_name = "Temperature",
    format = const.FORMAT.SINT16,
    factor = 0.1,
    unit = "°C",
    length = 2,
  },
  [0x46] = {
    name = "uv_index",
    display_name = "UV Index",
    format = const.FORMAT.UINT8,
    factor = 0.1,
    unit = nil,
    length = 1,
  },
  [0x47] = {
    name = "volume",
    display_name = "Volume",
    format = const.FORMAT.UINT16,
    factor = 0.1,
    unit = "L",
    length = 2,
  },
  [0x48] = {
    name = "volume_ml",
    display_name = "Volume",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "mL",
    length = 2,
  },
  [0x49] = {
    name = "volume_flow_rate",
    display_name = "Volume Flow Rate",
    format = const.FORMAT.UINT16,
    factor = 0.001,
    unit = "m³/h",
    length = 2,
  },
  [0x4A] = {
    name = "voltage",
    display_name = "Voltage",
    format = const.FORMAT.UINT16,
    factor = 0.1,
    unit = "V",
    length = 2,
  },
  [0x4B] = {
    name = "gas",
    display_name = "Gas",
    format = const.FORMAT.UINT24,
    factor = 0.001,
    unit = "m³",
    length = 3,
  },
  [0x4C] = {
    name = "gas",
    display_name = "Gas",
    format = const.FORMAT.UINT32,
    factor = 0.001,
    unit = "m³",
    length = 4,
  },
  [0x4D] = {
    name = "energy",
    display_name = "Energy",
    format = const.FORMAT.UINT32,
    factor = 0.001,
    unit = "kWh",
    length = 4,
  },
  [0x4E] = {
    name = "volume",
    display_name = "Volume",
    format = const.FORMAT.UINT32,
    factor = 0.001,
    unit = "L",
    length = 4,
  },
  [0x4F] = {
    name = "water",
    display_name = "Water",
    format = const.FORMAT.UINT32,
    factor = 0.001,
    unit = "L",
    length = 4,
  },
  [0x50] = {
    name = "timestamp",
    display_name = "Timestamp",
    format = const.FORMAT.UINT32,
    factor = 1,
    unit = nil,
    length = 4,
  },
  [0x51] = {
    name = "acceleration",
    display_name = "Acceleration",
    format = const.FORMAT.UINT16,
    factor = 0.001,
    unit = "m/s²",
    length = 2,
  },
  [0x52] = {
    name = "gyroscope",
    display_name = "Gyroscope",
    format = const.FORMAT.UINT16,
    factor = 0.001,
    unit = "°/s",
    length = 2,
  },
  [0x53] = { name = "text", display_name = "Text", format = const.FORMAT.STRING, factor = 1, unit = nil, length = 0 }, -- Variable length
  [0x54] = { name = "raw", display_name = "Raw", format = const.FORMAT.STRING, factor = 1, unit = nil, length = 0 }, -- Variable length
  [0x55] = {
    name = "volume_storage",
    display_name = "Volume Storage",
    format = const.FORMAT.UINT32,
    factor = 0.001,
    unit = "L",
    length = 4,
  },
  [0x56] = {
    name = "conductivity",
    display_name = "Conductivity",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "µS/cm",
    length = 2,
  },
  [0x57] = {
    name = "temperature",
    display_name = "Temperature",
    format = const.FORMAT.SINT8,
    factor = 1,
    unit = "°C",
    length = 1,
  },
  [0x58] = {
    name = "temperature",
    display_name = "Temperature",
    format = const.FORMAT.SINT8,
    factor = 0.35,
    unit = "°C",
    length = 1,
  },
  [0x59] = { name = "count", display_name = "Count", format = const.FORMAT.SINT8, factor = 1, unit = nil, length = 1 },
  [0x5A] = { name = "count", display_name = "Count", format = const.FORMAT.SINT16, factor = 1, unit = nil, length = 2 },
  [0x5B] = { name = "count", display_name = "Count", format = const.FORMAT.SINT32, factor = 1, unit = nil, length = 4 },
  [0x5C] = {
    name = "power",
    display_name = "Power",
    format = const.FORMAT.SINT32,
    factor = 0.01,
    unit = "W",
    length = 4,
  },
  [0x5D] = {
    name = "current",
    display_name = "Current",
    format = const.FORMAT.SINT16,
    factor = 0.001,
    unit = "A",
    length = 2,
  },
  [0x5E] = {
    name = "direction",
    display_name = "Direction",
    format = const.FORMAT.UINT16,
    factor = 0.01,
    unit = "°",
    length = 2,
  },
  [0x5F] = {
    name = "precipitation",
    display_name = "Precipitation",
    format = const.FORMAT.UINT16,
    factor = 0.1,
    unit = "mm",
    length = 2,
  },
  [0x60] = {
    name = "channel",
    display_name = "Channel",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x61] = {
    name = "rotational_speed",
    display_name = "Rotational Speed",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = "rpm",
    length = 2,
  },
  [0x62] = {
    name = "speed_signed",
    display_name = "Speed",
    format = const.FORMAT.SINT32,
    factor = 0.000001,
    unit = "m/s",
    length = 4,
  },
  [0x63] = {
    name = "acceleration_signed",
    display_name = "Acceleration",
    format = const.FORMAT.SINT32,
    factor = 0.000001,
    unit = "m/s²",
    length = 4,
  },

  -- Binary sensors
  [0x0F] = {
    name = "generic_boolean",
    display_name = "Generic Boolean",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x10] = {
    name = "power_on",
    display_name = "Power",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x11] = {
    name = "opening",
    display_name = "Opening",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x15] = {
    name = "battery_low",
    display_name = "Battery Low",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x16] = {
    name = "battery_charging",
    display_name = "Battery Charging",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x17] = {
    name = "carbon_monoxide_detected",
    display_name = "Carbon Monoxide",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x18] = { name = "cold", display_name = "Cold", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x19] = {
    name = "connectivity",
    display_name = "Connectivity",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x1A] = { name = "door", display_name = "Door", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x1B] = {
    name = "garage_door",
    display_name = "Garage Door",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x1C] = {
    name = "gas_detected",
    display_name = "Gas",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x1D] = { name = "heat", display_name = "Heat", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x1E] = {
    name = "light_detected",
    display_name = "Light",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x1F] = {
    name = "lock_unlocked",
    display_name = "Lock",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x20] = {
    name = "moisture_detected",
    display_name = "Moisture",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x21] = { name = "motion", display_name = "Motion", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x22] = { name = "moving", display_name = "Moving", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x23] = {
    name = "occupancy",
    display_name = "Occupancy",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x24] = { name = "plug", display_name = "Plug", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x25] = {
    name = "presence",
    display_name = "Presence",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x26] = {
    name = "problem",
    display_name = "Problem",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x27] = {
    name = "running",
    display_name = "Running",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x28] = { name = "safety", display_name = "Safety", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x29] = {
    name = "smoke_detected",
    display_name = "Smoke",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x2A] = {
    name = "sound_detected",
    display_name = "Sound",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x2B] = { name = "tamper", display_name = "Tamper", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },
  [0x2C] = {
    name = "vibration_detected",
    display_name = "Vibration",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
  [0x2D] = { name = "window", display_name = "Window", format = const.FORMAT.UINT8, factor = 1, unit = nil, length = 1 },

  -- Events
  [0x3A] = {
    name = "button",
    display_name = "Button",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
    is_event = true,
  },
  [0x3C] = {
    name = "dimmer",
    display_name = "Dimmer",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 2,
    is_event = true,
  },

  -- Device Info
  [0xF0] = {
    name = "device_type_id",
    display_name = "Device Type ID",
    format = const.FORMAT.UINT16,
    factor = 1,
    unit = nil,
    length = 2,
  },
  [0xF1] = {
    name = "firmware_version",
    display_name = "Firmware Version",
    format = const.FORMAT.UINT32,
    factor = 1,
    unit = nil,
    length = 4,
  },
  [0xF2] = {
    name = "firmware_version",
    display_name = "Firmware Version",
    format = const.FORMAT.UINT24,
    factor = 1,
    unit = nil,
    length = 3,
  },

  -- Misc
  [0x00] = {
    name = "packet_id",
    display_name = "Packet ID",
    format = const.FORMAT.UINT8,
    factor = 1,
    unit = nil,
    length = 1,
  },
}

--- @class BTHomeV1FormatDefinition
--- @field format BTHomeFormat Format name (e.g., "uint8", "sint16")
--- @field length integer Byte length

--- BTHome V1 data format types (for legacy support).
--- In V1, bits 5-7 of the object byte encode the data format.
--- @type table<integer, BTHomeV1FormatDefinition?>
const.V1_FORMATS = {
  [0x00] = { format = const.FORMAT.UINT8, length = 1 },
  [0x01] = { format = const.FORMAT.SINT8, length = 1 },
  [0x02] = { format = const.FORMAT.UINT16, length = 2 },
  [0x03] = { format = const.FORMAT.SINT16, length = 2 },
  [0x04] = { format = const.FORMAT.UINT24, length = 3 },
  [0x05] = { format = const.FORMAT.SINT24, length = 3 },
  [0x06] = { format = const.FORMAT.UINT32, length = 4 },
  [0x07] = { format = const.FORMAT.SINT32, length = 4 },
}

--- Device info byte bit positions.
--- @enum BTHomeDeviceInfoBit
const.DEVICE_INFO = {
  ENCRYPTED_BIT = 0, -- Bit 0: encryption flag
  TRIGGER_BIT = 2, -- Bit 2: trigger-based device flag
  VERSION_SHIFT = 5, -- Bits 5-7: BTHome version
  VERSION_MASK = 0x07, -- Mask for version bits (3 bits)
}

--- BTHome versions.
--- @enum BTHomeVersionEnum
const.VERSION = {
  V1 = 1,
  V2 = 2,
}

--- Get object definition by ID.
--- @param object_id integer The object ID (0x00-0xFF)
--- @return BTHomeObjectDefinition|nil definition Object definition or nil if unknown
function const.get_object(object_id)
  return const.OBJECT_IDS[object_id]
end

--- Get the length of a variable-length field.
--- For text and raw fields, the first byte is the length.
--- @param format BTHomeFormat The format type
--- @param data string The data starting at the length byte
--- @return integer length The total length including the length byte
function const.get_variable_length(format, data)
  if format == const.FORMAT.STRING and #data >= 1 then
    return 1 + string.byte(data, 1)
  end
  return 0
end

--- Run self-tests.
--- @return boolean success True if all tests passed
function const.selftest()
  print("Testing const module...")
  local passed = 0
  local total = 0

  -- ===========================================================================
  -- Object ID Lookup Tests
  -- ===========================================================================

  local test_ids = {
    { id = 0x00, name = "packet_id" },
    { id = 0x01, name = "battery" },
    { id = 0x02, name = "temperature" },
    { id = 0x03, name = "humidity" },
    { id = 0x3A, name = "button" },
    { id = 0x53, name = "text" },
  }

  for _, test in ipairs(test_ids) do
    total = total + 1
    local obj = const.get_object(test.id)
    if obj and obj.name == test.name then
      print(string.format("  PASS: Object ID 0x%02X = %s", test.id, test.name))
      passed = passed + 1
    else
      print(string.format("  FAIL: Object ID 0x%02X", test.id))
      print(string.format("    Expected: %s", test.name))
      print(string.format("    Got: %s", obj and obj.name or "nil"))
    end
  end

  -- ===========================================================================
  -- Object Attribute Tests
  -- ===========================================================================

  total = total + 1
  local temp = const.get_object(0x02)
  if temp and temp.factor == 0.01 and temp.length == 2 then
    print("  PASS: Temperature has correct factor and length")
    passed = passed + 1
  else
    print("  FAIL: Temperature attributes")
    print(string.format("    Expected: factor=0.01, length=2"))
    print(string.format("    Got: factor=%s, length=%s", temp and temp.factor, temp and temp.length))
  end

  -- ===========================================================================
  -- Unknown Object ID Tests
  -- ===========================================================================

  total = total + 1
  local unknown = const.get_object(0xFF)
  if unknown == nil then
    print("  PASS: Unknown object ID returns nil")
    passed = passed + 1
  else
    print("  FAIL: Unknown object ID should return nil")
    print(string.format("    Got: %s", tostring(unknown)))
  end

  print(string.format("\nconst module: %d/%d tests passed\n", passed, total))
  return passed == total
end

return const
