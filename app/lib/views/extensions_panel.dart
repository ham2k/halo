// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension Management: enable/disable the optional extensions,
// grouped per category, with a search/filter field pinned at the TOP.
// Core (always-enabled) extensions are never listed. Metadata comes from
// the build index (ExtensionService.loadAvailableExtensions — readable
// even when the runtime is down); the enabled state is the overrides map
// in SettingsService.extensionOverrides, applied by restarting the
// extension runtime with the filtered bundle set.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import 'package:file_selector/file_selector.dart' show XFile;

import 'package:halo_core/halo_core.dart' show nowUtc;
import '../services/extensions/catalog_service.dart';
import '../services/error_reporting_service.dart';
import '../services/extensions/extension_relevance.dart' show ExtensionRelevance, OperatorGeo, kAlwaysSuggested, kRelevanceSoon, relevanceBand;
import '../services/extensions/extension_installer.dart';
import '../services/extensions/extension_service.dart';
import '../services/status_bar_service.dart' show StatusBarService;
import '../services/extensions/installed_extensions.dart';
import 'extension_install_flow.dart';
import '../services/halo_services.dart';

/// Category display order; anything unrecognized lands in "other". Public
/// because the Accounts panel groups by the same categories, and two lists in
/// two orders would present the same extensions differently in each.
const extensionCategoryOrder = ['activity', 'contest', 'lookup', 'spots', 'dashboard'];

String extensionCategoryTitle(String category) => switch (category) {
  'activity' => t.extensionsPanel.categoryActivity,
  'contest' => t.extensionsPanel.categoryContest,
  'lookup' => t.extensionsPanel.categoryLookup,
  'spots' => t.extensionsPanel.categorySpots,
  'dashboard' => t.extensionsPanel.categoryDashboard,
  _ => t.extensionsPanel.categoryOther,
};

IconData extensionCategoryIcon(String? category) => switch (category) {
  'activity' => MdiIcons.compass,
  'contest' => MdiIcons.trophy,
  'lookup' => MdiIcons.accountSearch,
  'spots' => MdiIcons.radioTower,
  'dashboard' => MdiIcons.viewDashboard,
  _ => MdiIcons.toyBrick,
};

/// The categories present in [keys], in [extensionCategoryOrder] first and
/// then whatever else turned up, so a caller grouping by category doesn't
/// restate the ordering rule.
List<String> extensionCategoriesIn(Iterable<String> keys) => [
  ...extensionCategoryOrder.where(keys.contains),
  ...keys.where((c) => !extensionCategoryOrder.contains(c)),
];

class ExtensionsPanel extends StatefulWidget {
  final HaLoServices services;

  /// Restricts the list to extensions whose manifest declares this hook —
  /// what the Add a Panel sheet opens, so an operator sent there looking for
  /// more panels is not handed the whole catalog to search through.
  final String? onlyHook;

  /// Ends the panel in its own Done footer band — for the modal-pane
  /// presentations, which drop the header's X in exchange
  /// ([haloDialogFooterBand]). Off inside the Settings view, where the panel
  /// is the page and there is nothing to be done with.
  final bool footer;

  const ExtensionsPanel({super.key, required this.services, this.onlyHook, this.footer = false});

  @override
  State<ExtensionsPanel> createState() => ExtensionsPanelState();
}

class ExtensionsPanelState extends State<ExtensionsPanel> {
  final _searchController = TextEditingController();

  /// True while a toggle's or a removal's runtime restart is applying — all
  /// switches disable and a progress row shows, then everything re-enables.
  /// Installs do not set it: they narrate themselves in the footer and on
  /// their own row, through [ExtensionInstaller].
  bool _applying = false;

  /// Every update Pending Updates has listed since the panel opened, by key,
  /// with the release it offered.
  ///
  /// Held rather than recomputed: an update that lands stops being pending,
  /// and a list that dropped each row the moment its update finished would
  /// reshuffle under the pointer through the whole of an Update all. A row
  /// stays, saying what it was updated to, until the panel is opened again.
  final _heldPending = <String, CatalogEntry>{};

  /// The order each category's rows appear in, held still for as long as the
  /// panel is open — see [_orderFor].
  final _rowOrder = <String, List<String>>{};

  /// The categories whose "and N others" row has been tapped, which then show
  /// everything the catalog has under that heading.
  ///
  /// One-way for the life of the panel: opening a category is a question
  /// being answered, and the row that opened it is gone once it is.
  final _expandedCategories = <String>{};

  /// The key the scroll view currently holds, and the controller that goes
  /// with it — see where they are refreshed, in [build].
  Key _listKey = listContentsKey(const []);

  /// Recreated with each [_listKey], carrying the offset over: a fresh scroll
  /// view starts at the top, and an operator opening a category half way down
  /// the panel would be thrown back to the first one.
  ScrollController _scroll = ScrollController();
  double _offset = 0;

  /// The catalog's entries once fetched; null before the fetch resolves and
  /// when it could not be read — [_catalogLoading] tells the two apart.
  List<CatalogEntry>? _catalog;
  bool _catalogLoading = false;

  /// The operator geo the catalog was last asked with. Compared against
  /// FlagsService's on every change it announces: the callsign's annotation
  /// can land after the panel opened (a cold launch opens Settings before
  /// the runtime is up), and the ranking is the catalog's own answer to
  /// that geo, so a new geo is a new request — not a re-sort.
  OperatorGeo? _catalogGeo;

