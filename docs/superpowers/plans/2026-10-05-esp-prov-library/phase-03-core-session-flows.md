> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 3: Core: session, flows, QR parser

**Goal:** `EspSession` with scheme selection from `proto-ver`, Wi-Fi/Thread/control/custom flows with typed states, and the QR payload parser, all tested against a firmware simulator.

**Depends on:** Phase 2 (all tasks).

Flows and the session import each other (`EspSession.wifi` returns a
`WifiProvisioner` that calls `EspSession.request`). That is fine in Dart and
keeps the public API as in spec 3.4. Flow tests use Security 0 devices so
they exercise the protocol, not the ciphers; the session tests cover all
three schemes end to end against `FakeDevice`.

---

### Task 3.1: ProvCredentials and DeviceInfo (proto-ver parsing)

**Files:**
- Create: `packages/esp_prov_core/lib/src/session/prov_credentials.dart`
- Create: `packages/esp_prov_core/lib/src/session/device_info.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/session/device_info_test.dart`
- Test: `packages/esp_prov_core/test/session/prov_credentials_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: Exported:
- `sealed class ProvCredentials { const factory none() = ProvNoCredentials; const factory pop(String pop) = ProvPopCredentials; const factory security2({required String username, required String password}) = ProvSecurity2Credentials; String get kind; }`
  with `ProvNoCredentials`, `ProvPopCredentials { final String pop; }`, `ProvSecurity2Credentials { final String username; final String password; }`; `toString()` never prints secrets.
- `final class DeviceInfo { const new({required String version, required int secVer, required int secPatchVer, required Set<String> capabilities, Map<String, Object?> appInfo = const {}}); factory parse(String response); bool hasCapability(String capability); }`
  (spec 3.4's comment calls the version field `ver`; it is `version` here).

`proto-ver` rules (facts doc + esp_prov `esp_prov.py`): the response is
JSON `{"prov":{"ver","sec_ver","sec_patch_ver","cap":[...]}, "<app>":{...}}`.
A missing `sec_ver` means 0 if `cap` contains `no_sec`, else 1. That is
esp_prov's rule and a superset of the spec's "missing -> 1". A missing
`sec_patch_ver` means 0. Very old firmware answers a plain version string
(e.g. `V0.1`), treated as Security 1 with no capabilities. Trailing NUL
bytes are stripped and numeric strings are accepted.

- [ ] **Step 1: Write the failing tests**

Create `packages/esp_prov_core/test/session/device_info_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('legacy v1.1 JSON without sec_ver means Security 1', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","cap":["wifi_scan"]}}',
    );
    expect(info.version, 'v1.1');
    expect(info.secVer, 1);
    expect(info.secPatchVer, 0);
    expect(info.capabilities, {'wifi_scan'});
  });

  test('no_sec without sec_ver means Security 0', () {
    expect(
      DeviceInfo.parse('{"prov":{"ver":"v1.1","cap":["no_sec"]}}').secVer,
      0,
    );
  });

  test('netprov-v1.2 with Thread capabilities', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"netprov-v1.2","sec_ver":2,"sec_patch_ver":1,'
      '"cap":["thread_scan","thread_prov"]}}',
    );
    expect(info.secVer, 2);
    expect(info.secPatchVer, 1);
    expect(info.hasCapability('thread_prov'), isTrue);
    expect(info.hasCapability('wifi_prov'), isFalse);
  });

  test('missing sec_patch_ver is 0', () {
    expect(
      DeviceInfo.parse('{"prov":{"ver":"v1.1","sec_ver":2}}').secPatchVer,
      0,
    );
  });

  test('extra application keys land in appInfo', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","sec_ver":2},"my_app":{"fw":"1.2.3"}}',
    );
    expect(info.appInfo, {
      'my_app': {'fw': '1.2.3'},
    });
  });

  test('a plain version string is legacy Security 1', () {
    final info = DeviceInfo.parse('V0.1');
    expect(info.version, 'V0.1');
    expect(info.secVer, 1);
    expect(info.capabilities, isEmpty);
  });

  test('trailing NUL bytes and numeric strings are tolerated', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","sec_ver":"2","cap":[]}}\u0000',
    );
    expect(info.secVer, 2);
  });
}
```

Create `packages/esp_prov_core/test/session/prov_credentials_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('factories build the sealed subtypes', () {
    expect(const ProvCredentials.none(), isA<ProvNoCredentials>());
    expect(
      const ProvCredentials.pop('abcd1234'),
      isA<ProvPopCredentials>().having((c) => c.pop, 'pop', 'abcd1234'),
    );
    expect(
      const ProvCredentials.security2(username: 'u', password: 'p'),
      isA<ProvSecurity2Credentials>()
          .having((c) => c.username, 'username', 'u')
          .having((c) => c.password, 'password', 'p'),
    );
  });

  test('credentials toString never prints secrets', () {
    expect(
      const ProvCredentials.security2(
        username: 'u',
        password: 'hunter2',
      ).toString(),
      isNot(contains('hunter2')),
    );
    expect(
      const ProvCredentials.pop('hunter2').toString(),
      isNot(contains('hunter2')),
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/device_info_test.dart test/session/prov_credentials_test.dart)`

Expected: FAIL: `Error: Undefined name 'DeviceInfo'.`

- [ ] **Step 3: Implement**

Create `packages/esp_prov_core/lib/src/session/prov_credentials.dart`:

```dart
/// Credentials for the security scheme the device declares in `proto-ver`.
///
/// The library picks the scheme from the firmware; these only carry the
/// secrets. A kind that does not fit the firmware makes `EspSession.open`
/// throw `SchemeMismatch`.
sealed class ProvCredentials {
  const new();

  /// No credentials: Security 0, or Security 1 firmware with `no_pop`.
  const factory none() = ProvNoCredentials;

  /// Security 1 proof of possession.
  const factory pop(String pop) = ProvPopCredentials;

  /// Security 2 SRP-6a username and password.
  const factory security2({
    required String username,
    required String password,
  }) = ProvSecurity2Credentials;

  /// Short description used in error messages, e.g. `'proof of possession'`.
  String get kind;
}

/// See [ProvCredentials.none].
final class ProvNoCredentials extends ProvCredentials {
  /// Creates empty credentials.
  const new();

  @override
  String get kind => 'no';
}

/// See [ProvCredentials.pop].
final class ProvPopCredentials extends ProvCredentials {
  /// Creates proof-of-possession credentials.
  const new(this.pop);

  /// The proof of possession string printed by the firmware.
  final String pop;

  @override
  String get kind => 'proof of possession';

  @override
  String toString() => 'ProvCredentials.pop(<redacted>)';
}

/// See [ProvCredentials.security2].
final class ProvSecurity2Credentials extends ProvCredentials {
  /// Creates Security 2 credentials.
  const new({required this.username, required this.password});

  /// SRP-6a username (the firmware example uses `wifiprov`).
  final String username;

  /// SRP-6a password.
  final String password;

  @override
  String get kind => 'Security 2 username/password';

  @override
  String toString() =>
      'ProvCredentials.security2(username: $username, password: <redacted>)';
}
```

Create `packages/esp_prov_core/lib/src/session/device_info.dart`:

```dart
import 'dart:convert';

/// What the device reports on the `proto-ver` endpoint.
final class DeviceInfo {
  /// Creates device info. Use [DeviceInfo.parse] for device responses.
  const new({
    required this.version,
    required this.secVer,
    required this.secPatchVer,
    required this.capabilities,
    this.appInfo = const {},
  });

  /// Parses a `proto-ver` response.
  ///
  /// Accepts the JSON form
  /// `{"prov":{"ver":..,"sec_ver":..,"sec_patch_ver":..,"cap":[..]},..}` and
  /// the plain version string of very old firmware. Missing `sec_ver` means
  /// Security 0 when the `no_sec` capability is present, else Security 1
  /// (esp_prov's rule). Missing `sec_patch_ver` means 0. Every top-level key
  /// other than `prov` lands in [appInfo].
  factory parse(String response) {
    final text = response.replaceAll('\u0000', '').trim();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      decoded = null;
    }
    if (decoded is! Map<String, Object?>) {
      return DeviceInfo(
        version: text,
        secVer: 1,
        secPatchVer: 0,
        capabilities: const {},
      );
    }
    final prov = decoded['prov'];
    final provMap = prov is Map<String, Object?> ? prov : <String, Object?>{};
    final rawCaps = provMap['cap'];
    final capabilities = <String>{
      if (rawCaps is List<Object?>) ...rawCaps.whereType<String>(),
    };
    return DeviceInfo(
      version: provMap['ver'] is String ? provMap['ver']! as String : '',
      secVer:
          _asInt(provMap['sec_ver']) ??
          (capabilities.contains('no_sec') ? 0 : 1),
      secPatchVer: _asInt(provMap['sec_patch_ver']) ?? 0,
      capabilities: capabilities,
      appInfo: {
        for (final entry in decoded.entries)
          if (entry.key != 'prov') entry.key: entry.value,
      },
    );
  }

  /// Provisioning protocol version, e.g. `v1.1` or `netprov-v1.2`.
  final String version;

  /// Security scheme version (0, 1 or 2).
  final int secVer;

  /// Security patch level. 1 means Security 2 increments its GCM nonce.
  final int secPatchVer;

  /// Capability strings, e.g. `wifi_scan`, `no_pop`, `thread_prov`.
  final Set<String> capabilities;

  /// Application-defined keys reported next to `prov`.
  final Map<String, Object?> appInfo;

  /// Whether the device lists [capability].
  bool hasCapability(String capability) => capabilities.contains(capability);

  static int? _asInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };

  @override
  String toString() =>
      'DeviceInfo(version: $version, secVer: $secVer, '
      'secPatchVer: $secPatchVer, capabilities: $capabilities)';
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
export 'src/session/device_info.dart';
export 'src/session/prov_credentials.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/device_info_test.dart test/session/prov_credentials_test.dart)`

Expected: `+9: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/session/device_info_test.dart \
  packages/esp_prov_core/test/session/prov_credentials_test.dart \
  packages/esp_prov_core/lib/src/session/prov_credentials.dart \
  packages/esp_prov_core/lib/src/session/device_info.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): credentials and proto-ver DeviceInfo" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 3.2: Security scheme selection from the firmware

**Files:**
- Create: `packages/esp_prov_core/lib/src/session/scheme_selector.dart`
- Test: `packages/esp_prov_core/test/session/scheme_selector_test.dart`

**Interfaces:**
- Consumes: `Security0/1/2` (Phase 2), `DeviceInfo`, `ProvCredentials` (3.1), `SchemeMismatch`, `MissingCredentials`, `UnsupportedCapability` (2.1).
- Produces: `package:esp_prov_core/src/session/scheme_selector.dart`: `SecurityScheme selectScheme(DeviceInfo info, ProvCredentials? credentials)` (not exported).

The firmware decides the scheme; the caller only supplies secrets (spec
3.3). Mapping:

| `sec_ver` | credentials | result |
|---|---|---|
| 0 | none/null | `Security0()` |
| 0 | pop or security2 | `SchemeMismatch(expected: 0)` |
| 1 | any except security2, and `no_pop` in caps | `Security1()` (PoP ignored, as esp_prov does) |
| 1 | non-empty pop | `Security1(pop: pop)` |
| 1 | none/null/empty pop, no `no_pop` | `MissingCredentials` |
| 1 | security2 | `SchemeMismatch(expected: 1)` |
| 2 | security2 with non-empty username and password | `Security2(..., patchVersion: info.secPatchVer)` |
| 2 | pop | `SchemeMismatch(expected: 2)` |
| 2 | none/null/empty fields | `MissingCredentials` |
| other | any | `UnsupportedCapability('security scheme N')` |

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_core/test/session/scheme_selector_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:test/test.dart';

DeviceInfo _info(int secVer, {Set<String> caps = const {}}) => DeviceInfo(
  version: 'v1.1',
  secVer: secVer,
  secPatchVer: 1,
  capabilities: caps,
);

void main() {
  test('Security 0 with no credentials', () {
    expect(selectScheme(_info(0), null), isA<Security0>());
  });

  test('Security 0 with a PoP is a SchemeMismatch', () {
    expect(
      () => selectScheme(_info(0), const ProvCredentials.pop('x')),
      throwsA(isA<SchemeMismatch>()),
    );
  });

  test('Security 1 with a PoP', () {
    expect(
      selectScheme(_info(1), const ProvCredentials.pop('abcd1234')),
      isA<Security1>(),
    );
  });

  test('Security 1 with no_pop needs no credentials and ignores a PoP', () {
    final info = _info(1, caps: {'no_pop'});
    expect(selectScheme(info, null), isA<Security1>());
    expect(
      selectScheme(info, const ProvCredentials.pop('ignored')),
      isA<Security1>(),
    );
  });

  test('Security 1 without no_pop and without a PoP', () {
    expect(
      () => selectScheme(_info(1), const ProvCredentials.none()),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('Security 2 with username/password', () {
    final scheme = selectScheme(
      _info(2),
      const ProvCredentials.security2(username: 'u', password: 'p'),
    );
    expect(scheme, isA<Security2>());
  });

  test('Security 2 with a PoP names what the device wants', () {
    expect(
      () => selectScheme(_info(2), const ProvCredentials.pop('abcd1234')),
      throwsA(
        isA<SchemeMismatch>()
            .having((e) => e.expected, 'expected', 2)
            .having(
              (e) => e.message,
              'message',
              contains('ProvCredentials.security2'),
            ),
      ),
    );
  });

  test('Security 2 with an empty password is MissingCredentials', () {
    expect(
      () => selectScheme(
        _info(2),
        const ProvCredentials.security2(username: 'u', password: ''),
      ),
      throwsA(isA<MissingCredentials>()),
    );
  });

  test('unknown scheme', () {
    expect(
      () => selectScheme(_info(3), null),
      throwsA(isA<UnsupportedCapability>()),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/scheme_selector_test.dart)`

Expected: FAIL: `Error when reading 'lib/src/session/scheme_selector.dart'`.

- [ ] **Step 3: Implement**

Create `packages/esp_prov_core/lib/src/session/scheme_selector.dart`:

```dart
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';

/// Chooses the security scheme the firmware declared and checks that
/// [credentials] fit it.
SecurityScheme selectScheme(DeviceInfo info, ProvCredentials? credentials) {
  final provided = credentials ?? const ProvCredentials.none();
  final noPop = info.hasCapability('no_pop');
  return switch (info.secVer) {
    0 => switch (provided) {
      ProvNoCredentials() => Security0(),
      _ => throw SchemeMismatch(expected: 0, provided: provided.kind),
    },
    1 => switch (provided) {
      ProvSecurity2Credentials() => throw SchemeMismatch(
        expected: 1,
        provided: provided.kind,
      ),
      _ when noPop => Security1(),
      ProvPopCredentials(:final pop) when pop.isNotEmpty => Security1(pop: pop),
      _ => throw const MissingCredentials(
        'The device uses Security 1 with a proof of possession. '
        'Pass ProvCredentials.pop(...).',
      ),
    },
    2 => switch (provided) {
      ProvSecurity2Credentials(:final username, :final password)
          when username.isNotEmpty && password.isNotEmpty =>
        Security2(
          username: username,
          password: password,
          patchVersion: info.secPatchVer,
        ),
      ProvPopCredentials() => throw SchemeMismatch(
        expected: 2,
        provided: provided.kind,
      ),
      _ => throw const MissingCredentials(
        'The device uses Security 2. Pass '
        'ProvCredentials.security2(username: ..., password: ...).',
      ),
    },
    _ => throw UnsupportedCapability('security scheme ${info.secVer}'),
  };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/scheme_selector_test.dart)`

Expected: `+9: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/session/scheme_selector_test.dart \
  packages/esp_prov_core/lib/src/session/scheme_selector.dart
git commit -m "feat(core): select the security scheme from proto-ver" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 3.3: EspSession, custom endpoints and prov-ctrl

**Files:**
- Create: `packages/esp_prov_core/lib/src/flows/flow_support.dart`
- Create: `packages/esp_prov_core/lib/src/flows/custom_endpoint.dart`
- Create: `packages/esp_prov_core/lib/src/flows/prov_ctrl.dart`
- Create: `packages/esp_prov_core/lib/src/session/esp_session.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/support/fake_device.dart`
- Test: `packages/esp_prov_core/test/session/esp_session_test.dart`
- Test: `packages/esp_prov_core/test/flows/prov_ctrl_test.dart`

**Interfaces:**
- Consumes: everything above; `SerialQueue` (2.1).
- Produces: Exported:
- `final class EspSession { static Future<EspSession> open(ProvTransport transport, {ProvCredentials? credentials}); final DeviceInfo info; int get securityVersion; Set<String> get endpoints; Future<Uint8List> request(String endpoint, Uint8List body); ProvCtrl get ctrl; CustomEndpoint custom(String name); Stream<void> get onDisconnected; Future<void> close(); }`
  (`wifi`/`thread` getters are added in 3.4/3.5).
- `final class CustomEndpoint { new(EspSession session, String name); final String name; bool get isAvailable; Future<Uint8List> send(Uint8List data); }`
- `final class ProvCtrl { new(EspSession session); Future<void> resetWifi(); Future<void> reprovisionWifi(); Future<void> resetThread(); Future<void> reprovisionThread(); }`
- Internal `src/flows/flow_support.dart`: `void checkStatus(pb.Status status, String operation)`, `Future<void> ctrlRequest(EspSession session, pb.NetworkCtrlPayload command, pb.NetworkCtrlMsgType expected)`.
- Test helper `test/support/fake_device.dart`: `typedef EndpointHandler = FutureOr<List<int>> Function(Uint8List request);`
  `final class FakeDevice implements ProvTransport { new({required String protoVer, String pop = '', String username = 'wifiprov', String password = 'abcd1234', Set<String> extraEndpoints = const {}, Map<String, EndpointHandler>? handlers}); final List<(String, Uint8List)> plainRequests; int sessionMessages; int disconnectCalls; bool get isConnected; void dropLink(); }`
  and `String protoVerJson({required int secVer, int? secPatchVer, List<String> caps, String ver})`.

`EspSession.open`: write `---` to `proto-ver` (esp_prov does the same),
parse with `DeviceInfo.parse`, `selectScheme` (fails before any handshake
traffic), require `prov-session`, run the handshake. `request` runs
through one `SerialQueue`, because Security 1 and 2 ciphers are stateful
and order-dependent. It checks the endpoint before encrypting, so no
keystream or nonce is spent on an unknown endpoint. After any failed
transaction the session is poisoned: the device and the client can no
longer agree on cipher state, so later requests throw `TransportException`
("Reconnect") instead of returning garbage.

`FakeDevice` is a firmware simulator, not a mock. It implements the device
side of Security 0/1/2 (X25519 + `AesCtrStream`; SRP server math with
`Srp6aClient.k/n/g` + `AesGcmCounter`). Like `protocomm_ble`, it drops the
link and throws `DeviceDisconnected` when the client proof is wrong.
Application endpoints are scripted with `handlers` that see decrypted
requests.

- [ ] **Step 1: Write the firmware simulator and the failing tests**

Create `packages/esp_prov_core/test/support/fake_device.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256, sha512;
import 'package:cryptography_plus/cryptography_plus.dart';
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/crypto/aes_ctr_stream.dart';
import 'package:esp_prov_core/src/crypto/aes_gcm_counter.dart';
import 'package:esp_prov_core/src/crypto/bytes.dart';
import 'package:esp_prov_core/src/crypto/srp6a.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec0.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec1.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/sec2.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/session.pb.dart' as pb;

/// Handles one decrypted request on an application endpoint and returns the
/// plaintext response.
typedef EndpointHandler = FutureOr<List<int>> Function(Uint8List request);

/// A simulated provisioning device implementing the device side of
/// Security 0, 1 and 2 like ESP-IDF protocomm. When the client proof is
/// wrong it drops the link, as the firmware does.
final class FakeDevice implements ProvTransport {
  /// Creates a device that reports [protoVer] on `proto-ver`.
  new({
    required this.protoVer,
    this.pop = '',
    this.username = 'wifiprov',
    this.password = 'abcd1234',
    Set<String> extraEndpoints = const {},
    Map<String, EndpointHandler>? handlers,
  }) : endpoints = {
         ProvEndpoints.protoVer,
         ProvEndpoints.session,
         ProvEndpoints.config,
         ProvEndpoints.scan,
         ProvEndpoints.ctrl,
         ...extraEndpoints,
       },
       handlers = handlers ?? {};

  /// JSON (or legacy plain string) returned by `proto-ver`.
  final String protoVer;

  /// Security 1 proof of possession the device expects.
  final String pop;

  /// Security 2 username the device's verifier was made for.
  final String username;

  /// Security 2 password the device's verifier was made for.
  final String password;

  /// Handlers for encrypted endpoints, keyed by endpoint name.
  final Map<String, EndpointHandler> handlers;

  @override
  final Set<String> endpoints;

  /// Decrypted application requests in arrival order.
  final List<(String, Uint8List)> plainRequests = [];

  /// Number of `prov-session` messages received.
  int sessionMessages = 0;

  /// Number of [disconnect] calls.
  int disconnectCalls = 0;

  final _random = Random(7);
  final _disconnects = StreamController<void>.broadcast();
  bool _connected = true;

  late final DeviceInfo _info = DeviceInfo.parse(protoVer);
  late AesCtrStream _ctr;
  late AesGcmCounter _gcm;
  late Uint8List _devicePublic;
  late Uint8List _clientPublic;
  late BigInt _b;
  late BigInt _v;
  late Uint8List _salt;
  late Uint8List _bBytes;
  late String _clientUsername;

  /// Whether the link is up.
  bool get isConnected => _connected;

  @override
  Stream<void> get onDisconnected => _disconnects.stream;

  /// Simulates the link dropping (firmware auto-stop, out of range, ...).
  void dropLink() {
    if (!_connected) return;
    _connected = false;
    _disconnects.add(null);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    dropLink();
  }

  @override
  Future<Uint8List> send(String endpoint, Uint8List request) async {
    if (!_connected) throw const DeviceDisconnected();
    if (endpoint == ProvEndpoints.protoVer) {
      return Uint8List.fromList(utf8.encode(protoVer));
    }
    if (endpoint == ProvEndpoints.session) {
      sessionMessages++;
      final response = await _session(pb.SessionData.fromBuffer(request));
      return response.writeToBuffer();
    }
    final plain = await _decrypt(request);
    plainRequests.add((endpoint, plain));
    final handler = handlers[endpoint];
    if (handler == null) {
      throw TransportException('No handler for $endpoint');
    }
    final response = await handler(plain);
    if (!_connected) throw const DeviceDisconnected();
    return await _encrypt(Uint8List.fromList(response));
  }

  Future<Uint8List> _decrypt(Uint8List data) => switch (_info.secVer) {
    1 => _ctr.apply(data),
    2 => _gcm.decrypt(data),
    _ => Future.value(data),
  };

  Future<Uint8List> _encrypt(Uint8List data) => switch (_info.secVer) {
    1 => _ctr.apply(data),
    2 => _gcm.encrypt(data),
    _ => Future.value(data),
  };

  Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  Never _rejectProof() {
    // protocomm_ble: "Invalid content received, killing connection".
    dropLink();
    throw const DeviceDisconnected();
  }

  Future<pb.SessionData> _session(pb.SessionData req) async {
    switch (req.whichProto()) {
      case pb.SessionData_Proto.sec0:
        return pb.SessionData(
          secVer: pb.SecSchemeVersion.SecScheme0,
          sec0: pb.Sec0Payload(
            msg: pb.Sec0MsgType.S0_Session_Response,
            sr: pb.S0SessionResp(status: pb.Status.Success),
          ),
        );
      case pb.SessionData_Proto.sec1:
        return await _sec1(req.sec1);
      case pb.SessionData_Proto.sec2:
        return _sec2(req.sec2);
      case pb.SessionData_Proto.notSet:
        throw const TransportException('empty SessionData');
    }
  }

  Future<pb.SessionData> _sec1(pb.Sec1Payload payload) async {
    if (payload.hasSc0()) {
      final keyPair = await X25519().newKeyPair();
      _devicePublic = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      _clientPublic = Uint8List.fromList(payload.sc0.clientPubkey);
      final shared = await X25519().sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(
          _clientPublic,
          type: KeyPairType.x25519,
        ),
      );
      var key = Uint8List.fromList(await shared.extractBytes());
      if (pop.isNotEmpty) {
        key = xorBytes(key, sha256.convert(utf8.encode(pop)).bytes);
      }
      final random = _randomBytes(16);
      _ctr = AesCtrStream(key: key, iv: random);
      return pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Response0,
          sr0: pb.SessionResp0(
            status: pb.Status.Success,
            devicePubkey: _devicePublic,
            deviceRandom: random,
          ),
        ),
      );
    }
    final check = await _ctr.apply(payload.sc1.clientVerifyData);
    if (!constantTimeEquals(check, _devicePublic)) _rejectProof();
    final verify = await _ctr.apply(_clientPublic);
    return pb.SessionData(
      secVer: pb.SecSchemeVersion.SecScheme1,
      sec1: pb.Sec1Payload(
        msg: pb.Sec1MsgType.Session_Response1,
        sr1: pb.SessionResp1(
          status: pb.Status.Success,
          deviceVerifyData: verify,
        ),
      ),
    );
  }

  Uint8List _h(List<List<int>> parts) =>
      Uint8List.fromList(sha512.convert(concatBytes(parts)).bytes);

  pb.SessionData _sec2(pb.Sec2Payload payload) {
    final n = Srp6aClient.n;
    final g = Srp6aClient.g;
    const len = Srp6aClient.nLength;
    if (payload.hasSc0()) {
      _clientUsername = utf8.decode(payload.sc0.clientUsername);
      _clientPublic = Uint8List.fromList(payload.sc0.clientPubkey);
      final salt = _randomBytes(16);
      final inner = _h([utf8.encode('$username:$password')]);
      final x = bytesToBigInt(_h([salt, inner]));
      final v = g.modPow(x, n);
      final b = bytesToBigInt(_randomBytes(32));
      final bigB = (Srp6aClient.k * v + g.modPow(b, n)) % n;
      _salt = salt;
      _v = v;
      _b = b;
      _bBytes = bigIntToBytes(bigB);
      return pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme2,
        sec2: pb.Sec2Payload(
          msg: pb.Sec2MsgType.S2Session_Response0,
          sr0: pb.S2SessionResp0(
            status: pb.Status.Success,
            devicePubkey: _bBytes,
            deviceSalt: salt,
          ),
        ),
      );
    }
    final aBytes = _clientPublic;
    final bigA = bytesToBigInt(aBytes);
    final u = bytesToBigInt(
      _h([
        bigIntToBytes(bigA, length: len),
        bigIntToBytes(bytesToBigInt(_bBytes), length: len),
      ]),
    );
    final s = (bigA * _v.modPow(u, n) % n).modPow(_b, n);
    final key = _h([bigIntToBytes(s)]);
    final hN = _h([bigIntToBytes(n, length: len)]);
    final hG = _h([bigIntToBytes(g, length: len)]);
    final m1 = _h([
      xorBytes(hN, hG),
      _h([utf8.encode(_clientUsername)]),
      _salt,
      aBytes,
      _bBytes,
      key,
    ]);
    if (!constantTimeEquals(m1, payload.sc1.clientProof)) _rejectProof();
    final m2 = _h([aBytes, m1, key]);
    final nonce = Uint8List.fromList([..._randomBytes(8), 0, 0, 0, 1]);
    _gcm = AesGcmCounter(
      key: key.sublist(0, 32),
      nonce: nonce,
      incrementNonce: _info.secPatchVer >= 1,
    );
    return pb.SessionData(
      secVer: pb.SecSchemeVersion.SecScheme2,
      sec2: pb.Sec2Payload(
        msg: pb.Sec2MsgType.S2Session_Response1,
        sr1: pb.S2SessionResp1(
          status: pb.Status.Success,
          deviceProof: m2,
          deviceNonce: nonce,
        ),
      ),
    );
  }
}

