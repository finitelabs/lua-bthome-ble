--- @module "bthome.crypto"
--- BTHome cryptographic operations module.
--- Provides AES-CCM authenticated encryption for encrypted BTHome advertisements.
---
--- @class bthome.crypto
local crypto = {
  --- @type bthome.crypto.aes_ccm
  aes_ccm = require("bthome.crypto.aes_ccm"),
}

return crypto
