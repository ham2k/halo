// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// IntegrationService (docs/extensions/integrations.md): which operations an
// integration is called about — only those it is switched on for, on this
// device — and the contacts each call says changed. When a call happens is
// the engine assistants share, tested in assistant_service_test.dart. Runs
// on the fake clock (docs/design/time.md §7).

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/integration_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';

import '../support/fake_clock.dart';

class _Call {
  final String hookKey;
  final String integrationKey;
  final Map<String, dynamic> args;
  _Call(this.hookKey, this.integrationKey, this.args);

  String get operationUuid => (args['operation'] as Map)['uuid'] as String;
  Set<String> get reasons => {...(args['reasons'] as List).cast<String>()};
  Map<String, dynamic> get changes => args['changes'] as Map<String, dynamic>;
  List<String> uuids(String kind) => [for (final qso in changes[kind] as List) (qso as Map)['uuid'] as String];
  List<String> get deleted => (changes['deleted'] as List).cast<String>();
}

class _FakeIntegrationExtensions implements IntegrationExtensionSource {
  List<Map<String, dynamic>>? entries;
  final calls = <_Call>[];
  Object? failWith;

  /// False is no runtime to call: nothing reaches the extension.
  bool answering = true;

  _FakeIntegrationExtensions(this.entries);

  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionIntegrations() async => entries;

  @override
  Future<bool> observeIntegration({required String hookKey, required String integrationKey, required Map<String, dynamic> args}) async {
    if (!answering) return false;
    calls.add(_Call(hookKey, integrationKey, args));
    if (failWith != null) throw failWith!;
    return true;
  }

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async => {'from': panelKey};

  @override
  bool canReadRadio(String? hookKey) => false;
}

Map<String, dynamic> _integration(String key, List<String> on, {String hookKey = 'k1abc-club'}) => {'hookKey': hookKey, 'key': key, 'title': key, 'on': on};

const _id = 'integration:k1abc-club:stream';

Operation _op(String uuid, {List<String> on = const []}) =>
    Operation(uuid: uuid, data: const {'stationCall': 'K1ABC'}, localData: {IntegrationService.localDataKey: on});

Qso _qso(String uuid, {int stamp = 1, String band = '20m', bool deleted = false}) => Qso(
  uuid: uuid,
  operationUuid: 'op-1',
  data: {
    'band': band,
    'updatedAtMillis': stamp,
    'their': {'call': 'W1$uuid'},
  },
  deleted: deleted,
);

/// Past the gap a second call waits out.
final _pastGap = panelRenderThrottle + const Duration(milliseconds: 10);

