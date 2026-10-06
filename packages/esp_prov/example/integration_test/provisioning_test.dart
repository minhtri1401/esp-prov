// Hardware test: needs a phone with Bluetooth and an ESP32 running the
// wifi_prov_mgr example.
//
// fvm flutter test integration_test/provisioning_test.dart -d <device-id> \
//   --dart-define=PROV_NAME=PROV_1A2B3C \
//   --dart-define=PROV_SEC=2 \
//   --dart-define=PROV_USERNAME=wifiprov \
//   --dart-define=PROV_SECRET=abcd1234 \
//   --dart-define=WIFI_SSID=MyNetwork \
//   --dart-define=WIFI_PASSPHRASE=secret123
import 'dart:convert';

import 'package:esp_prov/esp_prov.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:universal_ble/universal_ble.dart';

const _name = String.fromEnvironment('PROV_NAME');
const _sec = int.fromEnvironment('PROV_SEC', defaultValue: 2);
const _username = String.fromEnvironment(
  'PROV_USERNAME',
  defaultValue: 'wifiprov',
);
const _secret = String.fromEnvironment('PROV_SECRET', defaultValue: 'abcd1234');
const _ssid = String.fromEnvironment('WIFI_SSID');
const _passphrase = String.fromEnvironment('WIFI_PASSPHRASE');

ProvCredentials get _credentials => switch (_sec) {
  0 => const ProvCredentials.none(),
  1 => const ProvCredentials.pop(_secret),
  _ => const ProvCredentials.security2(username: _username, password: _secret),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(_name, isNotEmpty, reason: 'pass --dart-define=PROV_NAME=...');
    expect(_ssid, isNotEmpty, reason: 'pass --dart-define=WIFI_SSID=...');
    await UniversalBle.requestPermissions();
  });

  testWidgets('wrong credentials surface as PopMismatch', (tester) async {
    if (_sec == 0) return;
    final device = await EspProvisioning().findDevice(_name);
    const wrong = _sec == 1
        ? ProvCredentials.pop('wrong-pop')
        : ProvCredentials.security2(
            username: _username,
            password: 'wrong-password',
          );
    await expectLater(
      device.connect(credentials: wrong),
      throwsA(isA<PopMismatch>()),
    );
  });

  testWidgets('handshake, custom-data, Wi-Fi scan and provision', (
    tester,
  ) async {
    // Give the firmware time to re-advertise after the rejected session.
    await Future<void>.delayed(const Duration(seconds: 2));
    final device = await EspProvisioning().findDevice(_name);
    final session = await device.connect(credentials: _credentials);
    expect(session.securityVersion, _sec);

    final reply = await session
        .custom('custom-data')
        .send(utf8.encode('esp_prov integration test'));
    expect(utf8.decode(reply).replaceAll('\u0000', ''), 'SUCCESS');

    final networks = await session.wifi.scan();
    expect(networks.map((n) => n.ssid), contains(_ssid));

    final states = await session.wifi
        .provision(ssid: _ssid, passphrase: _passphrase)
        .toList();
    expect(states.last, isA<WifiConnected>(), reason: 'states: $states');
    await session.close();
  });
}
