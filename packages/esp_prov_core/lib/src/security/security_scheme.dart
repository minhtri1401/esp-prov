import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/offload.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec1.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec2.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

part 'security0.dart';
part 'security1.dart';
part 'security2.dart';

/// A protocomm security scheme: handshake on `prov-session`, then a
/// stateful cipher for every later request and response.
///
/// Encryption is asynchronous because cryptography_plus is. Calls must be
/// made in protocol order; `EspSession` serialises them.
sealed class SecurityScheme {
  /// Security version number as reported in `proto-ver` (`sec_ver`).
  int get version;

  /// Runs the handshake over [transport] on the `prov-session` endpoint.
  Future<void> handshake(ProvTransport transport);

  /// Encrypts a request body.
  Future<Uint8List> encrypt(Uint8List plain);

  /// Decrypts a response body.
  Future<Uint8List> decrypt(Uint8List cipher);
}

/// Sends one handshake message and parses the device's `SessionData` reply.
Future<pb.SessionData> _exchange(
  ProvTransport transport,
  pb.SessionData request,
) async {
  final response = await transport.send(
    ProvEndpoints.session,
    request.writeToBuffer(),
  );
  try {
    return pb.SessionData.fromBuffer(response);
  } on InvalidProtocolBufferException catch (e) {
    throw HandshakeFailed('Malformed prov-session response: ${e.message}');
  }
}

/// Throws [HandshakeFailed] unless [status] is `Success`.
void _checkStatus(pb.Status status, String step) {
  if (status != pb.Status.Success) {
    throw HandshakeFailed(
      '$step failed with device status ${status.name}.',
      status: ProvStatus.fromValue(status.value),
    );
  }
}

/// Throws [HandshakeFailed] unless the device answered with
/// [expectedVersion] and the [expectedProto] payload.
void _checkScheme(
  pb.SessionData response,
  pb.SecSchemeVersion expectedVersion,
  pb.SessionData_Proto expectedProto,
) {
  if (response.secVer != expectedVersion ||
      response.whichProto() != expectedProto) {
    throw HandshakeFailed(
      'Device answered with ${response.secVer.name} and payload '
      '${response.whichProto().name}, expected ${expectedVersion.name} and '
      '${expectedProto.name}.',
    );
  }
}

/// Runs the proof step of a handshake. The firmware closes the BLE link when
/// it rejects a proof, so a transport failure here means a wrong PoP or
/// password rather than a radio problem.
Future<pb.SessionData> _exchangeProof(
  ProvTransport transport,
  pb.SessionData request,
  String what,
) async {
  try {
    return await _exchange(transport, request);
  } on TransportException catch (e) {
    throw PopMismatch(
      'The device dropped the session after receiving the $what '
      '(${e.message}). The $what is most likely wrong.',
    );
  } on DeviceDisconnected {
    throw PopMismatch(
      'The device disconnected after receiving the $what. '
      'The $what is most likely wrong.',
    );
  }
}
