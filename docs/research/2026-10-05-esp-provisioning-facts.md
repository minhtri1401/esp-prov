# ESP Unified Provisioning — verified facts (2026-10-05)

## BLE transport
- One primary service (128-bit UUID taken from advertisement; firmware default decodes to 1775244d-6b43-439b-877c-060f2d9bed07; esp_prov fallback 021a9004-0382-4aea-bff4-6b3f1c5adfb4).
- Each endpoint = one characteristic; UUID = service UUID with LE bytes 12-13 replaced by 16-bit: prov-ctrl FF4F, prov-scan FF50, prov-session FF51, prov-config FF52, proto-ver FF53, custom endpoints FF54, FF55... in creation order.
- Endpoint name is the 0x2901 Characteristic User Description value. Clients map name -> char UUID.
- Transaction = write-with-response then read the same characteristic. Notify only if firmware enables ble_notify.
- Payload cap: Bluedroid 256 B (480 B with sec2), NimBLE 512 B. Android lib requests MTU 512. Scan results fetched max 4 per page over BLE.
- Device name prefix PROV_ is example convention; apps filter by prefix.
- Auto-stop: after Connected, firmware stops provisioning ~1 s later (disconnect expected); 30 s autostop timer if get_status never polled.

## Endpoints
proto-ver (plaintext JSON), prov-session (handshake), prov-scan, prov-config, prov-ctrl (encrypted), custom (encrypted raw bytes).
proto-ver JSON: {"prov":{"ver":"v1.1"|"netprov-v1.2","sec_ver":N,"sec_patch_ver":N,"cap":["wifi_scan","no_pop"|"no_sec","wifi_prov","thread_prov","thread_scan"]}, "<app>":{...}}. sec_ver absent -> assume sec1. sec_patch_ver absent -> 0.

## Security
- Sec0: S0SessionCmd -> S0SessionResp.
- Sec1: X25519; client sends pubkey (Cmd0); device returns device_pubkey + device_random(16); key = shared XOR SHA256(pop) bytewise; AES-256-CTR key, IV=device_random, ONE continuous keystream for both directions (encrypt==decrypt); client_verify = ctr(device_pubkey) (Cmd1); device_verify_data decrypt must equal client pubkey.
- Sec2: SRP-6a RFC5054 3072-bit N, g=5, SHA-512. A must serialize to exactly 384 bytes (re-roll a). x=H(s|H(I:p)), k=H(N|PAD(g)), u=H(PAD(A)|PAD(B)), S=(B-k*g^x)^(a+u*x), K=H(S) 64B, M1=H(H(N)^H(g)|H(I)|s|A|B|K), M2=H(A|M1|K). AES-256-GCM key=K[0:32], tag 16 appended, no AAD. IV = device_nonce (8B session id + 4B BE counter starting 1); patch_ver 1: counter++ after every encrypt/decrypt (shared counter); patch_ver 0: fixed nonce (legacy broken firmware).
- Espressif recommends sec2; IDF 6.0 disables sec0/sec1 by default. sec2 since IDF 5.0.

## Protos
protocomm: constants, session, sec0, sec1, sec2. Wi-Fi: wifi_constants/config/scan/ctrl (IDF<=5.x) superseded by network_constants/config/scan/ctrl (idf-extra-components/network_provisioning, wire compatible; Thread msgs use enum 6-11 / fields 16-21). Status enum: Success..InvalidSession(7). WifiStationState Connected0 Connecting1 Disconnected2 ConnectionFailed3; fail AuthError0 NetworkNotFound1; attempt_failed{attempts_remaining}. Scan: start{blocking,passive,group_channels,period_ms} -> status{scan_finished,result_count} -> result{start_index,count} entries{ssid,channel,rssi,bssid,auth}. Ctrl: reset, reprov.

## QR payload
{"ver":"v1","name":"PROV_XXXXXX","pop":"...","transport":"ble"|"softap","security":0|1|2 (default 2),"password":"...","username":"...","network":"thread"}

## Ecosystem
- flutter_esp_ble_prov 0.1.7 (Feb 2024) GitLab afshar-oss, MIT, sec1 only, wraps Android lib-2.1.2 / unpinned iOS ESPProvision, stubbed callbacks crash, AGP namespace broken. Name owned by other publisher.
- No Dart package implements sec2 in Dart. esp_ble_prov_dart (pure Dart sec0/1, universal_ble ^1.2).
- BLE: universal_ble 2.3.0 BSD-3, 6 platforms, Pigeon, 0x2901 descriptor read since 2.2.0 (recommended). flutter_blue_plus 2.x proprietary license + License enum + telemetry. bluetooth_low_energy MIT, stalled Jan 2026. flutter_reactive_ble cannot read descriptors.
- Crypto: cryptography 2.9.0 / cryptography_plus 3.0.0 (X25519, AesCtr, AesGcm); pointycastle 4.0.0 (stateful CTR, GCM tag appended, SRP group constants but M1/M2 formula differs); crypto 3.0.7 SHA-512; x25519 0.1.2. Write own SRP-6a (~150 lines BigInt.modPow), run in Isolate.run.
- protobuf 6.1.0, protoc_plugin 25.1.0.
- Flutter 3.47.6 / Dart 3.13.5. Pigeon 29. Pure-Dart core -> 160 pub points, 6 platforms.
