// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Tapping a focused-but-empty field a second time dismisses the on-screen
// keyboard. On a phone the keyboard covers half the screen, and a field you
// focused but haven't typed into yet is the one case where there's nothing to
// lose by closing it — so the second tap reads as "never mind" rather than
// "put the caret somewhere", which is what it would mean in a field that
// already holds text.
//
// This is one interceptor near the app root rather than an `onTap` on each of
// the ~30 `TextField`s in the app: there is no shared field wrapper to hang
// the behavior off, and a per-site opt-in would be silently missing from
// every field added later.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// A bottom inset (logical px) below this isn't a real virtual keyboard.
/// iOS raises a thin shortcuts/assistant bar (~45–55px) when a HARDWARE
/// keyboard is attached — that bumps `viewInsets` too, but there's no
/// on-screen keyboard to dismiss then. Every real on-screen keyboard is far
/// taller (landscape iPhone, the shortest case, is still ~150px+), so this
/// threshold cleanly separates the two.
const double minVirtualKeyboardInset = 100.0;

/// Whether a full on-screen ("virtual") keyboard is up.
///
/// Read from the raw [FlutterView] inset rather than `MediaQuery`: inside a
/// `Scaffold` body `MediaQuery.viewInsetsOf(context).bottom` is always 0
/// because the Scaffold already consumed the keyboard inset to resize the
/// body. `viewInsets` is in physical pixels, so divide by the device pixel
/// ratio before comparing against the logical threshold.
bool virtualKeyboardIsUp(BuildContext context) {
  if (!isMobilePlatform) return false;
  final view = View.of(context);
  return view.viewInsets.bottom / view.devicePixelRatio > minVirtualKeyboardInset;
}

/// A pointer that went down on a focused, empty field — a dismissal the
/// gesture still has to earn by ending as an actual tap (see
/// `_TapToDismissEmptyFieldState._onPointerUp`).
class _Candidate {
  final int pointer;
  final FocusNode node;
  final Offset position;
  final Duration downAt;

  const _Candidate({required this.pointer, required this.node, required this.position, required this.downAt});
}

/// Wraps the app so that tapping an already-focused, still-empty text field
/// dismisses the on-screen keyboard. A no-op everywhere else: off mobile, with
/// the keyboard already down, on a field holding text, on gestures that aren't
/// taps, and on taps that land anywhere but the focused field itself.
class TapToDismissEmptyField extends StatefulWidget {
  final Widget child;

  const TapToDismissEmptyField({super.key, required this.child});

  @override
  State<TapToDismissEmptyField> createState() => _TapToDismissEmptyFieldState();
}

class _TapToDismissEmptyFieldState extends State<TapToDismissEmptyField> {
  /// The in-flight candidate, if any. The decision has to START on the way
  /// down — by the time the finger lifts the field may already have been
  /// re-focused, and an empty field's `textEditingValue` can change under an
  /// autocorrect/suggestion commit — but it can't be ACTED on until the way
  /// up (see [_onPointerUp]).
  _Candidate? _candidate;

  /// The tap target of the field owning [editableContext] — the enclosing
  /// [TextField]'s box, NOT the inner editable strip.
  ///
  /// These differ a lot: a field with a floating label and content padding
  /// (i.e. every field built with `poloFieldDecoration`) measures ~88pt tall
  /// while its editable covers only the ~24pt text line. Hit-testing against
  /// the editable would ignore taps on the label and padding — which the
  /// field itself treats as taps on the field, focusing from them — leaving
  /// most of the field silently unresponsive to this gesture.
  ///
  /// Falls back to null for a bare `EditableText` with no `TextField` around
  /// it, in which case the caller uses the editable's own box.
  static RenderBox? _fieldTapTarget(BuildContext editableContext) {
    RenderBox? target;
    editableContext.visitAncestorElements((element) {
      // TextFormField builds a TextField internally, so this covers both.
      if (element.widget is! TextField) return true;
      final object = element.renderObject;
      if (object is RenderBox) target = object;
      return false;
    });
    return target;
  }

  /// The focused node when [position] (global coordinates) lands on it and it
  /// is an empty text field, else null.
  static FocusNode? _focusedEmptyFieldAt(Offset position) {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focus == null || focusContext == null || !focus.hasFocus) return null;

    // Only text fields have a keyboard to dismiss. The focus node lives inside
    // EditableText's own subtree, so this walks up to the field's state.
    final editable = focusContext.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return null;
    if (editable.textEditingValue.text.isNotEmpty) return null;

    final box = _fieldTapTarget(editable.context) ?? focusContext.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.paintBounds.contains(box.globalToLocal(position)) ? focus : null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!virtualKeyboardIsUp(context)) return;
    final node = _focusedEmptyFieldAt(event.position);
    if (node == null) return;
    // Only overwritten once this pointer qualifies, so a second finger landing
    // elsewhere can't cancel a dismissal the first one already earned.
    _candidate = _Candidate(pointer: event.pointer, node: node, position: event.position, downAt: event.timeStamp);
  }

  void _onPointerUp(PointerUpEvent event) {
    final candidate = _candidate;
    if (candidate == null || event.pointer != candidate.pointer) return;
    _candidate = null;

    // Only an actual TAP dismisses. Without these two guards any gesture that
    // merely STARTS on the field ends up dismissing: a drag (scrolling the
    // page from the field) and a long-press (which on an empty field raises
    // the paste toolbar, and would drop the keyboard out from under it).
    if ((event.position - candidate.position).distance > kTouchSlop) return;
    if (event.timeStamp - candidate.downAt > kLongPressTimeout) return;

    // Why pointer UP and not pointer DOWN: a real tap holds the finger down
    // for 50–150ms, i.e. several frames. Unfocusing from a post-frame
    // callback scheduled at DOWN therefore lands long before the finger
    // lifts, and the tap that follows calls `requestKeyboard()` and puts the
    // keyboard right back up.
    //
    // Why still post-frame: the tap recognizer calls `requestKeyboard()`
    // during the gesture arena sweep, and that sweep runs AFTER this callback
    // — `GestureBinding` sits last in the hit-test path, behind the render
    // objects a `Listener` installs. Deferring to the end of the frame puts
    // the unfocus after the refocus rather than before it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The field can go away between the tap and this callback — a dialog
      // closing, a pane popping, a list rebuilding on a stream event. Reading
      // an unmounted context's ancestors throws ("Looking up a deactivated
      // widget's ancestor is unsafe"), and there is nothing left to dismiss.
      final nodeContext = candidate.node.context;
      if (nodeContext == null || !nodeContext.mounted) return;
      // Re-check: between the tap and this callback the user may have started
      // typing (autocorrect/suggestion commit), which makes the field no
      // longer the "nothing to lose" case this is for.
      final editable = nodeContext.findAncestorStateOfType<EditableTextState>();
      if (editable == null || editable.textEditingValue.text.isNotEmpty) return;
      candidate.node.unfocus();
    });
    // addPostFrameCallback does not itself schedule a frame; without this the
    // unfocus would sit queued until some unrelated frame happened to run.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _candidate?.pointer) _candidate = null;
  }

  @override
  Widget build(BuildContext context) {
    // Listener, not GestureDetector: this must observe taps without entering
    // the gesture arena, where it would compete with the field's own tap
    // recognizer (and with scrolling).
    return Listener(onPointerDown: _onPointerDown, onPointerUp: _onPointerUp, onPointerCancel: _onPointerCancel, child: widget.child);
  }
}
