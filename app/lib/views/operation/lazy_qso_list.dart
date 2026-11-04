// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's QSO list, held back behind a spinner until the route
// that brought it in has finished arriving.

import 'dart:async';

import 'package:flutter/material.dart';

/// Below this QSO count, [QsoList]'s first build is cheap enough that
/// [LazyQsoList]'s spinner isn't worth showing at all — see its call site.
const lazyQsoListThreshold = 200;

/// Defers [child]'s first build behind a spinner until the enclosing route's
/// own push transition finishes — [QsoList]'s first inflation on a large
/// operation is expensive enough (HALO-258) to stutter if it lands on the
/// same frames as that transition. Tied to the transition's actual
/// [AnimationStatus] first, rather than a guessed duration alone: a fixed
/// timer close to the transition's own length would land the swap
/// mid-animation as often as after it. Only defers once: [child]'s
/// underlying QSO stream already updates in place above this widget
/// regardless of readiness, so later emissions rebuild [child] without
/// resetting it.
class LazyQsoList extends StatefulWidget {
  final Widget child;
  final bool largeEnough;

  const LazyQsoList({super.key, required this.child, required this.largeEnough});

  @override
  State<LazyQsoList> createState() => _LazyQsoListState();
}

/// Slack past the transition's own length before [_LazyQsoListState] gives
/// up on the status listener and forces readiness — see its settle timer.
const _settleSlack = Duration(milliseconds: 100);

class _LazyQsoListState extends State<LazyQsoList> {
  bool _ready = false;
  Animation<double>? _routeAnimation;
  Timer? _settleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeArm();
  }

  @override
  void didUpdateWidget(LazyQsoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Logging past the threshold while the panel is already open (the call
    // site keeps this the same widget type specifically to allow that — see
    // its comment) only changes `largeEnough`, which doesn't dirty
    // dependencies — without this, arming would never happen and the
    // spinner this build shows from here on would never clear.
    _maybeArm();
  }

  void _maybeArm() {
    if (_ready || _routeAnimation != null || !widget.largeEnough) return;
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null || animation.isCompleted) {
      // No enclosing route transition (or it already finished before this
      // widget mounted, e.g. reached other than by a fresh push) — nothing
      // to wait for.
      _ready = true;
      return;
    }
    _routeAnimation = animation..addStatusListener(_onRouteAnimationStatus);
    // The status listener is the fast path, but the transition's own
    // AnimationController is driven by a Ticker that a backgrounded/occluded
    // desktop window can stop delivering frames to — stranding the
    // controller mid-flight with no forward or reverse status ever firing
    // again. A wall-clock deadline, comfortably past the transition's own
    // length, is the only way off that path that doesn't depend on the
    // ticker resuming on its own. Armed a frame late (post-frame callback,
    // not here) so the deadline is measured from an actual rendered frame —
    // arming mid-build would count time this build itself hasn't spent yet.
    // ModalRoute always extends TransitionRoute, and `route` is non-null
    // here (its animation isn't) — see ModalRoute's declaration. The longer
    // of the two directions: _onRouteAnimationStatus treats a pop
    // (dismissed) as equally valid as a completed push, so the deadline
    // has to cover whichever transition is actually playing.
    final forward = route!.transitionDuration;
    final reverse = route.reverseTransitionDuration;
    final transitionDuration = (forward > reverse ? forward : reverse) + _settleSlack;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _ready) return;
      _settleTimer = Timer(transitionDuration, () {
        if (!mounted || _ready) return;
        _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
        setState(() => _ready = true);
      });
    });
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    // completed: the ordinary forward-push case this exists for. dismissed:
    // the transition unwound instead of finishing (e.g. this widget mounted
    // mid-pop, or a push got cancelled) — settling back to nothing playing
    // out is just as much "stop waiting" as finishing forward is.
    if (status != AnimationStatus.completed && status != AnimationStatus.dismissed) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _settleTimer?.cancel();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => (!widget.largeEnough || _ready) ? widget.child : const Center(child: CircularProgressIndicator());
}
