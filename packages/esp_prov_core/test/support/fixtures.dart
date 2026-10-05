import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_prov_core/src/crypto/bytes.dart';

/// Loads `test/fixtures/<name>` produced by tool/gen_fixtures.py.
///
/// `dart test` runs with the package root as the working directory.
Map<String, Object?> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// Reads a hex field from a fixture map.
Uint8List hexField(Map<String, Object?> fixture, String key) =>
    fromHex(fixture[key]! as String);

/// Reads the list of message maps under [key].
List<Map<String, Object?>> messages(
  Map<String, Object?> fixture, [
  String key = 'messages',
]) => (fixture[key]! as List<Object?>).cast<Map<String, Object?>>();
