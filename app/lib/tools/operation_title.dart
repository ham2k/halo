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

import '../i18n/strings.g.dart';

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
/// contributed anything.
String displayTitleFor(BuildContext context, Operation operation) {
  final generated = generatedTitleFor(context, operation);
  if (operation.userTitle.isNotEmpty) {
    return generated.isEmpty ? operation.userTitle : '${operation.userTitle} $generated';
  }
  return generated.isEmpty ? context.t.operation.generalOperation : generated;
}

/// The operation's display subtitle: always the ref-derived detail (there's
/// no user override for this, unlike the title) — empty when nothing
/// contributed one.
String displaySubtitleFor(Operation operation) => operation.titleFragments.subtitle;
