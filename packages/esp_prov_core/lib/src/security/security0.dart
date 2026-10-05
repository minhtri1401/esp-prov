part of 'security_scheme.dart';

/// Security 0: no encryption. Data is sent in plain text.
final class Security0 extends SecurityScheme {
  @override
  int get version => 0;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final response = await _exchange(
      transport,
      pb.SessionData(
        // sec_ver SecScheme0 and msg S0_Session_Command are the proto3
        // default (0) and are left unset; protobuf.dart would otherwise
        // serialise them, unlike esp_prov.
        sec0: pb.Sec0Payload(sc: pb.S0SessionCmd()),
      ),
    );
    _checkScheme(
      response,
      pb.SecSchemeVersion.SecScheme0,
      pb.SessionData_Proto.sec0,
    );
    if (!response.sec0.hasSr()) {
      throw const HandshakeFailed(
        'Security 0 response has no session response payload',
      );
    }
    _checkStatus(response.sec0.sr.status, 'Security 0 session setup');
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) async => plain;

  @override
  Future<Uint8List> decrypt(Uint8List cipher) async => cipher;
}
