// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Spots Panel scores its board against the log through the same resume
// rule as the call-info pills: the cached checkpoint plus the contacts logged
// since it. The trap is the second after working a station — a board that
// resumed from the checkpoint alone would leave that station unstruck until
// the next rescore landed. So what this pins is the panel's OWN decision:
// that its pass hands the scorers the checkpoint AND the new contact.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extension_scoring.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/scoring_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart';

class _FakeExtensions extends ExtensionService {
  _FakeExtensions(this.board);

  final List<Map<String, dynamic>> board;
  final List<ScoringResume?> resumes = [];

  @override
  Future<Map<String, Map<String, List<String>>>?> scoreCandidates({
    required Map<String, dynamic> operation,
    required String operationUuid,
    required Map<String, Map<String, dynamic>> candidates,
    List<Map<String, dynamic>>? segments,
    ScoringResume? resume,
    Set<String> huntedRefTypes = const {},
  }) async {
    resumes.add(resume);
    return {};
  }

  @override
  Future<({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed})>
      getSpots() async => (items: board, succeeded: const ['test'], unreachable: const <String>[], failed: const <String>[]);

  @override
  Future<void> start() async {}

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);
}

Map<String, dynamic> _spot(String call) => {
      'their': {'call': call},
      'freq': 14250.0,
      'band': '20m',
      'mode': 'SSB',
      'refs': const <Map<String, dynamic>>[],
      'spot': {'timeInMillis': nowMillis() - 60000, 'source': 'test'},
      'hookKey': 'test',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the board\'s pass carries the checkpoint and the contact logged since it', (tester) async {
    tester.view.physicalSize = const Size(500, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();
    await settings.setSpottingFilters({'bandFilter': 'any', 'modeFilter': 'any', 'sortBy': 'frequency', 'groupByBand': true});
    final extensions = _FakeExtensions([_spot('K1ABC')]);
    final services = HaLoServices(db, settings, extensions: extensions);

    final operations = OperationsRepository(db);
    final qsos = QsosRepository(db);
    final created = await operations.create(stationCall: 'N0CALL', userTitle: 'Test Op');
    final folded = await qsos.add(created.uuid, {'their': {'call': 'W1AW'}, 'band': '20m', 'mode': 'SSB', 'startAtMillis': 1000});
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    final since = await qsos.add(created.uuid, {'their': {'call': 'K1ABC'}, 'band': '20m', 'mode': 'SSB', 'startAtMillis': 2000});
    // The last rescore's cache: it folded the first contact; the second is
    // the station just worked, which the rescore's own debounce has not yet
    // caught up with.
    await operations.updateLocalData(created.uuid, {
      'scoring': {
        'core': {
          'scoresheet': const {'worked': ['W1AW']},
          'scoresheetDay': 0,
          'checkpoint': {
            'digest': checkpointDigestOf([folded]),
            'updatedAtMillis': folded.updatedAtMillis,
            'startAtMillis': 1000,
            'operationUpdatedAtMillis': (await operations.get(created.uuid))!.updatedAtMillis,
          },
        },
      },
    });
    final operation = (await operations.get(created.uuid))!;
    final log = await qsos.forOperation(created.uuid);

    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: buildHaLoTheme(Brightness.light),
        home: Scaffold(
          body: SpotsPanel(
            operation: operation,
            services: services,
            logRevision: 'r1',
            visible: ValueNotifier(true),
            qsos: log,
          ),
        ),
      ),
    ));
    // The spots refresh, then the scoring debounce.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(extensions.resumes, isNotEmpty, reason: 'a board with a spot scores it');
    final resume = extensions.resumes.last;
    expect(resume, isNotNull, reason: 'the log is the checkpoint plus one contact: a resume, not a cold fold');
    expect(resume!.checkpoints['core']?.sheet, const {'worked': ['W1AW']});
    expect(resume.tail.map((q) => q['uuid']), [since.uuid], reason: 'the station just worked travels as the tail');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
