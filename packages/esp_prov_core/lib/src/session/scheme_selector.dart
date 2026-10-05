import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';

/// Chooses the security scheme the firmware declared and checks that
/// [credentials] fit it.
SecurityScheme selectScheme(DeviceInfo info, ProvCredentials? credentials) {
  final provided = credentials ?? const ProvCredentials.none();
  final noPop = info.hasCapability('no_pop');
  return switch (info.secVer) {
    0 => switch (provided) {
      ProvNoCredentials() => Security0(),
      _ => throw SchemeMismatch(expected: 0, provided: provided.kind),
    },
    1 => switch (provided) {
      ProvSecurity2Credentials() => throw SchemeMismatch(
        expected: 1,
        provided: provided.kind,
      ),
      _ when noPop => Security1(),
      ProvPopCredentials(:final pop) when pop.isNotEmpty => Security1(pop: pop),
      _ => throw const MissingCredentials(
        'The device uses Security 1 with a proof of possession. '
        'Pass ProvCredentials.pop(...).',
      ),
    },
    2 => switch (provided) {
      ProvSecurity2Credentials(:final username, :final password)
          when username.isNotEmpty && password.isNotEmpty =>
        Security2(
          username: username,
          password: password,
          patchVersion: info.secPatchVer,
        ),
      ProvPopCredentials() => throw SchemeMismatch(
        expected: 2,
        provided: provided.kind,
      ),
      _ => throw const MissingCredentials(
        'The device uses Security 2. Pass '
        'ProvCredentials.security2(username: ..., password: ...).',
      ),
    },
    _ => throw UnsupportedCapability('security scheme ${info.secVer}'),
  };
}
