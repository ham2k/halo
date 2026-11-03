// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps the bindings in force (halo_widgets' `keyBindings`) in step with the
// settings and the Keyboard Shortcuts experiment, and tells iOS which ⌘
// chords to claim (docs/design/keyboard-shortcuts.md).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'error_reporting_service.dart';
import 'sets/set_tree.dart';
import 'settings_service.dart';

/// The Keyboard Shortcuts experiment's key in experiments.yaml.
const keyBindingsExperiment = 'kb';

/// A named set of keyboard shortcuts: the commands and command text whose
/// keys differ from the defaults.
@immutable
class KeyBindingSet {
  final String id;
  final String name;

  /// Commands and command text only: MIDI controls belong to no set.
  final KeyBindingOverrides keys;

  const KeyBindingSet({required this.id, required this.name, this.keys = const KeyBindingOverrides()});

  factory KeyBindingSet.fromJson(Map<dynamic, dynamic> json) {
    final keys = KeyBindingOverrides.fromJson(json);
    return KeyBindingSet(
      id: json['id'] as String,
      name: json['name'] is String ? json['name'] as String : '',
      keys: KeyBindingOverrides(commands: keys.commands, text: keys.text),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, ...keys.toJson()};

  KeyBindingSet withKeys(KeyBindingOverrides keys) => KeyBindingSet(
    id: id,
    name: name,
    keys: KeyBindingOverrides(commands: keys.commands, text: keys.text),
  );

  KeyBindingSet renamed(String name) => KeyBindingSet(id: id, name: name, keys: keys);

  KeyBindingSet copiedAs({required String id, required String name}) => KeyBindingSet(id: id, name: name, keys: keys);
}

class KeyBindingsService extends ChangeNotifier {
  final SettingsService settings;

  /// The channel AppDelegate.swift registers its UIKeyCommands from.
  static const _channel = MethodChannel('ham2k/key_commands');

  /// The MIDI controls bound to commands: `{midi: {id: [control]}}`. They
  /// belong to the controller, so no set holds them. Device-local and never
  /// synced, like the station's equipment. A device whose [setsPrefsKey] is
  /// not written yet keeps its one set of changes here too, as `commands`
  /// and `text`.
  static const prefsKey = 'keyBindings';

  /// The sets: `{active: id, sets: [{id, name, commands, text}], tree:
  /// {...}}`, each holding only what differs from the defaults. Device-local
  /// and never synced: a keyboard is per-device.
  static const setsPrefsKey = 'keyBindingSets';

  /// The set that is the app's own keys: never stored, never changed.
  static const appDefaultsId = 'app-defaults';

  /// The set a device's changes from before sets become.
  static const _carriedId = 'carried';

  KeyBindingsService(this.settings) {
    settings.addListener(_apply);
    _apply();
  }

  bool get enabled => settings.experimentEnabled(keyBindingsExperiment);

  Map<String, dynamic> get _stored => settings.jsonMapPref(prefsKey);

  /// The changes a device made before there were sets — until the first
  /// write of a set takes them over, the set they are read as.
  KeyBindingOverrides? get _carried {
    if (settings.jsonMapPref(setsPrefsKey).isNotEmpty) return null;
    final carried = KeyBindingOverrides.fromJson(_stored);
    return carried.commands.isEmpty && carried.text.isEmpty ? null : KeyBindingOverrides(commands: carried.commands, text: carried.text);
  }

  /// The stored sets, App Defaults not among them.
  List<KeyBindingSet> get sets {
    if (_carried case final carried?) return [KeyBindingSet(id: _carriedId, name: t.keyboardShortcuts.sets.carriedName, keys: carried)];
    return [
      if (settings.jsonMapPref(setsPrefsKey)['sets'] case final List<dynamic> list)
        for (final entry in list)
          if (entry is Map && entry['id'] is String) KeyBindingSet.fromJson(entry),
    ];
  }

  /// The set in use: App Defaults where the one stored is gone.
  String get activeSetId {
    if (_carried != null) return _carriedId;
    final id = settings.jsonMapPref(setsPrefsKey)['active'];
    return id is String && sets.any((set) => set.id == id) ? id : appDefaultsId;
  }

  bool get onAppDefaults => activeSetId == appDefaultsId;

  SetTree get tree => SetTree.fromJson(settings.jsonMapPref(setsPrefsKey)['tree']);

  /// Stores [sets], with [active] in use and the folders as [tree] (as they
  /// are where null). The first write takes over the changes a device made
  /// before there were sets, leaving [prefsKey] its MIDI controls alone.
  Future<void> setSets(List<KeyBindingSet> sets, {required String active, SetTree? tree}) async {
    final folders = tree ?? this.tree;
    await settings.setJsonMapPref(setsPrefsKey, {
      'active': active,
      'sets': [for (final set in sets) set.toJson()],
      'tree': folders.toJson(),
    });
    final stored = _stored;
    if (stored.containsKey('commands') || stored.containsKey('text')) {
      await settings.setJsonMapPref(prefsKey, KeyBindingOverrides(midi: KeyBindingOverrides.fromJson(stored).midi).toJson());
    }
    _apply();
    notifyListeners();
  }

