// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyboard shortcuts as data: the chords, the commands they run, and the
// bindings in force (docs/design/keyboard-shortcuts.md). Each key handler
// stays where it is and asks [keyBindings] whether an event is its command's,
// instead of testing keys and modifiers itself.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext, EditableText, FocusManager, IconData, TextEditingValue, TextSelection;

import 'logging_controls.dart' show LoggingControls;
import 'logging_controls_entry_row.dart' show LoggingEntryRow;
import 'mdi_icons.g.dart';

/// A modifier as a binding stores it. [cmd] and [meta] are the same key to
/// Flutter — ⌘ on Apple keyboards, Windows or Super elsewhere — and are kept
/// apart only so a file says which keyboard it was written for; both match
/// either. Listed in the order a chord is written.
enum KeyModifier { cmd, ctrl, meta, alt, shift }

/// One key a chord can name: its name in a binding, the logical key it
/// matches, and — for a key whose character a modifier changes — the
/// physical key it also matches while ⌥ or ⇧ is held. On a Mac ⌥K reports the
/// logical key '˚' in a browser, so a chord naming K has to find it by
/// position.
class _KeyName {
  final String name;
  final LogicalKeyboardKey logical;
  final PhysicalKeyboardKey? physical;

  /// The character the key types with nothing held, for a key that types one.
  final String? character;

  /// On the numeric keypad: typing the same character as a main-row key, it
  /// is still a key of its own, so it is never matched by that character.
  final bool numpad;

  const _KeyName(this.name, this.logical, {this.physical, this.character, this.numpad = false});

  /// A key a callsign is typed with — a letter, a digit, `,` `.` `/` — which
  /// no command may take on its own (docs/design/keyboard-shortcuts.md).
  bool get callsign => character != null && RegExp(r'^[a-z0-9,./]$').hasMatch(character!);
}

final List<_KeyName> _keyNames = [
  for (var i = 0; i < 26; i++)
    _KeyName(
      String.fromCharCode(0x41 + i),
      LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + i),
      physical: PhysicalKeyboardKey(PhysicalKeyboardKey.keyA.usbHidUsage + i),
      character: String.fromCharCode(0x61 + i),
    ),
  for (var i = 0; i < 10; i++)
    _KeyName(
      '$i',
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + i),
      // USB HID numbers the digit row 1…9, then 0.
      physical: PhysicalKeyboardKey(i == 0 ? PhysicalKeyboardKey.digit0.usbHidUsage : PhysicalKeyboardKey.digit1.usbHidUsage + i - 1),
      character: '$i',
    ),
  const _KeyName('=', LogicalKeyboardKey.equal, physical: PhysicalKeyboardKey.equal, character: '='),
  const _KeyName('-', LogicalKeyboardKey.minus, physical: PhysicalKeyboardKey.minus, character: '-'),
  // Its own key on some layouts (German), and shifted `=` on others.
  const _KeyName('Plus', LogicalKeyboardKey.add, character: '+'),
  const _KeyName('_', LogicalKeyboardKey.underscore, character: '_'),
  const _KeyName('[', LogicalKeyboardKey.bracketLeft, physical: PhysicalKeyboardKey.bracketLeft, character: '['),
  const _KeyName(']', LogicalKeyboardKey.bracketRight, physical: PhysicalKeyboardKey.bracketRight, character: ']'),
  const _KeyName(';', LogicalKeyboardKey.semicolon, physical: PhysicalKeyboardKey.semicolon, character: ';'),
  // Not `LogicalKeyboardKey.quote`, which is the DOUBLE quote.
  const _KeyName("'", LogicalKeyboardKey.quoteSingle, physical: PhysicalKeyboardKey.quote, character: "'"),
  const _KeyName(',', LogicalKeyboardKey.comma, physical: PhysicalKeyboardKey.comma, character: ','),
  const _KeyName('.', LogicalKeyboardKey.period, physical: PhysicalKeyboardKey.period, character: '.'),
  const _KeyName('/', LogicalKeyboardKey.slash, physical: PhysicalKeyboardKey.slash, character: '/'),
  const _KeyName(r'\', LogicalKeyboardKey.backslash, physical: PhysicalKeyboardKey.backslash, character: r'\'),
  const _KeyName('`', LogicalKeyboardKey.backquote, physical: PhysicalKeyboardKey.backquote, character: '`'),
  for (var i = 1; i <= 24; i++) _KeyName('F$i', LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + i - 1)),
  const _KeyName('Enter', LogicalKeyboardKey.enter),
  const _KeyName('Tab', LogicalKeyboardKey.tab),
  const _KeyName('Space', LogicalKeyboardKey.space, character: ' '),
  const _KeyName('Escape', LogicalKeyboardKey.escape),
  const _KeyName('Backspace', LogicalKeyboardKey.backspace),
  const _KeyName('Delete', LogicalKeyboardKey.delete),
  const _KeyName('Insert', LogicalKeyboardKey.insert),
  const _KeyName('Home', LogicalKeyboardKey.home),
  const _KeyName('End', LogicalKeyboardKey.end),
  const _KeyName('PageUp', LogicalKeyboardKey.pageUp),
  const _KeyName('PageDown', LogicalKeyboardKey.pageDown),
  const _KeyName('Up', LogicalKeyboardKey.arrowUp),
  const _KeyName('Down', LogicalKeyboardKey.arrowDown),
  const _KeyName('Left', LogicalKeyboardKey.arrowLeft),
  const _KeyName('Right', LogicalKeyboardKey.arrowRight),
  const _KeyName('NumpadEnter', LogicalKeyboardKey.numpadEnter),
  for (var i = 0; i < 10; i++) _KeyName('Numpad$i', LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + i), character: '$i', numpad: true),
  const _KeyName('NumpadAdd', LogicalKeyboardKey.numpadAdd, character: '+', numpad: true),
  const _KeyName('NumpadSubtract', LogicalKeyboardKey.numpadSubtract, character: '-', numpad: true),
  const _KeyName('NumpadMultiply', LogicalKeyboardKey.numpadMultiply, character: '*', numpad: true),
  const _KeyName('NumpadDivide', LogicalKeyboardKey.numpadDivide, character: '/', numpad: true),
  const _KeyName('NumpadDecimal', LogicalKeyboardKey.numpadDecimal, character: '.', numpad: true),
];

