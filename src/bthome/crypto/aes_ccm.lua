--- @module "bthome.crypto.aes_ccm"
--- AES-CCM Authenticated Encryption for BTHome BLE advertisements.
--- CCM combines CTR mode encryption with CBC-MAC authentication.
--- @see RFC 3610 for CCM specification
--- @see https://bthome.io/encryption for BTHome encryption details
---
--- @class bthome.crypto.aes_ccm
local aes_ccm = {}

local bit32 = require("bitn").bit32

-- Local references for performance
local bit32_raw_band = bit32.raw_band
local bit32_raw_bxor = bit32.raw_bxor
local bit32_raw_lshift = bit32.raw_lshift
local math_floor = math.floor
local math_min = math.min
local string_byte = string.byte
local string_char = string.char
local string_format = string.format
local string_rep = string.rep
local string_sub = string.sub
local table_concat = table.concat

-- ============================================================================
-- AES CORE IMPLEMENTATION
-- ============================================================================

-- AES S-box (substitution box)
--- @type integer[]
local SBOX = {
  0x63,
  0x7c,
  0x77,
  0x7b,
  0xf2,
  0x6b,
  0x6f,
  0xc5,
  0x30,
  0x01,
  0x67,
  0x2b,
  0xfe,
  0xd7,
  0xab,
  0x76,
  0xca,
  0x82,
  0xc9,
  0x7d,
  0xfa,
  0x59,
  0x47,
  0xf0,
  0xad,
  0xd4,
  0xa2,
  0xaf,
  0x9c,
  0xa4,
  0x72,
  0xc0,
  0xb7,
  0xfd,
  0x93,
  0x26,
  0x36,
  0x3f,
  0xf7,
  0xcc,
  0x34,
  0xa5,
  0xe5,
  0xf1,
  0x71,
  0xd8,
  0x31,
  0x15,
  0x04,
  0xc7,
  0x23,
  0xc3,
  0x18,
  0x96,
  0x05,
  0x9a,
  0x07,
  0x12,
  0x80,
  0xe2,
  0xeb,
  0x27,
  0xb2,
  0x75,
  0x09,
  0x83,
  0x2c,
  0x1a,
  0x1b,
  0x6e,
  0x5a,
  0xa0,
  0x52,
  0x3b,
  0xd6,
  0xb3,
  0x29,
  0xe3,
  0x2f,
  0x84,
  0x53,
  0xd1,
  0x00,
  0xed,
  0x20,
  0xfc,
  0xb1,
  0x5b,
  0x6a,
  0xcb,
  0xbe,
  0x39,
  0x4a,
  0x4c,
  0x58,
  0xcf,
  0xd0,
  0xef,
  0xaa,
  0xfb,
  0x43,
  0x4d,
  0x33,
  0x85,
  0x45,
  0xf9,
  0x02,
  0x7f,
  0x50,
  0x3c,
  0x9f,
  0xa8,
  0x51,
  0xa3,
  0x40,
  0x8f,
  0x92,
  0x9d,
  0x38,
  0xf5,
  0xbc,
  0xb6,
  0xda,
  0x21,
  0x10,
  0xff,
  0xf3,
  0xd2,
  0xcd,
  0x0c,
  0x13,
  0xec,
  0x5f,
  0x97,
  0x44,
  0x17,
  0xc4,
  0xa7,
  0x7e,
  0x3d,
  0x64,
  0x5d,
  0x19,
  0x73,
  0x60,
  0x81,
  0x4f,
  0xdc,
  0x22,
  0x2a,
  0x90,
  0x88,
  0x46,
  0xee,
  0xb8,
  0x14,
  0xde,
  0x5e,
  0x0b,
  0xdb,
  0xe0,
  0x32,
  0x3a,
  0x0a,
  0x49,
  0x06,
  0x24,
  0x5c,
  0xc2,
  0xd3,
  0xac,
  0x62,
  0x91,
  0x95,
  0xe4,
  0x79,
  0xe7,
  0xc8,
  0x37,
  0x6d,
  0x8d,
  0xd5,
  0x4e,
  0xa9,
  0x6c,
  0x56,
  0xf4,
  0xea,
  0x65,
  0x7a,
  0xae,
  0x08,
  0xba,
  0x78,
  0x25,
  0x2e,
  0x1c,
  0xa6,
  0xb4,
  0xc6,
  0xe8,
  0xdd,
  0x74,
  0x1f,
  0x4b,
  0xbd,
  0x8b,
  0x8a,
  0x70,
  0x3e,
  0xb5,
  0x66,
  0x48,
  0x03,
  0xf6,
  0x0e,
  0x61,
  0x35,
  0x57,
  0xb9,
  0x86,
  0xc1,
  0x1d,
  0x9e,
  0xe1,
  0xf8,
  0x98,
  0x11,
  0x69,
  0xd9,
  0x8e,
  0x94,
  0x9b,
  0x1e,
  0x87,
  0xe9,
  0xce,
  0x55,
  0x28,
  0xdf,
  0x8c,
  0xa1,
  0x89,
  0x0d,
  0xbf,
  0xe6,
  0x42,
  0x68,
  0x41,
  0x99,
  0x2d,
  0x0f,
  0xb0,
  0x54,
  0xbb,
  0x16,
}

