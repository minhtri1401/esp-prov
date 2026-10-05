import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/custom_endpoint.dart';
import 'package:esp_prov_core/src/flows/prov_ctrl.dart';
import 'package:esp_prov_core/src/flows/thread_provisioner.dart';
import 'package:esp_prov_core/src/flows/wifi_provisioner.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:esp_prov_core/src/transport/serial_queue.dart';

/// An authenticated provisioning session with one device.
final class EspSession {
  new _(this._transport, this.info, this._scheme);

  /// Reads `proto-ver`, picks the security scheme the firmware declares,
  /// runs the handshake and returns the session.
  ///
  /// Throws [SchemeMismatch] or [MissingCredentials] when [credentials] do
  /// not fit the firmware, [PopMismatch] when the device rejects them, and
  /// [HandshakeFailed] for other handshake errors.
  static Future<EspSession> open(
    ProvTransport transport, {
    ProvCredentials? credentials,
  }) async {
    final info = transport.endpoints.contains(ProvEndpoints.protoVer)
        ? DeviceInfo.parse(
            utf8.decode(
              await transport.send(
                ProvEndpoints.protoVer,
                Uint8List.fromList(utf8.encode('---')),
              ),
              allowMalformed: true,
            ),
          )
        : DeviceInfo.parse('');
    final scheme = selectScheme(info, credentials);
    if (!transport.endpoints.contains(ProvEndpoints.session)) {
      throw UnknownEndpoint(ProvEndpoints.session);
    }
    await scheme.handshake(transport);
    return EspSession._(transport, info, scheme);
  }

  final ProvTransport _transport;
  final SecurityScheme _scheme;
  final SerialQueue _queue = SerialQueue();
  bool _closed = false;
  Object? _failure;
  WifiProvisioner? _wifi;
  ThreadProvisioner? _thread;
  ProvCtrl? _ctrl;

  /// Version and capabilities reported by the device.
  final DeviceInfo info;

  /// Security version in use (0, 1 or 2).
  int get securityVersion => _scheme.version;

  /// Endpoint names the transport discovered.
  Set<String> get endpoints => _transport.endpoints;

  /// Encrypts [body], sends it to [endpoint] and returns the decrypted
  /// response. Requests run one at a time, in call order.
  ///
  /// Security 1 and 2 ciphers are stateful, so after any failed request the
  /// device and this session disagree on cipher state. Later requests then
  /// throw [TransportException] and the caller must reconnect.
  Future<Uint8List> request(String endpoint, Uint8List body) =>
      _queue.run(() async {
        if (_closed) {
          throw const DeviceDisconnected('The session is closed.');
        }
        final failure = _failure;
        if (failure != null) {
          if (failure is DeviceDisconnected) throw failure;
          throw TransportException(
            'The session cannot be used after a failed request. '
            'Reconnect and open a new session.',
            cause: failure,
          );
        }
        if (!_transport.endpoints.contains(endpoint)) {
          throw UnknownEndpoint(endpoint);
        }
        try {
          final encrypted = await _scheme.encrypt(body);
          final response = await _transport.send(endpoint, encrypted);
          return await _scheme.decrypt(response);
        } on Object catch (e) {
          _failure = e;
          rethrow;
        }
      });

  /// Wi-Fi scan and provisioning.
  ///
  /// Throws [UnsupportedCapability] only when the firmware lists
  /// `thread_prov` without `wifi_prov` (a Thread-only device).
  WifiProvisioner get wifi {
    if (info.hasCapability('thread_prov') && !info.hasCapability('wifi_prov')) {
      throw UnsupportedCapability('wifi_prov');
    }
    return _wifi ??= WifiProvisioner(this);
  }

  /// Thread scan and provisioning. Requires the `thread_prov` capability.
  ThreadProvisioner get thread {
    if (!info.hasCapability('thread_prov')) {
      throw UnsupportedCapability('thread_prov');
    }
    return _thread ??= ThreadProvisioner(this);
  }

  /// Reset and re-provision commands on `prov-ctrl`.
  ProvCtrl get ctrl => _ctrl ??= ProvCtrl(this);

  /// An application endpoint registered by the firmware, e.g. `custom-data`.
  CustomEndpoint custom(String name) => CustomEndpoint(this, name);

  /// Emits once when the link drops.
  Stream<void> get onDisconnected => _transport.onDisconnected;

  /// Closes the session and the link. Safe to call more than once and after
  /// the device has already disconnected.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _transport.disconnect();
  }
}