final Map<String, _KeyName> _keysByName = {for (final key in _keyNames) key.name.toLowerCase(): key};
final Map<LogicalKeyboardKey, _KeyName> _keysByLogical = {for (final key in _keyNames) key.logical: key};
final Map<PhysicalKeyboardKey, _KeyName> _keysByPhysical = {for (final key in _keyNames) ?key.physical: key};

const _modifierAliases = {
  'cmd': KeyModifier.cmd,
  'command': KeyModifier.cmd,
  'ctrl': KeyModifier.ctrl,
  'control': KeyModifier.ctrl,
  'meta': KeyModifier.meta,
  'win': KeyModifier.meta,
  'super': KeyModifier.meta,
  'alt': KeyModifier.alt,
  'option': KeyModifier.alt,
  'shift': KeyModifier.shift,
};

/// Whether [platform] names its ⌘ key `cmd` rather than `meta` — Apple's,
/// a browser on a Mac included, since [defaultTargetPlatform] is the host OS
/// there.
bool isApplePlatform([TargetPlatform? platform]) {
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.macOS || p == TargetPlatform.iOS;
}

/// A key with the modifiers held for it: `cmd+shift+D`.
@immutable
class KeyChord {
  final LogicalKeyboardKey key;
  final Set<KeyModifier> modifiers;

  KeyChord(this.key, [Iterable<KeyModifier> modifiers = const []]) : modifiers = Set.unmodifiable(modifiers);

  /// [text] as a binding writes it — modifiers then the key, joined by `+`,
  /// in any case, with `option`, `control`, `command`, `win` and `super`
  /// read as their stored names. Null for anything else, a key this table
  /// does not name included.
  static KeyChord? parse(String text) {
    final parts = text.trim().split('+').map((p) => p.trim()).toList();
    if (parts.length > 1 && parts.last.isEmpty && parts[parts.length - 2].isEmpty) {
      // `cmd++`: the key is the plus sign itself.
      parts
        ..removeLast()
        ..last = 'Plus';
    }
    if (parts.isEmpty || parts.any((p) => p.isEmpty)) return null;
    final key = _keysByName[parts.last.toLowerCase()];
    if (key == null) return null;
    final modifiers = <KeyModifier>{};
    for (final part in parts.take(parts.length - 1)) {
      final modifier = _modifierAliases[part.toLowerCase()];
      if (modifier == null || !modifiers.add(modifier)) return null;
    }
    return KeyChord(key.logical, modifiers);
  }

  /// The chord [event] makes with the modifiers held now, or null for a key
  /// a binding cannot name — a modifier pressed on its own among them.
  static KeyChord? fromEvent(KeyEvent event, {TargetPlatform? platform}) {
    final name = _keysByLogical[event.logicalKey] ?? _keysByPhysical[event.physicalKey];
    if (name == null) return null;
    final keyboard = HardwareKeyboard.instance;
    return KeyChord(name.logical, {
      if (keyboard.isMetaPressed) isApplePlatform(platform) ? KeyModifier.cmd : KeyModifier.meta,
      if (keyboard.isControlPressed) KeyModifier.ctrl,
      if (keyboard.isAltPressed) KeyModifier.alt,
      if (keyboard.isShiftPressed) KeyModifier.shift,
    });
  }

  _KeyName get _name => _keysByLogical[key]!;

