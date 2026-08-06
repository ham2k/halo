// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The catalog of panels a customizable view can hold (docs/design/layouts.md).
// Two sources, one list: the app registers its NATIVE panels here, and every
// extension `panel` hook contributes its own (docs/extensions/hooks.md).
//
// This service owns panel IDENTITY — id, title, description, icon, preview,
// what a panel re-renders on, and where its settings live. It deliberately
// owns no widgets: a native panel's widget stays with the view that builds
// it, and an extension panel's content is a document this service fetches
// and `PanelContentView` draws. That split is what lets the Layout Setup
// sheet list panels it has no way to build.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Where a panel comes from, which decides how the view gets its content.
enum PanelSource { native, extension }

class PanelDefinition {
  /// Stable across releases — it is persisted inside saved layouts, so
  /// changing one drops that panel out of every arrangement holding it.
  /// Extension panels are namespaced `ext:<hookKey>:<panelKey>`, which is
  /// also what keeps two extensions from colliding on a plain key.
  final String id;
  final String title;
  final String? description;
  final String? icon;

  /// An SVG document or a `data:` URI — never a URL. The sheet that shows
  /// it has to render offline, and a remote preview would be a fetch (and a
  /// beacon) fired by merely opening the panel list.
  final String? preview;

  final PanelSource source;

  /// Extension panels only: what routes calls back to the registering hook,
  /// and the panel's own key within it.
  final String? hookKey;
  final String? panelKey;

  /// What this panel asks to be re-rendered on ('operation', 'qso',
  /// 'qsoLogged', 'lookup', 'spots', `tick:<seconds>`). Empty means "render
  /// once" — right for static reference material, and the default, so a
  /// panel that says nothing about triggers costs nothing per keystroke.
  final List<String> triggers;

  /// The panel's declarative config fields, in the settings-panel field
  /// schema. Empty when the panel has nothing to configure — which is what
  /// decides whether a settings control appears next to it at all.
  final List<Map<String, dynamic>> formFields;

  /// Native panels whose settings are assembled from declared settings
  /// targeting them (the logging panel's tune dialog), rather than from a
  /// form of their own.
  final String? settingsTarget;

  const PanelDefinition({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    this.preview,
    required this.source,
    this.hookKey,
    this.panelKey,
    this.triggers = const [],
    this.formFields = const [],
    this.settingsTarget,
  });

  bool get hasSettings => formFields.isNotEmpty || settingsTarget != null;

  /// Value equality so a re-registration with identical content is a no-op:
  /// native panels are registered from `didChangeDependencies`, which runs
  /// far more often than their identity changes, and every notification is
  /// a rebuild of everything listening to the catalog.
  @override
  bool operator ==(Object other) =>
      other is PanelDefinition &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.icon == icon &&
      other.preview == preview &&
      other.source == source &&
      other.hookKey == hookKey &&
      other.panelKey == panelKey &&
      other.settingsTarget == settingsTarget &&
      listEquals(other.triggers, triggers) &&
      other.formFields.length == formFields.length;

  @override
  int get hashCode => Object.hash(id, title, description, icon, preview, source, hookKey, panelKey, settingsTarget);

  /// Reads one entry of `getExtensionPanels`. Returns null for an entry
  /// missing what a panel cannot work without — an extension bug should
  /// cost that panel, not the whole catalog.
  static PanelDefinition? fromExtensionEntry(Map<String, dynamic> entry) {
    final hookKey = entry['hookKey'] as String?;
    final panelKey = entry['key'] as String?;
    final title = entry['title'] as String?;
    if (hookKey == null || panelKey == null || title == null) return null;
    return PanelDefinition(
      id: extensionPanelId(hookKey: hookKey, panelKey: panelKey),
      title: title,
      description: entry['description'] as String?,
      icon: entry['icon'] as String?,
      preview: entry['preview'] as String?,
      source: PanelSource.extension,
      hookKey: hookKey,
      panelKey: panelKey,
      triggers: [
        for (final t in (entry['on'] as List?) ?? const [])
          if (t is String && isKnownPanelTrigger(t))
            t
          else
            ...() {
              debugPrint('[panels] "$panelKey" asked for an unrecognized trigger ($t); it will never fire');
              return const <String>[];
            }(),
      ],
      formFields: [
        for (final f in (entry['form'] as List?) ?? const [])
          // A field with no key renders in the form and can never be saved
          // or handed back as `config`, so the operator would fill in a
          // control that does nothing.
          if (f is Map && f['key'] is String)
            f.cast<String, dynamic>()
          else
            ...() {
              debugPrint('[panels] dropping a config field with no key from "$panelKey"');
              return const <Map<String, dynamic>>[];
            }(),
      ],
    );
  }

