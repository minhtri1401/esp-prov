import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:test/test.dart';

DeviceInfo _info(int secVer, {Set<String> caps = const {}}) => DeviceInfo(
  version: 'v1.1',
  secVer: secVer,
  secPatchVer: 1,
  capabilities: caps,
);

void main() {
  test('Security 0 with no credentials', () {
    expect(selectScheme(_info(0), null), isA<Security0>());
  });

  test('Security 0 with a PoP is a SchemeMismatch', () {
    expect(
      () => selectScheme(_info(0), const ProvCredentials.pop('x')),
      throwsA(isA<SchemeMismatch>()),
    );
  });

  test('Security 1 with a PoP', () {
    expect(
      selectScheme(_info(1), const ProvCredentials.pop('abcd1234')),
      isA<Security1>(),
    );
  });

  test('Security 1 with no_pop needs no credentials and ignores a PoP', () {
    final info = _info(1, caps: {'no_pop'});
    expect(selectScheme(info, null), isA<Security1>());
    expect(
      selectScheme(info, const ProvCredentials.pop('ignored')),
      isA<Security1>(),
    );
  });

  test('Security 1 without no_pop and without a PoP', () {
    expect(
      () => selectScheme(_info(1), const ProvCredentials.none()),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('Security 2 with username/password', () {
    final scheme = selectScheme(
      _info(2),
      const ProvCredentials.security2(username: 'u', password: 'p'),
    );
    expect(scheme, isA<Security2>());
  });

  test('Security 2 with a PoP names what the device wants', () {
    expect(
      () => selectScheme(_info(2), const ProvCredentials.pop('abcd1234')),
      throwsA(
        isA<SchemeMismatch>()
            .having((e) => e.expected, 'expected', 2)
            .having(
              (e) => e.message,
              'message',
              contains('ProvCredentials.security2'),
            ),
      ),
    );
  });

  test('Security 2 with an empty password is MissingCredentials', () {
    expect(
      () => selectScheme(
        _info(2),
        const ProvCredentials.security2(username: 'u', password: ''),
      ),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('unknown scheme', () {
    expect(
      () => selectScheme(_info(3), null),
      throwsA(isA<UnsupportedCapability>()),
    );
  });

  test('Security 1 with security2 credentials is a SchemeMismatch', () {
    expect(
      () => selectScheme(
        _info(1),
        const ProvCredentials.security2(username: 'u', password: 'p'),
      ),
      throwsA(isA<SchemeMismatch>().having((e) => e.expected, 'expected', 1)),
    );
  });

  test('Security 1 with an empty PoP is MissingCredentials', () {
    expect(
      () => selectScheme(_info(1), const ProvCredentials.pop('')),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('Security 0 with security2 credentials is a SchemeMismatch', () {
    expect(
      () => selectScheme(
        _info(0),
        const ProvCredentials.security2(username: 'u', password: 'p'),
      ),
      throwsA(isA<SchemeMismatch>().having((e) => e.expected, 'expected', 0)),
    );
  });

  test('Security 2 with no credentials is MissingCredentials', () {
    expect(
      () => selectScheme(_info(2), null),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('Security 2 with an empty username is MissingCredentials', () {
    expect(
      () => selectScheme(
        _info(2),
        const ProvCredentials.security2(username: '', password: 'p'),
      ),
      throwsA(isA<MissingCredentials>()),
    );
  });
}
