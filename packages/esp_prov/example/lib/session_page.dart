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
