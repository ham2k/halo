// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// OperationRuntimeState without a widget. Its traps: a controls fetch is
// asked for by three callers that overlap, and the runtime it asks can be
// restarting; and the live rescore is fed by streams its own writes
// re-emit, so the fingerprint that gates it is the only thing between a
// rescore and a loop of them.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/halo_services.dart';
import 'package:ham2k_logger/views/operation/operation_runtime_state.dart';
import 'package:halo_extension_host/halo_extension_host.dart' show ExtensionHost;

import '../support/halo_test_support.dart';

Map<String, dynamic> _control(String label) => {
  'key': 'c/exchange',
  'label': label,
  'icon': 'flag-checkered',
  'input': {'kind': 'text', 'refType': 'c', 'field': 'exchange'},
};

/// Every `loggingControls` call waits on a completer of the test's, so the
/// test decides the order they resolve in.
class _Scripted extends ExtensionServiceWithFakeHost {
  _Scripted() : super(FakeExtensionHost({}));

  final List<Completer<ControlsResult>> pending = [];

  /// How many refs each fetch asked about.
  final List<int> askedRefs = [];

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) {
    final completer = Completer<ControlsResult>();
    pending.add(completer);
    askedRefs.add((operationData['refs'] as List?)?.length ?? 0);
    return completer.future;
  }

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);

  /// The station's own entity lookups, each waiting on its own completer,
  /// and the call each was for.
  final List<Completer<Map<String, dynamic>?>> entityLookups = [];
  final List<String> entityCalls = [];

  @override
  Future<Map<String, dynamic>?> lookupCall(
    String call, {
    required Map<String, dynamic> qso,
    required Map<String, dynamic> operation,
    bool online = true,
    bool recentContext = false,
    String? streakKey,
  }) {
    final completer = Completer<Map<String, dynamic>?>();
    entityLookups.add(completer);
    entityCalls.add(call);
    return completer.future;
  }
}

/// The logging controls always answer, empty; the operation's own (the
/// map's) answer from [answers], in order.
class _MapScripted extends ExtensionServiceWithFakeHost {
  _MapScripted(this.answers) : super(FakeExtensionHost({}));

  final List<ControlsResult> answers;
  int calls = 0;

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async =>
      (controls: const <Map<String, dynamic>>[], loadFailed: false);

  @override
  Future<ControlsResult> operationControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async => answers[calls++];
}

/// A runtime that takes until [booted] completes to start. Until then a
/// controls fetch fails, as the real one does with no host; after, it answers
/// with a control named for the refs it was asked about.
class _SlowBoot extends ExtensionServiceWithFakeHost {
  _SlowBoot() : super(FakeExtensionHost({}));

  final booted = Completer<void>();

  @override
  Future<void> start() => booted.future;

  @override
  Future<ControlsResult> loggingControls(Map<String, dynamic> operationData, {Map<String, dynamic>? qso}) async => booted.isCompleted
      ? (controls: [_control('refs:${(operationData['refs'] as List?)?.length ?? 0}')], loadFailed: false)
      : (controls: const <Map<String, dynamic>>[], loadFailed: true);
}

/// A runtime that can be down: no host, as while it boots or restarts.
class _HostCanBeDown extends ExtensionServiceWithFakeHost {
  _HostCanBeDown([Map<String, Object?> stubs = const {}]) : super(FakeExtensionHost(stubs));

  bool up = true;

  @override
  ExtensionHost? get host => up ? fakeHost : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;
  late Operation operation;
  Operation? current;

  /// The setup sheet's draft, while one is open.
  Operation? draft;
  var disposedByTest = false;

