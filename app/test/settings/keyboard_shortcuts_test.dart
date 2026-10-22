// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyboard Shortcuts through the real app (docs/design/keyboard-shortcuts.md):
// the experiment as the only thing that changes a key, keys bound to typed
// command text, and the editor taking a key from the command that had it.
// Driven through HaLoApp's own handler, since a handler copied into a test
// could not notice the app's one losing its bindings.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:ham2k_logger/config/release_notes.dart';
import 'package:ham2k_logger/config/tester_notes.dart';
import 'package:ham2k_logger/main.dart';
import 'package:ham2k_logger/services/extensions/extension_service.dart';
import 'package:ham2k_logger/services/key_bindings_service.dart';
import 'package:ham2k_logger/views/command_dialog.dart';
import 'package:ham2k_logger/views/settings/keyboard_shortcuts_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/halo_test_support.dart';

/// DEVMODE and CW run as they are, NOTE waits for its text, and nothing
/// else is a command.
class _Commands extends ExtensionService {
  final executed = <String>[];

  @override
  bool get ready => true;

  @override
  Future<void> start() async {}

  @override
  Future<List<Map<String, dynamic>>> getCommandCatalog() async => [
    {'command': 'DEVMODE', 'describe': 'Toggle developer mode'},
    {'command': 'NOTE', 'describe': 'Add a note', 'expectsParams': true},
  ];

  @override
  Future<Map<String, dynamic>?> interpretCommand(String input, [Map<String, dynamic>? operation, Map<String, dynamic>? qso, bool execute = false]) async {
    final text = input.trim().toUpperCase();
    if (text == 'DEVMODE') {
      if (execute) executed.add(text);
      return {'describe': 'Toggle developer mode?', 'confirm': 'Developer mode on', 'commands': const []};
    }
    if (text == 'CW') {
      if (execute) executed.add(text);
      return {'describe': 'Mode CW', 'confirm': 'Mode CW', 'commands': const []};
    }
    if (text == 'NOTE') return {'describe': 'Add a note', 'expectsParams': true};
    // Reads in the preview and fails as it runs, the way a hook that throws
    // does.
    if (text == 'BROKEN') return execute ? null : {'describe': 'Breaks'};
    return null;
  }
}

Future<({HaLoServices services, _Commands commands})> _boot(WidgetTester tester, {bool shortcuts = true}) async {
  SharedPreferences.setMockInitialValues({});
  setReleaseNotesForTesting(const []);
  setTesterNotesForTesting(const []);
  final commands = _Commands();
  final HaLoHarness(:services) = await makeHaLoServices(prefs: null, extensions: commands);
  await services.settings.setExperimentEnabled(keyBindingsExperiment, shortcuts);
  // The bindings are one value for the whole test process.
  addTearDown(() => keyBindings.value = LegacyKeyBindings());
  await tester.pumpWidget(TranslationProvider(child: HaLoApp(services: services)));
  await tester.pumpAndSettle();
  return (services: services, commands: commands);
}

