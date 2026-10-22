// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Station Configuration section: that it's gated on the CAT
// experiment, that it sits between Application Preferences and Cloud Sync, and
// that it lists configured equipment with its live status.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/views/add_equipment_dialog.dart';
import 'package:ham2k_logger/views/settings_view.dart';

import '../support/fake_serial_ports.dart';
import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => useSerialPortsForTest(const []));

  Future<HaLoServices> pumpSettings(
    WidgetTester tester, {
    Object? equipment,
    FlutterSecureStorage? secureStorage,
    // Short windows are how the Add dialog's list is made to overflow: the
    // catalogue is only a handful of radios, so at the default size it
    // never scrolls and the scroll-driven fold cannot be exercised at all.
    Size viewSize = const Size(1000, 1400),
  }) async {
    tester.view.physicalSize = viewSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final HaLoHarness(:services) = await makeHaLoServices(
      prefs: {if (equipment != null) 'stationEquipment': jsonEncode(equipment)},
      secureStorage: secureStorage,
    );

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: SettingsView(services: services)),
      ),
    );
    await tester.pumpAndSettle();
    return services;
  }

  testWidgets('the section sits between Application Preferences and Cloud Sync', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Station Configuration'), findsOneWidget);
    // The CAT pun, not the plain radio glyph.
    expect(find.byIcon(MdiIcons.cat), findsWidgets);

    // Order comes from the entry's `order`, so assert on where the rows
    // actually land. Scoped to the sidebar — it's the first ListView in the
    // tree (the split's primary pane); "Callsign" also appears as a field
    // label in the Settings panel showing alongside it.
    final sidebar = find.byType(ListView).first;
    double rowY(String label) => tester.getTopLeft(find.descendant(of: sidebar, matching: find.text(label))).dy;

    expect(rowY('Station Configuration'), greaterThan(rowY('Application Preferences')));
    expect(rowY('Station Configuration'), lessThan(rowY('Cloud Sync')));
  });

  testWidgets('the panel starts empty and offers to add equipment', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
  });

  for (final radioName in ['Remote Rig', '']) {
    testWidgets('the inventory retains an absent peer with ${radioName.isEmpty ? 'an ID fallback' : 'its saved name'} until a local rig is selected', (
      tester,
    ) async {
      final services = await pumpSettings(
        tester,
        equipment: {
          'version': 3,
          'mainVfo': {'radio': 'local-rig'},
          'nodes': {
            'local-rig': {
              'typeKey': 'flexradio-tcp',
              'name': 'Local Rig',
              'config': {'host': 'flex.local', 'port': 4992},
            },
          },
        },
      );
      await services.cat.setRadio1(PeerRadio(PeerRadioSelection(deviceId: 'remote-device', radioId: 'remote-rig', radioName: radioName)));
      await tester.tap(find.text('Station Configuration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 transceiver'));
      await tester.pumpAndSettle();

      final label = radioName.isEmpty ? 'remote-rig' : radioName;
      // Both the current rig and its inventory row keep the saved selection
      // visible even when no peer offers it. The name falls back to its ID.
      expect(find.text(label), findsNWidgets(2));
      expect(find.text('Local Rig'), findsOneWidget);

      await services.cat.setRadio1(const LocalRadio('local-rig'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsNothing);
      expect(find.text('Local Rig'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Configuration fields start where the list rows do', (tester) async {
    // On a wide pane the rows are centred to the ideal reading width by an
    // inset that rides the ambient ListTileTheme. A hand-built row that names
    // a spacing rung instead spans the whole pane, and the fields sit a
    // couple of hundred pixels left of every row around them.
    await pumpSettings(
      tester,
      viewSize: const Size(1600, 1200),
      equipment: {
        'version': 1,
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'flexradio-tcp',
            'name': 'Left Radio',
            'config': {'host': 'flex.local', 'port': 4992},
          },
          'ant-1': {'typeKey': 'antenna-none', 'name': 'Dipole', 'config': <String, dynamic>{}},
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.widgetWithText(DropdownButtonFormField<String?>, 'Antenna in Use'));
    // The leading control of a ListTile in the same list — the current
    // transceiver's plug button — is where a row's contents actually start.
    final rowFinder = find.widgetWithText(ListTile, 'Left Radio');
    final row = tester.getRect(rowFinder.first);
    final rowContentLeft = tester.getRect(find.ancestor(of: find.byIcon(MdiIcons.powerPlugOff), matching: find.byType(IconButton))).left;

    expect(field.left, rowContentLeft);
    // And that both of them are where a WIDE pane puts them. Comparing the
    // field to a sibling row alone would stay green with the panel's centring
    // gone altogether — the row moves with it.
    expect(field.left - row.left, greaterThan(settingsRowInset + settingsRowCentering(row.width) / 2));
  });

  testWidgets('the current transceiver heads the panel with its address and state, and the inventory lists it again', (tester) async {
    await pumpSettings(
      tester,
      equipment: {
        'version': 1,
        // radio1 is spelled out because it is plain stored state — the panel
        // shows exactly what was saved and nothing designates a radio on load.
        // A real blob always carries this key once a transceiver exists.
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'flexradio-tcp',
            'name': 'Left Radio',
            'config': {'host': 'flex.local', 'port': 4992},
          },
        },
      },
    );

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    // Once, in the Current Transceiver band: the inventory's sections start
    // closed, so a panel opened to check the rig is not a list to scroll.
    expect(find.text('Left Radio'), findsOneWidget);
    expect(find.text('flex.local:4992'), findsOneWidget);
    // State and control are one icon: an unplugged plug, which connects when
    // pressed — and no status word to squeeze the reading out of the row.
    expect(find.byIcon(MdiIcons.powerPlugOff), findsOneWidget);
    expect(find.byIcon(MdiIcons.powerPlug), findsNothing);
    expect(find.text('Not connected'), findsOneWidget, reason: 'where the reading goes while there is none');

    // Opened, the inventory names it again, as the radio the main VFO follows.
    await tester.tap(find.text('1 transceiver'));
    await tester.pumpAndSettle();
    expect(find.text('Left Radio'), findsNWidgets(2));
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Main VFO'), findsOneWidget, reason: 'its icon says it is the one in use');
    semantics.dispose();
  });

  testWidgets('a shut inventory section keeps the break before CAT Control Preferences', (tester) async {
    // In a sectioned list every row after a band belongs to that band's
    // section, and a folding section folds all of them — so a spacer written
    // as a plain row after the inventory closes up whenever the last section
    // is shut, which is how every section starts.
    await pumpSettings(
      tester,
      equipment: {
        'version': 1,
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'flexradio-tcp',
            'name': 'Left Radio',
            'config': {'host': 'flex.local', 'port': 4992},
          },
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    final gap = tester.getTopLeft(find.text(t.settings.station.catControlPreferences)).dy - tester.getBottomLeft(find.text('1 transceiver')).dy;
    expect(gap, greaterThanOrEqualTo(Space.xl * 2));
  });

  testWidgets('the panel is categories over sections, and both pin', (tester) async {
    // Two heading levels, and the difference between them is what says which
    // is which: a category runs edge to edge on its band, a section is
    // accent-on-surface over a rule inside one. Both hold the top of the pane
    // while their rows scroll under them.
    await pumpSettings(
      tester,
      viewSize: const Size(1200, 900),
      equipment: {
        'version': 1,
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'flexradio-tcp',
            'name': 'Left Radio',
            'config': {'host': 'flex.local', 'port': 4992},
          },
          'ant-1': {'typeKey': 'antenna-none', 'name': 'Dipole', 'config': <String, dynamic>{}},
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    for (final title in ['Current Transceiver', 'Equipment Inventory', 'CAT Control Preferences']) {
      expect(find.widgetWithText(CategoryBand, title), findsOneWidget, reason: '"$title" is a category');
    }
    expect(find.widgetWithText(SectionHeader, 'Configuration'), findsOneWidget);
    // The inventory's own kinds, as sections under it, counted.
    expect(find.widgetWithText(SectionHeader, '1 transceiver'), findsOneWidget);
    expect(find.widgetWithText(SectionHeader, '1 antenna'), findsOneWidget);
    // A kind with nothing in it gets no heading at all — transceivers aside.
    expect(find.textContaining('other device'), findsNothing);

    // Pinned, both levels — SectionedListView cuts on either.
    expect(find.ancestor(of: find.byType(CategoryBand), matching: find.byType(PinnedHeaderSliver)), findsWidgets);
    expect(find.ancestor(of: find.widgetWithText(SectionHeader, '1 transceiver'), matching: find.byType(PinnedHeaderSliver)), findsOneWidget);
  });

  testWidgets('Add Equipment is a button in the Inventory heading', (tester) async {
    // It was the last ROW of the inventory, which on a long one is the single
    // place an operator has to scroll to reach.
    await pumpSettings(tester);
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Add');
    expect(button, findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Add'), findsNothing, reason: 'and no longer a row');
    expect(
      find.ancestor(of: button, matching: find.widgetWithText(CategoryBand, 'Equipment Inventory')),
      findsOneWidget,
      reason: 'it rides the heading it belongs to',
    );
  });

  testWidgets('adding by hand goes through the type list into that type\'s own form', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    // Not pumpAndSettle: while nothing has announced itself the dialog shows
    // a CircularProgressIndicator, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The whole list IS the manual path now, so it carries no heading of its
    // own — a radio on another subnet, or behind a router that doesn't
    // forward broadcasts, is reached from the same list as everything else.
    expect(find.text('Add by address'), findsNothing);
    // Shut, every one of them: the operator picks the make before the model.
    expect(find.text('Icom IC-705'), findsNothing, reason: 'the Icom shelf is closed');

    await tester.tap(find.text('Icom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The RADIO is what the operator picks, named as it is on its own front
    // panel — how it is connected is the next question, not part of this one.
    expect(find.text('Icom IC-705'), findsOneWidget);
    expect(find.text('Icom IC-7300'), findsOneWidget);
    // Opening one shelf does not open the rest.
    expect(find.text('FlexRadio (SmartSDR)'), findsNothing);

    // The section names itself and stays named: discovery runs for as long
    // as this dialog is open, so a heading that flipped between "searching"
    // and "found" would be naming one unfinished activity twice — the
    // spinner beside it is what says the search is still going.
    expect(find.text('Detected Equipment'), findsOneWidget);

    // The caveat appears where it is earned and nowhere else. The Q900's
    // definition was written from the manufacturer's published protocol and
    // has never met a radio, so it says so; every other pairing built here
    // has met one. The per-transport marker the IC-705 used to show while
    // its USB side was untried is a separate thing, and stays gone.
    //
    // Only the built prefix of a lazy list is covered, which is why the
    // count is exact rather than a bare "at least one": a second untested
    // definition sorting into view is the change these assertions exist to
    // catch, and `findsWidgets` would let one through.
    // Shut again, so the shelf below it is not pushed off the bottom of a
    // lazy list that never builds what it cannot reach.
    await tester.tap(find.text('Icom'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Icom IC-705'), findsNothing);

    await tester.tap(find.text('Other Brands'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Guohetec Q900'), findsOneWidget);
    // No hardware-verification caveat anywhere, in either wording: the Q900's
    // definition has never met a radio and its row says nothing about it.
    expect(find.text('Not tested against this hardware'), findsNothing);
    expect(find.textContaining('(untested)'), findsNothing);

    await tester.tap(find.text('Other Brands'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('FlexRadio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The one shelf whose heading is not simply a brand.
  const otherEquipment = 'Other Equipment (Antennas, Keys, etc)';

  /// The pane's own catalogue, for scoping a find away from the Settings
  /// panel behind it — every model name here also appears in the Main VFO
  /// dropdown once one is added.
  final catalogue = find.byType(CustomScrollView).last;

  /// Opens one brand's shelf. Every group starts shut, so nothing names a
  /// radio until this runs.
  Future<void> openBrand(WidgetTester tester, String brand) async {
    await tester.tap(find.text(brand));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('what announced itself is the first shelf, and it opens itself', (tester) async {
    // The one shelf that starts open: a radio the app has already found is
    // the shortest path to a configured one, and it costs nothing to see it
    // before hunting by make. Everything else starts shut.
    await pumpSettings(tester);
    await openAddDialog(tester);

    final detected = tester.getRect(find.ancestor(of: find.text('Detected Equipment'), matching: find.byType(CollapsibleBand)));
    final elecraft = tester.getRect(find.ancestor(of: find.text('Elecraft'), matching: find.byType(CollapsibleBand)));
    expect(detected.top, lessThan(elecraft.top), reason: 'first in the list');

    // The spinner is a ROW, not something in the header: discovery never ends
    // while the pane is open, so a header spinner would spin at the operator
    // the whole time, and one above the list would push every found radio
    // down a line as it arrived.
    final spinner = find.byType(CircularProgressIndicator);
    expect(spinner, findsOneWidget);
    expect(
      find.ancestor(of: spinner, matching: find.byType(ListTile)),
      findsOneWidget,
      reason: 'it rides a row of the list',
    );
    expect(
      find.descendant(of: find.byType(CollapsibleBand), matching: spinner),
      findsNothing,
      reason: 'and not the shelf heading',
    );

    // Centred in the row, not parked in the leading slot: it stands for the
    // search itself, so there is no name beside it to line up with.
    final spinnerRect = tester.getRect(spinner);
    final rowRect = tester.getRect(find.ancestor(of: spinner, matching: find.byType(ListTile)).first);
    expect(spinnerRect.center.dx, closeTo(rowRect.center.dx, 2));

    // Shutting it is the operator's to do, and doing so takes the spinner
    // with it — the search goes on, the row saying so does not.
    await openBrand(tester, 'Detected Equipment');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the spinner gives up after a few seconds, while the listening does not', (tester) async {
    // UDP discovery has no terminal state — it listens for as long as the
    // pane is open — so a spinner tied to the actual activity would turn for
    // the whole visit and become furniture. It says the search STARTED.
    final services = await pumpSettings(tester);
    await openAddDialog(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // The shelf stays, and so does the search behind it: a radio announcing
    // itself after this still has somewhere to appear.
    expect(find.text('Detected Equipment'), findsOneWidget);
    expect(services.cat.isDiscovering, isTrue, reason: 'the spinner stopping is not the search stopping');
  });

  testWidgets('opening a shelf leaves the ones above it where they were', (tester) async {
    // Pinning every opened shelf to the top scrolls the shelves above it
    // away, so opening a brand made "Detected Equipment" vanish and come
    // back. The reveal moves by the LEAST that puts the opened shelf on
    // screen, and by nothing at all when it already is.
    // A window short enough that the list scrolls — at full height nothing
    // moves whatever the reveal does, and the assertion would hold either way.
    await pumpSettings(tester, viewSize: const Size(1000, 620));
    await openAddDialog(tester);

    final before = tester.getRect(find.ancestor(of: find.text('Detected Equipment'), matching: find.byType(CollapsibleBand)));
    // Icom is far enough down that pinning it to the top would scroll the
    // first shelf clean off, and near enough that it is already visible — so
    // the right answer is to move nothing at all.
    await openBrand(tester, 'Icom');

    expect(find.text('Detected Equipment'), findsOneWidget, reason: 'it does not go anywhere');
    final after = tester.getRect(find.ancestor(of: find.text('Detected Equipment'), matching: find.byType(CollapsibleBand)));
    expect(after.top, closeTo(before.top, 1), reason: 'and it does not move');
    expect(find.text('Icom IC-705'), findsOneWidget, reason: 'while the opened shelf is on screen');
  });

  testWidgets('the catalogue is shelved by brand, in a fixed order, everything else last', (tester) async {
    // The order is the point: the five brands come first and in one settled
    // order, and the two catch-alls come last however many radios each holds.
    // A group derived from whatever the catalogue happens to declare would
    // reorder itself the day a model is added.
    await pumpSettings(tester);
    await openAddDialog(tester);

    const expected = ['Elecraft', 'FlexRadio', 'Icom', 'Kenwood', 'Yaesu', 'Software Intermediaries', 'Other Brands', otherEquipment];
    final tops = [for (final name in expected) tester.getTopLeft(find.descendant(of: catalogue, matching: find.text(name))).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: '"${expected[i]}" should sit below "${expected[i - 1]}"');
    }
  });

  testWidgets('opening a shelf animates, rather than snapping open', (tester) async {
    // The pane remounts its whole scroll view when a shelf opens, because
    // every row below it moves and the web hit-tests stale geometry
    // (docs/quirks.md). A remount would also re-inflate the caret's
    // AnimatedRotation already at its new angle — the section would appear
    // open with no turn and no cross-fade. The GlobalKey on each shelf is
    // what keeps the State across it.
    //
    // Mutation check: drop that key and the State identity below changes.
    await pumpSettings(tester);
    await openAddDialog(tester);

    final before = tester.state(find.byType(AnimatedRotation).first);
    await tester.tap(find.text('Icom'));
    await tester.pump();
    expect(
      tester.state(find.byType(AnimatedRotation).first),
      same(before),
      reason: 'the caret has to be the same widget mid-turn, not a fresh one at the far angle',
    );

    // ...and it is genuinely between the two angles part-way through. Scoped
    // to the caret's own AnimatedRotation: the pane's slide and the shelf's
    // cross-fade put Transforms of their own ahead of it in the tree.
    await tester.pump(const Duration(milliseconds: 100));
    final rotated = tester.widget<Transform>(find.descendant(of: find.byType(AnimatedRotation).first, matching: find.byType(Transform)).first);
    expect(rotated.transform.entry(0, 1).abs(), greaterThan(0.01), reason: 'mid-turn, not parked at either angle');

    // Not pumpAndSettle: the discovery spinner never settles.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Icom IC-705'), findsOneWidget);
  });

  testWidgets('a shelf heading is styled like a Settings category, not like a plain band', (tester) async {
    // Same kind of thing, one pane apart: a shelf of rows under a band that
    // folds. Two styles for that would read as two mechanisms, so the heading
    // takes SectionHeader.titleStyle whole — the slab face and the accent.
    await pumpSettings(tester);
    await openAddDialog(tester);

    final context = tester.element(find.text('Elecraft'));
    final expected = SectionHeader.titleStyle(context);
    final heading = tester.widget<Text>(find.text('Elecraft'));
    expect(heading.style?.fontFamily, expected.fontFamily);
    expect(heading.style?.fontFamily, 'RobotoSlab', reason: 'the slab face, spelled out so a theme change is visible here');
    expect(heading.style?.fontWeight, expected.fontWeight);
    expect(heading.style?.color, expected.color);

    // And the search strip must NOT be that same band: at full strength it
    // merges with the collapsed shelves under it into one block of tint with
    // no edge between them — the trap the Settings panel's own search strip
    // is washed to 50% to avoid.
    Color? bandBehind(Finder of) {
      for (final element in find.ancestor(of: of, matching: find.byType(Material)).evaluate()) {
        if ((element.widget as Material).color case final color?) return color;
      }
      return null;
    }

    final shelfBand = bandBehind(find.text('Elecraft'));
    final searchBand = bandBehind(find.widgetWithText(TextField, 'Search equipment'));
    expect(shelfBand, haloDialogBandColorAt(context), reason: 'the shelf keeps the category band');
    expect(searchBand, isNot(shelfBand), reason: 'and the strip above it does not');
  });

  testWidgets('a shelf lists its models alphabetically, in the current locale', (tester) async {
    // Sorted at BUILD time, from the names as the current locale renders
    // them. An order fixed where the catalogue is declared would be
    // alphabetical only in whichever language happened to be active first.
    //
    // Mutation check: drop the sort and this fails on the pair below, since
    // the catalogue declares the IC-705 before Icom - Generic.
    await pumpSettings(tester);
    await openAddDialog(tester);
    await openBrand(tester, 'Icom');

    const expected = ['Icom - Generic', 'Icom IC-705', 'Icom IC-706MKIIG', 'Icom IC-7300', 'Icom IC-7300 MK2'];
    final tops = [for (final name in expected) tester.getTopLeft(find.descendant(of: catalogue, matching: find.text(name))).dy];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: '"${expected[i]}" should sit below "${expected[i - 1]}"');
    }
  });

  testWidgets('only one shelf is open at a time, and the one just opened is on screen', (tester) async {
    // Several open at once puts the shelf you wanted back below the fold,
    // which is the state closing them was for. And shutting a tall shelf
    // ABOVE the one being opened pulls everything up under the pointer — the
    // header just tapped can land above the viewport with its rows nowhere on
    // screen, which is what the scroll correction exists to undo.
    //
    // A short window, so the list actually scrolls; at full height every
    // shelf fits and the correction is unreachable.
    await pumpSettings(tester, viewSize: const Size(1000, 620));
    await openAddDialog(tester);

    await openBrand(tester, 'Icom');
    expect(find.text('Icom IC-705'), findsOneWidget);

    // Scrolled to, because with Icom open it is below the fold — which is
    // also what makes the correction matter: the shelf being shut is above
    // this one, so everything is about to move.
    await tester.scrollUntilVisible(
      find.text('Other Brands'),
      200,
      scrollable: find.descendant(of: catalogue, matching: find.byType(Scrollable)).last,
    );
    await tester.tap(find.text('Other Brands'));
    // Not pumpAndSettle: the discovery spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Icom IC-705'), findsNothing, reason: 'opening one shelf shuts the other');
    expect(find.text('Guohetec Q900'), findsOneWidget);

    // Fully on screen and at the top of it: the shelf that just shut was above
    // this one, so without the correction the collapse leaves this header
    // wherever it lands — which for a shelf this far down is above the
    // viewport with its rows off it. The BAND, not its text: the title sits
    // inset inside the header, so a text-based measure is off by that padding.
    final header = tester.getRect(find.ancestor(of: find.text('Other Brands'), matching: find.byType(CollapsibleBand)));
    final viewport = tester.getRect(find.byType(CustomScrollView).last);
    expect(header.top, greaterThanOrEqualTo(viewport.top - 1), reason: 'not clipped off the top');
    expect(header.top, lessThan(viewport.top + header.height), reason: 'at the top, not merely somewhere');
    expect(find.text('Guohetec Q900'), findsOneWidget, reason: 'so its first rows are under it');
  });

  testWidgets('a radio whose brand has no shelf of its own falls to Other Brands', (tester) async {
    // Matched EXACTLY against featuredBrands: a model spelling its maker any
    // other way, or naming none at all, lands here rather than silently
    // creating a sixth brand nobody ordered.
    await pumpSettings(tester);
    await openAddDialog(tester);
    await openBrand(tester, 'Other Brands');

    expect(find.text('Xiegu X6100'), findsOneWidget);
    expect(find.text('Guohetec Q900'), findsOneWidget);
    expect(find.text('Radio controlled via rigctld'), findsNothing, reason: 'a bridge is not a radio with an odd maker');
  });

  testWidgets('the bridges get a shelf of their own, away from the radios', (tester) async {
    // They answer a different question: an operator browsing brands is
    // looking for what is on their desk, while one reaching for flrig
    // already knows their radio is not directly reachable. Keyed by model
    // rather than derived, so a bridge left off the list falls in with the
    // radios rather than quietly forming a shelf of one.
    await pumpSettings(tester);
    await openAddDialog(tester);
    await openBrand(tester, 'Software Intermediaries');

    expect(find.text('Radio controlled via flrig'), findsOneWidget);
    expect(find.text('Radio controlled via rigctld'), findsOneWidget);
    expect(find.text('Xiegu X6100'), findsNothing, reason: 'a radio with an unshelved maker is not a bridge');
  });

  testWidgets('the search box filters by radio name and by how it plugs in', (tester) async {
    await pumpSettings(tester);
    await openAddDialog(tester);

    // A query FLATTENS the shelves: the answer to "which brand?" is the row
    // itself, and headers over one-row groups would be most of what came
    // back. So a match shows without its group ever being opened, which is
    // also what makes these assertions mean anything.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'icom');
    await tester.pump();
    expect(find.text('Icom IC-705'), findsOneWidget);
    expect(find.text('Icom - Generic'), findsOneWidget);
    expect(find.text('Icom'), findsNothing, reason: 'the shelf headings go with the shelves');
    expect(find.text('FlexRadio (SmartSDR)'), findsNothing);

    // Matching the transport too is the point: an operator with a cable in
    // their hand knows how the radio plugs in long before they know whether
    // its protocol is called CI-V.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'usb');
    await tester.pump();
    expect(find.text('Icom IC-705'), findsOneWidget, reason: 'it has a USB serial pairing');
    expect(find.text('Radio controlled via rigctld'), findsNothing, reason: 'network only');
    // The Yaesus sort below the fold, and a lazy list never builds what is
    // down there — findsNothing on one of them would pass whether the filter
    // worked or not, so they are scrolled to rather than merely looked for.
    await tester.scrollUntilVisible(
      find.text('Yaesu FT-891'),
      200,
      scrollable: find.descendant(of: catalogue, matching: find.byType(Scrollable)).last,
    );
    expect(find.text('Yaesu FT-891'), findsOneWidget);
    expect(find.text('Yaesu - Generic'), findsOneWidget);

    // The brand is searchable even where the model's name carries it and the
    // shelf would have said it anyway — flattening throws the heading away,
    // so the haystack has to hold what the heading held.
    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'xiegu');
    await tester.pump();
    expect(find.text('Xiegu X6100'), findsOneWidget);
    expect(find.text('Icom - Generic'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'zzzz');
    await tester.pump();
    expect(find.text('No equipment matches'), findsOneWidget);
  });

  testWidgets('the Lab599 radios and the Bluetooth LE pairing wait for EXP 500MP', (tester) async {
    // Neither has met hardware: offered before the experiment is on, an
    // operator would set up a radio from guesses and blame the app.
    final services = await pumpSettings(tester);
    await openAddDialog(tester);
    final search = find.widgetWithText(TextField, 'Search equipment');

    await tester.enterText(search, 'tx-500');
    await tester.pump();
    expect(find.text('Lab599 TX-500MP'), findsNothing);
    await tester.enterText(search, 'bluetooth le');
    await tester.pump();
    expect(find.text('Icom IC-7300'), findsNothing, reason: 'its only Bluetooth is the LE pairing every serial radio derives');

    Navigator.of(tester.element(search)).pop();
    await tester.pumpAndSettle();
    await services.settings.setExperimentEnabled('500mp', true);
    await tester.pumpAndSettle();
    await openAddDialog(tester);

    await tester.enterText(search, 'tx-500');
    await tester.pump();
    expect(find.text('Lab599 TX-500MP'), findsOneWidget);
    await tester.enterText(search, 'bluetooth le');
    await tester.pump();
    expect(find.text('Icom IC-7300'), findsOneWidget);
  });

  testWidgets('a radio already on a pairing EXP 500MP holds back keeps it in its editor', (tester) async {
    // The gate holds back the offer only. Dropped from the editor, the
    // node's own pairing would vanish from its Connection choice, and the
    // first save would move a working radio onto another one.
    await pumpSettings(
      tester,
      equipment: {
        'version': 1,
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'ic7300-ble',
            'name': 'Field Radio',
            'config': {'bleDevice': 'AA:BB', 'bleDeviceName': 'Bridge'},
          },
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field Radio').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SegmentedButton<dynamic>, 'Bluetooth LE'), findsOneWidget);
  });

  testWidgets('a search reaches the equipment that is added by name, not picked by model', (tester) async {
    // "Other Equipment" is a shelf like any other now, so the keyer an
    // operator searches for by make has to come back from the same box that
    // finds their radio — nobody hunting "winkey" knows it lives under a
    // heading rather than in the catalogue.
    final services = await pumpSettings(tester);
    await services.settings.setExperimentEnabled('keyer', true);
    await tester.pumpAndSettle();
    await openAddDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Search equipment'), 'winkey');
    await tester.pump();
    expect(find.text('WinKeyer (K1EL or compatible)'), findsOneWidget);
    expect(find.text(otherEquipment), findsNothing, reason: 'a query flattens every shelf, this one included');
    expect(find.text('Icom IC-705'), findsNothing);
  });

  testWidgets('a transport glyph is pinned beside the radio\'s name, not centred down the row', (tester) async {
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
    await pumpSettings(tester);
    await openAddDialog(tester);
    await openBrand(tester, 'Icom');

    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Icom IC-705')).titleAlignment, ListTileTitleAlignment.top);
  });

  testWidgets('a short window does not overflow the dialog', (tester) async {
    // With scrollable: false the search row and the discovery section are the
    // Column's inflexible children — an unbounded section pushes the whole
    // dialog past its height cap and paints overflow stripes. Any thrown
    // layout exception fails this test on its own.
    await pumpSettings(tester, viewSize: const Size(900, 420));
    await openAddDialog(tester);

    expect(find.text('Detected Equipment'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(find.text('Detected Equipment'), findsOneWidget);
  });

  testWidgets('a new radio is named after the model, numbered once that name is taken', (tester) async {
    await pumpSettings(tester, secureStorage: FakeSecureStorage());
    await openAddDialog(tester);
    await openBrand(tester, 'Software Intermediaries');

    await tester.tap(find.text('Radio controlled via rigctld'));
    await tester.pumpAndSettle();

    // Prefilled, and prefilled EDITABLY — the operator sees what it will be
    // called before agreeing to it. NOT the catalogue row's own words: that
    // entry describes the PATH to a radio, so the node takes the model's
    // suggestedName instead and ends up named after the rig.
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Name').first).controller?.text, 'My Radio (via rigctld)');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    await openAddDialog(tester);
    await openBrand(tester, 'Software Intermediaries');
    // Scoped to the pane: the name is now also on the equipment row and in
    // the Main VFO dropdown behind it.
    await tester.tap(find.descendant(of: catalogue, matching: find.text('Radio controlled via rigctld')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.widgetWithText(TextField, 'Name').first).controller?.text,
      'My Radio (via rigctld) 2',
      reason: 'the shack already has one, and two identical rows cannot be told apart',
    );
  });

  testWidgets('opening the iOS keyboard keeps the equipment editor active with an antenna configured', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(440, 956) * 3;
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);

    final HaLoHarness(:services) = await makeHaLoServices(
      prefs: {
        'stationEquipment': jsonEncode({
          'version': 1,
          'nodes': {
            'antenna-1': {'typeKey': 'antenna-none', 'name': 'Dipole', 'config': {}},
          },
        }),
      },
    );
    await services.settings.setTrackStationInfo(true);
    await services.settings.setStationInfoTrackedFields({'rig', 'power', 'antenna', 'key'});
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          builder: (context, child) => StatusBarOverlay(services: services, child: child!),
          home: SettingsView(services: services),
        ),
      ),
    );

    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> tapVisible(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        final scrollable = find.descendant(of: find.byType(AddEquipmentDialog), matching: find.byType(Scrollable)).last;
        await tester.scrollUntilVisible(finder, 250, scrollable: scrollable);
      }
      await tester.ensureVisible(finder);
      await settle();
      await tester.tap(finder);
      await settle();
    }

    await settle();
    await tapVisible(find.text('Station Configuration'));
    await tapVisible(find.widgetWithText(FilledButton, 'Add').last);
    await tapVisible(find.text('Other Brands'));
    await tapVisible(find.text('Generic Radio (Placeholder)').last);

    final field = find.widgetWithText(TextField, 'Name').last;
    final focus = tester.widget<TextField>(field).focusNode!;
    tester.testTextInput.log.clear();
    await tester.tap(field);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext'), isEmpty);

    // StatusBarOverlay shrinks the whole Navigator, including the station
    // list behind the editor. With an antenna, its lazy list drops the offscreen
    // "What to track?" form. Disposing that non-text form must not finish
    // the active editor's platform-wide autofill context: native iOS closes
    // its keyboard even though TestTextInput leaves Dart focus unchanged.
    final trackingForm = find.ancestor(of: find.text('What to track?', skipOffstage: false), matching: find.byType(FormRenderer));
    expect(trackingForm, findsOneWidget, reason: 'the form must be mounted before the inset, or nothing is disposed');
    tester.view.viewInsets = const FakeViewPadding(bottom: 346 * 3);
    await settle();
    expect(trackingForm, findsNothing, reason: 'the inset must drop the form, or the test exercises no disposal');

    expect(
      tester.testTextInput.log.where((call) => call.method == 'TextInput.finishAutofillContext'),
      isEmpty,
      reason: 'background station controls must not dismiss the equipment editor keyboard',
    );
    expect(tester.widget<TextField>(field).focusNode, same(focus));
    expect(focus.hasFocus, isTrue);
    tester.testTextInput.enterText('My Radio');
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, 'My Radio');
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an occupied K4 receiver stays in the editor with a field validation message', (tester) async {
    final services = await pumpSettings(
      tester,
      secureStorage: FakeSecureStorage(),
      equipment: {
        'version': 3,
        'nodes': {
          'k4-main': {
            'typeKey': 'k4-remote',
            'name': 'My K4 Main',
            'config': {'host': '192.0.2.4', 'remotePort': 9204, 'receiver': 'main', 'k4ConnectionId': 'k4-main'},
          },
          'k4-sub': {
            'typeKey': 'k4-remote',
            'name': 'My K4 Sub',
            'config': {'host': '192.0.2.4', 'remotePort': 9204, 'receiver': 'sub', 'k4ConnectionId': 'k4-main'},
          },
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 transceivers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My K4 Main').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<dynamic>, t.settings.station.k4Receiver));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.station.k4ReceiverSub).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(find.text(t.settings.station.k4ReceiverAlreadyConfigured), findsOneWidget);
    expect(find.text('Save'), findsWidgets, reason: 'validation must keep the editor open for correction');
    expect(services.cat.nodeFor('k4-main')!.config['receiver'], 'main');
    expect(tester.takeException(), isNull, reason: 'an occupied receiver is a form error, not an unhandled exception');
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
    final services = await pumpSettings(tester, secureStorage: FakeSecureStorage());

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await openBrand(tester, 'Icom');

    await tester.tap(find.text('Icom IC-705'));
    await tester.pumpAndSettle();

    // Opened on the verified pairing, and the choice is a field in the form
    // rather than a fork before it.
    expect(find.text('Connection'), findsWidgets);
    expect(find.widgetWithText(SegmentedButton<dynamic>, 'Network/WiFi'), findsOneWidget);
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

  testWidgets('switched to WiFi, only WiFi\'s own rules apply: a missing username refuses the save', (tester) async {
    // The trap: FormRenderer validates every declared field, hidden ones
    // included, so the editor must ask the pairing the connection choice
    // NAMES. Asked of the serial pairing it opened on instead — whose port
    // is set — this save would go through with a WiFi radio that cannot log
    // in. (A blank field of the other pairing proves nothing: a pairing with
    // no port or address is unconfigured and skips its checks.)
    final services = await pumpSettings(
      tester,
      secureStorage: FakeSecureStorage(),
      equipment: {
        'version': 1,
        'nodes': {
          'radio-1': {
            'typeKey': 'ic705-serial',
            'name': 'The 705',
            'config': {'port': '/dev/cu.usbmodem1', 'civAddress': 'A4', 'baudRate': 19200},
          },
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 transceiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The 705').last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(SegmentedButton<dynamic>), matching: find.text('Network/WiFi')));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Address').first, '10.0.0.9');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    expect(services.cat.nodes.single.typeKey, 'ic705-serial', reason: 'not saved as WiFi without a username');
    expect(find.text('Save'), findsWidgets, reason: 'the editor is still open, with the error on its field');
  });

  testWidgets('switching transport swaps which pairing the form is describing', (tester) async {
    // Stops at the swap, deliberately: saving the serial pairing needs a
    // serial port to pick, and this fixture has none.
    // That the re-typed node then persists is cat_service_test's to prove.
    await pumpSettings(
      tester,
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
    // The inventory's sections start closed; the row is in Transceivers.
    await tester.tap(find.text('1 transceiver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The 705').last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(SegmentedButton<dynamic>), matching: find.text('USB Serial')));
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
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<dynamic>), matching: find.text('Network/WiFi')));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Address').first).controller?.text, '10.0.0.9');
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
    // The inventory's sections start closed; the row is in Transceivers.
    await tester.tap(find.text('1 transceiver'));
    await tester.pumpAndSettle();
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

  testWidgets('the Main VFO radio is picked from every known radio, by the menu or by a row\'s icon', (tester) async {
    // Configuration, not link state: both ways offer every transceiver the
    // station knows about, whether or not it happens to be connected.
    final services = await pumpSettings(
      tester,
      equipment: {
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
      },
    );

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    expect(find.text('Current Transceiver'), findsOneWidget);

    // The menu under the current transceiver's row.
    await tester.tap(find.byIcon(MdiIcons.menuDown));
    await tester.pumpAndSettle();
    expect(find.text('Right Radio'), findsOneWidget, reason: 'neither is connected, and both are offered');
    await tester.tap(find.text('Right Radio'));
    await tester.pumpAndSettle();
    expect(services.cat.radio1, LocalRadio('radio-2'));

    // And the inventory's own row: its dim icon makes it the one.
    await tester.tap(find.text('2 transceivers'));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Use Left Radio for the Main VFO'));
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(services.cat.radio1, LocalRadio('radio-1'));
  });

  testWidgets("a multi-channel radio wears its channel beside the name, not in the address", (tester) async {
    // Two slices of one Flex are two rows with the SAME address, so the slice
    // is the only thing telling them apart — which is why it belongs with the
    // name and not appended to the address, where a narrow column clipped it
    // to "…Slice A" and dropped the address entirely.
    await pumpSettings(
      tester,
      equipment: {
        'version': 1,
        'radio1': 'radio-1',
        'nodes': {
          'radio-1': {
            'typeKey': 'flexradio-tcp',
            'name': 'Shack Flex',
            'config': {'host': 'flex.local', 'port': 4992, 'slice': '1'},
          },
        },
      },
    );
    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 transceiver'));
    await tester.pumpAndSettle();

    expect(find.text('Slice B'), findsOneWidget);

    // Beside the NAME, not in the address column — the row is a 3:2 split and
    // the address sits at its right end, so a slice still tacked onto the
    // address would be over there.
    final pill = tester.getRect(find.text('Slice B'));
    final name = tester.getRect(find.text('Shack Flex').last);
    expect(pill.left, greaterThan(name.left), reason: 'after the name');

    // And gone from the ADDRESS, which says only where the radio is — on the
    // inventory row and on the current transceiver's alike.
    expect(find.text('flex.local:4992'), findsNWidgets(2), reason: 'the slice is not tacked onto it');
  });

  testWidgets('a node whose type no longer exists says so instead of vanishing', (tester) async {
    await pumpSettings(
      tester,
      equipment: {
        'version': 1,
        'nodes': {
          'orphan': {'typeKey': 'a-driver-we-removed', 'name': 'Old Rig'},
        },
      },
    );

    await tester.tap(find.text('Station Configuration'));
    await tester.pumpAndSettle();
    // With no category to file it under it is other equipment — counted
    // there, and listed once that section is open.
    await tester.tap(find.text('1 other device'));
    await tester.pumpAndSettle();

    expect(find.text('Old Rig'), findsOneWidget);
    expect(find.textContaining('a-driver-we-removed'), findsOneWidget);
    // No Connect button for something the app can't talk to.
    expect(find.text('Connect'), findsNothing);
  });
}