-- Round constants (Rcon) for key expansion
--- @type integer[]
local RCON = {
  0x01,
  0x02,
  0x04,
  0x08,
  0x10,
  0x20,
  0x40,
  0x80,
  0x1b,
  0x36,
}

--- @alias AESWord [integer, integer, integer, integer]
--- @alias AESBlock [integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer]
--- @alias AESState [AESWord, AESWord, AESWord, AESWord]

--- Initialize a 4-element AES word with zeros
--- @return AESWord word Initialized word
local function create_aes_word()
  --- @type AESState
  return { 0, 0, 0, 0 }
end

--- Initialize a 4x4 AES state array with zeros
--- @return AESState state Initialized state
local function create_aes_state()
  --- @type AESState
  return {
    create_aes_word(),
    create_aes_word(),
    create_aes_word(),
    create_aes_word(),
  }
end

-- Pre-allocated state array for aes_encrypt_block()
local aes_state = create_aes_state()

-- Pre-allocated arrays for mix_columns()
local mix_a = create_aes_word()
local mix_b = create_aes_word()

--- XOR two 4-byte words
--- @param a AESWord 4-byte array
--- @param b AESWord 4-byte array
--- @return AESWord result 4-byte array
local function xor_words(a, b)
  return {
    bit32_raw_bxor(a[1], b[1]),
    bit32_raw_bxor(a[2], b[2]),
    bit32_raw_bxor(a[3], b[3]),
    bit32_raw_bxor(a[4], b[4]),
  }
end

--- Rotate word (circular left shift by 1 byte)
--- @param word AESWord 4-byte array
--- @return AESWord result Rotated 4-byte array
local function rot_word(word)
  return { word[2], word[3], word[4], word[1] }
end

--- Apply S-box substitution to a word
--- @param word AESWord 4-byte array
--- @return AESWord result Substituted 4-byte array
local function sub_word(word)
  local s_1 = assert(SBOX[word[1] + 1], "Invalid SBOX index " .. (word[1] + 1))
  local s_2 = assert(SBOX[word[2] + 1], "Invalid SBOX index " .. (word[2] + 1))
  local s_3 = assert(SBOX[word[3] + 1], "Invalid SBOX index " .. (word[3] + 1))
  local s_4 = assert(SBOX[word[4] + 1], "Invalid SBOX index " .. (word[4] + 1))
  return { s_1, s_2, s_3, s_4 }
end

--- AES key expansion
--- @param key string Encryption key (16, 24, or 32 bytes)
--- @return table expanded_key Array of round keys
--- @return integer nr Number of rounds
local function key_expansion(key)
  local key_len = #key
  local nr -- Number of rounds
  local nk -- Number of 32-bit words in key

  if key_len == 16 then
    nr = 10
    nk = 4
  elseif key_len == 24 then
    nr = 12
    nk = 6
  elseif key_len == 32 then
    nr = 14
    nk = 8
  else
    error("Invalid key length. Must be 16, 24, or 32 bytes")
  end

  -- Convert key to words
  --- @type AESState
  local w = {}
  for i = 1, nk do
    w[i] = {
      string_byte(key, (i - 1) * 4 + 1),
      string_byte(key, (i - 1) * 4 + 2),
      string_byte(key, (i - 1) * 4 + 3),
      string_byte(key, (i - 1) * 4 + 4),
    }
  end

  -- Expand key
  for i = nk + 1, 4 * (nr + 1) do
    local temp = w[i - 1]
    local idx = i - 1 -- 0-based index for modulo arithmetic
    if idx % nk == 0 then
      local t = assert(RCON[idx / nk], "Invalid RCON index " .. (idx / nk))
      temp = xor_words(sub_word(rot_word(temp)), { t, 0, 0, 0 })
    elseif nk > 6 and idx % nk == 4 then
      temp = sub_word(temp)
    end
    w[i] = xor_words(w[i - nk], temp)
  end

  return w, nr
