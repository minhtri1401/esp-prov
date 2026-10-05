part of 'security_scheme.dart';

/// Security 1: X25519 key exchange, optional proof of possession, and one
/// continuous AES-256-CTR keystream for the session.
final class Security1 extends SecurityScheme {
  /// Creates the scheme. [pop] may be null or empty when the firmware
  /// advertises the `no_pop` capability.
  new({String? pop}) : this._(pop, () => X25519().newKeyPair());

  /// Creates the scheme with a fixed client key pair (fixture tests only).
  @visibleForTesting
  new withKeyPair({
    required Future<SimpleKeyPair> Function() keyPair,
    String? pop,
  }) : this._(pop, keyPair);

  new _(this._pop, this._newKeyPair);

  final String? _pop;
  final Future<SimpleKeyPair> Function() _newKeyPair;
  AesCtrStream? _stream;

  @override
  int get version => 1;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final keyPair = await _newKeyPair();
    final clientPublic = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );

    final resp0 = await _exchange(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        // msg Session_Command0 is the proto3 default (0); leave it unset so the
        // bytes match esp_prov (protobuf.dart serialises explicit defaults).
        sec1: pb.Sec1Payload(sc0: pb.SessionCmd0(clientPubkey: clientPublic)),
      ),
    );
    _checkScheme(
      resp0,
      pb.SecSchemeVersion.SecScheme1,
      pb.SessionData_Proto.sec1,
    );
    if (!resp0.sec1.hasSr0()) {
      throw const HandshakeFailed('Security 1 response 0 has no payload');
    }
    final sr0 = resp0.sec1.sr0;
    _checkStatus(sr0.status, 'Security 1 key exchange');
    final devicePublic = Uint8List.fromList(sr0.devicePubkey);
    final deviceRandom = Uint8List.fromList(sr0.deviceRandom);
    if (devicePublic.length != 32 || deviceRandom.length != 16) {
      throw HandshakeFailed(
        'Security 1 response has a ${devicePublic.length}-byte public key '
        'and ${deviceRandom.length}-byte random; expected 32 and 16.',
      );
    }

    final shared = await X25519().sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(devicePublic, type: KeyPairType.x25519),
    );
    var key = Uint8List.fromList(await shared.extractBytes());
    final pop = _pop;
    if (pop != null && pop.isNotEmpty) {
      key = xorBytes(key, sha256.convert(utf8.encode(pop)).bytes);
    }
    final stream = AesCtrStream(key: key, iv: deviceRandom);

    final clientVerify = await stream.apply(devicePublic);
    final resp1 = await _exchangeProof(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Command1,
          sc1: pb.SessionCmd1(clientVerifyData: clientVerify),
        ),
      ),
      'proof of possession',
    );
    _checkScheme(
      resp1,
      pb.SecSchemeVersion.SecScheme1,
      pb.SessionData_Proto.sec1,
    );
    if (!resp1.sec1.hasSr1()) {
      throw const HandshakeFailed('Security 1 response 1 has no payload');
    }
    _checkStatus(resp1.sec1.sr1.status, 'Security 1 verification');
    final deviceVerify = await stream.apply(resp1.sec1.sr1.deviceVerifyData);
    if (!constantTimeEquals(deviceVerify, clientPublic)) {
      throw const PopMismatch(
        'The device verification data does not match. The proof of '
        'possession is wrong.',
      );
    }
    _stream = stream;
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) => _ready().apply(plain);

  @override
  Future<Uint8List> decrypt(Uint8List cipher) => _ready().apply(cipher);

  AesCtrStream _ready() =>
      _stream ?? (throw StateError('Security 1 handshake has not completed.'));
}
