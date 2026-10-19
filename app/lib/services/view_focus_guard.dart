// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keeps a spurious browser focus report from killing the focused field.

import 'dart:async' show scheduleMicrotask, unawaited;
import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter/widgets.dart';

import 'document_focus.dart';

/// Puts focus back when the browser reports the Flutter view unfocused while
/// the page itself is still focused.
///
/// On web with the accessibility DOM on, the engine hosts the focused text
/// field in a real `<input>` inside the semantics tree. Churn anywhere in that
/// tree — a status-bar message arriving, a progress bar's label changing a few
/// nodes away — can blur that input with nothing taking its place, which
/// leaves the document's active element on `<body>`. The browser then reports
/// the whole view as unfocused and Flutter answers by parking focus on the
/// root scope (`_ViewState.didChangeViewFocus`), where no widget can receive a
/// keystroke: the caret vanishes and the operator has to click the field again.
///
/// What separates that from the operator genuinely leaving is the PAGE's own
/// focus. Switching window, tab or application takes it; the accessibility
/// DOM's blur does not. So a view-unfocused report that arrives while
/// [documentHasFocus] is still true is spurious, and the focus just parked is
/// put back.
///
/// Web-only — nowhere else routes focus through a DOM that can produce the
/// report. The stub's `false` makes this inert off web even if it were
/// installed there.
class ViewFocusGuard with WidgetsBindingObserver {
  ViewFocusGuard._(this._pageHasFocus);

  final bool Function() _pageHasFocus;

  /// Installs the guard for the app's lifetime. Never removed: there is no
  /// point in the app's life where a spurious unfocus stops being wrong.
  static void install() {
    if (!kIsWeb) return;
    installWith(documentHasFocus);
  }

  /// Installs against an explicit page-focus predicate, and hands the guard
  /// back so it can be taken down again.
  ///
  /// Tests run off web, where [documentHasFocus] is a constant `false` — every
  /// case would pass by the guard never doing anything at all.
  @visibleForTesting
  static ViewFocusGuard installWith(bool Function() pageHasFocus) {
    final guard = ViewFocusGuard._(pageHasFocus);
    FocusManager.instance.addListener(guard._remember);
    WidgetsBinding.instance.addObserver(guard);
    return guard;
  }

  @visibleForTesting
  void uninstall() {
    FocusManager.instance.removeListener(_remember);
    WidgetsBinding.instance.removeObserver(this);
  }

  /// The last node that actually held focus. Never the root scope — that IS
  /// the parked state this undoes, so remembering it would make the guard
  /// restore the very thing it is there to reverse.
  FocusNode? _lastFocused;

  /// The node a spurious unfocus interrupted, held until the view has its
  /// focus back and the node has been re-asserted. Null whenever no recovery
  /// is in flight, which is what keeps the guard out of the way of focus
  /// changes the operator caused.
  FocusNode? _recovering;

  /// What Flutter's own handling of the latest report focused: the parked
  /// root scope, or whatever its answer to a `focused` event picked. Anything
  /// else holding focus when a restore runs was the app's own request.
  FocusNode? _reportOutcome;

  /// Reads [_reportOutcome] once every observer has handled the report.
  /// Flutter's handling runs in the same dispatch as ours, before or after
  /// it, so only a microtask is sure to see what it did.
  void _noteReportOutcome() {
    scheduleMicrotask(() {
      FocusManager.instance.applyFocusChangesIfNeeded();
      _reportOutcome = FocusManager.instance.primaryFocus;
    });
  }

  /// The node the app focused since the report, or null when focus is still
  /// where the report, or [node], left it. One of [node]'s own scopes is
  /// never the app's choice: a field that lets go of focus hands it to its
  /// enclosing scope, which takes no keystrokes — parked in all but name. A
  /// scope elsewhere (a dialog's, opened with nothing to autofocus) is.
  ///
  /// The report is the only thing the guard undoes. Moving focus from one
  /// text field to another that has only just been built (FIND opening the
  /// log's Find bar) can itself blur the browser's input, so the report and
  /// its echo land in the same frame as the app's request; restoring over it
  /// hands the caret back to the field the app moved away from.
  FocusNode? _focusedSinceReport(FocusNode node) {
    FocusManager.instance.applyFocusChangesIfNeeded();
    final now = FocusManager.instance.primaryFocus;
    if (now == null || identical(now, node) || identical(now, _reportOutcome) || (now is FocusScopeNode && node.ancestors.contains(now))) return null;
    return _isLive(now) ? now : null;
  }

