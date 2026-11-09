// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What assistants say about spots (`host.spots.mark`): the board's stable spot
// ids a mark names, which have to survive the refreshes that replace every
// spot; the marks themselves, kept per extension and combined per row; and the
// rule that only an extension declaring `assistant` may put one.

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHostException;
import 'package:ham2k_logger/services/extensions/extension_info.dart';
import 'package:ham2k_logger/services/spot_board.dart';
import 'package:ham2k_logger/services/spot_marks_service.dart';
import 'package:ham2k_logger/services/spots_service.dart';
import 'package:ham2k_logger/views/operation/spots_panel.dart' show sectionSpots;

import '../support/halo_test_support.dart';

typedef Fetched = ({List<Map<String, dynamic>> items, List<String> succeeded, List<String> unreachable, List<String> failed});

Map<String, dynamic> _spot(String call, {String source = 'pota', num freq = 14025, String? mode, int ageMinutes = 1}) => {
  'their': {'call': call},
  'freq': freq,
  'mode': ?mode,
  'hookKey': source,
  'spot': {'timeInMillis': DateTime.now().millisecondsSinceEpoch - Duration(minutes: ageMinutes).inMilliseconds, 'source': source},
};

const SpotMark _plain = (icon: null, color: null, note: null, boost: 0, hidden: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a spot id', () {
    // A mark names a spot the next refresh replaces with a fresh map: an id
    // that moved with the frequency or the time would leave every mark
    // pointing at nothing two minutes after it was put.
    test('stays the same when the same source reports the same station again, wherever it moved on the band', () async {
      var answer = [_spot('K1ABC', freq: 14025, mode: 'CW')];
      final spots = SpotsService(fetchSpots: () async => (items: answer, succeeded: const ['pota'], unreachable: const <String>[], failed: const <String>[]));
      addTearDown(spots.dispose);
      await spots.refresh();
      final first = spots.spotsBySource['pota']!.single['id'];

      answer = [_spot('K1ABC', freq: 14031, mode: 'CW', ageMinutes: 0)];
      await spots.refresh();
      expect(spots.spotsBySource['pota']!.single['id'], first);
      expect(first, 'pota|K1ABC|20m|CW');
    });

    test('differs by source, band and mode', () {
      final id = spotIdFor('pota', _spot('K1ABC', mode: 'CW'));
      expect(spotIdFor('sota', _spot('K1ABC', mode: 'CW')), isNot(id));
      expect(spotIdFor('pota', _spot('K1ABC', freq: 7025, mode: 'CW')), isNot(id));
      expect(spotIdFor('pota', _spot('K1ABC', mode: 'SSB')), isNot(id));
    });

    // A source cannot choose an id, or it could name another source's spot
    // and mark it on that source's behalf.
    test("replaces whatever id a source sent", () {
      expect(withSpotId('pota', {..._spot('K1ABC', mode: 'CW'), 'id': 'sota|K1ABC|20m|CW'})['id'], 'pota|K1ABC|20m|CW');
    });

    // A merged row is one station several sources reported: a mark on any
    // of those reports has to reach it.
    test('a merged row carries the id of every report it took in', () {
      final pota = withSpotId('pota', _spot('K1ABC', mode: 'CW'));
      final cluster = withSpotId('cluster', _spot('K1ABC', source: 'cluster', freq: 14025.2, mode: 'CW', ageMinutes: 2));
      final merged = mergeSpotsByCallAndFreq([pota, cluster]);
      expect(spotIdsOf(merged.single), unorderedEquals(['pota|K1ABC|20m|CW', 'cluster|K1ABC|20m|CW']));
    });
  });

  group('marks', () {
    late SpotMarksService marks;
    setUp(() => marks = SpotMarksService());
    tearDown(() => marks.dispose());

    test("combine every extension's: their icons and notes, the strongest boost, and who hid it", () {
      marks.mark('k1abc-coach', ['a'], (icon: 'star', color: '#ff0000', note: 'needed for WAS', boost: 2, hidden: false));
      marks.mark('w2xyz-helper', ['b'], (icon: 'flag', color: null, note: null, boost: 5, hidden: true));
      final marking = marks.markingFor(['a', 'b'])!;
      expect([for (final icon in marking.icons) icon.icon], ['star', 'flag']);
      expect(marking.notes, ['needed for WAS']);
      expect(marking.boost, 5);
      expect(marking.hiddenBy, {'w2xyz-helper'});
      expect(marks.markingFor(['c']), isNull);
    });

    // A merged row can be two stations at once (`K1ABC,W2XYZ` on one park):
    // what one extension said about the second is as much its word as what
    // it said about the first.
    test("count everything one extension said about every station a row stands for", () {
      marks.mark('k1abc-coach', ['a'], (icon: null, color: '#ff0000', note: 'first', boost: 0, hidden: false));
      marks.mark('k1abc-coach', ['b'], (icon: null, color: '#00ff00', note: null, boost: 4, hidden: true));
      final marking = marks.markingFor(['a', 'b'])!;
      expect(marking.boost, 4);
      expect(marking.hiddenBy, {'k1abc-coach'});
      expect(marking.color, '#00ff00', reason: "the highlight is the boost's, not the first mark's");
    });

    // Each notice repaints the board and fires every `spots` trigger, the
    // marking assistant's own among them: re-marking what it already holds on
    // that trigger would wake it again, and again, for as long as it runs.
    test('marking again with what is held says nothing to the listeners', () {
      var notices = 0;
      marks.addListener(() => notices++);
      marks.mark('k1abc-coach', ['a', 'b'], _plain);
      marks.mark('k1abc-coach', ['b', 'a'], _plain);
      expect(notices, 1);
      marks.mark('k1abc-coach', ['a'], (icon: 'star', color: null, note: null, boost: 0, hidden: false));
      expect(notices, 2);
    });

    test('are taken by id, or all at once, and go with their extension and its sub-keys', () {
      marks.mark('k1abc-coach', ['a', 'b'], _plain);
      marks.mark('k1abc-coach_rate', ['c'], _plain);
      marks.mark('w2xyz-helper', ['d'], _plain);
      marks.unmark('k1abc-coach', ['a']);
      expect(marks.markingFor(['a']), isNull);
      expect(marks.markingFor(['b']), isNotNull);

      marks.forget(['k1abc-coach']);
      expect(marks.markingFor(['b', 'c']), isNull, reason: "a sub-key is the bundle's");
      expect(marks.markingFor(['d']), isNotNull);
    });

    test('past the most one extension holds, the whole call is refused', () {
      marks.mark('k1abc-coach', [for (var i = 0; i < SpotMarksService.maxMarksPerExtension; i++) 'id$i'], _plain);
      expect(() => marks.mark('k1abc-coach', ['one-more'], _plain), throwsA(isA<SpotsPushRefused>()));
      expect(marks.markingFor(['one-more']), isNull);
      marks.mark('k1abc-coach', ['id0'], (icon: 'star', color: null, note: null, boost: 0, hidden: false));
      expect(marks.markingFor(['id0'])!.icons.single.icon, 'star', reason: 'replacing one it holds is no more');
    });
  });

  // The picks are the point of a boost: above the band sections, yet still in
  // them, as the calls of note are.
  test('the picks are a section of their own under your spots, the spots staying in their band too', () {
    final a = {..._spot('K1ABC'), 'band': '20m'}, b = {..._spot('W2XYZ', freq: 7025), 'band': '40m'};
    final sections = sectionSpots([a, b], selfSpots: [_spot('N0DEV')], picks: [b], callsWithNotes: const {});
    expect([for (final section in sections) section.key], ['self', 'picks', '40m', '20m']);
    expect(sections[1].spots, [b]);
  });

  group('the host call', () {
    (ExtensionServiceWithFakeHost, SpotMarksService) harness(List<String> hooks, {ExtensionSource source = ExtensionSource.installed}) {
      final extensions = ExtensionServiceWithFakeHost(FakeExtensionHost({}));
      extensions.debugSetAvailableExtensions([
        ExtensionInfo(key: 'k1abc-coach', file: 'k1abc-coach.js', name: 'Coach', core: false, source: source, hooks: hooks),
      ]);
      addTearDown(extensions.bandAnnotations.dispose);
      addTearDown(extensions.spotMarks.dispose);
      return (extensions, extensions.spotMarks);
    }

    Future<dynamic> call(ExtensionServiceWithFakeHost extensions, String method, Map<String, dynamic> rest) =>
        extensions.debugHandleHostCall(method, {'ns': 'k1abc-coach', 'extensionKey': 'k1abc-coach', ...rest});

    // The install warning is what the operator agreed to an extension acting
    // on their board for; one that never declared the hook never got it.
    test('is refused to an extension whose manifest does not declare `assistant`', () async {
      final (extensions, marks) = harness(const ['panel']);
      await expectLater(
        call(extensions, 'markSpots', {
          'ids': ['a'],
          'mark': {'hidden': true},
        }),
        throwsA(isA<ExtensionHostException>()),
      );
      expect(marks.isEmpty, isTrue);
    });

    // A switched-off assistant is never called again, so it can never take
    // back the spots it hid: the app has to.
    test("an extension's marks go when none of its assistants is on, and stay while one is", () {
      final (extensions, marks) = harness(const ['assistant']);
      marks.mark('k1abc-coach', ['a'], _plain);
      marks.mark('ham2k-band-plan', ['b'], _plain);
      extensions.releaseSpotMarks(offered: {'k1abc-coach_rate', 'k1abc-coach_qsy'}, on: {'k1abc-coach_qsy'});
      expect(marks.markingFor(['a']), isNotNull);
      extensions.releaseSpotMarks(offered: {'k1abc-coach_rate', 'k1abc-coach_qsy'}, on: {});
      expect(marks.markingFor(['a']), isNull);
      expect(marks.markingFor(['b']), isNotNull, reason: 'an extension offering no assistant is not one switched off');
    });

    test('puts a mark for an assistant, and refuses a malformed one', () async {
      final (extensions, marks) = harness(const ['assistant']);
      await call(extensions, 'markSpots', {
        'ids': ['a'],
        'mark': {'icon': 'star', 'note': '  worth a call  ', 'boost': 3},
      });
      final marking = marks.markingFor(['a'])!;
      expect(marking.notes, ['worth a call']);
      expect(marking.boost, 3);

      await expectLater(
        call(extensions, 'markSpots', {
          'ids': ['a'],
          'mark': {'boost': -1},
        }),
        throwsA(isA<FormatException>()),
      );
      // A colour the board cannot draw is refused, not taken and dropped.
      await expectLater(
        call(extensions, 'markSpots', {
          'ids': ['a'],
          'mark': {'color': 'red'},
        }),
        throwsA(isA<FormatException>()),
      );
      await call(extensions, 'unmarkSpots', {});
      expect(marks.isEmpty, isTrue);
    });
  });
}
