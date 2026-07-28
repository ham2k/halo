// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The final "for X at Y" assembly step for an operation's title
// (ham2k/app-halo-dist#174) — `OperationTitleFragments` (halo_core) already
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

/// The ref-derived part of [operation]'s title, live-computed from its
/// currently cached [Operation.titleFragments] — used for preview ahead of
/// whatever's persisted in `data['title']` (e.g. mid-edit, before the next
/// save).
String generatedTitleFor(BuildContext context, Operation operation) =>
    buildGeneratedTitle(context.t, operation.titleFragments);

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
