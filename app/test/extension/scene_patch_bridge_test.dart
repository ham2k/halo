// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene changes in place, by the steps of a patch, from an event answer or
// `host.updateScene`; and a render that gives the scene the pane already
// shows crosses as nothing changed (docs/design/panel-scenes.md § Patches).
// The runtime keeps each placement's last scene, and the pane applies each
// patch to the scene it shows: a step lost, misapplied, or applied to a
// scene the pane no longer shows puts in front of the operator a scene the
// extension never rendered, with nothing to say so — so each test holds
// what the pane ends up with against the whole scene, rendered fresh.
// Driven through the REAL kernel, by hand-written bundles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation/extension_panel.dart';
import 'package:ham2k_logger/views/operation/panel_content_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/shipped_extensions.dart';

/// A scene of a backdrop, a line of text and a button over it: the text from
/// the placement's config, else the last button clicked, which an event
/// answer patches in. Layers it is told to add come after; and a bench that
/// pushes a patch to a placement.
const patcher = r'''
  globalThis.__halo.defineExtension({
    key: 'patcher',
    name: 'patcher',
    version: '0.0.1',
    onActivation(api) {
      let clicked = null;
      const extra = [];
      const scene = (label) => ({
        version: 1, width: 200, height: 20, values: {}, strings: { label },
        layers: [
          { id: 'bg', x: 0, y: 0, width: 200, height: 20, svg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 20"><rect width="200" height="20" fill="#000"/></svg>' },
          { id: 'text', x: 0, y: 0, width: 200, height: 20, text: { value: 'label', size: 12, color: '#FFFFFF' } },
          ...extra,
        ],
        controls: [
          { id: 'go', kind: 'button', label: 'Go', event: 'clicked', x: 0, y: 0, width: 100, height: 20 },
          { id: 'bad', kind: 'button', label: 'Bad', event: 'bad', x: 100, y: 0, width: 100, height: 20 },
        ],
      });
      api.registerHook('panel', {
        hook: {
          getPanels: async () => [{ key: 'p', title: 'Patcher' }],
          // A stray `patch` on a render answer, as a hook sharing one answer shape for both might send.
          render: async (args) => args.config?.orphan
            ? { kind: 'scene', patch: [{ set: ['strings', 'label'], value: 'orphan' }] }
            : { kind: 'scene', scene: scene(args.config?.label ?? clicked ?? 'hello'), ...(args.config?.stray ? { patch: null, base: 3 } : {}) },
          onEvent: async (args) => {
            if (args.event.action === 'bad') return { values: { x: 'not a number' }, patch: [{ set: ['strings', 'label'], value: 'bad' }] };
            if (args.event.action === 'nopatch') return { values: {}, patch: null };
            clicked = args.event.action;
            return { values: {}, patch: [{ set: ['strings', 'label'], value: clicked }] };
          },
        },
      });
      api.registerHook('bench', {
        hook: {
          call: async (args) => {
            if (args.probe !== 'addLayer') return await api.hostCall('updateScene', { instanceId: args.instanceId, patch: args.patch });
            // Sent, then moved in place, as a hook keeping its own objects does.
            const layer = { id: 'extra', x: 0, y: 0, width: 10, height: 10, text: { value: 'label', size: 8 } };
            extra.push(layer);
            const applied = await api.hostCall('updateScene', { instanceId: args.instanceId, patch: [{ insert: ['layers'], value: layer }] });
            layer.y = 5;
            return applied;
          },
        },
      });
    },
  });
''';

/// Pushes to whichever placement it is told: never one of its own.
const intruder = r'''
  globalThis.__halo.defineExtension({
    key: 'intruder',
    name: 'intruder',
    version: '0.0.1',
    onActivation(api) {
      api.registerHook('bench', {
        hook: { call: async (args) => await api.hostCall('updateScene', { instanceId: args.instanceId, patch: args.patch }) },
      });
    },
  });
''';

({String source, ExtensionInfo info}) bundle(String key, String source) =>
    (source: source, info: ExtensionInfo(key: key, file: '$key.js', source: ExtensionSource.dev, core: true, name: key));

const relabel = [
  {
    'set': ['strings', 'label'],
    'value': 'pushed',
  },
];

/// A pane as the update registry sees it: told each update, applying it when it can.
class _Pane {
  final String name;
  final List<String> told;
  final void Function(Map<String, dynamic> update)? apply;
  _Pane(this.name, this.told, {this.apply});

  bool take(Map<String, dynamic> update) {
    told.add(name);
    apply?.call(update);
    return apply != null;
  }
}

/// The production service, keeping the args each event crossed with.
class _RecordingService extends ExtensionService {
  final eventArgs = <Map<String, dynamic>>[];
  int renders = 0;

