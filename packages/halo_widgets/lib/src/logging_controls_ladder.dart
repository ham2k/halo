// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The focus ladder (APP-19, docs/design/logging-fields.md § "Leaving the
// entry row"):
//
//     QSO list  ──▲──  secondary pills  ──▲──  main logging fields
//               ──▼──                   ──▼──
//
// Arrow Up walks outward from the fields, Arrow Down walks back in, so the
// whole panel is reachable without leaving the home row. Every rung hangs
// its handling off a FocusNode's own `onKeyEvent` rather than a panel-wide
// `CallbackShortcuts`: a node handler only sees keys aimed at that rung,
// while a panel-wide arrow binding would swallow the arrow keys for
// everything in the panel — including a text field's own caret movement.
//
// [LoggingFocusLadder] holds the rungs' nodes and every move between them on
// behalf of `LoggingControls`: which main field the keyboard was last in and
// gets back to, which pill it was last on, where the next field's caret
// lands, and the key handlers for a main field, a pill and an open control.
// The panel keeps what is its own — which fields are on the row, what each
// control opens into, and opening a control (the More pane, the Time seed)
// — and hands them over through the configuration and the callbacks.
//
// Crossing out of the panel is the host's business, not this widget's:
// `onNavigateToQsoList` hands the keyboard up, and `LoggingControlsController`
// hands it back.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logging_controls_metrics.dart';
import 'secondary_control_row.dart' show SecondaryControlSpec;

/// What the ladder reads from the panel — re-read on every use rather than
/// copied in, because each of these can change under a mounted panel.
typedef FocusLadderConfig = ({
  /// The main logging fields in row order, each with its controller — Tab
  /// and the arrows have to read the caret and the value, not just move
  /// focus. A function: the row is rebuilt on every read (the RST fields,
  /// the exchange fields and the optional State/Grid all come and go).
  List<PrimaryField> Function() primaryFields,

  /// The field a control expands *into* — what the operator opened it to
  /// type in — or null for a control with nothing to type.
  FocusNode? Function(String? key) expandedFocusFor,

  /// Every focusable field inside a control's expanded content, in layout
  /// order, each with its controller.
  List<(FocusNode, TextEditingController)> Function(String key) expandedFieldOrderFor,

  /// The control that is open, if any.
  String? selectedControlKey,

  /// Whether the form refuses input right now — a locked form's secondary
  /// controls are pointer-blocked and dimmed, and the keyboard shouldn't
  /// reach past that either. A function: the panel derives it.
  bool Function() fieldsLocked,

  /// Whether an event row is loaded: then there is no callsign field, and
  /// the event text field stands in for it.
  bool editingEvent,
  FocusNode eventTextFocus,
  FocusNode callFocus,

  /// Hands the keyboard up to the host's QSO list; true when it took it.
  /// Null when the host has none — then the pills are the top rung.
  bool Function()? navigateToQsoList,
});

/// The ladder. See the file comment.
///
/// Not a notifier: every move it makes lands on a focus node, and the panel's
/// own focus listeners repaint. Disposed with the panel; a post-frame
/// callback that outlives it checks before touching a node.
class LoggingFocusLadder {
  LoggingFocusLadder({required this.config, required this.selectControl, required this.showControl});

  /// The panel as it stands right now.
  final FocusLadderConfig Function() config;

  /// Opens (or, with null, closes) a control the way a tap does — the
  /// panel's own decision, since a tap on `more` pops a pane instead of
  /// expanding, and an event row refuses every control but Time. For
  /// everything else the panel comes back to [openControl]/[closeControl].
  final void Function(String? key) selectControl;

  /// Shows (or, with null, hides) a control WITHOUT moving focus — a
  /// crossing lands on the field it chose itself. The panel seeds the Time
  /// fields here, as it does on a tap, and repaints.
  final void Function(String? key) showControl;

  bool _disposed = false;

  // ---- The main fields ----

