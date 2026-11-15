// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Holding a live list still while the operator is using it: rows that move
// under a finger or a pointer get the wrong row tapped. The list's owner keeps
// showing what it had while [ListUpdateHold.held] is true, counts what it is
// holding back, and offers it through [PendingUpdatesToast].

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Whether a live list is being used right now: true from the first touch,
/// scroll or pointer movement over it until [quiet] passes without another
/// and with no finger or button still down on it — to within an eighth of
/// [quiet] more.
///
/// The owner decides what holding means — which updates wait and which (the
/// operator's own changes) go through at once — and listens for the release
/// to apply what waited.
class ListUpdateHold extends ChangeNotifier {
  ListUpdateHold({this.quiet = const Duration(seconds: 4)});

  final Duration quiet;

  bool get held => _timer != null;

  /// Ticks eight times per [quiet] while held, counting [_quietTicks] since
  /// the last interaction: one timer for the whole hold, where a timer
  /// restarted at each interaction would be dozens a second under a moving
  /// mouse. Counted rather than clocked, so a test's fake timers drive it.
  Timer? _timer;
  int _quietTicks = 0;
  static const _ticksPerQuiet = 8;

  /// The pointers down on the list. A finger resting on a row while the
  /// operator decides reports nothing, and the row must not move under it.
  final _pressed = <int>{};

  /// The operator did something to the list. Restarts the quiet period, and
  /// notifies only when this starts a hold: a pointer moving over the list
  /// reports dozens of times a second.
  void interacted() {
    _quietTicks = 0;
    if (_timer != null) return;
    _timer = Timer.periodic(quiet ~/ _ticksPerQuiet, (_) => _tick());
    notifyListeners();
  }

  /// [pointer] went down on the list: held until it lifts, and [quiet] after.
  void pressed(int pointer) {
    _pressed.add(pointer);
    interacted();
  }

  void lifted(int pointer) {
    if (_pressed.remove(pointer)) interacted();
  }

  void _tick() {
    if (_pressed.isNotEmpty) {
      _quietTicks = 0;
    } else if (++_quietTicks > _ticksPerQuiet) {
      release();
    }
  }

  /// Ends the hold now — the quiet period ran out, or the operator asked for
  /// the list as it stands.
  void release() {
    _pressed.clear();
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Reports every touch, scroll and pointer movement over [child] to [hold].
///
/// Pointer events rather than scroll notifications: the list scrolls itself
/// too (revealing the QSO being logged), and that is not the operator using
/// it. A mouse resting still is not using it either, so hovering counts only
/// while the pointer moves.
class ListUpdateHoldDetector extends StatelessWidget {
  final ListUpdateHold hold;
  final Widget child;

  const ListUpdateHoldDetector({super.key, required this.hold, required this.child});

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => hold.pressed(event.pointer),
    onPointerUp: (event) => hold.lifted(event.pointer),
    onPointerCancel: (event) => hold.lifted(event.pointer),
    onPointerMove: (_) => hold.interacted(),
    onPointerHover: (_) => hold.interacted(),
    onPointerSignal: (_) => hold.interacted(),
    onPointerPanZoomStart: (_) => hold.interacted(),
    onPointerPanZoomUpdate: (_) => hold.interacted(),
    child: child,
  );
}

/// A scroll controller for a list whose content can change above the view
/// without the view moving: [shiftBy] scrolls by exactly what changed out of
/// sight, so the rows in view stay where they are — mid-drag, mid-fling and
/// mid-animation included.
class ShiftableScrollController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) => _ShiftableScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );

  /// Moves the view by [delta], without animating or telling anyone. Called
  /// while building the frame whose layout moves the content by the same
  /// amount, so the two land together.
  void shiftBy(double delta) {
    for (final position in positions) {
      if (position is _ShiftableScrollPosition) position.shiftBy(delta);
    }
  }
}

class _ShiftableScrollPosition extends ScrollPositionWithSingleContext {
  _ShiftableScrollPosition({required super.physics, required super.context, super.initialPixels, super.keepScrollOffset, super.oldPosition, super.debugLabel});

  /// The animation [animateTo] last started, to carry along when shifted.
  ({double to, Duration duration, Curve curve})? _animation;

  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) {
    _animation = (to: to, duration: duration, curve: curve);
    return super.animateTo(to, duration: duration, curve: curve);
  }

  void shiftBy(double delta) {
    correctPixels(pixels + delta);
    // A fling, or an animation to a row, runs to absolute positions, which
    // would carry the view straight back by [delta] on its next tick. Each
    // starts again from here, after the frame, once the layout has the
    // content it runs over: the fling at the speed it had, the animation to
    // where its target is now.
    switch (activity) {
      case final BallisticScrollActivity fling:
        final velocity = fling.velocity;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (identical(activity, fling)) goBallistic(velocity);
        });
      case final DrivenScrollActivity driven:
        if (_animation case final animation?) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (identical(activity, driven)) animateTo(animation.to + delta, duration: animation.duration, curve: animation.curve);
          });
        }
    }
  }
}

/// "Refresh to see 3 updates" at the bottom of a held list, fading in while
/// there are [count] updates waiting and out when there are none. Tapping it
/// is [onApply].
///
/// Keeps its last label while fading out, so the text does not drop to
/// "0 updates" on the way.
class PendingUpdatesToast extends StatefulWidget {
  final int count;
  final String Function(int count) label;
  final VoidCallback onApply;

  const PendingUpdatesToast({super.key, required this.count, required this.label, required this.onApply});

  @override
  State<PendingUpdatesToast> createState() => _PendingUpdatesToastState();
}

class _PendingUpdatesToastState extends State<PendingUpdatesToast> {
  int _shownCount = 0;

  @override
  Widget build(BuildContext context) {
    final visible = widget.count > 0;
    if (visible) _shownCount = widget.count;
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: _shownCount == 0
            ? const SizedBox.shrink()
            : Material(
                color: theme.colorScheme.inverseSurface,
                elevation: 3,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onApply,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(MdiIcons.refresh, size: 18, color: theme.colorScheme.onInverseSurface),
                        const SizedBox(width: Space.sm),
                        Text(
                          widget.label(_shownCount),
                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
