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
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:halo_widgets/halo_widgets.dart' show WallClock;

/// Where a panel comes from, which decides how the view gets its content.
enum PanelSource { native, extension }

/// The root views that host a dock, and so the values a native panel's
/// [PanelDefinition.views] is drawn from.
///
/// These reach settings storage indirectly — a view's [LayoutKeys] entries are
/// spelled with the same words — so they are as stable as a panel id.
abstract final class PanelViews {
  static const home = 'home';
  static const operation = 'operation';
  static const logs = 'logs';
}

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

  /// Which root views may offer this panel (see [PanelViews]).
  ///
  /// Empty means opposite things by [source], and deliberately so — each
  /// direction is the SAFE one for that kind of panel:
  ///
  /// - **Extension**: every view. An extension knows nothing about our views,
  ///   and a dashboard panel is as much at home beside the operation list as
  ///   beside the logging controls.
  /// - **Native**: no view at all. Ours are built out of one view's own state,
  ///   so a native panel that names no view is a registration someone forgot
  ///   to finish. Failing CLOSED makes the expensive mistake impossible: the
  ///   other view can never offer a pane it has no widget for, which would
  ///   land the operator a permanently broken pane whose tab reads like a real
  ///   panel. The cheap mistake is what is left — the panel is missing from
  ///   its own sheet, which whoever added it sees immediately.
  final Set<String> views;

  /// A minimum this panel's own content needs, beyond the dock's default
  /// floor (`dockMinPaneExtent` in halo_widgets) — a map, a table, anything
  /// that genuinely cannot use less. Null on either axis falls back to the
  /// default there.
  ///
  /// Native panels only for now: an extension panel's `panel` hook entry
  /// declares no minimum and always gets the default.
  final double? minWidth;
  final double? minHeight;

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
    this.views = const {},
    this.minWidth,
    this.minHeight,
  });

  /// Whether [view] may offer this panel — see [views] for why an empty set
  /// answers yes for an extension panel and no for a native one.
  bool availableIn(String view) =>
      views.isEmpty ? source == PanelSource.extension : views.contains(view);

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
    views: views,
    minWidth: minWidth,
    minHeight: minHeight,
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
      setEquals(other.views, views) &&
      listEquals(other.triggers, triggers) &&
      other.formFields.length == formFields.length &&
      other.minWidth == minWidth &&
      other.minHeight == minHeight;

  @override
  int get hashCode =>
      Object.hash(id, title, description, icon, preview, source, hookKey, panelKey, settingsTarget, minWidth, minHeight);

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

/// The minimum idle GAP between one render finishing and the next starting,
/// however often a panel's triggers fire. A trigger is a hint that something
/// changed, not a demand for a frame: 'qso' fires as fast as the operator
/// types, and every render crosses the JS bridge.
///
/// A gap rather than a period, because the runtime is single-threaded: a
/// panel whose render costs more than this would otherwise be allowed to
/// start the next one the instant it returned, holding the bridge and
/// starving every other hook.
const panelRenderThrottle = Duration(milliseconds: 750);

/// Whether the app is on screen enough for a panel to be worth rendering.
///
/// `inactive` counts as visible: on desktop it means the window merely lost
/// focus while still fully on screen, and a panel that stopped updating there
/// would read as broken. Only `hidden`, `paused` and `detached` — minimized, a
/// background browser tab, a suspended mobile app — mean nobody can see it.
///
/// Pure, because the wiring around it cannot be tested here: the test binding
/// restores `resumed` on the next pump, so a lifecycle state set in a widget
/// test does not survive to the moment a trigger arrives.
bool appIsVisibleIn(AppLifecycleState state) =>
    state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

/// How long a render must wait, given when the last one FINISHED.
///
/// Pure, and separate from the panel, because a widget test cannot see the
/// difference: the throttle runs on the real clock (a Timer does), while
/// `tester.pump` advances only the fake one — so measuring from the START of
/// a render looks identical there. The arithmetic is checkable here; which
/// stamp the call site passes is held by `_lastRenderEndedAt`'s comment.
Duration panelRenderDelay({required DateTime? lastEndedAt, required DateTime now}) {
  if (lastEndedAt == null) return Duration.zero;
  final since = now.difference(lastEndedAt);
  if (since.isNegative) return panelRenderThrottle;
  return since >= panelRenderThrottle ? Duration.zero : panelRenderThrottle - since;
}

/// What to do with a render request that arrived while the panel is busy —
/// mid-render, or inside the idle gap after one.
enum PanelRenderRequest { now, defer, coalesce, drop }

