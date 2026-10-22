// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps the bindings in force (halo_widgets' `keyBindings`) in step with the
// settings and the Keyboard Shortcuts experiment, and tells iOS which ⌘
// chords to claim (docs/design/keyboard-shortcuts.md).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'error_reporting_service.dart';
import 'settings_service.dart';

/// The Keyboard Shortcuts experiment's key in experiments.yaml.
const keyBindingsExperiment = 'kb';

class KeyBindingsService extends ChangeNotifier {
  final SettingsService settings;

  /// The channel AppDelegate.swift registers its UIKeyCommands from.
  static const _channel = MethodChannel('ham2k/key_commands');

  /// Where the operator's changes are stored: `{commands: {id: [chord]},
  /// text: {command text: [chord]}}`, only what differs from the defaults.
  /// Device-local and never synced, like the station's equipment: a keyboard
  /// is per-device.
  static const prefsKey = 'keyBindings';

  KeyBindingsService(this.settings) {
    settings.addListener(_apply);
    _apply();
  }

  bool get enabled => settings.experimentEnabled(keyBindingsExperiment);

  /// The operator's changes, as stored.
  KeyBindingOverrides get overrides => KeyBindingOverrides.fromJson(settings.jsonMapPref(prefsKey));

  Future<void> setOverrides(KeyBindingOverrides overrides) async {
    await settings.prefs.setString(prefsKey, jsonEncode(overrides.toJson()));
    _apply();
    notifyListeners();
  }

  String? _lastNative;

  void _apply() {
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
