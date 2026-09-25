// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings screen: a sidebar of panels, each a route of its own on a
// narrow window and a pane beside the sidebar on a wide one. The core
// panels live under views/settings/; extension-contributed ones are
// rendered from their declarative definition through FormRenderer.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/halo_services.dart';
import 'panel_use_tracker.dart';
import '../services/link_opener.dart';
import '../services/settings_service.dart';
import 'header_profile_label.dart';
import 'help_panel.dart';
import '../settings/settings_catalog.dart' show elementSearchScore;
import '../settings/settings_registry.dart';
import 'accordion_section.dart' show accordionCurve, accordionDuration;
import 'extensions_panel.dart';
import 'peers_panel.dart';
import 'station_panel.dart';

import 'settings/about_panel.dart';
import 'settings/accounts_panel.dart';
import 'settings/data_files_panel.dart';
import 'settings/developer_panel.dart';
import 'settings/extension_settings_panel.dart';
import 'settings/profiles_panel.dart';
import 'settings/settings_category.dart';
import 'settings/settings_pane_width.dart';
import 'settings/sync_panel.dart';

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
  // Every declared group — core, sync and extension — in one panel,
  // led by the `common: true`-flagged subset of all of them (see
  // settings_registry.dart).
  _SettingsPanelEntry(key: 'settings', title: t.settings.panels.settings, icon: MdiIcons.cog, order: 0, description: t.settings.panels.settingsDescription),
  _SettingsPanelEntry(key: 'sync', title: t.settings.sync.title, icon: MdiIcons.sync, order: 10, description: t.settings.panels.syncDescription),
  _SettingsPanelEntry(key: 'accounts', title: t.settings.accounts.title, icon: MdiIcons.key, order: 20, description: t.settings.panels.accountsDescription),
  _SettingsPanelEntry(key: 'help', title: t.settings.help.title, icon: MdiIcons.lifebuoy, order: 95, description: t.settings.help.description),
  _SettingsPanelEntry(
    key: 'extensions',
    title: t.settings.panels.extensions,
    icon: MdiIcons.toyBrick,
    order: 40,
    description: t.settings.panels.extensionsDescription,
  ),
];
// Before Application Preferences (order 0) — the Profiles panel leads the list.
// Internally "profiles"; until multi-profile features are enabled it
// presents itself as just "Callsign".
const _profilesPanelOrder = -10;
// Between Settings (0) and Sync (10) — see the entry itself.
const _stationPanelOrder = 5;
const _developerPanelOrder = 90;
const _aboutPanelOrder = 100;
const _extensionPanelDefaultOrder = 50;

class SettingsView extends StatefulWidget {
  /// Settings' arrangement is fixed (docs/design/layouts.md): its split
  /// opts into the "surfaces" divider style below.
  static const layoutPolicy = ViewLayoutPolicy.fixed;

  final HaLoServices services;
  final String? initialPanel;

  /// Whether Settings is shown INSIDE a shell that already provides
  /// navigation, rather than pushed as its own route.
  ///
  /// No inset goes with it — the rail is a sibling that owns its own column,
  /// so nothing here has to hold room for it.
  final bool embedded;

  /// Leaves the settings screen when it is [embedded]. There is no route under
  /// an embedded SettingsView, so the plain back button has nothing to pop:
  /// the owner takes it down instead.
  final VoidCallback? onBack;

  /// Space held at the leading edge for the app's mark, which the window draws
  /// over that corner (see `HomeRailLogo`). Zero where a rail sits under the
  /// mark and this view starts beside it — only the railless arrangement has
  /// this view and the mark reaching for the same corner.
  final double leadingInset;

