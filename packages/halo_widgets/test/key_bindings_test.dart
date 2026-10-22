// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyboard shortcuts as data (docs/design/keyboard-shortcuts.md): what a
// chord reads as, what it matches, which chords may be bound, and the
// legacy matcher that keeps `EXP KB` off from changing any key.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo_widgets/halo_widgets.dart';

KeyChord chord(String text) => KeyChord.parse(text)!;

/// Presses [key] with [modifiers] held and returns what [test] answered for
/// the key-down event, asked while the modifiers are still down — which is
/// when every handler asks.
Future<bool> pressing(
  WidgetTester tester,
  LogicalKeyboardKey key,
  bool Function(KeyEvent event) test, {
  List<LogicalKeyboardKey> modifiers = const [],
  PhysicalKeyboardKey? physicalKey,
  String? character,
  String platform = 'android',
}) async {
  bool? answer;
  bool handler(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == key) answer = test(event);
    return false;
  }

  HardwareKeyboard.instance.addHandler(handler);
  addTearDown(() => HardwareKeyboard.instance.removeHandler(handler));
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m, platform: platform);
  }
  await tester.sendKeyDownEvent(key, platform: platform, physicalKey: physicalKey, character: character);
  await tester.sendKeyUpEvent(key, platform: platform, physicalKey: physicalKey);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m, platform: platform);
  }
  HardwareKeyboard.instance.removeHandler(handler);
  return answer!;
}

