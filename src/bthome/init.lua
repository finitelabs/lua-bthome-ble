--- @module "bthome"
--- Pure Lua BTHome BLE advertisement parser library.
--- This library provides parsing for BTHome V1 and V2 BLE advertisements,
--- supporting both unencrypted and encrypted payloads.
---
--- @usage
--- local bthome = require("bthome")
--- print(bthome.version())
---
--- -- Parse V2 unencrypted advertisement
--- local result = bthome.parse(bthome.UUID_V2, service_data)
---
--- -- Parse V2 encrypted advertisement
--- local result = bthome.parse(bthome.UUID_V2, service_data, bind_key, mac_address)
---
--- -- Parse V1 encrypted advertisement
--- local result = bthome.parse(bthome.UUID_V1_ENCRYPTED, service_data, bind_key, mac_address)
---
--- @class bthome
local bthome = {
  --- @type bthome.const
  const = require("bthome.const"),
  --- @type bthome.event
  event = require("bthome.event"),
  --- @type bthome.parser
  parser = require("bthome.parser"),
  --- @type bthome.crypto
  crypto = require("bthome.crypto"),
}
bthome.UUID_V1_UNENCRYPTED = bthome.parser.UUID_V1_UNENCRYPTED
bthome.UUID_V1_ENCRYPTED = bthome.parser.UUID_V1_ENCRYPTED
bthome.UUID_V2 = bthome.parser.UUID_V2

--- Library version (injected at build time for releases).
local VERSION = "dev"

--- Get the library version string.
--- @return string version Version string (e.g., "v1.0.0" or "dev")
function bthome.version()
  return VERSION
end

bthome.parse = bthome.parser.parse

return bthome
