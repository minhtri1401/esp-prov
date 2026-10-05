/// Credentials for the security scheme the device declares in `proto-ver`.
///
/// The library picks the scheme from the firmware; these only carry the
/// secrets. A kind that does not fit the firmware makes `EspSession.open`
/// throw `SchemeMismatch`.
sealed class ProvCredentials {
  const new();

  /// No credentials: Security 0, or Security 1 firmware with `no_pop`.
  const factory none() = ProvNoCredentials;

  /// Security 1 proof of possession.
  const factory pop(String pop) = ProvPopCredentials;

  /// Security 2 SRP-6a username and password.
  const factory security2({
    required String username,
    required String password,
  }) = ProvSecurity2Credentials;

  /// Short description used in error messages, e.g. `'proof of possession'`.
  String get kind;
}

/// See [ProvCredentials.none].
final class ProvNoCredentials extends ProvCredentials {
  /// Creates empty credentials.
  const new();

  @override
  String get kind => 'no';
}

/// See [ProvCredentials.pop].
final class ProvPopCredentials extends ProvCredentials {
  /// Creates proof-of-possession credentials.
  const new(this.pop);

  /// The proof of possession string printed by the firmware.
  final String pop;

  @override
  String get kind => 'proof of possession';

  @override
  String toString() => 'ProvCredentials.pop(<redacted>)';
}

/// See [ProvCredentials.security2].
final class ProvSecurity2Credentials extends ProvCredentials {
  /// Creates Security 2 credentials.
  const new({required this.username, required this.password});

  /// SRP-6a username (the firmware example uses `wifiprov`).
  final String username;

  /// SRP-6a password.
  final String password;

  @override
  String get kind => 'Security 2 username/password';

  @override
  String toString() =>
      'ProvCredentials.security2(username: $username, password: <redacted>)';
}
