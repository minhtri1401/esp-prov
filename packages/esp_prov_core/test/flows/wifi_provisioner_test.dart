import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';
import '../support/network_handlers.dart';

pb.WiFiScanResult _ap(String ssid, int rssi, {int auth = 3}) =>
    pb.WiFiScanResult(
      ssid: utf8.encode(ssid),
      rssi: rssi,
      channel: 6,
      bssid: [1, 2, 3, 4, 5, rssi & 0xff],
      auth: pb.WifiAuthMode.valueOf(auth),
    );

pb.RespGetWifiStatus _connecting({int? attemptsRemaining}) =>
    pb.RespGetWifiStatus(
      status: pb.Status.Success,
      wifiStaState: pb.WifiStationState.Connecting,
      attemptFailed: attemptsRemaining == null
          ? null
          : pb.WifiAttemptFailed(attemptsRemaining: attemptsRemaining),
    );

final _connected = pb.RespGetWifiStatus(
  status: pb.Status.Success,
  wifiStaState: pb.WifiStationState.Connected,
  wifiConnected: pb.WifiConnectedState(
    ip4Addr: '192.168.1.42',
    authMode: pb.WifiAuthMode.WPA2_PSK,
    ssid: utf8.encode('Home'),
    bssid: [1, 2, 3, 4, 5, 6],
    channel: 6,
  ),
);

pb.RespGetWifiStatus _failed(pb.WifiConnectFailedReason reason) =>
    pb.RespGetWifiStatus(
      status: pb.Status.Success,
      wifiStaState: pb.WifiStationState.ConnectionFailed,
      wifiFailReason: reason,
    );

Future<(FakeDevice, WifiProvisioner)> _open(
  Map<String, EndpointHandler> handlers,
) async {
  final device = FakeDevice(
    protoVer: protoVerJson(secVer: 0, caps: ['no_sec', 'wifi_scan']),
    handlers: handlers,
  );
  final session = await EspSession.open(device);
  return (
    device,
    WifiProvisioner(session, scanPollInterval: Duration.zero, maxScanPolls: 5),
  );
}

Stream<WifiProvisionState> _provision(WifiProvisioner wifi) => wifi.provision(
  ssid: 'Home',
  passphrase: 'password1',
  timeout: const Duration(milliseconds: 200),
  pollInterval: const Duration(milliseconds: 5),
);