  /// The main field the keyboard was last in, so collapsing a secondary
  /// control puts the operator back where they left off rather than always
  /// at Call. Null until one has been focused at all.
  ///
  /// Tracked continuously, NOT sampled when a chip is tapped: by the time
  /// the tap reaches [selectControl] the field has usually already been
  /// blurred (on desktop and web a TextField's own tap-outside drops focus
  /// on any tap outside it), so "which field has focus right now" reads as
  /// none and every collapse would fall back to Call.
  FocusNode? _lastPrimaryFocus;

  /// Where the next primary field to gain focus should put its caret, and
  /// the node that instruction belongs to.
  ///
  /// Set ONLY for a rightward arrow move — the single path that wants
  /// anything other than the end-of-value default the focus listeners
  /// already apply. A leftward move and every Tab move want the end, so they
  /// set nothing: writing `text.length` for them too means Tab onto an
  /// already-focused node (a row with one primary field) leaves an
  /// instruction nobody collects, and the next field to focus — Frequency,
  /// say — takes it and puts its caret at 0.
  ///
  /// Keyed to the node because `requestFocus` does NOT deliver focus
  /// synchronously: `FocusManager` applies it on a microtask, so another
  /// node can reach the listeners first.
  ({FocusNode node, int offset})? _pendingCaret;

  /// Just the nodes of the main fields, for the callers that only move focus
  /// and never read a value.
  List<FocusNode> get primaryFocusOrder => [for (final field in config().primaryFields()) field.focus];

  /// Only a main field's own node is remembered — a secondary control's
  /// field (Frequency, Time, a ref) must never become the place we return
  /// to.
  void notePrimaryFocus(FocusNode node) {
    if (primaryFocusOrder.any((f) => identical(f, node))) _lastPrimaryFocus = node;
  }

  /// The pending caret offset for [node], if it is the node the instruction
  /// was meant for.
  ///
  /// Only a PRIMARY field resolves an instruction: Freq and Time share these
  /// focus listeners but are secondary-control fields, so they must neither
  /// consume one nor discard one in passing. Any other primary field
  /// arriving first DOES clear it — by then it is stale, and leaving it set
  /// would misplace the caret the next time its target happened to take
  /// focus.
  int? takePendingCaretOffset(FocusNode node, TextEditingController controller) {
    final pending = _pendingCaret;
    if (pending == null) return null;
    if (!primaryFocusOrder.any((f) => identical(f, node))) return null;
    _pendingCaret = null;
    return identical(pending.node, node) ? pending.offset.clamp(0, controller.text.length) : null;
  }

  /// Moves focus to the next primary field Space stops at, wrapping back to
  /// Call after the last one.
  void advancePrimaryFocus() {
    final fields = config().primaryFields();
    final current = fields.indexWhere((f) => f.focus.hasFocus);
    // Nothing focused counts as sitting on the last field, so the walk
    // starts at Call.
    final next = _nextStop(fields, current < 0 ? fields.length - 1 : current, forward: true);
    if (next != null) fields[next].focus.requestFocus();
  }

  /// The index of the field Space and Tab stop at after (or, going back,
  /// before) [index], wrapping at both ends and passing over every
  /// `skipFocus` field. Null when no other field takes a stop.
  static int? _nextStop(List<PrimaryField> fields, int index, {required bool forward}) {
    for (var step = 1; step < fields.length; step++) {
      final i = (index + (forward ? step : -step)) % fields.length;
      if (!fields[i].skipFocus) return i;
    }
    return null;
  }

  /// Moves focus to [index] among the main fields (wrapping at either end)
  /// and says where the caret should land — the start of the value for a
  /// rightward move, the end for a leftward one, so the caret keeps
  /// travelling in the direction the arrow key was pushing it.
  void movePrimaryFocus(int index, {required bool caretAtStart}) {
    final fields = config().primaryFields();
    final node = fields[(index + fields.length) % fields.length].focus;
    // Assigning null on the end-of-value path also clears any instruction
    // left over from a move whose target never arrived.
    _pendingCaret = caretAtStart ? (node: node, offset: 0) : null;
    node.requestFocus();
  }

