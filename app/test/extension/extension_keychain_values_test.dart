// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// `host.keychainSet` and `ctx.keychain` through the REAL kernel: what one
// extension keeps there is its own, whatever another names, and its hooks see
// it on their very next call.

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/extensions/extension_keychain.dart';
import 'package:ham2k_logger/services/extensions/extension_keychain_values.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

/// A keychain that answers a turn later, as the platform's does, and can
/// refuse: [unreadable] names fail to read, every write fails while
/// [refuseWrites], and a delete of an item it does not hold fails as macOS 26
/// answers it.
class _Keychain implements FlutterSecureStorage {
  final items = <String, String>{};
  final unreadable = <String>{};
  var refuseWrites = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    final aTurnLater = Future<void>.delayed(Duration.zero);
    switch (invocation.memberName) {
      case #read:
        return aTurnLater.then<String?>((_) {
          if (unreadable.contains(key)) throw PlatformException(code: 'read', details: -25293);
          return items[key];
        });
      case #write:
        return aTurnLater.then<void>((_) {
          if (refuseWrites) throw PlatformException(code: 'write', details: -25308);
          items[key] = invocation.namedArguments[#value] as String;
        });
      case #delete:
        return aTurnLater.then<void>((_) {
          if (items.remove(key) == null) throw PlatformException(code: 'delete', details: -34018);
        });
    }
    return super.noSuchMethod(invocation);
  }
}

/// Keeps a value, and reports what its hooks are handed.
String probe(String key) =>
    '''
  globalThis.__halo.defineExtension({
    key: '$key',
    name: '$key',
    version: '0.0.1',
    onActivation(api) {
      api.registerHook('bench', {
        hook: {
          call: async (args, ctx) => {
            switch (args.probe) {
              case 'set':
                await api.hostCall('keychainSet', { key: args.key, value: args.value });
                return null;
              case 'setAs':
                await api.hostCall('keychainSet', { ns: args.ns, key: args.key, value: args.value });
                return null;
              case 'publicSet':
                return await globalThis.__halo.hostCall('keychainSet', { ns: args.ns, key: args.key, value: args.value });
            }
            return { keychain: ctx.keychain ?? null };
          },
        },
      });
    },
  });
''';

