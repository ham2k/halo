// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration section: that it's gated on the CAT
// experiment, that it sits between Callsign and Settings, and
// that it lists configured equipment with its live status.

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import 'fake_secure_storage.dart';
import 'operation_view_layout_test.dart' show MockExtensionHost, ExtensionServiceWithMockHost;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HaLoServices> pumpSettings(WidgetTester tester,
      {required bool catEnabled,
      Object? equipment,
      FlutterSecureStorage? secureStorage,
      // Short windows are how the Add dialog's list is made to overflow: the
      // catalogue is only a handful of radios, so at the default size it
      // never scrolls and the scroll-driven fold cannot be exercised at all.
      Size viewSize = const Size(1000, 1400)}) async {
    tester.view.physicalSize = viewSize;
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

  testWidgets('with CAT on, the section sits between Callsign and Settings', (tester) async {
    await pumpSettings(tester, catEnabled: true);

    expect(find.text('Station Configuration'), findsOneWidget);
    // The CAT pun, not the plain radio glyph.
    expect(find.byIcon(MdiIcons.cat), findsWidgets);

    // Order comes from the entry's `order`, so assert on where the rows
    // actually land. Scoped to the sidebar — it's the first ListView in the
    // tree (the split's primary pane); "Callsign" also appears as a field
    // label in the Settings panel showing alongside it.
    final sidebar = find.byType(ListView).first;
    double rowY(String label) =>
        tester.getTopLeft(find.descendant(of: sidebar, matching: find.text(label))).dy;

    expect(rowY('Station Configuration'), greaterThan(rowY('Callsign')));
    expect(rowY('Station Configuration'), lessThan(rowY('Settings')));
  });

  testWidgets('the panel starts empty and offers to add equipment', (tester) async {
    await pumpSettings(tester, catEnabled: true);

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsOneWidget);
    expect(find.text('Add equipment'), findsOneWidget);
  });

  testWidgets('the Current Configuration fields start where the list rows do', (tester) async {
    // On a wide pane the rows are centred to the ideal reading width by an
    // inset that rides the ambient ListTileTheme. A hand-built row that names
    // a spacing rung instead spans the whole pane, and the fields sit a
    // couple of hundred pixels left of every row around them.
    await pumpSettings(tester, catEnabled: true, viewSize: const Size(1600, 1200));
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.widgetWithText(DropdownButtonFormField<String?>, 'Transceiver for Main VFO'));
    // The leading glyph of a plain row in the same list — where a row's
    // contents actually start, inset and centring included.
    final row = tester.getRect(find.widgetWithText(ListTile, 'Add equipment'));
    final rowContentLeft = tester
        .getRect(find.descendant(
          of: find.widgetWithText(ListTile, 'Add equipment'),
          matching: find.byType(Icon),
        ))
        .left;

    expect(field.left, rowContentLeft);
    // And that both of them are where a WIDE pane puts them. Comparing the
    // field to a sibling row alone would stay green with the panel's centring
    // gone altogether — the row moves with it.
    expect(field.left - row.left, greaterThan(settingsRowInset + settingsRowCentering(row.width) / 2));
  });

  testWidgets('configured equipment lists with its address and status', (tester) async {
    await pumpSettings(tester, catEnabled: true, equipment: {
      'version': 1,
      // radio1 is spelled out because it is now plain stored state — the panel
      // shows exactly what was saved and nothing designates a radio on load
      // (HALO-50). A real blob always carries this key once a transceiver
      // exists, since adding one writes it; a fixture without it describes a
      // configuration the app never produces.
      'radio1': 'radio-1',
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

    // The whole list IS the manual path now, so it carries no heading of its
    // own — a radio on another subnet, or behind a router that doesn't
    // forward broadcasts, is reached from the same list as everything else.
    expect(find.text('Add by address'), findsNothing);
    // The RADIO is what the operator picks, named as it is on its own front
    // panel — how it is connected is the next question, not part of this one.
    // Sampled from the top of the sorted list, because the list is lazy: a
    // name further down is absent because it was never built, not because
    // the catalogue lost it.
    expect(find.text('FlexRadio (SmartSDR)'), findsOneWidget);
    expect(find.text('Icom IC-705'), findsOneWidget);
    expect(find.text('Icom IC-7300'), findsOneWidget);

    // The section names itself and stays named: discovery runs for as long
    // as this dialog is open, so a heading that flipped between "searching"
    // and "found" would be naming one unfinished activity twice — the
    // spinner beside it is what says the search is still going.
    expect(find.text('Detected Equipment'), findsOneWidget);

    // Every pairing in the catalogue has now met a radio, so nothing carries
    // the caveat — neither the whole-model one nor the per-transport marker
    // the IC-705 used to show while its USB side was untried. A definition
    // added for a driver or transport nobody has pointed at a rig brings both
    // back, which is what these two assertions are watching for.
    expect(find.text('Not tested against this hardware'), findsNothing);
    expect(find.textContaining('(untested)'), findsNothing);

    await tester.tap(find.text('FlexRadio (SmartSDR)'));
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

  /// What the fold actually hides: the found-devices body under the permanent
  /// title. The title and its spinner never fold, so they cannot stand in for
  /// the section's state.
  final discoveryBody = find.descendant(
    of: find.byType(AnimatedSize),
    matching: find.byType(SingleChildScrollView),
  );

  /// Opens Station Configuration and the Add dialog. Never pumpAndSettle:
  /// while nothing has announced itself the discovery section holds a
  /// CircularProgressIndicator, which never settles.
  Future<void> openAddDialog(WidgetTester tester) async {
    // Only navigate in if we are not already there: opening the dialog a
    // second time in one test starts from the panel, where the sidebar row
    // may not be hit-testable.
    if (find.text('Equipment Inventory').evaluate().isEmpty) {
      await tester.tap(find.text('Station Configuration'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add equipment').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the equipment list is alphabetical, not grouped by brand', (tester) async {
    // Sorted at BUILD time, from the names as the current locale renders
    // them. An order fixed where the catalogue is declared would be
    // alphabetical only in whichever language happened to be active first.
    //
    // Mutation check: drop the sort and this fails on the Icom pair, since
    // the catalogue declares the IC-705 before Icom - Generic.
    //
    // The sample stops where the lazy list does — a name below the fold is
    // never built, so its position says nothing either way.
    await pumpSettings(tester, catEnabled: true);
    await openAddDialog(tester);

    const expected = [
      'FlexRadio (SmartSDR)',
      'Generic Radio via flrig',
      'Generic Radio via rigctld',
      'Icom - Generic',
      'Icom IC-705',
      'Icom IC-706MKIIG',
      'Icom IC-7300',
      'Icom IC-7300 MK2',
    ];
    final tops = [
      for (final name in expected)
        tester.getTopLeft(find.descendant(of: find.byType(HaloDialog), matching: find.text(name))).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]),
          reason: '"${expected[i]}" should sit below "${expected[i - 1]}"');
    }
  });

  testWidgets('the search box filters by radio name and by how it plugs in', (tester) async {
    await pumpSettings(tester, catEnabled: true);
    await openAddDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'icom');
    await tester.pump();
    expect(find.text('Icom IC-705'), findsOneWidget);
    expect(find.text('Icom - Generic'), findsOneWidget);
    // The absent name has to be one the UNFILTERED list would have built:
    // the Yaesus sort last and are below the fold either way, so looking for
    // one of those passes whether the filter ran or not. FlexRadio sorts
    // first.
    expect(find.text('FlexRadio (SmartSDR)'), findsNothing);

    // Matching the transport too is the point: an operator with a cable in
    // their hand knows how the radio plugs in long before they know whether
    // its protocol is called CI-V.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'usb');
    await tester.pump();
    expect(find.text('Icom IC-705'), findsOneWidget, reason: 'it has a USB serial pairing');
    expect(find.text('Generic Radio via rigctld'), findsNothing, reason: 'network only');
    // The Yaesus sort below the fold, and a lazy list never builds what is
    // down there — findsNothing on one of them would pass whether the filter
    // worked or not, so they are scrolled to rather than merely looked for.
    await tester.scrollUntilVisible(find.text('Yaesu FT-891'), 200,
        scrollable: find.descendant(of: find.byType(HaloDialog), matching: find.byType(Scrollable)).last);
    expect(find.text('Yaesu FT-891'), findsOneWidget);
    expect(find.text('Yaesu - Generic'), findsOneWidget);

    // The brand is searchable even when the model's name doesn't carry it:
    // the X6100 is named for what is written on the radio, and an operator
    // hunting for "Xiegu" has to reach it. Drop the manufacturer from the
    // match and this finds nothing.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'xiegu');
    await tester.pump();
    expect(find.text('X6100'), findsOneWidget);
    expect(find.text('Icom - Generic'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'zzzz');
    await tester.pump();
    expect(find.text('No equipment matches'), findsOneWidget);
  });

  testWidgets('scrolling the equipment list folds the discovery section away', (tester) async {
    // A window short enough that the catalogue overflows — at full size the
    // list never scrolls and this behaviour is unreachable.
    await pumpSettings(tester, catEnabled: true, viewSize: const Size(1000, 620));
    await openAddDialog(tester);

    // The title and its spinner are permanent — discovery is still running,
    // and the fold is about the found-devices body below them.
    expect(find.text('Detected Equipment'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(discoveryBody, findsOneWidget);

    // The dialog's own list, not the settings sidebar behind it.
    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, -120));
    await tester.pump();

    expect(discoveryBody, findsNothing, reason: 'scrolling into the list gives its room to the list');
    // The title and its spinner stay: they are what tell the operator
    // discovery is still running, and losing them would read as it having
    // stopped.
    expect(find.text('Detected Equipment'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.drag(list, const Offset(0, 400));
    await tester.pump();
    expect(discoveryBody, findsOneWidget,
        reason: 'back at the top, what announced itself is worth the room again');
  });

  testWidgets('a transport glyph is pinned beside the radio\'s name, not centred down the row',
      (tester) async {
    // Material 3 centres a ListTile's trailing widget against the WHOLE tile
    // unless titleAlignment says otherwise, so on a two-line row the glyph
    // drops a full line below the name it belongs to. A shrink-wrapping
    // Column around the glyph does NOT fix this — only the alignment does.
    //
    // This asserts the property rather than measuring the geometry, and the
    // difference is worth stating: no catalogue row is two-line today, since
    // every pairing is hardware-verified and none carries a caveat under its
    // name. A measurement would therefore pass with the alignment deleted.
    // A discovered device's row (`detail` under its name) is two-line and
    // still needs this, and so does the next radio that ships untested.
    await pumpSettings(tester, catEnabled: true);
    await openAddDialog(tester);

    expect(
      tester.widget<ListTile>(find.widgetWithText(ListTile, 'Icom IC-705')).titleAlignment,
      ListTileTitleAlignment.top,
    );
  });

  testWidgets('the fold reopens when the list stops being scrollable under it', (tester) async {
    // The trap: a scroll position corrected during LAYOUT — the list shrinking
    // under a filter, or growing back when one is cleared — moves `pixels`
    // without dispatching any ScrollNotification. Watching only that
    // notification leaves the section folded shut over a list that no longer
    // scrolls, with no gesture anywhere that reopens it.
    //
    // Mutation check: drop the ScrollMetricsNotification listener and the
    // final expectation here fails.
    await pumpSettings(tester, catEnabled: true, viewSize: const Size(1000, 620));
    await openAddDialog(tester);

    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, -120));
    await tester.pump();
    expect(discoveryBody, findsNothing, reason: 'folded, as it should be');

    // Filter to nothing: the ListView unmounts entirely and takes its
    // Scrollable with it.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'zzzz');
    await tester.pump();
    expect(find.text('No equipment matches'), findsOneWidget);

    // Clearing it mounts a FRESH scrollable at offset 0. The operator is
    // looking at a full, unscrolled list — the section has to be back.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(discoveryBody, findsOneWidget,
        reason: 'the list is back at the top, so what announced itself is worth the room again');
  });

  testWidgets('a short window does not overflow the dialog', (tester) async {
    // With scrollable: false the search row and the discovery section are the
    // Column's inflexible children — an unbounded section pushes the whole
    // dialog past its height cap and paints overflow stripes. Any thrown
    // layout exception fails this test on its own.
    await pumpSettings(tester, catEnabled: true, viewSize: const Size(900, 420));
    await openAddDialog(tester);

    expect(find.text('Detected Equipment'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.text('Detected Equipment'), findsOneWidget);
  });

  testWidgets('a new radio is named after the model, numbered once that name is taken', (tester) async {
    await pumpSettings(tester, catEnabled: true, secureStorage: FakeSecureStorage());
    await openAddDialog(tester);

    await tester.tap(find.text('Generic Radio via rigctld'));
    await tester.pumpAndSettle();

    // Prefilled, and prefilled EDITABLY — the operator sees what it will be
    // called before agreeing to it.
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Name').first).controller?.text,
      'Generic Radio via rigctld',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    await openAddDialog(tester);
    // Scoped to the dialog: the name is now also on the equipment row and in
    // the Main VFO dropdown behind it.
    await tester.tap(find.descendant(
      of: find.byType(HaloDialog),
      matching: find.text('Generic Radio via rigctld'),
    ));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Name').first).controller?.text,
      'Generic Radio via rigctld 2',
      reason: 'the shack already has one, and two identical rows cannot be told apart',
    );
  });

  testWidgets('a radio with two ways in asks which, and only that one has to validate', (tester) async {
    // The trap this exists to catch: FormRenderer registers EVERY declared
    // field, visible or not, and `submit` runs the validator over all of them
    // (see its `_visibleElements` doc). The IC-705's serial pairing declares a
    // serial port and requires one — so a validator that asked the pairing the
    // node OPENED on, rather than the one the `transport` field currently
    // names, would refuse to save a perfectly good WiFi radio with "a serial
    // port is required" anchored on a field the operator cannot even see.
    //
    // Mutation check: point the validator at anything but `values['transport']`
    // and the Save below stops producing a node.
    final services = await pumpSettings(tester, catEnabled: true, secureStorage: FakeSecureStorage());

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add equipment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Icom IC-705'));
    await tester.pumpAndSettle();

    // Opened on the verified pairing, and the choice is a field in the form
    // rather than a fork before it.
    expect(find.text('Connection'), findsWidgets);
    expect(find.text('WiFi'), findsWidgets);
    // The network pairing's own fields are showing...
    expect(find.text("Radio username"), findsWidgets);
    // ...and the serial pairing's are not, though they are registered.
    expect(find.text('Serial port'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Address').first, '10.0.0.9');
    await tester.enterText(find.widgetWithText(TextField, 'Radio username').first, 'op');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final node = services.cat.nodes.single;
    expect(node.typeKey, 'ic705-network', reason: 'the pairing the transport field named');
    expect(node.config['host'], '10.0.0.9');
    // The discriminator chose a typeKey; it is not itself a setting any
    // transport or driver reads, so it must not be stored as one.
    expect(node.config.containsKey('transport'), isFalse);
  });

  testWidgets('switching transport swaps which pairing the form is describing', (tester) async {
    // Stops at the swap, deliberately: saving the serial pairing needs a
    // serial port to pick, and a test process has none (libserialport is not
    // loadable there, and the picker degrades to an empty list by design).
    // That the re-typed node then persists is cat_service_test's to prove.
    await pumpSettings(
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

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    // The row, not the Main VFO dropdown above it — the name appears in both.
    await tester.tap(find.text('The 705').last);
    await tester.pumpAndSettle();

    // The transport dropdown is found by its CURRENT value, not by position:
    // choosing serial adds a baud-rate dropdown of its own, so an index would
    // start aiming at that instead.
    await tester.tap(find.widgetWithText(DropdownButtonFormField<dynamic>, 'WiFi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB serial').last);
    await tester.pumpAndSettle();

    // The other pairing's fields took over, and its prefill came with it —
    // seeded up front from every variant's defaultConfig, so switching lands
    // on sensible values with nothing to plumb through onChange.
    expect(find.text('Serial port'), findsWidgets);
    expect(find.text("Radio username"), findsNothing);
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Radio CI-V address').first).controller?.text,
      'A4',
      reason: "the serial pairing's own prefill, seeded before the operator ever chose it",
    );

    // Switching back finds what was already there. FormRenderer keeps a
    // hidden field's value, which is exactly why nothing here has to thread
    // the old transport's settings anywhere.
    await tester.tap(find.widgetWithText(DropdownButtonFormField<dynamic>, 'USB serial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WiFi').last);
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Address').first).controller?.text,
      '10.0.0.9',
    );
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

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Transceiver for Main VFO'));
    await tester.pumpAndSettle();
    // Neither radio is connected, and both are offered anyway.
    expect(find.text('Right Radio'), findsWidgets);

    await tester.tap(find.text('Right Radio').last);
    await tester.pumpAndSettle();
    expect(services.cat.radio1, LocalRadio('radio-2'));
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
