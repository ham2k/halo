// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The final "for X at Y" assembly step for an operation's title —
// `OperationTitleFragments` (halo_core) already
// grouped and joined extensions' ref-derived fragments; this just localizes
// the "for"/"at" prepositions (BuildContext lives here, not in halo_core)
// and leads with the user's own title when they set one.

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';

/// Assembles [fragments] into the localized "for X at Y" sentence — the
/// generated (non-user) part of an operation's title. `ActivitiesView.
/// saveAndClose` calls this with the global `t` to persist the result into
/// `data['title']`; [generatedTitleFor] below calls it with a BuildContext's
/// `t` for the live, not-yet-saved preview.
String buildGeneratedTitle(Translations t, OperationTitleFragments fragments) {
  if (fragments.isEmpty) return '';
  final op = t.operation;
  return [
    if (fragments.title.isNotEmpty) fragments.title,
    if (fragments.forText.isNotEmpty) op.titleFor(value: fragments.forText),
    if (fragments.atText.isNotEmpty) op.titleAt(value: fragments.atText),
  ].join(' ');
}

/// What a segment row says about its stretch of the log — polo's
/// `describeOperation`: one phrase per ref, the most specific fragment it
/// offered ("at US-1000", "for ARRL 10G Sep", a plain title), then "at
/// `<grid>`", joined with " • ". Per ref rather than merged by kind, so a
/// two-ref segment keeps each ref's own phrase.
String segmentDescriptionFor(Translations t, Iterable<OperationTitleSuggestion> suggestions, String? grid) {
  final op = t.operation;
  String? phraseOf(OperationTitleSuggestion s) {
    if (s.atText case final at? when at.isNotEmpty) return op.titleAt(value: at);
    if (s.forText case final f? when f.isNotEmpty) return op.titleFor(value: f);
    if (s.title case final title? when title.isNotEmpty) return title;
    if (s.subtitle case final subtitle? when subtitle.isNotEmpty) return subtitle;
    return null;
  }

  return [
    for (final s in suggestions)
      ?phraseOf(s),
    if (grid != null && grid.isNotEmpty) op.titleAt(value: grid),
  ].join(' • ');
}

/// The ref-derived part of [operation]'s title: the live preview from this
/// device's cached [Operation.titleFragments] when it has one, otherwise the
/// synced [Operation.title] persisted by an earlier save (on this or another
/// device) — a newly-synced operation has no local cache at all, and an
/// extension hook that's still booting, times out, or throws leaves this
/// device's own cache just as empty; either way this is the only source of a
/// generated title until this device computes its own successfully.
///
/// Gated on [operation] actually having refs, not on whether a local cache
/// exists: a ref-less operation can never have a legitimate ref-derived
/// title, but PoLo writes its own placeholder text straight into the synced
/// `title` field for one — a localized "General Operation"
/// (`setOperationData.js`) or the literal, unlocalized "New Operation"
/// (`operationsDB.js`) — which must not render here as though HaLo had
/// generated it.
///
/// Checks the cached fragments themselves, not [buildGeneratedTitle]'s
/// rendered string: a suggestion that's only a [OperationTitleFragments.
/// subtitle] (no title/for/at) is a live, legitimate cache entry, but
/// renders as `''` — treating that as "nothing cached" would fall through
/// to a possibly-stale synced title instead of correctly showing none.
String generatedTitleFor(BuildContext context, Operation operation) {
  final fragments = operation.titleFragments;
  if (!fragments.isEmpty) return buildGeneratedTitle(context.t, fragments);
  return operation.refs.isEmpty ? '' : operation.title;
}

/// The operation's display title: the user's own title (set via the
/// operation dialog), if any, followed by the ref-derived suggestion ("for X
/// at Y") — or a localized "General Operation" placeholder when neither
/// contributed anything. A Test Operation (station call ending in `/T` or
/// `/TEST`) always gets "Testing" appended, placeholder included, so it
/// can't be mistaken for a real activation in a list or a title bar.
String displayTitleFor(BuildContext context, Operation operation) {
  final generated = generatedTitleFor(context, operation);
  final base = operation.userTitle.isNotEmpty
      ? (generated.isEmpty ? operation.userTitle : '${operation.userTitle} $generated')
      : (generated.isEmpty ? context.t.operation.generalOperation : generated);
  return operation.isTestOperation ? '$base ${context.t.operation.testOperationSuffix}' : base;
}

/// The callsign line the Operation View's header leads with: the station
/// call, plus who is at the key when that is a different callsign, plus this
/// device's multi-station position when it has one — `K2SUL (op KI2D /OP2)`.
///
/// Deliberately NOT what a list uses: the station call alone is what tells
/// one operation from another at a glance, so the home screen keeps rendering
/// [Operation.stationCall] straight. This is for the one place with the room
/// to say more.
String headerCallsignFor(Operation operation) {
  final stationCall = operation.stationCall;
  final operatorCall = operatorCallFor(operation);
  final position = (asQsonString(operation.localData['multiIdentifier']) ?? '').trim();
  final parts = [
    // A club station logged by its own licensee names nobody new — app-polo
    // draws the same line (`operationTemplates.js`).
    if (operatorCall.isNotEmpty && operatorCall.toUpperCase() != stationCall.trim().toUpperCase())
      'op $operatorCall',
    // The suffix goes on the STATION call over the air (see
    // `spotCallForSelfSpot`); here it rides with the operator, because what
    // it names is which operator this device belongs to.
    if (position.isNotEmpty) '/OP$position',
  ];
  return parts.isEmpty ? stationCall : '$stationCall (${parts.join(' ')})';
}

/// The operation's display subtitle: always the ref-derived detail (there's
/// no user override for this, unlike the title) — empty when nothing
/// contributed one.
String displaySubtitleFor(Operation operation) => operation.titleFragments.subtitle;
