import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('factories build the sealed subtypes', () {
    expect(const ProvCredentials.none(), isA<ProvNoCredentials>());
    expect(
      const ProvCredentials.pop('abcd1234'),
      isA<ProvPopCredentials>().having((c) => c.pop, 'pop', 'abcd1234'),
    );
    expect(
      const ProvCredentials.security2(username: 'u', password: 'p'),
      isA<ProvSecurity2Credentials>()
          .having((c) => c.username, 'username', 'u')
          .having((c) => c.password, 'password', 'p'),
    );
  });

  test('credentials toString never prints secrets', () {
    expect(
      const ProvCredentials.security2(
        username: 'u',
        password: 'hunter2',
      ).toString(),
      isNot(contains('hunter2')),
    );
    expect(
      const ProvCredentials.pop('hunter2').toString(),
      isNot(contains('hunter2')),
    );
  });
}
