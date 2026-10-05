import 'dart:typed_data';

/// Big-endian unsigned integer from [bytes].
BigInt bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b & 0xff);
  }
  return result;
}

/// Big-endian encoding of a non-negative [value].
///
/// Without [length] the result is minimal (no leading zero bytes, `[0]` for
/// zero), which matches mbedTLS `esp_mpi_to_bin` and Python `long_to_bytes`.
/// With [length] the result is left-padded with zeros to exactly [length]
/// bytes (the SRP `PAD()` operation).
Uint8List bigIntToBytes(BigInt value, {int? length}) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'must be non-negative');
  }
  final minimal = value == BigInt.zero ? 1 : (value.bitLength + 7) >> 3;
  final size = length ?? minimal;
  if (minimal > size && value != BigInt.zero) {
    throw ArgumentError.value(value, 'value', 'does not fit in $size bytes');
  }
  final out = Uint8List(size);
  var v = value;
  for (var i = size - 1; i >= 0 && v > BigInt.zero; i--) {
    out[i] = (v & _byteMask).toInt();
    v = v >> 8;
  }
  return out;
}

final BigInt _byteMask = BigInt.from(0xff);

/// Bytewise XOR of two equal-length lists.
Uint8List xorBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    throw ArgumentError('Length mismatch: ${a.length} != ${b.length}');
  }
  return Uint8List.fromList([for (var i = 0; i < a.length; i++) a[i] ^ b[i]]);
}

/// Comparison whose running time does not depend on where the lists differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Concatenates byte lists.
Uint8List concatBytes(List<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  parts.forEach(builder.add);
  return builder.takeBytes();
}

/// Lowercase hex encoding.
String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Decodes an even-length hex string.
Uint8List fromHex(String hex) {
  if (hex.length.isOdd) {
    throw FormatException('Odd-length hex string', hex);
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
