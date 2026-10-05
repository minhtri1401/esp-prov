> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 4: BLE adapter on universal_ble with contract tests

**Goal:** `esp_prov_ble_universal`: scanning, connection, endpoint discovery and serialised transactions on `universal_ble` ^2.2.0, verified by contract tests against a fake `UniversalBlePlatform`.

**Depends on:** Phase 1 and Task 2.1 only (the transport interfaces, errors and `SerialQueue`). It can run in parallel with Tasks 2.2-2.9 and all of Phase 3.

---

### Task 4.1: Adapter package and endpoint discovery

**Files:**
- Create: `packages/esp_prov_ble_universal/pubspec.yaml`
- Create: `packages/esp_prov_ble_universal/analysis_options.yaml`
- Modify: `pubspec.yaml`
- Create: `packages/esp_prov_ble_universal/lib/src/endpoint_discovery.dart`
- Create: `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`
- Test: `packages/esp_prov_ble_universal/test/endpoint_discovery_test.dart`

**Interfaces:**
- Consumes: `ProvTransport` etc. from Task 2.1 (only the interfaces and errors).
- Produces: Package `esp_prov_ble_universal` in the workspace. Exported from
`package:esp_prov_ble_universal/esp_prov_ble_universal.dart`:
`const fallbackEndpointNames = <int, String>{0xff4f: 'prov-ctrl', 0xff50: 'prov-scan', 0xff51: 'prov-session', 0xff52: 'prov-config', 0xff53: 'proto-ver'}`,
`String characteristicUuidFor(String serviceUuid, int endpointId)`,
`int? endpointIdOf(String serviceUuid, String characteristicUuid)`,
`final class EndpointMap { const new(Map<String, String> characteristics, List<String> warnings); }`,
`Future<EndpointMap> discoverEndpoints(BleService service, Future<Uint8List> Function(String characteristicUuid) readUserDescription)`.
Internal constant `userDescriptionUuid = '00002901-0000-1000-8000-00805f9b34fb'`.

From here on the workspace contains a Flutter package, so dependencies are
resolved with `fvm flutter pub get` (`tool/check.sh` already does this).

UUID derivation (facts doc, BLE transport): each endpoint characteristic
is the service UUID with little-endian bytes 12-13 replaced by a 16-bit id.
In the canonical string those bytes are hex characters 4-7, e.g. service
`021a9004-0382-4aea-bff4-6b3f1c5adfb4` -> `prov-session` (0xff51)
`021aff51-0382-4aea-bff4-6b3f1c5adfb4`. Names come from the 0x2901 user
description. A characteristic without one (or whose read fails, as on some
browsers) falls back to the table above. Anything else, e.g. a custom
endpoint without a descriptor, is reported in `warnings` and stays
unaddressable (spec 3.2).

universal_ble API facts used in this phase, verified against the 2.3.0
source in the pub cache (`~/.pub-cache/hosted/pub.dev/universal_ble-2.3.0`):
`BleService(String uuid, List<BleCharacteristic>)`,
`BleCharacteristic(String uuid, List<CharacteristicProperty>, List<BleDescriptor>)`,
`BleDescriptor(String uuid)`, and `BleUuidParser.string()`, which normalises
to lowercase 128-bit and expands 16-bit ids.

- [ ] **Step 1: Create the package and add it to the workspace**

Create `packages/esp_prov_ble_universal/pubspec.yaml`:

