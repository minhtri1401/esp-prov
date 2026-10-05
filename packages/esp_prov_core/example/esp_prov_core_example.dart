// Prints the credentials a provisioning QR code implies, then shows how a
// session is opened once a transport (e.g. esp_prov_ble_universal) exists.
// ignore_for_file: avoid_print
import 'package:esp_prov_core/esp_prov_core.dart';

Future<void> provision(ProvTransport transport) async {
  final session = await EspSession.open(
    transport,
    credentials: const ProvCredentials.security2(
      username: 'wifiprov',
      password: 'abcd1234',
    ),
  );
  try {
    final networks = await session.wifi.scan();
    print(networks.map((n) => '${n.ssid} ${n.rssi} dBm').join('\n'));
    await session.wifi
        .provision(ssid: 'MyNetwork', passphrase: 'secret123')
        .forEach(print);
  } finally {
    await session.close();
  }
}

void main() {
  final qr = ProvQrPayload.parse(
    '{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov",'
    '"pop":"abcd1234","transport":"ble"}',
  );
  print('Device ${qr.name} needs ${qr.credentials.kind} credentials.');
}
