// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Radio control's quick-access dialog (StationPanel's `compact` mode):
// current configuration and the current rig only, a Power field, no Add
// Equipment/Other Options, and a More Settings/Done footer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_core/halo_core.dart';
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment.dart';
import 'package:ham2k_logger/services/peer/peer_station_radios.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/views/station_panel.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    services = harness.services;
  });

  // The VFO's persist debounce, which a Power commit arms and which would
  // otherwise outlive the widget tree and fail the test on a pending timer.
  Future<void> settleVfoWrite(WidgetTester tester) => tester.runAsync(services.radio.flushPendingWrites);

  Widget wrap(Widget child) => TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets('shows only the current rig, not other radios, and no Add Equipment', (tester) async {
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Second Radio');
    expect(services.cat.radio1, isNotNull, reason: 'newest addNode designates radio1');

    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Main Radio'), findsNothing, reason: 'radio1 is Second Radio, the newest added');
    // Once in the VFO dropdown's selected value, once in the equipment row.
    expect(find.text('Second Radio'), findsNWidgets(2));
    expect(find.text('Add equipment'), findsNothing);
  });

  testWidgets('hides Other Options entirely', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Other Options'), findsNothing);
    expect(find.text('Track Station Info for each QSO'), findsNothing);
  });

  testWidgets('has no equipment row when no rig is designated', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('No equipment configured'), findsNothing, reason: 'compact mode never shows this message');
  });

  group("a peer's radio driving the main VFO", () {
    const pick = PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', deviceName: "VE1SK's iPad", radioName: 'FTDX10');

    testWidgets('gets a row of its own in Equipment in Use', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      // The trap the section header names: with the peer listed nowhere, a
      // section titled "Equipment in Use" sat empty while the dropdown
      // directly above it named the peer as the rig in use.
      expect(find.text('Equipment in Use'), findsOneWidget);
      expect(find.text('FTDX10'), findsOneWidget);
      expect(find.text("On VE1SK's iPad"), findsOneWidget);
      // It drives vfoA, so it wears the pill a local rig in that role wears.
      expect(find.text('Main VFO'), findsOneWidget);
      // No peer is offering it in this test, and the row says so rather than
      // disappearing — the pick survives the peer walking away.
      expect(find.text('Not available'), findsOneWidget);
    });

    testWidgets('has nothing to connect, edit or unplug', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      // Anchored on the peer's own row: with no local radio and the keyer
      // experiment off, a bare findsNothing for the plug passes just as well
      // when the row is not built at all.
      final row = find.ancestor(of: find.text('FTDX10'), matching: find.byType(ListTile));
      expect(row, findsOneWidget);

      // The rig is plugged into the other device. A plug icon here would
      // offer a session this app cannot open, and the row is not a local
      // equipment record to edit or remove either.
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.powerPlugOff)), findsNothing);
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.powerPlug)), findsNothing);
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.trashCanOutline)), findsNothing);
    });

    testWidgets('the Key in Use row names the peer that keys, and the dialog builds', (tester) async {
      // The row exists for a peer's key even on a device with no key
      // inventory of its own — the phone this feature is for — or its
      // operator can neither set the speed nor step off the peer's key. And
      // the pick shows the PEER: nothing is stored for a default, so a picker
      // reading the stored value alone says None while F1 keys over the link.
      await services.settings.setExperimentEnabled('keyer', true);
      await services.cat.setRadio1(const PeerRadio(pick));
      services.cat.noteOffer(pick.deviceId, pick.deviceName, const [PeerRadioOffer(id: 'rig-1', name: 'FTDX10', keysCw: true)]);

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Key in Use'), findsOneWidget);
      expect(find.text("Key on VE1SK's iPad"), findsOneWidget);
      expect(find.text('None selected'), findsNothing);
    });

    testWidgets('a keying peer adds no key row while the keyer experiment is off', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));
      services.cat.noteOffer(pick.deviceId, pick.deviceName, const [PeerRadioOffer(id: 'rig-1', name: 'FTDX10', keysCw: true)]);

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Key in Use'), findsNothing, reason: 'a bare row with nothing selectable in it');
    });
  });

  group('CW keyer row', () {
    testWidgets('is not there at all without the keyer experiment', (tester) async {
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.widgetWithText(TextButton, 'Messages'), findsNothing);
    });

    testWidgets('a radio that cannot key, as the only key, shows no keyer row', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.widgetWithText(TextButton, 'Messages'), findsNothing);
    });

    testWidgets('a capable radio, never connected, drives the whole row from what it CAN do', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // Added, never connected — auto-designated as the key in use because
      // it can key and nothing else was. The trap this catches is laying the
      // row out from the LINK: everything below is a fact about the rig, and
      // an unplugged cable changes none of it.
      await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      final pick = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(pick.onChanged, isNull, reason: 'the speed is the keyer\'s; only a live session can take one');
      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'CW Keyer')).onPressed,
        isNotNull,
        reason: 'the messages are settings, editable without a radio',
      );
      expect(
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Phone Keyer')).onPressed,
        isNotNull,
        reason: 'the rig holds memories whether or not it is plugged in',
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull, reason: 'the keyer area is worth showing for a rig that can key');
      expect(find.text('CAT Keyer in Bench Rig'), findsOneWidget, reason: 'a radio in the key pick is its keyer');
    });

    testWidgets('a side the station cannot send on is disabled, and says why where it can be said', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // A keyer of its own beside a rig that keys neither: CW can go out, no
      // voice memory can. Disabling on capability is the point — a hover
      // tooltip is not available to say so (docs/design/user-interface.md),
      // so the reason has to reach a screen reader or nowhere.
      final keyer = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Keyer', config: placeholderRadioModel.variants.single.defaultConfig);
      await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
      await services.cat.setDesignated(kCategoryKey, keyer.uuid);
      expect(services.cat.radio1HasVoiceMemories, isFalse, reason: 'sanity: a generic Kenwood pins no memory count');

      // The reason lives ONLY in the semantics tree, which is off by default
      // in a widget test — without this handle the label search below cannot
      // fail, whatever the widget says.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'CW Keyer')).onPressed, isNotNull);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Phone Keyer')).onPressed, isNull);
      expect(find.bySemanticsLabel('Phone Keyer. Not supported by this radio'), findsOneWidget);
      expect(find.bySemanticsLabel('CW Keyer. Not supported by this radio'), findsNothing, reason: 'a button that works must not carry a reason it does not');
      semantics.dispose();
    });

    testWidgets('a radio keying through its own CAT session draws ONE equipment row', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // One rig, auto-designated both as radio1 and as the key in use — the
      // trap is drawing it a second time as "the keyer in use", which reads
      // as a shack with two identical radios on one address.
      await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      expect(services.cat.isRadio1(services.cat.designatedKeyerNode!.uuid), isTrue, reason: 'sanity: one node fills both roles');

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      // Once as the Main VFO dropdown's value, once as its equipment row —
      // the key pick names it as 'CAT Keyer in Bench Rig', not a bare match.
      expect(find.text('Bench Rig'), findsNWidgets(2));
    });

    testWidgets('a keyer that is NOT the current rig keeps its own row', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // The keyer added first, the rig second so the rig is radio1. The row
      // is this keyer's only reachable connect button in compact, so the
      // one-row rule above must narrow to the shared node and no further.
      final keyer = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Keyer', config: placeholderRadioModel.variants.single.defaultConfig);
      await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
      await services.cat.setDesignated(kCategoryKey, keyer.uuid);
      expect(services.cat.isRadio1(keyer.uuid), isFalse, reason: 'sanity: the rig, not the keyer, drives the main VFO');

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(find.text('Bench Keyer'), findsOneWidget, reason: 'its equipment row; the key pick names it as CAT Keyer in ...');
      expect(find.byIcon(MdiIcons.powerPlugOff), findsNWidgets(2), reason: 'rig and keyer each connect from their own row');
    });

    testWidgets('a connected keyer-capable radio enables the pick at the speed the radio reported', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // The placeholder rig keys nothing but reports a speed like a real
      // one — the same path an IC-7300's 0x14 0x0C answer takes.
      final node = await services.cat.addNode(
        typeKey: 'placeholder-radio',
        name: 'Bench Rig',
        // The Add dialog prefills these; a bare node fails its own validators.
        config: placeholderRadioModel.variants.single.defaultConfig,
      );
      await tester.runAsync(() => services.cat.connect(node.uuid));
      expect(services.cat.canKeyCw, isTrue, reason: 'sanity: the placeholder rig is a CwKeyerSession');

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      final pick = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
      expect(pick.onChanged, isNotNull);
      expect(find.text('22 WPM'), findsOneWidget, reason: 'the placeholder rig comes up at 22 WPM');
      expect(find.text('Connect a radio that can key CW to send messages from here.'), findsNothing);

      // Picking a speed is a set on the radio, and what shows is what the
      // radio says back — not the picked value assumed.
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 WPM').last);
      await tester.pumpAndSettle();
      expect(services.cat.keyerSpeed, 25);
      expect(find.text('25 WPM'), findsOneWidget);

      await tester.runAsync(() => services.cat.disconnect(node.uuid));
    });
  });

  testWidgets('Power field persists to the VFO on submit', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(services.radio.vfoA.power, isNull);
    expect(find.text('Watts'), findsOneWidget, reason: 'unit label after the field');
    await tester.enterText(find.widgetWithText(TextFormField, 'Power'), '100');
    expect(services.radio.vfoA.power, isNull, reason: 'not committed until submit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 100);
  });

  testWidgets('Power field commits on losing focus, not just on submit', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Power'), '50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 50);
  });

  testWidgets('typing does not rebuild the field mid-entry (no per-keystroke remount)', (tester) async {
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, 'Power');
    await tester.enterText(field, '1');
    await tester.pump();
    // A per-keystroke commit-and-remount (the ValueKey bug) would have
    // pushed '1' to settings already and swapped in a fresh Element/
    // FocusNode — losing focus after the first digit. Still focused here
    // means the rest of a multi-digit value can land in the same field.
    expect(services.radio.vfoA.power, isNull);
    await tester.enterText(field, '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settleVfoWrite(tester);

    expect(services.radio.vfoA.power, 15);
  });

  testWidgets('footer: More Settings fires the callback, Done pops the pane', (tester) async {
    var moreSettingsTapped = false;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(
                child: StationPanel(services: services, compact: true, onMoreSettings: () => moreSettingsTapped = true),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More Settings'));
    await tester.pumpAndSettle();
    expect(moreSettingsTapped, isTrue);

    // Still open — this test's onMoreSettings doesn't pop, unlike the real
    // logging_panel.dart wiring, so Done is exercised as a separate action.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(StationPanel), findsNothing);
  });
}