  bool get _hasMeta => modifiers.contains(KeyModifier.cmd) || modifiers.contains(KeyModifier.meta);

  /// Whether the chord holds a command modifier — ⌘, Ctrl, Win — rather than
  /// only ⌥ or ⇧, or nothing.
  bool get hasCommandModifier => _hasMeta || modifiers.contains(KeyModifier.ctrl);

  /// Whether pressing the chord in a text field would type a character into
  /// it: a key that types one, with no command modifier. ⌥ counts as typing:
  /// it makes '∑' of W on a Mac, and '@' of 2 on a Spanish one.
  bool get typesCharacter => !hasCommandModifier && _name.character != null;

  /// Whether the chord is a callsign key with at most ⇧ held — one no command
  /// may take, since every callsign is typed with it.
  bool get isCallsignKey => _name.callsign && !hasCommandModifier && !modifiers.contains(KeyModifier.alt);

  /// The character the key types with nothing held, if it types one.
  String? get character => _name.character;

  /// Whether [event] is this chord: the key, and exactly these modifiers.
  /// `cmd` and `meta` both stand for the ⌘/Windows key.
  ///
  /// A bare key that types a character — PTT's ['], a `]` — is the character
  /// typed instead, ⇧ or not: a German layout types ['] with ⇧, and US ⇧[']
  /// is ["], and the platforms disagree about which key name either one
  /// reports. Not a keypad key, which types what a main-row key does.
  bool matches(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (modifiers.isEmpty && _name.character != null && _name.character != ' ' && !_name.numpad) {
      return !keyboard.isMetaPressed && !keyboard.isControlPressed && !keyboard.isAltPressed && event.character == _name.character;
    }
    if (keyboard.isMetaPressed != _hasMeta) return false;
    if (keyboard.isControlPressed != modifiers.contains(KeyModifier.ctrl)) return false;
    if (keyboard.isAltPressed != modifiers.contains(KeyModifier.alt)) return false;
    if (keyboard.isShiftPressed != modifiers.contains(KeyModifier.shift)) return false;
    if (event.logicalKey == key) return true;
    // By position only where a modifier has rewritten the key into one no
    // chord can name — ⌥K reported as '˚'. A key that still names a key of
    // its own is that key: on AZERTY the key in W's place is Z, and ⌥Z there
    // must not wipe as ⌥W.
    final physical = _name.physical;
    return physical != null &&
        (keyboard.isAltPressed || keyboard.isShiftPressed) &&
        !_keysByLogical.containsKey(event.logicalKey) &&
        event.physicalKey == physical;
  }

  /// Whether this and [other] are the same keys to press — `cmd` and `meta`
  /// are one key.
  bool samePressAs(KeyChord other) => key == other.key && _pressSignature == other._pressSignature;

  int get _pressSignature =>
      (_hasMeta ? 1 : 0) |
      (modifiers.contains(KeyModifier.ctrl) ? 2 : 0) |
      (modifiers.contains(KeyModifier.alt) ? 4 : 0) |
      (modifiers.contains(KeyModifier.shift) ? 8 : 0);

  /// This chord with its modifiers swapped as [translation] says, all at
  /// once — so `cmd`→`ctrl` and `ctrl`→`cmd` trade places — or null when it
  /// holds a modifier [translation] maps to null: a shortcut the operator
  /// chose to leave out. A modifier [translation] does not name stays.
  KeyChord? translated(Map<KeyModifier, KeyModifier?> translation) {
    final next = <KeyModifier>{};
    for (final modifier in modifiers) {
      if (!translation.containsKey(modifier)) {
        next.add(modifier);
      } else if (translation[modifier] case final to?) {
        next.add(to);
      } else {
        return null;
      }
    }
    return KeyChord(key, next);
  }

  /// As stored: `cmd+shift+D`.
  @override
  String toString() => [
    for (final m in KeyModifier.values)
      if (modifiers.contains(m)) m.name,
    _name.name,
  ].join('+');

  /// As the operator reads it on [platform]: `⇧⌘D` on Apple's, `Ctrl+Shift+D`
  /// elsewhere — for text, where [labelParts]' icons cannot go.
  String label([TargetPlatform? platform]) => [for (final part in labelParts(platform)) part.text].join(isApplePlatform(platform) ? '' : '+');

