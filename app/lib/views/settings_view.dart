// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App-wide settings: appearance, QRZ.com credentials, and about/version —
// a small, single-screen start (no app-polo-style nested settings stack;
// there's nowhere near enough settings yet to need one).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';

import '../config/experiments.dart';
import '../config/release_notes.dart';
import '../config/user_agent.dart';
import '../config/version.dart';
import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/data_file_manager.dart';
import '../services/deep_link_service.dart';
import '../services/extension_service.dart';
import '../services/settings_service.dart';
import '../tools/form_chrome_labels.dart';
import 'header_profile_label.dart';
import '../settings/settings_registry.dart';
import 'experiments_pane.dart';
import 'extensions_panel.dart';
import 'ham2k_logo.dart';
import 'notice_history_view.dart';
import 'operation_dialogs.dart';
import 'release_overlay.dart';
import 'switch_accounts_dialog.dart';
import 'version_label.dart';

/// A sidebar entry: `key` identifies it (a fixed core key, or an
/// extension's `panelKey`); `descriptor` is null for core panels and the
/// raw `getSettingsPanels()` entry for extension-contributed ones (needed
/// downstream by `_buildPanelContent` to route the definition fetch).
/// `order` places it among every other panel — core and extension-
/// contributed alike sort together by this one value.
class _SettingsPanelEntry {
  final String key;
  final String title;
  final IconData icon;
  final int order;
  final Map<String, dynamic>? descriptor;

  /// Panel-screen AppBar title, when the sidebar title carries extra state
  /// (Profiles' "Callsign: KI2D") that would read oddly as a heading.
  final String? screenTitle;

  /// When set, appended to [title] on the sidebar row as `: value` with the
  /// value in the mono font — used for the operator callsign, which reads as
  /// a callsign rather than prose.
  final String? monoDetail;

  /// Second-line description shown under the title in the sidebar list.
  /// Null for extension-contributed panels (the extension SDK's panel
  /// descriptor has no description field), which stay single-line.
  final String? description;

  const _SettingsPanelEntry({
    required this.key,
    required this.title,
    required this.icon,
    required this.order,
    this.descriptor,
    this.screenTitle,
    this.monoDetail,
    this.description,
  });

  String get effectiveScreenTitle => screenTitle ?? title;
}

// A function of the current translations (not a const list) so the sidebar
// follows the app locale like the panel bodies do.
List<_SettingsPanelEntry> _fixedCorePanels(Translations t) => [
      // The whitelisted subset of the declarative settings registry (see
      // settings_registry.dart); the full set lives under All Settings.
      _SettingsPanelEntry(
          key: 'settings',
          title: t.settings.panels.commonPreferences,
          icon: Icons.tune,
          order: 0,
          description: t.settings.panels.commonPreferencesDescription),
      // Immediately after Common Preferences: every declared group — core,
      // sync, and extension — in one place.
      _SettingsPanelEntry(
          key: 'all_settings',
          title: t.settings.panels.allSettings,
          icon: Icons.settings,
          order: 5,
          description: t.settings.panels.allSettingsDescription),
      _SettingsPanelEntry(
          key: 'sync',
          title: t.settings.sync.title,
          icon: Icons.sync,
          order: 10,
          description: t.settings.panels.syncDescription),
      _SettingsPanelEntry(
          key: 'accounts',
          title: t.settings.accounts.title,
          icon: Icons.vpn_key,
          order: 20,
          description: t.settings.panels.accountsDescription),
      _SettingsPanelEntry(
          key: 'extensions',
          title: t.settings.panels.extensions,
          icon: Icons.extension,
          order: 40,
          description: t.settings.panels.extensionsDescription),
    ];
// Before Common Preferences (order 0) — the Profiles panel leads the list.
// Internally "profiles"; until multi-profile features are enabled it
// presents itself as just "Callsign".
const _profilesPanelOrder = -10;
const _developerPanelOrder = 90;
const _aboutPanelOrder = 100;
const _extensionPanelDefaultOrder = 50;

class SettingsView extends StatefulWidget {
  /// Settings' arrangement is fixed (docs/design/layouts.md): its split
  /// opts into the "surfaces" divider style below.
  static const layoutPolicy = ViewLayoutPolicy.fixed;

  final HaLoServices services;
  final String? initialPanel;

  const SettingsView({super.key, required this.services, this.initialPanel});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late String _selectedPanel;
  List<Map<String, dynamic>> _extensionPanels = [];
  // Extension-contributed panels only appear in _buildPanelEntries once
  // _loadExtensionPanels's bridge call resolves. Until then, the wide-layout
  // auto-correct below must not treat a selected-but-not-yet-loaded panel
  // key as gone and snap the selection elsewhere — so it's gated on this
  // flag.
  bool _extensionPanelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _selectedPanel = widget.initialPanel ?? 'settings';
    _loadExtensionPanels();
    // A runtime restart (extension enabled/disabled) changes which panels
    // exist — re-fetch so a disabled extension's panel disappears (the
    // missing-selection auto-correct below handles it being selected).
    widget.services.extensions.runtimeGeneration.addListener(_loadExtensionPanels);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_loadExtensionPanels);
    super.dispose();
  }

  Future<void> _loadExtensionPanels() async {
    await widget.services.extensions.start();
    final panels = await widget.services.extensions.getSettingsPanels();
    if (!mounted) return;
    // The extension runtime failing to start is the one failure mode that's
    // both detectable here and not already self-reported elsewhere (a
    // single misbehaving extension's getPanels() failing is caught and
    // isolated per-hook, so it only silently drops its own panels — no
    // signal to surface for that). If the whole runtime never came up,
    // everything extension-contributed is missing with no other indication,
    // so show it rather than fail silently.
    if (!widget.services.extensions.ready) {
      widget.services.statusBar.showNotice(
        key: 'settings_extensions_unavailable',
        icon: 'alert-circle',
        title: t.settings.panels.unavailableTitle,
        text: t.settings.panels.unavailableText,
      );
    }
    if (mounted) {
      setState(() {
        _extensionPanels = panels;
        _extensionPanelsLoaded = true;
      });
    }
  }

  List<_SettingsPanelEntry> _buildPanelEntries(SettingsService settings, Translations t) {
    final operatorCall = settings.activeProfile.operatorCall;
    final entries = [
      _SettingsPanelEntry(
        key: 'profiles',
        title: t.common.callsign,
        monoDetail: operatorCall.isEmpty ? null : operatorCall,
        description: t.settings.panels.profilesDescription,
        screenTitle: t.settings.panels.stationProfiles,
        icon: resolveIconName('account'),
        order: _profilesPanelOrder,
      ),
      ..._fixedCorePanels(t),
      // After the extension-contributed panels (default order 50): data
      // files are contributed by extensions too, so they sit alongside
      // them. Not in _fixedCorePanels because its icon resolves an MDI
      // name at runtime.
      _SettingsPanelEntry(
        key: 'data_files',
        title: t.settings.panels.dataFiles,
        icon: resolveIconName('file-cabinet'),
        order: 60,
        description: t.settings.panels.dataFilesDescription,
      ),
      for (final p in _extensionPanels)
        _SettingsPanelEntry(
          key: p['panelKey'] as String,
          title: (p['title'] as String?) ?? (p['panelKey'] as String),
          icon: resolveIconName(p['icon'] as String?),
          order: (p['order'] as num?)?.toInt() ?? _extensionPanelDefaultOrder,
          descriptor: p,
        ),
      if (settings.developerMode)
        _SettingsPanelEntry(
          key: 'developer',
          title: t.settings.panels.developerSettings,
          icon: Icons.bug_report,
          order: _developerPanelOrder,
          description: t.settings.panels.developerSettingsDescription,
        ),
      _SettingsPanelEntry(
          key: 'about',
          title: t.settings.panels.about,
          icon: Icons.info,
          order: _aboutPanelOrder,
          description: t.settings.panels.aboutDescription),
    ];
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return ListenableBuilder(listenable: settings, builder: (context, _) => _buildContent(context, settings));
  }

  Widget _buildContent(BuildContext context, SettingsService settings) {
    final bool isWide = ShirtSize.of(context).isTwoPane;

    final panels = _buildPanelEntries(settings, context.t);
    final selectionExists = panels.any((p) => p.key == _selectedPanel);
    final effectivePanel = selectionExists ? panels.firstWhere((p) => p.key == _selectedPanel) : panels.first;
    if (!selectionExists && _extensionPanelsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPanel = effectivePanel.key);
      });
    }

    if (isWide) {
      // Each side is its own Scaffold with its own AppBar, so the header
      // splits at the same draggable divider as the body. Only the LEFT
      // pane's AppBar reserves macOS traffic-light clearance — the right
      // one sits mid-window (layouts.md rule 5).
      return ResizableSplitView(
        // Settings is ViewLayoutPolicy.fixed and opts into the "surfaces"
        // divider: the selected panel reads as a surface under the sidebar's
        // shadow. See docs/design/layouts.md.
        dividerStyle: SplitDividerStyle.surfaces,
        // Fixed at 40% of the split's width — the sidebar isn't
        // user-resizable (issue #183 follow-up).
        resizable: false,
        primaryFraction: 0.4,
        minPrimaryWidth: 240,
        maxPrimaryWidth: idealPaneWidth,
        // Each pane owns its ScaffoldMessenger so a SnackBar (e.g. the
        // copy-version toast) shows only in the pane that raised it. Sharing
        // the root messenger — which both pane Scaffolds otherwise register
        // with — makes one SnackBar appear in both halves of the split.
        primary: ScaffoldMessenger(
          child: Scaffold(
            appBar: AppBar(
              flexibleSpace: windowHeaderGestureArea(),
              leadingWidth: macOSAwareLeadingWidth(context),
              leading: macOSAwareBackButton(context),
              title: shrinkToFitText(Text(context.t.settings.title)),
            ),
            body: _buildSidebar(context, isWide: true, panels: panels, selectedKey: effectivePanel.key),
          ),
        ),
        // The Builder gets a context under the split's PaneSafeArea: the
        // whole right panel — title included — shifts right by the grab
        // strip's clearance, keeping the AppBar title aligned with the
        // panel elements below it.
        secondary: Builder(builder: (context) {
          final safeLeft = PaneSafeArea.leftOf(context);
          return ScaffoldMessenger(
            child: Scaffold(
            appBar: AppBar(
              flexibleSpace: windowHeaderGestureArea(),
              // Centered to match each panel's own content below, which
              // centers (rather than pins left) at the same idealPaneWidth
              // cap — see _buildPanelContent.
              centerTitle: true,
              title: shrinkToFitText(Text(effectivePanel.effectiveScreenTitle)),
              automaticallyImplyLeading: false,
              actions: [
                HeaderProfileLabel(settings: widget.services.settings),
                windowsCaptionSpacer(context),
              ],
            ),
            // No ambient left Padding here (that would inset the whole
            // body — row backgrounds/dividers included — same mistake
            // operation_view.dart's OperationSettingsPanel comment warns
            // against). Each panel insets its own row CONTENT instead, via
            // this ListTileTheme default (ListTile-based panels) or its own
            // explicit padding (panels that aren't ListTile-based) — so
            // row backgrounds and dividers still reach the pane's true
            // edge, right up to the grab-strip clearance this cancels.
            body: ListTileTheme.merge(
              contentPadding: EdgeInsets.only(left: 16 + safeLeft, right: 16),
              child: _buildPanelContent(effectivePanel, widget.services),
            ),
          ),
          );
        }),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: windowHeaderGestureArea(),
          leadingWidth: macOSAwareLeadingWidth(context),
          leading: macOSAwareBackButton(context),
          title: shrinkToFitText(Text(context.t.settings.title)),
          actions: [
            HeaderProfileLabel(settings: widget.services.settings),
            windowsCaptionSpacer(context),
          ],
        ),
        body: _buildSidebar(context, isWide: false, panels: panels, selectedKey: effectivePanel.key),
      );
    }
  }

  Widget _buildSidebar(
    BuildContext context, {
    required bool isWide,
    required List<_SettingsPanelEntry> panels,
    required String selectedKey,
  }) {
    // The status footer no longer reserves the home indicator globally (it
    // collapses when empty), so the list clears the bottom safe area itself;
    // the Scaffold canvas fills behind it.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: ListView.builder(
      itemCount: panels.length,
      itemBuilder: (context, index) {
        final panel = panels[index];
        final isSelected = isWide && selectedKey == panel.key;

        // A panel with a monoDetail (the operator callsign) shows it in a
        // monospace face after the title, e.g. "Callsign: KI2D". Titles are
        // bold, matching the app's other list rows.
        final mono = panel.monoDetail;
        const titleStyle = TextStyle(fontWeight: FontWeight.bold);
        final Widget titleWidget = (mono != null && mono.isNotEmpty)
            ? Text.rich(
                TextSpan(
                  text: '${panel.title}: ',
                  children: [TextSpan(text: mono, style: const TextStyle(fontFamily: 'RobotoMono'))],
                ),
                style: titleStyle,
              )
            : Text(panel.title, style: titleStyle);

        return ListTile(
          selected: isSelected,
          leading: Icon(panel.icon),
          title: titleWidget,
          subtitle: panel.description == null ? null : Text(panel.description!),
          onTap: () {
            setState(() {
              _selectedPanel = panel.key;
            });
            if (!isWide) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _SettingsPanelScreen(panel: panel, services: widget.services),
                ),
              );
            }
          },
          mouseCursor: SystemMouseCursors.click,
        );
      },
      ),
    );
  }
}