/// `proto-ver` JSON for a typical device.
String protoVerJson({
  required int secVer,
  int? secPatchVer,
  List<String> caps = const ['wifi_scan', 'wifi_prov'],
  String ver = 'v1.1',
}) => jsonEncode({
  'prov': {
    'ver': ver,
    'sec_ver': secVer,
    'sec_patch_ver': ?secPatchVer,
    'cap': caps,
  },
});
```

Create `packages/esp_prov_core/test/session/esp_session_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

import '../support/fake_device.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

FakeDevice _echoDevice(String protoVer, {String pop = ''}) => FakeDevice(
  protoVer: protoVer,
  pop: pop,
  extraEndpoints: {'custom-data'},
  handlers: {
    'custom-data': (request) => [...request.reversed],
  },
);

void main() {
  test('Security 0 session round-trips a custom endpoint', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    expect(session.securityVersion, 0);
    expect(await session.custom('custom-data').send(_bytes('abc')), [
      ...utf8.encode('cba'),
    ]);
  });

  test('Security 1 session keeps one keystream across messages', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'abcd1234');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('abcd1234'),
    );
    final endpoint = session.custom('custom-data');
    for (final text in ['a', 'hello world 1234', 'x' * 40]) {
      expect(
        utf8.decode(await endpoint.send(_bytes(text))),
        [...text.split('').reversed].join(),
      );
    }
  });

  test('Security 1 with a wrong PoP throws PopMismatch', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'abcd1234');
    await expectLater(
      EspSession.open(device, credentials: const ProvCredentials.pop('nope')),
      throwsA(isA<PopMismatch>()),
    );
    expect(device.isConnected, isFalse);
  });

  for (final patch in [0, 1]) {
    test('Security 2 session (sec_patch_ver $patch)', () async {
      final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: patch));
      final session = await EspSession.open(
        device,
        credentials: const ProvCredentials.security2(
          username: 'wifiprov',
          password: 'abcd1234',
        ),
      );
      final endpoint = session.custom('custom-data');
      expect(await endpoint.send(_bytes('ab')), utf8.encode('ba'));
      expect(await endpoint.send(_bytes('xyz')), utf8.encode('zyx'));
    });
  }

  test('Security 2 with a wrong password throws PopMismatch', () async {
    final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: 1));
    await expectLater(
      EspSession.open(
        device,
        credentials: const ProvCredentials.security2(
          username: 'wifiprov',
          password: 'wrong',
        ),
      ),
      throwsA(isA<PopMismatch>()),
    );
  });

  test('wrong credential kind fails before any handshake message', () async {
    final device = _echoDevice(protoVerJson(secVer: 2, secPatchVer: 1));
    await expectLater(
      EspSession.open(device, credentials: const ProvCredentials.pop('x')),
      throwsA(isA<SchemeMismatch>()),
    );
    expect(device.sessionMessages, 0);
  });

  test('legacy plain-text proto-ver selects Security 1', () async {
    final device = _echoDevice('v1.1', pop: 'abcd1234');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('abcd1234'),
    );
    expect(session.securityVersion, 1);
    expect(session.info.version, 'v1.1');
  });

  test('concurrent requests are serialised in call order', () async {
    final device = _echoDevice(protoVerJson(secVer: 1), pop: 'p');
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('p'),
    );
    final endpoint = session.custom('custom-data');
    final results = await Future.wait([
      for (var i = 0; i < 5; i++) endpoint.send(_bytes('message $i')),
    ]);
    for (var i = 0; i < 5; i++) {
      expect(
        utf8.decode(results[i]),
        [...'message $i'.split('').reversed].join(),
      );
    }
    expect(
      [for (final (_, body) in device.plainRequests) utf8.decode(body)],
      [for (var i = 0; i < 5; i++) 'message $i'],
    );
  });

  test('after a failed request the session refuses further requests', () async {
    var calls = 0;
    final device = FakeDevice(
      protoVer: protoVerJson(secVer: 1),
      pop: 'p',
      extraEndpoints: {'custom-data'},
      handlers: {
        'custom-data': (request) {
          calls++;
          if (calls == 1) throw const TransportException('GATT timeout');
          return request;
        },
      },
    );
    final session = await EspSession.open(
      device,
      credentials: const ProvCredentials.pop('p'),
    );
    final endpoint = session.custom('custom-data');
    await expectLater(
      endpoint.send(_bytes('a')),
      throwsA(isA<TransportException>()),
    );
    await expectLater(
      endpoint.send(_bytes('b')),
      throwsA(
        isA<TransportException>().having(
          (e) => e.message,
          'message',
          contains('Reconnect'),
        ),
      ),
    );
    expect(calls, 1);
  });

  test('unknown endpoint throws UnknownEndpoint without sending', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    expect(session.custom('nope').isAvailable, isFalse);
    await expectLater(
      session.custom('nope').send(_bytes('x')),
      throwsA(isA<UnknownEndpoint>()),
    );
    expect(device.plainRequests, isEmpty);
  });

  test('close is idempotent and safe after the device dropped', () async {
    final device = _echoDevice(protoVerJson(secVer: 0, caps: ['no_sec']));
    final session = await EspSession.open(device);
    device.dropLink();
    await session.close();
    await session.close();
    expect(device.disconnectCalls, 1);
    await expectLater(
      session.custom('custom-data').send(_bytes('x')),
      throwsA(isA<DeviceDisconnected>()),
    );
  });
}
```

Create `packages/esp_prov_core/test/flows/prov_ctrl_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';

