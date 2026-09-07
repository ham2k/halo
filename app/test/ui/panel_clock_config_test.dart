// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One clock pane's settings belong to the PLACEMENT, not to the panel.
//
// The whole reason an operator wants two of these is to see two zones at
// once, so a config keyed by the descriptor would collapse the feature into
// one clock drawn twice — and would do it silently, since both panes would
// still render perfectly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/services/panel_service.dart';
import 'package:ham2k_logger/views/operation/clock/clock_faces.dart';
import 'package:ham2k_logger/views/operation/clock/clock_panel.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import '../support/fake_panel_extensions.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  const fields = [
    {'type': 'field', 'key': clockFaceKey, 'fieldType': 'select'},
    {'type': 'field', 'key': clockZoneKey, 'fieldType': 'select'},
    {'type': 'field', 'key': clockShowSecondsKey, 'fieldType': 'checkbox'},
  ];

  PanelService serviceWith(FakePanelExtensions extensions) {
    final service = PanelService(extensions);
    service.registerNative(const PanelDefinition(
      id: 'clock',
      title: 'Clock',
      source: PanelSource.native,
      multiple: true,
      formFields: fields,
    ));
    return service;
  }

  group('config is per placement', () {
    test('two panes of one panel read their own values', () async {
      final extensions = FakePanelExtensions(configs: {
        'clock#1': {clockZoneKey: 'UTC'},
        'clock#2': {clockZoneKey: 'Asia/Tokyo'},
      });
      final service = serviceWith(extensions);

      // `configFor` is handed the panel the catalog resolved, and reads
      // `panel.id`. An instance carries the INSTANCE id — swapping that for
      // the descriptor's here is what would make both panes show one zone.
      expect((await service.configFor(service['clock#1']!))[clockZoneKey], 'UTC');
      expect((await service.configFor(service['clock#2']!))[clockZoneKey], 'Asia/Tokyo');
    });

    test('removing a placement forgets what it held; removing the panel does not', () async {
      final extensions = FakePanelExtensions(configs: {
        'clock#1': {clockZoneKey: 'Asia/Tokyo'},
      });
      final service = serviceWith(extensions);

      // An instance id is an anonymous slot — `nextInstanceId` hands the
      // lowest free number to the next placement, so a zone left behind
      // reappears inside whatever pane is added next.
      await service.forgetInstanceConfig('clock#1');
      expect(extensions.forgotten, ['clock#1']);

      // The descriptor is the opposite case: a panel placed once and taken
      // out is expected to come back set up the way it was.
      await service.forgetInstanceConfig('clock');
      expect(extensions.forgotten, ['clock#1']);
    });
  });

  group('the pane reads its own placement', () {
    Future<void> pump(WidgetTester tester, PanelService service, String panelId) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ClockPanel(panelId: panelId, panels: service),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    Object? painterOf(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .firstWhere((p) => p is LcdFacePainter || p is AnalogFacePainter, orElse: () => null);

    testWidgets('each placement wears its own face', (tester) async {
      final extensions = FakePanelExtensions(configs: {
        'clock#1': {clockFaceKey: clockFaceAnalog},
        'clock#2': {clockFaceKey: clockFaceLcd},
      });
      final service = serviceWith(extensions);

      // clock#1 first, and against the NON-default face: a lookup that
      // silently defaulted every placement (returning an empty config
      // instead of throwing) would read as LCD here, not analog — so this
      // assertion alone rules that class of bug out before clock#2's
      // default-coincident value could mask it.
      await pump(tester, service, 'clock#1');
      expect(painterOf(tester), isA<AnalogFacePainter>());

      await pump(tester, service, 'clock#2');
      expect(painterOf(tester), isA<LcdFacePainter>());

      // Back to clock#1, to catch the other direction: a lookup that
      // cross-contaminated placements would now show clock#2's stored LCD
      // instead of clock#1's own analog.
      await pump(tester, service, 'clock#1');
      expect(painterOf(tester), isA<AnalogFacePainter>());
    });

    testWidgets('a stored face the build no longer has falls back to analog rather than throwing', (tester) async {
      // A layout outlives the release that named its face — `swiss` is
      // exactly that, dropped after the SBB face's removal. A pane that threw
      // here would take the whole Operation View with it.
      final service = serviceWith(FakePanelExtensions(configs: {
        'clock#1': {clockFaceKey: 'swiss'},
      }));
      await pump(tester, service, 'clock#1');
      expect(painterOf(tester), isA<AnalogFacePainter>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('a placement with nothing stored is a UTC LCD clock', (tester) async {
      final service = serviceWith(FakePanelExtensions(configs: const {}));
      await pump(tester, service, 'clock#1');
      expect(painterOf(tester), isA<LcdFacePainter>());
      // Seconds default ON: the pane exists to be read at a glance while
      // logging, and a clock without seconds cannot time a contest exchange.
      final lcd = painterOf(tester)! as LcdFacePainter;
      expect(lcd.digits, hasLength(6));
    });

    testWidgets('the tab is named after the zone, so two clocks are told apart', (tester) async {
      // Without this both tabs read "Clock" and the operator has to open each
      // one's settings to find out which is which.
      final titles = <String?>[];
      final service = serviceWith(FakePanelExtensions(configs: {
        'clock#1': {clockZoneKey: 'America/New_York'},
      }));
      // TranslationProvider because naming the tab reads the localized label
      // for the device zone — the only string this pane needs.
      await tester.pumpWidget(TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: ClockPanel(
              panelId: 'clock#1',
              panels: service,
              onTitle: titles.add,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(titles, ['New York']);
    });
  });
}
