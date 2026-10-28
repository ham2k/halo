// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One category of the Settings panel — the collapsible band a group's rows
// sit under — and the identity of the rows in it, which the panel remounts
// its list on. Shared by the screen and an extension's own panel, so its own
// file: a panel need not import the screen that builds it.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'settings_pane_width.dart';
import '../settings_view.dart';

/// WHICH rows a category currently holds, hashed — the same identity
/// `listContentsKey` is built from, and for the same reason: the panel
/// remounts its scroll view when rows move, and a group that grows or drops
/// elements moves every row below it (docs/quirks.md).
///
/// An element's own key where it has one, its type otherwise: headers and
/// dividers carry no key, and two of them in a row are interchangeable for
/// this purpose — what matters is that one appeared or went away.
int settingsRowIdentity(List<Map<String, dynamic>> elements) => Object.hashAll([for (final el in elements) el['key'] ?? el['type']]);

/// One CATEGORY of the Settings panel — a declared group, an extension's
/// whole panel, or Common Preferences — as a collapsible band of rows.
///
/// A category heads itself with the filled band the app's sections have
/// always used, precisely so it does not read as one of the headings a
/// panel's own `style: 'section'` headers put INSIDE it (docs/extensions/
/// forms.md) — those are the accent title over a hairline, on no ground.
/// One is the shelf, the other names a group of rows on it.
///
/// With no [onToggle] the rows are headed by a plain section heading and
/// always show — how a group's contribution to Common Preferences appears,
/// where rows drawn from a dozen groups need saying which group each came
/// from, and the collapsible category above owns them all.
///
/// [hidden] takes the whole category out of view without unmounting it —
/// what the search does to one that matches nothing. Unmounting it
/// disposes every FocusNode and TextEditingController its FormRenderer
/// owns, and on web that teardown takes the browser's text-input element
/// with it: focus falls back to the route's scope and the next keystrokes
/// are swallowed, so the query loses characters as it is typed. macOS has
/// no DOM and shows no symptom.
///
/// `maintainState` is what keeps the State (and its nodes) alive; the
/// ExcludeFocus is what keeps a hidden category's fields out of the Tab
/// order, which Visibility alone does not do. A merely collapsed one is the
/// section's own business ([CollapsibleSection]).
Widget settingsCategory(
  BuildContext context, {
  required String title,
  required bool expanded,
  required VoidCallback? onToggle,
  required Widget child,
  bool hidden = false,
}) {
  final rows = ExcludeFocus(excluding: hidden, child: child);
  return Visibility(
    visible: !hidden,
    maintainState: true,
    child: onToggle == null
        ? Column(mainAxisSize: MainAxisSize.min, children: [SectionHeader(title), rows])
        : CollapsibleSection.band(
            title: Text(title, style: SectionHeader.titleStyle(context)),
            expanded: expanded,
            onToggle: onToggle,
            headerColor: haloCategoryBandColor(context),
            onHeaderColor: _accent(context),
            headerInset: _headerInset(context),
            child: Padding(
              padding: const EdgeInsets.only(bottom: _categoryEndGap),
              child: rows,
            ),
          ),
  );
}

/// [settingsCategory] as a SLIVER, for the panel that scrolls its categories
/// itself: the band pins, holding the top of the pane while the category's
/// own rows scroll under it, and the section bands inside [sliver] pin under
/// it in turn.
///
/// Every wrapper here has a sliver twin of the box one — `SliverVisibility`
/// for `Visibility`, [CollapsingSliver] for the cross-fade — and
/// `ExcludeFocus` needs none, being layout-transparent either way.
Widget settingsCategorySliver(
  BuildContext context, {
  required String title,
  required bool expanded,
  required VoidCallback? onToggle,
  required Widget sliver,
  bool hidden = false,
}) {
  final rows = ExcludeFocus(excluding: hidden, child: sliver);
  return SliverVisibility(
    visible: !hidden,
    maintainState: true,
    sliver: onToggle == null
        ? SliverMainAxisGroup(slivers: [SectionHeader.pinned(context, title), rows])
        : SliverCollapsibleSection(
            title: Text(title, style: SectionHeader.titleStyle(context)),
            expanded: expanded,
            onToggle: onToggle,
            headerColor: haloCategoryBandColor(context),
            onHeaderColor: _accent(context),
            headerInset: _headerInset(context),
            sliver: SliverPadding(
              padding: const EdgeInsets.only(bottom: _categoryEndGap),
              sliver: rows,
            ),
          ),
  );
}

/// Below a category's last row, about a fifth of a settings row: without
/// it the next category's band butts against that row and reads as its
/// footer. Inside the fold, so a shut category keeps the bands together.
/// Not under a plain-headed group, whose rows run straight into the next
/// group's heading inside one category.
const _categoryEndGap = Space.xl;

/// What the chevron and the title are drawn in — the section band's own
/// accent, so the shelf and the headings on it agree.
Color _accent(BuildContext context) => SectionHeader.titleStyle(context).color ?? Theme.of(context).colorScheme.onSurface;

/// The centring only: the band runs to the pane's edges like every row does,
/// while the chevron and title follow the pane's centring so they land
/// beside the rows below rather than out in the gutter of a wide window.
EdgeInsetsGeometry _headerInset(BuildContext context) => EdgeInsets.symmetric(horizontal: settingsRowCentering(settingsPaneWidth(context)));