EndpointHandler _ctrl(pb.Status status, List<pb.NetworkCtrlMsgType> seen) =>
    (request) {
      final cmd = pb.NetworkCtrlPayload.fromBuffer(request);
      seen.add(cmd.msg);
      return pb.NetworkCtrlPayload(
        msg: pb.NetworkCtrlMsgType.valueOf(cmd.msg.value + 1),
        status: status,
      ).writeToBuffer();
    };

void main() {
  test('each command sends its message type', () async {
    final seen = <pb.NetworkCtrlMsgType>[];
    final session = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec']),
        handlers: {'prov-ctrl': _ctrl(pb.Status.Success, seen)},
      ),
    );
    await session.ctrl.resetWifi();
    await session.ctrl.reprovisionWifi();
    await session.ctrl.resetThread();
    await session.ctrl.reprovisionThread();
    expect(seen, [
      pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReset,
      pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReprov,
      pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReset,
      pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReprov,
    ]);
  });

  test('a failure status throws ProvStatusException', () async {
    final session = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec']),
        handlers: {'prov-ctrl': _ctrl(pb.Status.InternalError, [])},
      ),
    );
    await expectLater(
      session.ctrl.resetWifi(),
      throwsA(
        isA<ProvStatusException>().having(
          (e) => e.status,
          'status',
          ProvStatus.internalError,
        ),
      ),
    );
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/esp_session_test.dart test/flows/prov_ctrl_test.dart)`

Expected: FAIL: `Error: Undefined name 'EspSession'.`

- [ ] **Step 3: Implement the session, custom endpoint and control flows**

Create `packages/esp_prov_core/lib/src/flows/flow_support.dart`:

```dart
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

/// Throws [ProvStatusException] unless [status] is `Success`.
void checkStatus(pb.Status status, String operation) {
  if (status != pb.Status.Success) {
    throw ProvStatusException(
      ProvStatus.fromValue(status.value),
      operation: operation,
    );
  }
}

T _decode<T extends Object>(String endpoint, T Function() parse) {
  try {
    return parse();
  } on InvalidProtocolBufferException catch (e) {
    throw CryptoException(
      'Could not decode the $endpoint response (${e.message}). The session '
      'keys are probably out of sync; reconnect.',
    );
  }
}

Never _unexpected(String endpoint, Object got, Object expected) =>
    throw CryptoException(
      'Unexpected $endpoint response $got (expected $expected). The session '
      'keys are probably out of sync; reconnect.',
    );

/// Sends a `prov-ctrl` command and checks the response type and status.
Future<void> ctrlRequest(
  EspSession session,
  pb.NetworkCtrlPayload command,
  pb.NetworkCtrlMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.ctrl,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.ctrl,
    () => pb.NetworkCtrlPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.ctrl, response.msg, expected);
  }
  checkStatus(response.status, expected.name);
}
```

Create `packages/esp_prov_core/lib/src/flows/custom_endpoint.dart`:

```dart
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
```

Create `packages/esp_prov_core/lib/src/flows/prov_ctrl.dart`:

```dart
import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Control commands on the `prov-ctrl` endpoint.
///
/// Each method completes normally on success and throws
/// [ProvStatusException] on a non-success device status, or
/// [UnknownEndpoint] on firmware without `prov-ctrl`.
final class ProvCtrl {
  /// Creates the control client. Obtain one from `EspSession.ctrl`.
  new(this._session);

  final EspSession _session;

  /// Clears the Wi-Fi credentials and state machine after a failed attempt.
  Future<void> resetWifi() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReset,
      cmdCtrlWifiReset: pb.CmdCtrlWifiReset(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlWifiReset,
  );

  /// Lets an already provisioned device accept new Wi-Fi credentials.
  Future<void> reprovisionWifi() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlWifiReprov,
      cmdCtrlWifiReprov: pb.CmdCtrlWifiReprov(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlWifiReprov,
  );

  /// Clears the Thread dataset and state machine.
  Future<void> resetThread() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReset,
      cmdCtrlThreadReset: pb.CmdCtrlThreadReset(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlThreadReset,
  );

  /// Lets an already provisioned device accept a new Thread dataset.
  Future<void> reprovisionThread() => ctrlRequest(
    _session,
    pb.NetworkCtrlPayload(
      msg: pb.NetworkCtrlMsgType.TypeCmdCtrlThreadReprov,
      cmdCtrlThreadReprov: pb.CmdCtrlThreadReprov(),
    ),
    pb.NetworkCtrlMsgType.TypeRespCtrlThreadReprov,
  );
}
```

Create `packages/esp_prov_core/lib/src/session/esp_session.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/custom_endpoint.dart';
import 'package:esp_prov_core/src/flows/prov_ctrl.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:esp_prov_core/src/transport/serial_queue.dart';

/// An authenticated provisioning session with one device.
final class EspSession {
  new _(this._transport, this.info, this._scheme);

  /// Reads `proto-ver`, picks the security scheme the firmware declares,
  /// runs the handshake and returns the session.
  ///
  /// Throws [SchemeMismatch] or [MissingCredentials] when [credentials] do
  /// not fit the firmware, [PopMismatch] when the device rejects them, and
  /// [HandshakeFailed] for other handshake errors.
  static Future<EspSession> open(
    ProvTransport transport, {
    ProvCredentials? credentials,
  }) async {
    final info = transport.endpoints.contains(ProvEndpoints.protoVer)
        ? DeviceInfo.parse(
            utf8.decode(
              await transport.send(
                ProvEndpoints.protoVer,
                Uint8List.fromList(utf8.encode('---')),
              ),
              allowMalformed: true,
            ),
          )
        : DeviceInfo.parse('');
    final scheme = selectScheme(info, credentials);
    if (!transport.endpoints.contains(ProvEndpoints.session)) {
      throw UnknownEndpoint(ProvEndpoints.session);
    }
    await scheme.handshake(transport);
    return EspSession._(transport, info, scheme);
  }

  final ProvTransport _transport;
  final SecurityScheme _scheme;
  final SerialQueue _queue = SerialQueue();
  bool _closed = false;
  Object? _failure;
  ProvCtrl? _ctrl;

  /// Version and capabilities reported by the device.
  final DeviceInfo info;

  /// Security version in use (0, 1 or 2).
  int get securityVersion => _scheme.version;

  /// Endpoint names the transport discovered.
  Set<String> get endpoints => _transport.endpoints;

  /// Encrypts [body], sends it to [endpoint] and returns the decrypted
  /// response. Requests run one at a time, in call order.
  ///
  /// Security 1 and 2 ciphers are stateful, so after any failed request the
  /// device and this session disagree on cipher state. Later requests then
  /// throw [TransportException] and the caller must reconnect.
  Future<Uint8List> request(String endpoint, Uint8List body) =>
      _queue.run(() async {
        if (_closed) {
          throw const DeviceDisconnected('The session is closed.');
        }
        final failure = _failure;
        if (failure != null) {
          throw TransportException(
            'The session cannot be used after a failed request. '
            'Reconnect and open a new session.',
            cause: failure,
          );
        }
        if (!_transport.endpoints.contains(endpoint)) {
          throw UnknownEndpoint(endpoint);
        }
        final encrypted = await _scheme.encrypt(body);
        try {
          final response = await _transport.send(endpoint, encrypted);
          return await _scheme.decrypt(response);
        } on Object catch (e) {
          _failure = e;
          rethrow;
        }
      });

