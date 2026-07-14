// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ham2k_logger/services/settings_service.dart';

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

    testWidgets('UiScale scales the whole subtree: children lay out in size/scale and paint scaled up', (tester) async {
      // The font-scale mechanism: everything under UiScale sees a MediaQuery
      // whose size is divided by the scale, and a fixed-size child paints back
      // up by the scale. A 400x400 box at scale 2.0 fills an 800x800 window.
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      late Size innerSize;
      late double reportedScale;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: UiScale(
              scale: 2.0,
              child: Builder(builder: (context) {
                innerSize = MediaQuery.sizeOf(context);
                reportedScale = UiScale.of(context);
                return const SizedBox(key: Key('box'), width: 400, height: 400);
              }),
            ),
          ),
        ),
      );

      // The subtree believes the screen is half the real size...
      expect(innerSize, const Size(400, 400));
      expect(reportedScale, 2.0);
      // ...and the 400-logical box paints at 800 physical (fills the window).
      expect(tester.getSize(find.byKey(const Key('box'))), const Size(400, 400));
      final rect = tester.getRect(find.byKey(const Key('box')));
      expect(rect.width, 800); // scaled up by 2.0 on screen
      expect(rect.height, 800);
    });

    testWidgets('UiScale at 1.0 is a pass-through', (tester) async {
      late double reportedScale;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: UiScale(
            scale: 1.0,
            child: Builder(builder: (context) {
              reportedScale = UiScale.of(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(reportedScale, 1.0);
      expect(find.byType(Transform), findsNothing); // no transform inserted
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
