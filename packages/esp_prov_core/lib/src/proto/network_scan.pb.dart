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

import 'constants.pbenum.dart' as $1;
import 'network_constants.pbenum.dart' as $0;
import 'network_scan.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'network_scan.pbenum.dart';

class CmdScanWifiStart extends $pb.GeneratedMessage {
  factory CmdScanWifiStart({
    $core.bool? blocking,
    $core.bool? passive,
    $core.int? groupChannels,
    $core.int? periodMs,
  }) {
    final result = CmdScanWifiStart._();
    if (blocking != null) result.blocking = blocking;
    if (passive != null) result.passive = passive;
    if (groupChannels != null) result.groupChannels = groupChannels;
    if (periodMs != null) result.periodMs = periodMs;
    return result;
  }

  CmdScanWifiStart._();

  factory CmdScanWifiStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiStart()..mergeFromBuffer(data, registry);
  factory CmdScanWifiStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiStart()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanWifiStart',
      createEmptyInstance: CmdScanWifiStart.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'blocking')
    ..aOB(2, _omitFieldNames ? '' : 'passive')
    ..aI(3, _omitFieldNames ? '' : 'groupChannels',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'periodMs', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiStart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiStart copyWith(void Function(CmdScanWifiStart) updates) =>
      super.copyWith((message) => updates(message as CmdScanWifiStart))
          as CmdScanWifiStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdScanWifiStart() / CmdScanWifiStart.new instead')
  static CmdScanWifiStart create() => CmdScanWifiStart._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanWifiStart._();
  @$core.override
  CmdScanWifiStart createEmptyInstance() => CmdScanWifiStart._();
  @$core.pragma('dart2js:noInline')
  static CmdScanWifiStart getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CmdScanWifiStart>(
          CmdScanWifiStart.$_createMessage);
  static CmdScanWifiStart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get blocking => $_getBF(0);
  @$pb.TagNumber(1)
  set blocking($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBlocking() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlocking() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get passive => $_getBF(1);
  @$pb.TagNumber(2)
  set passive($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassive() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassive() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get groupChannels => $_getIZ(2);
  @$pb.TagNumber(3)
  set groupChannels($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasGroupChannels() => $_has(2);
  @$pb.TagNumber(3)
  void clearGroupChannels() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get periodMs => $_getIZ(3);
  @$pb.TagNumber(4)
  set periodMs($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPeriodMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearPeriodMs() => $_clearField(4);
}

class CmdScanThreadStart extends $pb.GeneratedMessage {
  factory CmdScanThreadStart({
    $core.bool? blocking,
    $core.int? channelMask,
  }) {
    final result = CmdScanThreadStart._();
    if (blocking != null) result.blocking = blocking;
    if (channelMask != null) result.channelMask = channelMask;
    return result;
  }

  CmdScanThreadStart._();

  factory CmdScanThreadStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadStart()..mergeFromBuffer(data, registry);
  factory CmdScanThreadStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadStart()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanThreadStart',
      createEmptyInstance: CmdScanThreadStart.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'blocking')
    ..aI(2, _omitFieldNames ? '' : 'channelMask',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadStart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadStart copyWith(void Function(CmdScanThreadStart) updates) =>
      super.copyWith((message) => updates(message as CmdScanThreadStart))
          as CmdScanThreadStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdScanThreadStart() / CmdScanThreadStart.new instead')
  static CmdScanThreadStart create() => CmdScanThreadStart._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanThreadStart._();
  @$core.override
  CmdScanThreadStart createEmptyInstance() => CmdScanThreadStart._();
  @$core.pragma('dart2js:noInline')
  static CmdScanThreadStart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdScanThreadStart>(
          CmdScanThreadStart.$_createMessage);
  static CmdScanThreadStart? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get blocking => $_getBF(0);
  @$pb.TagNumber(1)
  set blocking($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBlocking() => $_has(0);
  @$pb.TagNumber(1)
  void clearBlocking() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get channelMask => $_getIZ(1);
  @$pb.TagNumber(2)
  set channelMask($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannelMask() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannelMask() => $_clearField(2);
}

class RespScanWifiStart extends $pb.GeneratedMessage {
  factory RespScanWifiStart() => RespScanWifiStart._();

  RespScanWifiStart._();

  factory RespScanWifiStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiStart()..mergeFromBuffer(data, registry);
  factory RespScanWifiStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiStart()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanWifiStart',
      createEmptyInstance: RespScanWifiStart.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiStart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiStart copyWith(void Function(RespScanWifiStart) updates) =>
      super.copyWith((message) => updates(message as RespScanWifiStart))
          as RespScanWifiStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RespScanWifiStart() / RespScanWifiStart.new instead')
  static RespScanWifiStart create() => RespScanWifiStart._();
  static $pb.GeneratedMessage $_createMessage() => RespScanWifiStart._();
  @$core.override
  RespScanWifiStart createEmptyInstance() => RespScanWifiStart._();
  @$core.pragma('dart2js:noInline')
  static RespScanWifiStart getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RespScanWifiStart>(
          RespScanWifiStart.$_createMessage);
  static RespScanWifiStart? _defaultInstance;
}

class RespScanThreadStart extends $pb.GeneratedMessage {
  factory RespScanThreadStart() => RespScanThreadStart._();

  RespScanThreadStart._();

  factory RespScanThreadStart.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadStart()..mergeFromBuffer(data, registry);
  factory RespScanThreadStart.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadStart()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanThreadStart',
      createEmptyInstance: RespScanThreadStart.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadStart clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadStart copyWith(void Function(RespScanThreadStart) updates) =>
      super.copyWith((message) => updates(message as RespScanThreadStart))
          as RespScanThreadStart;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RespScanThreadStart() / RespScanThreadStart.new instead')
  static RespScanThreadStart create() => RespScanThreadStart._();
  static $pb.GeneratedMessage $_createMessage() => RespScanThreadStart._();
  @$core.override
  RespScanThreadStart createEmptyInstance() => RespScanThreadStart._();
  @$core.pragma('dart2js:noInline')
  static RespScanThreadStart getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespScanThreadStart>(
          RespScanThreadStart.$_createMessage);
  static RespScanThreadStart? _defaultInstance;
}

class CmdScanWifiStatus extends $pb.GeneratedMessage {
  factory CmdScanWifiStatus() => CmdScanWifiStatus._();

  CmdScanWifiStatus._();

  factory CmdScanWifiStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiStatus()..mergeFromBuffer(data, registry);
  factory CmdScanWifiStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanWifiStatus',
      createEmptyInstance: CmdScanWifiStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiStatus copyWith(void Function(CmdScanWifiStatus) updates) =>
      super.copyWith((message) => updates(message as CmdScanWifiStatus))
          as CmdScanWifiStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdScanWifiStatus() / CmdScanWifiStatus.new instead')
  static CmdScanWifiStatus create() => CmdScanWifiStatus._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanWifiStatus._();
  @$core.override
  CmdScanWifiStatus createEmptyInstance() => CmdScanWifiStatus._();
  @$core.pragma('dart2js:noInline')
  static CmdScanWifiStatus getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CmdScanWifiStatus>(
          CmdScanWifiStatus.$_createMessage);
  static CmdScanWifiStatus? _defaultInstance;
}

class CmdScanThreadStatus extends $pb.GeneratedMessage {
  factory CmdScanThreadStatus() => CmdScanThreadStatus._();

  CmdScanThreadStatus._();

  factory CmdScanThreadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadStatus()..mergeFromBuffer(data, registry);
  factory CmdScanThreadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanThreadStatus',
      createEmptyInstance: CmdScanThreadStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadStatus copyWith(void Function(CmdScanThreadStatus) updates) =>
      super.copyWith((message) => updates(message as CmdScanThreadStatus))
          as CmdScanThreadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CmdScanThreadStatus() / CmdScanThreadStatus.new instead')
  static CmdScanThreadStatus create() => CmdScanThreadStatus._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanThreadStatus._();
  @$core.override
  CmdScanThreadStatus createEmptyInstance() => CmdScanThreadStatus._();
  @$core.pragma('dart2js:noInline')
  static CmdScanThreadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdScanThreadStatus>(
          CmdScanThreadStatus.$_createMessage);
  static CmdScanThreadStatus? _defaultInstance;
}

class RespScanWifiStatus extends $pb.GeneratedMessage {
  factory RespScanWifiStatus({
    $core.bool? scanFinished,
    $core.int? resultCount,
  }) {
    final result = RespScanWifiStatus._();
    if (scanFinished != null) result.scanFinished = scanFinished;
    if (resultCount != null) result.resultCount = resultCount;
    return result;
  }

  RespScanWifiStatus._();

  factory RespScanWifiStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiStatus()..mergeFromBuffer(data, registry);
  factory RespScanWifiStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanWifiStatus',
      createEmptyInstance: RespScanWifiStatus.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'scanFinished')
    ..aI(2, _omitFieldNames ? '' : 'resultCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiStatus copyWith(void Function(RespScanWifiStatus) updates) =>
      super.copyWith((message) => updates(message as RespScanWifiStatus))
          as RespScanWifiStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RespScanWifiStatus() / RespScanWifiStatus.new instead')
  static RespScanWifiStatus create() => RespScanWifiStatus._();
  static $pb.GeneratedMessage $_createMessage() => RespScanWifiStatus._();
  @$core.override
  RespScanWifiStatus createEmptyInstance() => RespScanWifiStatus._();
  @$core.pragma('dart2js:noInline')
  static RespScanWifiStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespScanWifiStatus>(
          RespScanWifiStatus.$_createMessage);
  static RespScanWifiStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get scanFinished => $_getBF(0);
  @$pb.TagNumber(1)
  set scanFinished($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScanFinished() => $_has(0);
  @$pb.TagNumber(1)
  void clearScanFinished() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get resultCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set resultCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultCount() => $_clearField(2);
}

class RespScanThreadStatus extends $pb.GeneratedMessage {
  factory RespScanThreadStatus({
    $core.bool? scanFinished,
    $core.int? resultCount,
  }) {
    final result = RespScanThreadStatus._();
    if (scanFinished != null) result.scanFinished = scanFinished;
    if (resultCount != null) result.resultCount = resultCount;
    return result;
  }

  RespScanThreadStatus._();

  factory RespScanThreadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadStatus()..mergeFromBuffer(data, registry);
  factory RespScanThreadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanThreadStatus',
      createEmptyInstance: RespScanThreadStatus.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'scanFinished')
    ..aI(2, _omitFieldNames ? '' : 'resultCount',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadStatus copyWith(void Function(RespScanThreadStatus) updates) =>
      super.copyWith((message) => updates(message as RespScanThreadStatus))
          as RespScanThreadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RespScanThreadStatus() / RespScanThreadStatus.new instead')
  static RespScanThreadStatus create() => RespScanThreadStatus._();
  static $pb.GeneratedMessage $_createMessage() => RespScanThreadStatus._();
  @$core.override
  RespScanThreadStatus createEmptyInstance() => RespScanThreadStatus._();
  @$core.pragma('dart2js:noInline')
  static RespScanThreadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespScanThreadStatus>(
          RespScanThreadStatus.$_createMessage);
  static RespScanThreadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get scanFinished => $_getBF(0);
  @$pb.TagNumber(1)
  set scanFinished($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasScanFinished() => $_has(0);
  @$pb.TagNumber(1)
  void clearScanFinished() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get resultCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set resultCount($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultCount() => $_clearField(2);
}

class CmdScanWifiResult extends $pb.GeneratedMessage {
  factory CmdScanWifiResult({
    $core.int? startIndex,
    $core.int? count,
  }) {
    final result = CmdScanWifiResult._();
    if (startIndex != null) result.startIndex = startIndex;
    if (count != null) result.count = count;
    return result;
  }

  CmdScanWifiResult._();

  factory CmdScanWifiResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiResult()..mergeFromBuffer(data, registry);
  factory CmdScanWifiResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanWifiResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanWifiResult',
      createEmptyInstance: CmdScanWifiResult.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'startIndex', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'count', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanWifiResult copyWith(void Function(CmdScanWifiResult) updates) =>
      super.copyWith((message) => updates(message as CmdScanWifiResult))
          as CmdScanWifiResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CmdScanWifiResult() / CmdScanWifiResult.new instead')
  static CmdScanWifiResult create() => CmdScanWifiResult._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanWifiResult._();
  @$core.override
  CmdScanWifiResult createEmptyInstance() => CmdScanWifiResult._();
  @$core.pragma('dart2js:noInline')
  static CmdScanWifiResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CmdScanWifiResult>(
          CmdScanWifiResult.$_createMessage);
  static CmdScanWifiResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get startIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set startIndex($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class CmdScanThreadResult extends $pb.GeneratedMessage {
  factory CmdScanThreadResult({
    $core.int? startIndex,
    $core.int? count,
  }) {
    final result = CmdScanThreadResult._();
    if (startIndex != null) result.startIndex = startIndex;
    if (count != null) result.count = count;
    return result;
  }

  CmdScanThreadResult._();

  factory CmdScanThreadResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadResult()..mergeFromBuffer(data, registry);
  factory CmdScanThreadResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CmdScanThreadResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CmdScanThreadResult',
      createEmptyInstance: CmdScanThreadResult.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'startIndex', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'count', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CmdScanThreadResult copyWith(void Function(CmdScanThreadResult) updates) =>
      super.copyWith((message) => updates(message as CmdScanThreadResult))
          as CmdScanThreadResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CmdScanThreadResult() / CmdScanThreadResult.new instead')
  static CmdScanThreadResult create() => CmdScanThreadResult._();
  static $pb.GeneratedMessage $_createMessage() => CmdScanThreadResult._();
  @$core.override
  CmdScanThreadResult createEmptyInstance() => CmdScanThreadResult._();
  @$core.pragma('dart2js:noInline')
  static CmdScanThreadResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CmdScanThreadResult>(
          CmdScanThreadResult.$_createMessage);
  static CmdScanThreadResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get startIndex => $_getIZ(0);
  @$pb.TagNumber(1)
  set startIndex($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartIndex() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartIndex() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);
}

class WiFiScanResult extends $pb.GeneratedMessage {
  factory WiFiScanResult({
    $core.List<$core.int>? ssid,
    $core.int? channel,
    $core.int? rssi,
    $core.List<$core.int>? bssid,
    $0.WifiAuthMode? auth,
  }) {
    final result = WiFiScanResult._();
    if (ssid != null) result.ssid = ssid;
    if (channel != null) result.channel = channel;
    if (rssi != null) result.rssi = rssi;
    if (bssid != null) result.bssid = bssid;
    if (auth != null) result.auth = auth;
    return result;
  }

  WiFiScanResult._();

  factory WiFiScanResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WiFiScanResult()..mergeFromBuffer(data, registry);
  factory WiFiScanResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WiFiScanResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WiFiScanResult',
      createEmptyInstance: WiFiScanResult.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'ssid', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'rssi')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'bssid', $pb.PbFieldType.OY)
    ..aE<$0.WifiAuthMode>(5, _omitFieldNames ? '' : 'auth',
        enumValues: $0.WifiAuthMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WiFiScanResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WiFiScanResult copyWith(void Function(WiFiScanResult) updates) =>
      super.copyWith((message) => updates(message as WiFiScanResult))
          as WiFiScanResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WiFiScanResult() / WiFiScanResult.new instead')
  static WiFiScanResult create() => WiFiScanResult._();
  static $pb.GeneratedMessage $_createMessage() => WiFiScanResult._();
  @$core.override
  WiFiScanResult createEmptyInstance() => WiFiScanResult._();
  @$core.pragma('dart2js:noInline')
  static WiFiScanResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WiFiScanResult>(
          WiFiScanResult.$_createMessage);
  static WiFiScanResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get ssid => $_getN(0);
  @$pb.TagNumber(1)
  set ssid($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSsid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSsid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get channel => $_getIZ(1);
  @$pb.TagNumber(2)
  set channel($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannel() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rssi => $_getIZ(2);
  @$pb.TagNumber(3)
  set rssi($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRssi() => $_has(2);
  @$pb.TagNumber(3)
  void clearRssi() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get bssid => $_getN(3);
  @$pb.TagNumber(4)
  set bssid($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBssid() => $_has(3);
  @$pb.TagNumber(4)
  void clearBssid() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.WifiAuthMode get auth => $_getN(4);
  @$pb.TagNumber(5)
  set auth($0.WifiAuthMode value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasAuth() => $_has(4);
  @$pb.TagNumber(5)
  void clearAuth() => $_clearField(5);
}

class ThreadScanResult extends $pb.GeneratedMessage {
  factory ThreadScanResult({
    $core.int? panId,
    $core.int? channel,
    $core.int? rssi,
    $core.int? lqi,
    $core.List<$core.int>? extAddr,
    $core.String? networkName,
    $core.List<$core.int>? extPanId,
  }) {
    final result = ThreadScanResult._();
    if (panId != null) result.panId = panId;
    if (channel != null) result.channel = channel;
    if (rssi != null) result.rssi = rssi;
    if (lqi != null) result.lqi = lqi;
    if (extAddr != null) result.extAddr = extAddr;
    if (networkName != null) result.networkName = networkName;
    if (extPanId != null) result.extPanId = extPanId;
    return result;
  }

  ThreadScanResult._();

  factory ThreadScanResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadScanResult()..mergeFromBuffer(data, registry);
  factory ThreadScanResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ThreadScanResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ThreadScanResult',
      createEmptyInstance: ThreadScanResult.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'panId', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'channel', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'rssi')
    ..aI(4, _omitFieldNames ? '' : 'lqi', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'extAddr', $pb.PbFieldType.OY)
    ..aOS(6, _omitFieldNames ? '' : 'networkName')
    ..a<$core.List<$core.int>>(
        7, _omitFieldNames ? '' : 'extPanId', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadScanResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ThreadScanResult copyWith(void Function(ThreadScanResult) updates) =>
      super.copyWith((message) => updates(message as ThreadScanResult))
          as ThreadScanResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ThreadScanResult() / ThreadScanResult.new instead')
  static ThreadScanResult create() => ThreadScanResult._();
  static $pb.GeneratedMessage $_createMessage() => ThreadScanResult._();
  @$core.override
  ThreadScanResult createEmptyInstance() => ThreadScanResult._();
  @$core.pragma('dart2js:noInline')
  static ThreadScanResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ThreadScanResult>(
          ThreadScanResult.$_createMessage);
  static ThreadScanResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get panId => $_getIZ(0);
  @$pb.TagNumber(1)
  set panId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPanId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get channel => $_getIZ(1);
  @$pb.TagNumber(2)
  set channel($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChannel() => $_has(1);
  @$pb.TagNumber(2)
  void clearChannel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rssi => $_getIZ(2);
  @$pb.TagNumber(3)
  set rssi($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRssi() => $_has(2);
  @$pb.TagNumber(3)
  void clearRssi() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get lqi => $_getIZ(3);
  @$pb.TagNumber(4)
  set lqi($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLqi() => $_has(3);
  @$pb.TagNumber(4)
  void clearLqi() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get extAddr => $_getN(4);
  @$pb.TagNumber(5)
  set extAddr($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExtAddr() => $_has(4);
  @$pb.TagNumber(5)
  void clearExtAddr() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get networkName => $_getSZ(5);
  @$pb.TagNumber(6)
  set networkName($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNetworkName() => $_has(5);
  @$pb.TagNumber(6)
  void clearNetworkName() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get extPanId => $_getN(6);
  @$pb.TagNumber(7)
  set extPanId($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExtPanId() => $_has(6);
  @$pb.TagNumber(7)
  void clearExtPanId() => $_clearField(7);
}

class RespScanWifiResult extends $pb.GeneratedMessage {
  factory RespScanWifiResult({
    $core.Iterable<WiFiScanResult>? entries,
  }) {
    final result = RespScanWifiResult._();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  RespScanWifiResult._();

  factory RespScanWifiResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiResult()..mergeFromBuffer(data, registry);
  factory RespScanWifiResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanWifiResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanWifiResult',
      createEmptyInstance: RespScanWifiResult.$_createMessage)
    ..pPM<WiFiScanResult>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: WiFiScanResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanWifiResult copyWith(void Function(RespScanWifiResult) updates) =>
      super.copyWith((message) => updates(message as RespScanWifiResult))
          as RespScanWifiResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RespScanWifiResult() / RespScanWifiResult.new instead')
  static RespScanWifiResult create() => RespScanWifiResult._();
  static $pb.GeneratedMessage $_createMessage() => RespScanWifiResult._();
  @$core.override
  RespScanWifiResult createEmptyInstance() => RespScanWifiResult._();
  @$core.pragma('dart2js:noInline')
  static RespScanWifiResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespScanWifiResult>(
          RespScanWifiResult.$_createMessage);
  static RespScanWifiResult? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WiFiScanResult> get entries => $_getList(0);
}

class RespScanThreadResult extends $pb.GeneratedMessage {
  factory RespScanThreadResult({
    $core.Iterable<ThreadScanResult>? entries,
  }) {
    final result = RespScanThreadResult._();
    if (entries != null) result.entries.addAll(entries);
    return result;
  }

  RespScanThreadResult._();

  factory RespScanThreadResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadResult()..mergeFromBuffer(data, registry);
  factory RespScanThreadResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RespScanThreadResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RespScanThreadResult',
      createEmptyInstance: RespScanThreadResult.$_createMessage)
    ..pPM<ThreadScanResult>(1, _omitFieldNames ? '' : 'entries',
        subBuilder: ThreadScanResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RespScanThreadResult copyWith(void Function(RespScanThreadResult) updates) =>
      super.copyWith((message) => updates(message as RespScanThreadResult))
          as RespScanThreadResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RespScanThreadResult() / RespScanThreadResult.new instead')
  static RespScanThreadResult create() => RespScanThreadResult._();
  static $pb.GeneratedMessage $_createMessage() => RespScanThreadResult._();
  @$core.override
  RespScanThreadResult createEmptyInstance() => RespScanThreadResult._();
  @$core.pragma('dart2js:noInline')
  static RespScanThreadResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RespScanThreadResult>(
          RespScanThreadResult.$_createMessage);
  static RespScanThreadResult? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ThreadScanResult> get entries => $_getList(0);
}

enum NetworkScanPayload_Payload {
  cmdScanWifiStart,
  respScanWifiStart,
  cmdScanWifiStatus,
  respScanWifiStatus,
  cmdScanWifiResult,
  respScanWifiResult,
  cmdScanThreadStart,
  respScanThreadStart,
  cmdScanThreadStatus,
  respScanThreadStatus,
  cmdScanThreadResult,
  respScanThreadResult,
  notSet
}

class NetworkScanPayload extends $pb.GeneratedMessage {
  factory NetworkScanPayload({
    NetworkScanMsgType? msg,
    $1.Status? status,
    CmdScanWifiStart? cmdScanWifiStart,
    RespScanWifiStart? respScanWifiStart,
    CmdScanWifiStatus? cmdScanWifiStatus,
    RespScanWifiStatus? respScanWifiStatus,
    CmdScanWifiResult? cmdScanWifiResult,
    RespScanWifiResult? respScanWifiResult,
    CmdScanThreadStart? cmdScanThreadStart,
    RespScanThreadStart? respScanThreadStart,
    CmdScanThreadStatus? cmdScanThreadStatus,
    RespScanThreadStatus? respScanThreadStatus,
    CmdScanThreadResult? cmdScanThreadResult,
    RespScanThreadResult? respScanThreadResult,
  }) {
    final result = NetworkScanPayload._();
    if (msg != null) result.msg = msg;
    if (status != null) result.status = status;
    if (cmdScanWifiStart != null) result.cmdScanWifiStart = cmdScanWifiStart;
    if (respScanWifiStart != null) result.respScanWifiStart = respScanWifiStart;
    if (cmdScanWifiStatus != null) result.cmdScanWifiStatus = cmdScanWifiStatus;
    if (respScanWifiStatus != null)
      result.respScanWifiStatus = respScanWifiStatus;
    if (cmdScanWifiResult != null) result.cmdScanWifiResult = cmdScanWifiResult;
    if (respScanWifiResult != null)
      result.respScanWifiResult = respScanWifiResult;
    if (cmdScanThreadStart != null)
      result.cmdScanThreadStart = cmdScanThreadStart;
    if (respScanThreadStart != null)
      result.respScanThreadStart = respScanThreadStart;
    if (cmdScanThreadStatus != null)
      result.cmdScanThreadStatus = cmdScanThreadStatus;
    if (respScanThreadStatus != null)
      result.respScanThreadStatus = respScanThreadStatus;
    if (cmdScanThreadResult != null)
      result.cmdScanThreadResult = cmdScanThreadResult;
    if (respScanThreadResult != null)
      result.respScanThreadResult = respScanThreadResult;
    return result;
  }

  NetworkScanPayload._();

  factory NetworkScanPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NetworkScanPayload()..mergeFromBuffer(data, registry);
  factory NetworkScanPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      NetworkScanPayload()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, NetworkScanPayload_Payload>
      _NetworkScanPayload_PayloadByTag = {
    10: NetworkScanPayload_Payload.cmdScanWifiStart,
    11: NetworkScanPayload_Payload.respScanWifiStart,
    12: NetworkScanPayload_Payload.cmdScanWifiStatus,
    13: NetworkScanPayload_Payload.respScanWifiStatus,
    14: NetworkScanPayload_Payload.cmdScanWifiResult,
    15: NetworkScanPayload_Payload.respScanWifiResult,
    16: NetworkScanPayload_Payload.cmdScanThreadStart,
    17: NetworkScanPayload_Payload.respScanThreadStart,
    18: NetworkScanPayload_Payload.cmdScanThreadStatus,
    19: NetworkScanPayload_Payload.respScanThreadStatus,
    20: NetworkScanPayload_Payload.cmdScanThreadResult,
    21: NetworkScanPayload_Payload.respScanThreadResult,
    0: NetworkScanPayload_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NetworkScanPayload',
      createEmptyInstance: NetworkScanPayload.$_createMessage)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21])
    ..aE<NetworkScanMsgType>(1, _omitFieldNames ? '' : 'msg',
        enumValues: NetworkScanMsgType.values)
    ..aE<$1.Status>(2, _omitFieldNames ? '' : 'status',
        enumValues: $1.Status.values)
    ..aOM<CmdScanWifiStart>(10, _omitFieldNames ? '' : 'cmdScanWifiStart',
        subBuilder: CmdScanWifiStart.$_createMessage)
    ..aOM<RespScanWifiStart>(11, _omitFieldNames ? '' : 'respScanWifiStart',
        subBuilder: RespScanWifiStart.$_createMessage)
    ..aOM<CmdScanWifiStatus>(12, _omitFieldNames ? '' : 'cmdScanWifiStatus',
        subBuilder: CmdScanWifiStatus.$_createMessage)
    ..aOM<RespScanWifiStatus>(13, _omitFieldNames ? '' : 'respScanWifiStatus',
        subBuilder: RespScanWifiStatus.$_createMessage)
    ..aOM<CmdScanWifiResult>(14, _omitFieldNames ? '' : 'cmdScanWifiResult',
        subBuilder: CmdScanWifiResult.$_createMessage)
    ..aOM<RespScanWifiResult>(15, _omitFieldNames ? '' : 'respScanWifiResult',
        subBuilder: RespScanWifiResult.$_createMessage)
    ..aOM<CmdScanThreadStart>(16, _omitFieldNames ? '' : 'cmdScanThreadStart',
        subBuilder: CmdScanThreadStart.$_createMessage)
    ..aOM<RespScanThreadStart>(17, _omitFieldNames ? '' : 'respScanThreadStart',
        subBuilder: RespScanThreadStart.$_createMessage)
    ..aOM<CmdScanThreadStatus>(18, _omitFieldNames ? '' : 'cmdScanThreadStatus',
        subBuilder: CmdScanThreadStatus.$_createMessage)
    ..aOM<RespScanThreadStatus>(
        19, _omitFieldNames ? '' : 'respScanThreadStatus',
        subBuilder: RespScanThreadStatus.$_createMessage)
    ..aOM<CmdScanThreadResult>(20, _omitFieldNames ? '' : 'cmdScanThreadResult',
        subBuilder: CmdScanThreadResult.$_createMessage)
    ..aOM<RespScanThreadResult>(
        21, _omitFieldNames ? '' : 'respScanThreadResult',
        subBuilder: RespScanThreadResult.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkScanPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NetworkScanPayload copyWith(void Function(NetworkScanPayload) updates) =>
      super.copyWith((message) => updates(message as NetworkScanPayload))
          as NetworkScanPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use NetworkScanPayload() / NetworkScanPayload.new instead')
  static NetworkScanPayload create() => NetworkScanPayload._();
  static $pb.GeneratedMessage $_createMessage() => NetworkScanPayload._();
  @$core.override
  NetworkScanPayload createEmptyInstance() => NetworkScanPayload._();
  @$core.pragma('dart2js:noInline')
  static NetworkScanPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NetworkScanPayload>(
          NetworkScanPayload.$_createMessage);
  static NetworkScanPayload? _defaultInstance;

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
  NetworkScanPayload_Payload whichPayload() =>
      _NetworkScanPayload_PayloadByTag[$_whichOneof(0)]!;
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
  NetworkScanMsgType get msg => $_getN(0);
  @$pb.TagNumber(1)
  set msg(NetworkScanMsgType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMsg() => $_has(0);
  @$pb.TagNumber(1)
  void clearMsg() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.Status get status => $_getN(1);
  @$pb.TagNumber(2)
  set status($1.Status value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(10)
  CmdScanWifiStart get cmdScanWifiStart => $_getN(2);
  @$pb.TagNumber(10)
  set cmdScanWifiStart(CmdScanWifiStart value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCmdScanWifiStart() => $_has(2);
  @$pb.TagNumber(10)
  void clearCmdScanWifiStart() => $_clearField(10);
  @$pb.TagNumber(10)
  CmdScanWifiStart ensureCmdScanWifiStart() => $_ensure(2);

  @$pb.TagNumber(11)
  RespScanWifiStart get respScanWifiStart => $_getN(3);
  @$pb.TagNumber(11)
  set respScanWifiStart(RespScanWifiStart value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRespScanWifiStart() => $_has(3);
  @$pb.TagNumber(11)
  void clearRespScanWifiStart() => $_clearField(11);
  @$pb.TagNumber(11)
  RespScanWifiStart ensureRespScanWifiStart() => $_ensure(3);

  @$pb.TagNumber(12)
  CmdScanWifiStatus get cmdScanWifiStatus => $_getN(4);
  @$pb.TagNumber(12)
  set cmdScanWifiStatus(CmdScanWifiStatus value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCmdScanWifiStatus() => $_has(4);
  @$pb.TagNumber(12)
  void clearCmdScanWifiStatus() => $_clearField(12);
  @$pb.TagNumber(12)
  CmdScanWifiStatus ensureCmdScanWifiStatus() => $_ensure(4);

  @$pb.TagNumber(13)
  RespScanWifiStatus get respScanWifiStatus => $_getN(5);
  @$pb.TagNumber(13)
  set respScanWifiStatus(RespScanWifiStatus value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRespScanWifiStatus() => $_has(5);
  @$pb.TagNumber(13)
  void clearRespScanWifiStatus() => $_clearField(13);
  @$pb.TagNumber(13)
  RespScanWifiStatus ensureRespScanWifiStatus() => $_ensure(5);

  @$pb.TagNumber(14)
  CmdScanWifiResult get cmdScanWifiResult => $_getN(6);
  @$pb.TagNumber(14)
  set cmdScanWifiResult(CmdScanWifiResult value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCmdScanWifiResult() => $_has(6);
  @$pb.TagNumber(14)
  void clearCmdScanWifiResult() => $_clearField(14);
  @$pb.TagNumber(14)
  CmdScanWifiResult ensureCmdScanWifiResult() => $_ensure(6);

  @$pb.TagNumber(15)
  RespScanWifiResult get respScanWifiResult => $_getN(7);
  @$pb.TagNumber(15)
  set respScanWifiResult(RespScanWifiResult value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRespScanWifiResult() => $_has(7);
  @$pb.TagNumber(15)
  void clearRespScanWifiResult() => $_clearField(15);
  @$pb.TagNumber(15)
  RespScanWifiResult ensureRespScanWifiResult() => $_ensure(7);

  @$pb.TagNumber(16)
  CmdScanThreadStart get cmdScanThreadStart => $_getN(8);
  @$pb.TagNumber(16)
  set cmdScanThreadStart(CmdScanThreadStart value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasCmdScanThreadStart() => $_has(8);
  @$pb.TagNumber(16)
  void clearCmdScanThreadStart() => $_clearField(16);
  @$pb.TagNumber(16)
  CmdScanThreadStart ensureCmdScanThreadStart() => $_ensure(8);

  @$pb.TagNumber(17)
  RespScanThreadStart get respScanThreadStart => $_getN(9);
  @$pb.TagNumber(17)
  set respScanThreadStart(RespScanThreadStart value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasRespScanThreadStart() => $_has(9);
  @$pb.TagNumber(17)
  void clearRespScanThreadStart() => $_clearField(17);
  @$pb.TagNumber(17)
  RespScanThreadStart ensureRespScanThreadStart() => $_ensure(9);

  @$pb.TagNumber(18)
  CmdScanThreadStatus get cmdScanThreadStatus => $_getN(10);
  @$pb.TagNumber(18)
  set cmdScanThreadStatus(CmdScanThreadStatus value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCmdScanThreadStatus() => $_has(10);
  @$pb.TagNumber(18)
  void clearCmdScanThreadStatus() => $_clearField(18);
  @$pb.TagNumber(18)
  CmdScanThreadStatus ensureCmdScanThreadStatus() => $_ensure(10);

  @$pb.TagNumber(19)
  RespScanThreadStatus get respScanThreadStatus => $_getN(11);
  @$pb.TagNumber(19)
  set respScanThreadStatus(RespScanThreadStatus value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasRespScanThreadStatus() => $_has(11);
  @$pb.TagNumber(19)
  void clearRespScanThreadStatus() => $_clearField(19);
  @$pb.TagNumber(19)
  RespScanThreadStatus ensureRespScanThreadStatus() => $_ensure(11);

  @$pb.TagNumber(20)
  CmdScanThreadResult get cmdScanThreadResult => $_getN(12);
  @$pb.TagNumber(20)
  set cmdScanThreadResult(CmdScanThreadResult value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasCmdScanThreadResult() => $_has(12);
  @$pb.TagNumber(20)
  void clearCmdScanThreadResult() => $_clearField(20);
  @$pb.TagNumber(20)
  CmdScanThreadResult ensureCmdScanThreadResult() => $_ensure(12);

  @$pb.TagNumber(21)
  RespScanThreadResult get respScanThreadResult => $_getN(13);
  @$pb.TagNumber(21)
  set respScanThreadResult(RespScanThreadResult value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasRespScanThreadResult() => $_has(13);
  @$pb.TagNumber(21)
  void clearRespScanThreadResult() => $_clearField(21);
  @$pb.TagNumber(21)
  RespScanThreadResult ensureRespScanThreadResult() => $_ensure(13);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