  /// Reset and re-provision commands on `prov-ctrl`.
  ProvCtrl get ctrl => _ctrl ??= ProvCtrl(this);

  /// An application endpoint registered by the firmware, e.g. `custom-data`.
  CustomEndpoint custom(String name) => CustomEndpoint(this, name);

  /// Emits once when the link drops.
  Stream<void> get onDisconnected => _transport.onDisconnected;

  /// Closes the session and the link. Safe to call more than once and after
  /// the device has already disconnected.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _transport.disconnect();
  }
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
export 'src/flows/custom_endpoint.dart';
export 'src/flows/prov_ctrl.dart';
export 'src/security/security_scheme.dart';
export 'src/session/device_info.dart';
export 'src/session/esp_session.dart';
export 'src/session/prov_credentials.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_core && fvm dart test test/session/esp_session_test.dart test/flows/prov_ctrl_test.dart)`

Expected: `+14: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/support/fake_device.dart \
  packages/esp_prov_core/test/session/esp_session_test.dart \
  packages/esp_prov_core/test/flows/prov_ctrl_test.dart \
  packages/esp_prov_core/lib/src/flows/flow_support.dart \
  packages/esp_prov_core/lib/src/flows/custom_endpoint.dart \
  packages/esp_prov_core/lib/src/flows/prov_ctrl.dart \
  packages/esp_prov_core/lib/src/session/esp_session.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): EspSession with serialised encrypted requests" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 3.4: WifiProvisioner: scan and provision

**Files:**
- Create: `packages/esp_prov_core/lib/src/flows/wifi_models.dart`
- Create: `packages/esp_prov_core/lib/src/flows/wifi_provisioner.dart`
- Modify: `packages/esp_prov_core/lib/src/flows/flow_support.dart`
- Modify: `packages/esp_prov_core/lib/src/session/esp_session.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/support/network_handlers.dart`
- Test: `packages/esp_prov_core/test/flows/wifi_provisioner_test.dart`

**Interfaces:**
- Consumes: `EspSession`, `checkStatus`, `FakeDevice` (3.3).
- Produces: Exported:
- `enum WifiAuthMode { open, wep, wpaPsk, wpa2Psk, wpaWpa2Psk, wpa2Enterprise, wpa3Psk, wpa2Wpa3Psk, unknown; static WifiAuthMode fromValue(int value) }`
- `final class WifiNetwork { final String ssid; final Uint8List bssid; final int channel; final int rssi; final WifiAuthMode authMode; }`
- `enum WifiFailureReason { authError, networkNotFound, timeout, deviceDisconnected }`
- `sealed class WifiProvisionState` with `WifiApplying()`, `WifiConnecting()`, `WifiAttemptFailed({required int attemptsRemaining})`, `WifiConnected({required String ip4, required WifiAuthMode authMode, required String ssid, required Uint8List bssid, required int channel})`, `WifiFailed({required WifiFailureReason reason})`.
- `final class WifiProvisioner { new(EspSession session, {Duration scanPollInterval = const Duration(milliseconds: 500), int maxScanPolls = 60}); Future<List<WifiNetwork>> scan({bool passive = false, int groupChannels = 0, int periodMs = 120}); Stream<WifiProvisionState> provision({required String ssid, required String passphrase, Uint8List? bssid, int? channel, Duration timeout = const Duration(seconds: 30), Duration pollInterval = const Duration(seconds: 1)}); }`
- `EspSession.wifi` getter. Internal additions to `flow_support.dart`: `const scanPageSize = 4`, `scanRequest`, `configRequest`, `runNetworkScan({required pb.NetworkScanPayload start, required bool thread, required Duration pollInterval, required int maxPolls})`, `Future<bool> waitOrDisconnect(Duration delay, Future<void> disconnected)`.
- Test helper `test/support/network_handlers.dart`: `EndpointHandler scanHandler({List<pb.WiFiScanResult> wifi, List<pb.ThreadScanResult> thread, int pollsUntilFinished = 1, int? maxPerPage, List<(int, int)>? pageLog})`, `EndpointHandler configHandler({List<pb.RespGetWifiStatus> wifiStatuses, List<pb.RespGetThreadStatus> threadStatuses, pb.Status setStatus, void Function(pb.NetworkConfigPayload)? onCommand})`.

Scan (spec 3.5): `CmdScanWifiStart{blocking: true}`; poll
`CmdScanWifiStatus` every `scanPollInterval` until `scan_finished` (at most
`maxScanPolls`, then `TransportException`); page `CmdScanWifiResult` with
`count <= 4` (BLE 256-byte responses, esp_prov uses 4); stop early if a page
is empty. Results are deduplicated by SSID (strongest kept), hidden (empty)
SSIDs are dropped, and the list is sorted by RSSI. An auth mode the protos
do not know is stored by protobuf.dart in `unknownFields` (the getter
returns `Open`), so tag 5 in `unknownFields` maps to `WifiAuthMode.unknown`.

Provision: validate synchronously (`ArgumentError`: SSID 1..32 UTF-8 bytes,
passphrase <= 64 bytes, BSSID 6 bytes, channel 0..255). Then
`CmdSetWifiConfig` -> `CmdApplyWifiConfig` -> poll `CmdGetWifiStatus`:
`Connected` -> `WifiConnected` (stream ends);
`ConnectionFailed` -> `WifiFailed(authError | networkNotFound)`;
`Connecting` with `attempt_failed` -> `WifiAttemptFailed` (only when the
count changes); `Disconnected` keeps polling; `timeout` elapsed ->
`WifiFailed(timeout)`. A link drop while waiting (`onDisconnected`) or a
`DeviceDisconnected` from a request becomes `WifiFailed(deviceDisconnected)`.
Once `WifiConnected` has been emitted the generator returns and cancels its
listener, so the expected auto-stop disconnect is never observed.

Note the proto enum name: `WifiConnectFailedReason.WifiNetworkNotFound`
(network_constants.proto), not `NetworkNotFound` (older wifi_constants.proto).

- [ ] **Step 1: Write the scripted network handlers and the failing test**

Create `packages/esp_prov_core/test/support/network_handlers.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;

import 'fake_device.dart';