end

--- MixColumns transformation
--- @param state AESState 4x4 state matrix
local function mix_columns(state)
  -- Reuse pre-allocated arrays
  local a = mix_a
  local b = mix_b
  for c = 1, 4 do
    for i = 1, 4 do
      a[i] = state[i][c]
      b[i] = bit32_raw_band(state[i][c], 0x80) ~= 0
          and bit32_raw_bxor(bit32_raw_band(bit32_raw_lshift(state[i][c], 1), 0xFF), 0x1B)
        or bit32_raw_band(bit32_raw_lshift(state[i][c], 1), 0xFF)
    end

    state[1][c] = bit32_raw_bxor(bit32_raw_bxor(bit32_raw_bxor(b[1], a[2]), bit32_raw_bxor(b[2], a[3])), a[4])
    state[2][c] = bit32_raw_bxor(bit32_raw_bxor(bit32_raw_bxor(a[1], b[2]), bit32_raw_bxor(a[3], b[3])), a[4])
    state[3][c] = bit32_raw_bxor(bit32_raw_bxor(bit32_raw_bxor(a[1], a[2]), bit32_raw_bxor(b[3], a[4])), b[4])
    state[4][c] = bit32_raw_bxor(bit32_raw_bxor(bit32_raw_bxor(a[1], b[1]), bit32_raw_bxor(a[2], a[3])), b[4])
  end
end

--- SubBytes transformation
--- @param state AESState 4x4 state matrix
local function sub_bytes(state)
  for i = 1, 4 do
    for j = 1, 4 do
      local s_index = state[i][j] + 1
      state[i][j] = assert(SBOX[s_index], "Invalid SBOX index " .. s_index)
    end
  end
end

--- ShiftRows transformation
--- @param state AESState 4x4 state matrix
local function shift_rows(state)
  -- Row 1: no shift
  -- Row 2: shift left by 1
  local temp = state[2][1]
  state[2][1] = state[2][2]
  state[2][2] = state[2][3]
  state[2][3] = state[2][4]
  state[2][4] = temp

  -- Row 3: shift left by 2
  temp = state[3][1]
  state[3][1] = state[3][3]
  state[3][3] = temp
  temp = state[3][2]
  state[3][2] = state[3][4]
  state[3][4] = temp

  -- Row 4: shift left by 3 (or right by 1)
  temp = state[4][4]
  state[4][4] = state[4][3]
  state[4][3] = state[4][2]
  state[4][2] = state[4][1]
  state[4][1] = temp
end

--- AddRoundKey transformation
--- @param state AESState 4x4 state matrix
--- @param round_key table Round key words
--- @param round integer Round number
local function add_round_key(state, round_key, round)
  for c = 1, 4 do
    local key_word = round_key[round * 4 + c]
    for r = 1, 4 do
      state[r][c] = bit32_raw_bxor(state[r][c], key_word[r])
    end
  end
end

--- AES block encryption
--- @param input string 16-byte plaintext block
--- @param expanded_key table Expanded key
--- @param nr integer Number of rounds
--- @return string ciphertext 16-byte encrypted block
local function aes_encrypt_block(input, expanded_key, nr)
  -- Reuse pre-allocated state array
  local state = aes_state
  for i = 1, 4 do
    for j = 1, 4 do
      state[i][j] = string_byte(input, (j - 1) * 4 + i)
    end
  end

  -- Initial round
  add_round_key(state, expanded_key, 0)

  -- Main rounds
  for round = 1, nr - 1 do
    sub_bytes(state)
    shift_rows(state)
    mix_columns(state)
    add_round_key(state, expanded_key, round)
  end

  -- Final round (no MixColumns)
  sub_bytes(state)
  shift_rows(state)
  add_round_key(state, expanded_key, nr)

  -- Convert state to output (optimized with table)
  local output_bytes = {}
  local idx = 1
  for j = 1, 4 do
    for i = 1, 4 do
      output_bytes[idx] = string_char(state[i][j])
      idx = idx + 1
    end
  end

  return table_concat(output_bytes)
