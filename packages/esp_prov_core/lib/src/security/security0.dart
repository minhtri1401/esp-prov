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
        secVer: pb.SecSchemeVersion.SecScheme0,
        // msg S0_Session_Command is the proto3 default (0) and is left unset;
        // protobuf.dart would otherwise serialise it, unlike esp_prov.
        sec0: pb.Sec0Payload(sc: pb.S0SessionCmd()),
      ),
    );
    _checkScheme(response, pb.SecSchemeVersion.SecScheme0);
    _checkStatus(response.sec0.sr.status, 'Security 0 session setup');
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) async => plain;

  @override
  Future<Uint8List> decrypt(Uint8List cipher) async => cipher;
}