  /// What rebuilds the panel: the settings (overrides, revocations), the
  /// update check (badges) and the flags (operator geo). Built once — a
  /// `Listenable.merge` made inside build would subscribe afresh on every
  /// rebuild.
  late Listenable _listenable;

  /// The Catalog section shows where Install from file does — the full
  /// panel, on a platform with a store: a hook-filtered panel is asking a
  /// narrower question, and the web has nowhere to install into. Hidden
  /// entirely: no header, no status line, and no fetch — a section that is
  /// not built but still asks the catalog is a request nobody can see the
  /// reason for.
  bool get _catalogShown => widget.onlyHook == null && InstalledExtensions.isSupported;

  @override
  void initState() {
    super.initState();
    _subscribe();
    // Usually already memoized by the runtime boot; on a broken runtime
    // this is what still populates the panel.
    widget.services.extensions.loadAvailableExtensions().then((_) {
      if (mounted) setState(() {});
    });
    // Fresh on every opening, cache bypassed: the operator has come to see
    // what the catalog holds, and an answer from four minutes ago is one that
    // predates whatever they came to look for. The update check goes with it —
    // it runs on a six-hour timer of its own, and Pending Updates would
    // otherwise show what was true this morning.
    if (_catalogShown) {
      unawaited(_loadCatalog(force: true));
      unawaited(widget.services.catalogUpdateCheck.check(force: true, announce: false));
    }
  }

