// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Phone Keyer dialog, with and without a radio that can play. What
// is defended: the rows are the RADIO's memories when one is on (its count,
// not the label count), the buttons act on CatService and follow what it
// reports, and with no radio the labels stay editable while the buttons
// are gone — a label is worth setting before the rig is on the desk.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/voice_messages_dialog.dart';

import '../support/halo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices();
    final settings = harness.settings;
    services = harness.services;
    await settings.setExperimentEnabled('keyer', true);
  });

  Future<void> connectPlaceholder(WidgetTester tester, {bool records = true}) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, if (!records) 'placeholderNoVoiceRecording': true},
    );
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.canPlayVoice, isTrue, reason: 'sanity');
  }

  Widget host() => TranslationProvider(
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => showVoiceMessagesDialog(context, services), child: const Text('open')),
        ),
      ),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('with no radio: every label, no buttons, and a line saying why', (tester) async {
    await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
    await open(tester);
    expect(find.text('Phone Keyer'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(SettingsService.voiceMessageCount));
    expect(find.textContaining('CQ POTA'), findsOneWidget);
    expect(find.byIcon(MdiIcons.play), findsNothing);
    expect(find.text('Connect a radio with a voice keyer to play or record from here.'), findsOneWidget);
  });

  testWidgets('a row edits its label, and nothing else — the audio is in the radio', (tester) async {
    await open(tester);
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Voice memory (3)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: 'a label, and no message field beside it');
    await tester.enterText(find.byType(TextField), 'Exchange');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.settings.voiceMessageLabel(3), 'Exchange');
    expect(find.textContaining('Exchange'), findsOneWidget, reason: 'the list behind shows it');
  });

  /// The list names the memories; everything one DOES to a memory lives in
  /// its own dialog, which is where these tests go.
  Future<void> openMemory(WidgetTester tester, int n) async {
    await tester.tap(find.byType(ListTile).at(n - 1));
    await tester.pumpAndSettle();
  }

  testWidgets('with the placeholder radio: its memories, and no buttons on the rows', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    expect(find.byType(ListTile), findsNWidgets(placeholderVoiceMemoryCount));
    // The rows are names and lengths. A Play on each was one tap from the
    // air, in a list an operator opens to RENAME things.
    expect(find.byIcon(MdiIcons.play), findsNothing);
    expect(find.byIcon(MdiIcons.recordCircleOutline), findsNothing);
    expect(find.text('Unknown length'), findsNWidgets(placeholderVoiceMemoryCount));
    expect(find.textContaining('record the memories on the radio'), findsNothing);
  });

  testWidgets('a radio whose CAT cannot record says so where Record is, not under the list', (tester) async {
    // Every Icom: `0x28` plays a memory, and nothing in CI-V records one.
    await connectPlaceholder(tester, records: false);
    await open(tester);
    // The trap this test exists for: explaining an absent action somewhere
    // other than where the operator looks for it. Recording moved into the
    // memory's dialog; the sentence has to follow it.
    expect(find.textContaining('record the memories on the radio'), findsNothing);

    await openMemory(tester, 2);
    expect(find.textContaining('record the memories on the radio'), findsOneWidget);
    // Disabled, not absent: absent, recording reads as something the APP
    // does not do rather than something this RADIO does not.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Record')).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Play')).onPressed, isNotNull);
  });

  testWidgets('the memory dialog plays it: Play becomes Stop, and the length is measured off the play', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await openMemory(tester, 3);
    // The row behind it says the same thing, hence findsWidgets.
    expect(find.text('Unknown length'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    expect(services.cat.voiceActivity.value, const VoiceActivity(memory: 3));
    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    // Record is disabled while the radio is busy with anything.
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Record')).onPressed, isNull);

    // The placeholder's pretend playback ends on its own, and the play is
    // what measures the memory — nothing anywhere asks for a measurement.
    await tester.pump(placeholderVoicePlayDuration + const Duration(milliseconds: 100));
    expect(services.cat.voiceActivity.value, isNull);
    expect(services.settings.voiceMessageDuration(3), greaterThan(0));
    await tester.pump();
    // Shown to a tenth, because the measurement has milliseconds in it.
    expect(find.textContaining(RegExp(r'^\d+\.\d s$')), findsWidgets);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a play the operator stops is not a measurement', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await openMemory(tester, 3);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pump();
    // The trap: timing a play that was cut short. Stored, it would pace
    // every later bar for that memory to finish early.
    expect(services.settings.voiceMessageDuration(3), 0);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('the memory dialog records: Record starts one that only Stop ends', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await openMemory(tester, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Record'));
    await tester.pump();
    expect(services.cat.voiceActivity.value, const VoiceActivity(memory: 2, recording: true));
    // Longer than a pretend playback: a recording has no natural end.
    await tester.pump(placeholderVoicePlayDuration * 3);
    expect(services.cat.voiceActivity.value, const VoiceActivity(memory: 2, recording: true));
    await tester.tap(find.widgetWithText(FilledButton, 'Stop'));
    await tester.pump();
    expect(services.cat.voiceActivity.value, isNull);
    // A recording times how long the operator held it, which is not the
    // memory's length.
    expect(services.settings.voiceMessageDuration(2), 0);
    await tester.pump(const Duration(seconds: 31));
  });
}
