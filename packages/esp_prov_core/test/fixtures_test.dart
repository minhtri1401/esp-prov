import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  test('fixtures were generated from the pinned Espressif commits', () {
    for (final name in [
      'sec1_pop.json',
      'sec1_no_pop_carry.json',
      'sec2_example.json',
      'sec2_short_b.json',
      'sec2_short_s.json',
    ]) {
      final generator = loadFixture(name)['generator']! as Map<String, Object?>;
      expect(
        generator['esp_idf'],
        '4d59230ddff16327812782151ef0afef202dc6d7',
        reason: name,
      );
      expect(
        generator['idf_extra_components'],
        '69e8b21e1a20c8c1c48f5d5cffceeb0bc262eed0',
        reason: name,
      );
    }
  });

  test('Security 2 edge-case fixtures exercise short B and short S', () {
    expect(
      hexField(loadFixture('sec2_short_b.json'), 'device_public_key'),
      hasLength(lessThan(384)),
    );
    expect(
      loadFixture('sec2_short_s.json')['premaster_secret_length'],
      lessThan(384),
    );
    expect(
      hexField(loadFixture('sec2_example.json'), 'client_public_key'),
      hasLength(384),
    );
  });
}