void main() {
  group('a chord as text', () {
    test('reads back as it was written, modifiers in a fixed order', () {
      expect('${chord('shift+cmd+d')}', 'cmd+shift+D');
      expect('${chord('alt+1')}', 'alt+1');
      expect('${chord('F5')}', 'F5');
    });

    test('takes the names a person writing a file by hand would use', () {
      expect(chord('option+command+K'), chord('cmd+alt+K'));
      expect(chord('control+Win+K'), chord('ctrl+meta+K'));
      expect(chord('super+K'), chord('meta+K'));
    });

    test('names the plus key so it does not read as a separator', () {
      expect(chord('cmd++'), chord('cmd+Plus'));
      expect('${chord('cmd++')}', 'cmd+Plus');
    });

    test('refuses what is not a chord rather than guessing', () {
      for (final text in ['', 'cmd+', 'cmd+cmd+K', 'hyper+K', 'cmd+NotAKey', 'fn+K']) {
        expect(KeyChord.parse(text), isNull, reason: text);
      }
    });

    test('reads as each platform writes its shortcuts', () {
      expect(chord('cmd+shift+D').label(TargetPlatform.macOS), '⇧⌘D');
      expect(chord('ctrl+alt+shift+cmd+K').label(TargetPlatform.macOS), '⌃⌥⇧⌘K', reason: "Apple's own modifier order");
      expect(chord('ctrl+shift+D').label(TargetPlatform.windows), 'Ctrl+Shift+D');
      expect(chord('meta+K').label(TargetPlatform.windows), 'Win+K');
      expect(chord('meta+K').label(TargetPlatform.linux), 'Super+K');
    });
  });

  // The app's fonts hold none of these symbols, and the color emoji font
  // holds `↩`: drawn as text, Return would be an emoji.
  test('draws the Mac symbols as icons, and never spells Return as ↩', () {
    final parts = chord('cmd+Enter').labelParts(TargetPlatform.macOS);
    expect([for (final p in parts) p.icon], [MdiIcons.appleKeyboardCommand, MdiIcons.subdirectoryArrowLeft]);
    expect(chord('cmd+Enter').label(TargetPlatform.macOS), '⌘Return');
    expect(chord('ctrl+Enter').labelParts(TargetPlatform.windows).map((p) => p.icon), everyElement(isNull), reason: 'Windows spells its keys out');
  });

  group('a chord against a key press', () {
    testWidgets('wants exactly its modifiers, so ⌘K and ⌘⇧K can be two commands', (tester) async {
      final k = chord('cmd+K');
      expect(await pressing(tester, LogicalKeyboardKey.keyK, k.matches, modifiers: [LogicalKeyboardKey.metaLeft]), isTrue);
      expect(await pressing(tester, LogicalKeyboardKey.keyK, k.matches, modifiers: [LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft]), isFalse);
      expect(await pressing(tester, LogicalKeyboardKey.keyK, k.matches, modifiers: [LogicalKeyboardKey.controlLeft]), isFalse);
    });

    testWidgets('reads cmd and meta as the one key they are', (tester) async {
      expect(await pressing(tester, LogicalKeyboardKey.keyK, chord('meta+K').matches, modifiers: [LogicalKeyboardKey.metaLeft]), isTrue);
      expect(chord('cmd+K').samePressAs(chord('meta+K')), isTrue);
    });

    // In a browser on a Mac, ⌥K arrives as the logical key '˚'.
    testWidgets('finds an ⌥ chord by where the key sits', (tester) async {
      const ringAbove = LogicalKeyboardKey(0x2DA);
      expect(
        await pressing(
          tester,
          ringAbove,
          chord('alt+K').matches,
          modifiers: [LogicalKeyboardKey.altLeft],
          physicalKey: PhysicalKeyboardKey.keyK,
          platform: 'web',
        ),
        isTrue,
      );
    });

    // On AZERTY the key in A's place types Q: Ctrl+Q there is not Ctrl+A.
    testWidgets('does not find a chord by position without ⌥ or ⇧', (tester) async {
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.keyQ,
          chord('ctrl+A').matches,
          modifiers: [LogicalKeyboardKey.controlLeft],
          physicalKey: PhysicalKeyboardKey.keyA,
        ),
        isFalse,
      );
    });

    // On AZERTY the key in W's place is Z: ⌥Z there must not wipe as ⌥W.
    testWidgets('does not take a key that names a key of its own for the one in its place', (tester) async {
      expect(
        await pressing(tester, LogicalKeyboardKey.keyZ, chord('alt+W').matches, modifiers: [LogicalKeyboardKey.altLeft], physicalKey: PhysicalKeyboardKey.keyW),
        isFalse,
      );
    });

    // PTT's ['] is typed with ⇧ on a German layout, and US ⇧['] is ["].
    testWidgets("matches a bare typing key by the character typed, ⇧ or not", (tester) async {
      final apostrophe = chord("'");
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.numberSign,
          apostrophe.matches,
          modifiers: [LogicalKeyboardKey.shiftLeft],
          physicalKey: PhysicalKeyboardKey.backslash,
          character: "'",
          platform: 'web',
        ),
        isTrue,
      );
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.quoteSingle,
          apostrophe.matches,
          modifiers: [LogicalKeyboardKey.shiftLeft],
          physicalKey: PhysicalKeyboardKey.quote,
          character: '"',
          platform: 'web',
        ),
        isFalse,
      );
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.quoteSingle,
          apostrophe.matches,
          modifiers: [LogicalKeyboardKey.metaLeft],
          physicalKey: PhysicalKeyboardKey.quote,
          character: "'",
          platform: 'web',
        ),
        isFalse,
        reason: '⌘[\'] is a chord, never PTT',
      );
    });
  });

  group('the defaults', () {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
      test('bind no key twice on ${platform.name}', () {
        expect(KeyBindings.resolve(platform: platform).conflicts, isEmpty);
      });

      test('can all be bound on ${platform.name} — none is a key the app keeps for itself', () {
        for (final spec in keyCommandSpecs) {
          for (final c in spec.defaultChords(platform)) {
            expect(keyChordRefusal(c, spec.id, platform), isNull, reason: '${spec.id}: $c');
          }
        }
      });
    }

    test("use the platform's own command key, never both", () {
      expect(KeyBindings.resolve(platform: TargetPlatform.macOS).chordsFor('app.commandDialog'), contains(chord('cmd+K')));
      expect(KeyBindings.resolve(platform: TargetPlatform.macOS).chordsFor('app.commandDialog'), isNot(contains(chord('ctrl+K'))));
      expect(KeyBindings.resolve(platform: TargetPlatform.windows).chordsFor('app.commandDialog'), contains(chord('ctrl+K')));
    });

    test('give each keyer message its function key and its ⌥-digit', () {
      for (var n = 1; n <= keyerMessageKeyCount; n++) {
        expect(KeyBindings.resolve().chordsFor('keyer.message$n'), [chord('F$n'), chord('alt+$n')]);
      }
    });
  });

  group('the legacy bindings (EXP KB off)', () {
    // Before bindings, every handler took ⌘ OR Ctrl on every platform; the
    // experiment is what is allowed to change that, not the refactor.
    testWidgets('still take Ctrl as ⌘ on a Mac', (tester) async {
      final legacy = LegacyKeyBindings(TargetPlatform.macOS);
      expect(
        await pressing(tester, LogicalKeyboardKey.keyK, (e) => legacy.matches('app.commandDialog', e), modifiers: [LogicalKeyboardKey.controlLeft]),
        isTrue,
      );
      final resolved = KeyBindings.resolve(platform: TargetPlatform.macOS);
      expect(
        await pressing(tester, LogicalKeyboardKey.keyK, (e) => resolved.matches('app.commandDialog', e), modifiers: [LogicalKeyboardKey.controlLeft]),
        isFalse,
      );
    });

    testWidgets('keep F-keys for messages with ⇧ held, as before', (tester) async {
      final legacy = LegacyKeyBindings();
      expect(await pressing(tester, LogicalKeyboardKey.f3, (e) => legacy.matches('keyer.message3', e), modifiers: [LogicalKeyboardKey.shiftLeft]), isTrue);
    });

    testWidgets('run no bound command text', (tester) async {
      final legacy = LegacyKeyBindings();
      expect(await pressing(tester, LogicalKeyboardKey.keyJ, (e) => legacy.textCommandFor(e) != null, modifiers: [LogicalKeyboardKey.metaLeft]), isFalse);
    });
  });

  group('which chords may be bound', () {
    test('never Escape, nor a field key on its own', () {
      for (final text in ['Escape', 'cmd+Escape', 'Enter', 'Space', 'Tab', 'shift+Tab', 'Up', 'PageDown', 'Backspace']) {
        expect(keyChordRefusal(chord(text), 'app.toggleTheme'), KeyChordRefusal.fixed, reason: text);
      }
    });

    test("never the QSO list's walk, nor undo", () {
      expect(keyChordRefusal(chord('alt+Up'), 'app.toggleTheme'), KeyChordRefusal.fixed);
      expect(keyChordRefusal(chord('cmd+Down'), 'app.toggleTheme'), KeyChordRefusal.fixed);
      expect(keyChordRefusal(chord('cmd+Z'), 'app.toggleTheme', TargetPlatform.macOS), KeyChordRefusal.fixed);
      expect(keyChordRefusal(chord('ctrl+Z'), 'app.toggleTheme', TargetPlatform.windows), KeyChordRefusal.fixed);
      expect(keyChordRefusal(chord('ctrl+Z'), 'app.toggleTheme', TargetPlatform.macOS), isNull, reason: 'Ctrl+Z is no undo on a Mac');
    });

    // Every callsign is typed with these: taken by a command, a call could
    // not be entered at all.
    test('no callsign key on its own, for any command', () {
      for (final text in ['A', 'shift+A', '7', ',', '.', '/', 'Numpad5', 'NumpadDecimal', 'NumpadDivide']) {
        expect(keyChordRefusal(chord(text), pttCommandId), KeyChordRefusal.callsignKey, reason: text);
      }
    });

    test('any other key on its own, for any command — the field rule decides where it fires', () {
      for (final text in [']', '[', r'\', ';', "'", '=', '-', '`', 'shift+]', 'NumpadAdd', 'F9']) {
        expect(keyChordRefusal(chord(text), 'app.toggleTheme'), isNull, reason: text);
      }
      expect(keyChordRefusal(chord('alt+A'), 'app.toggleTheme'), isNull, reason: 'a held ⌥ makes it a chord');
      expect(keyChordRefusal(chord('ctrl+7'), 'app.toggleTheme'), isNull);
    });

    test('a system chord, with a warning', () {
      expect(isReservedKeyChord(chord('cmd+Q'), TargetPlatform.macOS), isTrue);
      expect(isReservedKeyChord(chord('alt+F4'), TargetPlatform.windows), isTrue);
      expect(isReservedKeyChord(chord('cmd+J'), TargetPlatform.macOS), isFalse);
    });
  });

  group('the operator’s changes', () {
    test('carry only what differs from the defaults', () {
      final moved = const KeyBindingOverrides().withCommand('logging.wipe', [chord('F9')]);
      expect(moved.commands.keys, ['logging.wipe']);
      final back = moved.withCommand('logging.wipe', keyCommandSpec('logging.wipe')!.defaultChords());
      expect(back.isEmpty, isTrue, reason: 'a file of changes must not pin every default it passed through');
    });

    test('keep a command with every key taken from it', () {
      final none = const KeyBindingOverrides().withCommand('app.toggleTheme', const []);
      expect(none.resolve().chordsFor('app.toggleTheme'), isEmpty);
      expect(none.toJson(), {
        'commands': {'app.toggleTheme': <String>[]},
      });
    });

    // Command text is listed because the operator added it, key or not.
    test('keep added command text with no key until it is removed', () {
      final added = const KeyBindingOverrides().withText('20M; CW', const []);
      expect(added.text, {'20M; CW': isEmpty});
      expect(added.resolve().chordsFor(textCommandId('20M; CW')), isEmpty);
      expect(added.withoutText('20M; CW').text, isEmpty);
    });

    test('drop a chord that does not read, and say which', () {
      final unreadable = <String>[];
      final read = KeyBindingOverrides.fromJson({
        'commands': {
          'app.toggleTheme': ['cmd+shift+T', 'hyper+T'],
        },
      }, unreadable: unreadable);
      expect(read.commands['app.toggleTheme'], [chord('cmd+shift+T')]);
      expect(unreadable, ['hyper+T']);
    });

    // A key a newer version names, read by this one, must not take the
    // command's defaults with it — and a later save would make that stick.
    test('keep the defaults of a command none of whose chords read', () {
      final read = KeyBindingOverrides.fromJson({
        'commands': {
          'logView.find': ['cmd+NotAKey'],
          'app.toggleTheme': <String>[],
        },
      });
      expect(read.commands.containsKey('logView.find'), isFalse);
      expect(read.commands['app.toggleTheme'], isEmpty, reason: 'an empty list given as such still means no key');
    });

    test('show where a command and typed text share a key', () {
      final bindings = KeyBindingOverrides(
        text: {
          '20M': [chord('alt+W') /* the wipe's default */],
        },
      ).resolve();
      final clash = bindings.conflicts.single;
      expect(clash.ids, unorderedEquals(['logging.wipe', textCommandId('20M')]));
    });

    test('translate every modifier at once, so cmd and ctrl can trade places', () {
      final swapped = chord('cmd+ctrl+K').translated({KeyModifier.cmd: KeyModifier.ctrl, KeyModifier.ctrl: KeyModifier.cmd});
      expect(swapped, chord('cmd+ctrl+K'));
      expect(chord('cmd+K').translated({KeyModifier.cmd: KeyModifier.ctrl}), chord('ctrl+K'));
      expect(chord('cmd+K').translated({KeyModifier.cmd: null}), isNull, reason: 'null leaves the shortcut out');
      expect(chord('alt+K').translated({KeyModifier.cmd: KeyModifier.ctrl}), chord('alt+K'), reason: 'alt is never translated');
    });
  });

  group('a key that types', () {
    Future<void> field(WidgetTester tester, FocusNode focus) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: EditableText(
          controller: TextEditingController(),
          focusNode: focus,
          style: const TextStyle(),
          cursorColor: const Color(0xFF000000),
          backgroundCursorColor: const Color(0xFF000000),
        ),
      ),
    );

    // A shortcut on `]` that fired in a note would make `]` untypeable there.
    testWidgets('is the focused field\'s, not the shortcut\'s, in a field that takes it', (tester) async {
      final bindings = KeyBindings.resolve();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await field(tester, focus);
      bool yields(KeyEvent e) => bindings.yieldsToField('app.toggleTheme', chord(']'), e);

      expect(await pressing(tester, LogicalKeyboardKey.bracketRight, yields, character: ']'), isFalse, reason: 'nothing focused takes it');
      focus.requestFocus();
      await tester.pump();
      expect(await pressing(tester, LogicalKeyboardKey.bracketRight, yields, character: ']'), isTrue);
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.bracketRight,
          (e) => bindings.yieldsToField('app.toggleTheme', chord('ctrl+]'), e),
          modifiers: [LogicalKeyboardKey.controlLeft],
          character: ']',
        ),
        isFalse,
        reason: 'a ⌘ or Ctrl chord types nothing',
      );
      expect(await pressing(tester, LogicalKeyboardKey.f9, yields), isFalse, reason: 'a key that types nothing never yields');
    });

    // Legacy stood aside only for the keyer's ⌥-digits and PTT — EXP KB off
    // must not start yielding anything else.
    testWidgets('yields with Keyboard Shortcuts off only where it always did', (tester) async {
      final legacy = LegacyKeyBindings();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await field(tester, focus);
      focus.requestFocus();
      await tester.pump();
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.keyW,
          (e) => legacy.yieldsToField('logging.wipe', chord('alt+W'), e),
          modifiers: [LogicalKeyboardKey.altLeft],
          character: '∑',
        ),
        isFalse,
      );
      expect(
        await pressing(
          tester,
          LogicalKeyboardKey.digit2,
          (e) => legacy.yieldsToField('keyer.message2', chord('alt+2'), e),
          modifiers: [LogicalKeyboardKey.altLeft],
          character: '@',
        ),
        isTrue,
      );
    });
  });

  group('free text', () {
    testWidgets('is a text field outside the entry row', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: EditableText(
            controller: TextEditingController(),
            focusNode: focus,
            style: const TextStyle(),
            cursorColor: const Color(0xFF000000),
            backgroundCursorColor: const Color(0xFF000000),
          ),
        ),
      );
      expect(focusInFreeText(), isFalse);
      focus.requestFocus();
      await tester.pump();
      expect(focusInFreeText(), isTrue);
    });
  });
}