  /// Tab and the arrow keys inside a main logging field.
  ///
  /// Tab is always ours: it walks the same stops Space does, passing over the
  /// `skipFocus` fields, and wraps at both ends — Flutter's own traversal
  /// would stop on a skipped field, walk on off the last field into the
  /// chips and the Log button, and Shift-Tab off the callsign out of the row
  /// entirely. The entry row is a loop, not a waypoint. The arrow keys are
  /// intercepted only at the edge of a value, and they stop at EVERY field,
  /// skipped ones included — they are how a skipped field is reached.
  KeyEventResult onPrimaryFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final fields = config().primaryFields();
    final index = fields.indexWhere((f) => identical(f.focus, node));
    // A node that isn't currently a primary field (its control stopped being
    // rendered, say) keeps whatever the platform would do.
    if (index < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Shift is the only modifier that means anything to us (it reverses
    // Tab). Everything else belongs to the platform or the field: Cmd/Option
    // +arrow are line- and word-wise caret moves, and Ctrl+Tab is a pane
    // switch on every desktop — claiming them would take real editing
    // gestures away and teleport the operator to another field instead.
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    // Arrow Up leaves the row upward, for the secondary control pills — the
    // keyboard-only way out that the Tab loop above deliberately doesn't
    // provide (APP-19), opening the pill it lands on immediately rather
    // than waiting for a separate Enter. Inert while the fields are locked:
    // a staged-delete or deleted QSO's secondary controls are pointer-blocked
    // and dimmed, and the keyboard shouldn't reach past that either. (An
    // open options menu keeps Up for its own highlight; the exchange node
    // takes it before it reaches here.)
    if (key == LogicalKeyboardKey.arrowUp) {
      if (config().fieldsLocked()) return KeyEventResult.ignored;
      focusPillAndOpen();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      final next = _nextStop(fields, index, forward: !shift);
      if (next != null) movePrimaryFocus(next, caretAtStart: false);
      return KeyEventResult.handled;
    }

    if (key != LogicalKeyboardKey.arrowRight && key != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }
    // Shift-arrow is selecting text, and a non-collapsed selection means the
    // arrow collapses it rather than leaving the field. Only a bare caret
    // sitting against an edge is asking to travel.
    if (shift || fields.length < 2) return KeyEventResult.ignored;
    final controller = fields[index].controller;
    final selection = controller.selection;
    if (!selection.isCollapsed || selection.baseOffset < 0) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowRight && selection.baseOffset >= controller.text.length) {
      movePrimaryFocus(index + 1, caretAtStart: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && selection.baseOffset == 0) {
      movePrimaryFocus(index - 1, caretAtStart: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Opens [key]'s control and lands the keyboard on the field it opens
  /// into — Radio's Frequency, the field the operator actually types in —
  /// once it has built. A control with nothing to type (Spotting with its
  /// comment hidden) leaves focus alone rather than yanking it somewhere
  /// useless.
  void openControl(String key) {
    showControl(key);
    final target = config().expandedFocusFor(key);
    if (target != null) _requestFocusOnceBuilt(key, target);
  }

  /// Closes whatever is open and hands the cursor back to the main field the
  /// operator was in, so logging continues without a tap.
  void closeControl() {
    showControl(null);
    focusLastPrimaryField();
  }

  /// Back to the field the operator was last in, with Call as the fallback
  /// for a remembered node whose field is gone (the contest changed, RSTs
  /// were hidden) — such a node would swallow the request silently.
  ///
  /// "Gone" is a MOUNTED check, not a null one: a node detached from its
  /// field keeps the context it last had, defunct, and a request on it is
  /// deferred until it is reparented — which for a field that left the row
  /// is never, leaving the keyboard on no field at all.
  void focusLastPrimaryField() {
    final config = this.config();
    if (config.editingEvent) {
      // Neither the callsign field nor a remembered primary field exists
      // while an event is loaded — NOTE/TODO's own text is the only
      // focusable main field, if this event even has one.
      if (_isOnScreen(config.eventTextFocus)) config.eventTextFocus.requestFocus();
      return;
    }
    final remembered = _lastPrimaryFocus;
    ((remembered != null && _isOnScreen(remembered)) ? remembered : config.callFocus).requestFocus();
  }

  static bool _isOnScreen(FocusNode node) => node.context?.mounted ?? false;

  // ---- The pills ----

  /// One node per secondary control pill, so the keyboard can sit on a pill
  /// the way it sits on a field. Owned here rather than inside
  /// `SecondaryControlRow` so all of the panel's keyboard policy stays in
  /// one place; the row just passes it to the chip. Long-lived — the chips
  /// themselves are rebuilt constantly and animate in and out.
  final Map<String, FocusNode> _pillFocus = {};

  FocusNode pillFocusFor(String key) => _pillFocus[key] ??= FocusNode(debugLabel: 'pill:$key', onKeyEvent: (node, event) => onPillKeyEvent(key, event));

  /// The pill keys on the strip, in display order — recorded by the panel
  /// as it assembles the specs, so the arrow keys walk exactly what is on
  /// screen (hidden controls, an activity that stopped applying, a reorder
  /// from the settings dialog) instead of a second list that could drift
  /// from it.
  List<String> pillOrder = const [];

  /// The pill the keyboard was last on, so stepping down to a field and
  /// back up returns to where you were rather than to the start of the
  /// strip.
  String? _lastPillKey;

  /// Moves the keyboard onto the pill strip — at [key] when given, else the
  /// pill it was last on, else the first. A no-op when there are no pills.
  /// Returns the pill it landed on (null when there were none), so callers
  /// that also need to open it don't have to re-derive the same target.
  ///
  /// The strip scrolls horizontally and can hold more pills than fit, so a
  /// focused pill also has to be scrolled into view: focus alone doesn't
  /// move a viewport.
  String? _focusPill([String? key]) {
    final order = pillOrder;
    if (order.isEmpty) return null;
    final remembered = _lastPillKey;
    final target = (key != null && order.contains(key)) ? key : (remembered != null && order.contains(remembered) ? remembered : order.first);
    _lastPillKey = target;
    final node = pillFocusFor(target);
    node.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = node.context;
      if (context == null || _disposed) return;
      Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    });
    return target;
  }

  /// [_focusPill], then opens whatever it landed on — the single motion
  /// that replaces the old separate "land on the pill, then Enter to open"
  /// steps. Skips `more`: it pops a dialog rather than expanding inline, and
  /// arriving by keyboard shouldn't trigger that on its own (Enter still
  /// does, same as a tap).
  void focusPillAndOpen([String? key]) {
    final target = _focusPill(key);
    if (target == null) return;
    if (target == 'more') {
      _restOnMore();
      return;
    }
    selectControl(target);
  }

  /// `more` never opens, but whatever WAS open — a control left visibly
  /// expanded from before this move, or the one just crossed out of — still
  /// needs to close, or its panel is left rendered under a keyboard that
  /// already moved on.
  void _restOnMore() {
    if (config().selectedControlKey != null) showControl(null);
  }

  /// Crosses onto [key]'s pill for Tab/Shift-Tab — opens its control (unless
  /// `more`, which pops a dialog rather than expanding) and lands on its own
  /// first (`fromStart: true`) or last field, NOT the one field it opens
  /// into on a tap or on arrival via Up ([focusPillAndOpen]'s target —
  /// Radio's Frequency, the field the operator actually types into).
  /// Landing there from a Tab crossing in from Time would skip Band
  /// entirely. A fieldless control just leaves the keyboard on its own
  /// chip, same as [focusPillAndOpen].
  ///
  /// Left/Right go through [_crossToNextControl] instead, which always
  /// lands on the canonical field regardless of direction — see its own doc
  /// for why.
  void crossToPill(String key, {required bool fromStart}) {
    _focusPill(key);
    if (key == 'more') {
      _restOnMore();
      return;
    }
    showControl(key);
    final fields = config().expandedFieldOrderFor(key);
    if (fields.isEmpty) return;
    final target = fromStart ? fields.first.$1 : fields.last.$1;
    _requestFocusOnceBuilt(key, target);
  }

  /// Requests focus for [target], a field belonging to [key]'s control,
  /// retrying one extra frame later if it can't take focus yet.
  ///
  /// A DropdownMenu field (Band/Mode) re-entered after being closed needs a
  /// frame of its own beyond the rebuild that reopens it: closing disables
  /// the supplied FocusNode's `canRequestFocus` as part of tearing the
  /// internal widget down, and DropdownMenu restores it (the panel's own
  /// `expandedBuilder` sets it back to `typeable`) only once ITS rebuild has
  /// run — which can land one frame after ours. A single post-frame
  /// callback can lose that race and silently do nothing (`requestFocus()`
  /// on a non-requestable node is a no-op), so this retries once rather
  /// than leaving the keyboard nowhere.
  void _requestFocusOnceBuilt(String key, FocusNode target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || config().selectedControlKey != key) return;
      if (target.canRequestFocus) {
        target.requestFocus();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && config().selectedControlKey == key) target.requestFocus();
      });
    });
  }

  /// Moves from field [currentIndex] of [key]'s own field list (`-1` when
  /// it can't be determined) to the next (`forward`) or previous one, or —
  /// once [key]'s own fields are exhausted — across to the neighbouring
  /// pill via [crossToPill], wrapping at both ends of the strip. Tab and
  /// Shift-Tab's own move — a control with several fields (Time's Date,
  /// Radio's Band and Mode) is walked in full before the strip moves on.
  /// Cursor keys use [_crossToNextControl] instead: they treat a whole
  /// control as one stop, same as they treat one main field.
  void _stepSecondaryField(String key, int currentIndex, {required bool forward}) {
    final fields = config().expandedFieldOrderFor(key);
    final next = forward ? currentIndex + 1 : currentIndex - 1;
    if (next >= 0 && next < fields.length) {
      fields[next].$1.requestFocus();
      return;
    }
    final order = pillOrder;
    final pillIndex = order.indexOf(key);
    if (pillIndex < 0 || order.isEmpty) return;
    crossToPill(order[(pillIndex + (forward ? 1 : -1)) % order.length], fromStart: forward);
  }

  /// Crosses straight to the next (`forward`) or previous pill, wrapping at
  /// both ends of the strip, and lands on ITS `expandedFocusFor` target —
  /// the one field a tap or arriving via Up focuses (Radio's Frequency) —
  /// rather than a first-or-last pick from `expandedFieldOrderFor`. Unlike
  /// [_stepSecondaryField] (Tab's own move), this never stops at a sibling
  /// field within [key]'s own control first, and unlike [crossToPill] it
  /// doesn't care which direction it arrived from either: Left/Right treat
  /// the whole neighbouring control as one stop with one entry point, the
  /// way they treat one main field, rather than a first-field-forward /
  /// last-field-backward pair that would put Left on Mode and Right on Band.
  void _crossToNextControl(String key, {required bool forward}) {
    final order = pillOrder;
    final pillIndex = order.indexOf(key);
    if (pillIndex < 0 || order.isEmpty) return;
    focusPillAndOpen(order[(pillIndex + (forward ? 1 : -1)) % order.length]);
  }

  KeyEventResult onPillKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Ctrl/Meta/Alt are always someone else's (platform gestures). Shift is
    // checked per key below instead of folded in here, because Tab needs it
    // for its own reversal — the same split [onExpandedKeyEvent] and
    // [onPrimaryFieldKeyEvent] make.
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    // Tab/Shift-Tab walk the same strip Left/Right do, chip to chip, opening
    // whatever they land on — but not quite the same landing: Tab picks a
    // first-or-last FIELD ([crossToPill]'s `fromStart`), Left/Right always
    // land on the control's one canonical field ([_crossToNextControl]).
    // Checked first since nothing past this point answers Shift.
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final order = pillOrder;
      final index = order.indexOf(key);
      if (index < 0 || order.length < 2) return KeyEventResult.ignored;
      final forward = !shift;
      crossToPill(order[(index + (forward ? 1 : -1)) % order.length], fromStart: forward);
      return KeyEventResult.handled;
    }
    if (shift) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        final order = pillOrder;
        final index = order.indexOf(key);
        // Wraps at both ends: the strip is a short ring, and running off it
        // into the fields would make Left/Right two different gestures
        // depending on where you happened to be standing.
        //
        // With nowhere to go (one pill, or a key that has just left the
        // strip) the keystroke is passed on rather than swallowed — a
        // handler that silently eats keys it does nothing with is how a
        // strip ends up blocking a shortcut nobody remembers binding.
        if (index < 0 || order.length < 2) return KeyEventResult.ignored;
        // Opens the pill it steps to, same as Tab — a chip is never a
        // resting stop of its own now, it's just what a fieldless control
        // (More, Spotting without a comment) leaves the keyboard on. Goes
        // through _crossToNextControl, not crossToPill directly, so the
        // landing field matches [onExpandedKeyEvent]'s cursor-key move.
        _crossToNextControl(key, forward: event.logicalKey == LogicalKeyboardKey.arrowRight);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        // Off the top of the panel, into the QSO list — when the host has
        // one. Without a host to take it, the pills are simply the top rung.
        config().navigateToQsoList?.call();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        // Closes whatever this pill has open (a fieldless control — one with
        // a field parked the keyboard inside it instead, on
        // [onExpandedKeyEvent]'s turf) on the way back to the main field,
        // same as Escape below.
        closeControl();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // A pill's control opens the moment the keyboard lands on it, so by
        // the time Enter is pressed here it's normally already open — Enter
        // then closes it, same as it does from inside the field. `more`
        // never auto-opens (see [focusPillAndOpen]/[crossToPill]), so this
        // still opens it fresh, same as a tap.
        selectControl(config().selectedControlKey == key ? null : key);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Same "out of here entirely" meaning Escape has inside an open
        // control, from one rung further out. Handled here rather than left
        // to the panel's Escape because that one would read a merely-parked
        // keyboard as a cue to wipe the form the operator hasn't touched.
        closeControl();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- An open control ----

  /// Down or Enter inside an open secondary control's field closes it and
  /// puts the keyboard straight back on the main field the operator was in
  /// — the control opened itself on arrival ([focusPillAndOpen]), so
  /// there's no pill stop to return to on the way out either.
  ///
  /// Up closes it too, but keeps going one rung further, the way Up already
  /// does from a bare pill — straight on to the QSO list rather than
  /// stopping at the main fields.
  ///
  /// Escape does the Down/Enter thing too, via the panel-wide shortcut
  /// rather than here — it needs to fire even when nothing in the control
  /// has focus to bubble an event up from.
  ///
  /// Tab/Shift-Tab move within this control's own fields, then across to
  /// the next/previous pill once they're exhausted
  /// ([_stepSecondaryField]) — a control with several fields (Time's Date,
  /// Radio's Band and Mode) is walked in full before the strip moves on. An
  /// edge-of-value cursor key skips straight to the next/previous pill
  /// instead ([_crossToNextControl]) — Left/Right treat a whole control as
  /// one stop, the way they treat one main field.
  ///
  /// A dropdown's own arrow handling (the Band/Mode fields, or an open
  /// suggestion menu) already claims and consumes Up/Down before it gets
  /// here, so this only ever sees the ones meant for us.
  ///
  /// Enter deliberately does NOT log the QSO from ANY expanded control's
  /// fields — without this handler it would, via the Radio control's own
  /// `onSubmitted` or, for the activity reference controls and the spot
  /// comment (which declare none), the panel's root Enter shortcut this
  /// handler intercepts below. APP-19 asks for close-first, and Enter logs
  /// again one rung down, from any main field. A control that acts on Enter
  /// itself (Spotting's Send) does so on its own field's node, which the
  /// framework consults before this ancestor.
  KeyEventResult onExpandedKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final shift = keyboard.isShiftPressed;
    // Ctrl/Meta/Alt are always someone else's (platform gestures) — Cmd+Down
    // is "caret to the end of the text" on macOS, for instance. Shift is
    // checked per key below instead, since Tab needs it for its own
    // reversal while the others treat it as "text selection, leave it
    // alone" (same split [onPillKeyEvent] and [onPrimaryFieldKeyEvent]
    // make).
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    if (logicalKey == LogicalKeyboardKey.tab) {
      final fields = config().expandedFieldOrderFor(key);
      final currentIndex = fields.indexWhere((f) => f.$1.hasFocus);
      _stepSecondaryField(key, currentIndex, forward: !shift);
      return KeyEventResult.handled;
    }

    if (logicalKey == LogicalKeyboardKey.arrowLeft || logicalKey == LogicalKeyboardKey.arrowRight) {
      // Shift-arrow is selecting text, and a non-collapsed selection means
      // the arrow collapses it rather than leaving the field — only a bare
      // caret sitting against an edge is asking to travel. Same rule the
      // main fields' own Left/Right apply.
      if (shift) return KeyEventResult.ignored;
      final fields = config().expandedFieldOrderFor(key);
      final currentIndex = fields.indexWhere((f) => f.$1.hasFocus);
      if (currentIndex < 0) return KeyEventResult.ignored;
      final selection = fields[currentIndex].$2.selection;
      if (!selection.isCollapsed || selection.baseOffset < 0) return KeyEventResult.ignored;
      final forward = logicalKey == LogicalKeyboardKey.arrowRight;
      final atEdge = forward ? selection.baseOffset >= fields[currentIndex].$2.text.length : selection.baseOffset == 0;
      if (!atEdge) return KeyEventResult.ignored;
      _crossToNextControl(key, forward: forward);
      return KeyEventResult.handled;
    }

    if (shift) return KeyEventResult.ignored;
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      _closeExpandedControlToQsoList(key);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown || logicalKey == LogicalKeyboardKey.enter || logicalKey == LogicalKeyboardKey.numpadEnter) {
      closeExpandedControl(key);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Closes [key]'s control and returns the keyboard to the main field the
  /// operator was in before, but only if that control is still the one
  /// open — idempotent, because Enter can arrive twice for one keypress:
  /// once as a raw key event here, and again through a field's
  /// `onSubmitted` once the platform turns it into a text-input action (see
  /// the Frequency field's own `onSubmitted`, which calls this directly for
  /// that second route).
  void closeExpandedControl(String key) {
    if (config().selectedControlKey != key) return;
    closeControl();
  }

  /// Closes [key]'s control and hands the keyboard on to the QSO list —
  /// Up's own close, one rung further out than Down/Enter/Escape's: leaving
  /// a control by Up keeps walking outward past the main fields, the same
  /// direction Up already takes from a bare pill, rather than stopping at
  /// them.
  void _closeExpandedControlToQsoList(String key) {
    if (config().selectedControlKey != key) return;
    showControl(null);
    // Nothing navigable (an empty operation, or one holding only event
    // markers) leaves the callback with nowhere to put the keyboard — this
    // control just collapsed, so without a fallback focus would be left on
    // no field at all rather than merely stuck where it started.
    if (config().navigateToQsoList?.call() != true) focusLastPrimaryField();
  }

  /// Adds the panel's keyboard policy to a control spec: a focus node for its
  /// pill, and a non-focusable ancestor over its expanded content that watches
  /// for the keys which close it again. Applied once, over the assembled list,
  /// so a newly added kind of control can't arrive without it.
  ///
  /// Through `copyWith` rather than a fresh [SecondaryControlSpec]:
  /// re-listing the fields here drops any the spec grows later, and a chip
  /// rendering the default is not a failure anything reports.
  SecondaryControlSpec withKeyboardNavigation(SecondaryControlSpec spec, {bool enabled = true}) => spec.copyWith(
    focusNode: pillFocusFor(spec.key),
    enabled: enabled,
    expandedBuilder: (context) => Focus(
      // Not a stop on the way anywhere: it exists only to see key events
      // on their way up from whatever inside the control has focus.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) => onExpandedKeyEvent(spec.key, event),
      child: spec.expandedBuilder(context),
    ),
  );

  void dispose() {
    _disposed = true;
    for (final node in _pillFocus.values) {
      node.dispose();
    }
  }
}
