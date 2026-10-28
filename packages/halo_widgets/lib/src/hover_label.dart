// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';

import 'spacing.dart';

/// [label] in a small popup above [child] while the mouse is over it.
///
/// The sanctioned exception to "no tooltips" (docs/design/user-interface.md
/// § Buttons and hover labels): a row of status icons with nothing else to
/// name them — the Spotting control's source icons — and an icon-only button
/// in a toolbar or a header. Not Flutter's `Tooltip`, which the app root
/// hides everywhere. Mouse only: touch has no hover.
///
/// It waits for the pointer to come to rest on [child] — [restDelay] without
/// moving more than [twitch] — so a pointer passing over a row of icons on
/// its way somewhere else does not flash a label at each one. Once up, it
/// stays until the pointer leaves.
class HoverLabel extends StatefulWidget {
  static const restDelay = Duration(milliseconds: 500);

  /// How far, in logical pixels, a resting pointer may drift without starting
  /// the wait over: a hand on a mouse is never perfectly still.
  static const twitch = 4.0;

  const HoverLabel({super.key, required this.label, required this.child, this.namesChild = true});

  final String label;
  final Widget child;

  /// Whether [label] becomes [child]'s accessible name, replacing whatever
  /// semantics it had — what touch and a screen reader get for a status icon,
  /// which has no other. False for a button, which keeps its own: its tap
  /// among them, and the name its icon's `semanticLabel` gives it.
  final bool namesChild;

  @override
  State<HoverLabel> createState() => _HoverLabelState();
}

class _HoverLabelState extends State<HoverLabel> {
  final _popup = OverlayPortalController();
  final _link = LayerLink();

  /// The wait for the pointer to rest, and where it started.
  Timer? _rest;
  Offset? _restingAt;

  void _moved(Offset position) {
    if (_popup.isShowing) return;
    if (_restingAt case final at? when (position - at).distance <= HoverLabel.twitch) return;
    _restingAt = position;
    _rest?.cancel();
    _rest = Timer(HoverLabel.restDelay, _popup.show);
  }

  void _left() {
    _rest?.cancel();
    _rest = _restingAt = null;
    _popup.hide();
  }

  @override
  void dispose() {
    _rest?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (event) => _moved(event.position),
      onHover: (event) => _moved(event.position),
      onExit: (_) => _left(),
      child: OverlayPortal(
        controller: _popup,
        // Positioned with no size: loose constraints, so the follower is the
        // popup's own size and its bottom-centre anchor lands on the popup.
        overlayChildBuilder: (context) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: const Offset(0, -Space.xs),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(Space.xs)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xxs),
                  child: Text(widget.label, style: TextStyle(color: scheme.onInverseSurface, fontSize: 12)),
                ),
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: widget.namesChild ? Semantics(label: widget.label, excludeSemantics: true, child: widget.child) : widget.child,
        ),
      ),
    );
  }
}