  const SettingsView({super.key, required this.services, this.initialPanel, this.embedded = false, this.onBack, this.leadingInset = 0});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  /// Embedded, the window controls sit over the RAIL rather than over this
  /// header, so the macOS traffic-light clearance is the rail's to hold and a
  /// plain back button is the right one here.
  Widget _leading(BuildContext context) {
    if (!widget.embedded) return macOSAwareBackButton(context);
    if (widget.onBack == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: widget.leadingInset),
      child: BackButton(onPressed: widget.onBack),
    );
  }

  double? _leadingWidth(BuildContext context) {
    if (!widget.embedded) return macOSAwareLeadingWidth(context);
    if (widget.onBack == null) return 0;
    return widget.leadingInset == 0 ? null : widget.leadingInset + 48;
  }

  late String _selectedPanel;
  List<Map<String, dynamic>> _extensionPanels = [];
  // Extension-contributed panels only appear in _buildPanelEntries once
  // _loadExtensionPanels's bridge call resolves. Until then, the wide-layout
  // auto-correct below must not treat a selected-but-not-yet-loaded panel
  // key as gone and snap the selection elsewhere — so it's gated on this
  // flag.
  bool _extensionPanelsLoaded = false;

  /// One per screen instance — see [PanelUseTracker].
  late final PanelUseTracker _panels;

  @override
  void initState() {
    super.initState();
    _selectedPanel = widget.initialPanel ?? 'settings';
    widget.services.track('screen_viewed', {'screen': 'settings'});
    _panels = PanelUseTracker(track: widget.services.track, screen: 'settings');
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
        icon: MdiIcons.account,
        order: _profilesPanelOrder,
      ),
      // Station equipment and CAT control (docs/design/cat.md). Between
      // Settings (0) and Sync (10). Not hidden
      // on web: the serial transport works there,
      // via the Web Serial API. TCP and the Icom network transport
      // don't — a radio using either throws UnsupportedError on
      // connect, just not hidden a layer up from it.
      if (settings.experimentEnabled('gato') /* stored key, see experiments.yaml */ )
        _SettingsPanelEntry(
          key: 'station',
          title: t.settings.panels.station,
          icon: MdiIcons.cat,
          order: _stationPanelOrder,
          description: t.settings.panels.stationDescription,
        ),
      // Between Sync (10) and Accounts (20): both are about where the log
      // goes — cloud first, then the devices beside you.
      if (settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ )
        _SettingsPanelEntry(key: 'peers', title: t.settings.panels.peers, icon: MdiIcons.lan, order: 15, description: t.settings.panels.peersDescription),
      ..._fixedCorePanels(t),
      // sidebar: false (e.g. call-notes, HALO-53) opts a panel out of this
      // top-level list — it's still returned by getSettingsPanels() for
      // whichever screen the extension links it from instead (the data
      // sources' own "Extensions" section, here).
      for (final p in _extensionPanels)
        if (p['sidebar'] != false)
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
          icon: MdiIcons.bug,
          order: _developerPanelOrder,
          description: t.settings.panels.developerSettingsDescription,
        ),
      _SettingsPanelEntry(
        key: 'about',
        title: t.settings.panels.about,
        icon: MdiIcons.information,
        order: _aboutPanelOrder,
        description: t.settings.panels.aboutDescription,
      ),
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
        // user-resizable.
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
              leadingWidth: _leadingWidth(context),
              leading: _leading(context),
              title: shrinkToFitText(Text(context.t.settings.title)),
            ),
            body: _buildSidebar(context, isWide: true, panels: panels, selectedKey: effectivePanel.key),
          ),
        ),
        // The LayoutBuilder gets a context under the split's PaneSafeArea
        // (for `safeLeft`) and reports the pane's own true width — the
        // whole right panel, title included, shifts right by the grab
        // strip's clearance and its title lines up with the panel elements
        // below it.
        secondary: LayoutBuilder(
          builder: (context, constraints) {
            final safeLeft = PaneSafeArea.leftOf(context);
            final paneWidth = constraints.maxWidth;
            // The rows below span the pane and inset their CONTENTS by the
            // centering offset plus 24 + safeLeft (_buildPanelContent's
            // ListTileTheme merge over the one below). Replicate both parts to
            // get the title's left edge to the same absolute x, measured from
            // the pane's true left edge.
            final centeringOffset = settingsRowCentering(paneWidth);
            final targetLeft = centeringOffset + settingsRowInset + safeLeft;
            // NavigationToolbar (which AppBar's title slot layouts through)
            // starts the title at `titleSpacing` from the toolbar's left edge
            // when centerTitle is false — see _ToolbarLayout.performLayout in
            // navigation_toolbar.dart (`middleStart = leadingWidth +
            // middleSpacing`; leadingWidth is 0, there's no leading widget
            // here) — subtract it back out so a plain Padding (not a second,
            // re-centered ConstrainedBox inside that already-narrower-than-
            // the-pane slot, which drifted left by half the trailing actions'
            // width) lands exactly on `targetLeft`.
            final titleSpacing = Theme.of(context).appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
            return ScaffoldMessenger(
              child: Scaffold(
                appBar: AppBar(
                  flexibleSpace: windowHeaderGestureArea(),
                  centerTitle: false,
                  title: Padding(
                    padding: EdgeInsets.only(left: targetLeft - titleSpacing),
                    child: shrinkToFitText(Text(effectivePanel.effectiveScreenTitle)),
                  ),
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
                body: SettingsList(extraLeft: safeLeft, child: _buildPanelContent(effectivePanel, widget.services, _panels, _openPanel)),
              ),
            );
          },
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: windowHeaderGestureArea(),
          leadingWidth: _leadingWidth(context),
          leading: _leading(context),
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

  /// Selects [key]'s panel — beside the sidebar on a wide window, as a
  /// pushed screen on a narrow one. Also how a panel's own rows (a `panel`
  /// link in Application Preferences) move to another panel.
  void _openPanel(String key) {
    if (!mounted) return;
    final panel = _buildPanelEntries(widget.services.settings, context.t).where((p) => p.key == key).firstOrNull;
    assert(panel != null, 'no settings panel "$key" to open');
    if (panel == null) return;
    setState(() => _selectedPanel = key);
    if (!ShirtSize.of(context).isTwoPane) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _SettingsPanelScreen(panel: panel, services: widget.services, openPanel: _openPanel),
        ),
      );
    }
  }

  Widget _buildSidebar(BuildContext context, {required bool isWide, required List<_SettingsPanelEntry> panels, required String selectedKey}) {
    // The status footer doesn't reserve the home indicator globally (it
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
                    children: [
                      TextSpan(
                        text: mono,
                        style: const TextStyle(fontFamily: 'RobotoMono'),
                      ),
                    ],
                  ),
                  style: titleStyle,
                )
              : Text(panel.title, style: titleStyle);

          return ListTile(
            selected: isSelected,
            // Material's default selected color is colorScheme.primary — a fill
            // color here (the AppBar/FAB teal), not tuned for reading directly
            // on this sidebar's surface; only 2.67:1 in dark mode.
            selectedColor: HaLoColors.of(context).onSurfaceAccent,
            // The section band's own hue, at half strength against the
            // sidebar's surface: the selected row and the section it opens read
            // as one family, but the band still marks a heading and this only
            // marks a row. Derived rather than a fixed tint, so it follows the
            // theme instead of disappearing in dark mode.
            selectedTileColor: Color.lerp(Theme.of(context).colorScheme.surface, haloDialogBandColorAt(context), 0.5),
            leading: Icon(panel.icon),
            title: titleWidget,
            subtitle: panel.description == null ? null : Text(panel.description!),
            onTap: () => _openPanel(panel.key),
            mouseCursor: SystemMouseCursors.click,
          );
        },
      ),
    );
  }
}

