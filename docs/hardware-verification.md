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
| A (sec2) | [ ] | [ ] |
| B (sec1) | [ ] | [ ] |
| C (sec2, long timeout) | [ ] | [ ] |

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
- [ ] Wrong password (`Security 2` segment, password `nope`): SnackBar text
      starts with `The device dropped the session` or `The device proof does
      not verify` (PopMismatch), not a generic error. The monitor prints
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