void main() {
  group('scan', () {
    test('pages by 4, dedupes by SSID, drops hidden, sorts by RSSI', () async {
      final pageLog = <(int, int)>[];
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(
          pollsUntilFinished: 3,
          pageLog: pageLog,
          wifi: [
            _ap('A', -70),
            _ap('B', -40),
            _ap('A', -50),
            _ap('', -30),
            _ap('C', -90),
            _ap('D', -60),
            _ap('E', -65),
            _ap('F', -80),
            _ap('G', -85),
            _ap('B', -45),
          ],
        ),
      });
      final networks = await wifi.scan();
      expect(pageLog, [(0, 4), (4, 4), (8, 2)]);
      expect(networks.map((n) => n.ssid), ['B', 'A', 'D', 'E', 'F', 'G', 'C']);
      expect(networks[1].rssi, -50);
      expect(networks.first.authMode, WifiAuthMode.wpa2Psk);
    });

    test('stops paging when the device returns fewer entries', () async {
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(
          maxPerPage: 1,
          wifi: [_ap('A', -1), _ap('B', -2), _ap('C', -3)],
        ),
      });
      expect((await wifi.scan()).map((n) => n.ssid), ['A', 'B', 'C']);
    });

    test('an empty result needs no result request', () async {
      final pageLog = <(int, int)>[];
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(pageLog: pageLog),
      });
      expect(await wifi.scan(), isEmpty);
      expect(pageLog, isEmpty);
    });

    test('gives up when the scan never finishes', () async {
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(pollsUntilFinished: 999, wifi: [_ap('A', 1)]),
      });
      await expectLater(wifi.scan(), throwsA(isA<TransportException>()));
    });

    test('an auth mode newer than this library maps to unknown', () async {
      // Field 5 (auth), varint 9: a value network_constants.proto lacks.
      final entry = pb.WiFiScanResult.fromBuffer([
        ...(_ap('New', -10)..clearAuth()).writeToBuffer(),
        0x28,
        0x09,
      ]);
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(wifi: [entry]),
      });
      expect((await wifi.scan()).single.authMode, WifiAuthMode.unknown);
    });
  });

  group('provision', () {
    test('happy path emits Applying, Connecting, Connected', () async {
      pb.CmdSetWifiConfig? sent;
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [_connecting(), _connecting(), _connected],
          onCommand: (c) {
            if (c.hasCmdSetWifiConfig()) sent = c.cmdSetWifiConfig;
          },
        ),
      });
      final states = await _provision(wifi).toList();
      expect(states, [
        isA<WifiApplying>(),
        isA<WifiConnecting>(),
        isA<WifiConnected>()
            .having((s) => s.ip4, 'ip4', '192.168.1.42')
            .having((s) => s.ssid, 'ssid', 'Home')
            .having((s) => s.authMode, 'authMode', WifiAuthMode.wpa2Psk),
      ]);
      expect(utf8.decode(sent!.ssid), 'Home');
      expect(utf8.decode(sent!.passphrase), 'password1');
    });

    test(
      'attempt failures are reported once per change, then AuthError',
      () async {
        final (_, wifi) = await _open({
          'prov-config': configHandler(
            wifiStatuses: [
              _connecting(attemptsRemaining: 2),
              _connecting(attemptsRemaining: 2),
              _connecting(attemptsRemaining: 1),
              _failed(pb.WifiConnectFailedReason.AuthError),
            ],
          ),
        });
        final states = await _provision(wifi).toList();
        expect(states, [
          isA<WifiApplying>(),
          isA<WifiConnecting>(),
          isA<WifiAttemptFailed>().having(
            (s) => s.attemptsRemaining,
            'remaining',
            2,
          ),
          isA<WifiAttemptFailed>().having(
            (s) => s.attemptsRemaining,
            'remaining',
            1,
          ),
          isA<WifiFailed>().having(
            (s) => s.reason,
            'reason',
            WifiFailureReason.authError,
          ),
        ]);
      },
    );

    test('unknown SSID ends with networkNotFound', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [
            _failed(pb.WifiConnectFailedReason.WifiNetworkNotFound),
          ],
        ),
      });
      expect(
        (await _provision(wifi).last as WifiFailed).reason,
        WifiFailureReason.networkNotFound,
      );
    });

    test('Disconnected state keeps polling until the timeout', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [
            pb.RespGetWifiStatus(
              status: pb.Status.Success,
              wifiStaState: pb.WifiStationState.Disconnected,
            ),
          ],
        ),
      });
      expect(
        (await _provision(wifi).last as WifiFailed).reason,
        WifiFailureReason.timeout,
      );
    });

    test('a disconnect after Connected is swallowed', () async {
      late FakeDevice device;
      final handler = configHandler(wifiStatuses: [_connected]);
      final (d, wifi) = await _open({
        'prov-config': (request) {
          final response = handler(request);
          // Firmware auto-stop: drop the link shortly after Connected.
          Timer(Duration.zero, device.dropLink);
          return response;
        },
      });
      device = d;
      final states = await _provision(wifi).toList();
      expect(states.last, isA<WifiConnected>());
    });

    test(
      'a disconnect before Connected ends with deviceDisconnected',
      () async {
        late FakeDevice device;
        final handler = configHandler(wifiStatuses: [_connecting()]);
        var polls = 0;
        final (d, wifi) = await _open({
          'prov-config': (request) {
            final response = handler(request);
            if (pb.NetworkConfigPayload.fromBuffer(request)
                    .hasCmdGetWifiStatus() &&
                ++polls == 2) {
              Timer(Duration.zero, device.dropLink);
            }
            return response;
          },
        });
        device = d;
        expect(
          (await _provision(wifi).last as WifiFailed).reason,
          WifiFailureReason.deviceDisconnected,
        );
      },
    );

    test('a device status error surfaces as ProvStatusException', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          setStatus: pb.Status.InvalidArgument,
          wifiStatuses: [_connected],
        ),
      });
      await expectLater(
        _provision(wifi),
        emitsInOrder([
          isA<WifiApplying>(),
          emitsError(
            isA<ProvStatusException>().having(
              (e) => e.status,
              'status',
              ProvStatus.invalidArgument,
            ),
          ),
        ]),
      );
    });

    test('rejects invalid credentials before talking to the device', () async {
      final (device, wifi) = await _open({});
      expect(
        () => wifi.provision(ssid: '', passphrase: 'x'),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(ssid: 'x' * 33, passphrase: 'x'),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(ssid: 'ok', passphrase: 'p' * 65),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(
          ssid: 'ok',
          passphrase: 'password',
          bssid: Uint8List(5),
        ),
        throwsArgumentError,
      );
      expect(device.plainRequests, isEmpty);
    });

    test('a 32-byte multi-byte UTF-8 SSID is accepted', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(wifiStatuses: [_connected]),
      });
      // 8 x 4-byte emoji = 32 bytes.
      final ssid = '\u{1F600}' * 8;
      expect(utf8.encode(ssid).length, 32);
      final states = await wifi
          .provision(ssid: ssid, passphrase: '', timeout: Duration.zero)
          .toList();
      expect(states.last, isA<WifiConnected>());
    });
  });
}
