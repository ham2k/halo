// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The kernel asks the host for an account's credentials before EVERY hook
// method call (its own cache lives 3 s), and each `getAccount` is two keychain
// reads. On Linux a keychain read is several blocking D-Bus round trips on the
// GTK thread: without the host's in-memory copy, every navigation freezes for
// as long as gnome-keyring takes, once per account-bearing extension, and a
// locked keyring turns each of those into an unlock attempt. These tests pin
// that the host answers from memory after the first read, that every writer
// keeps the copy honest, and that a remembered failure is bounded.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/extension_account_cache.dart';
import 'package:ham2k_logger/services/extension_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  /// A keychain that counts its reads. [locked] models gnome-keyring refusing:
  /// every read throws, the way the Linux plugin reports KeyringLocked.
  /// [failDeletes] models macOS 26 refusing a delete with -34018.
  ({Map<String, String> store, List<String> reads}) fakeKeychain({bool locked = false, bool failDeletes = false}) {
    final store = <String, String>{};
    final reads = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          reads.add(key!);
          if (locked) throw PlatformException(code: 'KeyringLocked', message: 'locked');
          return store[key];
        case 'write':
          store[key!] = args['value'] as String;
          return null;
        case 'delete':
          if (failDeletes) throw PlatformException(code: '-34018', message: 'errSecMissingEntitlement');
          store.remove(key);
          return null;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    return (store: store, reads: reads);
  }

  Future<Map<String, dynamic>> getAccount(ExtensionService s, String kvKey) async =>
      (await s.debugHandleHostCall('getAccount', {'kvKey': kvKey})) as Map<String, dynamic>;

  setUp(() => AccountContextCache.unreadableRetry = const Duration(seconds: 60));

  test('a second hook-context read for the same account costs no keychain read', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"n0dev"}';
    final service = ExtensionService();

    final first = await getAccount(service, 'qrz');
    expect(first['credentials'], {'username': 'n0dev'});
    expect(keychain.reads, ['account_creds_qrz', 'account_session_qrz']);

    final second = await getAccount(service, 'qrz');
    expect(second['credentials'], {'username': 'n0dev'});
    // The trap: the kernel re-asks after its 3 s TTL, and every extra read
    // here is a UI freeze on Linux.
    expect(keychain.reads, hasLength(2), reason: 'the second getAccount reached the keychain again');
  });

  test('a locked keyring is asked once per account, not once per hook call', () async {
    final keychain = fakeKeychain(locked: true);
    final service = ExtensionService();

    final first = await getAccount(service, 'qrz');
    expect(first['unavailable'], isTrue);
    expect(keychain.reads, hasLength(1));

    final second = await getAccount(service, 'qrz');
    expect(second['unavailable'], isTrue, reason: 'a cached failure must still say "could not look", not "signed out"');
    expect(keychain.reads, hasLength(1), reason: 'the locked keyring was asked again');
  });

  test('writing credentials replaces the copy and drops the old session', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"old"}';
    keychain.store['account_session_qrz'] = '{"token":"from-old-login"}';
    final service = ExtensionService();
    expect((await getAccount(service, 'qrz'))['session'], {'token': 'from-old-login'});

    await service.setAccountCredentials('qrz', {'username': 'new'});
    final after = await getAccount(service, 'qrz');
    expect(after['credentials'], {'username': 'new'});
    // A stale copy here keeps the OLD account's OAuth session acting for the
    // new login — the exact leak setAccountCredentials deletes the item for.
    expect(after['session'], isEmpty);
    expect(keychain.reads, hasLength(2), reason: 'the write should update the copy, not force a reread');
  });

  test('a session the keychain would not delete is not claimed gone', () async {
    final keychain = fakeKeychain(failDeletes: true);
    keychain.store['account_creds_qrz'] = '{"username":"old"}';
    keychain.store['account_session_qrz'] = '{"token":"from-old-login"}';
    final service = ExtensionService();
    await getAccount(service, 'qrz');

    await service.setAccountCredentials('qrz', {'username': 'new'});
    // A copy saying "no session" here hides the leak until the next launch
    // reads the old token back from the keychain.
    expect((await getAccount(service, 'qrz'))['session'], {'token': 'from-old-login'});
  });

  test('a session written by the extension is what the next hook call sees', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"n0dev"}';
    final service = ExtensionService();
    await getAccount(service, 'qrz');

    await service.debugHandleHostCall('setAccountSession', {
      'kvKey': 'qrz',
      'session': {'token': 'fresh'},
    });
    expect((await getAccount(service, 'qrz'))['session'], {'token': 'fresh'});
    expect(keychain.reads, hasLength(2));
  });

  test('clearing the account signs the next hook call out', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"n0dev"}';
    final service = ExtensionService();
    await getAccount(service, 'qrz');

    await service.clearAccount('qrz');
    final after = await getAccount(service, 'qrz');
    expect(after['credentials'], isEmpty);
    expect(after.containsKey('unavailable'), isFalse);
  });

  test('a remembered failure is asked again once the retry interval has passed', () async {
    fakeKeychain(locked: true);
    final service = ExtensionService();
    expect((await getAccount(service, 'qrz'))['unavailable'], isTrue);

    // The phone unlocks; nothing in the app tells the host so. Without the
    // retry, every lookup stays signed out until Settings › Accounts opens or
    // the app restarts — the keychain-locked rule promises the unlock resolves it.
    final unlocked = fakeKeychain();
    unlocked.store['account_creds_qrz'] = '{"username":"n0dev"}';
    expect((await getAccount(service, 'qrz'))['unavailable'], isTrue, reason: 'inside the interval the copy stands');

    AccountContextCache.unreadableRetry = Duration.zero;
    final after = await getAccount(service, 'qrz');
    expect(after.containsKey('unavailable'), isFalse);
    expect(after['credentials'], {'username': 'n0dev'});
    expect(unlocked.reads, hasLength(2));
  });

  test('a session the extension wrote clears a remembered failure', () async {
    fakeKeychain(locked: true);
    final service = ExtensionService();
    expect((await getAccount(service, 'qrz'))['unavailable'], isTrue);

    final unlocked = fakeKeychain();
    unlocked.store['account_creds_qrz'] = '{"username":"n0dev"}';
    await service.debugHandleHostCall('setAccountSession', {
      'kvKey': 'qrz',
      'session': {'token': 'fresh'},
    });
    // The write proved the keychain works; leaving the failure in place would
    // hide the session just written from the very next hook call.
    final after = await getAccount(service, 'qrz');
    expect(after.containsKey('unavailable'), isFalse);
    expect(after['session'], {'token': 'fresh'});
  });

  test('a read made through the flag-refresh bypass is not remembered', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"n0dev"}';
    final service = ExtensionService();

    // The bypass reads under device-local options, which may not be this
    // account's; remembering that answer pins it for the whole generation.
    service.debugRefreshingAccountSynchronizable = true;
    await getAccount(service, 'qrz');
    service.debugRefreshingAccountSynchronizable = false;
    await getAccount(service, 'qrz');
    expect(keychain.reads, hasLength(4), reason: 'the bypass read was served as the resolved-flag answer');
  });

  test('the Accounts UI reading the keychain evicts the copy, so a synced item reaches hooks', () async {
    final keychain = fakeKeychain();
    keychain.store['account_creds_qrz'] = '{"username":"old"}';
    final service = ExtensionService();
    await getAccount(service, 'qrz');

    // Written by another device (iCloud Keychain), not by this process.
    keychain.store['account_creds_qrz'] = '{"username":"synced"}';
    expect(await service.getAccountCredentials('qrz'), {'username': 'synced'});
    expect((await getAccount(service, 'qrz'))['credentials'], {
      'username': 'synced',
    }, reason: 'hooks still used the old credentials the Accounts panel no longer shows');
  });

  test('the Accounts UI reading a keyring that now works clears a cached failure', () async {
    fakeKeychain(locked: true);
    final service = ExtensionService();
    expect((await getAccount(service, 'qrz'))['unavailable'], isTrue);

    // The keyring unlocks mid-session.
    final unlocked = fakeKeychain();
    unlocked.store['account_creds_qrz'] = '{"username":"n0dev"}';
    expect(await service.getAccountCredentials('qrz'), {'username': 'n0dev'});

    final after = await getAccount(service, 'qrz');
    expect(after.containsKey('unavailable'), isFalse, reason: 'hooks stayed "unavailable" after the dialog proved the keyring works');
    expect(after['credentials'], {'username': 'n0dev'});
  });
}