/// Stateful only to own a [PanelUseTracker]: the narrow layout pushes each
/// settings panel as its own route, and without per-instance de-duplication
/// here `panel_used` would be reported for wide windows only — a bias by
/// layout rather than by what operators actually do.
class _SettingsPanelScreen extends StatefulWidget {
  final _SettingsPanelEntry panel;
  final HaLoServices services;
  final FormOpenPanel openPanel;

  const _SettingsPanelScreen({required this.panel, required this.services, required this.openPanel});

  @override
  State<_SettingsPanelScreen> createState() => _SettingsPanelScreenState();
}

class _SettingsPanelScreenState extends State<_SettingsPanelScreen> {
  late final _panels = PanelUseTracker(track: widget.services.track, screen: 'settings');

  @override
  Widget build(BuildContext context) {
    final panel = widget.panel;
    final services = widget.services;
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
      body: _buildPanelContent(panel, services, _panels, widget.openPanel),
    );
  }
}

/// Extension panels all report as a single `extension` rather than by their
/// own key: those ids come from whatever the operator has installed, so
/// reporting them by name would be unbounded cardinality AND would leak
/// extension usage, which docs/design/telemetry.md excludes on purpose.
String _panelUseName(_SettingsPanelEntry panel) => panel.descriptor != null ? 'extension' : panel.key;

Widget _buildPanelContent(_SettingsPanelEntry panel, HaLoServices services, PanelUseTracker panels, FormOpenPanel openPanel) {
  final Widget content;
  switch (panel.key) {
    case 'profiles':
      content = ProfilesPanel(services: services);
    case 'station':
      content = StationPanel(services: services);
    case 'settings':
      content = _SettingsPanel(services: services, openPanel: openPanel);
    case 'extensions':
      content = ExtensionsPanel(services: services);
    case 'sync':
      content = SyncPanel(services: services);
    case 'peers':
      content = PeersPanel(services: services);
    case 'accounts':
      // Service credentials and the offline data they and the extensions
      // feed, in one scroll.
      content = CustomScrollView(
        slivers: [
          AccountsPanel(services: services),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Space.md),
            sliver: DataFilesPanel(services: services),
          ),
        ],
      );
    case 'developer':
      content = DeveloperPanel(services: services);
    case 'about':
      content = AboutPanel(services: services);
    case 'help':
      content = const HelpPanel();
    default:
      final descriptor = panel.descriptor;
      content = descriptor == null ? const SizedBox.shrink() : ExtensionSettingsPanel(services: services, descriptor: descriptor);
  }
  // Observes only, and wraps the body once so BOTH returns below are covered.
  final body = Listener(onPointerDown: (_) => panels.used(_panelUseName(panel)), child: content);
  // Settings content spans the pane; the ideal reading width is reached by
  // PADDING each row's contents, not by capping the column. Rows, section
  // bands and dividers therefore run to the pane's own edges, the way the
  // rest of the app's lists do — a capped column leaves them floating in a
  // gutter of bare surface on a wide window.
  //
  // The offset rides the ambient ListTileTheme, which is where every row in
  // here already takes its inset from (ListTile-based panels directly,
  // FormRenderer through its `_rowContentPadding`) — so there is one number
  // to line the pane's title up with, not two.
  //
  // The SafeArea sits inside: each panel's scroll view clears the bottom
  // safe area itself, since the status footer doesn't reserve the home
  // indicator globally.
  return LayoutBuilder(
    builder: (context, constraints) {
      final base = ListTileTheme.of(context).contentPadding ?? _defaultRowInset;
      return ListTileTheme.merge(
        contentPadding: base.add(EdgeInsets.symmetric(horizontal: settingsRowCentering(constraints.maxWidth))),
        child: SettingsPaneWidth(
          width: constraints.maxWidth,
          child: SafeArea(top: false, left: false, right: false, child: body),
        ),
      );
    },
  );
}

