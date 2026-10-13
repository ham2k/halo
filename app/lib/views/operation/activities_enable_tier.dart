// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The second tier of the operation sheet's activity search: an extension the
// app has but is not running, offered in place. activity_search_state.dart
// owns the search results and activities_view_extensions.dart the sheet's
// tier state; what is here needs none of it.
//
// "Not running" is two different cases with two different remedies. A
// switched-off extension is a switch away. One the operator switched on but
// the app will not load — a release the catalog revoked, or a bundle the
// engine refused — is not: the switch is already on, so offering it again
// writes an override that is already true and nothing changes. That row says
// the extension is not running and leads to the Extensions panel, which says
// why and carries the fix.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/extensions/extension_service.dart';

/// How [input] should be matched against an extension the operator has NOT
/// switched on: [search] is the whole box, matched loosely against names,
/// descriptions and keywords; [key] is its first word, which must equal one
/// of an extension's scope words exactly — a `ref:` type it declares, or its
/// key. A lone trailing colon is dropped from both.
///
/// The first word is the part that matters here. An extension that is off
/// contributes no controls, so `ActivitySearchQuery.parse` can't recognize its
/// key and hands the whole string on as plain search text — and `sota
/// w7a/mn-001` matches no extension as a whole, leaving the operator with an
/// empty list and no hint that SOTA is a switch away.
///
/// Exactly, though, and not through the loose match: keys turn up inside
/// unrelated extensions' keywords, so `pota bear mtn` would otherwise offer to
/// enable State Parks Events above the parks the operator was looking for.
///
/// Both are empty for an empty box: "show everything" is not a match.
({String search, String key}) extensionSearchCandidates(String input) {
  final trimmed = input.trim().replaceFirst(RegExp(r':$'), '').trim();
  final firstWord = input.trim().split(RegExp(r'\s')).first;
  return (search: trimmed, key: firstWord.replaceFirst(RegExp(r':$'), '').toLowerCase());
}

/// Whether the tier offers [info] at all: a non-core extension the app
/// offers that is not running, for either reason (see the file header).
/// Experiment-gated extensions are excluded: enabling one from here couldn't
/// load it anyway (the gate still holds), leaving a dead row and a scope
/// prefix that matches nothing.
bool _offered(ExtensionService extensions, ExtensionInfo info) => !info.core && extensions.isExtensionAvailable(info) && !extensions.isExtensionEnabled(info);

/// Extensions the tier offers that match [input] — by a scope word alone
/// (a `ref:` type they declare, or their key: [activityScopeWordsOf]) when
/// [keyOnly], else by the loose search as well.
List<ExtensionInfo> notRunningExtensionsMatching(ExtensionService extensions, String input, {bool keyOnly = false}) {
  final candidates = extensionSearchCandidates(input);
  if (candidates.search.isEmpty) return const [];
  final locale = LocaleSettings.currentLocale.languageCode;
  return [
    for (final info in extensions.availableExtensions)
      if (_offered(extensions, info) &&
          (activityScopeWordsOf(key: info.key, hooks: info.hooks).contains(candidates.key) ||
              (!keyOnly && info.matchesSearch(candidates.search, locale: locale))))
        info,
  ];
}

/// Extensions the tier offers that claim one of [unhandled] — the extension
/// behind a red "unknown" row in Current Activities.
List<ExtensionInfo> notRunningExtensionsForRefs(ExtensionService extensions, List<({String type, String? code})> unhandled) {
  if (unhandled.isEmpty) return const [];
  return [
    for (final info in extensionsDeclaringRefs(extensions.availableExtensions, unhandled))
      if (_offered(extensions, info)) info,
  ];
}

/// A row of the tier. "Enable X" for a switched-off extension; for one that
/// is switched on and still not running, "X is not running", leading to the
/// Extensions panel instead.
class NotRunningExtensionRow extends StatelessWidget {
  final ExtensionService extensions;
  final ExtensionInfo info;
  final Widget leading;

  /// Why an enable row is offered, which differs by what surfaced it.
  final String enableHint;

  final VoidCallback onEnable;
  final VoidCallback onOpenExtensions;

  const NotRunningExtensionRow({
    super.key,
    required this.extensions,
    required this.info,
    required this.leading,
    required this.enableHint,
    required this.onEnable,
    required this.onOpenExtensions,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t.activitiesView;
    final name = info.nameFor(LocaleSettings.currentLocale.languageCode);
    final switchedOn = extensions.isExtensionSwitchedOn(info);
    return ListTile(
      tileColor: Theme.of(context).colorScheme.secondaryContainer,
      leading: leading,
      title: Text(
        switchedOn ? t.extensionNotRunning(name: name) : t.enableExtension(name: name),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(switchedOn ? t.extensionNotRunningHint : enableHint),
      trailing: Icon(switchedOn ? MdiIcons.toyBrick : MdiIcons.plus),
      onTap: switchedOn ? onOpenExtensions : onEnable,
    );
  }
}