  /// [label] in its pieces, a modifier or the key each, with the icon a key
  /// cap draws in place of the text where there is one. Icons, because the
  /// app's own fonts hold none of these symbols: each would come from
  /// whatever fallback font the platform has, and `↩` from the color emoji
  /// one, as an emoji.
  List<({String text, IconData? icon})> labelParts([TargetPlatform? platform]) {
    final apple = isApplePlatform(platform);
    if (apple) {
      // Apple's own order: ⌃⌥⇧⌘.
      return [
        if (modifiers.contains(KeyModifier.ctrl)) (text: '⌃', icon: MdiIcons.appleKeyboardControl),
        if (modifiers.contains(KeyModifier.alt)) (text: '⌥', icon: MdiIcons.appleKeyboardOption),
        if (modifiers.contains(KeyModifier.shift)) (text: '⇧', icon: MdiIcons.appleKeyboardShift),
        if (_hasMeta) (text: '⌘', icon: MdiIcons.appleKeyboardCommand),
        _keyPart(apple),
      ];
    }
    final metaLabel = switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.windows => 'Win',
      TargetPlatform.linux => 'Super',
      _ => 'Meta',
    };
    return [
      if (modifiers.contains(KeyModifier.ctrl)) (text: 'Ctrl', icon: null),
      if (_hasMeta) (text: metaLabel, icon: null),
      if (modifiers.contains(KeyModifier.alt)) (text: 'Alt', icon: null),
      if (modifiers.contains(KeyModifier.shift)) (text: 'Shift', icon: null),
      _keyPart(apple),
    ];
  }

  ({String text, IconData? icon}) _keyPart(bool apple) => switch (_name.name) {
    'Plus' => (text: '+', icon: null),
    'Up' => (text: '↑', icon: MdiIcons.arrowUp),
    'Down' => (text: '↓', icon: MdiIcons.arrowDown),
    'Left' => (text: '←', icon: MdiIcons.arrowLeft),
    'Right' => (text: '→', icon: MdiIcons.arrowRight),
    'Enter' when apple => (text: 'Return', icon: MdiIcons.subdirectoryArrowLeft),
    'Backspace' when apple => (text: '⌫', icon: MdiIcons.backspaceOutline),
    'Delete' when apple => (text: 'Del', icon: null),
    'Tab' when apple => (text: '⇥', icon: MdiIcons.keyboardTab),
    'Escape' => (text: 'Esc', icon: null),
    final name when name.startsWith('Numpad') && name.length > 6 => (
      text:
          'Num ${switch (name.substring(6)) {
            'Add' => '+',
            'Subtract' => '-',
            'Multiply' => '*',
            'Divide' => '/',
            'Decimal' => '.',
            final rest => rest,
          }}',
      icon: null,
    ),
    final name => (text: name, icon: null),
  };

  @override
  bool operator ==(Object other) => other is KeyChord && other.key == key && setEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAllUnordered(modifiers));
}

/// Where a command's key works — what the Keyboard Shortcuts settings say
/// beside it. Not consulted for conflicts: every context sits inside the one
/// before it, so two commands on one chord always meet somewhere.
enum KeyCommandContext {
  /// Anywhere in the app, no dialog over it.
  app,

  /// A view holding a log in front: Operation, Chasing, Logs.
  logView,

  /// The Operation view in front, keying through a CAT radio.
  operation,

  /// The keyboard in the logging panel.
  logging,
}

/// A command a key can run, and the chords it starts with.
class KeyCommandSpec {
  /// Stable: bindings are stored and exported under it.
  final String id;
  final KeyCommandContext context;

  /// Chords as [KeyChord.parse] reads them, with `mod` standing for ⌘ on
  /// Apple platforms and Ctrl elsewhere. `mod` is never stored.
  final List<String> defaults;

  const KeyCommandSpec(this.id, this.context, this.defaults);

  List<KeyChord> defaultChords([TargetPlatform? platform]) {
    final mod = isApplePlatform(platform) ? 'cmd' : 'ctrl';
    return [for (final text in defaults) KeyChord.parse(text.replaceAll('mod', mod))!];
  }
}

/// The prefix that marks a binding to typed command text — `text:20M` — as
/// opposed to a [KeyCommandSpec] id.
const textCommandPrefix = 'text:';

String textCommandId(String text) => '$textCommandPrefix$text';

/// Every command a key can be bound to, apart from typed command text.
/// Ordered as the settings list them.
final List<KeyCommandSpec> keyCommandSpecs = [
  const KeyCommandSpec('app.commandDialog', KeyCommandContext.app, ['mod+K', 'mod+shift+K', 'mod+alt+K']),
  const KeyCommandSpec('app.toggleTheme', KeyCommandContext.app, ['mod+shift+D']),
  const KeyCommandSpec('app.toggleLanguage', KeyCommandContext.app, ['mod+shift+L']),
  const KeyCommandSpec('app.fontScaleUp', KeyCommandContext.app, ['mod+=', 'mod+Plus', 'mod+NumpadAdd']),
  const KeyCommandSpec('app.fontScaleDown', KeyCommandContext.app, ['mod+-', 'mod+NumpadSubtract']),
  const KeyCommandSpec('app.fontScaleReset', KeyCommandContext.app, ['mod+0', 'mod+Numpad0']),
  const KeyCommandSpec('app.densityLooser', KeyCommandContext.app, ['mod+shift+=', 'mod+shift+Plus', 'mod+shift+NumpadAdd']),
  const KeyCommandSpec('app.densityDenser', KeyCommandContext.app, ['mod+shift+-', 'mod+shift+_', 'mod+shift+NumpadSubtract']),
  const KeyCommandSpec('app.densityAuto', KeyCommandContext.app, ['mod+shift+0', 'mod+shift+Numpad0']),
  const KeyCommandSpec('logView.find', KeyCommandContext.logView, ['mod+F']),
  for (var n = 1; n <= keyerMessageKeyCount; n++) KeyCommandSpec('keyer.message$n', KeyCommandContext.operation, ['F$n', 'alt+$n']),
  const KeyCommandSpec('keyer.keyboardMode', KeyCommandContext.operation, ['alt+K']),
  const KeyCommandSpec('radio.ptt', KeyCommandContext.operation, ["'"]),
  const KeyCommandSpec('logging.wipe', KeyCommandContext.logging, ['alt+W']),
];

