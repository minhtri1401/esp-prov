// This is a generated file - do not edit.
//
// Generated from network_constants.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class WifiStationState extends $pb.ProtobufEnum {
  static const WifiStationState Connected =
      WifiStationState._(0, _omitEnumNames ? '' : 'Connected');
  static const WifiStationState Connecting =
      WifiStationState._(1, _omitEnumNames ? '' : 'Connecting');
  static const WifiStationState Disconnected =
      WifiStationState._(2, _omitEnumNames ? '' : 'Disconnected');
  static const WifiStationState ConnectionFailed =
      WifiStationState._(3, _omitEnumNames ? '' : 'ConnectionFailed');

  static const $core.List<WifiStationState> values = <WifiStationState>[
    Connected,
    Connecting,
    Disconnected,
    ConnectionFailed,
  ];

  static final $core.List<WifiStationState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static WifiStationState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WifiStationState._(super.value, super.name);
}

class WifiConnectFailedReason extends $pb.ProtobufEnum {
  static const WifiConnectFailedReason AuthError =
      WifiConnectFailedReason._(0, _omitEnumNames ? '' : 'AuthError');
  static const WifiConnectFailedReason WifiNetworkNotFound =
      WifiConnectFailedReason._(1, _omitEnumNames ? '' : 'WifiNetworkNotFound');

  static const $core.List<WifiConnectFailedReason> values =
      <WifiConnectFailedReason>[
    AuthError,
    WifiNetworkNotFound,
  ];

  static final $core.List<WifiConnectFailedReason?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static WifiConnectFailedReason? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WifiConnectFailedReason._(super.value, super.name);
}

class WifiAuthMode extends $pb.ProtobufEnum {
  static const WifiAuthMode Open =
      WifiAuthMode._(0, _omitEnumNames ? '' : 'Open');
  static const WifiAuthMode WEP =
      WifiAuthMode._(1, _omitEnumNames ? '' : 'WEP');
  static const WifiAuthMode WPA_PSK =
      WifiAuthMode._(2, _omitEnumNames ? '' : 'WPA_PSK');
  static const WifiAuthMode WPA2_PSK =
      WifiAuthMode._(3, _omitEnumNames ? '' : 'WPA2_PSK');
  static const WifiAuthMode WPA_WPA2_PSK =
      WifiAuthMode._(4, _omitEnumNames ? '' : 'WPA_WPA2_PSK');
  static const WifiAuthMode WPA2_ENTERPRISE =
      WifiAuthMode._(5, _omitEnumNames ? '' : 'WPA2_ENTERPRISE');
  static const WifiAuthMode WPA3_PSK =
      WifiAuthMode._(6, _omitEnumNames ? '' : 'WPA3_PSK');
  static const WifiAuthMode WPA2_WPA3_PSK =
      WifiAuthMode._(7, _omitEnumNames ? '' : 'WPA2_WPA3_PSK');

  static const $core.List<WifiAuthMode> values = <WifiAuthMode>[
    Open,
    WEP,
    WPA_PSK,
    WPA2_PSK,
    WPA_WPA2_PSK,
    WPA2_ENTERPRISE,
    WPA3_PSK,
    WPA2_WPA3_PSK,
  ];

  static final $core.List<WifiAuthMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static WifiAuthMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const WifiAuthMode._(super.value, super.name);
}

class ThreadNetworkState extends $pb.ProtobufEnum {
  static const ThreadNetworkState Attached =
      ThreadNetworkState._(0, _omitEnumNames ? '' : 'Attached');
  static const ThreadNetworkState Attaching =
      ThreadNetworkState._(1, _omitEnumNames ? '' : 'Attaching');
  static const ThreadNetworkState Dettached =
      ThreadNetworkState._(2, _omitEnumNames ? '' : 'Dettached');
  static const ThreadNetworkState AttachingFailed =
      ThreadNetworkState._(3, _omitEnumNames ? '' : 'AttachingFailed');

  static const $core.List<ThreadNetworkState> values = <ThreadNetworkState>[
    Attached,
    Attaching,
    Dettached,
    AttachingFailed,
  ];

  static final $core.List<ThreadNetworkState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static ThreadNetworkState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ThreadNetworkState._(super.value, super.name);
}

class ThreadAttachFailedReason extends $pb.ProtobufEnum {
  static const ThreadAttachFailedReason DatasetInvalid =
      ThreadAttachFailedReason._(0, _omitEnumNames ? '' : 'DatasetInvalid');
  static const ThreadAttachFailedReason ThreadNetworkNotFound =
      ThreadAttachFailedReason._(
          1, _omitEnumNames ? '' : 'ThreadNetworkNotFound');

  static const $core.List<ThreadAttachFailedReason> values =
      <ThreadAttachFailedReason>[
    DatasetInvalid,
    ThreadNetworkNotFound,
  ];

  static final $core.List<ThreadAttachFailedReason?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static ThreadAttachFailedReason? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ThreadAttachFailedReason._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
