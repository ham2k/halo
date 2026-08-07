// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One extension-contributed panel in a customizable view: asks the panel's
// hook for a document, draws it with PanelContentView, and re-asks when
// something the panel declared an interest in changes.
//
// The trigger list is a budget, not a subscription. Every render crosses the
// JS bridge, so a panel is re-rendered only for what it asked for, never
// more often than `panelRenderThrottle`, and never at all while it is behind
// another tab — an unselected dock tab stays MOUNTED (IndexedStack), which
// the dock publishes through DockPaneVisibility; without that last rule a
// four-panel layout would keep paying for the three panels nobody is looking
// at.
//
// The budget has two halves: what the panel's DESCRIPTOR declared, paid by
// every placement of that panel, and what THIS placement's last render asked
// for (`PanelContent.triggers`). The second exists for panels whose content
// the operator writes — one custom-text pane naming the callsign being typed
// must not put the others on the typing path with it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../i18n/strings.g.dart';
import '../../services/error_reporting_service.dart';
import '../../services/panel_service.dart';
import 'panel_content_view.dart';

/// What a panel renders against, gathered by the view. Compared field by
/// field to decide whether a rebuild is worth a render — the view rebuilds
/// for reasons no panel cares about.
@immutable
class PanelRenderContext {
  final Operation operation;
  final Map<String, dynamic>? qso;
  final int qsoCount;

  /// Bumped by the view when spots refresh or a lookup resolves — signals
  /// that carry no value of their own into the render args.
  final int spotsRevision;
  final int lookupRevision;

  const PanelRenderContext({
    required this.operation,
    this.qso,
    required this.qsoCount,
    this.spotsRevision = 0,
    this.lookupRevision = 0,
  });

  /// The triggers that fired between [previous] and this — empty means
  /// nothing this panel could have asked for actually changed.
  Set<String> changesFrom(PanelRenderContext previous) => {
    if (operation.uuid != previous.operation.uuid || operation.data != previous.operation.data) 'operation',
    if (qso != previous.qso) 'qso',
    if (qsoCount != previous.qsoCount) 'qsoLogged',
    if (spotsRevision != previous.spotsRevision) 'spots',
    if (lookupRevision != previous.lookupRevision) 'lookup',
  };
}

class ExtensionPanel extends StatefulWidget {
  final PanelDefinition panel;
  final PanelService panels;
  final PanelRenderContext renderContext;

  /// A title this render supplied, or null to fall back to the descriptor's.
  /// The tab lives in the dock, above this widget, so the label has to be
  /// handed upward — and it can only be known once the panel has answered.
  final ValueChanged<String?>? onTitle;

  const ExtensionPanel({
    super.key,
    required this.panel,
    required this.panels,
    required this.renderContext,
    this.onTitle,
  });

  @override
  State<ExtensionPanel> createState() => _ExtensionPanelState();
}

class _ExtensionPanelState extends State<ExtensionPanel> {
  PanelContent? _content;
  String? _error;

  /// False while this panel sits behind another tab. It stays mounted (so
  /// its scroll position and content survive), but it stops rendering —
  /// published by the dock, since nothing else knows which pane of a group
  /// is on top.
  bool _visible = true;