Future<void> _press(WidgetTester tester, List<LogicalKeyboardKey> modifiers, LogicalKeyboardKey key) async {
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyEvent(key);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Past every message's own timer (a command's word stays up five seconds),
/// then down.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  // Before bindings every chord took Ctrl as ⌘; turning the experiment on is
  // the one thing allowed to hand ⌃K back to text editing.
  testWidgets('on a Mac, ⌃K opens the command dialog until Keyboard Shortcuts is on', variant: TargetPlatformVariant.only(TargetPlatform.macOS), (
    tester,
  ) async {
    final (:services, commands: _) = await _boot(tester, shortcuts: false);
    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyK);
    expect(find.byType(CommandDialog), findsOneWidget);
    await _press(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyK);
    expect(find.byType(CommandDialog), findsNothing);

    await services.settings.setExperimentEnabled(keyBindingsExperiment, true);
    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyK);
    expect(find.byType(CommandDialog), findsNothing);
    await _press(tester, [LogicalKeyboardKey.metaLeft], LogicalKeyboardKey.keyK);
    expect(find.byType(CommandDialog), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a key bound to command text runs it, and says so on the status bar', (tester) async {
    final (:services, :commands) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('DEVMODE', [KeyChord.parse('ctrl+J')!]));

    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyJ);

    expect(commands.executed, ['DEVMODE']);
    expect(services.statusBar.items.map((i) => i.text), contains('Developer mode on'));
    await _unmount(tester);
  });

  testWidgets('a chain runs its commands in order, and says what each did', (tester) async {
    final (:services, :commands) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('CW; DEVMODE', [KeyChord.parse('ctrl+J')!]));

    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyJ);

    expect(commands.executed, ['CW', 'DEVMODE']);
    expect(services.statusBar.items.map((i) => i.text), contains('Mode CW · Developer mode on'));
    await _unmount(tester);
  });

  // Running on past a command that failed would apply the rest of a chain
  // the operator built to run together — a band change without its mode.
  testWidgets('a chain stops at the first command that cannot run', (tester) async {
    final (:services, :commands) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('CW; NOPE; DEVMODE', [KeyChord.parse('ctrl+J')!]));

    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyJ);

    expect(commands.executed, ['CW']);
    expect(services.statusBar.items.map((i) => i.text), contains('Mode CW · Unknown command: NOPE'), reason: 'what ran before the stop is still named');
    await _unmount(tester);
  });

  testWidgets('a command that fails as it runs says so, instead of the key doing nothing', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('BROKEN', [KeyChord.parse('ctrl+J')!]));

    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyJ);

    expect(services.statusBar.items.map((i) => i.text), contains('The command failed to run'));
    await _unmount(tester);
  });

  testWidgets('a command added in the settings stays listed with no key, until removed', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(body: KeyboardShortcutsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // One category open at a time: opening Commands closes App above it.
    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commands'));
    await tester.pumpAndSettle();
    expect(find.text('DEVMODE'), findsNothing, reason: 'only the commands the operator added are listed');

    await tester.tap(find.text('Add a Command…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'cw ;devmode');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('cw; devmode'), findsOneWidget);
    expect(services.keyBindingsService.overrides.text, {'cw; devmode': isEmpty});

    await tester.tap(find.text('cw; devmode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Command'));
    await tester.pumpAndSettle();
    expect(find.text('cw; devmode'), findsNothing);
    expect(services.keyBindingsService.overrides.text, isEmpty);
    await _unmount(tester);
  });

  testWidgets('a command the app does not know is refused when added, naming which', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(body: KeyboardShortcutsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // One category open at a time: opening Commands closes App above it.
    await tester.tap(find.text('App'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commands'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a Command…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'CW; NOPE');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('No command reads “NOPE”'), findsOneWidget);
    expect(services.keyBindingsService.overrides.text, isEmpty);
    await _unmount(tester);
  });

  testWidgets('a bare non-callsign key runs its command with no field to take it', (tester) async {
    final (:services, :commands) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('DEVMODE', [KeyChord.parse(']')!]));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight, character: ']');
    await tester.pump();

    expect(commands.executed, ['DEVMODE']);
    await _unmount(tester);
  });

  testWidgets('a key bound to a command waiting for its text opens the dialog with it typed', (tester) async {
    final (:services, :commands) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withText('NOTE', [KeyChord.parse('ctrl+J')!]));

    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyJ);

    expect(commands.executed, isEmpty, reason: 'a NOTE with nothing to say is not a NOTE');
    expect(find.byType(CommandDialog), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CommandDialog), matching: find.byType(EditableText)).evaluate().map((e) => (e.widget as EditableText).controller.text),
      ['NOTE '],
    );
    await _unmount(tester);
  });

  // The density and font keys differ by ⇧ alone: matched loosely, ⌃⇧= would
  // also zoom.
  testWidgets('with Keyboard Shortcuts on, ⇧ still parts Layout Density from Font Scale', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    final scale = services.settings.fontScale;
    final density = services.settings.densityPreference;
    await _press(tester, [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft], LogicalKeyboardKey.minus);
    expect(services.settings.fontScale, scale);
    expect(services.settings.densityPreference, isNot(density));
    await _unmount(tester);
  });

  testWidgets('the editor takes a key from the command that had it, when asked to', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(body: KeyboardShortcutsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch between light and dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Shortcut'));
    await tester.pump();
    await _press(tester, [LogicalKeyboardKey.controlLeft], LogicalKeyboardKey.keyK);
    expect(find.byType(CommandDialog), findsNothing, reason: 'the recorder hears ⌃K, not the app');
    expect(find.text('Take Ctrl+K from “Open the command dialog”'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final bindings = services.keyBindingsService.overrides.resolve();
    final ctrlK = KeyChord.parse('ctrl+K')!;
    expect(bindings.chordsFor('app.toggleTheme'), contains(ctrlK));
    expect(bindings.chordsFor('app.commandDialog'), isNot(contains(ctrlK)));
    expect(bindings.conflicts, isEmpty);
    await _unmount(tester);
  });

  testWidgets('Reset to Default in the editor puts the command back as it shipped', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await services.keyBindingsService.setOverrides(const KeyBindingOverrides().withCommand('app.toggleTheme', const []));
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(body: KeyboardShortcutsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch between light and dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to Default'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(services.keyBindingsService.overrides.isEmpty, isTrue, reason: 'the defaults are not stored as a change');
    await _unmount(tester);
  });

  testWidgets('the recorder refuses a fixed key, and Escape stops it rather than being bound', (tester) async {
    final (:services, commands: _) = await _boot(tester);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildHaLoTheme(Brightness.light),
          home: Scaffold(body: KeyboardShortcutsPanel(services: services)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch between light and dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Shortcut'));
    await tester.pump();
    await _press(tester, const [], LogicalKeyboardKey.enter);
    expect(find.textContaining('can’t be changed'), findsOneWidget);
    expect(find.text('Press the keys for the shortcut…'), findsOneWidget, reason: 'still listening for one that can be bound');

    await _press(tester, const [], LogicalKeyboardKey.escape);
    expect(find.text('Add Shortcut'), findsOneWidget, reason: 'Escape stopped listening');
    expect(find.byType(HaloDialog), findsOneWidget, reason: 'and did not also close the editor');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(services.keyBindingsService.overrides.isEmpty, isTrue);
    await _unmount(tester);
  });
}
