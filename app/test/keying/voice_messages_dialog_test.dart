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
import 'package:ham2k_logger/services/cat/cat_service.dart';
import 'package:ham2k_logger/services/cat/driver.dart';
import 'package:ham2k_logger/services/cat/drivers/placeholder_radio_driver.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/voice_messages_dialog.dart';

import '../support/fake_voice_audio.dart';
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

  testWidgets('with no radio: every label, no buttons, and first of all a line saying why', (tester) async {
    await services.settings.setVoiceMessageLabel(2, 'CQ POTA');
    await open(tester);
    expect(find.text('Phone Keyer Messages'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(SettingsService.voiceMessageCount));
    expect(find.textContaining('CQ POTA'), findsOneWidget);
    expect(find.byIcon(MdiIcons.play), findsNothing);
    // Above the controls, not under the list: every control below does
    // nothing until it changes.
    final notice = find.text('Current radio does not support Phone messages');
    expect(notice, findsOneWidget);
    expect(tester.getTopLeft(notice).dy, lessThan(tester.getTopLeft(find.byType(ListTile).first).dy));
  });

  testWidgets('a row edits its label, and nothing else — the audio is in the radio', (tester) async {
    await open(tester);
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(HaloDialog, 'Voice memory 3'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: 'a label, and no message field beside it');
    await tester.enterText(find.byType(TextField), 'Exchange');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.settings.voiceMessageLabel(3), 'Exchange');
    expect(find.textContaining('Exchange'), findsOneWidget, reason: 'the list behind shows it');
  });

  testWidgets('a Save with nothing typed writes nothing over a name that changed underneath', (tester) async {
    // On a radio that names its own memories the field can open on a name
    // the radio has since replaced; saving it unedited would rename the slot
    // for every client of that radio.
    await services.settings.setVoiceMessageLabel(3, 'CQ');
    await open(tester);
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();
    await services.settings.setVoiceMessageLabel(3, 'Renamed elsewhere');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(services.settings.voiceMessageLabel(3), 'Renamed elsewhere');
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
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Play on Radio')).onPressed, isNotNull);
  });

  testWidgets('the memory dialog plays it: Play becomes Stop, and the length is measured off the play', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await openMemory(tester, 3);
    // The row behind it says the same thing, hence findsWidgets.
    expect(find.text('Unknown length'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Play on Radio'));
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

  // The trap: one radio's memories for both sets, so while radio A plays a
  // CQ the operator in set B sees A's memories playing, names A's, and a
  // Play here goes out on A.
  testWidgets("under SO2R it is the operator's radio's: its labels, its activity, and a Play on it", (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    final cat = services.cat;
    Future<String> rig(String name) async {
      final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => cat.connect(node.uuid));
      addTearDown(() => cat.disconnect(node.uuid));
      return node.uuid;
    }

    final left = await rig('Left Rig'), right = await rig('Right Rig');
    await cat.setRadio1(LocalRadio(left));
    await cat.setRadio2(right);
    await services.settings.setVoiceMessageLabel(2, 'CQ LEFT');
    await services.settings.setVoiceMessageLabel(2, 'CQ RIGHT', radio: 'B');
    cat.keyer('A').playVoiceMemory(2);
    await tester.pump();
    expect(cat.keyer('A').voiceActivity.value?.memory, 2, reason: 'sanity: radio A is playing memory 2');
    cat.noteOperatorRadio('B');

    await open(tester);
    expect(find.textContaining('CQ RIGHT'), findsOneWidget);
    expect(find.textContaining('CQ LEFT'), findsNothing);
    expect(find.text('Playing…'), findsNothing, reason: "Radio B's memory 2 is not the one on the air");

    await openMemory(tester, 3);
    await tester.tap(find.widgetWithText(FilledButton, 'Play on Radio'));
    await tester.pump();
    expect(cat.keyer('B').voiceActivity.value?.memory, 3, reason: 'a Play from set B plays on Radio B');
    expect(cat.keyer('A').voiceActivity.value, isNull, reason: "and takes the air from radio A's CQ");
    await tester.pump(const Duration(seconds: 31));
  });

  // The trap: the pick atop set B's pane being radio1's — or no pick at all,
  // leaving Radio B on its own memories whatever the operator wants of it.
  testWidgets("set B's pane carries Radio B's own Phone Keying pick", (tester) async {
    await services.settings.setExperimentEnabled('so2r', true);
    final cat = services.cat;
    Future<String> rig(String name) async {
      final node = await cat.addNode(typeKey: 'placeholder-radio', name: name, config: placeholderRadioModel.variants.single.defaultConfig);
      await tester.runAsync(() => cat.connect(node.uuid));
      addTearDown(() => cat.disconnect(node.uuid));
      return node.uuid;
    }

    final left = await rig('Left Rig'), right = await rig('Right Rig');
    await cat.setRadio1(LocalRadio(left));
    await cat.setRadio2(right);
    cat.noteOperatorRadio('B');

    await open(tester);
    expect(find.text('B: Phone Keying'), findsOneWidget);
    expect(find.text('Memories in Right Rig'), findsOneWidget);

    await tester.tap(find.text('Memories in Right Rig'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
    expect(cat.keyer('B').voiceKeyingSource, VoiceKeyingSource.none);
    expect(cat.keyer('A').voiceKeyingSource, VoiceKeyingSource.radio, reason: "radio1's pick is untouched");
    expect(find.text('Phone keying is off'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('a play the operator stops is not a measurement', (tester) async {
    await connectPlaceholder(tester);
    await open(tester);
    await openMemory(tester, 3);
    await tester.tap(find.widgetWithText(FilledButton, 'Play on Radio'));
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

  group('on a computer that can play recordings', () {
    final cq = VoiceMessageSet.empty(id: 's1', name: 'CQ');
    late FakeVoiceAudio audio;

    setUp(() async {
      audio = FakeVoiceAudio();
      final harness = await makeHaLoServices(
        cat: (settings) => CatService(settings, voiceAudio: audio, voiceMessagesDirectory: () async => '/v'),
      );
      services = harness.services;
      await harness.settings.setExperimentEnabled('keyer', true);
      await harness.settings.setVoiceMessageSets([cq], active: VoiceMessageSet.defaultId);
    });

    /// The computer as Phone Keying's source, which is what offers the sets.
    Future<void> fromComputer(WidgetTester tester) async {
      await tester.runAsync(() => services.cat.selectVoiceKeyingSource(VoiceKeyingSource.computer));
      await tester.runAsync(pumpEventQueue);
    }

    IconButton setButton(WidgetTester tester, String name) =>
        tester.widget<IconButton>(find.ancestor(of: find.bySemanticsLabel(name), matching: find.byType(IconButton)));

    // Sets are recordings on this computer: offered while the computer
    // plays the messages, and never in the way of the radio's own memories,
    // which Phone Keying picks rather than this list.
    testWidgets('the sets are offered only while the computer plays the messages, the default first', (tester) async {
      await open(tester);
      expect(find.bySemanticsLabel('New Set'), findsNothing, reason: "the radio's own memories are not a set");
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      await fromComputer(tester);
      await open(tester);
      final picker = tester.widget<DropdownButton<String>>(find.byWidgetPredicate((widget) => widget is DropdownButton<String> && widget.items!.length == 2));
      expect([for (final item in picker.items!) (item.child as Text).data], ['Sound files on this computer', 'CQ']);
      expect(setButton(tester, 'New Set').onPressed, isNotNull);
    });

    // The default set is where sound files go before any set is made; gone,
    // the picker would have nothing between the radio and the sets an
    // operator has yet to make.
    testWidgets('the default set is neither renamed nor deleted', (tester) async {
      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(VoiceMessageSet.defaultId));
      await open(tester);
      expect(setButton(tester, 'Rename Set').onPressed, isNull);
      expect(setButton(tester, 'Delete Set').onPressed, isNull);
    });

    // The folder, not the file: opening a .wav plays it in whatever the
    // system opens sound files with, which is not what the button is for.
    testWidgets("Open File shows the message's folder, and only for a set of sound files", (tester) async {
      await connectPlaceholder(tester);
      await open(tester);
      await openMemory(tester, 2);
      expect(find.text('Open File'), findsNothing, reason: "the radio's own memories have no file");

      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(cq.id));
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Open File'));
      expect(audio.revealed, ['/v/s1/2.wav']);
    });

    // On Windows a file being listened to is held open, and the recording
    // cannot then be renamed over it: Record ends the listen first.
    testWidgets('Record stops a Listen to the same message before it starts', (tester) async {
      audio.lengths['/v/s1/2.wav'] = const Duration(seconds: 2);
      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(cq.id));
      await tester.runAsync(pumpEventQueue);
      await open(tester);
      await openMemory(tester, 2);
      await tester.tap(find.widgetWithText(FilledButton, 'Listen'));
      await tester.pump();
      expect(audio.listens.single.isPlaying, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Record'));
      await tester.pump();
      expect(audio.listens.single.stopped, isTrue);
      expect(audio.recordings.single.path, '/v/s1/2.wav.recording');
      services.cat.stopVoice();
      await tester.pump(const Duration(seconds: 2));
    });

    // Said with words, a message plays no recording of its own: one recorded
    // with the words still stored would never be heard, and a Cancel after
    // it must not leave them in its place.
    testWidgets('with words entered there is no Record, and recording in their place clears them', (tester) async {
      await services.settings.setExperimentEnabled('words', true);
      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(cq.id));
      await tester.runAsync(() => services.cat.keyer('A').setVoiceMessageTemplate(2, '{{ qso.call }} 59'));
      await tester.runAsync(pumpEventQueue);
      await open(tester);
      await openMemory(tester, 2);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Record')).onPressed, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Say with my words'), '');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Record'));
        await pumpEventQueue();
      });
      await tester.pump();
      expect(services.cat.keyer('A').voiceMessageTemplate(2), '');
      expect(audio.recordings.single.path, '/v/s1/2.wav.recording');
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(services.cat.keyer('A').voiceMessageTemplate(2), '', reason: 'a Cancel does not undo what a recording did');
      services.cat.stopVoice();
      await tester.pump(const Duration(seconds: 2));
    });

    // An .m4a renamed to .wav reads as not recorded otherwise, and the
    // operator records over the file they put there.
    testWidgets("a file that will not play is said to be one, where its length would be", (tester) async {
      audio.unreadable.add('/v/s1/3.wav');
      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(cq.id));
      await tester.runAsync(pumpEventQueue);
      await open(tester);
      expect(find.text("Can't play this file"), findsOneWidget);
      expect(find.text('Not recorded'), findsNWidgets(SettingsService.voiceMessageCount - 1));
    });

    // Deleting a set takes its recordings, and nothing is a draft here to
    // Cancel back to.
    testWidgets('deleting a set asks first', (tester) async {
      await fromComputer(tester);
      await tester.runAsync(() => services.cat.selectVoiceMessageSet(cq.id));
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Delete Set'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(services.settings.voiceMessageSets, hasLength(2));

      await tester.tap(find.bySemanticsLabel('Delete Set'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect([for (final set in services.settings.voiceMessageSets) set.id], [VoiceMessageSet.defaultId]);
      expect(services.settings.voiceMessageSetId, VoiceMessageSet.defaultId);
    });
  });
}
