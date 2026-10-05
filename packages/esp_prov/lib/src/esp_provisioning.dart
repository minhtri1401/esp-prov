import 'dart:async';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:esp_prov_core/esp_prov_core.dart';

/// Scans for provisioning devices and opens sessions with them.
final class EspProvisioning {
  /// Creates the entry point. Uses `universal_ble` unless a [scanner] is
  /// given (tests, or another BLE stack).
  new({ProvScanner? scanner})
    : _scanner = scanner ?? const UniversalBleScanner();

  final ProvScanner _scanner;

  /// Emits each device whose name starts with [namePrefix]
  /// (case-insensitive) once. Cancel the subscription to stop scanning.
  Stream<EspDevice> scan({String namePrefix = 'PROV_'}) =>
      _scanner.scan(namePrefix: namePrefix).map(EspDevice.new);

  /// Scans until a device named exactly [name] (case-insensitive) appears,
  /// e.g. the `name` from a [ProvQrPayload]. The scan stops either way.
  ///
  /// Throws [TransportException] if none is seen within [timeout].
  Future<EspDevice> findDevice(
    String name, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final wanted = name.toLowerCase();
    final found = Completer<EspDevice>();
    void fail(Object error) {
      if (!found.isCompleted) found.completeError(error);
    }

    final timer = Timer(
      timeout,
      () => fail(TransportException('Device "$name" not found in $timeout.')),
    );
    final subscription = scan(namePrefix: name).listen(
      (device) {
        if (device.name.toLowerCase() == wanted && !found.isCompleted) {
          found.complete(device);
        }
      },
      onError: fail,
      onDone: () =>
          fail(TransportException('Scan ended before "$name" was found.')),
    );
    try {
      return await found.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}

/// A provisioning device found by [EspProvisioning.scan].
final class EspDevice {
  /// Wraps a transport-level [DiscoveredDevice].
  new(this.discovered);

  /// The underlying transport-level device.
  final DiscoveredDevice discovered;

  /// Platform device id.
  String get id => discovered.id;

  /// Advertised name, e.g. `PROV_1A2B3C`.
  String get name => discovered.name;

  /// Signal strength of the last advertisement.
  int? get rssi => discovered.rssi;

  /// Connects, reads `proto-ver`, runs the handshake for the scheme the
  /// firmware declares and returns the session. The link is closed again if
  /// any step fails.
  ///
  /// See [EspSession.open] for the errors thrown.
  Future<EspSession> connect({ProvCredentials? credentials}) async {
    final transport = await discovered.connect();
    try {
      return await EspSession.open(transport, credentials: credentials);
    } on Object {
      await transport.disconnect();
      rethrow;
    }
  }
}
