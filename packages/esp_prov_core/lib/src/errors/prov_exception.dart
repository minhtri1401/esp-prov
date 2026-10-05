import 'package:esp_prov_core/src/errors/prov_status.dart';

/// Base class of every error this library throws on purpose.
///
/// Switch over it exhaustively to give users a precise message.
sealed class ProvException implements Exception {
  const new(this.message);

  /// Human-readable description, safe to show in logs.
  final String message;

  @override
  String toString() {
    final name = switch (this) {
      TransportException() => 'TransportException',
      DeviceDisconnected() => 'DeviceDisconnected',
      UnknownEndpoint() => 'UnknownEndpoint',
      UnsupportedCapability() => 'UnsupportedCapability',
      SchemeMismatch() => 'SchemeMismatch',
      MissingCredentials() => 'MissingCredentials',
      PopMismatch() => 'PopMismatch',
      HandshakeFailed() => 'HandshakeFailed',
      CryptoException() => 'CryptoException',
      ProvStatusException() => 'ProvStatusException',
    };
    return '$name: $message';
  }
}

/// The transport failed: BLE error, timeout, or an unusable session.
final class TransportException extends ProvException {
  /// Creates a transport failure with an optional underlying [cause].
  const new(super.message, {this.cause});

  /// The platform error that triggered this exception, if any.
  final Object? cause;
}

/// The link to the device dropped.
final class DeviceDisconnected extends ProvException {
  /// Creates a disconnect error.
  const new([super.message = 'The device disconnected.']);
}

/// The device does not expose the requested protocomm endpoint.
final class UnknownEndpoint extends ProvException {
  /// Creates an error for the missing [endpoint].
  new(this.endpoint)
    : super('Endpoint "$endpoint" was not discovered on the device.');

  /// The endpoint name that was requested.
  final String endpoint;
}

/// The device firmware does not advertise a capability the call needs.
final class UnsupportedCapability extends ProvException {
  /// Creates an error for the missing [capability].
  new(this.capability) : super('The device does not support "$capability".');

  /// The capability that is missing, e.g. `thread_prov`.
  final String capability;
}

/// The credentials kind does not match the security scheme of the device.
final class SchemeMismatch extends ProvException {
  /// Creates a mismatch between the device's [expected] security version and
  /// the [provided] credentials kind.
  new({required this.expected, required this.provided})
    : super(
        'The device uses Security $expected and needs '
        '${_hint(expected)}, but $provided credentials were provided.',
      );

  /// Security version the device declared in `proto-ver`.
  final int expected;

  /// Description of the credentials the caller passed.
  final String provided;

  static String _hint(int secVer) => switch (secVer) {
    0 => 'ProvCredentials.none()',
    1 => 'ProvCredentials.pop(...)',
    2 => 'ProvCredentials.security2(username: ..., password: ...)',
    _ => 'an unsupported scheme',
  };
}

/// The device needs credentials and none (or not enough) were provided.
final class MissingCredentials extends ProvException {
  /// Creates a missing-credentials error.
  const new(super.message);
}

/// The security handshake on `prov-session` failed.
final class HandshakeFailed extends ProvException {
  /// Creates a handshake failure with the device [status], if one was sent.
  const new(super.message, {this.status = ProvStatus.unknown});

  /// Status reported by the device, or [ProvStatus.unknown].
  final ProvStatus status;
}

/// The device rejected the proof of possession (Security 1) or the
/// username/password proof (Security 2), or its own proof did not verify.
final class PopMismatch extends HandshakeFailed {
  /// Creates a proof mismatch error.
  const new(super.message, {super.status});
}

/// Encryption or decryption failed, e.g. an AES-GCM tag mismatch.
final class CryptoException extends ProvException {
  /// Creates a crypto failure.
  const new(super.message);
}

/// The device answered a request with a non-success status.
final class ProvStatusException extends ProvException {
  /// Creates an error for [status] returned while running [operation].
  new(this.status, {required String operation})
    : super('$operation failed with device status ${status.name}.');

  /// The status the device returned.
  final ProvStatus status;
}
