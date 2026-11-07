--- Main chunk of build/bthome-tests.lua, the with-tests build: the library, as `require("bthome")`
--- returns it, plus `selftest()` over every suite in test/.

--- @class bthome.with_tests: bthome
local bthome = require("bthome")
local test_const = require("test_const")
local test_event = require("test_event")
local test_crypto_aes_ccm = require("test_crypto_aes_ccm")
local test_parser = require("test_parser")

--- Run self-tests for all modules.
--- @return boolean success True if all tests passed
function bthome.selftest()
  print("BTHome Library Self-Test")
  print("========================")
  print("")

  local all_passed = true

  -- Test const module
  local const_ok = test_const()
  if not const_ok then
    all_passed = false
  end

  -- Test event module
  local event_ok = test_event()
  if not event_ok then
    all_passed = false
  end

  -- Test crypto module
  local crypto_ok = test_crypto_aes_ccm()
  if not crypto_ok then
    all_passed = false
  end

  -- Test parser module
  local parser_ok = test_parser()
  if not parser_ok then
    all_passed = false
  end

  print("")
  if all_passed then
    print("All BTHome tests passed!")
  else
    print("Some BTHome tests failed!")
  end

  return all_passed
end

return bthome
