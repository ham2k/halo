// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keyboard shortcuts as a file: the operator's changes from the defaults,
// written as YAML with the platform they were made on, for another device to
// translate on import (docs/design/keyboard-shortcuts.md § Files).

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:halo_widgets/halo_widgets.dart';
import 'package:yaml/yaml.dart';

import '../views/command_engine.dart' show commandTextParts;
import '../views/dock_layouts/yaml_reader.dart';
import '../views/dock_layouts/yaml_writer.dart' as yaml_writer;

/// The top-level key that marks a shortcuts file, and the format version it
/// carries. A reader refuses a version it does not know rather than guessing
/// at a shape that was never written for it.
const keyBindingsFileMarker = 'ham2k-keys';
const keyBindingsFileVersion = 1;

/// What an exported file is named with. The content is YAML, but a name of
/// its own says which app the file is for.
const keyBindingsFileExtension = 'h2kkey';

/// An export's name before the extension: the profile's callsign after
/// "Keyboard Shortcuts", so one device's files for several profiles stay
/// apart — `KI2D/P` as `KI2D-P`, since a file system takes the slash as a
/// folder.
String keyBindingsFileStem(String callsign) {
  final call = callsign.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  return call.isEmpty ? 'Keyboard Shortcuts' : 'Keyboard Shortcuts $call';
}

/// Why a file is not one this version can read — what the operator is told,
/// in their language.
enum KeyBindingsFileProblem { notYaml, notKeysFile, newerVersion, malformed, tooLarge }

class KeyBindingsFileException implements Exception {
  final KeyBindingsFileProblem problem;

  /// The line the YAML parser stopped at, for [KeyBindingsFileProblem.notYaml].
  final int? line;

  /// Which part of the file, in English: for the console, never the screen.
  final String detail;

  const KeyBindingsFileException(this.problem, this.detail, {this.line});

  @override
  String toString() => '${problem.name}: $detail';
}

class KeyBindingsFile {
  /// The platform the file was written on — a [platformToken], with a browser
  /// named by the OS it ran on, since that is the keyboard it was pressed on.
  final String? platform;
  final KeyBindingOverrides overrides;

  /// Chords in the file that do not parse, left out of [overrides].
  final List<String> unreadable;

  const KeyBindingsFile({this.platform, required this.overrides, this.unreadable = const []});

  String toYaml() => '# Ham2K Logger keyboard shortcuts\n${yaml_writer.toYaml(toJson())}';

  Map<String, dynamic> toJson() => {keyBindingsFileMarker: keyBindingsFileVersion, 'platform': ?platform, ...overrides.toJson()};

  /// The commands the file binds that this version does not know.
  List<String> get unknownCommands => [
    for (final id in overrides.commands.keys)
      if (keyCommandSpec(id) == null) id,
  ];

  /// What an import takes from the file, its modifiers read through
  /// [translation]: the commands this version knows, with the chords the
  /// recorder would refuse left out and returned as [refused] — a file is no
  /// way round the fixed keys.
  ({KeyBindingOverrides overrides, List<KeyChord> refused}) importable(Map<KeyModifier, KeyModifier?> translation) {
    final translated = KeyBindingOverrides(
      commands: {
        for (final e in overrides.commands.entries)
          if (keyCommandSpec(e.key) != null) e.key: e.value,
      },
      text: overrides.text,
    ).translated(translation);
    final refused = <KeyChord>[];
    List<KeyChord> allowed(String id, List<KeyChord> chords) {
      final kept = <KeyChord>[];
      for (final chord in chords) {
        (keyChordRefusal(chord, id) == null ? kept : refused).add(chord);
      }
      return kept;
    }

    return (
      overrides: KeyBindingOverrides(
        commands: {
          // A command whose every chord was refused keeps its defaults, rather
          // than an empty list that would read as "no key".
          for (final e in translated.commands.entries)
            if (allowed(e.key, e.value) case final kept when kept.isNotEmpty || e.value.isEmpty) e.key: kept,
        },
        text: {for (final e in translated.text.entries) e.key: allowed(textCommandId(e.key), e.value)},
      ),
      refused: refused,
    );
  }

  /// Throws [KeyBindingsFileException] for anything that is not a shortcuts
  /// file this version can read.
  static KeyBindingsFile parse(String text) {
    try {
      return _parse(text);
    } on StackOverflowError {
      throw const KeyBindingsFileException(KeyBindingsFileProblem.tooLarge, 'nested too deeply to read');
    }
  }