end

-- ============================================================================
-- CCM MODE IMPLEMENTATION
-- ============================================================================

--- XOR two byte strings of equal length.
--- @param a string First string
--- @param b string Second string
--- @return string result XOR result
local function xor_strings(a, b)
  local result = {}
  for i = 1, #a do
    result[i] = string_char(bit32_raw_bxor(string_byte(a, i), string_byte(b, i)))
  end
  return table_concat(result)
end

--- Generate CTR counter blocks.
--- @param nonce string CCM nonce
--- @param counter integer Counter value (0 for CBC-MAC tag encryption, 1+ for CTR)
--- @param L integer Size of length field (typically 2 for BTHome)
--- @return string block 16-byte counter block
local function generate_counter_block(nonce, counter, L)
  -- Counter block format: [Flags][Nonce][Counter]
  -- Flags = L-1 (for CTR blocks)
  local flags = math_floor(L - 1)

  -- Build counter block
  local block = string_char(flags) .. nonce

  -- Append counter (big-endian, L bytes)
  local counter_bytes = {}
  local temp_counter = counter
  for i = L, 1, -1 do
    counter_bytes[i] = string_char(math_floor(temp_counter % 256))
    temp_counter = math_floor(temp_counter / 256)
  end

  return block .. table_concat(counter_bytes)
end

