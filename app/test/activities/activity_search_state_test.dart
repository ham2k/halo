// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ActivitySearchState without a widget. Its traps: searches, pans, outline
// parks and link lookups all overlap, each answering whenever the runtime
// gets to it, and only the answer to the question still on screen may land.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/outline_grid_service.dart';
import 'package:ham2k_logger/views/map/map_zoom_controller.dart' show MapViewBounds;
import 'package:ham2k_logger/views/operation/activity_search_query.dart';
import 'package:ham2k_logger/views/operation/activity_search_state.dart';

import '../support/halo_test_support.dart';

Map<String, dynamic> _park(String ref, {double distance = 5}) => {
  'type': OutlineGridService.potaActivationType,
  'ref': ref,
  'shortLabel': 'POTA $ref',
  'name': 'Park $ref',
  'distance': distance,
  'relevance': 1,
};

const MapViewBounds _view = (south: 40.0, west: -75.0, north: 41.0, east: -74.0);

typedef _Ask = ({String? term, List<String>? keys, Map<String, dynamic> data, MapViewBounds? within, Completer<ActivitySuggestionResult> answer});

/// Every search and pan waits on a completer of the test's; links answer at
/// once unless [gateLinks] holds them too.
class _Scripted extends ExtensionServiceWithFakeHost {
  _Scripted() : super(FakeExtensionHost({}));

  final asks = <_Ask>[];

  @override
  Future<ActivitySuggestionResult> suggestActivities(
    Map<String, dynamic> operationData, {
    String? searchTerm,
    GridLocation? fallbackLocation,
    List<String>? activityKeys,
    List<String>? preferredKeys,
    String? preferredSearchTerm,
    ({double south, double west, double north, double east})? searchWithin,
  }) {
    final answer = Completer<ActivitySuggestionResult>();
    asks.add((term: searchTerm, keys: activityKeys, data: operationData, within: searchWithin, answer: answer));
    return answer.future;
  }

  bool gateLinks = false;
  final linkAnswers = <({List<Map<String, dynamic>> refs, Completer<List<RefLink?>> answer})>[];

  @override
  Future<List<RefLink?>> linkForRefs(List<Map<String, dynamic>> refs) {
    final links = [for (final ref in refs) RefLink(url: 'https://example.com/${ref['ref']}')];
    if (!gateLinks) return Future.value(links);
    final answer = Completer<List<RefLink?>>();
    linkAnswers.add((refs: refs, answer: answer));
    return answer.future;
  }
}

/// Records where the parks near the operation were asked for, and answers
/// with [found] once [ready] completes.
class _Outline extends NoOutlineGrid {
  final asked = <GridLocation>[];
  List<Map<String, dynamic>> found = const [];
  Completer<void> ready = Completer<void>()..complete();

