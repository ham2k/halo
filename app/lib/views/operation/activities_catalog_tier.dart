// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The third tier of the operation sheet's activity search (HALO-559): an
// extension the app does not have at all, found in the catalog and offered as
// an install in place. The two tiers above it — enabled, and installed but
// not running — live in activities_view.dart, which owns the search state, and
// activities_enable_tier.dart; what is here is everything that needs none of
// it.
//
// The tier exists because a QSO party is becoming one extension per event
// (HALO-558): typing "texas" then matches nothing installed, and an activity
// the operator searched for looking like it does not exist is the failure
// this closes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/extensions/catalog_service.dart';
import '../../services/error_reporting_service.dart';
import '../../config/experiments.dart' show kCatalogExperiment;
import '../../services/extensions/extension_relevance.dart';
import '../../services/extensions/extension_info.dart' show hooksClaimRef;
import '../../services/halo_services.dart';
import '../../services/extensions/installed_extensions.dart';
import '../extension_install_flow.dart';
import '../extensions_panel.dart' show extensionCategoryIcon;

/// The sheet's half of the tier: the listing it matches against, the one
/// fetch that gets it, and what that fetch currently matches.
///
/// Fetched LAZILY — on the first search that could use it, never on opening:
/// an operation sheet opened to add a nearby park asks the catalog nothing.
/// And once per sheet however much is typed, because a fetch per keystroke is
/// the failure a five-minute cache hides rather than prevents — an
/// unreachable catalog has no cache at all, and is the case that must not be
/// asked eight times for one word.
class CatalogTier {
  /// What arrived; null while a fetch is in flight and after one that failed.
  List<CatalogEntry>? entries;

  /// The subset [entries] currently offers for what is in the box.
  List<CatalogEntry> matches = const [];

  /// The subset offered for a reference the operation carries that nothing
  /// installed handles — the same rows, reached without typing anything.
  List<CatalogEntry> refMatches = const [];

  bool _fetchStarted = false;

  /// Whether the tier appears at all. Where the Extensions panel's Catalog
  /// section appears — a platform with a store to install into, and only
  /// under the experiment while that section is still gated. Off, the tier is
  /// absent and nothing is fetched: a section that is not built must not be
  /// asking the catalog anything.
  static bool shownFor(HaLoServices services) => InstalledExtensions.isSupported && services.settings.experimentEnabled(kCatalogExperiment);

  /// Catalog entries claiming any of [refs], minus [alreadyOffered]. What
  /// answers an operation opened long after the extension that wrote its
  /// references left the app — the catalog carries each entry's manifest
  /// `hooks`, so a claim is readable without a byte of its code running.
  List<CatalogEntry> matchingRefs(HaLoServices services, Iterable<({String type, String? code})> refs, {required Set<String> alreadyOffered}) {
    final listing = entries;
    if (listing == null || refs.isEmpty || !shownFor(services)) return const [];
    final available = {for (final info in services.extensions.availableExtensions) info.key};
    final matched = [
      for (final entry in listing)
        if (!available.contains(entry.key) &&
            !alreadyOffered.contains(entry.key) &&
            refs.any((ref) => hooksClaimRef(entry.hooks, type: ref.type, code: ref.code)))
          entry,
    ];
    return orderedCatalogEntries(matched, services.flags.operatorGeo, LocaleSettings.currentLocale.languageCode);
  }

  /// What [input] matches, or empty while the listing has not arrived. The
  /// candidates are read off the box exactly as the two tiers above read it.
  List<CatalogEntry> matching(HaLoServices services, ({String search, String key}) candidates, {required bool keyOnly}) {
    final listing = entries;
    if (listing == null || !shownFor(services)) return const [];
    return catalogExtensionsMatching(
      listing,
      search: candidates.search,
      key: candidates.key,
      keyOnly: keyOnly,
      availableKeys: {for (final info in services.extensions.availableExtensions) info.key},
      locale: LocaleSettings.currentLocale.languageCode,
      operatorGeo: services.flags.operatorGeo,
    );
  }

  /// Fetches the listing unless that has already been tried, calling
  /// [onLoaded] once it lands. The service never throws and answers null for
  /// a catalog it could not reach, which leaves the tier simply absent with
  /// no error in the way of the operator's search.
  void ensureFetched(HaLoServices services, void Function() onLoaded) {
    if (_fetchStarted) return;
    _fetchStarted = true;
    unawaited(_fetch(services, onLoaded));
  }

