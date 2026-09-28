// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The callsign field is the default focus: if nothing else has a claim on
// it, focus belongs there. [DefaultFocusBackstop] is what makes that an
// invariant rather than a starting condition, on behalf of
// `LoggingControls` — see the class comment for what "nothing" means and
// for the mobile clause.

import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// The backstop for the default-focus rule (docs/design/logging-fields.md
/// § Which field has focus): whenever primary focus lands on NOTHING, the
/// callsign field takes it — or the event text field, while the panel is
/// editing an event row and has no callsign field ([target]). Owns
/// [panelScope], the panel's Tab-trapping scope, because "one of this
/// panel's" is judged against it. The panel's
/// per-path assertions (autofocus, a spot tap, the wipe after a log,
/// `focusCall`) stay; this catches what they miss — a dialog or sheet
/// popping over a panel that had nothing focused, a menu closing, a field
/// disposed by a pane switch, a stray `unfocus()`.
///
/// "Nothing" is a null primary focus, or one of the callsign field's own
/// ancestors holding it — a scope (the root, the route's, the panel's own
/// Tab-trapping one) focused for want of a child — or, outside this panel
/// but on the same route, a node that is not somebody's place: a button
/// that kept the focus of a click, which is what web hands one. A text
/// field, a `DropdownButton` or a key-handling surface (the QSO list)
/// anywhere has a claim and keeps it, as does anything under this panel's
/// own scope (its pills, its Band dropdown), and a scope that is NOT an
/// ancestor belongs to a dialog, sheet, menu or overlay whose focus this
/// must not rob, whatever is in it. A route's scope is the one case
/// that check misses: a route pushed in the same turn as the unfocus
/// (`operation_view` does exactly that on the way into a sheet) only
/// claims focus once its scope is built, a frame after the reclaim would
/// run — so [routeIsCurrent] is checked as well, and without it the
/// callsign field types behind the dialog.
///
/// Not while the app is away: on desktop and web the `FocusManager` parks
/// focus on the root scope when the app goes inactive and puts it back on
/// resume — but only if nothing took it meanwhile. Reclaiming there would
/// be that something, and the operator who switched apps from the QSO list
/// would come back to the callsign field. What the wait misses is looked at
/// on resume ([onResumed]): the parked field may have been disposed while
/// the app was away, or a dialog may have closed on its own, and then the
/// manager restores nothing, notifies nothing, and focus would sit on the
/// root scope for good.
///
/// On mobile the reclaim would raise the virtual keyboard, so it happens
/// only if the operator's last claim was in this panel ([_panelHeldFocus])
/// — and a claim taken elsewhere on the route (a text field in another
/// pane) ends that. And a panel field that loses focus to nothing while the
/// route stays current is the operator closing the keyboard — Done, Back,
/// tap-to-dismiss on the empty callsign field — which is exactly the "nothing
/// focused" they asked for: it is left alone and it ends the claim too, so
/// a dialog opened and closed after it leaves the keyboard down. The one
/// blur that is not that is the sheet's on its way in, and it tells itself
/// apart by the route it pushes in the same turn: the route is no longer
/// current at the end of the frame, the claim is kept, and the field is
/// reclaimed when the sheet pops. Keyboard state can draw none of these
/// lines — it is down at every pop and still up at the instant of either
/// kind of blur — and neither can `hardwareKeyboardAttached`, which
/// governs the autofocus and the spot tap but plays no part here: a device
/// can report a hardware keyboard and still show the on-screen one (the
/// simulator always does; an iPad can), and then the dismissal the
/// operator just made is the only thing worth believing.
class DefaultFocusBackstop {
  DefaultFocusBackstop({required this.target, required this.routeIsCurrent});

  /// The field the backstop reclaims — the callsign field, or the event text
  /// field standing in for it. Read per decision: the panel swaps them.
  final FocusNode Function() target;

  /// Whether the panel's route is the current one — read at the end of the
  /// frame, when a route pushed in the same turn as a blur has landed.
  final bool Function() routeIsCurrent;

  /// The panel's own Tab-trapping scope (the `FocusScope` around the panel);
  /// a node under it is "one of this panel's".
  final panelScope = FocusScopeNode(debugLabel: 'logging panel');

  bool _attached = false;
  bool _disposed = false;
  bool _reclaimFocusScheduled = false;

