import 'dart:async';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

/// One expected transaction: the request the client must send and what the
/// fake device answers. A non-null [error] is thrown instead of answering.
final class Exchange {
  /// Creates an expected exchange.
  const new(this.endpoint, this.request, this.response, {this.error});

  /// Endpoint the request must go to.
  final String endpoint;

  /// Exact request bytes, or null to accept any request.
  final List<int>? request;

  /// Bytes returned to the client.
  final List<int> response;

  /// Error thrown instead of returning [response].
  final Exception? error;
}

/// A [ProvTransport] that replays recorded exchanges in order and fails the
/// test on any unexpected request.
final class ReplayTransport implements ProvTransport {
  /// Creates a transport that expects [exchanges] in order.
  new(this.exchanges, {this.endpoints = const {'proto-ver', 'prov-session'}});

  /// Remaining expected exchanges.
  final List<Exchange> exchanges;

  @override
  final Set<String> endpoints;

  /// Every request that was sent, in order.
  final List<(String, Uint8List)> sent = [];

  final _disconnects = StreamController<void>.broadcast();

  @override
  Stream<void> get onDisconnected => _disconnects.stream;

  @override
  Future<void> disconnect() async {}

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) async {
    sent.add((endpoint, request));
    expect(exchanges, isNotEmpty, reason: 'unexpected request to $endpoint');
    final next = exchanges.removeAt(0);
    expect(endpoint, next.endpoint);
    if (next.request != null) {
      expect(request, next.request, reason: 'request bytes to $endpoint');
    }
    if (next.error != null) throw next.error!;
    return Uint8List.fromList(next.response);
  }
}