  @override
  void didUpdateWidget(ExtensionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      oldWidget.services.flags.removeListener(_onFlagsChanged);
      _subscribe();
    }
  }

  void _subscribe() {
    final services = widget.services;
    _listenable = Listenable.merge([services.settings, services.catalogUpdateCheck, services.flags, services.extensionInstaller]);
    services.flags.addListener(_onFlagsChanged);
  }

  void _onFlagsChanged() {
    if (!_catalogShown || _catalogLoading) return;
    if (widget.services.flags.operatorGeo == _catalogGeo) return;
    unawaited(_loadCatalog());
  }

  /// Once per opening, and again when the operator geo changes.
  ///
  /// [force] bypasses the service's own cache — what an opening does, since
  /// the operator asking is the case the cache must not answer. The listener
  /// path below leaves it alone: a geo arriving is the app noticing
  /// something, not somebody waiting on an answer.
  Future<void> _loadCatalog({bool force = false}) async {
    final geo = widget.services.flags.operatorGeo;
    setState(() {
      _catalogGeo = geo;
      _catalogLoading = true;
    });
    final entries = await widget.services.catalog.fetchCatalog(geo: geo, force: force);
    if (!mounted) return;
    setState(() {
      _catalog = entries;
      _catalogLoading = false;
    });
    // The geo moved under the request; ask again with the one in force.
    if (widget.services.flags.operatorGeo != geo) _onFlagsChanged();
  }

  @override
  void dispose() {
    widget.services.flags.removeListener(_onFlagsChanged);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// [natural] with every key it already holds kept where it was.
  ///
  /// Installing something moves it out of the catalog's half of a heading and
  /// into the operator's own, and re-sorting there and then takes the row out
  /// from under the pointer that just installed it. So a key keeps the place
  /// it was first given, and the natural order decides only where a key
  /// nobody has seen yet goes — appended, which for an offer arriving with the
  /// catalog is where it belongs anyway. Reopening the panel builds this state
  /// afresh and everything sorts again.
  ///
  /// A search asks a different question and answers in its own order, so it
  /// passes [frozen] false and leaves what is held here untouched: clearing
  /// the box puts the list back the way the operator left it.
  List<String> _orderFor(String category, List<String> natural, {required bool frozen}) {
    if (!frozen) return natural;
    final held = _rowOrder.putIfAbsent(category, () => <String>[]);
    for (final key in natural) {
      if (!held.contains(key)) held.add(key);
    }
    final present = natural.toSet();
    return [
      for (final key in held)
        if (present.contains(key)) key,
    ];
  }

  Future<void> _toggle(String key, bool enabled) async {
    setState(() => _applying = true);
    try {
      // Persists the override first (the switch flips immediately via the
      // settings listenable), then restarts the runtime if the effective
      // set changed.
      await widget.services.extensions.setExtensionEnabled(key, enabled);
      widget.services.track(enabled ? 'extension_enabled' : 'extension_disabled', {'extension': key});
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  /// Picks a `.h2kext`, asks, installs, and reboots the runtime around it.
  Future<void> _install() async {
    final services = widget.services;
    final store = services.extensions.installed;
    // The button is disabled without a store, so this is belt-and-braces —
    // but a press that did nothing at all, with no message and no log, is the
    // one outcome nobody could report.
    if (store == null) {
      debugPrint('[extensions] install pressed before the installed store was ready');
      return;
    }
    final name = await installExtensionFromFile(context, store: store, commit: commitThroughInstaller(services), isBusy: services.extensionInstaller.isActive);
    if (name == null) return; // cancelled, or refused with its own dialog
    services.track('extension_installed', {});
  }

  /// Install or Update from the catalog: the shared path (installFromCatalog).
  Future<void> _installFromCatalog(CatalogEntry entry) =>
      installFromCatalog(context, services: widget.services, release: entry.release, name: entry.nameFor(LocaleSettings.currentLocale.languageCode));

  /// Takes every pending update — the shared path, which confirms first.
  ///
  /// The list is captured by the caller: each install changes what is
  /// pending, and the confirmation is about the list the operator pressed on.
  Future<void> _updateAll(List<CatalogEntry> entries) => updateAllFromCatalog(context, services: widget.services, entries: entries);

  /// Opens an extension's details, and does whatever the operator chose
  /// there — the dialog only ever answers.
  Future<void> _showDetails(ExtensionInfo info) async {
    final locale = LocaleSettings.currentLocale.languageCode;
    // What the catalog offers, when it offers something newer. The row's own
    // "Update available" badge reads the same two sources, so the button in
    // the dialog and the badge on the row can never disagree.
    final entry = _catalogEntryFor(info);
    final from = info.isInstalled ? _installedFrom(info) : null;
    final action = await showExtensionDetails(
      context,
      info: info,
      locale: locale,
      installedFrom: from?.label,
      installedFromIcon: from?.icon,
      updateVersion: entry?.version,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ExtensionDetailsAction.uninstall:
        await _uninstall(info);
      case ExtensionDetailsAction.update:
        if (entry != null) await _installFromCatalog(entry);
    }
  }

  /// The catalog's release for [info] when it is newer than what is
  /// installed, from either the listing on screen or the unattended check.
  CatalogEntry? _catalogEntryFor(ExtensionInfo info) {
    // `_catalogShown` for the same reason the row's badge reads it: an Update
    // button that installs from a catalog the panel is not showing is worse
    // than no badge at all.
    if (!info.isInstalled || !_catalogShown) return null;
    for (final entry in [
      ?(_catalog ?? const <CatalogEntry>[]).where((e) => e.key == info.key).firstOrNull,
      ?widget.services.catalogUpdateCheck.pendingUpdates[info.key],
    ]) {
      if (entry.isNewerThan(info.version)) return entry;
    }
    return null;
  }

  /// Where an installed extension's bytes came from, in the words the consent
  /// screen used when it arrived — the catalog's host, or a file, or the app
  /// itself for one it shipped pre-loaded, which nobody downloaded.
  ({String label, IconData icon}) _installedFrom(ExtensionInfo info) {
    final provenance = BundleProvenance.fromJson(widget.services.settings.extensionInstalledFrom[info.key]);
    if (provenance == null) {
      return (label: t.extensionsPanel.installedFromFile, icon: MdiIcons.fileOutline);
    }
    if (provenance.isPreloaded) {
      return (label: t.extensionsPanel.installedPreloaded, icon: MdiIcons.packageVariantClosed);
    }
    return (label: t.extensionsPanel.installedFrom(source: provenance.host), icon: MdiIcons.downloadOutline);
  }

  Future<void> _uninstall(ExtensionInfo info) async {
    final locale = LocaleSettings.currentLocale.languageCode;
    final name = info.nameFor(locale);
    if (!await confirmUninstall(context, name: name)) return;
    if (!mounted) return;
    setState(() => _applying = true);
    try {
      await widget.services.extensions.uninstallExtension(info.key);
      widget.services.track('extension_uninstalled', {});
    } catch (e, stack) {
      // Otherwise the spinner clears, the row is still there, and nothing says
      // the removal failed — the operator is left to conclude the button does
      // not work.
      ErrorReportingService.report(e, stack, context: 'extension-uninstall');
      if (mounted) {
        widget.services.statusBar.setMessage(
          key: 'extensions:uninstall',
          text: t.extensionsPanel.uninstallFailed(name: name),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    // The search bar and the applying line aren't rows, so they take the
    // rows' own content inset explicitly — the ambient ListTileTheme, which
    // already carries the grab-strip clearance (layouts.md) and the pane's
    // centering. Anything else and the field is wider than what it filters.
    //
    // A modal pane publishes no such theme, and zero there puts the field
    // flush against the pane's edges: fall back to the settings-list inset
    // and publish it, so the rows below line up with the field rather than
    // each taking a default of their own.
    final rowInset = ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: settingsRowInset);
    final query = _searchController.text.trim().toLowerCase();

    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        // Experiment-gated extensions are hidden entirely, not shown
        // disabled — their stored override survives for when the
        // experiment returns (isExtensionAvailable).
        final extensionService = widget.services.extensions;
        final listed = extensionService.availableExtensions
            .where((info) => !info.core && extensionService.isExtensionAvailable(info))
            .where((info) => widget.onlyHook == null || info.hooks.contains(widget.onlyHook))
            .toList();
        final locale = LocaleSettings.currentLocale.languageCode;
        // Search matches both the localized and the English name/description,
        // so a user can find an extension by either.
        final visible = query.isEmpty
            ? listed
            : [
                for (final info in listed)
                  if (info.matchesSearch(query, locale: locale)) info,
              ];

        // The operator's own geography and the clock, resolved once for the
        // whole build: every row below is ranked against the same instant, so
        // a list cannot order itself by two different "now"s.
        final operatorGeo = widget.services.flags.operatorGeo;
        final now = nowUtc();
        int bandOf(ExtensionRelevance? relevance) => relevanceBand(relevance, operator: operatorGeo, now: now);

        // What the catalog is compared against: the keys the app is
        // OFFERING of its own (a catalog entry for one is "Built in", never
        // installable) and the installed store's versions (a higher catalog
        // version is an Update).
        //
        // Offering, not merely shipping. Once upgraded to catalog extensions
        // the app withdraws its own extensions, and the store will then install a
        // catalog bundle for one of those keys — so a panel judging by what
        // the app ships would show "Built in" over a row that is in fact
        // installable, and disagree with the door about the same bundle.
        final builtInKeys = {
          for (final info in extensionService.availableExtensions)
            if (info.source == ExtensionSource.asset && extensionService.isBuiltInOffered(info)) info.key,
        };
        final installedVersions = {
          for (final info in extensionService.availableExtensions)
            if (info.isInstalled) info.key: info.version,
        };
        final catalogByKey = {for (final entry in _catalog ?? const <CatalogEntry>[]) entry.key: entry};
        final pendingUpdates = widget.services.catalogUpdateCheck.pendingUpdates;
        // The badge follows the section: the Update button it points at is
        // a catalog row, and in a hook-filtered panel there is none.
        bool hasUpdate(String key) =>
            _catalogShown &&
            ((catalogByKey[key]?.isNewerThan(installedVersions[key]) ?? false) || (pendingUpdates[key]?.isNewerThan(installedVersions[key]) ?? false));

        // What the catalog offers that the operator does not already have.
        //
        // An entry for something installed or built in is dropped rather than
        // shown beside it: the two would sit adjacent under the same heading,
        // naming the same extension twice, and what to do about an update is
        // the installed row's own business (its badge, and the Update in its
        // details).
        //
        // Everything on offer, not only what is suggested: the rest is behind
        // this category's "and N others" row, and both halves come from here.
        // With a query it is what the query matched, because then the
        // operator has said what they are looking for.
        final offers = <CatalogEntry>[];
        if (_catalogShown && _catalog != null) {
          for (final entry in _catalog!) {
            if (installedVersions.containsKey(entry.key) || builtInKeys.contains(entry.key)) continue;
            if (query.isEmpty || entry.matchesSearch(query, locale: locale)) offers.add(entry);
          }
        }

        final categories = extensionCategoriesIn({for (final info in visible) info.category ?? 'other', for (final entry in offers) entry.category ?? 'other'});

        // Which of the offers are worth putting in front of somebody who did
        // not ask. Ninety extensions under five headings would bury what an
        // operator actually uses, and everything held back is one tap away.
        //
        // A DATED extension is only ever suggested inside its window, whoever
        // the operator is: a QSO party six months out is not news, and the
        // state it runs in is true all year. Its own geography cannot let it
        // back in, or every operator in Texas would carry the Texas QSO Party
        // in their suggestions from one running to the next.
        bool isSuggested(CatalogEntry entry) {
          if (kAlwaysSuggested.contains(entry.key)) return true;
          final relevance = entry.relevance;
          if (relevance == null) return false;
          if (relevance.dates.isNotEmpty) return relevance.startsWithin(kRelevanceSoon, now);
          return bandOf(relevance) < 2;
        }

        final overrides = settings.extensionOverrides;
        final revoked = settings.extensionRevoked;
        final rows = <Widget>[];
        // What the list is actually showing of the catalog, gathered as the
        // rows are built rather than derived a second time: the row-set key
        // below has to change when an expansion changes the rows, and a key
        // computed from the offers alone would not notice.
        final shownOffers = <String>[];
        // What the operator has that the catalog has moved on from, gathered
        // ahead of the categories: an update is a job to finish rather than
        // something to find, and hunting five of them down a list of ninety is
        // the panel making work. Absent when there is nothing to do — an empty
        // heading saying so is a worse answer than silence.
        // Whichever source actually offers something NEWER, not whichever
        // answers first: `hasUpdate` is true when either is ahead, so
        // preferring the listing unconditionally can put a row on screen
        // reading `1.0.0 → 1.0.0` and have Update all reinstall it.
        final installer = widget.services.extensionInstaller;
        final visibleByKey = {for (final info in visible) info.key: info};
        if (query.isEmpty) {
          for (final info in visible) {
            final entry = _catalogEntryFor(info);
            if (entry != null) _heldPending[entry.key] = entry;
          }
        }
        // What is held and still here — an extension removed since is gone
        // from the list along with its row.
        // A held row stays while it is under way, once it has landed, or while
        // the catalog still offers it — not for an offer since withdrawn, and
        // not at all once the catalog is off: an Update button then installs
        // from a catalog the panel no longer shows (see [_catalogEntryFor]).
        final held = [
          if (_catalogShown)
            for (final entry in _heldPending.values)
              if (visibleByKey[entry.key] case final info?)
                if (installer.isActive(entry.key) || !entry.isNewerThan(info.version) || _catalogEntryFor(info) != null) entry,
        ];
        // What Update all would still take: not what has landed, and not what
        // is under way already.
        final pending = [
          for (final entry in held)
            if (entry.isNewerThan(visibleByKey[entry.key]!.version) && !installer.isActive(entry.key)) entry,
        ];
        if (query.isEmpty && held.isNotEmpty) {
          // Row identities, so taking an update remounts the list rather than
          // leaving the web's hit-testing on the geometry that had one more
          // row in it (docs/quirks.md, listContentsKey).
          shownOffers.addAll(held.map((entry) => 'pending:${entry.key}'));
          // On the post-it yellow, edge to edge, band and rows alike: this
          // section is a standing notice rather than one more group, and it is
          // the one part of the panel that says something is owed rather than
          // offering something to browse.
          final notice = HaLoColors.of(context).notice;
          final onNotice = HaLoColors.of(context).onNotice;
          rows.add(
            SectionHeader(
              t.extensionsPanel.pendingUpdatesSection,
              background: notice,
              color: onNotice,
              trailing: OutlinedButton(
                onPressed: _applying || pending.isEmpty ? null : () => unawaited(_updateAll(pending)),
                // Outlined, so the verb reads as a button on a ground that is
                // already a colour: a bare label on the notice yellow is one
                // more piece of the sentence around it.
                style: OutlinedButton.styleFrom(
                  foregroundColor: onNotice,
                  side: BorderSide(color: onNotice),
                ),
                child: Text(t.extensionsPanel.updateAllAction),
              ),
            ),
          );
          for (final entry in held) {
            final info = visibleByKey[entry.key]!;
            final busy = installer.isActive(entry.key);
            final landed = !entry.isNewerThan(info.version);
            rows.add(
              ListTile(
                key: ValueKey('pending-${entry.key}'),
                // The tile's own ground, which fills the row's whole width: the
                // band's ColoredBox reaches the pane's edges and the rows under
                // it have to as well, or the notice is a stripe with a ragged
                // side.
                tileColor: notice,
                leading: ExtensionIconTile(icon: info.icon, accentColor: info.accentColor, fallbackIcon: extensionCategoryIcon(info.category)),
                title: Text(info.nameFor(locale), style: TextStyle(color: onNotice)),
                // What it would become, beside what it is: the row is about the
                // gap between the two, and a version on its own says neither.
                subtitle: busy
                    ? _InstallProgressLine(extensionKey: entry.key, statusBar: widget.services.statusBar, color: onNotice)
                    : Text(
                        landed
                            ? t.extensionsPanel.updatedTo(version: info.version ?? entry.version)
                            : t.extensionsPanel.installVersion(version: '${info.version} → ${entry.version}'),
                        style: TextStyle(color: onNotice),
                      ),
                trailing: busy
                    ? _InstallSpinner(color: onNotice)
                    : landed
                    ? SizedBox(
                        height: _trailingControlHeight,
                        child: Icon(MdiIcons.check, color: onNotice),
                      )
                    : SizedBox(
                        height: _trailingControlHeight,
                        child: FilledButton(
                          onPressed: _applying ? null : () => unawaited(_installFromCatalog(entry)),
                          child: Text(t.extensionsPanel.updateAction),
                        ),
                      ),
              ),
            );
          }
        }

        for (final category in categories) {
          final inCategory =
              [
                for (final info in visible)
                  if ((info.category ?? 'other') == category) info,
              ]..sort((a, b) {
                final byBand = bandOf(a.relevance).compareTo(bandOf(b.relevance));
                if (byBand != 0) return byBand;
                return a.nameFor(locale).toLowerCase().compareTo(b.nameFor(locale).toLowerCase());
              });
          final offered =
              [
                for (final e in offers)
                  if ((e.category ?? 'other') == category) e,
              ]..sort((a, b) {
                final byBand = bandOf(a.relevance).compareTo(bandOf(b.relevance));
                if (byBand != 0) return byBand;
                return a.nameFor(locale).toLowerCase().compareTo(b.nameFor(locale).toLowerCase());
              });
          // A search is the operator asking, so it answers in full — and so
          // does a category they have opened. Otherwise the head of the list
          // is what is suggested, and only a few of it: a heading that
          // already carries three of the operator's own extensions is a
          // subject they have settled, and five more offers under it is a
          // sales pitch rather than a panel.
          final shown = query.isNotEmpty || _expandedCategories.contains(category)
              ? offered
              : offered.where(isSuggested).take(inCategory.length >= 3 ? 2 : 5).toList();
          final hidden = offered.length - shown.length;
          if (inCategory.isEmpty && offered.isEmpty) continue;
          rows.add(SectionHeader(extensionCategoryTitle(category)));
          // One pass over the held order, and each key is drawn as whatever it
          // is NOW: the extension the operator just installed keeps the place
          // its offer had, and simply stops being an offer.
          final store = extensionService.installed;
          final installedByKey = {for (final info in inCategory) info.key: info};
          final offersByKey = {for (final entry in shown) entry.key: entry};
          final order = _orderFor(category, [...inCategory.map((info) => info.key), ...shown.map((entry) => entry.key)], frozen: query.isEmpty);
          for (final orderedKey in order) {
            final info = installedByKey[orderedKey];
            final entry = offersByKey[orderedKey];
            if (info == null && entry == null) continue;
            if (info != null) {
              final enabled = overrides[info.key] ?? info.enabledByDefault;
              // The extension's own icon (build-index `icon`, mirroring its
              // hooks) when it has one; the category icon otherwise, on the
              // accent its manifest names.
              final icon = ExtensionIconTile(icon: info.icon, accentColor: info.accentColor, fallbackIcon: extensionCategoryIcon(info.category));
              final title = Text(info.nameFor(locale));
              final description = info.descriptionFor(locale);
              // Stable identity: without keys, list churn during the applying
              // rebuilds re-creates row elements and their icons visibly flicker.
              final rowKey = ValueKey('extension-${info.key}');
              // NOT disabled while applying (onChanged: null would repaint every
              // tile in disabled grey — the "icons fade to white" flicker); the
              // IgnorePointer below blocks input instead, so the rows keep their
              // exact appearance.
              void toggle(bool value) => unawaited(_toggle(info.key, value));

              if (!info.isInstalled) {
                // A ListTile with its own switch rather than a SwitchListTile,
                // which has nowhere to put the line under the control: an
                // extension the app ships is at whatever version the app is,
                // which is nobody's to act on, so it says so where the others
                // carry a version. The tap still toggles the whole row.
                rows.add(
                  ListTile(
                    key: rowKey,
                    leading: icon,
                    title: title,
                    subtitle: _DescriptionLine(description: description, onDetails: () => unawaited(_showDetails(info))),
                    onTap: () => toggle(!enabled),
                    mouseCursor: SystemMouseCursors.click,
                    trailing: _TrailingWithCaption(
                      caption: t.extensionsPanel.builtIn,
                      control: _trailingSwitch(value: enabled, onChanged: toggle),
                    ),
                  ),
                );
                continue;
              }

              // An installed extension sits in its own category alongside the
              // app's own — it is the same kind of thing, and splitting them
              // would make "where is my extension" a question about where it
              // came from. What it gets extra is a way to remove it, which a
              // SwitchListTile has nowhere to put. A revoked release gets no
              // switch at all: the catalog pulled it, and a switch that could
              // not turn it on would only say the panel is broken. What is
              // left is the catalog's note, an update if there is one, and
              // the way out.
              final isRevoked = extensionService.isExtensionRevoked(info);
              final revokedNote = isRevoked ? (revoked[info.key]?['note'] ?? '') : '';
              // An update under way, from anywhere — this row, its details,
              // Update all, the notice. The switch goes with it: the install
              // restarts the runtime, and a toggle then is a restart racing it.
              final busy = installer.isActive(info.key);
              // A bundle the engine refused. Said on the row because the
              // extension is installed, switched on, and doing nothing — and
              // the one dialog that names it passes by once. It keeps its
              // switch, unlike a revoked release: the operator turning it off
              // is a choice that still means something once a later version
              // lifts the refusal.
              rows.add(
                ListTile(
                  key: rowKey,
                  leading: icon,
                  title: title,
                  // The row toggles, as the built-in rows above it do. Boxing the
                  // switch to [_trailingControlHeight] to make room for the
                  // version under it takes its tap target below the 48 Material
                  // asks for, and the row is what gives that back.
                  onTap: isRevoked || busy ? null : () => toggle(!enabled),
                  mouseCursor: isRevoked || busy ? null : SystemMouseCursors.click,
                  // No "Installed" here any more: it sits under the same headings
                  // as the app's own extensions, so saying so on every row said
                  // nothing the section did not. What is left is what is
                  // UNUSUAL about this one.
                  subtitle: busy
                      ? _InstallProgressLine(extensionKey: info.key, statusBar: widget.services.statusBar)
                      : _DescriptionLine(
                          description: [
                            if (isRevoked) t.extensionsPanel.revokedBadge,
                            if (extensionService.isExtensionRefused(info)) t.extensionsPanel.refusedBadge,
                            if (hasUpdate(info.key)) t.extensionsPanel.updateAvailableBadge,
                            if (revokedNote.isNotEmpty) revokedNote,
                            ?description,
                          ].join(' · '),
                          onDetails: () => unawaited(_showDetails(info)),
                        ),
                  trailing: _TrailingWithCaption(
                    // What is installed, not what the catalog offers: the offer
                    // is on the catalog row below, and the two together are what
                    // an update moves between.
                    caption: info.version,
                    // Removing lives in the details dialog now. It was a bin
                    // beside the switch, one mis-aimed click from a toggle, and
                    // the row it sat on could not say what would be removed.
                    control: busy
                        ? const _InstallSpinner()
                        : isRevoked
                        ? const SizedBox(height: _trailingControlHeight)
                        : _trailingSwitch(value: enabled, onChanged: toggle),
                  ),
                ),
              );
              continue;
            }
            // The catalog's offer, under the same heading as what the operator
            // already has. A separate "Catalog" section made finding a contest
            // a question about where it came from.
            shownOffers.add('catalog:${entry!.key}');
            final description = entry.descriptionFor(locale);
            final busy = installer.isActive(entry.key);
            rows.add(
              ListTile(
                key: ValueKey('catalog-${entry.key}'),
                // The glyph in the accent rather than a solid tile of it, and
                // faded: this row is an offer, and at an installed row's weight
                // it claims a place in the panel that nothing has taken yet.
                leading: ExtensionIconTile(
                  icon: entry.icon,
                  accentColor: entry.accentColor,
                  fallbackIcon: extensionCategoryIcon(entry.category),
                  filled: false,
                  opacity: kUninstalledIconOpacity,
                ),
                title: Text(entry.nameFor(locale)),
                subtitle: busy
                    ? _InstallProgressLine(extensionKey: entry.key, statusBar: widget.services.statusBar)
                    : description == null
                    ? null
                    : Text(description),
                // The offered version under the button, as an installed row
                // carries the version it holds.
                trailing: _TrailingWithCaption(
                  caption: entry.version,
                  control: busy
                      ? const _InstallSpinner()
                      : SizedBox(
                          height: _trailingControlHeight,
                          // Disabled until the store exists, like Install from file: a
                          // press before then has nothing to install into. `_applying`
                          // is the IgnorePointer's job, not a disabled button's.
                          child: OutlinedButton(
                            onPressed: store == null ? null : () => unawaited(_installFromCatalog(entry)),
                            child: Text(t.extensionsPanel.installAction),
                          ),
                        ),
                ),
              ),
            );
          }

          // What the category holds beyond what is worth suggesting. Without
          // it the rest of the catalog is reachable only by guessing at a
          // name in the search box.
          //
          // "… and N other" continues the list above it, so a category with
          // nothing suggested — where it continues nothing — counts what is
          // there instead. Centered and bold because it is the one row that
          // is not an extension: it reads as the end of the section rather
          // than as another thing to install.
          if (hidden > 0) {
            shownOffers.add('more:$category');
            final theme = Theme.of(context);
            rows.add(
              ListTile(
                key: ValueKey('catalog-more-$category'),
                title: Text(
                  shown.isEmpty ? t.extensionsPanel.availableInCategory(count: hidden) : t.extensionsPanel.moreInCategory(count: hidden),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                onTap: () => setState(() => _expandedCategories.add(category)),
              ),
            );
          }
        }

        // The catalog's own state, once, under whatever it managed to say —
        // not per category, which would repeat "unreachable" five times.
        if (_catalogShown && _catalogLoading) {
          rows.add(_CatalogStatusLine(t.extensionsPanel.catalogLoading));
        } else if (_catalogShown && _catalog == null) {
          rows.add(_CatalogStatusLine(t.extensionsPanel.catalogUnreachable));
        }

        // Which rows the scroll view holds, and a controller to match.
        //
        // Refreshed HERE rather than from the setState that changed things,
        // the way the Settings list does it: the row set is only known once
        // this builder has computed it — the catalog's answer, the query, and
        // which categories are open all land in the same pass — and the
        // replacement view is built in this very frame, so it needs its
        // controller now rather than after it.
        final listKey = listContentsKey([for (final info in visible) info.key, ...shownOffers]);
        if (listKey != _listKey) {
          _listKey = listKey;
          // The outgoing controller is still attached to the scroll view being
          // replaced, which only detaches during this build — disposing it
          // here would assert.
          final outgoing = _scroll;
          WidgetsBinding.instance.addPostFrameCallback((_) => outgoing.dispose());
          _scroll = ScrollController(initialScrollOffset: _offset);
        }

        final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: rowInset.add(const EdgeInsets.only(top: Space.lg, bottom: Space.xl)),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      selectAllOnFocus: false,
                      key: const ValueKey('extensions-search'),
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        // Filled, like the Settings search it sits a panel
                        // away from: an unfilled field on a panel's own ground
                        // is a rectangle of border with nothing saying it can
                        // be typed in.
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(MdiIcons.close, size: 18, semanticLabel: 'Clear'),
                                onPressed: () => setState(() => _searchController.clear()),
                              ),
                        hintText: t.extensionsPanel.searchHint,
                        border: searchBorder,
                        focusedBorder: haloFocusedBorder(searchBorder, context),
                      ),
                    ),
                  ),
                  // An icon beside the search field rather than a labelled
                  // button under the list. Hidden in a hook-filtered panel,
                  // which is asking a narrower question than "what do I
                  // have". The label survives as the icon's semantics — it is
                  // the only name a screen reader has for it.
                  if (widget.onlyHook == null && InstalledExtensions.isSupported) ...[
                    const SizedBox(width: Space.md),
                    IconButton(
                      key: const ValueKey('extensions-install-from-file'),
                      icon: Icon(MdiIcons.fileCogOutline, semanticLabel: t.extensionsPanel.installFromFile),
                      // Disabled until the store exists — it is built on the
                      // first loadAvailableExtensions, and a press before that
                      // has nothing to install into.
                      onPressed: _applying || extensionService.installed == null ? null : () => unawaited(_install()),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              // The offset is recorded rather than read back off the
              // controller after the fact: the controller that HELD it is
              // replaced along with the scroll view, so by then it is gone.
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0) _offset = notification.metrics.pixels;
                  return false;
                },
                child: IgnorePointer(
                  ignoring: _applying,
                  child: rows.isEmpty
                      ? Center(child: Text(t.extensionsPanel.noMatches))
                      : SectionedListView(
                          // Without the key the row a click lands on is not
                          // the row under the pointer — the web's
                          // accessibility DOM keeps the pre-filter geometry
                          // (docs/quirks.md, where this was measured). The row
                          // set, not the query: an uninstall, an install and
                          // an experiment flip each change the rows with the
                          // query untouched, while a toggle changes neither
                          // and must not remount. The catalog rows are rows
                          // too: the fetch resolving changes the set as surely
                          // as an install does, and so does opening a
                          // category, which moves every row beneath it.
                          key: _listKey,
                          controller: _scroll,
                          padding: const EdgeInsets.only(bottom: Space.md),
                          children: rows,
                        ),
                ),
              ),
            ),
            if (_applying)
              Padding(
                padding: rowInset.add(const EdgeInsets.only(top: Space.md, bottom: Space.lg)),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: Space.lg),
                    Expanded(child: Text(t.extensionsPanel.applying)),
                  ],
                ),
              ),
            if (widget.footer)
              haloDialogFooterBand(
                context,
                // Disabled while applying, like the Install button above: a
                // pop here resolves the caller's await while the runtime
                // restart is still in flight, and the caller then re-reads a
                // half-started runtime.
                cancel: TextButton(onPressed: _applying ? null : () => Navigator.of(context).maybePop(), child: Text(t.common.done)),
              ),
          ],
        );

        // Published for the rows and the section bands below, so the field
        // above them and they take the same inset — see [rowInset].
        final body = ListTileTheme.merge(contentPadding: rowInset, child: content);

        // Dropping a bundle on the panel is the same install as the button —
        // same inspection, same consent screen — reached the way someone who
        // has just downloaded a file expects to reach it. Only where there is
        // a store to install into, and only in the full panel: the hook-
        // filtered one is asking a narrower question.
        if (widget.onlyHook != null || extensionService.installed == null) return body;
        return ExtensionDropTarget(onFile: _installDropped, child: body);
      },
    );
  }

  /// A dropped file takes exactly the path a picked one does.
  Future<void> _installDropped(XFile file) async {
    final services = widget.services;
    final store = services.extensions.installed;
    if (store == null) return;
    final name = await installExtensionFromBytes(
      context,
      store: store,
      read: file.readAsBytes,
      commit: commitThroughInstaller(services),
      isBusy: services.extensionInstaller.isActive,
    );
    if (name == null) return;
    services.track('extension_installed', {});
  }
}

