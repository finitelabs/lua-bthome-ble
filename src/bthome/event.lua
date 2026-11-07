--- @module "bthome.event"
--- BTHome button and dimmer event definitions.
--- Provides decoding for button presses and dimmer rotations.
--- @see https://bthome.io/format
--- @class bthome.event
local event = {}

local bit16 = require("bitn").bit16
local bit16_band = bit16.band
local bit16_rshift = bit16.rshift

--- @class BTHomeButtonEvent
--- @field raw_value integer Raw event byte value
--- @field event_type integer Event type code
--- @field event_name string Event name ("press", "double_press", "long_press", etc.)
--- @field device_number integer|nil Device/button number for multi-button devices

--- @class BTHomeDimmerEvent
--- @field raw_value integer Raw 2-byte value (little-endian: event_type in low byte, steps in high byte)
--- @field event_type integer Event type code (0=none, 1=rotate_left, 2=rotate_right)
--- @field event_name string Event name ("none", "rotate_left", or "rotate_right")
--- @field steps integer Number of rotation steps

--- Button event types.
--- The event value encodes both the event type (high nibble) and button number (low nibble).
--- Event value format: [event_type (4 bits)][device_number (4 bits)]
--- For single-button devices, device_number is typically 0.
--- @enum BTHomeButtonEventType
event.BUTTON = {
  NONE = 0x00,
  PRESS = 0x01,
  DOUBLE_PRESS = 0x02,
  TRIPLE_PRESS = 0x03,
  LONG_PRESS = 0x04,
  LONG_DOUBLE_PRESS = 0x05,
  LONG_TRIPLE_PRESS = 0x06,
  HOLD_PRESS = 0x80,
}

--- Button event names indexed by event type.
--- @type table<integer, string?>
event.BUTTON_NAMES = {
  [0x00] = "none",
  [0x01] = "press",
  [0x02] = "double_press",
  [0x03] = "triple_press",
  [0x04] = "long_press",
  [0x05] = "long_double_press",
  [0x06] = "long_triple_press",
  [0x80] = "hold_press",
}

--- Dimmer event types.
--- The dimmer event uses 2 bytes: [event_type][steps]
--- Event type: 0 = none, 1 = rotate left (counter-clockwise), 2 = rotate right (clockwise)
--- Steps: number of rotation steps (0-255)
--- @enum BTHomeDimmerEventType
event.DIMMER = {
  NONE = 0x00,
  ROTATE_LEFT = 0x01, -- Counter-clockwise
  ROTATE_RIGHT = 0x02, -- Clockwise
}

--- Dimmer event names indexed by event type.
--- @type table<integer, string?>
event.DIMMER_NAMES = {
  [0x00] = "none",
  [0x01] = "rotate_left",
  [0x02] = "rotate_right",
}

--- Decode a button event byte.
--- @param value integer The raw event byte value
--- @return BTHomeButtonEvent result Decoded button event with device_number and event_type
function event.decode_button(value)
  -- For button events with device numbers (multi-button devices):
  -- High nibble = event type, Low nibble = device number
  -- However, most implementations use the full byte as event type
  -- with separate multi-button handling via multiple object instances.

  local event_type = value
  local device_number = nil

  -- Check if this is a device-number encoded event (values > 0x06 except 0x80)
  if value > 0x06 and value ~= 0x80 then
    -- Multi-button event: low nibble is device number, high nibble is event type
    device_number = value % 0x10
    event_type = math.floor(value / 0x10) * 0x10
    if event_type == 0 then
      event_type = value -- Fall back to treating entire value as event type
      device_number = nil
    end
  end

  local event_name = event.BUTTON_NAMES[event_type] or "unknown"

  return {
    raw_value = value,
    event_type = event_type,
    event_name = event_name,
    device_number = device_number,
  }
end

--- Decode a dimmer event value.
--- The format is 2 bytes: [event_type][steps], read as little-endian uint16.
--- Low byte = event_type (0=none, 1=rotate_left, 2=rotate_right)
--- High byte = steps (number of rotation steps)
--- @param value integer The raw 2-byte dimmer value (as little-endian uint16)
--- @return BTHomeDimmerEvent result Decoded dimmer event with event_type and steps
function event.decode_dimmer(value)
  local event_type = bit16_band(value, 0xFF)
  local steps = bit16_rshift(value, 8)

  return {
    raw_value = value,
    event_type = event_type,
    event_name = event.DIMMER_NAMES[event_type] or "unknown",
    steps = steps,
  }
end

--- Decode an event based on the event type.
--- @param event_type string The event type ("button" or "dimmer")
--- @param value integer The raw event value
--- @return BTHomeButtonEvent|BTHomeDimmerEvent result Decoded event
function event.decode(event_type, value)
  if event_type == "button" then
    return event.decode_button(value)
  elseif event_type == "dimmer" then
    return event.decode_dimmer(value)
  else
    -- Return button-like structure for unknown event types
    return {
      raw_value = value,
      event_type = value,
      event_name = "unknown",
      device_number = nil,
    }
  end
end

return event
