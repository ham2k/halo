// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:halo_build_tools/halo_build_tools.dart';
import 'package:test/test.dart';

void main() {
  group('patch tag + wiring', () {
    test('tag name is patch-<edition> (matches codemagic.yaml patterns)', () {
      expect(patchTagName(Edition.next), 'patch-next');
      expect(patchTagName(Edition.dev), 'patch-dev');
    });

    test('platforms match the wired *-<edition>-patch workflows', () {
      // Keep in step with codemagic.yaml: next has all three, dev has no
      // android-dev-patch, prod has no patch plane yet.
      expect(patchPlatformsForEdition(Edition.next), ['ios', 'macos', 'android']);
      expect(patchPlatformsForEdition(Edition.dev), ['ios', 'macos']);
      expect(patchPlatformsForEdition(Edition.prod), isEmpty);
    });
  });

  group('isPatchBreakingPath', () {
    test('native platform projects force a full release', () {
      // A patch can't change compiled native code (docs/releases.md §4.2).
      for (final p in [
        'app/android/app/build.gradle',
        'app/ios/Runner/Info.plist',
        'app/macos/Runner/Release.entitlements',
        'app/windows/runner/main.cpp',
        'app/linux/my_application.cc',
        'packages/some_plugin/android/src/Foo.kt',
      ]) {
        expect(isPatchBreakingPath(p), isTrue, reason: p);
      }
    });

    test('dependency manifests are breaking (may pull in native code)', () {
      expect(isPatchBreakingPath('app/pubspec.yaml'), isTrue);
      expect(isPatchBreakingPath('app/pubspec.lock'), isTrue);
    });

    test('pure Dart and assets are patch-safe', () {
      for (final p in [
        'app/lib/services/auto_update_service.dart',
        'packages/halo_core/lib/src/foo.dart',
        'app/assets/updates-index.html',
        // "ios" as part of a filename, not a directory segment, is not native.
        'app/lib/services/ios_helper.dart',
      ]) {
        expect(isPatchBreakingPath(p), isFalse, reason: p);
      }
    });
  });

  group('classifyPatchChanges', () {
    test('splits breaking vs safe and drops blanks', () {
      final compat = classifyPatchChanges([
        'app/lib/main.dart',
        '  ', // blank — ignored
        'app/ios/Runner/Info.plist',
        'app/pubspec.yaml',
        'app/assets/x.png',
      ]);
      expect(compat.safe, ['app/lib/main.dart', 'app/assets/x.png']);
      expect(compat.breaking, ['app/ios/Runner/Info.plist', 'app/pubspec.yaml']);
      expect(compat.isPatchable, isFalse);
    });

    test('a pure-Dart changeset is patchable', () {
      final compat = classifyPatchChanges(['app/lib/a.dart', 'packages/halo_core/lib/b.dart']);
      expect(compat.isPatchable, isTrue);
      expect(compat.breaking, isEmpty);
    });
  });
}
