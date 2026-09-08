// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'section_header.dart';

/// A settings-shaped list whose [SectionHeader] bands PIN: each band holds
/// the top of the pane while its own rows scroll under it, and is pushed off
/// by the next section's.
///
/// Takes the same flat list of rows a `ListView` does, bands among them, and
/// cuts it into one sliver group per band — so a panel becomes a sectioned
/// list by changing the widget it builds and nothing else. Reading the bands
/// out of the child list is the point: a panel assembles its rows with loops
/// and conditionals, and asking every one of them to hand back a structured
/// list of sections instead would rewrite them all.
///
/// A band must be a DIRECT child. One buried inside a row-building widget is
/// a row like any other, and the rows after it join the section ABOVE — a
/// pinned band left naming content that is not its. [SectionHeader] asserts
/// against that in debug; a widget that must carry its own band cuts its own
/// sections and is passed in a [SectionedSlivers].
///
/// Rows outside any band (everything before the first one) lead the list
/// unpinned, which is what they are.
class SectionedListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  /// As tall as its contents, for a list inside a dialog or a column rather
  /// than one filling a pane.
  final bool shrinkWrap;

  final ScrollPhysics? physics;

  const SectionedListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final group = SliverMainAxisGroup(slivers: sectionSlivers(context, children));
    return CustomScrollView(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      slivers: [if (padding == null) group else SliverPadding(padding: padding!, sliver: group)],
    );
  }
}

/// [children] cut into a sliver per section: every [SectionHeader] among them
/// becomes a pinned band over the rows that follow it, up to the next one.
///
/// For a caller that already builds a sliver list of its own and wants its
/// bands to pin — [SectionedListView] is this plus the scroll view.
List<Widget> sectionSlivers(BuildContext context, List<Widget> children) {
  final slivers = <Widget>[];
  var rows = <Widget>[];
  SectionHeader? band;

  void flush() {
    if (band == null && rows.isEmpty) return;
    final list = SliverList(delegate: SliverChildListDelegate(rows));
    slivers.add(band == null
        ? list
        : SliverMainAxisGroup(slivers: [band!.asPinnedSliver(context), list]));
    rows = [];
    band = null;
  }

  for (final child in children) {
    if (child is SectionHeader) {
      flush();
      band = child;
    } else if (child is SectionedSlivers) {
      // Already cut, and it ends whatever section it follows: its own first
      // band heads its own rows.
      flush();
      slivers.add(child);
    } else {
      rows.add(child);
    }
  }
  flush();
  return slivers;
}

/// Says that these children of a [SectionedListView] are SLIVERS, not rows.
///
/// For a widget that owns a band of its own and cannot be flattened into its
/// host's child list — one whose rows come from a stream, or that holds the
/// state its rows are built from. It cuts its own sections
/// ([sectionSlivers]) and returns a sliver; this is how the list is told,
/// since a widget's build result is not something the cut can see:
///
/// ```dart
/// SectionedListView(children: [
///   const SectionHeader('This Device'),
///   ...rows,
///   SectionedSlivers(slivers: [_DeviceList(services: services)]),
/// ])
/// ```
class SectionedSlivers extends StatelessWidget {
  final List<Widget> slivers;

  const SectionedSlivers({super.key, required this.slivers});

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(slivers: slivers);
}
