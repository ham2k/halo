// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Regressions for defects a review found — each one a case where the code's
// own comment or the documentation already claimed the safe behavior while
// the code did the unsafe thing. That combination is what makes them worth
// pinning: the next reader has no reason to doubt the claim.

import 'dart:convert';
import 'dart:io';

import 'package:halo_cli/src/cli.dart';
import 'package:halo_cli/src/commands/account_commands.dart';
import 'package:halo_cli/src/config.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String configPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('halo-cli-review');
    configPath = '${temp.path}/halo-cli.json';
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Map<String, Object?> readConfig() => (jsonDecode(File(configPath).readAsStringSync()) as Map).cast<String, Object?>();

  /// Names a throwaway `--cache` alongside `--config`: without it the run
  /// falls back to `defaultCacheDir()` and opens the DEVELOPER'S own
  /// reference database — see account_test.dart's own `run` for what that
  /// costs. `--config` alone is deliberately still exercised below by the
  /// tests about `--config` itself, which pass their own argument lists.
  Future<int> run(List<String> args) => runHaloExt(['--config', configPath, '--cache', '${temp.path}/cache', ...args]);

  group('the environment overrides one run, never the file', () {
    test('a HALO_SETTING_ override is not written back by an unrelated save', () {
      // Same rule the secrets already followed. Without it, one
      // `HALO_SETTING_developerMode=true …` run plus any save — an
      // extension's setSettings, an `account set` — turns a one-off override
      // into stored state the operator never chose and cannot see.
      File(configPath).writeAsStringSync(
        jsonEncode({
          'settings': {'operatorCall': 'KI2D'},
        }),
      );
      final config = CliConfig.load(path: configPath, environment: {'HALO_SETTING_developerMode': 'true'});
      expect(config.settings['developerMode'], isTrue, reason: 'the override applies to this run');

      config.setExtensionSettings('pota', {'showSpots': true});

      final saved = (readConfig()['settings'] as Map);
      expect(saved.containsKey('developerMode'), isFalse);
      expect(saved['operatorCall'], 'KI2D', reason: 'what was in the file stays');
    });
  });

  group('--config', () {
    test('a writer may CREATE the file it was pointed at', () async {
      // `--config ci.json account set …` is the documented CI path. Requiring
      // the file to exist first made it impossible to ever produce one.
      expect(await run(['account', 'set', 'qrz', 'username=N0DEV']), 0);
      expect(File(configPath).existsSync(), isTrue);
    });

    test('a reader still refuses a path that is not there', () async {
      // The typo guard: proceeding with empty credentials looks exactly like
      // an extension that has none.
      expect(await runHaloExt(['--config', '${temp.path}/nope.json', '--cache', '${temp.path}/cache', 'account', 'list']), 2);
    });

    test('a config that is not a JSON object is a config error, not a crash', () {
      File(configPath).writeAsStringSync('[]');
      expect(() => CliConfig.load(path: configPath), throwsA(predicate((e) => '$e'.contains('must hold a JSON object'))));
    });
  });

  group('a field typed wrong is refused', () {
    // The two sources used to be validated separately, so anything piped in
    // through `--stdin` walked straight past the check and was stored.
    final qrz = AccountDefinition(
      key: 'qrz',
      kvKey: 'qrz',
      label: 'QRZ.com',
      description: null,
      usesOAuth: false,
      fields: [
        AccountField(key: 'username', label: 'Login', type: 'text'),
        AccountField(key: 'password', label: 'Password', type: 'secret'),
      ],
    );

    test('on the command line', () async {
      final stored = File(configPath)..writeAsStringSync('{}');
      expect(await run(['account', 'set', 'qrz', 'passwrod=hunter2']), 2);
      expect(stored.readAsStringSync(), isNot(contains('passwrod')));
    });

    test('and through --stdin', () {
      expect(
        () => assignmentsFor(account: qrz, stdinLines: const ['passwrod=hunter2']),
        throwsA(predicate((e) => '$e'.contains('passwrod') && '$e'.contains('`password`'))),
      );
    });

    test('while the declared fields go through from either source', () {
      expect(assignmentsFor(account: qrz, commandLine: const ['username=N0DEV'], stdinLines: const ['password=hunter2']), {
        'username': 'N0DEV',
        'password': 'hunter2',
      });
    });

    test('a value containing = keeps it', () {
      expect(assignmentsFor(account: qrz, commandLine: const ['password=a=b']), {'password': 'a=b'});
    });
  });
}