/// A tick is a SAMPLE; every other reason is an EVENT.
///
/// A tick is dropped whenever a render is already coming — one in flight, or
/// one already scheduled by the throttle. Another tick is aimed at the next
/// boundary, and the render that is coming reads fresh context anyway, so the
/// only thing keeping this one achieves is harm: it lands late, off the
/// boundary it existed to hit, and it RELABELS the pending render, telling
/// the panel it is rendering for a tick when a QSO was logged.
///
/// An event has nothing coming to bring it back. Mid-render it coalesces —
/// the render in flight owes one more when it finishes — and inside the idle
/// gap it waits out the remainder.
///
/// [coalesce] and [defer] are distinct because arming a timer for a render
/// that is still running is how the idle gap gets defeated: the gap is
/// measured from the LAST render's end, so mid-render it has usually already
/// elapsed and the timer would be armed for zero.
PanelRenderRequest panelRenderRequest({
  required String reason,
  required bool rendering,
  required bool scheduled,
  required Duration wait,
}) {
  final coming = rendering || scheduled;
  if (reason == 'tick') return coming ? PanelRenderRequest.drop : _waitOrNow(wait);
  if (rendering) return PanelRenderRequest.coalesce;
  return _waitOrNow(wait);
}

PanelRenderRequest _waitOrNow(Duration wait) =>
    wait > Duration.zero ? PanelRenderRequest.defer : PanelRenderRequest.now;

/// The period a panel ticks at, given everything it declared — the shortest
/// of them, floored at [minPanelTickSeconds]. Null when it asked for none.
///
/// Pure so that "the declared period is what runs" can be checked at all: the
/// rate itself is not observable in a widget test, because the boundary a
/// tick is aimed at comes from the real clock while the timer runs on the
/// test's fake one.
Duration? panelTickPeriod(Iterable<String> triggers) {
  final seconds = triggers
      .map((t) => t.startsWith('tick:') ? int.tryParse(t.substring(5)) : null)
      .nonNulls
      .fold<int?>(null, (best, s) => best == null ? s : (s < best ? s : best));
  if (seconds == null) return null;
  return Duration(seconds: seconds < minPanelTickSeconds ? minPanelTickSeconds : seconds);
}

/// The shortest REAL interval between two ticks of the same panel, whatever
/// the app clock is doing. [minPanelTickSeconds] is what an author may ask
/// for; this is what a travelled clock cannot get under.
const minPanelTickMillis = 1000;

/// The real milliseconds to wait for [periodMs]'s next boundary.
///
/// The floor widens the PERIOD rather than clamping the wait, and the
/// difference is the whole behaviour: the wait to the next boundary of a
/// one-second period is under a second by definition, so clamping the wait to
/// a second replaces every aligned wait with a flat one, and the panel ticks
/// a second after whenever it mounted for the rest of the session — losing
/// exactly the alignment the boundary aim exists for. Widening keeps the aim
/// and moves the boundary instead.
///
/// So the floor bounds the interval between CONSECUTIVE ticks, which is the
/// rate that costs anything. The single partial wait from arming to the first
/// boundary is whatever the phase makes it, and can be shorter.
int panelTickDelayMillis({required int periodMs, required int nowMillis, required double speed}) {
  // Both arguments to `delayToBoundary` are on the APP clock and its answer is
  // in real time, so the floor has to be converted before it can be compared.
  final virtualFloor = (minPanelTickMillis * speed).ceil();
  final effective = periodMs > virtualFloor ? periodMs : virtualFloor;
  return WallClock.delayToBoundary(periodMs: effective, nowMillis: nowMillis, speed: speed);
}

