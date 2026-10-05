> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 5: esp_prov facade, example app, docs, hardware verification

**Goal:** The Flutter entry point `esp_prov`, a working example app, user-facing docs, and the hardware verification run against the ESP32-S3-DevKitC-1.

**Depends on:** Phases 3 and 4.

---

### Task 5.1: esp_prov facade: EspProvisioning and EspDevice

**Files:**
- Create: `packages/esp_prov/pubspec.yaml`
- Create: `packages/esp_prov/analysis_options.yaml`
- Modify: `pubspec.yaml`
- Create: `packages/esp_prov/lib/esp_prov.dart`
- Create: `packages/esp_prov/lib/src/esp_provisioning.dart`
- Test: `packages/esp_prov/test/esp_provisioning_test.dart`

**Interfaces:**
- Consumes: `EspSession`, `ProvCredentials`, `ProvScanner` (core); `UniversalBleScanner` (4.3).
- Produces: Package `esp_prov`. `package:esp_prov/esp_prov.dart` re-exports all of
`esp_prov_core` plus `UniversalBleDevice`, `UniversalBleScanner`,
`UniversalBleTransport`, and adds:
`final class EspProvisioning { new({ProvScanner? scanner}); Stream<EspDevice> scan({String namePrefix = 'PROV_'}); Future<EspDevice> findDevice(String name, {Duration timeout = const Duration(seconds: 15)}); }`
`final class EspDevice { new(DiscoveredDevice discovered); final DiscoveredDevice discovered; String get id; String get name; int? get rssi; Future<EspSession> connect({ProvCredentials? credentials}); }`

`EspDevice.connect` closes the link again if `EspSession.open` throws
(wrong credentials must not leave a connected peripheral behind).
`findDevice` stops the scan in every outcome (found, timeout, scan ended).
It manages the subscription and a `Timer` itself, because
`Future.timeout` would leave the BLE scan running.

- [ ] **Step 1: Create the package and add it to the workspace**

Create `packages/esp_prov/pubspec.yaml`:

```yaml
name: esp_prov
description: >-
  Provision ESP32 devices over Bluetooth LE with Espressif Unified
  Provisioning: Security 0/1/2, Wi-Fi and Thread, custom endpoints.
version: 0.1.0
repository: https://github.com/MinhTri1401/esp_prov/tree/main/packages/esp_prov
issue_tracker: https://github.com/MinhTri1401/esp_prov/issues
topics:
  - esp32
  - provisioning
  - wifi
  - bluetooth
  - iot

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  esp_prov_ble_universal: ^0.1.0
  esp_prov_core: ^0.1.0
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: ^11.0.0
```

Create `packages/esp_prov/analysis_options.yaml`:

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
  - packages/esp_prov

dev_dependencies:
  very_good_analysis: ^11.0.0
```

Run: `fvm flutter pub get`

Expected: `Got dependencies!`

- [ ] **Step 2: Write the failing test**

Create `packages/esp_prov/test/esp_provisioning_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov/esp_prov.dart';
import 'package:flutter_test/flutter_test.dart';

/// SessionData{sec0: Sec0Payload{msg: S0_Session_Response, sr: {}}}.
const _sec0SessionResponse = [0x52, 0x05, 0x08, 0x01, 0xaa, 0x01, 0x00];

final class _FakeTransport implements ProvTransport {
  new(this.protoVer);

  final String protoVer;
  int disconnects = 0;

  @override
  Set<String> get endpoints => {'proto-ver', 'prov-session'};

  @override
  Stream<void> get onDisconnected => const Stream.empty();

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) async =>
      Uint8List.fromList(
        endpoint == 'proto-ver' ? utf8.encode(protoVer) : _sec0SessionResponse,
      );
}

final class _FakeDevice implements DiscoveredDevice {
  new(this.name, this.transport);

  @override
  final String name;

  final _FakeTransport transport;

  @override
  String get id => name;

  @override
  int? get rssi => -50;

  @override
  String get serviceUuid => '';

  @override
  Future<ProvTransport> connect() async => transport;
}

final class _FakeScanner implements ProvScanner {
  new(this.devices);

  final List<DiscoveredDevice> devices;
  String? lastPrefix;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) {
    lastPrefix = namePrefix;
    return Stream.fromIterable(devices);
  }
}

final class _StreamScanner implements ProvScanner {
  new(this.stream);

  final Stream<DiscoveredDevice> stream;

  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) => stream;
}

