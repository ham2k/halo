// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The system back — Android's back gesture and button, and a keyboard's Back
// key, which many tablet keyboards put on their Escape key — for what the
// Navigator cannot answer it for: a cover painted above every route, and a
// view that wants the press before its route is popped.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app's one [SystemBack].
final systemBack = SystemBack();

/// Asks for the system back ahead of the Navigator.
///
/// A press goes first to the top [SystemBackCover], which it dismisses; then
/// to each handler, newest first, until one takes it; and only then to the
/// Navigator, which pops a route or leaves the app.
///
/// A predictive back SWIPE over a pushed page never comes here: the page's
/// own transition claims it and pops the page, and nothing ahead of it can
/// refuse. A button or key back always does, and so does a swipe at the
/// first route.
///
/// [attach] must run before the app's `WidgetsApp` registers its own
/// observer: the binding asks its observers in registration order, and the
/// Navigator's answer ends the search.
class SystemBack with WidgetsBindingObserver {
  /// Bottom to top: by layer, and within one layer in the order they came up.
  final _covers = <({VoidCallback dismiss, int layer})>[];
  final _handlers = <bool Function()>[];
  bool _attached = false;

  /// What the Navigator last said about taking a back itself
  /// ([NavigationNotification.canHandlePop]).
  bool _navigatorTakesBack = false;

  /// What the engine was last told, or null when it has been told nothing
  /// since the app last came up.
  bool? _published;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void _addCover(VoidCallback dismiss, int layer) {
    final above = _covers.indexWhere((cover) => cover.layer > layer);
    _covers.insert(above < 0 ? _covers.length : above, (dismiss: dismiss, layer: layer));
    _publish();
  }

  void _removeCover(VoidCallback dismiss) {
    final before = _covers.length;
    _covers.removeWhere((cover) => cover.dismiss == dismiss);
    if (_covers.length != before) _publish();
  }

  /// [handler] is asked before the Navigator; true takes the press. It must
  /// answer for its own route being in front, since covers aside it is asked
  /// whatever is.
  void addHandler(bool Function() handler) => _handlers.add(handler);

  void removeHandler(bool Function() handler) => _handlers.remove(handler);

  /// The `MaterialApp`'s `onNavigationNotification`, in place of
  /// `WidgetsApp`'s own, which would tell Android only what the Navigator can
  /// take and so drop a cover's claim on the next route change.
  bool onNavigationNotification(NavigationNotification notification) {
    _navigatorTakesBack = notification.canHandlePop;
    _publish();
    return true;
  }

  void _publish() {
    // As `WidgetsApp` does: nothing goes to the engine before the app is up.
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.detached) return;
    final takesBack = _navigatorTakesBack || _covers.isNotEmpty;
    if (takesBack == _published) return;
    _published = takesBack;
    SystemNavigator.setFrameworkHandlesBack(takesBack);
  }

  /// Coming up publishes what changed while the app was not up — a cover
  /// shown before the first frame — and a detach forgets what the engine
  /// was told, since the next one to attach starts from its own default.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _published = null;
    } else {
      _publish();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (_covers.isNotEmpty) {
      _covers.last.dismiss();
      return true;
    }
    for (final handler in _handlers.reversed.toList()) {
      if (handler()) return true;
    }
    return false;
  }
}

/// [child], painted above every route, which a system back dismisses by
/// calling [onBack] for as long as it is in the tree. While one is up
/// Android sends the press to the app even at its first route — without
/// that, a back over Home would leave the app with the cover still showing.
class SystemBackCover extends StatefulWidget {
  final VoidCallback onBack;

  /// Where [child] paints, higher above: of two covers up at once the back
  /// goes to the higher one, the one the operator sees; on one layer, to
  /// the newer.
  final int layer;

  final Widget child;

  const SystemBackCover({super.key, required this.onBack, required this.layer, required this.child});

  @override
  State<SystemBackCover> createState() => _SystemBackCoverState();
}

class _SystemBackCoverState extends State<SystemBackCover> {
  @override
  void initState() {
    super.initState();
    systemBack._addCover(_back, widget.layer);
  }

  @override
  void dispose() {
    systemBack._removeCover(_back);
    super.dispose();
  }

  void _back() => widget.onBack();

  @override
  Widget build(BuildContext context) => widget.child;
}
