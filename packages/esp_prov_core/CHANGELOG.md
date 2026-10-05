## 0.1.0

- Initial release.
- `EspSession`: `proto-ver` parsing, security scheme selection from the
  firmware, serialised encrypted requests.
- Security 0, Security 1 (X25519 + AES-256-CTR + PoP) and Security 2
  (SRP-6a 3072-bit SHA-512 + AES-256-GCM, `sec_patch_ver` 0 and 1).
- Wi-Fi and Thread scan and provisioning, `prov-ctrl` commands, custom
  endpoints, QR payload parsing.
- Typed errors (`ProvException` hierarchy).
- Test fixtures generated from Espressif's `esp_prov` tool.
