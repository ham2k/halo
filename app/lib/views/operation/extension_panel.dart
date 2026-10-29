// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One extension-contributed panel in a customizable view: asks the panel's
// hook for a document, draws it with PanelContentView, and re-asks when
// something the panel declared an interest in changes.
//
// The trigger list is a budget, not a subscription. Every render crosses the
// JS bridge, so a panel is re-rendered only for what it asked for, never
// more often than `panelRenderThrottle`, and — after its first render —
// never at all while nobody can see it. Unwatched is two independent things:
// behind another dock tab, since an unselected tab stays MOUNTED
// (IndexedStack) and the dock publishes that through DockPaneVisibility; and
// the whole app hidden, which the dock knows nothing about. Without either
// rule a four-panel layout in a minimized window keeps paying for four
// panels nobody is looking at.
//
// The budget has two halves: what the panel's DESCRIPTOR declared, paid by
// every placement of that panel, and what THIS placement's last render asked
// for (`PanelContent.triggers`). The second exists for panels whose content
// the operator writes — one custom-text pane naming the callsign being typed
// must not put the others on the typing path with it.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/error_reporting_service.dart';
import '../../services/panel_content_budgets.dart';
import '../../services/panel_service.dart';
import 'panel_content_view.dart';
import 'panel_environment.dart';
import 'panel_scene/scene_model.dart';
import 'panel_scene/scene_spectrum.dart';

/// An operation as a hook sees it — what a panel's `render` and the
/// `template` hook (a CW message about to be keyed) are handed, so
/// `{{ op.station }}` means the same on both.
Map<String, dynamic> operationHookArgs(Operation operation) => {
  ...operation.data,
  'uuid': operation.uuid,
  // RESOLVED, as `operationQsonFor` sends it: with a position set the
  // operator lives in that position's slot, and only this side knows which
  // seat this device is in. It replaces whatever `operatorCall` the data holds.
  'operatorCall': operatorCallFor(operation),
  // Row COLUMNS, not QSON — `qsonPayloadFor`'s shape carries neither,
  // and a panel is the surface that most wants to say when the
  // operation ran. Without them a template naming the operation's
  // date has nothing to name (see the SDK's `opValues`).
  if (operation.startAtMillisMin != null) 'startAtMillisMin': operation.startAtMillisMin,
  if (operation.startAtMillisMax != null) 'startAtMillisMax': operation.startAtMillisMax,
};

/// What a panel renders against, gathered by the view. Compared field by
/// field to decide whether a rebuild is worth a render — the view rebuilds
/// for reasons no panel cares about.
@immutable
class PanelRenderContext {
  /// Null on a view that has no operation open — Home. A panel whose template
  /// names the operation renders that part empty there rather than the view
  /// refusing to place it: the dashboard panels (clock, weather, solar) are
  /// exactly the ones an operator wants on Home, and none of them ask.
  final Operation? operation;
  final Map<String, dynamic>? qso;
  final int qsoCount;

  /// The log as the view holds it: the list its log stream last emitted.
  /// Without it a panel hears only changes to [qsoCount], so an edited time
  /// or operator never reaches one that keeps what it read. See [_logChanged]
  /// for what counts as a change.
  final List<Qso>? log;

  /// Bumped by the view when spots refresh or a lookup resolves — signals
  /// that carry no value of their own into the render args.
  final int spotsRevision;
  final int lookupRevision;

  const PanelRenderContext({this.operation, this.qso, this.qsoCount = 0, this.log, this.spotsRevision = 0, this.lookupRevision = 0});

  /// The triggers that fired between [previous] and this — empty means
  /// nothing this panel could have asked for actually changed.
  Set<String> changesFrom(PanelRenderContext previous) => {
    if (operation?.uuid != previous.operation?.uuid || operation?.data != previous.operation?.data) 'operation',
    if (qso != previous.qso) 'qso',
    if (qsoCount != previous.qsoCount || _logChanged(log, previous.log)) 'qsoLogged',
    if (spotsRevision != previous.spotsRevision) 'spots',
    if (lookupRevision != previous.lookupRevision) 'lookup',
  };