  static KeyBindingsFile _parse(String text) {
    final Object? document;
    try {
      document = loadPlainYaml(text);
    } on YamlTooLargeException catch (e) {
      throw KeyBindingsFileException(KeyBindingsFileProblem.tooLarge, e.detail);
    } on YamlException catch (e) {
      throw KeyBindingsFileException(KeyBindingsFileProblem.notYaml, e.message, line: e.span == null ? null : e.span!.start.line + 1);
    }
    if (document is! Map) throw const KeyBindingsFileException(KeyBindingsFileProblem.notKeysFile, 'the document is not a map');
    final version = document[keyBindingsFileMarker];
    if (version is! int) throw const KeyBindingsFileException(KeyBindingsFileProblem.notKeysFile, 'no "$keyBindingsFileMarker" version');
    if (version > keyBindingsFileVersion) throw KeyBindingsFileException(KeyBindingsFileProblem.newerVersion, 'format $version');
    for (final section in ['commands', 'text']) {
      final value = document[section];
      if (value == null) continue;
      if (value is! Map || value.values.any((chords) => chords is! List)) {
        throw KeyBindingsFileException(KeyBindingsFileProblem.malformed, '"$section" is not a map of lists');
      }
    }
    final unreadable = <String>[];
    final overrides = KeyBindingOverrides.fromJson(document, unreadable: unreadable);
    // Command text with no command in it — empty, or only `;` — would claim
    // its key and run nothing.
    final emptyText = [
      for (final command in overrides.text.keys)
        if (commandTextParts(command).isEmpty) command,
    ];
    unreadable.addAll(emptyText.map((command) => '"$command"'));
    return KeyBindingsFile(
      platform: document['platform'] is String ? document['platform'] as String : null,
      overrides: emptyText.fold(overrides, (o, command) => o.withoutText(command)),
      unreadable: unreadable,
    );
  }
}

/// The platform a file is written on, by the keyboard it was pressed on: a
/// browser is named by the OS it runs on, unlike [platformToken].
String keyboardPlatformToken() => defaultTargetPlatform.name.toLowerCase();

/// Whether [platform], a [platformToken], has Apple's keyboard — ⌘ rather
/// than a Windows or Super key. Null for a platform the file did not say.
bool? platformHasAppleKeyboard(String? platform) => switch (platform) {
  'macos' || 'ios' => true,
  'windows' || 'linux' || 'android' => false,
  _ => null,
};

/// The modifiers a chord pressed on this device can hold among `cmd`, `ctrl`
/// and `meta`: `cmd` and `ctrl` on Apple's keyboards, `ctrl` and `meta`
/// elsewhere.
List<KeyModifier> localPlatformModifiers() => isApplePlatform() ? [KeyModifier.cmd, KeyModifier.ctrl] : [KeyModifier.ctrl, KeyModifier.meta];

/// What each of [modifiers] (from a file written on [fromPlatform]) most
/// likely means on this device — what the import dialog starts from. Null
/// leaves those shortcuts out.
Map<KeyModifier, KeyModifier?> suggestedTranslation(Set<KeyModifier> modifiers, String? fromPlatform) {
  final fromApple = platformHasAppleKeyboard(fromPlatform);
  final toApple = isApplePlatform();
  KeyModifier? suggest(KeyModifier m) {
    if (fromApple == null || fromApple == toApple) {
      // Same keyboard family: each key is itself, a `meta` written on a Mac
      // being its ⌘ and a `cmd` written elsewhere its Windows key.
      return switch (m) {
        KeyModifier.cmd || KeyModifier.meta => toApple ? KeyModifier.cmd : KeyModifier.meta,
        _ => m,
      };
    }
    // Across families the command key is ⌘ on a Mac and Ctrl elsewhere, so
    // that is what trades: ⌘K becomes Ctrl+K and back.
    if (fromApple) {
      return switch (m) {
        KeyModifier.cmd || KeyModifier.meta => KeyModifier.ctrl,
        KeyModifier.ctrl => KeyModifier.meta,
        _ => m,
      };
    }
    return switch (m) {
      KeyModifier.ctrl => KeyModifier.cmd,
      KeyModifier.cmd || KeyModifier.meta => KeyModifier.ctrl,
      _ => m,
    };
  }

  return {for (final m in modifiers) m: suggest(m)};
}
