// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What a PLACEMENT may ask to be woken by, on top of what its panel's
// descriptor declared (`PanelContent.triggers`). The rules live in
// PanelService because more than the pane depends on them: the operation
// view produces a QSO draft per keystroke only while something in the
// arrangement wants one, and that decision is made from an id.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/panel_service.dart';

void main() {
  const descriptor = PanelDefinition(
    id: 'ext:text:custom',
    title: 'Custom Text',
    source: PanelSource.extension,
    hookKey: 'text',
    panelKey: 'custom',
    triggers: ['qsoLogged'],
  );

  late _StubSource source;
  late PanelService panels;
  setUp(() {
    source = _StubSource([descriptor]);
    panels = PanelService(source);
  });
  tearDown(() => panels.dispose());

  test('a placement is woken by its descriptor and its own render together', () async {
    await panels.refreshExtensionPanels();
    panels.declareTriggers('ext:text:custom', ['qso']);

    expect(panels.triggersFor('ext:text:custom'), {'qsoLogged', 'qso'});
  });

  // The whole point of per-instance triggers: one operator's template naming
  // the callsign being typed must not put every other pane of the same panel
  // on the typing path.
  test('one placement asking for a trigger says nothing about another', () async {
    await panels.refreshExtensionPanels();
    panels.declareTriggers('ext:text:custom#2', ['qso']);

    expect(panels.declaredTriggers('ext:text:custom'), isEmpty);
    expect(panels.triggersFor('ext:text:custom'), {'qsoLogged'});
  });

  // Same rule as a descriptor's, for the same reason: a panel rendered once
  // and then silent forever is indistinguishable from one that meant to be,
  // so a name the host never fires is refused where someone can see it.
  test('a trigger the host does not fire is dropped, not stored', () {
    panels.declareTriggers('ext:text:custom', ['qso', 'whenever', 'tick:0']);

    expect(panels.declaredTriggers('ext:text:custom'), ['qso']);
  });

  test('a valid tick survives, since that is how a template clock updates', () {
    panels.declareTriggers('ext:text:custom', ['tick:30']);

    expect(panels.declaredTriggers('ext:text:custom'), ['tick:30']);
  });

  // The view rebuilds on this notification, and only then does it start
  // producing the signal that was just asked for. Without it a template
  // naming the QSO would sit on an empty draft until something unrelated
  // rebuilt the view.
  test('a change notifies, and re-declaring the same set does not', () {
    var notifications = 0;
    panels.addListener(() => notifications++);

    expect(panels.declareTriggers('ext:text:custom', ['qso']), isTrue);
    expect(notifications, 1);

    expect(panels.declareTriggers('ext:text:custom', ['qso']), isFalse);
    expect(notifications, 1, reason: 'every render of a stable template would otherwise rebuild the view');
  });

  test('a placement that stops asking is left with nothing', () {
    panels.declareTriggers('ext:text:custom', ['qso']);
    expect(panels.declareTriggers('ext:text:custom', const []), isTrue);

    expect(panels.declaredTriggers('ext:text:custom'), isEmpty);
  });

  // An instance id is an anonymous slot that the next placement reuses
  // (`forgetInstanceConfig`). Left behind, a pane holding static text would
  // inherit the typing-path cost of whatever used to be in that slot.
  test('removing a pane forgets what it asked for', () async {
    await panels.refreshExtensionPanels();
    panels.declareTriggers('ext:text:custom#1', ['qso']);

    await panels.forgetInstanceConfig('ext:text:custom#1');

    expect(panels.declaredTriggers('ext:text:custom#1'), isEmpty);
  });

  // The config guards do not apply to trigger declarations, which are
  // runtime state rather than the operator's configuration. A pane removed
  // while its extension is disabled — the catalog answers null — must still
  // give up its claim on the typing path, and a pane added behind a dock tab
  // does not render until it is looked at, so nothing else would clear it.
  test('a pane removed while its panel is unknown still forgets', () async {
    // No refreshExtensionPanels: the catalog has never heard of this id.
    panels.declareTriggers('ext:text:custom#1', ['qso']);

    await panels.forgetInstanceConfig('ext:text:custom#1');

    expect(panels.declaredTriggers('ext:text:custom#1'), isEmpty);
  });

  // A disabled extension's pane shows a placeholder instead of rendering, so
  // anything produced for it is produced for nobody — and `qso` is not free:
  // it rebuilds and deep-compares the QSO draft on every keystroke for the
  // whole view. The declaration itself survives, so re-enabling restores it
  // without waiting for a render.
  test('a panel the catalog cannot explain asks for nothing', () async {
    await panels.refreshExtensionPanels();
    panels.declareTriggers('ext:text:custom', ['qso']);
    expect(panels.triggersFor('ext:text:custom'), {'qsoLogged', 'qso'});

    // The operator disables the extension: its panels leave the catalog,
    // while the pane stays in the arrangement as a placeholder.
    source.panels.clear();
    await panels.refreshExtensionPanels();

    expect(panels.triggersFor('ext:text:custom'), isEmpty);
    expect(panels.declaredTriggers('ext:text:custom'), ['qso']);
  });

  // Reached once per render — a `tick:5` pane every five seconds. Comparing
  // as a list would make a reordered but identical set restart tickers and
  // rebuild the operation view for nothing.
  test('the same triggers in a different order are not a change', () {
    expect(panels.declareTriggers('ext:text:custom', ['qso', 'tick:30']), isTrue);
    expect(panels.declareTriggers('ext:text:custom', ['tick:30', 'qso']), isFalse);
  });
}

/// Serves one catalog of extension panels, in the shape the service parses.
class _StubSource implements PanelExtensionSource {
  _StubSource(this.panels);

  final List<PanelDefinition> panels;

  @override
  final runtimeGeneration = ValueNotifier(0);

  @override
  Future<List<Map<String, dynamic>>?> getExtensionPanels() async => [
    for (final panel in panels)
      {
        'hookKey': panel.hookKey,
        'key': panel.panelKey,
        'title': panel.title,
        'on': panel.triggers,
        // A form field, so `forgetInstanceConfig` has something to forget —
        // it returns early for a panel with no config at all.
        'form': [
          {'key': 'content', 'type': 'field', 'fieldType': 'multiline'},
        ],
        'multiple': true,
      },
  ];

  @override
  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  }) async => null;

  @override
  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async => const {};

  @override
  Future<void> forgetPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  }) async {}
}