  /// Whether the last node to hold focus was one of this panel's — see the
  /// class comment. Only the mobile clause reads it.
  bool _panelHeldFocus = false;

  /// Whether the primary focus at the previous notification was under
  /// [panelScope] — what a blur to nothing left, as opposed to a route's
  /// scope handing back on pop.
  bool _lastPrimaryWasPanel = false;

  void attach() {
    if (_attached) return;
    _attached = true;
    FocusManager.instance.addListener(_onPrimaryFocusChanged);
  }

  /// The app is back: whatever focus change landed while it was away was
  /// skipped, so decide again. The manager's own restore of the parked node
  /// is still pending at this point; the post-frame callback applies it
  /// before looking, and finds it a claim when it took.
  void onResumed() => _onPrimaryFocusChanged();

  /// Stops listening and releases [panelScope]. Call before disposing the
  /// nodes [target] can return.
  void dispose() {
    _disposed = true;
    if (_attached) FocusManager.instance.removeListener(_onPrimaryFocusChanged);
    panelScope.dispose();
  }

  /// Null before the platform has said anything, which is not "away".
  static bool get _appIsResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  void _onPrimaryFocusChanged() {
    if (_disposed || !_appIsResumed) return;
    // A node not in the tree (the callsign field while an event row is
    // edited, before the swap) has no ancestry to judge against; its
    // `context` is no guide, since a node keeps the last one it was
    // attached with.
    final target = this.target();
    if (target.ancestors.isEmpty) return;
    final primary = FocusManager.instance.primaryFocus;
    final leftPanel = _lastPrimaryWasPanel;
    _lastPrimaryWasPanel = primary != null && primary.ancestors.contains(panelScope);
    if (!_focusIsUnclaimed()) {
      if (_lastPrimaryWasPanel) {
        _panelHeldFocus = true;
      } else if (primary is! FocusScopeNode && target.ancestors.contains(primary!.enclosingScope)) {
        _panelHeldFocus = false;
      }
      return;
    }
    if (_reclaimFocusScheduled) return;
    if (isMobilePlatform && !_panelHeldFocus) return;
    _reclaimFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_appIsResumed) {
        _reclaimFocusScheduled = false;
        return;
      }
      // A request made earlier in this same post-frame phase — the web
      // view-focus guard putting a parked field back, a menu item handing
      // focus on — is still pending, and would read as "nothing" here and
      // be overridden by the reclaim. Applying first makes it the claim it
      // is. (`MenuAnchor` does the same, for the same reason.) It notifies
      // synchronously, re-entering the listener above, which is why the
      // scheduled flag is still up here: the re-entry updates the memory
      // and schedules nothing, and this callback decides on what it left.
      FocusManager.instance.applyFocusChangesIfNeeded();
      _reclaimFocusScheduled = false;
      if (!_focusIsUnclaimed() || !routeIsCurrent()) return;
      if (isMobilePlatform && (leftPanel || !_panelHeldFocus)) {
        _panelHeldFocus = false;
        return;
      }
      // A locked form's fields are disabled, so this is a no-op there —
      // "no field takes focus", per the contract.
      this.target().requestFocus();
    });
    // The callback needs a frame to run in, and nothing else may be
    // scheduling one.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _focusIsUnclaimed() {
    final primary = FocusManager.instance.primaryFocus;
    final ours = target().ancestors;
    if (primary == null || ours.contains(primary)) return true;
    if (primary.ancestors.contains(panelScope)) return false;
    if (primary is FocusScopeNode || !ours.contains(primary.enclosingScope)) return false;
    return !_isKeyboardSurface(primary);
  }

  /// Whether [node] is somewhere the operator would type or steer from — as
  /// opposed to a button holding the focus of a click. A key handler is the
  /// mark of a navigation surface (the QSO list); a text field's node is the
  /// `EditableText`'s own; a `DropdownButton` is an `InkWell` inside, so it
  /// has to be recognized by name.
  static bool _isKeyboardSurface(FocusNode node) {
    if (node.onKeyEvent != null) return true;
    final ctx = node.context;
    if (ctx == null) return false;
    if (ctx.findAncestorStateOfType<EditableTextState>() != null) return true;
    var dropdown = false;
    ctx.visitAncestorElements((element) {
      dropdown = element.widget is DropdownButton;
      return !dropdown;
    });
    return dropdown;
  }
}
