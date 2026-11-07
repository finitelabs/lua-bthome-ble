--- @module "bthome.parser"
--- BTHome BLE advertisement parser.
--- Parses both V1 and V2 BTHome advertisements, including encrypted payloads.
--- @see https://bthome.io/format
---
--- @class bthome.parser
local parser = {}

local bitn = require("bitn")
local bit16_u16_to_le_bytes = bitn.bit16.u16_to_le_bytes
local bit32_u32_to_le_bytes = bitn.bit32.u32_to_le_bytes

--- BTHome V1 unencrypted service UUID.
--- @type integer
parser.UUID_V1_UNENCRYPTED = 0x181C
--- BTHome V1 encrypted service UUID.
--- @type integer
parser.UUID_V1_ENCRYPTED = 0x181E
--- BTHome V2 service UUID.
--- @type integer
parser.UUID_V2 = 0xFCD2

--- @class BTHomeDeviceInfo
--- @field encrypted boolean True if the advertisement is encrypted
--- @field trigger_based boolean True if this is a trigger-based device (buttons, events)
--- @field version integer BTHome version (1 or 2)

--- @class BTHomeReading
--- @field name string Sensor name (e.g., "temperature", "humidity", "button")
--- @field value integer|number|string The sensor value (scaled by factor)
--- @field unit string|nil Unit of measurement (e.g., "°C", "%", nil)
--- @field id integer Object ID from the BTHome specification
--- @field instance integer Instance number for duplicate sensors (starts at 1)
--- @field event BTHomeButtonEvent|BTHomeDimmerEvent|nil Decoded event data (for button/dimmer only)

--- @class BTHomeParseResult
--- @field device_info BTHomeDeviceInfo Parsed device information
--- @field packet_id integer|nil Packet counter (if present in advertisement)
--- @field readings BTHomeReading[] Array of sensor readings

local const = require("bthome.const")
local event = require("bthome.event")
local crypto = require("bthome.crypto")

--- Read a little-endian unsigned integer from a string.
--- @param data string Input bytes
--- @param offset integer Starting offset (1-based)
--- @param length integer Number of bytes to read
--- @return integer value Unsigned integer value
local function read_uint_le(data, offset, length)
  local value = 0
  local multiplier = 1
  for i = 0, length - 1 do
    value = value + string.byte(data, offset + i) * multiplier
    multiplier = multiplier * 256
  end
  return value
end

--- Read a little-endian signed integer from a string.
--- @param data string Input bytes
--- @param offset integer Starting offset (1-based)
--- @param length integer Number of bytes to read
--- @return integer value Signed integer value
local function read_sint_le(data, offset, length)
  local value = read_uint_le(data, offset, length)
  local max_positive = math.floor(2 ^ (length * 8 - 1))
  if value >= max_positive then
    return math.floor(value - 2 ^ (length * 8))
  end
  return value
end

--- Build nonce for BTHome V1 encrypted advertisements.
--- Nonce format (12 bytes): MAC (6) || UUID16 (2 LE) || counter (4 LE)
--- @param mac string 6-byte MAC address
--- @param uuid integer UUID (0x181E for BTHome V1 encrypted)
--- @param counter integer 32-bit counter
--- @return string nonce 12-byte nonce
local function build_v1_nonce(mac, uuid, counter)
  return mac .. bit16_u16_to_le_bytes(uuid) .. bit32_u32_to_le_bytes(counter)
end

--- Build nonce for BTHome V2 encrypted advertisements.
--- Nonce format (13 bytes): MAC (6) || UUID (2 LE) || device_info (1) || counter (4 LE)
--- @param mac string 6-byte MAC address
--- @param uuid integer UUID (typically 0xFCD2 for BTHome)
--- @param device_info integer Device info byte
--- @param counter integer 32-bit counter
--- @return string nonce 13-byte nonce
local function build_v2_nonce(mac, uuid, device_info, counter)
  return mac .. bit16_u16_to_le_bytes(uuid) .. string.char(device_info) .. bit32_u32_to_le_bytes(counter)
