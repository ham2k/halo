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
import 'package:halo_cli/src/commands/hook_commands.dart' show exportTarget;
import 'package:halo_cli/src/config.dart';
import 'package:path/path.dart' as p;
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
      expect(await run(['account', 'set', 'ham2k-qrz', 'username=N0DEV']), 0);
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

  group('files the CLI writes', () {
    // An export hook is extension code; its filename is the extension's to
    // choose. Joined as-is, `../.bashrc` writes the operator's shell startup,
    // and `.bashrc` does when --out is the home directory.
    test('an export lands in the directory named, under a name and nothing more', () {
      expect(exportTarget(temp.path, '../.bashrc').path, p.join(temp.path, 'bashrc'));
      expect(exportTarget(temp.path, '/etc/passwd').path, p.join(temp.path, 'passwd'));
      expect(exportTarget(temp.path, r'..\..\x.adi').path, p.join(temp.path, 'x.adi'));
      expect(exportTarget(temp.path, 42).path, p.join(temp.path, 'export.txt'));
      expect(exportTarget(configPath, '../elsewhere.adi').path, configPath, reason: 'a file named with --out is the file');
    });

    // Written in place, a new config is readable by others under the usual
    // umask until a chmod after the write, and a reader who opened it then
    // keeps reading every later save.
    test('the config, credentials and all, is never readable by anyone else', () {
      if (Platform.isWindows) return;
      String mode(String path) => (FileStat.statSync(path).mode & 0x1ff).toRadixString(8);
      CliConfig.load(environment: {'XDG_CONFIG_HOME': temp.path}).setAccountSession('qrz', {'key': 'abc123'});
      final made = '${temp.path}/ham2k';
      expect(mode('$made/halo-cli.json'), '600');
      expect(mode(made), '700', reason: 'a directory the CLI made for it is private too');
      expect(Directory(made).listSync().map((e) => e.uri.pathSegments.last), ['halo-cli.json'], reason: 'nothing left beside it');

      final shared = Directory('${temp.path}/shared')..createSync();
      Process.runSync('chmod', ['755', shared.path]);
      final loose = File('${shared.path}/halo-cli.json')..writeAsStringSync('{}');
      Process.runSync('chmod', ['644', loose.path]);
      CliConfig.load(path: loose.path).setAccountSession('qrz', {'key': 'abc123'});
      expect(mode(loose.path), '600', reason: 'a loose file is made private by the next save');
      expect(mode(shared.path), '755', reason: "a directory that was already there is not the CLI's to change");
      expect(shared.listSync().map((e) => e.uri.pathSegments.last), ['halo-cli.json'], reason: 'the staging directory goes once the file is in place');

      // A config kept elsewhere and linked here is the one that changes.
      final kept = File('${temp.path}/dotfiles/halo-cli.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      final link = Link('${temp.path}/linked.json')..createSync(kept.path);
      CliConfig.load(path: link.path).setAccountSession('qrz', {'key': 'abc123'});
      expect(FileSystemEntity.isLinkSync(link.path), isTrue);
      expect(kept.readAsStringSync(), contains('abc123'));
      expect(mode(kept.path), '600');
    });
  });
}
