// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What each platform's manifest CLAIMS, read from the manifests themselves.
//
// These files are the only statement of it — no Dart code registers a scheme
// on iOS, macOS or Android — so nothing but reading them can catch a claim
// drifting back. The Windows half of the same catalog is checked in
// windows_url_schemes_test.dart, which can call the Dart table directly.
//
// The rules under test are in deep_link_service.dart's header.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `<string>` inside EVERY `CFBundleURLSchemes` array.
///
/// All of them, not the first: `CFBundleURLTypes` is an array of dicts, and
/// one-dict-per-scheme is a perfectly ordinary way to write it (app-polo's own
/// Info.plist does). Reading only the first array would step straight over a
/// reinstated `com.ham2k.polo` added as a second dict — which is precisely how
/// someone would add one.
List<String> _plistClaimedSchemes(String plist) {
  final arrays = RegExp(r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>', dotAll: true).allMatches(plist);
  expect(arrays, isNotEmpty, reason: 'no CFBundleURLSchemes array in the plist');
  return [for (final array in arrays) ...RegExp(r'<string>(.*?)</string>').allMatches(array.group(1)!).map((m) => m.group(1)!)];
}

/// Every `<string>` inside `LSApplicationQueriesSchemes` — what canOpenURL is
/// PERMITTED TO ASK about, which is a different list from what is claimed.
List<String> _plistQueriedSchemes(String plist) {
  final array = RegExp(r'<key>LSApplicationQueriesSchemes</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
  expect(array, isNotNull, reason: 'no LSApplicationQueriesSchemes array in the plist');
  return RegExp(r'<string>(.*?)</string>').allMatches(array!.group(1)!).map((m) => m.group(1)!).toList();
}

/// `android:scheme` on every `<data>` in [xml], however the tag is spaced and
/// whatever else it carries.
///
/// Deliberately not `<data android:scheme="…"/>`: that exact form is one way
/// of several to write the same tag. `<data android:scheme="com.ham2k.polo" />`
/// — the spacing app-polo's own manifest uses — and
/// `<data android:scheme="com.ham2k.polo" android:host="*"/>` are the same
/// claim, and a pattern that misses them makes this guard pass on a manifest
/// that has the claim back.
List<String> _dataSchemesIn(String xml) =>
    RegExp(r'<data\s[^>]*android:scheme="([^"]+)"[^>]*>').allMatches(xml).map((m) => m.group(1)!).where((s) => s.startsWith('com.ham2k')).toList();

/// What the manifest CLAIMS — the `<data>` schemes on the activity's
/// intent-filters, with the `<queries>` block removed first.
///
/// Stripping `<queries>` is what makes this mean "claims". A scheme named
/// there is the Android counterpart of `LSApplicationQueriesSchemes` —
/// permission to ASK, granting no handler registration — so counting one as a
/// claim would fail the PoLo test for a manifest that claims nothing, exactly
/// when detection is extended to probe schemes rather than packages.
List<String> _manifestClaimedSchemes(String manifest) => _dataSchemesIn(manifest.replaceAll(RegExp(r'<queries>.*?</queries>', dotAll: true), ''));

void main() {
  final ios = File('ios/Runner/Info.plist').readAsStringSync();
  final macos = File('macos/Runner/Info.plist').readAsStringSync();
  final android = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  group('the readers see a claim however it is written', () {
    // These guards are only worth the file if they catch a claim added in a
    // form nobody used before. Each case below is a real spelling of the same
    // claim that an earlier, tighter reader stepped straight over — a silent
    // pass on a manifest that HAS the claim back.
    test('a scheme in a second CFBundleURLTypes dict still counts', () {
      const plist = '''
<key>CFBundleURLTypes</key>
<array>
  <dict><key>CFBundleURLSchemes</key><array><string>com.ham2k</string></array></dict>
  <dict><key>CFBundleURLSchemes</key><array><string>com.ham2k.polo</string></array></dict>
</array>''';
      expect(_plistClaimedSchemes(plist), contains('com.ham2k.polo'));
    });

    test('a <data> tag counts whatever its spacing or extra attributes', () {
      expect(_dataSchemesIn('<data android:scheme="com.ham2k.polo" />'), ['com.ham2k.polo']);
      expect(_dataSchemesIn('<data android:scheme="com.ham2k.polo" android:host="*"/>'), ['com.ham2k.polo']);
    });

    test('a scheme named only in <queries> is not a claim', () {
      // Permission to ask is not a registration. Counting it as one would
      // fail the PoLo guard below for a manifest that claims nothing.
      const manifest = '''
<manifest>
  <application><intent-filter><data android:scheme="com.ham2k"/></intent-filter></application>
  <queries><intent><data android:scheme="com.ham2k.polo"/></intent></queries>
</manifest>''';
      expect(_manifestClaimedSchemes(manifest), ['com.ham2k']);
    });
  });

  group('no Ham2K logger claims PoLo\'s schemes', () {
    // The whole sibling-app offer (HALO-526) rests on this. Onboarding asks
    // the OS whether PoLo is installed; an app that claims com.ham2k.polo
    // answers its own question, so the offer appears on a device that has
    // never had PoLo — and then opens itself. Reinstating the claim looks
    // harmless and breaks the feature silently, on devices only.
    test('iOS', () {
      expect(_plistClaimedSchemes(ios).where((s) => s.startsWith('com.ham2k.polo')), isEmpty);
    });
    test('macOS', () {
      expect(_plistClaimedSchemes(macos).where((s) => s.startsWith('com.ham2k.polo')), isEmpty);
    });
    test('Android', () {
      expect(_manifestClaimedSchemes(android).where((s) => s.startsWith('com.ham2k.polo')), isEmpty);
    });
  });

  group('an edition claims only its own edition schemes', () {
    // com.ham2k.halo.<edition> is usable as "is that edition installed?"
    // ONLY while exactly one app answers it. A manifest that spells the
    // editions out instead of templating them — which is what iOS and Android
    // both did before HALO-526 — makes every build answer for all three, and
    // the probe then reports siblings that are not there.
    test('iOS templates the edition rather than listing all three', () {
      final claimed = _plistClaimedSchemes(ios);
      expect(claimed, contains(r'com.ham2k.halo.$(HALO_EDITION)'));
      for (final edition in ['dev', 'next', 'prod']) {
        expect(claimed, isNot(contains('com.ham2k.halo.$edition')), reason: edition);
      }
    });

    test('macOS templates the edition rather than listing all three', () {
      final claimed = _plistClaimedSchemes(macos);
      expect(claimed, contains(r'com.ham2k.halo.$(HALO_EDITION)'));
      for (final edition in ['dev', 'next', 'prod']) {
        expect(claimed, isNot(contains('com.ham2k.halo.$edition')), reason: edition);
      }
    });

    test('Android templates the edition rather than listing all three', () {
      // ${editionScheme} is a manifestPlaceholder, set per flavor in
      // build.gradle.kts; the merged manifest resolves it to one edition.
      final claimed = _manifestClaimedSchemes(android);
      expect(claimed, contains(r'com.ham2k.halo.${editionScheme}'));
      for (final edition in ['dev', 'next', 'prod']) {
        expect(claimed, isNot(contains('com.ham2k.halo.$edition')), reason: edition);
      }
    });
  });

  group('the official com.ham2k.logger family stays claimed', () {
    // com.ham2k.logger* is the OFFICIAL prefix — it is what OAuth providers
    // hold on their redirect allowlists, so dropping one fails sign-in at the
    // provider. Detection nonetheless probes the .halo ALIAS family, because a
    // build older than HALO-526 claims every edition's .logger scheme and a
    // hit on one therefore names no particular edition.
    test('iOS', () {
      expect(
        _plistClaimedSchemes(ios),
        containsAll(<String>['com.ham2k', 'com.ham2k.logger', r'com.ham2k.logger.$(HALO_EDITION)', r'com.ham2k.logger.$(HALO_EDITION).auth']),
      );
    });
    test('macOS', () {
      expect(
        _plistClaimedSchemes(macos),
        containsAll(<String>['com.ham2k', 'com.ham2k.logger', r'com.ham2k.logger.$(HALO_EDITION)', r'com.ham2k.logger.$(HALO_EDITION).auth']),
      );
    });
    test('Android', () {
      expect(
        _manifestClaimedSchemes(android),
        containsAll(<String>['com.ham2k', 'com.ham2k.logger', r'com.ham2k.logger.${editionScheme}', r'com.ham2k.logger.${editionScheme}.auth']),
      );
    });
  });

  test('iOS may ask about PoLo and about every HaLo edition', () {
    // Claiming and querying are different keys: this list grants no handler
    // registration, so listing all three editions here does NOT make this
    // build answer for its siblings. All three are listed because the plist
    // is templated per edition and cannot know which one it is building; the
    // running edition always answers about itself and is excluded in Dart.
    expect(_plistQueriedSchemes(ios), containsAll(<String>['com.ham2k.polo', 'com.ham2k.halo.dev', 'com.ham2k.halo.next', 'com.ham2k.halo.prod']));
  });

  test('Android may query the sibling packages', () {
    // Android 11+ package-visibility filtering: without these, getPackageInfo
    // throws NameNotFoundException for an app that IS installed, and the
    // offer never appears — a silent false negative, not an error.
    final queries = RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(android);
    expect(queries, isNotNull);
    final packages = RegExp(r'<package android:name="([^"]+)"/>').allMatches(queries!.group(1)!).map((m) => m.group(1)!).toSet();
    expect(packages, containsAll(<String>['com.ham2k.polo.prod', 'com.ham2k.polo.beta', 'com.ham2k.polo.alpha']));
    expect(packages, containsAll(<String>['com.ham2k.logger.prod', 'com.ham2k.logger.next', 'com.ham2k.logger.dev']));
  });
}
