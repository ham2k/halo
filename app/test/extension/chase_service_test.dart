// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Judging a station against the checklists (docs/design/claims.md §8): what
// the programs say working it would claim, compared against the `claims`
// table as it stands now — not as it stood when the station was first seen.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_extension_host/halo_extension_host.dart';
import 'package:ham2k_logger/services/chase_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_extension_host.dart';
import '../support/fake_secure_storage.dart';

/// A program whose checklist is the calls worked, each for any band, its
/// band and its mode.
List<Map<String, dynamic>> _claimsOf(Map<String, dynamic> qso) {
  final call = (qso['their'] as Map)['call'];
  return [
    {'holder': 'ME', 'ref': call, 'band': null, 'mode': null, 'level': 'worked'},
    {'holder': 'ME', 'ref': call, 'band': qso['band'], 'mode': null, 'level': 'worked'},
    {'holder': 'ME', 'ref': call, 'band': null, 'mode': qso['mode'], 'level': 'worked'},
  ];
}

Map<String, dynamic> _candidate(String call, {String band = '20m', String mode = 'CW', int at = 1000}) => {
  'their': {'call': call},
  'band': band,
  'mode': mode,
  'startAtMillis': at,
  'our': {'call': 'ME'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoDatabase db;
  late ClaimsRepository claims;
  late QsosRepository qsos;
  late SettingsService settings;
  late Map<String, Object?> stubs;
  late ChaseService service;
  late int asked;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: FakeSecureStorage());
    db = HaLoDatabase(NativeDatabase.memory());
    claims = ClaimsRepository(db);
    qsos = QsosRepository(db);
    asked = 0;
    stubs = {
      'chasing:*:program': [
        {
          'key': 'calls',
          'ok': true,
          'value': {
            'label': 'Calls',
            'version': 1,
            'editions': 'lifetime',
            'color': '#2e7d32',
            'supersedes': ['newCall'],
          },
        },
      ],
      'chasing:calls:claimsForQsos': (Object? args) {
        final sent = ((args as Map)['qsos'] as List).cast<Map<String, dynamic>>();
        asked += sent.length;
        return {for (final qso in sent) qso['uuid']: _claimsOf(qso)};
      },
    };
    service = ChaseService(
      extensions: ExtensionServiceWithFakeHost(FakeExtensionHost(stubs)),
      claims: claims,
      qsos: qsos,
      settings: settings,
      changeDebounce: Duration.zero,
    );
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() async {
    service.dispose();
    await db.close();
  });

  /// Writes the slots a contact with [call] on [band] in [mode] fills.
  Future<void> worked(String call, {String band = '20m', String mode = 'CW', String level = 'worked'}) => claims.applyUpgrades([
    for (final claim in _claimsOf(_candidate(call, band: band, mode: mode)))
      StoredClaim.fromQso(program: 'calls', version: 1, claim: QsoClaim.tryParse({...claim, 'level': level})!, qso: 'q-$call-$band-$mode', atMillis: 1),
  ]);

  /// Lets the table's change stream deliver and the debounce fire.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

  List<ChaseVerdict>? verdictOf(Map<String, List<ChaseJudgement>> judged, String key) => judged[key]?.singleOrNull?.verdicts;

  test('a station never worked is a new reference; one worked on another band, a new band', () async {
    await worked('W1AW', band: '40m', mode: 'CW', level: 'confirmed');
    final judged = await service.judge({'fresh': _candidate('K1ABC'), 'known': _candidate('W1AW')});
    expect(verdictOf(judged, 'fresh'), [ChaseVerdict.newRef]);
    expect(verdictOf(judged, 'known'), [ChaseVerdict.newBand]);
  });

  // A board is judged again on every spots refresh and every checklist
  // change. Asking the runtime each time is a crossing per spot per pass; a
  // spot's time moves on every pass, so a cache keyed on it would never hit.
  // But a program with editions claims by the contact's date, and an answer
  // for one day kept for another puts the claim in last year's checklist.
  test('the program is asked about a station once a day, however often it is judged', () async {
    await service.judge({'a': _candidate('K1ABC', at: 1000)});
    await service.judge({'a': _candidate('K1ABC', at: 61000), 'b': _candidate('K1ABC', at: 2000)});
    expect(asked, 1);
    await service.judge({'a': _candidate('K1ABC', band: '40m')});
    expect(asked, 2, reason: 'another band is another question');
    await service.judge({'a': _candidate('K1ABC', at: 1000 + Duration.millisecondsPerDay)});
    expect(asked, 3, reason: 'another day is another question');
  });

  // Logging the station fills its slots; a verdict still reading "new" sends
  // the operator after a contact they just made. Without dropping the cached
  // checklist on the table's change, the second judgement reads the old one.
  test('a slot filled after a verdict is read on the next judgement, and readers are told', () async {
    expect(verdictOf(await service.judge({'a': _candidate('K1ABC')}), 'a'), [ChaseVerdict.newRef]);
    final revision = service.revision;
    var told = 0;
    service.addListener(() => told++);
    await worked('K1ABC');
    await settle();
    expect(service.revision, greaterThan(revision));
    expect(told, greaterThan(0));
    expect(verdictOf(await service.judge({'a': _candidate('K1ABC')}), 'a'), [ChaseVerdict.unconfirmed]);
  });

  test('a goal turned off is not judged', () async {
    await service.setGoals([for (final goal in service.goals) goal.withOn(false)]);
    expect((await service.judge({'a': _candidate('K1ABC')}))['a'], isEmpty);
  });

  // A failure answered as "claims nothing" would read the same as a program
  // judging the station worked — and the next pass would not ask again.
  test('a program that fails leaves no verdict, and is asked again next time', () async {
    final working = stubs['chasing:calls:claimsForQsos']!;
    stubs['chasing:calls:claimsForQsos'] = ExtensionHostException('timed out');
    expect((await service.judge({'a': _candidate('K1ABC')}))['a'], isEmpty);
    stubs['chasing:calls:claimsForQsos'] = working;
    expect(verdictOf(await service.judge({'a': _candidate('K1ABC')}), 'a'), [ChaseVerdict.newRef]);
  });

  group('notices', () {
    const newRef = ChaseJudgement(program: 'calls', verdicts: [ChaseVerdict.newRef]);
    const unconfirmed = ChaseJudgement(program: 'calls', verdicts: [ChaseVerdict.unconfirmed]);
    const worked = ChaseJudgement(program: 'calls', verdicts: [ChaseVerdict.worked]);
    List<ChaseNotice> read(List<String> keys) => [for (final key in keys) ChaseNotice.tryParse(key)!];

    test('the Chasing view shows every verdict but worked; elsewhere only those alerting', () {
      expect(read(service.noticesFor([newRef, unconfirmed, worked], chasing: true)).map((n) => n.verdict), [ChaseVerdict.newRef, ChaseVerdict.unconfirmed]);
      expect(read(service.noticesFor([newRef, unconfirmed], chasing: false)).map((n) => n.verdict), [ChaseVerdict.newRef]);
      expect(read(service.noticesFor([newRef], chasing: true)).single.alerting, isTrue, reason: 'new references alert unless the operator says otherwise');
    });

    // "DXCC in 80m" and "DXCC in CW" each name their own: the band rides on
    // the new-band notice, the mode on the new-mode one.
    test('a new band carries its band, and a new mode its mode', () {
      const both = ChaseJudgement(program: 'calls', verdicts: [ChaseVerdict.newBand, ChaseVerdict.newMode], band: '80m', mode: 'CW');
      final notices = read(service.noticesFor([both], chasing: true));
      expect([for (final n in notices) (n.verdict, n.band, n.mode)], [(ChaseVerdict.newBand, '80m', null), (ChaseVerdict.newMode, null, 'CW')]);
    });

    test('the alerts the operator picks decide what alerts', () async {
      await service.setAlerting({ChaseVerdict.unconfirmed});
      final notices = read(service.noticesFor([newRef, unconfirmed], chasing: true));
      expect([for (final n in notices) (n.verdict, n.alerting)], [(ChaseVerdict.newRef, false), (ChaseVerdict.unconfirmed, true)]);
    });

    // A station worked this period is a dupe. A chasing notice beside the
    // dupe un-strikes the row and tells the operator to work it again.
    test('a duplicate carries no chasing notice, and the Chasing view keeps only scoring\'s dupe', () {
      final duplicate = service.withNotices((notices: ['newDay'], alerts: ['duplicate', 'invalidBand']), [newRef], chasing: true);
      expect(duplicate.notices, isEmpty);
      expect(duplicate.alerts, ['duplicate']);
      final fresh = service.withNotices((notices: ['newDay'], alerts: const []), [newRef], chasing: true);
      expect(fresh.notices.map(ChaseNotice.tryParse).nonNulls, hasLength(1));
      expect(fresh.notices, isNot(contains('newDay')), reason: "the period's scoring is not what the Chasing view ranks by");
    });

    test('elsewhere chasing notices join the operation\'s scoring', () {
      final merged = service.withNotices((notices: ['newBand'], alerts: ['invalidBand']), [newRef], chasing: false);
      expect(merged.notices.first, 'newBand');
      expect(merged.notices, hasLength(2));
      expect(merged.alerts, ['invalidBand']);
    });

    // DXCC's lifetime verdict and core scoring's "new in this operation"
    // would both read "New DXCC" about different checklists.
    test('a program judging the call drops the scoring notice it supersedes; one not judging leaves it', () {
      expect(service.withNotices((notices: ['newCall', 'newBand'], alerts: const []), [worked], chasing: false).notices, ['newBand']);
      expect(service.withNotices((notices: ['newCall'], alerts: const []), const [], chasing: false).notices, ['newCall']);
    });
  });

  // A goal that leaves no verdict leaves no judgement, so a judgement's
  // index says nothing about the goal: two spots each new to one program
  // would both rank as the first goal's, and tie on time.
  test("a spot ranks by its best verdict, and a tie goes to the goal the operator put first", () async {
    (stubs['chasing:*:program']! as List).add({
      'key': 'parks',
      'ok': true,
      'value': {'label': 'Parks', 'version': 1, 'editions': 'lifetime'},
    });
    service.extensions.runtimeGeneration.value++;
    await settle();
    await service.setGoals([...service.goals.reversed]);
    expect([for (final goal in service.goals) goal.key], ['parks', 'calls']);

    const callsRef = ChaseJudgement(program: 'calls', verdicts: [ChaseVerdict.newRef]);
    const parksRef = ChaseJudgement(program: 'parks', verdicts: [ChaseVerdict.newRef]);
    const parksBand = ChaseJudgement(program: 'parks', verdicts: [ChaseVerdict.newBand]);
    expect(service.rankOf([callsRef]), (rank: 3, goal: 1));
    expect(service.rankOf([parksRef]), (rank: 3, goal: 0));
    expect(service.rankOf([parksBand, callsRef]), (rank: 3, goal: 1), reason: 'a better verdict outranks an earlier goal');
    expect(service.rankOf(const []), isNull);
  });

  // The logging panel's typed calls share the cache with the board, one
  // entry per keystroke, so it fills in ordinary use. Starting over must not
  // lose the batch's own cached candidates, which [ChaseService.judge] reads
  // back from it: they would come out with no verdict, and alerts flicker.
  test('a batch that overflows the claims cache still judges the candidates it already had', () async {
    await service.judge({for (var i = 0; i < 3999; i++) 'k$i': _candidate('K$i')});
    final judged = await service.judge({'old': _candidate('K0'), 'new1': _candidate('N1'), 'new2': _candidate('N2')});
    expect(verdictOf(judged, 'old'), [ChaseVerdict.newRef]);
    expect(verdictOf(judged, 'new1'), [ChaseVerdict.newRef]);
  });

  // A checklist read that started before the table changed holds the table
  // as it was. Cached after the change drops the cache, it outlives the
  // change, and every later judgement reads the slot as still open.
  test('a checklist read overtaken by a change to the table is not kept', () async {
    final slow = _SlowClaims(db);
    final judging = ChaseService(extensions: service.extensions, claims: slow, qsos: qsos, settings: settings, changeDebounce: Duration.zero);
    addTearDown(judging.dispose);
    await settle();
    slow.gate = Completer<void>();
    final first = judging.judge({'a': _candidate('K1ABC')});
    await settle();
    await worked('K1ABC');
    await settle();
    slow.gate!.complete();
    slow.gate = null;
    await first;
    expect(verdictOf(await judging.judge({'a': _candidate('K1ABC')}), 'a'), [ChaseVerdict.unconfirmed]);
  });

  group('imports', () {
    const importer = ChasingImporter(key: 'credited', label: 'Credited calls', extensions: ['csv']);
    late List<Object?> answer;
    late Map<dynamic, dynamic> sent;
    setUp(() {
      answer = [];
      stubs['chasing:calls:importClaims'] = (Object? args) {
        sent = args! as Map;
        return {'claims': answer, 'skipped': 1};
      };
    });
    Map<String, dynamic> credited(String call, {int? at}) => {
      'holder': 'ME',
      'ref': call,
      'band': null,
      'mode': null,
      'level': 'verified',
      'by': 'sponsor',
      'at': ?at,
    };
    Future<({int claims, int skipped})?> import() =>
        service.importFile(service.programs['calls']!, importer, name: 'credits.csv', text: 'the file', station: {'call': 'ME'});

    /// The live claim records the importer keeps in the log, by reference.
    Future<Map<String, (ClaimLevel, int?)>> recorded() async => {
      for (final qso in await qsos.claimEvents('calls', 'credited'))
        if (!qso.deleted)
          if (claimEventOf(qso.data) case final event?) event.claim.ref: (event.claim.level, event.atMillis),
    };

    // Kept in the claims table alone, an import vanished whenever the table
    // was emptied — a device joining an account empties it.
    test('a file becomes claim records in the log, and the program reads the file for the station', () async {
      answer = [credited('W1AW', at: 500), credited('W1AW', at: 900), 'not a claim'];
      expect(await import(), (claims: 1, skipped: 2));
      expect(sent['importer'], 'credited');
      expect(sent['file'], {'name': 'credits.csv', 'text': 'the file'});
      expect(sent['station'], {'call': 'ME'});
      expect(await recorded(), {'W1AW': (ClaimLevel.verified, 500)}, reason: 'the earlier of two records for one slot');
    });

    // Sponsor exports are cumulative, so the new file is the whole list.
    test('importing the same kind of file again replaces the last one', () async {
      answer = [credited('W1AW'), credited('K1ABC')];
      await import();
      answer = [credited('K1ABC')];
      await import();
      expect((await recorded()).keys, ['K1ABC']);
    });

    // An empty export and a file picked by mistake read the same; taking
    // either as the new list would withdraw everything the last one gave.
    test('a file that claims nothing leaves the last import as it was', () async {
      answer = [credited('W1AW')];
      await import();
      answer = [];
      expect(await import(), (claims: 0, skipped: 1));
      expect((await recorded()).keys, ['W1AW']);
    });

    test('a program that fails to read the file writes nothing', () async {
      stubs['chasing:calls:importClaims'] = ExtensionHostException('timed out');
      expect(await import(), isNull);
      expect(await recorded(), isEmpty);
    });
  });

  test("a summary is the program's own tally of the station's first holder's checklist", () async {
    await worked('W1AW', level: 'confirmed');
    List<Object?>? slots;
    stubs['chasing:calls:holdersFor'] = (Object? args) => ['ME', 'ME/P'];
    stubs['chasing:calls:summarizeClaims'] = (Object? args) {
      slots = (args as Map)['slots'] as List;
      return {
        'calls': {'key': 'calls', 'label': '1 call', 'summary': '1'},
      };
    };
    final summaries = await service.summaries({'call': 'ME'});
    expect(summaries.single.holder, 'ME');
    expect(summaries.single.tallies['calls']!['label'], '1 call');
    expect(slots, hasLength(3));
  });
}

/// Holds every checklist read at [gate], once it has read the table.
class _SlowClaims extends ClaimsRepository {
  _SlowClaims(super.db);

  Completer<void>? gate;

  @override
  Future<List<StoredClaim>> checklist(String program, String holder, {String edition = ''}) async {
    final rows = await super.checklist(program, holder, edition: edition);
    await gate?.future;
    return rows;
  }
}
