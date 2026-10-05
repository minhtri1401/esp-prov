import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/offload.dart';
import 'package:test/test.dart';

void main() {
  test('returns the computation result', () async {
    final base = BigInt.from(5);
    expect(await offload(() => base.pow(3)), BigInt.from(125));
  });

  test('keeps the error type thrown inside the computation', () async {
    await expectLater(
      offload<int>(() => throw const HandshakeFailed('u == 0')),
      throwsA(isA<HandshakeFailed>()),
    );
  });
}
