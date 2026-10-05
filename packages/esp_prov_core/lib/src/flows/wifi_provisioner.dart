import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/flows/wifi_models.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Wi-Fi scan and provisioning over `prov-scan` and `prov-config`.
///
/// Obtain one from `EspSession.wifi`.
final class WifiProvisioner {
  /// Creates a provisioner. [scanPollInterval] and [maxScanPolls] bound how
  /// long [scan] waits for the device to finish scanning.
  new(
    this._session, {
    this.scanPollInterval = const Duration(milliseconds: 500),
    this.maxScanPolls = 60,
  });

  final EspSession _session;

  /// Delay between `CmdScanWifiStatus` polls.
  final Duration scanPollInterval;

  /// Status polls before [scan] gives up with [TransportException].
  final int maxScanPolls;

  /// Asks the device to scan and returns the access points it found,
  /// strongest first, one entry per SSID (the strongest). Hidden networks
  /// (empty SSID) are left out.
  Future<List<WifiNetwork>> scan({
    bool passive = false,
    int groupChannels = 0,
    int periodMs = 120,
  }) async {
    final pages = await runNetworkScan(
      _session,
      start: pb.NetworkScanPayload(
        msg: pb.NetworkScanMsgType.TypeCmdScanWifiStart,
        cmdScanWifiStart: pb.CmdScanWifiStart(
          blocking: true,
          passive: passive,
          groupChannels: groupChannels,
          periodMs: periodMs,
        ),
      ),
      thread: false,
      pollInterval: scanPollInterval,
      maxPolls: maxScanPolls,
    );
    final strongest = <String, WifiNetwork>{};
    for (final page in pages) {
      for (final entry in page.respScanWifiResult.entries) {
        final network = WifiNetwork(
          ssid: utf8.decode(entry.ssid, allowMalformed: true),
          bssid: Uint8List.fromList(entry.bssid),
          channel: entry.channel,
          rssi: entry.rssi,
          // protobuf.dart reads unknown enum values as the default (Open)
          // and keeps the raw value in unknownFields; tag 5 is `auth`.
          authMode: entry.unknownFields.hasField(5)
              ? WifiAuthMode.unknown
              : WifiAuthMode.fromValue(entry.auth.value),
        );
        if (network.ssid.isEmpty) continue;
        final current = strongest[network.ssid];
        if (current == null || network.rssi > current.rssi) {
          strongest[network.ssid] = network;
        }
      }
    }
    return strongest.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Sends credentials, applies them and polls the connection state.
  ///
  /// Emits [WifiApplying], [WifiConnecting], any [WifiAttemptFailed], then
  /// exactly one terminal [WifiConnected] or [WifiFailed] and closes.
  /// A disconnect after [WifiConnected] is expected (firmware auto-stop) and
  /// ignored; a disconnect before it yields
  /// `WifiFailed(WifiFailureReason.deviceDisconnected)`.
  ///
  /// Throws [ArgumentError] immediately for an SSID outside 1..32 UTF-8
  /// bytes, a passphrase over 64 bytes, or a BSSID that is not 6 bytes.
  /// Device status errors arrive as [ProvStatusException] stream errors.
  Stream<WifiProvisionState> provision({
    required String ssid,
    required String passphrase,
    Uint8List? bssid,
    int? channel,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    final ssidBytes = utf8.encode(ssid);
    final passBytes = utf8.encode(passphrase);
    if (ssidBytes.isEmpty || ssidBytes.length > 32) {
      throw ArgumentError.value(ssid, 'ssid', 'must be 1 to 32 UTF-8 bytes');
    }
    if (passBytes.length > 64) {
      throw ArgumentError('passphrase must be at most 64 UTF-8 bytes');
    }
    if (bssid != null && bssid.length != 6) {
      throw ArgumentError.value(bssid, 'bssid', 'must be 6 bytes');
    }
    if (channel != null && (channel < 0 || channel > 255)) {
      throw ArgumentError.value(channel, 'channel', 'must be 0 to 255');
    }
    return _provision(
      pb.CmdSetWifiConfig(
        ssid: ssidBytes,
        passphrase: passBytes,
        bssid: bssid,
        channel: channel,
      ),
      timeout,
      pollInterval,
    );
  }

  Stream<WifiProvisionState> _provision(
    pb.CmdSetWifiConfig config,
    Duration timeout,
    Duration pollInterval,
  ) async* {
    final disconnected = Completer<void>();
    final subscription = _session.onDisconnected.listen((_) {
      if (!disconnected.isCompleted) disconnected.complete();
    });
    try {
      yield const WifiApplying();
      final set = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdSetWifiConfig,
          cmdSetWifiConfig: config,
        ),
        pb.NetworkConfigMsgType.TypeRespSetWifiConfig,
      );
      checkStatus(set.respSetWifiConfig.status, 'Set Wi-Fi config');
      final apply = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdApplyWifiConfig,
          cmdApplyWifiConfig: pb.CmdApplyWifiConfig(),
        ),
        pb.NetworkConfigMsgType.TypeRespApplyWifiConfig,
      );
      checkStatus(apply.respApplyWifiConfig.status, 'Apply Wi-Fi config');
      yield const WifiConnecting();

      final clock = Stopwatch()..start();
      int? lastAttemptsRemaining;
      while (true) {
        final response = await configRequest(
          _session,
          pb.NetworkConfigPayload(
            msg: pb.NetworkConfigMsgType.TypeCmdGetWifiStatus,
            cmdGetWifiStatus: pb.CmdGetWifiStatus(),
          ),
          pb.NetworkConfigMsgType.TypeRespGetWifiStatus,
        );
        final status = response.respGetWifiStatus;
        checkStatus(status.status, 'Get Wi-Fi status');
        final state = status.wifiStaState;
        if (state == pb.WifiStationState.Connected) {
          final c = status.wifiConnected;
          yield WifiConnected(
            ip4: c.ip4Addr,
            authMode: WifiAuthMode.fromValue(c.authMode.value),
            ssid: utf8.decode(c.ssid, allowMalformed: true),
            bssid: Uint8List.fromList(c.bssid),
            channel: c.channel,
          );
          return;
        }
        if (state == pb.WifiStationState.ConnectionFailed) {
          yield WifiFailed(
            reason:
                status.wifiFailReason == pb.WifiConnectFailedReason.AuthError
                ? WifiFailureReason.authError
                : WifiFailureReason.networkNotFound,
          );
          return;
        }
        if (state == pb.WifiStationState.Connecting &&
            status.hasAttemptFailed()) {
          final remaining = status.attemptFailed.attemptsRemaining;
          if (remaining != lastAttemptsRemaining) {
            lastAttemptsRemaining = remaining;
            yield WifiAttemptFailed(attemptsRemaining: remaining);
          }
        }
        if (clock.elapsed >= timeout) {
          yield const WifiFailed(reason: WifiFailureReason.timeout);
          return;
        }
        if (await waitOrDisconnect(pollInterval, disconnected.future)) {
          yield const WifiFailed(reason: WifiFailureReason.deviceDisconnected);
          return;
        }
      }
    } on DeviceDisconnected {
      yield const WifiFailed(reason: WifiFailureReason.deviceDisconnected);
    } finally {
      await subscription.cancel();
    }
  }
}
