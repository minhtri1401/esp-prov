/// Runs [computation] inline. Used on the web, which has no isolates.
Future<R> offload<R>(R Function() computation) async => computation();
