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

import 'network_constants.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'network_constants.pbenum.dart';

class WifiConnectedState extends $pb.GeneratedMessage {
  factory WifiConnectedState({
    $core.String? ip4Addr,
    WifiAuthMode? authMode,
    $core.List<$core.int>? ssid,
    $core.List<$core.int>? bssid,
    $core.int? channel,
  }) {
    final result = WifiConnectedState._();
    if (ip4Addr != null) result.ip4Addr = ip4Addr;
    if (authMode != null) result.authMode = authMode;
    if (ssid != null) result.ssid = ssid;
    if (bssid != null) result.bssid = bssid;
    if (channel != null) result.channel = channel;
    return result;
  }

  WifiConnectedState._();

  factory WifiConnectedState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WifiConnectedState()..mergeFromBuffer(data, registry);
  factory WifiConnectedState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WifiConnectedState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WifiConnectedState',
      createEmptyInstance: WifiConnectedState.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'ip4Addr')
    ..aE<WifiAuthMode>(2, _omitFieldNames ? '' : 'authMode',
        enumValues: WifiAuthMode.values)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'ssid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'bssid', $pb.PbFieldType.OY)
    ..aI(5, _omitFieldNames ? '' : 'channel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WifiConnectedState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WifiConnectedState copyWith(void Function(WifiConnectedState) updates) =>
      super.copyWith((message) => updates(message as WifiConnectedState))
          as WifiConnectedState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WifiConnectedState() / WifiConnectedState.new instead')
  static WifiConnectedState create() => WifiConnectedState._();
  static $pb.GeneratedMessage $_createMessage() => WifiConnectedState._();
  @$core.override
  WifiConnectedState createEmptyInstance() => WifiConnectedState._();
  @$core.pragma('dart2js:noInline')
  static WifiConnectedState getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WifiConnectedState>(
          WifiConnectedState.$_createMessage);
  static WifiConnectedState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get ip4Addr => $_getSZ(0);
  @$pb.TagNumber(1)
  set ip4Addr($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIp4Addr() => $_has(0);
  @$pb.TagNumber(1)
  void clearIp4Addr() => $_clearField(1);

  @$pb.TagNumber(2)
  WifiAuthMode get authMode => $_getN(1);
  @$pb.TagNumber(2)
  set authMode(WifiAuthMode value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthMode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get ssid => $_getN(2);
  @$pb.TagNumber(3)
  set ssid($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSsid() => $_has(2);
  @$pb.TagNumber(3)
  void clearSsid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get bssid => $_getN(3);
  @$pb.TagNumber(4)
  set bssid($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBssid() => $_has(3);
  @$pb.TagNumber(4)
  void clearBssid() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get channel => $_getIZ(4);
  @$pb.TagNumber(5)
  set channel($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChannel() => $_has(4);
  @$pb.TagNumber(5)
  void clearChannel() => $_clearField(5);
}

class WifiAttemptFailed extends $pb.GeneratedMessage {
  factory WifiAttemptFailed({
    $core.int? attemptsRemaining,
  }) {
    final result = WifiAttemptFailed._();
    if (attemptsRemaining != null) result.attemptsRemaining = attemptsRemaining;
    return result;
  }

  WifiAttemptFailed._();

  factory WifiAttemptFailed.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WifiAttemptFailed()..mergeFromBuffer(data, registry);
  factory WifiAttemptFailed.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WifiAttemptFailed()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WifiAttemptFailed',
      createEmptyInstance: WifiAttemptFailed.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'attemptsRemaining',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WifiAttemptFailed clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WifiAttemptFailed copyWith(void Function(WifiAttemptFailed) updates) =>
      super.copyWith((message) => updates(message as WifiAttemptFailed))
          as WifiAttemptFailed;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WifiAttemptFailed() / WifiAttemptFailed.new instead')
  static WifiAttemptFailed create() => WifiAttemptFailed._();
  static $pb.GeneratedMessage $_createMessage() => WifiAttemptFailed._();
  @$core.override
  WifiAttemptFailed createEmptyInstance() => WifiAttemptFailed._();
  @$core.pragma('dart2js:noInline')
  static WifiAttemptFailed getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WifiAttemptFailed>(
          WifiAttemptFailed.$_createMessage);
  static WifiAttemptFailed? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get attemptsRemaining => $_getIZ(0);
  @$pb.TagNumber(1)
  set attemptsRemaining($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAttemptsRemaining() => $_has(0);
  @$pb.TagNumber(1)
  void clearAttemptsRemaining() => $_clearField(1);
}

class ThreadAttachState extends $pb.GeneratedMessage {
  factory ThreadAttachState({
    $core.int? panId,
    $core.List<$core.int>? extPanId,
    $core.int? channel,
    $core.String? name,
  }) {
    final result = ThreadAttachState._();
    if (panId != null) result.panId = panId;
    if (extPanId != null) result.extPanId = extPanId;
    if (channel != null) result.channel = channel;
    if (name != null) result.name = name;
    return result;
  }

  ThreadAttachState._();

  factory ThreadAttachState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadAttachState()..mergeFromBuffer(data, registry);
  factory ThreadAttachState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadAttachState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadAttachState',
      createEmptyInstance: ThreadAttachState.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'panId', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'extPanId', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadAttachState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadAttachState copyWith(void Function(ThreadAttachState) updates) =>
      super.copyWith((message) => updates(message as ThreadAttachState))
          as ThreadAttachState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ThreadAttachState() / ThreadAttachState.new instead')
  static ThreadAttachState create() => ThreadAttachState._();
  static $pb.GeneratedMessage $_createMessage() => ThreadAttachState._();
  @$core.override
  ThreadAttachState createEmptyInstance() => ThreadAttachState._();
  @$core.pragma('dart2js:noInline')
  static ThreadAttachState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ThreadAttachState>(
          ThreadAttachState.$_createMessage);
  static ThreadAttachState? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get panId => $_getIZ(0);
  @$pb.TagNumber(1)
  set panId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPanId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get extPanId => $_getN(1);
  @$pb.TagNumber(2)
  set extPanId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExtPanId() => $_has(1);
  @$pb.TagNumber(2)
  void clearExtPanId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get channel => $_getIZ(2);
  @$pb.TagNumber(3)
  set channel($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChannel() => $_has(2);
  @$pb.TagNumber(3)
  void clearChannel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
