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

/// The operation's display title: the ref-derived suggestion ("for X at Y"),
/// or a localized "General Operation" placeholder when refs suggested
/// nothing — with the user's own title (set via the operation dialog), if
/// any, prepended in front of it rather than replacing it.
String displayTitleFor(BuildContext context, Operation operation) {
  final fragments = operation.titleFragments;
  final t = context.t.operation;
  final generated = fragments.isEmpty
      ? ''
      : [
          if (fragments.title.isNotEmpty) fragments.title,
          if (fragments.forText.isNotEmpty) t.titleFor(value: fragments.forText),
          if (fragments.atText.isNotEmpty) t.titleAt(value: fragments.atText),
        ].join(' ');

  if (operation.title.isNotEmpty) {
    return generated.isEmpty ? operation.title : '${operation.title} $generated';
  }
  return generated.isEmpty ? t.generalOperation : generated;
}

/// The operation's display subtitle: always the ref-derived detail (there's
/// no user override for this, unlike the title) — empty when nothing
/// contributed one.
String displaySubtitleFor(Operation operation) => operation.titleFragments.subtitle;
