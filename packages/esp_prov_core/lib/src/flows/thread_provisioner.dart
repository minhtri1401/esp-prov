import 'dart:async';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/flows/thread_models.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Thread scan and provisioning (`network_provisioning` firmware only).
///
/// Obtain one from `EspSession.thread`.
final class ThreadProvisioner {
  /// Creates a provisioner. See `WifiProvisioner` for the scan parameters.
  new(
    this._session, {
    this.scanPollInterval = const Duration(milliseconds: 500),
    this.maxScanPolls = 60,
  });

  final EspSession _session;

  /// Delay between `CmdScanThreadStatus` polls.
  final Duration scanPollInterval;

  /// Status polls before [scan] gives up with [TransportException].
  final int maxScanPolls;

  /// Asks the device to scan for Thread networks, strongest first.
  Future<List<ThreadNetwork>> scan() async {
    final pages = await runNetworkScan(
      _session,
      start: pb.NetworkScanPayload(
        msg: pb.NetworkScanMsgType.TypeCmdScanThreadStart,
        cmdScanThreadStart: pb.CmdScanThreadStart(blocking: true),
      ),
      thread: true,
      pollInterval: scanPollInterval,
      maxPolls: maxScanPolls,
    );
    return [
      for (final page in pages)
        for (final e in page.respScanThreadResult.entries)
          ThreadNetwork(
            panId: e.panId,
            channel: e.channel,
            rssi: e.rssi,
            lqi: e.lqi,
            extAddr: Uint8List.fromList(e.extAddr),
            networkName: e.networkName,
            extPanId: Uint8List.fromList(e.extPanId),
          ),
    ]..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Sends an operational dataset (TLV bytes), applies it and polls until the
  /// device attaches or fails. Same stream contract as
  /// `WifiProvisioner.provision`.
  ///
  /// Throws [ArgumentError] immediately for an empty dataset or one longer
  /// than 254 bytes (the Thread maximum).
  Stream<ThreadProvisionState> provision({
    required Uint8List datasetTlvs,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    if (datasetTlvs.isEmpty || datasetTlvs.length > 254) {
      throw ArgumentError.value(
        datasetTlvs.length,
        'datasetTlvs',
        'must be 1 to 254 bytes',
      );
    }
    return _provision(datasetTlvs, timeout, pollInterval);
  }

  Stream<ThreadProvisionState> _provision(
    Uint8List dataset,
    Duration timeout,
    Duration pollInterval,
  ) async* {
    final disconnected = Completer<void>();
    final subscription = _session.onDisconnected.listen((_) {
      if (!disconnected.isCompleted) disconnected.complete();
    });
    try {
      yield const ThreadApplying();
      final set = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdSetThreadConfig,
          cmdSetThreadConfig: pb.CmdSetThreadConfig(dataset: dataset),
        ),
        pb.NetworkConfigMsgType.TypeRespSetThreadConfig,
      );
      checkStatus(set.respSetThreadConfig.status, 'Set Thread config');
      final apply = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdApplyThreadConfig,
          cmdApplyThreadConfig: pb.CmdApplyThreadConfig(),
        ),
        pb.NetworkConfigMsgType.TypeRespApplyThreadConfig,
      );
      checkStatus(apply.respApplyThreadConfig.status, 'Apply Thread config');
      yield const ThreadAttaching();

      final clock = Stopwatch()..start();
      while (true) {
        final response = await configRequest(
          _session,
          pb.NetworkConfigPayload(
            msg: pb.NetworkConfigMsgType.TypeCmdGetThreadStatus,
            cmdGetThreadStatus: pb.CmdGetThreadStatus(),
          ),
          pb.NetworkConfigMsgType.TypeRespGetThreadStatus,
        );
        final status = response.respGetThreadStatus;
        checkStatus(status.status, 'Get Thread status');
        if (status.threadState == pb.ThreadNetworkState.Attached) {
          final a = status.threadAttached;
          yield ThreadAttached(
            panId: a.panId,
            extPanId: Uint8List.fromList(a.extPanId),
            channel: a.channel,
            name: a.name,
          );
          return;
        }
        if (status.threadState == pb.ThreadNetworkState.AttachingFailed) {
          yield ThreadFailed(
            reason:
                status.threadFailReason ==
                    pb.ThreadAttachFailedReason.DatasetInvalid
                ? ThreadFailureReason.datasetInvalid
                : ThreadFailureReason.networkNotFound,
          );
          return;
        }
        if (clock.elapsed >= timeout) {
          yield const ThreadFailed(reason: ThreadFailureReason.timeout);
          return;
        }
        if (await waitOrDisconnect(pollInterval, disconnected.future)) {
          yield const ThreadFailed(
            reason: ThreadFailureReason.deviceDisconnected,
          );
          return;
        }
      }
    } on DeviceDisconnected {
      yield const ThreadFailed(reason: ThreadFailureReason.deviceDisconnected);
    } finally {
      await subscription.cancel();
    }
  }
}
