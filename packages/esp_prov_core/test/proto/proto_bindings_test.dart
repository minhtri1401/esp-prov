import 'package:esp_prov_core/src/proto/constants.pb.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart';
import 'package:esp_prov_core/src/proto/network_constants.pb.dart';
import 'package:esp_prov_core/src/proto/sec1.pb.dart';
import 'package:esp_prov_core/src/proto/session.pb.dart';
import 'package:test/test.dart';

void main() {
  test('SessionData round-trips through bytes', () {
    final original = SessionData(
      secVer: SecSchemeVersion.SecScheme1,
      sec1: Sec1Payload(
        msg: Sec1MsgType.Session_Command1,
        sc1: SessionCmd1(clientVerifyData: [1, 2, 3]),
      ),
    );
    final decoded = SessionData.fromBuffer(original.writeToBuffer());
    expect(decoded.whichProto(), SessionData_Proto.sec1);
    expect(decoded.sec1.sc1.clientVerifyData, [1, 2, 3]);
  });

  test('Thread messages use the network_provisioning field numbers', () {
    final bytes = NetworkConfigPayload(
      msg: NetworkConfigMsgType.TypeCmdSetThreadConfig,
      cmdSetThreadConfig: CmdSetThreadConfig(dataset: [1]),
    ).writeToBuffer();
    // msg = 8 (field 1), cmd_set_thread_config = field 18 holding dataset [1].
    expect(bytes, [0x08, 0x08, 0x92, 0x01, 0x03, 0x0a, 0x01, 0x01]);
  });

  test('enum names are verbatim from the Espressif protos', () {
    expect(Status.InvalidSession.value, 7);
    expect(WifiConnectFailedReason.WifiNetworkNotFound.value, 1);
    expect(ThreadNetworkState.Dettached.value, 2);
    expect(WifiAuthMode.WPA2_WPA3_PSK.value, 7);
  });
}
