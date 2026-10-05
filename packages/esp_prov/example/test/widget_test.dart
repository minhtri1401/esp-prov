import 'package:esp_prov/esp_prov.dart';
import 'package:esp_prov_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Device implements DiscoveredDevice {
  @override
  String get id => 'AA:BB';

  @override
  String get name => 'PROV_ABC123';

  @override
  int? get rssi => -42;

  @override
  String get serviceUuid => '';

  @override
  Future<ProvTransport> connect() =>
      Future.error(const TransportException('not in tests'));
}

final class _Scanner implements ProvScanner {
  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) =>
      Stream.value(_Device());
}

void main() {
  testWidgets('scan lists devices', (tester) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async => permissionRequests++,
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('scan')));
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    expect(permissionRequests, 1);
    expect(find.text('PROV_ABC123'), findsOneWidget);
  });

  testWidgets('connect errors are shown, not thrown', (tester) async {
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async {},
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('scan')));
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('PROV_ABC123'));
    // Cancelling the finished scan completes in the root zone, so let real
    // async work run while the tap is handled.
    await tester.runAsync(() async {
      await tester.tap(find.text('PROV_ABC123'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('not in tests'), findsOneWidget);
  });

  testWidgets('an invalid QR payload shows a message', (tester) async {
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async {},
      ),
    );
    await tester.enterText(find.byKey(const Key('qr')), 'not json');
    await tester.tap(find.text('Connect with QR payload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QR payload is not JSON'), findsOneWidget);
  });

  testWidgets('a throwing permission request is shown, not thrown', (
    tester,
  ) async {
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async => throw StateError('no bluetooth'),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('qr')),
      '{"ver":"v1","name":"PROV_ABC123","transport":"ble","pop":"abcd1234"}',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Connect with QR payload'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('no bluetooth'), findsOneWidget);
  });
}
