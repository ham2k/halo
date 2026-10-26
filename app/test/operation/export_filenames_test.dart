// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An export hook names the file its content lands in, and that name is the
// extension's word. Joined onto the directory the operator chose as it comes,
// `../../Library/LaunchAgents/x.plist` writes extension-controlled content
// anywhere the app can. Every writer takes the name through
// `safeExportFilename`; this file holds it to the directory.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/export_service.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';

/// `saveToDisk` is a pure writer: it reads neither the log nor the runtime.
/// A repository read reaching this fake is a design change, not a test gap.
class _UnusedQsos implements QsosRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('safeExportFilename', () {
    test('keeps a plain name as offered', () {
      expect(safeExportFilename('2026-10-26 N0CALL abc.adi'), '2026-10-26 N0CALL abc.adi');
      expect(safeExportFilename('K-TEST ñandú.cbr'), 'K-TEST ñandú.cbr');
    });

    test('keeps only the last segment of a path, under either separator convention', () {
      expect(safeExportFilename('../../Library/LaunchAgents/x.plist'), 'x.plist');
      expect(safeExportFilename(r'..\..\Users\sd\x.plist'), 'x.plist');
      expect(safeExportFilename(r'C:\Users\sd\x.plist'), 'x.plist');
      expect(safeExportFilename(r'\\server\share\x.plist'), 'x.plist');
      expect(safeExportFilename('/etc/passwd'), 'passwd');
      expect(safeExportFilename('dir/'), 'dir');
    });

    test('drops control characters and what Windows refuses in a name', () {
      expect(safeExportFilename('log\u0000.adi'), 'log.adi');
      expect(safeExportFilename('log\u0085.adi'), 'log.adi', reason: 'a C1 control is as invisible as a C0 one');
      expect(safeExportFilename('a<b>c:d"e|f?g*h.txt'), 'abcdefgh.txt');
      expect(safeExportFilename('  padded.adi \n'), 'padded.adi');
      // Windows drops trailing dots and spaces itself, so two such names
      // would be one file there.
      expect(safeExportFilename('x.adi.'), 'x.adi');
      expect(safeExportFilename('x.adi . '), 'x.adi');
      expect(safeExportFilename('.hidden'), '.hidden');
    });

    test('drops format characters, which would show one extension and save another', () {
      expect(safeExportFilename('report\u202Eida.exe'), 'reportida.exe');
      expect(safeExportFilename('a\u200Bb.adi'), 'ab.adi');
      expect(safeExportFilename('x\u2028y\u2029z.adi'), 'xyz.adi');
    });

    test('a Windows device name is no name: it writes to the device and nothing lands', () {
      for (final device in ['NUL.adi', 'nul', 'CON.log', 'PRN', 'aux.txt', 'COM0.adi', 'COM1.adi', 'COM¹.adi', 'LPT0', 'LPT9', 'lpt³.txt']) {
        expect(safeExportFilename(device), 'export.txt', reason: device);
      }
      expect(safeExportFilename('console.adi'), 'console.adi');
      expect(safeExportFilename('nul2.adi'), 'nul2.adi');
      expect(safeExportFilename('com10.adi'), 'com10.adi');
    });

    test('a name with nothing left is export.txt', () {
      expect(safeExportFilename(null), 'export.txt');
      expect(safeExportFilename(''), 'export.txt');
      expect(safeExportFilename('..'), 'export.txt');
      expect(safeExportFilename('...'), 'export.txt');
      expect(safeExportFilename('/'), 'export.txt');
      expect(safeExportFilename(r'C:\'), 'export.txt');
      expect(safeExportFilename(r'\\server\share'), 'export.txt');
      expect(safeExportFilename('\u0001\u0002'), 'export.txt');
      expect(safeExportFilename(' . . '), 'export.txt');
    });
  });

  group('safeExportFilename length', () {
    test('a name longer than a filesystem holds is cut to fit, extension kept', () {
      final long = safeExportFilename('${'a' * 300}.adi');
      expect(long, endsWith('.adi'));
      expect(long.length, 255);

      // Cut by characters, never through one: every byte that stays is a
      // whole ñ.
      final wide = safeExportFilename('${'ñ' * 200}.adi');
      expect(wide, endsWith('.adi'));
      expect(wide.codeUnits.length <= 255, isTrue);
      expect(wide.substring(0, wide.length - 4).replaceAll('ñ', ''), isEmpty);
      expect(wide.substring(0, wide.length - 4).length * 2 + 4 <= 255, isTrue, reason: 'ñ is two bytes');
    });
  });

  group('uniqueExportFilenames', () {
    test('a disambiguated name is checked against every name already given', () {
      expect(
        uniqueExportFilenames([
          {'filename': 'log.adi'},
          {'filename': 'log.adi'},
          {'filename': 'log-2.adi'},
        ]),
        ['log.adi', 'log-2.adi', 'log-2-2.adi'],
      );
      expect(
        uniqueExportFilenames([
          {'filename': 'log-2.adi'},
          {'filename': 'log.adi'},
          {'filename': 'log.adi'},
        ]),
        ['log-2.adi', 'log.adi', 'log-3.adi'],
      );
    });

    test('two offers that differ only in the directories they named still come out distinct', () {
      expect(
        uniqueExportFilenames([
          {'filename': '../../evil.plist'},
          {'filename': r'..\..\evil.plist'},
          {'filename': 'ok.adi'},
          {'filename': null},
          {'filename': '/'},
        ]),
        ['evil.plist', 'evil-2.plist', 'ok.adi', 'export.txt', 'export-2.txt'],
      );
    });

    test('names that a filesystem would merge come out distinct', () {
      expect(
        uniqueExportFilenames([
          {'filename': 'Log.adi'},
          {'filename': 'log.adi'},
          {'filename': 'x.adi'},
          {'filename': 'x.adi.'},
        ]),
        ['Log.adi', 'log-2.adi', 'x.adi', 'x-2.adi'],
      );
    });

    test('never returns anything but a bare name', () {
      const hostile = ['../x', r'..\x', '/x', r'\x', r'C:\x', '//x', 'a/b/c', r'a\b\c', '.', '..', '', 'x/..'];
      for (final name in uniqueExportFilenames([
        for (final h in hostile) {'filename': h},
      ])) {
        // `basename` of a root is the root, so being one's own basename is
        // not enough: no separator at all.
        expect(name, isNot(anyOf(contains('/'), contains('\\'), '.', '..', isEmpty)), reason: name);
        expect(p.posix.basename(name), name, reason: name);
        expect(p.windows.basename(name), name, reason: name);
      }
    });
  });

  group('saveToDisk on desktop', () {
    late Directory chosen;
    late ExportService exports;
    final asked = <MethodCall>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();
      exports = ExportService(extensions: ExtensionService(), qsos: _UnusedQsos(), settings: settings);
      // The chosen directory sits two levels inside a root the test owns, so
      // a `../../` that escaped would land where the test looks, and nowhere
      // the test's cleanup would not reach.
      final root = Directory.systemTemp.createTempSync('halo-export-root');
      chosen = Directory(p.join(root.path, 'a', 'b', 'chosen'))..createSync(recursive: true);
      addTearDown(() => root.deleteSync(recursive: true));
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      asked.clear();
      // file_selector has no plugin under `flutter test`; its method channel
      // answers here as the operator would: this directory, or a path in it.
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call);
        return switch (call.method) {
          'getDirectoryPath' => chosen.path,
          'getSavePath' => p.join(chosen.path, (call.arguments as Map)['suggestedName'] as String),
          _ => null,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    });

    test('several files land inside the chosen directory whatever path their hooks named', () async {
      final saved = await exports.saveToDisk([
        {'filename': '../../evil.plist', 'content': 'one'},
        {'filename': r'..\..\evil.plist', 'content': 'two'},
        {'filename': 'ok.adi', 'content': 'three'},
      ]);
      expect(saved?.location, chosen.path);
      expect(saved?.count, 3);
      expect(File(p.join(chosen.path, 'evil.plist')).readAsStringSync(), 'one');
      expect(File(p.join(chosen.path, 'evil-2.plist')).readAsStringSync(), 'two');
      expect(File(p.join(chosen.path, 'ok.adi')).readAsStringSync(), 'three');
      expect(chosen.listSync(), hasLength(3));
      for (final above in [chosen.parent, chosen.parent.parent]) {
        expect(above.listSync().whereType<File>(), isEmpty, reason: above.path);
      }
    });

    test('a single file is offered to the save dialog under its bare name', () async {
      final saved = await exports.saveToDisk([
        {'filename': '../../evil.plist', 'content': 'one'},
      ]);
      final save = asked.singleWhere((c) => c.method == 'getSavePath');
      expect((save.arguments as Map)['suggestedName'], 'evil.plist');
      expect(saved?.location, p.join(chosen.path, 'evil.plist'));
      expect(File(p.join(chosen.path, 'evil.plist')).readAsStringSync(), 'one');
    });
  });
}