  @override
  Future<OutlineParks> parksNear(GridLocation center, double radiusKm, {GridLocation? measureFrom, Set<String> known = const {}}) async {
    asked.add(center);
    await ready.future;
    return (distances: {for (final park in found) park['ref'] as String: (park['distance'] as num).toDouble()}, found: found, settled: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Scripted extensions;
  late _Outline outline;
  late Operation operation;
  late Map<String, List<String>> scopes;
  late bool controlsLoaded;

  /// What `onAnswered` was told, in order.
  late List<({String term, ActivitySearchQuery query})> answered;

  /// `onAnswered` and the listeners, in the order they heard of anything.
  late List<String> events;
  var disposedByTest = false;

  Future<ActivitySearchState> makeState({Duration debounce = const Duration(milliseconds: 10)}) async {
    extensions = _Scripted();
    outline = _Outline();
    final services = (await makeHaLoServices(extensions: extensions, outlineGrid: outline)).services;
    operation = Operation(uuid: 'op-1', data: const {'refs': <Object>[], 'grid': 'FN31ah'});
    scopes = const {
      'pota': ['pota'],
      'sota': ['sota'],
    };
    controlsLoaded = true;
    answered = [];
    events = [];
    disposedByTest = false;
    final state = ActivitySearchState(
      services: services,
      currentOperation: () => operation,
      scopes: () => scopes,
      controlsLoaded: () => controlsLoaded,
      onAnswered: (term, query) {
        answered.add((term: term, query: query));
        events.add('answered');
      },
      debounce: debounce,
    )..addListener(() => events.add('notified'));
    addTearDown(() {
      if (!disposedByTest) state.dispose();
    });
    return state;
  }

  /// Lets the scripted futures run. Nothing timed waits on this.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  void answer(int ask, List<Map<String, dynamic>> suggestions, {bool allSourcesFailed = false, bool someSourcesFailed = false}) => extensions.asks[ask].answer
      .complete((suggestions: suggestions, allSourcesFailed: allSourcesFailed, someSourcesFailed: allSourcesFailed || someSourcesFailed));

  group('searches', () {
    test('an older search answering after a newer one is dropped', () async {
      final state = await makeState();
      unawaited(state.search('older'));
      unawaited(state.search('newer'));
      await settle();
      answer(1, [_park('US-0002')]);
      await settle();
      answer(0, [_park('US-0001')]);
      await settle();

      expect(state.suggestions.map((s) => s['ref']), ['US-0002']);
      expect(answered.map((a) => a.term), ['newer']);
      expect(state.answeredSearches, 1);
    });

    // On a fake clock: that the kept timer HAS fired is the late-not-early
    // direction a real timer cannot promise (time.md §7).
    test('typing is searched once the box sits still, for the last text only', () async {
      final state = await makeState();
      fakeAsync((async) {
        state.searchSoon('b');
        state.searchSoon('be');
        state.searchSoon('bear');
        async.elapse(const Duration(milliseconds: 9));
        expect(extensions.asks, isEmpty, reason: 'the box has not sat still yet');
        async.elapse(const Duration(milliseconds: 1));
        expect(extensions.asks.map((a) => a.term), ['bear']);
        async.elapse(const Duration(milliseconds: 100));
        expect(extensions.asks.map((a) => a.term), ['bear']);
      });
    });

    // Closing Manage Extensions reloads the controls before it searches;
    // without this, a tick's search fires mid-reload with the old scopes.
    test('a pending search can be dropped without running one', () async {
      final state = await makeState();
      state.searchSoon('bear');
      state.cancelPending();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(extensions.asks, isEmpty);
    });

    // The scope rows and the extension flows search straight away; without
    // the cancel, the keystroke still waiting fires after them and puts the
    // old, unscoped answer back on screen.
    test('a search run now drops the one still waiting to be typed', () async {
      final state = await makeState();
      state.searchSoon('be');
      unawaited(state.search('pota: '));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(extensions.asks, hasLength(1));
      expect(extensions.asks.single.keys, ['pota']);
    });

    // The sheet derives its enable and install rows from the same text; told
    // after the listeners, they would land a rebuild behind the results.
    test('onAnswered hears of an answer before the listeners do, with the text as typed', () async {
      final state = await makeState();
      unawaited(state.search('pota bear'));
      await settle();
      events.clear();
      answer(0, const []);
      await settle();

      expect(answered.single.term, 'pota bear');
      expect(answered.single.query.preferredKeys, ['pota']);
      expect(state.answeredSearches, 1);
      expect(events.take(2), ['answered', 'notified']);
    });

    test('every source failing is told apart from finding nothing, and a typed search from a nearby one', () async {
      final state = await makeState();
      unawaited(state.search('bear'));
      await settle();
      answer(0, const [], allSourcesFailed: true);
      await settle();
      expect(state.failed, isTrue);
      expect(state.areSearchResults, isTrue);

      unawaited(state.search(''));
      await settle();
      answer(1, const []);
      await settle();
      expect(state.failed, isFalse);
      expect(state.areSearchResults, isFalse);
    });

    // The contest extensions answer an empty list to nearly every search, so
    // "every source failed" alone misses a failed POTA beside them and tells
    // the operator there is nothing nearby.
    test('one source failing fails a search that found nothing, but not one that found something', () async {
      final state = await makeState();
      unawaited(state.search(''));
      await settle();
      answer(0, const [], someSourcesFailed: true);
      await settle();
      expect(state.failed, isTrue);

      unawaited(state.search(''));
      await settle();
      answer(1, [_park('US-0001')], someSourcesFailed: true);
      await settle();
      expect(state.failed, isFalse);
      expect(state.suggestions.map((s) => s['ref']), ['US-0001']);
    });

    // A location typed while the hooks were answering is where "nearby" is
    // by the time the answer lands; the parks found by their outline have to
    // be looked for there, not where the operation was when the box changed.
    test('a search asks about the operation as it is when the answer lands', () async {
      final state = await makeState();
      operation = Operation(uuid: 'op-1', data: const {'refs': <Object>[]});
      unawaited(state.search(''));
      await settle();
      operation = Operation(uuid: 'op-1', data: const {'refs': <Object>[], 'grid': 'FN31ah'});
      answer(0, const []);
      await settle();

      expect(outline.asked, hasLength(1));
      expect(outline.asked.single.latitude, closeTo(operation.location!.latitude, 1e-9));
    });
  });

  group('outline parks', () {
    test('the nearby list keeps loading until the parks found by their outline arrive, then holds them', () async {
      final state = await makeState();
      outline
        ..ready = Completer<void>()
        ..found = [_park('US-4556', distance: 0.2)];
      unawaited(state.search(''));
      await settle();
      answer(0, [_park('US-0001')]);
      await settle();
      expect(state.loading, isTrue, reason: 'a park far off by its point is "not nearby" until its outline is read');

      outline.ready.complete();
      await settle();
      expect(state.loading, isFalse);
      expect(state.suggestions.map((s) => s['ref']), containsAll(['US-0001', 'US-4556']));
    });

    test('a typed search asks for no outline parks', () async {
      final state = await makeState();
      unawaited(state.search('bear'));
      await settle();
      answer(0, const []);
      await settle();

      expect(outline.asked, isEmpty);
      expect(state.loading, isFalse);
    });

    test('outline parks for a search already replaced are dropped', () async {
      final state = await makeState();
      outline
        ..ready = Completer<void>()
        ..found = [_park('US-4556', distance: 0.2)];
      unawaited(state.search(''));
      await settle();
      answer(0, [_park('US-0001')]);
      await settle();
      unawaited(state.search('bear'));
      await settle();
      outline.ready.complete();
      await settle();

      expect(state.suggestions.map((s) => s['ref']), ['US-0001']);
      expect(state.loading, isTrue, reason: 'the newer search is still out');
    });

    // The first nearby search races the controls; POTA's own suggestions drop
    // every park while it is not running, so before the controls answer an
    // absent POTA scope proves nothing. Once they have, it means POTA is off.
    test('POTA outline parks are asked for before the controls load, and not once they say POTA is off', () async {
      final state = await makeState();
      scopes = const {};
      controlsLoaded = false;
      unawaited(state.search(''));
      await settle();
      answer(0, const []);
      await settle();
      expect(outline.asked, hasLength(1));

      controlsLoaded = true;
      unawaited(state.search(''));
      await settle();
      answer(1, const []);
      await settle();
      expect(outline.asked, hasLength(1));
    });

    test('a scope POTA does not serve asks for no outline parks', () async {
      final state = await makeState();
      unawaited(state.search('sota:'));
      await settle();
      answer(0, const []);
      await settle();
      expect(outline.asked, isEmpty);

      unawaited(state.search('pota:'));
      await settle();
      answer(1, const []);
      await settle();
      expect(outline.asked, hasLength(1));
    });
  });

  group('the results map', () {
    Future<ActivitySearchState> answeredNearby(List<Map<String, dynamic>> suggestions) async {
      final state = await makeState();
      unawaited(state.search('sota:'));
      await settle();
      answer(0, suggestions);
      await settle();
      return state;
    }

    test('panning finds nothing more while text is in the box', () async {
      final state = await makeState();
      unawaited(state.search('bear'));
      await settle();
      answer(0, const []);
      await settle();

      expect(await state.explore(_view), isTrue, reason: 'whole, so the map does not keep asking');
      expect(extensions.asks, hasLength(1));
    });

    test('a pan adds only what neither list has, and the next search clears it', () async {
      final state = await answeredNearby([_park('US-0001')]);
      final whole = state.explore(_view);
      await settle();
      expect(extensions.asks[1].within, _view);
      expect(extensions.asks[1].keys, ['sota']);
      answer(1, [_park('US-0001'), _park('US-0002')]);

      expect(await whole, isTrue);
      expect(state.exploredSuggestions.map((s) => s['ref']), ['US-0002']);

      unawaited(state.search('sota:'));
      await settle();
      answer(2, const []);
      await settle();
      expect(state.exploredSuggestions, isEmpty);
    });

    // The fan-out keeps what answered when one program times out, so a pan
    // can come back with parks and still be missing a program's. Called
    // whole, the map never asks that view again and those parks never come.
    test('a pan one program failed keeps what the others found, and says to ask again', () async {
      final state = await answeredNearby([_park('US-0001')]);
      final whole = state.explore(_view);
      await settle();
      answer(1, [_park('US-0002')], someSourcesFailed: true);

      expect(await whole, isFalse);
      expect(state.exploredSuggestions.map((s) => s['ref']), ['US-0002']);
    });

    test('a pan answering after a newer search adds nothing, and says to ask again', () async {
      final state = await answeredNearby([_park('US-0001')]);
      final whole = state.explore(_view);
      await settle();
      unawaited(state.search('sota:'));
      await settle();
      answer(2, const []);
      await settle();
      answer(1, [_park('US-0002')]);

      expect(await whole, isFalse);
      expect(state.exploredSuggestions, isEmpty);
    });
  });

  group('links', () {
    test('links resolved for a list already replaced are not installed', () async {
      final state = await makeState();
      extensions.gateLinks = true;
      unawaited(state.search('sota: a'));
      await settle();
      answer(0, [_park('US-0001')]);
      await settle();
      unawaited(state.search('sota: b'));
      await settle();
      answer(1, [_park('US-0002')]);
      await settle();
      expect(extensions.linkAnswers, hasLength(2));

      extensions.linkAnswers[1].answer.complete([const RefLink(url: 'https://example.com/US-0002')]);
      await settle();
      extensions.linkAnswers[0].answer.complete([const RefLink(url: 'https://example.com/US-0001')]);
      await settle();

      expect(state.links.keys, ['${OutlineGridService.potaActivationType}:US-0002']);
    });

    test('a removed reference comes back at the top of the list, once, with its link', () async {
      final state = await makeState();
      unawaited(state.search('sota:'));
      await settle();
      answer(0, [_park('US-0001')]);
      await settle();

      state.reoffer(_park('US-0009'));
      state.reoffer(_park('US-0009'));
      await settle();

      expect(state.suggestions.map((s) => s['ref']), ['US-0009', 'US-0001']);
      expect(state.links['${OutlineGridService.potaActivationType}:US-0009']?.url, 'https://example.com/US-0009');
    });
  });

  test('nothing lands after dispose, and a keystroke still waiting never searches', () async {
    final state = await makeState();
    unawaited(state.search(''));
    await settle();
    state.searchSoon('bear');
    state.dispose();
    disposedByTest = true;
    answer(0, [_park('US-0001')]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(answered, isEmpty);
    expect(extensions.asks, hasLength(1));
  });

  // A notify after dispose is an error, and the sheet can close on any of
  // these mid-flight.
  test('a pan, outline parks or links answering after dispose land nowhere', () async {
    final state = await makeState();
    extensions.gateLinks = true;
    outline
      ..ready = Completer<void>()
      ..found = [_park('US-4556', distance: 0.2)];
    unawaited(state.search(''));
    await settle();
    answer(0, [_park('US-0001')]);
    await settle();
    final pan = state.explore(_view);
    await settle();
    state.dispose();
    disposedByTest = true;
    outline.ready.complete();
    extensions.linkAnswers.single.answer.complete([const RefLink(url: 'https://example.com/US-0001')]);
    answer(1, [_park('US-0002')]);

    expect(await pan, isFalse);
    await settle();
  });
}
