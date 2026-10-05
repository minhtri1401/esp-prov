import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256, sha512;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec1.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec2.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;

/// Handles one decrypted request on an application endpoint and returns the
/// plaintext response.
typedef EndpointHandler = FutureOr<List<int>> Function(Uint8List request);

/// A simulated provisioning device implementing the device side of
/// Security 0, 1 and 2 like ESP-IDF protocomm. When the client proof is
/// wrong it drops the link, as the firmware does.
final class FakeDevice implements ProvTransport {
  /// Creates a device that reports [protoVer] on `proto-ver`.
  new({
    required this.protoVer,
    this.pop = '',
    this.username = 'wifiprov',
    this.password = 'abcd1234',
    Set<String> extraEndpoints = const {},
    Map<String, EndpointHandler>? handlers,
  }) : endpoints = {
         ProvEndpoints.protoVer,
         ProvEndpoints.session,
         ProvEndpoints.config,
         ProvEndpoints.scan,
         ProvEndpoints.ctrl,
         ...extraEndpoints,
       },
       handlers = handlers ?? {};

  /// JSON (or legacy plain string) returned by `proto-ver`.
  final String protoVer;

  /// Security 1 proof of possession the device expects.
  final String pop;

  /// Security 2 username the device's verifier was made for.
  final String username;

  /// Security 2 password the device's verifier was made for.
  final String password;

  /// Handlers for encrypted endpoints, keyed by endpoint name.
  final Map<String, EndpointHandler> handlers;

  @override
  final Set<String> endpoints;

  /// Decrypted application requests in arrival order.
  final List<(String, Uint8List)> plainRequests = [];

  /// Number of `prov-session` messages received.
  int sessionMessages = 0;

  /// Number of [disconnect] calls.
  int disconnectCalls = 0;

  final _random = Random(7);
  final _disconnects = StreamController<void>.broadcast();
  bool _connected = true;

  late final DeviceInfo _info = DeviceInfo.parse(protoVer);
  late AesCtrStream _ctr;
  late AesGcmCounter _gcm;
  late Uint8List _devicePublic;
  late Uint8List _clientPublic;
  late BigInt _b;
  late BigInt _v;
  late Uint8List _salt;
  late Uint8List _bBytes;
  late String _clientUsername;

  /// Whether the link is up.
  bool get isConnected => _connected;

  @override
  Stream<void> get onDisconnected => _disconnects.stream;

