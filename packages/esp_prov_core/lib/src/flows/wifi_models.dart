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

  /// The device made no progress for `timeout`.
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