  Future<void> _fetch(HaLoServices services, void Function() onLoaded) async {
    final fetched = await services.catalog.fetchCatalog(geo: services.flags.operatorGeo);
    if (fetched == null) return;
    entries = fetched;
    onLoaded();
  }
}

/// Catalog entries matching [input] that the app does not already have — by
/// exact [key] alone when [keyOnly], else by the loose [search] as well. The
/// two are what `extensionSearchCandidates` read off the box, so this tier
/// answers the same text the two above it do.
///
/// Anything in [availableKeys] is excluded whatever its state: a built-in, an
/// installed-but-disabled or a dev-server extension belongs to one of those
/// tiers, and offering to install over it would ask the operator to download
/// what they already have — which for a built-in key the install flow would
/// then refuse, after the consent screen.
///
/// Ordered by the catalog's own geographic rule, so an operator in Texas is
/// offered the Texas party ahead of Vermont's.
List<CatalogEntry> catalogExtensionsMatching(
  List<CatalogEntry> entries, {
  required String search,
  required String key,
  required bool keyOnly,
  required Set<String> availableKeys,
  required String locale,
  OperatorGeo? operatorGeo,
}) {
  if (search.isEmpty) return const [];
  final matched = [
    for (final entry in entries)
      if (!availableKeys.contains(entry.key) && (entry.key.toLowerCase() == key || (!keyOnly && entry.matchesSearch(search, locale: locale)))) entry,
  ];
  return orderedCatalogEntries(matched, operatorGeo, locale);
}

/// An "Install X" row of the Activity Types section, for a catalog extension
/// the search matched that the app does not have.
///
/// Deliberately not the enable row it sits under: enabling is free and
/// instant, while this downloads code the operator has to consent to, and a
/// row that said "Enable" for it would be asking one thing and doing another.
class InstallExtensionRow extends StatelessWidget {
  final CatalogEntry entry;

  /// Null while an install is already under way, which makes the row inert.
  final VoidCallback? onTap;

  const InstallExtensionRow({super.key, required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = LocaleSettings.currentLocale.languageCode;
    return ListTile(
      tileColor: theme.colorScheme.secondaryContainer,
      // Unfilled and faded, like the offers in the Extensions panel: nothing
      // here is installed yet.
      leading: ExtensionIconTile(
        icon: entry.icon,
        accentColor: entry.accentColor,
        fallbackIcon: extensionCategoryIcon(entry.category),
        filled: false,
        opacity: kUninstalledIconOpacity,
      ),
      title: Text(
        context.t.activitiesView.installExtension(name: entry.nameFor(locale)),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(context.t.activitiesView.installExtensionHint),
      trailing: const Icon(MdiIcons.trayArrowDown),
      onTap: onTap,
    );
  }
}

/// Installs [entry] from the catalog and leaves it running, answering whether
/// the extension is now there to be searched.
///
/// The consent screen is the shared flow's — the same one a file install
/// shows, over bytes checked against the listing's hash — so false covers a
/// cancel and a refusal the flow has already explained, as well as an install
/// that went wrong underneath it.
Future<bool> installCatalogExtension(BuildContext context, {required HaLoServices services, required CatalogEntry entry}) async {
  try {
    final name = await installFromCatalog(context, services: services, release: entry.release, name: entry.nameFor(LocaleSettings.currentLocale.languageCode));
    if (name == null) return false;
    // A fresh catalog install drops the operator's stored override, so the
    // extension lands on whatever its manifest defaults to — which an author
    // is free to set to off. Off is not what someone who searched for it and
    // then agreed to install it asked for.
    final installed = services.extensions.availableExtensions.where((info) => info.key == entry.key).firstOrNull;
    if (installed != null && !services.extensions.isExtensionEnabled(installed)) {
      await services.extensions.setExtensionEnabled(entry.key, true);
    }
    return true;
  } catch (e, stack) {
    // Every refusal the flow decides for itself has already been shown; what
    // reaches here is the install failing underneath it, which otherwise
    // leaves a spinner turning over nothing anyone could report.
    debugPrint('[activities] installing ${entry.key} from the catalog failed: $e');
    ErrorReportingService.report(e, stack, context: 'activities:install-catalog-extension');
    return false;
  }
}
