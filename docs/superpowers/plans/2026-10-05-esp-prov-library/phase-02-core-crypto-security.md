> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 2: Core: transport interfaces, crypto primitives, Security 0/1/2

**Goal:** The transport contract, the error model, and Security 0/1/2 handshakes and ciphers in pure Dart, proven byte-identical to Espressif esp_prov fixtures.

**Depends on:** Phase 1.

All work is in `packages/esp_prov_core`. Nothing in this package may
import Flutter or `universal_ble` (spec section 3). Every task ends with
`fvm dart analyze --fatal-infos` clean; the generated proto code is
excluded from analysis.

---

### Task 2.1: Error model, transport interfaces and the serial queue

**Files:**
- Create: `packages/esp_prov_core/lib/src/errors/prov_status.dart`
- Create: `packages/esp_prov_core/lib/src/errors/prov_exception.dart`
- Create: `packages/esp_prov_core/lib/src/transport/prov_transport.dart`
- Create: `packages/esp_prov_core/lib/src/transport/serial_queue.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/errors/prov_exception_test.dart`
- Test: `packages/esp_prov_core/test/transport/serial_queue_test.dart`

**Interfaces:**
- Consumes: workspace from Phase 1.
- Produces: From `package:esp_prov_core/esp_prov_core.dart`:
- `enum ProvStatus { success, invalidSecScheme, invalidProto, tooManySessions, invalidArgument, internalError, cryptoError, invalidSession, unknown; static ProvStatus fromValue(int value) }`
- `sealed class ProvException implements Exception { final String message; }` with final subclasses
  `TransportException(String message, {Object? cause})`, `DeviceDisconnected([String message])`,
  `UnknownEndpoint(String endpoint)`, `UnsupportedCapability(String capability)`,
  `SchemeMismatch({required int expected, required String provided})`, `MissingCredentials(String message)`,
  `HandshakeFailed(String message, {ProvStatus status = ProvStatus.unknown})`,
  `PopMismatch(String message, {ProvStatus status})` (extends `HandshakeFailed`), `CryptoException(String message)`,
  `ProvStatusException(ProvStatus status, {required String operation})`.
- `abstract final class ProvEndpoints { protoVer, session, config, scan, ctrl }` (string constants).
- `abstract interface class ProvTransport { Set<String> get endpoints; Future<Uint8List> send(String endpoint, Uint8List request); Stream<void> get onDisconnected; Future<void> disconnect(); }`
- `abstract interface class ProvScanner { Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}); }`
- `abstract interface class DiscoveredDevice { String get id; String get name; int? get rssi; String get serviceUuid; Future<ProvTransport> connect(); }`
- `final class SerialQueue { Future<T> run<T>(Future<T> Function() task); }`

The spec lists the error model under Phase 3, but the security layer in
this phase already throws `HandshakeFailed`/`PopMismatch`/`CryptoException`,
so it is built first. `PopMismatch` must extend `HandshakeFailed` (spec 3.7),
which is only legal because both live in the same library (a `final` class
can be extended inside its own library).

Dart 3.13 note used throughout this plan: `very_good_analysis` 11 enables
`unnecessary_type_name_in_constructor`, so constructors are declared with the
new syntax: `const new(this.message);`, `new named(...)`,
`factory parse(String json)`. Call sites are unchanged
(`ProvStatusException(...)`, `DeviceInfo.parse(...)`).

- [ ] **Step 1: Write the failing tests**

Create `packages/esp_prov_core/test/errors/prov_exception_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('PopMismatch is a HandshakeFailed', () {
    const error = PopMismatch('wrong pop');
    expect(error, isA<HandshakeFailed>());
    expect(error.status, ProvStatus.unknown);
    expect(error.toString(), 'PopMismatch: wrong pop');
  });

  test('SchemeMismatch tells the developer what the device wants', () {
    final error = SchemeMismatch(expected: 1, provided: 'no');
    expect(error.message, contains('ProvCredentials.pop'));
    expect(error.toString(), startsWith('SchemeMismatch: '));
  });

  test('UnknownEndpoint and ProvStatusException carry their data', () {
    expect(UnknownEndpoint('custom-data').endpoint, 'custom-data');
    final status = ProvStatusException(
      ProvStatus.invalidArgument,
      operation: 'Set Wi-Fi config',
    );
    expect(status.message, contains('invalidArgument'));
  });

  test('ProvStatus.fromValue maps wire values', () {
    expect(ProvStatus.fromValue(0), ProvStatus.success);
    expect(ProvStatus.fromValue(7), ProvStatus.invalidSession);
    expect(ProvStatus.fromValue(42), ProvStatus.unknown);
    expect(ProvStatus.fromValue(-1), ProvStatus.unknown);
  });
}
```

Create `packages/esp_prov_core/test/transport/serial_queue_test.dart`:

```dart
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_core && fvm dart test test/errors test/transport)`

Expected: FAIL: compilation errors such as `Error: Method not found: 'PopMismatch'.` and `Error: 'HandshakeFailed' isn't a type.`

- [ ] **Step 3: Implement the error model, transport interfaces and queue**

Create `packages/esp_prov_core/lib/src/errors/prov_status.dart`:

```dart
/// Status codes a protocomm device returns (constants.proto `Status`).
enum ProvStatus {
  /// `Success = 0`.
  success,

  /// `InvalidSecScheme = 1`.
  invalidSecScheme,

  /// `InvalidProto = 2`.
  invalidProto,

  /// `TooManySessions = 3`.
  tooManySessions,

  /// `InvalidArgument = 4`.
  invalidArgument,

  /// `InternalError = 5`.
  internalError,

  /// `CryptoError = 6`.
  cryptoError,

  /// `InvalidSession = 7`.
  invalidSession,

  /// A value this library does not know about.
  unknown;

  /// Maps the wire value of constants.proto `Status` to a [ProvStatus].
  static ProvStatus fromValue(int value) =>
      value >= 0 && value < unknown.index ? values[value] : unknown;
}
```

Create `packages/esp_prov_core/lib/src/errors/prov_exception.dart`:

```dart
import 'package:esp_prov_core/src/errors/prov_status.dart';

/// Base class of every error this library throws on purpose.
///
/// Switch over it exhaustively to give users a precise message.
sealed class ProvException implements Exception {
  const new(this.message);

  /// Human-readable description, safe to show in logs.
  final String message;

  @override
  String toString() {
    final name = switch (this) {
      TransportException() => 'TransportException',
      DeviceDisconnected() => 'DeviceDisconnected',
      UnknownEndpoint() => 'UnknownEndpoint',
      UnsupportedCapability() => 'UnsupportedCapability',
      SchemeMismatch() => 'SchemeMismatch',
      MissingCredentials() => 'MissingCredentials',
      PopMismatch() => 'PopMismatch',
      HandshakeFailed() => 'HandshakeFailed',
      CryptoException() => 'CryptoException',
      ProvStatusException() => 'ProvStatusException',
    };
    return '$name: $message';
  }
}

/// The transport failed: BLE error, timeout, or an unusable session.
final class TransportException extends ProvException {
  /// Creates a transport failure with an optional underlying [cause].
  const new(super.message, {this.cause});

  /// The platform error that triggered this exception, if any.
  final Object? cause;
}

/// The link to the device dropped.
final class DeviceDisconnected extends ProvException {
  /// Creates a disconnect error.
  const new([super.message = 'The device disconnected.']);
}

/// The device does not expose the requested protocomm endpoint.
final class UnknownEndpoint extends ProvException {
  /// Creates an error for the missing [endpoint].
  new(this.endpoint)
    : super('Endpoint "$endpoint" was not discovered on the device.');

  /// The endpoint name that was requested.
  final String endpoint;
}

/// The device firmware does not advertise a capability the call needs.
final class UnsupportedCapability extends ProvException {
  /// Creates an error for the missing [capability].
  new(this.capability) : super('The device does not support "$capability".');

  /// The capability that is missing, e.g. `thread_prov`.
  final String capability;
}

/// The credentials kind does not match the security scheme of the device.
final class SchemeMismatch extends ProvException {
  /// Creates a mismatch between the device's [expected] security version and
  /// the [provided] credentials kind.
  new({required this.expected, required this.provided})
    : super(
        'The device uses Security $expected and needs '
        '${_hint(expected)}, but $provided credentials were provided.',
      );

  /// Security version the device declared in `proto-ver`.
  final int expected;

  /// Description of the credentials the caller passed.
  final String provided;

  static String _hint(int secVer) => switch (secVer) {
    0 => 'ProvCredentials.none()',
    1 => 'ProvCredentials.pop(...)',
    2 => 'ProvCredentials.security2(username: ..., password: ...)',
    _ => 'an unsupported scheme',
  };
}

/// The device needs credentials and none (or not enough) were provided.
final class MissingCredentials extends ProvException {
  /// Creates a missing-credentials error.
  const new(super.message);
}

/// The security handshake on `prov-session` failed.
final class HandshakeFailed extends ProvException {
  /// Creates a handshake failure with the device [status], if one was sent.
  const new(super.message, {this.status = ProvStatus.unknown});

  /// Status reported by the device, or [ProvStatus.unknown].
  final ProvStatus status;
}

/// The device rejected the proof of possession (Security 1) or the
/// username/password proof (Security 2), or its own proof did not verify.
final class PopMismatch extends HandshakeFailed {
  /// Creates a proof mismatch error.
  const new(super.message, {super.status});
}

/// Encryption or decryption failed, e.g. an AES-GCM tag mismatch.
final class CryptoException extends ProvException {
  /// Creates a crypto failure.
  const new(super.message);
}

/// The device answered a request with a non-success status.
final class ProvStatusException extends ProvException {
  /// Creates an error for [status] returned while running [operation].
  new(this.status, {required String operation})
    : super('$operation failed with device status ${status.name}.');

  /// The status the device returned.
  final ProvStatus status;
}
```

Create `packages/esp_prov_core/lib/src/transport/prov_transport.dart`:

```dart
import 'dart:typed_data';

/// Names of the protocomm endpoints every provisioning firmware exposes.
abstract final class ProvEndpoints {
  /// Plain-text JSON version and capability endpoint.
  static const protoVer = 'proto-ver';

  /// Security handshake endpoint.
  static const session = 'prov-session';

  /// Network configuration endpoint (encrypted).
  static const config = 'prov-config';

  /// Network scan endpoint (encrypted).
  static const scan = 'prov-scan';

  /// Provisioning control endpoint (encrypted).
  static const ctrl = 'prov-ctrl';
}

/// A connected link to a provisioning device.
///
/// One call to [send] is one protocomm transaction. Implementations must
/// serialise concurrent calls so transactions never interleave on the link.
abstract interface class ProvTransport {
  /// Endpoint names discovered on the device, e.g.
  /// `{'prov-session', 'prov-config', 'custom-data'}`.
  Set<String> get endpoints;

  /// Sends [request] to [endpoint] and returns the device's response bytes.
  ///
  /// Throws `TransportException` on link errors and `DeviceDisconnected`
  /// if the link drops.
  Future<Uint8List> send(String endpoint, Uint8List request);

  /// Emits once when the link drops for any reason.
  Stream<void> get onDisconnected;

  /// Closes the link. Safe to call when already disconnected.
  Future<void> disconnect();
}

/// Discovers provisioning devices.
abstract interface class ProvScanner {
  /// Emits each device whose advertised name starts with [namePrefix]
  /// (case-insensitive), once per device id.
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'});
}

/// A device found by a [ProvScanner].
abstract interface class DiscoveredDevice {
  /// Platform device id (MAC address on Android, UUID on Apple platforms).
  String get id;

  /// Advertised name.
  String get name;

  /// Signal strength of the last advertisement, if known.
  int? get rssi;

  /// 128-bit primary service UUID taken from the advertisement, lowercase.
  String get serviceUuid;

  /// Connects and discovers the protocomm endpoints.
  Future<ProvTransport> connect();
}
```

Create `packages/esp_prov_core/lib/src/transport/serial_queue.dart`:

```dart
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
```

Replace the entire contents of `packages/esp_prov_core/lib/esp_prov_core.dart`:

```dart
/// Pure-Dart client for Espressif Unified Provisioning (protocomm).
///
/// Bring a `ProvTransport` (for example from `esp_prov_ble_universal`), open
/// an `EspSession`, then use its Wi-Fi, Thread, control and custom endpoint
/// flows.
library;

export 'src/errors/prov_exception.dart';
export 'src/errors/prov_status.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_core && fvm dart test test/errors test/transport)`

