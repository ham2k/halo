// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// AssistantService (docs/extensions/assistants.md): when an assistant is called,
// about which operation, and for what. Everything here runs on the fake clock
// (docs/design/time.md §7) — the gap between calls is the throttle a panel
// pays, and asserting it on real timers would test only a loaded machine.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/assistant_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';

import '../support/fake_clock.dart';

class _Call {
  final String hookKey;
  final String assistantKey;
  final Map<String, dynamic> args;
  _Call(this.hookKey, this.assistantKey, this.args);

  String get operationUuid => (args['operation'] as Map)['uuid'] as String;
  Set<String> get reasons => {...(args['reasons'] as List).cast<String>()};

  /// `<what> <reasons, sorted>`: comparable, where a record holding a set is not.
  String about(String what) => '$what ${(reasons.toList()..sort()).join(',')}';
}

class _FakeAssistantExtensions implements AssistantExtensionSource {
  List<Map<String, dynamic>>? entries;
  final calls = <_Call>[];
  final radioReaders = <String>{};

  /// When set, each call waits on it — a call in flight, for as long as a test wants.
  Completer<void>? hold;
  Object? failWith;

  _FakeAssistantExtensions(this.entries);

  @override
  final ValueNotifier<int> runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionAssistants() async => entries;

  @override
  Future<bool> observe({required String hookKey, required String assistantKey, required Map<String, dynamic> args}) async {
    calls.add(_Call(hookKey, assistantKey, args));
    await hold?.future;
    if (failWith != null) throw failWith!;
    return true;
  }

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async => {'from': panelKey};

  @override
  bool canReadRadio(String? hookKey) => radioReaders.contains(hookKey);
}

class _MemorySwitches implements AssistantSwitches {
  final values = <String, bool>{};
  @override
  bool? read(String id) => values[id];
  @override
  Future<void> write(String id, bool enabled) async => values[id] = enabled;
}

Map<String, dynamic> _assistant(String key, List<String> on, {String hookKey = 'k1abc-coach', bool? enabledByDefault}) => {
  'hookKey': hookKey,
  'key': key,
  'title': key,
  'on': on,
  'enabledByDefault': ?enabledByDefault,
};

const _op1 = Operation(uuid: 'op-1', data: {'stationCall': 'K1ABC'});
const _op2 = Operation(uuid: 'op-2', data: {'stationCall': 'K1ABC'});

/// Past the gap a second call waits out, so a test asserting "it came" never
/// depends on how close to the gap it looked.
final _pastGap = panelRenderThrottle + const Duration(milliseconds: 10);