class _SettingsPanelScreen extends StatelessWidget {
  final _SettingsPanelEntry panel;
  final HaLoServices services;

  const _SettingsPanelScreen({required this.panel, required this.services});

  @override
  Widget build(BuildContext context) {
    if (ShirtSize.of(context).isTwoPane) {
      // Remove THIS screen's route specifically — Navigator.pop() takes the
      // top-most route, which may be a Modal Pane stacked above (an account
      // pane opened from a panel on a narrow window): popping that instead
      // would destroy the pane mid-edit on a resize it's designed to
      // survive. removeRoute leaves anything above this screen intact.
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route != null && route.isActive && !route.isFirst) {
          Navigator.of(context).removeRoute(route);
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: windowHeaderGestureArea(),
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: macOSAwareBackButton(context),
        // Centered to match the panel's own content below — see
        // _buildPanelContent.
        centerTitle: true,
        title: shrinkToFitText(Text(panel.effectiveScreenTitle)),
        actions: [
          HeaderProfileLabel(settings: services.settings),
          windowsCaptionSpacer(context),
        ],
      ),
      body: _buildPanelContent(panel, services),
    );
  }
}

Widget _buildPanelContent(_SettingsPanelEntry panel, HaLoServices services) {
  final Widget content;
  switch (panel.key) {
    case 'profiles':
      content = _ProfilesPanel(services: services);
    case 'settings':
      content = _CommonSettingsPanel(services: services);
    case 'extensions':
      content = ExtensionsPanel(services: services);
    case 'all_settings':
      content = _AllSettingsPanel(services: services);
    case 'sync':
      content = _SyncPanel(services: services);
    case 'accounts':
      content = _AccountsPanel(services: services);
    case 'data_files':
      content = _DataFilesPanel(services: services);
    case 'developer':
      content = _DeveloperPanel(services: services);
    case 'about':
      content = _AboutPanel(services: services);
    default:
      final descriptor = panel.descriptor;
      content = descriptor == null
          ? const SizedBox.shrink()
          : _ExtensionSettingsPanel(services: services, descriptor: descriptor);
  }
  // About manages its own width (see _AboutPanel): the header photo spans
  // the pane's full true width edge-to-edge, while its rows below cap at
  // idealPaneWidth and center, same as every other panel below — so it
  // must not also get the blanket cap-and-center wrapper below.
  if (panel.key == 'about') {
    return SafeArea(top: false, left: false, right: false, child: content);
  }
  // Cap settings content at the ideal reading width, centered in the pane
  // rather than stretching across (or pinning to one edge of) a wide one.
  // The SafeArea sits inside the cap: each panel's scroll view clears the
  // bottom safe area itself now that the status footer no longer reserves
  // the home indicator globally.
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: idealPaneWidth),
      child: SafeArea(top: false, left: false, right: false, child: content),
    ),
  );
}

/// The "profiles" panel — callsign profiles. Until multi-profile features
/// are enabled it presents itself as just "Callsign": a single field, saved
/// as the default profile's `operatorCall` (see [SettingsService.activeProfile]).
class _ProfilesPanel extends StatelessWidget {
  final HaLoServices services;

  const _ProfilesPanel({required this.services});

  Future<void> _editCallsign(BuildContext context) async {
    final result = await editOneFieldDialog(
      context,
      title: context.t.common.callsign,
      fieldLabel: context.t.common.callsign,
      fieldInitial: services.settings.activeProfile.operatorCall,
      fieldCapitalization: TextCapitalization.characters,
    );
    if (result == null) return;
    await services.setOperatorCall(result);
  }

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final call = settings.activeProfile.operatorCall;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              leading: Icon(resolveIconName('account')),
              title: Text(context.t.common.callsign),
              subtitle: Text(call.isEmpty ? context.t.settings.profiles.notSet : call),
              onTap: () => _editCallsign(context),
              mouseCursor: SystemMouseCursors.click,
            ),
          ],
        );
      },
    );
  }
}

/// One declared settings group rendered as an autosaving form: the group's
/// title as a section header, then its elements. Values refresh whenever
/// the group's [SettingsGroup.listenable] fires (a keyboard shortcut, the
/// "..." menu, another panel) — same external-change contract as
/// [_ExtensionSettingsPanel], including its reload coalescing (commit
/// notifies SettingsService synchronously, mid-autosave).
class _SettingsGroupForm extends StatefulWidget {
  final HaLoServices services;
  final SettingsGroup group;

  /// Element keys to keep — the Common Preferences whitelist. Null shows all.
  final Set<String>? fieldFilter;

  /// All Settings' search query (lowercased); when it matches nothing in
  /// this group, the whole section — header included — renders empty.
  final String searchQuery;

