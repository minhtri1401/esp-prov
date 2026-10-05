/// Runs CPU-heavy work off the calling isolate where the platform allows it.
///
/// Native platforms use `Isolate.run`; the web (no `dart:isolate`) runs the
/// computation inline. The conditional export keeps `dart:isolate` out of web
/// builds so the package stays compatible with all six platforms.
library;

export 'offload_inline.dart' if (dart.library.io) 'offload_isolate.dart';
