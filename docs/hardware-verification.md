# Hardware verification: ESP32-S3-DevKitC-1

Manual checklist for the success criteria in
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md` (section 1).
Run it before every release and after any change to `security/`, `crypto/`,
`session/` or the BLE adapter. Record the results in the PR description.

Hardware: ESP32-S3-DevKitC-1 N16R8, a USB-C cable on the **UART** port, an
Android phone (Android 12 or newer) and an iPhone, and a 2.4 GHz Wi-Fi
network you control (SSID plus passphrase).

## 0. One-time setup (manual, done by a person)

ESP-IDF is not installed on the development Mac. Install it once:

```bash
brew install cmake ninja dfu-util ccache python3
mkdir -p ~/esp && cd ~/esp
git clone -b v5.4.2 --recursive https://github.com/espressif/esp-idf.git esp-idf-v5.4.2
cd esp-idf-v5.4.2 && ./install.sh esp32s3
```

Every new terminal that builds firmware needs:

```bash
. ~/esp/esp-idf-v5.4.2/export.sh
idf.py --version   # expect: ESP-IDF v5.4.2
```

Find the board's serial port after plugging it in:

```bash
ls /dev/cu.usbserial-* /dev/cu.wchusbserial-* /dev/cu.usbmodem* 2>/dev/null
```

Use that path as `PORT` below, e.g. `export PORT=/dev/cu.usbserial-110`.

Optional second pass on ESP-IDF 6.0: clone `-b v6.0` into
`~/esp/esp-idf-v6.0`, install it, and source its `export.sh`. In 6.0
`wifi_prov_mgr` no longer exists under `$IDF_PATH/examples/provisioning`. The
example lives in idf-extra-components:

```bash
git clone https://github.com/espressif/idf-extra-components ~/esp/idf-extra-components
cp -r ~/esp/idf-extra-components/network_provisioning/examples/wifi_prov ~/esp/prov-sec2-idf6
```

Repeat sections 1-3 using that copy instead of the `cp -r "$IDF_PATH/..."`
line. The `EXAMPLE_PROV_SECURITY_VERSION_*` menuconfig symbols are unchanged;
the manager menu is named **Network Provisioning Manager** (symbol
`CONFIG_NETWORK_PROV_AUTOSTOP_TIMEOUT`). `proto-ver` then reports
`ver: netprov-v1.2`.

## 1. Build A: Security 2 (example default)

```bash
cp -r "$IDF_PATH/examples/provisioning/wifi_prov_mgr" ~/esp/prov-sec2
cd ~/esp/prov-sec2
idf.py set-target esp32s3
idf.py -p "$PORT" erase-flash flash monitor
```

The defaults are BLE transport, Security 2, development mode (username
`wifiprov`, password `abcd1234`) and a `custom-data` endpoint. In the monitor,
after `If QR code is not visible, copy paste the below URL in a browser.`,
the URL ends in `?data=` followed by the QR payload JSON, e.g.
`{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov","pop":"abcd1234","transport":"ble"}`.
Its `name` (`PROV_XXXXXX` below) is the BLE device name. Leave the monitor
running (Ctrl+] exits).

## 2. Build B: Security 1 with PoP `abcd1234`

```bash
cp -r "$IDF_PATH/examples/provisioning/wifi_prov_mgr" ~/esp/prov-sec1
cd ~/esp/prov-sec1
idf.py set-target esp32s3
idf.py menuconfig
```

In menuconfig: **Example Configuration -> Protocomm security version ->
Security version 1**. Save and exit, then:

```bash
idf.py -p "$PORT" erase-flash flash monitor
```

The QR payload is `{"ver":"v1","name":"PROV_XXXXXX","pop":"abcd1234","transport":"ble"}`.

## 3. Build C: Security 2 with a longer auto-stop timeout

Same as build A (the `custom-data` endpoint is already registered by the
example), plus in menuconfig: **Component config -> Wi-Fi Provisioning
Manager -> Provisioning auto-stop timeout** set to `120`. Leave
**Example Configuration -> Re-provisioning** OFF: enabling it calls
`wifi_prov_mgr_disable_auto_stop(1000)` and the board would never stop.

The raised timeout gives you up to 120 s to query status before the board
stops on its own. The roughly 1 s stop after the app observes `Connected` is
unchanged.

## 4. Automated hardware test (per build, per phone)

From `packages/esp_prov/example`, with the phone connected and the board
freshly flashed (`erase-flash` resets the provisioned state):

```bash
fvm flutter devices                      # copy the phone's device id
fvm flutter test integration_test/provisioning_test.dart -d <device-id> \
  --dart-define=PROV_NAME=PROV_XXXXXX \
  --dart-define=PROV_SEC=2 \
  --dart-define=PROV_USERNAME=wifiprov \
  --dart-define=PROV_SECRET=abcd1234 \
  --dart-define=WIFI_SSID=<your ssid> \
  --dart-define=WIFI_PASSPHRASE=<your passphrase>
```

Build C uses the same command as build A. For build B use `PROV_SEC=1` (username is ignored). Expected: `All tests
passed!`, and the monitor shows `Received Wi-Fi credentials`, then
`Connected with IP Address:...`, then `Provisioning successful`.

