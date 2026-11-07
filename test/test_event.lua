--- Tests for bthome.event: `make test` runs them, and so does the with-tests build's selftest().

local event = require("bthome.event")

--- Run self-tests.
--- @return boolean success True if all tests passed
local function selftest()
  print("Testing event module...")
  local passed = 0
  local total = 0

  -- ===========================================================================
  -- Button Event Decoding Tests
  -- ===========================================================================

  local button_tests = {
    { value = 0x00, expected_name = "none" },
    { value = 0x01, expected_name = "press" },
    { value = 0x02, expected_name = "double_press" },
    { value = 0x03, expected_name = "triple_press" },
    { value = 0x04, expected_name = "long_press" },
    { value = 0x80, expected_name = "hold_press" },
  }

  for _, test in ipairs(button_tests) do
    total = total + 1
    local result = event.decode_button(test.value)
    if result.event_name == test.expected_name then
      print(string.format("  PASS: Button 0x%02X = %s", test.value, test.expected_name))
      passed = passed + 1
    else
      print(string.format("  FAIL: Button 0x%02X", test.value))
      print(string.format("    Expected: %s", test.expected_name))
      print(string.format("    Got: %s", result.event_name))
    end
  end

  -- ===========================================================================
  -- Dimmer Event Decoding Tests
  -- ===========================================================================

  -- Dimmer format: 2 bytes [event_type][steps] read as little-endian uint16
  -- So value = event_type + (steps * 256)
  local dimmer_tests = {
    { value = 0x0000, expected_name = "none", expected_steps = 0 }, -- event_type=0, steps=0
    { value = 0x0301, expected_name = "rotate_left", expected_steps = 3 }, -- event_type=1, steps=3
    { value = 0x0501, expected_name = "rotate_left", expected_steps = 5 }, -- event_type=1, steps=5
    { value = 0x0102, expected_name = "rotate_right", expected_steps = 1 }, -- event_type=2, steps=1
    { value = 0x0A02, expected_name = "rotate_right", expected_steps = 10 }, -- event_type=2, steps=10
  }

  for _, test in ipairs(dimmer_tests) do
    total = total + 1
    local result = event.decode_dimmer(test.value)
    if result.event_name == test.expected_name and result.steps == test.expected_steps then
      print(string.format("  PASS: Dimmer 0x%04X = %s, %d steps", test.value, test.expected_name, test.expected_steps))
      passed = passed + 1
    else
      print(string.format("  FAIL: Dimmer 0x%04X", test.value))
      print(string.format("    Expected: %s, %d steps", test.expected_name, test.expected_steps))
      print(string.format("    Got: %s, %d steps", result.event_name, result.steps))
    end
  end

  print(string.format("\nevent module: %d/%d tests passed\n", passed, total))
  return passed == total
end

return selftest
