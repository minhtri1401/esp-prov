import 'dart:isolate';

/// Runs [computation] on a short-lived isolate and returns its result.
///
/// [computation] must only capture sendable values (BigInt, Uint8List,
/// String, ...).
Future<R> offload<R>(R Function() computation) => Isolate.run(computation);
