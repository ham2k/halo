// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Storing account credentials. These run the CLI end to end (a real runtime,
// real bundles, the real `account` hooks) because what is being checked is
// the agreement between three parties — the extension's declared fields, what
// gets written, and what `getAccount` hands back — and a fixture on either
// side would let that agreement drift while the test stayed green.

import 'dart:convert';
import 'dart:io';

import 'package:halo_cli/src/cli.dart';
import 'package:halo_cli/src/config.dart';
import 'package:halo_cli/src/bundles.dart';
import 'package:halo_cli/src/host_calls.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String configPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('halo-cli-account');
    configPath = '${temp.path}/halo-cli.json';
    File(configPath).writeAsStringSync('{}');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Every invocation names a throwaway `--cache` as well as a `--config`.
  /// Without it the run falls back to `defaultCacheDir()` — the DEVELOPER'S
  /// own `~/.cache/ham2k/halo-cli` — and opens the reference database there.
  /// A machine whose cache a newer build has already migrated then fails
  /// every test here on a schema error, with nothing in the failure naming
  /// the cache as the reason. It is also a real file this suite would
  /// otherwise create and leave behind on a machine that has never synced.
  Future<int> run(List<String> args) => runHaloExt(['--config', configPath, '--cache', '${temp.path}/cache', ...args]);

  Map<String, Object?> storedFor(String kvKey) {
    final json = jsonDecode(File(configPath).readAsStringSync()) as Map<String, Object?>;
    final account = ((json['accounts'] as Map?) ?? const {})[kvKey];
    return account is Map ? account.cast<String, Object?>() : const {};
  }

  test('stores what the extension declared, and nothing it did not', () async {
    expect(await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV', 'password=hunter2']), 0);

    final credentials = storedFor('ham2k-qrz')['credentials'] as Map;
    expect(credentials, {'username': 'N0DEV', 'password': 'hunter2'});
  });

  test('a misspelled field is refused, naming the real ones', () async {
    // Storing it would leave the account looking configured while the
    // extension reads null for the field it actually asked for — a failure
    // that surfaces much later as "QRZ lookups stopped working".
    expect(await run(['account', 'set', 'ham2k-qrz', 'usrname=N0DEV']), 2);
    expect(storedFor('ham2k-qrz'), isEmpty);
  });

  test('the stored credentials are what the extension reads back', () async {
    // The whole point of the command: `getAccount` is the host call every
    // account-using hook makes, and it must see what `set` wrote — under the
    // kvKey, wrapped the way the app wraps it.
    await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV', 'password=hunter2']);

    final config = CliConfig.load(path: configPath);
    final host = CliHostCalls(config: config, index: _emptyIndex);
    final account = await host.call('getAccount', {'ns': 'ham2k-qrz', 'kvKey': 'ham2k-qrz'}) as Map;

    expect((account['credentials'] as Map)['username'], 'N0DEV');
    expect(account['session'], isEmpty);
  });

  test("an extension reads and writes only the accounts in its own namespace", () async {
    // The kernel stamps the caller's namespace beside the kvKey, and the host
    // judges the pair again, as the app's does: a bundle served as another
    // key, or a kernel that let a foreign kvKey through, must not be handed
    // the QRZ login or be able to replace its session.
    await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV', 'password=hunter2']);
    final config = CliConfig.load(path: configPath);
    final host = CliHostCalls(config: config, index: _emptyIndex);

    expect(await host.call('getAccount', {'ns': 'ham2k-qrz', 'kvKey': 'ham2k-qrz_backup'}), isA<Map>(), reason: 'its own key and `_` before more is its own');
    for (final ns in ['ham2k-lofi', 'ham2k', null]) {
      await expectLater(host.call('getAccount', {'ns': ns, 'kvKey': 'ham2k-qrz'}), throwsStateError, reason: 'read as $ns');
      await expectLater(
        host.call('setAccountSession', {
          'ns': ns,
          'kvKey': 'ham2k-qrz',
          'session': {'key': 'forged'},
        }),
        throwsStateError,
        reason: 'written as $ns',
      );
    }
    expect(CliConfig.load(path: configPath).accountFor('ham2k-qrz')['session'], isEmpty);
  });

  test('a second set updates one field and keeps the rest', () async {
    // Changing a username must not silently blank the password stored beside
    // it — the file is the only copy, and there is no keychain to fall back
    // on.
    await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV', 'password=hunter2']);
    await run(['account', 'set', 'ham2k-qrz', 'username=KI2D']);

    expect(storedFor('ham2k-qrz')['credentials'], {'username': 'KI2D', 'password': 'hunter2'});
  });

  test('forget removes the account, and says so the second time', () async {
    await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV']);
    expect(await run(['account', 'forget', 'ham2k-qrz']), 0);
    expect(storedFor('ham2k-qrz'), isEmpty);
    // Not an error the first time, an error the second: "nothing to forget"
    // is worth saying, since the alternative reads as a successful delete of
    // credentials that are actually still somewhere.
    expect(await run(['account', 'forget', 'ham2k-qrz']), 2);
  });

  test('an unknown account names what is available', () async {
    expect(await run(['account', 'set', 'nosuchaccount', 'a=b']), 2);
  });

  test('the config file holding credentials is not world-readable', () async {
    await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV', 'password=hunter2']);
    final mode = File(configPath).statSync().mode & 0x1FF;
    expect(mode, 0x180, reason: 'expected 0600, got ${mode.toRadixString(8)}');
  }, skip: Platform.isWindows ? 'POSIX modes' : null);
}

/// `getAccount` never looks at the bundle index; an empty one keeps this off
/// the filesystem.
final _emptyIndex = BundleIndex(directory: Directory('/nowhere'), kernelFile: 'kernel.js', extensions: const []);
