// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map pane's settings are the placement's own (map_pane_config.dart). The
// traps: a write that lands on another pane's config, or on an app-wide
// preference every pane reads; a pane that goes on showing what it read
// before its settings changed; and a pane with nothing stored that drops the
// basemap the operator had picked when the panes still shared one.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show FormRenderer;
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/map/map_pane_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_panel_extensions.dart';

PanelDefinition _map(String id, {Map<String, dynamic> initialConfig = const {}}) =>
    PanelDefinition(id: id, title: 'Map', source: PanelSource.native, formFields: mapPaneFields, initialConfig: initialConfig);

void main() {
  late FakePanelExtensions extensions;
  late PanelService panels;
  setUp(() {
    extensions = FakePanelExtensions(configs: {});
    panels = PanelService(extensions)
      ..registerNative(_map('map'))
      ..registerNative(_map('chaseMap'));
  });

  /// What each pane's [MapPaneConfig] last built with.
  final shown = <String, MapPaneOptions>{};
  Widget pane(String id) => MapPaneConfig(
    panels: panels,
    panelId: id,
    builder: (context, options) {
      shown[id] = options;
      return const SizedBox();
    },
  );

  testWidgets("a framing picked in one pane's settings frames that pane alone", (tester) async {
    shown.clear();
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                pane('map'),
                pane('chaseMap'),
                Expanded(
                  child: MapPaneSettings(panelId: 'map', panels: panels),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(shown['map']!.framing, MapFraming.allQsos);
    expect(find.text('Frame to show all QSOs'), findsOneWidget, reason: 'the row says what is picked');

    final form = tester.state(find.byType(FormRenderer));
    await tester.tap(find.text('Map Framing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frame the whole world'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(FormRenderer)), same(form), reason: 'an edit keeps the form, and its focus and scroll, rather than drawing a new one');

    expect(extensions.configs['map'], {mapPaneFramingKey: 'world'});
    expect(extensions.configs['chaseMap'], anyOf(isNull, isNot(contains(mapPaneFramingKey))));
    expect(shown['map']!.framing, MapFraming.world, reason: 'the pane re-reads its settings once they are written');
    expect(shown['chaseMap']!.framing, MapFraming.allQsos);
    expect(find.text('Frame the whole world'), findsOneWidget);
  });

  // A blank pane where the map was is the failure nobody can report.
  testWidgets('settings that cannot be read leave a map on the defaults, and the failure is not swallowed', (tester) async {
    shown.clear();
    panels = PanelService(_UnreadableConfig())..registerNative(_map('map'));
    final escaped = <Object>[];
    await runZonedGuarded(() async {
      await tester.pumpWidget(pane('map'));
      await tester.pumpAndSettle();
    }, (error, _) => escaped.add(error));
    expect(shown['map']?.framing, MapFraming.allQsos);
    expect(escaped, [isA<StateError>()], reason: 'what ErrorPolicy is handed');
  });

  testWidgets('settings that cannot be read are offered from the defaults, not as an empty sheet', (tester) async {
    panels = PanelService(_UnreadableConfig())..registerNative(_map('map'));
    final escaped = <Object>[];
    await runZonedGuarded(() async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: MapPaneSettings(panelId: 'map', panels: panels),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, (error, _) => escaped.add(error));
    expect(find.text('Map Framing'), findsOneWidget);
    expect(find.text('Frame to show all QSOs'), findsOneWidget);
    expect(escaped, [isA<StateError>()], reason: 'what ErrorPolicy is handed');
  });

  // Two settings changed in quick succession start two loads, and storage
  // can answer them out of order: the first, read before the second change
  // landed, must not put back what the operator just changed.
  testWidgets('a load that finishes after a later one does not undo it', (tester) async {
    shown.clear();
    final gated = _GatedConfig();
    panels = PanelService(gated)..registerNative(_map('map'));
    await tester.pumpWidget(pane('map'));
    gated.answer(0, const {});
    await tester.pump();

    panels.markConfigChanged('map');
    await tester.pump();
    panels.markConfigChanged('map');
    await tester.pump();
    gated.answer(2, {mapPaneFramingKey: 'world'});
    await tester.pump();
    gated.answer(1, {mapPaneFramingKey: 'country'});
    await tester.pump();
    expect(shown['map']!.framing, MapFraming.world);
  });

  test('a pane with nothing stored starts from the app-wide map choices, and keeps them as its own', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    await settings.setMapStyle(MapStyle.darkMatter);
    await settings.setSettingValue(SettingsService.generalGroup, 'mapShowCallsigns', true);
    final initial = mapPaneInitialConfig(settings);
    panels.registerNative(_map('logsMap', initialConfig: initial));

    final first = MapPaneOptions.fromConfig(await panels.configFor(panels['logsMap']!));
    expect(first.style, MapStyle.darkMatter);
    expect(first.callsigns, isTrue);
    expect(first.grayline, isFalse);
    expect(first.movement, MapMovement.zoomLine);
    expect(first.framing, MapFraming.allQsos);

    // The Maps view's style moves on, and the registration with it; the pane
    // keeps the basemap it started with.
    await settings.setMapStyle(MapStyle.liberty);
    panels.registerNative(_map('logsMap', initialConfig: mapPaneInitialConfig(settings)));
    expect(MapPaneOptions.fromConfig(await panels.configFor(panels['logsMap']!)).style, MapStyle.darkMatter);
  });

  test('a stored value this build no longer offers reads as the default', () {
    final options = MapPaneOptions.fromConfig({mapPaneStyleKey: 'retiredStyle', mapPaneMovementKey: 'retired', mapPaneFramingKey: 'retired'});
    expect(options.style, MapStyle.automatic);
    expect(options.movement, MapMovement.zoomLine);
    expect(options.framing, MapFraming.allQsos);
  });
}

class _UnreadableConfig extends FakePanelExtensions {
  _UnreadableConfig() : super(configs: {});

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) async =>
      throw StateError('storage unavailable');
}

/// Storage whose reads wait until the test answers them, by order asked.
class _GatedConfig extends FakePanelExtensions {
  _GatedConfig() : super(configs: {});

  final _reads = <Completer<Map<String, dynamic>>>[];

  void answer(int read, Map<String, dynamic> config) => _reads[read].complete(config);

  @override
  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields}) {
    final read = Completer<Map<String, dynamic>>();
    _reads.add(read);
    return read.future;
  }
}
