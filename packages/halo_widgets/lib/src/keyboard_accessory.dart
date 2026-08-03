// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The mobile numbers row belongs to whichever field has focus, but it has to
// be DRAWN at the very bottom of the window, under the status footer and
// directly on top of the on-screen keyboard — it reads as an extension of the
// keyboard, so nothing may come between them.
//
// A row built inside a route can't satisfy both facts: the status footer is
// one level up in `StatusBarOverlay` (one integration point for every route),
// so it would always paint BELOW the footer's spot no matter what either did.
//
// So the row is published rather than placed: the focused field describes the
// row it wants, and the overlay draws it in the one spot that is under the
// footer and above the keyboard.

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Whether the pane that would publish a row is the one actually on screen.
///
/// Focus is not enough on its own. On a phone the logging panel sits in a
/// `TabBarView` behind a keep-alive, so switching to Spots neither disposes it
/// nor takes focus off the call field — it just stops being visible. The row
/// is drawn one level up, OUTSIDE the tab view, so without this it stays
/// pinned over the spot list and types into the hidden call field.
///
/// Absent means visible, so tests and any host with a single pane need not
/// think about it.
class KeyboardAccessoryVisibility extends InheritedWidget {
  final bool visible;

  const KeyboardAccessoryVisibility({super.key, required this.visible, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KeyboardAccessoryVisibility>()?.visible ?? true;

  @override
  bool updateShouldNotify(KeyboardAccessoryVisibility oldWidget) => oldWidget.visible != visible;
}

/// What a focused field wants the numbers row to look like right now.
///
/// Deliberately data, not a widget: a published widget would close over the
/// publisher's `BuildContext` and go stale the moment that route rebuilt, and
/// the row's colours have to come from the host's *current* accent (the
/// logging panel swaps tertiary→secondary while editing an existing QSO).
@immutable
class KeyboardAccessorySpec {
  /// Fired with the tapped character: '0'–'9', or [extraKey].
  final ValueChanged<String> onKey;

  /// The contextual extra key after the digits — "/" while composing a
  /// callsign, "." in numeric fields — or null to omit it.
  final String? extraKey;

  final bool vibrate;
  final int backgroundColor;
  final int foregroundColor;

  const KeyboardAccessorySpec({
    required this.onKey,
    required this.vibrate,
    required this.backgroundColor,
    required this.foregroundColor,
    this.extraKey,
  });

  /// Value equality so a rebuild that produces an identical spec doesn't
  /// notify — the logging panel rebuilds on every QSO-stream tick, and the
  /// overlay sits above the whole app.
  @override
  bool operator ==(Object other) =>
      other is KeyboardAccessorySpec &&
      other.onKey == onKey &&
      other.extraKey == extraKey &&
      other.vibrate == vibrate &&
      other.backgroundColor == backgroundColor &&
      other.foregroundColor == foregroundColor;

  @override
  int get hashCode => Object.hash(onKey, extraKey, vibrate, backgroundColor, foregroundColor);
}

/// The channel between the focused field and the overlay that draws its row.
///
/// One instance per app, handed to both ends. Publishers must [clear] on
/// dispose and when they lose focus, or a stale row outlives the field it
/// types into — [clearIfOwner] makes that safe when two fields hand off
/// (the new one publishes before the old one's dispose runs).
class KeyboardAccessoryController extends ValueNotifier<KeyboardAccessorySpec?> {
  KeyboardAccessoryController() : super(null);

  Object? _owner;

  /// Bumped by every publish and withdrawal, so a write deferred past the end
  /// of the frame can tell whether it is still the latest word — see [_set].
  int _generation = 0;

  /// Publish [spec] on behalf of [owner] (pass `this` from a State).
  void publish(Object owner, KeyboardAccessorySpec spec) {
    _owner = owner;
    _set(spec);
  }

  /// Withdraw only if [owner] is still the publisher. A field losing focus to
  /// another field must not blank the row the new one just published.
  void clearIfOwner(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _set(null);
  }

  /// Writes the value, deferring to the end of the frame when the tree is
  /// locked.
  ///
  /// Withdrawal happens from `dispose`, which runs inside `finalizeTree` with
  /// the tree locked; `deactivate` is no better, since it runs during build.
  /// Notifying a listener there does not merely warn — `markNeedsBuild` bails
  /// out *before* marking the listener dirty, so the row would stay on screen
  /// until something unrelated rebuilt the overlay, and the framework error
  /// reaches the operator as a crash notice on the way past.
  ///
  /// A deferred write must be able to be SUPERSEDED, which is why every call
  /// takes a generation and a deferred one checks it before landing. The
  /// hand-off makes this necessary rather than tidy: the arriving field
  /// publishes from a post-frame callback it scheduled during build, while the
  /// leaving field withdraws from `dispose` in the same frame's `finalizeTree`
  /// — so the withdrawal is queued *after* the publish and would otherwise
  /// overwrite it, blanking the row of a field that is focused and on screen.
  /// (Checking ownership at fire time is not enough on its own: the withdrawal
  /// already cleared `_owner` on its way in.)
  void _set(KeyboardAccessorySpec? next) {
    final generation = ++_generation;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final locked = phase != SchedulerPhase.idle && phase != SchedulerPhase.postFrameCallbacks;
    if (!locked) {
      value = next;
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation) return; // someone else has spoken since
      value = next;
    });
    // addPostFrameCallback does not itself schedule a frame; without this the
    // write would sit queued until some unrelated frame happened to run.
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
