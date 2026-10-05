import 'dart:async';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';
import '../support/network_handlers.dart';

FakeDevice _device(Map<String, EndpointHandler> handlers) => FakeDevice(
  protoVer: protoVerJson(
    secVer: 0,
    ver: 'netprov-v1.2',
    caps: ['no_sec', 'thread_scan', 'thread_prov'],
  ),
  handlers: handlers,
);

Future<ThreadProvisioner> _open(Map<String, EndpointHandler> handlers) async {
  final session = await EspSession.open(_device(handlers));
  return ThreadProvisioner(session, scanPollInterval: Duration.zero);
}

Stream<ThreadProvisionState> _provision(ThreadProvisioner thread) =>
    thread.provision(
      datasetTlvs: Uint8List.fromList([1]),
      timeout: const Duration(milliseconds: 200),
      pollInterval: const Duration(milliseconds: 5),
    );

pb.RespGetThreadStatus _state(
  pb.ThreadNetworkState state, [
  pb.ThreadAttachFailedReason? reason,
]) => pb.RespGetThreadStatus(
  status: pb.Status.Success,
  threadState: state,
  threadFailReason: reason,
);

void main() {
  test('scan returns networks strongest first', () async {
    final thread = await _open({
      'prov-scan': scanHandler(
        thread: [
          for (final (name, rssi) in [('a', -80), ('b', -20), ('c', -50)])
            pb.ThreadScanResult(
              networkName: name,
              rssi: rssi,
              panId: 0x1234,
              channel: 15,
              extPanId: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
        ],
      ),
    });
    final networks = await thread.scan();
    expect(networks.map((n) => n.networkName), ['b', 'c', 'a']);
    expect(networks.first.panId, 0x1234);
  });

  test('provision attaches', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.Attaching,
          ),
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.Attached,
            threadAttached: pb.ThreadAttachState(
              panId: 0x1234,
              channel: 15,
              name: 'OpenThread',
              extPanId: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
          ),
        ],
      ),
    });
    final states = await thread
        .provision(
          datasetTlvs: Uint8List.fromList([0, 3, 0, 0, 15]),
          pollInterval: Duration.zero,
        )
        .toList();
    expect(states, [
      isA<ThreadApplying>(),
      isA<ThreadAttaching>(),
      isA<ThreadAttached>().having((s) => s.name, 'name', 'OpenThread'),
    ]);
  });

  test('invalid dataset ends with datasetInvalid', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.AttachingFailed,
            threadFailReason: pb.ThreadAttachFailedReason.DatasetInvalid,
          ),
        ],
      ),
    });
    final last = await thread
        .provision(datasetTlvs: Uint8List.fromList([1]))
        .last;
    expect((last as ThreadFailed).reason, ThreadFailureReason.datasetInvalid);
  });

  test('rejects empty and oversized datasets', () async {
    final thread = await _open({});
    expect(
      () => thread.provision(datasetTlvs: Uint8List(0)),
      throwsArgumentError,
    );
    expect(
      () => thread.provision(datasetTlvs: Uint8List(255)),
      throwsArgumentError,
    );
  });

  test('networkNotFound failure', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [
          _state(
            pb.ThreadNetworkState.AttachingFailed,
            pb.ThreadAttachFailedReason.ThreadNetworkNotFound,
          ),
        ],
      ),
    });
    expect(
      (await _provision(thread).last as ThreadFailed).reason,
      ThreadFailureReason.networkNotFound,
    );
  });

  test('Dettached keeps polling until the timeout', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [_state(pb.ThreadNetworkState.Dettached)],
      ),
    });
    final states = await _provision(thread).toList();
    expect(states.last, isA<ThreadFailed>());
    expect((states.last as ThreadFailed).reason, ThreadFailureReason.timeout);
    expect(states.whereType<ThreadFailed>(), hasLength(1));
  });

  test('a disconnect before Attached ends with deviceDisconnected', () async {
    late FakeDevice device;
    final handler = configHandler(
      threadStatuses: [_state(pb.ThreadNetworkState.Attaching)],
    );
    var polls = 0;
    device = _device({
      'prov-config': (request) {
        final response = handler(request);
        if (pb.NetworkConfigPayload.fromBuffer(request)
                .hasCmdGetThreadStatus() &&
            ++polls == 2) {
          Timer(Duration.zero, device.dropLink);
        }
        return response;
      },
    });
    final thread = ThreadProvisioner(await EspSession.open(device));
    expect(
      (await _provision(thread).last as ThreadFailed).reason,
      ThreadFailureReason.deviceDisconnected,
    );
  });
}