  void _remember() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || identical(node, FocusManager.instance.rootScope)) return;
    _lastFocused = node;
  }

  /// Whether [node] is still somewhere in the focus tree.
  ///
  /// NOT `node.context != null`: a node's context is set when it attaches and
  /// never cleared again — not by `detach`, not by `dispose` — so that reads
  /// true forever and would have the guard chase a field that is long gone.
  /// `enclosingScope` walks parents, and detaching clears those.
  static bool _isLive(FocusNode? node) => node != null && node.enclosingScope != null;

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    switch (event.state) {
      case ViewFocusState.unfocused:
        // The operator really did leave — window, tab or application. Their
        // focus change is not ours to undo.
        if (!_pageHasFocus()) return;
        // A recovery is already in flight. Overwriting it would leave the
        // first echo uncorrected, which is the very regression the `focused`
        // case exists to prevent.
        if (_recovering != null) return;
        if (!_isLive(_lastFocused)) {
          _lastFocused = null;
          return;
        }
        final node = _lastFocused!;
        _recovering = node;
        _noteReportOutcome();
        _afterThisFrame(() {
          if (!_isLive(node)) {
            // Nothing left to restore — but the view is still DOM-unfocused,
            // which is the state where the app takes no keystrokes at all. Let
            // the framework put focus somewhere rather than leaving it parked.
            _recovering = null;
            _requestViewFocus(event.viewId);
            return;
          }
          if (_focusedSinceReport(node) case final moved?) {
            // The echo, when it has yet to come, re-asserts the app's choice
            // over Flutter's answer to it instead.
            if (identical(_recovering, node)) _recovering = moved;
            return;
          }
          // Focusing the node is the whole request. The browser's focus comes
          // back on its own: the scope regaining it is an edge `_ViewState`
          // watches for, and it asks the platform for the view's focus in
          // response — so an explicit request here is redundant, which is why
          // there isn't one. It has to be done AFTER the parking has landed
          // though, or the scope never loses focus, that edge never happens,
          // and the browser's focus stays on `<body>` while the caret returns:
          // a field that looks focused and swallows everything typed into it.
          node.requestFocus();
          _warnIfFocusRefused(node);
        });

      case ViewFocusState.focused:
        final node = _recovering;
        _recovering = null;
        // A view focus the operator caused — coming back to the tab, or a
        // click. Flutter's own handling of it is correct; leave it alone.
        if (node == null) return;
        _noteReportOutcome();
        // The view regaining focus is NOT the end of the recovery, it is the
        // last thing that can wreck it. Flutter answers a `focused` event by
        // running `findFirstFocus(scope, ignoreCurrentFocus: true)` and
        // focusing THAT — the view's first focusable widget, not the one the
        // operator was in. Left alone it lands the caret in the callsign
        // field while someone is typing a note, which is a worse bug than the
        // one this class exists for. So the remembered node is asserted again,
        // after that has run.
        _afterThisFrame(() {
          if (!_isLive(node) || _focusedSinceReport(node) != null) return;
          node.requestFocus();
          _warnIfFocusRefused(node);
          // Re-focuses the editing element the engine feeds `EditableText`
          // from. Only for a node that actually hosts one: the message starts
          // an editing session, and sending it when no text field has ever
          // opened one throws inside the platform handler where nothing
          // attributes it to us. It also keeps a mobile keyboard from being
          // raised over a focused button.
          if (node.context?.findAncestorStateOfType<EditableTextState>() != null) {
            unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
          }
        });
    }
  }

  /// Asks the platform for the view's focus when there is no node to restore.
  void _requestViewFocus(int viewId) {
    WidgetsBinding.instance.platformDispatcher.requestViewFocusChange(viewId: viewId, state: ViewFocusState.focused, direction: ViewFocusDirection.undefined);
  }

  /// Says so when a restore did not take.
  ///
  /// `requestFocus` is a no-op on a node that cannot take focus — disabled in
  /// the same frame, or under a scope that has stopped accepting it — and the
  /// framework's own complaint about that case is an ErrorPolicy `logOnly`
  /// rule (`focus-node-cannot-request-focus`), so absolutely nothing would
  /// otherwise mark the difference between this guard working and this guard
  /// quietly leaving a dead field with a blinking caret.
  void _warnIfFocusRefused(FocusNode node) {
    if (identical(FocusManager.instance.primaryFocus, node)) return;
    debugPrint('[focus] view-focus recovery did not take for ${node.debugLabel ?? node.runtimeType}');
  }

  /// Runs [action] once the frame in flight is done.
  ///
  /// Post-frame rather than a microtask: the parking, and the framework's own
  /// answer to a `focused` event, both happen while this event is being
  /// dispatched. Anything scheduled here therefore marks its focus request
  /// last, which is the one that wins.
  ///
  /// `ensureVisualUpdate` because `addPostFrameCallback` does not schedule a
  /// frame of its own, and a view losing focus need not dirty anything — the
  /// callback would otherwise sit queued until some unrelated frame ran.
  void _afterThisFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