  Future<OperationRuntimeState> makeState(ExtensionService extensions, {Duration rescoreDelay = const Duration(milliseconds: 1)}) async {
    services = (await makeHaLoServices(extensions: extensions)).services;
    operation = await services.operations.create(stationCall: 'N0CALL');
    current = operation;
    draft = null;
    disposedByTest = false;
    final state = OperationRuntimeState(
      services: services,
      currentOperation: () => current,
      controlsOperation: () => draft ?? current,
      rescoreDelay: rescoreDelay,
    );
    // Before the harness closes the database: the first emission's unawaited
    // retitle, and a rescore, can still be writing when a test ends. The
    // database runs in this isolate, so once the timer is cancelled the event
    // queue alone carries them to the end.
    addTearDown(() async {
      await services.scoring.rescoreOperation(operation);
      await pumpEventQueue();
    });
    addTearDown(() {
      if (!disposedByTest) state.dispose();
    });
    return state;
  }

  /// Lets the scripted fetches' futures run. Nothing timed waits on this.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  /// Until the scheduled rescore's timer has fired — which is when it
  /// records the fingerprint. A fixed sleep instead reads that too early on a
  /// loaded machine, where a timer fires late (time.md §7).
  Future<void> fired(OperationRuntimeState state) async {
    while (state.rescoreScheduled) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  group('controls', () {
    test('an older fetch resolving after a newer one does not replace it', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      unawaited(state.refreshControls(operation));
      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending[1].complete((controls: [_control('newer')], loadFailed: false));
      await settle();
      extensions.pending[0].complete((controls: [_control('older')], loadFailed: false));
      await settle();

      expect(state.loggingControls.single['label'], 'newer');
    });

    test('a failed fetch keeps the controls the panel already shows, and says why', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending[0].complete((controls: [_control('live')], loadFailed: false));
      await settle();
      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending[1].complete((controls: const <Map<String, dynamic>>[], loadFailed: true));
      await settle();

      // Blanking the panel would take the operator's exchange field away
      // because the runtime happened to be restarting.
      expect(state.loggingControls.single['label'], 'live');
      expect(state.mapControls.single['label'], 'live');
      expect(services.statusBar.itemForKey('operation:logging-controls-stale'), isNotNull, reason: 'kept controls may be the wrong set');
    });

    test("the map keeps its activation icons across a failed fetch, and a restart retries them", () async {
      final extensions = _MapScripted([
        (controls: [_control('partial')], loadFailed: true),
        (controls: [_control('full')], loadFailed: false),
        (controls: const <Map<String, dynamic>>[], loadFailed: true),
        (controls: [_control('fixed')], loadFailed: false),
      ]);
      final state = await makeState(extensions);

      await state.refreshControls(operation);
      expect(state.mapControls.single['label'], 'partial', reason: 'with nothing shown yet, whatever extensions did answer beats no colours');
      await state.refreshControls(operation);
      expect(state.mapControls.single['label'], 'full');
      await state.refreshControls(operation);
      expect(state.mapControls.single['label'], 'full', reason: 'a restarting runtime must not take the icons away');

      // The logging controls answered fine, so only the map's own staleness
      // can ask for this retry.
      state.runtimeRestarted();
      await settle();
      expect(extensions.calls, 4);
      expect(state.mapControls.single['label'], 'fixed');
    });

    test('an edit made while the runtime boots is not undone when it comes up', () async {
      final extensions = _SlowBoot();
      final state = await makeState(extensions);

      state.operationChanged(null, operation);
      final withRef = Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      );
      current = withRef;
      state.operationChanged(operation, withRef);
      await settle();
      extensions.booted.complete();
      await settle();

      // The boot's own fetch is the LAST one asked for, so it is the one the
      // request-id guard keeps: asked about the operation as it opened, the
      // panel would lose the contest's exchange field it just gained.
      expect(state.loggingControls.single['label'], 'refs:1');
    });