/// A `prov-scan` handler that reports [wifi] / [thread] results after
/// [pollsUntilFinished] status polls and serves them in pages.
/// [maxPerPage] lets a test make the device return fewer entries than asked.
EndpointHandler scanHandler({
  List<pb.WiFiScanResult> wifi = const [],
  List<pb.ThreadScanResult> thread = const [],
  int pollsUntilFinished = 1,
  int? maxPerPage,
  List<(int, int)>? pageLog,
}) {
  var polls = 0;
  return (Uint8List request) {
    final cmd = pb.NetworkScanPayload.fromBuffer(request);
    pb.NetworkScanPayload reply(pb.NetworkScanMsgType msg) =>
        pb.NetworkScanPayload(msg: msg, status: pb.Status.Success);
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiStart) {
      return reply(pb.NetworkScanMsgType.TypeRespScanWifiStart).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadStart) {
      return reply(pb.NetworkScanMsgType.TypeRespScanThreadStart)
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiStatus) {
      polls++;
      return (reply(pb.NetworkScanMsgType.TypeRespScanWifiStatus)
            ..respScanWifiStatus = pb.RespScanWifiStatus(
              scanFinished: polls >= pollsUntilFinished,
              resultCount: wifi.length,
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadStatus) {
      polls++;
      return (reply(pb.NetworkScanMsgType.TypeRespScanThreadStatus)
            ..respScanThreadStatus = pb.RespScanThreadStatus(
              scanFinished: polls >= pollsUntilFinished,
              resultCount: thread.length,
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanWifiResult) {
      final r = cmd.cmdScanWifiResult;
      pageLog?.add((r.startIndex, r.count));
      final end = (r.startIndex + (maxPerPage ?? r.count)).clamp(
        0,
        wifi.length,
      );
      return (reply(pb.NetworkScanMsgType.TypeRespScanWifiResult)
            ..respScanWifiResult = pb.RespScanWifiResult(
              entries: wifi.sublist(r.startIndex, end),
            ))
          .writeToBuffer();
    }
    if (cmd.msg == pb.NetworkScanMsgType.TypeCmdScanThreadResult) {
      final r = cmd.cmdScanThreadResult;
      final end = (r.startIndex + r.count).clamp(0, thread.length);
      return (reply(pb.NetworkScanMsgType.TypeRespScanThreadResult)
            ..respScanThreadResult = pb.RespScanThreadResult(
              entries: thread.sublist(r.startIndex, end),
            ))
          .writeToBuffer();
    }
    throw StateError('unexpected scan command ${cmd.msg}');
  };
}

/// A `prov-config` handler that accepts set/apply and answers each status
/// poll with the next entry of [wifiStatuses] / [threadStatuses] (the last
/// entry repeats). [setStatus] is returned for the set-config command.
EndpointHandler configHandler({
  List<pb.RespGetWifiStatus> wifiStatuses = const [],
  List<pb.RespGetThreadStatus> threadStatuses = const [],
  pb.Status setStatus = pb.Status.Success,
  void Function(pb.NetworkConfigPayload command)? onCommand,
}) {
  var wifiIndex = 0;
  var threadIndex = 0;
  return (Uint8List request) {
    final cmd = pb.NetworkConfigPayload.fromBuffer(request);
    onCommand?.call(cmd);
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdSetWifiConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespSetWifiConfig,
        respSetWifiConfig: pb.RespSetWifiConfig(status: setStatus),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdApplyWifiConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespApplyWifiConfig,
        respApplyWifiConfig: pb.RespApplyWifiConfig(status: pb.Status.Success),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdGetWifiStatus) {
      final status = wifiStatuses[wifiIndex];
      if (wifiIndex < wifiStatuses.length - 1) wifiIndex++;
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespGetWifiStatus,
        respGetWifiStatus: status,
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdSetThreadConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespSetThreadConfig,
        respSetThreadConfig: pb.RespSetThreadConfig(status: setStatus),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdApplyThreadConfig) {
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespApplyThreadConfig,
        respApplyThreadConfig: pb.RespApplyThreadConfig(
          status: pb.Status.Success,
        ),
      ).writeToBuffer();
    }
    if (cmd.msg == pb.NetworkConfigMsgType.TypeCmdGetThreadStatus) {
      final status = threadStatuses[threadIndex];
      if (threadIndex < threadStatuses.length - 1) threadIndex++;
      return pb.NetworkConfigPayload(
        msg: pb.NetworkConfigMsgType.TypeRespGetThreadStatus,
        respGetThreadStatus: status,
      ).writeToBuffer();
    }
    throw StateError('unexpected config command ${cmd.msg}');
  };
}
```

Create `packages/esp_prov_core/test/flows/wifi_provisioner_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';
import '../support/network_handlers.dart';

pb.WiFiScanResult _ap(String ssid, int rssi, {int auth = 3}) =>
    pb.WiFiScanResult(
      ssid: utf8.encode(ssid),
      rssi: rssi,
      channel: 6,
      bssid: [1, 2, 3, 4, 5, rssi & 0xff],
      auth: pb.WifiAuthMode.valueOf(auth),
    );

pb.RespGetWifiStatus _connecting({int? attemptsRemaining}) =>
    pb.RespGetWifiStatus(
      status: pb.Status.Success,
      wifiStaState: pb.WifiStationState.Connecting,
      attemptFailed: attemptsRemaining == null
          ? null
          : pb.WifiAttemptFailed(attemptsRemaining: attemptsRemaining),
    );

final _connected = pb.RespGetWifiStatus(
  status: pb.Status.Success,
  wifiStaState: pb.WifiStationState.Connected,
  wifiConnected: pb.WifiConnectedState(
    ip4Addr: '192.168.1.42',
    authMode: pb.WifiAuthMode.WPA2_PSK,
    ssid: utf8.encode('Home'),
    bssid: [1, 2, 3, 4, 5, 6],
    channel: 6,
  ),
);

pb.RespGetWifiStatus _failed(pb.WifiConnectFailedReason reason) =>
    pb.RespGetWifiStatus(
      status: pb.Status.Success,
      wifiStaState: pb.WifiStationState.ConnectionFailed,
      wifiFailReason: reason,
    );

Future<(FakeDevice, WifiProvisioner)> _open(
  Map<String, EndpointHandler> handlers,
) async {
  final device = FakeDevice(
    protoVer: protoVerJson(secVer: 0, caps: ['no_sec', 'wifi_scan']),
    handlers: handlers,
  );
  final session = await EspSession.open(device);
  return (
    device,
    WifiProvisioner(session, scanPollInterval: Duration.zero, maxScanPolls: 5),
  );
}

Stream<WifiProvisionState> _provision(WifiProvisioner wifi) => wifi.provision(
  ssid: 'Home',
  passphrase: 'password1',
  timeout: const Duration(milliseconds: 200),
  pollInterval: const Duration(milliseconds: 5),
);

void main() {
  group('scan', () {
    test('pages by 4, dedupes by SSID, drops hidden, sorts by RSSI', () async {
      final pageLog = <(int, int)>[];
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(
          pollsUntilFinished: 3,
          pageLog: pageLog,
          wifi: [
            _ap('A', -70),
            _ap('B', -40),
            _ap('A', -50),
            _ap('', -30),
            _ap('C', -90),
            _ap('D', -60),
            _ap('E', -65),
            _ap('F', -80),
            _ap('G', -85),
            _ap('B', -45),
          ],
        ),
      });
      final networks = await wifi.scan();
      expect(pageLog, [(0, 4), (4, 4), (8, 2)]);
      expect(networks.map((n) => n.ssid), ['B', 'A', 'D', 'E', 'F', 'G', 'C']);
      expect(networks[1].rssi, -50);
      expect(networks.first.authMode, WifiAuthMode.wpa2Psk);
    });

    test('stops paging when the device returns fewer entries', () async {
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(
          maxPerPage: 1,
          wifi: [_ap('A', -1), _ap('B', -2), _ap('C', -3)],
        ),
      });
      expect((await wifi.scan()).map((n) => n.ssid), ['A', 'B', 'C']);
    });

    test('an empty result needs no result request', () async {
      final pageLog = <(int, int)>[];
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(pageLog: pageLog),
      });
      expect(await wifi.scan(), isEmpty);
      expect(pageLog, isEmpty);
    });

    test('gives up when the scan never finishes', () async {
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(pollsUntilFinished: 999, wifi: [_ap('A', 1)]),
      });
      await expectLater(wifi.scan(), throwsA(isA<TransportException>()));
    });

    test('an auth mode newer than this library maps to unknown', () async {
      // Field 5 (auth), varint 9: a value network_constants.proto lacks.
      final entry = pb.WiFiScanResult.fromBuffer([
        ...(_ap('New', -10)..clearAuth()).writeToBuffer(),
        0x28,
        0x09,
      ]);
      final (_, wifi) = await _open({
        'prov-scan': scanHandler(wifi: [entry]),
      });
      expect((await wifi.scan()).single.authMode, WifiAuthMode.unknown);
    });
  });

  group('provision', () {
    test('happy path emits Applying, Connecting, Connected', () async {
      pb.CmdSetWifiConfig? sent;
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [_connecting(), _connecting(), _connected],
          onCommand: (c) {
            if (c.hasCmdSetWifiConfig()) sent = c.cmdSetWifiConfig;
          },
        ),
      });
      final states = await _provision(wifi).toList();
      expect(states, [
        isA<WifiApplying>(),
        isA<WifiConnecting>(),
        isA<WifiConnected>()
            .having((s) => s.ip4, 'ip4', '192.168.1.42')
            .having((s) => s.ssid, 'ssid', 'Home')
            .having((s) => s.authMode, 'authMode', WifiAuthMode.wpa2Psk),
      ]);
      expect(utf8.decode(sent!.ssid), 'Home');
      expect(utf8.decode(sent!.passphrase), 'password1');
    });

    test(
      'attempt failures are reported once per change, then AuthError',
      () async {
        final (_, wifi) = await _open({
          'prov-config': configHandler(
            wifiStatuses: [
              _connecting(attemptsRemaining: 2),
              _connecting(attemptsRemaining: 2),
              _connecting(attemptsRemaining: 1),
              _failed(pb.WifiConnectFailedReason.AuthError),
            ],
          ),
        });
        final states = await _provision(wifi).toList();
        expect(states, [
          isA<WifiApplying>(),
          isA<WifiConnecting>(),
          isA<WifiAttemptFailed>().having(
            (s) => s.attemptsRemaining,
            'remaining',
            2,
          ),
          isA<WifiAttemptFailed>().having(
            (s) => s.attemptsRemaining,
            'remaining',
            1,
          ),
          isA<WifiFailed>().having(
            (s) => s.reason,
            'reason',
            WifiFailureReason.authError,
          ),
        ]);
      },
    );

    test('unknown SSID ends with networkNotFound', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [
            _failed(pb.WifiConnectFailedReason.WifiNetworkNotFound),
          ],
        ),
      });
      expect(
        (await _provision(wifi).last as WifiFailed).reason,
        WifiFailureReason.networkNotFound,
      );
    });

    test('Disconnected state keeps polling until the timeout', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          wifiStatuses: [
            pb.RespGetWifiStatus(
              status: pb.Status.Success,
              wifiStaState: pb.WifiStationState.Disconnected,
            ),
          ],
        ),
      });
      expect(
        (await _provision(wifi).last as WifiFailed).reason,
        WifiFailureReason.timeout,
      );
    });

    test('a disconnect after Connected is swallowed', () async {
      late FakeDevice device;
      final handler = configHandler(wifiStatuses: [_connected]);
      final (d, wifi) = await _open({
        'prov-config': (request) {
          final response = handler(request);
          // Firmware auto-stop: drop the link shortly after Connected.
          Timer(Duration.zero, device.dropLink);
          return response;
        },
      });
      device = d;
      final states = await _provision(wifi).toList();
      expect(states.last, isA<WifiConnected>());
    });

    test(
      'a disconnect before Connected ends with deviceDisconnected',
      () async {
        late FakeDevice device;
        final handler = configHandler(wifiStatuses: [_connecting()]);
        var polls = 0;
        final (d, wifi) = await _open({
          'prov-config': (request) {
            final response = handler(request);
            if (pb.NetworkConfigPayload.fromBuffer(request)
                    .hasCmdGetWifiStatus() &&
                ++polls == 2) {
              Timer(Duration.zero, device.dropLink);
            }
            return response;
          },
        });
        device = d;
        expect(
          (await _provision(wifi).last as WifiFailed).reason,
          WifiFailureReason.deviceDisconnected,
        );
      },
    );

    test('a device status error surfaces as ProvStatusException', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(
          setStatus: pb.Status.InvalidArgument,
          wifiStatuses: [_connected],
        ),
      });
      await expectLater(
        _provision(wifi),
        emitsInOrder([
          isA<WifiApplying>(),
          emitsError(
            isA<ProvStatusException>().having(
              (e) => e.status,
              'status',
              ProvStatus.invalidArgument,
            ),
          ),
        ]),
      );
    });

    test('rejects invalid credentials before talking to the device', () async {
      final (device, wifi) = await _open({});
      expect(
        () => wifi.provision(ssid: '', passphrase: 'x'),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(ssid: 'x' * 33, passphrase: 'x'),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(ssid: 'ok', passphrase: 'p' * 65),
        throwsArgumentError,
      );
      expect(
        () => wifi.provision(
          ssid: 'ok',
          passphrase: 'password',
          bssid: Uint8List(5),
        ),
        throwsArgumentError,
      );
      expect(device.plainRequests, isEmpty);
    });

    test('a 32-byte multi-byte UTF-8 SSID is accepted', () async {
      final (_, wifi) = await _open({
        'prov-config': configHandler(wifiStatuses: [_connected]),
      });
      // 8 x 4-byte emoji = 32 bytes.
      final ssid = '\u{1F600}' * 8;
      expect(utf8.encode(ssid).length, 32);
      final states = await wifi
          .provision(ssid: ssid, passphrase: '', timeout: Duration.zero)
          .toList();
      expect(states.last, isA<WifiConnected>());
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/flows/wifi_provisioner_test.dart)`

Expected: FAIL: `Error: Type 'WifiProvisioner' not found.`

- [ ] **Step 3: Implement the Wi-Fi flow**

Create `packages/esp_prov_core/lib/src/flows/wifi_models.dart`:

```dart
import 'dart:typed_data';

/// Wi-Fi authentication mode (network_constants.proto `WifiAuthMode`).
enum WifiAuthMode {
  /// `Open = 0`.
  open,

  /// `WEP = 1`.
  wep,

  /// `WPA_PSK = 2`.
  wpaPsk,

  /// `WPA2_PSK = 3`.
  wpa2Psk,

  /// `WPA_WPA2_PSK = 4`.
  wpaWpa2Psk,

  /// `WPA2_ENTERPRISE = 5`.
  wpa2Enterprise,

  /// `WPA3_PSK = 6`.
  wpa3Psk,

  /// `WPA2_WPA3_PSK = 7`.
  wpa2Wpa3Psk,

  /// A value newer than this library.
  unknown;

  /// Maps a wire value to a mode.
  static WifiAuthMode fromValue(int value) =>
      value >= 0 && value < unknown.index ? values[value] : unknown;
}

/// An access point found by `WifiProvisioner.scan`.
final class WifiNetwork {
  /// Creates a scan result.
  const new({
    required this.ssid,
    required this.bssid,
    required this.channel,
    required this.rssi,
    required this.authMode,
  });

  /// Network name, decoded as UTF-8.
  final String ssid;

  /// 6-byte BSSID of the strongest access point seen for [ssid].
  final Uint8List bssid;

  /// Wi-Fi channel.
  final int channel;

  /// Signal strength in dBm.
  final int rssi;

  /// Authentication mode.
  final WifiAuthMode authMode;

  @override
  String toString() =>
      'WifiNetwork($ssid, rssi: $rssi, channel: $channel, ${authMode.name})';
}

/// Why Wi-Fi provisioning ended without a connection.
enum WifiFailureReason {
  /// Wrong passphrase (`WifiConnectFailedReason.AuthError`).
  authError,

  /// SSID not found (`WifiConnectFailedReason.WifiNetworkNotFound`).
  networkNotFound,

  /// The device kept trying until `timeout` elapsed.
  timeout,

  /// The link dropped before the device reported `Connected`.
  deviceDisconnected,
}

/// Progress of `WifiProvisioner.provision`.
sealed class WifiProvisionState {
  const new();
}

/// Credentials are being sent and applied.
final class WifiApplying extends WifiProvisionState {
  /// Creates the state.
  const new();
}

/// The device is joining the network.
final class WifiConnecting extends WifiProvisionState {
  /// Creates the state.
  const new();
}

/// One connection attempt failed; the device will retry.
final class WifiAttemptFailed extends WifiProvisionState {
  /// Creates the state.
  const new({required this.attemptsRemaining});

  /// Retries the firmware has left.
  final int attemptsRemaining;
}

/// Terminal: the device joined the network.
final class WifiConnected extends WifiProvisionState {
  /// Creates the state.
  const new({
    required this.ip4,
    required this.authMode,
    required this.ssid,
    required this.bssid,
    required this.channel,
  });

  /// IPv4 address the device obtained.
  final String ip4;

  /// Authentication mode of the joined network.
  final WifiAuthMode authMode;

  /// SSID the device joined.
  final String ssid;

  /// BSSID the device joined.
  final Uint8List bssid;

  /// Channel the device joined on.
  final int channel;
}

/// Terminal: provisioning did not succeed.
final class WifiFailed extends WifiProvisionState {
  /// Creates the state.
  const new({required this.reason});

  /// Why it failed.
  final WifiFailureReason reason;
}
```

Create `packages/esp_prov_core/lib/src/flows/wifi_provisioner.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/flows/wifi_models.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Wi-Fi scan and provisioning over `prov-scan` and `prov-config`.
///
/// Obtain one from `EspSession.wifi`.
final class WifiProvisioner {
  /// Creates a provisioner. [scanPollInterval] and [maxScanPolls] bound how
  /// long [scan] waits for the device to finish scanning.
  new(
    this._session, {
    this.scanPollInterval = const Duration(milliseconds: 500),
    this.maxScanPolls = 60,
  });

  final EspSession _session;

  /// Delay between `CmdScanWifiStatus` polls.
  final Duration scanPollInterval;

  /// Status polls before [scan] gives up with [TransportException].
  final int maxScanPolls;

  /// Asks the device to scan and returns the access points it found,
  /// strongest first, one entry per SSID (the strongest). Hidden networks
  /// (empty SSID) are left out.
  Future<List<WifiNetwork>> scan({
    bool passive = false,
    int groupChannels = 0,
    int periodMs = 120,
  }) async {
    final pages = await runNetworkScan(
      _session,
      start: pb.NetworkScanPayload(
        msg: pb.NetworkScanMsgType.TypeCmdScanWifiStart,
        cmdScanWifiStart: pb.CmdScanWifiStart(
          blocking: true,
          passive: passive,
          groupChannels: groupChannels,
          periodMs: periodMs,
        ),
      ),
      thread: false,
      pollInterval: scanPollInterval,
      maxPolls: maxScanPolls,
    );
    final strongest = <String, WifiNetwork>{};
    for (final page in pages) {
      for (final entry in page.respScanWifiResult.entries) {
        final network = WifiNetwork(
          ssid: utf8.decode(entry.ssid, allowMalformed: true),
          bssid: Uint8List.fromList(entry.bssid),
          channel: entry.channel,
          rssi: entry.rssi,
          // protobuf.dart reads unknown enum values as the default (Open)
          // and keeps the raw value in unknownFields; tag 5 is `auth`.
          authMode: entry.unknownFields.hasField(5)
              ? WifiAuthMode.unknown
              : WifiAuthMode.fromValue(entry.auth.value),
        );
        if (network.ssid.isEmpty) continue;
        final current = strongest[network.ssid];
        if (current == null || network.rssi > current.rssi) {
          strongest[network.ssid] = network;
        }
      }
    }
    return strongest.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Sends credentials, applies them and polls the connection state.
  ///
  /// Emits [WifiApplying], [WifiConnecting], any [WifiAttemptFailed], then
  /// exactly one terminal [WifiConnected] or [WifiFailed] and closes.
  /// A disconnect after [WifiConnected] is expected (firmware auto-stop) and
  /// ignored; a disconnect before it yields
  /// `WifiFailed(WifiFailureReason.deviceDisconnected)`.
  ///
  /// Throws [ArgumentError] immediately for an SSID outside 1..32 UTF-8
  /// bytes, a passphrase over 64 bytes, or a BSSID that is not 6 bytes.
  /// Device status errors arrive as [ProvStatusException] stream errors.
  Stream<WifiProvisionState> provision({
    required String ssid,
    required String passphrase,
    Uint8List? bssid,
    int? channel,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    final ssidBytes = utf8.encode(ssid);
    final passBytes = utf8.encode(passphrase);
    if (ssidBytes.isEmpty || ssidBytes.length > 32) {
      throw ArgumentError.value(ssid, 'ssid', 'must be 1 to 32 UTF-8 bytes');
    }
    if (passBytes.length > 64) {
      throw ArgumentError('passphrase must be at most 64 UTF-8 bytes');
    }
    if (bssid != null && bssid.length != 6) {
      throw ArgumentError.value(bssid, 'bssid', 'must be 6 bytes');
    }
    if (channel != null && (channel < 0 || channel > 255)) {
      throw ArgumentError.value(channel, 'channel', 'must be 0 to 255');
    }
    return _provision(
      pb.CmdSetWifiConfig(
        ssid: ssidBytes,
        passphrase: passBytes,
        bssid: bssid,
        channel: channel,
      ),
      timeout,
      pollInterval,
    );
  }

  Stream<WifiProvisionState> _provision(
    pb.CmdSetWifiConfig config,
    Duration timeout,
    Duration pollInterval,
  ) async* {
    final disconnected = Completer<void>();
    final subscription = _session.onDisconnected.listen((_) {
      if (!disconnected.isCompleted) disconnected.complete();
    });
    try {
      yield const WifiApplying();
      final set = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdSetWifiConfig,
          cmdSetWifiConfig: config,
        ),
        pb.NetworkConfigMsgType.TypeRespSetWifiConfig,
      );
      checkStatus(set.respSetWifiConfig.status, 'Set Wi-Fi config');
      final apply = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdApplyWifiConfig,
          cmdApplyWifiConfig: pb.CmdApplyWifiConfig(),
        ),
        pb.NetworkConfigMsgType.TypeRespApplyWifiConfig,
      );
      checkStatus(apply.respApplyWifiConfig.status, 'Apply Wi-Fi config');
      yield const WifiConnecting();

      final clock = Stopwatch()..start();
      int? lastAttemptsRemaining;
      while (true) {
        final response = await configRequest(
          _session,
          pb.NetworkConfigPayload(
            msg: pb.NetworkConfigMsgType.TypeCmdGetWifiStatus,
            cmdGetWifiStatus: pb.CmdGetWifiStatus(),
          ),
          pb.NetworkConfigMsgType.TypeRespGetWifiStatus,
        );
        final status = response.respGetWifiStatus;
        checkStatus(status.status, 'Get Wi-Fi status');
        final state = status.wifiStaState;
        if (state == pb.WifiStationState.Connected) {
          final c = status.wifiConnected;
          yield WifiConnected(
            ip4: c.ip4Addr,
            authMode: WifiAuthMode.fromValue(c.authMode.value),
            ssid: utf8.decode(c.ssid, allowMalformed: true),
            bssid: Uint8List.fromList(c.bssid),
            channel: c.channel,
          );
          return;
        }
        if (state == pb.WifiStationState.ConnectionFailed) {
          yield WifiFailed(
            reason:
                status.wifiFailReason == pb.WifiConnectFailedReason.AuthError
                ? WifiFailureReason.authError
                : WifiFailureReason.networkNotFound,
          );
          return;
        }
        if (state == pb.WifiStationState.Connecting &&
            status.hasAttemptFailed()) {
          final remaining = status.attemptFailed.attemptsRemaining;
          if (remaining != lastAttemptsRemaining) {
            lastAttemptsRemaining = remaining;
            yield WifiAttemptFailed(attemptsRemaining: remaining);
          }
        }
        if (clock.elapsed >= timeout) {
          yield const WifiFailed(reason: WifiFailureReason.timeout);
          return;
        }
        if (await waitOrDisconnect(pollInterval, disconnected.future)) {
          yield const WifiFailed(reason: WifiFailureReason.deviceDisconnected);
          return;
        }
      }
    } on DeviceDisconnected {
      yield const WifiFailed(reason: WifiFailureReason.deviceDisconnected);
    } finally {
      await subscription.cancel();
    }
  }
}
```

Replace the entire contents of `packages/esp_prov_core/lib/src/flows/flow_support.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/errors/prov_status.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_ctrl.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:protobuf/protobuf.dart' show InvalidProtocolBufferException;

