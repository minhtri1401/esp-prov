import 'dart:async';
import 'dart:math' as math;

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

/// Scan results are fetched at most this many per request: the firmware
/// caps a BLE response at 256 bytes (see esp_prov `scan_wifi_APs`).
const scanPageSize = 4;

/// Throws [ProvStatusException] unless [status] is `Success`.
void checkStatus(pb.Status status, String operation) {
  if (status != pb.Status.Success) {
    throw ProvStatusException(
      ProvStatus.fromValue(status.value),
      operation: operation,
    );
  }
}

T _decode<T extends Object>(String endpoint, T Function() parse) {
  try {
    return parse();
  } on InvalidProtocolBufferException catch (e) {
    throw CryptoException(
      'Could not decode the $endpoint response (${e.message}). The session '
      'keys are probably out of sync; reconnect.',
    );
  }
}

Never _unexpected(String endpoint, Object got, Object expected) =>
    throw CryptoException(
      'Unexpected $endpoint response $got (expected $expected). The session '
      'keys are probably out of sync; reconnect.',
    );

/// Sends a `prov-scan` command and checks the response type and status.
Future<pb.NetworkScanPayload> scanRequest(
  EspSession session,
  pb.NetworkScanPayload command,
  pb.NetworkScanMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.scan,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.scan,
    () => pb.NetworkScanPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.scan, response.msg, expected);
  }
  checkStatus(response.status, expected.name);
  return response;
}

/// Sends a `prov-config` command and checks the response type.
Future<pb.NetworkConfigPayload> configRequest(
  EspSession session,
  pb.NetworkConfigPayload command,
  pb.NetworkConfigMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.config,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.config,
    () => pb.NetworkConfigPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.config, response.msg, expected);
  }
  return response;
}

/// Sends a `prov-ctrl` command and checks the response type and status.
Future<void> ctrlRequest(
  EspSession session,
  pb.NetworkCtrlPayload command,
  pb.NetworkCtrlMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.ctrl,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.ctrl,
    () => pb.NetworkCtrlPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.ctrl, response.msg, expected);
  }
  checkStatus(response.status, expected.name);
}

/// Runs start -> status polling -> paged results on `prov-scan` and returns
/// every result page. Shared by Wi-Fi ([thread] false) and Thread scans.
Future<List<pb.NetworkScanPayload>> runNetworkScan(
  EspSession session, {
  required pb.NetworkScanPayload start,
  required bool thread,
  required Duration pollInterval,
  required int maxPolls,
}) async {
  await scanRequest(
    session,
    start,
    thread
        ? pb.NetworkScanMsgType.TypeRespScanThreadStart
        : pb.NetworkScanMsgType.TypeRespScanWifiStart,
  );

  var count = 0;
  for (var poll = 1; ; poll++) {
    final status = await scanRequest(
      session,
      thread
          ? pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanThreadStatus,
              cmdScanThreadStatus: pb.CmdScanThreadStatus(),
            )
          : pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanWifiStatus,
              cmdScanWifiStatus: pb.CmdScanWifiStatus(),
            ),
      thread
          ? pb.NetworkScanMsgType.TypeRespScanThreadStatus
          : pb.NetworkScanMsgType.TypeRespScanWifiStatus,
    );
    final finished = thread
        ? status.respScanThreadStatus.scanFinished
        : status.respScanWifiStatus.scanFinished;
    if (finished) {
      count = thread
          ? status.respScanThreadStatus.resultCount
          : status.respScanWifiStatus.resultCount;
      break;
    }
    if (poll >= maxPolls) {
      throw const TransportException(
        'The device did not finish the network scan in time.',
      );
    }
    await Future<void>.delayed(pollInterval);
  }

  final pages = <pb.NetworkScanPayload>[];
  var index = 0;
  while (index < count) {
    final size = math.min(scanPageSize, count - index);
    final page = await scanRequest(
      session,
      thread
          ? pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanThreadResult,
              cmdScanThreadResult: pb.CmdScanThreadResult(
                startIndex: index,
                count: size,
              ),
            )
          : pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanWifiResult,
              cmdScanWifiResult: pb.CmdScanWifiResult(
                startIndex: index,
                count: size,
              ),
            ),
      thread
          ? pb.NetworkScanMsgType.TypeRespScanThreadResult
          : pb.NetworkScanMsgType.TypeRespScanWifiResult,
    );
    final received = thread
        ? page.respScanThreadResult.entries.length
        : page.respScanWifiResult.entries.length;
    if (received == 0) break;
    pages.add(page);
    index += received;
  }
  return pages;
}

/// Waits for [delay]; returns true if [disconnected] completes first.
Future<bool> waitOrDisconnect(Duration delay, Future<void> disconnected) =>
    Future.any([
      Future<bool>.delayed(delay, () => false),
      disconnected.then((_) => true),
    ]);
