/// Runs asynchronous tasks one at a time, in submission order.
///
/// A failing task does not block the tasks queued after it.
final class SerialQueue {
  Future<void> _tail = Future<void>.value();

  /// Schedules [task] after every previously scheduled task has completed and
  /// returns its result.
  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: _ignore);
    return result;
  }

  static void _ignore(Object _, StackTrace _) {}
}