  static String extensionPanelId({required String hookKey, required String panelKey}) => 'ext:$hookKey:$panelKey';
}

/// The triggers the host actually fires, plus `tick:<seconds>`. A name
/// outside this set is accepted by the SDK's TypeScript types but would sit
/// in a descriptor doing nothing, so it is rejected at parse time WITH a
/// line in the console — a panel that renders once and never again is
/// otherwise indistinguishable from a panel that meant to.
const knownPanelTriggers = {'operation', 'qso', 'qsoLogged', 'lookup', 'spots'};

bool isKnownPanelTrigger(String trigger) {
  if (knownPanelTriggers.contains(trigger)) return true;
  if (!trigger.startsWith('tick:')) return false;
  final seconds = int.tryParse(trigger.substring(5));
  return seconds != null && seconds > 0;
}

/// How often a panel may be re-rendered, however often its triggers fire.
/// A trigger is a hint that something changed, not a demand for a frame:
/// 'qso' fires as fast as the operator types, and every render crosses the
/// JS bridge.
const panelRenderThrottle = Duration(milliseconds: 750);

/// The shortest `tick:<seconds>` a panel may ask for. A panel wanting to be
/// live to the second wants a native panel, not a bridge call a second.
const minPanelTickSeconds = 5;

/// The narrow slice of [ExtensionService] the catalog uses. Named so the
/// catalog's own rules — what a failed read means, what a malformed
/// descriptor costs — can be tested without booting a JS runtime, which is
/// the difference between testing them and asserting they were written.
abstract interface class PanelExtensionSource {
  /// Ticks after every successful runtime (re)start, which is the path an
  /// extension enable/disable toggle takes. The panels a runtime offers are
  /// only knowable by asking it, so without this a catalog read before the
  /// runtime came up would stay unresolved for the session.
  Listenable get runtimeGeneration;

  /// Null when the runtime could not be asked at all.
  Future<List<Map<String, dynamic>>?> getExtensionPanels();

  Future<Map<String, dynamic>?> renderPanel({
    required String hookKey,
    required String panelKey,
    required Map<String, dynamic> args,
  });

  Future<Map<String, dynamic>> readPanelConfig({
    required String panelKey,
    required List<Map<String, dynamic>> fields,
  });
}

class PanelService extends ChangeNotifier {
  final PanelExtensionSource extensions;

  PanelService(this.extensions) {
    extensions.runtimeGeneration.addListener(_onRuntimeReplaced);
  }

  /// A fresh runtime carries a different set of extensions, so the panels it
  /// offers have to be re-read rather than served from the old set's answer.
  /// Without this a view that stays mounted across a trip to Settings only
  /// notices a newly enabled extension's panels when something else happens
  /// to ask — which, before this, meant opening the Layout Setup sheet.
  void _onRuntimeReplaced() {
    unawaited(refreshExtensionPanels());
  }

  @override
  void dispose() {
    _disposed = true;
    extensions.runtimeGeneration.removeListener(_onRuntimeReplaced);
    super.dispose();
  }

