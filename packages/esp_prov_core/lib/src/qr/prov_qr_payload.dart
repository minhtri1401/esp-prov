import 'dart:convert';

import 'package:esp_prov_core/src/session/prov_credentials.dart';

/// The JSON payload printed by provisioning firmware as a QR code, e.g.
/// `{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov","pop":"abcd1234",
/// "transport":"ble"}`.
final class ProvQrPayload {
  /// Creates a payload.
  const new({
    required this.version,
    required this.name,
    required this.transport,
    this.pop,
    this.username,
    this.password,
    this.security,
    this.network,
  });

  /// Parses the QR string. Throws [FormatException] when it is not a JSON
  /// object or has no non-empty `name`.
  factory parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json.trim());
    } on FormatException catch (e) {
      throw FormatException('QR payload is not JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('QR payload is not a JSON object');
    }
    final map = decoded;
    String? str(String key) => switch (map[key]) {
      final String v => v,
      _ => null,
    };

    final name = str('name');
    if (name == null || name.isEmpty) {
      throw const FormatException('QR payload has no "name"');
    }
    final security = map['security'];
    return ProvQrPayload(
      version: str('ver') ?? 'v1',
      name: name,
      transport: str('transport') ?? 'ble',
      pop: str('pop'),
      username: str('username'),
      password: str('password'),
      security: switch (security) {
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      },
      network: str('network'),
    );
  }

  /// Payload format version, usually `v1`.
  final String version;

  /// Advertised device name, e.g. `PROV_1A2B3C`.
  final String name;

  /// `ble` or `softap`.
  final String transport;

  /// Security 1 proof of possession, or the Security 2 password in the
  /// stock ESP-IDF examples.
  final String? pop;

  /// Security 2 username.
  final String? username;

  /// Security 2 password when given explicitly.
  final String? password;

  /// Explicit `security` field; the stock examples omit it.
  final int? security;

  /// `wifi` or `thread` when the firmware states it.
  final String? network;

  /// Whether the device should be reached over BLE.
  bool get isBle => transport.toLowerCase() == 'ble';

  /// Credentials implied by the payload.
  ///
  /// With an explicit [security] field: 0 gives none, 1 gives `pop`, 2 gives
  /// `security2`. Without it (stock examples) a `username` means Security 2
  /// with the password taken from `password` or else `pop`; a lone `pop`
  /// means Security 1; nothing means no credentials.
  ProvCredentials get credentials {
    final secret = password ?? pop ?? '';
    final kind = security ?? (username != null ? 2 : (pop != null ? 1 : 0));
    return switch (kind) {
      2 => ProvCredentials.security2(
        username: username ?? '',
        password: secret,
      ),
      1 => ProvCredentials.pop(pop ?? ''),
      _ => const ProvCredentials.none(),
    };
  }
}
