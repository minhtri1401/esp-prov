import 'dart:async';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('runs tasks one at a time in submission order', () async {
    final queue = SerialQueue();
    final log = <String>[];
    Future<int> task(String name, int value) async {
      log.add('start $name');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      log.add('end $name');
      return value;
    }

    final results = await Future.wait([
      queue.run(() => task('a', 1)),
      queue.run(() => task('b', 2)),
    ]);
    expect(results, [1, 2]);
    expect(log, ['start a', 'end a', 'start b', 'end b']);
  });

  test('a failing task does not block the next one', () async {
    final queue = SerialQueue();
    final failed = queue.run<int>(() => Future.error(StateError('boom')));
    final next = queue.run(() async => 42);
    await expectLater(failed, throwsStateError);
    expect(await next, 42);
  });
}
