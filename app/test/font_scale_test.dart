// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/settings_service.dart';
import 'package:ham2k_logger/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontScale Settings & Logic', () {
    test('FontScale factors are correct', () {
      expect(FontScale.smallest.scaleFactor, 0.70);
      expect(FontScale.smaller.scaleFactor, 0.85);
      expect(FontScale.normal.scaleFactor, 1.00);
      expect(FontScale.larger.scaleFactor, 1.20);
      expect(FontScale.largest.scaleFactor, 1.40);
    });

    test('SettingsService: default scale, updates, and persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      expect(settings.fontScale, FontScale.normal);

      int listenerCalls = 0;
      settings.addListener(() {
        listenerCalls++;
      });

      await settings.setFontScale(FontScale.larger);
      expect(settings.fontScale, FontScale.larger);
      expect(listenerCalls, 1);

      // Verify it persists in shared preferences
      final settingsReloaded = await SettingsService.load();
      expect(settingsReloaded.fontScale, FontScale.larger);
    });

    test('SettingsService: step-by-step increase/decrease helpers', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      expect(settings.fontScale, FontScale.normal); // index 2

      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.larger); // index 3

      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largest); // index 4

      // Increase again does nothing
      await settings.increaseFontScale();
      expect(settings.fontScale, FontScale.largest);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.larger);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.normal);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smaller);

      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallest);

      // Decrease again does nothing
      await settings.decreaseFontScale();
      expect(settings.fontScale, FontScale.smallest);
    });

    test('RelativeTextScaler scales correctly', () {
      const parentScaler = TextScaler.linear(1.5);
      const relativeScaler = RelativeTextScaler(parentScaler, 1.2);

      // ignore: deprecated_member_use
      expect(relativeScaler.textScaleFactor, 1.5 * 1.2);
      expect(relativeScaler.scale(10.0), 10.0 * 1.5 * 1.2);
    });
  });

  group('Keyboard Shortcuts Verification', () {
    testWidgets('Key events trigger font scale changes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsService.load();

      await tester.pumpWidget(KeyboardShortcutTestWidget(settings: settings));

      expect(settings.fontScale, FontScale.normal);

      // Simulate Cmd + =
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.larger);

      // Reset with Cmd + 0
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.normal);

      // Decrease with Cmd + -
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.smaller);

      // Decrease with Cmd + _ (LogicalKeyboardKey.underscore)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      HardwareKeyboard.instance.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.minus,
          logicalKey: LogicalKeyboardKey.underscore,
          timeStamp: Duration.zero,
        ),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(settings.fontScale, FontScale.smallest);
    });
  });
}

class KeyboardShortcutTestWidget extends StatefulWidget {
  final SettingsService settings;
  const KeyboardShortcutTestWidget({super.key, required this.settings});

  @override
  State<KeyboardShortcutTestWidget> createState() => _KeyboardShortcutTestWidgetState();
}

class _KeyboardShortcutTestWidgetState extends State<KeyboardShortcutTestWidget> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final hasModifier = isMetaPressed || isControlPressed;

    if (!hasModifier) return false;

    final key = event.logicalKey;
    final settings = widget.settings;

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      settings.increaseFontScale();
      return true;
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        key == LogicalKeyboardKey.underscore) {
      settings.decreaseFontScale();
      return true;
    } else if (key == LogicalKeyboardKey.digit0 ||
        key == LogicalKeyboardKey.numpad0) {
      settings.setFontScale(FontScale.normal);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
