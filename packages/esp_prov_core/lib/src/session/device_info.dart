import 'dart:convert';

/// What the device reports on the `proto-ver` endpoint.
final class DeviceInfo {
  /// Creates device info. Use [DeviceInfo.parse] for device responses.
  const new({
    required this.version,
    required this.secVer,
    required this.secPatchVer,
    required this.capabilities,
    this.appInfo = const {},
  });

  /// Parses a `proto-ver` response.
  ///
  /// Accepts the JSON form
  /// `{"prov":{"ver":..,"sec_ver":..,"sec_patch_ver":..,"cap":[..]},..}` and
  /// the plain version string of very old firmware. Missing `sec_ver` means
  /// Security 0 when the `no_sec` capability is present, else Security 1
  /// (esp_prov's rule). Missing `sec_patch_ver` means 0. Every top-level key
  /// other than `prov` lands in [appInfo].
  factory parse(String response) {
    final text = response.replaceAll('\u0000', '').trim();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map<String, Object?>) {
      return DeviceInfo(
        version: text,
        secVer: 1,
        secPatchVer: 0,
        capabilities: const {},
      );
    }
    final prov = decoded['prov'];
    final provMap = prov is Map<String, Object?> ? prov : <String, Object?>{};
    final rawCaps = provMap['cap'];
    final capabilities = <String>{
      if (rawCaps is List<Object?>) ...rawCaps.whereType<String>(),
    };
    return DeviceInfo(
      version: provMap['ver'] is String ? provMap['ver']! as String : '',
      secVer:
          _asInt(provMap['sec_ver']) ??
          (capabilities.contains('no_sec') ? 0 : 1),
      secPatchVer: _asInt(provMap['sec_patch_ver']) ?? 0,
      capabilities: capabilities,
      appInfo: {
        for (final entry in decoded.entries)
          if (entry.key != 'prov') entry.key: entry.value,
      },
    );
  }

  /// Provisioning protocol version, e.g. `v1.1` or `netprov-v1.2`.
  final String version;

  /// Security scheme version (0, 1 or 2).
  final int secVer;

  /// Security patch level. 1 means Security 2 increments its GCM nonce.
  final int secPatchVer;

  /// Capability strings, e.g. `wifi_scan`, `no_pop`, `thread_prov`.
  final Set<String> capabilities;

  /// Application-defined keys reported next to `prov`.
  final Map<String, Object?> appInfo;

  /// Whether the device lists [capability].
  bool hasCapability(String capability) => capabilities.contains(capability);

  static int? _asInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };

  @override
  String toString() =>
      'DeviceInfo(version: $version, secVer: $secVer, '
      'secPatchVer: $secPatchVer, capabilities: $capabilities)';
}
