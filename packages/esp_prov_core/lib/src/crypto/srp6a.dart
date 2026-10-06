import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';

/// Output of the client side of the SRP-6a exchange.
final class Srp6aProof {
  /// Creates a proof bundle.
  const new({
    required this.clientProof,
    required this.expectedServerProof,
    required this.sessionKey,
  });

  /// M1, sent to the device in `S2SessionCmd1.client_proof`.
  final Uint8List clientProof;

  /// M2 the device must return in `S2SessionResp1.device_proof`.
  final Uint8List expectedServerProof;

  /// K = H(S), 64 bytes. The AES-GCM key is its first 32 bytes.
  final Uint8List sessionKey;
}

/// SRP-6a exactly as ESP-IDF `esp_srp.c` (device) and esp_prov `srp6a.py`
/// (host) implement it: RFC 5054 3072-bit group, g = 5, SHA-512.
///
/// Byte conventions (verified against esp_srp.c):
/// * `PAD(x)` = x left-padded with zeros to 384 bytes. Used for N and g in
///   k, for A and B in u, and for g in H(g).
/// * `x = H(s | H(I ":" p))` with the salt bytes exactly as the device sent
///   them and the full 64-byte inner digest.
/// * `K = H(S)` with S in minimal big-endian form (no padding).
/// * `M1 = H(H(N) xor H(PAD(g)) | H(I) | s | A | B | K)` with A as sent
///   (always 384 bytes) and B exactly as the device sent it.
/// * `M2 = H(A | M1 | K)`.
abstract final class Srp6aClient {
  /// RFC 5054 3072-bit prime N.
  static final BigInt n = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33'
    'A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7'
    'ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864'
    'D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E2'
    '08E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF',
    radix: 16,
  );

  /// Generator g = 5.
  static final BigInt g = BigInt.from(5);

  /// Byte length of N; A must serialise to exactly this many bytes.
  static const nLength = 384;

  /// Multiplier k = H(N | PAD(g)).
  static final BigInt k = bytesToBigInt(
    _h([bigIntToBytes(n, length: nLength), bigIntToBytes(g, length: nLength)]),
  );

  /// A random 256-bit private exponent with the top bit set, like esp_prov.
  static BigInt randomPrivateKey([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
    bytes[0] |= 0x80;
    return bytesToBigInt(bytes);
  }

  /// A = g^a mod N as exactly [nLength] bytes, or `null` when A has a leading
  /// zero byte. The device hashes A as received while esp_prov re-encodes it
  /// minimally, so callers must pick a new `a` when this returns `null`.
  static Uint8List? publicKey(BigInt a) {
    final bigA = g.modPow(a, n);
    if ((bigA.bitLength + 7) >> 3 != nLength) return null;
    return bigIntToBytes(bigA, length: nLength);
  }

  /// Computes the proofs and session key. CPU-heavy: run via `offload`.
  ///
  /// Throws [HandshakeFailed] when `B % N == 0` or `u == 0`.
  static Srp6aProof computeProof({
    required String username,
    required String password,
    required BigInt a,
    required Uint8List clientPublicKey,
    required Uint8List salt,
    required Uint8List serverPublicKey,
  }) {
    final bigB = bytesToBigInt(serverPublicKey);
    if (bigB % n == BigInt.zero) {
      throw const HandshakeFailed('Device sent an invalid SRP public key.');
    }
    if (serverPublicKey.length > nLength) {
      throw const HandshakeFailed('Device SRP public key is too long.');
    }
    final u = bytesToBigInt(
      _h([
        bigIntToBytes(bytesToBigInt(clientPublicKey), length: nLength),
        bigIntToBytes(bigB, length: nLength),
      ]),
    );
    if (u == BigInt.zero) {
      throw const HandshakeFailed('SRP scrambling parameter u is zero.');
    }

    final user = utf8.encode(username);
    final inner = _h([user, utf8.encode(':'), utf8.encode(password)]);
    final x = bytesToBigInt(_h([salt, inner]));
    final v = g.modPow(x, n);
    final base = (bigB - k * v % n) % n;
    final s = base.modPow(a + u * x, n);
    final sessionKey = _h([bigIntToBytes(s)]);

    final hN = _h([bigIntToBytes(n, length: nLength)]);
    final hG = _h([bigIntToBytes(g, length: nLength)]);
    final m1 = _h([
      xorBytes(hN, hG),
      _h([user]),
      salt,
      clientPublicKey,
      serverPublicKey,
      sessionKey,
    ]);
    final m2 = _h([clientPublicKey, m1, sessionKey]);
    return Srp6aProof(
      clientProof: m1,
      expectedServerProof: m2,
      sessionKey: sessionKey,
    );
  }

  static Uint8List _h(List<List<int>> parts) =>
      Uint8List.fromList(sha512.convert(concatBytes(parts)).bytes);
}