void main() {
  const sec0 = '{"prov":{"ver":"v1.1","sec_ver":0,"cap":["no_sec"]}}';
  const sec2 = '{"prov":{"ver":"v1.1","sec_ver":2,"sec_patch_ver":1}}';

  test('scan wraps discovered devices', () async {
    final scanner = _FakeScanner([_FakeDevice('PROV_1', _FakeTransport(sec0))]);
    final devices = await EspProvisioning(scanner: scanner).scan().toList();
    expect(devices.single.name, 'PROV_1');
    expect(scanner.lastPrefix, 'PROV_');
  });

  test('connect opens a session', () async {
    final device = EspDevice(_FakeDevice('PROV_1', _FakeTransport(sec0)));
    final session = await device.connect();
    expect(session.securityVersion, 0);
  });

  test('a failed connect closes the link', () async {
    final transport = _FakeTransport(sec2);
    final device = EspDevice(_FakeDevice('PROV_1', transport));
    await expectLater(device.connect(), throwsA(isA<MissingCredentials>()));
    expect(transport.disconnects, 1);
  });

  test('findDevice matches the exact QR name', () async {
    final scanner = _FakeScanner([
      _FakeDevice('PROV_1A', _FakeTransport(sec0)),
      _FakeDevice('prov_1', _FakeTransport(sec0)),
    ]);
    final device = await EspProvisioning(scanner: scanner).findDevice('PROV_1');
    expect(device.name, 'prov_1');
  });

  test('findDevice times out and stops scanning', () async {
    var cancelled = false;
    final controller = StreamController<DiscoveredDevice>(
      onCancel: () => cancelled = true,
    );
    final scanner = _StreamScanner(controller.stream);
    await expectLater(
      EspProvisioning(scanner: scanner)
          .findDevice('PROV_X', timeout: const Duration(milliseconds: 20)),
      throwsA(isA<TransportException>()),
    );
    expect(cancelled, isTrue);
  });

  test('findDevice reports a missing device', () async {
    final scanner = _FakeScanner(const []);
    await expectLater(
      EspProvisioning(scanner: scanner).findDevice('PROV_X'),
      throwsA(isA<TransportException>()),
    );
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `(cd packages/esp_prov && fvm flutter test)`

Expected: FAIL: `Compilation failed ... Error: Type 'ProvTransport' not found.` (`lib/esp_prov.dart` does not exist yet).

- [ ] **Step 4: Implement**

Create `packages/esp_prov/lib/esp_prov.dart`:

````dart
/// Provision Espressif devices over Bluetooth LE.
///
/// ```dart
/// final prov = EspProvisioning();
/// await for (final device in prov.scan()) {
///   final session = await device.connect(
///     credentials: const ProvCredentials.security2(
///       username: 'wifiprov',
///       password: 'abcd1234',
///     ),
///   );
///   // session.wifi.scan(), session.wifi.provision(...)
/// }
/// ```
library;

export 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart'
    show UniversalBleDevice, UniversalBleScanner, UniversalBleTransport;
export 'package:esp_prov_core/esp_prov_core.dart';

export 'src/esp_provisioning.dart';
````

Create `packages/esp_prov/lib/src/esp_provisioning.dart`:

```dart
import 'dart:async';

import 'package:esp_prov_ble_universal/esp_prov_ble_universal.dart';
import 'package:esp_prov_core/esp_prov_core.dart';

/// Scans for provisioning devices and opens sessions with them.
final class EspProvisioning {
  /// Creates the entry point. Uses `universal_ble` unless a [scanner] is
  /// given (tests, or another BLE stack).
  new({ProvScanner? scanner})
    : _scanner = scanner ?? const UniversalBleScanner();

  final ProvScanner _scanner;

  /// Emits each device whose name starts with [namePrefix]
  /// (case-insensitive) once. Cancel the subscription to stop scanning.
  Stream<EspDevice> scan({String namePrefix = 'PROV_'}) =>
      _scanner.scan(namePrefix: namePrefix).map(EspDevice.new);

  /// Scans until a device named exactly [name] (case-insensitive) appears,
  /// e.g. the `name` from a [ProvQrPayload]. The scan stops either way.
  ///
  /// Throws [TransportException] if none is seen within [timeout].
  Future<EspDevice> findDevice(
    String name, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final wanted = name.toLowerCase();
    final found = Completer<EspDevice>();
    void fail(Object error) {
      if (!found.isCompleted) found.completeError(error);
    }

    final timer = Timer(
      timeout,
      () => fail(TransportException('Device "$name" not found in $timeout.')),
    );
    final subscription = scan(namePrefix: name).listen(
      (device) {
        if (device.name.toLowerCase() == wanted && !found.isCompleted) {
          found.complete(device);
        }
      },
      onError: fail,
      onDone: () =>
          fail(TransportException('Scan ended before "$name" was found.')),
    );
    try {
      return await found.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}

/// A provisioning device found by [EspProvisioning.scan].
final class EspDevice {
  /// Wraps a transport-level [DiscoveredDevice].
  new(this.discovered);

  /// The underlying transport-level device.
  final DiscoveredDevice discovered;

  /// Platform device id.
  String get id => discovered.id;

  /// Advertised name, e.g. `PROV_1A2B3C`.
  String get name => discovered.name;

  /// Signal strength of the last advertisement.
  int? get rssi => discovered.rssi;

  /// Connects, reads `proto-ver`, runs the handshake for the scheme the
  /// firmware declares and returns the session. The link is closed again if
  /// any step fails.
  ///
  /// See [EspSession.open] for the errors thrown.
  Future<EspSession> connect({ProvCredentials? credentials}) async {
    final transport = await discovered.connect();
    try {
      return await EspSession.open(transport, credentials: credentials);
    } on Object {
      await transport.disconnect();
      rethrow;
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `(cd packages/esp_prov && fvm flutter test)`

Expected: `+6: All tests passed!`

- [ ] **Step 6: Analyze**

Run: `(cd packages/esp_prov && fvm flutter analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 7: Commit**

```bash
git add \
  packages/esp_prov/pubspec.yaml \
  packages/esp_prov/analysis_options.yaml \
  pubspec.yaml \
  packages/esp_prov/test/esp_provisioning_test.dart \
  packages/esp_prov/lib/esp_prov.dart \
  packages/esp_prov/lib/src/esp_provisioning.dart \
  pubspec.lock
git commit -m "feat(esp_prov): EspProvisioning facade" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 5.2: Example app

**Files:**
- Create: `packages/esp_prov/example/android, ios, macos, linux, windows, web` (generated by `flutter create`; Android manifest, iOS/macOS Info.plist and macOS entitlements patched in Step 7)
- Modify: `packages/esp_prov/example/pubspec.yaml`
- Modify: `packages/esp_prov/example/analysis_options.yaml`
- Modify: `pubspec.yaml`
- Modify: `packages/esp_prov/example/lib/main.dart`
- Create: `packages/esp_prov/example/lib/home_page.dart`
- Create: `packages/esp_prov/example/lib/session_page.dart`
- Modify: `packages/esp_prov/example/test/widget_test.dart`

**Interfaces:**
- Consumes: `EspProvisioning`, `EspDevice`, `EspSession`, `ProvQrPayload`, Wi-Fi states (5.1 and core).
- Produces: `packages/esp_prov/example` (workspace member `esp_prov_example`):
`EspProvExampleApp({required EspProvisioning provisioning, required Future<void> Function() requestPermissions})`,
`HomePage` (QR paste field with key `Key('qr')`, credential selector,
name prefix, scan button with key `Key('scan')`, device list) and
`SessionPage(name:, session:)` (device info, Wi-Fi scan list, SSID and
passphrase, provision log, custom-data round trip).

`flutter create` generates the platform folders; then replace its
`pubspec.yaml` (the app becomes a workspace member, so delete its
`pubspec.lock`), `analysis_options.yaml`, `lib/` and `test/`. The app asks
for permissions through `UniversalBle.requestPermissions()` (available in
universal_ble since 1.0) and keeps it injectable for widget tests. Platform
setup follows universal_ble's README: Android manifest permissions,
`NSBluetoothAlwaysUsageDescription` on iOS/macOS, and the macOS
`com.apple.security.device.bluetooth` entitlement.

Widget-test note: `StreamSubscription.cancel()` on a finished stream returns
a future completed in the root zone, which `pumpAndSettle` never runs. The
connect-error test therefore taps inside `tester.runAsync`. The app itself
keeps awaiting `cancel()` so the scan stops before connecting.

- [ ] **Step 1: Generate the Flutter app skeleton**

Run (from the repository root):

```bash
fvm flutter create --project-name esp_prov_example --org dev.espprov \
  --platforms android,ios,macos,linux,windows,web --no-pub packages/esp_prov/example
rm -f packages/esp_prov/example/pubspec.lock packages/esp_prov/example/esp_prov_example.iml
```

Expected: `All done!` and the platform folders under `packages/esp_prov/example`.

- [ ] **Step 2: Make it a workspace member**

Replace the entire contents of `packages/esp_prov/example/pubspec.yaml`:

```yaml
name: esp_prov_example
description: Example app for esp_prov. Scans, connects, provisions Wi-Fi.
publish_to: none
version: 1.0.0+1

resolution: workspace

environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"

dependencies:
  esp_prov: ^0.1.0
  flutter:
    sdk: flutter
  universal_ble: ^2.2.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  very_good_analysis: ^11.0.0

flutter:
  uses-material-design: true
```

Replace the entire contents of `packages/esp_prov/example/analysis_options.yaml`:

```yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - build/**
    - android/**
    - ios/**
    - linux/**
    - macos/**
    - web/**
    - windows/**

linter:
  rules:
    public_member_api_docs: false
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
  - packages/esp_prov
  - packages/esp_prov/example

dev_dependencies:
  very_good_analysis: ^11.0.0
```

Run: `fvm flutter pub get`

Expected: `Got dependencies!`

- [ ] **Step 3: Write the failing widget tests**

Replace the entire contents of `packages/esp_prov/example/test/widget_test.dart`:

```dart
import 'package:esp_prov/esp_prov.dart';
import 'package:esp_prov_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Device implements DiscoveredDevice {
  @override
  String get id => 'AA:BB';

  @override
  String get name => 'PROV_ABC123';

  @override
  int? get rssi => -42;

  @override
  String get serviceUuid => '';

  @override
  Future<ProvTransport> connect() =>
      Future.error(const TransportException('not in tests'));
}

final class _Scanner implements ProvScanner {
  @override
  Stream<DiscoveredDevice> scan({String namePrefix = 'PROV_'}) =>
      Stream.value(_Device());
}

void main() {
  testWidgets('scan lists devices', (tester) async {
    var permissionRequests = 0;
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async => permissionRequests++,
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('scan')));
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    expect(permissionRequests, 1);
    expect(find.text('PROV_ABC123'), findsOneWidget);
  });

  testWidgets('connect errors are shown, not thrown', (tester) async {
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async {},
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('scan')));
    await tester.tap(find.byKey(const Key('scan')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('PROV_ABC123'));
    // Cancelling the finished scan completes in the root zone, so let real
    // async work run while the tap is handled.
    await tester.runAsync(() async {
      await tester.tap(find.text('PROV_ABC123'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text('not in tests'), findsOneWidget);
  });

  testWidgets('an invalid QR payload shows a message', (tester) async {
    await tester.pumpWidget(
      EspProvExampleApp(
        provisioning: EspProvisioning(scanner: _Scanner()),
        requestPermissions: () async {},
      ),
    );
    await tester.enterText(find.byKey(const Key('qr')), 'not json');
    await tester.tap(find.text('Connect with QR payload'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QR payload is not JSON'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run them to verify they fail**

Run: `(cd packages/esp_prov/example && fvm flutter test)`

Expected: FAIL: `Compilation failed ... Error: Method not found: 'EspProvExampleApp'.`

- [ ] **Step 5: Write the app**

Replace the entire contents of `packages/esp_prov/example/lib/main.dart`:

```dart
import 'package:esp_prov/esp_prov.dart';
import 'package:esp_prov_example/home_page.dart';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  runApp(
    EspProvExampleApp(
      provisioning: EspProvisioning(),
      requestPermissions: UniversalBle.requestPermissions,
    ),
  );
}

class EspProvExampleApp extends StatelessWidget {
  const new({
    required this.provisioning,
    required this.requestPermissions,
    super.key,
  });

  final EspProvisioning provisioning;
  final Future<void> Function() requestPermissions;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'esp_prov example',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    home: HomePage(
      provisioning: provisioning,
      requestPermissions: requestPermissions,
    ),
  );
}

/// Text for an error shown to the user.
String describeError(Object error) =>
    error is ProvException ? error.message : error.toString();
```

Create `packages/esp_prov/example/lib/home_page.dart`:

```dart
import 'dart:async';

import 'package:esp_prov/esp_prov.dart';
import 'package:esp_prov_example/main.dart';
import 'package:esp_prov_example/session_page.dart';
import 'package:flutter/material.dart';

enum CredentialKind { none, pop, security2 }

class HomePage extends StatefulWidget {
  const new({
    required this.provisioning,
    required this.requestPermissions,
    super.key,
  });

  final EspProvisioning provisioning;
  final Future<void> Function() requestPermissions;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _qr = TextEditingController();
  final _prefix = TextEditingController(text: 'PROV_');
  final _username = TextEditingController(text: 'wifiprov');
  final _secret = TextEditingController(text: 'abcd1234');
  final _devices = <EspDevice>[];
  CredentialKind _kind = CredentialKind.security2;
  StreamSubscription<EspDevice>? _scan;
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    _qr.dispose();
    _prefix.dispose();
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  ProvCredentials get _credentials => switch (_kind) {
    CredentialKind.none => const ProvCredentials.none(),
    CredentialKind.pop => ProvCredentials.pop(_secret.text),
    CredentialKind.security2 => ProvCredentials.security2(
      username: _username.text,
      password: _secret.text,
    ),
  };

  Future<void> _toggleScan() async {
    if (_scan != null) {
      await _scan!.cancel();
      setState(() => _scan = null);
      return;
    }
    try {
      await widget.requestPermissions();
    } on Object catch (e) {
      _show(e);
      return;
    }
    setState(() {
      _devices.clear();
      _scan = widget.provisioning
          .scan(namePrefix: _prefix.text)
          .listen((d) => setState(() => _devices.add(d)), onError: _show);
    });
  }

  Future<void> _connect(
    Future<EspDevice> Function() find,
    ProvCredentials credentials,
  ) async {
    setState(() => _busy = true);
    await _scan?.cancel();
    _scan = null;
    try {
      final device = await find();
      final session = await device.connect(credentials: credentials);
      if (!mounted) {
        await session.close();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionPage(name: device.name, session: session),
        ),
      );
    } on Object catch (e) {
      _show(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectWithQr() async {
    final ProvQrPayload qr;
    try {
      qr = ProvQrPayload.parse(_qr.text);
    } on FormatException catch (e) {
      _show(e.message);
      return;
    }
    await widget.requestPermissions();
    await _connect(
      () => widget.provisioning.findDevice(qr.name),
      qr.credentials,
    );
  }

  void _show(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(describeError(error))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ESP provisioning')),
    body: AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('qr'),
            controller: _qr,
            decoration: const InputDecoration(
              labelText: 'QR payload JSON (paste)',
            ),
            maxLines: 3,
          ),
          FilledButton(
            onPressed: _connectWithQr,
            child: const Text('Connect with QR payload'),
          ),
          const Divider(height: 32),
          SegmentedButton<CredentialKind>(
            segments: const [
              ButtonSegment(value: CredentialKind.none, label: Text('None')),
              ButtonSegment(value: CredentialKind.pop, label: Text('PoP')),
              ButtonSegment(
                value: CredentialKind.security2,
                label: Text('Security 2'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.single),
          ),
          if (_kind == CredentialKind.security2)
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
          if (_kind != CredentialKind.none)
            TextField(
              controller: _secret,
              decoration: InputDecoration(
                labelText: _kind == CredentialKind.pop
                    ? 'Proof of possession'
                    : 'Password',
              ),
            ),
          TextField(
            controller: _prefix,
            decoration: const InputDecoration(labelText: 'Name prefix'),
          ),
          FilledButton.tonal(
            key: const Key('scan'),
            onPressed: _toggleScan,
            child: Text(_scan == null ? 'Scan' : 'Stop scan'),
          ),
          if (_busy) const LinearProgressIndicator(),
          for (final device in _devices)
            ListTile(
              title: Text(device.name),
              subtitle: Text('${device.id}  RSSI ${device.rssi ?? '-'}'),
              onTap: () => _connect(() async => device, _credentials),
            ),
        ],
      ),
    ),
  );
}
```

Create `packages/esp_prov/example/lib/session_page.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:esp_prov/esp_prov.dart';
import 'package:esp_prov_example/main.dart';
import 'package:flutter/material.dart';

class SessionPage extends StatefulWidget {
  const new({required this.name, required this.session, super.key});

  final String name;
  final EspSession session;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final _ssid = TextEditingController();
  final _passphrase = TextEditingController();
  final _custom = TextEditingController(text: 'hello from esp_prov');
  final _log = <String>[];
  List<WifiNetwork> _networks = const [];
  bool _busy = false;

  EspSession get _session => widget.session;

  @override
  void dispose() {
    unawaited(_session.close());
    _ssid.dispose();
    _passphrase.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _append(String line) => setState(() => _log.add(line));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      _append('Error: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanWifi() => _run(() async {
    final networks = await _session.wifi.scan();
    setState(() => _networks = networks);
    _append('Found ${networks.length} networks');
  });

  Future<void> _provision() => _run(() async {
    final states = _session.wifi.provision(
      ssid: _ssid.text,
      passphrase: _passphrase.text,
    );
    await for (final state in states) {
      _append(switch (state) {
        WifiApplying() => 'Sending credentials',
        WifiConnecting() => 'Device is connecting',
        WifiAttemptFailed(:final attemptsRemaining) =>
          'Attempt failed, $attemptsRemaining left',
        WifiConnected(:final ip4, :final ssid) => 'Connected to $ssid as $ip4',
        WifiFailed(:final reason) => 'Failed: ${reason.name}',
      });
    }
  });

  Future<void> _sendCustom() => _run(() async {
    final endpoint = _session.custom('custom-data');
    final response = await endpoint.send(utf8.encode(_custom.text));
    final text = utf8
        .decode(response, allowMalformed: true)
        .replaceAll('\u0000', '');
    _append('custom-data replied: $text');
  });

  @override
  Widget build(BuildContext context) {
    final info = _session.info;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${info.version}  Security ${info.secVer} '
              '(patch ${info.secPatchVer})\n'
              'Capabilities: ${info.capabilities.join(', ')}\n'
              'Endpoints: ${_session.endpoints.join(', ')}',
            ),
            if (_busy) const LinearProgressIndicator(),
            FilledButton.tonal(
              onPressed: _scanWifi,
              child: const Text('Scan Wi-Fi'),
            ),
            for (final n in _networks)
              ListTile(
                dense: true,
                title: Text(n.ssid),
                subtitle: Text('${n.rssi} dBm  ${n.authMode.name}'),
                onTap: () => _ssid.text = n.ssid,
              ),
            TextField(
              controller: _ssid,
              decoration: const InputDecoration(labelText: 'SSID'),
            ),
            TextField(
              controller: _passphrase,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            FilledButton(onPressed: _provision, child: const Text('Provision')),
            const Divider(height: 32),
            TextField(
              controller: _custom,
              decoration: const InputDecoration(labelText: 'custom-data'),
            ),
            FilledButton.tonal(
              onPressed: _sendCustom,
              child: const Text('Send custom data'),
            ),
            const Divider(height: 32),
            for (final line in _log) Text(line),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the widget tests to verify they pass**

Run: `(cd packages/esp_prov/example && fvm flutter test)`

Expected: `+3: All tests passed!`

- [ ] **Step 7: Add Bluetooth permissions for Android, iOS and macOS**

Run (from the repository root):

```bash
cd packages/esp_prov/example && python3 - <<'EOF'
import plistlib
from pathlib import Path

USAGE = 'Bluetooth is used to find and provision nearby ESP32 devices.'
for path in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']:
    p = Path(path)
    data = plistlib.loads(p.read_bytes())
    data['NSBluetoothAlwaysUsageDescription'] = USAGE
    p.write_bytes(plistlib.dumps(data))
for path in ['macos/Runner/DebugProfile.entitlements',
             'macos/Runner/Release.entitlements']:
    p = Path(path)
    data = plistlib.loads(p.read_bytes())
    data['com.apple.security.device.bluetooth'] = True
    p.write_bytes(plistlib.dumps(data))

manifest = Path('android/app/src/main/AndroidManifest.xml')
head = '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
text = manifest.read_text()
assert text.startswith(head), 'unexpected manifest header'
permissions = (
    '    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />\n'
    '    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />\n'
    '    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />\n'
    '    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />\n'
    '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />\n'
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />\n'
)
manifest.write_text(text.replace(head, head + permissions, 1))
print('platform permissions added')
EOF
```

Expected: `platform permissions added`; `git diff --stat` shows the manifest, both `Info.plist` files and both macOS entitlements changed.

- [ ] **Step 8: Analyze and build for the web (proves no dart:io/dart:isolate leaks into web)**

Run: `(cd packages/esp_prov/example && fvm flutter analyze --fatal-infos && fvm flutter build web)`

Expected: `No issues found!`, `Wasm dry run succeeded`, `✓ Built build/web`.

- [ ] **Step 9: Commit**

```bash
git add \
  packages/esp_prov/example/pubspec.yaml \
  packages/esp_prov/example/analysis_options.yaml \
  pubspec.yaml \
  packages/esp_prov/example/test/widget_test.dart \
  packages/esp_prov/example/lib/main.dart \
  packages/esp_prov/example/lib/home_page.dart \
  packages/esp_prov/example/lib/session_page.dart \
  pubspec.lock \
  packages/esp_prov/example
git commit -m "feat(example): example app for scan, QR, Wi-Fi and custom data" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 5.3: Hardware integration test and verification checklist

**Files:**
- Create: `docs/hardware-verification.md`
- Test: `packages/esp_prov/example/integration_test/provisioning_test.dart`

**Interfaces:**
- Consumes: the example app (5.2).
- Produces: `packages/esp_prov/example/integration_test/provisioning_test.dart` (parameterised by `--dart-define`) and `docs/hardware-verification.md`.

The integration test is the automated half of success criteria 1, 4 and
5. It needs a phone and the ESP32-S3 board, so CI only analyzes it.
`docs/hardware-verification.md` is the manual half and includes installing
ESP-IDF, which is not on this Mac. Steps 3 and 4 are manual and done by a
person with the hardware.

- [ ] **Step 1: Write the integration test and the checklist**

Create `packages/esp_prov/example/integration_test/provisioning_test.dart`:

```dart
// Hardware test: needs a phone with Bluetooth and an ESP32 running the
// wifi_prov_mgr example. See docs/hardware-verification.md.
//
// fvm flutter test integration_test/provisioning_test.dart -d <device-id> \
//   --dart-define=PROV_NAME=PROV_1A2B3C \
//   --dart-define=PROV_SEC=2 \
//   --dart-define=PROV_USERNAME=wifiprov \
//   --dart-define=PROV_SECRET=abcd1234 \
//   --dart-define=WIFI_SSID=MyNetwork \
//   --dart-define=WIFI_PASSPHRASE=secret123
import 'dart:convert';

import 'package:esp_prov/esp_prov.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:universal_ble/universal_ble.dart';

const _name = String.fromEnvironment('PROV_NAME');
const _sec = int.fromEnvironment('PROV_SEC', defaultValue: 2);
const _username = String.fromEnvironment(
  'PROV_USERNAME',
  defaultValue: 'wifiprov',
);
const _secret = String.fromEnvironment('PROV_SECRET', defaultValue: 'abcd1234');
const _ssid = String.fromEnvironment('WIFI_SSID');
const _passphrase = String.fromEnvironment('WIFI_PASSPHRASE');

ProvCredentials get _credentials => switch (_sec) {
  0 => const ProvCredentials.none(),
  1 => const ProvCredentials.pop(_secret),
  _ => const ProvCredentials.security2(username: _username, password: _secret),
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(_name, isNotEmpty, reason: 'pass --dart-define=PROV_NAME=...');
    expect(_ssid, isNotEmpty, reason: 'pass --dart-define=WIFI_SSID=...');
    await UniversalBle.requestPermissions();
  });

  testWidgets('wrong credentials surface as PopMismatch', (tester) async {
    if (_sec == 0) return;
    final device = await EspProvisioning().findDevice(_name);
    const wrong = _sec == 1
        ? ProvCredentials.pop('wrong-pop')
        : ProvCredentials.security2(
            username: _username,
            password: 'wrong-password',
          );
    await expectLater(
      device.connect(credentials: wrong),
      throwsA(isA<PopMismatch>()),
    );
  });

  testWidgets('handshake, custom-data, Wi-Fi scan and provision', (
    tester,
  ) async {
    // Give the firmware time to re-advertise after the rejected session.
    await Future<void>.delayed(const Duration(seconds: 2));
    final device = await EspProvisioning().findDevice(_name);
    final session = await device.connect(credentials: _credentials);
    expect(session.securityVersion, _sec);

    final reply = await session
        .custom('custom-data')
        .send(utf8.encode('esp_prov integration test'));
    expect(utf8.decode(reply).replaceAll('\u0000', ''), 'SUCCESS');

    final networks = await session.wifi.scan();
    expect(networks.map((n) => n.ssid), contains(_ssid));

    final states = await session.wifi
        .provision(ssid: _ssid, passphrase: _passphrase)
        .toList();
    expect(states.last, isA<WifiConnected>());
    await session.close();
  });
}
```

Create `docs/hardware-verification.md`:

````markdown
# Hardware verification: ESP32-S3-DevKitC-1

Manual checklist for the success criteria in
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md` (section 1).
Run it before every release and after any change to `security/`, `crypto/`,
`session/` or the BLE adapter. Record the results in the PR description.

Hardware: ESP32-S3-DevKitC-1 N16R8, a USB-C cable on the **UART** port, an
Android phone (Android 12 or newer) and an iPhone, and a 2.4 GHz Wi-Fi
network you control (SSID plus passphrase).

## 0. One-time setup (manual, done by a person)

ESP-IDF is not installed on the development Mac. Install it once:

```bash
brew install cmake ninja dfu-util ccache python3
mkdir -p ~/esp && cd ~/esp
git clone -b v5.4.2 --recursive https://github.com/espressif/esp-idf.git esp-idf-v5.4.2
cd esp-idf-v5.4.2 && ./install.sh esp32s3
```

Every new terminal that builds firmware needs:

```bash
. ~/esp/esp-idf-v5.4.2/export.sh
idf.py --version   # expect: ESP-IDF v5.4.2
```

Find the board's serial port after plugging it in:

```bash
ls /dev/cu.usbserial-* /dev/cu.wchusbserial-* /dev/cu.usbmodem* 2>/dev/null
```

Use that path as `PORT` below, e.g. `export PORT=/dev/cu.usbserial-110`.

Optional second pass on ESP-IDF 6.0 (pulls `network_provisioning`, reports
`netprov-v1.2`): clone `-b v6.0` into `~/esp/esp-idf-v6.0` and repeat
sections 1-3 with its `export.sh`. The example path is the same.

## 1. Build A: Security 2 (example default)

```bash
cp -r "$IDF_PATH/examples/provisioning/wifi_prov_mgr" ~/esp/prov-sec2
cd ~/esp/prov-sec2
idf.py set-target esp32s3
idf.py -p "$PORT" erase-flash flash monitor
```

The defaults are BLE transport, Security 2, development mode (username
`wifiprov`, password `abcd1234`) and a `custom-data` endpoint. In the monitor,
after `If QR code is not visible, copy paste the below URL in a browser.`,
the URL ends in `?data=` followed by the QR payload JSON, e.g.
`{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov","pop":"abcd1234","transport":"ble"}`.
Its `name` (`PROV_XXXXXX` below) is the BLE device name. Leave the monitor
running (Ctrl+] exits).

## 2. Build B: Security 1 with PoP `abcd1234`

```bash
cp -r "$IDF_PATH/examples/provisioning/wifi_prov_mgr" ~/esp/prov-sec1
cd ~/esp/prov-sec1
idf.py set-target esp32s3
idf.py menuconfig
```

In menuconfig: **Example Configuration -> Protocomm security version ->
Security version 1**. Save and exit, then:

```bash
idf.py -p "$PORT" erase-flash flash monitor
```

The QR payload is `{"ver":"v1","name":"PROV_XXXXXX","pop":"abcd1234","transport":"ble"}`.

## 3. Build C: Security 2 with a longer auto-stop timeout

Same as build A, plus in menuconfig: **Component config -> Wi-Fi Provisioning
Manager -> Provisioning auto-stop timeout** set to `120`, and **Example
Configuration -> Re-provisioning** enabled (lets `ctrl.reprovisionWifi()` be
exercised without erasing flash).

## 4. Automated hardware test (per build, per phone)

From `packages/esp_prov/example`, with the phone connected and the board
freshly flashed (`erase-flash` resets the provisioned state):

```bash
fvm flutter devices                      # copy the phone's device id
fvm flutter test integration_test/provisioning_test.dart -d <device-id> \
  --dart-define=PROV_NAME=PROV_XXXXXX \
  --dart-define=PROV_SEC=2 \
  --dart-define=PROV_USERNAME=wifiprov \
  --dart-define=PROV_SECRET=abcd1234 \
  --dart-define=WIFI_SSID=<your ssid> \
  --dart-define=WIFI_PASSPHRASE=<your passphrase>
```

For build B use `PROV_SEC=1` (username is ignored). Expected: `All tests
passed!`, and the monitor shows `Received Wi-Fi credentials`, then
`Connected with IP Address:...`, then `Provisioning successful`.

| Build | Android | iOS |
|---|---|---|
| A (sec2) | [ ] | [ ] |
| B (sec1) | [ ] | [ ] |
| C (sec2, long timeout) | [ ] | [ ] |

## 5. Manual example-app checks (build C, one phone is enough)

Run `fvm flutter run -d <device-id>` in `packages/esp_prov/example`.
Before each check, if the device was provisioned, run
`idf.py -p "$PORT" erase-flash flash monitor` again.

- [ ] Scan lists `PROV_XXXXXX` once (no duplicates), with an RSSI value.
- [ ] Paste the QR JSON from the monitor, tap **Connect with QR payload**:
      session page shows `Security 2 (patch 1)` and endpoints include
      `custom-data`.
- [ ] **Scan Wi-Fi** lists your network; tapping it fills the SSID.
- [ ] **Send custom data** logs `custom-data replied: SUCCESS`; the monitor
      prints `Received data: hello from esp_prov`.
- [ ] Wrong password (`Security 2` segment, password `nope`): SnackBar text
      starts with `The device dropped the session` or `The device proof does
      not verify` (PopMismatch), not a generic error. The monitor prints
      `Received incorrect username and/or PoP for establishing secure
      session!`.
- [ ] Wrong passphrase: log ends with `Failed: authError` (may first show
      `Attempt failed, N left`).
- [ ] Unknown SSID (type `does-not-exist`): log ends with
      `Failed: networkNotFound`.
- [ ] Unplug the board while the log shows `Device is connecting`: log ends
      with `Failed: deviceDisconnected`.
- [ ] Correct credentials: log ends with `Connected to <ssid> as <ip>`; the
      board then stops advertising (auto-stop) and the app shows no error.
- [ ] Build B with the PoP segment and `abcd1234`: same flow succeeds;
      PoP `wrong` gives a PopMismatch message.

## 6. Timing

- [ ] On the Android phone, Security 2 connect (tap to session page) takes
      under 3 s. If it is slower, profile `Srp6aClient.computeProof`
      (spec target: SRP math under 1 s in release builds).
````

- [ ] **Step 2: Analyze it**

Run: `(cd packages/esp_prov/example && fvm flutter analyze --fatal-infos)`

Expected: `No issues found!`

- [ ] **Step 3: MANUAL: install ESP-IDF and flash build A (Security 2)**

Follow `docs/hardware-verification.md` sections 0 and 1 on the Mac with
the board attached. Expected: `idf.py --version` prints
`ESP-IDF v5.4.2`, and the monitor shows the QR URL whose `data=` JSON
contains `"username":"wifiprov","pop":"abcd1234"`.

- [ ] **Step 4: MANUAL: run the hardware matrix**

Run section 4 for builds A, B and C on the Android phone and the iPhone,
then the section 5 checks. Expected: `All tests passed!` for every cell of
the table, every section 5 box ticked. Paste the filled table into the PR
description. If a cell fails, stop and debug with
`superpowers:systematic-debugging`; do not change fixtures to make hardware
pass.

- [ ] **Step 5: Commit**

```bash
git add \
  packages/esp_prov/example/integration_test/provisioning_test.dart \
  docs/hardware-verification.md
git commit -m "test(example): hardware integration test and checklist" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 5.4: READMEs, package example and API docs

**Files:**
- Create: `README.md`
- Create: `packages/esp_prov/README.md`
- Create: `packages/esp_prov_core/README.md`
- Create: `packages/esp_prov_ble_universal/README.md`
- Create: `packages/esp_prov_core/example/esp_prov_core_example.dart`

**Interfaces:**
- Consumes: all packages.
- Produces: root `README.md`; `README.md` in each package; `packages/esp_prov_core/example/esp_prov_core_example.dart` (pana "has an example").

pana scores "Package has an example" and "20% of the public API
documented" per package. Every public member already has a `///` comment
(the `public_member_api_docs` lint enforces it); this task adds the package
READMEs and the core example, and checks dartdoc.

- [ ] **Step 1: Write the READMEs and the core example**

Create `README.md`:

````markdown
# esp_prov

Provision Espressif devices from Flutter and Dart using Espressif's Unified
Provisioning protocol (protocomm) over Bluetooth LE. Security 0, 1 and 2 are
implemented in pure Dart, with Wi-Fi and Thread flows and custom endpoints.
Works with ESP-IDF 5.1 through 6.x firmware (`wifi_provisioning` and
`network_provisioning`).

| Package | What it is |
|---|---|
| [`esp_prov`](packages/esp_prov) | Flutter entry point: scan, connect, provision. Start here. |
| [`esp_prov_core`](packages/esp_prov_core) | Pure-Dart protocol stack (no Flutter). Bring your own transport. |
| [`esp_prov_ble_universal`](packages/esp_prov_ble_universal) | BLE transport on `universal_ble` (Android, iOS, macOS, Windows, Linux, web). |

## Development

The toolchain is pinned with [FVM](https://fvm.app) to Flutter 3.47.5
(Dart 3.13). FVM 3 reads `.fvmrc`; FVM 2.x needs the local link once:

```bash
fvm use 3.47.5 --force   # FVM 2.x; with FVM 3 run `fvm install` instead
fvm dart --version       # Dart SDK version: 3.13.x
tool/check.sh            # pub get, format check, analyze, tests for every package
```

Regenerating code and fixtures:

```bash
fvm dart pub global activate protoc_plugin 25.1.0
tool/gen_proto.sh      # protoc -> packages/esp_prov_core/lib/src/proto

uv venv .venv && uv pip install --python .venv/bin/python -r tool/requirements.txt
.venv/bin/python tool/gen_fixtures.py   # Espressif esp_prov -> test fixtures
```

Hardware verification against an ESP32-S3 is described in
[docs/hardware-verification.md](docs/hardware-verification.md).
````

Create `packages/esp_prov/README.md`:

````markdown
# esp_prov

Provision ESP32 devices over Bluetooth LE with Espressif's Unified
Provisioning protocol. Security 0, 1 and 2 (SRP-6a + AES-GCM) are implemented
in pure Dart; no native Espressif SDK is involved.

- Scans for `PROV_` devices, connects, reads `proto-ver` and picks the
  security scheme the firmware declares.
- Wi-Fi scan and provisioning with typed progress states.
- Thread provisioning (`network_provisioning` firmware).
- Custom endpoints (`custom-data` in the ESP-IDF examples).
- Parses the provisioning QR payload printed by the firmware.

## Usage

```dart
import 'package:esp_prov/esp_prov.dart';

Future<void> provision() async {
  final prov = EspProvisioning();
  final device = await prov.scan(namePrefix: 'PROV_').first;
  final session = await device.connect(
    credentials: const ProvCredentials.security2(
      username: 'wifiprov',
      password: 'abcd1234',
    ),
  );
  try {
    final networks = await session.wifi.scan();
    await for (final state in session.wifi.provision(
      ssid: networks.first.ssid,
      passphrase: 'my-passphrase',
    )) {
      switch (state) {
        case WifiConnected(:final ip4):
          print('Device joined the network as $ip4');
        case WifiFailed(:final reason):
          print('Provisioning failed: ${reason.name}');
        case WifiApplying() || WifiConnecting() || WifiAttemptFailed():
          break;
      }
    }
  } finally {
    await session.close();
  }
}
```

From a QR code string:

```dart
final qr = ProvQrPayload.parse(qrString);
final device = await EspProvisioning().findDevice(qr.name);
final session = await device.connect(credentials: qr.credentials);
```

### Errors

All failures are subclasses of the sealed `ProvException`:
`PopMismatch` (wrong PoP or password), `SchemeMismatch` (credential kind does
not match the firmware), `MissingCredentials`, `DeviceDisconnected`,
`TransportException`, `UnknownEndpoint`, `UnsupportedCapability`,
`HandshakeFailed`, `CryptoException`, `ProvStatusException`. Wrong Wi-Fi
passphrase or unknown SSID are not exceptions: they arrive as
`WifiFailed(reason: WifiFailureReason.authError | networkNotFound)`.

## Platform setup

This package does not request runtime permissions. Request them before
scanning (for example with `UniversalBle.requestPermissions()` or
`permission_handler`).

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

**iOS and macOS** (`Info.plist`): `NSBluetoothAlwaysUsageDescription`.
**macOS** entitlements: `com.apple.security.device.bluetooth`.

**Web**: Web Bluetooth needs a user gesture to scan and only exposes
services listed in `UniversalBleScanner(webServiceUuids: ...)`. Some browsers
cannot read characteristic descriptors; the standard endpoints still work
through the UUID fallback, custom endpoints may not.

## Security 2 performance

The SRP-6a handshake does 3072-bit modular exponentiation. On native
platforms it runs on a background isolate; on the web it runs inline and
takes noticeably longer.
````

Create `packages/esp_prov_core/README.md`:

````markdown
# esp_prov_core

Pure-Dart client for Espressif Unified Provisioning (protocomm), with no
Flutter dependency. It runs on all six platforms and in plain Dart programs.

It provides:

- `EspSession`: reads `proto-ver`, chooses Security 0, 1 or 2 from the
  firmware, runs the handshake and encrypts every request.
- Security 1 (X25519, AES-256-CTR, proof of possession) and Security 2
  (SRP-6a 3072-bit SHA-512, AES-256-GCM), verified byte for byte against
  Espressif's `esp_prov` tool.
- `WifiProvisioner`, `ThreadProvisioner`, `ProvCtrl`, `CustomEndpoint`.
- `ProvQrPayload` for the QR JSON printed by the firmware.

You supply a `ProvTransport`. For Bluetooth LE use
[`esp_prov_ble_universal`](https://pub.dev/packages/esp_prov_ble_universal),
or the Flutter package [`esp_prov`](https://pub.dev/packages/esp_prov), which
wires everything together.

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';

Future<void> run(ProvTransport transport) async {
  final session = await EspSession.open(
    transport,
    credentials: const ProvCredentials.pop('abcd1234'),
  );
  final reply = await session.custom('custom-data').send(
    Uint8List.fromList('hello'.codeUnits),
  );
  print(String.fromCharCodes(reply));
  await session.close();
}
```

A transport implements four members:

```dart
abstract interface class ProvTransport {
  Set<String> get endpoints;
  Future<Uint8List> send(String endpoint, Uint8List request);
  Stream<void> get onDisconnected;
  Future<void> disconnect();
}
```

`send` is one protocomm transaction (for BLE: write with response, then read
the same characteristic). Implementations must serialise concurrent calls.
````

Create `packages/esp_prov_ble_universal/README.md`:

````markdown
# esp_prov_ble_universal

Bluetooth LE transport for
[`esp_prov_core`](https://pub.dev/packages/esp_prov_core), built on
[`universal_ble`](https://pub.dev/packages/universal_ble).

- `UniversalBleScanner`: scans by advertised name prefix
  (case-insensitive), one result per device, primary service UUID from the
  advertisement.
- `UniversalBleTransport`: connects, requests MTU 512 on Android, finds the
  provisioning service, maps endpoint names from the 0x2901 user
  description descriptors (falling back to the ESP-IDF UUID table
  `ff4f`-`ff53`), and runs each request as write-with-response then read.
  Requests are serialised; a dropped link surfaces as `DeviceDisconnected`.

```dart
const scanner = UniversalBleScanner();
final device = await scanner.scan(namePrefix: 'PROV_').first;
final transport = await device.connect();
final session = await EspSession.open(
  transport,
  credentials: const ProvCredentials.none(),
);
```

Most apps should use [`esp_prov`](https://pub.dev/packages/esp_prov)
instead. Permissions and platform setup are described there; this package
does not request runtime permissions.
````

Create `packages/esp_prov_core/example/esp_prov_core_example.dart`:

```dart
// Prints the credentials a provisioning QR code implies, then shows how a
// session is opened once a transport (e.g. esp_prov_ble_universal) exists.
// ignore_for_file: avoid_print
import 'package:esp_prov_core/esp_prov_core.dart';

Future<void> provision(ProvTransport transport) async {
  final session = await EspSession.open(
    transport,
    credentials: const ProvCredentials.security2(
      username: 'wifiprov',
      password: 'abcd1234',
    ),
  );
  try {
    final networks = await session.wifi.scan();
    print(networks.map((n) => '${n.ssid} ${n.rssi} dBm').join('\n'));
    await session.wifi
        .provision(ssid: 'MyNetwork', passphrase: 'secret123')
        .forEach(print);
  } finally {
    await session.close();
  }
}

void main() {
  final qr = ProvQrPayload.parse(
    '{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov",'
    '"pop":"abcd1234","transport":"ble"}',
  );
  print('Device ${qr.name} needs ${qr.credentials.kind} credentials.');
}
```

- [ ] **Step 2: Run the core example**

Run: `(cd packages/esp_prov_core && fvm dart run example/esp_prov_core_example.dart)`

Expected: `Device PROV_1A2B3C needs Security 2 username/password credentials.`

- [ ] **Step 3: Check the API docs build without warnings**

Run (from the repository root):

```bash
for pkg in packages/esp_prov_core packages/esp_prov_ble_universal packages/esp_prov; do
  (cd "$pkg" && fvm dart doc --dry-run) || exit 1
done
```

Expected: `Found 0 warnings and 0 errors.` three times.

- [ ] **Step 4: Run the full check**

Run: `tool/check.sh`

Expected: `All checks passed.`

- [ ] **Step 5: Commit**

```bash
git add \
  README.md \
  packages/esp_prov/README.md \
  packages/esp_prov_core/README.md \
  packages/esp_prov_ble_universal/README.md \
  packages/esp_prov_core/example/esp_prov_core_example.dart
git commit -m "docs: READMEs and core example" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