/// How many keyer messages have a command of their own.
const keyerMessageKeyCount = 8;

/// The command [id] names, or null for typed text or an id no longer known.
KeyCommandSpec? keyCommandSpec(String id) {
  for (final spec in keyCommandSpecs) {
    if (spec.id == id) return spec;
  }
  return null;
}

/// PTT: the push-to-talk key (cat_ptt.dart).
const pttCommandId = 'radio.ptt';

/// What the operator changed from the defaults: a command's chords in place
/// of its defaults (none at all, for a command they took every key from),
/// and the chords bound to typed command text. The shape stored in the
/// settings and carried by a keyboard shortcuts file.
@immutable
class KeyBindingOverrides {
  final Map<String, List<KeyChord>> commands;
  final Map<String, List<KeyChord>> text;

  const KeyBindingOverrides({this.commands = const {}, this.text = const {}});

  /// [json] as [toJson] writes it. A chord that does not parse is left out,
  /// and its text added to [unreadable] when given; a command keeps the
  /// chords that did.
  factory KeyBindingOverrides.fromJson(Map<dynamic, dynamic> json, {List<String>? unreadable}) {
    // A list given with chords none of which read stays out altogether:
    // kept as an empty list it would mean "no key", taking the command's
    // defaults with the chords this version cannot read.
    Map<String, List<KeyChord>> read(Object? section) => {
      if (section is Map)
        for (final entry in section.entries)
          if (entry.value is List)
            if (_chordList(entry.value as List, unreadable) case final chords when chords.isNotEmpty || (entry.value as List).isEmpty) '${entry.key}': chords,
    };
    return KeyBindingOverrides(commands: read(json['commands']), text: read(json['text']));
  }

  static List<KeyChord> _chordList(List<dynamic> texts, List<String>? unreadable) {
    final chords = <KeyChord>[];
    for (final text in texts) {
      final chord = KeyChord.parse('$text');
      if (chord != null) {
        chords.add(chord);
      } else {
        unreadable?.add('$text');
      }
    }
    return chords;
  }

  Map<String, dynamic> toJson() => {
    if (commands.isNotEmpty)
      'commands': {
        for (final e in commands.entries) e.key: [for (final c in e.value) '$c'],
      },
    if (text.isNotEmpty)
      'text': {
        for (final e in text.entries) e.key: [for (final c in e.value) '$c'],
      },
  };

  bool get isEmpty => commands.isEmpty && text.isEmpty;

  /// Every chord [KeyChord.translated] through [translation]; a command or
  /// command text whose chords are all left out stays, with none.
  KeyBindingOverrides translated(Map<KeyModifier, KeyModifier?> translation) {
    List<KeyChord> each(List<KeyChord> chords) => [for (final chord in chords) ?chord.translated(translation)];
    return KeyBindingOverrides(commands: {for (final e in commands.entries) e.key: each(e.value)}, text: {for (final e in text.entries) e.key: each(e.value)});
  }

  /// [other] on top of these: its commands and command text in place of the
  /// same ones here, the rest kept.
  KeyBindingOverrides mergedWith(KeyBindingOverrides other) => KeyBindingOverrides(commands: {...commands, ...other.commands}, text: {...text, ...other.text});

  /// The modifiers among `cmd`, `ctrl` and `meta` that any chord here holds.
  Set<KeyModifier> get platformModifiers => {
    for (final chords in [...commands.values, ...text.values])
      for (final chord in chords)
        for (final m in chord.modifiers)
          if (m != KeyModifier.alt && m != KeyModifier.shift) m,
  };

  KeyBindings resolve([TargetPlatform? platform]) => KeyBindings.resolve(overrides: commands, textBindings: text, platform: platform);

