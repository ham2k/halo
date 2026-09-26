// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// On the web a platform view — the map, a website pane — is an HTML element
// the browser hands every pointer event over it, whatever Flutter paints
// above: the engine gives the Flutter scene `pointer-events: none` and every
// platform-view slot `auto`. A dialog, a pane or a menu drawn over a map then
// lets the map pan under the operator's drag and take the clicks meant for its
// buttons.
//
// Two answers, both an invisible element of our own that the browser finds
// first, and so hands the events to Flutter: [PlatformViewShield] under a
// surface the app draws, and [PlatformViewCover] over a platform view while a
// route sits over its own — which reaches the framework's popups, a dropdown's
// menu, that nothing of the app's can shield. Elsewhere a platform view takes
// part in Flutter's own hit testing, and both are their child alone.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'platform_view_shield_element.dart' if (dart.library.js_interop) 'platform_view_shield_element_web.dart';

/// [child], kept from handing its pointer events to a platform view beneath
/// it on the web, by an element under it that the browser finds first.
class PlatformViewShield extends StatelessWidget {
  final Widget child;

  const PlatformViewShield({super.key, required this.child});

  /// Builds the web's shield wherever the tests run.
  @visibleForTesting
  static bool debugOnWeb = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && !debugOnWeb) return child;
    return Stack(
      // Passthrough: [child] is laid out as if the shield were not there — a
      // floor on its height still reaches it, where a loose Stack would drop
      // it and centre a shorter child in the room.
      fit: StackFit.passthrough,
      children: [
        const Positioned.fill(child: _Blocker()),
        child,
      ],
    );
  }
}

/// [child], a platform view, with an element over it on the web while a route
/// — a dialog, a pane, a dropdown's menu — sits over the one it is in, and
/// until that route has finished leaving: a click during a dialog's fade-out
/// is a click on the dialog, not on the map showing through it.
class PlatformViewCover extends StatefulWidget {
  final Widget child;

  const PlatformViewCover({super.key, required this.child});

  /// How long a route takes to leave, at most: the top sheet's 600 ms, the
  /// longest of them, with room to spare. A popup over a page does not drive
  /// the page's own secondary animation, so there is no transition to follow.
  static const exitTime = Duration(milliseconds: 650);

  @override
  State<PlatformViewCover> createState() => _PlatformViewCoverState();
}

class _PlatformViewCoverState extends State<PlatformViewCover> {
  bool _covered = false;
  Timer? _leaving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route's coming and going reaches here: `ModalRoute.of` depends on it.
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    if (covered) {
      _leaving?.cancel();
      _leaving = null;
      _covered = true;
    } else if (_covered && _leaving == null) {
      _leaving = Timer(PlatformViewCover.exitTime, () {
        _leaving = null;
        if (mounted) setState(() => _covered = false);
      });
    }
  }

  @override
  void dispose() {
    _leaving?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && !PlatformViewShield.debugOnWeb) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (_covered) const Positioned.fill(child: _Blocker()),
      ],
    );
  }
}

/// The invisible element itself. Out of the focus order and the semantics
/// tree: it is plumbing, and a platform view is otherwise a stop for Tab.
class _Blocker extends StatelessWidget {
  const _Blocker();

  @override
  Widget build(BuildContext context) => ExcludeFocus(child: ExcludeSemantics(child: platformViewBlocker()));
}
