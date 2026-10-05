// This is a generated file - do not edit.
//
// Generated from network_ctrl.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class NetworkCtrlMsgType extends $pb.ProtobufEnum {
  static const NetworkCtrlMsgType TypeCtrlReserved =
      NetworkCtrlMsgType._(0, _omitEnumNames ? '' : 'TypeCtrlReserved');
  static const NetworkCtrlMsgType TypeCmdCtrlWifiReset =
      NetworkCtrlMsgType._(1, _omitEnumNames ? '' : 'TypeCmdCtrlWifiReset');
  static const NetworkCtrlMsgType TypeRespCtrlWifiReset =
      NetworkCtrlMsgType._(2, _omitEnumNames ? '' : 'TypeRespCtrlWifiReset');
  static const NetworkCtrlMsgType TypeCmdCtrlWifiReprov =
      NetworkCtrlMsgType._(3, _omitEnumNames ? '' : 'TypeCmdCtrlWifiReprov');
  static const NetworkCtrlMsgType TypeRespCtrlWifiReprov =
      NetworkCtrlMsgType._(4, _omitEnumNames ? '' : 'TypeRespCtrlWifiReprov');
  static const NetworkCtrlMsgType TypeCmdCtrlThreadReset =
      NetworkCtrlMsgType._(5, _omitEnumNames ? '' : 'TypeCmdCtrlThreadReset');
  static const NetworkCtrlMsgType TypeRespCtrlThreadReset =
      NetworkCtrlMsgType._(6, _omitEnumNames ? '' : 'TypeRespCtrlThreadReset');
  static const NetworkCtrlMsgType TypeCmdCtrlThreadReprov =
      NetworkCtrlMsgType._(7, _omitEnumNames ? '' : 'TypeCmdCtrlThreadReprov');
  static const NetworkCtrlMsgType TypeRespCtrlThreadReprov =
      NetworkCtrlMsgType._(8, _omitEnumNames ? '' : 'TypeRespCtrlThreadReprov');

  static const $core.List<NetworkCtrlMsgType> values = <NetworkCtrlMsgType>[
    TypeCtrlReserved,
    TypeCmdCtrlWifiReset,
    TypeRespCtrlWifiReset,
    TypeCmdCtrlWifiReprov,
    TypeRespCtrlWifiReprov,
    TypeCmdCtrlThreadReset,
    TypeRespCtrlThreadReset,
    TypeCmdCtrlThreadReprov,
    TypeRespCtrlThreadReprov,
  ];

  static final $core.List<NetworkCtrlMsgType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 8);
  static NetworkCtrlMsgType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const NetworkCtrlMsgType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