  /// With [id] bound to [chords] — and no override left at all when they are
  /// its defaults on [platform].
  KeyBindingOverrides withCommand(String id, List<KeyChord> chords, [TargetPlatform? platform]) {
    final defaults = keyCommandSpec(id)?.defaultChords(platform);
    final isDefault = defaults != null && listEquals(defaults, chords);
    return KeyBindingOverrides(
      commands: {
        for (final entry in commands.entries)
          if (entry.key != id) entry.key: entry.value,
        if (!isDefault) id: List.unmodifiable(chords),
      },
      text: text,
    );
  }

  /// With [command] bound to [chords]. None keeps it listed with no key yet:
  /// command text is there because the operator added it, and goes only when
  /// they remove it ([withoutText]).
  KeyBindingOverrides withText(String command, List<KeyChord> chords) => KeyBindingOverrides(
    commands: commands,
    text: {
      for (final entry in text.entries)
        if (entry.key != command) entry.key: entry.value,
      command: List.unmodifiable(chords),
    },
  );

  /// Without [command] at all.
  KeyBindingOverrides withoutText(String command) => KeyBindingOverrides(
    commands: commands,
    text: {
      for (final entry in text.entries)
        if (entry.key != command) entry.key: entry.value,
    },
  );
}

/// The bindings in force: each command's chords, and the chords bound to
/// typed command text under [textCommandId] ids.
class KeyBindings {
  final Map<String, List<KeyChord>> chords;

  const KeyBindings(this.chords);

  /// The defaults for [platform], with [overrides] — a command's list
  /// replacing its defaults whole, an empty list meaning no key — and
  /// [textBindings] on top. An override for a command that no longer exists
  /// is ignored.
  factory KeyBindings.resolve({
    Map<String, List<KeyChord>> overrides = const {},
    Map<String, List<KeyChord>> textBindings = const {},
    TargetPlatform? platform,
  }) => KeyBindings({
    for (final spec in keyCommandSpecs) spec.id: overrides[spec.id] ?? spec.defaultChords(platform),
    for (final entry in textBindings.entries)
      if (entry.value.isNotEmpty) textCommandId(entry.key): entry.value,
  });

  List<KeyChord> chordsFor(String id) => chords[id] ?? const [];

  /// The chord of [id]'s that [event] is, or null.
  KeyChord? match(String id, KeyEvent event) {
    for (final chord in chordsFor(id)) {
      if (chord.matches(event)) return chord;
    }
    return null;
  }

  bool matches(String id, KeyEvent event) => match(id, event) != null;

  /// [id]'s first chord as the operator reads it, or null with none bound.
  String? label(String id, [TargetPlatform? platform]) => chordsFor(id).firstOrNull?.label(platform);

  /// [id]'s chord that [event] is, unless the focused field takes the key
  /// ([yieldsToField]) — what a handler acts on.
  KeyChord? claim(String id, KeyEvent event) {
    final chord = match(id, event);
    return chord == null || yieldsToField(id, chord, event) ? null : chord;
  }

  /// Whether [event], matched by [id]'s [chord], is a character for the
  /// focused field rather than [id]'s command: a chord with no command
  /// modifier that types something the field would take
  /// ([fieldTakesKey]). Asked by every handler once its chord has matched.
  bool yieldsToField(String id, KeyChord chord, KeyEvent event) {
    if (chord.hasCommandModifier) return false;
    final character = _typed(event);
    return character != null && fieldTakesKey(FocusManager.instance.primaryFocus?.context, character);
  }

  /// The typed command text [event] is bound to, with the chord it matched.
  ({String text, KeyChord chord})? textCommandFor(KeyEvent event) {
    for (final entry in chords.entries) {
      if (!entry.key.startsWith(textCommandPrefix)) continue;
      for (final chord in entry.value) {
        if (chord.matches(event)) return (text: entry.key.substring(textCommandPrefix.length), chord: chord);
      }
    }
    return null;
  }

  /// Every chord bound to more than one command, with the commands it is
  /// bound to.
  List<({KeyChord chord, List<String> ids})> get conflicts {
    final seen = <({KeyChord chord, List<String> ids})>[];
    for (final entry in chords.entries) {
      for (final chord in entry.value) {
        final existing = seen.where((c) => c.chord.samePressAs(chord)).firstOrNull;
        if (existing == null) {
          seen.add((chord: chord, ids: [entry.key]));
        } else if (!existing.ids.contains(entry.key)) {
          existing.ids.add(entry.key);
        }
      }
    }
    return [
      for (final c in seen)
        if (c.ids.length > 1) c,
    ];
  }

  /// The commands other than [id] that [chord] is bound to.
  List<String> othersOn(KeyChord chord, {String? id}) => [
    for (final entry in chords.entries)
      if (entry.key != id && entry.value.any(chord.samePressAs)) entry.key,
  ];
}

/// The bindings with Keyboard Shortcuts off (`EXP KB`): each handler's key
/// test exactly as it was written before bindings existed, so turning the
/// experiment on is the only thing that can change what a key does. [chords]
/// still says what each one is pressed as, for labels.
class LegacyKeyBindings extends KeyBindings {
  LegacyKeyBindings([TargetPlatform? platform]) : super({for (final spec in keyCommandSpecs) spec.id: spec.defaultChords(platform)});