  @override
  Future<Map<String, dynamic>?> renderPanel({required String hookKey, required String panelKey, required Map<String, dynamic> args}) {
    renders++;
    return super.renderPanel(hookKey: hookKey, panelKey: panelKey, args: args);
  }

  @override
  Future<Map<String, dynamic>?> panelEvent({required String hookKey, required String panelKey, required Map<String, dynamic> args}) {
    eventArgs.add(args);
    return super.panelEvent(hookKey: hookKey, panelKey: panelKey, args: args);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingService extensions;
  late PanelService panels;
  late PanelDefinition panel;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    extensions = _RecordingService()..settings = await SettingsService.load();
    prepareExtensionServiceForTest(extensions);
    await extensions.setDevBundles({'patcher': bundle('patcher', patcher), 'intruder': bundle('intruder', intruder)});
    panels = PanelService(extensions);
    await panels.refreshExtensionPanels();
    panel = panels.catalog.singleWhere((p) => p.panelKey == 'p');
  });

  tearDown(() => panels.dispose());

  /// [label]'s scene rendered for the pane showing [shown]: what crossed, and what the pane holds after.
  Future<Map<String, dynamic>> crossing(PanelContent? shown, Map<String, Object> config) async =>
      (await panels.render(panel, {'config': config, 'qsoCount': 0, 'reason': 'test', if (shown?.revision != null) 'sceneRevision': shown!.revision}))!;

  Future<(Map<String, dynamic>, PanelContent)> render(PanelContent? shown, {String label = 'hello', bool stray = false}) async {
    final crossed = (await panels.render(panel, {
      'config': {'label': label, if (stray) 'stray': true},
      'qsoCount': 0,
      'reason': 'test',
      if (shown?.revision != null) 'sceneRevision': shown!.revision,
    }))!;
    return (crossed, PanelContent.fromJson(crossed, previous: shown)!);
  }

  Future<Object?> push(String who, List<Object> patch, {String? instanceId, String? probe}) => extensions.host!.invokeHook(
    'bench',
    key: who,
    method: 'call',
    args: {'instanceId': instanceId ?? panel.id, 'patch': patch, 'probe': ?probe},
    timeout: const Duration(seconds: 10),
  );

  test('a render that gives the scene shown again crosses as nothing changed, and one that changed comes whole', () async {
    final (firstCrossed, first) = await render(null);
    expect(firstCrossed['scene'], isA<Map>(), reason: 'nothing shown yet: the scene goes whole');
    final (unchanged, again) = await render(first);
    expect(unchanged['scene'], isNull);
    expect(unchanged['patch'], isEmpty);
    expect(again, first, reason: 'the same scene again rebuilds nothing');
    final (changed, second) = await render(again, label: 'there');
    expect(changed['scene'], isA<Map>());
    expect(second.scene!.strings['label'], 'there');
  });

  test('an event answer\'s patch changes the scene the pane shows, as the extension\'s next render would', () async {
    final (_, shown) = await render(null);
    final answer = (await panels.event(panel, {
      'config': {'label': 'hello'},
      'qsoCount': 0,
      'reason': 'event',
      'sceneRevision': shown.revision,
      'event': {'controlId': 'x', 'action': 'clicked', 'phase': 'commit', 'sequence': 1},
    }))!;
    final updated = shown.updated(answer);
    expect(updated.scene!.strings['label'], 'clicked');
    expect(identical(updated.scene!.layers.first, shown.scene!.layers.first), isTrue, reason: 'what the step did not touch is not read again');
    final (_, whole) = await render(null, label: 'clicked');
    expect(updated.document, whole.document);
    expect(() => whole.updated(answer), throwsA(isA<SceneOutOfStep>()), reason: 'taken from a scene this one is not');
  });

  test('host.updateScene changes what the extension\'s own placement shows, and no other extension\'s', () async {
    expect(await push('patcher', relabel), false, reason: 'nothing rendered yet: nothing to patch');
    var (_, shown) = await render(null);
    panels.listenForSceneUpdates(panel.id, (update) {
      shown = shown.updated(update);
      return true;
    });
    expect(await push('patcher', relabel), true);
    expect(shown.scene!.strings['label'], 'pushed');
    await expectLater(push('intruder', relabel), throwsA(anything), reason: 'refused: not the intruder\'s placement');
    await expectLater(
      extensions.debugHandleHostCall('updateScene', {
        'instanceId': panel.id,
        'base': shown.revision,
        'revision': 999,
        'patch': relabel,
        'extensionKey': 'intruder',
      }),
      throwsA(anything),
      reason: 'the app refuses it too, whoever the call says it is from',
    );
    final (_, next) = await render(shown, label: 'hello');
    expect(next.scene!.strings['label'], 'hello', reason: 'the render after an update is taken from it');
  });

  // A runtime numbering from 1 again would hand a fresh scene the number of
  // one the pane still shows from before; taken for that one, it is kept,
  // and the pane shows the old version's scene for good.
  test('a scene from a new runtime never shares a revision with one from before', () async {
    final (_, before) = await render(null);
    await extensions.restartRuntime();
    final (_, after) = await render(null);
    expect(after.revision, isNot(before.revision));
    expect(PanelContent.fromJson({'kind': 'scene', 'scene': after.document, 'revision': after.revision}, previous: before), isNot(before));
  });

  // Applied to the kernel's scene as the very objects the hook still holds,
  // a value changed in place afterwards changes the scene the kernel thinks
  // the app shows, and the next render crosses as unchanged.
  test('a value the hook changes after sending it is a change the next render brings', () async {
    var (_, shown) = await render(null);
    panels.listenForSceneUpdates(panel.id, (update) {
      shown = shown.updated(update);
      return true;
    });
    expect(await push('patcher', const [], probe: 'addLayer'), true);
    expect(shown.scene!.layers.last.rect.top, 0);
    final (crossed, next) = await render(shown);
    expect(crossed['scene'], isA<Map>(), reason: 'the layer moved after it was sent: changed, not the same scene again');
    expect(next.scene!.layers.last.rect.top, 5);
  });

  test('an event answer\'s patch with no scene to apply it to leaves the rest of the answer standing', () async {
    final answer = await panels.event(panel, {
      'config': <String, dynamic>{},
      'qsoCount': 0,
      'reason': 'event',
      'event': {'controlId': 'go', 'action': 'clicked', 'phase': 'activate', 'sequence': 1},
    });
    expect(answer!['values'], isEmpty);
    expect(answer['patch'], isNull);
  });

  // An update the runtime cannot apply, with nothing held, still reaches the
  // pane, which renders the panel again for the whole scene; otherwise one
  // with no triggers stays as it was.
  test('host.updateScene with no scene held is told to the pane, to ask for it whole', () async {
    final told = <Map<String, dynamic>>[];
    panels.listenForSceneUpdates(panel.id, (update) {
      told.add(update);
      return false;
    });
    expect(await push('patcher', relabel), false);
    expect(told.single['base'], isNull);
  });

  // An empty update still moves the runtime on; a pane that stays where it
  // was is out of step, and its next render and update both come whole.
  test('an empty update moves the pane on with the runtime', () async {
    var (_, shown) = await render(null);
    panels.listenForSceneUpdates(panel.id, (update) {
      final updated = shown.updated(update);
      if (updated != shown) shown = updated;
      return true;
    });
    expect(await push('patcher', const []), true);
    final (crossed, _) = await render(shown);
    expect(crossed['patch'], isEmpty, reason: 'still in step');
  });

  // A view stays mounted under the one opened over it, and a placement's id is
  // the same in both: kept as one listener, the second pane's would replace
  // the first's, and closing it would leave the first with none.
  test('every pane showing a placement takes its updates, and one closing leaves the others theirs', () async {
    var (_, shown) = await render(null);
    final told = <String>[];
    final home = _Pane('home', told);
    final operation = _Pane('operation', told, apply: (update) => shown = shown.updated(update));
    // Each a tear-off, as a pane hands its own method: a new object every time it is named.
    panels.listenForSceneUpdates(panel.id, home.take);
    panels.listenForSceneUpdates(panel.id, operation.take);
    expect(await push('patcher', relabel), true, reason: 'one applied it');
    expect(told, ['home', 'operation']);
    panels.stopSceneUpdates(panel.id, operation.take);
    await push('patcher', relabel);
    expect(told.sublist(2), ['home'], reason: 'the closed pane is gone, the other still told');
  });

  // Held on to after the app refused it, the scene a push would have left is
  // what the kernel judges the next push against: a corrected retry is
  // refused for a marker the operator never saw.
  test('a push the app refuses is let go, so a corrected one is judged against what the pane shows', () async {
    var (_, shown) = await render(null);
    panels.listenForSceneUpdates(panel.id, (update) {
      // As the pane does: out of step, it asks for the scene whole and says it did not apply it.
      try {
        shown = shown.updated(update);
        return true;
      } on SceneOutOfStep {
        return false;
      }
    });
    Map<String, Object> layer(Object y) => {
      'id': 'late',
      'x': 0,
      'y': y,
      'width': 10,
      'height': 10,
      'text': {'value': 'label', 'size': 8},
    };
    List<Object> insert(Object y) => [
      {
        'insert': ['layers'],
        'value': layer(y),
      },
    ];
    await expectLater(push('patcher', insert('not a number')), throwsA(anything));
    expect(await push('patcher', insert(2)), false, reason: 'not refused as already having a layer the pane never showed');
  });

  test('a stray patch on a render answer is no patch: the scene comes whole', () async {
    final (crossed, shown) = await render(null, stray: true);
    expect(crossed.containsKey('patch'), isFalse);
    expect(shown.scene!.strings['label'], 'hello');
    // One with no scene at all is refused as having none, not taken for a patch.
    final orphan = await crossing(shown, {'orphan': true});
    expect(orphan.containsKey('patch'), isFalse);
    expect(() => PanelContent.fromJson(orphan, previous: shown), throwsA(isA<FormatException>()));
  });

  test('an event answer\'s null patch is no patch, and the answer stands', () async {
    final (_, shown) = await render(null);
    final answer = await panels.event(panel, {
      'config': <String, dynamic>{},
      'qsoCount': 0,
      'reason': 'event',
      'sceneRevision': shown.revision,
      'event': {'controlId': 'go', 'action': 'nopatch', 'phase': 'activate', 'sequence': 1},
    });
    expect(answer!['values'], isEmpty);
  });

  test('an update for a placement the catalog does not hold is not applied, and not refused as another\'s', () async {
    await render(null);
    expect(await push('patcher', relabel, instanceId: 'ext:patcher:gone'), false);
  });

  testWidgets('an update the pane takes shows at once, and one it cannot take brings the whole scene', (tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            // Room for the pane's notice that an action failed.
            body: SizedBox(
              width: 200,
              height: 300,
              child: ExtensionPanel(panel: panel, panels: panels, renderContext: const PanelRenderContext()),
            ),
          ),
        ),
      ),
    );
    Future<void> bridgeUntil(bool Function() delivered) async {
      for (var i = 0; i < 500 && !delivered(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        // With time: the render asked again waits out the pane's idle gap on a timer.
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
      }
    }

    await bridgeUntil(() => find.text('hello').evaluate().isNotEmpty);
    expect(await tester.runAsync(() => push('patcher', relabel)), true);
    await tester.pump();
    expect(find.text('pushed'), findsOneWidget);
    // Taken from a revision the pane does not show: it says so, and asks again.
    expect(panels.updateScene('patcher', {'instanceId': panel.id, 'base': -1, 'revision': -2, 'patch': relabel}), false);
    await bridgeUntil(() => find.text('hello').evaluate().isNotEmpty);
    expect(find.text('hello'), findsOneWidget, reason: 'the whole scene, as the extension renders it');
    // Through the pane itself: an answer's patch is taken from the scene it shows.
    final box = tester.getRect(find.byType(ExtensionPanel));
    await tester.tapAt(Offset(box.left + 20, box.center.dy));
    await bridgeUntil(() => find.text('clicked').evaluate().isNotEmpty);
    expect(extensions.eventArgs.last['sceneRevision'], isA<int>(), reason: 'the event says which scene its answer may patch');
    expect(find.text('clicked'), findsOneWidget);
    // An answer whose values are refused changes nothing, its patch included.
    await tester.tapAt(Offset(box.right - 20, box.center.dy));
    await bridgeUntil(() => find.text('That panel action failed. Try again.').evaluate().isNotEmpty);
    expect(find.text('bad'), findsNothing);
    expect(find.text('clicked'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  // A view stays mounted under the one opened over it. A pane there showing a
  // placement the top one shows too is put out of step by every update the
  // top one takes; asking for the scene again each time, the two would take
  // turns rendering it whole, for nobody.
  testWidgets('a pane covered by another screen waits to be shown before asking for the scene again', (tester) async {
    var covered = false;
    late StateSetter cover;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                cover = setState;
                // As the navigator leaves a route an opaque one is opened over.
                return TickerMode(
                  enabled: !covered,
                  child: SizedBox(
                    width: 200,
                    height: 300,
                    child: ExtensionPanel(panel: panel, panels: panels, renderContext: const PanelRenderContext()),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    Future<void> settle(bool Function() delivered) async {
      for (var i = 0; i < 100 && !delivered(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await settle(() => find.text('hello').evaluate().isNotEmpty);
    cover(() => covered = true);
    await tester.pump();
    final before = extensions.renders;
    expect(panels.updateScene('patcher', {'instanceId': panel.id, 'base': -1, 'revision': -2, 'patch': relabel}), false);
    await settle(() => false);
    expect(extensions.renders, before, reason: 'covered: nobody to render it for');
    cover(() => covered = false);
    await settle(() => extensions.renders > before);
    expect(extensions.renders, before + 1, reason: 'shown again, it asks once for the whole scene');
    // The answer lands before the pane goes, or its wait for it is left running.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
