import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

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