/// A row's description with the way into its details at the end of it.
///
/// The button sits on the description line rather than in the trailing
/// column because the trailing column is the switch's, and a second control
/// beside a switch is one mis-aimed click from toggling the extension.
///
/// [description] may be empty — an extension whose manifest carries none —
/// and the button still has to be reachable, so the line is built either way.
class _DescriptionLine extends StatelessWidget {
  final String? description;
  final VoidCallback onDetails;

  const _DescriptionLine({required this.description, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final text = description ?? '';
    return Row(
      children: [
        if (text.isNotEmpty) Expanded(child: Text(text)) else const Spacer(),
        SizedBox(
          width: 32,
          height: _trailingControlHeight,
          child: IconButton(
            icon: Icon(MdiIcons.informationOutline, semanticLabel: context.t.extensionsPanel.detailsAction),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: onDetails,
          ),
        ),
      ],
    );
  }
}

/// A row's subtitle while its extension is being installed: the footer's own
/// progress item for it, mirrored, as the Data Files rows mirror theirs — the
/// footer may be under the pane, and the row is where the operator looks.
///
/// Its own listener, not the panel's: the status bar notifies on every tick
/// of every progress bar in the app, and the panel rebuilding a hundred rows
/// for each one is the cost this keeps to the row that asked.
class _InstallProgressLine extends StatelessWidget {
  final String extensionKey;
  final StatusBarService statusBar;

