import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';

EndpointHandler _ctrl(pb.Status status, List<pb.NetworkCtrlMsgType> seen) =>
    (request) {
      final cmd = pb.NetworkCtrlPayload.fromBuffer(request);
      seen.add(cmd.msg);
      return pb.NetworkCtrlPayload(
        msg: pb.NetworkCtrlMsgType.valueOf(cmd.msg.value + 1),
        status: status,
      ).writeToBuffer();
    };

void main() {
  test('each command sends its message type', () async {
    final seen = <pb.NetworkCtrlMsgType>[];
    final session = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec']),
        handlers: {'prov-ctrl': _ctrl(pb.Status.Success, seen)},
      ),
    );
    await session.ctrl.resetWifi();
    await session.ctrl.reprovisionWifi();
    await session.ctrl.resetThread();
    await session.ctrl.reprovisionThread();
    expect(seen, [
      pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReset,
      pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReprov,
      pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReset,
      pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReprov,
    ]);
  });

  test('a failure status throws ProvStatusException', () async {
    final session = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec']),
        handlers: {'prov-ctrl': _ctrl(pb.Status.InternalError, [])},
      ),
    );
    await expectLater(
      session.ctrl.resetWifi(),
      throwsA(
        isA<ProvStatusException>().having(
          (e) => e.status,
          'status',
          ProvStatus.internalError,
        ),
      ),
    );
  });
}
