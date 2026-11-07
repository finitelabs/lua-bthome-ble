local const = require("bthome.const")

--- Run self-tests.
--- @return boolean success True if all tests passed
local function selftest()
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

return selftest
