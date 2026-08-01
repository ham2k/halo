// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration section: that it's gated on the CAT
// experiment, that it sits between Callsign and Common Preferences, and
// that it lists configured equipment with its live status.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> pumpSettings(WidgetTester tester,
      {required bool catEnabled, Object? equipment, FlutterSecureStorage? secureStorage}) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      if (catEnabled)
        'experiments': jsonEncode({
          'gato': {'enabled': true},
        }),
      if (equipment != null) 'stationEquipment': jsonEncode(equipment),
    });
    final settings = SettingsService(await SharedPreferences.getInstance(), secureStorage: secureStorage);
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final extensions = ExtensionServiceWithMockHost(const MockExtensionHost({}))..settings = settings;
    final services = HaLoServices(db, settings, extensions: extensions);

    await tester.pumpWidget(TranslationProvider(child: MaterialApp(home: SettingsView(services: services))));
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets('the section is hidden until the CAT experiment is on', (tester) async {
    await pumpSettings(tester, catEnabled: false);
    expect(find.text('Station Configuration'), findsNothing);
  });

  testWidgets('with CAT on, the section sits between Callsign and Common Preferences', (tester) async {
    await pumpSettings(tester, catEnabled: true);

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
    await pumpSettings(tester, catEnabled: true);

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsOneWidget);
    expect(find.text('Add equipment'), findsOneWidget);
  });

  testWidgets('configured equipment lists with its address and status', (tester) async {
    await pumpSettings(tester, catEnabled: true, equipment: {
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

    // Twice, and both are meant: once as the chosen Main VFO in Current
    // Configuration, once as its own row in Equipment Inventory.
    expect(find.text('Left Radio'), findsNWidgets(2));
    // Where it is, and that nothing is pretending to be connected on load.
    expect(find.textContaining('flex.local:4992'), findsOneWidget);
    // No status word at all now — state and control are one icon: an unplugged plug, which connects when
    // pressed. No localized word, so nothing here can grow and squeeze the
    // live frequency out of the row.
    expect(find.byIcon(MdiIcons.powerPlugOff), findsOneWidget);
    expect(find.byIcon(MdiIcons.powerPlug), findsNothing);
    // The sole transceiver is auto-designated radio1, so it wears the pill —
    // a one-radio shack never has to choose.
    expect(find.text('Main VFO'), findsOneWidget);
  });

  testWidgets('adding by hand goes through the type list into that type\'s own form', (tester) async {
    await pumpSettings(tester, catEnabled: true);
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
    expect(find.text('Yaesu FT-891 — USB serial'), findsOneWidget);
    // The caveat marks the DISTINCTION, and it is now down to one. The Flex
    // (a FLEX-6600), the FT-891 over its own USB bridge, and — as of
    // 2026-08-01 — the IC-705 over WiFi have all met their hardware, the last
    // held for ten minutes through the app itself rather than a bench tool.
    //
    // What still carries it is Icom CI-V over USB SERIAL: same driver, but
    // that pairing has never been pointed at a radio. The flag lives on the
    // TYPE for exactly this reason — marking the driver verified would have
    // dropped the caveat from a combination nobody has tested.
    expect(find.text('Not tested against this hardware'), findsOneWidget);

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

  testWidgets('a stored password shows as a hint in the editor, never as a value', (tester) async {
    // This covers the gap a service-level test cannot: that station_panel puts
    // the bullets under the 'placeholder' key and not 'value'. With 'value',
    // FormRenderer seeds them into the field, an untouched Save writes eight
    // bullets over the real keychain password, the radio stops connecting, and
    // the show/hide eye "reveals" them. Every service test still passes,
    // because none of them goes through this widget.
    final services = await pumpSettings(
      tester,
      catEnabled: true,
      secureStorage: FakeSecureStorage(),
      equipment: {
        'version': 1,
        'nodes': {
          'radio-1': {
            'typeKey': 'ic705-network',
            'name': 'The 705',
            'config': {'host': '10.0.0.9', 'username': 'op'},
          },
        },
      },
    );
    // Seeded after the pump, the way it really arrives: the config blob never
    // carries the password, so the panel has to ask the keychain.
    await services.settings.setEquipmentSecret('radio-1', 'password', 'hunter2');

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    // The row, not the Main VFO dropdown above it — the name appears in both.
    await tester.tap(find.text('The 705').last);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.widgetWithText(TextField, 'Radio password'));

    // Visible, so a saved password does not look like no password at all.
    expect(field.decoration?.hintText, '••••••••');
    // And a HINT: the field is genuinely empty, which is what CatService
    // reads as "keep what is stored".
    expect(field.controller?.text, isEmpty);
    // The real secret never entered the form.
    expect(field.controller?.text, isNot(contains('hunter2')));
  });

  testWidgets('the Main VFO transceiver is chosen from a dropdown of every known radio', (tester) async {
    // Configuration, not link state: the dropdown offers every transceiver
    // the station knows about, whether or not it happens to be connected.
    final services = await pumpSettings(tester, catEnabled: true, equipment: {
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

    expect(find.text('Current Configuration'), findsOneWidget);
    expect(find.text('Equipment Inventory'), findsOneWidget);
    expect(find.text('Transceiver for Main VFO'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    // Neither radio is connected, and both are offered anyway.
    expect(find.text('Right Radio'), findsWidgets);

    await tester.tap(find.text('Right Radio').last);
    await tester.pumpAndSettle();
    expect(services.cat.radio1, 'radio-2');
  });

  testWidgets('a node whose type no longer exists says so instead of vanishing', (tester) async {
    await pumpSettings(tester, catEnabled: true, equipment: {
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
