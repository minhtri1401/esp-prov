# Vendored Espressif protobuf definitions

These `.proto` files are copied unmodified from Espressif repositories and
compiled into `packages/esp_prov_core/lib/src/proto` by `tool/gen_proto.sh`.
They import each other by bare file name, so `protoc` runs with this
directory as its only include path.

| File | Source repository | Path | Commit |
|---|---|---|---|
| constants.proto, session.proto, sec0.proto, sec1.proto, sec2.proto | [espressif/esp-idf](https://github.com/espressif/esp-idf) | `components/protocomm/proto/` | `4d59230ddff16327812782151ef0afef202dc6d7` (master, 2026-09-25) |
| network_constants.proto, network_config.proto, network_scan.proto, network_ctrl.proto | [espressif/idf-extra-components](https://github.com/espressif/idf-extra-components) | `network_provisioning/proto/` | `69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0` (master, 2026-10-02) |

The `network_*` messages are wire compatible with the older
`wifi_provisioning` `wifi_*.proto` files (same field numbers) and add the
Thread messages (enum values 6-11, payload fields 16-21).

Licenses: both sources are Apache-2.0. See `LICENSE.esp-idf` and
`LICENSE.network_provisioning` in this directory.

To update: change the commits in this table and in `tool/gen_fixtures.py`,
re-download the files (from the repository root), run `tool/gen_proto.sh`,
then `tool/check.sh`:

```bash
IDF=4d59230ddff16327812782151ef0afef202dc6d7
IEC=69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0
P=third_party/espressif/proto
for f in constants session sec0 sec1 sec2; do
  curl -fsSL -o "$P/$f.proto" \
    "https://raw.githubusercontent.com/espressif/esp-idf/$IDF/components/protocomm/proto/$f.proto"
done
for f in network_constants network_config network_scan network_ctrl; do
  curl -fsSL -o "$P/$f.proto" \
    "https://raw.githubusercontent.com/espressif/idf-extra-components/$IEC/network_provisioning/proto/$f.proto"
done
curl -fsSL -o "$P/LICENSE.esp-idf" \
  "https://raw.githubusercontent.com/espressif/esp-idf/$IDF/LICENSE"
curl -fsSL -o "$P/LICENSE.network_provisioning" \
  "https://raw.githubusercontent.com/espressif/idf-extra-components/$IEC/network_provisioning/LICENSE"
```
