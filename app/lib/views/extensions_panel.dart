// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Extension Management (Issue #25): enable/disable the optional extensions,
// grouped per category, with a search/filter field pinned at the BOTTOM.
// Core (always-enabled) extensions are never listed. Metadata comes from
// the build index (ExtensionService.loadAvailableExtensions — readable
// even when the runtime is down); the enabled state is the overrides map
// in SettingsService.extensionOverrides, applied by restarting the
// extension runtime with the filtered bundle set.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';

/// Category display order; anything unrecognized lands in "other".
const _categoryOrder = ['activity', 'lookup'];

class ExtensionsPanel extends StatefulWidget {
  final HaLoServices services;

  const ExtensionsPanel({super.key, required this.services});

  @override
  State<ExtensionsPanel> createState() => ExtensionsPanelState();
}

class ExtensionsPanelState extends State<ExtensionsPanel> {
  final _searchController = TextEditingController();

  /// True while a toggle's runtime restart is applying — all switches
  /// disable and a progress row shows, then everything re-enables.
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // Usually already memoized by the runtime boot; on a broken runtime
    // this is what still populates the panel.
    widget.services.extensions.loadAvailableExtensions().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  String _categoryTitle(String category) => switch (category) {
        'activity' => t.extensionsPanel.categoryActivity,
        'lookup' => t.extensionsPanel.categoryLookup,
        _ => t.extensionsPanel.categoryOther,
      };

  IconData _categoryIcon(String? category) => switch (category) {
        'activity' => Icons.explore_outlined,
        'lookup' => Icons.person_search_outlined,
        _ => Icons.extension_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final safeLeft = PaneSafeArea.leftOf(context);
    final query = _searchController.text.trim().toLowerCase();

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final listed = widget.services.extensions.availableExtensions.where((info) => !info.core).toList();
        final visible = query.isEmpty
            ? listed
            : [
                for (final info in listed)
                  if (info.name.toLowerCase().contains(query) ||
                      info.key.toLowerCase().contains(query) ||
                      (info.description ?? '').toLowerCase().contains(query))
                    info,
              ];

        // Fixed category order, then whatever else appears.
        final categories = <String>[
          ..._categoryOrder,
          ...{for (final info in visible) info.category ?? 'other'}.where((c) => !_categoryOrder.contains(c)),
        ];

        final overrides = settings.extensionOverrides;
        final rows = <Widget>[];
        for (final category in categories) {
          final inCategory = [for (final info in visible) if ((info.category ?? 'other') == category) info];
          if (inCategory.isEmpty) continue;
          rows.add(Padding(
            padding: EdgeInsets.only(left: safeLeft),
            child: SectionHeader(_categoryTitle(category)),
          ));
          for (final info in inCategory) {
            rows.add(SwitchListTile(
              // Stable identity: without keys, list churn during the
              // applying rebuilds re-creates row elements and their icons
              // visibly flicker.
              key: ValueKey('extension-${info.key}'),
              // The extension's own icon (build-index `icon`, mirroring its
              // hooks) when it has one; the category icon otherwise.
              secondary: Icon(info.icon != null ? resolveIconName(info.icon) : _categoryIcon(info.category)),
              title: Text(info.name),
              subtitle: info.description == null ? null : Text(info.description!),
              value: overrides[info.key] ?? info.enabledByDefault,
              // NOT disabled while applying (onChanged: null would repaint
              // every tile in disabled grey — the "icons fade to white"
              // flicker); the IgnorePointer below blocks input instead, so
              // the rows keep their exact appearance.
              onChanged: (enabled) => unawaited(_toggle(info.key, enabled)),
              mouseCursor: SystemMouseCursors.click,
            ));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: _applying,
                child: rows.isEmpty
                    ? Center(child: Text(t.extensionsPanel.noMatches))
                    : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: rows),
              ),
            ),
            if (_applying)
              Padding(
                padding: EdgeInsets.fromLTRB(16 + safeLeft, 8, 16, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t.extensionsPanel.applying)),
                  ],
                ),
              ),
            // The issue asks for the search field at the BOTTOM — thumb
            // reach on mobile, and the list stays put while filtering.
            Padding(
              padding: EdgeInsets.fromLTRB(16 + safeLeft, 8, 16, 16),
              child: TextField(
                key: const ValueKey('extensions-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear',
                          onPressed: () => setState(() => _searchController.clear()),
                        ),
                  hintText: t.extensionsPanel.searchHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
