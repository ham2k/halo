// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Which other Ham2K loggers a build looks for, and how. The
// rules are in sibling_apps_service.dart's header; the two that a plausible
// edit breaks silently are that a build never offers to link with ITSELF,
// and that iOS probes the `halo` alias family rather than `logger` — a
// `logger` probe passes every unit test and then answers yes on a device
// whose only other logger is a pre-526 build of some OTHER edition.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ham2k_logger/config/version.dart';
import 'package:ham2k_logger/services/sibling_apps_service.dart';
import 'package:ham2k_logger/views/switch_accounts_dialog.dart';

import '../support/error_reporting_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final android = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final ios = File('ios/Runner/Info.plist').readAsStringSync();

  group('the running edition is never offered', () {
    // The mutation to catch is a filter comparing against the wrong field —
    // a name, an id prefix — that lets a build offer to link with itself.
    for (final edition in Edition.values) {
      test('$edition, Android', () {
        final offered = filterSiblings(androidSiblingCatalog, running: edition);
        expect(offered.map((a) => a.edition), isNot(contains(edition)));
        expect(offered.where((a) => a.edition == null), hasLength(3), reason: 'every PoLo flavor stays');
        expect(offered, hasLength(androidSiblingCatalog.length - 1));
      });
      test('$edition, iOS', () {
        final offered = filterSiblings(iosSiblingCatalog, running: edition);
        expect(offered.map((a) => a.edition), isNot(contains(edition)));
        expect(offered, hasLength(iosSiblingCatalog.length - 1));
      });
    }
  });

  test('iOS probes the halo ALIAS family, never logger', () {
    for (final app in iosSiblingCatalog) {
      expect(app.id, isNot(startsWith('com.ham2k.logger')), reason: '${app.id} would match a pre-526 build of any edition');
      if (app.edition != null) expect(app.id, 'com.ham2k.halo.${app.edition!.name}');
    }
  });

  test('every iOS probe is a scheme the plist lets this app ask about', () {
    // canOpenURL answers false for a scheme missing from
    // LSApplicationQueriesSchemes whether or not the app is installed.
    final queried = RegExp(r'<key>LSApplicationQueriesSchemes</key>\s*<array>(.*?)</array>', dotAll: true)
        .firstMatch(ios)!
        .group(1)!;
    final schemes = RegExp(r'<string>([^<]+)</string>').allMatches(queried).map((m) => m.group(1)!).toSet();
    expect(schemes, containsAll(iosSiblingCatalog.map((a) => a.id)));
  });

  test('the Android catalog is exactly the packages the manifest may query', () {
    // Android 11+ hides a package not named in <queries>: a catalog entry
    // missing there reads as "not installed" while sitting on the device.
    final queries = RegExp(r'<queries>(.*?)</queries>', dotAll: true).firstMatch(android)!.group(1)!;
    final packages = RegExp(r'<package android:name="([^"]+)"\s*/>').allMatches(queries).map((m) => m.group(1)!).toSet();
    expect(androidSiblingCatalog.map((a) => a.id).toSet(), packages);
  });

  test('the link is the QR link — the scheme retargeted on iOS, untouched on Android', () {
    // Both paths build from linkClientQrUrl, so a change to that format
    // reaches the sibling flow too; what differs is only the targeting.
    final url = linkClientQrUrl(clientUuid: 'c-1', challengeToken: 't-1');
    const polo = SiblingApp(id: 'com.ham2k.polo', name: 'PoLo');
    expect(siblingLinkUrl(polo, url, platform: TargetPlatform.iOS), 'com.ham2k.polo:///link_client?id=c-1&token=t-1');
    const poloPackage = SiblingApp(id: 'com.ham2k.polo.prod', name: 'PoLo');
    expect(siblingLinkUrl(poloPackage, url, platform: TargetPlatform.android), url);
  });

  group('SiblingAppsService over the channel', () {
    const channel = MethodChannel('ham2k/sibling_apps');
    final calls = <MethodCall>[];
    List<String> installed = const [];

    setUp(() {
      calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'list' => installed,
          'open' => true,
          _ => throw MissingPluginException(),
        };
      });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('asks only about the filtered catalog, and answers in catalog order', () async {
      installed = ['com.ham2k.logger.next', 'com.ham2k.polo.prod'];
      final found = await SiblingAppsService().list();
      final asked = (calls.single.arguments as Map)['ids'] as List;
      expect(asked, isNot(contains('com.ham2k.logger.${kEdition.name}')), reason: 'never asks about itself');
      expect(found.map((a) => a.id), ['com.ham2k.polo.prod', 'com.ham2k.logger.next']);
    });

    test('a native defect in list is reported, not read as "nothing installed"', () async {
      // The native halves throw nothing expected, so a PlatformException is
      // a bug — and the offer silently not appearing is all anyone would
      // otherwise see of it.
      final backend = FakeErrorReportingBackend();
      await withErrorHooks(() async {
        installed = const [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'error', message: 'kotlin blew up');
        });
        expect(await SiblingAppsService().list(), isEmpty);
        expect(backend.exceptions, hasLength(1));
      }, backend: backend);
    });

    test('a native defect in open propagates to the caller', () async {
      // False is the EXPECTED answer's spelling ("not installed any more");
      // a defect must not wear it.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'error', message: 'kotlin blew up');
      });
      const app = SiblingApp(id: 'com.ham2k.polo.prod', name: 'PoLo');
      expect(() => SiblingAppsService().open(app, 'com.ham2k:///link_client'), throwsA(isA<PlatformException>()));
    });

    test('open hands the native side the id and the retargeted url', () async {
      const app = SiblingApp(id: 'com.ham2k.polo.prod', name: 'PoLo');
      expect(await SiblingAppsService().open(app, 'com.ham2k:///link_client?id=1&token=2'), isTrue);
      expect(calls.single.arguments, {'id': 'com.ham2k.polo.prod', 'url': 'com.ham2k:///link_client?id=1&token=2'});
    });
  });

  test('without a native half there are no siblings, and open fails quietly', () async {
    // Web, desktop and the plain test binding: the offer simply never
    // appears, which is the pre-526 onboarding.
    expect(await SiblingAppsService().list(), isEmpty);
    expect(await SiblingAppsService().open(const SiblingApp(id: 'x', name: 'x'), 'com.ham2k:///link_client'), isFalse);
  });
}
