import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('a rejected payload does not leak the pop into the exception', () {
    expect(
      () => ProvQrPayload.parse('{"ver":"v1","pop":"s3cr3t-pop-value"}'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.toString(),
          'toString',
          isNot(contains('s3cr3t-pop-value')),
        ),
      ),
    );
  });

  test('stock Security 2 QR: password travels in "pop"', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov",'
      '"pop":"abcd1234","transport":"ble"}',
    );
    expect(qr.name, 'PROV_1A2B3C');
    expect(qr.isBle, isTrue);
    expect(qr.security, isNull);
    expect(
      qr.credentials,
      isA<ProvSecurity2Credentials>()
          .having((c) => c.username, 'username', 'wifiprov')
          .having((c) => c.password, 'password', 'abcd1234'),
    );
  });

  test('stock Security 1 QR gives a PoP', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","pop":"abcd1234","transport":"ble"}',
    );
    expect(
      qr.credentials,
      isA<ProvPopCredentials>().having((c) => c.pop, 'pop', 'abcd1234'),
    );
  });

  test('QR without secrets gives no credentials', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","transport":"softap"}',
    );
    expect(qr.credentials, isA<ProvNoCredentials>());
    expect(qr.isBle, isFalse);
  });

  test('explicit security and password fields win', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"P","security":2,"username":"u",'
      '"password":"secret","pop":"other","network":"thread"}',
    );
    expect(qr.security, 2);
    expect(qr.network, 'thread');
    expect((qr.credentials as ProvSecurity2Credentials).password, 'secret');
  });

  test('explicit security 0 and 1 override inference', () {
    final none = ProvQrPayload.parse(
      '{"name":"P","security":0,"username":"u","pop":"x"}',
    );
    expect(none.credentials, isA<ProvNoCredentials>());
    final one = ProvQrPayload.parse(
      '{"name":"P","security":1,"username":"u","pop":"x"}',
    );
    expect(
      one.credentials,
      isA<ProvPopCredentials>().having((c) => c.pop, 'pop', 'x'),
    );
  });

  test('transport check is case-insensitive', () {
    final qr = ProvQrPayload.parse('{"name":"P","transport":"BLE"}');
    expect(qr.isBle, isTrue);
  });

  test('invalid payloads throw FormatException', () {
    expect(() => ProvQrPayload.parse('not json'), throwsFormatException);
    expect(() => ProvQrPayload.parse('[1,2]'), throwsFormatException);
    expect(
      () => ProvQrPayload.parse('{"ver":"v1","pop":"x"}'),
      throwsFormatException,
    );
    expect(() => ProvQrPayload.parse('{"name":""}'), throwsFormatException);
  });
}
