// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The buttons laid over a map's corners, shared by the Map tab and the Maps
// view so the two maps' controls look and behave alike.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'map_zoom_controller.dart';

/// One of the round buttons over a map's corner.
class MapRoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;

  /// Null draws the button disabled.
  final VoidCallback? onPressed;

  const MapRoundButton({super.key, required this.icon, required this.semanticLabel, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    elevation: 2,
    child: IconButton(
      icon: Icon(icon, semanticLabel: semanticLabel),
      onPressed: onPressed,
    ),
  );
}

/// The +/- zoom pill — a mouse/trackpad has no pinch gesture, and
/// scroll-to-zoom isn't discoverable without one. One pill rather than two
/// separate cards, with a hairline between the two actions — clipped so
/// each IconButton's own hover/ripple stays inside the pill instead of
/// squaring off its corners.
class MapZoomButtons extends StatelessWidget {
  final MapZoomController controller;

  const MapZoomButtons({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(MdiIcons.plus, semanticLabel: context.t.map.zoomIn),
            onPressed: controller.zoomIn,
          ),
          Divider(height: 1, thickness: 1, color: theme.dividerColor),
          IconButton(
            icon: Icon(MdiIcons.minus, semanticLabel: context.t.map.zoomOut),
            onPressed: controller.zoomOut,
          ),
        ],
      ),
    );
  }
}