  const _SettingsGroupForm({
    required this.services,
    required this.group,
    this.fieldFilter,
    this.searchQuery = '',
  });

  @override
  State<_SettingsGroupForm> createState() => _SettingsGroupFormState();
}

class _SettingsGroupFormState extends State<_SettingsGroupForm> {
  List<Map<String, dynamic>>? _elements;
  bool _reloading = false;
  bool _reloadPending = false;

  @override
  void initState() {
    super.initState();
    _load();
    widget.group.listenable?.addListener(_load);
  }

  @override
  void dispose() {
    widget.group.listenable?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_reloading) {
      _reloadPending = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadPending = false;
        var elements = await widget.services.systemLists.resolveInElements(await widget.group.buildElements());
        final filter = widget.fieldFilter;
        if (filter != null) {
          elements = [
            for (final el in elements)
              if (filter.contains(el['key'])) el,
          ];
        }
        if (mounted) setState(() => _elements = elements);
      } while (_reloadPending && mounted);
    } finally {
      _reloading = false;
    }
  }

  Future<Map<String, dynamic>?> _autosave(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    await widget.group.commit(fieldKey, value);
    // Re-fetch so value-dependent icons/descriptions (theme icon, consent
    // wording) follow the new value.
    if (mounted) await _load();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var elements = _elements;
    if (elements == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (widget.searchQuery.isNotEmpty) {
      elements = [
        for (final el in elements)
          if (_elementMatchesQuery(el, widget.searchQuery)) el,
      ];
      if (elements.isEmpty) return const SizedBox.shrink();
    }
    return FormRenderer(
      formDefinition: {
        'elements': [
          {'type': 'header', 'title': widget.group.title, 'style': 'section'},
          ...elements,
        ],
      },
      initialState: const {},
      showActions: false,
      showTitle: false,
      developerMode: widget.services.settings.developerMode,
      labels: formRendererLabelsFor(context.t),
      onChange: _autosave,
      onOpenLink: _openLink,
      onSubmit: (_) {},
      onCancel: () {},
    );
  }
}

void _openLink(String url) {
  unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
}

/// The All Settings search predicate: does this element's key, label
/// (title), or description mention [query]? Chrome elements (headers,
/// dividers, markdown) never match — while filtering, only the settings
/// themselves show.
bool _elementMatchesQuery(Map<String, dynamic> el, String query) {
  if (query.isEmpty) return true;
  final type = el['type'];
  if (type != 'field' && type != 'link' && type != 'action') return false;
  bool has(dynamic v) => v is String && v.toLowerCase().contains(query);
  return has(el['key']) || has(el['label']) || has(el['description']);
}

/// The whitelisted subset of the settings registry ([commonSettingsFields])
/// — the panel most users ever need.
class _CommonSettingsPanel extends StatelessWidget {
  final HaLoServices services;

  const _CommonSettingsPanel({required this.services});

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final group in services.settingsRegistry.groups) {
      final prefix = '${group.key}.';
      final keys = {
        for (final id in commonSettingsFields)
          if (id.startsWith(prefix)) id.substring(prefix.length),
      };
      if (keys.isEmpty) continue;
      sections.add(_SettingsGroupForm(services: services, group: group, fieldFilter: keys));
    }
    // FormRenderer rows zero their own contentPadding, so the wide layout's
    // grab-strip clearance must come from this panel's padding (layouts.md).
    final safeLeft = PaneSafeArea.leftOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16 + safeLeft, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final section in sections) ...[section, const SizedBox(height: 24)]],
      ),
    );
  }
}

/// Every declared settings group — core and sync from the registry, then
/// each extension-contributed panel as its own `extension_{panelKey}`
/// section (full validate/transform/commit behavior via
/// [_ExtensionSettingsPanel] in embedded mode).
class _AllSettingsPanel extends StatefulWidget {
  final HaLoServices services;

  const _AllSettingsPanel({required this.services});

  @override
  State<_AllSettingsPanel> createState() => _AllSettingsPanelState();
}

