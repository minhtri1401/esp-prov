// This is a generated file - do not edit.
//
// Generated from network_scan.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class NetworkScanMsgType extends $pb.ProtobufEnum {
  static const NetworkScanMsgType TypeCmdScanWifiStart =
      NetworkScanMsgType._(0, _omitEnumNames ? '' : 'TypeCmdScanWifiStart');
  static const NetworkScanMsgType TypeRespScanWifiStart =
      NetworkScanMsgType._(1, _omitEnumNames ? '' : 'TypeRespScanWifiStart');
  static const NetworkScanMsgType TypeCmdScanWifiStatus =
      NetworkScanMsgType._(2, _omitEnumNames ? '' : 'TypeCmdScanWifiStatus');
  static const NetworkScanMsgType TypeRespScanWifiStatus =
      NetworkScanMsgType._(3, _omitEnumNames ? '' : 'TypeRespScanWifiStatus');
  static const NetworkScanMsgType TypeCmdScanWifiResult =
      NetworkScanMsgType._(4, _omitEnumNames ? '' : 'TypeCmdScanWifiResult');
  static const NetworkScanMsgType TypeRespScanWifiResult =
      NetworkScanMsgType._(5, _omitEnumNames ? '' : 'TypeRespScanWifiResult');
  static const NetworkScanMsgType TypeCmdScanThreadStart =
      NetworkScanMsgType._(6, _omitEnumNames ? '' : 'TypeCmdScanThreadStart');
  static const NetworkScanMsgType TypeRespScanThreadStart =
      NetworkScanMsgType._(7, _omitEnumNames ? '' : 'TypeRespScanThreadStart');
  static const NetworkScanMsgType TypeCmdScanThreadStatus =
      NetworkScanMsgType._(8, _omitEnumNames ? '' : 'TypeCmdScanThreadStatus');
  static const NetworkScanMsgType TypeRespScanThreadStatus =
      NetworkScanMsgType._(9, _omitEnumNames ? '' : 'TypeRespScanThreadStatus');
  static const NetworkScanMsgType TypeCmdScanThreadResult =
      NetworkScanMsgType._(10, _omitEnumNames ? '' : 'TypeCmdScanThreadResult');
  static const NetworkScanMsgType TypeRespScanThreadResult =
      NetworkScanMsgType._(
          11, _omitEnumNames ? '' : 'TypeRespScanThreadResult');

  static const $core.List<NetworkScanMsgType> values = <NetworkScanMsgType>[
    TypeCmdScanWifiStart,
    TypeRespScanWifiStart,
    TypeCmdScanWifiStatus,
    TypeRespScanWifiStatus,
    TypeCmdScanWifiResult,
    TypeRespScanWifiResult,
    TypeCmdScanThreadStart,
    TypeRespScanThreadStart,
    TypeCmdScanThreadStatus,
    TypeRespScanThreadStatus,
    TypeCmdScanThreadResult,
    TypeRespScanThreadResult,
  ];

  static final $core.List<NetworkScanMsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static NetworkScanMsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NetworkScanMsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
