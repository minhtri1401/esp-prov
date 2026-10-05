import 'package:esp_prov_core/esp_prov_core.dart';
import 'package:test/test.dart';

void main() {
  test('legacy v1.1 JSON without sec_ver means Security 1', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","cap":["wifi_scan"]}}',
    );
    expect(info.version, 'v1.1');
    expect(info.secVer, 1);
    expect(info.secPatchVer, 0);
    expect(info.capabilities, {'wifi_scan'});
  });

  test('no_sec without sec_ver means Security 0', () {
    expect(
      DeviceInfo.parse('{"prov":{"ver":"v1.1","cap":["no_sec"]}}').secVer,
      0,
    );
  });

  test('netprov-v1.2 with Thread capabilities', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"netprov-v1.2","sec_ver":2,"sec_patch_ver":1,'
      '"cap":["thread_scan","thread_prov"]}}',
    );
    expect(info.secVer, 2);
    expect(info.secPatchVer, 1);
    expect(info.hasCapability('thread_prov'), isTrue);
    expect(info.hasCapability('wifi_prov'), isFalse);
  });

  test('missing sec_patch_ver is 0', () {
    expect(
      DeviceInfo.parse('{"prov":{"ver":"v1.1","sec_ver":2}}').secPatchVer,
      0,
    );
  });

  test('extra application keys land in appInfo', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","sec_ver":2},"my_app":{"fw":"1.2.3"}}',
    );
    expect(info.appInfo, {
      'my_app': {'fw': '1.2.3'},
    });
  });

  test('a plain version string is legacy Security 1', () {
    final info = DeviceInfo.parse('V0.1');
    expect(info.version, 'V0.1');
    expect(info.secVer, 1);
    expect(info.capabilities, isEmpty);
  });

  test('trailing NUL bytes and numeric strings are tolerated', () {
    final info = DeviceInfo.parse(
      '{"prov":{"ver":"v1.1","sec_ver":"2","cap":[]}}\u0000',
    );
    expect(info.secVer, 2);
  });

  test('truncated JSON throws FormatException', () {
    expect(
      () => DeviceInfo.parse('{"prov":{"ver":"v1.1"'),
      throwsFormatException,
    );
  });

  test('JSON without prov throws FormatException', () {
    expect(
      () => DeviceInfo.parse('{"myapp":{"ver":"1"}}'),
      throwsFormatException,
    );
  });

  test('prov that is not a map throws FormatException', () {
    expect(() => DeviceInfo.parse('{"prov":"v1.1"}'), throwsFormatException);
  });

  test('legacy plain string strips trailing NULs', () {
    final info = DeviceInfo.parse('V0.1\u0000\u0000');
    expect(info.version, 'V0.1');
    expect(info.secVer, 1);
    expect(info.appInfo, isEmpty);
  });
}