end

--- Parse the device info byte to extract flags and version.
--- @param device_info integer Device info byte
--- @return BTHomeDeviceInfo info Parsed device info
local function parse_device_info(device_info)
  local encrypted = (device_info % 2) == 1
  local trigger_based = (math.floor(device_info / 4) % 2) == 1
  local version = math.floor(device_info / 32)

  return {
    encrypted = encrypted,
    trigger_based = trigger_based,
    version = version,
  }
end

--- Read a value based on format type.
--- @param data string Raw data
--- @param offset integer Starting offset (1-based)
--- @param format string Format type (uint8, sint8, uint16, etc.)
--- @param length integer Byte length
--- @return number|integer|string|nil value Parsed value
--- @return integer bytes_consumed Number of bytes consumed
local function read_value(data, offset, format, length)
  if offset + length - 1 > #data then
    return nil, 0
  end

  if format == "string" then
    -- Variable length: first byte is length
    local str_len = string.byte(data, offset)
    if offset + str_len > #data then
      return nil, 0
    end
    return data:sub(offset + 1, offset + str_len), str_len + 1
  elseif format == "mac" then
    return data:sub(offset, offset + length - 1), length
  elseif format:sub(1, 4) == "uint" then
    return read_uint_le(data, offset, length), length
  elseif format:sub(1, 4) == "sint" then
    return read_sint_le(data, offset, length), length
  else
    return read_uint_le(data, offset, length), length
  end
end

