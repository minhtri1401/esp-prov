import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/session/esp_session.dart';

/// An application endpoint the firmware registered with
/// `wifi_prov_mgr_endpoint_create` / `network_prov_mgr_endpoint_create`.
///
/// Payloads are raw bytes, encrypted with the session cipher.
final class CustomEndpoint {
  /// Creates the endpoint client. Obtain one from `EspSession.custom`.
  new(this._session, this.name);

  final EspSession _session;

  /// Endpoint name, e.g. `custom-data`.
  final String name;

  /// Whether the transport discovered this endpoint.
  bool get isAvailable => _session.endpoints.contains(name);

  /// Sends [data] and returns the device's response.
  ///
  /// Throws [UnknownEndpoint] if the transport did not discover [name].
  Future<Uint8List> send(Uint8List data) => _session.request(name, data);
}