    test("a ref added in the setup sheet while the runtime boots is not undone when it comes up", () async {
      final extensions = _SlowBoot();
      final state = await makeState(extensions);

      state.operationChanged(null, operation);
      final withRef = Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      );
      // The sheet's own fetch for its draft, which fails with no runtime yet.
      draft = withRef;
      unawaited(state.refreshControls(withRef));
      await settle();
      extensions.booted.complete();
      await settle();

      // Asked about the saved, ref-less operation instead, the boot's fetch
      // would win and say nothing was stale — and closing the sheet hands the
      // draft over without fetching again, so the field would stay missing.
      expect(state.loggingControls.single['label'], 'refs:1');
    });

    test("a station call saved during the boot's first fetch is the one its entity is looked up for", () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      state.operationChanged(null, operation);
      await settle();
      final renamed = Operation(uuid: operation.uuid, data: {...operation.data, 'stationCall': 'N0NEW'});
      current = renamed;
      state.operationChanged(operation, renamed);
      await settle();
      extensions.pending.single.complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
      await settle();

      // Lookups carry no ordering guard: the boot's, asked last and likely to
      // finish last, decides which call's entity the operation ends up with.
      expect(extensions.entityCalls, ['N0NEW', 'N0NEW']);
      for (final lookup in extensions.entityLookups) {
        lookup.complete(null);
      }
      await settle();
    });

    test('a runtime restart refetches only after a fetch failed', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending[0].complete((controls: [_control('live')], loadFailed: false));
      await settle();
      // Any extension anywhere being toggled restarts the runtime; a healthy
      // operation must not pay a round trip for each one.
      state.runtimeRestarted();
      await settle();
      expect(extensions.pending, hasLength(1));

      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending[1].complete((controls: const <Map<String, dynamic>>[], loadFailed: true));
      await settle();
      state.runtimeRestarted();
      await settle();
      expect(extensions.pending, hasLength(3), reason: 'nothing else would correct the stale set until the operation is reopened');
      extensions.pending[2].complete((controls: [_control('fixed')], loadFailed: false));
      await settle();
      expect(state.loggingControls.single['label'], 'fixed');
      expect(services.statusBar.itemForKey('operation:logging-controls-stale'), isNull);
    });

    test("a runtime restart retries the setup sheet's draft, not the saved operation", () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      final withRef = Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      );
      draft = withRef;
      unawaited(state.refreshControls(withRef));
      await settle();
      extensions.pending.single.complete((controls: const <Map<String, dynamic>>[], loadFailed: true));
      await settle();

      // Retried against the saved, ref-less operation, the draft's contest
      // field would never arrive while the sheet is open.
      state.runtimeRestarted();
      await settle();
      expect(extensions.askedRefs, [1, 1]);
      extensions.pending.last.complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
      await settle();
    });

    test('a re-emission of the same saved operation does not refetch; a ref change does', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      state.operationChanged(null, operation);
      await settle();
      expect(extensions.pending, hasLength(1), reason: 'the first emission starts the runtime and fetches');

      // A QSO add or a rescore re-emits the row with only counters moved.
      state.operationChanged(operation, operation);
      await settle();
      expect(extensions.pending, hasLength(1));

      final withRef = Operation(
        uuid: operation.uuid,
        data: {
          ...operation.data,
          'refs': [
            {'type': 'c', 'ref': 'C-1'},
          ],
        },
      );
      state.operationChanged(operation, withRef);
      await settle();
      expect(extensions.pending, hasLength(2));
      for (final c in extensions.pending) {
        if (!c.isCompleted) c.complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
      }
      await settle();
    });
  });

  group('closing the view', () {
    test('takes its stale-controls notice down with it', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending.single.complete((controls: const <Map<String, dynamic>>[], loadFailed: true));
      await settle();
      expect(services.statusBar.itemForKey('operation:logging-controls-stale'), isNotNull);

      // Nothing retries for a closed view, so the notice would stay up with
      // no operation open.
      state.dispose();
      disposedByTest = true;
      expect(services.statusBar.itemForKey('operation:logging-controls-stale'), isNull);
    });

    test("whose controls are current leaves another view's notice alone", () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      unawaited(state.refreshControls(operation));
      await settle();
      extensions.pending.single.complete((controls: [_control('live')], loadFailed: false));
      await settle();
      // The key is every Operation view's: one stacked under this one.
      services.statusBar.setMessage(key: 'operation:logging-controls-stale', text: 'stale');

      state.dispose();
      disposedByTest = true;
      expect(services.statusBar.itemForKey('operation:logging-controls-stale'), isNotNull);
    });
  });

  group('closing the view mid-boot', () {
    test('during the first fetch, the boot goes no further', () async {
      final extensions = _Scripted();
      final state = await makeState(extensions);

      state.operationChanged(null, operation);
      await settle();
      state.dispose();
      disposedByTest = true;
      extensions.pending.single.complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
      await settle();

      expect(extensions.entityLookups, isEmpty, reason: 'nobody has the operation open to show its entity');
    });

    test('during the entity lookup, nothing is scheduled behind it', () async {
      final extensions = _Scripted();
      // Long enough that a timer started here is still pending when checked.
      final state = await makeState(extensions, rescoreDelay: const Duration(hours: 1));

      state.operationChanged(null, operation);
      await settle();
      extensions.pending.single.complete((controls: const <Map<String, dynamic>>[], loadFailed: false));
      await settle();
      state.dispose();
      disposedByTest = true;
      extensions.entityLookups.single.complete(null);
      await settle();

      expect(state.rescoreScheduled, isFalse, reason: 'dispose has already cancelled the only timer it will ever cancel');
    });
  });

  group('rescore', () {
    Future<List<Qso>> log() => services.qsos.watchForOperation(operation.uuid).first;

    test("a rescore's own score writes do not schedule another", () async {
      final state = await makeState(
        _HostCanBeDown({
          'scoring:*:scope': [
            {'key': 'core', 'ok': true, 'value': 'always'},
          ],
          'scoring:core:scoreQsos': (Object? args) => {
            'qsoScores': {
              for (final uuid in scoredUuids(args)) uuid: {'value': 1},
            },
            'daySections': const <dynamic>[],
            'operationSummary': const <String, dynamic>{},
            'scoresheet': const <String, dynamic>{},
          },
        }),
      );
      await services.qsos.add(operation.uuid, {
        'their': {'call': 'W1AW'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 1000,
      });

      state.qsosChanged(await log());
      await fired(state);
      // Queued behind the pass the timer started, so it waits that one out.
      await services.scoring.rescoreOperation(operation);
      final scored = await log();
      expect(scored.single.scoreCache, isNotNull, reason: 'the pass wrote scores, so the log below is its re-emission');

      // Scheduling on that re-emission is a rescore loop.
      state.qsosChanged(scored);
      expect(state.rescoreScheduled, isFalse);

      await services.qsos.add(operation.uuid, {
        'their': {'call': 'K1ABC'},
        'band': '20m',
        'mode': 'SSB',
        'startAtMillis': 2000,
      });
      state.qsosChanged(await log());
      expect(state.rescoreScheduled, isTrue, reason: 'a contact logged is a real change');
      await fired(state);
    });

    test('a rescore that found no runtime is tried again by the same log', () async {
      final extensions = _HostCanBeDown()..up = false;
      final state = await makeState(extensions);
      final qsos = await log();

      state.qsosChanged(qsos);
      await fired(state);
      // Marked scored here, the log would wait for its next contact.
      extensions.up = true;
      state.qsosChanged(qsos);
      expect(state.rescoreScheduled, isTrue);
      await fired(state);
    });

    test('a runtime restart rescores the same log', () async {
      final state = await makeState(_HostCanBeDown());
      final qsos = await log();

      state.qsosChanged(qsos);
      await fired(state);
      state.qsosChanged(qsos);
      expect(state.rescoreScheduled, isFalse);

      // The new runtime holds none of the old scorers' checkpoints.
      state.runtimeRestarted();
      expect(state.rescoreScheduled, isTrue);
      await fired(state);
    });

    test('a saved change to the operation schedules a rescore of an unchanged log', () async {
      final state = await makeState(_HostCanBeDown());
      final qsos = await log();
      state.qsosChanged(qsos);
      await fired(state);

      // A title, say: nothing the log's own fingerprint can see.
      final saved = Operation(uuid: operation.uuid, data: {...operation.data, 'userTitle': 'Renamed', 'updatedAtMillis': (operation.updatedAtMillis ?? 0) + 1});
      current = saved;
      state.operationChanged(operation, saved);
      expect(state.rescoreScheduled, isTrue);
      await fired(state);
    });
  });
}