class _AllSettingsPanelState extends State<_AllSettingsPanel> {
  List<Map<String, dynamic>>? _extensionPanels;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExtensionPanels();
    // Extension toggles restart the runtime with a different panel set.
    widget.services.extensions.runtimeGeneration.addListener(_loadExtensionPanels);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_loadExtensionPanels);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExtensionPanels() async {
    await widget.services.extensions.start();
    final panels = await widget.services.extensions.getSettingsPanels();
    if (mounted) setState(() => _extensionPanels = panels);
  }

  @override
  Widget build(BuildContext context) {
    final extensionPanels = _extensionPanels;
    final query = _searchController.text.trim().toLowerCase();
    // FormRenderer rows zero their own contentPadding, so the wide layout's
    // grab-strip clearance must come from this panel's padding (layouts.md).
    final safeLeft = PaneSafeArea.leftOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned above the scroll: filters every section below by setting
        // key, title, and description; sections with no match disappear
        // entirely, title included.
        Padding(
          padding: EdgeInsets.fromLTRB(16 + safeLeft, 16, 16, 0),
          child: TextField(
            key: const ValueKey('all-settings-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: context.t.settings.search.clear,
                      onPressed: () => setState(() => _searchController.clear()),
                    ),
              hintText: context.t.settings.search.hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16 + safeLeft, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in widget.services.settingsRegistry.groups) ...[
                  _SettingsGroupForm(services: widget.services, group: group, searchQuery: query),
                  const SizedBox(height: 24),
                ],
                if (extensionPanels == null)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else
                  for (final descriptor in extensionPanels) ...[
                    _ExtensionSettingsPanel(
                      services: widget.services,
                      descriptor: descriptor,
                      embedded: true,
                      sectionTitle: (descriptor['title'] as String?) ?? (descriptor['panelKey'] as String),
                      searchQuery: query,
                    ),
                    const SizedBox(height: 24),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncPanel extends StatefulWidget {
  final HaLoServices services;

  const _SyncPanel({required this.services});

  @override
  State<_SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends State<_SyncPanel> {
  Map<String, dynamic>? _syncAccount;
  bool _loadingSyncAccount = false;

  @override
  void initState() {
    super.initState();
    if (widget.services.settings.syncEnabled) {
      _refreshSyncAccount();
    }
  }

  Future<void> _refreshSyncAccount() async {
    if (!mounted) return;
    setState(() => _loadingSyncAccount = true);
    final account = await widget.services.extensions.syncAccountData();
    if (!mounted) return;
    setState(() {
      _syncAccount = account;
      _loadingSyncAccount = false;
    });
  }

  Future<void> _toggleSync(bool enabled) async {
    await widget.services.setSyncEnabled(enabled);
    if (enabled) {
      unawaited(_refreshSyncAccount());
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _switchAccounts() async {
    final linked = await showSwitchAccountsDialog(
      context,
      fetchAccountData: widget.services.extensions.syncAccountData,
      linkClient: widget.services.extensions.syncLinkClient,
      linkClientWithEmail: widget.services.extensions.syncLinkClientWithEmail,
    );
    if (linked == true) {
      // The server-side account just changed: run a round now so the
      // engine's account-identity gating raises the combine/replace banner
      // immediately instead of on the next loop tick.
      unawaited(widget.services.syncEngine.runOneRound());
      unawaited(_refreshSyncAccount());
    }
  }

  Future<void> _combineAccount() async {
    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.combine);
    if (mounted) setState(() {});
  }

  Future<void> _replaceAccount() async {
    final opCount = (await widget.services.operations.syncCounts()).total;
    final qsoCount = (await widget.services.qsos.syncCounts()).total;
    if (!mounted) return;

    final confirmed = await showHaloDialog<bool>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(context.t.settings.syncPanel.replaceDialogTitle),
        content: Text(
          context.t.settings.syncPanel.replaceDialogBody(
            operations: context.t.settings.syncPanel
                .replaceDialogOperations(count: opCount, n: formatNumber(opCount)),
            qsos: context.t.settings.syncPanel.replaceDialogQsos(count: qsoCount, n: formatNumber(qsoCount)),
          ),
        ),
        cancel: TextButton(
            onPressed: () => Navigator.of(context).pop(false), child: Text(context.t.common.cancel)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.t.settings.syncPanel.replace)),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.replace);
    if (mounted) setState(() {});
  }

  String get _syncAccountSubtitle {
    if (_loadingSyncAccount) return t.settings.syncPanel.checking;
    final account = _syncAccount?['current_account'] as Map?;
    final call = account?['call'] as String?;
    if (call == null || call.isEmpty) return t.settings.syncPanel.notLinked;
    final email = account?['email'] as String?;
    return (email == null || email.isEmpty)
        ? t.settings.syncPanel.linkedAs(call: call)
        : t.settings.syncPanel.linkedAsWithEmail(call: call, email: email);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final safeLeft = PaneSafeArea.leftOf(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
                padding: EdgeInsets.only(left: safeLeft),
                child: SectionHeader(context.t.settings.syncPanel.configuration)),
            // The operator-callsign row moved to the Station Profiles panel
            // (settings.activeProfile).
            SwitchListTile(
              secondary: Icon(resolveIconName(settings.syncEnabled ? 'cloud-sync' : 'cloud-off')),
              title: Text(context.t.settings.syncPanel.enableTitle),
              subtitle: Text(
                settings.syncEnabled
                    ? context.t.settings.syncPanel.enabledDescription
                    : context.t.settings.syncPanel.disabledDescription,
              ),
              value: settings.syncEnabled,
              onChanged: _toggleSync,
              mouseCursor: SystemMouseCursors.click,
            ),
            if (settings.syncState['pendingAccountUUID'] != null)
              _PendingAccountBanner(
                onCombine: _combineAccount,
                onReplace: _replaceAccount,
                extraLeftMargin: safeLeft,
              ),
            // The footer status bar isn't visible on this screen, so mirror
            // the backfill-progress item here while it's active.
            ListenableBuilder(
              listenable: widget.services.statusBar,
              builder: (context, _) {
                final progress = widget.services.statusBar.itemForKey(HaLoServices.syncProgressStatusKey);
                if (progress == null || !settings.syncEnabled) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(resolveIconName(progress.icon ?? 'cloud-sync')),
                  title: Text(progress.title ?? context.t.settings.syncPanel.syncing),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (progress.text != null) Text(progress.text!),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress.progressValue),
                    ],
                  ),
                );
              },
            ),
            if (settings.syncEnabled) ...[
              ListTile(
                leading: Icon(resolveIconName('account-check')),
                title: Text(context.t.settings.syncPanel.account),
                subtitle: Text(_syncAccountSubtitle),
                trailing: IconButton(
                  icon: Icon(resolveIconName('refresh')),
                  tooltip: context.t.settings.syncPanel.refresh,
                  onPressed: _refreshSyncAccount,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              ListTile(
                leading: Icon(resolveIconName('account-switch')),
                title: Text(context.t.settings.syncPanel.switchAccounts),
                subtitle: Text(context.t.settings.syncPanel.switchAccountsDescription),
                onTap: _switchAccounts,
                mouseCursor: SystemMouseCursors.click,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AccountsPanel extends StatefulWidget {
  final HaLoServices services;

  const _AccountsPanel({required this.services});

  @override
  State<_AccountsPanel> createState() => _AccountsPanelState();
}

class _AccountsPanelState extends State<_AccountsPanel> {
  List<Map<String, dynamic>>? _accounts;
  final Map<String, String> _accountIdentities = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await widget.services.extensions.start();
    final accounts = await widget.services.extensions.getAccounts();
    final identities = <String, String>{};
    for (final account in accounts) {
      final kvKey = account['kvKey'] as String;
      final creds = await widget.services.extensions.getAccountCredentials(kvKey);
      if (creds.isNotEmpty) {
        identities[kvKey] = ExtensionService.identityFromCredentials(creds) ?? t.settings.accounts.connected;
      }
    }
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _accountIdentities.clear();
        _accountIdentities.addAll(identities);
      });
    }
  }

  Future<void> _openAccountDialog(Map<String, dynamic> account) async {
    await showModalPane<void>(
      context,
      title: account['label'] as String,
      barrierDismissible: false,
      closeTooltip: context.t.common.close,
      builder: (context) => _AccountPane(services: widget.services, account: account, onSaved: _loadAccounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final safeLeft = PaneSafeArea.leftOf(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
            padding: EdgeInsets.only(left: safeLeft), child: SectionHeader(context.t.settings.accounts.title)),
        if (_accounts!.isEmpty)
          ListTile(title: Text(context.t.settings.accounts.none))
        else
          ..._accounts!.map((account) {
            final kvKey = account['kvKey'] as String;
            final label = account['label'] as String;
            final description = account['description'] as String?;
            final identity = _accountIdentities[kvKey];
            return ListTile(
              leading: Icon(MdiIcons.keyChain),
              title: Text.rich(TextSpan(children: [
                TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (identity != null) TextSpan(text: '  $identity'),
              ])),
              subtitle: Text(description ?? (identity == null ? context.t.settings.accounts.notConfigured : '')),
              onTap: () => _openAccountDialog(account),
              mouseCursor: SystemMouseCursors.click,
            );
          }),
      ],
    );
  }
}

/// The Data Files panel: every data file the enabled extensions register
/// (POTA parks, SOTA summits, callsign notes…), each showing when it was
/// last downloaded and a Refresh button that forces a fresh fetch. The list
/// re-loads when the extension runtime restarts (a toggle changes which
/// files exist). Country data (Big CTY) is bundled, not a downloaded data
/// file, so it doesn't appear here.
class _DataFilesPanel extends StatefulWidget {
  final HaLoServices services;

  const _DataFilesPanel({required this.services});

  @override
  State<_DataFilesPanel> createState() => _DataFilesPanelState();
}

class _DataFilesPanelState extends State<_DataFilesPanel> {
  List<DataFileStatus>? _files;
  final Set<String> _refreshing = {};

  @override
  void initState() {
    super.initState();
    _load();
    widget.services.extensions.runtimeGeneration.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await widget.services.extensions.start();
    final files = await widget.services.dataFiles.listDataFiles();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _refresh(DataFileStatus file) async {
    setState(() => _refreshing.add(file.key));
    try {
      // The stamped time comes back from the refresh, so the row updates
      // from it directly — no second listDataFiles round-trip.
      final updatedAt = await widget.services.dataFiles.refreshDataFile(file.key);
      if (mounted && updatedAt != null) _applyUpdatedAt(file.key, updatedAt);
    } catch (e) {
      if (mounted) {
        widget.services.statusBar.setMessage(
          key: 'dataFile:refresh',
          text: t.settings.offlineData.refreshFailed(name: file.name, error: e),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing.remove(file.key));
    }
  }

  void _applyUpdatedAt(String key, DateTime updatedAt) {
    final files = _files;
    if (files == null) return;
    final index = files.indexWhere((f) => f.key == key);
    if (index < 0) return;
    setState(() => _files = [...files]..[index] = files[index].withUpdatedAt(updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    if (files == null) return const Center(child: CircularProgressIndicator());
    final safeLeft = PaneSafeArea.leftOf(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
            padding: EdgeInsets.only(left: safeLeft), child: SectionHeader(context.t.settings.offlineData.title)),
        if (files.isEmpty)
          ListTile(
            title: Text(context.t.settings.offlineData.noFiles),
            subtitle: Text(context.t.settings.offlineData.noFilesDescription),
          )
        else
          for (final file in files) _buildRow(context, file),
      ],
    );
  }

  Widget _buildRow(BuildContext context, DataFileStatus file) {
    final icon = Icon(resolveIconName(file.icon ?? 'file-document-outline'));

    // While refreshing, mirror this data file's live status-bar progress
    // item (keyed `dataFile:$key`, set by DataFileManager) as the subtitle —
    // the footer status bar isn't visible on this screen.
    if (_refreshing.contains(file.key)) {
      return ListenableBuilder(
        listenable: widget.services.statusBar,
        builder: (context, _) {
          final progress = widget.services.statusBar.itemForKey('dataFile:${file.key}');
          return ListTile(
            leading: icon,
            title: Text(file.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progress?.text ?? context.t.settings.offlineData.refreshing),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: progress?.progressValue),
              ],
            ),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        },
      );
    }

    return ListTile(
      leading: icon,
      title: Text(file.name),
      subtitle: Text(_dataFileUpdatedLabel(file.updatedAt)),
      trailing: IconButton(
        icon: Icon(resolveIconName('refresh')),
        tooltip: context.t.settings.offlineData.refresh,
        onPressed: () => _refresh(file),
        mouseCursor: SystemMouseCursors.click,
      ),
    );
  }
}

/// "Updated 2d 7h ago" / "Never downloaded" — the same day+hour granularity
/// app-polo's data settings use.
String _dataFileUpdatedLabel(DateTime? updatedAt) {
  if (updatedAt == null) return t.settings.offlineData.neverDownloaded;
  final diff = DateTime.now().difference(updatedAt);
  if (diff.isNegative || diff.inSeconds < 60) return t.settings.offlineData.updatedJustNow;
  final days = diff.inDays;
  if (days > 0) {
    final hours = diff.inHours % 24;
    return hours == 0
        ? t.settings.offlineData.updatedDaysAgo(days: days)
        : t.settings.offlineData.updatedDaysHoursAgo(days: days, hours: hours);
  }
  final hours = diff.inHours;
  if (hours > 0) {
    final minutes = diff.inMinutes % 60;
    return minutes == 0
        ? t.settings.offlineData.updatedHoursAgo(hours: hours)
        : t.settings.offlineData.updatedHoursMinutesAgo(hours: hours, minutes: minutes);
  }
  return t.settings.offlineData.updatedMinutesAgo(minutes: diff.inMinutes);
}

/// Renders one extension-contributed `settingsPanel` panel — the
/// `descriptor` (from `getSettingsPanels()`) says which registration
/// (`hookKey`) and tier (`kind`) it is; `panelKey` disambiguates when a
/// Tier 2 registration serves more than one panel. `FormRenderer`'s
/// `onChange` is repurposed as the autosave point: validate, then (Tier 2
/// only) transform, then commit — nothing is persisted unless it passes
/// validation, but the field keeps whatever the user typed either way,
/// same as any other live form.
class _ExtensionSettingsPanel extends StatefulWidget {
  final HaLoServices services;
  final Map<String, dynamic> descriptor;

  /// Embedded: rendered as a shrink-wrapped section inside the All Settings
  /// scroll view instead of a standalone scrolling panel.
  final bool embedded;

  /// Section title rendered above the form in embedded mode — lives here
  /// (not in the parent) so a search query that empties this section hides
  /// its title along with it.
  final String? sectionTitle;

  /// All Settings' search query (lowercased); empty shows everything.
  final String searchQuery;

  const _ExtensionSettingsPanel({
    required this.services,
    required this.descriptor,
    this.embedded = false,
    this.sectionTitle,
    this.searchQuery = '',
  });

  @override
  State<_ExtensionSettingsPanel> createState() => _ExtensionSettingsPanelState();
}

class _ExtensionSettingsPanelState extends State<_ExtensionSettingsPanel> {
  Map<String, dynamic>? _definition;
  bool _loading = true;
  List<Map<String, dynamic>>? _accountsCache;

  // _load() is called from two places that can fire back-to-back for the
  // same underlying change: _autosave's own reload after a commit, and the
  // SettingsService listener below — committing a core setting notifies
  // listeners synchronously, mid-commit, before _autosave reaches its own
  // reload. Without this guard, one field edit fires two concurrent
  // getSettingsPanelDefinition bridge calls that race on `setState`. This
  // coalesces any _load() calls that arrive while one is already in flight
  // into a single extra pass once the current one finishes, instead of
  // running them in parallel.
  bool _reloading = false;
  bool _reloadPending = false;

  // FormRenderer always calls onChange (_autosave) and then validator
  // (_validate) back-to-back for the same (fieldKey, value) on every blur/
  // interaction — without this, each interaction would run
  // validateSettingsField's bridge call twice (autosave's own gate, then
  // FormRenderer's separate validator call) and, worse, the two calls could
  // disagree. Cache the one real result and let the second call reuse it.
  String? _lastValidatedFieldKey;
  dynamic _lastValidatedValue;
  String? _lastValidationError;

  String get _hookKey => widget.descriptor['hookKey'] as String;
  String get _panelKey => widget.descriptor['panelKey'] as String;
  String get _kind => widget.descriptor['kind'] as String;

  @override
  void initState() {
    super.initState();
    _load();
    // Picks up changes made outside this panel — e.g. font scale via
    // keyboard shortcuts (main.dart) — which call SettingsService directly
    // and never go through _autosave's own reload.
    widget.services.settings.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (_reloading) {
      _reloadPending = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadPending = false;
        var definition = await widget.services.extensions.getSettingsPanelDefinition(
          hookKey: _hookKey,
          panelKey: _panelKey,
          kind: _kind,
        );
        // Extension-declared fields can reference system lists too.
        if (definition?['elements'] is List) {
          definition = {
            ...definition!,
            'elements': await widget.services.systemLists
                .resolveInElements((definition['elements'] as List).cast<Map<String, dynamic>>()),
          };
        }
        if (mounted) {
          setState(() {
            _definition = definition;
            _loading = false;
          });
        }
      } while (_reloadPending && mounted);
    } finally {
      _reloading = false;
    }
  }

  Map<String, dynamic> _fieldFor(String fieldKey) {
    final elements = (_definition?['elements'] as List? ?? const []).cast<Map>();
    for (final el in elements) {
      if (el['type'] == 'field' && el['key'] == fieldKey) return el.cast<String, dynamic>();
    }
    return const {};
  }

  Future<String?> _validate(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    if (_lastValidatedFieldKey == fieldKey && _lastValidatedValue == value) {
      return _lastValidationError;
    }
    final error = await widget.services.extensions.validateSettingsField(
      kind: _kind,
      hookKey: _hookKey,
      panelKey: _panelKey,
      field: _fieldFor(fieldKey),
      fieldKey: fieldKey,
      value: value,
      state: state,
    );
    _lastValidatedFieldKey = fieldKey;
    _lastValidatedValue = value;
    _lastValidationError = error;
    return error;
  }

  Future<Map<String, dynamic>?> _autosave(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    if (await _validate(fieldKey, value, state) != null) return null;
    final field = _fieldFor(fieldKey);
    final committedValue = _kind == 'dynamic'
        ? await widget.services.extensions.transformSettingsField(
            hookKey: _hookKey,
            panelKey: _panelKey,
            fieldKey: fieldKey,
            value: value,
            state: state,
          )
        : value;
    await widget.services.extensions.commitSettingsFieldValue(
      kind: _kind,
      hookKey: _hookKey,
      panelKey: _panelKey,
      fieldKey: fieldKey,
      value: committedValue,
      state: state,
      isSecret: field['fieldType'] == 'secret',
    );
    // Re-fetch so the panel reflects whatever the commit actually changed —
    // not just this field's own value, but anything getDefinition derives
    // from it (a hook keying labels off ctx.locale, fields that appear/
    // disappear based on another field's value, etc.). _load() only shows
    // its loading spinner on the very first call (_loading starts true);
    // by now it's already false, so this swaps _definition in place with
    // no flash.
    if (mounted) await _load();
    return null;
  }

  Future<void> _manageAccount(String accountKey, String? subkey) async {
    if (subkey != null) {
      // No AccountHook registration today can produce more than one account
      // under the same kvKey, so there's nothing to disambiguate against
      // yet — surfaced rather than silently ignored (see
      // docs/extensions/settings.md's account field type note on subkey).
      debugPrint(
        '[settings] account field requested subkey "$subkey" for "$accountKey", but '
        'subkey-based account disambiguation is not implemented yet — matching by kvKey only.',
      );
    }
    final accounts = _accountsCache ??= await widget.services.extensions.getAccounts();
    Map<String, dynamic>? account;
    for (final a in accounts) {
      if (a['kvKey'] == accountKey) {
        account = a;
        break;
      }
    }
    if (account == null || !mounted) return;
    await showModalPane<void>(
      context,
      title: account['label'] as String,
      barrierDismissible: false,
      closeTooltip: context.t.common.close,
      builder: (context) => _AccountPane(
        services: widget.services,
        account: account!,
        onSaved: () {
          _accountsCache = null;
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.embedded
          ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          : const Center(child: CircularProgressIndicator());
    }
    var definition = _definition;
    if (definition == null) {
      return Center(child: Text(context.t.settings.developer.panelLoadFailed));
    }
    if (widget.searchQuery.isNotEmpty) {
      final filtered = [
        for (final el in (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (_elementMatchesQuery(el, widget.searchQuery)) el,
      ];
      if (filtered.isEmpty) return const SizedBox.shrink();
      definition = {...definition, 'elements': filtered};
    }

    final form = FormRenderer(
      formDefinition: definition,
      initialState: const {},
      showActions: false,
      // The embedded section already renders sectionTitle — the form's own
      // definition title would double it.
      showTitle: !(widget.embedded && widget.sectionTitle != null),
      developerMode: widget.services.settings.developerMode,
      labels: formRendererLabelsFor(context.t),
      validator: _validate,
      onChange: _autosave,
      onAction: (actionKey, method, state) => widget.services.extensions.runSettingsAction(
        hookKey: _hookKey,
        panelKey: _panelKey,
        method: method,
        state: state,
      ),
      onManageAccount: _manageAccount,
      onOpenLink: _openLink,
      onSubmit: (_) {},
      onCancel: () {},
    );
    if (widget.embedded) {
      final title = widget.sectionTitle;
      if (title == null) return form;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          form,
        ],
      );
    }

    final safeLeft = PaneSafeArea.leftOf(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16 + safeLeft, 16, 16, 16),
      child: form,
    );
  }
}

class _DeveloperPanel extends StatelessWidget {
  final HaLoServices services;

  const _DeveloperPanel({required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final safeLeft = PaneSafeArea.leftOf(context);

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.fromLTRB(16 + safeLeft, 16, 16, 16),
          children: [
            Text(
              context.t.settings.developer.options,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(context.t.settings.developerMode),
              subtitle: Text(context.t.settings.developer.developerModeDescription),
              value: settings.developerMode,
              onChanged: (enabled) => settings.setDeveloperMode(enabled),
              contentPadding: EdgeInsets.zero,
            ),
            // Gated by the 'experiments' meta-experiment (EXP EXPERIMENTS /
            // EXP EXP): the tile only appears once someone opted in via the
            // command. Reads live — the whole panel rebuilds under the
            // ListenableBuilder(settings) above, so toggling it (either
            // way, including from inside the pane itself) shows/hides the
            // tile immediately.
            if (settings.experimentEnabled('experiments'))
              FutureBuilder<List<ExperimentDefinition>>(
                future: loadExperiments(),
                builder: (context, snapshot) {
                  final definitions = snapshot.data ?? const <ExperimentDefinition>[];
                  // Counted against the CURRENT catalog's LISTED entries: state
                  // for removed experiments doesn't inflate it, and hidden ones
                  // are excluded so the count can't disagree with the pane
                  // (which doesn't list them).
                  final enabledCount = settings.enabledExperimentCount([
                    for (final d in definitions)
                      if (!d.hidden) d.key,
                  ]);
                  return ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: Text(context.t.settings.developer.experiments),
                    subtitle: Text(context.t.settings.developer.experimentsEnabled(count: enabledCount)),
                    contentPadding: EdgeInsets.zero,
                    mouseCursor: SystemMouseCursors.click,
                    // The pane loads the catalog itself — capturing this
                    // builder's `definitions` would freeze a still-loading
                    // (empty) snapshot into the pane for its whole lifetime.
                    onTap: () => showModalPane<void>(
                      context,
                      title: context.t.settings.developer.experiments,
                      closeTooltip: context.t.common.close,
                      builder: (_) => ExperimentsPane(settings: settings),
                    ),
                  );
                },
              ),
            // Shorebird over-the-air patch track (docs/releases.md §4.3). Only
            // shown when the Shorebird engine is actually present — i.e. a
            // `shorebird release` build, not a local/debug/web one — so it's
            // invisible and inert everywhere it can't do anything.
            if (services.updates.isAvailable) ...[
              const SizedBox(height: 16),
              Text(
                context.t.settings.developer.patchTrack,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  context.t.settings.developer.patchTrackDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'stable', label: Text(context.t.settings.developer.trackStable)),
                  ButtonSegment(value: 'unstable', label: Text(context.t.settings.developer.trackUnstable)),
                  ButtonSegment(value: 'bleeding-edge', label: Text(context.t.settings.developer.trackBleeding)),
                ],
                selected: {settings.shorebirdTrack},
                onSelectionChanged: (selected) async {
                  final track = selected.first;
                  await settings.setShorebirdTrack(track);
                  services.statusBar
                      .setMessage(key: 'shorebird:check', text: t.settings.developer.checkingTrack(track: track));
                  final applied = await services.updates.checkAndApply();
                  if (!context.mounted) return;
                  services.statusBar.setMessage(
                    key: 'shorebird:check',
                    text: applied
                        ? t.settings.developer.patchDownloaded
                        : t.settings.developer.noNewPatch(track: track),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FutureBuilder<int?>(
                  future: services.updates.currentPatchNumber(),
                  builder: (context, snapshot) {
                    final patch = snapshot.data;
                    return Text(
                      patch == null
                          ? context.t.settings.developer.noPatchInstalled
                          : context.t.settings.developer.runningPatch(patch: patch),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final formDefinition = {
                  'title': 'Developer Form Demo',
                  'subtitle': 'Verify all form element types and features',
                  'elements': [
                    {
                      'type': 'header',
                      'title': 'General Information',
                      'subtitle': 'These elements describe basic section settings',
                    },
                    {
                      'type': 'field',
                      'fieldType': 'text',
                      'key': 'name',
                      'label': 'Name',
                      'placeholder': 'Enter your full name',
                    },
                    {
                      'type': 'field',
                      'fieldType': 'multiline',
                      'key': 'bio',
                      'label': 'Biography',
                      'placeholder': 'Tell us about yourself...',
                    },
                    {'type': 'divider', 'title': 'Contact Details'},
                    {
                      'type': 'field',
                      'fieldType': 'email',
                      'key': 'email',
                      'label': 'Email Address',
                      'placeholder': 'email@example.com',
                    },
                    {
                      'type': 'field',
                      'fieldType': 'callsign',
                      'key': 'callsign',
                      'label': 'Operator Callsign',
                      'placeholder': 'W1AW',
                    },
                    {
                      'type': 'field',
                      'fieldType': 'number',
                      'key': 'power',
                      'label': 'Power Output (Watts)',
                      'placeholder': '100',
                    },
                    {'type': 'markdown', 'text': 'Please make sure to **validate** the information before saving.'},
                    {'type': 'divider', 'title': 'Preferences'},
                    {
                      'type': 'field',
                      'fieldType': 'select',
                      'key': 'license',
                      'label': 'License Class',
                      'options': [
                        {'label': 'Technician', 'value': 'tech'},
                        {'label': 'General', 'value': 'general'},
                        {'label': 'Extra', 'value': 'extra'},
                      ],
                    },
                    {
                      'type': 'field',
                      'fieldType': 'radio',
                      'key': 'mode_pref',
                      'label': 'Preferred Mode',
                      'options': [
                        {'label': 'SSB / Phone', 'value': 'ssb'},
                        {'label': 'CW / Morse', 'value': 'cw'},
                        {'label': 'Digital (FT8, RTTY)', 'value': 'digital'},
                      ],
                    },
                    {'type': 'field', 'fieldType': 'checkbox', 'key': 'subscribe', 'label': 'Subscribe to newsletter'},
                  ],
                };

                final initialState = {'name': 'Sebastian Delmont', 'license': 'extra', 'subscribe': true};

                final result = await showFormDialog(
                  context,
                  formDefinition: formDefinition,
                  initialState: initialState,
                  labels: formRendererLabelsFor(context.t),
                  validator: (fieldKey, value, state) async {
                    await Future<void>.delayed(const Duration(milliseconds: 200));

                    if (fieldKey == 'email') {
                      final str = value?.toString() ?? '';
                      if (str.isNotEmpty && !str.contains('@')) {
                        return 'Invalid email address format';
                      }
                    }
                    if (fieldKey == 'callsign') {
                      final str = value?.toString() ?? '';
                      if (str.isNotEmpty && str.length < 3) {
                        return 'Callsign is too short (min 3 chars)';
                      }
                    }
                    if (fieldKey == 'power') {
                      final numVal = value as num?;
                      if (numVal != null && (numVal < 0 || numVal > 1500)) {
                        return 'Power must be between 0 and 1500 Watts';
                      }
                    }
                    return null;
                  },
                  transformer: (fieldKey, value, state) async {
                    if (fieldKey == 'callsign') {
                      return value?.toString().toUpperCase();
                    }
                    return value;
                  },
                );

                if (context.mounted && result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${result.toString()}')));
                }
              },
              child: const Text('Test Custom Form Dialog'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              context.t.settings.developer.systemInformation,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow(context, context.t.settings.sync.deviceKey, settings.syncDeviceKey ?? context.t.settings.developer.loading),
            _infoRowWidget(
              context,
              context.t.settings.developer.appVersion,
              const VersionLabel(style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              context.t.settings.developer.activeExtensions,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _ActiveExtensionsList(services: services),
          ],
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return _infoRowWidget(
      context,
      label,
      SelectableText(
        value,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _infoRowWidget(BuildContext context, String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 3, child: value),
        ],
      ),
    );
  }
}

/// The Developer panel's live listing of activated extensions with their
/// versions — served by the kernel's own `kernel-info` extension, the one
/// place versions exist (they're deliberately absent from the build index).
/// Refreshes on runtime restarts (extension toggles).
class _ActiveExtensionsList extends StatefulWidget {
  final HaLoServices services;

  const _ActiveExtensionsList({required this.services});

  @override
  State<_ActiveExtensionsList> createState() => _ActiveExtensionsListState();
}

class _ActiveExtensionsListState extends State<_ActiveExtensionsList> {
  List<Map<String, dynamic>>? _extensions;

  @override
  void initState() {
    super.initState();
    _load();
    widget.services.extensions.runtimeGeneration.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    await widget.services.extensions.start();
    final extensions = await widget.services.extensions.listActiveExtensions();
    if (mounted) {
      setState(() => _extensions = extensions..sort((a, b) => (a['key'] as String).compareTo(b['key'] as String)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final extensions = _extensions;
    if (extensions == null) return Text(context.t.settings.developer.loading);
    if (extensions.isEmpty) return Text(context.t.settings.developer.runtimeNotAvailable);

    // Category comes from the build index (the runtime listing carries only
    // key/name/version); anything the index doesn't categorize — core
    // extensions and the kernel's own built-ins — lands under Core.
    final categoryByKey = {
      for (final info in widget.services.extensions.availableExtensions)
        if (info.category != null) info.key: info.category!,
    };
    final categoryTitles = {
      'activity': context.t.extensionsPanel.categoryActivity,
      'lookup': context.t.extensionsPanel.categoryLookup,
      'core': context.t.settings.developer.categoryCore,
    };
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final ext in extensions) {
      grouped.putIfAbsent(categoryByKey[ext['key']] ?? 'core', () => []).add(ext);
    }
    final categories = [
      ...['activity', 'lookup'].where(grouped.containsKey),
      ...grouped.keys.where((c) => c != 'activity' && c != 'lookup'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              categoryTitles[category] ?? category,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          for (final ext in grouped[category]!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      (ext['name'] as String?) ?? (ext['key'] as String? ?? '?'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SelectableText(
                      '${ext['key']}@${ext['version']}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// How many releases' notes show in the About screen's "Release Notes"
/// preview/modal — a handful of the most recent, not the full history (the
/// old "last 20 releases as cards" design this replaced).
const _aboutRecentReleaseCount = 3;

/// Tapping the About screen's version row copies the full app name and
/// version details — handy for pasting into a bug report or support email.
Future<void> _copyVersionDetailsToClipboard(BuildContext context) async {
  final details = await versionDetailsText();
  await Clipboard.setData(ClipboardData(text: '$ham2kAppName\n$details'));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.t.settings.about.copiedVersion)));
}

class _AboutPanel extends StatelessWidget {
  final HaLoServices services;

  const _AboutPanel({required this.services});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReleaseNotesEntry>>(
      future: loadReleaseNotes(),
      builder: (context, snapshot) {
        final releaseNotes = snapshot.data ?? const [];
        final recentReleases = releaseNotes.take(_aboutRecentReleaseCount).toList();
        final theme = Theme.of(context);
        // Match the running version explicitly rather than assuming
        // `releaseNotes.first` is it — release-notes.yaml's newest-first
        // order is a hand-maintained authoring convention, not something
        // the loader enforces, so notes written ahead of an actual version
        // bump (or a hotfix/rollback) could otherwise show a different
        // release here than the VersionLabel row below it. Falls back to
        // `.first` only when the running version has no entry yet.
        final currentRelease = releaseNotes.isEmpty
            ? null
            : releaseNotes.firstWhere((entry) => entry.version == kPublicVersion, orElse: () => releaseNotes.first);

        // Unlike every other settings panel (capped AND pinned left — see
        // _buildPanelContent), About's own content caps at the same
        // idealPaneWidth but CENTERS within the pane; the header photo and
        // the dividers between rows opt out of the cap entirely and span
        // the pane's full true width edge-to-edge.
        Widget centered(Widget child) =>
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: idealPaneWidth), child: child));

        // CustomScrollView + SliverFillRemaining(hasScrollBody: false)
        // rather than a plain Column: on a short viewport (a phone in
        // landscape, or a resized-short desktop window) the fixed-height
        // rows above (240px header + two dividers + version row + title)
        // alone can exceed the available height, and a bare Column has no
        // scroll fallback for that — it just overflows. This fills the
        // remaining space normally when there's room (matching the old
        // Column+Expanded look) and degrades to a scrollable, naturally-
        // sized preview when there isn't, instead of throwing.
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _AboutHeader(release: currentRelease)),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverToBoxAdapter(
              child: centered(
                ListTile(
                  leading: const Icon(Icons.info),
                  // VersionLabel renders SelectableText, whose own tap
                  // recognizer (for cursor placement) would otherwise win
                  // the gesture arena over this ListTile's onTap —
                  // IgnorePointer keeps the whole row a single tap target
                  // instead of a text-selection field.
                  title: const IgnorePointer(
                    child: VersionLabel(
                      detailed: true,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      boldFirstLine: true,
                    ),
                  ),
                  onTap: () => _copyVersionDetailsToClipboard(context),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            // Notices & Messages used to be its own top-level settings
            // panel — moved here (issue #183), between the version and the
            // release notes, as an entry point into the same history view.
            SliverToBoxAdapter(
              child: centered(
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(context.t.settings.about.notices),
                  subtitle: Text(context.t.settings.about.noticesDescription),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalPane<void>(
                    context,
                    title: context.t.settings.about.notices,
                    closeTooltip: context.t.common.close,
                    // NoticeHistoryView is its own scrolling ListView — the
                    // pane must not also wrap it in a SingleChildScrollView.
                    scrollable: false,
                    builder: (context) => NoticeHistoryView(services: services),
                  ),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (recentReleases.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: centered(
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t.settings.about.releaseNotes,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: centered(_ReleaseNotesPreview(releases: recentReleases)),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The last few releases' notes as one markdown block — shared by the
/// clipped/faded preview and the modal pane's full (unclipped) view, so
/// they always show identical content.
String _combinedReleaseNotesMarkdown(List<ReleaseNotesEntry> releases) {
  final lines = <String>[];
  for (final release in releases) {
    lines.add('**${release.name}**');
    lines.add('');
    lines.addAll(release.changes.map((change) => '- $change'));
    lines.add('');
  }
  return lines.join('\n');
}

/// Tapping the preview opens the same content in a Modal Pane, scrollable
/// and un-clipped — the preview itself never scrolls (`ClipRect` fades it
/// out at the bottom instead), same non-scrollable-`SingleChildScrollView`
/// trick as `release_overlay.dart`'s collapsed notes: it gives the
/// `MarkdownBody` unbounded height along the scroll axis so its natural
/// (taller-than-available) size never trips a RenderFlex overflow.
class _ReleaseNotesPreview extends StatelessWidget {
  final List<ReleaseNotesEntry> releases;

  const _ReleaseNotesPreview({required this.releases});

  @override
  Widget build(BuildContext context) {
    final markdown = _combinedReleaseNotesMarkdown(releases);
    final styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return GestureDetector(
      key: const Key('aboutReleaseNotesPreview'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showModalPane<void>(
        context,
        title: context.t.settings.about.releaseNotes,
        closeTooltip: context.t.common.close,
        builder: (context) => MarkdownBody(data: markdown, styleSheet: styleSheet),
      ),
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0, 0.85, 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MarkdownBody(data: markdown, styleSheet: styleSheet),
          ),
        ),
      ),
    );
  }
}

/// The About screen's top banner: the current release's cover photo fading
/// into the surface color (same technique as `ReleaseOverlayView`), with the
/// ham2k arc and app name over it — Issue #42's "Recent Changes" header
/// treatment.
class _AboutHeader extends StatelessWidget {
  final ReleaseNotesEntry? release;

  const _AboutHeader({required this.release});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // No ambient panel-body inset to cancel here (see _buildContent) — this
    // Stack already spans the pane's true width.
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (release != null)
            Image.asset(
              release!.imageAssetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => ColoredBox(color: theme.colorScheme.primaryContainer),
            )
          else
            ColoredBox(color: theme.colorScheme.primaryContainer),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.colorScheme.surface.withValues(alpha: 0.3), theme.colorScheme.surface],
                stops: const [0.0, 0.9],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GestureDetector(
                key: const Key('aboutWordmark'),
                onTap: () => showPhotoWordmarkModal(context, release: release),
                child: const Ham2kBrandMark(logoWidth: 140, showShadow: true, titleFontSizeDelta: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown whenever `SettingsService.syncState['pendingAccountUUID']` is set —
/// a first-ever link, or a re-registration under a different account
/// (`SyncEngine`'s account-identity gating, DESIGN.md's sync reconciliation
/// flow) — pausing sync until the user picks how to reconcile local data.
class _PendingAccountBanner extends StatelessWidget {
  final VoidCallback onCombine;
  final VoidCallback onReplace;
  final double extraLeftMargin;

  const _PendingAccountBanner({required this.onCombine, required this.onReplace, this.extraLeftMargin = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.fromLTRB(16 + extraLeftMargin, 4, 16, 12),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(resolveIconName('cloud-question'), color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t.settings.syncPanel.pendingBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.t.settings.syncPanel.pendingBannerBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCombine, child: Text(context.t.settings.syncPanel.combine)),
                const SizedBox(width: 8),
                FilledButton(onPressed: onReplace, child: Text(context.t.settings.syncPanel.replace)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One extension account's credentials, shown as a Modal Pane
/// (docs/design/layouts.md): a dialog on wide layouts, a full screen on
/// phones, where the old AlertDialog was cramped. The route provides the
/// title and chrome; the action row renders here because it depends on
/// this State (_testing, _loggedIn).
/// Opens [accountKey]'s standalone account dialog from anywhere in the app
/// (declarative `account` actions — e.g. an extension's "reconnect your
/// account" dialog button). `accountKey` matches the account's kvKey.
Future<void> showAccountDialogByKey(HaLoServices services, String accountKey, {String? subkey}) async {
  final accounts = await services.extensions.getAccounts();
  Map<String, dynamic>? account;
  for (final a in accounts) {
    if (a['kvKey'] == accountKey || a['key'] == accountKey) {
      account = a;
      break;
    }
  }
  if (account == null) {
    debugPrint('[accounts] no account "$accountKey" to open');
    return;
  }
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await showModalPane<void>(
    context,
    title: account['label'] as String? ?? accountKey,
    barrierDismissible: false,
    closeTooltip: context.t.common.close,
    builder: (context) => _AccountPane(services: services, account: account!, onSaved: () {}),
  );
}

class _AccountPane extends StatefulWidget {
  final HaLoServices services;
  final Map<String, dynamic> account;
  final VoidCallback onSaved;

  const _AccountPane({required this.services, required this.account, required this.onSaved});

  @override
  State<_AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends State<_AccountPane> {
  final Map<String, TextEditingController> _controllers = {};
  bool _testing = false;
  String? _testResult;
  bool _loggedIn = false;

  /// OAuth tokens obtained from a Login that haven't been saved yet — only
  /// persisted when the user presses Save, discarded on Cancel/close.
  Map<String, String>? _pendingCredentials;

  String? _fieldError(String key, String value) {
    if (widget.account['key'] == 'qrz' && key == 'username' && value.contains('@')) {
      return "Don't use your email for login.";
    }
    return null;
  }

  List<Map<String, dynamic>> get _fields =>
      (widget.account['fields'] as List? ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _oauth2 => widget.account['oauth2'] as Map<String, dynamic>?;

  String get _kvKey => widget.account['kvKey'] as String;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final creds = await widget.services.extensions.getAccountCredentials(_kvKey);
    setState(() {
      _loggedIn = creds.isNotEmpty;
    });
    for (final field in _fields) {
      final key = field['key'] as String;
      _controllers[key] = TextEditingController(text: creds[key] ?? '');
    }
    // Existing credentials get verified right away, so the "Connected as"
    // area reflects reality without a manual Test.
    if (creds.isNotEmpty) await _test();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    try {
      if (_oauth2 == null) {
        final creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
        await widget.services.extensions.setAccountCredentials(_kvKey, creds);
      } else if (_pendingCredentials != null) {
        await widget.services.extensions.setAccountCredentials(_kvKey, _pendingCredentials!);
      }
    } catch (e) {
      debugPrint('[accounts] save failed for $_kvKey: $e');
      if (mounted) {
        widget.services.statusBar.setMessage(key: 'accounts:save', text: t.settings.accounts.saveFailed(error: e));
      }
      return;
    }
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  /// Bumped by [_clear] so an in-flight test's result can't repopulate the
  /// "Connected as" area after a disconnect.
  int _testGeneration = 0;

  Future<void> _clear() async {
    // Update the UI first — the keychain call shouldn't delay the visible
    // disconnect.
    _testGeneration++;
    setState(() {
      _loggedIn = false;
      _testing = false;
      _testResult = null;
      _pendingCredentials = null;
    });
    for (final c in _controllers.values) {
      c.clear();
    }
    await widget.services.extensions.clearAccount(_kvKey);
    widget.onSaved();
  }

  Future<void> _test() async {
    final generation = _testGeneration;
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final Map<String, String> creds;
    if (_oauth2 != null) {
      creds = _pendingCredentials ?? await widget.services.extensions.getAccountCredentials(_kvKey);
    } else {
      creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
    }

    final res = await widget.services.extensions.testCredentials(widget.account['key'] as String, creds);

    if (mounted && generation == _testGeneration) {
      setState(() {
        _testing = false;
        _testResult = res;
      });
    }
  }

  Future<void> _doOAuth() async {
    final oauth2 = _oauth2!;
    final issuer = oauth2['issuer'] as String;
    final clientId = oauth2['clientId'] as String;
    final redirectUrl = oauth2['redirectUrl'] as String;
    final scopes = (oauth2['scopes'] as List).cast<String>();

    try {
      final userAgent = await ham2kUserAgent();
      final discoveryUrl = Uri.parse('$issuer/.well-known/openid-configuration');
      final response = await http.get(discoveryUrl, headers: {'User-Agent': userAgent});
      if (response.statusCode != 200) throw Exception('Failed to load OIDC discovery: ${response.statusCode}');
      final discovery = jsonDecode(response.body) as Map<String, dynamic>;
      final authEndpoint = discovery['authorization_endpoint'] as String;
      final tokenEndpoint = discovery['token_endpoint'] as String;

      final codeVerifier = _randomString(64);
      final codeChallenge = _sha256Challenge(codeVerifier);
      final state = _randomString(16);

      final authUri = Uri.parse(authEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': clientId,
          'redirect_uri': redirectUrl,
          'scope': scopes.join(' '),
          'state': state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );

      if (!mounted) return;

      // The provider redirects to a com.ham2k.*.auth:// URL. Normally the
      // webview intercepts it below, but if the OS handles it instead (the
      // schemes are registered as deep links), it comes back through
      // DeepLinkService — either way the webview route pops with the code.
      final navigator = Navigator.of(context);
      String? authError;
      final linkSub = widget.services.deepLinks.links.listen((uri) {
        if (!DeepLinkService.isAuthCallback(uri)) return;
        if (uri.queryParameters['state'] != state) return;
        authError = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
        navigator.pop(uri.queryParameters['code']);
      });

      InAppWebViewController? webViewController;

      final code = await navigator.push<String>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              flexibleSpace: windowHeaderGestureArea(),
              title: Text(context.t.settings.accounts.connectTo(label: '${widget.account['label']}')),
              actions: [
                // Continues the login in the system browser (from wherever
                // the in-app page currently is); the redirect then comes
                // back through the deep-link listener above. Keep this page
                // open — closing it abandons the flow.
                TextButton(
                  child: Text(context.t.settings.accounts.openInBrowser),
                  onPressed: () async {
                    final current = await webViewController?.getUrl();
                    unawaited(launchUrl(Uri.parse((current ?? authUri).toString()), mode: LaunchMode.externalApplication));
                  },
                ),
                windowsCaptionSpacer(context),
              ],
              leadingWidth: macOSAwareLeadingWidth(context),
              leading: isMacOSChromelessWindow
                  ? Padding(
                      padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)),
                      child: CloseButton(onPressed: () => Navigator.of(context).pop()),
                    )
                  : CloseButton(onPressed: () => Navigator.of(context).pop()),
            ),
            body: InAppWebView(
              onWebViewCreated: (controller) => webViewController = controller,
              initialUrlRequest: URLRequest(url: WebUri(authUri.toString())),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true, useShouldOverrideUrlLoading: true),
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url?.toString();
                if (url != null && url.startsWith(redirectUrl)) {
                  final uri = Uri.parse(url);
                  final redirectCode = uri.queryParameters['code'];
                  final redirectState = uri.queryParameters['state'];
                  if (redirectState == state) {
                    Navigator.of(context).pop(redirectCode);
                  } else {
                    Navigator.of(context).pop();
                  }
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ),
      );

      await linkSub.cancel();

      if (code == null) {
        if (authError != null) throw Exception(authError);
        return;
      }

      setState(() => _testing = true);

      final tokenResponse = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded', 'User-Agent': userAgent},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': code,
          'redirect_uri': redirectUrl,
          'code_verifier': codeVerifier,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw Exception('Failed to exchange code: ${tokenResponse.body}');
      }

      final tokens = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final credentials = <String, String>{};
      if (tokens['access_token'] != null) credentials['accessToken'] = tokens['access_token'] as String;
      if (tokens['refresh_token'] != null) credentials['refreshToken'] = tokens['refresh_token'] as String;
      if (tokens['id_token'] != null) credentials['idToken'] = tokens['id_token'] as String;

      // Held until the user presses Save — nothing is persisted yet.
      setState(() {
        _pendingCredentials = credentials;
        _testing = false;
      });
      // Verify the fresh tokens right away, same as opening with stored ones.
      await _test();
    } catch (e) {
      if (mounted) {
        setState(() => _testing = false);
        widget.services.statusBar.setMessage(key: 'accounts:login', text: t.settings.accounts.loginFailed(error: e));
      }
    }
  }

  String _randomString(int length) {
    final rand = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  String _sha256Challenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_oauth2 != null) ...[
          if (_pendingCredentials != null) ...[
            Text(
              context.t.settings.accounts.loggedInAs(
                  identity: ExtensionService.identityFromCredentials(_pendingCredentials!) ??
                      '${widget.account['label']}'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.t.settings.accounts.pressSaveToKeep,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (_loggedIn) ...[
            Text(
              context.t.settings.accounts.connectedTo(label: '${widget.account['label']}'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            OutlinedButton(
                onPressed: _testing ? null : _doOAuth, child: Text(context.t.settings.accounts.connect)),
          ],
        ] else ...[
          ..._fields.map((field) {
            final key = field['key'] as String;
            final preface = field['preface'] as String?;
            final postface = field['postface'] as String?;
            final controller = _controllers[key];

            if (controller == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preface != null && preface.isNotEmpty) ...[
                    MarkdownBody(data: preface),
                    const SizedBox(height: 8),
                  ],
                  if (field['type'] == 'secret')
                    SecretTextField(
                      controller: controller,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                      decoration: poloFieldDecoration(
                        context,
                        field['label'] as String,
                      ).copyWith(errorText: _fieldError(key, controller.text)),
                      onChanged: (_) => setState(() {}),
                    )
                  else
                    TextField(
                      controller: controller,
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                      keyboardType: field['type'] == 'email' ? TextInputType.emailAddress : TextInputType.text,
                      decoration: poloFieldDecoration(
                        context,
                        field['label'] as String,
                      ).copyWith(errorText: _fieldError(key, controller.text)),
                      onChanged: (_) => setState(() {}),
                    ),
                  if (postface != null && postface.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    MarkdownBody(data: postface),
                  ],
                ],
              ),
            );
          }),
        ],
        if (_loggedIn && _pendingCredentials == null) ...[
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: _clear,
              child: Text(context.t.settings.accounts.disconnect),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          context.t.settings.accounts.connectedAs,
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _testing
                    ? const SizedBox(
                        height: 20,
                        child: Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : MarkdownBody(data: _testResult ?? '—'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _testing ? null : _test, child: Text(context.t.settings.accounts.test)),
          ],
        ),
        const SizedBox(height: 24),
        haloDialogFooterRow(
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
          actions: [
            FilledButton(onPressed: _save, child: Text(context.t.common.save)),
          ],
        ),
      ],
    );
  }
}
