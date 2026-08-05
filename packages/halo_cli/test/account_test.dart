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

  Future<int> run(List<String> args) => runHaloExt(['--config', configPath, ...args]);

  Map<String, Object?> storedFor(String kvKey) {
    final json = jsonDecode(File(configPath).readAsStringSync()) as Map<String, Object?>;
    final account = ((json['accounts'] as Map?) ?? const {})[kvKey];
    return account is Map ? account.cast<String, Object?>() : const {};
  }

  test('stores what the extension declared, and nothing it did not', () async {
    expect(await run(['account', 'set', 'qrz', 'username=N0DEV', 'password=hunter2']), 0);

    final credentials = storedFor('qrz')['credentials'] as Map;
    expect(credentials, {'username': 'N0DEV', 'password': 'hunter2'});
  });

  test('a misspelled field is refused, naming the real ones', () async {
    // Storing it would leave the account looking configured while the
    // extension reads null for the field it actually asked for — a failure
    // that surfaces much later as "QRZ lookups stopped working".
    expect(await run(['account', 'set', 'qrz', 'usrname=N0DEV']), 2);
    expect(storedFor('qrz'), isEmpty);
  });

  test('the stored credentials are what the extension reads back', () async {
    // The whole point of the command: `getAccount` is the host call every
    // account-using hook makes, and it must see what `set` wrote — under the
    // kvKey, wrapped the way the app wraps it.
    await run(['account', 'set', 'qrz', 'username=N0DEV', 'password=hunter2']);

    final config = CliConfig.load(path: configPath);
    final host = CliHostCalls(config: config, index: _emptyIndex);
    final account = await host.call('getAccount', {'kvKey': 'qrz'}) as Map;

    expect((account['credentials'] as Map)['username'], 'N0DEV');
    expect(account['session'], isEmpty);
  });

  test('a second set updates one field and keeps the rest', () async {
    // Changing a username must not silently blank the password stored beside
    // it — the file is the only copy, and there is no keychain to fall back
    // on.
    await run(['account', 'set', 'qrz', 'username=N0DEV', 'password=hunter2']);
    await run(['account', 'set', 'qrz', 'username=KI2D']);

    expect(storedFor('qrz')['credentials'], {'username': 'KI2D', 'password': 'hunter2'});
  });

  test('forget removes the account, and says so the second time', () async {
    await run(['account', 'set', 'qrz', 'username=N0DEV']);
    expect(await run(['account', 'forget', 'qrz']), 0);
    expect(storedFor('qrz'), isEmpty);
    // Not an error the first time, an error the second: "nothing to forget"
    // is worth saying, since the alternative reads as a successful delete of
    // credentials that are actually still somewhere.
    expect(await run(['account', 'forget', 'qrz']), 2);
  });

  test('an unknown account names what is available', () async {
    expect(await run(['account', 'set', 'nosuchaccount', 'a=b']), 2);
  });

  test('the config file holding credentials is not world-readable', () async {
    await run(['account', 'set', 'qrz', 'username=N0DEV', 'password=hunter2']);
    final mode = File(configPath).statSync().mode & 0x1FF;
    expect(mode, 0x180, reason: 'expected 0600, got ${mode.toRadixString(8)}');
  }, skip: Platform.isWindows ? 'POSIX modes' : null);
}

/// `getAccount` never looks at the bundle index; an empty one keeps this off
/// the filesystem.
final _emptyIndex = BundleIndex(directory: Directory('/nowhere'), kernelFile: 'kernel.js', extensions: const []);
