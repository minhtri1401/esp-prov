import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/replay_transport.dart';

List<int> _resp(pb.Status status) => pb.SessionData(
  secVer: pb.SecSchemeVersion.SecScheme0,
  sec0: pb.Sec0Payload(
    msg: pb.Sec0MsgType.S0_Session_Response,
    sr: pb.S0SessionResp(status: status),
  ),
).writeToBuffer();

void main() {
  test('handshake sends S0SessionCmd and accepts Success', () async {
    final transport = ReplayTransport([
      Exchange('prov-session', null, _resp(pb.Status.Success)),
    ]);
    final scheme = Security0();
    await scheme.handshake(transport);

    final request = pb.SessionData.fromBuffer(transport.sent.single.$2);
    expect(request.secVer, pb.SecSchemeVersion.SecScheme0);
    expect(request.sec0.hasSc(), isTrue);
    expect(scheme.version, 0);
    expect(await scheme.encrypt(Uint8List.fromList([1, 2])), [1, 2]);
    expect(await scheme.decrypt(Uint8List.fromList([3])), [3]);
  });

  test('non-success status throws HandshakeFailed with the status', () async {
    final transport = ReplayTransport([
      Exchange('prov-session', null, _resp(pb.Status.InvalidSession)),
    ]);
    await expectLater(
      Security0().handshake(transport),
      throwsA(
        isA<HandshakeFailed>().having(
          (e) => e.status,
          'status',
          ProvStatus.invalidSession,
        ),
      ),
    );
  });
}