--- Compute CBC-MAC authentication tag.
--- @param expanded_key table Pre-expanded AES key
--- @param nr integer Number of rounds
--- @param nonce string CCM nonce
--- @param aad string Associated authenticated data (can be empty)
--- @param plaintext string Plaintext to authenticate
--- @param M integer Tag length in bytes (4 for BTHome)
--- @param L integer Length field size (typically 2)
--- @return string tag Authentication tag (M bytes)
local function cbc_mac(expanded_key, nr, nonce, aad, plaintext, M, L)
  -- Build B0 block
  -- Flags: [Reserved (1)][Adata (1)][M' (3)][L' (3)]
  -- M' = (M-2)/2, L' = L-1
  local adata_flag = #aad > 0 and 0x40 or 0x00
  local m_field = math_floor((M - 2) / 2) * 8 -- Shift left 3 bits
  local l_field = L - 1

  local flags = math_floor(adata_flag + m_field + l_field)

  -- B0 = Flags || Nonce || Q (message length, L bytes, big-endian)
  local b0 = string_char(flags) .. nonce

  -- Append message length (L bytes, big-endian)
  local msg_len = #plaintext
  local len_bytes = {}
  for i = L, 1, -1 do
    len_bytes[i] = string_char(math_floor(msg_len % 256))
    msg_len = math_floor(msg_len / 256)
  end
  b0 = b0 .. table_concat(len_bytes)

  -- Initialize CBC-MAC with B0
  local y = aes_encrypt_block(b0, expanded_key, nr)

  -- Process AAD if present
  if #aad > 0 then
    local aad_block
    if #aad < 0xFF00 then
      -- Short encoding: 2-byte length prefix
      aad_block = string_char(math_floor(#aad / 256), math_floor(#aad % 256)) .. aad
    else
      error("AAD too long")
    end

    -- Pad AAD to multiple of 16 bytes
    local pad_len = (16 - (#aad_block % 16)) % 16
    aad_block = aad_block .. string_rep("\0", pad_len)

    -- Process AAD blocks
    for i = 1, #aad_block, 16 do
      local block = string_sub(aad_block, i, i + 15)
      y = aes_encrypt_block(xor_strings(y, block), expanded_key, nr)
    end
  end

  -- Process plaintext blocks
  if #plaintext > 0 then
    -- Pad plaintext to multiple of 16 bytes
    local pad_len = (16 - (#plaintext % 16)) % 16
    local padded = plaintext .. string_rep("\0", pad_len)

    for i = 1, #padded, 16 do
      local block = string_sub(padded, i, i + 15)
      y = aes_encrypt_block(xor_strings(y, block), expanded_key, nr)
    end
  end

  -- Return first M bytes as tag
  return string_sub(y, 1, M)
end

-- ============================================================================
-- AEAD INTERFACE
-- ============================================================================

--- Encrypt data using AES-CCM.
--- @param key string 16-byte AES key
--- @param nonce string CCM nonce (typically 13 bytes for BTHome V2)
--- @param aad string Associated authenticated data (empty string for BTHome)
--- @param plaintext string Data to encrypt
--- @param tag_length integer Authentication tag length (4 bytes for BTHome)
--- @return string|nil ciphertext Encrypted data with appended tag
--- @return string|nil error Error message
function aes_ccm.encrypt(key, nonce, aad, plaintext, tag_length)
  if #key ~= 16 then
    return nil, "key must be 16 bytes"
  end

  local M = math_floor(tag_length or 4)
  local L = 16 - 1 - #nonce -- Compute L from nonce length

  if L < 2 or L > 8 then
    return nil, "invalid nonce length"
  end

  -- Expand key
  local expanded_key, nr = key_expansion(key)

  -- Compute CBC-MAC tag
  local tag = cbc_mac(expanded_key, nr, nonce, aad, plaintext, M, L)

  -- Generate S0 for tag encryption
  local s0 = aes_encrypt_block(generate_counter_block(nonce, 0, L), expanded_key, nr)

  -- Encrypt tag
  local encrypted_tag = xor_strings(tag, string_sub(s0, 1, M))

  -- CTR encrypt plaintext
  local ciphertext = {}
  local block_num = 1

  for i = 1, #plaintext, 16 do
    local block = string_sub(plaintext, i, math_min(i + 15, #plaintext))
    local counter_block = generate_counter_block(nonce, block_num, L)
    local keystream = aes_encrypt_block(counter_block, expanded_key, nr)
    ciphertext[#ciphertext + 1] = xor_strings(block, string_sub(keystream, 1, #block))
    block_num = block_num + 1
  end

  return table_concat(ciphertext) .. encrypted_tag
end

--- Decrypt data using AES-CCM.
--- @param key string 16-byte AES key
--- @param nonce string CCM nonce
--- @param aad string Associated authenticated data (empty string for BTHome)
--- @param ciphertext_and_tag string Encrypted data with appended tag
--- @param tag_length integer Authentication tag length (4 bytes for BTHome)
--- @return string|nil plaintext Decrypted data
--- @return string|nil error Error message (including authentication failure)
function aes_ccm.decrypt(key, nonce, aad, ciphertext_and_tag, tag_length)
  if #key ~= 16 and #key ~= 24 and #key ~= 32 then
    return nil, "Key must be 16, 24, or 32 bytes"
  end

  local M = math_floor(tag_length or 4)
  local L = 16 - 1 - #nonce

  if L < 2 or L > 8 then
    return nil, "invalid nonce length"
  end

  if #ciphertext_and_tag < M then
    return nil, "ciphertext too short"
  end

  -- Split ciphertext and tag
  local ciphertext_len = #ciphertext_and_tag - M
  local ciphertext = string_sub(ciphertext_and_tag, 1, ciphertext_len)
  local encrypted_tag = string_sub(ciphertext_and_tag, ciphertext_len + 1)

  -- Expand key
  local expanded_key, nr = key_expansion(key)

  -- Generate S0 for tag decryption
  local s0 = aes_encrypt_block(generate_counter_block(nonce, 0, L), expanded_key, nr)

  -- Decrypt tag
  local received_tag = xor_strings(encrypted_tag, string_sub(s0, 1, M))

  -- CTR decrypt ciphertext
  local plaintext = {}
  local block_num = 1

  for i = 1, #ciphertext, 16 do
    local block = string_sub(ciphertext, i, math_min(i + 15, #ciphertext))
    local counter_block = generate_counter_block(nonce, block_num, L)
    local keystream = aes_encrypt_block(counter_block, expanded_key, nr)
    plaintext[#plaintext + 1] = xor_strings(block, string_sub(keystream, 1, #block))
    block_num = block_num + 1
  end

  local plaintext_str = table_concat(plaintext)

  -- Verify CBC-MAC
  local computed_tag = cbc_mac(expanded_key, nr, nonce, aad, plaintext_str, M, L)

  -- Constant-time comparison
  local tag_match = true
  for i = 1, M do
    if string_byte(computed_tag, i) ~= string_byte(received_tag, i) then
      tag_match = false
    end
  end

  if not tag_match then
    return nil, "authentication failed"
  end

  return plaintext_str
end

-- ============================================================================
-- SELF-TEST
-- ============================================================================

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
function aes_ccm.selftest()
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

return aes_ccm
