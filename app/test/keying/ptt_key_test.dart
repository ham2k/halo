// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// ['] PTT through the operation view (docs/design/cat.md § PTT): the key
// handler, the draft's mode it reads, the radio at the end of it — and where
// ['] is PTT and where it is a character (key_bindings.dart's
// fieldTakesKey).
//
// The radio tests run a placeholder with no voice memories, on a station with
// no CW messages: ['] needs the draft's mode, and a view that tracked the
// draft only for the keyers would never know it was in a Phone mode there, so
// the key would do nothing.
//
// The field tests ask the REAL logging fields rather than hand-built ones:
// the answer comes from each field's own formatters, and a field whose filter
// changed — or a call field that stopped relaxing its filter for a command —
// would pass any test that rebuilt the formatters itself.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons, fieldTakesKey;
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/driver.dart' show voiceMemoriesConfigKey;
import 'package:ham2k_logger/services/cat/equipment.dart' show kCategoryKey;
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/cat/main_vfo.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

void main() {
  /// The key a keyboard reports for ['], found from the character rather than
  /// named: `LogicalKeyboardKey.quote` is the DOUBLE quote, and a handler and
  /// a test that both named it would agree with each other and miss every
  /// real ['].
  final apostrophe = LogicalKeyboardKey.findKeyByKeyId("'".codeUnitAt(0))!;

  /// ['] as a US keyboard in a browser reports it: that logical key, on the
  /// physical Quote key, typing the character.
  Future<void> pressApostrophe(WidgetTester tester) => tester.sendKeyEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'");

  bool quoteIsPtt() => !fieldTakesKey(FocusManager.instance.primaryFocus?.context, "'");

  Future<HaLoServices> pumpOperation(
    WidgetTester tester, {
    Map<String, dynamic> stubs = const {},
    bool showState = false,
    String? radioMode,
    bool memories = false,
    bool pttOn = true,
  }) async {
    final HaLoHarness(:services, :settings) = await makeHaLoServices(stubs: stubs);
    await settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    if (showState || radioMode != null) await settings.setShowStateField(true);
    if (radioMode != null) {
      await settings.setExperimentEnabled('keyer', true);
      await settings.setSettingValue(SettingsService.radioGroup, 'pttKey', pttOn);
      for (var n = 1; n <= SettingsService.cwMessageCount; n++) {
        await settings.setCwMessage(n, '');
      }
      final node = await services.cat.addNode(
        typeKey: 'placeholder-radio',
        name: 'Bench Rig',
        config: {...placeholderRadioModel.variants.single.defaultConfig, if (!memories) voiceMemoriesConfigKey: 0},
      );
      await tester.runAsync(() => services.cat.connect(node.uuid));
      services.radio.setVfo('vfoA', freq: 14250, mode: radioMode);
    }
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return services;
  }

  /// The view's drift subscriptions schedule their cleanup on a timer, which
  /// the framework reports as a leak unless it is allowed to run — and so do
  /// the radio's, so it is disconnected first.
  Future<void> unmount(WidgetTester tester, HaLoServices services) async {
    await tester.runAsync(() async {
      for (final node in services.cat.nodes) {
        await services.cat.disconnect(node.uuid);
      }
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> focusField(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(TextField, label));
    await tester.pump();
  }

  group('the radio', () {
    testWidgets("in a Phone mode ['] keys the radio, and ['] again unkeys it", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      expect(services.cat.canPlayVoice, isFalse, reason: 'sanity: nothing but PTT asks for the draft');
      await focusField(tester, t.loggingControls.theirCall);

      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('Escape unkeys it too', (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);

      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse, reason: 'Escape stops everything that transmits, and a held key is the first of them');

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("a held key drops on ['] even where ['] would be typed", (tester) async {
      // Every input reads as a command waiting for free text, as NOTE does.
      final services = await pumpOperation(
        tester,
        radioMode: 'USB',
        stubs: {
          'command:*:interpret': [
            {
              'key': 'test',
              'ok': true,
              'value': {'expectsParams': true, 'mixedCase': true, 'describe': 'Note'},
            },
          ],
        },
      );
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'NOTE ');
      await tester.pumpAndSettle();
      expect(quoteIsPtt(), isFalse, reason: 'sanity: here a free [\'] would be typed');
      // The operator who keyed and then started a note still has the
      // transmitter on; the key that put it there has to take it off.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("['] drops a held key from a dialog over the view", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      final navigator = Navigator.of(tester.element(find.byType(OperationView)));
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(OperationView)),
          builder: (_) => const AlertDialog(content: TextField()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)));
      await tester.pump();
      // The view is no longer the front route, so no other key of the view's
      // reaches it — but the transmitter is still on.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      navigator.pop();
      await tester.pumpAndSettle();
      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('Escape drops a held key from a dialog over the view too', (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(OperationView)),
          builder: (_) => const AlertDialog(content: TextField()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      // The dialog took its Escape as well, and closed: the operator reaching
      // for Escape with the transmitter on means both.
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("with a second operation over the first, ['] unkeys and stays unkeyed", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      final second = await services.operations.create(stationCall: 'KI2D');
      unawaited(
        Navigator.of(tester.element(find.byType(OperationView))).push(
          MaterialPageRoute<void>(
            builder: (_) => OperationView(services: services, operationUuid: second.uuid),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, t.loggingControls.theirCall).last);
      await tester.pump();
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      // One handler for the station: two views each with their own would have
      // the one behind unkey and the one in front key again on the same press.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("['] ends a voice CQ repeat, and the memory playing, before it keys", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB', memories: true);
      await services.settings.setVoiceRepeat(true);
      await services.settings.setVoiceRepeatCooldown(5);
      services.cat.playVoiceMemory(1);
      await tester.pump();
      expect(services.cat.keyerRepeatActive.value, isTrue, reason: 'sanity: a CQ is repeating');
      await focusField(tester, t.loggingControls.theirCall);

      await pressApostrophe(tester);
      await tester.pump();
      // The operator answering a CQ with their own voice: a repeat left armed
      // would play the CQ over them when its wait ran out.
      expect(services.cat.keyerRepeatActive.value, isFalse);
      expect(services.cat.voiceActivity.value, isNull);
      expect(services.cat.pttKeys.held.value, isTrue);
      expect(services.cat.radio1IsTransmitting, isTrue);

      await pressApostrophe(tester);
      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("a voice memory on the radio the app keyed takes the transmitter over", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB', memories: true);
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.pttKeys.held.value, isTrue);

      services.cat.playVoiceMemory(1, repeat: false);
      await tester.pump();
      // Left held, the key would outlive the memory — and a radio whose memory
      // unkeys it when it ends (the FT-891's TX0) would drop it mid-over.
      expect(services.cat.pttKeys.held.value, isFalse);
      expect(services.cat.voiceActivity.value, isNotNull);

      services.cat.stopVoice();
      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('turning the setting on with the operation open takes effect at once', (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB', pttOn: false);
      await focusField(tester, t.loggingControls.theirCall);
      await services.settings.setSettingValue(SettingsService.radioGroup, 'pttKey', true);
      await tester.pumpAndSettle();
      // Nothing else asks this station for the draft's mode (no CW messages,
      // no voice memories), so the view has to notice the setting itself.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      await pressApostrophe(tester);
      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("a key held when the operation closes is still dropped by [']", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      expect(services.cat.radio1IsTransmitting, isTrue, reason: 'closing the view is not an unkey');
      await pressApostrophe(tester);
      expect(services.cat.pttKeys.held.value, isFalse, reason: 'with no view left to key from, the key is still the operator\'s to drop');

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    group('with two radios', () {
      Future<({HaLoServices services, String a, String b})> twoRadios(WidgetTester tester) async {
        final services = await pumpOperation(tester, radioMode: 'USB');
        final a = services.cat.localRadio1!;
        final b = await services.cat.addNode(typeKey: 'placeholder-radio', name: 'Second Rig', config: placeholderRadioModel.variants.single.defaultConfig);
        await tester.runAsync(() => services.cat.connect(b.uuid));
        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(a)));
        services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
        await tester.pumpAndSettle();
        await focusField(tester, t.loggingControls.theirCall);
        return (services: services, a: a, b: b.uuid);
      }

      testWidgets("the key stays with the radio it keyed when Main VFO moves, and ['] still drops it", (tester) async {
        final (:services, :a, :b) = await twoRadios(tester);
        await pressApostrophe(tester);
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue);

        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue, reason: 'moving the role is not an unkey');
        // The key belongs to the radio, so the press that drops it reaches
        // that radio wherever Main VFO points now.
        await pressApostrophe(tester);
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isFalse);
        expect(services.cat.stateFor(b).telemetry.transmitting, isNot(isTrue));

        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets('a voice memory on one radio first unkeys the other: one transmitter at a time', (tester) async {
        final (:services, :a, :b) = await twoRadios(tester);
        await pressApostrophe(tester);
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue);

        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        services.cat.playVoiceMemory(1, repeat: false);
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isFalse);
        expect(services.cat.pttKeys.held.value, isFalse);
        expect(services.cat.stateFor(b).telemetry.transmitting, isTrue, reason: 'sanity: the memory is playing on B');

        services.cat.stopVoice();
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets('a CW message on one radio first unkeys the other', (tester) async {
        final (:services, :a, :b) = await twoRadios(tester);
        await pressApostrophe(tester);
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue);

        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        expect(services.cat.canKeyCw, isTrue, reason: "sanity: B's CAT keys CW");
        services.cat.sendCw('TEST');
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isFalse);

        services.cat.stopCw();
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets("a CW message quiets every radio but the one whose keyer sends it", (tester) async {
        // B is Main VFO, with A's own CAT keyer as its key in use: the CW goes
        // out on A, so B's memory is what has to stop.
        final (:services, :a, :b) = await twoRadios(tester);
        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        await tester.runAsync(() => services.cat.setDesignated(kCategoryKey, a));
        expect(services.cat.canKeyCw, isTrue, reason: "sanity: A's CAT keys CW for B");
        services.cat.playVoiceMemory(1, repeat: false);
        await tester.pump();
        expect(services.cat.stateFor(b).telemetry.transmitting, isTrue, reason: 'sanity: the memory is playing on B');

        services.cat.sendCw('TEST');
        await tester.pump();
        expect(services.cat.stateFor(b).telemetry.transmitting, isFalse, reason: 'B would go on playing while A sends');

        services.cat.stopCw();
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets("a key left on a radio that is no longer Main VFO still shows", (tester) async {
        final (:services, :a, :b) = await twoRadios(tester);
        expect(find.byIcon(MdiIcons.circle), findsNothing, reason: 'sanity: nothing on the air yet');
        await pressApostrophe(tester);
        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        await tester.pump();
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue);
        // ['] drops it from anywhere; the operator has to be able to see
        // there is something to drop.
        expect(find.byIcon(MdiIcons.circle), findsWidgets);

        await pressApostrophe(tester);
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets("a memory another radio's message cuts short is not timed, and its CQ does not come back", (tester) async {
        // B is Main VFO, with A's own CAT keyer as its key in use: CW goes out
        // on A and quiets B, whose memory 1 is a repeating CQ.
        final (:services, :a, :b) = await twoRadios(tester);
        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        await tester.runAsync(() => services.cat.setDesignated(kCategoryKey, a));
        await services.settings.setVoiceRepeat(true);
        await services.settings.setVoiceRepeatCooldown(5);
        final lengthBefore = services.cat.voiceMessageDuration(1);
        services.cat.playVoiceMemory(1);
        await tester.pump(const Duration(seconds: 1));
        expect(services.cat.keyerRepeatActive.value, isTrue, reason: 'sanity: a CQ is repeating on B');

        services.cat.sendCw('TEST');
        await tester.pump();
        expect(services.cat.stateFor(b).telemetry.transmitting, isFalse, reason: 'sanity: B was quieted');
        // Left armed, the CQ would play again after its wait and take the
        // transmitter back from A's message.
        expect(services.cat.keyerRepeatActive.value, isFalse);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        expect(services.cat.voiceMessageDuration(1), lengthBefore, reason: 'a second of a cut-short memory stored as its length');

        services.cat.stopCw();
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));

      testWidgets('keying one radio first stops a voice memory playing on the other', (tester) async {
        // B has the memories; A, Main VFO again by the time ['] is pressed,
        // has none.
        final (:services, :a, :b) = await twoRadios(tester);
        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(b)));
        services.cat.playVoiceMemory(1, repeat: false);
        await tester.pump();
        expect(services.cat.stateFor(b).telemetry.transmitting, isTrue, reason: 'sanity: the memory is playing on B');

        await tester.runAsync(() => services.cat.setRadio1(LocalRadio(a)));
        services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
        await tester.pumpAndSettle();
        await focusField(tester, t.loggingControls.theirCall);
        await pressApostrophe(tester);
        await tester.pump();
        expect(services.cat.stateFor(b).telemetry.transmitting, isFalse, reason: 'radio B would go on transmitting its memory while A keys');
        expect(services.cat.stateFor(a).telemetry.transmitting, isTrue);

        await pressApostrophe(tester);
        await unmount(tester, services);
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    testWidgets("after a reconnect the first ['] keys, rather than unkeying the old session", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      final rig = services.cat.localRadio1!;
      await focusField(tester, t.loggingControls.theirCall);
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      // The old session's teardown unkeys the radio itself. Asked before the
      // reconnect: the placeholder announces it is receiving as it starts,
      // which would clear a stale key by itself — a radio that waits to be
      // asked would not.
      await tester.runAsync(() => services.cat.disconnect(rig));
      expect(services.cat.pttKeys.held.value, isFalse);
      await tester.runAsync(() => services.cat.connect(rig));
      services.radio.setVfo('vfoA', freq: 14250, mode: 'USB');
      await tester.pumpAndSettle();
      expect(services.cat.pttKeys.held.value, isFalse);
      await focusField(tester, t.loggingControls.theirCall);
      // A key still "held" for the closed session would swallow this press
      // as an unkey, and the operator would have to press twice to talk.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("holding ['] down keeps its repeats out of the field", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.qsoEditForm.theirState);
      await tester.sendKeyDownEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'");
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);
      // Unclaimed, each repeat would be typed into the State field while the
      // operator holds the key to talk.
      expect(await tester.sendKeyRepeatEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: "'"), isTrue);
      await tester.sendKeyUpEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote);
      expect(services.cat.radio1IsTransmitting, isTrue, reason: 'the release of the key that keyed is not a second press');

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("['] typed with Shift held still keys", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);
      // On a German or Swiss layout ['] is a shifted key, and the browser
      // already reports the character it typed.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: 'web');
      await pressApostrophe(tester);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: 'web');
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isTrue);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets('a double quote keys nothing, though it is the same key', (tester) async {
      final services = await pumpOperation(tester, radioMode: 'USB');
      await focusField(tester, t.loggingControls.theirCall);
      // US Shift+['] types ["]. A native platform reports it under the
      // unshifted key's name, so only the character tells them apart.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: 'web');
      await tester.sendKeyEvent(apostrophe, platform: 'web', physicalKey: PhysicalKeyboardKey.quote, character: '"');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: 'web');
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));

    testWidgets("outside a Phone mode ['] keys nothing", (tester) async {
      final services = await pumpOperation(tester, radioMode: 'CW');
      await focusField(tester, t.loggingControls.theirCall);

      // A carrier with nobody talking into it, on a CW contact.
      await pressApostrophe(tester);
      await tester.pump();
      expect(services.cat.radio1IsTransmitting, isFalse);

      await unmount(tester, services);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('where the keyboard is', () {
    testWidgets("in the main fields ['] keys PTT, whatever the field would accept", (tester) async {
      final services = await pumpOperation(tester, showState: true);

      await focusField(tester, t.loggingControls.theirCall);
      expect(quoteIsPtt(), isTrue, reason: 'the call field in callsign mode');
      await focusField(tester, t.loggingControls.sent);
      expect(quoteIsPtt(), isTrue, reason: 'a signal report');
      // State has no character filter. Asked of its formatters alone it would
      // keep the ['], and the operator working a contact from it could not talk.
      await focusField(tester, t.qsoEditForm.theirState);
      expect(quoteIsPtt(), isTrue, reason: 'an unfiltered exchange field');

      await unmount(tester, services);
    });

    testWidgets("the call field reading a command that takes free text keeps [']", (tester) async {
      // Every input reads as a command waiting for free text, as NOTE does.
      final services = await pumpOperation(
        tester,
        stubs: {
          'command:*:interpret': [
            {
              'key': 'test',
              'ok': true,
              'value': {'expectsParams': true, 'mixedCase': true, 'describe': 'Note'},
            },
          ],
        },
      );
      await focusField(tester, t.loggingControls.theirCall);
      await tester.enterText(find.widgetWithText(TextField, t.loggingControls.theirCall), 'NOTE ');
      await tester.pumpAndSettle();

      // Without this the operator's "can't" in a note keys the transmitter.
      expect(quoteIsPtt(), isFalse);

      await unmount(tester, services);
    });

    testWidgets("outside the logging fields a text field keeps ['] whatever it filters", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Column(
              children: [
                TextField(key: const Key('digits'), inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const Focus(child: SizedBox(key: Key('not-a-field'), width: 10, height: 10)),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('digits')));
      await tester.pump();
      // A search box or a dialog's number is not where an operator keys a
      // radio, and a key that sometimes typed and sometimes transmitted in
      // the same field would be worse than one that never keys there.
      expect(quoteIsPtt(), isFalse);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(quoteIsPtt(), isTrue, reason: 'with no field focused, the key has nothing else to mean');
    });
  });
}
