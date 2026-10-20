// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The buttons laid over a map's corners, shared by the Map tab and the Maps
// view so the two maps' controls look and behave alike.

import 'dart:math' as math;

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

/// The compass over a turned or tilted map: its needle points north and
/// leans back as far as the map does, and a tap sets the map north-up and
/// flat again. Shown only while the map is turned or tilted — see
/// [MapZoomController.turned].
class MapCompassButton extends StatelessWidget {
  final MapZoomController controller;

  const MapCompassButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: IconButton(
        onPressed: controller.resetNorth,
        icon: Semantics(
          label: context.t.map.resetNorth,
          child: ValueListenableBuilder(
            valueListenable: controller.orientation,
            builder: (context, orientation, _) => Transform(
              alignment: Alignment.center,
              // A bearing names the direction at the top, so north lies that
              // far round the other way; a tilt foreshortens the needle the
              // way it does the map.
              transform: Matrix4.rotationX(orientation.pitch * math.pi / 180)..rotateZ(-orientation.bearing * math.pi / 180),
              child: CustomPaint(
                size: const Size.square(24),
                painter: _CompassNeedlePainter(north: theme.colorScheme.error, south: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compass needle filling its square, its [north] half up.
class _CompassNeedlePainter extends CustomPainter {
  final Color north;
  final Color south;

  const _CompassNeedlePainter({required this.north, required this.south});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final halfWidth = size.width * 0.2, length = size.height * 0.45;
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy - length)
        ..lineTo(cx + halfWidth, cy)
        ..lineTo(cx - halfWidth, cy)
        ..close(),
      Paint()..color = north,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy + length)
        ..lineTo(cx + halfWidth, cy)
        ..lineTo(cx - halfWidth, cy)
        ..close(),
      Paint()..color = south,
    );
  }

  @override
  bool shouldRepaint(_CompassNeedlePainter old) => old.north != north || old.south != south;
}