  /// The text colour — the notice's, on the Pending Updates yellow.
  final Color? color;

  const _InstallProgressLine({required this.extensionKey, required this.statusBar, this.color});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: statusBar,
      builder: (context, _) {
        final item = statusBar.itemForKey(ExtensionInstaller.progressKey(extensionKey));
        // Nothing posted is a refusal dialog open over the row, and the
        // footer's item already taken down for it — a line here would say
        // something is still happening.
        if (item == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.text ?? '', style: color == null ? null : TextStyle(color: color)),
            // A message rather than a bar is the install waiting on the
            // operator (the consent screen), which no bar should claim.
            if (item.isProgress) ...[const SizedBox(height: Space.sm), LinearProgressIndicator(value: item.progressValue, color: color)],
          ],
        );
      },
    );
  }
}

/// Where a row's control goes while its extension is being installed.
class _InstallSpinner extends StatelessWidget {
  final Color? color;

  const _InstallSpinner({this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _trailingControlHeight,
    height: _trailingControlHeight,
    child: Padding(
      padding: const EdgeInsets.all(Space.sm),
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    ),
  );
}

/// One line under the Catalog header that is not a row — loading, or
/// unreachable — at the rows' own inset, the way the search field takes it.
class _CatalogStatusLine extends StatelessWidget {
  final String text;

