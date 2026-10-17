// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/error_reporting_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ErrorReportingService.resetForTesting);
  tearDown(ErrorReportingService.resetForTesting);

  Future<ExtensionService> service() async {
    SharedPreferences.setMockInitialValues({});
    return ExtensionService()..settings = SettingsService(await SharedPreferences.getInstance());
  }

  test('preloading and copying credentials work without native plugins', () async {
    final extensions = await service();
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      await preloadShippedExtensionsForTest(extensions);
      await extensions.setAccountCredentials('old-account', {'username': 'N0DEV'});
      await extensions.copyExtensionSecrets(from: 'old-account', to: 'new-account');
      expect(await extensions.getAccountCredentials('new-account'), {'username': 'N0DEV'});
      expect(backend.exceptions, isEmpty, reason: 'a successful fixture must not hide plugin failures behind passing assertions');
    }, backend: backend);
  });

  test('a custom keychain failure still reaches the service and error reporter', () async {
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'KeyringLocked', message: 'locked'));
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final extensions = await service();
    prepareExtensionServiceForTest(extensions);
    final backend = FakeErrorReportingBackend();
    await withErrorHooks(() async {
      expect(
        await extensions.getAccountCredentials('qrz'),
        isNull,
        reason: 'fixture setup must not replace a test of unavailable storage with an empty keychain',
      );
      expect(backend.exceptions.single.error, isA<PlatformException>());
      expect(backend.exceptions.single.context, 'accounts:read-credentials');
    }, backend: backend);
  });

  test('the fixture shuts down its real runtime at teardown', () async {
    final extensions = await service();
    // Registered first, so this observes the fixture after its own cleanup.
    addTearDown(() => expect(extensions.ready, isFalse, reason: 'a runtime must not keep running after its temporary store is deleted'));
    await startWithShippedExtensions(extensions);
    expect(extensions.ready, isTrue);
    expect(extensions.firstCatchUpSettled, isTrue);
  });
}
