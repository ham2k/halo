// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's layouts as documents (docs/extensions/host.md §
// host.layouts), through the real Operation view: it reads any layout, and
// writes only the ones it made, straight to storage — never into an edit the
// operator has open, and never over a layout that has become theirs.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/dock_host.dart';
import 'package:ham2k_logger/views/dock_layouts/layout_file.dart';
import 'package:ham2k_logger/views/dock_layouts/view_layouts.dart';
import 'package:ham2k_logger/views/logs_view.dart';
import 'package:ham2k_logger/views/operation/clock/clock_panel.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// A document placing the log beside a clock set to [zone].
Map<String, dynamic> _withClock(String zone) => {
  'ham2k-layout': 1,
  'name': 'Sprint',
  'wide': {
    'root': {
      'split': 'horizontal',
      'weights': [2, 1],
      'children': [
        {
          'tabs': [
            {'panel': 'logging'},
          ],
        },
        {
          'tabs': [
            {
              'panel': clockPanelId,
              'instance': true,
              'settings': {clockZoneKey: zone},
            },
          ],
        },
      ],
    },
  },
};

void main() {
  Future<HaLoServices> servicesWith({bool experiment = true}) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setExperimentEnabled('layouts', experiment);
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['spots']),
        ],
        [2, 1],
      ).toJson(),
    );
    return services;
  }

  Future<DockHost> pumpOperation(WidgetTester tester, HaLoServices services) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(OperationView)) as DockHost;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<String?> zoneOf(HaLoServices services, String id) async {
    final panel = services.panels[id];
    if (panel == null) return null;
    return (await services.panels.configFor(panel))[clockZoneKey] as String?;
  }

  testWidgets('a new layout joins the list as the extension\'s, and is not drawn until switched to', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);

    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    await tester.pumpAndSettle();
    expect(made.reason, isNull);
    expect(made.name, 'Sprint');
    expect(host.viewLayouts.active, ViewLayouts.defaultId, reason: 'the operator is left looking at what they were');
    expect(host.viewLayouts[made.id!]!.madeBy, 'coach');
    final listed = control.list('coach').firstWhere((view) => view['view'] == 'operation')['layouts'] as List;
    expect(listed.firstWhere((layout) => layout['id'] == made.id)['mine'], isTrue);
    expect(listed.firstWhere((layout) => layout['id'] == ViewLayouts.defaultId).containsKey('mine'), isFalse);

    control.switchTo('operation', made.id!);
    await tester.pumpAndSettle();
    final clock = host.dockSpec!.collectModules().firstWhere((id) => id.startsWith(clockPanelId));
    expect(await zoneOf(services, clock), 'Asia/Tokyo', reason: 'an instance\'s settings are written before it is drawn');
    await unmount(tester);
  });

  testWidgets('get reads a layout back as the document it was written from', (tester) async {
    final services = await servicesWith();
    await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    await tester.pumpAndSettle();

    final (:reason, :document) = await control.read('operation', made.id);
    expect(reason, isNull);
    final file = LayoutFile.fromDocument(document);
    expect(file.name, 'Sprint');
    final tabs = file.arrangements[DockLayoutClass.wide]!.root.toJson().toString();
    expect(tabs, contains('Asia/Tokyo'));
    expect((await control.read('operation', '99')).reason, 'invalid');
    await unmount(tester);
    expect((await control.read('operation', null)).reason, 'closed');
  });

  testWidgets('replacing its own layout on screen redraws it, and forgets the instances it held', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    control.switchTo('operation', made.id!);
    await tester.pumpAndSettle();
    final before = host.dockSpec!.collectModules().firstWhere((id) => id.startsWith(clockPanelId));

    final replaced = await control.apply('operation', _withClock('Europe/Paris'), mode: 'replace', id: made.id, owner: 'coach');
    await tester.pumpAndSettle();
    expect(replaced.reason, isNull);
    final after = host.dockSpec!.collectModules().firstWhere((id) => id.startsWith(clockPanelId));
    expect(after, isNot(before), reason: 'a new instance, never one still holding the old one\'s settings');
    expect(await zoneOf(services, after), 'Europe/Paris');
    expect(await zoneOf(services, before), isNot('Asia/Tokyo'), reason: 'the replaced instance\'s settings would open in the next pane handed its id');
    expect(host.layoutEditing, isFalse, reason: 'never into an edit the operator would have to Save');
    await unmount(tester);
  });

  testWidgets('adding puts the document\'s panes in a new column at the right', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    control.switchTo('operation', made.id!);
    await tester.pumpAndSettle();

    final added = await control.apply(
      'operation',
      {
        'ham2k-layout': 1,
        'wide': {
          'root': {
            'tabs': [
              {'panel': 'map'},
            ],
          },
        },
      },
      mode: 'add',
      id: made.id,
      owner: 'coach',
    );
    await tester.pumpAndSettle();
    expect(added.reason, isNull);
    final root = host.dockSpec! as DockSplit;
    expect(root.children.last.collectModules(), ['map']);
    expect(host.dockSpec!.collectModules(), containsAll(['logging', 'map']));
    await unmount(tester);
  });

  testWidgets('the operator\'s layouts and another extension\'s are not the caller\'s to change', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final theirs = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'other');
    await tester.pumpAndSettle();

    for (final id in [ViewLayouts.defaultId, theirs.id!]) {
      expect(
        (await control.apply('operation', _withClock('Europe/Paris'), mode: 'replace', id: id, owner: 'coach')).reason,
        'notOwn',
        reason: id,
      );
      expect((await control.remove('operation', id, owner: 'coach')).reason, 'notOwn', reason: id);
    }
    expect(host.viewLayouts.layouts, hasLength(2));
    await unmount(tester);
  });

  testWidgets('a layout the operator saves an edit to, or renames, is theirs from then on', (tester) async {
    // Their work is never overwritten: an extension replacing a layout after
    // the operator rearranged it would throw that away.
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final saved = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    final renamed = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    control.switchTo('operation', saved.id!);
    await tester.pumpAndSettle();

    host.startLayoutEditing();
    await tester.pumpAndSettle();
    host.saveLayout();
    await tester.pumpAndSettle();
    await host.editLayout(renamed.id!, name: 'Mine now');
    await tester.pumpAndSettle();

    for (final id in [saved.id!, renamed.id!]) {
      expect(host.viewLayouts[id]!.madeBy, isNull, reason: id);
      expect(
        (await control.apply('operation', _withClock('Europe/Paris'), mode: 'replace', id: id, owner: 'coach')).reason,
        'notOwn',
        reason: id,
      );
    }
    await unmount(tester);
  });

  testWidgets('nothing is written while the operator edits, with no view open, or without named layouts', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    await tester.pumpAndSettle();

    host.startLayoutEditing();
    await tester.pumpAndSettle();
    expect((await control.apply('operation', _withClock('Europe/Paris'), mode: 'new', owner: 'coach')).reason, 'editing');
    expect((await control.remove('operation', made.id!, owner: 'coach')).reason, 'editing');
    expect((await control.read('operation', null)).reason, 'editing', reason: 'what is on screen is a draft the operator has not kept');
    host.revertLayout();
    await tester.pumpAndSettle();

    await services.settings.setExperimentEnabled('layouts', false);
    expect((await control.apply('operation', _withClock('Europe/Paris'), mode: 'new', owner: 'coach')).reason, 'unavailable');
    await services.settings.setExperimentEnabled('layouts', true);
    await unmount(tester);
    expect((await control.apply('operation', _withClock('Europe/Paris'), mode: 'new', owner: 'coach')).reason, 'closed');
  });

  testWidgets('a document that is not a layout, or places nothing here, writes nothing', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);

    final notOne = await control.apply('operation', {'name': 'x'}, mode: 'new', owner: 'coach');
    expect(notOne.reason, 'invalid');
    expect(notOne.message, isNotNull);
    final nothingHere = await control.apply(
      'operation',
      {
        'ham2k-layout': 1,
        'wide': {
          'root': {
            'tabs': [
              {'panel': 'logs-only-pane'},
            ],
          },
        },
      },
      mode: 'new',
      owner: 'coach',
    );
    expect(nothingHere.reason, 'empty');
    expect(nothingHere.skipped, ['logs-only-pane']);
    expect(host.viewLayouts.layouts, hasLength(1));
    await unmount(tester);
  });

  testWidgets('its own layout can be removed, and the view moves off it', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    control.switchTo('operation', made.id!);
    await tester.pumpAndSettle();

    expect(await control.remove('operation', made.id!, owner: 'coach'), (reason: null, name: 'Sprint'));
    await tester.pumpAndSettle();
    expect(host.viewLayouts[made.id!], isNull);
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    await unmount(tester);
  });

  testWidgets('an edit the operator opens while a layout is written keeps its draft', (tester) async {
    // A write waits on its panels' settings. Redrawing the layout once they
    // are in, under an edit begun meanwhile, would drop the snapshot Discard
    // goes back to, and a Save would keep the extension's arrangement.
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    final made = await control.apply('operation', _withClock('Asia/Tokyo'), mode: 'new', owner: 'coach');
    control.switchTo('operation', made.id!);
    await tester.pumpAndSettle();
    final drawn = host.dockSpec!.collectModules();

    final pending = control.apply('operation', _withClock('Europe/Paris'), mode: 'replace', id: made.id, owner: 'coach');
    host.startLayoutEditing();
    final replaced = await pending;
    await tester.pumpAndSettle();
    expect(replaced.reason, 'editing');
    expect(host.layoutEditing, isTrue);
    host.revertLayout();
    await tester.pumpAndSettle();
    expect(host.dockSpec!.collectModules(), drawn);
    expect(host.arrangementSpec(made.id!, DockLayoutClass.wide).collectModules(), drawn, reason: 'nothing reached storage');
    expect(await zoneOf(services, drawn.firstWhere((id) => id.startsWith(clockPanelId))), 'Asia/Tokyo');
    await unmount(tester);
  });

  testWidgets('a panel instance in an edit open in another view is not handed out again', (tester) async {
    // The edit's draft has not reached storage. An instance id taken from
    // stored layouts alone would be one the draft already holds, and the
    // extension's settings would overwrite the operator's in that pane.
    final services = await servicesWith();
    tester.view.physicalSize = const Size(2400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: OperationView(services: services, operationUuid: operation.uuid),
              ),
              Expanded(child: LogsView(services: services)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final operationHost = tester.state(find.byType(OperationView)) as DockHost;
    final logsHost = tester.state(find.byType(LogsView)) as DockHost;

    operationHost.startLayoutEditing();
    await operationHost.importLayout(
      operationHost.importTargets(LayoutFile.fromDocument(_withClock('Asia/Tokyo')), LayoutImportMode.add),
      mode: LayoutImportMode.add,
    );
    await tester.pumpAndSettle();
    final inDraft = operationHost.dockSpec!.collectModules().firstWhere((id) => id.startsWith(clockPanelId));

    final made = await DockLayoutControl(services).apply('logs', _withClock('Europe/Paris'), mode: 'new', owner: 'coach');
    await tester.pumpAndSettle();
    expect(made.reason, isNull);
    final written = logsHost.arrangementSpec(made.id!, DockLayoutClass.wide).collectModules().firstWhere((id) => id.startsWith(clockPanelId));
    expect(written, isNot(inDraft));
    expect(await zoneOf(services, inDraft), 'Asia/Tokyo');
    operationHost.revertLayout();
    await unmount(tester);
  });

  test('a document nested past a file\'s limit is refused, not followed', () {
    // The tree is built by recursion: one an extension nested ten thousand
    // deep would run it out of stack.
    Object? deep = {
      'tabs': [
        {'panel': 'logging'},
      ],
    };
    for (var i = 0; i < 10000; i++) {
      deep = {
        'split': 'horizontal',
        'children': [deep],
      };
    }
    expect(
      () => LayoutFile.fromDocument({
        'ham2k-layout': 1,
        'wide': {'root': deep},
      }),
      throwsA(isA<LayoutFileException>().having((e) => e.problem, 'problem', LayoutFileProblem.tooLarge)),
    );
  });
}
