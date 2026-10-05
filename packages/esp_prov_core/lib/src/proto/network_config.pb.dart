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

import 'constants.pbenum.dart' as $1;
import 'network_config.pbenum.dart';
import 'network_constants.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'network_config.pbenum.dart';

class CmdGetWifiStatus extends $pb.GeneratedMessage {
  factory CmdGetWifiStatus() => CmdGetWifiStatus._();

  CmdGetWifiStatus._();

  factory CmdGetWifiStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdGetWifiStatus()..mergeFromBuffer(data, registry);
  factory CmdGetWifiStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdGetWifiStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdGetWifiStatus',
      createEmptyInstance: CmdGetWifiStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdGetWifiStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdGetWifiStatus copyWith(void Function(CmdGetWifiStatus) updates) =>
      super.copyWith((message) => updates(message as CmdGetWifiStatus))
          as CmdGetWifiStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdGetWifiStatus() / CmdGetWifiStatus.new instead')
  static CmdGetWifiStatus create() => CmdGetWifiStatus._();
  static $pb.GeneratedMessage $_createMessage() => CmdGetWifiStatus._();
  @$core.override
  CmdGetWifiStatus createEmptyInstance() => CmdGetWifiStatus._();
  @$core.pragma('dart2js:noInline')
  static CmdGetWifiStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CmdGetWifiStatus>(
          CmdGetWifiStatus.$_createMessage);
  static CmdGetWifiStatus? _defaultInstance;
}

enum RespGetWifiStatus_State {
  wifiFailReason,
  wifiConnected,
  attemptFailed,
  notSet
}

class RespGetWifiStatus extends $pb.GeneratedMessage {
  factory RespGetWifiStatus({
    $1.Status? status,
    $0.WifiStationState? wifiStaState,
    $0.WifiConnectFailedReason? wifiFailReason,
    $0.WifiConnectedState? wifiConnected,
    $0.WifiAttemptFailed? attemptFailed,
  }) {
    final result = RespGetWifiStatus._();
    if (status != null) result.status = status;
    if (wifiStaState != null) result.wifiStaState = wifiStaState;
    if (wifiFailReason != null) result.wifiFailReason = wifiFailReason;
    if (wifiConnected != null) result.wifiConnected = wifiConnected;
    if (attemptFailed != null) result.attemptFailed = attemptFailed;
    return result;
  }

  RespGetWifiStatus._();

