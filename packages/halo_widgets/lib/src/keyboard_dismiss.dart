// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Tapping a focused-but-empty callsign field a second time dismisses the
// on-screen keyboard. On a phone the keyboard covers half the screen, and a
// field you focused but haven't typed into yet is the one case where there's
// nothing to lose by closing it — so the second tap reads as "never mind"
// rather than "put the caret somewhere", which is what it would mean in a
// field that already holds text.
//
// Opt-in per field, and only the fields focus comes to rest in, emptied, opt
// in: the logging panel's callsign field and the home screen's Quick Lookup
// (docs/design/logging-fields.md) — after a log, a wipe or a command — and the
// operation setup sheet's activity search, after its clear button. On iOS,
// where a touch outside a field does not unfocus it, this is the operator's
// way to put the keyboard away from there. Do not hoist it to cover every
// field: an operator on a form — account credentials, a settings dialog — who
// taps an empty field again is placing the caret, not asking for the keyboard
// to go, and losing it there reads as the app misbehaving.

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

/// A pointer that went down on the focused, empty field — a dismissal the
/// gesture still has to earn by ending as an actual tap (see
/// `_TapToDismissEmptyFieldState._onPointerUp`).
class _Candidate {
  final int pointer;
  final Offset position;
  final Duration downAt;

  const _Candidate({required this.pointer, required this.position, required this.downAt});
}

/// Wraps the text field that owns [focusNode] and [controller] so that
/// tapping it again while it is focused and still empty dismisses the
/// on-screen keyboard. A no-op everywhere else: off mobile, with the keyboard
/// already down, on a field holding text, and on gestures that aren't taps.
class TapToDismissEmptyField extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final Widget child;

  const TapToDismissEmptyField({super.key, required this.focusNode, required this.controller, required this.child});

  @override
  State<TapToDismissEmptyField> createState() => _TapToDismissEmptyFieldState();
}

class _TapToDismissEmptyFieldState extends State<TapToDismissEmptyField> {
  /// The in-flight candidate, if any. The decision has to START on the way
  /// down — by the time the finger lifts the tap may already have focused
  /// the field, which would make the FIRST tap look like a second one — but
  /// it can't be ACTED on until the way up (see [_onPointerUp]).
  _Candidate? _candidate;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.focusNode.hasFocus || widget.controller.text.isNotEmpty) return;
    if (!virtualKeyboardIsUp(context)) return;
    _candidate = _Candidate(pointer: event.pointer, position: event.position, downAt: event.timeStamp);
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
      // Re-check: between the tap and this callback the user may have started
      // typing (autocorrect/suggestion commit), which makes the field no
      // longer the "nothing to lose" case this is for.
      if (!mounted || widget.controller.text.isNotEmpty) return;
      widget.focusNode.unfocus();
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
    // recognizer (and with scrolling). Wrapping the whole TextField makes its
    // label and padding — which the field focuses from — part of the target.
    return Listener(onPointerDown: _onPointerDown, onPointerUp: _onPointerUp, onPointerCancel: _onPointerCancel, child: widget.child);
  }
}
