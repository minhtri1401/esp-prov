part of 'security_scheme.dart';

/// Security 2: SRP-6a (3072-bit, SHA-512) authentication and AES-256-GCM.
final class Security2 extends SecurityScheme {
  /// Creates the scheme for [username]/[password]. [patchVersion] is the
  /// firmware `sec_patch_ver` and selects the nonce rule (see
  /// [AesGcmCounter]).
  new({
    required String username,
    required String password,
    required int patchVersion,
  }) : this._(username, password, patchVersion, Srp6aClient.randomPrivateKey);

  /// Creates the scheme with a deterministic private key source (fixture
  /// tests only).
  @visibleForTesting
  new withPrivateKeys({
    required String username,
    required String password,
    required int patchVersion,
    required BigInt Function() nextPrivateKey,
  }) : this._(username, password, patchVersion, nextPrivateKey);

  new _(
    this._username,
    this._password,
    this._patchVersion,
    this._nextPrivateKey,
  );

  static const _maxRerolls = 10000;

  final String _username;
  final String _password;
  final int _patchVersion;
  final BigInt Function() _nextPrivateKey;
  AesGcmCounter? _cipher;

  @override
  int get version => 2;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final (a, clientPublic) = await _newEphemeral();

    final resp0 = await _exchange(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        // msg S2Session_Command0 is the proto3 default (0); leave it unset
        // so the bytes match esp_prov (protobuf.dart writes set defaults).
        sec2: pb.Sec2Payload(
          sc0: pb.S2SessionCmd0(
            clientUsername: utf8.encode(_username),
            clientPubkey: clientPublic,
          ),
        ),
      ),
    );
    _checkScheme(
      resp0,
      pb.SecSchemeVersion.SecScheme2,
      pb.SessionData_Proto.sec2,
    );
    if (!resp0.sec2.hasSr0()) {
      throw const HandshakeFailed('Security 2 response 0 has no payload');
    }
    final sr0 = resp0.sec2.sr0;
    _checkStatus(sr0.status, 'Security 2 key exchange');
    final serverPublic = Uint8List.fromList(sr0.devicePubkey);
    final salt = Uint8List.fromList(sr0.deviceSalt);
    if (serverPublic.isEmpty || salt.isEmpty) {
      throw const HandshakeFailed('Security 2 response is missing B or salt.');
    }

    final username = _username;
    final password = _password;
    final proof = await offload(
      () => Srp6aClient.computeProof(
        username: username,
        password: password,
        a: a,
        clientPublicKey: clientPublic,
        salt: salt,
        serverPublicKey: serverPublic,
      ),
    );

    final resp1 = await _exchangeProof(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        sec2: pb.Sec2Payload(
          msg: pb.Sec2MsgType.S2Session_Command1,
          sc1: pb.S2SessionCmd1(clientProof: proof.clientProof),
        ),
      ),
      'username and password',
    );
    _checkScheme(
      resp1,
      pb.SecSchemeVersion.SecScheme2,
      pb.SessionData_Proto.sec2,
    );
    if (!resp1.sec2.hasSr1()) {
      throw const HandshakeFailed('Security 2 response 1 has no payload');
    }
    final sr1 = resp1.sec2.sr1;
    _checkStatus(sr1.status, 'Security 2 verification');
    if (!constantTimeEquals(sr1.deviceProof, proof.expectedServerProof)) {
      throw const PopMismatch(
        'The device proof does not verify. The username or password is '
        'wrong, or the device is not the one you expect.',
      );
    }
    if (sr1.deviceNonce.length != 12) {
      throw HandshakeFailed(
        'Device nonce has ${sr1.deviceNonce.length} bytes; expected 12.',
      );
    }
    _cipher = AesGcmCounter(
      key: proof.sessionKey.sublist(0, 32),
      nonce: sr1.deviceNonce,
      incrementNonce: _patchVersion >= 1,
    );
  }

  /// Picks `a` until A = g^a mod N serialises to exactly 384 bytes.
  Future<(BigInt, Uint8List)> _newEphemeral() async {
    for (var i = 0; i < _maxRerolls; i++) {
      final a = _nextPrivateKey();
      final publicKey = await offload(() => Srp6aClient.publicKey(a));
      if (publicKey != null) return (a, publicKey);
    }
    throw const HandshakeFailed('Could not generate a full-length SRP key.');
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) => _ready().encrypt(plain);

  @override
  Future<Uint8List> decrypt(Uint8List cipher) => _ready().decrypt(cipher);

  AesGcmCounter _ready() =>
      _cipher ?? (throw StateError('Security 2 handshake has not completed.'));
}
