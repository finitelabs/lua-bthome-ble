--- Tests for bthome.parser: `make test` runs them, and so does the with-tests build's selftest().

local parser = require("bthome.parser")

--- Run self-tests.
--- Test vectors derived from bthome-ble Python reference implementation.
--- @see https://github.com/Bluetooth-Devices/bthome-ble
--- @return boolean success True if all tests passed
local function selftest()
  print("Testing parser module...")
  local passed = 0
  local total = 0

  -- Helper to convert hex string to binary
  local function hex_to_bin(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
      local byte = tonumber(hex:sub(i, i + 1), 16) or 0
      bytes[#bytes + 1] = string.char(byte)
    end
    return table.concat(bytes)
  end

  -- Helper to check a single reading value
  local function check_reading(result, name, expected, tolerance)
    tolerance = tolerance or 0.01
    for _, reading in ipairs(result.readings) do
      if reading.name == name then
        if type(expected) == "number" then
          return math.abs(reading.value - expected) < tolerance
        else
          return reading.value == expected
        end
      end
    end
    return false
  end

  -- Helper to run a simple V2 parse test (most common case)
  local function run_test(test_name, hex_data, checks)
    total = total + 1
    local data = hex_to_bin(hex_data)
    local result, err = parser.parse(parser.UUID_V2, data)
    if result then
      local all_ok = true
      for name, expected in pairs(checks) do
        if not check_reading(result, name, expected) then
          all_ok = false
          print(string.format("  FAIL: %s", test_name))
          print(string.format("    Expected %s: %s", name, tostring(expected)))
          print("    Got readings:")
          for _, r in ipairs(result.readings) do
            print(string.format("      %s = %s", r.name, tostring(r.value)))
          end
          break
        end
      end
      if all_ok then
        print(string.format("  PASS: %s", test_name))
        passed = passed + 1
        return true
      end
    else
      print(string.format("  FAIL: %s", test_name))
      print(string.format("    Error: %s", err or "unknown"))
    end
    return false
  end

  -- ===========================================================================
  -- V2 Basic Sensor Tests (from bthome-ble test_parser_v2.py)
  -- ===========================================================================

  -- Temperature + Humidity (official test vector)
  -- 40 02 ca 09 03 bf 13 -> temp=25.06, humidity=50.55
  run_test("V2 temperature+humidity", "4002ca0903bf13", { temperature = 25.06, humidity = 50.55 })

  -- Pressure: 40 04 13 8a 01 -> 1008.83 mbar
  run_test("V2 pressure", "4004138a01", { pressure = 1008.83 })

  -- Illuminance: 40 05 13 8a 14 -> 13460.67 lux
  run_test("V2 illuminance", "4005138a14", { illuminance = 13460.67 })

  -- Mass (kg): 40 06 5e 1f -> 80.30 kg
  run_test("V2 mass_kg", "40065e1f", { mass_kg = 80.30 })

  -- Mass (lb): 40 07 3e 1d -> 74.86 lb
  run_test("V2 mass_lb", "40073e1d", { mass_lb = 74.86 })

  -- Dew point: 40 08 ca 06 -> 17.38 °C
  run_test("V2 dewpoint", "4008ca06", { dewpoint = 17.38 })

  -- Count: 40 09 60 -> 96
  run_test("V2 count", "400960", { count = 96 })

  -- Energy: 40 0a 13 8a 14 -> 1346.067 kWh
  run_test("V2 energy", "400a138a14", { energy = 1346.067 })

  -- Power: 40 0b 02 1b 00 -> 69.14 W
  run_test("V2 power", "400b021b00", { power = 69.14 })

  -- Voltage: 40 0c 02 0c -> 3.074 V
  run_test("V2 voltage", "400c020c", { voltage = 3.074 })

  -- PM2.5 + PM10: 40 0d 12 0c 0e 02 1c -> PM2.5=3090, PM10=7170
  run_test("V2 PM sensors", "400d120c0e021c", { pm2_5 = 3090, pm10 = 7170 })

  -- CO2: 40 12 e2 04 -> 1250 ppm
  run_test("V2 CO2", "4012e204", { co2 = 1250 })

  -- TVOC: 40 13 33 01 -> 307 µg/m³
  run_test("V2 TVOC", "40133301", { tvoc = 307 })

  -- Moisture: 40 14 02 0c -> 30.74 %
  run_test("V2 moisture", "4014020c", { moisture = 30.74 })

  -- Battery: 40 01 64 -> 100%
  run_test("V2 battery", "400164", { battery = 100 })

  -- ===========================================================================
  -- V2 Boolean Sensor Tests
  -- ===========================================================================

  -- Generic boolean: 40 0f 01 -> true
  run_test("V2 generic_boolean", "400f01", { generic_boolean = 1 })

  -- Power on: 40 10 01 -> true
  run_test("V2 power_on", "401001", { power_on = 1 })

  -- Opening: 40 11 00 -> false (closed)
  run_test("V2 opening closed", "401100", { opening = 0 })

  -- Opening: 40 11 01 -> true (open)
  run_test("V2 opening open", "401101", { opening = 1 })

  -- Motion: 40 21 01 -> detected (0x21 = motion)
  run_test("V2 motion", "402101", { motion = 1 })

  -- Smoke: 40 29 01 -> detected (0x29 = smoke_detected)
  run_test("V2 smoke_detected", "402901", { smoke_detected = 1 })

  -- Tamper: 40 2B 01 -> detected (0x2B = tamper)
  run_test("V2 tamper", "402B01", { tamper = 1 })

  -- ===========================================================================
  -- V2 Extended Numeric Sensors
  -- ===========================================================================

  -- Current: 40 43 4e 34 -> 13.39 A (0x344E = 13390, * 0.001)
  run_test("V2 current", "40434e34", { current = 13.390 })

  -- Speed: 40 44 4e 34 -> 133.90 m/s (0x344E = 13390, * 0.01)
  run_test("V2 speed", "40444e34", { speed = 133.90 })

  -- Temperature 0x45 (sint16, factor 0.1): 40 45 11 01 -> 27.3 °C (0x0111 = 273, * 0.1)
  run_test("V2 temperature 0x45", "40451101", { temperature = 27.3 })

  -- Temperature 0x57 (sint8, factor 1): 40 57 11 -> 17 °C
  run_test("V2 temperature 0x57", "405711", { temperature = 17 })

  -- UV Index: 40 46 32 -> 5.0 (0x32 = 50, * 0.1)
  run_test("V2 UV index", "404632", { uv_index = 5.0 })

  -- Volume (0x47): 40 47 87 56 -> 2215.1 L (0x5687 = 22151, * 0.1)
  run_test("V2 volume 0x47", "40478756", { volume = 2215.1 })

  -- Volume mL: 40 48 dc 87 -> 34780 mL
  run_test("V2 volume_ml", "4048dc87", { volume_ml = 34780 })

  -- Distance mm: 40 40 0c 00 -> 12 mm
  run_test("V2 distance_mm", "40400c00", { distance_mm = 12 })

  -- Distance m: 40 41 4e 00 -> 7.8 m
  run_test("V2 distance_m", "40414e00", { distance_m = 7.8 })

  -- Duration: 40 42 4e 34 00 -> 13.390 s
  run_test("V2 duration", "40424e3400", { duration = 13.390 })

  -- Rotation: 40 3f 02 0c -> 307.4 °
  run_test("V2 rotation", "403f020c", { rotation = 307.4 })

  -- Humidity 0x2E (uint8, factor 1): 40 2E 34 -> 52%
  run_test("V2 humidity 0x2E", "402E34", { humidity = 52 })

  -- Moisture 0x2F (uint8, factor 1): 40 2F 2D -> 45%
  run_test("V2 moisture 0x2F", "402F2D", { moisture = 45 })

  -- Voltage 0x4A (uint16, factor 0.1): 40 4A 02 0C -> 307.4V (0x0C02 = 3074, * 0.1)
  -- Reference: test_parser_v2.py uses this exact vector
  run_test("V2 voltage 0x4A", "404A020C", { voltage = 307.4 })

  -- Window 0x2D: 40 2D 01 -> 1 (open)
  -- Reference: test_parser_v2.py uses this exact vector
  run_test("V2 window", "402D01", { window = 1 })

  -- ===========================================================================
  -- V2 Firmware Version Tests
  -- ===========================================================================

  -- Firmware version uint32 (0xF1): 40 F1 04 03 02 01 -> "1.2.3.4"
  -- Bytes are in little-endian order, parsed as version string
  total = total + 1
  local fw32_data = hex_to_bin("40F104030201")
  local fw32_result = parser.parse(parser.UUID_V2, fw32_data)
  if fw32_result then
    local found = false
    for _, r in ipairs(fw32_result.readings) do
      if r.name == "firmware_version" and r.value == "1.2.3.4" then
        found = true
      end
    end
    if found then
      print("  PASS: V2 firmware_version uint32")
      passed = passed + 1
    else
      print("  FAIL: V2 firmware_version uint32")
      print("    Expected: firmware_version = '1.2.3.4'")
      print("    Got readings:")
      for _, r in ipairs(fw32_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V2 firmware_version uint32")
    print("    Error: parsing failed")
  end

  -- Firmware version uint24 (0xF2): 40 F2 03 02 01 -> "1.2.3"
  total = total + 1
  local fw24_data = hex_to_bin("40F2030201")
  local fw24_result = parser.parse(parser.UUID_V2, fw24_data)
  if fw24_result then
    local found = false
    for _, r in ipairs(fw24_result.readings) do
      if r.name == "firmware_version" and r.value == "1.2.3" then
        found = true
      end
    end
    if found then
      print("  PASS: V2 firmware_version uint24")
      passed = passed + 1
    else
      print("  FAIL: V2 firmware_version uint24")
      print("    Expected: firmware_version = '1.2.3'")
      print("    Got readings:")
      for _, r in ipairs(fw24_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V2 firmware_version uint24")
    print("    Error: parsing failed")
  end

  -- Firmware version with realistic values: 40 F1 01 00 05 02 -> "2.5.0.1"
  total = total + 1
  local fw_real_data = hex_to_bin("40F101000502")
  local fw_real_result = parser.parse(parser.UUID_V2, fw_real_data)
  if fw_real_result then
    local found = false
    for _, r in ipairs(fw_real_result.readings) do
      if r.name == "firmware_version" and r.value == "2.5.0.1" then
        found = true
      end
    end
    if found then
      print("  PASS: V2 firmware_version realistic")
      passed = passed + 1
    else
      print("  FAIL: V2 firmware_version realistic")
      print("    Expected: firmware_version = '2.5.0.1'")
      print("    Got readings:")
      for _, r in ipairs(fw_real_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V2 firmware_version realistic")
    print("    Error: parsing failed")
  end

  -- ===========================================================================
  -- V2 Event Tests
  -- ===========================================================================

  -- Button press (short)
  total = total + 1
  local btn_data = hex_to_bin("443a01")
  local btn_result = parser.parse(parser.UUID_V2, btn_data)
  if btn_result and btn_result.device_info.trigger_based then
    local found = false
    for _, r in ipairs(btn_result.readings) do
      if r.name == "button" and r.event and r.event.event_name == "press" then
        found = true
      end
    end
    if found then
      print("  PASS: V2 button press event")
      passed = passed + 1
    else
      print("  FAIL: V2 button press event")
      print("    Expected: button with event_name = 'press'")
    end
  else
    print("  FAIL: V2 button press event")
    print("    Error: parsing failed or trigger_based not set")
  end

  -- Button long press
  total = total + 1
  local btn_long_data = hex_to_bin("443a04")
  local btn_long_result = parser.parse(parser.UUID_V2, btn_long_data)
  if btn_long_result then
    local found = false
    for _, r in ipairs(btn_long_result.readings) do
      if r.name == "button" and r.event and r.event.event_name == "long_press" then
        found = true
      end
    end
    if found then
      print("  PASS: V2 button long_press event")
      passed = passed + 1
    else
      print("  FAIL: V2 button long_press event")
      print("    Expected: button with event_name = 'long_press'")
    end
  else
    print("  FAIL: V2 button long_press event")
    print("    Error: parsing failed")
  end

  -- Dimmer rotate left: 44 3C 01 03
  -- device_info=0x44 (trigger-based, V2), object_id=0x3C (dimmer)
  -- value bytes: 01 03 -> little-endian uint16 = 0x0301 -> event_type=1 (rotate_left), steps=3
  total = total + 1
  local dimmer_data = hex_to_bin("443c0103")
  local dimmer_result = parser.parse(parser.UUID_V2, dimmer_data)
  if dimmer_result then
    local found = false
    for _, r in ipairs(dimmer_result.readings) do
      if r.name == "dimmer" and r.event and r.event.event_name == "rotate_left" and r.event.steps == 3 then
        found = true
      end
    end
    if found then
      print("  PASS: V2 dimmer rotate_left event")
      passed = passed + 1
    else
      print("  FAIL: V2 dimmer rotate_left event")
      print("    Expected: dimmer with event_name = 'rotate_left', steps = 3")
    end
  else
    print("  FAIL: V2 dimmer rotate_left event")
    print("    Error: parsing failed")
  end

  -- Dimmer rotate right: 44 3C 02 05
  -- device_info=0x44, object_id=0x3C
  -- value bytes: 02 05 -> little-endian uint16 = 0x0502 -> event_type=2 (rotate_right), steps=5
  total = total + 1
  local dimmer_right_data = hex_to_bin("443c0205")
  local dimmer_right_result = parser.parse(parser.UUID_V2, dimmer_right_data)
  if dimmer_right_result then
    local found = false
    for _, r in ipairs(dimmer_right_result.readings) do
      if r.name == "dimmer" and r.event and r.event.event_name == "rotate_right" and r.event.steps == 5 then
        found = true
      end
    end
    if found then
      print("  PASS: V2 dimmer rotate_right event")
      passed = passed + 1
    else
      print("  FAIL: V2 dimmer rotate_right event")
      print("    Expected: dimmer with event_name = 'rotate_right', steps = 5")
    end
  else
    print("  FAIL: V2 dimmer rotate_right event")
    print("    Error: parsing failed")
  end

  -- ===========================================================================
  -- Packet ID Test
  -- ===========================================================================

  total = total + 1
  local pkt_data = hex_to_bin("400005020000")
  local pkt_result = parser.parse(parser.UUID_V2, pkt_data)
  if pkt_result and pkt_result.packet_id == 5 then
    print("  PASS: V2 packet ID parsing")
    passed = passed + 1
  else
    print("  FAIL: V2 packet ID parsing")
    print(string.format("    Expected: packet_id = 5"))
    print(string.format("    Got: packet_id = %s", pkt_result and tostring(pkt_result.packet_id) or "nil"))
  end

  -- ===========================================================================
  -- Multiple Readings Test
  -- ===========================================================================

  total = total + 1
  local multi_data = hex_to_bin("40015f02e8030310" .. "27")
  local multi_result = parser.parse(parser.UUID_V2, multi_data)
  if multi_result and #multi_result.readings == 3 then
    print("  PASS: Multiple readings in one advertisement")
    passed = passed + 1
  else
    print("  FAIL: Multiple readings parsing")
    print(string.format("    Expected: 3 readings"))
    print(string.format("    Got: %d readings", multi_result and #multi_result.readings or 0))
  end

  -- ===========================================================================
  -- Error Handling Tests
  -- ===========================================================================

  -- Empty data
  total = total + 1
  local _, err_empty = parser.parse(parser.UUID_V2, "")
  if err_empty then
    print("  PASS: Empty data rejected")
    passed = passed + 1
  else
    print("  FAIL: Empty data should be rejected")
    print("    Expected: error message")
    print("    Got: no error")
  end

  -- Invalid version (0)
  total = total + 1
  local _, err_ver = parser.parse(parser.UUID_V2, hex_to_bin("00"))
  if err_ver and err_ver:find("version") then
    print("  PASS: Invalid version rejected")
    passed = passed + 1
  else
    print("  FAIL: Invalid version should be rejected")
    print("    Expected: error containing 'version'")
    print(string.format("    Got: %s", err_ver or "no error"))
  end

  -- Encrypted without bind_key
  total = total + 1
  local _, err_key = parser.parse(parser.UUID_V2, hex_to_bin("41"))
  if err_key and err_key:find("bind_key") then
    print("  PASS: Encrypted without bind_key rejected")
    passed = passed + 1
  else
    print("  FAIL: Encrypted without bind_key should require key")
    print("    Expected: error containing 'bind_key'")
    print(string.format("    Got: %s", err_key or "no error"))
  end

  -- Encrypted without MAC
  total = total + 1
  local bind_key = hex_to_bin("231d39c1d7cc1ab1aee224cd096db932")
  local _, err_mac = parser.parse(parser.UUID_V2, hex_to_bin("41aabbccdd"), bind_key)
  if err_mac and err_mac:find("MAC") then
    print("  PASS: Encrypted without MAC rejected")
    passed = passed + 1
  else
    print("  FAIL: Encrypted without MAC should require address")
    print("    Expected: error containing 'MAC'")
    print(string.format("    Got: %s", err_mac or "no error"))
  end

  -- Truncated data (object ID without value)
  total = total + 1
  local _, err_trunc = parser.parse(parser.UUID_V2, hex_to_bin("4002"))
  if err_trunc and err_trunc:find("truncated") then
    print("  PASS: Truncated data rejected")
    passed = passed + 1
  else
    print("  FAIL: Truncated data should be rejected")
    print("    Expected: error containing 'truncated'")
    print(string.format("    Got: %s", err_trunc or "no error"))
  end

  -- ===========================================================================
  -- Negative Temperature Test (Signed Value)
  -- ===========================================================================

  -- Temperature: -10.0°C = -1000 = 0xFC18 in little-endian = 18 FC
  total = total + 1
  local neg_temp_data = hex_to_bin("400218fc")
  local neg_temp_result = parser.parse(parser.UUID_V2, neg_temp_data)
  if neg_temp_result then
    local found = false
    for _, r in ipairs(neg_temp_result.readings) do
      if r.name == "temperature" and math.abs(r.value - -10.0) < 0.01 then
        found = true
      end
    end
    if found then
      print("  PASS: V2 negative temperature")
      passed = passed + 1
    else
      print("  FAIL: V2 negative temperature")
      print("    Expected: temperature = -10.0")
      print("    Got readings:")
      for _, r in ipairs(neg_temp_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V2 negative temperature")
    print("    Error: parsing failed")
  end

  -- ===========================================================================
  -- V2 Encrypted Advertisement Test
  -- ===========================================================================

  -- Official BTHome test vector from https://bthome.io/encryption/
  -- Decrypted payload: 02ca09 03bf13 = temp 25.06°C, humidity 50.55%
  -- MAC: 5448E68F80A5
  -- Bind key: 231d39c1d7cc1ab1aee224cd096db932
  -- Service data: 41e445f3c9962b332211006c7c4519
  --   41 = device_info (encrypted=true, v2)
  --   e445f3c9962b = encrypted data (6 bytes)
  --   33221100 = counter (1122867 in LE)
  --   6c7c4519 = MIC (4 bytes)
  total = total + 1
  local enc_packet = hex_to_bin("41e445f3c9962b332211006c7c4519")
  local enc_bind_key = hex_to_bin("231d39c1d7cc1ab1aee224cd096db932")
  local enc_mac = hex_to_bin("5448E68F80A5")
  local enc_result, enc_err = parser.parse(parser.UUID_V2, enc_packet, enc_bind_key, enc_mac)
  if enc_result and enc_result.readings and #enc_result.readings > 0 then
    -- Check for expected values
    local found_temp = false
    local found_hum = false
    for _, r in ipairs(enc_result.readings) do
      if r.name == "temperature" and math.abs(r.value - 25.06) < 0.01 then
        found_temp = true
      end
      if r.name == "humidity" and math.abs(r.value - 50.55) < 0.01 then
        found_hum = true
      end
    end
    if found_temp and found_hum then
      print("  PASS: V2 encrypted advertisement decryption")
      passed = passed + 1
    else
      print("  FAIL: V2 encrypted advertisement decryption")
      print("    Expected: temperature = 25.06, humidity = 50.55")
      print("    Got readings:")
      for _, r in ipairs(enc_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V2 encrypted advertisement decryption")
    print(string.format("    Error: %s", enc_err or "unknown"))
  end

  -- ===========================================================================
  -- V1 Encrypted Advertisement Test
  -- ===========================================================================

  -- Official BTHome V1 test vector from bthome-ble test_parser_v1.py
  -- MAC: 54:48:E6:8F:80:A5
  -- Bind key: 231d39c1d7cc1ab1aee224cd096db932
  -- Service data (UUID 0x181E): fba435e4d3c312fb0011223357d90a99
  -- Decrypted payload uses V1 format: temp 25.06°C, humidity 50.55%
  total = total + 1
  local v1_enc_packet = hex_to_bin("fba435e4d3c312fb0011223357d90a99")
  local v1_enc_bind_key = hex_to_bin("231d39c1d7cc1ab1aee224cd096db932")
  local v1_enc_mac = hex_to_bin("5448E68F80A5")
  local v1_enc_result, v1_enc_err = parser.parse(parser.UUID_V1_ENCRYPTED, v1_enc_packet, v1_enc_bind_key, v1_enc_mac)
  if v1_enc_result and v1_enc_result.readings and #v1_enc_result.readings > 0 then
    local found_temp = false
    local found_hum = false
    for _, r in ipairs(v1_enc_result.readings) do
      if r.name == "temperature" and math.abs(r.value - 25.06) < 0.01 then
        found_temp = true
      end
      if r.name == "humidity" and math.abs(r.value - 50.55) < 0.01 then
        found_hum = true
      end
    end
    if found_temp and found_hum and v1_enc_result.device_info.version == 1 and v1_enc_result.device_info.encrypted then
      print("  PASS: V1 encrypted advertisement decryption")
      passed = passed + 1
    else
      print("  FAIL: V1 encrypted advertisement decryption")
      print("    Expected: temperature = 25.06, humidity = 50.55, version = 1, encrypted = true")
      print(
        string.format(
          "    Got: version = %d, encrypted = %s",
          v1_enc_result.device_info.version,
          tostring(v1_enc_result.device_info.encrypted)
        )
      )
      print("    Got readings:")
      for _, r in ipairs(v1_enc_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V1 encrypted advertisement decryption")
    print(string.format("    Error: %s", v1_enc_err or "unknown"))
  end

  -- ===========================================================================
  -- V1 Unencrypted Advertisement Tests
  -- ===========================================================================

  -- Official BTHome V1 test vector from bthome-ble test_parser_v1.py
  -- test_bthome_temperature_humidity: temp 25.06°C, humidity 50.55%
  -- Data: 23 02 ca 09 03 03 bf 13
  --   23 = control (len=3, fmt=1), 02 = temperature, ca09 = 2506 -> 25.06
  --   03 = control (len=3, fmt=0), 03 = humidity, bf13 = 5055 -> 50.55
  total = total + 1
  local v1_temp_hum_data = hex_to_bin("2302ca090303bf13")
  local v1_temp_hum_result, v1_temp_hum_err = parser.parse(parser.UUID_V1_UNENCRYPTED, v1_temp_hum_data)
  if v1_temp_hum_result and v1_temp_hum_result.readings then
    local found_temp = false
    local found_hum = false
    for _, r in ipairs(v1_temp_hum_result.readings) do
      if r.name == "temperature" and math.abs(r.value - 25.06) < 0.01 then
        found_temp = true
      end
      if r.name == "humidity" and math.abs(r.value - 50.55) < 0.01 then
        found_hum = true
      end
    end
    if
      found_temp
      and found_hum
      and v1_temp_hum_result.device_info.version == 1
      and not v1_temp_hum_result.device_info.encrypted
    then
      print("  PASS: V1 unencrypted temperature+humidity")
      passed = passed + 1
    else
      print("  FAIL: V1 unencrypted temperature+humidity")
      print("    Expected: temperature = 25.06, humidity = 50.55, version = 1, encrypted = false")
      print("    Got readings:")
      for _, r in ipairs(v1_temp_hum_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V1 unencrypted temperature+humidity")
    print(string.format("    Error: %s", v1_temp_hum_err or "unknown"))
  end

  -- Official BTHome V1 test vector from bthome-ble test_parser_v1.py
  -- test_bthome_pressure: pressure 1008.83 mbar
  -- Data: 04 04 13 8a 01
  --   04 = control (len=4, fmt=0), 04 = pressure, 138a01 = 100883 -> 1008.83
  total = total + 1
  local v1_pressure_data = hex_to_bin("0404138a01")
  local v1_pressure_result, v1_pressure_err = parser.parse(parser.UUID_V1_UNENCRYPTED, v1_pressure_data)
  if v1_pressure_result and v1_pressure_result.readings then
    local found_pressure = false
    for _, r in ipairs(v1_pressure_result.readings) do
      if r.name == "pressure" and math.abs(r.value - 1008.83) < 0.01 then
        found_pressure = true
      end
    end
    if found_pressure then
      print("  PASS: V1 unencrypted pressure")
      passed = passed + 1
    else
      print("  FAIL: V1 unencrypted pressure")
      print("    Expected: pressure = 1008.83")
      print("    Got readings:")
      for _, r in ipairs(v1_pressure_result.readings) do
        print(string.format("      %s = %s", r.name, tostring(r.value)))
      end
    end
  else
    print("  FAIL: V1 unencrypted pressure")
    print(string.format("    Error: %s", v1_pressure_err or "unknown"))
  end

  -- ===========================================================================
  -- Duplicate Object ID Tests (instance field)
  -- ===========================================================================

  -- Two power readings (0x10) and two opening readings (0x11)
  -- This simulates pvvx firmware on LYWSD03MMC that sends multiple comfort zone triggers
  -- Format: 40 10 01 10 00 11 01 11 00
  --   40 = V2, not encrypted
  --   10 01 = power_on (object 0x10) = 1 (on)
  --   10 00 = power_on (object 0x10) = 0 (off)
  --   11 01 = opening (object 0x11) = 1 (open)
  --   11 00 = opening (object 0x11) = 0 (closed)
  total = total + 1
  local dup_data = hex_to_bin("401001100011011100")
  local dup_result = parser.parse(parser.UUID_V2, dup_data)
  if dup_result and #dup_result.readings == 4 then
    local r = dup_result.readings
    -- Check names are unchanged and instances are assigned correctly
    local all_match = r[1].name == "power_on"
      and r[1].instance == 1
      and r[2].name == "power_on"
      and r[2].instance == 2
      and r[3].name == "opening"
      and r[3].instance == 1
      and r[4].name == "opening"
      and r[4].instance == 2
    if all_match then
      print("  PASS: Duplicate object IDs get instance numbers")
      passed = passed + 1
    else
      print("  FAIL: Duplicate object IDs get instance numbers")
      print("    Expected: power_on(1), power_on(2), opening(1), opening(2)")
      print("    Got readings:")
      for i, reading in ipairs(r) do
        print(string.format("      [%d] name=%s, instance=%s", i, reading.name, tostring(reading.instance)))
      end
    end
  else
    print("  FAIL: Duplicate object IDs get instance numbers")
    print("    Expected: 4 readings")
    print(string.format("    Got: %d readings", dup_result and #dup_result.readings or 0))
  end

  -- Three identical temperature readings to test instance=1, 2, 3
  -- Format: 40 02 ca09 02 bf13 02 1027
  --   40 = V2, not encrypted
  --   02 ca09 = temperature = 25.06°C
  --   02 bf13 = temperature = 50.55°C (using humidity bytes as temp for variety)
  --   02 1027 = temperature = 100.00°C
  total = total + 1
  local triple_data = hex_to_bin("4002ca0902bf13021027")
  local triple_result = parser.parse(parser.UUID_V2, triple_data)
  if triple_result and #triple_result.readings == 3 then
    local r = triple_result.readings
    local all_match = r[1].name == "temperature"
      and r[1].instance == 1
      and r[2].name == "temperature"
      and r[2].instance == 2
      and r[3].name == "temperature"
      and r[3].instance == 3
    if all_match then
      print("  PASS: Triple duplicate gets instance=1, 2, 3")
      passed = passed + 1
    else
      print("  FAIL: Triple duplicate gets instance=1, 2, 3")
      print("    Expected: temperature(1), temperature(2), temperature(3)")
      print("    Got readings:")
      for i, reading in ipairs(r) do
        print(string.format("      [%d] name=%s, instance=%s", i, reading.name, tostring(reading.instance)))
      end
    end
  else
    print("  FAIL: Triple duplicate gets instance=1, 2, 3")
    print("    Expected: 3 readings")
    print(string.format("    Got: %d readings", triple_result and #triple_result.readings or 0))
  end

  print(string.format("\nparser module: %d/%d tests passed\n", passed, total))
  return passed == total
end

return selftest