({String source, ExtensionInfo info}) bundle(String key) =>
    (source: probe(key), info: ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('through the kernel', () {
    late ExtensionService extensions;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      extensions = ExtensionService()..settings = settings;
      prepareExtensionServiceForTest(extensions);
      await extensions.setDevBundles({'keeper': bundle('keeper'), 'outsider': bundle('outsider')});
    });

    Future<dynamic> call(String who, String probe, [Map<String, dynamic> args = const {}]) =>
        extensions.host!.invokeHook('bench', key: who, method: 'call', args: {'probe': probe, ...args}, timeout: const Duration(seconds: 10));
    Future<dynamic> keychainOf(String who) async => ((await call(who, 'read')) as Map)['keychain'];

    test('a hook sees what its extension kept on its very next call, and nothing once removed', () async {
      expect(await keychainOf('keeper'), isEmpty);
      // Read once first, so a value cached for the context's lifetime would show here as stale.
      await call('keeper', 'set', {
        'key': 'logbooks',
        'value': [
          {'key': 'ABCD-1234', 'call': 'KI2D'},
        ],
      });
      expect(await keychainOf('keeper'), {
        'logbooks': [
          {'key': 'ABCD-1234', 'call': 'KI2D'},
        ],
      });
      await call('keeper', 'set', {'key': 'logbooks', 'value': null});
      expect(await keychainOf('keeper'), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test("another extension never sees it, and naming the keeper writes only into its own, or is refused", () async {
      await call('keeper', 'set', {'key': 'token', 'value': 'secret'});
      expect(await keychainOf('outsider'), isEmpty);

      await call('outsider', 'setAs', {'ns': 'keeper', 'key': 'token', 'value': 'forged'});
      expect(await keychainOf('keeper'), {'token': 'secret'});
      expect(await keychainOf('outsider'), {'token': 'forged'});

      await expectLater(
        call('outsider', 'publicSet', {'ns': 'keeper', 'key': 'token', 'value': 'forged'}),
        throwsA(isA<ExtensionHostException>().having((e) => e.toString(), 'message', contains('identity'))),
      );
      // The host holds the line on its own, whatever reached it.
      await expectLater(extensions.debugHandleHostCall('keychainSet', {'key': 'token', 'value': 'x'}), throwsA(isA<ExtensionHostException>()));
      expect(await keychainOf('keeper'), {'token': 'secret'});
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the store', () {
    late FlutterSecureStorage storage;
    late Set<String> recorded;
    ExtensionKeychainValues store() => ExtensionKeychainValues(
      storage,
      names: () => {...recorded},
      recordName: (name) async => recorded.add(name),
      forgetName: (name) async => recorded.remove(name),
    );

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = const FlutterSecureStorage();
      recorded = {};
    });

    test('a value survives into a later run, found by the names the app recorded writing', () async {
      await store().write('keeper', 'token', {'n': 1});
      expect(await store().read('keeper'), {
        'token': {'n': 1},
      });
      expect(recorded, {'extensionKeychain_keeper_token'});
    });

    test("an extension whose key starts another's reads only its own", () async {
      await store().write('keeper', 'token', 'a');
      await store().write('keeper-two', 'token', 'b');
      expect(await store().read('keeper'), {'token': 'a'});
      expect(isExtensionKeychainItemOf('extensionKeychain_keeper-two_token', 'keeper'), isFalse);
      expect(isExtensionKeychainItemOf('extensionKeychain_keeper_token', 'keeper'), isTrue, reason: 'an uninstall finds it');
    });

    test('removing a value forgets its name, so a later run does not ask the keychain for it', () async {
      final values = store();
      await values.write('keeper', 'token', 'a');
      await values.write('keeper', 'token', null);
      expect(recorded, isEmpty);
      expect(await store().read('keeper'), isEmpty);
    });

    test('a value that does not decode is left out, and the rest are still handed to the hooks', () async {
      final keychain = _Keychain();
      final values = ExtensionKeychainValues(
        keychain,
        names: () => {...recorded},
        recordName: (name) async => recorded.add(name),
        forgetName: (name) async => recorded.remove(name),
      );
      await values.write('keeper', 'good', 1);
      await values.write('keeper', 'bad', 2);
      keychain.items['extensionKeychain_keeper_bad'] = '{not json';
      // Failing the whole read would hide every value for good: the extension
      // is told only that storage is unreadable, and cannot tell which to fix.
      expect(await values.read('keeper'), {'good': 1});
    });

    test("a value the keychain would not take does not use up one of the extension's keys", () async {
      final keychain = _Keychain();
      final values = ExtensionKeychainValues(
        keychain,
        names: () => {...recorded},
        recordName: (name) async => recorded.add(name),
        forgetName: (name) async => recorded.remove(name),
      );
      await values.write('keeper', 'kept', 1);
      keychain.refuseWrites = true;
      await expectLater(values.write('keeper', 'refused', 2), throwsA(isA<PlatformException>()));
      await expectLater(values.write('keeper', 'kept', 3), throwsA(isA<PlatformException>()));
      expect(recorded, {'extensionKeychain_keeper_kept'}, reason: 'the one already kept stays found');
    });

    test('a value that cannot be read can still be replaced or removed, and removing one never set is no error', () async {
      final keychain = _Keychain();
      ExtensionKeychainValues values() => ExtensionKeychainValues(
        keychain,
        names: () => {...recorded},
        recordName: (name) async => recorded.add(name),
        forgetName: (name) async => recorded.remove(name),
      );
      await values().write('keeper', 'broken', 'x');
      await values().write('keeper', 'other', 'y');
      keychain.unreadable.add('extensionKeychain_keeper_broken');
      await expectLater(values().read('keeper'), throwsA(isA<PlatformException>()), reason: 'unreadable, not empty');

      // Writing needs none of the other values: one bad item must not lock
      // the extension out of the rest, or out of removing it.
      await values().write('keeper', 'other', 'z');
      await values().write('keeper', 'broken', null);
      keychain.unreadable.clear();
      expect(await values().read('keeper'), {'other': 'z'});

      await values().write('keeper', 'never-set', null);
    });

    test('an extension taking over another key gets its values, found by name, and keeps its own', () async {
      final keychain = _Keychain();
      ExtensionKeychainValues values() => ExtensionKeychainValues(
        keychain,
        names: () => {...recorded},
        recordName: (name) async => recorded.add(name),
        forgetName: (name) async => recorded.remove(name),
      );
      await values().write('old', 'logbooks', ['A']);
      await values().write('old', 'token', 't');
      await values().write('new', 'token', 'mine');
      final taking = values();
      expect(await taking.read('new'), {'token': 'mine'});

      await taking.copy(from: 'old', to: 'new');
      // Copied but not recorded, a read never finds them: the new extension
      // would see nothing entered.
      expect(await taking.read('new'), {
        'logbooks': ['A'],
        'token': 'mine',
      });
      expect(await values().read('old'), {
        'logbooks': ['A'],
        'token': 't',
      });
    });

    test("held to kvSet's limits: ten keys, and 4,096 characters of key and JSON each", () async {
      final values = store();
      for (var i = 0; i < kMaxKvKeysPerBundle; i++) {
        await values.write('keeper', 'k$i', i);
      }
      await expectLater(values.write('keeper', 'one-more', 1), throwsArgumentError);
      await values.write('keeper', 'k0', 'replacing one already kept is not one more');
      await expectLater(values.write('keeper', 'k1', 'x' * kMaxKvEntryChars), throwsArgumentError);
      await expectLater(values.write('keeper', '', 1), throwsArgumentError);
    });
  });
}
