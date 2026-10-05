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
