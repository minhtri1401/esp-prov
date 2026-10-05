import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Control commands on the `prov-ctrl` endpoint.
///
/// Each method completes normally on success and throws
/// [ProvStatusException] on a non-success device status, or
/// [UnknownEndpoint] on firmware without `prov-ctrl`.
final class ProvCtrl {
  /// Creates the control client. Obtain one from `EspSession.ctrl`.
  new(this._session);

  final EspSession _session;

  /// Clears the Wi-Fi credentials and state machine after a failed attempt.
  Future<void> resetWifi() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReset,
      cmdCtrlWifiReset: pb.CmdCtrlWifiReset(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlWifiReset,
  );

  /// Lets an already provisioned device accept new Wi-Fi credentials.
  Future<void> reprovisionWifi() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReprov,
      cmdCtrlWifiReprov: pb.CmdCtrlWifiReprov(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlWifiReprov,
  );

  /// Clears the Thread dataset and state machine.
  Future<void> resetThread() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReset,
      cmdCtrlThreadReset: pb.CmdCtrlThreadReset(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlThreadReset,
  );

  /// Lets an already provisioned device accept a new Thread dataset.
  Future<void> reprovisionThread() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReprov,
      cmdCtrlThreadReprov: pb.CmdCtrlThreadReprov(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlThreadReprov,
  );
}