--- Parse firmware version bytes into a version string.
--- Bytes are read in little-endian order and formatted as "major.minor.patch[.build]"
--- @param data string Raw data
--- @param offset integer Starting offset (1-based)
--- @param length integer Number of bytes (3 or 4)
--- @return string version Version string (e.g., "1.2.3" or "1.2.3.4")
local function parse_firmware_version(data, offset, length)
  local parts = {}
  -- Read bytes in reverse order (little-endian: LSB first, but version is MSB first)
  for i = length, 1, -1 do
    parts[#parts + 1] = tostring(string.byte(data, offset + i - 1))
  end
  return table.concat(parts, ".")
end

--- Parse V2 BTHome payload (object IDs followed by values).
--- @param payload string Payload data (after device info byte)
--- @param start_offset integer Starting offset in payload (1-based)
--- @return BTHomeReading[]|nil readings Array of parsed readings
--- @return integer|nil packet_id Packet ID if present
--- @return string|nil error Error message if parsing failed
local function parse_v2_payload(payload, start_offset)
  local readings = {}
  local packet_id = nil
  local pos = start_offset

  while pos <= #payload do
    -- Read object ID
    local object_id = string.byte(payload, pos)
    pos = pos + 1

    -- Look up object definition
    local obj_def = const.get_object(object_id)
    if not obj_def then
      return nil, nil, string.format("unknown object ID: 0x%02X at position %d", object_id, pos - 1)
    end

    -- Handle variable-length fields
    local length = obj_def.length
    if length == 0 then
      -- Variable length: first byte is length
      if pos > #payload then
        return nil, nil, "truncated variable-length field"
      end
      length = string.byte(payload, pos) + 1 -- Include length byte
    end

    -- Read value
    local value, consumed = read_value(payload, pos, obj_def.format, length)
    if value == nil then
      return nil, nil, string.format("truncated data for object 0x%02X", object_id)
    end
    pos = pos + consumed

    -- Handle special object types
    if object_id == 0x00 and type(value) == "number" then
      -- Packet ID (always uint8)
      packet_id = math.floor(value)
    elseif object_id == 0xF1 or object_id == 0xF2 then
      -- Firmware version: parse as version string instead of raw integer
      local fw_version = parse_firmware_version(payload, pos - consumed, consumed)
      readings[#readings + 1] = {
        name = obj_def.name,
        value = fw_version,
        unit = obj_def.unit,
        id = object_id,
      }
    elseif obj_def.is_event and type(value) ~= "string" then
      -- Event (button, dimmer)
      local event_data = event.decode(obj_def.name, math.floor(value))
      readings[#readings + 1] = {
        name = obj_def.name,
        value = value,
        unit = obj_def.unit,
        id = object_id,
        event = event_data,
      }
    else
      -- Regular sensor reading: apply scaling factor
      if type(value) == "number" and obj_def.factor ~= 1 then
        value = value * obj_def.factor
      end
      readings[#readings + 1] = {
        name = obj_def.name,
        value = value,
        unit = obj_def.unit,
        id = object_id,
      }
    end
  end

  return readings, packet_id
end

--- Parse V1 BTHome payload (legacy format).
--- V1 format per object (from bthome-ble):
---   Byte 0: Control byte (bits 0-4 = data length incl type byte, bits 5-7 = format type)
---   Byte 1: Object/measurement type (same IDs as V2)
---   Bytes 2+: Data value
--- @param payload string Payload data
--- @param start_offset integer Starting offset
--- @return BTHomeReading[]|nil readings Array of parsed readings
--- @return integer|nil packet_id Packet ID if present
--- @return string|nil error Error message
local function parse_v1_payload(payload, start_offset)
  local readings = {}
  local packet_id = nil
  local pos = start_offset

  while pos <= #payload do
    -- Read control byte
    local control_byte = string.byte(payload, pos)
    local data_length_with_type = control_byte % 32 -- bits 0-4: length including type byte
    local format_type = math.floor(control_byte / 32) -- bits 5-7: format type

    -- Need at least control byte + type byte
    if pos + 1 > #payload then
      return nil, nil, "truncated V1 payload: missing type byte"
    end

    -- Read object type (same as V2 object IDs)
    local object_id = string.byte(payload, pos + 1)

    -- Calculate positions
    -- data_length_with_type includes the type byte, so actual data length = data_length_with_type - 1
    -- next_obj = pos + data_length_with_type + 1 (the +1 is for control byte)
    local actual_data_length = data_length_with_type - 1
    local data_start = pos + 2
    local next_pos = pos + data_length_with_type + 1

    if actual_data_length < 1 then
      return nil, nil, string.format("invalid V1 data length for object 0x%02X", object_id)
    end

    if data_start + actual_data_length - 1 > #payload then
      return nil, nil, string.format("truncated V1 data for object 0x%02X", object_id)
    end

    -- Get format info for reading the value
    local v1_format = const.V1_FORMATS[format_type]
    if not v1_format then
      return nil, nil, string.format("unknown V1 format type: %d", format_type)
    end

    -- Read value using actual data length
    local value, _ = read_value(payload, data_start, v1_format.format, actual_data_length)
    if value == nil then
      return nil, nil, string.format("failed to read V1 data for object 0x%02X", object_id)
    end

    -- Look up object definition (V1 uses same object IDs as V2)
    local obj_def = const.get_object(object_id)
    local name = obj_def and obj_def.name or string.format("sensor_%d", object_id)
    local factor = obj_def and obj_def.factor or 1
    local unit = obj_def and obj_def.unit or nil

    -- Apply scaling
    if type(value) == "number" and factor ~= 1 then
      value = value * factor
    end

    if object_id == 0 and type(value) == "number" then
      packet_id = math.floor(value)
    else
      readings[#readings + 1] = {
        name = name,
        value = value,
        unit = unit,
        id = object_id,
      }
    end

    pos = next_pos
  end

  return readings, packet_id
end

--- Post-process readings to assign instance numbers for duplicate names.
--- When the same sensor name appears multiple times, each gets an instance number starting at 1.
--- Example: temperature (instance=1), temperature (instance=2), temperature (instance=3)
--- @param readings BTHomeReading[] Array of readings to process
local function assign_instance_numbers(readings)
  local name_counts = {}

  for _, reading in ipairs(readings) do
    local name = reading.name
    if name_counts[name] then
      name_counts[name] = name_counts[name] + 1
    else
      name_counts[name] = 1
    end
    reading.instance = name_counts[name]
  end
end

--- Decrypt an encrypted BTHome V1 advertisement.
--- V1 encrypted format: [ciphertext][counter (4 bytes)][MIC (4 bytes)]
--- V1 uses UUID 0x181E and AAD = 0x11
--- @param encrypted_payload string Encrypted service data
--- @param bind_key string 16-byte encryption key
--- @param mac_address string 6-byte MAC address
--- @return string|nil decrypted Decrypted payload
--- @return string|nil error Error message
local function decrypt_v1(encrypted_payload, bind_key, mac_address)
  -- Encrypted V1 format:
  -- [ciphertext][counter (4 bytes)][MIC (4 bytes)]

  if #encrypted_payload < 8 then
    return nil, "encrypted payload too short"
  end

  -- Calculate 1-indexed positions for MIC and counter
  local mic_start = #encrypted_payload - 4 + 1 -- First byte of MIC
  local counter_start = mic_start - 4 -- First byte of counter

  local counter = read_uint_le(encrypted_payload, counter_start, 4)

  -- Build nonce for V1: MAC (6) + UUID16 (2) + counter (4) = 12 bytes
  -- V1 encrypted uses UUID 0x181E
  local nonce = build_v1_nonce(mac_address, 0x181E, counter)

  -- V1 uses AAD = 0x11 (single byte)
  local aad = string.char(0x11)

  -- Decrypt (ciphertext + MIC, excluding counter bytes)
  local ciphertext_with_mic = encrypted_payload:sub(1, counter_start - 1) .. encrypted_payload:sub(mic_start)

  local plaintext, err = crypto.aes_ccm.decrypt(bind_key, nonce, aad, ciphertext_with_mic, 4)
  if not plaintext then
    return nil, "decryption failed: " .. (err or "unknown error")
  end

  return plaintext
end

--- Decrypt an encrypted BTHome V2 advertisement.
--- @param encrypted_payload string Encrypted portion of service data
--- @param bind_key string 16-byte encryption key
--- @param mac_address string 6-byte MAC address
--- @param device_info integer Device info byte
--- @return string|nil decrypted Decrypted payload
--- @return string|nil error Error message
local function decrypt_v2(encrypted_payload, bind_key, mac_address, device_info)
  -- Encrypted V2 format:
  -- [encrypted data][counter (4 bytes)][MIC (4 bytes)]

  if #encrypted_payload < 8 then
    return nil, "encrypted payload too short"
  end

  -- Calculate 1-indexed positions for MIC and counter
  local mic_start = #encrypted_payload - 4 + 1 -- First byte of MIC
  local counter_start = mic_start - 4 -- First byte of counter

  local counter = read_uint_le(encrypted_payload, counter_start, 4)

  -- Build nonce for V2
  local nonce = build_v2_nonce(mac_address, 0xFCD2, device_info, counter)

  -- Decrypt (ciphertext + MIC, excluding counter bytes)
  local ciphertext_with_mic = encrypted_payload:sub(1, counter_start - 1) .. encrypted_payload:sub(mic_start)

  local plaintext, err = crypto.aes_ccm.decrypt(bind_key, nonce, "", ciphertext_with_mic, 4)
  if not plaintext then
    return nil, "decryption failed: " .. (err or "unknown error")
  end

  return plaintext
end

--- Parse a BTHome BLE advertisement.
--- Supports both V1 and V2 formats, encrypted and unencrypted.
---
--- The service UUID determines the format:
--- - 0x181C (UUID_V1_UNENCRYPTED): V1 unencrypted
--- - 0x181E (UUID_V1_ENCRYPTED): V1 encrypted (requires bind_key and mac_address)
--- - 0xFCD2 (UUID_V2): V2 format (device_info byte determines encryption)
---
--- @param uuid integer Service UUID (0x181C, 0x181E, or 0xFCD2)
--- @param service_data string Raw service data bytes from BLE advertisement
--- @param bind_key string|nil 16-byte encryption key (required for encrypted ads)
--- @param mac_address string|nil 6-byte MAC address (required for encrypted ads)
--- @return BTHomeParseResult|nil result Parsed result with device_info, packet_id, and readings
--- @return string|nil error Error message if parsing failed
function parser.parse(uuid, service_data, bind_key, mac_address)
  if not service_data or #service_data < 1 then
    return nil, "empty service data"
  end

  local device_info
  local payload
  local readings, packet_id, err

  -- V1 unencrypted (UUID 0x181C)
  if uuid == parser.UUID_V1_UNENCRYPTED then
    readings, packet_id, err = parse_v1_payload(service_data, 1)
    if not readings then
      return nil, err
    end

    device_info = {
      encrypted = false,
      trigger_based = false,
      version = 1,
    }

    assign_instance_numbers(readings)

    return {
      device_info = device_info,
      packet_id = packet_id,
      readings = readings,
    }
  end

  -- V1 encrypted (UUID 0x181E)
  if uuid == parser.UUID_V1_ENCRYPTED then
    if not bind_key then
      return nil, "bind_key required for encrypted advertisement"
    end
    if not mac_address then
      return nil, "MAC address required for encrypted advertisement"
    end
    if #bind_key ~= 16 then
      return nil, "bind_key must be 16 bytes"
    end
    if #mac_address ~= 6 then
      return nil, "MAC address must be 6 bytes"
    end

    local decrypted
    decrypted, err = decrypt_v1(service_data, bind_key, mac_address)
    if not decrypted then
      return nil, err
    end

    -- V1 encrypted payloads use V1 format internally
    readings, packet_id, err = parse_v1_payload(decrypted, 1)
    if not readings then
      return nil, err
    end

    device_info = {
      encrypted = true,
      trigger_based = false,
      version = 1,
    }

    assign_instance_numbers(readings)

    return {
      device_info = device_info,
      packet_id = packet_id,
      readings = readings,
    }
  end

  -- V2 (UUID 0xFCD2)
  if uuid ~= parser.UUID_V2 then
    return nil, string.format("unknown BTHome service UUID: 0x%04X", uuid)
  end

  -- Parse device info byte (first byte)
  local device_info_byte = string.byte(service_data, 1)
  device_info = parse_device_info(device_info_byte)

  -- Validate version in device_info byte
  if device_info.version ~= 2 then
    return nil, string.format("invalid BTHome V2 device_info version: %d", device_info.version)
  end

  payload = service_data:sub(2)

  if device_info.encrypted then
    -- Handle encrypted payload
    if not bind_key then
      return nil, "bind_key required for encrypted advertisement"
    end
    if not mac_address then
      return nil, "MAC address required for encrypted advertisement"
    end
    if #bind_key ~= 16 then
      return nil, "bind_key must be 16 bytes"
    end
    if #mac_address ~= 6 then
      return nil, "MAC address must be 6 bytes"
    end

    local decrypted
    decrypted, err = decrypt_v2(payload, bind_key, mac_address, device_info_byte)
    if not decrypted then
      return nil, err
    end

    payload = decrypted
  end

  -- Parse V2 payload
  readings, packet_id, err = parse_v2_payload(payload, 1)
  if not readings then
    return nil, err
  end

  -- Assign instance numbers for duplicate sensors (instance=1, instance=2, etc.)
  assign_instance_numbers(readings)

  return {
    device_info = device_info,
    packet_id = packet_id,
    readings = readings,
  }
end

return parser