  @override
  KeyChord? match(String id, KeyEvent event) {
    if (!_legacyMatches(id, event)) return null;
    final chords = chordsFor(id);
    // The keyer's ⌥-digit form is the one that types a character — the
    // caller's free-text guard reads it off the chord.
    if (id.startsWith('keyer.message') && HardwareKeyboard.instance.isAltPressed) return chords.last;
    return chords.firstOrNull;
  }

  @override
  ({String text, KeyChord chord})? textCommandFor(KeyEvent event) => null;

  /// Only the two that ever stood aside: the keyer's ⌥-digits in free text,
  /// and ['] wherever a field would take it.
  @override
  bool yieldsToField(String id, KeyChord chord, KeyEvent event) {
    if (id.startsWith('keyer.message')) return chord.modifiers.contains(KeyModifier.alt) && focusInFreeText();
    if (id == pttCommandId) {
      final character = _typed(event);
      return character != null && fieldTakesKey(FocusManager.instance.primaryFocus?.context, character);
    }
    return false;
  }

  static bool _legacyMatches(String id, KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    final alt = keyboard.isAltPressed;
    final shift = keyboard.isShiftPressed;
    final key = event.logicalKey;
    bool any(List<LogicalKeyboardKey> keys) => keys.contains(key);
    const plus = [LogicalKeyboardKey.equal, LogicalKeyboardKey.add, LogicalKeyboardKey.numpadAdd];
    const minus = [LogicalKeyboardKey.minus, LogicalKeyboardKey.underscore, LogicalKeyboardKey.numpadSubtract];
    const zero = [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0];
    switch (id) {
      case 'app.commandDialog':
        return command && key == LogicalKeyboardKey.keyK;
      case 'app.toggleTheme':
        return command && shift && key == LogicalKeyboardKey.keyD;
      case 'app.toggleLanguage':
        return command && shift && key == LogicalKeyboardKey.keyL;
      case 'app.densityLooser':
        return command && shift && any(plus);
      case 'app.densityDenser':
        return command && shift && any(minus);
      case 'app.densityAuto':
        return command && shift && any(zero);
      case 'app.fontScaleUp':
        return command && !shift && any(plus);
      case 'app.fontScaleDown':
        return command && !shift && any(minus);
      case 'app.fontScaleReset':
        return command && !shift && any(zero);
      case 'logView.find':
        return command && !shift && !alt && key == LogicalKeyboardKey.keyF;
      case 'keyer.keyboardMode':
        return alt && !command && !shift && event.physicalKey == PhysicalKeyboardKey.keyK;
      case 'logging.wipe':
        return alt && !command && !shift && key == LogicalKeyboardKey.keyW;
      case pttCommandId:
        return !keyboard.isMetaPressed && !keyboard.isControlPressed && !alt && event.character == "'";
    }
    if (id.startsWith('keyer.message')) {
      final n = int.tryParse(id.substring('keyer.message'.length));
      if (n == null) return false;
      if (command || alt) {
        return alt && !command && !shift && _keysByPhysical[event.physicalKey]?.name == '$n';
      }
      return key == LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + n - 1);
    }
    return false;
  }
}

/// The bindings in force — set by the app from its settings, read by every
/// handler at the moment a key arrives. Starts as the legacy ones, so a
/// widget built without the app (a test) keys as it always has.
final ValueNotifier<KeyBindings> keyBindings = ValueNotifier<KeyBindings>(LegacyKeyBindings());

/// True while the Keyboard Shortcuts settings are listening for a chord to
/// bind: every key goes to the recorder then, ⌘K included.
final ValueNotifier<bool> keyChordRecording = ValueNotifier<bool>(false);

/// Whether the keyboard is in a text field other than the main logging
/// fields — notes, comments, a search — where a chord that
/// [KeyChord.typesCharacter] is a character the operator is typing. The
/// call, RST and exchange fields never take one, so a chord there is the
/// command's.
bool focusInFreeText([BuildContext? focused]) {
  final context = focused ?? FocusManager.instance.primaryFocus?.context;
  if (context == null || context.findAncestorWidgetOfExactType<EditableText>() == null) return false;
  return context.findAncestorWidgetOfExactType<LoggingEntryRow>() == null;
}

/// What [event] types, or null for a key that types nothing: control
/// characters, and the private-use range macOS reports function keys in.
String? _typed(KeyEvent event) {
  final character = event.character;
  if (character == null || character.isEmpty) return null;
  final unit = character.codeUnitAt(0);
  if (unit < 0x20 || unit == 0x7F || (unit >= 0xE000 && unit <= 0xF8FF)) return null;
  return character;
}

