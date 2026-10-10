// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'activities_results_map.dart';

/// Whether an operation may carry more than one ref of [type] at a time, as
/// the extension declared it: on the [suggestion] being added, or — for a
/// ref typed in by hand, which has no suggestion — on the type's [control]
/// descriptor. Defaults to FALSE: one reference of a kind is the safe
/// assumption, and a type that genuinely stacks (POTA n-fers) says so
/// explicitly. Anything else gets the replace-on-add behavior of
/// [refsKeptWhenAdding].
bool allowsMultipleRefsOfType(String? type, {Map<String, dynamic>? suggestion, Map<String, dynamic>? control}) {
  final fromSuggestion = suggestion?['allowsMultiple'];
  if (fromSuggestion is bool) return fromSuggestion;
  final fromControl = control?['allowsMultiple'];
  if (fromControl is bool) return fromControl;
  return false;
}

/// Whether a ref of [type] is form-configured (a contest). Their `label`
/// carries the event name with its variation baked in ("CQ WW CW",
/// "ARRL Field Day 2027"), so lists lead with it — a plain reference
/// activity leads with its code-like `shortLabel` ("POTA US-1234") instead.
///
/// This is the one place an *editor* property decides display. Every other
/// surface reads `shortLabel`, which names the same event abbreviated
/// ("FD 2027"); see the display-key table in docs/design/contests.md §5.4,
/// which extension authors are held to.
bool refTypeIsForm(Map<String, dynamic>? control) => (control?['input'] as Map?)?['kind'] == 'form';

/// Where tapping a Current Activities row should point the results map, or
/// null for a row that must stay inert.
///
/// Null with the list showing: there is no camera to move, and a row that
/// silently did nothing in one mode and something in the other would read as
/// broken in whichever the operator met first. Null too for a reference with
/// no resolvable location — a program whose codes carry no coordinate has
/// nowhere to point at, and no marker on the map either.
///
/// The editor takes precedence over this at the call site (see
/// `_moveMapToRef`'s caller): a form-configured reference has nothing else
/// that opens its form.
GridLocation? refRowMapTarget(Map<String, dynamic> ref, {required bool mapShowing}) {
  if (!mapShowing) return null;
  return locationForSuggestion(ref);
}

/// Whether a ref of [type] has anything to edit once it's on the operation.
/// Defaults to FALSE — a plain reference activity (POTA, SOTA) carries only
/// the code its own search already resolved, so retyping it by hand invites a
/// typo no lookup would catch. A type whose refs carry more than that says
/// `editable: true` on its control descriptor.
bool refTypeIsEditable(Map<String, dynamic>? control) {
  // A form-configured activity is editable by construction: the form IS the
  // reference, so there is always something to open. Inferring it here rather
  // than making every contest also set `editable: true` — the flag exists to
  // mark the unusual reference type that carries more than a looked-up code,
  // and a form control is that by definition.
  if (refTypeIsForm(control)) return true;
  return control?['editable'] == true;
}

/// What an activity row leads with, for a ref or a suggestion alike — the
/// two must agree, or the same reference reads differently before and after
/// it is added. See [refTypeIsForm] for which field wins.
String activityRowTitle(Map<String, dynamic>? control, Map<String, dynamic> entry) {
  final leading = refTypeIsForm(control) ? entry['label'] ?? entry['shortLabel'] : entry['shortLabel'];
  return (leading ?? entry['ref'] ?? '?') as String;
}

/// An activity row's second line: what the reference IS, beyond its code —
/// a park's name and location, a contest's exchange. Null when the entry
/// carries neither, so the row stays a single line rather than an empty one.
String? activityRowDetail(Map<String, dynamic> entry) {
  final detail = [entry['name'], entry['location']].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
  return detail.isEmpty ? null : detail;
}

/// Whether an already-added suggestion should be hidden rather than shown
/// (faded) — the one rule both the results list (`resultRows`, below) and the
/// results map (`activitySuggestionMarkers`, activities_results_map.dart)
/// apply to the same `ActivitySearchState.suggestions`/`refs` inputs, kept in
/// one place so they can't quietly disagree. A nearby suggestion already on
/// the operation is just noise; a SEARCH hit has to stay — dropping what the
/// operator searched for reads as "no such reference".
bool suggestionHidesAsAlreadyAdded({required bool alreadyAdded, required bool suggestionsAreSearchResults}) => alreadyAdded && !suggestionsAreSearchResults;

/// The refs to keep when adding one of [type]: all of them when the type
/// allows multiple, and otherwise everything BUT that type — a single-ref
/// type's new reference replaces the one already there rather than piling up
/// next to it.
List<Map<String, dynamic>> refsKeptWhenAdding({required List<Map<String, dynamic>> refs, required String? type, required bool allowsMultiple}) {
  if (type == null || allowsMultiple) return refs;
  return refs.where((r) => r['type'] != type).toList();
}

/// A short marker beside an activity row's title — "already selected" on a
/// suggestion the operation carries, "retired" on a reference its program has
/// delisted.
///
/// [unavailable] paints the error role rather than the secondary one. The two
/// say different things and must not read alike: one is a reference the
/// operator already has, the other is one they cannot activate at all.
class ActivityRowChip extends StatelessWidget {
  final String label;
  final bool unavailable;

  const ActivityRowChip({super.key, required this.label, this.unavailable = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
      decoration: BoxDecoration(color: unavailable ? scheme.errorContainer : scheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: unavailable ? scheme.onErrorContainer : scheme.onSecondaryContainer)),
    );
  }
}

/// Whether an entry's program has retired this reference, so it can no longer
/// be activated. Set by the extension's `suggest` hook and persisted with the
/// ref (see the SDK's `ActivitySuggestion.disabled`).
bool activityRowIsRetired(Map<String, dynamic> entry) => entry['retired'] == true;

/// Whether an entry's code fails the pattern its program's control declares —
/// what the "Not valid" mark on a row reports.
///
/// A reference like this is kept, never refused: the pattern is HaLo's idea of
/// the program rather than the program's own, so a format that changed — or one
/// this app simply has wrong — must not cost the operator a code they were
/// given on the air. The mark is the whole of the app's opinion about it, and
/// the reference reaches the log and the exports either way.
///
/// A ref type with no control at all has no pattern to fail: that is a
/// different problem, and [isUnknownRefType] already colors the row for it. The
/// same silence covers a sheet whose controls did not load — `_controls` is
/// then empty and every reference reads as fine. Unmarked is the safe direction
/// of the two, and `_controlsUnreliable` already says on the row itself that
/// the sheet cannot vouch for what it is showing.
bool activityRowIsInvalid(List<Map<String, dynamic>> controls, Map<String, dynamic> entry) {
  // The widgets' own helper, so a row, the field that typed the code and the
  // chip that summarizes it cannot disagree about the same reference — and so a
  // regex an extension got wrong disables the mark rather than throwing into a
  // build that runs this for every row.
  final control = controlForRefType(controls, entry['type'] as String?);
  return anyRefFailsPattern([entry], (control?['input'] as Map?)?['pattern'] as String?);
}