/// Scan results are fetched at most this many per request: the firmware
/// caps a BLE response at 256 bytes (see esp_prov `scan_wifi_APs`).
const scanPageSize = 4;

/// Throws [ProvStatusException] unless [status] is `Success`.
void checkStatus(pb.Status status, String operation) {
  if (status != pb.Status.Success) {
    throw ProvStatusException(
      ProvStatus.fromValue(status.value),
      operation: operation,
    );
  }
}

T _decode<T extends Object>(String endpoint, T Function() parse) {
  try {
    return parse();
  } on InvalidProtocolBufferException catch (e) {
    throw CryptoException(
      'Could not decode the $endpoint response (${e.message}). The session '
      'keys are probably out of sync; reconnect.',
    );
  }
}

Never _unexpected(String endpoint, Object got, Object expected) =>
    throw CryptoException(
      'Unexpected $endpoint response $got (expected $expected). The session '
      'keys are probably out of sync; reconnect.',
    );

/// Sends a `prov-scan` command and checks the response type and status.
Future<pb.NetworkScanPayload> scanRequest(
  EspSession session,
  pb.NetworkScanPayload command,
  pb.NetworkScanMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.scan,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.scan,
    () => pb.NetworkScanPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.scan, response.msg, expected);
  }
  checkStatus(response.status, expected.name);
  return response;
}

/// Sends a `prov-config` command and checks the response type.
Future<pb.NetworkConfigPayload> configRequest(
  EspSession session,
  pb.NetworkConfigPayload command,
  pb.NetworkConfigMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.config,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.config,
    () => pb.NetworkConfigPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.config, response.msg, expected);
  }
  return response;
}

/// Sends a `prov-ctrl` command and checks the response type and status.
Future<void> ctrlRequest(
  EspSession session,
  pb.NetworkCtrlPayload command,
  pb.NetworkCtrlMsgType expected,
) async {
  final bytes = await session.request(
    ProvEndpoints.ctrl,
    command.writeToBuffer(),
  );
  final response = _decode(
    ProvEndpoints.ctrl,
    () => pb.NetworkCtrlPayload.fromBuffer(bytes),
  );
  if (response.msg != expected) {
    _unexpected(ProvEndpoints.ctrl, response.msg, expected);
  }
  checkStatus(response.status, expected.name);
}

/// Runs start -> status polling -> paged results on `prov-scan` and returns
/// every result page. Shared by Wi-Fi ([thread] false) and Thread scans.
Future<List<pb.NetworkScanPayload>> runNetworkScan(
  EspSession session, {
  required pb.NetworkScanPayload start,
  required bool thread,
  required Duration pollInterval,
  required int maxPolls,
}) async {
  await scanRequest(
    session,
    start,
    thread
        ? pb.NetworkScanMsgType.TypeRespScanThreadStart
        : pb.NetworkScanMsgType.TypeRespScanWifiStart,
  );

  var count = 0;
  for (var poll = 1; ; poll++) {
    final status = await scanRequest(
      session,
      thread
          ? pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanThreadStatus,
              cmdScanThreadStatus: pb.CmdScanThreadStatus(),
            )
          : pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanWifiStatus,
              cmdScanWifiStatus: pb.CmdScanWifiStatus(),
            ),
      thread
          ? pb.NetworkScanMsgType.TypeRespScanThreadStatus
          : pb.NetworkScanMsgType.TypeRespScanWifiStatus,
    );
    final finished = thread
        ? status.respScanThreadStatus.scanFinished
        : status.respScanWifiStatus.scanFinished;
    if (finished) {
      count = thread
          ? status.respScanThreadStatus.resultCount
          : status.respScanWifiStatus.resultCount;
      break;
    }
    if (poll >= maxPolls) {
      throw const TransportException(
        'The device did not finish the network scan in time.',
      );
    }
    await Future<void>.delayed(pollInterval);
  }

  final pages = <pb.NetworkScanPayload>[];
  var index = 0;
  while (index < count) {
    final size = math.min(scanPageSize, count - index);
    final page = await scanRequest(
      session,
      thread
          ? pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanThreadResult,
              cmdScanThreadResult: pb.CmdScanThreadResult(
                startIndex: index,
                count: size,
              ),
            )
          : pb.NetworkScanPayload(
              msg: pb.NetworkScanMsgType.TypeCmdScanWifiResult,
              cmdScanWifiResult: pb.CmdScanWifiResult(
                startIndex: index,
                count: size,
              ),
            ),
      thread
          ? pb.NetworkScanMsgType.TypeRespScanThreadResult
          : pb.NetworkScanMsgType.TypeRespScanWifiResult,
    );
    final received = thread
        ? page.respScanThreadResult.entries.length
        : page.respScanWifiResult.entries.length;
    if (received == 0) break;
    pages.add(page);
    index += received;
  }
  return pages;
}

/// Waits for [delay]; returns true if [disconnected] completes first.
Future<bool> waitOrDisconnect(Duration delay, Future<void> disconnected) =>
    Future.any([
      Future<bool>.delayed(delay, () => false),
      disconnected.then((_) => true),
    ]);
```

Replace the entire contents of `packages/esp_prov_core/lib/src/session/esp_session.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/custom_endpoint.dart';
import 'package:esp_prov_core/src/flows/prov_ctrl.dart';
import 'package:esp_prov_core/src/flows/wifi_provisioner.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:esp_prov_core/src/transport/serial_queue.dart';

/// An authenticated provisioning session with one device.
final class EspSession {
  new _(this._transport, this.info, this._scheme);

  /// Reads `proto-ver`, picks the security scheme the firmware declares,
  /// runs the handshake and returns the session.
  ///
  /// Throws [SchemeMismatch] or [MissingCredentials] when [credentials] do
  /// not fit the firmware, [PopMismatch] when the device rejects them, and
  /// [HandshakeFailed] for other handshake errors.
  static Future<EspSession> open(
    ProvTransport transport, {
    ProvCredentials? credentials,
  }) async {
    final info = transport.endpoints.contains(ProvEndpoints.protoVer)
        ? DeviceInfo.parse(
            utf8.decode(
              await transport.send(
                ProvEndpoints.protoVer,
                Uint8List.fromList(utf8.encode('---')),
              ),
              allowMalformed: true,
            ),
          )
        : DeviceInfo.parse('');
    final scheme = selectScheme(info, credentials);
    if (!transport.endpoints.contains(ProvEndpoints.session)) {
      throw UnknownEndpoint(ProvEndpoints.session);
    }
    await scheme.handshake(transport);
    return EspSession._(transport, info, scheme);
  }

  final ProvTransport _transport;
  final SecurityScheme _scheme;
  final SerialQueue _queue = SerialQueue();
  bool _closed = false;
  Object? _failure;
  WifiProvisioner? _wifi;
  ProvCtrl? _ctrl;

  /// Version and capabilities reported by the device.
  final DeviceInfo info;

  /// Security version in use (0, 1 or 2).
  int get securityVersion => _scheme.version;

  /// Endpoint names the transport discovered.
  Set<String> get endpoints => _transport.endpoints;

  /// Encrypts [body], sends it to [endpoint] and returns the decrypted
  /// response. Requests run one at a time, in call order.
  ///
  /// Security 1 and 2 ciphers are stateful, so after any failed request the
  /// device and this session disagree on cipher state. Later requests then
  /// throw [TransportException] and the caller must reconnect.
  Future<Uint8List> request(String endpoint, Uint8List body) =>
      _queue.run(() async {
        if (_closed) {
          throw const DeviceDisconnected('The session is closed.');
        }
        final failure = _failure;
        if (failure != null) {
          throw TransportException(
            'The session cannot be used after a failed request. '
            'Reconnect and open a new session.',
            cause: failure,
          );
        }
        if (!_transport.endpoints.contains(endpoint)) {
          throw UnknownEndpoint(endpoint);
        }
        final encrypted = await _scheme.encrypt(body);
        try {
          final response = await _transport.send(endpoint, encrypted);
          return await _scheme.decrypt(response);
        } on Object catch (e) {
          _failure = e;
          rethrow;
        }
      });

  /// Wi-Fi scan and provisioning.
  ///
  /// Throws [UnsupportedCapability] only when the firmware lists
  /// `thread_prov` without `wifi_prov` (a Thread-only device).
  WifiProvisioner get wifi {
    if (info.hasCapability('thread_prov') && !info.hasCapability('wifi_prov')) {
      throw UnsupportedCapability('wifi_prov');
    }
    return _wifi ??= WifiProvisioner(this);
  }

  /// Reset and re-provision commands on `prov-ctrl`.
  ProvCtrl get ctrl => _ctrl ??= ProvCtrl(this);

  /// An application endpoint registered by the firmware, e.g. `custom-data`.
  CustomEndpoint custom(String name) => CustomEndpoint(this, name);

  /// Emits once when the link drops.
  Stream<void> get onDisconnected => _transport.onDisconnected;

  /// Closes the session and the link. Safe to call more than once and after
  /// the device has already disconnected.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _transport.disconnect();
  }
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
export 'src/flows/custom_endpoint.dart';
export 'src/flows/prov_ctrl.dart';
export 'src/flows/wifi_models.dart';
export 'src/flows/wifi_provisioner.dart';
export 'src/security/security_scheme.dart';
export 'src/session/device_info.dart';
export 'src/session/esp_session.dart';
export 'src/session/prov_credentials.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd packages/esp_prov_core && fvm dart test test/flows/wifi_provisioner_test.dart)`

