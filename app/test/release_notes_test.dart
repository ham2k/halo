// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/config/release_notes.dart';

void main() {
  test('parses entries newest-first, in file order, keyed by full version', () {
    final entries = parseReleaseNotesYaml('''
"26.8.0":
  name: "August '26"
  photoCaption: "M1SDH at GB-4724"
  changes:
    - "First change"
    - |
      A multi-line change
      that spans two lines
"26.7.0":
  name: "July '26"
  photoCaption: "Someone at Somewhere"
  changes:
    - "Older change"
''');

    // Order must be preserved (newest release first) — this is what drives
    // both the startup overlay's version lookup and the About screen's
    // "last 20 releases" list; if order silently flipped, the About screen
    // would show oldest-first without any visible error.
    expect(entries.map((e) => e.version), ['26.8.0', '26.7.0']);
    expect(entries.first.name, "August '26");
    expect(entries.first.photoCaption, 'M1SDH at GB-4724');
    expect(entries.first.changes, ['First change', 'A multi-line change\nthat spans two lines\n']);
  });

  test('mainVersion drops the patch component to match the release-image filename convention', () {
    final entries = parseReleaseNotesYaml('''
"26.8.3":
  name: "August '26 patch 3"
  photoCaption: ""
  changes: []
''');

    expect(entries.single.mainVersion, '26.8');
    expect(entries.single.imageAssetPath, 'assets/images/releases/26.8-photo.jpg');
  });

  test('missing name/photoCaption/changes fall back instead of throwing', () {
    final entries = parseReleaseNotesYaml('''
"26.9.0": {}
''');

    expect(entries.single.name, '26.9.0');
    expect(entries.single.photoCaption, '');
    expect(entries.single.changes, isEmpty);
  });

  test('a version key with no body (a plausible hand-editing typo) is skipped, not thrown', () {
    final entries = parseReleaseNotesYaml('''
"26.9.0":
"26.8.0":
  name: "August '26"
  photoCaption: ""
  changes: []
''');

    // One malformed entry must not blank out every other release — that
    // would silently break both the startup overlay and the About screen's
    // Recent Changes for every version, not just the bad one.
    expect(entries.map((e) => e.version), ['26.8.0']);
  });

  test('a field of the wrong type (e.g. changes as a string, not a list) is skipped, not thrown', () {
    final entries = parseReleaseNotesYaml('''
"26.9.0":
  name: "September '26"
  photoCaption: ""
  changes: "oops, forgot the list dashes"
"26.8.0":
  name: "August '26"
  photoCaption: ""
  changes: []
''');

    // A type mismatch on one field throws inside the cast, not just a null
    // check — without a try/catch around each entry, that exception would
    // propagate out of the whole parse and lose every release, not just the
    // malformed one.
    expect(entries.map((e) => e.version), ['26.8.0']);
  });
}
