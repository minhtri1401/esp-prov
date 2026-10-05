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