  /// Set while a render is in flight, so a burst of triggers coalesces into
  /// one follow-up call instead of stacking calls the bridge will run in
  /// order anyway.
  bool _rendering = false;
  bool _pending = false;
  DateTime? _lastRenderedAt;
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
      if (!_visible) return;
      _rendered = true;
      // Straight to the bridge, not through the throttle: the operator is
      // looking at an empty pane until this answers.
      _render('initial');
      return;
    }
    // Coming back to the top: ask again only if something it cares about
    // happened while nobody was looking.
    if (becameVisible && _missedWhileHidden) {
      _missedWhileHidden = false;
      _requestRender('visible');
    }
  }

  @override
  void initState() {
    super.initState();
    widget.panels.addListener(_onCatalogChanged);
    _startTicker();
  }

  /// Everything this pane re-renders for: the triggers of the definition it
  /// was built with, plus the ones its own last render declared.
  ///
  /// The definition, NOT `panels[id]` — a pane outlives a runtime restart
  /// and keeps rendering while the catalog has no answer for its id, and
  /// asking the catalog would silently drop its descriptor's triggers for
  /// the length of that gap.
  Set<String> get _triggers => {
    ...widget.panel.triggers,
    ...widget.panels.declaredTriggers(widget.panel.id),
  };

  /// The panel's own config was edited (its form is host-persisted, so
  /// nothing else would tell this panel its inputs changed).
  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panel.id);
    if (revision == _configRevision) return;
    _configRevision = revision;
    if (!_visible) {
      _missedWhileHidden = true;
      return;
    }
    _requestRender('config');
  }

  int _configRevision = 0;

  @override
  void didUpdateWidget(ExtensionPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.panel.id != widget.panel.id) {
      _content = null;
      _error = null;
      _missedWhileHidden = false;
      _startTicker();
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
    if (!DockPaneVisibility.readOf(context)) {
      // Behind a tab: remembered, not rendered. The pane is still mounted,
      // so it would otherwise pay for every trigger nobody is watching.
      _missedWhileHidden = true;
      return;
    }
    _requestRender(fired.first);
  }

  void _startTicker() {
    _tick?.cancel();
    final seconds = _triggers
        .map((t) => t.startsWith('tick:') ? int.tryParse(t.substring(5)) : null)
        .nonNulls
        .fold<int?>(null, (best, s) => best == null ? s : (s < best ? s : best));
    if (seconds == null) return;
    // Floored rather than rejected: a panel asking for one-second updates
    // has misjudged what a bridge call costs, and dropping its panel over
    // that would be a worse answer than slowing it down.
    final period = Duration(seconds: seconds < minPanelTickSeconds ? minPanelTickSeconds : seconds);
    _tick = Timer.periodic(period, (_) {
      if (_visible) {
        _requestRender('tick');
      } else {
        _missedWhileHidden = true;
      }
    });
  }

  /// Renders no sooner than [panelRenderThrottle] after the last one.
  void _requestRender(String reason) {
    final since = _lastRenderedAt == null ? null : DateTime.now().difference(_lastRenderedAt!);
    if (since != null && since < panelRenderThrottle) {
      _throttle?.cancel();
      _throttle = Timer(panelRenderThrottle - since, () => _render(reason));
      return;
    }
    _render(reason);
  }

  Future<void> _render(String reason) async {
    if (_rendering) {
      // Whatever the newest reason is, the next render reads the newest
      // context anyway — only that one call is owed.
      _pending = true;
      return;
    }
    _rendering = true;
    _lastRenderedAt = DateTime.now();
    // Captured, so a render still in flight when the widget is handed a
    // different panel can't paint one panel's content under another's tab —
    // a plausible wrong answer is worse than an error.
    final panel = widget.panel;
    try {
      final ctx = widget.renderContext;
      // Read OUTSIDE the render's own try: a config read reaching the
      // keychain can fail for reasons that have nothing to do with this
      // extension, and blaming its panel would point the investigation at
      // the wrong component. An unreadable config renders as an empty one.
      Map<String, dynamic> config;
      try {
        config = await widget.panels.configFor(panel);
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'panel:config:${panel.id}');
        config = const {};
      }
      final result = await widget.panels.render(panel, {
        'operation': {
          ...ctx.operation.data,
          'uuid': ctx.operation.uuid,
          // Row COLUMNS, not QSON — `qsonPayloadFor`'s shape carries neither,
          // and a panel is the surface that most wants to say when the
          // operation ran. Without them a template naming the operation's
          // date has nothing to name (see the SDK's `opValues`).
          if (ctx.operation.startAtMillisMin != null) 'startAtMillisMin': ctx.operation.startAtMillisMin,
          if (ctx.operation.startAtMillisMax != null) 'startAtMillisMax': ctx.operation.startAtMillisMax,
        },
        if (ctx.qso != null) 'qso': ctx.qso,
        'qsoCount': ctx.qsoCount,
        'config': config,
        'reason': reason,
      });
      if (!mounted || panel.id != widget.panel.id) return;
      final content = PanelContent.fromJson(result);
      // Before the content is shown, so the ticker a template just asked for
      // is running by the time anyone could look at what it rendered. A
      // render that fails leaves the previous declaration standing: a panel
      // that throws has said nothing about what it needs, and dropping its
      // triggers would strand it on the error it just produced.
      if (content != null && widget.panels.declareTriggers(panel.id, content.triggers)) _startTicker();
      setState(() {
        _content = content;
        _error = content == null ? context.t.operation.layout.panelRenderFailed(panel: panel.title) : null;
      });
      // After the setState, not inside it: this reaches the VIEW's state, and
      // a panel is free to return the same title on every render, so the
      // listener has to be the one that drops a repeat.
      widget.onTitle?.call(content?.title);
    } catch (e, stack) {
      // Through ErrorPolicy like everything else (docs/design/error-reporting.md):
      // a panel that throws for every operator is exactly the thing that has
      // to be visible in aggregate, and a handler deciding on its own to keep
      // it local is the pattern that policy exists to prevent. What the
      // OPERATOR sees is a sentence naming the panel — an exception's
      // toString is not a user-facing string.
      ErrorReportingService.report(e, stack, context: 'panel:render:${panel.id}');
      if (!mounted || panel.id != widget.panel.id) return;
      setState(() => _error = context.t.operation.layout.panelRenderFailed(panel: panel.title));
    } finally {
      _rendering = false;
      if (_pending && mounted) {
        _pending = false;
        _requestRender('coalesced');
      }
    }
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
    _throttle?.cancel();
    _tick?.cancel();
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

  @override
  Widget build(BuildContext context) =>
      PanelContentView(content: _content, error: _error, onRetry: _error == null ? null : _retry);
}
