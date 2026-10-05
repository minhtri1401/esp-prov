import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// UUID of the Characteristic User Description descriptor that carries the
/// protocomm endpoint name.
const userDescriptionUuid = '00002901-0000-1000-8000-00805f9b34fb';

/// Endpoint names for characteristics without a 0x2901 descriptor, keyed by
/// the 16-bit id in UUID bytes 12-13 (ESP-IDF protocomm_ble defaults).
const fallbackEndpointNames = <int, String>{
  0xff4f: 'prov-ctrl',
  0xff50: 'prov-scan',
  0xff51: 'prov-session',
  0xff52: 'prov-config',
  0xff53: 'proto-ver',
};

/// The characteristic UUID protocomm_ble derives for [endpointId] from
/// [serviceUuid]: little-endian bytes 12-13 of the 128-bit UUID, which are
/// hex characters 4-7 of the canonical string.
///
/// `characteristicUuidFor('021a9004-0382-4aea-bff4-6b3f1c5adfb4', 0xff51)`
/// is `'021aff51-0382-4aea-bff4-6b3f1c5adfb4'`.
String characteristicUuidFor(String serviceUuid, int endpointId) {
  final service = BleUuidParser.string(serviceUuid);
  final id = endpointId.toRadixString(16).padLeft(4, '0');
  return '${service.substring(0, 4)}$id${service.substring(8)}';
}

/// The 16-bit endpoint id of [characteristicUuid] if it is derived from
/// [serviceUuid], otherwise null.
int? endpointIdOf(String serviceUuid, String characteristicUuid) {
  final service = BleUuidParser.string(serviceUuid);
  final characteristic = BleUuidParser.string(characteristicUuid);
  if (service.substring(0, 4) != characteristic.substring(0, 4) ||
      service.substring(8) != characteristic.substring(8)) {
    return null;
  }
  return int.parse(characteristic.substring(4, 8), radix: 16);
}

/// Result of endpoint discovery.
final class EndpointMap {
  /// Creates a map of endpoint name to characteristic UUID.
  const new(this.characteristics, this.warnings);

  /// Endpoint name to lowercase 128-bit characteristic UUID.
  final Map<String, String> characteristics;

  /// Characteristics that could not be named (custom endpoints without a
  /// 0x2901 descriptor, or descriptor read failures).
  final List<String> warnings;
}

/// Names every characteristic of [service].
///
/// The 0x2901 user description is authoritative. Characteristics without
/// one (or whose read fails, e.g. on some web browsers) fall back to
/// [fallbackEndpointNames]; anything else is reported in
/// [EndpointMap.warnings] and stays unaddressable.
Future<EndpointMap> discoverEndpoints(
  BleService service,
  Future<Uint8List> Function(String characteristicUuid) readUserDescription,
) async {
  final named = <String, String>{};
  final unnamed = <String>[];
  final warnings = <String>[];
  for (final characteristic in service.characteristics) {
    final uuid = BleUuidParser.string(characteristic.uuid);
    final hasDescription = characteristic.descriptors.any(
      (d) => BleUuidParser.string(d.uuid) == userDescriptionUuid,
    );
    if (hasDescription) {
      try {
        final raw = await readUserDescription(uuid);
        final name = utf8
            .decode(raw, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim()
            .toLowerCase();
        if (name.isNotEmpty) {
          final existing = named[name];
          if (existing == null) {
            named[name] = uuid;
          } else {
            warnings.add(
              'Characteristic $uuid repeats endpoint name "$name" already '
              'mapped to $existing; ignoring it.',
            );
          }
          continue;
        }
      } on Object catch (e) {
        warnings.add('Reading the 0x2901 descriptor of $uuid failed: $e');
      }
    }
    unnamed.add(uuid);
  }
  for (final uuid in unnamed) {
    final id = endpointIdOf(service.uuid, uuid);
    final name = id == null ? null : fallbackEndpointNames[id];
    if (name == null) {
      warnings.add(
        'Characteristic $uuid has no endpoint name and no known fallback id; '
        'it is not addressable.',
      );
    } else if (named.containsKey(name)) {
      warnings.add(
        'Characteristic $uuid would be "$name" by its id but that name is '
        'already mapped to ${named[name]}; ignoring it.',
      );
    } else {
      named[name] = uuid;
    }
  }
  return EndpointMap(named, warnings);
}
