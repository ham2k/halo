// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension assistants (docs/extensions/assistants.md): hooks that watch what
// the operator does in every open operation and answer through the host —
// the FYI line, notices, band annotations, the radio — with nothing on
// screen of their own. Switched on or off app-wide, in Settings › Assistants.
// When they are called is [WatcherService]'s.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../views/operation/panel_scene/cat_spectrum_source.dart';
import 'cat/cat_service.dart';
import 'settings_service.dart';
import 'watcher_service.dart';

/// The slice of [ExtensionService] the assistants use, named so their rules
/// can be tested without a JS runtime.
abstract interface class AssistantExtensionSource {
  /// Ticks after every runtime (re)start: the assistants a runtime offers are
  /// only knowable by asking it.
  Listenable get runtimeGeneration;

  /// Null when the runtime could not be asked.
  Future<List<Map<String, dynamic>>?> getExtensionAssistants();

  /// Throws when the hook does; false when there was no runtime to call.
  Future<bool> observe({required String hookKey, required String assistantKey, required Map<String, dynamic> args});

  Future<Map<String, dynamic>> readPanelConfig({required String panelKey, required List<Map<String, dynamic>> fields});

  /// Whether [hookKey]'s extension may read the radio (`requiresRadioRead`):
  /// the `radio` trigger fires for no one else.
  bool canReadRadio(String? hookKey);

  /// Takes the spot marks off every extension that offers assistants
  /// ([offered], by hook key) and has none of them on ([on]): one switched
  /// off is never called again to take back what it hid or picked.
  void releaseSpotMarks({required Set<String> offered, required Set<String> on});
}

/// Where the operator's on/off switch for each assistant is kept.
abstract interface class AssistantSwitches {
  bool? read(String id);
  Future<void> write(String id, bool enabled);
}

class AssistantService extends WatcherService {
  final AssistantExtensionSource extensions;
  final AssistantSwitches switches;

  /// The app's: switches in its prefs, the radio's dial from its CAT
  /// connections. Asks the extensions at once; the first operation view to
  /// open hears `open` when they answer.
  factory AssistantService.forApp(AssistantExtensionSource extensions, {required SettingsService settings, required CatService cat}) {
    final dial = CatSpectrumSource(cat, settings: settings);
    final service = AssistantService(extensions, switches: _PrefsAssistantSwitches(settings), radio: (changes: dial.readingChanges, state: dial.dialState));
    unawaited(service.refresh());
    return service;
  }

  AssistantService(this.extensions, {required this.switches, super.radio}) : super(runtimeGeneration: extensions.runtimeGeneration);

  @override
  String get kind => 'assistant';

  bool isEnabled(WatcherDefinition assistant) => switches.read(assistant.id) ?? assistant.enabledByDefault;

  @override
  bool isOnFor(WatcherDefinition watcher, WatcherFeed feed) => isEnabled(watcher);

  /// Switched on, an assistant is on for every operation, open or not yet.
  @override
  bool isOnAnywhere(WatcherDefinition watcher) => isEnabled(watcher);

  Future<void> setEnabled(WatcherDefinition assistant, bool enabled) async {
    if (isEnabled(assistant) == enabled) return;
    await switches.write(assistant.id, enabled);
    reconcile();
    notifyListeners();
  }

  @override
  Future<List<Map<String, dynamic>>?> fetchCatalog() => extensions.getExtensionAssistants();

  @override
  bool canReadRadio(String hookKey) => extensions.canReadRadio(hookKey);

  @override
  Future<Map<String, dynamic>> readConfig(WatcherDefinition watcher) => extensions.readPanelConfig(panelKey: watcher.id, fields: watcher.formFields);

  @override
  Future<bool> observe(WatcherDefinition watcher, WatcherFeed feed, Map<String, dynamic> args) {
    final qso = feed.context.qso;
    return extensions.observe(
      hookKey: watcher.hookKey,
      assistantKey: watcher.key,
      args: {
        'assistantKey': watcher.key,
        ...args,
        // Only to one that declared it: the draft is the operator's
        // keystrokes, and other features produce it too.
        if (qso != null && (watcher.triggers.contains('qso') || watcher.triggers.contains('lookup'))) 'qso': qso,
      },
    );
  }

  @override
  void reconciled() => extensions.releaseSpotMarks(
    offered: {for (final assistant in catalog) assistant.hookKey},
    on: {
      for (final assistant in catalog)
        if (isEnabled(assistant)) assistant.hookKey,
    },
  );
}

/// An assistant's on/off switch, kept in the app's prefs beside its settings.
class _PrefsAssistantSwitches implements AssistantSwitches {
  final SettingsService settings;
  _PrefsAssistantSwitches(this.settings);

  @override
  bool? read(String id) => settings.prefs.getBool('$id.enabled');

  @override
  Future<void> write(String id, bool enabled) => settings.prefs.setBool('$id.enabled', enabled);
}
