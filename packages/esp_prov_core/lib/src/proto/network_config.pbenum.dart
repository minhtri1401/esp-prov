// This is a generated file - do not edit.
//
// Generated from network_config.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class NetworkConfigMsgType extends $pb.ProtobufEnum {
  static const NetworkConfigMsgType TypeCmdGetWifiStatus =
      NetworkConfigMsgType._(0, _omitEnumNames ? '' : 'TypeCmdGetWifiStatus');
  static const NetworkConfigMsgType TypeRespGetWifiStatus =
      NetworkConfigMsgType._(1, _omitEnumNames ? '' : 'TypeRespGetWifiStatus');
  static const NetworkConfigMsgType TypeCmdSetWifiConfig =
      NetworkConfigMsgType._(2, _omitEnumNames ? '' : 'TypeCmdSetWifiConfig');
  static const NetworkConfigMsgType TypeRespSetWifiConfig =
      NetworkConfigMsgType._(3, _omitEnumNames ? '' : 'TypeRespSetWifiConfig');
  static const NetworkConfigMsgType TypeCmdApplyWifiConfig =
      NetworkConfigMsgType._(4, _omitEnumNames ? '' : 'TypeCmdApplyWifiConfig');
  static const NetworkConfigMsgType TypeRespApplyWifiConfig =
      NetworkConfigMsgType._(
          5, _omitEnumNames ? '' : 'TypeRespApplyWifiConfig');
  static const NetworkConfigMsgType TypeCmdGetThreadStatus =
      NetworkConfigMsgType._(6, _omitEnumNames ? '' : 'TypeCmdGetThreadStatus');
  static const NetworkConfigMsgType TypeRespGetThreadStatus =
      NetworkConfigMsgType._(
          7, _omitEnumNames ? '' : 'TypeRespGetThreadStatus');
  static const NetworkConfigMsgType TypeCmdSetThreadConfig =
      NetworkConfigMsgType._(8, _omitEnumNames ? '' : 'TypeCmdSetThreadConfig');
  static const NetworkConfigMsgType TypeRespSetThreadConfig =
      NetworkConfigMsgType._(
          9, _omitEnumNames ? '' : 'TypeRespSetThreadConfig');
  static const NetworkConfigMsgType TypeCmdApplyThreadConfig =
      NetworkConfigMsgType._(
          10, _omitEnumNames ? '' : 'TypeCmdApplyThreadConfig');
  static const NetworkConfigMsgType TypeRespApplyThreadConfig =
      NetworkConfigMsgType._(
          11, _omitEnumNames ? '' : 'TypeRespApplyThreadConfig');

  static const $core.List<NetworkConfigMsgType> values = <NetworkConfigMsgType>[
    TypeCmdGetWifiStatus,
    TypeRespGetWifiStatus,
    TypeCmdSetWifiConfig,
    TypeRespSetWifiConfig,
    TypeCmdApplyWifiConfig,
    TypeRespApplyWifiConfig,
    TypeCmdGetThreadStatus,
    TypeRespGetThreadStatus,
    TypeCmdSetThreadConfig,
    TypeRespSetThreadConfig,
    TypeCmdApplyThreadConfig,
    TypeRespApplyThreadConfig,
  ];

  static final $core.List<NetworkConfigMsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static NetworkConfigMsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NetworkConfigMsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
