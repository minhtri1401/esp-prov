import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('PopMismatch is a HandshakeFailed', () {
    const error = PopMismatch('wrong pop');
    expect(error, isA<HandshakeFailed>());
    expect(error.status, ProvStatus.unknown);
    expect(error.toString(), 'PopMismatch: wrong pop');
  });

  test('SchemeMismatch tells the developer what the device wants', () {
    final error = SchemeMismatch(expected: 1, provided: 'no');
    expect(error.message, contains('ProvCredentials.pop'));
    expect(error.toString(), startsWith('SchemeMismatch: '));
  });

  test('UnknownEndpoint and ProvStatusException carry their data', () {
    expect(UnknownEndpoint('custom-data').endpoint, 'custom-data');
    final status = ProvStatusException(
      ProvStatus.invalidArgument,
      operation: 'Set Wi-Fi config',
    );
    expect(status.message, contains('invalidArgument'));
  });

  test('ProvStatus.fromValue maps wire values', () {
    expect(ProvStatus.fromValue(0), ProvStatus.success);
    expect(ProvStatus.fromValue(7), ProvStatus.invalidSession);
    expect(ProvStatus.fromValue(42), ProvStatus.unknown);
    expect(ProvStatus.fromValue(-1), ProvStatus.unknown);
  });
}