/// The shortest `tick:<seconds>` a panel may ask for.
///
/// A warm render round-trip measures ~0.3 ms including the config read, so a
/// per-second panel costs about 0.03% of a core and four of them land inside
/// a frame's budget once a second.
///
/// It is still a floor. Below a second the wait stops being meaningfully
/// longer than the work, and a panel wanting smooth motion wants a native
/// pane — which owns its own ticker and never comes through here.
const minPanelTickSeconds = 1;

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
    // `#` separates a descriptor from a placement of it, so a native id
    // carrying one would resolve as an instance of a descriptor nothing
    // registered. These ids are ours, so this is a coding error rather than
    // the data problem `fromExtensionEntry` handles.
    assert(!panel.id.contains('#'), 'a native panel id may not contain "#"');
    if (_native[panel.id] == panel) return;
    _native[panel.id] = panel;
    notifyListeners();
  }

  /// Every panel, native first in registration order and extension panels
  /// after — a view's own panes are the ones an operator is looking for.
  ///
  /// Every view's, though: this is the catalog an id is resolved against, and
  /// a saved arrangement may name a panel the current view does not offer.
  /// What a view puts in front of the operator is [catalogFor].
  List<PanelDefinition> get catalog => [..._native.values, ..._extensionPanels];

  /// The panels [view] may offer — what its Add a Panel sheet lists. Native
  /// panels belonging to another view are filtered out; extension panels name
  /// no view and so survive for every one.
  List<PanelDefinition> catalogFor(String view) =>
      catalog.where((panel) => panel.availableIn(view)).toList();

  /// The panel an id names. An instance id (`…#2`) resolves to its
  /// descriptor, but what comes back carries the INSTANCE id — config is
  /// stored under it, so two Custom Text panes must not share a key.
  /// Everything that routes a call to the extension reads `hookKey` and
  /// `panelKey`, which an instance inherits unchanged.
  ///
  /// Instances are not an extension-only idea: the clock is a native panel an
  /// operator places several of, one per zone.
  PanelDefinition? operator [](String id) {
    final exact = _native[id] ?? _extensionPanels.where((p) => p.id == id).firstOrNull;
    if (exact != null) return exact;
    final descriptorId = PanelDefinition.descriptorIdOf(id);
    if (descriptorId == id) return null;
    final descriptor = _native[descriptorId] ?? _extensionPanels.where((p) => p.id == descriptorId).firstOrNull;
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

  final _refreshRequests = <String, int>{};

  /// Bumped when something asks ONE placement to reload what it is showing —
  /// the Web Site pane's "Refresh Now" button, which lives in that pane's
  /// settings sheet.
  ///
  /// A counter rather than a callback because the asker is a dialog and the
  /// answerer is a pane: the dialog has no handle on the pane's web view
  /// controller, and giving it one would mean the pane registering itself
  /// somewhere for the dialog to find. This is the same shape
  /// [configRevision] already uses for the same reason.
  ///
  /// Distinct from [configRevision] on purpose: reloading a page is not a
  /// config change, and folding it into that counter would make every reload
  /// re-read storage and rebuild the pane rather than reload the page.
  int refreshRequest(String id) => _refreshRequests[id] ?? 0;

  void requestRefresh(String id) {
    _refreshRequests[id] = refreshRequest(id) + 1;
    notifyListeners();
  }

  /// What each PLACEMENT asked for in its last render, on top of what its
  /// descriptor declared (`PanelContent.triggers`).
  final _declaredTriggers = <String, List<String>>{};

  /// Records one placement's runtime triggers, and reports whether they
  /// changed — the caller restarts its ticker on true, and listeners re-read
  /// [triggersFor] so the view can start producing a signal nobody wanted
  /// until now (a template that names the QSO being typed).
  ///
  /// Unknown names are dropped here, the same way and for the same reason as
  /// a descriptor's: a trigger the host never fires would leave a panel
  /// rendered once and silent forever, looking exactly like one that meant
  /// to be.
  bool declareTriggers(String id, List<String> triggers) {
    final accepted = {...triggers.where(isKnownPanelTrigger)};
    // Compared as a SET, and the rejects are reported only when the answer
    // changes. This runs on EVERY render — a `tick:5` panel reaches it once
    // per five seconds, a `qso` one once per keystroke pause — so a line
    // printed per call would drown the console that is the operator's only
    // window on error-policy'd failures, and a set that merely arrived in a
    // different order would restart tickers and rebuild the view for nothing.
    final previous = _declaredTriggers[id] ?? const <String>[];
    if (setEquals(previous.toSet(), accepted)) return false;
    for (final rejected in triggers.toSet().difference(accepted)) {
      debugPrint('[panels] "$id" rendered an unrecognized trigger ($rejected); it will never fire');
    }
    if (accepted.isEmpty) {
      _declaredTriggers.remove(id);
    } else {
      _declaredTriggers[id] = accepted.toList();
    }
    notifyListeners();
    return true;
  }

  /// What the placement [id]'s own last render asked for.
  List<String> declaredTriggers(String id) => _declaredTriggers[id] ?? const [];

  /// Everything that re-renders the placement [id]: its descriptor's
  /// triggers plus the ones its own last render asked for.
  ///
  /// For callers that hold only an id. A widget that holds the
  /// [PanelDefinition] itself must union with THAT rather than with the
  /// catalog's copy: a pane whose extension is being restarted keeps
  /// rendering from the definition it was built with, while `this[id]`
  /// answers null for as long as the runtime is down.
  ///
  /// A panel the catalog cannot explain wants NOTHING, whatever it once
  /// declared. Its pane is showing a placeholder rather than rendering, so
  /// every signal produced for it is produced for nobody — and the
  /// expensive one is real: a disabled extension whose pane had asked for
  /// `qso` would otherwise keep the whole operation view rebuilding the QSO
  /// draft on every keystroke for the rest of the session. The declaration
  /// is kept rather than deleted, so re-enabling the extension restores it
  /// without waiting for a render.
  Set<String> triggersFor(String id) {
    final panel = this[id];
    if (panel == null) return const {};
    return {...panel.triggers, ..._declaredTriggers[id] ?? const []};
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
    // Ahead of every guard below, because none of their reasoning applies to
    // this: trigger declarations are runtime state, not the operator's
    // configuration. An instance id is a slot `nextInstanceId` hands to the
    // next placement, and a pane added behind a dock tab does not render
    // until it is looked at — so a static-text pane could otherwise inherit
    // the previous occupant's `qso` declaration and hold the whole view on
    // the per-keystroke draft path for the session.
    _declaredTriggers.remove(id);
    // Same reasoning: a stale count left against a reused id makes the next
    // pane in that slot reload once on arrival, for a button nobody pressed.
    _refreshRequests.remove(id);

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