  /// Simulates the link dropping (firmware auto-stop, out of range, ...).
  void dropLink() {
    if (!_connected) return;
    _connected = false;
    _disconnects.add(null);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    dropLink();
  }

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) async {
    if (!_connected) throw const DeviceDisconnected();
    if (endpoint == ProvEndpoints.protoVer) {
      return Uint8List.fromList(utf8.encode(protoVer));
    }
    if (endpoint == ProvEndpoints.session) {
      sessionMessages++;
      final response = await _session(pb.SessionData.fromBuffer(request));
      return response.writeToBuffer();
    }
    final plain = await _decrypt(request);
    plainRequests.add((endpoint, plain));
    final handler = handlers[endpoint];
    if (handler == null) {
      throw TransportException('No handler for $endpoint');
    }
    final response = await handler(plain);
    if (!_connected) throw const DeviceDisconnected();
    return await _encrypt(Uint8List.fromList(response));
  }

  Future<Uint8List> _decrypt(Uint8List data) => switch (_info.secVer) {
    1 => _ctr.apply(data),
    2 => _gcm.decrypt(data),
    _ => Future.value(data),
  };

  Future<Uint8List> _encrypt(Uint8List data) => switch (_info.secVer) {
    1 => _ctr.apply(data),
    2 => _gcm.encrypt(data),
    _ => Future.value(data),
  };

  Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  Never _rejectProof() {
    // protocomm_ble: "Invalid content received, killing connection".
    dropLink();
    throw const DeviceDisconnected();
  }

  Future<pb.SessionData> _session(pb.SessionData req) async {
    switch (req.whichProto()) {
      case pb.SessionData_Proto.sec0:
        return pb.SessionData(
          secVer: pb.SecSchemeVersion.SecScheme0,
          sec0: pb.Sec0Payload(
            msg: pb.Sec0MsgType.S0_Session_Response,
            sr: pb.S0SessionResp(status: pb.Status.Success),
          ),
        );
      case pb.SessionData_Proto.sec1:
        return await _sec1(req.sec1);
      case pb.SessionData_Proto.sec2:
        return _sec2(req.sec2);
      case pb.SessionData_Proto.notSet:
        throw const TransportException('empty SessionData');
    }
  }

  Future<pb.SessionData> _sec1(pb.Sec1Payload payload) async {
    if (payload.hasSc0()) {
      final keyPair = await X25519().newKeyPair();
      _devicePublic = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      _clientPublic = Uint8List.fromList(payload.sc0.clientPubkey);
      final shared = await X25519().sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(
          _clientPublic,
          type: KeyPairType.x25519,
        ),
      );
      var key = Uint8List.fromList(await shared.extractBytes());
      if (pop.isNotEmpty) {
        key = xorBytes(key, sha256.convert(utf8.encode(pop)).bytes);
      }
      final random = _randomBytes(16);
      _ctr = AesCtrStream(key: key, iv: random);
      return pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Response0,
          sr0: pb.SessionResp0(
            status: pb.Status.Success,
            devicePubkey: _devicePublic,
            deviceRandom: random,
          ),
        ),
      );
    }
    final check = await _ctr.apply(payload.sc1.clientVerifyData);
    if (!constantTimeEquals(check, _devicePublic)) _rejectProof();
    final verify = await _ctr.apply(_clientPublic);
    return pb.SessionData(
      secVer: pb.SecSchemeVersion.SecScheme1,
      sec1: pb.Sec1Payload(
        msg: pb.Sec1MsgType.Session_Response1,
        sr1: pb.SessionResp1(
          status: pb.Status.Success,
          deviceVerifyData: verify,
        ),
      ),
    );
  }

  Uint8List _h(List<List<int>> parts) =>
      Uint8List.fromList(sha512.convert(concatBytes(parts)).bytes);

  pb.SessionData _sec2(pb.Sec2Payload payload) {
    final n = Srp6aClient.n;
    final g = Srp6aClient.g;
    const len = Srp6aClient.nLength;
    if (payload.hasSc0()) {
      _clientUsername = utf8.decode(payload.sc0.clientUsername);
      _clientPublic = Uint8List.fromList(payload.sc0.clientPubkey);
      final salt = _randomBytes(16);
      final inner = _h([utf8.encode('$username:$password')]);
      final x = bytesToBigInt(_h([salt, inner]));
      final v = g.modPow(x, n);
      final b = bytesToBigInt(_randomBytes(32));
      final bigB = (Srp6aClient.k * v + g.modPow(b, n)) % n;
      _salt = salt;
      _v = v;
      _b = b;
      _bBytes = bigIntToBytes(bigB);
      return pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        sec2: pb.Sec2Payload(
          msg: pb.Sec2MsgType.S2Session_Response0,
          sr0: pb.S2SessionResp0(
            status: pb.Status.Success,
            devicePubkey: _bBytes,
            deviceSalt: salt,
          ),
        ),
      );
    }
    final aBytes = _clientPublic;
    final bigA = bytesToBigInt(aBytes);
    final u = bytesToBigInt(
      _h([
        bigIntToBytes(bigA, length: len),
        bigIntToBytes(bytesToBigInt(_bBytes), length: len),
      ]),
    );
    final s = (bigA * _v.modPow(u, n) % n).modPow(_b, n);
    final key = _h([bigIntToBytes(s)]);
    final hN = _h([bigIntToBytes(n, length: len)]);
    final hG = _h([bigIntToBytes(g, length: len)]);
    final m1 = _h([
      xorBytes(hN, hG),
      _h([utf8.encode(_clientUsername)]),
      _salt,
      aBytes,
      _bBytes,
      key,
    ]);
    if (!constantTimeEquals(m1, payload.sc1.clientProof)) _rejectProof();
    final m2 = _h([aBytes, m1, key]);
    final nonce = Uint8List.fromList([..._randomBytes(8), 0, 0, 0, 1]);
    _gcm = AesGcmCounter(
      key: key.sublist(0, 32),
      nonce: nonce,
      incrementNonce: _info.secPatchVer >= 1,
    );
    return pb.SessionData(
      secVer: pb.SecSchemeVersion.SecScheme2,
      sec2: pb.Sec2Payload(
        msg: pb.Sec2MsgType.S2Session_Response1,
        sr1: pb.S2SessionResp1(
          status: pb.Status.Success,
          deviceProof: m2,
          deviceNonce: nonce,
        ),
      ),
    );
  }
}

/// `proto-ver` JSON for a typical device.
String protoVerJson({
  required int secVer,
  int? secPatchVer,
  List<String> caps = const ['wifi_scan', 'wifi_prov'],
  String ver = 'v1.1',
}) => jsonEncode({
  'prov': {
    'ver': ver,
    'sec_ver': secVer,
    'sec_patch_ver': ?secPatchVer,
    'cap': caps,
  },
});
