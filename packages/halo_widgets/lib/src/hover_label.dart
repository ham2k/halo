// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'spacing.dart';

/// [label] in a small popup above [child] while the mouse is over it.
///
/// The one sanctioned exception to "no tooltips"
/// (docs/design/user-interface.md § Buttons and hover labels): for a row of
/// status icons with nothing else to name them — the Spotting control's
/// source icons. Not Flutter's `Tooltip`, which the app root hides
/// everywhere. Mouse only: touch has no hover, so [label] is also [child]'s
/// accessible name, which is what reaches a screen reader.
class HoverLabel extends StatefulWidget {
  const HoverLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  State<HoverLabel> createState() => _HoverLabelState();
}

class _HoverLabelState extends State<HoverLabel> {
  final _popup = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => _popup.show(),
      onExit: (_) => _popup.hide(),
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
          child: Semantics(label: widget.label, excludeSemantics: true, child: widget.child),
        ),
      ),
    );
  }
}