Expected: `+14: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/support/network_handlers.dart \
  packages/esp_prov_core/test/flows/wifi_provisioner_test.dart \
  packages/esp_prov_core/lib/src/flows/wifi_models.dart \
  packages/esp_prov_core/lib/src/flows/wifi_provisioner.dart \
  packages/esp_prov_core/lib/src/flows/flow_support.dart \
  packages/esp_prov_core/lib/src/session/esp_session.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): Wi-Fi scan and provisioning flow" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 3.5: ThreadProvisioner and capability gates

**Files:**
- Create: `packages/esp_prov_core/lib/src/flows/thread_models.dart`
- Create: `packages/esp_prov_core/lib/src/flows/thread_provisioner.dart`
- Modify: `packages/esp_prov_core/lib/src/session/esp_session.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/flows/thread_provisioner_test.dart`
- Test: `packages/esp_prov_core/test/session/capabilities_test.dart`

**Interfaces:**
- Consumes: `runNetworkScan`, `configRequest`, `waitOrDisconnect` (3.4), handlers (3.4).
- Produces: Exported:
- `final class ThreadNetwork { final int panId; final int channel; final int rssi; final int lqi; final Uint8List extAddr; final String networkName; final Uint8List extPanId; }`
- `enum ThreadFailureReason { datasetInvalid, networkNotFound, timeout, deviceDisconnected }`
- `sealed class ThreadProvisionState` with `ThreadApplying()`, `ThreadAttaching()`, `ThreadAttached({required int panId, required Uint8List extPanId, required int channel, required String name})`, `ThreadFailed({required ThreadFailureReason reason})`.
- `final class ThreadProvisioner { new(EspSession session, {Duration scanPollInterval, int maxScanPolls}); Future<List<ThreadNetwork>> scan(); Stream<ThreadProvisionState> provision({required Uint8List datasetTlvs, Duration timeout, Duration pollInterval}); }`
- `EspSession.thread` getter: throws `UnsupportedCapability('thread_prov')` unless the device lists `thread_prov`. `EspSession.wifi` throws `UnsupportedCapability('wifi_prov')` only when `thread_prov` is listed without `wifi_prov`.

Same stream contract as Wi-Fi. Thread uses `CmdScanThreadStart{blocking:
true}`, `CmdSetThreadConfig{dataset}`, `CmdApplyThreadConfig` and
`CmdGetThreadStatus`; states `Attached`/`AttachingFailed` with
`ThreadAttachFailedReason.DatasetInvalid|ThreadNetworkNotFound`. The
detached state is spelled `Dettached` in the proto and is treated like
Wi-Fi `Disconnected` (keep polling). The dataset must be 1..254 bytes.

- [ ] **Step 1: Write the failing tests**

Create `packages/esp_prov_core/test/flows/thread_provisioner_test.dart`:

```dart
import 'dart:typed_data';

import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:esp_prov_core/src/proto/constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:test/test.dart';

import '../support/fake_device.dart';
import '../support/network_handlers.dart';

Future<ThreadProvisioner> _open(Map<String, EndpointHandler> handlers) async {
  final session = await EspSession.open(
    FakeDevice(
      protoVer: protoVerJson(
        secVer: 0,
        ver: 'netprov-v1.2',
        caps: ['no_sec', 'thread_scan', 'thread_prov'],
      ),
      handlers: handlers,
    ),
  );
  return ThreadProvisioner(session, scanPollInterval: Duration.zero);
}

void main() {
  test('scan returns networks strongest first', () async {
    final thread = await _open({
      'prov-scan': scanHandler(
        thread: [
          for (final (name, rssi) in [('a', -80), ('b', -20), ('c', -50)])
            pb.ThreadScanResult(
              networkName: name,
              rssi: rssi,
              panId: 0x1234,
              channel: 15,
              extPanId: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
        ],
      ),
    });
    final networks = await thread.scan();
    expect(networks.map((n) => n.networkName), ['b', 'c', 'a']);
    expect(networks.first.panId, 0x1234);
  });

  test('provision attaches', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.Attaching,
          ),
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.Attached,
            threadAttached: pb.ThreadAttachState(
              panId: 0x1234,
              channel: 15,
              name: 'OpenThread',
              extPanId: [1, 2, 3, 4, 5, 6, 7, 8],
            ),
          ),
        ],
      ),
    });
    final states = await thread
        .provision(
          datasetTlvs: Uint8List.fromList([0, 3, 0, 0, 15]),
          pollInterval: Duration.zero,
        )
        .toList();
    expect(states, [
      isA<ThreadApplying>(),
      isA<ThreadAttaching>(),
      isA<ThreadAttached>().having((s) => s.name, 'name', 'OpenThread'),
    ]);
  });

  test('invalid dataset ends with datasetInvalid', () async {
    final thread = await _open({
      'prov-config': configHandler(
        threadStatuses: [
          pb.RespGetThreadStatus(
            status: pb.Status.Success,
            threadState: pb.ThreadNetworkState.AttachingFailed,
            threadFailReason: pb.ThreadAttachFailedReason.DatasetInvalid,
          ),
        ],
      ),
    });
    final last = await thread
        .provision(datasetTlvs: Uint8List.fromList([1]))
        .last;
    expect((last as ThreadFailed).reason, ThreadFailureReason.datasetInvalid);
  });

  test('rejects empty and oversized datasets', () async {
    final thread = await _open({});
    expect(
      () => thread.provision(datasetTlvs: Uint8List(0)),
      throwsArgumentError,
    );
    expect(
      () => thread.provision(datasetTlvs: Uint8List(255)),
      throwsArgumentError,
    );
  });
}
```

Create `packages/esp_prov_core/test/session/capabilities_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

import '../support/fake_device.dart';