  /// Whether the log moved between [previous] and [log]. The stream emits a
  /// new list for every write to the operation's rows — a contact logged,
  /// edited, deleted or merged in, but also each rescore caching its
  /// verdicts, which changes nothing a panel reads and would re-render every
  /// `qsoLogged` panel once more per contact. The digest moves only when a
  /// contact's stamp moves or a contact comes or goes, so it tells the two
  /// apart; where it cannot vouch for a row (one with no stamp), any new list
  /// counts.
  static bool _logChanged(List<Qso>? log, List<Qso>? previous) {
    if (identical(log, previous)) return false;
    if (log is QsoLog && previous is QsoLog && log.unstamped == 0 && previous.unstamped == 0) {
      return log.length != previous.length || log.digest != previous.digest;
    }
    return true;
  }
}

class ExtensionPanel extends StatefulWidget {
  final PanelDefinition panel;
  final PanelService panels;
  final PanelRenderContext renderContext;

  /// A title this render supplied, or null to fall back to the descriptor's.
  /// The tab lives in the dock, above this widget, so the label has to be
  /// handed upward — and it can only be known once the panel has answered.
  final ValueChanged<String?>? onTitle;

  /// For a scene's `spectrum` controls; null when this panel may not read
  /// the radio.
  final SceneSpectrumSource? spectrum;

  const ExtensionPanel({super.key, required this.panel, required this.panels, required this.renderContext, this.onTitle, this.spectrum});

  @override
  State<ExtensionPanel> createState() => _ExtensionPanelState();
}

class _ExtensionPanelState extends State<ExtensionPanel> with WidgetsBindingObserver {
  PanelContent? _content;
  int _sceneGeneration = 0;
  int _sceneRevision = 0;
  String? _error;

  /// The refusal the console last named, so a ticking panel's repeat prints
  /// nothing and a new reason behind the same placeholder does.
  String? _lastRefusal;

  /// False while this panel sits behind another tab. It stays mounted (so
  /// its scroll position and content survive), but it stops rendering —
  /// published by the dock, since nothing else knows which pane of a group
  /// is on top.
  bool _visible = true;

  /// False only while every view is hidden — minimized, a background browser
  /// tab, a paused mobile app. Deliberately not `inactive`: on desktop that
  /// means the window merely lost focus while still on screen, and a panel
  /// that stopped updating there would look broken.
  ///
  /// ANDed with [_visible] as [_awake]. The dock's answer alone is not
  /// enough at a fast tick: a front-tab panel in a minimized window is
  /// `DockPaneVisibility.of(context) == true` and still crossing the bridge
  /// once a second for nobody.
  bool _appVisible = true;

  /// Whether anyone can actually see this pane right now.
  // Read the inherited flag at timer dispatch too: an offstage subtree can
  // remain dirty until its next frame, leaving didChangeDependencies pending.
  bool get _awake => _appVisible && DockPaneVisibility.readOf(context);

  /// Set while a render is in flight, so a burst of triggers coalesces into
  /// one follow-up call instead of stacking calls the bridge will run in
  /// order anyway.
  bool _rendering = false;
  bool _pending = false;

  /// When the last render FINISHED. The throttle is a minimum idle GAP, not a
  /// minimum period: the runtime is single-threaded, so a panel whose render
  /// costs more than the window would otherwise re-request the moment it
  /// returns and hold the bridge at a 100% duty cycle, starving every other
  /// hook. Measured from the end, a slow panel simply runs less often.
  DateTime? _lastRenderEndedAt;
  Timer? _throttle;
  Timer? _tick;

  /// Whether a trigger fired while this panel was behind another tab, so
  /// coming back to the top knows whether there is anything to ask about. A
  /// panel that declares no triggers renders once and stays put, which is
  /// what its descriptor asked for.
  bool _missedWhileHidden = false;

