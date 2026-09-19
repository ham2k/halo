// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the bundle-freshness check counts as a source. It walks `extensions/`
// by suffix, and that tree also holds build OUTPUT with the same suffixes —
// so the walk has to tell the two apart, in both directions.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/bundles.dart';

void main() {
  late Directory root;
  final built = DateTime(2026, 1, 1, 12);
  final before = built.subtract(const Duration(minutes: 5));
  final after = built.add(const Duration(minutes: 5));

  void write(String path, DateTime modified) {
    final file = File('${root.path}/$path')..createSync(recursive: true);
    file.setLastModifiedSync(modified);
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('bundle_freshness');
    write('activities/pota/src/index.ts', before);
    write('activities/pota/manifest.json', before);
  });

  tearDown(() => root.deleteSync(recursive: true));

  // Building the SDK package after the bundles changes no source. Counted, it
  // fails every test in this package as STALE until the next bundle build.
  test('build output written after the bundles is not a changed source', () {
    write('sdk/dist/index.d.ts', after);
    write('sdk/dist/i18n/activityScoring.en.json', after);
    write('sdk/samples/k2hrc-radio/src/index.ts', after);
    write('sdk/samples/k2hrc-radio/manifest.json', after);
    write('samples/k2hrc-radio/build/manifest.json', after);
    write('node_modules/@ham2k/lib-callsigns/package.json', after);

    expect(newestExtensionSource(root)!.isAfter(built), isFalse);
  });

  // The skip list must not grow into the sources: a check that stops seeing
  // an edit silently tests the previous build, which is what it exists for.
  test('an edit anywhere a bundle is built from still counts', () {
    for (final path in [
      'activities/pota/src/index.ts',
      'sdk/src/kernel.ts',
      'samples/k2hrc-radio/src/index.ts',
      'samples/k2hrc-radio/manifest.json',
    ]) {
      write(path, after);
      expect(newestExtensionSource(root)!.isAfter(built), isTrue, reason: path);
      write(path, before);
    }
  });
}
