// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The keyer's chords, as the operation view hears them: ⌥1-⌥8 for the
// function keys a laptop or tablet keyboard lacks, and ⌥K for keyboard mode.
// Against a real CatService with the placeholder radio in CW, which runs the
// real send queue, so what is asserted is what the queue was handed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/cat/equipment_registry.dart';
import 'package:ham2k_logger/services/extension_service.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/views/keyer_area.dart';
import 'package:ham2k_logger/views/operation_view.dart';

import '../support/halo_test_support.dart';

/// Stands in for the `template` hook without booting a JS engine.
class _TemplateExtensions extends ExtensionService {
  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<String?> renderTemplate(
    String template, {
    Map<String, dynamic>? operation,
    Map<String, dynamic>? qso,
    int? qsoCount,
    Map<String, dynamic>? log,
    Map<String, dynamic>? keyer,
  }) async => template;
}

void main() {
  late HaLoServices services;

  setUp(() async {
    final harness = await makeHaLoServices(extensions: _TemplateExtensions());
    services = harness.services;
    await harness.settings.setExperimentEnabled('gato', true);
    await harness.settings.setExperimentEnabled('keyer', true);
    await harness.settings.setProfileOperatorCall(SettingsService.defaultProfileId, 'KI2D');
    await harness.settings.recordOnboardingShown(OnboardingFlows.operationSheet);
    await harness.settings.setCwMessage(1, 'CQ TEST');
    await harness.settings.setCwMessage(3, 'TU');
  });

  Future<void> pumpOperation(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // In CW, so the draft keys CW rather than playing a voice memory.
    final node = await services.cat.addNode(
      typeKey: 'placeholder-radio',
      name: 'Bench Rig',
      config: {...placeholderRadioModel.variants.single.defaultConfig, 'placeholderMode': 'CW'},
    );
    await tester.runAsync(() => services.cat.connect(node.uuid));
    addTearDown(() => services.cat.disconnect(node.uuid));
    final operation = await services.operations.create(stationCall: 'KI2D');
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: OperationView(services: services, operationUuid: operation.uuid),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    services.cat.stopCw();
    await tester.pump(const Duration(seconds: 62));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder typingField() => find.descendant(of: find.byType(KeyerArea), matching: find.byType(TextField));

  testWidgets('⌥1-⌥8 key the message the matching function key would', (tester) async {
    await pumpOperation(tester);
    await chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.digit3);
    expect(services.cat.cwProgress.value?.text, 'TU');
    await unmount(tester);
  });

  testWidgets('by the physical key: on a Mac, Option makes the digit another character', (tester) async {
    await pumpOperation(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft, platform: 'web');
    // What a browser on a Mac reports for ⌥1: the character '¡', on the 1 key.
    await tester.sendKeyEvent(const LogicalKeyboardKey(0x000000a1), platform: 'web', physicalKey: PhysicalKeyboardKey.digit1, character: '¡');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft, platform: 'web');
    await tester.pump(const Duration(milliseconds: 100));
    expect(services.cat.cwProgress.value?.text, 'CQ TEST');
    await unmount(tester);
  });

  testWidgets('a digit with another modifier, or none, keys nothing', (tester) async {
    // The trap: reading the digit alone. A bare 1 is a character typed into
    // a field, and ⌘1 / ⌃1 belong to the browser and the desktop.
    await pumpOperation(tester);
    await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.digit1);
    await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(services.cat.cwSending, isFalse);
    await unmount(tester);
  });

  testWidgets('⌥K turns keyboard mode on, and again off', (tester) async {
    await pumpOperation(tester);
    await chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(milliseconds: 300));
    expect(typingField(), findsOneWidget, reason: 'the strip comes out for it, and the field takes the keyboard');
    await chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(milliseconds: 300));
    expect(typingField(), findsNothing);
    await unmount(tester);
  });

  testWidgets('⌥K by the physical key: on a Mac, Option makes K a \'˚\'', (tester) async {
    await pumpOperation(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft, platform: 'web');
    await tester.sendKeyEvent(const LogicalKeyboardKey(0x000002da), platform: 'web', physicalKey: PhysicalKeyboardKey.keyK, character: '˚');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft, platform: 'web');
    await tester.pump(const Duration(milliseconds: 300));
    expect(typingField(), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('⌥-digits in free text are characters, not messages', (tester) async {
    // On a Spanish Mac layout ⌥2 is '@', on a German one ⌥5-⌥8 are brackets
    // and bars: typed into a note, they must not key a message instead.
    // Keyboard mode's own field is free text too (a sendable '@').
    await pumpOperation(tester);
    await chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(milliseconds: 300));
    expect(typingField(), findsOneWidget, reason: 'sanity: the focus is in keyboard mode\'s field');
    await chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.digit3);
    expect(services.cat.cwSending, isFalse);
    await unmount(tester);
  });

  testWidgets('⌘K is left to the command dialog', (tester) async {
    await pumpOperation(tester);
    final before = services.cat.keyboardModeRequests.value;
    await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyK);
    expect(services.cat.keyboardModeRequests.value, before);
    await unmount(tester);
  });
}
