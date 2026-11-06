// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The move of an install's macOS secrets out of the keychain name every
// edition shared. What is at stake: a first launch that asks for the login
// keychain password (an item another edition created, under the shared
// name), and an existing install that silently loses what it had saved, or
// gets back what it has since changed or deleted.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/edition_keychain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../support/halo_test_support.dart';

/// The file keychain as the plugin's channel and the runner's listing see it:
/// items by (service, key). A [foreign] item belongs to another edition: read
/// with `kSecUseAuthenticationUIFail` it fails the way macOS does; read with a
/// dialog allowed it is [prompted], and released unless [declining].
/// [holdSharedReads] keeps every read under the shared name waiting, so a
/// test can act while a move is reading.
class _Keychain {
  final items = <(String, String), String>{};
  final foreign = <(String, String)>{};
  final sharedCalls = <String>[];
  var prompted = false;
  var declining = false;
  var listing = true;
  Completer<void>? holdSharedReads;

  static PlatformException _status(int code) => PlatformException(code: 'Unexpected security result code', details: code);

  Map<String, String> under(String service) => {
    for (final MapEntry(key: (s, k), :value) in items.entries)
      if (s == service) k: value,
  };

  void install() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const plugin = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    messenger.setMockMethodCallHandler(plugin, (call) async {
      final args = call.arguments as Map;
      final options = (args['options'] as Map).cast<String, String>();
      final id = (options['accountName']!, args['key'] as String);
      if (id.$1 == sharedMacKeychainService) sharedCalls.add('${call.method} ${id.$2}');
      switch (call.method) {
        case 'read':
          // Read before the hold: the answer is what the item held when asked.
          final value = items[id];
          if (id.$1 == sharedMacKeychainService) await holdSharedReads?.future;
          if (foreign.contains(id)) {
            if (options['authenticationUIBehavior'] == 'u_AuthUIF') throw _status(-25308);
            prompted = true;
            if (declining) throw _status(-128);
          }
          return value;
        case 'write':
          items[id] = args['value'] as String;
          return null;
        case 'delete':
          items.remove(id);
          return null;
        case 'containsKey':
          return items.containsKey(id);
        default:
          throw UnsupportedError('test keychain: ${call.method}');
      }
    });
    const runner = MethodChannel('ham2k/keychain');
    messenger.setMockMethodCallHandler(runner, (call) async {
      if (!listing) throw MissingPluginException();
      final service = (call.arguments as Map)['service'] as String;
      if (service == sharedMacKeychainService) sharedCalls.add('list');
      return under(service).keys.toList();
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin, null);
      messenger.setMockMethodCallHandler(runner, null);
    });
  }
}

