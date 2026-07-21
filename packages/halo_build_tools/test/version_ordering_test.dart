// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('isNewerRelease', () {
    test('a higher major/minor/patch is newer', () {
      expect(isNewerRelease(current: '26.8.1', available: '27.0.0'), isTrue);
      expect(isNewerRelease(current: '26.8.1', available: '26.9.0'), isTrue);
      expect(isNewerRelease(current: '26.8.1', available: '26.8.2'), isTrue);
    });

    test('the same or an older release is not newer', () {
      expect(isNewerRelease(current: '26.8.1', available: '26.8.1'), isFalse);
      expect(isNewerRelease(current: '26.8.1', available: '26.8.0'), isFalse);
      expect(isNewerRelease(current: '26.8.1', available: '26.7.9'), isFalse);
    });

    test('missing trailing components are treated as zero', () {
      // `latestRelease` is often just the line, e.g. "26.8".
      expect(isNewerRelease(current: '26.7.5', available: '26.8'), isTrue);
      expect(isNewerRelease(current: '26.8.0', available: '26.8'), isFalse);
      expect(isNewerRelease(current: '26.8', available: '26.8.0'), isFalse);
    });

    test('pre-release modifiers are stripped before comparing', () {
      // A pre-release of the line you are already on is not a newer binary.
      expect(isNewerRelease(current: '26.8.1-alpha1', available: '26.8.1'), isFalse);
      expect(isNewerRelease(current: '26.8.1-alpha1', available: '26.8.1-beta2'), isFalse);
      // ...but a pre-release of a genuinely newer line still counts.
      expect(isNewerRelease(current: '26.8.1', available: '26.9.0-pre1'), isTrue);
    });

    test('empty or unparseable available never prompts', () {
      expect(isNewerRelease(current: '26.8.1', available: ''), isFalse);
      expect(isNewerRelease(current: '26.8.1', available: 'garbage'), isFalse);
      expect(isNewerRelease(current: '26.8.1', available: 'v.next'), isFalse);
    });
  });
}
