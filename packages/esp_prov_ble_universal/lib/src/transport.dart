import 'dart:async';

import 'package:esp_prov_ble_universal/src/endpoint_discovery.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

/// Service UUID ESP-IDF protocomm_ble uses when the application sets none.
const defaultServiceUuid = '1775244d-6b43-439b-877c-060f2d9bed07';

/// Service UUID the ESP-IDF provisioning examples set (esp_prov's fallback).
const exampleServiceUuid = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

const _bluetoothBaseSuffix = '-0000-1000-8000-00805f9b34fb';

/// Picks the provisioning service: the advertised UUID, then
/// [defaultServiceUuid], then [exampleServiceUuid], then the only
/// non-standard service if exactly one exists. Returns null otherwise.
BleService? pickProvisioningService(
  List<BleService> services,
  String? advertisedServiceUuid,
) {
  BleService? byUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;
    final wanted = BleUuidParser.stringOrNull(uuid);
    for (final s in services) {
      if (BleUuidParser.string(s.uuid) == wanted) return s;
    }
    return null;
  }

  final custom = [
    for (final s in services)
      if (!BleUuidParser.string(s.uuid).endsWith(_bluetoothBaseSuffix)) s,
  ];
  return byUuid(advertisedServiceUuid) ??
      byUuid(defaultServiceUuid) ??
      byUuid(exampleServiceUuid) ??
      (custom.length == 1 ? custom.single : null);
}

/// A [ProvTransport] over a `universal_ble` connection.
///
/// Each [send] is a write-with-response followed by a read of the same
/// characteristic. Calls are serialised so transactions never interleave.
final class UniversalBleTransport implements ProvTransport {
  new _(this.deviceId, this.serviceUuid, EndpointMap map)
    : _characteristics = map.characteristics,
      warnings = List.unmodifiable(map.warnings) {
    _connectionSubscription = UniversalBle.connectionStream(deviceId)
        .listen((connected) {
          if (!connected) _markDisconnected();
        });
  }

  /// Connects to [deviceId], requests a 512-byte MTU on Android, discovers
  /// services and maps endpoint names to characteristics.
  ///
  /// Throws [TransportException] when the connection fails or no
  /// provisioning service is found.
  static Future<UniversalBleTransport> connect(
    String deviceId, {
    String? advertisedServiceUuid,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await UniversalBle.connect(deviceId, timeout: timeout);
    } on Object catch (e) {
      throw TransportException('Could not connect to $deviceId.', cause: e);
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await UniversalBle.requestMtu(deviceId, 512);
        } on Object catch (_) {
          // Best effort: the firmware also supports long writes.
        }
      }
      final services = await UniversalBle.discoverServices(
        deviceId,
        withDescriptors: true,
      );
      final service = pickProvisioningService(services, advertisedServiceUuid);
      if (service == null) {
        throw TransportException(
          'No provisioning service found on $deviceId '
          '(services: ${services.map((s) => s.uuid).join(', ')}).',
        );
      }
      final serviceUuid = BleUuidParser.string(service.uuid);
      final map = await discoverEndpoints(
        service,
        (characteristic) => UniversalBle.readDescriptor(
          deviceId,
          serviceUuid,
          characteristic,
          userDescriptionUuid,
        ),
      );
      return UniversalBleTransport._(deviceId, serviceUuid, map);
    } on Object catch (e) {
      try {
        await UniversalBle.disconnect(deviceId);
      } on Object {
        // Best effort: the original error must win.
      }
      if (e is ProvException) rethrow;
      throw TransportException('Connecting to $deviceId failed: $e', cause: e);
    }
  }

  /// Platform device id.
  final String deviceId;

  /// UUID of the provisioning service in use.
  final String serviceUuid;

  /// Problems found during endpoint discovery, e.g. unnamed characteristics.
  final List<String> warnings;

  final Map<String, String> _characteristics;
  final SerialQueue _queue = SerialQueue();
  final StreamController<void> _disconnects =
      StreamController<void>.broadcast();
  late final StreamSubscription<bool> _connectionSubscription;
  bool _connected = true;

  @override
  Set<String> get endpoints => _characteristics.keys.toSet();

  /// The characteristic UUID mapped to [endpoint], if any.
  String? characteristicFor(String endpoint) => _characteristics[endpoint];

  @override
  Stream<void> get onDisconnected => _disconnects.stream;

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) =>
      _queue.run(() async {
        if (!_connected) throw const DeviceDisconnected();
        final characteristic = _characteristics[endpoint];
        if (characteristic == null) throw UnknownEndpoint(endpoint);
        try {
          await UniversalBle.write(
            deviceId,
            serviceUuid,
            characteristic,
            request,
          );
          return await UniversalBle.read(deviceId, serviceUuid, characteristic);
        } on Object catch (e) {
          // The GATT error can arrive before the disconnect event; ask the
          // platform so a dropped link is always reported as a disconnect.
          if (_connected && !await _stillConnected()) _markDisconnected();
          if (!_connected) throw const DeviceDisconnected();
          throw TransportException(
            'BLE transaction on $endpoint failed.',
            cause: e,
          );
        }
      });

  Future<bool> _stillConnected() async {
    try {
      return await UniversalBle.getConnectionState(deviceId) ==
          BleConnectionState.connected;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _markDisconnected();
    await UniversalBle.disconnect(deviceId);
  }

  void _markDisconnected() {
    if (!_connected) return;
    _connected = false;
    _disconnects.add(null);
    unawaited(_connectionSubscription.cancel());
  }
}
