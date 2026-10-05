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
