// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Where a drop lands: the region of a pane a pointer is over, and the
// geometry that decides split versus nest. Pure functions, no widgets.

import 'package:flutter/material.dart';

/// Which side of a target group (or of the dock itself) a drag lands on.
/// Joining a group as a TAB is not a region: it happens on the tab strip and
/// carries the position within the group, which a region can't say.
enum DockRegion { left, right, top, bottom }

/// Which split band [local] falls in, given the band [active] right now.
/// The bands are thirds and they overlap at the corners — see
/// `DockGroupDropRegions` (dock_drop_targets.dart) for why, and for the two rules this implements.
/// Returns null for the middle square, which belongs to no band.
DockRegion? dockSplitRegionAt(Offset local, Size size, {DockRegion? active}) {
  if (size.isEmpty) return null;
  final horizontal = local.dy < size.height / 3
      ? DockRegion.top
      : local.dy > size.height * 2 / 3
      ? DockRegion.bottom
      : null;
  final vertical = local.dx < size.width / 3
      ? DockRegion.left
      : local.dx > size.width * 2 / 3
      ? DockRegion.right
      : null;
  if (horizontal != null && vertical != null) {
    if (active == horizontal || active == vertical) return active;
    return horizontal;
  }
  return horizontal ?? vertical;
}

/// How much of the centre square's height is left inert, split either side of
/// its middle line.
///
/// The one place inside a pane where a drag the operator thought better of can
/// be let go. Without it every pixel of every pane acts on release, and the
/// only way to abandon a drag is to carry it out of the dock.
const dockNestInertFraction = 0.2;

/// Where in the centre square [local] falls: [DockRegion.top] for the upper
/// half, [DockRegion.bottom] for the lower, null outside the square or inside
/// its inert middle strip.
///
/// The two answers are the same DIRECTIONS the outer bands report, and mean
/// something different: nest INSIDE the showing tab rather than split the
/// group. What tells them apart is how far in the pointer is, which is why
/// they are two functions over one geometry rather than one enum with six
/// values — a caller that confused them would rearrange the wrong thing.
DockRegion? dockNestRegionAt(Offset local, Size size) {
  if (size.isEmpty) return null;
  final left = size.width / 3;
  final top = size.height / 3;
  if (local.dx < left || local.dx > size.width - left) return null;
  if (local.dy < top || local.dy > size.height - top) return null;
  final middle = size.height / 2;
  final inert = size.height / 3 * dockNestInertFraction / 2;
  if ((local.dy - middle).abs() <= inert) return null;
  return local.dy < middle ? DockRegion.top : DockRegion.bottom;
}

/// What a drop on a group's body means: a direction, and whether it splits the
/// group in its parent or nests inside the tab that is showing.
@immutable
class DockBodyDrop {
  final DockRegion region;

  /// True for the centre square's halves — see [dockNestRegionAt].
  final bool nest;

  const DockBodyDrop(this.region, {required this.nest});

  @override
  bool operator ==(Object other) => other is DockBodyDrop && other.region == region && other.nest == nest;

  @override
  int get hashCode => Object.hash(region, nest);
}