void main() {
  late _FakeIntegrationExtensions extensions;
  late List<(String, Map<String, dynamic>)> writes;

  /// Each operation's local data as the repository holds it; a write's patch
  /// is made from it, as `updateLocalDataWith` does inside its transaction.
  late Map<String, Map<String, dynamic>> stored;

  IntegrationService start(FakeAsync async, List<Map<String, dynamic>> entries) {
    extensions = _FakeIntegrationExtensions(entries);
    writes = [];
    stored = {};
    final service = IntegrationService(
      extensions,
      writeLocalData: (uuid, patchFor) async {
        final patch = patchFor(stored[uuid] ?? const {});
        if (patch == null) return;
        stored[uuid] = {...?stored[uuid], ...patch};
        writes.add((uuid, patch));
      },
    );
    unawaited(service.refresh());
    async.flushMicrotasks();
    return service;
  }

  setUp(followFakeClock);

  test('an integration is called only about the operations it is switched on for', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final on = service.openFeed()..update(PanelRenderContext(operation: _op('op-1', on: [_id])));
      final off = service.openFeed()..update(PanelRenderContext(operation: _op('op-2')));
      async.flushMicrotasks();
      expect(extensions.calls.map((c) => '${c.operationUuid} ${c.reasons.join(',')}'), ['op-1 open']);

      async.elapse(_pastGap);
      off.update(PanelRenderContext(operation: _op('op-2'), qsoCount: 1));
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1), reason: 'a contact logged where it is off is no business of its');
      expect(service.wants('qsoLogged'), isTrue, reason: 'on somewhere, its triggers are produced');

      on.update(PanelRenderContext(operation: _op('op-1')));
      async.elapse(_pastGap);
      on.update(PanelRenderContext(operation: _op('op-1'), qsoCount: 1));
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1), reason: 'switched off, it hears nothing more');
      expect(service.wants('qsoLogged'), isFalse);
      service.dispose();
    });
  });

  test('switched on for an open operation, it hears open; its ticks reach only where it is on', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['tick:60']),
      ]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: _op('op-1')));
      service.openFeed().update(PanelRenderContext(operation: _op('op-2')));
      async.elapse(const Duration(minutes: 2));
      expect(extensions.calls, isEmpty, reason: 'off everywhere, nothing ticks');

      feed.update(PanelRenderContext(operation: _op('op-1', on: [_id])));
      async.flushMicrotasks();
      expect(extensions.calls.single.reasons, {'open'});

      async.elapse(const Duration(minutes: 1));
      expect(extensions.calls.map((c) => c.operationUuid).toSet(), {'op-1'}, reason: 'a tick is a call about the operations it is on for');
      expect(extensions.calls.last.reasons, {'tick'});
      service.dispose();
    });
  });

  test('changes carry what was logged, edited and deleted since its previous call, and nothing from before', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final op = _op('op-1', on: [_id]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.flushMicrotasks();
      final open = extensions.calls.single;
      expect(
        [open.uuids('logged'), open.uuids('updated'), open.deleted],
        [isEmpty, isEmpty, isEmpty],
        reason: 'what was in the log before it opened is not replayed',
      );

      async.elapse(_pastGap);
      feed.update(PanelRenderContext(operation: op, qsoCount: 3, log: [_qso('a'), _qso('b'), _qso('c')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), ['c']);
      expect(extensions.calls.last.uuids('updated'), isEmpty);

      // An edit moves the stamp; a deleted row the view still shows has left the log.
      feed.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a', stamp: 2), _qso('b', deleted: true), _qso('c')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), isEmpty);
      expect(extensions.calls.last.uuids('updated'), ['a']);
      expect(extensions.calls.last.deleted, ['b']);

      feed.update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a', stamp: 2)]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.deleted, ['c'], reason: 'a row gone from the list is deleted too');
      expect(extensions.calls.last.args.containsKey('qso'), isFalse);
      service.dispose();
    });
  });

  test('an event marker is no contact, and a log not read yet is not a log of new contacts', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final op = _op('op-1', on: [_id]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: op));
      async.elapse(_pastGap);

      // The view's first read of the log: everything in it predates the call.
      feed.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), isEmpty);

      feed.update(
        PanelRenderContext(
          operation: op,
          qsoCount: 2,
          log: [
            _qso('a'),
            _qso('b'),
            _qso('break', band: 'event'),
          ],
        ),
      );
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), isEmpty, reason: 'an event marker is never handed over');
      service.dispose();
    });
  });

  test('switched off and on again, it starts over from the log as it stands', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      // The view hands the same list until the log moves, as the log stream does.
      final before = [_qso('a')], after = [_qso('a'), _qso('b')];
      final feed = service.openFeed()
        ..update(
          PanelRenderContext(
            operation: _op('op-1', on: [_id]),
            qsoCount: 1,
            log: before,
          ),
        );
      async.elapse(_pastGap);
      feed.update(PanelRenderContext(operation: _op('op-1'), qsoCount: 1, log: before));
      feed.update(PanelRenderContext(operation: _op('op-1'), qsoCount: 2, log: after));
      async.elapse(_pastGap);
      extensions.calls.clear();
      feed.update(
        PanelRenderContext(
          operation: _op('op-1', on: [_id]),
          qsoCount: 2,
          log: after,
        ),
      );
      async.elapse(_pastGap);
      expect(extensions.calls.single.reasons, {'open'});
      expect(extensions.calls.single.uuids('logged'), isEmpty, reason: 'what was logged while it was off is not replayed');
      service.dispose();
    });
  });

  test('a call that throws still moves its changes on', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final op = _op('op-1', on: [_id]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a')]));
      async.elapse(_pastGap);

      extensions.failWith = StateError('service down');
      feed.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.elapse(_pastGap);
      extensions.failWith = null;
      feed.update(PanelRenderContext(operation: op, qsoCount: 3, log: [_qso('a'), _qso('b'), _qso('c')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), [
        'c',
      ], reason: 'a call can fail after the service took what it sent; handing it over again would post it twice');
      service.dispose();
    });
  });

  test('an entry with a field of the wrong type keeps its place, and costs no other its own', () {
    fakeAsync((async) {
      final service = start(async, [
        {'hookKey': 'k1abc-club', 'key': 'typo', 'title': 'Typo', 'on': 'qsoLogged', 'description': 7, 'form': 'none'},
        _integration('stream', const ['qsoLogged']),
      ]);
      expect(
        [
          for (final i in service.catalog) [i.key, i.triggers, i.description, i.formFields],
        ],
        [
          ['typo', isEmpty, isNull, isEmpty],
          [
            'stream',
            ['qsoLogged'],
            isNull,
            isEmpty,
          ],
        ],
        reason: 'a cast that throws empties the catalog: every integration switched on anywhere stops',
      );
      service.dispose();
    });
  });

  // The view's first build comes before its log does, so `open` usually
  // fires with no log. Taken at the next call instead, the start would fold
  // in every contact logged until then: a whole tick, for one woken only by
  // ticks.
  test('the first log the view reads is where changes start, not the next call', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['tick:60']),
      ]);
      final op = _op('op-1', on: [_id]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: op));
      async.flushMicrotasks();
      expect(extensions.calls.single.reasons, {'open'});

      feed.update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a')]));
      feed.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.elapse(const Duration(minutes: 1));
      expect(extensions.calls.last.reasons, {'tick'});
      expect(extensions.calls.last.uuids('logged'), ['b'], reason: 'a was in the log when it opened; b was logged after');
      service.dispose();
    });
  });

  test('a call that never went out, for want of a runtime, leaves its changes for the next', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final op = _op('op-1', on: [_id]);
      final feed = service.openFeed()..update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a')]));
      async.elapse(_pastGap);

      extensions.answering = false;
      feed.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.elapse(_pastGap);
      extensions.answering = true;
      feed.update(PanelRenderContext(operation: op, qsoCount: 3, log: [_qso('a'), _qso('b'), _qso('c')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), ['b', 'c'], reason: 'no extension was handed b, so nothing took it');
      service.dispose();
    });
  });

  test('an operation open in two views is one integration call, and the second view takes over when the first closes', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qsoLogged']),
      ]);
      final op = _op('op-1', on: [_id]);
      final first = service.openFeed()..update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a')]));
      // The command bar or the Logs edit panel pushing the same operation over it.
      final second = service.openFeed()..update(PanelRenderContext(operation: op, qsoCount: 1, log: [_qso('a')]));
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1));

      first.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      second.update(PanelRenderContext(operation: op, qsoCount: 2, log: [_qso('a'), _qso('b')]));
      async.elapse(_pastGap);
      expect(
        [for (final call in extensions.calls.skip(1)) call.uuids('logged')],
        [
          ['b'],
        ],
        reason: 'handed to it once per view, b would be posted twice',
      );

      first.close();
      async.elapse(_pastGap);
      expect(extensions.calls.last.reasons, {'open'}, reason: 'the view left open carries on');
      second.update(PanelRenderContext(operation: op, qsoCount: 3, log: [_qso('a'), _qso('b'), _qso('c')]));
      async.elapse(_pastGap);
      expect(extensions.calls.last.uuids('logged'), ['c']);
      service.dispose();
    });
  });

  test('the draft never reaches an integration', () {
    fakeAsync((async) {
      final service = start(async, [
        _integration('stream', const ['qso', 'lookup', 'qsoLogged']),
      ]);
      expect(service.catalog.single.triggers, ['qsoLogged'], reason: 'qso and lookup are refused when it is offered');
      final feed = service.openFeed()..update(PanelRenderContext(operation: _op('op-1', on: [_id])));
      async.elapse(_pastGap);
      feed.update(
        PanelRenderContext(
          operation: _op('op-1', on: [_id]),
          qso: const {
            'their': {'call': 'W1A'},
          },
        ),
      );
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1), reason: 'a keystroke wakes no integration');
      expect(service.wants('qso'), isFalse, reason: 'and no view produces the draft for one');
      service.dispose();
    });
  });

  test('switching one on or off writes its id into the operation, keeping the others', () {
    fakeAsync((async) {
      final service = start(async, [_integration('stream', const [])]);
      final stream = service.catalog.single;
      const other = 'integration:w7abc-board:score';
      stored['op-1'] = {
        IntegrationService.localDataKey: [other],
      };
      unawaited(service.setOn(stream, 'op-1', true));
      async.flushMicrotasks();
      expect(writes.single.$1, 'op-1');
      expect(writes.single.$2, {
        IntegrationService.localDataKey: [other, _id],
      });

      unawaited(service.setOn(stream, 'op-1', false));
      async.flushMicrotasks();
      expect(writes.last.$2, {
        IntegrationService.localDataKey: [other],
      });

      unawaited(service.setOn(stream, 'op-1', false));
      async.flushMicrotasks();
      expect(writes, hasLength(2), reason: 'already off, nothing is written: a localData write rebuilds the view');
      expect(IntegrationService.isOnIn(stream, _op('op-1', on: [_id])), isTrue);
      expect(stream.id, _id, reason: 'its settings and switch are kept under this id');
      service.dispose();
    });
  });

  test('two switches flipped before the operation is read again both stay on', () {
    fakeAsync((async) {
      final service = start(async, [_integration('stream', const []), _integration('board', const [], hookKey: 'w7abc-board')]);
      final [stream, board] = service.catalog;
      unawaited(service.setOn(stream, 'op-1', true));
      unawaited(service.setOn(board, 'op-1', true));
      async.flushMicrotasks();
      expect(
        stored['op-1']?[IntegrationService.localDataKey],
        [stream.id, board.id],
        reason: 'each switch makes its list from what the operation holds as it writes; from the copy the dialog last read, the second undoes the first',
      );
      service.dispose();
    });
  });
}
