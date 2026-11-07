local aes_ccm = require("bthome.crypto.aes_ccm")
local string_byte = string.byte
local string_char = string.char
local string_sub = string.sub
local table_concat = table.concat
local key_expansion = aes_ccm._internal.key_expansion
local aes_encrypt_block = aes_ccm._internal.aes_encrypt_block

local string_format = string.format

--- Helper to convert hex string to binary
--- @param hex string Hex string
--- @return string binary Binary string
local function hex_to_bin(hex)
  local bytes = {}
  for i = 1, #hex, 2 do
    bytes[#bytes + 1] = string_char(tonumber(string_sub(hex, i, i + 1), 16) or 0)
  end
  return table_concat(bytes)
end

--- Helper to convert binary to hex string
--- @param bin string Binary string
--- @return string hex Hex string
local function bin_to_hex(bin)
  local hex = {}
  for i = 1, #bin do
    hex[#hex + 1] = string_format("%02x", string_byte(bin, i))
  end
  return table_concat(hex)
end

--- Run self-tests using NIST and RFC test vectors.
--- @return boolean success True if all tests passed
local function selftest()
  print("Testing AES-CCM module...")
  local passed = 0
  local total = 0

  -- ===========================================================================
  -- AES-128 Block Cipher Tests (NIST FIPS-197)
  -- ===========================================================================

  local aes_vectors = {
    {
      name = "NIST FIPS-197 Appendix B",
      key = "2b7e151628aed2a6abf7158809cf4f3c",
      plaintext = "3243f6a8885a308d313198a2e0370734",
      ciphertext = "3925841d02dc09fbdc118597196a0b32",
    },
    {
      name = "All zeros",
      key = "00000000000000000000000000000000",
      plaintext = "00000000000000000000000000000000",
      ciphertext = "66e94bd4ef8a2c3b884cfa59ca342b2e",
    },
    {
      name = "NIST SP 800-38A F.1.1",
      key = "2b7e151628aed2a6abf7158809cf4f3c",
      plaintext = "6bc1bee22e409f96e93d7e117393172a",
      ciphertext = "3ad77bb40d7a3660a89ecaf32466ef97",
    },
  }

  for _, tv in ipairs(aes_vectors) do
    total = total + 1
    local key = hex_to_bin(tv.key)
    local plaintext = hex_to_bin(tv.plaintext)
    local expected_ct = hex_to_bin(tv.ciphertext)

    local expanded_key, nr = key_expansion(key)
    local ciphertext = aes_encrypt_block(plaintext, expanded_key, nr)

    if ciphertext == expected_ct then
      print(string_format("  PASS: AES-128 %s", tv.name))
      passed = passed + 1
    else
      print(string_format("  FAIL: AES-128 %s", tv.name))
      print(string_format("    Expected: %s", tv.ciphertext))
      print(string_format("    Got: %s", bin_to_hex(ciphertext)))
    end
  end

  -- ===========================================================================
  -- AES-CCM Tests (RFC 3610)
  -- ===========================================================================

  local ccm_vectors = {
    {
      name = "RFC 3610 Vector #1",
      key = "c0c1c2c3c4c5c6c7c8c9cacbcccdcecf",
      nonce = "00000003020100a0a1a2a3a4a5", -- 13 bytes
      aad = "0001020304050607",
      plaintext = "08090a0b0c0d0e0f101112131415161718191a1b1c1d1e",
      tag_length = 8,
      ciphertext = "588c979a61c663d2f066d0c2c0f989806d5f6b61dac38417e8d12cfdf926e0",
    },
  }

  for _, tv in ipairs(ccm_vectors) do
    local key = hex_to_bin(tv.key)
    local nonce = hex_to_bin(tv.nonce)
    local aad = hex_to_bin(tv.aad)
    local plaintext = hex_to_bin(tv.plaintext)
    local expected_ct = hex_to_bin(tv.ciphertext)

    -- Test encryption
    total = total + 1
    local ciphertext, err = aes_ccm.encrypt(key, nonce, aad, plaintext, tv.tag_length)
    if ciphertext and ciphertext == expected_ct then
      print(string_format("  PASS: CCM %s (encrypt)", tv.name))
      passed = passed + 1
    else
      print(string_format("  FAIL: CCM %s (encrypt)", tv.name))
      if err then
        print(string_format("    Error: %s", err))
      else
        print(string_format("    Expected: %s", tv.ciphertext))
        print(string_format("    Got: %s", ciphertext and bin_to_hex(ciphertext) or "nil"))
      end
    end

    -- Test decryption
    total = total + 1
    local decrypted, derr = aes_ccm.decrypt(key, nonce, aad, expected_ct, tv.tag_length)
    if decrypted and decrypted == plaintext then
      print(string_format("  PASS: CCM %s (decrypt)", tv.name))
      passed = passed + 1
    else
      print(string_format("  FAIL: CCM %s (decrypt)", tv.name))
      print(string_format("    Error: %s", derr or "decrypted data mismatch"))
    end
  end

  -- ===========================================================================
  -- Functional Tests
  -- ===========================================================================

  -- Roundtrip encryption/decryption
  total = total + 1
  local rt_key = hex_to_bin("231d39c1d7cc1ab1aee224cd096db932")
  local rt_nonce = hex_to_bin("aabbccddeeff00112233") -- 10 bytes -> L=5
  local rt_plaintext = hex_to_bin("48656c6c6f20576f726c6421") -- "Hello World!"

  local rt_ct, rt_err = aes_ccm.encrypt(rt_key, rt_nonce, "", rt_plaintext, 4)
  if rt_ct then
    local rt_dec = aes_ccm.decrypt(rt_key, rt_nonce, "", rt_ct, 4)
    if rt_dec and rt_dec == rt_plaintext then
      print("  PASS: Roundtrip encryption/decryption")
      passed = passed + 1
    else
      print("  FAIL: Roundtrip decryption")
      print("    Decryption did not match original plaintext")
    end
  else
    print("  FAIL: Roundtrip encryption")
    print(string_format("    Error: %s", rt_err or "unknown"))
  end

  -- Authentication failure on tampered data
  total = total + 1
  if rt_ct then
    local tampered = string_sub(rt_ct, 1, 1) .. string_char((string_byte(rt_ct, 2) + 1) % 256) .. string_sub(rt_ct, 3)
    local _, tamper_err = aes_ccm.decrypt(rt_key, rt_nonce, "", tampered, 4)
    if tamper_err and tamper_err:find("authentication") then
      print("  PASS: Tampered data rejected")
      passed = passed + 1
    else
      print("  FAIL: Tampered data should be rejected")
      print(string_format("    Error: %s", tamper_err or "no error returned"))
    end
  else
    print("  SKIP: Tampered data test (roundtrip encryption failed)")
  end

  print(string_format("\nAES-CCM module: %d/%d tests passed\n", passed, total))
  return passed == total
end

return selftest
