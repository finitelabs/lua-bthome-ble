# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a pure Lua implementation of the BTHome BLE advertisement parser
(5.1+ and LuaJIT), supporting BTHome V1 and V2 including encrypted
advertisements using AES-CCM.

The repo has no external dependencies, but the *canonical build artifact* does:
`build/bthome.lua` expects `bitn` on the Lua path. `build/bthome-portable.lua` is
the zero-dependency one. `src/bthome/crypto/aes_ccm.lua` is the only consumer,
which is why `-i "bitn"` works for the core build.

## Project Structure

```
lua-bthome-ble/
├── src/bthome/
│   ├── init.lua           # Module aggregator with version()
│   ├── const.lua          # Object IDs, data types, factors, units
│   ├── event.lua          # Button/dimmer event definitions
│   ├── parser.lua         # BLE advertisement parsing
│   └── crypto/
│       ├── init.lua       # Crypto aggregator
│       └── aes_ccm.lua    # AES-128 + AES-CCM AEAD for BTHome encryption
├── vendor/
│   └── bitn.lua           # Vendored bitwise operations library
├── .github/workflows/
│   ├── build.yml          # CI: check, test matrix, build
│   └── release.yml        # Release automation
├── .luarc-typecheck.json  # Hardened config for `make typecheck` (see below)
├── .luacheckrc
├── run_tests.sh           # Main test runner
├── run_tests_matrix.sh    # Multi-version test runner
└── Makefile               # Build automation
```

`vendor/bitn.lua` is a copied release artifact, not a submodule. It was last
pinned to v0.6.1 for a LuaJIT-2026 signedness fix in bitn's `_compat.lua`; the
tree does not otherwise record which version is vendored.

## Key Commands

```bash
# Run tests
make test

# Run specific module tests
make test-bthome
make test-parser
make test-crypto

# Run across Lua versions
make test-matrix

# Format code
make format

# Lint code
make lint

# Check LuaCATS annotations with lua-language-server
make typecheck

# Full gate: format-check + lint + typecheck
make check

# Build single-file distributions
make build
# Output: build/bthome.lua (core) and build/bthome-portable.lua (bundles bitn)

# Install development dependencies
make install-deps
```

`make check` is the gate CI runs. `make all` is `format lint test build`, which
rewrites `src/` in place and runs neither `format-check` nor `typecheck` — it is
not a substitute for `check`. `make help` is stale on this point: it describes
`check` as "format-check and lint" and omits typecheck.

### typecheck

`make typecheck` runs lua-language-server against the committed
`.luarc-typecheck.json`. It catches what luacheck does not: undefined or duplicate
`@alias`, returns that disagree with `@return`, fields missing from a `@class`.