  const _CatalogStatusLine(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowInset = ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: settingsRowInset);
    return Padding(
      padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.md)),
      child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// What every extension row's trailing control is boxed to, so the line
/// under it has room — see [_TrailingWithCaption]. Every one of them (the
/// switch, the remove button, the Install button) otherwise reserves a tap
/// target of 40 to 48 depending on the platform's density, which leaves
/// nothing behind for a line of text.
const _trailingControlHeight = 32.0;

Widget _trailingSwitch({required bool value, required ValueChanged<bool> onChanged}) => SizedBox(
  height: _trailingControlHeight,
  child: Switch(value: value, onChanged: onChanged),
);

/// A row's trailing control with one subdued line OVER it: the version the
/// extension is installed at, or offered at, or — for one the app ships,
/// whose version nobody can act on — the word for that.
///
/// The version reads on the row's first line, level with the name it belongs
/// to, and the control sits on the second beneath it.
///
/// Height is the whole design constraint here. A ListTile caps its trailing
/// box at 56 logical pixels less the theme's vertical density — 48 under the
/// desktop default — and never grows it however tall the row is, so the
/// control and the line under it fit that between them or the tile
/// overflows: hence [_trailingControlHeight] above, and the caption
/// [Flexible] below rather than free-standing, since the OS text-scale
/// preference composes on top of the app's own scaling
/// (docs/design/ui-scaling.md) and a caption at 1.5x would otherwise take
/// the tile with it. Everything here is in plain logical pixels; the app's
/// own font scale moves the cap and the contents together.
///
/// So a control that outgrows [_trailingControlHeight] never overflows the
/// tile — it squeezes the caption down to an unreadable sliver instead, which
/// is the failure to watch for.
class _TrailingWithCaption extends StatelessWidget {
  final Widget control;

  /// Null where there is nothing to say — an installed bundle whose manifest
  /// predates the version field — which leaves the control alone.
  final String? caption;

  const _TrailingWithCaption({required this.control, required this.caption});

  @override
  Widget build(BuildContext context) {
    if (caption == null) return control;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(caption!, maxLines: 1, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        control,
      ],
    );
  }
}