| Build | Android | iOS |
|---|---|---|
| A (sec2) | [x] ESP32 | [ ] |
| B (sec1) | [x] ESP32 | [ ] |
| C (sec2, long timeout) | [x] ESP32 | [ ] |

## 5. Manual example-app checks (build C, one phone is enough)

Run `fvm flutter run -d <device-id>` in `packages/esp_prov/example`.
Before each check, if the device was provisioned, run
`idf.py -p "$PORT" erase-flash flash monitor` again.

- [ ] Scan lists `PROV_XXXXXX` once (no duplicates), with an RSSI value.
- [ ] Paste the QR JSON from the monitor, tap **Connect with QR payload**:
      session page shows `Security 2 (patch 1)` and endpoints include
      `custom-data`.
- [ ] **Scan Wi-Fi** lists your network; tapping it fills the SSID.
- [ ] **Send custom data** logs `custom-data replied: SUCCESS`; the monitor
      prints `Received data: hello from esp_prov`.
- [ ] Wrong password (`Security 2` segment, password `nope`): SnackBar shows one of
      these messages (`describeError` returns the `ProvException` message
      only, not the error type), not a generic error: `The device
      disconnected after receiving the username and password` (real BLE path, `security_scheme.dart`), `The device dropped
      the session after receiving the username and password` (transport
      error variant), `The device proof does not verify` (Security 2,
      `security2.dart`) or `The device verification data does not match`
      (Security 1, `security1.dart`). The monitor prints
      `Received incorrect username and/or PoP for establishing secure
      session!`.
- [ ] Wrong passphrase: log ends with `Failed: authError` (may first show
      `Attempt failed, N left`). With the example's default 5 connection
      attempts a slow AP may produce `Failed: timeout` instead; record it.
- [ ] Unknown SSID (type `does-not-exist`): log ends with
      `Failed: networkNotFound`.
- [ ] Unplug the board while the log shows `Device is connecting`: log ends
      with `Failed: deviceDisconnected`.
- [ ] Correct credentials: log ends with `Connected to <ssid> as <ip>`; the
      board stops advertising about 1 s after `Connected` (auto-stop; same on
      builds A, B and C) and the app shows no error.
- [ ] Build B with the PoP segment and `abcd1234`: same flow succeeds;
      PoP `wrong` gives a PopMismatch message.

## 6. Timing

- [ ] On the Android phone, Security 2 connect (tap to session page) takes
      under 3 s. If it is slower, profile `Srp6aClient.computeProof`
      (spec target: SRP math under 1 s in release builds).

## Run record

### 2026-10-06: ESP32 (not S3), Pixel 8, ESP-IDF v5.4.2

Board: ESP32-D0WD-V3 rev 3.0, 4 MB flash, CH340 USB-serial (the
ESP32-S3-DevKitC-1 was not available; firmware built with
`idf.py set-target esp32`, otherwise as in sections 1-3). Phone: Pixel 8
(Android), debug build. iOS and the S3 run are still to do.

Section 4, automated test on Android: build A 2/2, build B 2/2, build C 2/2.
The monitor showed the expected sequence each time.

Section 5, example app (builds C and B):

- [x] Scan lists `PROV_184D9C` once, RSSI -47.
- [x] QR connect: `v1.1 Security 2 (patch 1)`, endpoints include `custom-data`.
- [x] Scan Wi-Fi lists the network; tapping fills the SSID.
- [x] Custom data: `custom-data replied: SUCCESS`; monitor prints
      `Received data: hello from esp_prov`.
- [x] Wrong password: `The device dropped the session after receiving the
      username and password (BLE transaction on prov-session failed.)`.
- [x] Wrong passphrase: `Failed: timeout` (allowed). The board needed about
      32 s for its 5 attempts and then reported an auth failure; the 30 s
      default `timeout` of `WifiProvisioner.provision` expired first.
- [x] Unknown SSID: `Failed: networkNotFound`. (The example firmware's log
      line says "authentication failed" for reason 201; the protocol reports
      AP not found.)
- [x] Unplug while connecting: `Failed: deviceDisconnected`.
- [x] Correct credentials: `Connected to P306 as 192.168.100.121`, board
      stops about 1 s later; the app then logs `Device disconnected` (no error).
- [x] Build B, PoP `abcd1234`: `Security 1 (patch 0)`, provisioning succeeds;
      wrong PoP gives `The device dropped the session after receiving the
      proof of possession`.

macOS (same board, macOS 27 on Apple silicon, debug): section 4 test passes
for build A (2/2, 20 s) and build B (2/2, 21 s); the monitor shows the
expected sequence. `fvm flutter build macos --release` succeeds. iOS was not
run; it shares the CoreBluetooth path with macOS in universal_ble.

Section 6: Security 2 BLE connect to `Secured session established` took
2.4-2.6 s on the monitor clock (debug build), under the 3 s target.

Follow-ups found:

- Wi-Fi `provision` gives up while the device still reports attempts
  remaining, so a wrong passphrase on default firmware tends to surface as
  `timeout` instead of `authError`.
- Example app: nothing tells the user to tap a scan result to connect with
  the manual credentials.
