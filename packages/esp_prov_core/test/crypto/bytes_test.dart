import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

void main() {
  group('bigIntToBytes', () {
    test('is minimal without a length', () {
      expect(bigIntToBytes(BigInt.from(0x0102)), [1, 2]);
      expect(bigIntToBytes(BigInt.zero), [0]);
    });

    test('left-pads to the requested length (PAD)', () {
      expect(bigIntToBytes(BigInt.from(5), length: 4), [0, 0, 0, 5]);
    });

    test('rejects values that do not fit', () {
      expect(
        () => bigIntToBytes(BigInt.from(0x010000), length: 2),
        throwsArgumentError,
      );
    });
  });

  test('bytesToBigInt ignores leading zeros', () {
    expect(bytesToBigInt([0, 0, 1, 0]), BigInt.from(256));
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  test('hex round trip', () {
    expect(toHex(fromHex('00ff10')), '00ff10');
  });
}
