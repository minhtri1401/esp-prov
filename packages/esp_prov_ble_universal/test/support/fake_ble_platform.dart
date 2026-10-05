import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Computes a characteristic's read value from the bytes last written to it.
typedef Responder = FutureOr<List<int>> Function(Uint8List written);

/// In-memory `universal_ble` platform for contract tests.
///
/// Install with `UniversalBle.setInstance(FakeBlePlatform(...))`. Methods the
/// adapter never calls fall through to [noSuchMethod], so the fake keeps
/// compiling if a universal_ble 2.x release adds platform methods.
class FakeBlePlatform extends UniversalBlePlatform {
  /// Creates a fake with one connectable device exposing [services].
  new({
    this.services = const [],
    this.userDescriptions = const {},
    this.failingDescriptorReads = const {},
    this.responders = const {},
    this.adverts = const [],
    this.transactionDelay = Duration.zero,
    this.failDiscoverServices = false,
  });

  /// Services returned by `discoverServices`.
  final List<BleService> services;

  /// 0x2901 values keyed by characteristic UUID.
  final Map<String, String> userDescriptions;

  /// Characteristic UUIDs whose 0x2901 read throws.
  final Set<String> failingDescriptorReads;

  /// Read handlers keyed by characteristic UUID.
  final Map<String, Responder> responders;

  /// Advertisements emitted when scanning starts.
  final List<BleDevice> adverts;

  /// Makes `discoverServices` throw.
  final bool failDiscoverServices;

  /// Delay applied to each write, to expose interleaving.
  final Duration transactionDelay;

  /// Operation log: `connect`, `mtu 512`, `write <uuid> <hex>`, `read <uuid>`,
  /// `disconnect`, `startScan`, `stopScan`.
  final List<String> log = [];

  /// Platform options passed to the last `startScan`.
  PlatformConfig? lastScanConfig;

  final Map<String, Uint8List> _lastWritten = {};
  bool _connected = false;

  /// Simulates the peripheral dropping the link.
  void dropLink(String deviceId) {
    _connected = false;
    updateConnection(deviceId, false);
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    log.add('connect');
    _connected = true;
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    log.add('disconnect');
    _connected = false;
    updateConnection(deviceId, false);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      _connected
      ? BleConnectionState.connected
      : BleConnectionState.disconnected;

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    log.add('mtu $expectedMtu');
    return expectedMtu;
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async {
    if (failDiscoverServices) throw Exception('GATT: discovery failed');
    return services;
  }

  @override
  Future<Uint8List> readDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor, {
    Duration? timeout,
  }) async {
    if (failingDescriptorReads.contains(characteristic)) {
      throw Exception('0x2901 read not supported');
    }
    return Uint8List.fromList(
      utf8.encode(userDescriptions[characteristic] ?? ''),
    );
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    if (!_connected) throw Exception('GATT: not connected');
    log.add('write $characteristic ${utf8.decode(value)}');
    _lastWritten[characteristic] = value;
    await Future<void>.delayed(transactionDelay);
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    if (!_connected) throw Exception('GATT: not connected');
    log.add('read $characteristic');
    final responder = responders[characteristic] ?? (w) => w;
    return Uint8List.fromList(
      await responder(_lastWritten[characteristic] ?? Uint8List(0)),
    );
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    log.add('startScan');
    lastScanConfig = platformConfig;
    adverts.forEach(updateScanResult);
  }

  @override
  Future<void> stopScan() async => log.add('stopScan');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeBlePlatform: ${invocation.memberName}');
}