/// The narrow layout has no ListTileTheme of its own to merge over (the wide
/// pane sets one before [_buildPanelContent] runs), so it starts from this.
const _defaultRowInset = EdgeInsets.symmetric(horizontal: settingsRowInset);

/// What a settings row's contents inset by, on top of the row inset, so they
/// land at [idealPaneWidth] centred in a pane of [paneWidth]. Zero once the
/// pane is narrower than that.
double settingsRowCentering(double paneWidth) => max(0.0, (paneWidth - idealPaneWidth) / 2);

/// One declared settings group rendered as an autosaving form: the group's
/// title as a category heading, then its elements. Values refresh whenever
/// the group's [SettingsGroup.listenable] fires (a keyboard shortcut, the
/// "..." menu, another panel) — same external-change contract as
/// [ExtensionSettingsPanel], including its reload coalescing (commit
/// notifies SettingsService synchronously, mid-autosave).
class _SettingsGroupForm extends StatefulWidget {
  final HaLoServices services;
  final SettingsGroup group;

  /// Common Preferences mode: keep only elements flagged `common: true`
  /// (settings_registry.dart's [elementIsCommon]). False shows everything
  /// the group declares (minus whatever `environment` rules out — that
  /// filter always applies, common or not).
  final bool commonOnly;

  /// The panel's search query (lowercased); when it matches nothing in
  /// this group, the whole category — heading included — renders empty.
  final String searchQuery;

  /// Whether this category's rows are showing. Ignored when [onToggle] is
  /// null.
  final bool expanded;

  /// Toggles [expanded], and by being non-null asks for the category
  /// heading. Null renders the rows BARE, which is how the groups inside
  /// Common Preferences appear: that one category heading owns them all.
  final VoidCallback? onToggle;

  /// Called when a load lands a DIFFERENT set of elements than the one
  /// showing — a group that grows sub-options when a toggle goes on, or the
  /// first load arriving. Every row below this one moves, which the panel
  /// has to know about (see `_SettingsPanelState._refreshListKey`); nothing
  /// else can tell it, since the set is decided in here.
  final VoidCallback? onRowsChanged;

  /// Renders as a SLIVER rather than a box — see [ExtensionSettingsPanel.sliver].
  final bool sliver;

  /// Where a `panel` link row goes. Null leaves such a row inert.
  final FormOpenPanel? openPanel;

  /// Element keys left out — for a group embedded where one of its rows
  /// would point back at the surface it is embedded in.
  final Set<String> excludeKeys;

  /// The rows alone, with no category heading or section band of their own:
  /// for a host that heads them itself.
  final bool bare;

  const _SettingsGroupForm({
    super.key,
    required this.services,
    required this.group,
    this.commonOnly = false,
    this.searchQuery = '',
    this.expanded = true,
    this.onToggle,
    this.onRowsChanged,
    this.sliver = false,
    this.openPanel,
    this.excludeKeys = const {},
    this.bare = false,
  });

  @override
  State<_SettingsGroupForm> createState() => _SettingsGroupFormState();
}