Expected: `+6: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/errors/prov_exception_test.dart \
  packages/esp_prov_core/test/transport/serial_queue_test.dart \
  packages/esp_prov_core/lib/src/errors/prov_status.dart \
  packages/esp_prov_core/lib/src/errors/prov_exception.dart \
  packages/esp_prov_core/lib/src/transport/prov_transport.dart \
  packages/esp_prov_core/lib/src/transport/serial_queue.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): error model, transport interfaces, serial queue" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.2: Byte helpers and the isolate offload

**Files:**
- Create: `packages/esp_prov_core/lib/src/crypto/bytes.dart`
- Create: `packages/esp_prov_core/lib/src/crypto/offload.dart`
- Create: `packages/esp_prov_core/lib/src/crypto/offload_isolate.dart`
- Create: `packages/esp_prov_core/lib/src/crypto/offload_inline.dart`
- Test: `packages/esp_prov_core/test/crypto/bytes_test.dart`
- Test: `packages/esp_prov_core/test/crypto/offload_test.dart`

**Interfaces:**
- Consumes: `HandshakeFailed` from Task 2.1.
- Produces: `package:esp_prov_core/src/crypto/bytes.dart` (not exported):
`BigInt bytesToBigInt(List<int>)`, `Uint8List bigIntToBytes(BigInt, {int? length})`
(minimal big-endian without `length`, left-padded `PAD()` with it),
`Uint8List xorBytes(List<int>, List<int>)`, `bool constantTimeEquals(List<int>, List<int>)`,
`Uint8List concatBytes(List<List<int>>)`, `String toHex(List<int>)`, `Uint8List fromHex(String)`.
`package:esp_prov_core/src/crypto/offload.dart`: `Future<R> offload<R>(R Function() computation)`
(Isolate.run on native, inline on web).

`offload.dart` uses a conditional export keyed on `dart.library.io`, so
`dart:isolate` never reaches web builds. Importing `dart:isolate`
unconditionally would cost the Web platform tag on pub.dev (success
criterion 3). The closure passed to `offload` must only capture sendable
values (BigInt, Uint8List, String). Errors keep their type across the
isolate boundary; the second test pins that.

- [ ] **Step 1: Write the failing tests**

Create `packages/esp_prov_core/test/crypto/bytes_test.dart`:

```dart
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