void main() {
  late _FakeAssistantExtensions extensions;
  late _MemorySwitches switches;
  late ValueNotifier<List<Object?>> dial;

  AssistantService start(FakeAsync async, List<Map<String, dynamic>> entries) {
    extensions = _FakeAssistantExtensions(entries);
    switches = _MemorySwitches();
    dial = ValueNotifier(const ['14074']);
    final service = AssistantService(extensions, switches: switches, radio: (changes: dial, state: () => dial.value));
    unawaited(service.refresh());
    async.flushMicrotasks();
    return service;
  }

  setUp(followFakeClock);

  test('an assistant hears of each operation as it opens, with no pane anywhere', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('rate', const ['qsoLogged']),
      ]);
      service.openFeed().update(const PanelRenderContext(operation: _op1));
      service.openFeed().update(const PanelRenderContext(operation: _op2));
      async.flushMicrotasks();
      expect(extensions.calls.map((c) => c.about(c.operationUuid)), ['op-1 open', 'op-2 open']);
      expect(extensions.calls.first.args['config'], {'from': 'assistant:k1abc-coach:rate'}, reason: 'its settings are kept under its own id');
      service.dispose();
    });
  });

  test('only what it declared wakes it', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('rate', const ['qsoLogged']),
      ]);
      final feed = service.openFeed()..update(const PanelRenderContext(operation: _op1));
      async.elapse(_pastGap);
      extensions.calls.clear();

      // A keystroke in the draft is not a contact logged.
      feed.update(
        const PanelRenderContext(
          operation: _op1,
          qso: {
            'their': {'call': 'W1A'},
          },
        ),
      );
      async.elapse(_pastGap);
      expect(extensions.calls, isEmpty);

      feed.update(
        const PanelRenderContext(
          operation: _op1,
          qso: {
            'their': {'call': 'W1A'},
          },
          qsoCount: 1,
        ),
      );
      async.elapse(_pastGap);
      expect(extensions.calls.single.reasons, {'qsoLogged'});
      service.dispose();
    });
  });

  test('what arrives while a call is out is folded into one call, after the gap', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('coach', const ['qsoLogged', 'spots']),
      ]);
      final feed = service.openFeed();
      extensions.hold = Completer();
      feed.update(const PanelRenderContext(operation: _op1));
      async.flushMicrotasks();
      expect(extensions.calls, hasLength(1));

      feed.update(const PanelRenderContext(operation: _op1, qsoCount: 1));
      feed.update(const PanelRenderContext(operation: _op1, qsoCount: 2, spotsRevision: 1));
      async.elapse(const Duration(seconds: 3));
      expect(extensions.calls, hasLength(1), reason: 'never a second call while the first is out');

      extensions.hold!.complete();
      extensions.hold = null;
      async.elapse(panelRenderThrottle - const Duration(milliseconds: 10));
      expect(extensions.calls, hasLength(1), reason: 'the gap after a call is the same one a panel waits out');

      async.elapse(const Duration(milliseconds: 20));
      expect(extensions.calls, hasLength(2));
      expect(extensions.calls.last.reasons, {'qsoLogged', 'spots'});
      expect(extensions.calls.last.args['qsoCount'], 2, reason: 'the call reads the newest context, not the one that woke it');
      service.dispose();
    });
  });

  test('switched off it hears nothing; switched on it hears every operation already open', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('coach', const ['qsoLogged'], enabledByDefault: false),
      ]);
      final feed = service.openFeed()..update(const PanelRenderContext(operation: _op1));
      feed.update(const PanelRenderContext(operation: _op1, qsoCount: 1));
      async.elapse(_pastGap);
      expect(extensions.calls, isEmpty, reason: 'enabledByDefault: false starts it off');
      expect(service.wants('qsoLogged'), isFalse, reason: 'a view must not produce a signal for an assistant that is off');

      unawaited(service.setEnabled(service.catalog.single, true));
      async.elapse(_pastGap);
      expect(extensions.calls.single.reasons, {'open'});
      expect(service.wants('qsoLogged'), isTrue);

      unawaited(service.setEnabled(service.catalog.single, false));
      async.flushMicrotasks();
      feed.update(const PanelRenderContext(operation: _op1, qsoCount: 2));
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1));
      service.dispose();
    });
  });

  // Two calls about one operation at once interleave their FYI posts and
  // clears; switching off and on again, or the runtime re-offering the same
  // assistant, must queue the `open` behind the call still out.
  test('switched off and on during a call, it hears `open` only after that call ends', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('coach', const ['qsoLogged']),
      ]);
      extensions.hold = Completer();
      service.openFeed().update(const PanelRenderContext(operation: _op1));
      async.flushMicrotasks();
      expect(extensions.calls, hasLength(1));

      unawaited(service.setEnabled(service.catalog.single, false));
      async.flushMicrotasks();
      unawaited(service.setEnabled(service.catalog.single, true));
      async.elapse(const Duration(seconds: 2));
      expect(extensions.calls, hasLength(1), reason: 'never beside the call still out');

      extensions.calls.clear();
      extensions.runtimeGeneration.value++;
      async.elapse(const Duration(seconds: 2));
      expect(extensions.calls, isEmpty, reason: 're-offered by the runtime, it still waits');

      extensions.hold!.complete();
      extensions.hold = null;
      async.elapse(_pastGap);
      expect(extensions.calls.map((c) => c.about(c.operationUuid)), ['op-1 open']);
      service.dispose();
    });
  });

  // The draft is the operator's keystrokes; other features produce it too,
  // so having one in hand is no reason to hand it over.
  test('the draft goes only to an assistant that declared `qso` or `lookup`', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('logged', const ['qsoLogged']),
        _assistant('typed', const ['qso']),
      ]);
      service.openFeed().update(
        const PanelRenderContext(
          operation: _op1,
          qso: {
            'their': {'call': 'W1A'},
          },
        ),
      );
      async.elapse(_pastGap);
      final byKey = {for (final c in extensions.calls) c.assistantKey: c.args};
      expect(byKey['logged']!.containsKey('qso'), isFalse);
      expect(byKey['typed']!['qso'], isNotNull);
      service.dispose();
    });
  });

  test('a tick reaches every open operation, on the period declared', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('clock', const ['tick:5']),
      ]);
      service.openFeed().update(const PanelRenderContext(operation: _op1));
      service.openFeed().update(const PanelRenderContext(operation: _op2));
      async.elapse(_pastGap);
      extensions.calls.clear();

      async.elapse(const Duration(seconds: 5));
      expect(extensions.calls.map((c) => c.about(c.operationUuid)), unorderedEquals(['op-1 tick', 'op-2 tick']));
      async.elapse(const Duration(seconds: 5));
      expect(extensions.calls, hasLength(4), reason: 'the chain re-arms itself');
      service.dispose();
    });
  });

  test('the radio wakes only an assistant whose extension may read the radio', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('band', const ['radio'], hookKey: 'k1abc-reader'),
        _assistant('band', const ['radio'], hookKey: 'k1abc-other'),
      ]);
      extensions.radioReaders.add('k1abc-reader');
      service.openFeed().update(const PanelRenderContext(operation: _op1));
      async.elapse(_pastGap);
      extensions.calls.clear();

      dial.value = const ['7074'];
      async.elapse(_pastGap);
      expect(extensions.calls.map((c) => c.about(c.hookKey)), ['k1abc-reader radio']);

      // A reading that leaves the dial where it was — a meter — is no change.
      dial.value = const ['7074'];
      async.elapse(_pastGap);
      expect(extensions.calls, hasLength(1));
      service.dispose();
    });
  });

  test('an operation closed is never called about again', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('coach', const ['tick:1']),
      ]);
      final feed = service.openFeed()..update(const PanelRenderContext(operation: _op1));
      async.elapse(_pastGap);
      feed.close();
      extensions.calls.clear();
      async.elapse(const Duration(seconds: 5));
      expect(extensions.calls, isEmpty);
      service.dispose();
    });
  });

  test('an assistant that throws is called again on the next change', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('coach', const ['qsoLogged']),
      ]);
      extensions.failWith = StateError('boom');
      final feed = service.openFeed()..update(const PanelRenderContext(operation: _op1));
      async.elapse(_pastGap);
      extensions.failWith = null;
      feed.update(const PanelRenderContext(operation: _op1, qsoCount: 1));
      async.elapse(_pastGap);
      expect(extensions.calls.map((c) => c.reasons), [
        {'open'},
        {'qsoLogged'},
      ]);
      service.dispose();
    });
  });

  test('an assistant the runtime no longer offers stops, and one it starts offering opens', () {
    fakeAsync((async) {
      final service = start(async, [
        _assistant('old', const ['tick:1']),
      ]);
      service.openFeed().update(const PanelRenderContext(operation: _op1));
      async.elapse(_pastGap);

      extensions.calls.clear();
      extensions.entries = [_assistant('new', const [])];
      extensions.runtimeGeneration.value++;
      async.elapse(const Duration(seconds: 3));
      expect(extensions.calls.map((c) => c.about(c.assistantKey)), ['new open']);
      service.dispose();
    });
  });
}
