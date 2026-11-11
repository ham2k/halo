// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An extension's reach into the layouts (docs/extensions/host.md §
// host.layouts), through the real Operation view: it switches what an open
// view draws and what the next one opens on, brings a tab to the front, and
// never touches a layout the operator is editing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/dock_host.dart';
import 'package:ham2k_logger/views/dock_layouts/view_layouts.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  Future<HaLoServices> servicesWith({bool experiment = true}) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices();
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await settings.setExperimentEnabled('layouts', experiment);
    // Info behind the log in one tab group: a pane an extension can only
    // bring up by bringing it to the front.
    await settings.setLayoutData(
      LayoutKeys.operationDock,
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging', 'info']),
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

  Set<String> inFront(DockHost host) => DockState.of(host.dockKey.currentState!.spec).selected;

  testWidgets('the list says which views are open, what they draw and what they hold', (tester) async {
    final services = await servicesWith();
    await pumpOperation(tester, services);
    final views = {for (final view in DockLayoutControl(services).list(null)) view['view']: view};

    expect(views['operation'], {
      'view': 'operation',
      'active': 'default',
      'layouts': [
        {'id': 'default', 'name': 'Default'},
      ],
      'open': true,
      'editing': false,
      'panels': ['logging', 'info', 'spots'],
    });
    expect(views['logs']!['open'], isFalse);
    expect(views['logs']!.containsKey('panels'), isFalse, reason: 'a view not open has no arrangement on screen to name');
    await unmount(tester);
  });

  testWidgets('a switch redraws the open view and is named once', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    await host.createLayout('Contest');
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    final control = DockLayoutControl(services);

    expect(control.switchTo('operation', '2'), (reason: null, name: 'Contest'));
    await tester.pumpAndSettle();
    expect(host.viewLayouts.active, '2');
    expect(ViewLayouts.read(services.settings, 'operation').active, '2', reason: 'the next Operation view opens on it too');

    // Nothing changed, so nothing for the status bar to name.
    expect(control.switchTo('operation', '2'), (reason: null, name: null));
    expect(control.switchTo('operation', '7'), (reason: 'invalid', name: null));
    expect(control.switchTo('mystery', '1'), (reason: 'invalid', name: null));
    await unmount(tester);
  });

  testWidgets('a view not open opens on the layout switched to', (tester) async {
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    await host.createLayout('Contest');
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    await unmount(tester);

    expect(DockLayoutControl(services).switchTo('operation', '2'), (reason: null, name: 'Contest'));
    await tester.pump();
    final reopened = await pumpOperation(tester, services);
    expect(reopened.viewLayouts.active, '2');
    await unmount(tester);
  });

  testWidgets('nothing changes under a layout being edited', (tester) async {
    // The draft belongs to the layout it began in: a switch would hand the
    // operator's Save to another one, and a tab moved mid-drag is a drop in
    // the wrong place.
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    await host.createLayout('Contest');
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    host.startLayoutEditing();
    await tester.pumpAndSettle();
    final control = DockLayoutControl(services);

    expect(control.switchTo('operation', '2'), (reason: 'editing', name: null));
    expect(control.focus('operation', 'info'), 'editing');
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    expect(inFront(host), isNot(contains('info')));
    expect(control.list(null).firstWhere((view) => view['view'] == 'operation')['editing'], isTrue);
    host.revertLayout();
    await unmount(tester);
  });

  testWidgets('a focus right after a switch finds the panel in the layout switched to', (tester) async {
    // The new layout has no tree until the next frame builds it; a call in
    // between would otherwise answer `missing` for a panel it holds.
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    await host.createLayout('Contest');
    await tester.pumpAndSettle();
    host.switchLayout(ViewLayouts.defaultId);
    await tester.pumpAndSettle();
    final control = DockLayoutControl(services);

    expect(control.switchTo('operation', '2'), (reason: null, name: 'Contest'));
    expect(control.list(null).firstWhere((view) => view['view'] == 'operation')['panels'], isNotEmpty);
    final contestPanels = host.dockSpec!.collectModules();
    expect(control.focus('operation', contestPanels.last), isNull);
    await tester.pumpAndSettle();
    expect(inFront(host), contains(contestPanels.last));
    await unmount(tester);
  });

  testWidgets('a list that lost its names is not written back from a closed view', (tester) async {
    // The next view opened tells the operator the names were lost; a switch
    // writing the rebuilt list back would make it read as whole, and they
    // would never hear of it.
    final services = await servicesWith();
    final host = await pumpOperation(tester, services);
    await host.createLayout('Contest');
    await tester.pumpAndSettle();
    await unmount(tester);
    await services.settings.setLayoutData(
      ViewLayouts.layoutKey(LayoutKeys.operationDock, '2'),
      DockSplit(
        Axis.horizontal,
        [
          DockGroup(['logging']),
          DockGroup(['spots']),
        ],
        [1, 1],
      ).toJson(),
    );
    await services.settings.setLayoutData(ViewLayouts.storageKey('operation'), {'unreadable': true});
    expect(ViewLayouts.read(services.settings, 'operation').recovered, isTrue);

    expect(DockLayoutControl(services).switchTo('operation', '2'), (reason: 'unavailable', name: null));
    expect(ViewLayouts.read(services.settings, 'operation').recovered, isTrue);
  });

  testWidgets('without named layouts on offer, no switch: the operator could not switch back', (tester) async {
    final services = await servicesWith(experiment: false);
    final host = await pumpOperation(tester, services);
    expect(DockLayoutControl(services).switchTo('operation', ViewLayouts.defaultId), (reason: 'unavailable', name: null));
    expect(host.viewLayouts.active, ViewLayouts.defaultId);
    await unmount(tester);
  });

  testWidgets('focus brings a tab to the front, and only one the arrangement holds', (tester) async {
    final services = await servicesWith(experiment: false);
    final host = await pumpOperation(tester, services);
    final control = DockLayoutControl(services);
    expect(inFront(host), isNot(contains('info')));

    expect(control.focus('operation', 'info'), isNull);
    await tester.pumpAndSettle();
    expect(inFront(host), contains('info'));

    expect(control.focus('operation', 'map'), 'missing');
    expect(control.focus('logs', 'info'), 'missing', reason: 'no Logs view is open to hold it');
    await unmount(tester);
  });
}
