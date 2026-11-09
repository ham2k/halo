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
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/station_panel.dart';
import 'package:ham2k_logger/views/station_rows.dart';

import '../support/fake_voice_audio.dart';
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

  // The keying lines sit under More details, folded until it is opened: a
  // finder that skips offstage widgets sees none of them before this.
  Future<void> openMoreDetails(WidgetTester tester) async {
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows only the current rig, not other radios, and no Add Equipment', (tester) async {
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Second Radio');
    expect(services.cat.radio1, isNotNull, reason: 'newest addNode designates radio1');

    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Main Radio'), findsNothing, reason: 'radio1 is Second Radio, the newest added');
    // Once, in the Current Transceiver band: the compact dialog lists no
    // inventory, and the band is where the rig in use is named.
    expect(find.text('Second Radio'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
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

  testWidgets('with no radio picked, tapping anywhere on the row opens the picker', (tester) async {
    // A row reading "No transceiver selected" has nothing to edit, so a tap
    // on it that only the small arrow answered would read as a dead row.
    await services.cat.addNode(typeKey: 'kenwood-serial', name: 'Main Radio');
    await services.cat.setRadio1(null);
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No transceiver selected'));
    await tester.pumpAndSettle();
    expect(find.text('Main Radio'), findsOneWidget, reason: 'the picker lists the station\'s radios');
  });

  group("a peer's radio driving the main VFO", () {
    const pick = PeerRadioSelection(deviceId: 'device-a', radioId: 'rig-1', deviceName: "VE1SK's iPad", radioName: 'FTDX10');

    testWidgets('heads the dialog as the Current Transceiver', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      // The trap: a peer's rig listed nowhere, while the logging panel
      // follows it, reads as no rig at all.
      expect(find.text('Current Transceiver'), findsOneWidget);
      expect(find.text('FTDX10'), findsOneWidget);
      expect(find.text("On VE1SK's iPad"), findsOneWidget);
      // It drives vfoA, so it wears the pill a local rig in that role wears.
      expect(find.text('Main VFO'), findsOneWidget);
      // No peer is offering it in this test, and the row says so rather than
      // disappearing — the pick survives the peer walking away.
      expect(find.text('Not available'), findsOneWidget);
    });

    testWidgets('a tap on its row says where it is configured', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      await tester.tap(find.text('FTDX10'));
      await tester.pumpAndSettle();
      expect(find.text('FTDX10 is on another device'), findsOneWidget);
    });

    testWidgets('has nothing to connect, edit or unplug', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      // Anchored on the peer's own row — its frame, which holds the buttons
      // in the margins beside the tile, not the tile itself: with no local
      // radio and the keyer experiment off, a bare findsNothing for the plug
      // passes just as well when the row is not built at all.
      final row = find.ancestor(of: find.text('FTDX10'), matching: find.byType(CurrentRowFrame));
      expect(row, findsOneWidget);

      // The rig is plugged into the other device. A plug icon here would
      // offer a session this app cannot open, and the row is not a local
      // equipment record to edit or remove either.
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.powerPlugOff)), findsNothing);
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.powerPlug)), findsNothing);
      expect(find.descendant(of: row, matching: find.byIcon(MdiIcons.trashCanOutline)), findsNothing);
    });

    testWidgets('the CW Keying row names the peer that keys, and the dialog builds', (tester) async {
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
      await openMoreDetails(tester);

      expect(find.text('CW Keying'), findsOneWidget);
      expect(find.text("Key on VE1SK's iPad"), findsOneWidget);
      expect(find.text('None selected'), findsNothing);
    });

    testWidgets('a keying peer adds no key row while the keyer experiment is off', (tester) async {
      await services.cat.setRadio1(const PeerRadio(pick));
      services.cat.noteOffer(pick.deviceId, pick.deviceName, const [PeerRadioOffer(id: 'rig-1', name: 'FTDX10', keysCw: true)]);

      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(find.text('More details'), findsNothing, reason: 'with no key row there is nothing to fold');
      expect(find.text('CW Keying'), findsNothing, reason: 'a bare row with nothing selectable in it');
    });
  });

  // Recordings on this computer are recorded before the rig is on the desk:
  // a Phone Keying line that waits for a radio leaves nowhere to record them.
  testWidgets('with no radio, Phone Keying offers the computer', (tester) async {
    final audio = FakeVoiceAudio();
    services = (await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    )).services;
    await services.settings.setExperimentEnabled('keyer', true);
    await services.cat.selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();
    await openMoreDetails(tester);
    expect(find.text('Audio in this computer'), findsOneWidget);
  });

  // Words picked without their experiment are the audio they come with:
  // read as None, the operator's recordings stop playing the moment the
  // experiment goes off.
  testWidgets('Phone Keying offers audio and words only with its experiment', (tester) async {
    final audio = FakeVoiceAudio();
    services = (await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    )).services;
    await services.settings.setExperimentEnabled('keyer', true);
    await services.cat.selectVoiceKeyingSource(VoiceKeyingSource.words);
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();
    await openMoreDetails(tester);
    expect(find.text('Audio in this computer'), findsOneWidget);
    await tester.tap(find.text('Audio in this computer'));
    await tester.pumpAndSettle();
    expect(find.text('Audio and words in this computer'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await services.settings.setExperimentEnabled('words', true);
    await tester.pumpWidget(wrap(StationPanel(key: UniqueKey(), services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();
    await openMoreDetails(tester);
    expect(find.text('Audio and words in this computer'), findsOneWidget);
  });

  // The trap: one Phone Keying line for two radios — Radio B left on its own
  // memories with no way to pick otherwise, or a pick made for it moving
  // radio1's.
  testWidgets('under SO2R, Radio B has a Phone Keying line of its own, under its antenna and key', (tester) async {
    final audio = FakeVoiceAudio();
    services = (await makeHaLoServices(
      cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
    )).services;
    await services.settings.setExperimentEnabled('keyer', true);
    await services.settings.setExperimentEnabled('so2r', true);
    final cat = services.cat;
    final left = await cat.addNode(typeKey: 'placeholder-radio', name: 'Left Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    final right = await cat.addNode(typeKey: 'placeholder-radio', name: 'Right Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await cat.setRadio1(LocalRadio(left.uuid));
    await cat.setRadio2(right.uuid);
    await cat.keyer('B').selectVoiceKeyingSource(VoiceKeyingSource.computer);
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();
    await openMoreDetails(tester);

    expect(find.text('A: Phone Keying'), findsOneWidget);
    expect(find.text('B: Phone Keying'), findsOneWidget);
    expect(find.text('Memories in Left Rig'), findsOneWidget, reason: "radio1's pick: its own memories");
    expect(find.text('Audio in this computer'), findsOneWidget, reason: "Radio B's pick: the computer");
    expect(find.bySemanticsLabel('Computer Audio'), findsOneWidget, reason: "the way to Radio B's sound devices, and only Radio B's");
  });

  testWidgets('under SO2R, the switcher is picked beside the button to its settings, which hold stereo and listening', (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    final cat = services.cat;
    final left = await cat.addNode(typeKey: 'placeholder-radio', name: 'Left Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    final right = await cat.addNode(typeKey: 'placeholder-radio', name: 'Right Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    final box = await cat.addNode(typeKey: 'otrsp-serial', name: 'SO2R Box');
    await cat.setRadio1(LocalRadio(left.uuid));
    await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
    await tester.pumpAndSettle();
    // No More details at all, so the switcher is absent rather than folded.
    expect(find.text('More details'), findsNothing, reason: 'two radios to switch between, or none');
    expect(find.text('SO2R Switcher'), findsNothing);

    await cat.setRadio2(right.uuid);
    await tester.pumpAndSettle();
    await openMoreDetails(tester);
    expect(find.text('SO2R Switcher'), findsOneWidget);
    final settingsButton = find.widgetWithIcon(IconButton, MdiIcons.tune).last;
    expect(tester.widget<IconButton>(settingsButton).onPressed, isNull, reason: 'with None picked there is nothing to set');

    // Held disconnected: a picked switcher is kept connected, and a serial
    // port this test has none of would leave its retries pending.
    await tester.runAsync(() => cat.disconnect(box.uuid));
    await cat.setSo2rSwitch(box.uuid);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('SO2R Switcher settings'));
    await tester.pumpAndSettle();
    expect(find.text('Listen to the other radio while transmitting'), findsOneWidget);
    await tester.tap(find.text('Stereo: Radio A left, Radio B right'));
    await tester.pumpAndSettle();
    expect(services.settings.so2rStereo, isTrue);
    expect(find.widgetWithText(SwitchListTile, 'Stereo: Radio A left, Radio B right'), findsOneWidget);
    // Not on the page itself any more: the settings are the dialog's.
    await tester.tap(find.widgetWithText(TextButton, 'Done').last);
    await tester.pumpAndSettle();
    expect(find.text('Listen to the other radio while transmitting'), findsNothing);
  });

  group('CW keyer row', () {
    testWidgets('a capable radio, never connected, drives the whole row from what it CAN do', (tester) async {
      await services.settings.setExperimentEnabled('keyer', true);
      // Added, never connected — auto-designated as the key in use because
      // it can key and nothing else was. The trap this catches is laying the
      // row out from the LINK: everything below is a fact about the rig, and
      // an unplugged cable changes none of it.
      await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Bench Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      await openMoreDetails(tester);

      expect(find.text('Memories in Bench Rig'), findsOneWidget, reason: "Phone Keying offers the rig's own memories");
      expect(find.text('CAT Keyer in Bench Rig'), findsOneWidget, reason: 'a radio in the key pick is its keyer');
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

      // Once, in the Current Transceiver band — the key pick names it as
      // 'CAT Keyer in Bench Rig', not a bare match.
      expect(find.text('Bench Rig'), findsOneWidget);
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
  });

  group('the current transceiver', () {
    // An IC-7300 on a USB serial adapter: its scope is the radio's own screen,
    // and its port is a long device path. Held disconnected: there is no such
    // port here, and its retries would outlive the test.
    Future<EquipmentNode> addIc7300(WidgetTester tester) async {
      final cat = services.cat;
      final node = await cat.addNode(
        typeKey: 'ic7300-serial',
        name: 'Shack 7300',
        config: {...cat.registry.typeFor('ic7300-serial')!.defaultConfig, 'port': '/dev/cu.usbserial-00F8E1EB0', 'baudRate': 19200},
      );
      await tester.runAsync(() => cat.disconnect(node.uuid));
      return node;
    }

    testWidgets('a serial port is clipped from the front, keeping the end that tells adapters apart', (tester) async {
      await addIc7300(tester);
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      // Clipped from the end, two adapters on one machine read alike as
      // "/dev/cu.usbse…"; the end of the path is what differs between them.
      // And only the port is clipped: clipping the whole line would spend
      // the cap on the driver's CI-V address and show no port at all.
      expect(find.text('…E1EB0 @ 19200 · CI-V 94'), findsOneWidget);
    });

    testWidgets('an Icom, whose scope is its own screen, offers bandscope adjustment under More details', (tester) async {
      final node = await addIc7300(tester);
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      await openMoreDetails(tester);

      expect(find.text('Automatically adjust bandscope'), findsOneWidget);
      await tester.tap(find.text('Let this app adjust the bandscope'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Use the radio's bandscope settings as-is").last);
      await tester.pumpAndSettle();
      // Stored on the radio's own node, where its session reads it at connect.
      expect(services.cat.nodeFor(node.uuid)!.config['civScopeAdjust'], 'radio');
    });

    testWidgets('under SO2R, Radio B offers its own bandscope adjustment', (tester) async {
      // Both radios in use draw their scopes, and B's is an Icom's own screen
      // as much as A's would be: with A's choice alone, B's could only be
      // changed by making it the Main VFO.
      await services.settings.setExperimentEnabled('so2r', true);
      final rigB = await addIc7300(tester);
      final rigA = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Left Rig', config: placeholderRadioModel.variants.single.defaultConfig);
      await services.cat.setRadio1(LocalRadio(rigA.uuid));
      await services.cat.setRadio2(rigB.uuid);
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      await openMoreDetails(tester);

      expect(find.text('B: Automatically adjust bandscope'), findsOneWidget);
      expect(find.text('A: Automatically adjust bandscope'), findsNothing, reason: 'the placeholder has no scope of its own');
    });

    testWidgets('a radio with a scope of its own has no bandscope adjustment, nor an empty More details', (tester) async {
      // A Flex streams a panadapter apart from its front panel: nothing HaLo
      // does to it shows on the radio, so there is no choice to offer. With
      // no key either, More details would open onto nothing.
      final node = await services.cat.addNode(typeKey: 'flexradio-tcp', name: 'Shack Flex', config: {'host': 'flex.invalid', 'port': 4992});
      await tester.runAsync(() => services.cat.disconnect(node.uuid));
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();

      expect(find.text('More details'), findsNothing);
      expect(find.text('Automatically adjust bandscope', skipOffstage: false), findsNothing);
    });

    testWidgets('the CW key sits beside the antenna when it is tracked, and under More details when it is not', (tester) async {
      // A key logged with every QSO changes as often as the antenna does; one
      // that is not is set once, and folded away with the rest.
      await services.cat.addNode(typeKey: 'key-none', name: 'Paddle');
      await tester.pumpWidget(wrap(StationPanel(services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      expect(find.text('CW Keying'), findsNothing, reason: 'folded until More details opens');
      await openMoreDetails(tester);
      expect(find.text('CW Keying'), findsOneWidget);

      await services.settings.setTrackStationInfo(true);
      await services.settings.setStationInfoTrackedFields({'rig', 'key'});
      await tester.pumpWidget(wrap(StationPanel(key: UniqueKey(), services: services, compact: true, onMoreSettings: () {})));
      await tester.pumpAndSettle();
      expect(find.text('CW Keying'), findsOneWidget, reason: 'out of the fold, with nothing opened');
    });
  });

  testWidgets('an inventory radio says why its plug cannot connect, and is silent when there is nothing to say', (tester) async {
    // The inventory's plug connects radios that are not the current one,
    // whose failures show nowhere else: ErrorPolicy keeps an unreachable
    // radio off the screen because its row says so.
    final cat = services.cat;
    await cat.addNode(typeKey: 'kenwood-serial', name: 'Spare Rig');
    final failing = await cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Dead Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, 'placeholderFailConnect': true},
    );
    final main = await cat.addNode(typeKey: 'placeholder-radio', name: 'Main Rig', config: placeholderRadioModel.variants.single.defaultConfig);
    await tester.runAsync(() => cat.disconnect(main.uuid));
    await tester.runAsync(() => cat.connect(failing.uuid));
    expect(cat.stateFor(failing.uuid).status, EquipmentStatus.error, reason: 'sanity: the connect failed');

    await tester.pumpWidget(wrap(StationPanel(services: services)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 transceivers'));
    await tester.pumpAndSettle();

    expect(find.text('Not configured'), findsOneWidget, reason: "Spare Rig's row: why its plug is disabled");
    expect(find.text(cat.stateFor(failing.uuid).error!), findsOneWidget, reason: "Dead Rig's row: why its connect failed");
    final mainRow = find.ancestor(of: find.text('Main Rig').last, matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(mainRow).subtitle, isNull, reason: 'nothing to say, so the name centres');
  });

  testWidgets('every plug lines up in the trailing margin, the current transceiver\'s and the inventory\'s', (tester) async {
    // The plugs sit in the margin, not at the end of each row's text: a plug
    // at the end of a row moves with whatever that row says, and two rows
    // for the same radio put its plug in two places.
    final cat = services.cat;
    for (final name in ['Rig A', 'Rig B']) {
      final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => cat.disconnect(node.uuid));
    }
    await tester.pumpWidget(wrap(StationPanel(services: services)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 transceivers'));
    await tester.pumpAndSettle();

    final plugs = find.byIcon(MdiIcons.powerPlugOff);
    expect(plugs, findsNWidgets(3), reason: 'the current row, and each inventory radio');
    final lefts = {for (var i = 0; i < 3; i++) tester.getRect(plugs.at(i)).left};
    expect(lefts, hasLength(1));
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
