import 'dart:typed_data';

import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;

import 'fake_device.dart';

/// A `prov-scan` handler that reports [wifi] / [thread] results after
/// [pollsUntilFinished] status polls and serves them in pages.
/// [maxPerPage] lets a test make the device return fewer entries than asked.
EndpointHandler scanHandler({
  List<pb.WiFiScanResult> wifi = const [],
  List<pb.ThreadScanResult> thread = const [],
  int pollsUntilFinished = 1,
  int? maxPerPage,
  List<(int, int)>? pageLog,
}) {
  var polls = 0;
  return (Uint8List request) {
    final cmd = pb.NetworkScanPayload.fromBuffer(request);
    pb.NetworkScanPayload reply(pb.NetworkScanMsgType msg) =>
        pb.NetworkScanPayload(msg: msg, status: pb.Status.Success);
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiStart) {
      return reply(pb.NetworkScanMsgType.TypeRespScanWifiStart).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadStart) {
      return reply(pb.NetworkScanMsgType.TypeRespScanThreadStart)
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiStatus) {
      polls++;
      return (reply(pb.NetworkScanMsgType.TypeRespScanWifiStatus)
            ..respScanWifiStatus = pb.RespScanWifiStatus(
              scanFinished: polls >= pollsUntilFinished,
              resultCount: wifi.length,
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadStatus) {
      polls++;
      return (reply(pb.NetworkScanMsgType.TypeRespScanThreadStatus)
            ..respScanThreadStatus = pb.RespScanThreadStatus(
              scanFinished: polls >= pollsUntilFinished,
              resultCount: thread.length,
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiResult) {
      final r = cmd.cmdScanWifiResult;
      pageLog?.add((r.startIndex, r.count));
      final end = (r.startIndex + (maxPerPage ?? r.count)).clamp(
        0,
        wifi.length,
      );
      return (reply(pb.NetworkScanMsgType.TypeRespScanWifiResult)
            ..respScanWifiResult = pb.RespScanWifiResult(
              entries: wifi.sublist(r.startIndex, end),
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadResult) {
      final r = cmd.cmdScanThreadResult;
      final end = (r.startIndex + r.count).clamp(0, thread.length);
      return (reply(pb.NetworkScanMsgType.TypeRespScanThreadResult)
            ..respScanThreadResult = pb.RespScanThreadResult(
              entries: thread.sublist(r.startIndex, end),
            ))
          .writeToBuffer();
    }
    throw StateError('unexpected scan command ${cmd.msg}');
  };
}

/// A `prov-config` handler that accepts set/apply and answers each status
/// poll with the next entry of [wifiStatuses] / [threadStatuses] (the last
/// entry repeats). [setStatus] is returned for the set-config command.
EndpointHandler configHandler({
  List<pb.RespGetWifiStatus> wifiStatuses = const [],
  List<pb.RespGetThreadStatus> threadStatuses = const [],
  pb.Status setStatus = pb.Status.Success,
  void Function(pb.NetworkConfigPayload command)? onCommand,
}) {
  var wifiIndex = 0;
  var threadIndex = 0;
  return (Uint8List request) {
    final cmd = pb.NetworkConfigPayload.fromBuffer(request);
    onCommand?.call(cmd);
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdSetWifiConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespSetWifiConfig,
        respSetWifiConfig: pb.RespSetWifiConfig(status: setStatus),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdApplyWifiConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespApplyWifiConfig,
        respApplyWifiConfig: pb.RespApplyWifiConfig(status: pb.Status.Success),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdGetWifiStatus) {
      final status = wifiStatuses[wifiIndex];
      if (wifiIndex < wifiStatuses.length - 1) wifiIndex++;
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespGetWifiStatus,
        respGetWifiStatus: status,
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdSetThreadConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespSetThreadConfig,
        respSetThreadConfig: pb.RespSetThreadConfig(status: setStatus),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdApplyThreadConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespApplyThreadConfig,
        respApplyThreadConfig: pb.RespApplyThreadConfig(
          status: pb.Status.Success,
        ),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdGetThreadStatus) {
      final status = threadStatuses[threadIndex];
      if (threadIndex < threadStatuses.length - 1) threadIndex++;
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespGetThreadStatus,
        respGetThreadStatus: status,
      ).writeToBuffer();
    }
    throw StateError('unexpected config command ${cmd.msg}');
  };
}
