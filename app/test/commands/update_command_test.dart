// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// UPDATE (update-commands) end to end on its data-file side: the real
// extension's actions, which data files a word names, and the pass that
// fetches them — past their max age, but never past the ETag check.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/data_file_manager.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/services/status_bar_service.dart';

import '../support/halo_test_support.dart';

class _CannedDataFileManager extends DataFileManager {
  final Map<String, String> bodiesByKey;
  final downloads = <({String key, bool force})>[];

  _CannedDataFileManager({required this.bodiesByKey, required super.lookups, required super.extensions, required super.prefs, super.statusBar});

  @override
  Future<String?> downloadFile(String key, String url, {bool force = false, String? encoding}) async {
    downloads.add((key: key, force: force));
    return bodiesByKey[key];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late LookupRepository lookups;
  late ExtensionService extensions;

  setUp(() async {
    db = HaLoDatabase(NativeDatabase.memory());
    lookups = LookupRepository(db);
    SharedPreferences.setMockInitialValues({});
    // SOTA is off by default; on here so a POTA pass has a neighbour to leave alone.
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setExtensionOverrides({'sota': true});
    extensions = ExtensionService()
      ..lookups = lookups
      ..settings = settings;
    await startWithShippedExtensions(extensions);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Map<String, dynamic>?> interpret(String input) async {
    final entries = await extensions.host!.invokeHookAll('command', method: 'interpret', args: {'input': input});
    for (final entry in entries) {
      if (entry['ok'] == true && entry['value'] is Map) return (entry['value'] as Map).cast<String, dynamic>();
    }
    return null;
  }

  group('UPDATE interpretation (real update-commands extension)', () {
    test('a data file word reaches the app as words, for it to match', () async {
      final result = await interpret('UPDATE pota');
      expect(result?['commands'], [
        {
          'updateDataFiles': {
            'matching': ['POTA'],
          },
        },
      ]);
    });

    test('DATA, APP and EXT each name their own action, and UPD is UPDATE', () async {
      expect((await interpret('UPDATE DATA'))?['commands'], [
        {'updateDataFiles': <String, dynamic>{}},
      ]);
      expect((await interpret('UPD APP'))?['commands'], [
        {'updateApp': <String, dynamic>{}},
      ]);
      expect((await interpret('UPD EXT'))?['commands'], [
        {'updateExtensions': <String, dynamic>{}},
      ]);
      expect((await interpret('UPDATE EXTENSIONS'))?['commands'], [
        {'updateExtensions': <String, dynamic>{}},
      ]);
    });

    test('a bare UPDATE is recognized but waits for a target', () async {
      // Without expectsParams, Enter on a bare UPDATE logs it as a callsign.
      final result = await interpret('UPDATE');
      expect(result?['expectsParams'], isTrue);
      expect(result?['commands'], isNull);
    });
  });

  group('dataFileAnswersTo', () {
    const callNotes = {'key': 'ham2k-call-notes-hams-of-note', 'category': 'call-notes', 'name': "Ham2K's Hams of Note"};

    test('a word is a whole word of the category, key or name, any case', () {
      expect(dataFileAnswersTo(callNotes, ['NOTES']), isTrue, reason: 'from the category');
      expect(dataFileAnswersTo(callNotes, ['hams']), isTrue, reason: 'from the name');
      // Prefixes don't answer: NOT would otherwise reach every call-notes file.
      expect(dataFileAnswersTo(callNotes, ['NOT']), isFalse);
    });

    test('every word must answer, so more words narrow', () {
      expect(dataFileAnswersTo(callNotes, ['CALL', 'NOTES']), isTrue);
      expect(dataFileAnswersTo(callNotes, ['CALL', 'HISTORY']), isFalse);
    });

    test('no words names nothing', () {
      // Otherwise an empty match would quietly mean "every file".
      expect(dataFileAnswersTo(callNotes, const []), isFalse);
    });

    test('a word with an accented letter stays one word', () {
      // Splitting on anything outside A-Z would cut "Élite" into "LITE".
      const custom = {'key': 'ham2k-call-notes-custom', 'category': 'call-notes', 'name': 'Notas Élite'};
      expect(dataFileAnswersTo(custom, ['ÉLITE']), isTrue);
      expect(dataFileAnswersTo(custom, ['LITE']), isFalse);
    });
  });

  test('UPDATE POTA fetches a fresh POTA file through the ETag check, and leaves SOTA alone', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = _CannedDataFileManager(
      lookups: lookups,
      extensions: extensions,
      prefs: prefs,
      bodiesByKey: {
        'ham2k-pota-all-parks':
            'reference,name,active,entityId,locationDesc,latitude,longitude,grid\n'
            'US-1234,Test State Park,1,291,US-CA,37.7749,-122.4194,\n',
        'ham2k-sota-all-summits':
            'SOTA Summits List\n'
            'SummitCode,SummitName,AssociationName,RegionName,Latitude,Longitude,AltM,Points,ValidFrom,ValidTo\n'
            'W6/CT-001,Test Peak,USA-California,Central,37.5,-122.1,1200,4,01/01/2020,31/12/2099\n',
      },
    );

    // Both freshly downloaded, as a sweep leaves them.
    await manager.syncAllDataFiles();
    final firstPass = manager.downloads.map((d) => d.key).toSet();
    expect(firstPass, containsAll(['ham2k-pota-all-parks', 'ham2k-sota-all-summits']), reason: 'sanity: both files are registered');
    manager.downloads.clear();

    // A plain sweep now fetches nothing: both are fresh. That is the gate
    // UPDATE has to get past.
    await manager.syncAllDataFiles(matching: ['POTA']);
    expect(manager.downloads, isEmpty);

    final matched = await manager.syncAllDataFiles(ignoreAge: true, matching: ['POTA']);
    expect(matched, 1);
    // `force: false` is the ETag check kept: a forced fetch re-downloads and
    // reprocesses tens of thousands of rows the server never changed.
    expect(manager.downloads, [(key: 'ham2k-pota-all-parks', force: false)]);
  });

  test('an UPDATE the server answers with 304 says the file is up to date', () async {
    // Clearing the progress quietly, as an unattended pass does, would leave
    // the operator who typed UPDATE unable to tell "nothing new" from "nothing
    // happened".
    final prefs = await SharedPreferences.getInstance();
    final statusBar = StatusBarService(prefs);
    final manager = _CannedDataFileManager(lookups: lookups, extensions: extensions, prefs: prefs, statusBar: statusBar, bodiesByKey: const {});

    await manager.syncAllDataFiles(ignoreAge: true, matching: ['POTA']);
    expect(statusBar.itemForKey('dataFile:ham2k-pota-all-parks')?.text, t.dataFiles.upToDate);
  });

  test('dataFilesAnswering names the files a word reaches, and none for a word that reaches nothing', () async {
    final manager = DataFileManager(lookups: lookups, extensions: extensions, prefs: await SharedPreferences.getInstance());
    final pota = await manager.dataFilesAnswering(['PARKS']);
    expect(pota, hasLength(1));
    expect(await manager.dataFilesAnswering(['NOSUCHFILE']), isEmpty);
  });
}