  /// False until the first render has been asked for. Visibility is only
  /// readable from `didChangeDependencies`, so that — not `initState` — is
  /// where a panel first reaches the bridge: every pane of a group is
  /// mounted at once, and rendering them all at mount is exactly the cost
  /// the visibility gate exists to avoid.
  bool _rendered = false;
  Map<String, dynamic>? _environment;
  String? _environmentKey;
  Size _paneSize = Size.zero;
  final _environmentReady = Completer<void>();
  bool _environmentScheduled = false;

  void _captureEnvironment(Map<String, dynamic> next) {
    final key = jsonEncode(next);
    if (key == _environmentKey) return;
    final initial = _environment == null;
    _environment = next;
    _environmentKey = key;
    if (initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_environmentReady.isCompleted) _environmentReady.complete();
      });
    } else if (!_environmentScheduled) {
      // Layout can run repeatedly during a dock resize. Only the newest
      // environment crosses the bridge, within the normal render budget.
      //
      // And only for a scene, the one kind drawn AGAINST the environment.
      // Markdown and HTML are themed and laid out by the host, so a splitter
      // drag would otherwise re-render — and for HTML, reload — every pane
      // for an answer that cannot differ. They still get the newest
      // environment on their next render.
      _environmentScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _environmentScheduled = false;
        if (mounted && _rendered && _content?.kind == 'scene') _requestRender('environment');
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = DockPaneVisibility.of(context);
    final becameVisible = visible && !_visible;
    _visible = visible;
    if (!_rendered) {
      // Set only when a render actually happens: a pane that starts behind a
      // tab has not had its first render yet, and marking it done here would
      // leave it blank forever — it isn't "coming back" when it is first
      // looked at, so nothing else would ask.
      //
      // The DOCK's answer alone, not `_awake`: a pane on the front tab of a
      // minimized window has no content at all, and one render now is what
      // makes it non-blank when the operator returns. Only repeat renders are
      // worth withholding from a hidden app.
      if (!_visible) return;
      _rendered = true;
      // Cleared with the render, not left standing: a tick fires while a pane
      // waits behind a tab, and at a one-second floor it will have. Carrying
      // the flag out of the FIRST reveal buys a spurious catch-up render on
      // the next one, which is the cost the flag exists to avoid.
      _missedWhileHidden = false;
      // Straight to the bridge, not through the throttle: the operator is
      // looking at an empty pane until this answers.
      _render('initial');
      return;
    }
    // Coming back to the top: ask again only if something it cares about
    // happened while nobody was looking — and only if anyone can see it. A
    // pane revealed while the whole app is hidden is still hidden, and the
    // flag keeps until it isn't.
    if (becameVisible && _missedWhileHidden && _appVisible) {
      _missedWhileHidden = false;
      _requestRender('visible');
    }
  }

  @override
  void initState() {
    super.initState();
    // Null before the first platform message, which is not evidence of being
    // hidden.
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible = state == null || appIsVisibleIn(state);
    WidgetsBinding.instance.addObserver(this);
    // Travel moves the boundary a pending tick was aimed at, and changes how
    // long the wait to the next one should be. Without this the panel sits
    // out its stale delay while every WallClock subscriber has already
    // re-aimed — the panel and the widgets it is supposed to share a frame
    // with drift apart, which is the whole reason it borrows their helper.
    AppClock.instance.addListener(_onClockTravel);
    widget.panels.addListener(_onCatalogChanged);
    widget.panels.extensions.runtimeGeneration.addListener(_onSceneRuntimeChanged);
    _startTicker();
    _watchRadio();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = appIsVisibleIn(state);
    if (visible == _appVisible) return;
    _appVisible = visible;
    // Coming back is the interesting half: a tick that fired while the app was
    // away is remembered the same way one behind a tab is, so the pane catches
    // up on return rather than waiting out another period.
    if (_appVisible && _missedWhileHidden && _visible) {
      _missedWhileHidden = false;
      _requestRender('visible');
    }
  }

  /// Everything this pane re-renders for: the triggers of the definition it
  /// was built with, plus the ones its own last render declared.
  ///
  /// The definition, NOT `panels[id]` — a pane outlives a runtime restart
  /// and keeps rendering while the catalog has no answer for its id, and
  /// asking the catalog would silently drop its descriptor's triggers for
  /// the length of that gap.
  Set<String> get _triggers => {...widget.panel.triggers, ...widget.panels.declaredTriggers(widget.panel.id)};

  /// The panel's own config was edited (its form is host-persisted, so
  /// nothing else would tell this panel its inputs changed).
  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panel.id);
    if (revision == _configRevision) return;
    _configRevision = revision;
    if (!_awake) {
      _missedWhileHidden = true;
      return;
    }
    _requestRender('config');
  }

  void _onSceneRuntimeChanged() {
    if (!mounted || _content?.kind != 'scene') return;
    setState(() {
      _sceneGeneration++;
    });
    _requestRender('runtime');
  }

  int _configRevision = 0;

  @override
  void didUpdateWidget(ExtensionPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      old.panels.extensions.runtimeGeneration.removeListener(_onSceneRuntimeChanged);
      widget.panels.extensions.runtimeGeneration.addListener(_onSceneRuntimeChanged);
      _sceneGeneration++;
      widget.panels.addListener(_onCatalogChanged);
    }
    // An extension update replaces the definition under the same id, and may change what it declares.
    final declared = old.panel.id == widget.panel.id && !listEquals(old.panel.triggers, widget.panel.triggers);
    if (declared) _startTicker();
    if (old.spectrum != widget.spectrum || declared) _watchRadio();
    if (old.panel.id != widget.panel.id) {
      _content = null;
      _error = null;
      _lastRefusal = null;
      _missedWhileHidden = false;
      _startTicker();
      _watchRadio();
      if (_visible) {
        _render('initial');
      } else {
        _rendered = false;
      }
      return;
    }
    final fired = widget.renderContext.changesFrom(old.renderContext).intersection(_triggers);
    if (fired.isEmpty) return;
    // Read fresh, not from `_visible`: this method runs before
    // didChangeDependencies, so a pane hidden in the same pump that fired
    // the trigger still has last frame's answer cached.
    if (!DockPaneVisibility.readOf(context) || !_appVisible) {
      // Behind a tab: remembered, not rendered. The pane is still mounted,
      // so it would otherwise pay for every trigger nobody is watching.
      _missedWhileHidden = true;
      return;
    }
    _requestRender(fired.first);
  }

  /// What this pane follows for a `radio` trigger, and the dial it last saw.
  /// Null while it declares none or may not read the radio.
  Listenable? _radioWatched;
  List<Object?>? _dialSeen;
  bool _saidUnread = false;

  /// Only while the pane declares `radio`: the source fires at meter rate,
  /// and a pane that did not ask must not pay for the comparison.
  void _watchRadio() {
    final asked = _triggers.contains('radio');
    // The dock hands no source to a panel that may not read the radio.
    if (asked && widget.spectrum == null && !_saidUnread) {
      _saidUnread = true;
      debugPrint('[panels] "${widget.panel.id}" asked for the radio trigger without requiresRadioRead; it will never fire');
    }
    final source = asked ? widget.spectrum : null;
    final next = source?.readingChanges;
    if (!identical(next, _radioWatched)) {
      _radioWatched?.removeListener(_onRadio);
      _radioWatched = next?..addListener(_onRadio);
    }
    _dialSeen = source?.dialState();
  }

  void _onRadio() {
    final dial = widget.spectrum?.dialState();
    if (!mounted || dial == null || listEquals(dial, _dialSeen)) return;
    _dialSeen = dial;
    // Behind a tab, [_render] remembers it for the reveal.
    _requestRender('radio');
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = null;
    _tickPeriod = panelTickPeriod(_triggers);
    _armTick();
  }

  Duration? _tickPeriod;

  /// Travel moves the boundary the pending tick was aimed at, so the wait it
  /// was armed with is no longer the wait to the next one. Re-aiming is what
  /// keeps this pane in the same frame as the `WallClock` widgets it is
  /// borrowing the boundary from.
  void _onClockTravel() {
    if (!mounted) return;
    _tick?.cancel();
    _tick = null;
    _armTick();
    // Travel changes the ANSWER, not just the schedule. `WallClock` notifies
    // its subscribers in the same frame, so a panel that only re-aimed its
    // timer would paint pre-travel time beside a clock chip that had already
    // jumped — until its next tick, which for the shipped solar dashboard's
    // `tick:600` is ten minutes. Not labelled a tick: a sample is droppable
    // and this is not.
    if (_awake) _requestRender('clock');
  }

  /// A chain of one-shot timers re-aimed at each wall-clock boundary, rather
  /// than one `Timer.periodic`.
  ///
  /// A periodic timer keeps only its own cadence, phased to whenever the pane
  /// mounted — so a `tick:1` panel showing a time flips its second at an
  /// arbitrary fraction of the real one and stays there. Aiming at the
  /// boundary also makes panels sharing a period fire in the SAME frame
  /// instead of several out of phase, which is the same trade `WallClock`
  /// makes for the app's per-second widgets.
  void _armTick() {
    final period = _tickPeriod;
    if (period == null || _tick != null) return;
    _tick = Timer(
      Duration(
        milliseconds: panelTickDelayMillis(periodMs: period.inMilliseconds, nowMillis: nowMillis(), speed: AppClock.instance.speed),
      ),
      () {
        _tick = null;
        // Re-armed in a `finally`: "a period is set" has to imply "a timer
        // exists", and nothing in this widget would notice if the chain broke.
        // `_startTicker` runs only on mount, a panel-id change and a CHANGE of
        // declared triggers, so a panel with settled triggers would simply
        // stop ticking for the rest of the session.
        try {
          if (!mounted) return;
          if (_awake) {
            _requestRender('tick');
          } else {
            // Still ticking while nobody is looking, deliberately: this flag is
            // how a reveal knows there is something to catch up on. Stopping
            // the chain here would need a matching re-arm on every path back to
            // visible, and missing one freezes the pane for good.
            _missedWhileHidden = true;
          }
        } finally {
          if (mounted) _armTick();
        }
      },
    );
  }

  /// Renders no sooner than [panelRenderThrottle] after the last one.
  void _requestRender(String reason) {
    // Real time on both ends of this throttle: the remainder becomes a Timer
    // duration, and a Timer fires on real time — pairing it with a rescaled
    // clock would make the throttle wait the wrong length.
    final wait = panelRenderDelay(lastEndedAt: _lastRenderEndedAt, now: realNowUtc());
    switch (panelRenderRequest(reason: reason, rendering: _rendering, scheduled: _throttle != null, wait: wait)) {
      case PanelRenderRequest.drop:
        return;
      case PanelRenderRequest.coalesce:
        // Owed, not timed: the render in flight re-requests when it finishes,
        // by which point the gap can be measured against an end that exists.
        _pending = true;
      case PanelRenderRequest.defer:
        _throttle?.cancel();
        _throttle = Timer(wait, () {
          _throttle = null;
          if (mounted) _render(reason);
        });
      case PanelRenderRequest.now:
        // A timer can still be armed here: it is due but has not run yet, and
        // the gap it was waiting out has already elapsed. Letting it stand
        // spends a second render on the moment this one covers.
        _throttle?.cancel();
        _throttle = null;
        _render(reason);
    }
  }

  /// The panel's stored config, or null when it cannot be read.
  ///
  /// Its own report, under `panel:config`: a config read reaching the keychain
  /// can fail for reasons that have nothing to do with this extension, and
  /// blaming its panel would point the investigation at the wrong component.
  Future<Map<String, dynamic>?> _readConfig(PanelDefinition panel) async {
    try {
      // Bounded, unlike the hook leg which `invokeHook` already times out.
      // A config with a secret field reaches the platform keychain, and a
      // keychain call has no timeout of its own — if it never returns,
      // `_rendering` never clears, and from then on every tick is DROPPED
      // and every event coalesced into a render that will never run. The
      // pane would sit on its last document, with no error and so no Retry,
      // and nothing anywhere would say why.
      final config = await widget.panels.configFor(panel).timeout(const Duration(seconds: 5));
      ErrorReportingService.recordSuccess('panel:config:${panel.id}');
      return config;
    } catch (e, stack) {
      // The console line is this catch's own: a failure the policy keeps
      // quiet never reaches the streak's report, and nothing else prints
      // for this leg.
      debugPrint('[panels] config for ${panel.id} failed: $e');
      ErrorReportingService.reportIfRepeated('panel:config:${panel.id}', e, stack, context: 'panel:config:${panel.id}', threshold: 1);
      return null;
    }
  }

  Future<void> _render(String reason) async {
    // A throttled refresh can become due after the panel was hidden.
    if (reason != 'initial' && !_awake) {
      _missedWhileHidden = true;
      return;
    }
    if (_rendering) {
      // Whatever the newest reason is, the next render reads the newest
      // context anyway — only that one call is owed.
      _pending = true;
      return;
    }
    _rendering = true;
    // Captured, so a render still in flight when the widget is handed a
    // different panel can't paint one panel's content under another's tab —
    // a plausible wrong answer is worse than an error.
    final panel = widget.panel;
    final generation = _sceneGeneration;
    final sceneRevision = _sceneRevision;
    try {
      await _environmentReady.future;
      if (!mounted) return;
      final ctx = widget.renderContext;
      if (_content != null && _content!.kind != 'scene') {
        // Not watched from `build`, so resolved here. The key is dropped with
        // it: a pane that turns into a scene must see its first capture as a
        // change rather than match a key from before it stopped watching.
        _environment = panelEnvironment(context, _paneSize);
        _environmentKey = null;
      }
      // An unreadable config renders as an empty one ([_readConfig]).
      final config = await _readConfig(panel) ?? const <String, dynamic>{};
      final operation = ctx.operation;
      final renderedEnvironment = _environmentKey;
      final result = await widget.panels.render(panel, {
        // Absent, not empty, on a view with no operation open: an empty map
        // would answer a template's `op.call` with the empty string, which
        // reads as "this operation has no callsign" rather than "there is no
        // operation". The SDK's `opValues` treats a missing key as the latter.
        if (operation != null) 'operation': operationHookArgs(operation),
        if (ctx.qso != null) 'qso': ctx.qso,
        'qsoCount': ctx.qsoCount,
        'config': config,
        'reason': reason,
        'environment': _environment,
        'clock': {'nowMillis': nowMillis(), 'realNowMillis': realNowMillis()},
      });
      if (!mounted || panel.id != widget.panel.id || generation != _sceneGeneration || sceneRevision != _sceneRevision) {
        return;
      }
      final content = PanelContent.fromJson(result, previous: _content);
      // A scene laid out for an environment that has since changed is not
      // shown. Owed here rather than left to [_captureEnvironment], which
      // cannot know a FIRST render is going to answer with a scene.
      if (content?.kind == 'scene' && renderedEnvironment != _environmentKey) {
        _pending = true;
        return;
      }
      // Before the content is shown, so the ticker a template just asked for
      // is running by the time anyone could look at what it rendered. A
      // render that fails leaves the previous declaration standing: a panel
      // that throws has said nothing about what it needs, and dropping its
      // triggers would strand it on the error it just produced.
      if (content != null && widget.panels.declareTriggers(panel.id, content.triggers)) {
        _startTicker();
        _watchRadio();
      }
      // A render that answered ends a refusal: the next one is news again.
      _lastRefusal = null;
      final error = content == null ? context.t.operation.layout.panelRenderFailed(panel: panel.title) : null;
      // Only when something actually changed. A panel on a tick re-renders the
      // same document most of the time — a band plan, a reference table — and
      // `setState` on an identical answer rebuilds the pane's subtree for
      // nothing, once per tick, for as long as it is on screen.
      if (content != _content || error != _error) {
        setState(() {
          _content = content;
          _error = error;
        });
      }
      // After the setState, not inside it: this reaches the VIEW's state, and
      // a panel is free to return the same title on every render, so the
      // listener has to be the one that drops a repeat.
      widget.onTitle?.call(content?.title);
      // LAST, and only for a render that produced a document. Everything above
      // can throw into the catch below, and clearing the streak before that
      // point would let a panel failing after the bridge call reset its own
      // evidence on every attempt — the streak would never leave 1 and the
      // failure would never be reported at all. A null document is a failed
      // render too, so it must not clear the streak either.
      if (content != null) ErrorReportingService.recordSuccess('panel:render:${panel.id}');
    } on PanelContentRefusal catch (e) {
      // A budget is the extension's to keep, like a refused host call, not a
      // failure of the app's: nothing is reported. The pane names the budget
      // and the console says what was sent — once per change, since a ticking
      // panel sends the same document again and again. The last document
      // stays underneath; the view shows the message over whatever it holds.
      if (!mounted || panel.id != widget.panel.id || generation != _sceneGeneration || sceneRevision != _sceneRevision) {
        return;
      }
      final message = _refusalMessage(e, panel);
      // The console keys on the reason and the pane on its wording: four
      // reasons share the `not self-contained` placeholder.
      if (e.message != _lastRefusal) {
        debugPrint('[panels] "${panel.id}" refused: ${e.message}');
        _lastRefusal = e.message;
      }
      if (message != _error) setState(() => _error = message);
    } catch (e, stack) {
      // Through ErrorPolicy like everything else (docs/design/error-reporting.md):
      // a panel that throws for every operator is exactly the thing that has
      // to be visible in aggregate, and a handler deciding on its own to keep
      // it local is the pattern that policy exists to prevent. What the
      // OPERATOR sees is a sentence naming the panel — an exception's
      // toString is not a user-facing string.
      //
      // The FIRST failure of a streak, then silence until one succeeds. A
      // ticking panel fails on a TIMER — one broken at `tick:1` would upload
      // once a second for as long as its pane is open, burying the crashes
      // policy exists to surface — but a threshold above one would lose the
      // panel that renders ONCE, which is the default and the case least
      // likely to reach us any other way.
      ErrorReportingService.reportIfRepeated('panel:render:${panel.id}', e, stack, context: 'panel:render:${panel.id}', threshold: 1);
      if (!mounted || panel.id != widget.panel.id || generation != _sceneGeneration || sceneRevision != _sceneRevision) {
        return;
      }
      setState(() => _error = context.t.operation.layout.panelRenderFailed(panel: panel.title));
    } finally {
      _rendering = false;
      // Stamped HERE, not at the start: see [_lastRenderEndedAt]. Set even
      // when the render threw — a panel failing in a tight loop is the case
      // that most needs the gap.
      _lastRenderEndedAt = realNowUtc();
      if (_pending && mounted) {
        _pending = false;
        _requestRender('coalesced');
      }
    }
  }

  /// What the operator reads in place of a document over its budget.
  String _refusalMessage(PanelContentRefusal refusal, PanelDefinition panel) {
    final layout = context.t.operation.layout;
    final max = refusal.max == null ? '' : formatNumber(refusal.max!);
    return switch (refusal.budget) {
      PanelBudget.characters => layout.panelOverCharacters(panel: panel.title, max: max),
      PanelBudget.elements => layout.panelOverElements(panel: panel.title, max: max),
      PanelBudget.depth => layout.panelOverDepth(panel: panel.title, max: max),
      PanelBudget.artwork => layout.panelNotArtwork(panel: panel.title),
    };
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
    widget.panels.extensions.runtimeGeneration.removeListener(_onSceneRuntimeChanged);
    AppClock.instance.removeListener(_onClockTravel);
    WidgetsBinding.instance.removeObserver(this);
    _throttle?.cancel();
    _tick?.cancel();
    _radioWatched?.removeListener(_onRadio);
    if (!_environmentReady.isCompleted) _environmentReady.complete();
    super.dispose();
  }

  /// Asks again after a failure, by hand.
  ///
  /// The only way back for a pane that declares no triggers: nothing else
  /// would ever ask it, `didUpdateWidget` has an empty set to intersect
  /// against, and the come-back-to-the-tab path is gated on a trigger having
  /// fired. Until this existed, a panel whose FIRST render failed — a
  /// runtime still starting, a bridge timeout — stayed broken for the rest
  /// of the session, and editing its config was the only cure.
  ///
  /// Clears the error, which is all it clears: a pane that rendered once and
  /// failed later goes back to showing that document while the retry is in
  /// flight, rather than throwing away the last thing it had to say. Only a
  /// pane whose first render failed has nothing to fall back to, and that
  /// one shows the spinner.
  void _retry() {
    setState(() => _error = null);
    _requestRender('retry');
  }

  Future<Map<String, Object>> _sceneEvent(Map<String, dynamic> event) async {
    _sceneRevision++;
    final panel = widget.panel;
    final generation = _sceneGeneration;
    final ctx = widget.renderContext;
    bool current() => mounted && generation == _sceneGeneration && panel.id == widget.panel.id;
    // Refused, NOT run against an empty config the way a render is: a config
    // is where a panel keeps which radio it commands, and an action aimed by
    // defaults is a plausible wrong answer. The failure is the config read's
    // and is already reported as one, so it is kept out of the panel's streak.
    var configUnreadable = false;
    try {
      final config = await _readConfig(panel);
      if (config == null) {
        configUnreadable = true;
        throw StateError('Panel config unavailable');
      }
      if (!current()) throw StateError('Panel replaced');
      final result = await widget.panels.event(panel, {
        if (ctx.operation != null) 'operation': operationHookArgs(ctx.operation!),
        if (ctx.qso != null) 'qso': ctx.qso,
        'qsoCount': ctx.qsoCount,
        'config': config,
        'reason': 'event',
        'environment': _environment,
        'clock': {'nowMillis': nowMillis(), 'realNowMillis': realNowMillis()},
        'event': event,
      });
      if (!current()) throw StateError('Panel replaced');
      // An answer with neither is a hook that forgot to return. Taken as an
      // empty patch, the operator's change would stand as if accepted.
      if (result == null || (result['values'] == null && result['strings'] == null)) {
        throw const FormatException('A panel event result needs values or strings');
      }
      final values = parseValues(result['values'] ?? const {});
      final strings = parseStrings(result['strings'] ?? const {});
      if (strings.keys.any(values.containsKey)) throw const FormatException('A panel event result names a value as both a number and a string');
      final patch = <String, Object>{...values, ...strings};
      ErrorReportingService.recordSuccess('panel:event:${panel.id}');
      return patch;
    } catch (error, stack) {
      if (current() && !configUnreadable) {
        ErrorReportingService.reportIfRepeated('panel:event:${panel.id}', error, stack, context: 'panel:event:${panel.id}', threshold: 1);
      }
      rethrow;
    } finally {
      // A render started before/during this action cannot replace its result.
      // Request authoritative state again even after a failed command.
      if (current()) {
        _sceneRevision++;
        _requestRender('event');
      }
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _paneSize = constraints.biggest;
      // Watched only for a scene, or for a pane that has not yet said what
      // it is. Resolving the environment is a few dozen theme lookups and a
      // `jsonEncode` to compare against, on every layout pass of a splitter
      // drag — and markdown and HTML never act on a change. They are handed
      // a fresh one when they render ([_render]).
      if (_content == null || _content!.kind == 'scene') {
        _captureEnvironment(panelEnvironment(context, _paneSize));
      }
      return PanelContentView(
        key: ValueKey('${widget.panel.id}:$_sceneGeneration'),
        content: _content,
        error: _error,
        onRetry: _error == null ? null : _retry,
        onSceneEvent: _sceneEvent,
        spectrum: widget.spectrum,
      );
    },
  );
}
