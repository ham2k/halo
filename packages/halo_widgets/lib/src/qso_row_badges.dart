// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The badges a QSO row wears between the name and the signal reports — the
// duplicate-serial mark, one icon per activity reference type, and the notes
// marker — with the helpers that decide what a row carries. `QsoList` draws
// them through [QsoRowBadges] and budgets their column from the same
// helpers, so the two cannot disagree about what a row shows.

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';

import 'activity_controls.dart';
import 'icon_resolver.dart';
import 'mdi_icons.g.dart';
import 'qso_edit_pane.dart' show notesChipIcon;

/// One badge's icon — the unknown-type avatar (radius 8) is the widest of
/// the shapes, so it sets the column's per-badge cost.
const double qsoRefIconWidth = 16;

/// Trailing space after each badge.
const double qsoRefIconGap = 6;

/// The marker a QSO row wears when the contact carries a note, or null when
/// it carries none — the Notes chip's own glyph, so the row and the control
/// that writes the note agree.
Widget? qsoNotesMarker(Qso qso, {Color? color}) => qso.hasNotes ? Icon(notesChipIcon, size: qsoNotesMarkerSize, color: color) : null;

/// [qsoNotesMarker]'s extent, for a caller that has to budget the width it
/// then lays out.
const double qsoNotesMarkerSize = 14;

/// The refs a QSO shows as badges, by type, with how many of each — the
/// "×N" suffix. Contest refs carry an exchange rather than a place, so they
/// get no icon: every row in a contest log would otherwise wear the same
/// badge, which says nothing while crowding the columns that do.
///
/// Shared by the per-row builder and the list-wide width budget, which have
/// to agree about what a row draws or the budget reserves the wrong space.
///
/// A code rides along with each badge, because an extension may claim a
/// reference by its code as well as its type (`alsoHandles`): without one, a
/// legacy `{type: 'qp', ref: 'NY'}` draws the unknown marker while the
/// activity row beside it names the party that handles it. Where a type has
/// several references and only some are claimed, the badge takes the first
/// claimed one's code — the icon then belongs to an extension that is
/// actually installed.
Map<String, ({int count, String? code})> qsoRefCountsByType(Qso qso, List<Map<String, dynamic>> controls) {
  final counts = <String, ({int count, String? code})>{};
  final claimedTypes = <String>{};
  for (final ref in qso.refs) {
    final type = ref['type'] as String?;
    if (type == null) continue;
    if (_isContestRef(ref, controls)) continue;
    final code = refCodeOf(ref);
    final claimed = !claimedTypes.contains(type) && controlForRef(controls, type: type, code: code) != null;
    if (claimed) claimedTypes.add(type);
    final previous = counts[type];
    counts[type] = (count: (previous?.count ?? 0) + 1, code: previous == null || claimed ? code : previous.code);
  }
  return counts;
}

/// Whether a ref is contest metadata rather than an activity reference.
///
/// Two independent signals, because either can be missing: the ref's own
/// `program` (set by a contest's `decorateRef`, so it survives the extension
/// being switched off), and the shape of the control that owns its type — a
/// contest writes its exchange through a primary field, while an activity
/// reference comes from a `refList`.
///
/// "Primary field" must mean the same set here as in the logging panel's
/// `_textControls`, i.e. `text`, `serial` AND `options`: `controlForRefType`
/// returns the FIRST control for a type, and CQ WPX declares its serial before
/// its text exchange, so dropping `serial` here makes every WPX QSO read as an
/// activity reference and wear an icon. `options` — the searchable exchange —
/// belongs here for as long as it is in `_textControls`: the core writes only
/// `{type, field}` onto the ref an exchange field fills, so a state-park QSO
/// carries nothing else to say it is a contest contact.
bool _isContestRef(Map<String, dynamic> ref, List<Map<String, dynamic>> controls) {
  if (ref['program'] == 'Contest') return true;
  final control = controlForRef(controls, type: ref['type'] as String?, code: refCodeOf(ref));
  final kind = (control?['input'] as Map?)?['kind'];
  return kind == 'text' || kind == 'serial' || kind == 'options' || kind == 'form';
}

/// A row's badges, laid out at their own width so the cluster sits flush
/// against the column after it. Every child is an icon of at most
/// [qsoRefIconWidth] followed by [qsoRefIconGap], plus a ref's "×N" — the
/// shape `QsoList`'s width budget reserves for.
class QsoRowBadges extends StatelessWidget {
  final Qso qso;

  /// [qsoRefCountsByType] for [qso] — passed in because the row has already
  /// computed it to decide whether to draw the column at all.
  final Map<String, ({int count, String? code})> refCounts;
  final List<Map<String, dynamic>> activityControls;

  /// The row's dim mono style: a badge reads at the weight of the time and
  /// RST beside it, not in a per-control accent.
  final TextStyle dimStyle;

  const QsoRowBadges({super.key, required this.qso, required this.refCounts, required this.activityControls, required this.dimStyle});

  @override
  Widget build(BuildContext context) {
    final notesMarker = qsoNotesMarker(qso, color: dimStyle.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A serial another position also sent: the number stands, and the
        // row says it is not alone.
        if (qso.serialConflict) ...[Icon(MdiIcons.alert, size: 14, color: Theme.of(context).colorScheme.error), const SizedBox(width: qsoRefIconGap)],
        for (final entry in refCounts.entries) ...[
          // An unrecognized type (its extension isn't installed/loaded right
          // now) gets a small pale-red question-mark marker instead of the
          // usual themed icon (ham2k/halo-dist#261) — via the shared
          // activityRefIcon, sized down for this compact inline usage; the
          // known-type icon stays bespoke, using the row's neutral foreground
          // rather than a per-control accent (#354).
          if (isUnknownRefType(activityControls, entry.key, code: entry.value.code))
            activityRefIcon(activityControls, entry.key, code: entry.value.code, iconSize: 10, avatarRadius: qsoRefIconWidth / 2)
          else
            Icon(resolveIconName(iconForRefType(activityControls, entry.key, code: entry.value.code)), size: 14, color: dimStyle.color),
          if (entry.value.count > 1) Text('×${entry.value.count}', style: dimStyle.copyWith(fontSize: 11)),
          const SizedBox(width: qsoRefIconGap),
        ],
        // Last, so it sits against the signal reports and the exchange
        // whatever else the row carries.
        if (notesMarker != null) ...[notesMarker, const SizedBox(width: qsoRefIconGap)],
      ],
    );
  }
}