`--configpath` displaces each individual setting the committed config declares,
not each table, so a knob is only closed if it is named. Suppression keys can be
enumerated from the diagnostics read sites:

    grep -rhoE "config\.get\([^,]*, *'Lua\.[A-Za-z.]+'" \
      script/core/diagnostics/*.lua script/provider/diagnostic.lua

Treat that as a floor, not a ceiling: its file scope is the shape of its blind
spot. Anything that gates file loading or rewrites source before analysis is read
elsewhere, and has to be enumerated separately from `script/plugin.lua` and
`script/workspace.lua`. `runtime.plugin` is the case that matters, and the grep
cannot surface it by construction. `check_worker.lua` does `require 'plugin'`, so
an `OnSetText` returning an empty edit blanks every file in the repo and the check
passes having analysed nothing.

Two traps decide how a key gets declared, and neither is answered by the key's
type:

Empty is not always inert, so read the read site. `neededFileStatus` and
`groupFileStatus` are per-key lookups that fall back to the built-in default, so
`{}` leaves behaviour untouched. `enableScheme` defaults to `["file"]`, which makes
`[]` silence the whole check exactly as a local `["git"]` would. It is declared as
`["file"]` for that reason.

Immunity is per-code, so one planted probe does not measure a key.
`check_worker.lua`'s `downgrade_checks_to_opened` force-overwrites only codes whose
default status is `Any`, leaving everything defaulting to `Opened` under local
control, which is precisely the type-check group this gate exists for. An
`undefined-global` probe therefore reports `neededFileStatus` as inert while a
`return-type-mismatch` probe shows it silencing the check. Probe with a type-check
code.

Declared here as measured live bypasses: `enable`, `disable`, `severity`,
`globals`, `globalsRegex`, `enableScheme`, `neededFileStatus` and `groupFileStatus`
under `diagnostics`, plus `special` and `plugin` under `runtime`. `pluginArgs`,
`groupSeverity`, `maxPreload` and `preloadFileSize` are declared as belt and
braces rather than measured bypasses: `groupSeverity` relabels a finding that is
still counted and still exits non-zero, and `preloadFileSize: 0` fails loud rather
than hiding anything. Declaring them costs nothing and saves re-deriving that.

Any setting this file does not name, under any table, is still reachable from a
local `.luarc.json`. Re-run both enumerations when upgrading the server rather than
assuming this list stayed complete.

The server version is not pinned locally, though. `install-deps` takes whatever
Homebrew has while CI pins 3.19.0, so compare the version the target prints if a
local result disagrees with CI.

`vendor/` is both a `library` and an `ignoreDir`. `ignoreDir` is what keeps the
check clean — without it the vendored code is diagnosed here, and the count moves
whenever `vendor/bitn.lua` is re-vendored, so it is not worth recording a number.
`library` makes the vendored definitions resolve. Nothing in `src/` annotates
against a bitn type yet, so `library` is currently the correct setting rather than
a load-bearing one; that flips the day `src/` does, when those uses would become
`undefined-doc-name`.

`runtime.version` is pinned to LuaJIT because that is what Control4 runs. Unset,
the server assumes Lua 5.4 and checks the wrong language. That happens to make no
difference to the findings here today, unlike in lua-bitn and lua-protobuf where
5.1-era compat shims trip the deprecation check.

Part of `check`, so CI enforces it, against the pinned 3.19.0.

## Architecture

### Module Design

The BTHome library provides parsing for BTHome V1 and V2 BLE advertisements:

- **const.lua**: 92 object ID entries (75 unique names) from the bthome.io/format
  spec. Not all are sensors — roughly 30 are binary sensors, plus 2 events and 3
  device-info IDs.
- **event.lua**: Button events (press, double_press, long_press, etc.) and dimmer events
- **parser.lua**: Main parsing logic for device info, object IDs, and encrypted payloads
- **crypto/aes_ccm.lua**: AES block cipher and AES-CCM AEAD. `key_expansion`
  implements 128/192/256 and `decrypt` accepts all three, but `encrypt` rejects
  any key that is not 16 bytes. BTHome itself is AES-128 only.

### BTHome Protocol

- **Service UUIDs**:
  - `0x181C` - V1 unencrypted
  - `0x181E` - V1 encrypted
  - `0xFCD2` - V2 (encryption determined by device_info byte)
- **V2 Device Info Byte**: Bit 0=encrypted, Bit 2=trigger, Bits 5-7=version
- **Encryption**: AES-128-CCM, 16-byte key, 4-byte MIC

**The two versions do not share a data format**, which is the single most common
way to misread `parser.lua`:

- **V2** is object ID followed by little-endian value bytes.
- **V1** is a control byte then a type byte then the data, with the length in bits
  0-4 of the control byte and the format in bits 5-7.

The crypto differs too. V1 uses a 12-byte nonce with `aad = string.char(0x11)`;
V2 uses a 13-byte nonce with empty AAD. Both splice the 4-byte counter out from
between the ciphertext and the MIC before calling CCM.

`packet_id` (object `0x00`) is hoisted out of `readings` onto the result root, so
it is not present in the readings list.

### Public API

```lua
local bthome = require("bthome")

-- Parse V2 unencrypted advertisement
local result = bthome.parse(bthome.UUID_V2, service_data)

-- Parse V2 encrypted advertisement
local result = bthome.parse(bthome.UUID_V2, service_data, bind_key, mac_address)

-- Parse V1 unencrypted advertisement
local result = bthome.parse(bthome.UUID_V1_UNENCRYPTED, service_data)

-- Parse V1 encrypted advertisement
local result = bthome.parse(bthome.UUID_V1_ENCRYPTED, service_data, bind_key, mac_address)

-- Result structure:
-- {
--   device_info = { encrypted = bool, trigger_based = bool, version = 1|2 },
--   packet_id = number|nil,
--   readings = {
--     { name = "temperature", value = 25.06, unit = "°C", id = 0x02, instance = 1 },
--     { name = "humidity", value = 50.55, unit = "%", id = 0x03, instance = 1 },
--   }
-- }
```

### Error Handling

`parser.parse` returns `result` or `nil, error_message` for **parse** failures.
Two qualifications matter:

- **It is not universal.** `bthome.version()` returns a string, `bthome.selftest()`
  a boolean, `const.get_object()` a bare `nil` with no second value, and the
  `event.decode_*` functions always return a table.
- **It does throw on mistyped arguments.** The `nil, err` contract covers bad
  *data*, not bad *calls*. `parse(nil, data)` raises from `string.format`, and
  passing a number where `bind_key` belongs raises on the length operator. Wrap in
  `pcall` if the arguments come from anywhere untrusted.

```lua
local result, err = bthome.parse(bthome.UUID_V2, service_data)
if not result then
  print("Parse error: " .. err)
end
```

**Parsing is all-or-nothing.** A single unrecognised object ID discards the whole
advertisement — `"unknown object ID: 0x%02X at position %d"` — rather than
returning the readings decoded up to that point. For a parser fed by third-party
firmware this is the contract most likely to surprise a caller: a device that adds
one unsupported measurement stops reporting entirely.

## Testing

Each module ships a `selftest()` returning a boolean, driven by the shell runner:

```bash
./run_tests.sh          # or `make test`
make test-parser        # one module
make test-matrix        # across Lua versions
```

Available test modules: bthome, const, event, crypto, parser.

`make test` runs `run_tests.sh` with no arguments, whose default module list is
just `bthome`; the others are reached only transitively through
`bthome.selftest()`. CI runs `make test-all`, which is the wider run.

## Building

The build process uses `amalg` to create single-file distributions:

```bash
make build
# Output:
#   build/bthome.lua      - Core (canonical); requires external bitn
#   build/bthome-portable.lua - Portable; bitn bundled, zero external deps
```

Version is automatically injected from git tags during release.

## CI/CD

- **build.yml**: Runs on push/PR to `main` or `master`
  - `check` job (Lua 5.4 only) — `make check`: stylua format check, luacheck, and
    typecheck against lua-language-server 3.19.0
  - `test` job — `make test-all` across Lua 5.1-5.4, LuaJIT 2.0/2.1
  - `build` job — both single-file distributions
  - Jobs are chained `check` → `test` → `build` with `fail-fast`, so a formatting
    slip stops the run before any test executes.

- **release.yml**: Runs on version tags (v*)
  - Builds and publishes release with bthome.lua and bthome-portable.lua artifacts

## Code Style

- 2-space indentation
- 120 column width
- Double quotes preferred
- LuaCATS annotations on public functions

There is no `.stylua.toml`; these live only as CLI flags in the Makefile. Running
bare `stylua src/` outside `make` therefore uses stylua's own defaults and
reformats differently. The 120-column limit is enforced by stylua alone —
`.luacheckrc` sets `max_line_length = false`.

## Dependencies

- **vendor/bitn.lua**: Vendored bitwise operations library (pure Lua)
  - Provides bit32 operations needed for AES and parsing
  - Excluded from the bthome.lua (core) build, included in bthome-portable.lua
