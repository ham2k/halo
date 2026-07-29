// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration section: that it's gated on the GATO
// experiment, that it sits between Callsign and Common Preferences, and
// that it lists configured equipment with its live status.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> pumpSettings(WidgetTester tester, {required bool gatoEnabled, Object? equipment}) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      if (gatoEnabled)
        'experiments': jsonEncode({
          'gato': {'enabled': true},
        }),
      if (equipment != null) 'stationEquipment': jsonEncode(equipment),
    });
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets('the section is hidden until the GATO experiment is on', (tester) async {
    await pumpSettings(tester, gatoEnabled: false);
    expect(find.text('Station Configuration'), findsNothing);
  });

  testWidgets('with GATO on, the section sits between Callsign and Common Preferences', (tester) async {
    await pumpSettings(tester, gatoEnabled: true);

    expect(find.text('Station Configuration'), findsOneWidget);
    // The same glyph the logging panel's Radio control uses.
    expect(find.byIcon(MdiIcons.radio), findsWidgets);

    // Order comes from the entry's `order`, so assert on where the rows
    // actually land. Scoped to the sidebar — it's the first ListView in the
    // tree (the split's primary pane); "Callsign" also appears as a field
    // label in the Common Preferences panel showing alongside it.
    final sidebar = find.byType(ListView).first;
    double rowY(String label) =>
        tester.getTopLeft(find.descendant(of: sidebar, matching: find.text(label))).dy;

    expect(rowY('Station Configuration'), greaterThan(rowY('Callsign')));
    expect(rowY('Station Configuration'), lessThan(rowY('Common Preferences')));
  });

  testWidgets('the panel starts empty and offers to add equipment', (tester) async {
    await pumpSettings(tester, gatoEnabled: true);

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsOneWidget);
    expect(find.text('Add equipment'), findsOneWidget);
  });

  testWidgets('configured equipment lists with its address and status', (tester) async {
    await pumpSettings(tester, gatoEnabled: true, equipment: {
      'version': 1,
      'nodes': {
        'radio-1': {
          'typeKey': 'flexradio-tcp',
          'name': 'Left Radio',
          'config': {'host': 'flex.local', 'port': 4992},
        },
      },
    });

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('Left Radio'), findsOneWidget);
    // Where it is, and that nothing is pretending to be connected on load.
    expect(find.textContaining('flex.local:4992'), findsOneWidget);
    expect(find.textContaining('Not connected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    // The sole transceiver is auto-designated radio1, so it wears the pill —
    // a one-radio shack never has to choose.
    expect(find.text('Main VFO'), findsOneWidget);
  });

  testWidgets('adding by hand goes through the type list into that type\'s own form', (tester) async {
    await pumpSettings(tester, gatoEnabled: true);
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add equipment'));
    // Not pumpAndSettle: while nothing has announced itself the dialog shows
    // a CircularProgressIndicator, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Discovery is still listening at this point; the manual list is what
    // makes a radio on another subnet — or behind a router that doesn't
    // forward broadcasts — configurable at all.
    expect(find.text('Add by address'), findsOneWidget);
    expect(find.text('FlexRadio (SmartSDR) — Network'), findsOneWidget);
    // The one driver here HAS been run against real hardware (a FLEX-6600),
    // so it carries no caveat. The caption exists so the ones that haven't
    // are not presented as equally trustworthy.
    expect(find.text('Not tested against this hardware'), findsNothing);

    await tester.tap(find.text('FlexRadio (SmartSDR) — Network'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The type's own configElements, plus the shared name field — nothing
    // in this file names them, so a new type contributes its settings
    // without touching the panel.
    expect(find.text('Address'), findsWidgets);
    expect(find.text('Port'), findsWidgets);
    expect(find.text('Name'), findsWidgets);
    // The pane's chrome comes from the app's translations, not the form
    // renderer's English fallbacks.
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('the Main VFO pill moves with the designation', (tester) async {
    final services = await pumpSettings(tester, gatoEnabled: true, equipment: {
      'version': 1,
      'radio1': 'radio-1',
      'nodes': {
        'radio-1': {
          'typeKey': 'flexradio-tcp',
          'name': 'Left Radio',
          'config': {'host': 'left.local', 'port': 4992},
        },
        'radio-2': {
          'typeKey': 'flexradio-tcp',
          'name': 'Right Radio',
          'config': {'host': 'right.local', 'port': 4992},
        },
      },
    });

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    // The pill rides in the subtitle, so it sits just below its own tile's
    // title and above the next tile's — which row it belongs to is the
    // claim, not how far down it is.
    double rowY(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(find.text('Main VFO'), findsOneWidget);
    expect(rowY('Main VFO'), greaterThan(rowY('Left Radio')));
    expect(rowY('Main VFO'), lessThan(rowY('Right Radio')), reason: 'on the designated row');

    // The choice is only offered on the row that isn't already driving the
    // panel, so the second tile's menu is the one that has it.
    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Use as Main VFO'), findsOneWidget);

    await tester.tap(find.text('Use as Main VFO'));
    await tester.pumpAndSettle();

    // The designation actually moved — not just the label rendering.
    expect(services.gato.radio1, 'radio-2');
    expect(find.text('Main VFO'), findsOneWidget);
    expect(rowY('Main VFO'), greaterThan(rowY('Right Radio')), reason: 'and so did the pill');
  });

  testWidgets('a node whose type no longer exists says so instead of vanishing', (tester) async {
    await pumpSettings(tester, gatoEnabled: true, equipment: {
      'version': 1,
      'nodes': {
        'orphan': {'typeKey': 'a-driver-we-removed', 'name': 'Old Rig'},
      },
    });

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('Old Rig'), findsOneWidget);
    expect(find.textContaining('a-driver-we-removed'), findsOneWidget);
    // No Connect button for something the app can't talk to.
    expect(find.text('Connect'), findsNothing);
  });
}
