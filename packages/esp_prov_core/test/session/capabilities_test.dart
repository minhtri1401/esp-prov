import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

import '../support/fake_device.dart';

void main() {
  test('capability gates for wifi and thread', () async {
    final threadOnly = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec', 'thread_prov']),
      ),
    );
    expect(() => threadOnly.wifi, throwsA(isA<UnsupportedCapability>()));
    expect(threadOnly.thread, isA<ThreadProvisioner>());

    final legacy = await EspSession.open(
      FakeDevice(protoVer: protoVerJson(secVer: 0, caps: ['no_sec'])),
    );
    expect(legacy.wifi, isA<WifiProvisioner>());
    expect(() => legacy.thread, throwsA(isA<UnsupportedCapability>()));
  });
}