  /// The set in use's changes, with the device's MIDI controls — every one
  /// of them, those bound to command text this set lacks included, so that
  /// binding a control elsewhere still takes it off them.
  KeyBindingOverrides get overrides {
    final keys = sets.where((set) => set.id == activeSetId).firstOrNull?.keys ?? const KeyBindingOverrides();
    return KeyBindingOverrides(commands: keys.commands, text: keys.text, midi: KeyBindingOverrides.fromJson(_stored).midi);
  }

  /// Stores [overrides]' keys in the set in use and its MIDI controls for
  /// the device. A control bound to command text the set in use does not
  /// hold is kept as it was — it waits for a set that has that text — and so
  /// is one on text this set drops while another set still holds it: the
  /// controls are the device's, and the other set's row still shows them.
  /// [overrides] binding the control to something else takes it either way.
  ///
  /// Throws [StateError] for keys on App Defaults, which hold none.
  Future<void> setOverrides(KeyBindingOverrides overrides) async {
    final current = sets, active = activeSetId, before = this.overrides;
    if (active == appDefaultsId && (overrides.commands.isNotEmpty || overrides.text.isNotEmpty)) {
      throw StateError('App Defaults keep the app’s own keys');
    }
    bool heldElsewhere(String text) => current.any((set) => set.id != active && set.keys.text.containsKey(text));
    final taken = {for (final controls in overrides.midi.values) ...controls};
    final waiting = {
      for (final entry in before.midi.entries)
        if (entry.key.startsWith(textCommandPrefix) && !overrides.midi.containsKey(entry.key))
          if (entry.key.substring(textCommandPrefix.length) case final text
              when !overrides.text.containsKey(text) && (!before.text.containsKey(text) || heldElsewhere(text)))
            if ([
                  for (final control in entry.value)
                    if (!taken.contains(control)) control,
                ]
                case final kept when kept.isNotEmpty)
              entry.key: kept,
    };
    final midi = KeyBindingOverrides(midi: {...waiting, ...overrides.midi});
    if (active != appDefaultsId) {
      final keys = KeyBindingOverrides(commands: overrides.commands, text: overrides.text);
      await setSets([for (final set in current) set.id == active ? set.withKeys(keys) : set], active: active);
    }
    await settings.setJsonMapPref(prefsKey, midi.toJson());
    _apply();
    notifyListeners();
  }

  String? _lastNative;

  KeyBindingOverrides _midiOverrides = const KeyBindingOverrides();

  /// The command a MIDI control presses (KeyBindingOverrides.midi) — none
  /// with the experiment off, as no rebound key acts then either.
  String? midiCommandFor(String control) => _midiOverrides.midiCommandFor(control);

  void _apply() {
    final overrides = this.overrides;
    // A control bound to command text the set in use lacks presses nothing:
    // no row would show what it runs.
    _midiOverrides = enabled ? KeyBindingOverrides(midi: overrides.midiKeptWith(overrides.text)) : const KeyBindingOverrides();
    final next = enabled ? overrides.resolve() : LegacyKeyBindings();
    keyBindings.value = next;
    _syncNative(next);
  }

  /// iOS hands a ⌘ chord to the app only when it is registered as a
  /// UIKeyCommand, so the ones the app-wide handler runs are sent there. Null
  /// puts back the list AppDelegate.swift holds itself, which is the one the
  /// legacy bindings key.
  void _syncNative(KeyBindings bindings) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final commands = bindings is LegacyKeyBindings ? null : iosKeyCommands(bindings);
    final encoded = jsonEncode(commands);
    if (encoded == _lastNative) return;
    // Recorded only once iOS has taken it: a list it refused is sent again on
    // the next change rather than taken for the one in force.
    _channel
        .invokeMethod<void>('setKeyCommands', commands)
        .then((_) => _lastNative = encoded, onError: (Object e, StackTrace stack) => ErrorReportingService.report(e, stack, context: 'keys:ios-sync'));
  }

  @override
  void dispose() {
    settings.removeListener(_apply);
    super.dispose();
  }
}

/// The ⌘ chords of the commands the app-wide handler runs — the `app.*`
/// commands and bound command text — as UIKeyCommand inputs: a chord whose
/// key types a character, which is all UIKeyCommand's `input` can name here.
@visibleForTesting
List<Map<String, dynamic>> iosKeyCommands(KeyBindings bindings) => [
  for (final entry in bindings.chords.entries)
    if (entry.key.startsWith('app.') || entry.key.startsWith(textCommandPrefix))
      for (final chord in entry.value)
        if (chord.modifiers.contains(KeyModifier.cmd) || chord.modifiers.contains(KeyModifier.meta))
          if (chord.character case final character?)
            {
              'id': entry.key,
              'input': character,
              'modifiers': [
                'cmd',
                for (final m in [KeyModifier.ctrl, KeyModifier.alt, KeyModifier.shift])
                  if (chord.modifiers.contains(m)) m.name,
              ],
            },
];
