// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Home-rail state shared by the home view, the rail itself, and the route
// observers that keep it honest about what is covering it.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Lets HomeView notice when it is on top again. It is `MaterialApp.home`, so
/// its State is created once and never disposed — `initState` alone would
/// report one home visit per LAUNCH while the operation and settings screens,
/// which are pushed, report per visit. The three counts have to be comparable
/// or `screen_viewed` cannot be read as navigation at all.
final homeRouteObserver = RouteObserver<PageRoute<dynamic>>();

/// The navigation rail's state, owned by the ROOT window rather than by a view.
///
/// It lives here because the rail is a sibling of the whole window — every
/// view's header and panes AND the status footer sit to its right. Drawn
/// inside the navigator it would be shortened whenever the footer took height,
/// and its bottom-anchored Settings destination would ride up and down as
/// status items came and went. Navigation must not move because a sync
/// reported progress.
///
/// [visible] follows the route: Home and the Settings it shows in place have
/// it; an operation takes it away.
///
/// One of the destinations the rail can point at — [HomeDestination.logs]
/// only reaches the rail when the `logs` experiment is on, but the state
/// still carries it whether or not it's currently offered, same as the
/// others.
enum HomeDestination { operations, logs, settings }

class HomeRailState extends ChangeNotifier {
  int _covering = 0;
  int _coveringPages = 0;
  bool _expanded = false;
  HomeDestination _destination = HomeDestination.operations;

  /// Whether ANYTHING is on top of the home layer — a pushed view, a dialog, a
  /// modal pane.
  ///
  /// The rail is drawn either side of the routes depending on this, and
  /// nothing else about it changes: it does not hide, narrow, or animate for
  /// navigation. Over the routes it is the window fixture Home sits beside and
  /// can be pressed; under them whatever arrived simply covers it, which is
  /// what a view that owns the window — or a dialog that dims it — should do.
  /// It has to be over them the rest of the time because the overlay a route
  /// lives in takes every pointer that lands in it, and a rail permanently
  /// underneath is a rail nothing can press.
  ///
  /// A COUNT rather than a flag, and driven by the navigator rather than by
  /// one route class opting in ([HomeRailRouteObserver]). Declared by the
  /// route, this is wrong for every route that forgets to declare — a ⌘K jump
  /// to an operation left a live rail pasted over the logging screen, pressing
  /// its Settings destination drove the Home underneath, and nothing said so.
  /// A flag is wrong again the moment two of them stack, since the inner one
  /// clears it on the way out while the outer is still up.
  bool get covered => _covering > 0;

  /// Whether the home layer's own chrome — Quick Lookup — is still on screen.
  ///
  /// Not the same question as [covered]: a dialog covers the rail without
  /// taking Quick Lookup off the window, so the bottom-chrome budget must go
  /// on reserving its height. Only a full page over the top replaces it.
  bool get homeChromeShowing => _coveringPages == 0;

  bool get expanded => _expanded;
  HomeDestination get destination => _destination;

  /// Whichever of [HomeDestination.operations]/[HomeDestination.logs] was
  /// active right before Settings opened — what closing Settings (the rail
  /// entry's own toggle, or its in-pane back button) returns to, rather than
  /// both of those hardcoding [HomeDestination.operations] and silently
  /// dropping out of Logs.
  HomeDestination _lastNonSettingsDestination = HomeDestination.operations;
  HomeDestination get lastNonSettingsDestination => _lastNonSettingsDestination;

  /// Counts one route arriving over the home layer, or leaving it. [page] for
  /// a route that REPLACES what is under it rather than dimming it.
  void coveringChanged(int delta, {required bool page}) => _set(() {
    _covering = math.max(0, _covering + delta);
    if (page) _coveringPages = math.max(0, _coveringPages + delta);
  }, false);

  set expanded(bool value) => _set(() => _expanded = value, _expanded == value);
  set destination(HomeDestination value) => _set(() {
    if (_destination != HomeDestination.settings) _lastNonSettingsDestination = _destination;
    _destination = value;
  }, _destination == value);

  /// Applies a change and tells the shell, deferring when we are inside a
  /// build: a view sets these from `initState`, which runs while the shell
  /// ABOVE it is building, and notifying straight through there is
  /// markNeedsBuild-during-build — refused by the framework, so the rail never
  /// appears and ErrorPolicy keeps the reason off the screen.
  void _set(VoidCallback apply, bool unchanged) {
    if (unchanged) return;
    apply();
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }
}

final homeRail = HomeRailState();

/// Keeps [HomeRailState.covered] in sync with the navigator's route stack.
///
/// Every route above the home layer counts, whatever pushed it and whatever
/// class it is — that is the whole point of observing the navigator instead of
/// asking routes to declare themselves. The bottom route is the home layer
/// itself and is not counted: it is what everything else covers.
class HomeRailRouteObserver extends NavigatorObserver {
  /// The first route pushed is the one the app starts on. Held rather than
  /// counted so a later push of the same class is still counted.
  Route<dynamic>? _homeRoute;

  /// What is currently counted, so no route is released twice — a pop that is
  /// followed by a remove, or an exit animation that finishes after the route
  /// has already gone, must not take a second off the count and expose the
  /// rail over whatever else is up.
  final Set<Route<dynamic>> _counted = {};

  bool _isPage(Route<dynamic> route) => route is PageRoute;

  void _cover(Route<dynamic> route) {
    if (identical(route, _homeRoute)) return;
    if (_counted.add(route)) homeRail.coveringChanged(1, page: _isPage(route));
  }

  void _uncover(Route<dynamic> route) {
    if (_counted.remove(route)) homeRail.coveringChanged(-1, page: _isPage(route));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null && _homeRoute == null) {
      _homeRoute = route;
      return;
    }
    _cover(route);
  }

  /// Released when the route is GONE, not when the pop is asked for.
  ///
  /// `didPop` fires as the pop begins, with the outgoing view still filling
  /// the window for the length of its reverse transition — 400ms for the
  /// operation view. Counting it out there paints the rail over a screen that
  /// is still on its way off and, being topmost, hands it the operator's taps:
  /// a press on Settings mid-slide drives the Home layer under an operation
  /// that is still visible. So the exit animation is what releases it.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final animation = route is TransitionRoute ? route.animation : null;
    if (animation == null || animation.isDismissed) {
      _uncover(route);
      return;
    }
    void whenGone(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animation.removeStatusListener(whenGone);
      _uncover(route);
    }

    animation.addStatusListener(whenGone);
  }

  /// A removal has no transition to wait for — the route is off the stack
  /// already. This also covers a pop whose animation never reaches dismissed
  /// because the route was disposed under it.
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _uncover(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      if (identical(oldRoute, _homeRoute)) {
        _homeRoute = newRoute;
        return;
      }
      _uncover(oldRoute);
    }
    if (newRoute != null) _cover(newRoute);
  }
}

final homeRailRouteObserver = HomeRailRouteObserver();