/// Whether the field with the keyboard at [focused] takes [character] as
/// text, so a key typing it is the field's rather than a shortcut's.
///
/// The main fields are where the operator works a contact, so there a key is
/// the shortcut's whatever the field would accept — a name or a state
/// included — save the call field reading a command that takes free text,
/// as NOTE does. In the secondary controls a field that would take the
/// character keeps it (a note), and one that would filter it out (the
/// frequency) lets the shortcut have it. Any other text field keeps it
/// whatever it filters. With no field focused there is nothing to take it.
bool fieldTakesKey(BuildContext? focused, String character) {
  final field = focused?.findAncestorWidgetOfExactType<EditableText>();
  if (field == null) return false;
  final row = focused!.findAncestorWidgetOfExactType<LoggingEntryRow>();
  if (row != null) return identical(field.controller, row.call.controller) && _fieldTakes(field, character);
  if (focused.findAncestorWidgetOfExactType<LoggingControls>() == null) return true;
  return !field.readOnly && _fieldTakes(field, character);
}

/// Whether typing [character] into [field] would leave it in the text —
/// asked of the field's own formatters, the same ones the keystroke meets,
/// so a field whose filter changes with its mode (the call field reading a
/// command) answers for the mode it is in.
bool _fieldTakes(EditableText field, String character) {
  final before = field.controller.value;
  final selection = before.selection.isValid ? before.selection : TextSelection.collapsed(offset: before.text.length);
  final kept = before.text.replaceRange(selection.start, selection.end, '');
  final typed = TextEditingValue(
    text: before.text.replaceRange(selection.start, selection.end, character),
    selection: TextSelection.collapsed(offset: selection.start + character.length),
  );
  // Not the length limit: a field that is full right now still takes the
  // character as text, and a key typing it must not run a shortcut instead.
  final formatters = [...?field.inputFormatters].where((formatter) => formatter is! LengthLimitingTextInputFormatter);
  final after = formatters.fold(typed, (value, formatter) => formatter.formatEditUpdate(before, value));
  return character.allMatches(after.text).length > character.allMatches(kept).length;
}

/// Why [chord] cannot be bound to [id] at all, or null when it can.
enum KeyChordRefusal {
  /// A key the logging panel, a dialog or a field owns
  /// (docs/design/keyboard-shortcuts.md § Fixed keys).
  fixed,

  /// A callsign key — a letter, a digit, `,` `.` `/` — with at most ⇧.
  callsignKey,
}

final _fieldKeys = {
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.backspace,
  LogicalKeyboardKey.delete,
};

KeyChordRefusal? keyChordRefusal(KeyChord chord, String id, [TargetPlatform? platform]) {
  if (chord.key == LogicalKeyboardKey.escape) return KeyChordRefusal.fixed;
  if (!chord.hasCommandModifier && !chord.modifiers.contains(KeyModifier.alt) && _fieldKeys.contains(chord.key)) return KeyChordRefusal.fixed;
  // The QSO list's walk (qso_list_walk.dart): ⌥ and ⌘ on Up and Down.
  final vertical = chord.key == LogicalKeyboardKey.arrowUp || chord.key == LogicalKeyboardKey.arrowDown;
  if (vertical && !chord.modifiers.contains(KeyModifier.shift) && !chord.modifiers.contains(KeyModifier.ctrl)) {
    if (chord.modifiers.length == 1) return KeyChordRefusal.fixed;
  }
  // Undo of a wipe or a staged delete, and every text field's own undo.
  if (chord.key == LogicalKeyboardKey.keyZ) {
    final undo = KeyChord(LogicalKeyboardKey.keyZ, {isApplePlatform(platform) ? KeyModifier.cmd : KeyModifier.ctrl});
    if (chord.samePressAs(undo)) return KeyChordRefusal.fixed;
  }
  if (chord.isCallsignKey) return KeyChordRefusal.callsignKey;
  return null;
}

/// Chords the system or the browser is likely to take before the app sees
/// them, or that every text field needs — bindable, with a warning.
bool isReservedKeyChord(KeyChord chord, [TargetPlatform? platform]) {
  final apple = isApplePlatform(platform);
  final reserved = [
    if (apple) ...['cmd+Q', 'cmd+H', 'cmd+alt+H', 'cmd+M', 'cmd+W', 'cmd+C', 'cmd+V', 'cmd+X', 'cmd+A', 'cmd+,', 'cmd+Tab', 'cmd+Space', 'cmd+ctrl+F'],
    if (!apple) ...['ctrl+C', 'ctrl+V', 'ctrl+X', 'ctrl+A', 'alt+F4', 'alt+Tab'],
    if (kIsWeb) ...[
      for (final k in ['W', 'T', 'N']) '${apple ? 'cmd' : 'ctrl'}+$k',
    ],
  ];
  return reserved.any((text) => KeyChord.parse(text)!.samePressAs(chord));
}