void main() {
  group('bigIntToBytes', () {
    test('is minimal without a length', () {
      expect(bigIntToBytes(BigInt.from(0x0102)), [1, 2]);
      expect(bigIntToBytes(BigInt.zero), [0]);
    });

    test('left-pads to the requested length (PAD)', () {
      expect(bigIntToBytes(BigInt.from(5), length: 4), [0, 0, 0, 5]);
    });

    test('rejects values that do not fit', () {
      expect(
        () => bigIntToBytes(BigInt.from(0x010000), length: 2),
        throwsArgumentError,
      );
    });
  });

  test('bytesToBigInt ignores leading zeros', () {
    expect(bytesToBigInt([0, 0, 1, 0]), BigInt.from(256));
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  test('hex round trip', () {
    expect(toHex(fromHex('00ff10')), '00ff10');
  });
}
```

Create `packages/esp_prov_core/test/crypto/offload_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/offload.dart';
import 'package:test/test.dart';

void main() {
  test('returns the computation result', () async {
    final base = BigInt.from(5);
    expect(await offload(() => base.pow(3)), BigInt.from(125));
  });

  test('keeps the error type thrown inside the computation', () async {
    await expectLater(
      offload<int>(() => throw const HandshakeFailed('u == 0')),
      throwsA(isA<HandshakeFailed>()),
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/bytes_test.dart test/crypto/offload_test.dart)`

Expected: FAIL: `Error when reading 'lib/src/crypto/bytes.dart': No such file or directory`.

- [ ] **Step 3: Implement the helpers**

Create `packages/esp_prov_core/lib/src/crypto/bytes.dart`:

```dart
import 'dart:typed_data';

/// Big-endian unsigned integer from [bytes].
BigInt bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b & 0xff);
  }
  return result;
}

/// Big-endian encoding of a non-negative [value].
///
/// Without [length] the result is minimal (no leading zero bytes, `[0]` for
/// zero), which matches mbedTLS `esp_mpi_to_bin` and Python `long_to_bytes`.
/// With [length] the result is left-padded with zeros to exactly [length]
/// bytes (the SRP `PAD()` operation).
Uint8List bigIntToBytes(BigInt value, {int? length}) {
  if (value.isNegative) {
    throw ArgumentError.value(value, 'value', 'must be non-negative');
  }
  final minimal = value == BigInt.zero ? 1 : (value.bitLength + 7) >> 3;
  final size = length ?? minimal;
  if (minimal > size && value != BigInt.zero) {
    throw ArgumentError.value(value, 'value', 'does not fit in $size bytes');
  }
  final out = Uint8List(size);
  var v = value;
  for (var i = size - 1; i >= 0 && v > BigInt.zero; i--) {
    out[i] = (v & _byteMask).toInt();
    v = v >> 8;
  }
  return out;
}

final BigInt _byteMask = BigInt.from(0xff);

/// Bytewise XOR of two equal-length lists.
Uint8List xorBytes(List<int> a, List<int> b) {
  if (a.length != b.length) {
    throw ArgumentError('Length mismatch: ${a.length} != ${b.length}');
  }
  return Uint8List.fromList([for (var i = 0; i < a.length; i++) a[i] ^ b[i]]);
}

/// Comparison whose running time does not depend on where the lists differ.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Concatenates byte lists.
Uint8List concatBytes(List<List<int>> parts) {
  final builder = BytesBuilder(copy: false);
  parts.forEach(builder.add);
  return builder.takeBytes();
}

/// Lowercase hex encoding.
String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Decodes an even-length hex string.
Uint8List fromHex(String hex) {
  if (hex.length.isOdd) {
    throw FormatException('Odd-length hex string', hex);
  }
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
```

Create `packages/esp_prov_core/lib/src/crypto/offload.dart`:

```dart
/// Runs CPU-heavy work off the calling isolate where the platform allows it.
///
/// Native platforms use `Isolate.run`; the web (no `dart:isolate`) runs the
/// computation inline. The conditional export keeps `dart:isolate` out of web
/// builds so the package stays compatible with all six platforms.
library;

export 'offload_inline.dart' if (dart.library.io) 'offload_isolate.dart';
```

Create `packages/esp_prov_core/lib/src/crypto/offload_isolate.dart`:

```dart
import 'dart:isolate';

/// Runs [computation] on a short-lived isolate and returns its result.
///
/// [computation] must only capture sendable values (BigInt, Uint8List,
/// String, ...).
Future<R> offload<R>(R Function() computation) => Isolate.run(computation);
```

Create `packages/esp_prov_core/lib/src/crypto/offload_inline.dart`:

```dart
/// Runs [computation] inline. Used on the web, which has no isolates.
Future<R> offload<R>(R Function() computation) async => computation();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/bytes_test.dart test/crypto/offload_test.dart)`

Expected: `+8: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/crypto/bytes_test.dart \
  packages/esp_prov_core/test/crypto/offload_test.dart \
  packages/esp_prov_core/lib/src/crypto/bytes.dart \
  packages/esp_prov_core/lib/src/crypto/offload.dart \
  packages/esp_prov_core/lib/src/crypto/offload_isolate.dart \
  packages/esp_prov_core/lib/src/crypto/offload_inline.dart
git commit -m "feat(core): byte helpers and isolate offload" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.3: Byte-exact fixtures from Espressif's esp_prov

**Files:**
- Create: `packages/esp_prov_core/test/fixtures/*.json` (generated by the script, committed)
- Create: `tool/requirements.txt`
- Create: `tool/gen_fixtures.py`
- Test: `packages/esp_prov_core/test/support/fixtures.dart`
- Test: `packages/esp_prov_core/test/fixtures_test.dart`

**Interfaces:**
- Consumes: `fromHex` from Task 2.2.
- Produces: `tool/gen_fixtures.py`, `tool/requirements.txt`, five committed JSON
fixtures in `packages/esp_prov_core/test/fixtures/`
(`sec1_pop.json`, `sec1_no_pop_carry.json`, `sec2_example.json`,
`sec2_short_b.json`, `sec2_short_s.json`) and the test loader
`test/support/fixtures.dart`: `Map<String, Object?> loadFixture(String name)`,
`Uint8List hexField(Map<String, Object?> fixture, String key)`,
`List<Map<String, Object?>> messages(Map<String, Object?> fixture, [String key = 'messages'])`.
Fixture keys: sec1 `pop, client_private_key, client_public_key, device_private_key, device_public_key, device_random, session_key, session_cmd0, session_resp0, session_cmd1, session_resp1, client_verify_data, device_verify_data, messages[{direction, plain, cipher}]`;
sec2 `username, password, salt, verifier, a, b (hex ints), client_public_key, device_public_key, u, session_key, client_proof, device_proof, device_nonce, session_cmd0, session_resp0, session_cmd1, session_resp1, premaster_secret_length, messages_patch0/messages_patch1[{direction, nonce, plain, cipher}]` (messages only in `sec2_example.json`).

How the generator works (read before editing it):

- `esp_prov` moved out of ESP-IDF. On master it lives in idf-extra-components
  at `network_provisioning/tool/esp_prov`, and its `proto` package loads
  protocomm `*_pb2.py` from `$IDF_PATH/components/protocomm/python`. The
  script therefore sparse-clones both repositories at the same pinned
  commits as the vendored protos into `.cache/espressif/` (gitignored) and
  sets `IDF_PATH` before importing.
- Randomness is pinned by monkeypatching module attributes, not `os.urandom`:
  `security.security1.X25519PrivateKey` is swapped for a class whose
  `generate()` returns the fixed client key, and
  `security.srp6a.get_random_of_length` is replaced so `Srp6a.__init__` uses
  the fixed `a`.
- The device side is simulated in Python, mirroring the firmware
  (`security1.c`, `esp_srp.c`): `x = SHA512(salt | SHA512(I ":" p))` with
  the full 64-byte inner digest, `k = H(PAD(N) | PAD(g))`,
  `u = H(PAD(A) | PAD(B))`, `S = (A * v^u)^b`, `K = H(minimal(S))`,
  `M1 = H(H(N) xor H(PAD(g)) | H(I) | salt | A | B | K)` over the bytes as
  sent, `M2 = H(A | M1 | K)`. The script asserts esp_prov's M1 equals the
  firmware M1, and that the stock example's hard-coded verifier equals
  `g^x mod N`. So the fixtures prove the firmware formula, not just
  self-consistency.
- `sec2_example.json` uses the real salt and verifier from ESP-IDF v5.4.2
  `examples/provisioning/wifi_prov_mgr/main/app_main.c`. `sec2_short_b`
  and `sec2_short_s` search `b` until B (as sent) or S has a leading zero
  byte, which pins "B hashed exactly as received" and "K = H(S) unpadded".
- `sec1_no_pop_carry.json` uses an IV whose low 64 bits are `ff..fe`, so the
  AES-CTR counter carries into the high 64 bits on the second block
  (mbedTLS/esp_prov increment the full 128-bit counter).

`uv` is at `~/.local/bin/uv`; use the full path if it is not on PATH.
`cryptography` is already in system Python but `protobuf` is not, hence the
venv.

- [ ] **Step 1: Write the loader and the failing fixture test**

Create `packages/esp_prov_core/test/support/fixtures.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_prov_core/src/crypto/bytes.dart';

/// Loads `test/fixtures/<name>` produced by tool/gen_fixtures.py.
///
/// `dart test` runs with the package root as the working directory.
Map<String, Object?> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, Object?>;

/// Reads a hex field from a fixture map.
Uint8List hexField(Map<String, Object?> fixture, String key) =>
    fromHex(fixture[key]! as String);

/// Reads the list of message maps under [key].
List<Map<String, Object?>> messages(
  Map<String, Object?> fixture, [
  String key = 'messages',
]) => (fixture[key]! as List<Object?>).cast<Map<String, Object?>>();
```

Create `packages/esp_prov_core/test/fixtures_test.dart`:

```dart
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  test('fixtures were generated from the pinned Espressif commits', () {
    for (final name in [
      'sec1_pop.json',
      'sec1_no_pop_carry.json',
      'sec2_example.json',
      'sec2_short_b.json',
      'sec2_short_s.json',
    ]) {
      final generator = loadFixture(name)['generator']! as Map<String, Object?>;
      expect(
        generator['esp_idf'],
        '4d59230ddff16327812782151ef0afef202dc6d7',
        reason: name,
      );
      expect(
        generator['idf_extra_components'],
        '69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0',
        reason: name,
      );
    }
  });

  test('Security 2 edge-case fixtures exercise short B and short S', () {
    expect(
      hexField(loadFixture('sec2_short_b.json'), 'device_public_key'),
      hasLength(lessThan(384)),
    );
    expect(
      loadFixture('sec2_short_s.json')['premaster_secret_length'],
      lessThan(384),
    );
    expect(
      hexField(loadFixture('sec2_example.json'), 'client_public_key'),
      hasLength(384),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/fixtures_test.dart)`

Expected: FAIL: `PathNotFoundException: Cannot open file, path = 'test/fixtures/sec1_pop.json'`.

- [ ] **Step 3: Write the generator**

Create `tool/requirements.txt`:

```text
# Python deps for tool/gen_fixtures.py (install with: uv pip install -r tool/requirements.txt)
cryptography>=42
protobuf>=4.21,<6
```

Create `tool/gen_fixtures.py`:

```python
#!/usr/bin/env python3
# Generates byte-exact protocomm Security 1 / Security 2 fixtures by driving
# Espressif's own esp_prov Python modules against a simulated device that
# mirrors the firmware (components/protocomm/src/security/security1.c and
# components/protocomm/src/crypto/srp6a/esp_srp.c).
#
# Usage (from the repo root):
#   uv venv .venv && uv pip install --python .venv/bin/python -r tool/requirements.txt
#   .venv/bin/python tool/gen_fixtures.py
#
# Output: packages/esp_prov_core/test/fixtures/{sec1,sec2}*.json
import hashlib
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / '.cache' / 'espressif'
OUT = ROOT / 'packages' / 'esp_prov_core' / 'test' / 'fixtures'

# Keep in sync with third_party/espressif/proto/README.md.
IDF_URL = 'https://github.com/espressif/esp-idf.git'
IDF_COMMIT = '4d59230ddff16327812782151ef0afef202dc6d7'
IEC_URL = 'https://github.com/espressif/idf-extra-components.git'
IEC_COMMIT = '69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0'


def sparse_checkout(url: str, commit: str, dest: Path, paths: list) -> None:
    marker = dest / '.fixture-commit'
    if marker.exists() and marker.read_text().strip() == commit:
        return
    dest.mkdir(parents=True, exist_ok=True)

    def git(*args: str) -> None:
        subprocess.run(['git', '-C', str(dest), *args], check=True)

    if not (dest / '.git').exists():
        git('init', '-q')
        git('remote', 'add', 'origin', url)
    git('sparse-checkout', 'set', '--no-cone', *paths)
    git('fetch', '-q', '--depth', '1', '--filter=blob:none', 'origin', commit)
    git('checkout', '-q', 'FETCH_HEAD')
    marker.write_text(commit)


IDF_DIR = CACHE / 'esp-idf'
IEC_DIR = CACHE / 'idf-extra-components'
sparse_checkout(IDF_URL, IDF_COMMIT, IDF_DIR, ['/components/protocomm/python/'])
sparse_checkout(IEC_URL, IEC_COMMIT, IEC_DIR,
                ['/network_provisioning/tool/esp_prov/', '/network_provisioning/python/'])

# esp_prov's proto/__init__.py loads protocomm *_pb2.py from $IDF_PATH and the
# network_*_pb2.py files relative to the esp_prov directory.
os.environ['IDF_PATH'] = str(IDF_DIR)
sys.path.insert(0, str(IEC_DIR / 'network_provisioning' / 'tool' / 'esp_prov'))

import proto  # noqa: E402  (esp_prov/proto)
import security  # noqa: E402  (esp_prov/security)
from cryptography.hazmat.primitives import serialization  # noqa: E402
from cryptography.hazmat.primitives.asymmetric.x25519 import (  # noqa: E402
    X25519PrivateKey, X25519PublicKey)
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes  # noqa: E402
from cryptography.hazmat.primitives.ciphers.aead import AESGCM  # noqa: E402

sec1_module = sys.modules['security.security1']
srp_module = sys.modules['security.srp6a']
session_pb2 = proto.session_pb2
sec1_pb2 = proto.sec1_pb2
sec2_pb2 = proto.sec2_pb2
constants_pb2 = proto.constants_pb2


def hx(data: bytes) -> str:
    return data.hex()


def raw_public(private_key: X25519PrivateKey) -> bytes:
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)


def minimal(n: int) -> bytes:
    # mbedtls / esp_mpi_to_bin: big-endian, no leading zero bytes.
    return b'\x00' if n == 0 else n.to_bytes((n.bit_length() + 7) // 8, 'big')


def sha512(*parts: bytes) -> bytes:
    h = hashlib.sha512()
    for p in parts:
        h.update(p)
    return h.digest()


# Plaintexts exchanged after the handshake. Lengths 1, 5, 16, 17, 40 and 3
# make the AES-CTR keystream offset cross block boundaries in both directions.
SAMPLES = [
    ('client_to_device', b'\x01'),
    ('device_to_client', b'hello'),
    ('client_to_device', bytes(range(16))),
    ('device_to_client', bytes(range(100, 117))),
    ('client_to_device', b'{"ssid":"MyNetwork","passphrase":"x"}' + b'\x00\x01\x02'),
    ('device_to_client', b'end'),
]


# ---------------------------------------------------------------- Security 1
def make_sec1(name: str, pop: str, client_priv: bytes, device_priv: bytes,
              device_random: bytes) -> dict:
    class _FixedClientKey:
        @staticmethod
        def generate() -> X25519PrivateKey:
            return X25519PrivateKey.from_private_bytes(client_priv)

    # Security1.__generate_key() calls X25519PrivateKey.generate(); swap the
    # module-level name so the client key pair is deterministic.
    sec1_module.X25519PrivateKey = _FixedClientKey

    dev_key = X25519PrivateKey.from_private_bytes(device_priv)
    dev_pub = raw_public(dev_key)

    client = security.Security1(pop, False)
    cmd0 = client.security1_session(None).encode('latin-1')
    parsed0 = session_pb2.SessionData()
    parsed0.ParseFromString(cmd0)
    client_pub = parsed0.sec1.sc0.client_pubkey

    shared = dev_key.exchange(X25519PublicKey.from_public_bytes(client_pub))
    if pop:
        digest = hashlib.sha256(pop.encode()).digest()
        shared = bytes(a ^ b for a, b in zip(shared, digest))
    device_ctr = Cipher(algorithms.AES(shared), modes.CTR(device_random)).encryptor()

    resp0 = session_pb2.SessionData()
    resp0.sec_ver = session_pb2.SecScheme1
    resp0.sec1.msg = sec1_pb2.Session_Response0
    resp0.sec1.sr0.status = constants_pb2.Success
    resp0.sec1.sr0.device_pubkey = dev_pub
    resp0.sec1.sr0.device_random = device_random
    resp0_bytes = resp0.SerializeToString()

    cmd1 = client.security1_session(resp0_bytes.decode('latin-1')).encode('latin-1')
    parsed1 = session_pb2.SessionData()
    parsed1.ParseFromString(cmd1)
    client_verify = parsed1.sec1.sc1.client_verify_data
    assert device_ctr.update(client_verify) == dev_pub, 'device rejected client verify'
    device_verify = device_ctr.update(client_pub)

    resp1 = session_pb2.SessionData()
    resp1.sec_ver = session_pb2.SecScheme1
    resp1.sec1.msg = sec1_pb2.Session_Response1
    resp1.sec1.sr1.status = constants_pb2.Success
    resp1.sec1.sr1.device_verify_data = device_verify
    resp1_bytes = resp1.SerializeToString()
    assert client.security1_session(resp1_bytes.decode('latin-1')) is None

    messages = []
    for direction, plain in SAMPLES:
        if direction == 'client_to_device':
            cipher = client.encrypt_data(plain)
            assert device_ctr.update(cipher) == plain
        else:
            cipher = device_ctr.update(plain)
            assert client.decrypt_data(cipher) == plain
        messages.append({'direction': direction, 'plain': hx(plain), 'cipher': hx(cipher)})

    return {
        'name': name,
        'pop': pop,
        'client_private_key': hx(client_priv),
        'client_public_key': hx(client_pub),
        'device_private_key': hx(device_priv),
        'device_public_key': hx(dev_pub),
        'device_random': hx(device_random),
        'session_key': hx(shared),
        'session_cmd0': hx(cmd0),
        'session_resp0': hx(resp0_bytes),
        'session_cmd1': hx(cmd1),
        'session_resp1': hx(resp1_bytes),
        'client_verify_data': hx(client_verify),
        'device_verify_data': hx(device_verify),
        'messages': messages,
    }


# ---------------------------------------------------------------- Security 2
N, G = srp_module.get_ng(srp_module.NG_3072)
N_LEN = 384

# Salt and verifier hard-coded in ESP-IDF v5.4.2
# examples/provisioning/wifi_prov_mgr/main/app_main.c for wifiprov / abcd1234.
EXAMPLE_SALT = bytes.fromhex('036ee0c7bcb9eda84c9eac97d93decf4')
EXAMPLE_VERIFIER = bytes.fromhex(
    '7c7c85476508946dd636af37d7e8914378cffd616c59d2f83908127238de9e24'
    'a470261cdfa903c2b270e7b13224da111d9718dc607208cc9ac90c4827e2ae89'
    'aa1625b804d21a9b3a8f37f6e43a712ee127866eadce28ff5446601fb99687dc'
    '5740a7d46cc97754dc1682f0ed356ac470ad3d90b5819470d7bc65b2d518e02e'
    'c3a5f968dd647bb8b73c9cfc00d8717eb79a7cb1b7c2c318342932433e0099e9'
    '8294e3d82ab09629b7df0e5f08334076529132009f972c896c391ec828054417'
    '3f68028a9f4461d1f5a17e5a70d2c72381cb3868e42c20bc40577617bd08b896'
    'bc26eb32466935058c1570d91be9becca938a667f0ad5013197264bf52c234e2'
    '1b11797472bd345bb1e2fd6673fe716474d04ebc51241940870e9240e621e72d'
    '4e37762f2ee268c789e8321342068484534ab30c1b4c8d1c519719abae77ffdb'
    'ecf0109534336bcb3e840fb9d85fb8a0b855533e70f718f5ce7b4ebf27cecea8'
    'b3be40c5c532293e71649ede8cf675a1e6f653c831a878de5040f762de36b2ba'
)


def fw_x(salt: bytes, username: str, password: str) -> int:
    # esp_srp.c calculate_x: SHA512(salt | SHA512(I ":" p)), full 64-byte inner digest.
    inner = sha512(username.encode(), b':', password.encode())
    return int.from_bytes(sha512(salt, inner), 'big')


def fw_padded_hash(a: bytes, b: bytes) -> int:
    pad = lambda v: bytes(N_LEN - len(v)) + v  # noqa: E731
    return int.from_bytes(sha512(pad(a), pad(b)), 'big')


FW_K = fw_padded_hash(minimal(N), minimal(G))


def fw_h_n_xor_h_g() -> bytes:
    hn = sha512(minimal(N))
    hg = sha512(bytes(N_LEN - 1) + minimal(G))
    return bytes(x ^ y for x, y in zip(hn, hg))


def make_sec2(name: str, username: str, password: str, salt: bytes, verifier: bytes,
              a: int, b: int, device_nonce: bytes, with_messages: bool) -> dict:
    v = int.from_bytes(verifier, 'big')
    assert pow(G, fw_x(salt, username, password), N) == v, 'verifier does not match firmware x'
    # Python esp_prov strips leading zero bytes when it converts digests to
    # ints; these fixtures must avoid inputs where it would differ from firmware.
    assert salt[0] != 0
    assert sha512(username.encode(), b':', password.encode())[0] != 0

    srp_module.get_random_of_length = lambda nbytes: a  # deterministic client 'a'

    client = security.Security2(1, username, password, False)
    cmd0 = client.security2_session(None).encode('latin-1')
    p0 = session_pb2.SessionData()
    p0.ParseFromString(cmd0)
    a_bytes = p0.sec2.sc0.client_pubkey
    assert len(a_bytes) == N_LEN, 'fixed a must give a 384-byte A'
    assert p0.sec2.sc0.client_username == username.encode()

    big_b = (FW_K * v + pow(G, b, N)) % N
    b_bytes = minimal(big_b)

    resp0 = session_pb2.SessionData()
    resp0.sec_ver = session_pb2.SecScheme2
    resp0.sec2.msg = sec2_pb2.S2Session_Response0
    resp0.sec2.sr0.status = constants_pb2.Success
    resp0.sec2.sr0.device_pubkey = b_bytes
    resp0.sec2.sr0.device_salt = salt
    resp0_bytes = resp0.SerializeToString()

    cmd1 = client.security2_session(resp0_bytes.decode('latin-1')).encode('latin-1')
    p1 = session_pb2.SessionData()
    p1.ParseFromString(cmd1)
    m1 = p1.sec2.sc1.client_proof

    # Device side, mirroring esp_srp_get_session_key / esp_srp_exchange_proofs.
    big_a = int.from_bytes(a_bytes, 'big')
    u = fw_padded_hash(a_bytes, b_bytes)
    big_s = pow(big_a * pow(v, u, N) % N, b, N)
    session_key = sha512(minimal(big_s))
    expected_m1 = sha512(fw_h_n_xor_h_g(), sha512(username.encode()), salt, a_bytes,
                         b_bytes, session_key)
    assert m1 == expected_m1, 'esp_prov M1 differs from firmware M1'
    m2 = sha512(a_bytes, m1, session_key)

    resp1 = session_pb2.SessionData()
    resp1.sec_ver = session_pb2.SecScheme2
    resp1.sec2.msg = sec2_pb2.S2Session_Response1
    resp1.sec2.sr1.status = constants_pb2.Success
    resp1.sec2.sr1.device_proof = m2
    resp1.sec2.sr1.device_nonce = device_nonce
    resp1_bytes = resp1.SerializeToString()
    assert client.security2_session(resp1_bytes.decode('latin-1')) is None
    assert client.srp6a_ctx.authenticated()

    result = {
        'name': name,
        'username': username,
        'password': password,
        'salt': hx(salt),
        'verifier': hx(verifier),
        'a': format(a, 'x'),
        'b': format(b, 'x'),
        'client_public_key': hx(a_bytes),
        'device_public_key': hx(b_bytes),
        'u': format(u, 'x'),
        'session_key': hx(session_key),
        'client_proof': hx(m1),
        'device_proof': hx(m2),
        'device_nonce': hx(device_nonce),
        'session_cmd0': hx(cmd0),
        'session_resp0': hx(resp0_bytes),
        'session_cmd1': hx(cmd1),
        'session_resp1': hx(resp1_bytes),
        'premaster_secret_length': len(minimal(big_s)),
    }
    if with_messages:
        for patch in (0, 1):
            client.sec_patch_ver = patch
            client.nonce = bytearray(device_nonce)
            device_gcm = AESGCM(session_key[:32])
            device_counter = bytearray(device_nonce)
            messages = []
            for direction, plain in SAMPLES:
                nonce_used = bytes(device_counter)
                if direction == 'client_to_device':
                    cipher = client.encrypt_data(plain)
                    assert device_gcm.decrypt(nonce_used, cipher, None) == plain
                else:
                    cipher = device_gcm.encrypt(nonce_used, plain, None)
                    assert client.decrypt_data(cipher) == plain
                if patch == 1:
                    counter = struct.unpack('>I', device_counter[8:])[0] + 1
                    device_counter[8:] = struct.pack('>I', counter)
                messages.append({'direction': direction, 'nonce': hx(nonce_used),
                                 'plain': hx(plain), 'cipher': hx(cipher)})
            result[f'messages_patch{patch}'] = messages
    return result


def find_b(a: int, salt: bytes, verifier: bytes, predicate, start: int) -> int:
    v = int.from_bytes(verifier, 'big')
    a_bytes = minimal(pow(G, a, N))
    b = start
    while True:
        big_b = (FW_K * v + pow(G, b, N)) % N
        u = fw_padded_hash(a_bytes, minimal(big_b))
        big_s = pow(pow(G, a, N) * pow(v, u, N) % N, b, N)
        if predicate(minimal(big_b), minimal(big_s)):
            return b
        b += 1


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fixtures = {
        'sec1_pop.json': make_sec1(
            'sec1 with PoP abcd1234', 'abcd1234',
            client_priv=bytes(range(1, 33)),
            device_priv=bytes(range(0x41, 0x61)),
            device_random=bytes.fromhex('0f1e2d3c4b5a69788796a5b4c3d2e1f0')),
        'sec1_no_pop_carry.json': make_sec1(
            'sec1 without PoP, IV low 64 bits at 0xff..fe (counter carry)', '',
            client_priv=bytes(range(0x80, 0xa0)),
            device_priv=bytes(range(0xc0, 0xe0)),
            device_random=bytes.fromhex('0123456789abcdeffffffffffffffffe')),
    }

    a = (1 << 255) | int.from_bytes(sha512(b'esp_prov fixture a')[:32], 'big')
    b = int.from_bytes(sha512(b'esp_prov fixture b')[:32], 'big')
    nonce = bytes.fromhex('a1b2c3d4e5f60718') + struct.pack('>I', 1)
    fixtures['sec2_example.json'] = make_sec2(
        'sec2 wifiprov/abcd1234 with the wifi_prov_mgr example salt and verifier',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, b, nonce, True)

    short_b = find_b(a, EXAMPLE_SALT, EXAMPLE_VERIFIER,
                     lambda bb, ss: len(bb) < N_LEN, start=b + 1)
    fixtures['sec2_short_b.json'] = make_sec2(
        'sec2 where the device public key B serialises to fewer than 384 bytes',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, short_b, nonce, False)

    short_s = find_b(a, EXAMPLE_SALT, EXAMPLE_VERIFIER,
                     lambda bb, ss: len(bb) == N_LEN and len(ss) < N_LEN, start=b + 1)
    fixtures['sec2_short_s.json'] = make_sec2(
        'sec2 where the premaster secret S has a leading zero byte (K = H(S) unpadded)',
        'wifiprov', 'abcd1234', EXAMPLE_SALT, EXAMPLE_VERIFIER, a, short_s, nonce, False)

    for file_name, data in fixtures.items():
        data['generator'] = {'esp_idf': IDF_COMMIT, 'idf_extra_components': IEC_COMMIT}
        (OUT / file_name).write_text(json.dumps(data, indent=2) + '\n')
        print(f'wrote {OUT / file_name}')


if __name__ == '__main__':
    main()
```

- [ ] **Step 4: Generate the fixtures**

Run: `uv venv .venv && uv pip install --python .venv/bin/python -r tool/requirements.txt && .venv/bin/python tool/gen_fixtures.py`

Expected: five lines `wrote .../packages/esp_prov_core/test/fixtures/<name>.json`
(sec1_pop, sec1_no_pop_carry, sec2_example, sec2_short_b, sec2_short_s) and
exit code 0. The first run spends about 15 s on two shallow sparse
clones. An `AssertionError` here means the simulated firmware and esp_prov
disagree: stop and investigate, do not edit the assertion.

- [ ] **Step 5: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/fixtures_test.dart)`

Expected: `+2: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/support/fixtures.dart \
  packages/esp_prov_core/test/fixtures_test.dart \
  tool/requirements.txt \
  tool/gen_fixtures.py \
  packages/esp_prov_core/test/fixtures
git commit -m "test(core): generate protocomm fixtures with Espressif esp_prov" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.4: AesCtrStream: one continuous AES-256-CTR keystream

**Files:**
- Create: `packages/esp_prov_core/lib/src/crypto/aes_ctr_stream.dart`
- Test: `packages/esp_prov_core/test/crypto/aes_ctr_stream_test.dart`

**Interfaces:**
- Consumes: `fromHex`, `toHex` (Task 2.2); fixtures and loader (Task 2.3).
- Produces: `package:esp_prov_core/src/crypto/aes_ctr_stream.dart`:
`final class AesCtrStream { new({required List<int> key, required List<int> iv}); int get offset; Future<Uint8List> apply(List<int> data); static Uint8List counterBlock(List<int> iv, int blockIndex); }`

Security 1 uses one CTR context for the whole session: the client's
encrypts and decrypts consume the same keystream in order (esp_prov calls
`cipher.update()` for both). `cryptography_plus` only has one-shot
`AesCtr.encrypt(clearText, secretKey:, nonce:)`. For it, a 16-byte nonce is
the initial counter block, and the Dart backend increments the whole 128-bit
block big-endian. `apply()` therefore works like this:

1. Reserve `[offset, offset + n)` synchronously, so overlapping calls never
   share bytes.
2. `skip = offset % 16`, `blocks = ceil((skip + n) / 16)`.
3. The counter for block `offset ~/ 16` is `iv + blockIndex` as a 128-bit
   big-endian add with full carry (`counterBlock`).
4. Encrypt `blocks * 16` zero bytes from that counter to get the keystream,
   then XOR `data[i] ^ keystream[skip + i]`.
5. WebCrypto increments only the low 64 bits (`counterBits` 64), so runs are
   split wherever the low 64 bits would wrap and each split gets a freshly
   derived counter. The keystream is then identical on every backend.

`AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty)` is the verified
cryptography_plus 3.0.0 API (`MacAlgorithm.empty` is a static const).

- [ ] **Step 1: Write the failing test**

The hand-derived tests pin the counter arithmetic; the fixture tests replay the exact esp_prov keystream, including the 64-bit carry case.

Create `packages/esp_prov_core/test/crypto/aes_ctr_stream_test.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  group('counterBlock', () {
    test('adds the block index big-endian', () {
      final iv = fromHex('000102030405060708090a0b0c0d0e0f');
      expect(
        toHex(AesCtrStream.counterBlock(iv, 0x0101)),
        '000102030405060708090a0b0c0d0f10',
      );
    });

    test('carries across all 16 bytes', () {
      final iv = fromHex('0123456789abcdefffffffffffffffff');
      expect(
        toHex(AesCtrStream.counterBlock(iv, 1)),
        '0123456789abcdf00000000000000000',
      );
    });

    test('wraps modulo 2^128', () {
      final iv = Uint8List(16)..fillRange(0, 16, 0xff);
      expect(toHex(AesCtrStream.counterBlock(iv, 2)), '${'0' * 31}1');
    });
  });

  group('apply', () {
    final key = List<int>.generate(32, (i) => i);
    final iv = List<int>.generate(16, (i) => 0xf0 + i);
    final data = List<int>.generate(70, (i) => (i * 7) & 0xff);

    test('chunked calls equal one call (keystream offset is kept)', () async {
      final whole = await AesCtrStream(key: key, iv: iv).apply(data);
      final chunked = AesCtrStream(key: key, iv: iv);
      final parts = <int>[];
      for (final size in [1, 15, 16, 3, 35]) {
        final start = parts.length;
        parts.addAll(await chunked.apply(data.sublist(start, start + size)));
      }
      expect(parts, whole);
      expect(chunked.offset, 70);
    });

    test('is its own inverse on a fresh stream', () async {
      final cipher = await AesCtrStream(key: key, iv: iv).apply(data);
      final plain = await AesCtrStream(key: key, iv: iv).apply(cipher);
      expect(plain, data);
    });

    test('overlapping calls reserve distinct keystream ranges', () async {
      final whole = await AesCtrStream(key: key, iv: iv).apply(data);
      final stream = AesCtrStream(key: key, iv: iv);
      final results = await Future.wait([
        stream.apply(data.sublist(0, 20)),
        stream.apply(data.sublist(20)),
      ]);
      expect([...results[0], ...results[1]], whole);
    });

    test('empty input consumes nothing', () async {
      final stream = AesCtrStream(key: key, iv: iv);
      expect(await stream.apply(const []), isEmpty);
      expect(stream.offset, 0);
    });

    test('rejects wrong key and IV sizes', () {
      expect(() => AesCtrStream(key: [1], iv: iv), throwsArgumentError);
      expect(() => AesCtrStream(key: key, iv: [1]), throwsArgumentError);
    });
  });

  for (final name in ['sec1_pop.json', 'sec1_no_pop_carry.json']) {
    test('matches the esp_prov keystream in $name', () async {
      final f = loadFixture(name);
      final stream = AesCtrStream(
        key: hexField(f, 'session_key'),
        iv: hexField(f, 'device_random'),
      );
      expect(
        await stream.apply(hexField(f, 'device_public_key')),
        hexField(f, 'client_verify_data'),
      );
      expect(
        await stream.apply(hexField(f, 'client_public_key')),
        hexField(f, 'device_verify_data'),
      );
      for (final m in messages(f)) {
        expect(
          await stream.apply(hexField(m, 'plain')),
          hexField(m, 'cipher'),
          reason: 'message ${m['direction']} ${m['plain']}',
        );
      }
    });
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/aes_ctr_stream_test.dart)`

Expected: FAIL: `Error when reading 'lib/src/crypto/aes_ctr_stream.dart'`.

- [ ] **Step 3: Implement AesCtrStream**

Create `packages/esp_prov_core/lib/src/crypto/aes_ctr_stream.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';

/// One continuous AES-256-CTR keystream, as used by protocomm Security 1.
///
/// The device and esp_prov use a single CTR context for the whole session:
/// every encrypt and every decrypt consumes the next bytes of the same
/// keystream. [apply] therefore keeps a byte [offset] across calls.
///
/// cryptography_plus only offers one-shot encryption, so each call derives
/// the counter block for `offset ~/ 16` itself (16-byte IV plus block index,
/// big-endian, full 128-bit carry like mbedTLS), encrypts zero bytes from that
/// counter to get the keystream, and XORs it with the data, skipping the
/// `offset % 16` bytes already used in the first block. Runs are split where
/// the low 64 bits of the counter wrap, so backends that only increment a
/// 64-bit counter (WebCrypto) still produce the mbedTLS keystream.
final class AesCtrStream {
  /// Creates a stream for a 32-byte [key] and 16-byte [iv].
  new({required List<int> key, required List<int> iv})
    : _key = SecretKeyData(List<int>.of(key)),
      _iv = Uint8List.fromList(iv) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
    if (iv.length != 16) {
      throw ArgumentError.value(iv.length, 'iv', 'must be 16 bytes');
    }
  }

  static const _blockSize = 16;
  static final BigInt _two64 = BigInt.one << 64;

  final AesCtr _aes = AesCtr.with256bits(macAlgorithm: MacAlgorithm.empty);
  final SecretKeyData _key;
  final Uint8List _iv;
  int _offset = 0;

  /// Number of keystream bytes consumed so far.
  int get offset => _offset;

  /// XORs [data] with the next `data.length` keystream bytes.
  ///
  /// Encryption and decryption are the same operation. The keystream range is
  /// reserved synchronously, so overlapping calls never reuse bytes.
  Future<Uint8List> apply(List<int> data) async {
    if (data.isEmpty) return Uint8List(0);
    final start = _offset;
    _offset += data.length;

    final skip = start % _blockSize;
    final totalBlocks = (skip + data.length + _blockSize - 1) ~/ _blockSize;
    final keystream = Uint8List(totalBlocks * _blockSize);

    var done = 0;
    var block = start ~/ _blockSize;
    while (done < totalBlocks) {
      final counter = counterBlock(_iv, block);
      final run = math.min(totalBlocks - done, _blocksBeforeLow64Wrap(counter));
      final box = await _aes.encrypt(
        Uint8List(run * _blockSize),
        secretKey: _key,
        nonce: counter,
      );
      keystream.setRange(
        done * _blockSize,
        (done + run) * _blockSize,
        box.cipherText,
      );
      done += run;
      block += run;
    }

    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ keystream[skip + i];
    }
    return out;
  }

  /// The counter block for [blockIndex]: [iv] + [blockIndex] as a 128-bit
  /// big-endian integer, wrapping modulo 2^128.
  static Uint8List counterBlock(List<int> iv, int blockIndex) {
    if (blockIndex < 0) {
      throw ArgumentError.value(blockIndex, 'blockIndex', 'must be >= 0');
    }
    final out = Uint8List.fromList(iv);
    var carry = blockIndex;
    for (var i = out.length - 1; i >= 0 && carry != 0; i--) {
      final sum = out[i] + (carry & 0xff);
      out[i] = sum & 0xff;
      carry = (carry >> 8) + (sum >> 8);
    }
    return out;
  }

  static int _blocksBeforeLow64Wrap(Uint8List counter) {
    var low = BigInt.zero;
    for (var i = 8; i < 16; i++) {
      low = (low << 8) | BigInt.from(counter[i]);
    }
    final remaining = _two64 - low;
    return remaining > BigInt.from(1 << 30) ? 1 << 30 : remaining.toInt();
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/aes_ctr_stream_test.dart)`

Expected: `+10: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/crypto/aes_ctr_stream_test.dart \
  packages/esp_prov_core/lib/src/crypto/aes_ctr_stream.dart
git commit -m "feat(core): continuous AES-CTR keystream for Security 1" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.5: AesGcmCounter: Security 2 AES-256-GCM with the nonce counter

**Files:**
- Create: `packages/esp_prov_core/lib/src/crypto/aes_gcm_counter.dart`
- Test: `packages/esp_prov_core/test/crypto/aes_gcm_counter_test.dart`

**Interfaces:**
- Consumes: `CryptoException` (Task 2.1), helpers (2.2), fixtures (2.3).
- Produces: `package:esp_prov_core/src/crypto/aes_gcm_counter.dart`:
`final class AesGcmCounter { new({required List<int> key, required List<int> nonce, required bool incrementNonce}); static const tagLength = 16; final bool incrementNonce; Uint8List get currentNonce; Future<Uint8List> encrypt(List<int> plain); Future<Uint8List> decrypt(List<int> cipherWithTag); }`

Rules (facts doc, Security 2): key = `K[0:32]`; 12-byte nonce = the
device's `device_nonce` (8-byte session id + 4-byte big-endian counter,
starting at whatever the device sent, normally 1); 16-byte tag appended; no
AAD. With `sec_patch_ver >= 1` the counter is incremented after every
encrypt and every decrypt, one counter shared by both directions. With 0 it
is fixed (legacy firmware). The counter value `0xffffffff` is used once,
then every later call throws `CryptoException` instead of reusing a nonce.

`AesGcm.with256bits()` defaults to `nonceLength: 12`. Passing it explicitly
trips `avoid_redundant_argument_values`, so the code relies on the default.
`SecretBox.concatenation(nonce: false)` gives `ciphertext | tag`, and
`SecretBox.fromConcatenation(data, nonceLength: 0, macLength: 16)` splits it.
A tag mismatch throws `SecretBoxAuthenticationError`, which is mapped to
`CryptoException`.

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_core/test/crypto/aes_gcm_counter_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);

  test('patch 1 increments the shared counter after each operation', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: true,
    );
    await gcm.encrypt([1, 2, 3]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000002');
    final peer = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000002'),
      incrementNonce: true,
    );
    await gcm.decrypt(await peer.encrypt([4]));
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000003');
  });

  test('counter carries into higher counter bytes', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f60718000000ff'),
      incrementNonce: true,
    );
    await gcm.encrypt([1]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000100');
  });

  test('patch 0 keeps the nonce fixed', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: false,
    );
    await gcm.encrypt([1]);
    await gcm.encrypt([2]);
    expect(toHex(gcm.currentNonce), 'a1b2c3d4e5f6071800000001');
  });

  test('counter overflow throws instead of reusing a nonce', () async {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f60718ffffffff'),
      incrementNonce: true,
    );
    await gcm.encrypt([1]);
    expect(() => gcm.encrypt([2]), throwsA(isA<CryptoException>()));
  });

  test('a modified tag throws CryptoException', () async {
    final nonce = fromHex('a1b2c3d4e5f6071800000001');
    final sealed = await AesGcmCounter(
      key: key,
      nonce: nonce,
      incrementNonce: true,
    ).encrypt([1, 2, 3]);
    sealed[sealed.length - 1] ^= 1;
    final gcm = AesGcmCounter(key: key, nonce: nonce, incrementNonce: true);
    expect(() => gcm.decrypt(sealed), throwsA(isA<CryptoException>()));
  });

  test('input shorter than the tag throws CryptoException', () {
    final gcm = AesGcmCounter(
      key: key,
      nonce: fromHex('a1b2c3d4e5f6071800000001'),
      incrementNonce: true,
    );
    expect(() => gcm.decrypt([1, 2, 3]), throwsA(isA<CryptoException>()));
  });

  for (final patch in [0, 1]) {
    test('matches esp_prov AES-GCM samples for sec_patch_ver $patch', () async {
      final f = loadFixture('sec2_example.json');
      final gcm = AesGcmCounter(
        key: hexField(f, 'session_key').sublist(0, 32),
        nonce: hexField(f, 'device_nonce'),
        incrementNonce: patch == 1,
      );
      for (final m in messages(f, 'messages_patch$patch')) {
        expect(toHex(gcm.currentNonce), m['nonce']);
        if (m['direction'] == 'client_to_device') {
          expect(
            await gcm.encrypt(hexField(m, 'plain')),
            hexField(m, 'cipher'),
          );
        } else {
          expect(
            await gcm.decrypt(hexField(m, 'cipher')),
            hexField(m, 'plain'),
          );
        }
      }
    });
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/aes_gcm_counter_test.dart)`

Expected: FAIL: `Error when reading 'lib/src/crypto/aes_gcm_counter.dart'`.

- [ ] **Step 3: Implement AesGcmCounter**

Create `packages/esp_prov_core/lib/src/crypto/aes_gcm_counter.dart`:

```dart
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';

/// AES-256-GCM with the protocomm Security 2 nonce rules.
///
/// The 12-byte nonce starts as the device's `device_nonce` (8-byte session id
/// followed by a 4-byte big-endian counter). With [incrementNonce] (firmware
/// `sec_patch_ver >= 1`) the counter is incremented after every encrypt and
/// every decrypt, one counter shared by both directions. Without it (legacy
/// `sec_patch_ver == 0` firmware) the nonce never changes. The 16-byte tag is
/// appended to the ciphertext and there is no associated data.
final class AesGcmCounter {
  /// Creates a cipher from the first 32 bytes of the SRP session key [key],
  /// the device [nonce] and the patch-level nonce rule.
  new({
    required List<int> key,
    required List<int> nonce,
    required this.incrementNonce,
  }) : _key = SecretKeyData(List<int>.of(key)),
       _nonce = Uint8List.fromList(nonce) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
    if (nonce.length != 12) {
      throw ArgumentError.value(nonce.length, 'nonce', 'must be 12 bytes');
    }
  }

  /// Length of the authentication tag appended to every ciphertext.
  static const tagLength = 16;

  /// Whether the counter advances after each operation.
  final bool incrementNonce;

  final AesGcm _gcm = AesGcm.with256bits();
  final SecretKeyData _key;
  final Uint8List _nonce;
  bool _exhausted = false;

  /// The nonce the next encrypt or decrypt will use.
  Uint8List get currentNonce => Uint8List.fromList(_nonce);

  /// Encrypts [plain] and returns `ciphertext | tag`.
  Future<Uint8List> encrypt(List<int> plain) async {
    final nonce = _takeNonce();
    final box = await _gcm.encrypt(plain, secretKey: _key, nonce: nonce);
    return box.concatenation(nonce: false);
  }

  /// Decrypts `ciphertext | tag`. Throws [CryptoException] if the tag does
  /// not verify or the input is shorter than the tag.
  Future<Uint8List> decrypt(List<int> cipherWithTag) async {
    final nonce = _takeNonce();
    if (cipherWithTag.length < tagLength) {
      throw CryptoException(
        'Ciphertext of ${cipherWithTag.length} bytes is shorter than the '
        '$tagLength-byte GCM tag.',
      );
    }
    final box = SecretBox.fromConcatenation(
      cipherWithTag,
      nonceLength: 0,
      macLength: tagLength,
    );
    try {
      final plain = await _gcm.decrypt(
        SecretBox(box.cipherText, nonce: nonce, mac: box.mac),
        secretKey: _key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const CryptoException(
        'AES-GCM tag mismatch: the response was not produced with this '
        'session key and nonce.',
      );
    }
  }

  Uint8List _takeNonce() {
    if (_exhausted) {
      throw const CryptoException('AES-GCM nonce counter overflow.');
    }
    final used = Uint8List.fromList(_nonce);
    if (incrementNonce) {
      final view = ByteData.sublistView(_nonce);
      final counter = view.getUint32(8);
      if (counter == 0xffffffff) {
        _exhausted = true;
      } else {
        view.setUint32(8, counter + 1);
      }
    }
    return used;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/aes_gcm_counter_test.dart)`

Expected: `+8: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/crypto/aes_gcm_counter_test.dart \
  packages/esp_prov_core/lib/src/crypto/aes_gcm_counter.dart
git commit -m "feat(core): AES-GCM with protocomm nonce counter" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.6: Srp6aClient: Espressif SRP-6a on BigInt

**Files:**
- Create: `packages/esp_prov_core/lib/src/crypto/srp6a.dart`
- Test: `packages/esp_prov_core/test/crypto/srp6a_test.dart`

**Interfaces:**
- Consumes: `HandshakeFailed` (2.1), byte helpers (2.2), fixtures (2.3).
- Produces: `package:esp_prov_core/src/crypto/srp6a.dart`:
`final class Srp6aProof { final Uint8List clientProof /*M1*/; final Uint8List expectedServerProof /*M2*/; final Uint8List sessionKey /*K, 64 bytes*/; }`
`abstract final class Srp6aClient { static final BigInt n; static final BigInt g; static const nLength = 384; static final BigInt k; static BigInt randomPrivateKey([Random? random]); static Uint8List? publicKey(BigInt a); static Srp6aProof computeProof({required String username, required String password, required BigInt a, required Uint8List clientPublicKey, required Uint8List salt, required Uint8List serverPublicKey}); }`

Exact formulas, with padding stated per term. Source: facts doc
(Security 2 line), cross-checked against ESP-IDF
`components/protocomm/src/crypto/srp6a/esp_srp.c` and esp_prov
`security/srp6a.py`. `PAD(x)` means left-pad to 384 bytes; "as sent"
means the exact bytes on the wire.

| Term | Formula | Padding |
|---|---|---|
| N, g | RFC 5054 3072-bit prime, g = 5 | N is 384 bytes |
| k | `H(PAD(N) \| PAD(g))` | both padded (`calculate_k`) |
| a | 256 random bits, top bit set (esp_prov `get_random_of_length(32)`) | |
| A | `g^a mod N` | must be exactly 384 bytes, else draw a new `a`: the device hashes A as received, esp_prov re-encodes it minimally |
| x | `H(salt \| H(I ":" p))` | salt as sent; inner digest full 64 bytes (`esp_srp.c calculate_x`) |
| u | `H(PAD(A) \| PAD(B))` | both padded; reject u = 0 |
| S | `(B - k*g^x)^(a + u*x) mod N` | reject `B mod N = 0` first |
| K | `H(S)` | S minimal big-endian, not padded (`esp_mpi_to_bin`) |
| M1 | `H(H(N) xor H(PAD(g)) \| H(I) \| salt \| A \| B \| K)` | H(g) over g padded to 384 (`H_N_xor_g`, `hash_g` with `pad_len`); salt, A, B as sent |
| M2 | `H(A \| M1 \| K)` | A as sent |

H is SHA-512 from `package:crypto`. Python esp_prov strips leading zeros
from the salt and the inner digest when it converts them to ints. The
firmware does not, and the firmware is what we talk to; the fixtures avoid
inputs where the two differ. `computeProof` is pure and CPU-heavy: callers
run it through `offload` (Task 2.9).

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_core/test/crypto/srp6a_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

void main() {
  test('group constants are RFC 5054 3072-bit with g = 5', () {
    expect(Srp6aClient.n.bitLength, 3072);
    expect(Srp6aClient.g, BigInt.from(5));
    expect(bigIntToBytes(Srp6aClient.n).length, Srp6aClient.nLength);
  });

  test('random private key is 256 bits with the top bit set', () {
    final a = Srp6aClient.randomPrivateKey();
    expect(a.bitLength, 256);
  });

  test('publicKey returns null when A has a leading zero byte', () {
    // a = 0 gives A = 1, which serialises to a single byte.
    expect(Srp6aClient.publicKey(BigInt.zero), isNull);
  });

  test('x uses the salt bytes as sent, including a leading zero', () {
    // esp_srp.c hashes the raw salt buffer; Python esp_prov would strip the
    // leading zero. Both salts below must produce different verifiers.
    final inner = sha512.convert(utf8.encode('wifiprov:abcd1234')).bytes;
    final withZero = sha512.convert([0, 1, 2, ...inner]).bytes;
    final stripped = sha512.convert([1, 2, ...inner]).bytes;
    expect(withZero, isNot(stripped));
  });

  for (final name in [
    'sec2_example.json',
    'sec2_short_b.json',
    'sec2_short_s.json',
  ]) {
    test('A, M1, M2 and K match esp_prov for $name', () {
      final f = loadFixture(name);
      final a = BigInt.parse(f['a']! as String, radix: 16);
      final clientPublic = Srp6aClient.publicKey(a);
      expect(clientPublic, hexField(f, 'client_public_key'));
      expect(clientPublic!.length, 384);

      final proof = Srp6aClient.computeProof(
        username: f['username']! as String,
        password: f['password']! as String,
        a: a,
        clientPublicKey: clientPublic,
        salt: hexField(f, 'salt'),
        serverPublicKey: hexField(f, 'device_public_key'),
      );
      expect(proof.clientProof, hexField(f, 'client_proof'));
      expect(proof.expectedServerProof, hexField(f, 'device_proof'));
      expect(proof.sessionKey, hexField(f, 'session_key'));
    });
  }

  test('B = 0 (mod N) is rejected', () {
    final f = loadFixture('sec2_example.json');
    expect(
      () => Srp6aClient.computeProof(
        username: 'wifiprov',
        password: 'abcd1234',
        a: BigInt.parse(f['a']! as String, radix: 16),
        clientPublicKey: hexField(f, 'client_public_key'),
        salt: hexField(f, 'salt'),
        serverPublicKey: bigIntToBytes(Srp6aClient.n),
      ),
      throwsA(isA<HandshakeFailed>()),
    );
    expect(
      () => Srp6aClient.computeProof(
        username: 'wifiprov',
        password: 'abcd1234',
        a: BigInt.one,
        clientPublicKey: Uint8List(384),
        salt: hexField(f, 'salt'),
        serverPublicKey: Uint8List(1),
      ),
      throwsA(isA<HandshakeFailed>()),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/srp6a_test.dart)`

Expected: FAIL: `Error when reading 'lib/src/crypto/srp6a.dart'`.

- [ ] **Step 3: Implement Srp6aClient**

Create `packages/esp_prov_core/lib/src/crypto/srp6a.dart`:

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';

/// Output of the client side of the SRP-6a exchange.
final class Srp6aProof {
  /// Creates a proof bundle.
  const new({
    required this.clientProof,
    required this.expectedServerProof,
    required this.sessionKey,
  });

  /// M1, sent to the device in `S2SessionCmd1.client_proof`.
  final Uint8List clientProof;

  /// M2 the device must return in `S2SessionResp1.device_proof`.
  final Uint8List expectedServerProof;

  /// K = H(S), 64 bytes. The AES-GCM key is its first 32 bytes.
  final Uint8List sessionKey;
}

/// SRP-6a exactly as ESP-IDF `esp_srp.c` (device) and esp_prov `srp6a.py`
/// (host) implement it: RFC 5054 3072-bit group, g = 5, SHA-512.
///
/// Byte conventions (verified against esp_srp.c; see
/// docs/research/2026-10-05-esp-provisioning-facts.md):
/// * `PAD(x)` = x left-padded with zeros to 384 bytes. Used for N and g in
///   k, for A and B in u, and for g in H(g).
/// * `x = H(s | H(I ":" p))` with the salt bytes exactly as the device sent
///   them and the full 64-byte inner digest.
/// * `K = H(S)` with S in minimal big-endian form (no padding).
/// * `M1 = H(H(N) xor H(PAD(g)) | H(I) | s | A | B | K)` with A as sent
///   (always 384 bytes) and B exactly as the device sent it.
/// * `M2 = H(A | M1 | K)`.
abstract final class Srp6aClient {
  /// RFC 5054 3072-bit prime N.
  static final BigInt n = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74'
    '020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F1437'
    '4FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF05'
    '98DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB'
    '9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF695581718'
    '3995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33'
    'A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7'
    'ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864'
    'D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E2'
    '08E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF',
    radix: 16,
  );

  /// Generator g = 5.
  static final BigInt g = BigInt.from(5);

  /// Byte length of N; A must serialise to exactly this many bytes.
  static const nLength = 384;

  /// Multiplier k = H(N | PAD(g)).
  static final BigInt k = bytesToBigInt(
    _h([bigIntToBytes(n, length: nLength), bigIntToBytes(g, length: nLength)]),
  );

  /// A random 256-bit private exponent with the top bit set, like esp_prov.
  static BigInt randomPrivateKey([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
    bytes[0] |= 0x80;
    return bytesToBigInt(bytes);
  }

  /// A = g^a mod N as exactly [nLength] bytes, or `null` when A has a leading
  /// zero byte. The device hashes A as received while esp_prov re-encodes it
  /// minimally, so callers must pick a new `a` when this returns `null`.
  static Uint8List? publicKey(BigInt a) {
    final bigA = g.modPow(a, n);
    if ((bigA.bitLength + 7) >> 3 != nLength) return null;
    return bigIntToBytes(bigA, length: nLength);
  }

  /// Computes the proofs and session key. CPU-heavy: run via `offload`.
  ///
  /// Throws [HandshakeFailed] when `B % N == 0` or `u == 0`.
  static Srp6aProof computeProof({
    required String username,
    required String password,
    required BigInt a,
    required Uint8List clientPublicKey,
    required Uint8List salt,
    required Uint8List serverPublicKey,
  }) {
    final bigB = bytesToBigInt(serverPublicKey);
    if (bigB % n == BigInt.zero) {
      throw const HandshakeFailed('Device sent an invalid SRP public key.');
    }
    if (serverPublicKey.length > nLength) {
      throw const HandshakeFailed('Device SRP public key is too long.');
    }
    final u = bytesToBigInt(
      _h([
        bigIntToBytes(bytesToBigInt(clientPublicKey), length: nLength),
        bigIntToBytes(bigB, length: nLength),
      ]),
    );
    if (u == BigInt.zero) {
      throw const HandshakeFailed('SRP scrambling parameter u is zero.');
    }

    final user = utf8.encode(username);
    final inner = _h([user, utf8.encode(':'), utf8.encode(password)]);
    final x = bytesToBigInt(_h([salt, inner]));
    final v = g.modPow(x, n);
    final base = (bigB - k * v % n) % n;
    final s = base.modPow(a + u * x, n);
    final sessionKey = _h([bigIntToBytes(s)]);

    final hN = _h([bigIntToBytes(n, length: nLength)]);
    final hG = _h([bigIntToBytes(g, length: nLength)]);
    final m1 = _h([
      xorBytes(hN, hG),
      _h([user]),
      salt,
      clientPublicKey,
      serverPublicKey,
      sessionKey,
    ]);
    final m2 = _h([clientPublicKey, m1, sessionKey]);
    return Srp6aProof(
      clientProof: m1,
      expectedServerProof: m2,
      sessionKey: sessionKey,
    );
  }

  static Uint8List _h(List<List<int>> parts) =>
      Uint8List.fromList(sha512.convert(concatBytes(parts)).bytes);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/crypto/srp6a_test.dart)`

Expected: `+8: All tests passed!` (A, M1, M2 and K byte-identical to esp_prov for all three Security 2 fixtures).

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/crypto/srp6a_test.dart \
  packages/esp_prov_core/lib/src/crypto/srp6a.dart
git commit -m "feat(core): SRP-6a client matching esp_srp.c" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.7: SecurityScheme and Security 0

**Files:**
- Create: `packages/esp_prov_core/lib/src/security/security_scheme.dart`
- Create: `packages/esp_prov_core/lib/src/security/security0.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/support/replay_transport.dart`
- Test: `packages/esp_prov_core/test/security/security0_test.dart`

**Interfaces:**
- Consumes: errors and `ProvTransport` (2.1), generated protos (1.1).
- Produces: Exported: `sealed class SecurityScheme { int get version; Future<void> handshake(ProvTransport transport); Future<Uint8List> encrypt(Uint8List plain); Future<Uint8List> decrypt(Uint8List cipher); }`
and `final class Security0 extends SecurityScheme`. Library-private helpers in
`security_scheme.dart` that the `part` files use: `_exchange`, `_checkStatus`,
`_checkScheme`. Test helper `test/support/replay_transport.dart`:
`final class Exchange { const new(String endpoint, List<int>? request, List<int> response, {Exception? error}); }`,
`final class ReplayTransport implements ProvTransport { new(List<Exchange> exchanges, {Set<String> endpoints}); final List<(String, Uint8List)> sent; }`.

Spec deviation, deliberate: spec 3.3 shows synchronous
`Uint8List encrypt/decrypt`, but cryptography_plus is asynchronous, so they
return `Future<Uint8List>`. `EspSession` (Phase 3) is already async, so
callers do not notice.

`SecurityScheme` is sealed, so its subclasses must be in the same library.
They live in `part` files (`security0.dart` ... `security2.dart`), and only
`security_scheme.dart` has imports. Tasks 2.8 and 2.9 replace that file to
add their imports and `part` lines.

protobuf.dart serializes a proto3 enum field that was explicitly set, even
to its default 0 (`08 00`); Python omits it. Every command whose `msg` is
0 therefore leaves `msg` unset, so requests match esp_prov byte for byte
(the fixture tests compare whole request buffers).

- [ ] **Step 1: Write the replay transport and the failing test**

Create `packages/esp_prov_core/test/support/replay_transport.dart`:

```dart
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
```

Create `packages/esp_prov_core/test/security/security0_test.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/replay_transport.dart';

List<int> _resp(pb.Status status) => pb.SessionData(
  secVer: pb.SecSchemeVersion.SecScheme0,
  sec0: pb.Sec0Payload(
    msg: pb.Sec0MsgType.S0_Session_Response,
    sr: pb.S0SessionResp(status: status),
  ),
).writeToBuffer();

void main() {
  test('handshake sends S0SessionCmd and accepts Success', () async {
    final transport = ReplayTransport([
      Exchange('prov-session', null, _resp(pb.Status.Success)),
    ]);
    final scheme = Security0();
    await scheme.handshake(transport);

    final request = pb.SessionData.fromBuffer(transport.sent.single.$2);
    expect(request.secVer, pb.SecSchemeVersion.SecScheme0);
    expect(request.sec0.hasSc(), isTrue);
    expect(scheme.version, 0);
    expect(await scheme.encrypt(Uint8List.fromList([1, 2])), [1, 2]);
    expect(await scheme.decrypt(Uint8List.fromList([3])), [3]);
  });

  test('non-success status throws HandshakeFailed with the status', () async {
    final transport = ReplayTransport([
      Exchange('prov-session', null, _resp(pb.Status.InvalidSession)),
    ]);
    await expectLater(
      Security0().handshake(transport),
      throwsA(
        isA<HandshakeFailed>().having(
          (e) => e.status,
          'status',
          ProvStatus.invalidSession,
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/security/security0_test.dart)`

Expected: FAIL: `Error: Method not found: 'Security0'`.

- [ ] **Step 3: Implement the scheme base and Security 0**

Create `packages/esp_prov_core/lib/src/security/security_scheme.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

part 'security0.dart';

/// A protocomm security scheme: handshake on `prov-session`, then a
/// stateful cipher for every later request and response.
///
/// Encryption is asynchronous because cryptography_plus is. Calls must be
/// made in protocol order; `EspSession` serialises them.
sealed class SecurityScheme {
  /// Security version number as reported in `proto-ver` (`sec_ver`).
  int get version;

  /// Runs the handshake over [transport] on the `prov-session` endpoint.
  Future<void> handshake(ProvTransport transport);

  /// Encrypts a request body.
  Future<Uint8List> encrypt(Uint8List plain);

  /// Decrypts a response body.
  Future<Uint8List> decrypt(Uint8List cipher);
}

/// Sends one handshake message and parses the device's `SessionData` reply.
Future<pb.SessionData> _exchange(
  ProvTransport transport,
  pb.SessionData request,
) async {
  final response = await transport.send(
    ProvEndpoints.session,
    request.writeToBuffer(),
  );
  try {
    return pb.SessionData.fromBuffer(response);
  } on InvalidProtocolBufferException catch (e) {
    throw HandshakeFailed('Malformed prov-session response: ${e.message}');
  }
}

/// Throws [HandshakeFailed] unless [status] is `Success`.
void _checkStatus(pb.Status status, String step) {
  if (status != pb.Status.Success) {
    throw HandshakeFailed(
      '$step failed with device status ${status.name}.',
      status: ProvStatus.fromValue(status.value),
    );
  }
}

/// Throws [HandshakeFailed] unless the device answered with [expected].
void _checkScheme(pb.SessionData response, pb.SecSchemeVersion expected) {
  if (response.secVer != expected) {
    throw HandshakeFailed(
      'Device answered with ${response.secVer.name}, expected '
      '${expected.name}.',
    );
  }
}
```

Create `packages/esp_prov_core/lib/src/security/security0.dart`:

```dart
part of 'security_scheme.dart';

/// Security 0: no encryption. Data is sent in plain text.
final class Security0 extends SecurityScheme {
  @override
  int get version => 0;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final response = await _exchange(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme0,
        // msg S0_Session_Command is the proto3 default (0) and is left unset;
        // protobuf.dart would otherwise serialise it, unlike esp_prov.
        sec0: pb.Sec0Payload(sc: pb.S0SessionCmd()),
      ),
    );
    _checkScheme(response, pb.SecSchemeVersion.SecScheme0);
    _checkStatus(response.sec0.sr.status, 'Security 0 session setup');
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) async => plain;

  @override
  Future<Uint8List> decrypt(Uint8List cipher) async => cipher;
}
```

Replace the entire contents of `packages/esp_prov_core/lib/esp_prov_core.dart`:

```dart
/// Pure-Dart client for Espressif Unified Provisioning (protocomm).
///
/// Bring a `ProvTransport` (for example from `esp_prov_ble_universal`), open
/// an `EspSession`, then use its Wi-Fi, Thread, control and custom endpoint
/// flows.
library;

export 'src/errors/prov_exception.dart';
export 'src/errors/prov_status.dart';
export 'src/security/security_scheme.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/security/security0_test.dart)`

Expected: `+2: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/support/replay_transport.dart \
  packages/esp_prov_core/test/security/security0_test.dart \
  packages/esp_prov_core/lib/src/security/security_scheme.dart \
  packages/esp_prov_core/lib/src/security/security0.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): sealed SecurityScheme and Security 0" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.8: Security 1: X25519, PoP and AES-CTR

**Files:**
- Modify: `packages/esp_prov_core/lib/src/security/security_scheme.dart`
- Create: `packages/esp_prov_core/lib/src/security/security1.dart`
- Test: `packages/esp_prov_core/test/security/security1_test.dart`

**Interfaces:**
- Consumes: `AesCtrStream` (2.4), `xorBytes`/`constantTimeEquals` (2.2), `SecurityScheme` helpers (2.7), fixtures (2.3), `ReplayTransport` (2.7).
- Produces: `final class Security1 extends SecurityScheme { new({String? pop}); @visibleForTesting new withKeyPair({required Future<SimpleKeyPair> Function() keyPair, String? pop}); }`
(call sites: `Security1(pop: 'abcd1234')`, `Security1.withKeyPair(...)`). New private
helper `_exchangeProof(transport, request, what)` in `security_scheme.dart`:
a `TransportException` or `DeviceDisconnected` while sending the proof
becomes `PopMismatch`.

Why a dropped link during Cmd1 means "wrong PoP": when the proof does not
verify, protocomm returns an error and `protocomm_ble` closes the
connection ("Invalid content received, killing connection"). The app
sees a GATT error or a disconnect, never a status code. Mapping that to
`PopMismatch` is what lets success criterion 4 tell a PoP mismatch apart
from a device disconnect. A disconnect during Cmd0 stays
`DeviceDisconnected` (pinned by a test).

Steps of the handshake: X25519 key pair; Cmd0 `{client_pubkey}` ->
Resp0 `{device_pubkey(32), device_random(16)}`; key = X25519 shared secret
XOR SHA-256(PoP) when PoP is non-empty (UTF-8 encoded); CTR stream with
IV = device_random; Cmd1 `{client_verify_data = ctr(device_pubkey)}` ->
Resp1 `{device_verify_data}`, which must decrypt (same stream) to the
client public key.

- [ ] **Step 1: Write the failing test**

`X25519().newKeyPairFromSeed(seed)` produces the same public key as Python `X25519PrivateKey.from_private_bytes(seed)` (both clamp the scalar), so the replayed requests match byte for byte.

Create `packages/esp_prov_core/test/security/security1_test.dart`:

```dart
import 'dart:typed_data';

import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/replay_transport.dart';

Security1 _fixedClient(Map<String, Object?> f) => Security1.withKeyPair(
  pop: f['pop']! as String,
  keyPair: () => X25519().newKeyPairFromSeed(hexField(f, 'client_private_key')),
);

List<Exchange> _handshake(Map<String, Object?> f, {List<int>? resp1}) => [
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd0'),
    hexField(f, 'session_resp0'),
  ),
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd1'),
    resp1 ?? hexField(f, 'session_resp1'),
  ),
];

void main() {
  for (final name in ['sec1_pop.json', 'sec1_no_pop_carry.json']) {
    test('handshake and messages match esp_prov ($name)', () async {
      final f = loadFixture(name);
      final transport = ReplayTransport(_handshake(f));
      final scheme = _fixedClient(f);
      await scheme.handshake(transport);
      expect(transport.exchanges, isEmpty);

      for (final m in messages(f)) {
        if (m['direction'] == 'client_to_device') {
          expect(
            await scheme.encrypt(hexField(m, 'plain')),
            hexField(m, 'cipher'),
          );
        } else {
          expect(
            await scheme.decrypt(hexField(m, 'cipher')),
            hexField(m, 'plain'),
          );
        }
      }
    });
  }

  test('wrong device verify data throws PopMismatch', () async {
    final f = loadFixture('sec1_pop.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    final tampered = Uint8List.fromList(resp1.sec1.sr1.deviceVerifyData);
    tampered[0] ^= 0x01;
    resp1.sec1.sr1.deviceVerifyData = tampered;
    final transport = ReplayTransport(
      _handshake(f, resp1: resp1.writeToBuffer()),
    );
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('device dropping the link after Cmd1 is a PopMismatch', () async {
    final f = loadFixture('sec1_pop.json');
    final transport = ReplayTransport([
      _handshake(f).first,
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd1'),
        const [],
        error: const DeviceDisconnected(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('a disconnect during Cmd0 stays DeviceDisconnected', () async {
    final f = loadFixture('sec1_pop.json');
    final transport = ReplayTransport([
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd0'),
        const [],
        error: const DeviceDisconnected(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(isA<DeviceDisconnected>()),
    );
  });

  test('error status in SessionResp0 throws HandshakeFailed', () async {
    final f = loadFixture('sec1_pop.json');
    final resp0 = pb.SessionData.fromBuffer(hexField(f, 'session_resp0'));
    resp0.sec1.sr0.status = pb.Status.InvalidArgument;
    final transport = ReplayTransport([
      Exchange(
        'prov-session',
        hexField(f, 'session_cmd0'),
        resp0.writeToBuffer(),
      ),
    ]);
    await expectLater(
      _fixedClient(f).handshake(transport),
      throwsA(
        isA<HandshakeFailed>()
            .having((e) => e.status, 'status', ProvStatus.invalidArgument)
            .having((e) => e is PopMismatch, 'is PopMismatch', isFalse),
      ),
    );
  });

  test('encrypt before handshake is a StateError', () {
    expect(() => Security1(pop: 'x').encrypt(Uint8List(1)), throwsStateError);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/security/security1_test.dart)`

Expected: FAIL: `Error: Type 'Security1' not found.`

- [ ] **Step 3: Implement Security 1**

Replace the entire contents of `packages/esp_prov_core/lib/src/security/security_scheme.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec1.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

part 'security0.dart';
part 'security1.dart';

/// A protocomm security scheme: handshake on `prov-session`, then a
/// stateful cipher for every later request and response.
///
/// Encryption is asynchronous because cryptography_plus is. Calls must be
/// made in protocol order; `EspSession` serialises them.
sealed class SecurityScheme {
  /// Security version number as reported in `proto-ver` (`sec_ver`).
  int get version;

  /// Runs the handshake over [transport] on the `prov-session` endpoint.
  Future<void> handshake(ProvTransport transport);

  /// Encrypts a request body.
  Future<Uint8List> encrypt(Uint8List plain);

  /// Decrypts a response body.
  Future<Uint8List> decrypt(Uint8List cipher);
}

/// Sends one handshake message and parses the device's `SessionData` reply.
Future<pb.SessionData> _exchange(
  ProvTransport transport,
  pb.SessionData request,
) async {
  final response = await transport.send(
    ProvEndpoints.session,
    request.writeToBuffer(),
  );
  try {
    return pb.SessionData.fromBuffer(response);
  } on InvalidProtocolBufferException catch (e) {
    throw HandshakeFailed('Malformed prov-session response: ${e.message}');
  }
}

/// Throws [HandshakeFailed] unless [status] is `Success`.
void _checkStatus(pb.Status status, String step) {
  if (status != pb.Status.Success) {
    throw HandshakeFailed(
      '$step failed with device status ${status.name}.',
      status: ProvStatus.fromValue(status.value),
    );
  }
}

/// Throws [HandshakeFailed] unless the device answered with [expected].
void _checkScheme(pb.SessionData response, pb.SecSchemeVersion expected) {
  if (response.secVer != expected) {
    throw HandshakeFailed(
      'Device answered with ${response.secVer.name}, expected '
      '${expected.name}.',
    );
  }
}

/// Runs the proof step of a handshake. The firmware closes the BLE link when
/// it rejects a proof, so a transport failure here means a wrong PoP or
/// password rather than a radio problem.
Future<pb.SessionData> _exchangeProof(
  ProvTransport transport,
  pb.SessionData request,
  String what,
) async {
  try {
    return await _exchange(transport, request);
  } on TransportException catch (e) {
    throw PopMismatch(
      'The device dropped the session after receiving the $what '
      '(${e.message}). The $what is most likely wrong.',
    );
  } on DeviceDisconnected {
    throw PopMismatch(
      'The device disconnected after receiving the $what. '
      'The $what is most likely wrong.',
    );
  }
}
```

Create `packages/esp_prov_core/lib/src/security/security1.dart`:

```dart
part of 'security_scheme.dart';

/// Security 1: X25519 key exchange, optional proof of possession, and one
/// continuous AES-256-CTR keystream for the session.
final class Security1 extends SecurityScheme {
  /// Creates the scheme. [pop] may be null or empty when the firmware
  /// advertises the `no_pop` capability.
  new({String? pop}) : this._(pop, () => X25519().newKeyPair());

  /// Creates the scheme with a fixed client key pair (fixture tests only).
  @visibleForTesting
  new withKeyPair({
    required Future<SimpleKeyPair> Function() keyPair,
    String? pop,
  }) : this._(pop, keyPair);

  new _(this._pop, this._newKeyPair);

  final String? _pop;
  final Future<SimpleKeyPair> Function() _newKeyPair;
  AesCtrStream? _stream;

  @override
  int get version => 1;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final keyPair = await _newKeyPair();
    final clientPublic = Uint8List.fromList(
      (await keyPair.extractPublicKey()).bytes,
    );

    final resp0 = await _exchange(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        // msg Session_Command0 is the proto3 default (0); leave it unset so the
        // bytes match esp_prov (protobuf.dart serialises explicit defaults).
        sec1: pb.Sec1Payload(sc0: pb.SessionCmd0(clientPubkey: clientPublic)),
      ),
    );
    _checkScheme(resp0, pb.SecSchemeVersion.SecScheme1);
    final sr0 = resp0.sec1.sr0;
    _checkStatus(sr0.status, 'Security 1 key exchange');
    final devicePublic = Uint8List.fromList(sr0.devicePubkey);
    final deviceRandom = Uint8List.fromList(sr0.deviceRandom);
    if (devicePublic.length != 32 || deviceRandom.length != 16) {
      throw HandshakeFailed(
        'Security 1 response has a ${devicePublic.length}-byte public key '
        'and ${deviceRandom.length}-byte random; expected 32 and 16.',
      );
    }

    final shared = await X25519().sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(devicePublic, type: KeyPairType.x25519),
    );
    var key = Uint8List.fromList(await shared.extractBytes());
    final pop = _pop;
    if (pop != null && pop.isNotEmpty) {
      key = xorBytes(key, sha256.convert(utf8.encode(pop)).bytes);
    }
    final stream = AesCtrStream(key: key, iv: deviceRandom);

    final clientVerify = await stream.apply(devicePublic);
    final resp1 = await _exchangeProof(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Command1,
          sc1: pb.SessionCmd1(clientVerifyData: clientVerify),
        ),
      ),
      'proof of possession',
    );
    _checkScheme(resp1, pb.SecSchemeVersion.SecScheme1);
    _checkStatus(resp1.sec1.sr1.status, 'Security 1 verification');
    final deviceVerify = await stream.apply(resp1.sec1.sr1.deviceVerifyData);
    if (!constantTimeEquals(deviceVerify, clientPublic)) {
      throw const PopMismatch(
        'The device verification data does not match. The proof of '
        'possession is wrong.',
      );
    }
    _stream = stream;
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) => _ready().apply(plain);

  @override
  Future<Uint8List> decrypt(Uint8List cipher) => _ready().apply(cipher);

  AesCtrStream _ready() =>
      _stream ?? (throw StateError('Security 1 handshake has not completed.'));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/security/security1_test.dart)`

Expected: `+7: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/security/security1_test.dart \
  packages/esp_prov_core/lib/src/security/security_scheme.dart \
  packages/esp_prov_core/lib/src/security/security1.dart
git commit -m "feat(core): Security 1 handshake and cipher" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 2.9: Security 2: SRP-6a handshake and AES-GCM

**Files:**
- Modify: `packages/esp_prov_core/lib/src/security/security_scheme.dart`
- Create: `packages/esp_prov_core/lib/src/security/security2.dart`
- Test: `packages/esp_prov_core/test/security/security2_test.dart`

**Interfaces:**
- Consumes: `Srp6aClient` (2.6), `AesGcmCounter` (2.5), `offload` (2.2), helpers from 2.7/2.8.
- Produces: `final class Security2 extends SecurityScheme { new({required String username, required String password, required int patchVersion}); @visibleForTesting new withPrivateKeys({required String username, required String password, required int patchVersion, required BigInt Function() nextPrivateKey}); }`.

Handshake: draw `a` until `Srp6aClient.publicKey(a)` is non-null (384
bytes, at most 10000 draws); Cmd0 `{client_username (UTF-8), client_pubkey = A}`
-> Resp0 `{device_pubkey = B, device_salt}`; `offload(computeProof)`;
Cmd1 `{client_proof = M1}` (sent with `_exchangeProof`, so a dropped link
becomes `PopMismatch`) -> Resp1 `{device_proof, device_nonce}`. Then
`device_proof` must equal M2 (constant-time compare, else `PopMismatch`),
`device_nonce` must be 12 bytes, and the cipher is
`AesGcmCounter(key: K[0:32], nonce: device_nonce, incrementNonce: patchVersion >= 1)`.
The modPow work for both A and the proof runs inside `offload` (Isolate.run
natively, inline on web).

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_core/test/security/security2_test.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fixtures.dart';
import '../support/replay_transport.dart';

Security2 _fixedClient(
  Map<String, Object?> f, {
  required int patchVersion,
  List<BigInt>? keys,
}) {
  final queue = keys ?? [BigInt.parse(f['a']! as String, radix: 16)];
  return Security2.withPrivateKeys(
    username: f['username']! as String,
    password: f['password']! as String,
    patchVersion: patchVersion,
    nextPrivateKey: () => queue.removeAt(0),
  );
}

List<Exchange> _handshake(Map<String, Object?> f, {List<int>? resp1}) => [
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd0'),
    hexField(f, 'session_resp0'),
  ),
  Exchange(
    'prov-session',
    hexField(f, 'session_cmd1'),
    resp1 ?? hexField(f, 'session_resp1'),
  ),
];

void main() {
  for (final patch in [0, 1]) {
    test('handshake and AES-GCM match esp_prov (patch $patch)', () async {
      final f = loadFixture('sec2_example.json');
      final scheme = _fixedClient(f, patchVersion: patch);
      await scheme.handshake(ReplayTransport(_handshake(f)));
      for (final m in messages(f, 'messages_patch$patch')) {
        if (m['direction'] == 'client_to_device') {
          expect(
            await scheme.encrypt(hexField(m, 'plain')),
            hexField(m, 'cipher'),
          );
        } else {
          expect(
            await scheme.decrypt(hexField(m, 'cipher')),
            hexField(m, 'plain'),
          );
        }
      }
    });
  }

  for (final name in ['sec2_short_b.json', 'sec2_short_s.json']) {
    test('handshake succeeds for $name', () async {
      final f = loadFixture(name);
      final transport = ReplayTransport(_handshake(f));
      await _fixedClient(f, patchVersion: 1).handshake(transport);
      expect(transport.exchanges, isEmpty);
    });
  }

  test('re-rolls a until A is 384 bytes', () async {
    final f = loadFixture('sec2_example.json');
    // a = 0 gives A = 1 (one byte), so the client must draw again.
    final scheme = _fixedClient(
      f,
      patchVersion: 1,
      keys: [BigInt.zero, BigInt.parse(f['a']! as String, radix: 16)],
    );
    final transport = ReplayTransport(_handshake(f));
    await scheme.handshake(transport);
    expect(transport.exchanges, isEmpty);
  });

  test('wrong device proof throws PopMismatch', () async {
    final f = loadFixture('sec2_example.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    final proof = Uint8List.fromList(resp1.sec2.sr1.deviceProof);
    proof[10] ^= 0xff;
    resp1.sec2.sr1.deviceProof = proof;
    await expectLater(
      _fixedClient(
        f,
        patchVersion: 1,
      ).handshake(ReplayTransport(_handshake(f, resp1: resp1.writeToBuffer()))),
      throwsA(isA<PopMismatch>()),
    );
  });

  test(
    'device closing the link after the client proof is PopMismatch',
    () async {
      final f = loadFixture('sec2_example.json');
      final transport = ReplayTransport([
        _handshake(f).first,
        Exchange(
          'prov-session',
          hexField(f, 'session_cmd1'),
          const [],
          error: const TransportException('GATT error 133'),
        ),
      ]);
      await expectLater(
        _fixedClient(f, patchVersion: 1).handshake(transport),
        throwsA(isA<PopMismatch>()),
      );
    },
  );

  test('a short device nonce throws HandshakeFailed', () async {
    final f = loadFixture('sec2_example.json');
    final resp1 = pb.SessionData.fromBuffer(hexField(f, 'session_resp1'));
    resp1.sec2.sr1.deviceNonce = Uint8List(8);
    await expectLater(
      _fixedClient(
        f,
        patchVersion: 1,
      ).handshake(ReplayTransport(_handshake(f, resp1: resp1.writeToBuffer()))),
      throwsA(
        isA<HandshakeFailed>().having(
          (e) => e is PopMismatch,
          'is PopMismatch',
          isFalse,
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/security/security2_test.dart)`

Expected: FAIL: `Error: Type 'Security2' not found.`

- [ ] **Step 3: Implement Security 2**

Replace the entire contents of `packages/esp_prov_core/lib/src/security/security_scheme.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/offload.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec1.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec2.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

part 'security0.dart';
part 'security1.dart';
part 'security2.dart';

/// A protocomm security scheme: handshake on `prov-session`, then a
/// stateful cipher for every later request and response.
///
/// Encryption is asynchronous because cryptography_plus is. Calls must be
/// made in protocol order; `EspSession` serialises them.
sealed class SecurityScheme {
  /// Security version number as reported in `proto-ver` (`sec_ver`).
  int get version;

  /// Runs the handshake over [transport] on the `prov-session` endpoint.
  Future<void> handshake(ProvTransport transport);

  /// Encrypts a request body.
  Future<Uint8List> encrypt(Uint8List plain);

  /// Decrypts a response body.
  Future<Uint8List> decrypt(Uint8List cipher);
}

/// Sends one handshake message and parses the device's `SessionData` reply.
Future<pb.SessionData> _exchange(
  ProvTransport transport,
  pb.SessionData request,
) async {
  final response = await transport.send(
    ProvEndpoints.session,
    request.writeToBuffer(),
  );
  try {
    return pb.SessionData.fromBuffer(response);
  } on InvalidProtocolBufferException catch (e) {
    throw HandshakeFailed('Malformed prov-session response: ${e.message}');
  }
}

/// Throws [HandshakeFailed] unless [status] is `Success`.
void _checkStatus(pb.Status status, String step) {
  if (status != pb.Status.Success) {
    throw HandshakeFailed(
      '$step failed with device status ${status.name}.',
      status: ProvStatus.fromValue(status.value),
    );
  }
}

/// Throws [HandshakeFailed] unless the device answered with [expected].
void _checkScheme(pb.SessionData response, pb.SecSchemeVersion expected) {
  if (response.secVer != expected) {
    throw HandshakeFailed(
      'Device answered with ${response.secVer.name}, expected '
      '${expected.name}.',
    );
  }
}

/// Runs the proof step of a handshake. The firmware closes the BLE link when
/// it rejects a proof, so a transport failure here means a wrong PoP or
/// password rather than a radio problem.
Future<pb.SessionData> _exchangeProof(
  ProvTransport transport,
  pb.SessionData request,
  String what,
) async {
  try {
    return await _exchange(transport, request);
  } on TransportException catch (e) {
    throw PopMismatch(
      'The device dropped the session after receiving the $what '
      '(${e.message}). The $what is most likely wrong.',
    );
  } on DeviceDisconnected {
    throw PopMismatch(
      'The device disconnected after receiving the $what. '
      'The $what is most likely wrong.',
    );
  }
}
```

Create `packages/esp_prov_core/lib/src/security/security2.dart`:

```dart
part of 'security_scheme.dart';

/// Security 2: SRP-6a (3072-bit, SHA-512) authentication and AES-256-GCM.
final class Security2 extends SecurityScheme {
  /// Creates the scheme for [username]/[password]. [patchVersion] is the
  /// firmware `sec_patch_ver` and selects the nonce rule (see
  /// [AesGcmCounter]).
  new({
    required String username,
    required String password,
    required int patchVersion,
  }) : this._(username, password, patchVersion, Srp6aClient.randomPrivateKey);

  /// Creates the scheme with a deterministic private key source (fixture
  /// tests only).
  @visibleForTesting
  new withPrivateKeys({
    required String username,
    required String password,
    required int patchVersion,
    required BigInt Function() nextPrivateKey,
  }) : this._(username, password, patchVersion, nextPrivateKey);

  new _(
    this._username,
    this._password,
    this._patchVersion,
    this._nextPrivateKey,
  );

  static const _maxRerolls = 10000;

  final String _username;
  final String _password;
  final int _patchVersion;
  final BigInt Function() _nextPrivateKey;
  AesGcmCounter? _cipher;

  @override
  int get version => 2;

  @override
  Future<void> handshake(ProvTransport transport) async {
    final (a, clientPublic) = await _newEphemeral();

    final resp0 = await _exchange(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        // msg S2Session_Command0 is the proto3 default (0); leave it unset
        // so the bytes match esp_prov (protobuf.dart writes set defaults).
        sec2: pb.Sec2Payload(
          sc0: pb.S2SessionCmd0(
            clientUsername: utf8.encode(_username),
            clientPubkey: clientPublic,
          ),
        ),
      ),
    );
    _checkScheme(resp0, pb.SecSchemeVersion.SecScheme2);
    final sr0 = resp0.sec2.sr0;
    _checkStatus(sr0.status, 'Security 2 key exchange');
    final serverPublic = Uint8List.fromList(sr0.devicePubkey);
    final salt = Uint8List.fromList(sr0.deviceSalt);
    if (serverPublic.isEmpty || salt.isEmpty) {
      throw const HandshakeFailed('Security 2 response is missing B or salt.');
    }

    final username = _username;
    final password = _password;
    final proof = await offload(
      () => Srp6aClient.computeProof(
        username: username,
        password: password,
        a: a,
        clientPublicKey: clientPublic,
        salt: salt,
        serverPublicKey: serverPublic,
      ),
    );

    final resp1 = await _exchangeProof(
      transport,
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        sec2: pb.Sec2Payload(
          msg: pb.Sec2MsgType.S2Session_Command1,
          sc1: pb.S2SessionCmd1(clientProof: proof.clientProof),
        ),
      ),
      'username and password',
    );
    _checkScheme(resp1, pb.SecSchemeVersion.SecScheme2);
    final sr1 = resp1.sec2.sr1;
    _checkStatus(sr1.status, 'Security 2 verification');
    if (!constantTimeEquals(sr1.deviceProof, proof.expectedServerProof)) {
      throw const PopMismatch(
        'The device proof does not verify. The username or password is '
        'wrong, or the device is not the one you expect.',
      );
    }
    if (sr1.deviceNonce.length != 12) {
      throw HandshakeFailed(
        'Device nonce has ${sr1.deviceNonce.length} bytes; expected 12.',
      );
    }
    _cipher = AesGcmCounter(
      key: proof.sessionKey.sublist(0, 32),
      nonce: sr1.deviceNonce,
      incrementNonce: _patchVersion >= 1,
    );
  }

  /// Picks `a` until A = g^a mod N serialises to exactly 384 bytes.
  Future<(BigInt, Uint8List)> _newEphemeral() async {
    for (var i = 0; i < _maxRerolls; i++) {
      final a = _nextPrivateKey();
      final publicKey = await offload(() => Srp6aClient.publicKey(a));
      if (publicKey != null) return (a, publicKey);
    }
    throw const HandshakeFailed('Could not generate a full-length SRP key.');
  }

  @override
  Future<Uint8List> encrypt(Uint8List plain) => _ready().encrypt(plain);

  @override
  Future<Uint8List> decrypt(Uint8List cipher) => _ready().decrypt(cipher);

  AesGcmCounter _ready() =>
      _cipher ?? (throw StateError('Security 2 handshake has not completed.'));
}
```

- [ ] **Step 4: Run the whole core suite**

Run: `(cd packages/esp_prov_core && fvm dart test )`

Expected: `+62: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/security/security2_test.dart \
  packages/esp_prov_core/lib/src/security/security_scheme.dart \
  packages/esp_prov_core/lib/src/security/security2.dart
git commit -m "feat(core): Security 2 SRP-6a handshake and AES-GCM" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