/// A preferences file that cannot be written.
class _ReadOnlyPrefs extends InMemorySharedPreferencesStore {
  _ReadOnlyPrefs(super.data) : super.withData();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => throw StateError('read-only preferences');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Keychain keychain;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    MacKeychainMove.reset();
    keychain = _Keychain()..install();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    MacKeychainMove.reset();
  });

  /// A launch: the preferences as they are on disk, then the boot step.
  Future<SharedPreferences> launch(Map<String, Object> prefs) async {
    MacKeychainMove.reset();
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    await MacKeychainMove.start(instance);
    return instance;
  }

  Map<String, Object> persisted(SharedPreferences prefs) => {for (final key in prefs.getKeys()) key: prefs.get(key)!};

  const ranBefore = {'settings.general': '{}'};

  test('a first install starts under its own name and never touches the shared one, even where another edition left items', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'next-key';
    keychain.foreign.add((sharedMacKeychainService, 'syncDeviceKey'));
    await launch({});
    final storage = EditionSecureStorage();

    expect(await storage.read(key: 'syncDeviceKey'), isNull);
    await storage.write(key: 'syncDeviceKey', value: 'own');

    expect(keychain.sharedCalls, isEmpty);
    expect(keychain.prompted, isFalse);
    expect(keychain.under(editionMacKeychainService), {'syncDeviceKey': 'own'});
    expect(editionMacKeychainService, isNot(sharedMacKeychainService));
  });

  test('a first install stays a first install: the preferences its launch writes do not make the next launch move', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'next-key';
    final prefs = await launch({});
    await prefs.setString('settings.general', '{}');
    await launch(persisted(prefs));

    expect(MacKeychainMove.pending, isFalse);
    expect(keychain.sharedCalls, isEmpty);
  });

  test('an install that ran before brings everything it had over, and leaves the originals for the other editions', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'creds';
    await launch(ranBefore);

    expect(MacKeychainMove.pending, isFalse);
    expect(keychain.under(editionMacKeychainService), {'syncDeviceKey': 'mine', 'account_creds_ham2k-qrz': 'creds'});
    expect(keychain.under(sharedMacKeychainService), {
      'syncDeviceKey': 'mine',
      'account_creds_ham2k-qrz': 'creds',
    }, reason: 'another edition may still use them');
    expect(keychain.prompted, isFalse);
    expect(await EditionSecureStorage().read(key: 'syncDeviceKey'), 'mine');
  });

  test('a move happens once: a later launch does not copy the shared name over what was written since', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
    final prefs = await launch(ranBefore);
    await EditionSecureStorage().write(key: 'syncDeviceKey', value: 'newer');
    keychain.sharedCalls.clear();

    await launch(persisted(prefs));

    expect(await EditionSecureStorage().read(key: 'syncDeviceKey'), 'newer');
    expect(keychain.sharedCalls, isEmpty);
  });

  test('an item only a dialog would release keeps the install on the shared name, silently, with everything it had', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'theirs';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    await launch(ranBefore);
    final storage = EditionSecureStorage();

    expect(MacKeychainMove.pending, isTrue);
    expect(keychain.prompted, isFalse, reason: 'the boot attempt never shows the dialog');
    expect(keychain.under(editionMacKeychainService), isEmpty, reason: 'a failed attempt leaves nothing a later one would mistake for another install\'s');
    expect(await storage.read(key: 'syncDeviceKey'), 'mine');
    await storage.write(key: 'account_session_ham2k-qrz', value: 'token');
    expect(keychain.items[(sharedMacKeychainService, 'account_session_ham2k-qrz')], 'token', reason: 'until the operator decides, nothing changes');
  });

  test('a pending move is tried again, silently, on the next launch, and finishes once everything copies', () async {
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'creds';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    final prefs = await launch(ranBefore);
    expect(MacKeychainMove.pending, isTrue);

    keychain.foreign.clear();
    await launch(persisted(prefs));

    expect(MacKeychainMove.pending, isFalse);
    expect(keychain.under(editionMacKeychainService), {'account_creds_ham2k-qrz': 'creds'});
    expect(keychain.prompted, isFalse);
  });

  test('Retry lets macOS ask for the keychain password, and moves once it releases the item', () async {
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'creds';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    await launch(ranBefore);

    expect(await MacKeychainMove.retry(), isTrue);

    expect(keychain.prompted, isTrue);
    expect(MacKeychainMove.pending, isFalse);
    expect(await EditionSecureStorage().read(key: 'account_creds_ham2k-qrz'), 'creds');
  });

  test('a Retry whose dialog is turned down stays where it was', () async {
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'creds';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    keychain.declining = true;
    await launch(ranBefore);

    expect(await MacKeychainMove.retry(), isFalse);
    expect(MacKeychainMove.pending, isTrue);
  });

  test('Continue moves with what can be copied now, including what changed while pending, and without what was deleted', () async {
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'theirs';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    keychain.items[(sharedMacKeychainService, 'account_session_ham2k-qrz')] = 'old-token';
    keychain.items[(sharedMacKeychainService, 'cluster.dx.example:7300.password')] = 'secret';
    await launch(ranBefore);
    final storage = EditionSecureStorage();
    // Read at boot, these two have changed since. A move that kept what it
    // read then would answer the stale token, and bring back the password
    // the operator removed.
    await storage.write(key: 'account_session_ham2k-qrz', value: 'new-token');
    await storage.delete(key: 'cluster.dx.example:7300.password');

    await MacKeychainMove.continueWithout();

    expect(MacKeychainMove.pending, isFalse);
    expect(keychain.prompted, isFalse);
    expect(keychain.under(editionMacKeychainService), {'account_session_ham2k-qrz': 'new-token'});
  });

  test('a secret saved while Continue is reading is moved as saved, not as read', () async {
    // Listed first, so the move has its old value in hand before the save.
    keychain.items[(sharedMacKeychainService, 'account_session_ham2k-qrz')] = 'old-token';
    keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'theirs';
    keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
    await launch(ranBefore);
    final storage = EditionSecureStorage();

    keychain.holdSharedReads = Completer();
    final continuing = MacKeychainMove.continueWithout();
    await pumpEventQueue();
    // Still pending, so this lands under the shared name, after the move has
    // asked for the old value.
    await storage.write(key: 'account_session_ham2k-qrz', value: 'new-token');
    keychain.holdSharedReads!.complete();
    await continuing;

    expect(MacKeychainMove.pending, isFalse);
    expect(await storage.read(key: 'account_session_ham2k-qrz'), 'new-token');
  });

  test('what another install of this edition saved under its name is neither replaced nor deleted', () async {
    // A second build of the same edition, or a developer data sandbox: its own
    // preferences, the same keychain name, and secrets of its own there.
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'shared-key';
    keychain.items[(editionMacKeychainService, 'syncDeviceKey')] = 'other-install-key';
    keychain.items[(editionMacKeychainService, 'account_creds_ham2k-qrz')] = 'other-install-creds';
    await launch(ranBefore);

    expect(MacKeychainMove.pending, isFalse);
    expect(keychain.under(editionMacKeychainService), {'syncDeviceKey': 'other-install-key', 'account_creds_ham2k-qrz': 'other-install-creds'});
  });

  test('a runner that cannot list the keychain leaves the install on the shared name rather than stopping the boot', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
    keychain.listing = false;
    await launch(ranBefore);

    expect(MacKeychainMove.pending, isTrue);
    expect(await EditionSecureStorage().read(key: 'syncDeviceKey'), 'mine');
  });

  test('a move whose completion cannot be saved does not switch, so the next launch cannot copy over newer secrets', () async {
    keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
    SharedPreferencesStorePlatform.instance = _ReadOnlyPrefs({'flutter.settings.general': '{}'});
    SharedPreferences.resetStatic();
    await MacKeychainMove.start(await SharedPreferences.getInstance());

    expect(MacKeychainMove.pending, isTrue);
    expect(keychain.under(editionMacKeychainService), isEmpty, reason: 'what it wrote is taken back, or the next attempt would not replace it');
  });

  test('iOS keeps its single service and has nothing to move', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    keychain.items[(iosKeychainService, 'syncDeviceKey')] = 'phone';
    await launch(ranBefore);

    expect(MacKeychainMove.pending, isFalse);
    expect(await EditionSecureStorage().read(key: 'syncDeviceKey'), 'phone');
    expect(keychain.sharedCalls, ['read syncDeviceKey'], reason: 'its own read, under the one service, and no listing');
  });

  group('the notice', () {
    test('says nothing once the move is done', () async {
      final services = (await makeHaLoServices()).services;
      await launch(ranBefore);

      maybeShowKeychainMoveNotice(services);
      expect(services.statusBar.activeNotices, isEmpty);
    });

    test('offers Retry and Continue while pending, and comes back after a Retry that did not finish', () async {
      final services = (await makeHaLoServices()).services;
      keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'creds';
      keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
      keychain.declining = true;
      await launch(ranBefore);

      maybeShowKeychainMoveNotice(services);
      final notice = services.statusBar.activeNotices.single;
      expect(notice.title, t.notices.keychainMoveTitle);
      expect(notice.actions.map((a) => a.label), [t.notices.keychainMoveRetry, t.notices.keychainMoveContinue]);

      notice.actions.first.onTap();
      await pumpEventQueue();
      expect(services.statusBar.activeNotices.single.key, keychainMoveNoticeKey, reason: 'the operator still has a choice to make');

      services.statusBar.activeNotices.single.actions.last.onTap();
      await pumpEventQueue();
      expect(services.statusBar.activeNotices, isEmpty);
      expect(MacKeychainMove.pending, isFalse);
    });
  });

  group('the sync account', () {
    // The sync device key IS the device's identity on the sync server, and an
    // unknown one gets a brand-new account. A Continue that leaves the key
    // behind must not quietly start a second account for this Mac.
    Future<HaLoServices> launchWithSyncKeyLeftBehind({required bool keyLoaded}) async {
      keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
      keychain.foreign.add((sharedMacKeychainService, 'syncDeviceKey'));
      await launch({...ranBefore, 'syncState': '{"lastSyncAccountUUID":"acct-1"}'});
      final services = (await makeHaLoServices(prefs: null, secureStorage: EditionSecureStorage())).services;
      // Read while pending, under the shared name, with the dialog allowed —
      // the way boot loads it, and the one thing that can carry it now.
      if (keyLoaded) expect(await services.settings.ensureSyncDeviceKey(), 'mine');
      return services;
    }

    test('Continue keeps the key this session loaded, so the next launch is on the same account', () async {
      final services = await launchWithSyncKeyLeftBehind(keyLoaded: true);

      await continueKeychainMove(services);

      expect(MacKeychainMove.pending, isFalse);
      expect(keychain.items[(editionMacKeychainService, 'syncDeviceKey')], 'mine');
      expect(services.settings.syncState[SyncEngine.replacedAccountKey], isNull, reason: 'nothing is being replaced');
    });

    test('with no key loaded, Continue names the account being left, for the engine to combine into the new one', () async {
      final services = await launchWithSyncKeyLeftBehind(keyLoaded: false);

      await continueKeychainMove(services);

      expect(keychain.items[(editionMacKeychainService, 'syncDeviceKey')], isNull);
      expect(services.settings.syncState[SyncEngine.replacedAccountKey], 'acct-1');
      expect(MacKeychainMove.syncClientSplitDue, isFalse, reason: 'the key minted next is already this device\'s own');
    });

    test('a key that came across with the rest needs nothing more', () async {
      keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'mine';
      await launch({...ranBefore, 'syncState': '{"lastSyncAccountUUID":"acct-1"}'});
      final services = (await makeHaLoServices(prefs: null, secureStorage: EditionSecureStorage())).services;

      await services.settings.keepSyncIdentityAfterKeychainMove();

      expect(keychain.items[(editionMacKeychainService, 'syncDeviceKey')], 'mine');
      expect(services.settings.syncState[SyncEngine.replacedAccountKey], isNull);
    });
  });

  group('a sync client of its own', () {
    // The device key a move brings along may be one several editions read
    // from the shared name, and editions sharing a client fight over its sync
    // cooldown. The split gives this one its own client on the SAME account;
    // a split that half-happens must leave the device as the client it was,
    // never on a new client whose account is its own and empty.
    Future<(HaLoServices, _SplittingExtensions)> movedWithSyncKey(Map<String, Object?>? Function(String key) answer) async {
      // Another edition's item is the evidence the key may be shared.
      keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'shared-key';
      keychain.items[(sharedMacKeychainService, 'account_creds_ham2k-qrz')] = 'theirs';
      keychain.foreign.add((sharedMacKeychainService, 'account_creds_ham2k-qrz'));
      await launch(ranBefore);
      await MacKeychainMove.continueWithout();
      final extensions = _SplittingExtensions(answer);
      final services = (await makeHaLoServices(prefs: null, secureStorage: EditionSecureStorage(), extensions: extensions)).services;
      await services.settings.ensureSyncDeviceKey();
      return (services, extensions);
    }

    test('an install that moved gets a new client on its account, and keeps the new key from then on', () async {
      final (services, extensions) = await movedWithSyncKey((key) => {'client': 'client-2', 'account': 'acct-1'});
      expect(MacKeychainMove.syncClientSplitDue, isTrue);

      await services.splitSyncClientIfDue();

      final newKey = extensions.splitKeys.single;
      expect(newKey, isNot('shared-key'));
      expect(keychain.items[(editionMacKeychainService, 'syncDeviceKey')], newKey);
      expect(services.settings.syncDeviceKey, newKey);
      expect(extensions.credentials, [newKey], reason: 'a runtime restart replays the credentials it was last given');
      expect(keychain.items[(sharedMacKeychainService, 'syncDeviceKey')], 'shared-key', reason: 'another edition may still be that client');
      expect(MacKeychainMove.syncClientSplitDue, isFalse);
    });

    test('a split that does not finish leaves the device as the client it was, and is tried again', () async {
      final (services, extensions) = await movedWithSyncKey((key) => {'error': 'Forbidden', 'error_status': 403});

      await services.splitSyncClientIfDue();

      expect(keychain.items[(editionMacKeychainService, 'syncDeviceKey')], 'shared-key');
      expect(services.settings.syncDeviceKey, 'shared-key');
      expect(extensions.credentials, isEmpty);
      expect(MacKeychainMove.syncClientSplitDue, isTrue);
    });

    test('an install that only ever shared the name with itself keeps its client', () async {
      // Everything read without a dialog: no other edition left anything
      // there, and a split would only leave a dead device on the account.
      keychain.items[(sharedMacKeychainService, 'syncDeviceKey')] = 'own-key';
      await launch(ranBefore);

      expect(MacKeychainMove.pending, isFalse);
      expect(MacKeychainMove.syncClientSplitDue, isFalse);
    });

    test('a first install has no shared client to split from', () async {
      await launch({});
      final extensions = _SplittingExtensions((key) => {'client': 'client-2'});
      final services = (await makeHaLoServices(prefs: null, secureStorage: EditionSecureStorage(), extensions: extensions)).services;
      await services.settings.ensureSyncDeviceKey();

      await services.splitSyncClientIfDue();

      expect(extensions.splitKeys, isEmpty);
    });
  });
}

/// The transport's side of the split, answered by [answer] for the key the
/// app asks it to move to.
class _SplittingExtensions extends ExtensionServiceWithFakeHost {
  final Map<String, Object?>? Function(String key) answer;
  final splitKeys = <String>[];
  final credentials = <String>[];

  _SplittingExtensions(this.answer);

  @override
  Future<Map<String, dynamic>?> syncMoveToNewClient(String key) async {
    splitKeys.add(key);
    return answer(key)?.cast<String, dynamic>();
  }

  @override
  Future<void> setSyncCredentials({required String deviceKey, required String operatorCall}) async => credentials.add(deviceKey);
}