  factory RespGetWifiStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespGetWifiStatus()..mergeFromBuffer(data, registry);
  factory RespGetWifiStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespGetWifiStatus()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RespGetWifiStatus_State>
      _RespGetWifiStatus_StateByTag = {
    10: RespGetWifiStatus_State.wifiFailReason,
    11: RespGetWifiStatus_State.wifiConnected,
    12: RespGetWifiStatus_State.attemptFailed,
    0: RespGetWifiStatus_State.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespGetWifiStatus',
      createEmptyInstance: RespGetWifiStatus.$_createMessage)
    ..oo(0, [10, 11, 12])
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..aE<$0.WifiStationState>(2, _omitFieldNames ? '' : 'wifiStaState',
        enumValues: $0.WifiStationState.values)
    ..aE<$0.WifiConnectFailedReason>(
        10, _omitFieldNames ? '' : 'wifiFailReason',
        enumValues: $0.WifiConnectFailedReason.values)
    ..aOM<$0.WifiConnectedState>(11, _omitFieldNames ? '' : 'wifiConnected',
        subBuilder: $0.WifiConnectedState.$_createMessage)
    ..aOM<$0.WifiAttemptFailed>(12, _omitFieldNames ? '' : 'attemptFailed',
        subBuilder: $0.WifiAttemptFailed.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespGetWifiStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespGetWifiStatus copyWith(void Function(RespGetWifiStatus) updates) =>
      super.copyWith((message) => updates(message as RespGetWifiStatus))
          as RespGetWifiStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RespGetWifiStatus() / RespGetWifiStatus.new instead')
  static RespGetWifiStatus create() => RespGetWifiStatus._();
  static $pb.GeneratedMessage $_createMessage() => RespGetWifiStatus._();
  @$core.override
  RespGetWifiStatus createEmptyInstance() => RespGetWifiStatus._();
  @$core.pragma('dart2js:noInline')
  static RespGetWifiStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RespGetWifiStatus>(
          RespGetWifiStatus.$_createMessage);
  static RespGetWifiStatus? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  RespGetWifiStatus_State whichState() =>
      _RespGetWifiStatus_StateByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  void clearState() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.WifiStationState get wifiStaState => $_getN(1);
  @$pb.TagNumber(2)
  set wifiStaState($0.WifiStationState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasWifiStaState() => $_has(1);
  @$pb.TagNumber(2)
  void clearWifiStaState() => $_clearField(2);

  @$pb.TagNumber(10)
  $0.WifiConnectFailedReason get wifiFailReason => $_getN(2);
  @$pb.TagNumber(10)
  set wifiFailReason($0.WifiConnectFailedReason value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasWifiFailReason() => $_has(2);
  @$pb.TagNumber(10)
  void clearWifiFailReason() => $_clearField(10);

  @$pb.TagNumber(11)
  $0.WifiConnectedState get wifiConnected => $_getN(3);
  @$pb.TagNumber(11)
  set wifiConnected($0.WifiConnectedState value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasWifiConnected() => $_has(3);
  @$pb.TagNumber(11)
  void clearWifiConnected() => $_clearField(11);
  @$pb.TagNumber(11)
  $0.WifiConnectedState ensureWifiConnected() => $_ensure(3);

  @$pb.TagNumber(12)
  $0.WifiAttemptFailed get attemptFailed => $_getN(4);
  @$pb.TagNumber(12)
  set attemptFailed($0.WifiAttemptFailed value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasAttemptFailed() => $_has(4);
  @$pb.TagNumber(12)
  void clearAttemptFailed() => $_clearField(12);
  @$pb.TagNumber(12)
  $0.WifiAttemptFailed ensureAttemptFailed() => $_ensure(4);
}

class CmdGetThreadStatus extends $pb.GeneratedMessage {
  factory CmdGetThreadStatus() => CmdGetThreadStatus._();

  CmdGetThreadStatus._();

  factory CmdGetThreadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdGetThreadStatus()..mergeFromBuffer(data, registry);
  factory CmdGetThreadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdGetThreadStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdGetThreadStatus',
      createEmptyInstance: CmdGetThreadStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdGetThreadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdGetThreadStatus copyWith(void Function(CmdGetThreadStatus) updates) =>
      super.copyWith((message) => updates(message as CmdGetThreadStatus))
          as CmdGetThreadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdGetThreadStatus() / CmdGetThreadStatus.new instead')
  static CmdGetThreadStatus create() => CmdGetThreadStatus._();
  static $pb.GeneratedMessage $_createMessage() => CmdGetThreadStatus._();
  @$core.override
  CmdGetThreadStatus createEmptyInstance() => CmdGetThreadStatus._();
  @$core.pragma('dart2js:noInline')
  static CmdGetThreadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdGetThreadStatus>(
          CmdGetThreadStatus.$_createMessage);
  static CmdGetThreadStatus? _defaultInstance;
}

enum RespGetThreadStatus_State { threadFailReason, threadAttached, notSet }

class RespGetThreadStatus extends $pb.GeneratedMessage {
  factory RespGetThreadStatus({
    $1.Status? status,
    $0.ThreadNetworkState? threadState,
    $0.ThreadAttachFailedReason? threadFailReason,
    $0.ThreadAttachState? threadAttached,
  }) {
    final result = RespGetThreadStatus._();
    if (status != null) result.status = status;
    if (threadState != null) result.threadState = threadState;
    if (threadFailReason != null) result.threadFailReason = threadFailReason;
    if (threadAttached != null) result.threadAttached = threadAttached;
    return result;
  }

  RespGetThreadStatus._();

  factory RespGetThreadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespGetThreadStatus()..mergeFromBuffer(data, registry);
  factory RespGetThreadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespGetThreadStatus()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RespGetThreadStatus_State>
      _RespGetThreadStatus_StateByTag = {
    10: RespGetThreadStatus_State.threadFailReason,
    11: RespGetThreadStatus_State.threadAttached,
    0: RespGetThreadStatus_State.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespGetThreadStatus',
      createEmptyInstance: RespGetThreadStatus.$_createMessage)
    ..oo(0, [10, 11])
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..aE<$0.ThreadNetworkState>(2, _omitFieldNames ? '' : 'threadState',
        enumValues: $0.ThreadNetworkState.values)
    ..aE<$0.ThreadAttachFailedReason>(
        10, _omitFieldNames ? '' : 'threadFailReason',
        enumValues: $0.ThreadAttachFailedReason.values)
    ..aOM<$0.ThreadAttachState>(11, _omitFieldNames ? '' : 'threadAttached',
        subBuilder: $0.ThreadAttachState.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespGetThreadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespGetThreadStatus copyWith(void Function(RespGetThreadStatus) updates) =>
      super.copyWith((message) => updates(message as RespGetThreadStatus))
          as RespGetThreadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RespGetThreadStatus() / RespGetThreadStatus.new instead')
  static RespGetThreadStatus create() => RespGetThreadStatus._();
  static $pb.GeneratedMessage $_createMessage() => RespGetThreadStatus._();
  @$core.override
  RespGetThreadStatus createEmptyInstance() => RespGetThreadStatus._();
  @$core.pragma('dart2js:noInline')
  static RespGetThreadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespGetThreadStatus>(
          RespGetThreadStatus.$_createMessage);
  static RespGetThreadStatus? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  RespGetThreadStatus_State whichState() =>
      _RespGetThreadStatus_StateByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  void clearState() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $0.ThreadNetworkState get threadState => $_getN(1);
  @$pb.TagNumber(2)
  set threadState($0.ThreadNetworkState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasThreadState() => $_has(1);
  @$pb.TagNumber(2)
  void clearThreadState() => $_clearField(2);

  @$pb.TagNumber(10)
  $0.ThreadAttachFailedReason get threadFailReason => $_getN(2);
  @$pb.TagNumber(10)
  set threadFailReason($0.ThreadAttachFailedReason value) =>
      $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasThreadFailReason() => $_has(2);
  @$pb.TagNumber(10)
  void clearThreadFailReason() => $_clearField(10);

  @$pb.TagNumber(11)
  $0.ThreadAttachState get threadAttached => $_getN(3);
  @$pb.TagNumber(11)
  set threadAttached($0.ThreadAttachState value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasThreadAttached() => $_has(3);
  @$pb.TagNumber(11)
  void clearThreadAttached() => $_clearField(11);
  @$pb.TagNumber(11)
  $0.ThreadAttachState ensureThreadAttached() => $_ensure(3);
}

class CmdSetWifiConfig extends $pb.GeneratedMessage {
  factory CmdSetWifiConfig({
    $core.List<$core.int>? ssid,
    $core.List<$core.int>? passphrase,
    $core.List<$core.int>? bssid,
    $core.int? channel,
  }) {
    final result = CmdSetWifiConfig._();
    if (ssid != null) result.ssid = ssid;
    if (passphrase != null) result.passphrase = passphrase;
    if (bssid != null) result.bssid = bssid;
    if (channel != null) result.channel = channel;
    return result;
  }

  CmdSetWifiConfig._();

  factory CmdSetWifiConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdSetWifiConfig()..mergeFromBuffer(data, registry);
  factory CmdSetWifiConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdSetWifiConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdSetWifiConfig',
      createEmptyInstance: CmdSetWifiConfig.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'ssid', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'passphrase', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'bssid', $pb.PbFieldType.OY)
    ..aI(4, _omitFieldNames ? '' : 'channel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdSetWifiConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdSetWifiConfig copyWith(void Function(CmdSetWifiConfig) updates) =>
      super.copyWith((message) => updates(message as CmdSetWifiConfig))
          as CmdSetWifiConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdSetWifiConfig() / CmdSetWifiConfig.new instead')
  static CmdSetWifiConfig create() => CmdSetWifiConfig._();
  static $pb.GeneratedMessage $_createMessage() => CmdSetWifiConfig._();
  @$core.override
  CmdSetWifiConfig createEmptyInstance() => CmdSetWifiConfig._();
  @$core.pragma('dart2js:noInline')
  static CmdSetWifiConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CmdSetWifiConfig>(
          CmdSetWifiConfig.$_createMessage);
  static CmdSetWifiConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get ssid => $_getN(0);
  @$pb.TagNumber(1)
  set ssid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSsid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSsid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get passphrase => $_getN(1);
  @$pb.TagNumber(2)
  set passphrase($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassphrase() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassphrase() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get bssid => $_getN(2);
  @$pb.TagNumber(3)
  set bssid($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBssid() => $_has(2);
  @$pb.TagNumber(3)
  void clearBssid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get channel => $_getIZ(3);
  @$pb.TagNumber(4)
  set channel($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChannel() => $_has(3);
  @$pb.TagNumber(4)
  void clearChannel() => $_clearField(4);
}

class CmdSetThreadConfig extends $pb.GeneratedMessage {
  factory CmdSetThreadConfig({
    $core.List<$core.int>? dataset,
  }) {
    final result = CmdSetThreadConfig._();
    if (dataset != null) result.dataset = dataset;
    return result;
  }

  CmdSetThreadConfig._();

  factory CmdSetThreadConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdSetThreadConfig()..mergeFromBuffer(data, registry);
  factory CmdSetThreadConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdSetThreadConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdSetThreadConfig',
      createEmptyInstance: CmdSetThreadConfig.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'dataset', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdSetThreadConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdSetThreadConfig copyWith(void Function(CmdSetThreadConfig) updates) =>
      super.copyWith((message) => updates(message as CmdSetThreadConfig))
          as CmdSetThreadConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdSetThreadConfig() / CmdSetThreadConfig.new instead')
  static CmdSetThreadConfig create() => CmdSetThreadConfig._();
  static $pb.GeneratedMessage $_createMessage() => CmdSetThreadConfig._();
  @$core.override
  CmdSetThreadConfig createEmptyInstance() => CmdSetThreadConfig._();
  @$core.pragma('dart2js:noInline')
  static CmdSetThreadConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdSetThreadConfig>(
          CmdSetThreadConfig.$_createMessage);
  static CmdSetThreadConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get dataset => $_getN(0);
  @$pb.TagNumber(1)
  set dataset($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDataset() => $_has(0);
  @$pb.TagNumber(1)
  void clearDataset() => $_clearField(1);
}

class RespSetWifiConfig extends $pb.GeneratedMessage {
  factory RespSetWifiConfig({
    $1.Status? status,
  }) {
    final result = RespSetWifiConfig._();
    if (status != null) result.status = status;
    return result;
  }

  RespSetWifiConfig._();

  factory RespSetWifiConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespSetWifiConfig()..mergeFromBuffer(data, registry);
  factory RespSetWifiConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespSetWifiConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespSetWifiConfig',
      createEmptyInstance: RespSetWifiConfig.$_createMessage)
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespSetWifiConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespSetWifiConfig copyWith(void Function(RespSetWifiConfig) updates) =>
      super.copyWith((message) => updates(message as RespSetWifiConfig))
          as RespSetWifiConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RespSetWifiConfig() / RespSetWifiConfig.new instead')
  static RespSetWifiConfig create() => RespSetWifiConfig._();
  static $pb.GeneratedMessage $_createMessage() => RespSetWifiConfig._();
  @$core.override
  RespSetWifiConfig createEmptyInstance() => RespSetWifiConfig._();
  @$core.pragma('dart2js:noInline')
  static RespSetWifiConfig getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RespSetWifiConfig>(
          RespSetWifiConfig.$_createMessage);
  static RespSetWifiConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

class RespSetThreadConfig extends $pb.GeneratedMessage {
  factory RespSetThreadConfig({
    $1.Status? status,
  }) {
    final result = RespSetThreadConfig._();
    if (status != null) result.status = status;
    return result;
  }

  RespSetThreadConfig._();

  factory RespSetThreadConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespSetThreadConfig()..mergeFromBuffer(data, registry);
  factory RespSetThreadConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespSetThreadConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespSetThreadConfig',
      createEmptyInstance: RespSetThreadConfig.$_createMessage)
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespSetThreadConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespSetThreadConfig copyWith(void Function(RespSetThreadConfig) updates) =>
      super.copyWith((message) => updates(message as RespSetThreadConfig))
          as RespSetThreadConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RespSetThreadConfig() / RespSetThreadConfig.new instead')
  static RespSetThreadConfig create() => RespSetThreadConfig._();
  static $pb.GeneratedMessage $_createMessage() => RespSetThreadConfig._();
  @$core.override
  RespSetThreadConfig createEmptyInstance() => RespSetThreadConfig._();
  @$core.pragma('dart2js:noInline')
  static RespSetThreadConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespSetThreadConfig>(
          RespSetThreadConfig.$_createMessage);
  static RespSetThreadConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

class CmdApplyWifiConfig extends $pb.GeneratedMessage {
  factory CmdApplyWifiConfig() => CmdApplyWifiConfig._();

  CmdApplyWifiConfig._();

  factory CmdApplyWifiConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdApplyWifiConfig()..mergeFromBuffer(data, registry);
  factory CmdApplyWifiConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdApplyWifiConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdApplyWifiConfig',
      createEmptyInstance: CmdApplyWifiConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdApplyWifiConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdApplyWifiConfig copyWith(void Function(CmdApplyWifiConfig) updates) =>
      super.copyWith((message) => updates(message as CmdApplyWifiConfig))
          as CmdApplyWifiConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdApplyWifiConfig() / CmdApplyWifiConfig.new instead')
  static CmdApplyWifiConfig create() => CmdApplyWifiConfig._();
  static $pb.GeneratedMessage $_createMessage() => CmdApplyWifiConfig._();
  @$core.override
  CmdApplyWifiConfig createEmptyInstance() => CmdApplyWifiConfig._();
  @$core.pragma('dart2js:noInline')
  static CmdApplyWifiConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdApplyWifiConfig>(
          CmdApplyWifiConfig.$_createMessage);
  static CmdApplyWifiConfig? _defaultInstance;
}

class CmdApplyThreadConfig extends $pb.GeneratedMessage {
  factory CmdApplyThreadConfig() => CmdApplyThreadConfig._();

  CmdApplyThreadConfig._();

  factory CmdApplyThreadConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdApplyThreadConfig()..mergeFromBuffer(data, registry);
  factory CmdApplyThreadConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdApplyThreadConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdApplyThreadConfig',
      createEmptyInstance: CmdApplyThreadConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdApplyThreadConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdApplyThreadConfig copyWith(void Function(CmdApplyThreadConfig) updates) =>
      super.copyWith((message) => updates(message as CmdApplyThreadConfig))
          as CmdApplyThreadConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CmdApplyThreadConfig() / CmdApplyThreadConfig.new instead')
  static CmdApplyThreadConfig create() => CmdApplyThreadConfig._();
  static $pb.GeneratedMessage $_createMessage() => CmdApplyThreadConfig._();
  @$core.override
  CmdApplyThreadConfig createEmptyInstance() => CmdApplyThreadConfig._();
  @$core.pragma('dart2js:noInline')
  static CmdApplyThreadConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdApplyThreadConfig>(
          CmdApplyThreadConfig.$_createMessage);
  static CmdApplyThreadConfig? _defaultInstance;
}

class RespApplyWifiConfig extends $pb.GeneratedMessage {
  factory RespApplyWifiConfig({
    $1.Status? status,
  }) {
    final result = RespApplyWifiConfig._();
    if (status != null) result.status = status;
    return result;
  }

  RespApplyWifiConfig._();

  factory RespApplyWifiConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespApplyWifiConfig()..mergeFromBuffer(data, registry);
  factory RespApplyWifiConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespApplyWifiConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespApplyWifiConfig',
      createEmptyInstance: RespApplyWifiConfig.$_createMessage)
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespApplyWifiConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespApplyWifiConfig copyWith(void Function(RespApplyWifiConfig) updates) =>
      super.copyWith((message) => updates(message as RespApplyWifiConfig))
          as RespApplyWifiConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RespApplyWifiConfig() / RespApplyWifiConfig.new instead')
  static RespApplyWifiConfig create() => RespApplyWifiConfig._();
  static $pb.GeneratedMessage $_createMessage() => RespApplyWifiConfig._();
  @$core.override
  RespApplyWifiConfig createEmptyInstance() => RespApplyWifiConfig._();
  @$core.pragma('dart2js:noInline')
  static RespApplyWifiConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespApplyWifiConfig>(
          RespApplyWifiConfig.$_createMessage);
  static RespApplyWifiConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

class RespApplyThreadConfig extends $pb.GeneratedMessage {
  factory RespApplyThreadConfig({
    $1.Status? status,
  }) {
    final result = RespApplyThreadConfig._();
    if (status != null) result.status = status;
    return result;
  }

  RespApplyThreadConfig._();

  factory RespApplyThreadConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespApplyThreadConfig()..mergeFromBuffer(data, registry);
  factory RespApplyThreadConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespApplyThreadConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespApplyThreadConfig',
      createEmptyInstance: RespApplyThreadConfig.$_createMessage)
    ..aE<$1.Status>(1, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespApplyThreadConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespApplyThreadConfig copyWith(
          void Function(RespApplyThreadConfig) updates) =>
      super.copyWith((message) => updates(message as RespApplyThreadConfig))
          as RespApplyThreadConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RespApplyThreadConfig() / RespApplyThreadConfig.new instead')
  static RespApplyThreadConfig create() => RespApplyThreadConfig._();
  static $pb.GeneratedMessage $_createMessage() => RespApplyThreadConfig._();
  @$core.override
  RespApplyThreadConfig createEmptyInstance() => RespApplyThreadConfig._();
  @$core.pragma('dart2js:noInline')
  static RespApplyThreadConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespApplyThreadConfig>(
          RespApplyThreadConfig.$_createMessage);
  static RespApplyThreadConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Status get status => $_getN(0);
  @$pb.TagNumber(1)
  set status($1.Status value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

enum NetworkConfigPayload_Payload {
  cmdGetWifiStatus,
  respGetWifiStatus,
  cmdSetWifiConfig,
  respSetWifiConfig,
  cmdApplyWifiConfig,
  respApplyWifiConfig,
  cmdGetThreadStatus,
  respGetThreadStatus,
  cmdSetThreadConfig,
  respSetThreadConfig,
  cmdApplyThreadConfig,
  respApplyThreadConfig,
  notSet
}

class NetworkConfigPayload extends $pb.GeneratedMessage {
  factory NetworkConfigPayload({
    NetworkConfigMsgType? msg,
    CmdGetWifiStatus? cmdGetWifiStatus,
    RespGetWifiStatus? respGetWifiStatus,
    CmdSetWifiConfig? cmdSetWifiConfig,
    RespSetWifiConfig? respSetWifiConfig,
    CmdApplyWifiConfig? cmdApplyWifiConfig,
    RespApplyWifiConfig? respApplyWifiConfig,
    CmdGetThreadStatus? cmdGetThreadStatus,
    RespGetThreadStatus? respGetThreadStatus,
    CmdSetThreadConfig? cmdSetThreadConfig,
    RespSetThreadConfig? respSetThreadConfig,
    CmdApplyThreadConfig? cmdApplyThreadConfig,
    RespApplyThreadConfig? respApplyThreadConfig,
  }) {
    final result = NetworkConfigPayload._();
    if (msg != null) result.msg = msg;
    if (cmdGetWifiStatus != null) result.cmdGetWifiStatus = cmdGetWifiStatus;
    if (respGetWifiStatus != null) result.respGetWifiStatus = respGetWifiStatus;
    if (cmdSetWifiConfig != null) result.cmdSetWifiConfig = cmdSetWifiConfig;
    if (respSetWifiConfig != null) result.respSetWifiConfig = respSetWifiConfig;
    if (cmdApplyWifiConfig != null)
      result.cmdApplyWifiConfig = cmdApplyWifiConfig;
    if (respApplyWifiConfig != null)
      result.respApplyWifiConfig = respApplyWifiConfig;
    if (cmdGetThreadStatus != null)
      result.cmdGetThreadStatus = cmdGetThreadStatus;
    if (respGetThreadStatus != null)
      result.respGetThreadStatus = respGetThreadStatus;
    if (cmdSetThreadConfig != null)
      result.cmdSetThreadConfig = cmdSetThreadConfig;
    if (respSetThreadConfig != null)
      result.respSetThreadConfig = respSetThreadConfig;
    if (cmdApplyThreadConfig != null)
      result.cmdApplyThreadConfig = cmdApplyThreadConfig;
    if (respApplyThreadConfig != null)
      result.respApplyThreadConfig = respApplyThreadConfig;
    return result;
  }

  NetworkConfigPayload._();

  factory NetworkConfigPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NetworkConfigPayload()..mergeFromBuffer(data, registry);
  factory NetworkConfigPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NetworkConfigPayload()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, NetworkConfigPayload_Payload>
      _NetworkConfigPayload_PayloadByTag = {
    10: NetworkConfigPayload_Payload.cmdGetWifiStatus,
    11: NetworkConfigPayload_Payload.respGetWifiStatus,
    12: NetworkConfigPayload_Payload.cmdSetWifiConfig,
    13: NetworkConfigPayload_Payload.respSetWifiConfig,
    14: NetworkConfigPayload_Payload.cmdApplyWifiConfig,
    15: NetworkConfigPayload_Payload.respApplyWifiConfig,
    16: NetworkConfigPayload_Payload.cmdGetThreadStatus,
    17: NetworkConfigPayload_Payload.respGetThreadStatus,
    18: NetworkConfigPayload_Payload.cmdSetThreadConfig,
    19: NetworkConfigPayload_Payload.respSetThreadConfig,
    20: NetworkConfigPayload_Payload.cmdApplyThreadConfig,
    21: NetworkConfigPayload_Payload.respApplyThreadConfig,
    0: NetworkConfigPayload_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkConfigPayload',
      createEmptyInstance: NetworkConfigPayload.$_createMessage)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21])
    ..aE<NetworkConfigMsgType>(1, _omitFieldNames ? '' : 'msg',
        enumValues: NetworkConfigMsgType.values)
    ..aOM<CmdGetWifiStatus>(10, _omitFieldNames ? '' : 'cmdGetWifiStatus',
        subBuilder: CmdGetWifiStatus.$_createMessage)
    ..aOM<RespGetWifiStatus>(11, _omitFieldNames ? '' : 'respGetWifiStatus',
        subBuilder: RespGetWifiStatus.$_createMessage)
    ..aOM<CmdSetWifiConfig>(12, _omitFieldNames ? '' : 'cmdSetWifiConfig',
        subBuilder: CmdSetWifiConfig.$_createMessage)
    ..aOM<RespSetWifiConfig>(13, _omitFieldNames ? '' : 'respSetWifiConfig',
        subBuilder: RespSetWifiConfig.$_createMessage)
    ..aOM<CmdApplyWifiConfig>(14, _omitFieldNames ? '' : 'cmdApplyWifiConfig',
        subBuilder: CmdApplyWifiConfig.$_createMessage)
    ..aOM<RespApplyWifiConfig>(15, _omitFieldNames ? '' : 'respApplyWifiConfig',
        subBuilder: RespApplyWifiConfig.$_createMessage)
    ..aOM<CmdGetThreadStatus>(16, _omitFieldNames ? '' : 'cmdGetThreadStatus',
        subBuilder: CmdGetThreadStatus.$_createMessage)
    ..aOM<RespGetThreadStatus>(17, _omitFieldNames ? '' : 'respGetThreadStatus',
        subBuilder: RespGetThreadStatus.$_createMessage)
    ..aOM<CmdSetThreadConfig>(18, _omitFieldNames ? '' : 'cmdSetThreadConfig',
        subBuilder: CmdSetThreadConfig.$_createMessage)
    ..aOM<RespSetThreadConfig>(19, _omitFieldNames ? '' : 'respSetThreadConfig',
        subBuilder: RespSetThreadConfig.$_createMessage)
    ..aOM<CmdApplyThreadConfig>(
        20, _omitFieldNames ? '' : 'cmdApplyThreadConfig',
        subBuilder: CmdApplyThreadConfig.$_createMessage)
    ..aOM<RespApplyThreadConfig>(
        21, _omitFieldNames ? '' : 'respApplyThreadConfig',
        subBuilder: RespApplyThreadConfig.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkConfigPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkConfigPayload copyWith(void Function(NetworkConfigPayload) updates) =>
      super.copyWith((message) => updates(message as NetworkConfigPayload))
          as NetworkConfigPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use NetworkConfigPayload() / NetworkConfigPayload.new instead')
  static NetworkConfigPayload create() => NetworkConfigPayload._();
  static $pb.GeneratedMessage $_createMessage() => NetworkConfigPayload._();
  @$core.override
  NetworkConfigPayload createEmptyInstance() => NetworkConfigPayload._();
  @$core.pragma('dart2js:noInline')
  static NetworkConfigPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkConfigPayload>(
          NetworkConfigPayload.$_createMessage);
  static NetworkConfigPayload? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  NetworkConfigPayload_Payload whichPayload() =>
      _NetworkConfigPayload_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  NetworkConfigMsgType get msg => $_getN(0);
  @$pb.TagNumber(1)
  set msg(NetworkConfigMsgType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMsg() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsg() => $_clearField(1);

  @$pb.TagNumber(10)
  CmdGetWifiStatus get cmdGetWifiStatus => $_getN(1);
  @$pb.TagNumber(10)
  set cmdGetWifiStatus(CmdGetWifiStatus value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCmdGetWifiStatus() => $_has(1);
  @$pb.TagNumber(10)
  void clearCmdGetWifiStatus() => $_clearField(10);
  @$pb.TagNumber(10)
  CmdGetWifiStatus ensureCmdGetWifiStatus() => $_ensure(1);

  @$pb.TagNumber(11)
  RespGetWifiStatus get respGetWifiStatus => $_getN(2);
  @$pb.TagNumber(11)
  set respGetWifiStatus(RespGetWifiStatus value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRespGetWifiStatus() => $_has(2);
  @$pb.TagNumber(11)
  void clearRespGetWifiStatus() => $_clearField(11);
  @$pb.TagNumber(11)
  RespGetWifiStatus ensureRespGetWifiStatus() => $_ensure(2);

  @$pb.TagNumber(12)
  CmdSetWifiConfig get cmdSetWifiConfig => $_getN(3);
  @$pb.TagNumber(12)
  set cmdSetWifiConfig(CmdSetWifiConfig value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCmdSetWifiConfig() => $_has(3);
  @$pb.TagNumber(12)
  void clearCmdSetWifiConfig() => $_clearField(12);
  @$pb.TagNumber(12)
  CmdSetWifiConfig ensureCmdSetWifiConfig() => $_ensure(3);

  @$pb.TagNumber(13)
  RespSetWifiConfig get respSetWifiConfig => $_getN(4);
  @$pb.TagNumber(13)
  set respSetWifiConfig(RespSetWifiConfig value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRespSetWifiConfig() => $_has(4);
  @$pb.TagNumber(13)
  void clearRespSetWifiConfig() => $_clearField(13);
  @$pb.TagNumber(13)
  RespSetWifiConfig ensureRespSetWifiConfig() => $_ensure(4);

  @$pb.TagNumber(14)
  CmdApplyWifiConfig get cmdApplyWifiConfig => $_getN(5);
  @$pb.TagNumber(14)
  set cmdApplyWifiConfig(CmdApplyWifiConfig value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCmdApplyWifiConfig() => $_has(5);
  @$pb.TagNumber(14)
  void clearCmdApplyWifiConfig() => $_clearField(14);
  @$pb.TagNumber(14)
  CmdApplyWifiConfig ensureCmdApplyWifiConfig() => $_ensure(5);

  @$pb.TagNumber(15)
  RespApplyWifiConfig get respApplyWifiConfig => $_getN(6);
  @$pb.TagNumber(15)
  set respApplyWifiConfig(RespApplyWifiConfig value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRespApplyWifiConfig() => $_has(6);
  @$pb.TagNumber(15)
  void clearRespApplyWifiConfig() => $_clearField(15);
  @$pb.TagNumber(15)
  RespApplyWifiConfig ensureRespApplyWifiConfig() => $_ensure(6);

  @$pb.TagNumber(16)
  CmdGetThreadStatus get cmdGetThreadStatus => $_getN(7);
  @$pb.TagNumber(16)
  set cmdGetThreadStatus(CmdGetThreadStatus value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasCmdGetThreadStatus() => $_has(7);
  @$pb.TagNumber(16)
  void clearCmdGetThreadStatus() => $_clearField(16);
  @$pb.TagNumber(16)
  CmdGetThreadStatus ensureCmdGetThreadStatus() => $_ensure(7);

  @$pb.TagNumber(17)
  RespGetThreadStatus get respGetThreadStatus => $_getN(8);
  @$pb.TagNumber(17)
  set respGetThreadStatus(RespGetThreadStatus value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasRespGetThreadStatus() => $_has(8);
  @$pb.TagNumber(17)
  void clearRespGetThreadStatus() => $_clearField(17);
  @$pb.TagNumber(17)
  RespGetThreadStatus ensureRespGetThreadStatus() => $_ensure(8);

  @$pb.TagNumber(18)
  CmdSetThreadConfig get cmdSetThreadConfig => $_getN(9);
  @$pb.TagNumber(18)
  set cmdSetThreadConfig(CmdSetThreadConfig value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCmdSetThreadConfig() => $_has(9);
  @$pb.TagNumber(18)
  void clearCmdSetThreadConfig() => $_clearField(18);
  @$pb.TagNumber(18)
  CmdSetThreadConfig ensureCmdSetThreadConfig() => $_ensure(9);

  @$pb.TagNumber(19)
  RespSetThreadConfig get respSetThreadConfig => $_getN(10);
  @$pb.TagNumber(19)
  set respSetThreadConfig(RespSetThreadConfig value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasRespSetThreadConfig() => $_has(10);
  @$pb.TagNumber(19)
  void clearRespSetThreadConfig() => $_clearField(19);
  @$pb.TagNumber(19)
  RespSetThreadConfig ensureRespSetThreadConfig() => $_ensure(10);

  @$pb.TagNumber(20)
  CmdApplyThreadConfig get cmdApplyThreadConfig => $_getN(11);
  @$pb.TagNumber(20)
  set cmdApplyThreadConfig(CmdApplyThreadConfig value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasCmdApplyThreadConfig() => $_has(11);
  @$pb.TagNumber(20)
  void clearCmdApplyThreadConfig() => $_clearField(20);
  @$pb.TagNumber(20)
  CmdApplyThreadConfig ensureCmdApplyThreadConfig() => $_ensure(11);

  @$pb.TagNumber(21)
  RespApplyThreadConfig get respApplyThreadConfig => $_getN(12);
  @$pb.TagNumber(21)
  set respApplyThreadConfig(RespApplyThreadConfig value) =>
      $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasRespApplyThreadConfig() => $_has(12);
  @$pb.TagNumber(21)
  void clearRespApplyThreadConfig() => $_clearField(21);
  @$pb.TagNumber(21)
  RespApplyThreadConfig ensureRespApplyThreadConfig() => $_ensure(12);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