class _SettingsGroupFormState extends State<_SettingsGroupForm> {
  List<Map<String, dynamic>>? _elements;
  bool _reloading = false;
  bool _reloadPending = false;
  int? _lastRowIdentity;

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
        final resolved = await widget.services.systemLists.resolveInElements(await widget.group.buildElements());
        // Platform-excluded elements don't exist on this session at all —
        // baked in here rather than filtered per-view, same as
        // [ExtensionSettingsPanel].
        final elements = [
          for (final el in filterElementsForEnvironment(resolved))
            // Declared, but edited by a dialog of their own (settings_registry.dart).
            if (el['listed'] != false && !widget.excludeKeys.contains(el['key'])) el,
        ];
        if (!mounted) continue;
        final identity = settingsRowIdentity(elements);
        setState(() => _elements = elements);
        if (identity != _lastRowIdentity) {
          _lastRowIdentity = identity;
          widget.onRowsChanged?.call();
        }
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

  /// See [ExtensionSettingsPanel]'s namesake: the states that are a box
  /// whichever way this group renders.
  Widget _box(Widget child) => widget.sliver ? SliverToBoxAdapter(child: child) : child;

  @override
  Widget build(BuildContext context) {
    var elements = _elements;
    if (elements == null) {
      return _box(
        const Padding(
          padding: EdgeInsets.all(Space.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    // A group can decline to contribute anything at all — RadioSettingsGroup
    // does while the CAT experiment is off. Its title is chrome for the rows
    // below it, so with no rows there is nothing to head.
    if (elements.isEmpty) return _box(const SizedBox.shrink());
    if (widget.commonOnly) {
      elements = [
        for (final el in elements)
          if (elementIsCommon(el)) el,
      ];
      if (elements.isEmpty) return _box(const SizedBox.shrink());
    }
    // A group the search excludes is HIDDEN, not unmounted — see
    // [settingsCategory], which is where that is done.
    var hidden = false;
    if (widget.searchQuery.isNotEmpty) {
      // Sorted by score, not left in declaration order. Subsequence matching
      // is permissive by design — `st` legitimately matches a fair few
      // settings — so the ranking is what makes it usable: without it a good
      // match sits wherever its group happened to declare it, among weaker
      // ones, and the search reads as barely filtering. Sections themselves
      // stay in their usual order; only the rows within one move.
      final scored = <({Map<String, dynamic> element, int score, int index})>[];
      for (var i = 0; i < elements.length; i++) {
        final score = elementSearchScore(elements[i], widget.searchQuery);
        if (score != null) scored.add((element: elements[i], score: score, index: i));
      }
      // Declaration order breaks ties explicitly: Dart's `List.sort` is not
      // stable above 32 elements, so equal-scoring rows would otherwise
      // reshuffle on every keystroke while the operator is reading them.
      scored.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.index.compareTo(b.index);
      });
      hidden = scored.isEmpty;
      if (!hidden) elements = [for (final s in scored) s.element];
    }
    final form = FormRenderer(
      formDefinition: {'elements': elements},
      initialState: const {},
      sliver: widget.sliver,
      showActions: false,
      showTitle: false,
      developerMode: widget.services.settings.developerMode,
      settingsList: true,
      onChange: _autosave,
      onAction: (key, method, state) async {
        await widget.group.openAction(context, key);
        return null;
      },
      onOpenLink: openExternalUrl,
      onOpenPanel: widget.openPanel,
      onSubmit: (_) {},
      onCancel: () {},
    );
    if (widget.bare) return form;
    return widget.sliver
        ? settingsCategorySliver(context, title: widget.group.title, expanded: widget.expanded, onToggle: widget.onToggle, hidden: hidden, sliver: form)
        : settingsCategory(context, title: widget.group.title, expanded: widget.expanded, onToggle: widget.onToggle, hidden: hidden, child: form);
  }
}

/// The rows of the registered settings group [groupKey], outside the Settings
/// panel, with the same commits, actions and live reloads it gets there —
/// headed by the host rather than by a category of their own. Nothing when
/// no group has that key, or when the group contributes nothing right now.
Widget settingsGroupRows({required HaLoServices services, required String groupKey, Set<String> excludeKeys = const {}}) {
  final group = services.settingsRegistry[groupKey];
  if (group == null) return const SizedBox.shrink();
  // Slivers, so a section the group declares pins in the host's list like
  // its own sections do — as a box its band would be buried in a row.
  return SectionedSlivers(
    slivers: [_SettingsGroupForm(services: services, group: group, excludeKeys: excludeKeys, bare: true, sliver: true)],
  );
}

/// Every declared setting in one panel: the `common: true` subset of all
/// of them leading, then every declared group — core, sync, and each
/// extension-contributed panel — as a category of its own
/// ([settingsCategory]).
///
/// One category is open at a time and which one is remembered across
/// visits ([_openCategoryPrefsKey]). A search opens every category that
/// still has a match, and the operator can close those individually while
/// the query stands; clearing it returns to the single remembered one.
class _SettingsPanel extends StatefulWidget {
  final HaLoServices services;

  final FormOpenPanel openPanel;

  const _SettingsPanel({required this.services, required this.openPanel});

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

/// The category that leads the panel, and the one open on a first run.
const _commonCategoryKey = 'common';

/// Which category is open, kept across visits to Settings. Empty string
/// means the operator closed the one that was open, leaving them all shut —
/// distinct from an absent key, which is a first run.
const _openCategoryPrefsKey = 'settingsOpenCategory';

class _SettingsPanelState extends State<_SettingsPanel> {
  List<Map<String, dynamic>>? _extensionPanels;
  final _searchController = TextEditingController();

  String? _openCategory;

  /// Categories the operator closed while the CURRENT query stands — a
  /// search opens them all, and this holds the ones they then dismissed.
  /// Cleared whenever searching starts or stops, so a query never leaves
  /// the single-open state behind it.
  final _closedWhileSearching = <String>{};
  bool _searching = false;

  /// One key per category, held here so it outlives the scroll view —
  /// [_refreshListKey] rebuilds that scroll view whenever the rows move,
  /// and a globally-keyed child is moved into the new one rather than
  /// disposed with the old.
  final _categoryKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String category) => _categoryKeys.putIfAbsent(category, GlobalKey.new);

  /// See [_refreshListKey].
  Key _listKey = listContentsKey(const []);

  /// Recreated with each [_listKey], carrying the offset over: a fresh
  /// scroll view starts at the top, and an operator opening a category half
  /// way down the panel would be thrown back to the first one.
  ScrollController _scroll = ScrollController();
  double _offset = 0;

  /// Bumped by a category whose own element set changed under it — see
  /// [_refreshListKey], which cannot see that from out here.
  int _rowsRevision = 0;

  void _rowsChanged() {
    if (!mounted) return;
    setState(() {
      _rowsRevision++;
      _refreshListKey();
    });
  }

  @override
  void initState() {
    super.initState();
    final stored = widget.services.settings.prefs.getString(_openCategoryPrefsKey);
    _openCategory = stored == null
        ? _commonCategoryKey
        : stored.isEmpty
        ? null
        : stored;
    _loadExtensionPanels();
    // Extension toggles restart the runtime with a different panel set.
    widget.services.extensions.runtimeGeneration.addListener(_loadExtensionPanels);
  }

  @override
  void dispose() {
    widget.services.extensions.runtimeGeneration.removeListener(_loadExtensionPanels);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadExtensionPanels() async {
    await widget.services.extensions.start();
    final panels = await widget.services.extensions.getSettingsPanels();
    if (!mounted) return;
    setState(() {
      _extensionPanels = panels;
      _refreshListKey();
    });
  }

  /// The key the scroll view takes, and the controller that goes with it.
  ///
  /// On the web a click is hit-tested against the accessibility DOM, and a
  /// list rebuilt in place can leave those elements holding the previous
  /// arrangement's geometry — the click then acts on a neighbouring row
  /// (docs/quirks.md, `listContentsKey`). Every row here acts on a tap, and
  /// four things move rows: the query, which category is open, the arrival
  /// of the extension-contributed ones, and a category's own element set
  /// changing under it — a group grows sub-options when a toggle goes on,
  /// and a Tier 2 extension panel rebuilds its whole definition on every
  /// commit. Only the category can see that last one, so it reports it
  /// ([_rowsChanged]).
  ///
  /// Keyed on the QUERY rather than on the surviving row set, unlike every
  /// other list taking this fix: which rows a category keeps is decided
  /// inside it, after its own async load and its own scoring, so this widget
  /// cannot enumerate them. The cost is a remount on a keystroke that
  /// narrows nothing; the alternative is not knowing when rows moved.
  ///
  /// Nothing is disposed by the remount — every category is globally keyed
  /// ([_keyFor]), so the framework moves it into the new scroll view with
  /// its State intact. That matters more here than anywhere else: dropping
  /// a form disposes the FocusNodes and TextEditingControllers it owns, and
  /// on web that teardown takes the focus out of the search field the
  /// operator is still typing in (see [settingsCategory]).
  void _refreshListKey() {
    final key = listContentsKey([
      _searchController.text.trim().toLowerCase(),
      _openCategory ?? '',
      _closedWhileSearching.length,
      _rowsRevision,
      for (final group in widget.services.settingsRegistry.groups) group.key,
      for (final descriptor in _extensionPanels ?? const <Map<String, dynamic>>[]) descriptor['panelKey'],
    ]);
    if (key == _listKey) return;
    _listKey = key;
    // The outgoing controller is still attached to the scroll view being
    // replaced, which only detaches during the coming build — disposing it
    // here would assert.
    final outgoing = _scroll;
    WidgetsBinding.instance.addPostFrameCallback((_) => outgoing.dispose());
    _scroll = ScrollController(initialScrollOffset: _offset);
  }

  bool _expanded(String key) => _searching ? !_closedWhileSearching.contains(key) : _openCategory == key;

  void _toggle(String key) {
    final opening = !_expanded(key);
    setState(() {
      if (_searching) {
        if (!_closedWhileSearching.remove(key)) _closedWhileSearching.add(key);
      } else {
        _openCategory = _openCategory == key ? null : key;
        widget.services.settings.prefs.setString(_openCategoryPrefsKey, _openCategory ?? '');
      }
      _refreshListKey();
    });
    if (opening) _scrollToCategory(key);
  }

  /// Brings a category the operator just opened to the top of the pane, so
  /// what they opened it for is the first thing under its band — a category
  /// half way down opens with most of itself below the fold otherwise, and
  /// the one above it closing pulls it somewhere else again.
  ///
  /// A list rebuilt mid-reveal (a category that grows rows under itself, a
  /// keystroke in the search field) replaces the controller this is animating
  /// and the pane stops where it got to. Rare enough to be left as a pause
  /// rather than paid for with a re-issue that could fight the operator's own
  /// scrolling.
  void _scrollToCategory(String key) {
    // A frame past the opening animation, not with it: the pane can only
    // scroll as far as the content it has, and the room this needs is
    // precisely what that animation is still making.
    Future.delayed(accordionDuration + const Duration(milliseconds: 16), () {
      if (!mounted || !_scroll.hasClients) return;
      // The category's own sliver, brought to the pane's leading edge —
      // measured now rather than at the tap, since the category that closed
      // in the same gesture (one open at a time) has moved this one since.
      final band = _categoryKeys[key]?.currentContext;
      // Its own mounted-ness, not this panel's: a category can go while the
      // animation runs (the search empties it, an extension unloads).
      if (band == null || !band.mounted) return;
      Scrollable.ensureVisible(band, alignment: 0, duration: accordionDuration, curve: accordionCurve);
    });
  }

  /// Every category below Common Preferences, core and extension-contributed
  /// alike, in ONE order — the same rule the sidebar sorts its entries by.
  /// Rendering the registry's groups and then the extensions' panels
  /// instead would pin every extension below every core group, and a group
  /// declaring itself last (Privacy) would land in the middle of the list.
  List<Widget> _orderedCategories(String query) {
    final categories = <({int order, int index, Widget widget})>[];
    for (final group in widget.services.settingsRegistry.groups) {
      categories.add((
        order: group.order,
        index: categories.length,
        widget: _SettingsGroupForm(
          key: _keyFor('group:${group.key}'),
          services: widget.services,
          group: group,
          sliver: true,
          searchQuery: query,
          expanded: _expanded('group:${group.key}'),
          onToggle: () => _toggle('group:${group.key}'),
          onRowsChanged: _rowsChanged,
          openPanel: widget.openPanel,
        ),
      ));
    }
    // Nothing stands in for them while they load: the core categories are
    // already on screen, and an extension's heading appearing a moment
    // later reads as the list filling in rather than as the panel waiting
    // on something.
    for (final descriptor in _extensionPanels ?? const <Map<String, dynamic>>[]) {
      final panelKey = descriptor['panelKey'] as String;
      categories.add((
        order: (descriptor['order'] as num?)?.toInt() ?? _extensionPanelDefaultOrder,
        index: categories.length,
        widget: ExtensionSettingsPanel(
          key: _keyFor('extension:$panelKey'),
          services: widget.services,
          descriptor: descriptor,
          embedded: true,
          sliver: true,
          sectionTitle: (descriptor['title'] as String?) ?? panelKey,
          searchQuery: query,
          expanded: _expanded('extension:$panelKey'),
          onToggle: () => _toggle('extension:$panelKey'),
          onRowsChanged: _rowsChanged,
        ),
      ));
    }
    // Declaration order breaks ties explicitly — Dart's sort is not stable
    // above 32 elements, and a list of categories that reshuffles between
    // builds is a list nobody can learn.
    categories.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
    });
    return [for (final category in categories) category.widget];
  }

  void _queryChanged(String query) {
    setState(() {
      final searching = query.trim().isNotEmpty;
      if (searching != _searching) _closedWhileSearching.clear();
      _searching = searching;
      _refreshListKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final extensionPanels = _extensionPanels;
    final query = _searchController.text.trim().toLowerCase();
    // The search bar isn't a row, so it takes the rows' own content inset
    // explicitly — the ambient ListTileTheme, which already carries the
    // grab-strip clearance (layouts.md) and the pane's centering. Anything
    // else and the field it filters with is wider than the results.
    final rowInset = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
    final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned above the scroll: filters every category below by setting
        // key, title, and description; categories with no match disappear
        // entirely, heading included.
        //
        // On a lighter wash of the category bands' ground, with the field
        // itself on the surface: the strip belongs to the chrome above the
        // list rather than to the list, and the field reads as the one thing
        // on it to type into. At the band's own strength the strip merges
        // with the collapsed bands under it into a single block of tint.
        ColoredBox(
          color: Color.lerp(theme.colorScheme.surface, haloDialogBandColorAt(context), 0.5)!,
          child: Padding(
            // Bottom as well as top: the categories below have no margin of
            // their own (a heading abuts its rows), so this is what keeps the
            // field off the first one.
            padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.xl)),
            child: TextField(
              selectAllOnFocus: false,
              key: const ValueKey('settings-search'),
              controller: _searchController,
              onChanged: _queryChanged,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.settings.search.clear),
                        onPressed: () {
                          _searchController.clear();
                          _queryChanged('');
                        },
                      ),
                hintText: context.t.settings.search.hint,
                border: searchBorder,
                focusedBorder: haloFocusedBorder(searchBorder, context),
              ),
            ),
          ),
        ),
        Expanded(
          // The offset is recorded rather than read back off the controller
          // after the fact: the controller that HELD it is replaced with the
          // scroll view (see [_refreshListKey]), so by then it is gone.
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) _offset = notification.metrics.pixels;
              return false;
            },
            // Every category is built up front rather than lazily: one
            // scrolled out of a lazy list is DISPOSED, and disposing a form
            // mid-search drops the focus of the field being typed in (see
            // [settingsCategory]). No horizontal padding either — rows run to
            // the pane's edges and inset their own contents through the
            // ambient ListTileTheme (see _rowContentPadding in
            // form_renderer.dart), landing on the same inset as the search
            // bar above.
            // A sliver viewport, not a plain one: the category bands PIN,
            // and so do the section bands inside them (docs/design/
            // user-interface.md § Settings lists).
            child: CustomScrollView(
              // Keyed and controller-carried: see [_refreshListKey].
              key: _listKey,
              controller: _scroll,
              slivers: [
                // Hidden rather than dropped while a search runs: its rows
                // are copies of ones the categories below already offer, so
                // showing it would answer every query twice.
                _CommonSettingsCategory(
                  key: _keyFor(_commonCategoryKey),
                  services: widget.services,
                  extensionPanels: extensionPanels,
                  expanded: _expanded(_commonCategoryKey),
                  onToggle: () => _toggle(_commonCategoryKey),
                  onRowsChanged: _rowsChanged,
                  hidden: _searching,
                ),
                ..._orderedCategories(query),
                const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The `common: true` subset of every declared group — core (via
/// [_SettingsGroupForm]'s `commonOnly`) and extension-contributed panels
/// (via [ExtensionSettingsPanel]'s) alike — as the panel's leading
/// category, the only one most operators ever open. Each candidate group is
/// always rendered: whether it ends up empty (nothing in it is flagged
/// `common`, or an `environment` filter rules out everything left) is only
/// known after its own async load, so an empty one collapses itself to
/// nothing rather than this widget pre-filtering synchronously the way a
/// static whitelist could.
class _CommonSettingsCategory extends StatelessWidget {
  final HaLoServices services;

  /// The extension panels to draw the common rows from, or null while the
  /// panel above is still loading them.
  final List<Map<String, dynamic>>? extensionPanels;

  final bool expanded;
  final VoidCallback onToggle;
  final bool hidden;

  /// See [_SettingsGroupForm.onRowsChanged]: the rows in here are drawn
  /// from every group and panel, so they move for all the same reasons.
  final VoidCallback onRowsChanged;

  const _CommonSettingsCategory({
    super.key,
    required this.services,
    required this.extensionPanels,
    required this.expanded,
    required this.onToggle,
    required this.onRowsChanged,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final panels = extensionPanels;
    return settingsCategorySliver(
      context,
      title: context.t.settings.panels.commonSettings,
      expanded: expanded,
      onToggle: onToggle,
      hidden: hidden,
      // Each contributing group is a sliver of its own, so the section band
      // naming it pins under this category's band while its rows pass.
      sliver: SliverMainAxisGroup(
        slivers: [
          for (final group in services.settingsRegistry.groups)
            _SettingsGroupForm(services: services, group: group, commonOnly: true, sliver: true, onRowsChanged: onRowsChanged),
          if (panels != null)
            for (final descriptor in panels)
              ExtensionSettingsPanel(
                services: services,
                descriptor: descriptor,
                embedded: true,
                commonOnly: true,
                sliver: true,
                sectionTitle: (descriptor['title'] as String?) ?? (descriptor['panelKey'] as String),
                onRowsChanged: onRowsChanged,
              ),
        ],
      ),
    );
  }
}
