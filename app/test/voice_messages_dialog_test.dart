// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Voice Messages dialog, with and without a radio that can play. What
// is defended: the rows are the RADIO's memories when one is on (its count,
// not the label count), the buttons act on CatService and follow what it
// reports, and with no radio the labels stay editable while the buttons
// are gone — a label is worth setting before the rig is on the desk.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/i18n/strings.g.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/voice_messages_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HaLoServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService(await SharedPreferences.getInstance());
    final db = HaLoDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    services = HaLoServices(db, settings);
    await settings.setExperimentEnabled('keyer', true);
  });

  Future<void> connectPlaceholder(WidgetTester tester) async {
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: placeholderRadioModel.variants.single.defaultConfig,
    );
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    expect(services.cat.canPlayVoice, isTrue, reason: 'sanity');
  }

  Widget host() => TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showVoiceMessagesDialog(context, services),
                child: const Text('open'),
              ),
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
    expect(find.text('Voice Messages'), findsOneWidget);
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

  testWidgets('with the placeholder radio: its memories, Play starts one and turns into Stop', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    expect(find.byType(ListTile), findsNWidgets(placeholderVoiceMemoryCount));
    expect(find.byIcon(MdiIcons.play), findsNWidgets(placeholderVoiceMemoryCount));
    expect(find.byIcon(MdiIcons.recordCircleOutline), findsNWidgets(placeholderVoiceMemoryCount),
        reason: 'the placeholder records too');
    expect(find.textContaining('front panel'), findsNothing);

    await tester.tap(find.byIcon(MdiIcons.play).at(2));
    await tester.pump();
    expect(services.cat.voiceActivity.value, const VoiceActivity(memory: 3));
    expect(find.text('Playing…'), findsOneWidget);
    expect(find.byIcon(MdiIcons.stop), findsOneWidget, reason: 'only the playing row offers a stop');
    // The other rows' Play is disabled while one plays — one memory at a time.
    final otherPlay = tester.widget<IconButton>(find.ancestor(of: find.byIcon(MdiIcons.play).first, matching: find.byType(IconButton)));
    expect(otherPlay.onPressed, isNull);

    await tester.tap(find.byIcon(MdiIcons.stop));
    await tester.pump();
    expect(services.cat.voiceActivity.value, isNull);
    expect(find.text('Playing…'), findsNothing);
    // Past the silence watch the report armed (cat_service.dart's
    // _staleAfter), which is otherwise a timer left pending.
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('Record starts a recording that only Stop ends', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await tester.tap(find.byIcon(MdiIcons.recordCircleOutline).at(1));
    await tester.pump();
    expect(services.cat.voiceActivity.value, const VoiceActivity(memory: 2, recording: true));
    expect(find.text('Recording…'), findsOneWidget);
    // Longer than a pretend playback: a recording has no natural end.
    await tester.pump(placeholderVoicePlayDuration * 3);
    expect(find.text('Recording…'), findsOneWidget);
    await tester.tap(find.byIcon(MdiIcons.stop));
    await tester.pump();
    expect(services.cat.voiceActivity.value, isNull);
    // Past the silence watch the report armed (cat_service.dart's
    // _staleAfter), which is otherwise a timer left pending.
    await tester.pump(const Duration(seconds: 31));
  });
}