void main() {
  test('capability gates for wifi and thread', () async {
    final threadOnly = await EspSession.open(
      FakeDevice(
        protoVer: protoVerJson(secVer: 0, caps: ['no_sec', 'thread_prov']),
      ),
    );
    expect(() => threadOnly.wifi, throwsA(isA<UnsupportedCapability>()));
    expect(threadOnly.thread, isA<ThreadProvisioner>());

    final legacy = await EspSession.open(
      FakeDevice(protoVer: protoVerJson(secVer: 0, caps: ['no_sec'])),
    );
    expect(legacy.wifi, isA<WifiProvisioner>());
    expect(() => legacy.thread, throwsA(isA<UnsupportedCapability>()));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `(cd packages/esp_prov_core && fvm dart test test/flows/thread_provisioner_test.dart test/session/capabilities_test.dart)`

Expected: FAIL: `Error: Type 'ThreadProvisioner' not found.`

- [ ] **Step 3: Implement the Thread flow**

Create `packages/esp_prov_core/lib/src/flows/thread_models.dart`:

```dart
import 'dart:typed_data';

/// A Thread network found by `ThreadProvisioner.scan`.
final class ThreadNetwork {
  /// Creates a scan result.
  const new({
    required this.panId,
    required this.channel,
    required this.rssi,
    required this.lqi,
    required this.extAddr,
    required this.networkName,
    required this.extPanId,
  });

  /// PAN ID.
  final int panId;

  /// IEEE 802.15.4 channel.
  final int channel;

  /// Signal strength in dBm.
  final int rssi;

  /// Link quality indicator.
  final int lqi;

  /// Extended address of the responding router.
  final Uint8List extAddr;

  /// Network name.
  final String networkName;

  /// Extended PAN ID.
  final Uint8List extPanId;
}

/// Why Thread provisioning ended without attaching.
enum ThreadFailureReason {
  /// The dataset was rejected (`ThreadAttachFailedReason.DatasetInvalid`).
  datasetInvalid,

  /// No matching network (`ThreadAttachFailedReason.ThreadNetworkNotFound`).
  networkNotFound,

  /// The device kept trying until `timeout` elapsed.
  timeout,

  /// The link dropped before the device reported `Attached`.
  deviceDisconnected,
}

/// Progress of `ThreadProvisioner.provision`.
sealed class ThreadProvisionState {
  const new();
}

/// The dataset is being sent and applied.
final class ThreadApplying extends ThreadProvisionState {
  /// Creates the state.
  const new();
}

/// The device is attaching to the network.
final class ThreadAttaching extends ThreadProvisionState {
  /// Creates the state.
  const new();
}

/// Terminal: the device attached.
final class ThreadAttached extends ThreadProvisionState {
  /// Creates the state.
  const new({
    required this.panId,
    required this.extPanId,
    required this.channel,
    required this.name,
  });

  /// PAN ID of the joined network.
  final int panId;

  /// Extended PAN ID of the joined network.
  final Uint8List extPanId;

  /// Channel of the joined network.
  final int channel;

  /// Name of the joined network.
  final String name;
}

/// Terminal: provisioning did not succeed.
final class ThreadFailed extends ThreadProvisionState {
  /// Creates the state.
  const new({required this.reason});

  /// Why it failed.
  final ThreadFailureReason reason;
}
```

Create `packages/esp_prov_core/lib/src/flows/thread_provisioner.dart`:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/flow_support.dart';
import 'package:esp_prov_core/src/flows/thread_models.dart';
import 'package:esp_prov_core/src/proto/network_config.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_constants.pb.dart' as pb;
import 'package:esp_prov_core/src/proto/network_scan.pb.dart' as pb;
import 'package:esp_prov_core/src/session/esp_session.dart';

/// Thread scan and provisioning (`network_provisioning` firmware only).
///
/// Obtain one from `EspSession.thread`.
final class ThreadProvisioner {
  /// Creates a provisioner. See `WifiProvisioner` for the scan parameters.
  new(
    this._session, {
    this.scanPollInterval = const Duration(milliseconds: 500),
    this.maxScanPolls = 60,
  });

  final EspSession _session;

  /// Delay between `CmdScanThreadStatus` polls.
  final Duration scanPollInterval;

  /// Status polls before [scan] gives up with [TransportException].
  final int maxScanPolls;

  /// Asks the device to scan for Thread networks, strongest first.
  Future<List<ThreadNetwork>> scan() async {
    final pages = await runNetworkScan(
      _session,
      start: pb.NetworkScanPayload(
        msg: pb.NetworkScanMsgType.TypeCmdScanThreadStart,
        cmdScanThreadStart: pb.CmdScanThreadStart(blocking: true),
      ),
      thread: true,
      pollInterval: scanPollInterval,
      maxPolls: maxScanPolls,
    );
    return [
      for (final page in pages)
        for (final e in page.respScanThreadResult.entries)
          ThreadNetwork(
            panId: e.panId,
            channel: e.channel,
            rssi: e.rssi,
            lqi: e.lqi,
            extAddr: Uint8List.fromList(e.extAddr),
            networkName: e.networkName,
            extPanId: Uint8List.fromList(e.extPanId),
          ),
    ]..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Sends an operational dataset (TLV bytes), applies it and polls until the
  /// device attaches or fails. Same stream contract as
  /// `WifiProvisioner.provision`.
  ///
  /// Throws [ArgumentError] immediately for an empty dataset or one longer
  /// than 254 bytes (the Thread maximum).
  Stream<ThreadProvisionState> provision({
    required Uint8List datasetTlvs,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(seconds: 1),
  }) {
    if (datasetTlvs.isEmpty || datasetTlvs.length > 254) {
      throw ArgumentError.value(
        datasetTlvs.length,
        'datasetTlvs',
        'must be 1 to 254 bytes',
      );
    }
    return _provision(datasetTlvs, timeout, pollInterval);
  }

  Stream<ThreadProvisionState> _provision(
    Uint8List dataset,
    Duration timeout,
    Duration pollInterval,
  ) async* {
    final disconnected = Completer<void>();
    final subscription = _session.onDisconnected.listen((_) {
      if (!disconnected.isCompleted) disconnected.complete();
    });
    try {
      yield const ThreadApplying();
      final set = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdSetThreadConfig,
          cmdSetThreadConfig: pb.CmdSetThreadConfig(dataset: dataset),
        ),
        pb.NetworkConfigMsgType.TypeRespSetThreadConfig,
      );
      checkStatus(set.respSetThreadConfig.status, 'Set Thread config');
      final apply = await configRequest(
        _session,
        pb.NetworkConfigPayload(
          msg: pb.NetworkConfigMsgType.TypeCmdApplyThreadConfig,
          cmdApplyThreadConfig: pb.CmdApplyThreadConfig(),
        ),
        pb.NetworkConfigMsgType.TypeRespApplyThreadConfig,
      );
      checkStatus(apply.respApplyThreadConfig.status, 'Apply Thread config');
      yield const ThreadAttaching();

      final clock = Stopwatch()..start();
      while (true) {
        final response = await configRequest(
          _session,
          pb.NetworkConfigPayload(
            msg: pb.NetworkConfigMsgType.TypeCmdGetThreadStatus,
            cmdGetThreadStatus: pb.CmdGetThreadStatus(),
          ),
          pb.NetworkConfigMsgType.TypeRespGetThreadStatus,
        );
        final status = response.respGetThreadStatus;
        checkStatus(status.status, 'Get Thread status');
        if (status.threadState == pb.ThreadNetworkState.Attached) {
          final a = status.threadAttached;
          yield ThreadAttached(
            panId: a.panId,
            extPanId: Uint8List.fromList(a.extPanId),
            channel: a.channel,
            name: a.name,
          );
          return;
        }
        if (status.threadState == pb.ThreadNetworkState.AttachingFailed) {
          yield ThreadFailed(
            reason:
                status.threadFailReason ==
                    pb.ThreadAttachFailedReason.DatasetInvalid
                ? ThreadFailureReason.datasetInvalid
                : ThreadFailureReason.networkNotFound,
          );
          return;
        }
        if (clock.elapsed >= timeout) {
          yield const ThreadFailed(reason: ThreadFailureReason.timeout);
          return;
        }
        if (await waitOrDisconnect(pollInterval, disconnected.future)) {
          yield const ThreadFailed(
            reason: ThreadFailureReason.deviceDisconnected,
          );
          return;
        }
      }
    } on DeviceDisconnected {
      yield const ThreadFailed(reason: ThreadFailureReason.deviceDisconnected);
    } finally {
      await subscription.cancel();
    }
  }
}
```

Replace the entire contents of `packages/esp_prov_core/lib/src/session/esp_session.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:esp_prov_core/src/errors/prov_exception.dart';
import 'package:esp_prov_core/src/flows/custom_endpoint.dart';
import 'package:esp_prov_core/src/flows/prov_ctrl.dart';
import 'package:esp_prov_core/src/flows/thread_provisioner.dart';
import 'package:esp_prov_core/src/flows/wifi_provisioner.dart';
import 'package:esp_prov_core/src/security/security_scheme.dart';
import 'package:esp_prov_core/src/session/device_info.dart';
import 'package:esp_prov_core/src/session/prov_credentials.dart';
import 'package:esp_prov_core/src/session/scheme_selector.dart';
import 'package:esp_prov_core/src/transport/prov_transport.dart';
import 'package:esp_prov_core/src/transport/serial_queue.dart';

/// An authenticated provisioning session with one device.
final class EspSession {
  new _(this._transport, this.info, this._scheme);

  /// Reads `proto-ver`, picks the security scheme the firmware declares,
  /// runs the handshake and returns the session.
  ///
  /// Throws [SchemeMismatch] or [MissingCredentials] when [credentials] do
  /// not fit the firmware, [PopMismatch] when the device rejects them, and
  /// [HandshakeFailed] for other handshake errors.
  static Future<EspSession> open(
    ProvTransport transport, {
    ProvCredentials? credentials,
  }) async {
    final info = transport.endpoints.contains(ProvEndpoints.protoVer)
        ? DeviceInfo.parse(
            utf8.decode(
              await transport.send(
                ProvEndpoints.protoVer,
                Uint8List.fromList(utf8.encode('---')),
              ),
              allowMalformed: true,
            ),
          )
        : DeviceInfo.parse('');
    final scheme = selectScheme(info, credentials);
    if (!transport.endpoints.contains(ProvEndpoints.session)) {
      throw UnknownEndpoint(ProvEndpoints.session);
    }
    await scheme.handshake(transport);
    return EspSession._(transport, info, scheme);
  }

  final ProvTransport _transport;
  final SecurityScheme _scheme;
  final SerialQueue _queue = SerialQueue();
  bool _closed = false;
  Object? _failure;
  WifiProvisioner? _wifi;
  ThreadProvisioner? _thread;
  ProvCtrl? _ctrl;

  /// Version and capabilities reported by the device.
  final DeviceInfo info;

  /// Security version in use (0, 1 or 2).
  int get securityVersion => _scheme.version;

  /// Endpoint names the transport discovered.
  Set<String> get endpoints => _transport.endpoints;

  /// Encrypts [body], sends it to [endpoint] and returns the decrypted
  /// response. Requests run one at a time, in call order.
  ///
  /// Security 1 and 2 ciphers are stateful, so after any failed request the
  /// device and this session disagree on cipher state. Later requests then
  /// throw [TransportException] and the caller must reconnect.
  Future<Uint8List> request(String endpoint, Uint8List body) =>
      _queue.run(() async {
        if (_closed) {
          throw const DeviceDisconnected('The session is closed.');
        }
        final failure = _failure;
        if (failure != null) {
          throw TransportException(
            'The session cannot be used after a failed request. '
            'Reconnect and open a new session.',
            cause: failure,
          );
        }
        if (!_transport.endpoints.contains(endpoint)) {
          throw UnknownEndpoint(endpoint);
        }
        final encrypted = await _scheme.encrypt(body);
        try {
          final response = await _transport.send(endpoint, encrypted);
          return await _scheme.decrypt(response);
        } on Object catch (e) {
          _failure = e;
          rethrow;
        }
      });

  /// Wi-Fi scan and provisioning.
  ///
  /// Throws [UnsupportedCapability] only when the firmware lists
  /// `thread_prov` without `wifi_prov` (a Thread-only device).
  WifiProvisioner get wifi {
    if (info.hasCapability('thread_prov') && !info.hasCapability('wifi_prov')) {
      throw UnsupportedCapability('wifi_prov');
    }
    return _wifi ??= WifiProvisioner(this);
  }

  /// Thread scan and provisioning. Requires the `thread_prov` capability.
  ThreadProvisioner get thread {
    if (!info.hasCapability('thread_prov')) {
      throw UnsupportedCapability('thread_prov');
    }
    return _thread ??= ThreadProvisioner(this);
  }

  /// Reset and re-provision commands on `prov-ctrl`.
  ProvCtrl get ctrl => _ctrl ??= ProvCtrl(this);

  /// An application endpoint registered by the firmware, e.g. `custom-data`.
  CustomEndpoint custom(String name) => CustomEndpoint(this, name);

  /// Emits once when the link drops.
  Stream<void> get onDisconnected => _transport.onDisconnected;

  /// Closes the session and the link. Safe to call more than once and after
  /// the device has already disconnected.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _transport.disconnect();
  }
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
export 'src/flows/custom_endpoint.dart';
export 'src/flows/prov_ctrl.dart';
export 'src/flows/thread_models.dart';
export 'src/flows/thread_provisioner.dart';
export 'src/flows/wifi_models.dart';
export 'src/flows/wifi_provisioner.dart';
export 'src/security/security_scheme.dart';
export 'src/session/device_info.dart';
export 'src/session/esp_session.dart';
export 'src/session/prov_credentials.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd packages/esp_prov_core && fvm dart test test/flows/thread_provisioner_test.dart test/session/capabilities_test.dart)`

Expected: `+5: All tests passed!`

- [ ] **Step 5: Analyze**

Run: `(cd packages/esp_prov_core && fvm dart analyze --fatal-infos) && fvm dart format --output=none --set-exit-if-changed packages`

Expected: `No issues found!` and `(0 changed)`.

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/flows/thread_provisioner_test.dart \
  packages/esp_prov_core/test/session/capabilities_test.dart \
  packages/esp_prov_core/lib/src/flows/thread_models.dart \
  packages/esp_prov_core/lib/src/flows/thread_provisioner.dart \
  packages/esp_prov_core/lib/src/session/esp_session.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): Thread provisioning and capability gates" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 3.6: ProvQrPayload

**Files:**
- Create: `packages/esp_prov_core/lib/src/qr/prov_qr_payload.dart`
- Modify: `packages/esp_prov_core/lib/esp_prov_core.dart`
- Test: `packages/esp_prov_core/test/qr/prov_qr_payload_test.dart`

**Interfaces:**
- Consumes: `ProvCredentials` (3.1).
- Produces: Exported: `final class ProvQrPayload { const new({required String version, required String name, required String transport, String? pop, String? username, String? password, int? security, String? network}); factory parse(String json); bool get isBle; ProvCredentials get credentials; }`.
`parse` throws `FormatException` for non-JSON, non-object or missing/empty `name`.

The stock ESP-IDF examples print
`{"ver":"v1","name":"PROV_XXXXXX","pop":"abcd1234","transport":"ble"}`
(Security 1) or
`{"ver":"v1","name":"PROV_XXXXXX","username":"wifiprov","pop":"abcd1234","transport":"ble"}`
(Security 2: the password travels in `pop`). Neither has a `security` key,
so `credentials` infers the kind: an explicit `security` wins; otherwise a
`username` means Security 2 with password `password ?? pop`, a lone `pop`
means Security 1, and nothing means none.

- [ ] **Step 1: Write the failing test**

Create `packages/esp_prov_core/test/qr/prov_qr_payload_test.dart`:

```dart
import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('stock Security 2 QR: password travels in "pop"', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov",'
      '"pop":"abcd1234","transport":"ble"}',
    );
    expect(qr.name, 'PROV_1A2B3C');
    expect(qr.isBle, isTrue);
    expect(qr.security, isNull);
    expect(
      qr.credentials,
      isA<ProvSecurity2Credentials>()
          .having((c) => c.username, 'username', 'wifiprov')
          .having((c) => c.password, 'password', 'abcd1234'),
    );
  });

  test('stock Security 1 QR gives a PoP', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","pop":"abcd1234","transport":"ble"}',
    );
    expect(
      qr.credentials,
      isA<ProvPopCredentials>().having((c) => c.pop, 'pop', 'abcd1234'),
    );
  });

  test('QR without secrets gives no credentials', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"PROV_1A2B3C","transport":"softap"}',
    );
    expect(qr.credentials, isA<ProvNoCredentials>());
    expect(qr.isBle, isFalse);
  });

  test('explicit security and password fields win', () {
    final qr = ProvQrPayload.parse(
      '{"ver":"v1","name":"P","security":2,"username":"u",'
      '"password":"secret","pop":"other","network":"thread"}',
    );
    expect(qr.security, 2);
    expect(qr.network, 'thread');
    expect((qr.credentials as ProvSecurity2Credentials).password, 'secret');
  });

  test('invalid payloads throw FormatException', () {
    expect(() => ProvQrPayload.parse('not json'), throwsFormatException);
    expect(() => ProvQrPayload.parse('[1,2]'), throwsFormatException);
    expect(
      () => ProvQrPayload.parse('{"ver":"v1","pop":"x"}'),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `(cd packages/esp_prov_core && fvm dart test test/qr/prov_qr_payload_test.dart)`

Expected: FAIL: `Error: Undefined name 'ProvQrPayload'.`

- [ ] **Step 3: Implement**

Create `packages/esp_prov_core/lib/src/qr/prov_qr_payload.dart`:

```dart
import 'dart:convert';

import 'package:esp_prov_core/src/session/prov_credentials.dart';

/// The JSON payload printed by provisioning firmware as a QR code, e.g.
/// `{"ver":"v1","name":"PROV_1A2B3C","username":"wifiprov","pop":"abcd1234",
/// "transport":"ble"}`.
final class ProvQrPayload {
  /// Creates a payload.
  const new({
    required this.version,
    required this.name,
    required this.transport,
    this.pop,
    this.username,
    this.password,
    this.security,
    this.network,
  });

  /// Parses the QR string. Throws [FormatException] when it is not a JSON
  /// object or has no non-empty `name`.
  factory parse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json.trim());
    } on FormatException catch (e) {
      throw FormatException('QR payload is not JSON: ${e.message}', json);
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('QR payload is not a JSON object', json);
    }
    final map = decoded;
    String? str(String key) => switch (map[key]) {
      final String v => v,
      _ => null,
    };

    final name = str('name');
    if (name == null || name.isEmpty) {
      throw FormatException('QR payload has no "name"', json);
    }
    final security = map['security'];
    return ProvQrPayload(
      version: str('ver') ?? 'v1',
      name: name,
      transport: str('transport') ?? 'ble',
      pop: str('pop'),
      username: str('username'),
      password: str('password'),
      security: switch (security) {
        final int v => v,
        final String v => int.tryParse(v),
        _ => null,
      },
      network: str('network'),
    );
  }

  /// Payload format version, usually `v1`.
  final String version;

  /// Advertised device name, e.g. `PROV_1A2B3C`.
  final String name;

  /// `ble` or `softap`.
  final String transport;

  /// Security 1 proof of possession, or the Security 2 password in the
  /// stock ESP-IDF examples.
  final String? pop;

  /// Security 2 username.
  final String? username;

  /// Security 2 password when given explicitly.
  final String? password;

  /// Explicit `security` field; the stock examples omit it.
  final int? security;

  /// `wifi` or `thread` when the firmware states it.
  final String? network;

  /// Whether the device should be reached over BLE.
  bool get isBle => transport.toLowerCase() == 'ble';

  /// Credentials implied by the payload.
  ///
  /// With an explicit [security] field: 0 gives none, 1 gives `pop`, 2 gives
  /// `security2`. Without it (stock examples) a `username` means Security 2
  /// with the password taken from `password` or else `pop`; a lone `pop`
  /// means Security 1; nothing means no credentials.
  ProvCredentials get credentials {
    final secret = password ?? pop ?? '';
    final kind = security ?? (username != null ? 2 : (pop != null ? 1 : 0));
    return switch (kind) {
      2 => ProvCredentials.security2(
        username: username ?? '',
        password: secret,
      ),
      1 => ProvCredentials.pop(pop ?? ''),
      _ => const ProvCredentials.none(),
    };
  }
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
export 'src/flows/custom_endpoint.dart';
export 'src/flows/prov_ctrl.dart';
export 'src/flows/thread_models.dart';
export 'src/flows/thread_provisioner.dart';
export 'src/flows/wifi_models.dart';
export 'src/flows/wifi_provisioner.dart';
export 'src/qr/prov_qr_payload.dart';
export 'src/security/security_scheme.dart';
export 'src/session/device_info.dart';
export 'src/session/esp_session.dart';
export 'src/session/prov_credentials.dart';
export 'src/transport/prov_transport.dart';
export 'src/transport/serial_queue.dart';
```

- [ ] **Step 4: Run the whole core suite**

Run: `(cd packages/esp_prov_core && fvm dart test )`

Expected: `+118: All tests passed!`

- [ ] **Step 5: Run the full check**

Run: `tool/check.sh`

Expected: `All checks passed.`

- [ ] **Step 6: Commit**

```bash
git add \
  packages/esp_prov_core/test/qr/prov_qr_payload_test.dart \
  packages/esp_prov_core/lib/src/qr/prov_qr_payload.dart \
  packages/esp_prov_core/lib/esp_prov_core.dart
git commit -m "feat(core): parse provisioning QR payloads" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