```yaml
name: esp_prov_ble_universal
description: >-
  Bluetooth LE transport for esp_prov_core built on universal_ble: scanning,
  endpoint discovery and serialised protocomm transactions on six platforms.
version: 0.1.0
repository: https://github.com/MinhTri1401/esp_prov/tree/main/packages/esp_prov_ble_universal
issue_tracker: https://github.com/MinhTri1401/esp_prov/issues
topics:
  - esp32
  - provisioning
  - bluetooth
  - ble

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  esp_prov_core: ^0.1.0
  flutter:
    sdk: flutter
  universal_ble: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Create `packages/esp_prov_ble_universal/analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - build/**
```

Replace the entire contents of `pubspec.yaml`:

```yaml
name: esp_prov_workspace
publish_to: none

environment:
  sdk: ^3.13.0

workspace:
  - packages/esp_prov_core
  - packages/esp_prov_ble_universal

dev_dependencies:
  very_good_analysis: ^11.0.0
```

Run: `fvm flutter pub get`

Expected: `Got dependencies!` with `universal_ble 2.3.0` (or a later 2.x) resolved; no `pubspec.lock` inside the package.

`flutter pub get` may print "Upgrading analysis_options.yaml to exclude build" for packages without a `build/**` exclude. The file above already has it, so nothing changes.

- [ ] **Step 2: Write the failing test**

Create `packages/esp_prov_ble_universal/test/endpoint_discovery_test.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

const _service = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

BleCharacteristic _char(int id, {bool described = true}) => BleCharacteristic(
  characteristicUuidFor(_service, id),
  [CharacteristicProperty.read, CharacteristicProperty.write],
  [if (described) BleDescriptor('2901')],
);

void main() {
  test('characteristic UUID replaces bytes 12-13 of the service UUID', () {
    expect(
      characteristicUuidFor(_service, 0xff51),
      '021aff51-0382-4aea-bff4-6b3f1c5adfb4',
    );
    expect(
      characteristicUuidFor('1775244D-6B43-439B-877C-060F2D9BED07', 0xff53),
      '1775ff53-6b43-439b-877c-060f2d9bed07',
    );
  });

  test('endpointIdOf inverts characteristicUuidFor', () {
    expect(
      endpointIdOf(_service, '021AFF50-0382-4AEA-BFF4-6B3F1C5ADFB4'),
      0xff50,
    );
    expect(
      endpointIdOf(_service, '00002a00-0000-1000-8000-00805f9b34fb'),
      isNull,
    );
  });

  test('0x2901 names win; missing ones use the UUID table', () async {
    final service = BleService(_service, [
      _char(0xff51),
      _char(0xff53, described: false),
      _char(0xff54),
      _char(0xff55, described: false),
    ]);
    final names = {
      characteristicUuidFor(_service, 0xff51): 'PROV-SESSION\u0000',
      characteristicUuidFor(_service, 0xff54): 'custom-data',
    };
    final map = await discoverEndpoints(
      service,
      (uuid) async => Uint8List.fromList(names[uuid]!.codeUnits),
    );
    expect(map.characteristics, {
      'prov-session': characteristicUuidFor(_service, 0xff51),
      'custom-data': characteristicUuidFor(_service, 0xff54),
      'proto-ver': characteristicUuidFor(_service, 0xff53),
    });
    expect(map.warnings.single, contains('021aff55'));
  });

  test('a failing descriptor read falls back to the table', () async {
    final service = BleService(_service, [_char(0xff52)]);
    final map = await discoverEndpoints(
      service,
      (uuid) => Future.error(Exception('web: descriptors unsupported')),
    );
    expect(map.characteristics.keys, ['prov-config']);
    expect(map.warnings.single, contains('0x2901'));
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test test/endpoint_discovery_test.dart)`

Expected: FAIL: `Compilation failed ... Error: Method not found: 'characteristicUuidFor'.` (the barrel does not exist yet).

- [ ] **Step 4: Implement endpoint discovery**

Create `packages/esp_prov_ble_universal/lib/src/endpoint_discovery.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// UUID of the Characteristic User Description descriptor that carries the
/// protocomm endpoint name.
const userDescriptionUuid = '00002901-0000-1000-8000-00805f9b34fb';

/// Endpoint names for characteristics without a 0x2901 descriptor, keyed by
/// the 16-bit id in UUID bytes 12-13 (ESP-IDF protocomm_ble defaults).
const fallbackEndpointNames = <int, String>{
  0xff4f: 'prov-ctrl',
  0xff50: 'prov-scan',
  0xff51: 'prov-session',
  0xff52: 'prov-config',
  0xff53: 'proto-ver',
};

/// The characteristic UUID protocomm_ble derives for [endpointId] from
/// [serviceUuid]: little-endian bytes 12-13 of the 128-bit UUID, which are
/// hex characters 4-7 of the canonical string.
///
/// `characteristicUuidFor('021a9004-0382-4aea-bff4-6b3f1c5adfb4', 0xff51)`
/// is `'021aff51-0382-4aea-bff4-6b3f1c5adfb4'`.
String characteristicUuidFor(String serviceUuid, int endpointId) {
  final service = BleUuidParser.string(serviceUuid);
  final id = endpointId.toRadixString(16).padLeft(4, '0');
  return '${service.substring(0, 4)}$id${service.substring(8)}';
}

/// The 16-bit endpoint id of [characteristicUuid] if it is derived from
/// [serviceUuid], otherwise null.
int? endpointIdOf(String serviceUuid, String characteristicUuid) {
  final service = BleUuidParser.string(serviceUuid);
  final characteristic = BleUuidParser.string(characteristicUuid);
  if (service.substring(0, 4) != characteristic.substring(0, 4) ||
      service.substring(8) != characteristic.substring(8)) {
    return null;
  }
  return int.parse(characteristic.substring(4, 8), radix: 16);
}

/// Result of endpoint discovery.
final class EndpointMap {
  /// Creates a map of endpoint name to characteristic UUID.
  const new(this.characteristics, this.warnings);

  /// Endpoint name to lowercase 128-bit characteristic UUID.
  final Map<String, String> characteristics;

  /// Characteristics that could not be named (custom endpoints without a
  /// 0x2901 descriptor, or descriptor read failures).
  final List<String> warnings;
}

/// Names every characteristic of [service].
///
/// The 0x2901 user description is authoritative. Characteristics without
/// one (or whose read fails, e.g. on some web browsers) fall back to
/// [fallbackEndpointNames]; anything else is reported in
/// [EndpointMap.warnings] and stays unaddressable.
Future<EndpointMap> discoverEndpoints(
  BleService service,
  Future<Uint8List> Function(String characteristicUuid) readUserDescription,
) async {
  final named = <String, String>{};
  final unnamed = <String>[];
  final warnings = <String>[];
  for (final characteristic in service.characteristics) {
    final uuid = BleUuidParser.string(characteristic.uuid);
    final hasDescription = characteristic.descriptors.any(
      (d) => BleUuidParser.string(d.uuid) == userDescriptionUuid,
    );
    if (hasDescription) {
      try {
        final raw = await readUserDescription(uuid);
        final name = utf8
            .decode(raw, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim()
            .toLowerCase();
        if (name.isNotEmpty) {
          named[name] = uuid;
          continue;
        }
      } on Object catch (e) {
        warnings.add('Reading the 0x2901 descriptor of $uuid failed: $e');
      }
    }
    unnamed.add(uuid);
  }
  for (final uuid in unnamed) {
    final id = endpointIdOf(service.uuid, uuid);
    final name = id == null ? null : fallbackEndpointNames[id];
    if (name != null && !named.containsKey(name)) {
      named[name] = uuid;
    } else {
      warnings.add(
        'Characteristic $uuid has no endpoint name; a custom endpoint on it '
        'cannot be addressed.',
      );
    }
  }
  return EndpointMap(named, warnings);
}
```

Create `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`:

```dart
/// Bluetooth LE transport for `esp_prov_core`, built on `universal_ble`.
library;

export 'src/endpoint_discovery.dart'
    show
        EndpointMap,
        characteristicUuidFor,
        discoverEndpoints,
        endpointIdOf,
        fallbackEndpointNames;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test test/endpoint_discovery_test.dart)`

Expected: `+4: All tests passed!`

- [ ] **Step 6: Analyze**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 7: Commit**

```bash
git add \
  packages/esp_prov_ble_universal/pubspec.yaml \
  packages/esp_prov_ble_universal/analysis_options.yaml \
  pubspec.yaml \
  packages/esp_prov_ble_universal/test/endpoint_discovery_test.dart \
  packages/esp_prov_ble_universal/lib/src/endpoint_discovery.dart \
  packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart \
  pubspec.lock
git commit -m "feat(ble): adapter package and 0x2901 endpoint discovery" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 4.2: UniversalBleTransport with contract tests

**Files:**
- Create: `packages/esp_prov_ble_universal/lib/src/transport.dart`
- Modify: `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`
- Test: `packages/esp_prov_ble_universal/test/support/fake_ble_platform.dart`
- Test: `packages/esp_prov_ble_universal/test/transport_test.dart`

**Interfaces:**
- Consumes: discovery (4.1); `SerialQueue`, `TransportException`, `DeviceDisconnected`, `UnknownEndpoint` (2.1).
- Produces: Exported:
`const defaultServiceUuid = '1775244d-6b43-439b-877c-060f2d9bed07'`,
`const exampleServiceUuid = '021a9004-0382-4aea-bff4-6b3f1c5adfb4'`,
`BleService? pickProvisioningService(List<BleService> services, String? advertisedServiceUuid)`,
`final class UniversalBleTransport implements ProvTransport { static Future<UniversalBleTransport> connect(String deviceId, {String? advertisedServiceUuid, Duration timeout = const Duration(seconds: 20)}); final String deviceId; final String serviceUuid; final List<String> warnings; String? characteristicFor(String endpoint); }`.
Test helper `test/support/fake_ble_platform.dart`: `class FakeBlePlatform extends UniversalBlePlatform { new({List<BleService> services, Map<String, String> userDescriptions, Set<String> failingDescriptorReads, Map<String, Responder> responders, List<BleDevice> adverts, Duration transactionDelay}); final List<String> log; PlatformConfig? lastScanConfig; void dropLink(String deviceId); }`.

Connect sequence (spec 3.2): `UniversalBle.connect`; on Android only
(`!kIsWeb && defaultTargetPlatform == TargetPlatform.android`)
`requestMtu(deviceId, 512)`, best effort; `discoverServices(withDescriptors: true)`;
pick the service (advertised UUID -> firmware default `1775244d-...` ->
example UUID `021a9004-...` -> the only non-standard service); read every
0x2901 with `readDescriptor`; on any failure disconnect and rethrow. A
transaction is `UniversalBle.write(..., withoutResponse: false)` then
`UniversalBle.read(...)` of the same characteristic inside one `SerialQueue`.
The adapter does not chunk: firmware limits are 256 B (Bluedroid), 480 B
(Security 2) and 512 B (NimBLE), and the core keeps requests small.

Disconnect detection: `UniversalBle.connectionStream(deviceId)` emitting
`false` marks the link down and fires `onDisconnected` once. A GATT error can
arrive before that event, so after an error the transport also asks
`getConnectionState`. A dropped link always surfaces as `DeviceDisconnected`,
never as a generic `TransportException`. That is what lets Security 1/2 turn
a mid-proof drop into `PopMismatch` and Wi-Fi into
`WifiFailed(deviceDisconnected)`.

Faking universal_ble (verified in 2.3.0 source): `UniversalBle.setInstance(UniversalBlePlatform)`
swaps the static platform. `UniversalBlePlatform` is a plain abstract class
(no `PlatformInterface` token check). `UniversalBle.connect` completes only
when the platform emits `updateConnection(deviceId, true)`. The fake extends
the platform, implements just the methods the adapter calls, and overrides
`noSuchMethod`, so it still compiles if a 2.x release adds abstract methods.
If a later universal_ble changes `setInstance` or those method signatures,
re-check `lib/src/interfaces/universal_ble_platform_interface.dart` in the
pub cache. `flutter_test` defaults `defaultTargetPlatform` to Android; the
MTU test overrides it with `debugDefaultTargetPlatformOverride`.

- [ ] **Step 1: Write the fake platform and the failing contract tests**

Create `packages/esp_prov_ble_universal/test/support/fake_ble_platform.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// Computes a characteristic's read value from the bytes last written to it.
typedef Responder = FutureOr<List<int>> Function(Uint8List written);

/// In-memory `universal_ble` platform for contract tests.
///
/// Install with `UniversalBle.setInstance(FakeBlePlatform(...))`. Methods the
/// adapter never calls fall through to [noSuchMethod], so the fake keeps
/// compiling if a universal_ble 2.x release adds platform methods.
class FakeBlePlatform extends UniversalBlePlatform {
  /// Creates a fake with one connectable device exposing [services].
  new({
    this.services = const [],
    this.userDescriptions = const {},
    this.failingDescriptorReads = const {},
    this.responders = const {},
    this.adverts = const [],
    this.transactionDelay = Duration.zero,
  });

  /// Services returned by `discoverServices`.
  final List<BleService> services;

  /// 0x2901 values keyed by characteristic UUID.
  final Map<String, String> userDescriptions;

  /// Characteristic UUIDs whose 0x2901 read throws.
  final Set<String> failingDescriptorReads;

  /// Read handlers keyed by characteristic UUID.
  final Map<String, Responder> responders;

  /// Advertisements emitted when scanning starts.
  final List<BleDevice> adverts;

  /// Delay applied to each write, to expose interleaving.
  final Duration transactionDelay;

  /// Operation log: `connect`, `mtu 512`, `write <uuid> <hex>`, `read <uuid>`,
  /// `disconnect`, `startScan`, `stopScan`.
  final List<String> log = [];

  /// Platform options passed to the last `startScan`.
  PlatformConfig? lastScanConfig;

  final Map<String, Uint8List> _lastWritten = {};
  bool _connected = false;

  /// Simulates the peripheral dropping the link.
  void dropLink(String deviceId) {
    _connected = false;
    updateConnection(deviceId, false);
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration? connectionTimeout,
    bool autoConnect = false,
    ConnectionPlatformConfig? platformConfig,
  }) async {
    log.add('connect');
    _connected = true;
    updateConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    log.add('disconnect');
    _connected = false;
    updateConnection(deviceId, false);
  }

  @override
  Future<BleConnectionState> getConnectionState(String deviceId) async =>
      _connected
      ? BleConnectionState.connected
      : BleConnectionState.disconnected;

  @override
  Future<int> requestMtu(String deviceId, int expectedMtu) async {
    log.add('mtu $expectedMtu');
    return expectedMtu;
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId,
    bool withDescriptors,
  ) async => services;

  @override
  Future<Uint8List> readDescriptorValue(
    String deviceId,
    String service,
    String characteristic,
    String descriptor, {
    Duration? timeout,
  }) async {
    if (failingDescriptorReads.contains(characteristic)) {
      throw Exception('0x2901 read not supported');
    }
    return Uint8List.fromList(
      utf8.encode(userDescriptions[characteristic] ?? ''),
    );
  }

  @override
  Future<void> writeValue(
    String deviceId,
    String service,
    String characteristic,
    Uint8List value,
    BleOutputProperty bleOutputProperty,
  ) async {
    if (!_connected) throw Exception('GATT: not connected');
    log.add('write $characteristic ${utf8.decode(value)}');
    _lastWritten[characteristic] = value;
    await Future<void>.delayed(transactionDelay);
  }

  @override
  Future<Uint8List> readValue(
    String deviceId,
    String service,
    String characteristic, {
    Duration? timeout,
  }) async {
    if (!_connected) throw Exception('GATT: not connected');
    log.add('read $characteristic');
    final responder = responders[characteristic] ?? (w) => w;
    return Uint8List.fromList(
      await responder(_lastWritten[characteristic] ?? Uint8List(0)),
    );
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    log.add('startScan');
    lastScanConfig = platformConfig;
    adverts.forEach(updateScanResult);
  }

  @override
  Future<void> stopScan() async => log.add('stopScan');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeBlePlatform: ${invocation.memberName}');
}
```

Create `packages/esp_prov_ble_universal/test/transport_test.dart`:

```dart
import 'dart:convert';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'support/fake_ble_platform.dart';

const _service = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';
const _device = 'AA:BB:CC:DD:EE:FF';

String _uuid(int id) => characteristicUuidFor(_service, id);

const _names = {
  0xff4f: 'prov-ctrl',
  0xff50: 'prov-scan',
  0xff51: 'prov-session',
  0xff52: 'prov-config',
  0xff53: 'proto-ver',
  0xff54: 'custom-data',
};

FakeBlePlatform _platform({
  String serviceUuid = _service,
  List<BleService>? extraServices,
  Map<String, Responder> responders = const {},
  Duration transactionDelay = Duration.zero,
}) => FakeBlePlatform(
  services: [
    BleService('1800', const []),
    BleService(serviceUuid, [
      for (final id in _names.keys)
        BleCharacteristic(characteristicUuidFor(serviceUuid, id), const [], [
          BleDescriptor('2901'),
        ]),
    ]),
    ...?extraServices,
  ],
  userDescriptions: {
    for (final e in _names.entries)
      characteristicUuidFor(serviceUuid, e.key): e.value,
  },
  responders: responders,
  transactionDelay: transactionDelay,
);

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('discovers endpoints from 0x2901 descriptors', () async {
    final platform = _platform();
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(transport.endpoints, _names.values.toSet());
    expect(transport.characteristicFor('custom-data'), _uuid(0xff54));
    expect(transport.warnings, isEmpty);
  });

  test('requests MTU 512 on Android only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = _platform();
    UniversalBle.setInstance(android);
    await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(android.log, contains('mtu 512'));

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = _platform();
    UniversalBle.setInstance(ios);
    await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    expect(ios.log.where((l) => l.startsWith('mtu')), isEmpty);
  });

  test('falls back to the firmware default service UUID', () async {
    UniversalBle.setInstance(_platform(serviceUuid: defaultServiceUuid));
    final transport = await UniversalBleTransport.connect(_device);
    expect(transport.serviceUuid, defaultServiceUuid);
  });

  test('without any provisioning service it disconnects and throws', () async {
    final platform = FakeBlePlatform(
      services: [BleService('1800', const []), BleService('180a', const [])],
    );
    UniversalBle.setInstance(platform);
    await expectLater(
      UniversalBleTransport.connect(_device),
      throwsA(isA<TransportException>()),
    );
    expect(platform.log.last, 'disconnect');
  });

  test(
    'send writes with response, then reads the same characteristic',
    () async {
      final platform = _platform(
        responders: {_uuid(0xff54): (w) => utf8.encode('re:${utf8.decode(w)}')},
      );
      UniversalBle.setInstance(platform);
      final transport = await UniversalBleTransport.connect(
        _device,
        advertisedServiceUuid: _service,
      );
      final response = await transport.send('custom-data', _bytes('hi'));
      expect(utf8.decode(response), 're:hi');
      expect(platform.log.skipWhile((l) => !l.startsWith('write')), [
        'write ${_uuid(0xff54)} hi',
        'read ${_uuid(0xff54)}',
      ]);
    },
  );

  test('concurrent sends never interleave', () async {
    final platform = _platform(
      transactionDelay: const Duration(milliseconds: 5),
    );
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await Future.wait([
      transport.send('prov-scan', _bytes('a')),
      transport.send('prov-config', _bytes('b')),
    ]);
    expect(platform.log.skipWhile((l) => !l.startsWith('write')), [
      'write ${_uuid(0xff50)} a',
      'read ${_uuid(0xff50)}',
      'write ${_uuid(0xff52)} b',
      'read ${_uuid(0xff52)}',
    ]);
  });

  test('unknown endpoint throws UnknownEndpoint', () async {
    UniversalBle.setInstance(_platform());
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('nope', _bytes('x')),
      throwsA(isA<UnknownEndpoint>()),
    );
  });

  test('a link drop emits onDisconnected and fails later sends', () async {
    final platform = _platform();
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    final dropped = transport.onDisconnected.first;
    platform.dropLink(_device);
    await dropped;
    await expectLater(
      transport.send('custom-data', _bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
    await transport.disconnect();
    await transport.disconnect();
  });

  test('a drop during a transaction surfaces as DeviceDisconnected', () async {
    late FakeBlePlatform platform;
    platform = _platform(
      responders: {
        // The error arrives before the connection event is delivered.
        _uuid(0xff52): (w) {
          platform.dropLink(_device);
          throw Exception('GATT 133');
        },
      },
    );
    UniversalBle.setInstance(platform);
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('prov-config', _bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
  });

  test('other BLE errors become TransportException', () async {
    UniversalBle.setInstance(
      _platform(responders: {_uuid(0xff52): (w) => throw Exception('133')}),
    );
    final transport = await UniversalBleTransport.connect(
      _device,
      advertisedServiceUuid: _service,
    );
    await expectLater(
      transport.send('prov-config', _bytes('x')),
      throwsA(isA<TransportException>()),
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test test/transport_test.dart)`

Expected: FAIL: `Compilation failed ... Error: Undefined name 'UniversalBleTransport'.`

- [ ] **Step 3: Implement the transport**

Create `packages/esp_prov_ble_universal/lib/src/transport.dart`:

```dart
import 'dart:async';

import 'package:esp_prov_ble_universal/src/endpoint_discovery.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

/// Service UUID ESP-IDF protocomm_ble uses when the application sets none.
const defaultServiceUuid = '1775244d-6b43-439b-877c-060f2d9bed07';

/// Service UUID the ESP-IDF provisioning examples set (esp_prov's fallback).
const exampleServiceUuid = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

const _bluetoothBaseSuffix = '-0000-1000-8000-00805f9b34fb';

/// Picks the provisioning service: the advertised UUID, then
/// [defaultServiceUuid], then [exampleServiceUuid], then the only
/// non-standard service if exactly one exists. Returns null otherwise.
BleService? pickProvisioningService(
  List<BleService> services,
  String? advertisedServiceUuid,
) {
  BleService? byUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return null;
    final wanted = BleUuidParser.stringOrNull(uuid);
    for (final s in services) {
      if (BleUuidParser.string(s.uuid) == wanted) return s;
    }
    return null;
  }

  final custom = [
    for (final s in services)
      if (!BleUuidParser.string(s.uuid).endsWith(_bluetoothBaseSuffix)) s,
  ];
  return byUuid(advertisedServiceUuid) ??
      byUuid(defaultServiceUuid) ??
      byUuid(exampleServiceUuid) ??
      (custom.length == 1 ? custom.single : null);
}

/// A [ProvTransport] over a `universal_ble` connection.
///
/// Each [send] is a write-with-response followed by a read of the same
/// characteristic. Calls are serialised so transactions never interleave.
final class UniversalBleTransport implements ProvTransport {
  new _(this.deviceId, this.serviceUuid, EndpointMap map)
    : _characteristics = map.characteristics,
      warnings = List.unmodifiable(map.warnings) {
    _connectionSubscription = UniversalBle.connectionStream(deviceId)
        .listen((connected) {
          if (!connected) _markDisconnected();
        });
  }

  /// Connects to [deviceId], requests a 512-byte MTU on Android, discovers
  /// services and maps endpoint names to characteristics.
  ///
  /// Throws [TransportException] when the connection fails or no
  /// provisioning service is found.
  static Future<UniversalBleTransport> connect(
    String deviceId, {
    String? advertisedServiceUuid,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await UniversalBle.connect(deviceId, timeout: timeout);
    } on Object catch (e) {
      throw TransportException('Could not connect to $deviceId.', cause: e);
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await UniversalBle.requestMtu(deviceId, 512);
        } on Object catch (_) {
          // Best effort: the firmware also supports long writes.
        }
      }
      final services = await UniversalBle.discoverServices(
        deviceId,
        withDescriptors: true,
      );
      final service = pickProvisioningService(services, advertisedServiceUuid);
      if (service == null) {
        throw TransportException(
          'No provisioning service found on $deviceId '
          '(services: ${services.map((s) => s.uuid).join(', ')}).',
        );
      }
      final serviceUuid = BleUuidParser.string(service.uuid);
      final map = await discoverEndpoints(
        service,
        (characteristic) => UniversalBle.readDescriptor(
          deviceId,
          serviceUuid,
          characteristic,
          userDescriptionUuid,
        ),
      );
      return UniversalBleTransport._(deviceId, serviceUuid, map);
    } on Object {
      await UniversalBle.disconnect(deviceId);
      rethrow;
    }
  }

  /// Platform device id.
  final String deviceId;

  /// UUID of the provisioning service in use.
  final String serviceUuid;

  /// Problems found during endpoint discovery, e.g. unnamed characteristics.
  final List<String> warnings;

  final Map<String, String> _characteristics;
  final SerialQueue _queue = SerialQueue();
  final StreamController<void> _disconnects =
      StreamController<void>.broadcast();
  late final StreamSubscription<bool> _connectionSubscription;
  bool _connected = true;

  @override
  Set<String> get endpoints => _characteristics.keys.toSet();

  /// The characteristic UUID mapped to [endpoint], if any.
  String? characteristicFor(String endpoint) => _characteristics[endpoint];

  @override
  Stream<void> get onDisconnected => _disconnects.stream;

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) =>
      _queue.run(() async {
        if (!_connected) throw const DeviceDisconnected();
        final characteristic = _characteristics[endpoint];
        if (characteristic == null) throw UnknownEndpoint(endpoint);
        try {
          await UniversalBle.write(
            deviceId,
            serviceUuid,
            characteristic,
            request,
          );
          return await UniversalBle.read(deviceId, serviceUuid, characteristic);
        } on Object catch (e) {
          // The GATT error can arrive before the disconnect event; ask the
          // platform so a dropped link is always reported as a disconnect.
          if (_connected && !await _stillConnected()) _markDisconnected();
          if (!_connected) throw const DeviceDisconnected();
          throw TransportException(
            'BLE transaction on $endpoint failed.',
            cause: e,
          );
        }
      });

  Future<bool> _stillConnected() async {
    try {
      return await UniversalBle.getConnectionState(deviceId) ==
          BleConnectionState.connected;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    _markDisconnected();
    await UniversalBle.disconnect(deviceId);
  }

  void _markDisconnected() {
    if (!_connected) return;
    _connected = false;
    _disconnects.add(null);
    unawaited(_connectionSubscription.cancel());
  }
}
```

Replace the entire contents of `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`:

```dart
/// Bluetooth LE transport for `esp_prov_core`, built on `universal_ble`.
library;

export 'src/endpoint_discovery.dart'
    show
        EndpointMap,
        characteristicUuidFor,
        discoverEndpoints,
        endpointIdOf,
        fallbackEndpointNames;
export 'src/transport.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test test/transport_test.dart)`

Expected: `+10: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_ble_universal/test/support/fake_ble_platform.dart \
  packages/esp_prov_ble_universal/test/transport_test.dart \
  packages/esp_prov_ble_universal/lib/src/transport.dart \
  packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart
git commit -m "feat(ble): UniversalBleTransport with serialised write-then-read" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 4.3: UniversalBleScanner

**Files:**
- Create: `packages/esp_prov_ble_universal/lib/src/scanner.dart`
- Modify: `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`
- Test: `packages/esp_prov_ble_universal/test/scanner_test.dart`

**Interfaces:**
- Consumes: transport (4.2), `ProvScanner`/`DiscoveredDevice` (2.1).
- Produces: Exported: `final class UniversalBleScanner implements ProvScanner { const new({List<String> webServiceUuids = const [defaultServiceUuid, exampleServiceUuid], bool androidLegacyScan = true}); }`
and `final class UniversalBleDevice implements DiscoveredDevice { const new({required String id, required String name, required int? rssi, required String serviceUuid}); Future<UniversalBleTransport> connect(); }`.

Filtering happens in Dart (case-insensitive prefix, dedupe by device id
after the first matching advert), not with `ScanFilter.withNamePrefix`,
whose case handling is platform-specific. `serviceUuid` is `services[0]`
from the advertisement, lowercase, or `''` when absent. The connect
fallbacks in 4.2 then apply. `startScan` gets
`PlatformConfig(android: AndroidOptions(legacy: true), web: WebOptions(optionalServices: ...))`:
universal_ble's README asks for `legacy: true` for ESP32 (legacy BLE 4.x
advertisements; the option exists since universal_ble 2.1.0), and Web
Bluetooth only lets a page open services listed in `optionalServices`.
Cancelling the stream calls `stopScan`. Permissions are not requested here
(spec 3.2); universal_ble itself asks on `startScan` on Android/iOS.

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_ble_universal/test/scanner_test.dart`:

```dart
import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

import 'support/fake_ble_platform.dart';

void main() {
  test('filters by name prefix case-insensitively and dedupes by id', () async {
    final platform = FakeBlePlatform(
      adverts: [
        BleDevice(
          deviceId: '1',
          name: 'PROV_AAA',
          rssi: -40,
          services: ['021A9004-0382-4AEA-BFF4-6B3F1C5ADFB4'],
        ),
        BleDevice(deviceId: '2', name: 'Headphones', rssi: -30),
        BleDevice(deviceId: '1', name: 'PROV_AAA', rssi: -41),
        BleDevice(deviceId: '3', name: 'prov_bbb', rssi: -70),
        BleDevice(deviceId: '4', name: null, rssi: -70),
      ],
    );
    UniversalBle.setInstance(platform);
    final devices = await const UniversalBleScanner().scan().take(2).toList();
    expect(devices.map((d) => d.id), ['1', '3']);
    expect(devices.first.serviceUuid, '021a9004-0382-4aea-bff4-6b3f1c5adfb4');
    expect(devices.last.serviceUuid, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(platform.log, ['startScan', 'stopScan']);
    expect(platform.lastScanConfig!.android!.legacy, isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test test/scanner_test.dart)`

Expected: FAIL: `Compilation failed ... Error: Couldn't find constructor 'UniversalBleScanner'.`

- [ ] **Step 3: Implement the scanner**

Create `packages/esp_prov_ble_universal/lib/src/scanner.dart`:

```dart
import 'dart:async';

import 'package:esp_prov_ble_universal/src/transport.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:universal_ble/universal_ble.dart';

/// A [ProvScanner] backed by `universal_ble`.
///
/// The adapter does not request runtime permissions; the app must hold
/// Bluetooth scan/connect permissions before calling [scan].
final class UniversalBleScanner implements ProvScanner {
  /// Creates a scanner. [webServiceUuids] are passed as Web Bluetooth
  /// `optionalServices` so the browser lets the page open them.
  /// [androidLegacyScan] makes Android report legacy (BLE 4.x)
  /// advertisements, which is what ESP32 provisioning firmware sends.
  const new({
    this.webServiceUuids = const [defaultServiceUuid, exampleServiceUuid],
    this.androidLegacyScan = true,
  });

  /// Service UUIDs the web build may access.
  final List<String> webServiceUuids;

  /// Passed as `AndroidOptions.legacy`.
  final bool androidLegacyScan;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) {
    final prefix = namePrefix.toLowerCase();
    final seen = <String>{};
    StreamSubscription<BleDevice>? subscription;
    late final StreamController<DiscoveredDevice> controller;
    controller = StreamController<DiscoveredDevice>(
      onListen: () {
        subscription = UniversalBle.scanStream.listen((device) {
          final name = device.name ?? '';
          if (!name.toLowerCase().startsWith(prefix)) return;
          if (!seen.add(device.deviceId)) return;
          controller.add(
            UniversalBleDevice(
              id: device.deviceId,
              name: name,
              rssi: device.rssi,
              serviceUuid: device.services.isEmpty
                  ? ''
                  : BleUuidParser.stringOrNull(device.services.first) ?? '',
            ),
          );
        }, onError: controller.addError);
        unawaited(
          UniversalBle.startScan(
            platformConfig: PlatformConfig(
              android: AndroidOptions(legacy: androidLegacyScan),
              web: WebOptions(optionalServices: webServiceUuids),
            ),
          ).catchError((Object e) {
            controller.addError(
              TransportException('Could not start the BLE scan.', cause: e),
            );
          }),
        );
      },
      onCancel: () async {
        await subscription?.cancel();
        await UniversalBle.stopScan();
      },
    );
    return controller.stream;
  }
}

/// A provisioning device seen by [UniversalBleScanner].
final class UniversalBleDevice implements DiscoveredDevice {
  /// Creates a device handle.
  const new({
    required this.id,
    required this.name,
    required this.rssi,
    required this.serviceUuid,
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final int? rssi;

  /// Advertised primary service UUID, or empty when the advertisement did
  /// not include one (the transport then falls back, see
  /// `pickProvisioningService`).
  @override
  final String serviceUuid;

  @override
  Future<UniversalBleTransport> connect() => UniversalBleTransport.connect(
    id,
    advertisedServiceUuid: serviceUuid.isEmpty ? null : serviceUuid,
  );
}
```

Replace the entire contents of `packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart`:

```dart
/// Bluetooth LE transport for `esp_prov_core`, built on `universal_ble`.
library;

export 'src/endpoint_discovery.dart'
    show
        EndpointMap,
        characteristicUuidFor,
        discoverEndpoints,
        endpointIdOf,
        fallbackEndpointNames;
export 'src/scanner.dart';
export 'src/transport.dart';
```

- [ ] **Step 4: Run the adapter suite**

Run: `(cd packages/esp_prov_ble_universal && fvm flutter test )`

Expected: `+15: All tests passed!`

- [ ] **Step 5: Run the full check**

Run: `tool/check.sh`

Expected: `All checks passed.`

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_ble_universal/test/scanner_test.dart \
  packages/esp_prov_ble_universal/lib/src/scanner.dart \
  packages/esp_prov_ble_universal/lib/esp_prov_ble_universal.dart
git commit -m "feat(ble): UniversalBleScanner" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
