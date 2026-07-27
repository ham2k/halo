// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What HaLo does on a machine whose secure storage cannot be reached (#438) —
// on Linux, a box with no Secret Service running (gnome-keyring, KWallet,
// KeePassXC), or one whose keyring will not unlock. libsecret reports all of
// those as `KeyringLocked`, so nothing here claims which.
//
// The decision recorded in that issue is REQUIRE it: no bundling, no on-disk
// fallback. So the whole behaviour under test is: tell the operator, once, and
// let every surface degrade honestly instead of hanging.
//
// Three things are pinned, each of which was broken:
//   * a credential read that fails answers NULL, not `{}` — an empty map is
//     "this account is not connected", which is a claim about the account and
//     was the wrong one to make about the machine;
//   * the notice is Linux-only and shows once;
//   * the runtime path an extension actually uses says `unavailable` rather
//     than handing back an empty account, which reads as signed-out.
//
// The settings_view panels that used to spin or render fieldless are fixed in
// the same commit but are NOT pinned here — rendering them needs the extension
// host and a settings panel, which is `account_lookup_failure_test.dart`'s
// machinery. Said plainly rather than implied by this file's name.
//
// NOT covered: that libsecret's absence at the SHARED LIBRARY level does
// anything at all — it cannot, the process dies before `main()`. That case is
// documentation (docs/quirks.md), not code.

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Points the secure-storage channel at [handler] for one test.
void _mockSecureStorage(Future<Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, handler);
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));
}

/// What the Linux plugin actually raises: `KeyringLocked` covers no Secret
/// Service, no default collection, and a collection that would not unlock
/// (flutter_secure_storage_linux, `Secret.hpp` `warmupKeyring`).
Future<Object?> _keyringLocked(MethodCall call) async =>
    throw PlatformException(code: 'KeyringLocked', message: 'Keyring is locked');

Future<HaLoServices> _services(SharedPreferences prefs) async {
  final db = HaLoDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return HaLoServices(db, SettingsService(prefs));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading credentials', () {
    test('an unreachable keyring answers null, which is not the same as "not connected"', () async {
      _mockSecureStorage(_keyringLocked);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      expect(await extensions.getAccountCredentials('sota'), isNull);
    });

    test('a plugin that never registered is caught too, not just a keyring that refuses', () async {
      // Catching only PlatformException reopened the original hang: a build
      // where the Linux plugin failed to register raises MissingPluginException,
      // and `_loadAccounts` reads this before its own setState.
      _mockSecureStorage((call) async => throw MissingPluginException('no impl'));
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      expect(await extensions.getAccountCredentials('sota'), isNull);
    });

    test('a reachable keyring with nothing stored answers an empty map', () async {
      _mockSecureStorage((call) async => null);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      expect(await extensions.getAccountCredentials('sota'), isEmpty);
    });

    test('stored credentials come back as themselves', () async {
      _mockSecureStorage((call) async => call.method == 'read' ? '{"username":"KI2D"}' : null);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      expect(await extensions.getAccountCredentials('qrz'), {'username': 'KI2D'});
    });
  });

  group('the device key', () {
    test('an unreachable keyring leaves no key and says storage is unavailable', () async {
      SharedPreferences.setMockInitialValues({});
      _mockSecureStorage(_keyringLocked);
      final settings = SettingsService(await SharedPreferences.getInstance());

      expect(await settings.ensureSyncDeviceKey(), isNull, reason: 'boot must still complete');
      expect(settings.secureStorageUnavailable, isTrue);
    });

    test('a working keyring mints a key and reports storage as fine', () async {
      SharedPreferences.setMockInitialValues({});
      final written = <String, String>{};
      _mockSecureStorage((call) async {
        if (call.method == 'write') {
          written[call.arguments['key'] as String] = call.arguments['value'] as String;
          return null;
        }
        return call.method == 'read' ? written[call.arguments['key'] as String] : null;
      });
      final settings = SettingsService(await SharedPreferences.getInstance());

      expect(await settings.ensureSyncDeviceKey(), isNotNull);
      expect(settings.secureStorageUnavailable, isFalse);
    });
  });

  group('the notice', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.linux);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('is shown on Linux, once, and never again', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final services = await _services(prefs);

      maybeShowNoKeyringNotice(services);
      expect(
        services.statusBar.activeNotices.map((n) => n.key),
        contains(noKeyringNoticeKey),
      );
      expect(
        services.statusBar.activeNotices.single.text,
        t.settings.accounts.noKeyringText,
        reason: 'the operator is told what to install, not just that something failed',
      );

      // Dismissing and re-running boot must not resurrect it: `showNotice`
      // removes and re-adds by key, so a second post would undo the dismissal.
      services.statusBar.dismissNotice(noKeyringNoticeKey);
      maybeShowNoKeyringNotice(services);
      expect(services.statusBar.activeNotices, isEmpty);
    });

    test('is not shown on the platforms that have a keychain of their own', () async {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({});
        final services = await _services(await SharedPreferences.getInstance());

        maybeShowNoKeyringNotice(services);
        expect(services.statusBar.activeNotices, isEmpty, reason: '$platform needs no such advice');
      }
    });
  });

  group('what an extension sees at runtime', () {
    test('a host getAccount on an unreachable store says unavailable, not "no account"', () async {
      // The path the branch is named for. An unguarded throw here rejects the
      // host call, the kernel turns a rejection into `undefined`, and the
      // extension reads that as signed out — the collapse getAccountCredentials
      // refuses to make. Everything the Settings UI does is chrome next to this.
      _mockSecureStorage(_keyringLocked);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      final result = await extensions.debugHandleHostCall('getAccount', {'kvKey': 'sota'});
      expect(result, isA<Map>());
      expect((result as Map)['unavailable'], isTrue);
      expect(result['credentials'], isEmpty);
    });

    test('a reachable store answers with no `unavailable` flag at all', () async {
      _mockSecureStorage((call) async => null);
      final db = HaLoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final extensions = ExtensionService()..lookups = LookupRepository(db);

      final result = await extensions.debugHandleHostCall('getAccount', {'kvKey': 'sota'}) as Map;
      expect(result.containsKey('unavailable'), isFalse, reason: 'absent when nothing is wrong');
      expect(result['credentials'], isEmpty);
    });
  });
}