  /// A refresh already awaiting the bridge cannot be cancelled, and reaching
  /// `notifyListeners()` on a disposed ChangeNotifier throws — out of an
  /// unawaited call, where ErrorPolicy would show the operator a notice for
  /// an ordinary teardown. A flag, not a try/catch: swallowing at the throw
  /// site is what error-reporting.md forbids.
  bool _disposed = false;

  final _native = <String, PanelDefinition>{};
  List<PanelDefinition> _extensionPanels = const [];
  final _configRevisions = <String, int>{};

  /// Counts refresh passes so a slower one cannot install its answer over a
  /// newer one's. Two restarts in quick succession — a toggle landing on a
  /// crash recovery — otherwise race on a 10-second bridge call, and the
  /// loser's catalog would stand for the rest of the session.
  int _refreshSeq = 0;

  /// Registered by the app at startup, before any view asks for a catalog.
  /// Re-registering an id replaces it — the app owns these outright, so a
  /// second registration is a correction, not a conflict.
  void registerNative(PanelDefinition panel) {
    assert(panel.source == PanelSource.native);
    if (_native[panel.id] == panel) return;
    _native[panel.id] = panel;
    notifyListeners();
  }

  /// Every panel, native first in registration order and extension panels
  /// after — a view's own panes are the ones an operator is looking for.
  List<PanelDefinition> get catalog => [..._native.values, ..._extensionPanels];

  PanelDefinition? operator [](String id) =>
      _native[id] ?? _extensionPanels.where((p) => p.id == id).firstOrNull;

  /// Re-reads what the extensions offer — on every runtime (re)start, and
  /// whenever a caller wants to be certain (the layout sheet asks on open).
  /// Cheap to repeat: one bridge call.
  Future<void> refreshExtensionPanels() async {
    final seq = ++_refreshSeq;
    final entries = await extensions.getExtensionPanels();
    // A newer pass started while this one was on the bridge; its answer
    // describes a later runtime than this one does.
    if (seq != _refreshSeq || _disposed) return;
    if (entries == null) {
      // Could not ask. Leave whatever the catalog already holds rather than
      // publishing an empty one as fact — a pane whose panel is missing from
      // the catalog shows a placeholder, and there is no reason to show one
      // for every extension panel just because a call failed.
      debugPrint('[panels] could not read extension panels; keeping what the catalog had');
      notifyListeners();
      return;
    }
    final panels = <PanelDefinition>[];
    final seen = <String>{};
    for (final entry in entries) {
      final panel = PanelDefinition.fromExtensionEntry(entry);
      if (panel == null) {
        // An extension author whose panel simply never appears has no other
        // way to find out why.
        debugPrint('[panels] ignoring an entry from "${entry['hookKey']}": needs a key and a title');
        continue;
      }
      // Two panels claiming one id would give the dock two tabs addressing
      // one pane; first registration wins, as it does for hooks — but not
      // silently, since the loser has no call of its own to fail at.
      if (!seen.add(panel.id)) {
        debugPrint('[panels] "${panel.id}" is already claimed; ignoring the duplicate');
        continue;
      }
      panels.add(panel);
    }
    _extensionPanels = panels;
    notifyListeners();
  }

  /// Bumped when a panel's own config is edited, so the panel showing
  /// content rendered against the old values knows to ask again — its form
  /// is host-persisted, so nothing else would tell it.
  int configRevision(String id) => _configRevisions[id] ?? 0;

  void markConfigChanged(String id) {
    _configRevisions[id] = configRevision(id) + 1;
    notifyListeners();
  }

  /// One extension panel's content. Native panels never come through here —
  /// they are widgets, and the view builds them itself.
  Future<Map<String, dynamic>?> render(PanelDefinition panel, Map<String, dynamic> args) {
    assert(panel.source == PanelSource.extension);
    return extensions.renderPanel(hookKey: panel.hookKey!, panelKey: panel.panelKey!, args: args);
  }

  Future<Map<String, dynamic>> configFor(PanelDefinition panel) =>
      extensions.readPanelConfig(panelKey: panel.id, fields: panel.formFields);
}
