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

import '../services/catalog_service.dart';
import '../services/error_reporting_service.dart';
import '../services/extension_geo.dart' show OperatorGeo;
import '../services/extension_service.dart';
import '../services/installed_extensions.dart';
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

  /// True while a toggle's runtime restart is applying — all switches
  /// disable and a progress row shows, then everything re-enables.
  bool _applying = false;

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
  /// narrower question, and the web has nowhere to install into — and only
  /// under the experiment while the catalog is not live. Hidden entirely:
  /// no header, no status line, and no fetch — a section that is not built
  /// but still asks the catalog is a request nobody can see the reason for.
  bool get _catalogShown =>
      widget.onlyHook == null &&
      InstalledExtensions.isSupported &&
      widget.services.settings.experimentEnabled('catalog') /* stored key, see experiments.yaml */;

  /// What [_catalogShown] answered last, so the settings change that flips
  /// the experiment is told apart from every other one (an override, a
  /// revocation) — those rebuild, this one also fetches.
  bool _catalogWasShown = false;

  @override
  void initState() {
    super.initState();
    _catalogWasShown = _catalogShown;
    _subscribe();
    // Usually already memoized by the runtime boot; on a broken runtime
    // this is what still populates the panel.
    widget.services.extensions.loadAvailableExtensions().then((_) {
      if (mounted) setState(() {});
    });
    if (_catalogShown) unawaited(_loadCatalog());
  }

  @override
  void didUpdateWidget(ExtensionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      oldWidget.services.flags.removeListener(_onFlagsChanged);
      oldWidget.services.settings.removeListener(_onSettingsChanged);
      _subscribe();
    }
  }

  void _subscribe() {
    final services = widget.services;
    _listenable = Listenable.merge([services.settings, services.catalogUpdateCheck, services.flags]);
    services.flags.addListener(_onFlagsChanged);
    services.settings.addListener(_onSettingsChanged);
  }

  /// The experiment flipped from the Experiments panel over this one: the
  /// fetch initState skipped is due now, without reopening. The service
  /// answers from its cache within its window, so flipping back and forth
  /// is not a request each time.
  void _onSettingsChanged() {
    final shown = _catalogShown;
    if (shown == _catalogWasShown) return;
    _catalogWasShown = shown;
    if (shown && !_catalogLoading) unawaited(_loadCatalog());
  }

  void _onFlagsChanged() {
    if (!_catalogShown || _catalogLoading) return;
    if (widget.services.flags.operatorGeo == _catalogGeo) return;
    unawaited(_loadCatalog());
  }

  /// Once per opening, and again when the operator geo changes; the service
  /// answers from its own cache for a while, so reopening the panel is not
  /// a request.
  Future<void> _loadCatalog() async {
    final geo = widget.services.flags.operatorGeo;
    setState(() {
      _catalogGeo = geo;
      _catalogLoading = true;
    });
    final entries = await widget.services.catalog.fetchCatalog(geo: geo);
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
    widget.services.settings.removeListener(_onSettingsChanged);
    _searchController.dispose();
    super.dispose();
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
    // NOT set around the picker and the consent screen: `_applying` shows
    // "applying changes…" and blocks the list, and the operator is going to
    // spend that time browsing their filesystem and reading a dialog.
    final name = await installExtensionFromFile(
      context,
      store: store,
      commit: (bundle) async {
        if (mounted) setState(() => _applying = true);
        try {
          await services.extensions.installBundle(bundle);
        } finally {
          if (mounted) setState(() => _applying = false);
        }
      },
    );
    if (name == null) return; // cancelled, or refused with its own dialog
    services.track('extension_installed', {});
    if (mounted) {
      services.statusBar.setMessage(key: 'extensions:installed', text: t.extensionsPanel.installedMessage(name: name));
    }
  }

  /// Install or Update from the catalog: the shared path (installFromCatalog),
  /// with this panel's applying state driven around the commit.
  Future<void> _installFromCatalog(CatalogEntry entry) => installFromCatalog(
        context,
        services: widget.services,
        release: entry.release,
        commit: (bundle) async {
          if (mounted) setState(() => _applying = true);
          try {
            await widget.services.extensions.installBundle(bundle);
          } finally {
            if (mounted) setState(() => _applying = false);
          }
        },
      );

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
        widget.services.statusBar
            .setMessage(key: 'extensions:uninstall', text: t.extensionsPanel.uninstallFailed(name: name));
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
    final rowInset =
        ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: settingsRowInset);
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

        final categories = extensionCategoriesIn({for (final info in visible) info.category ?? 'other'});

        // What the catalog is compared against: the keys the app ships (a
        // catalog entry for one is "Built in", never installable) and the
        // installed store's versions (a higher catalog version is an Update).
        final builtInKeys = {
          for (final info in extensionService.availableExtensions)
            if (info.source == ExtensionSource.asset) info.key,
        };
        final installedVersions = {
          for (final info in extensionService.availableExtensions)
            if (info.isInstalled) info.key: info.version,
        };
        final catalogByKey = {for (final entry in _catalog ?? const <CatalogEntry>[]) entry.key: entry};
        final pendingUpdates = widget.services.catalogUpdateCheck.pendingUpdates;
        // The badge follows the section: the Update button it points at is
        // a catalog row, and a check that ran before the experiment was
        // flipped off would otherwise leave a badge with nowhere to go.
        bool hasUpdate(String key) =>
            _catalogShown &&
            ((catalogByKey[key]?.isNewerThan(installedVersions[key]) ?? false) ||
                (pendingUpdates[key]?.isNewerThan(installedVersions[key]) ?? false));

        final overrides = settings.extensionOverrides;
        final revoked = settings.extensionRevoked;
        final rows = <Widget>[];
        for (final category in categories) {
          final inCategory = [for (final info in visible) if ((info.category ?? 'other') == category) info];
          if (inCategory.isEmpty) continue;
          rows.add(SectionHeader(extensionCategoryTitle(category)));
          for (final info in inCategory) {
            final enabled = overrides[info.key] ?? info.enabledByDefault;
            // The extension's own icon (build-index `icon`, mirroring its
            // hooks) when it has one; the category icon otherwise.
            final icon = Icon(info.icon != null ? resolveIconName(info.icon) : extensionCategoryIcon(info.category));
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
              rows.add(SwitchListTile(
                key: rowKey,
                secondary: icon,
                title: title,
                subtitle: description == null ? null : Text(description),
                value: enabled,
                onChanged: toggle,
                mouseCursor: SystemMouseCursors.click,
              ));
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
            rows.add(ListTile(
              key: rowKey,
              leading: icon,
              title: title,
              subtitle: Text([
                t.extensionsPanel.installedBadge,
                if (isRevoked) t.extensionsPanel.revokedBadge,
                if (hasUpdate(info.key)) t.extensionsPanel.updateAvailableBadge,
                if (revokedNote.isNotEmpty) revokedNote,
                ?description,
              ].join(' · ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(MdiIcons.trashCanOutline, semanticLabel: t.extensionsPanel.uninstallAction),
                    onPressed: () => unawaited(_uninstall(info)),
                  ),
                  if (!isRevoked) Switch(value: enabled, onChanged: toggle),
                ],
              ),
            ));
          }
        }

        // The catalog, under the app's own categories. The search field
        // filters it like everything above; a query that matches nothing in
        // it hides the section the way an emptied category loses its header.
        final catalogRows = <CatalogEntry>[];
        if (_catalogShown && _catalog != null) {
          catalogRows.addAll(_orderedCatalog(_catalog!, widget.services.flags.operatorGeo, locale));
          if (query.isNotEmpty) catalogRows.retainWhere((entry) => entry.matchesSearch(query, locale: locale));
        }
        if (_catalogShown && (query.isEmpty || catalogRows.isNotEmpty)) {
          rows.add(SectionHeader(t.extensionsPanel.catalogSection));
          if (_catalogLoading) {
            rows.add(_CatalogStatusLine(t.extensionsPanel.catalogLoading));
          } else if (_catalog == null) {
            rows.add(_CatalogStatusLine(t.extensionsPanel.catalogUnreachable));
          }
          final store = extensionService.installed;
          for (final entry in catalogRows) {
            final description = entry.descriptionFor(locale);
            final installedVersion = installedVersions[entry.key];
            final Widget action;
            if (builtInKeys.contains(entry.key)) {
              action = _CatalogState(t.extensionsPanel.builtIn);
            } else if (installedVersions.containsKey(entry.key) && !entry.isNewerThan(installedVersion)) {
              action = _CatalogState(t.extensionsPanel.installedBadge);
            } else {
              // Disabled until the store exists, like Install from file: a
              // press before then has nothing to install into. `_applying`
              // is the IgnorePointer's job, not a disabled button's.
              action = FilledButton(
                onPressed: store == null ? null : () => unawaited(_installFromCatalog(entry)),
                child: Text(installedVersion != null ? t.extensionsPanel.updateAction : t.extensionsPanel.installAction),
              );
            }
            rows.add(ListTile(
              key: ValueKey('catalog-${entry.key}'),
              leading: Icon(entry.icon != null ? resolveIconName(entry.icon) : extensionCategoryIcon(entry.category)),
              title: Text(entry.nameFor(locale)),
              subtitle: description == null ? null : Text(description),
              trailing: action,
            ));
          }
        }

        final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: rowInset.add(const EdgeInsets.only(top: Space.lg, bottom: Space.xl)),
              child: TextField(
                selectAllOnFocus: false,
                key: const ValueKey('extensions-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
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
            Expanded(
              child: IgnorePointer(
                ignoring: _applying,
                child: rows.isEmpty
                    ? Center(child: Text(t.extensionsPanel.noMatches))
                    : ListView(
                        // Without this the row a click lands on is not the row
                        // under the pointer — the web's accessibility DOM
                        // keeps the pre-filter geometry (docs/quirks.md, where
                        // this was measured). The row set, not the query: an
                        // uninstall, an install and an experiment flip each
                        // change the rows with the query untouched, while a
                        // toggle changes neither and must not remount. The
                        // catalog rows are rows too: the fetch resolving
                        // changes the set as surely as an install does.
                        key: listContentsKey([
                          for (final info in visible) info.key,
                          for (final entry in catalogRows) 'catalog:${entry.key}',
                        ]),
                        padding: const EdgeInsets.only(bottom: Space.md),
                        children: rows,
                      ),
              ),
            ),
            // Below the list, not above it: installing is rare next to
            // finding and toggling, which is what the search field at the top
            // is for. Hidden in a hook-filtered panel, which is asking a
            // narrower question than "what do I have".
            if (widget.onlyHook == null && InstalledExtensions.isSupported)
              Padding(
                padding: rowInset.add(const EdgeInsets.only(top: Space.md, bottom: Space.md)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(MdiIcons.plus, size: 18),
                    label: Text(t.extensionsPanel.installFromFile),
                    // Disabled until the store exists — it is built on the
                    // first loadAvailableExtensions, and a press before that
                    // has nothing to install into.
                    onPressed: _applying || extensionService.installed == null ? null : () => unawaited(_install()),
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
                cancel: TextButton(
                  onPressed: _applying ? null : () => Navigator.of(context).maybePop(),
                  child: Text(t.common.done),
                ),
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

  /// The three tiers of the catalog's own ordering rule: what the operator's
  /// callsign is in the audience of, what is for everyone, and the rest —
  /// alphabetical within each. With no callsign known yet there is no first
  /// tier: worldwide leads, and every gated entry follows.
  static List<CatalogEntry> _orderedCatalog(List<CatalogEntry> entries, OperatorGeo? operator, String locale) {
    int tier(CatalogEntry entry) {
      final geo = entry.geo;
      if (geo == null || geo.isWorldwide) return 1;
      return operator != null && geo.matchesOperator(operator) ? 0 : 2;
    }

    final tiers = {for (final entry in entries) entry.key: tier(entry)};
    return [...entries]..sort((a, b) {
        final byTier = tiers[a.key]!.compareTo(tiers[b.key]!);
        if (byTier != 0) return byTier;
        return a.nameFor(locale).toLowerCase().compareTo(b.nameFor(locale).toLowerCase());
      });
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
      commit: (bundle) async {
        if (mounted) setState(() => _applying = true);
        try {
          await services.extensions.installBundle(bundle);
        } finally {
          if (mounted) setState(() => _applying = false);
        }
      },
    );
    if (name == null) return;
    services.track('extension_installed', {});
    if (mounted) {
      services.statusBar.setMessage(key: 'extensions:installed', text: t.extensionsPanel.installedMessage(name: name));
    }
  }
}

/// One line under the Catalog header that is not a row — loading, or
/// unreachable — at the rows' own inset, the way the search field takes it.
class _CatalogStatusLine extends StatelessWidget {
  final String text;

  const _CatalogStatusLine(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowInset =
        ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: settingsRowInset);
    return Padding(
      padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.md)),
      child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

/// A catalog row's trailing state when there is nothing to do: "Built in",
/// or "Installed" and current.
class _CatalogState extends StatelessWidget {
  final String text;

  const _CatalogState(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}
