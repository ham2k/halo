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

  /// Whether an arrangement may hold more than one of this panel. Off by
  /// default: most panels are one thing, and two copies of a map or a spot
  /// list would be a mistake to offer. A panel whose content is the
  /// operator's own — a note, a scratchpad — is the case this exists for.
  ///
  /// Each placement gets its own [id] (see [instanceIdFor]), and because
  /// panel config is stored under the panel id, each instance's values are
  /// separately persisted without any storage code of their own.
  final bool multiple;

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
    this.multiple = false,
  });

  bool get hasSettings => formFields.isNotEmpty || settingsTarget != null;

  /// This descriptor as one placement of itself. Only the id moves — the
  /// routing keys, the form and the triggers stay the descriptor's.
  PanelDefinition asInstance(String instanceId) => PanelDefinition(
    id: instanceId,
    title: title,
    description: description,
    icon: icon,
    preview: preview,
    source: source,
    hookKey: hookKey,
    panelKey: panelKey,
    triggers: triggers,
    formFields: formFields,
    settingsTarget: settingsTarget,
    multiple: multiple,
  );

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
      other.multiple == multiple &&
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
    // `#` separates a descriptor from one of its placements, so a key
    // containing one would be read as an instance of a shorter descriptor
    // that may not exist. Dropped with a line rather than sanitized: an id
    // is persisted inside saved layouts, and quietly rewriting one would
    // strand every arrangement already holding it.
    if (hookKey.contains('#') || panelKey.contains('#')) {
      debugPrint('[panels] ignoring "$hookKey:$panelKey": a panel key may not contain "#"');
      return null;
    }
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
      multiple: entry['multiple'] == true,
    );
  }

  static String extensionPanelId({required String hookKey, required String panelKey}) => 'ext:$hookKey:$panelKey';

  /// The id of one PLACEMENT of a [multiple] panel — the descriptor's id
  /// with an instance suffix.
  ///
  /// `#` is deliberate, and [fromExtensionEntry] enforces that neither key
  /// contains one, so [descriptorIdOf] splits without ambiguity — and an id
  /// saved before instances existed parses as its own descriptor, which is
  /// what keeps every arrangement already on disk working.
  static String instanceIdFor(String descriptorId, int instance) => '$descriptorId#$instance';

  /// The descriptor an id belongs to — itself, for a panel placed once.
  static String descriptorIdOf(String id) {
    final cut = id.indexOf('#');
    return cut < 0 ? id : id.substring(0, cut);
  }
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

  Future<void> forgetPanelConfig({
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

  /// The panel an id names. An instance id (`…#2`) resolves to its
  /// descriptor, but what comes back carries the INSTANCE id — config is
  /// stored under it, so two Custom Text panes must not share a key.
  /// Everything that routes a call to the extension reads `hookKey` and
  /// `panelKey`, which an instance inherits unchanged.
  PanelDefinition? operator [](String id) {
    final exact = _native[id] ?? _extensionPanels.where((p) => p.id == id).firstOrNull;
    if (exact != null) return exact;
    final descriptorId = PanelDefinition.descriptorIdOf(id);
    if (descriptorId == id) return null;
    final descriptor = _extensionPanels.where((p) => p.id == descriptorId).firstOrNull;
    // A suffix on a descriptor that does not offer instances is a layout
    // naming something this catalog cannot explain, and the pane says so —
    // better than silently serving the descriptor and letting two placements
    // share one config.
    if (descriptor == null || !descriptor.multiple) return null;
    return descriptor.asInstance(id);
  }

  /// An instance id for [descriptorId] that nothing in [inLayout] is using.
  /// Numbered rather than random: these end up in a saved arrangement and in
  /// settings keys, where being readable is worth more than being
  /// unguessable.
  static String nextInstanceId(String descriptorId, Iterable<String> inLayout) {
    final taken = inLayout.where((id) => PanelDefinition.descriptorIdOf(id) == descriptorId).toSet();
    for (var i = 1;; i++) {
      final candidate = PanelDefinition.instanceIdFor(descriptorId, i);
      if (!taken.contains(candidate)) return candidate;
    }
  }

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

  /// Throws away what a removed pane held, for INSTANCES only.
  ///
  /// The distinction is the whole rule. An instance id is an anonymous slot
  /// — `#1` is not a thing the operator named, it is wherever the next
  /// placement happens to land, since [nextInstanceId] reuses the lowest
  /// free number. Left behind, one pane's notes reappear inside the next
  /// pane somebody adds, under its old tab name.
  ///
  /// A panel placed once is the opposite case and is deliberately NOT
  /// forgotten: the weather panel's location is that panel's configuration,
  /// not that pane's, and an operator who removes the pane and puts it back
  /// expects their setup intact.
  Future<void> forgetInstanceConfig(String id) async {
    final descriptorId = PanelDefinition.descriptorIdOf(id);
    if (descriptorId == id) return;
    // The DESCRIPTOR, not the instance: `this[id]` returns null while the
    // owning extension is disabled, or if the descriptor has stopped
    // offering instances — and a pane removed in either state would leave
    // its contents behind for the next placement to inherit, which is the
    // one outcome this must not have.
    final panel = this[descriptorId];
    if (panel == null || panel.formFields.isEmpty) return;
    await extensions.forgetPanelConfig(panelKey: id, fields: panel.formFields);
    _configRevisions.remove(id);
  }
}
