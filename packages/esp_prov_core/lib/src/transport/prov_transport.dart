import 'dart:typed_data';

/// Names of the protocomm endpoints every provisioning firmware exposes.
abstract final class ProvEndpoints {
  /// Plain-text JSON version and capability endpoint.
  static const protoVer = 'proto-ver';

  /// Security handshake endpoint.
  static const session = 'prov-session';

  /// Network configuration endpoint (encrypted).
  static const config = 'prov-config';

  /// Network scan endpoint (encrypted).
  static const scan = 'prov-scan';

  /// Provisioning control endpoint (encrypted).
  static const ctrl = 'prov-ctrl';
}

/// A connected link to a provisioning device.
///
/// One call to [send] is one protocomm transaction. Implementations must
/// serialise concurrent calls so transactions never interleave on the link.
abstract interface class ProvTransport {
  /// Endpoint names discovered on the device, e.g.
  /// `{'prov-session', 'prov-config', 'custom-data'}`.
  Set<String> get endpoints;

  /// Sends [request] to [endpoint] and returns the device's response bytes.
  ///
  /// Throws `TransportException` on link errors and `DeviceDisconnected`
  /// if the link drops.
  Future<Uint8List> send(String endpoint, Uint8List request);

  /// Emits once when the link drops for any reason.
  ///
  /// Must be a broadcast stream: it is listened to several times over the
  /// session lifetime (every provisioning run subscribes). A link that has
  /// dropped must also surface from [send] as `DeviceDisconnected`.
  Stream<void> get onDisconnected;

  /// Closes the link. Safe to call when already disconnected.
  Future<void> disconnect();
}

/// Discovers provisioning devices.
abstract interface class ProvScanner {
  /// Emits each device whose advertised name starts with [namePrefix]
  /// (case-insensitive), once per device id.
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'});
}

/// A device found by a [ProvScanner].
abstract interface class DiscoveredDevice {
  /// Platform device id (MAC address on Android, UUID on Apple platforms).
  String get id;

  /// Advertised name.
  String get name;

  /// Signal strength of the last advertisement, if known.
  int? get rssi;

  /// 128-bit primary service UUID taken from the advertisement, lowercase.
  String get serviceUuid;

  /// Connects and discovers the protocomm endpoints.
  Future<ProvTransport> connect();
}
