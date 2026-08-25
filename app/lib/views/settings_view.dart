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
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;


import '../config/experiments.dart';
import '../config/release_notes.dart';
import '../config/user_agent.dart';
import '../config/version.dart';
import '../i18n/strings.g.dart';
import '../main.dart';
import 'panel_use_tracker.dart';
import '../services/app_storage.dart';
import '../services/data_file_manager.dart';
import '../services/deep_link_service.dart';
import '../services/error_reporting_service.dart';
import '../services/extension_service.dart';
import '../services/link_opener.dart';
import '../services/pusher_service.dart';
import '../services/settings_service.dart';
import '../tools/form_chrome_labels.dart';
import '../tools/sync_account_identity.dart';
import 'header_profile_label.dart';
import 'help_panel.dart';
import '../settings/settings_catalog.dart' show elementSearchScore;
import '../settings/settings_registry.dart';
import 'confirm_device_dialog.dart';
import 'experiments_pane.dart';
import 'extensions_panel.dart';
import 'peers_panel.dart';
import 'station_panel.dart';
import 'ham2k_logo.dart';
import 'notice_history_view.dart';
import 'oauth_browser_login.dart';
import 'operation_dialogs.dart';
import 'release_overlay.dart';
import 'switch_accounts_dialog.dart';
import 'update_check_row.dart';
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
      // The `common: true`-flagged subset of the declarative settings
      // registry AND extension panels (see settings_registry.dart); the
      // full set lives under All Settings.
      _SettingsPanelEntry(
          key: 'settings',
          title: t.settings.panels.commonPreferences,
          icon: MdiIcons.tune,
          order: 0,
          description: t.settings.panels.commonPreferencesDescription),
      // Immediately after Common Preferences: every declared group — core,
      // sync, and extension — in one place.
      _SettingsPanelEntry(
          key: 'all_settings',
          title: t.settings.panels.allSettings,
          icon: MdiIcons.cog,
          order: 5,
          description: t.settings.panels.allSettingsDescription),
      _SettingsPanelEntry(
          key: 'sync',
          title: t.settings.sync.title,
          icon: MdiIcons.sync,
          order: 10,
          description: t.settings.panels.syncDescription),
      _SettingsPanelEntry(
          key: 'accounts',
          title: t.settings.accounts.title,
          icon: MdiIcons.key,
          order: 20,
          description: t.settings.panels.accountsDescription),
      _SettingsPanelEntry(
          key: 'help',
          title: t.settings.help.title,
          icon: MdiIcons.lifebuoy,
          order: 95,
          description: t.settings.help.description),
      _SettingsPanelEntry(
          key: 'extensions',
          title: t.settings.panels.extensions,
          icon: MdiIcons.toyBrick,
          order: 40,
          description: t.settings.panels.extensionsDescription),
    ];
// Before Common Preferences (order 0) — the Profiles panel leads the list.
// Internally "profiles"; until multi-profile features are enabled it
// presents itself as just "Callsign".
const _profilesPanelOrder = -10;
// Between Callsign and Common Preferences (0) — see the entry itself.
const _stationPanelOrder = -5;
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

  const SettingsView({
    super.key,
    required this.services,
    this.initialPanel,
    this.embedded = false,
    this.onBack,
    this.leadingInset = 0,
  });

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
      // Callsign (-10) and Common Preferences (0) — who you are, then what
      // you're operating with, then how the app behaves. Not hidden
      // on web: the serial transport works there,
      // via the Web Serial API. TCP and the Icom network transport
      // don't — a radio using either throws UnsupportedError on
      // connect, just not hidden a layer up from it.
      if (settings.experimentEnabled('gato') /* stored key, see experiments.yaml */)
        _SettingsPanelEntry(
          key: 'station',
          title: t.settings.panels.station,
          icon: MdiIcons.cat,
          order: _stationPanelOrder,
          description: t.settings.panels.stationDescription,
        ),
      // Between Sync (10) and Accounts (20): both are about where the log
      // goes — cloud first, then the devices beside you.
      if (settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */)
        _SettingsPanelEntry(
          key: 'peers',
          title: t.settings.panels.peers,
          icon: MdiIcons.lan,
          order: 15,
          description: t.settings.panels.peersDescription,
        ),
      ..._fixedCorePanels(t),
      // After the extension-contributed panels (default order 50): data
      // files are contributed by extensions too, so they sit alongside
      // them. Not in _fixedCorePanels because its icon resolves an MDI
      // name at runtime.
      _SettingsPanelEntry(
        key: 'data_files',
        title: t.settings.panels.dataFiles,
        icon: MdiIcons.fileCabinet,
        order: 60,
        description: t.settings.panels.dataFilesDescription,
      ),
      // sidebar: false (e.g. call-notes, HALO-53) opts a panel out of this
      // top-level list — it's still returned by getSettingsPanels() for
      // whichever screen the extension links it from instead (Data Files'
      // own "Extensions" section, here).
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
        secondary: LayoutBuilder(builder: (context, constraints) {
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
            body: SettingsList(
              extraLeft: safeLeft,
              child: _buildPanelContent(effectivePanel, widget.services, _panels),
            ),
          ),
          );
        }),
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

  Widget _buildSidebar(
    BuildContext context, {
    required bool isWide,
    required List<_SettingsPanelEntry> panels,
    required String selectedKey,
  }) {
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
                  children: [TextSpan(text: mono, style: const TextStyle(fontFamily: 'RobotoMono'))],
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
          selectedTileColor: Color.lerp(
            Theme.of(context).colorScheme.surface,
            haloDialogBandColorAt(context),
            0.5,
          ),
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

/// Stateful only to own a [PanelUseTracker]: the narrow layout pushes each
/// settings panel as its own route, and without per-instance de-duplication
/// here `panel_used` would be reported for wide windows only — a bias by
/// layout rather than by what operators actually do.
class _SettingsPanelScreen extends StatefulWidget {
  final _SettingsPanelEntry panel;
  final HaLoServices services;

  const _SettingsPanelScreen({required this.panel, required this.services});

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
      body: _buildPanelContent(panel, services, _panels),
    );
  }
}

/// Extension panels all report as a single `extension` rather than by their
/// own key: those ids come from whatever the operator has installed, so
/// reporting them by name would be unbounded cardinality AND would leak
/// extension usage, which docs/design/telemetry.md excludes on purpose.
String _panelUseName(_SettingsPanelEntry panel) =>
    panel.descriptor != null ? 'extension' : panel.key;

Widget _buildPanelContent(_SettingsPanelEntry panel, HaLoServices services, PanelUseTracker panels) {
  final Widget content;
  switch (panel.key) {
    case 'profiles':
      content = _ProfilesPanel(services: services);
    case 'station':
      content = StationPanel(services: services);
    case 'settings':
      content = _CommonSettingsPanel(services: services);
    case 'extensions':
      content = ExtensionsPanel(services: services);
    case 'all_settings':
      content = _AllSettingsPanel(services: services);
    case 'sync':
      content = _SyncPanel(services: services);
    case 'peers':
      content = PeersPanel(services: services);
    case 'accounts':
      content = _AccountsPanel(services: services);
    case 'data_files':
      content = _DataFilesPanel(services: services);
    case 'developer':
      content = _DeveloperPanel(services: services);
    case 'about':
      content = _AboutPanel(services: services);
    case 'help':
      content = const HelpPanel();
    default:
      final descriptor = panel.descriptor;
      content = descriptor == null
          ? const SizedBox.shrink()
          : _ExtensionSettingsPanel(services: services, descriptor: descriptor);
  }
  // Observes only, and wraps the body once so BOTH returns below are covered.
  final body = Listener(
    onPointerDown: (_) => panels.used(_panelUseName(panel)),
    child: content,
  );
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
  return LayoutBuilder(builder: (context, constraints) {
    final base = ListTileTheme.of(context).contentPadding ?? _defaultRowInset;
    return ListTileTheme.merge(
      contentPadding: base.add(EdgeInsets.symmetric(horizontal: settingsRowCentering(constraints.maxWidth))),
      child: _SettingsPaneWidth(
        width: constraints.maxWidth,
        child: SafeArea(top: false, left: false, right: false, child: body),
      ),
    );
  });
}

/// The pane's width, published once per layout for the section bands, whose
/// pinned extent has to be measured against it.
///
/// Not read from a `SliverLayoutBuilder` at the band itself, which is where
/// it is wanted: `SliverConstraints` carry `scrollOffset`, so such a builder
/// re-runs on every frame of a scroll — one text measurement per section per
/// frame, across every group and extension panel in All Settings, for a width
/// that cannot change while scrolling.
class _SettingsPaneWidth extends InheritedWidget {
  final double width;

  const _SettingsPaneWidth({required this.width, required super.child});

  @override
  bool updateShouldNotify(_SettingsPaneWidth old) => old.width != width;
}

/// The width [_buildPanelContent] published, or the window's where a panel is
/// rendered outside it (a test pumping one directly).
double settingsPaneWidth(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_SettingsPaneWidth>()?.width ?? MediaQuery.sizeOf(context).width;

/// The narrow layout has no ListTileTheme of its own to merge over (the wide
/// pane sets one before [_buildPanelContent] runs), so it starts from this.
const _defaultRowInset = EdgeInsets.symmetric(horizontal: settingsRowInset);

/// What a settings row's contents inset by, on top of the row inset, so they
/// land at [idealPaneWidth] centred in a pane of [paneWidth]. Zero once the
/// pane is narrower than that.
double settingsRowCentering(double paneWidth) => max(0.0, (paneWidth - idealPaneWidth) / 2);

/// The "profiles" panel — callsign profiles. Until multi-profile features
/// are enabled it presents itself as just "Callsign": a single field, saved
/// as the default profile's `operatorCall` (see [SettingsService.activeProfile]),
/// followed by the optional personal details log generators may need.
class _ProfilesPanel extends StatefulWidget {
  final HaLoServices services;

  const _ProfilesPanel({required this.services});

  @override
  State<_ProfilesPanel> createState() => _ProfilesPanelState();
}

class _ProfilesPanelState extends State<_ProfilesPanel> {
  /// The DXCC entity of the profile callsign, resolved through the extension
  /// runtime's offline lookup — Dart has no callsign parser of its own. Null
  /// while unresolved, which [_sectionLabel] reads as "don't know" rather than
  /// as an answer.
  String? _entityPrefix;

  /// The callsign [_entityPrefix] was resolved for, so a rebuild triggered by
  /// any other setting doesn't re-annotate. Only ever set from a lookup that
  /// ANSWERED: recording a failed one would cache "don't know" for the rest of
  /// the panel's life, and the operator's only way out would be to leave and
  /// come back. Same rule as FlagsService's `_lastFetchedCall`.
  String? _annotatedCall;

  @override
  void initState() {
    super.initState();
    _resolveEntityPrefix();
  }

  /// Bumped per resolve so a slow one can't install its answer over a newer
  /// one's — `lookupCall` waits on the whole hook pipeline (8s timeout), long
  /// enough for the operator to edit the callsign while one is in flight, and
  /// the loser would otherwise repaint the label for the callsign they just
  /// left. Same guard as `activities_view.dart`'s `_controlsRequest`.
  int _resolveRequest = 0;

  Future<void> _resolveEntityPrefix() async {
    final call = widget.services.settings.activeProfile.operatorCall;
    if (call.isEmpty || call == _annotatedCall) return;
    final request = ++_resolveRequest;
    // Idempotent and memoized (ExtensionService.start), so this waits out a
    // boot still in flight instead of reading a not-yet-running runtime as
    // "this callsign has no entity" — the first-run path, where a US operator
    // opening Settings early would otherwise never be offered a section.
    await widget.services.extensions.start();
    final info = await widget.services.extensions.lookupCall(
      call,
      qso: const {},
      operation: const {},
      online: false,
    );
    if (!mounted || request != _resolveRequest) return;
    final prefix = (info?['guess'] as Map<String, dynamic>?)?['entityPrefix'] as String?;
    if (prefix == null) {
      debugPrint('[settings] no DXCC entity for "$call" — the section field stays hidden');
      return;
    }
    _annotatedCall = call;
    setState(() => _entityPrefix = prefix);
  }

  /// What to call the section field, or null to leave it out entirely.
  ///
  /// Sections are an ARRL/RAC construct: every US entity — the lower 48 plus
  /// Alaska, Hawaii, the Pacific islands, Puerto Rico and the Virgin Islands —
  /// carries a `K…` entity prefix, and Canada is `VE`. An unresolved prefix
  /// hides the field rather than guessing, EXCEPT when a section is already
  /// stored: a value the operator can't see is a value they can't correct. That
  /// case gets the bare "Section" — naming a society we have not established
  /// would tell a VE operator their RAC section is an ARRL one.
  String? _sectionLabel(BuildContext context, String section) {
    final t = context.t.settings.profiles;
    final prefix = _entityPrefix;
    if (prefix != null && prefix.startsWith('K')) return t.arrlSection;
    if (prefix == 'VE') return t.racSection;
    return section.isEmpty ? null : t.section;
  }

  Future<void> _editCallsign() async {
    final result = await editOneFieldDialog(
      context,
      title: context.t.common.callsign,
      fieldLabel: context.t.common.callsign,
      fieldInitial: widget.services.settings.activeProfile.operatorCall,
      fieldCapitalization: TextCapitalization.characters,
    );
    if (result == null) return;
    await widget.services.setOperatorCall(result);
    await _resolveEntityPrefix();
  }

  /// One dialog for the whole group, whichever row was tapped — these are four
  /// facets of one answer ("who is submitting this log"), and an operator
  /// filling them in for the first time would otherwise open and dismiss four
  /// dialogs. The rows stay separate so each value is readable at a glance;
  /// [focusKey] opens on the one that was tapped.
  Future<void> _editPersonalInfo(String focusKey, String? sectionLabel) async {
    final profile = widget.services.settings.activeProfile;
    final result = await showHaloDialog<Map<String, String>>(
      context: context,
      builder: (context) => _PersonalInfoDialog(
        initial: {
          for (final key in _personalInfoKeys) key: (profile.data[key] as String?) ?? '',
        },
        sectionLabel: sectionLabel,
        focusKey: focusKey,
      ),
    );
    if (result == null) return;
    await widget.services.settings.setProfileFields(SettingsService.defaultProfileId, result);
  }

  Widget _fieldTile(String key, String label, String value, IconData icon, String? sectionLabel) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? context.t.settings.profiles.notSet : value),
    onTap: () => _editPersonalInfo(key, sectionLabel),
    mouseCursor: SystemMouseCursors.click,
  );

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final theme = Theme.of(context);
    final t = context.t.settings.profiles;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final profile = settings.activeProfile;
        final call = profile.operatorCall;
        final sectionLabel = _sectionLabel(context, profile.operatorSection);
        return ListView(
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            ListTile(
              leading: const Icon(MdiIcons.account),
              title: Text(context.t.common.callsign),
              subtitle: Text(call.isEmpty ? t.notSet : call),
              onTap: _editCallsign,
              mouseCursor: SystemMouseCursors.click,
            ),
            SectionHeader(t.personalInfo),
            Padding(
              // The rows' own inset, off the ambient ListTileTheme — it
              // carries the grab-strip clearance and the pane's centring,
              // neither of which a hand-written inset here would have.
              padding: (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero)
                  .add(const EdgeInsets.only(bottom: Space.xs)),
              child: Text(
                t.personalInfoNote,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            _fieldTile('operatorName', t.name, profile.operatorName, MdiIcons.cardAccountDetails, sectionLabel),
            _fieldTile('operatorEmail', t.email, profile.operatorEmail, MdiIcons.email, sectionLabel),
            _fieldTile('operatorClub', t.club, profile.operatorClub, MdiIcons.accountGroup, sectionLabel),
            if (sectionLabel != null)
              _fieldTile(
                'operatorSection',
                sectionLabel,
                profile.operatorSection,
                MdiIcons.mapMarkerRadius,
                sectionLabel,
              ),
          ],
        );
      },
    );
  }
}

/// The Personal Info fields, in the order the rows show them. Also the
/// dialog's field order, so the two can't drift apart.
const _personalInfoKeys = ['operatorName', 'operatorEmail', 'operatorClub', 'operatorSection'];

/// Every Personal Info field in one dialog — see [_ProfilesPanelState._editPersonalInfo]
/// for why the rows are separate but the editor is not.
///
/// Returns every field, not just the edited ones: the caller writes them in a
/// single store update, so a partial map would look like "clear the rest".
class _PersonalInfoDialog extends StatefulWidget {
  final Map<String, String> initial;

  /// Null when the callsign's entity has no section (see `_sectionLabel`), in
  /// which case the field is left out of the dialog exactly as it is left out
  /// of the list — and, since it is then absent from the result, its stored
  /// value is carried through untouched rather than blanked.
  final String? sectionLabel;

  final String focusKey;

  const _PersonalInfoDialog({required this.initial, required this.sectionLabel, required this.focusKey});

  @override
  State<_PersonalInfoDialog> createState() => _PersonalInfoDialogState();
}

class _PersonalInfoDialogState extends State<_PersonalInfoDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final key in _visibleKeys) key: TextEditingController(text: widget.initial[key] ?? ''),
  };

  List<String> get _visibleKeys =>
      widget.sectionLabel == null ? _personalInfoKeys.where((k) => k != 'operatorSection').toList() : _personalInfoKeys;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() => Navigator.of(context).pop({
    for (final entry in _controllers.entries)
      // The section is a code, and TextCapitalization is only a keyboard hint
      // that a hardware keyboard ignores — so the uppercasing happens here.
      entry.key: entry.key == 'operatorSection' ? entry.value.text.toUpperCase() : entry.value.text,
  });

  String _labelFor(String key) {
    final t = context.t.settings.profiles;
    return switch (key) {
      'operatorName' => t.name,
      'operatorEmail' => t.email,
      'operatorClub' => t.club,
      _ => widget.sectionLabel ?? t.section,
    };
  }

  @override
  Widget build(BuildContext context) {
    final keys = _visibleKeys;
    return HaloDialog(
      title: Text(context.t.settings.profiles.personalInfo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final key in keys) ...[
            if (key != keys.first) const SizedBox(height: Space.md),
            TextField(
              selectAllOnFocus: false,
              controller: _controllers[key],
              autofocus: key == widget.focusKey,
              keyboardType: key == 'operatorEmail' ? TextInputType.emailAddress : TextInputType.text,
              textCapitalization: switch (key) {
                'operatorEmail' => TextCapitalization.none,
                'operatorSection' => TextCapitalization.characters,
                _ => TextCapitalization.words,
              },
              decoration: poloFieldDecoration(context, _labelFor(key)),
              onSubmitted: (_) => _save(),
            ),
          ],
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
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

  /// Common Preferences mode: keep only elements flagged `common: true`
  /// (settings_registry.dart's [elementIsCommon]). False shows everything
  /// the group declares (minus whatever `environment` rules out — that
  /// filter always applies, common or not).
  final bool commonOnly;

  /// All Settings' search query (lowercased); when it matches nothing in
  /// this group, the whole section — header included — renders empty.
  final String searchQuery;

  const _SettingsGroupForm({
    required this.services,
    required this.group,
    this.commonOnly = false,
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
        final resolved = await widget.services.systemLists.resolveInElements(await widget.group.buildElements());
        // Platform-excluded elements don't exist on this session at all —
        // baked in here rather than filtered per-view, same as
        // [_ExtensionSettingsPanel].
        final elements = filterElementsForEnvironment(resolved);
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
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: CircularProgressIndicator())),
      );
    }
    // A group can decline to contribute anything at all — RadioSettingsGroup
    // does while the CAT experiment is off. Its title is chrome for the rows
    // below it, so with no rows there is nothing to head.
    if (elements.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    if (widget.commonOnly) {
      elements = [
        for (final el in elements)
          if (elementIsCommon(el)) el,
      ];
      if (elements.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    // A group the search excludes is HIDDEN, not unmounted. Unmounting it
    // disposes every FocusNode and TextEditingController its FormRenderer
    // owns, and on web that teardown takes the browser's text-input element
    // with it: focus falls back to the route's scope and the next keystrokes
    // are swallowed, so the query loses characters as it is typed. macOS has
    // no DOM and shows no symptom.
    //
    // `maintainState` is what keeps the State (and its nodes) alive; the
    // ExcludeFocus is what keeps hidden fields out of the Tab order, which
    // Offstage alone does not do. Nothing is spent that an empty query
    // doesn't already spend — with no search every group is mounted anyway.
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
    // A section, not a box: its band is PINNED over its own rows and pushed
    // off by the next section's, which only a SliverMainAxisGroup can
    // express. The band is therefore no longer part of the form definition —
    // the rows are the form, the heading is the sliver above them.
    return SliverVisibility(
      visible: !hidden,
      maintainState: true,
      sliver: SliverMainAxisGroup(slivers: [
        SectionHeader.pinned(context, widget.group.title, width: settingsPaneWidth(context)),
        SliverToBoxAdapter(
          child: ExcludeFocus(
            excluding: hidden,
            child: FormRenderer(
          formDefinition: {'elements': elements},
          initialState: const {},
          showActions: false,
          showTitle: false,
          developerMode: widget.services.settings.developerMode,
          labels: formRendererLabelsFor(context.t),
          settingsList: true,
          onChange: _autosave,
          onOpenLink: openExternalUrl,
          onSubmit: (_) {},
          onCancel: () {},
            ),
          ),
        ),
      ]),
    );
  }
}

/// The `common: true` subset of every declared group — core (via
/// [_SettingsGroupForm]'s `commonOnly`) and extension-contributed panels
/// (via [_ExtensionSettingsPanel]'s) alike — the panel most users ever
/// need. Each candidate section is always rendered: whether it ends up
/// empty (nothing in that group/panel is flagged `common`, or an
/// `environment` filter rules out everything left) is only known after its
/// own async load, so an empty one collapses itself to nothing rather than
/// this widget pre-filtering synchronously the way a static whitelist
/// could.
class _CommonSettingsPanel extends StatefulWidget {
  final HaLoServices services;

  const _CommonSettingsPanel({required this.services});

  @override
  State<_CommonSettingsPanel> createState() => _CommonSettingsPanelState();
}

class _CommonSettingsPanelState extends State<_CommonSettingsPanel> {
  List<Map<String, dynamic>>? _extensionPanels;

  @override
  void initState() {
    super.initState();
    _loadExtensionPanels();
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
    if (mounted) setState(() => _extensionPanels = panels);
  }

  @override
  Widget build(BuildContext context) {
    final extensionPanels = _extensionPanels;
    // A CustomScrollView because each section pins its own band while its
    // rows scroll under it (see [_SettingsGroupForm]). No horizontal
    // padding: rows, bands and dividers run to the pane's own edges, and
    // their CONTENTS are inset by the ambient ListTileTheme instead.
    return CustomScrollView(
      slivers: [
        // Straight into the first section: its band heads the list, flush
        // under the pane's own header.
        for (final group in widget.services.settingsRegistry.groups)
          _SettingsGroupForm(services: widget.services, group: group, commonOnly: true),
        if (extensionPanels != null)
          for (final descriptor in extensionPanels)
            _ExtensionSettingsPanel(
              services: widget.services,
              descriptor: descriptor,
              embedded: true,
              commonOnly: true,
              sectionTitle: (descriptor['title'] as String?) ?? (descriptor['panelKey'] as String),
            ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
      ],
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
    // The search bar isn't a row, so it takes the rows' own content inset
    // explicitly — the ambient ListTileTheme, which already carries the
    // grab-strip clearance (layouts.md) and the pane's centering. Anything
    // else and the field it filters with is wider than the results.
    final rowInset = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
    final searchBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned above the scroll: filters every section below by setting
        // key, title, and description; sections with no match disappear
        // entirely, title included.
        Padding(
          // Bottom as well as top: the sections below have no margin of their
          // own any more (a band abuts its rows), so this is what keeps the
          // field off the first one.
          padding: rowInset.add(const EdgeInsets.symmetric(vertical: Space.xl)),
          child: TextField(
            selectAllOnFocus: false,
            key: const ValueKey('all-settings-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(MdiIcons.magnify, size: 18),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(MdiIcons.close, size: 18, semanticLabel: context.t.settings.search.clear),
                      onPressed: () => setState(() => _searchController.clear()),
                    ),
              hintText: context.t.settings.search.hint,
              border: searchBorder,
              focusedBorder: haloFocusedBorder(searchBorder, context),
            ),
          ),
        ),
        Expanded(
          // Sliver sections, so each band pins over its own rows. No
          // horizontal padding — rows run to the pane's edges and inset their
          // own contents through the ambient ListTileTheme (see
          // _rowContentPadding in form_renderer.dart), landing on the same
          // inset the search bar above uses.
          child: CustomScrollView(
            slivers: [
              for (final group in widget.services.settingsRegistry.groups)
                _SettingsGroupForm(services: widget.services, group: group, searchQuery: query),
              if (extensionPanels == null)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: CircularProgressIndicator())),
                )
              else
                for (final descriptor in extensionPanels)
                  _ExtensionSettingsPanel(
                    services: widget.services,
                    descriptor: descriptor,
                    embedded: true,
                    sectionTitle: (descriptor['title'] as String?) ?? (descriptor['panelKey'] as String),
                    searchQuery: query,
                  ),
              const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
            ],
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

/// How often the Sync panel re-asks the server while it's on screen, with
/// and without a realtime connection to lean on.
///
/// api-lofi pushes a `permission` event on the ACCOUNT's channel the moment
/// another device asks to join (`Permission#notify_listeners`) and an
/// `account` event when its email settles, so where Pusher is configured
/// this poll is only a backstop for a socket that dropped — and one that
/// reconnects on its own inside 30s. Where it isn't (a checkout with no
/// `PUSHER_KEY`, so `services.pusher` is null), the poll is the *only* way
/// the Connection Requests row ever appears, which is why the two intervals
/// are so far apart.
const syncAccountPollWithRealtime = Duration(seconds: 60);
const syncAccountPollWithoutRealtime = Duration(seconds: 10);

class _SyncPanelState extends State<_SyncPanel> {
  Map<String, dynamic>? _syncAccount;
  bool _loadingSyncAccount = false;
  int? _localOperationCount;
  int? _localQsoCount;

  Timer? _accountPollTimer;
  StreamSubscription<PusherEvent>? _accountEvents;

  /// The account's Pusher channel, known only once account data has landed
  /// (`current_account.push_channel`) — so subscribing happens after a
  /// fetch, not in [initState].
  String? _accountChannel;

  @override
  void initState() {
    super.initState();
    if (widget.services.settings.syncEnabled) {
      _refreshSyncAccount();
      _startWatchingAccount();
    }
  }

  @override
  void dispose() {
    _stopWatchingAccount();
    super.dispose();
  }

  void _startWatchingAccount() {
    _accountPollTimer?.cancel();
    // Keyed on whether a subscription is actually LIVE, not merely on
    // whether this build has Pusher configured: before the first fetch the
    // channel is unknown, and a payload that carries none never yields one,
    // so deciding by `pusher != null` alone would drop those cases to a
    // 60-second wait with nothing anywhere saying why.
    final live = widget.services.pusher != null && _accountChannel != null;
    _accountPollTimer = Timer.periodic(
      live ? syncAccountPollWithRealtime : syncAccountPollWithoutRealtime,
      // A poll runs unattended, so anything escaping it escapes into the
      // zone handler — on a fixed short timer, which would turn one broken
      // extension call into a notice every ten seconds for as long as this
      // panel stays open.
      (_) => unawaited(_refreshSyncAccount(quiet: true).catchError(
        (Object error) => debugPrint('[sync-panel] background refresh failed: $error'),
      )),
    );
    _accountEvents ??= widget.services.pusher?.events.listen((event) {
      // Anything the server says about THIS account: a device asking to
      // join, or the account itself changing (an email confirmed from the
      // link, possibly on another device entirely).
      if (event.channel != _accountChannel) return;
      if (event.event != 'permission' && event.event != 'account') return;
      unawaited(_refreshSyncAccount(quiet: true));
    });
  }

  void _stopWatchingAccount() {
    _accountPollTimer?.cancel();
    _accountPollTimer = null;
    _accountEvents?.cancel();
    _accountEvents = null;
    final channel = _accountChannel;
    if (channel != null) widget.services.pusher?.unsubscribe(channel);
    _accountChannel = null;
  }

  /// Keeps the realtime subscription pointed at whatever account the last
  /// fetch reported — a switch mid-session moves it.
  void _subscribeToAccountChannel(Map<String, dynamic>? account) {
    final channel = ((account?['current_account'] as Map?)?['push_channel']) as String?;
    if (channel == null) {
      // Not fatal — the poll covers it — but it silently costs realtime, so
      // it must not be invisible to whoever is wondering why.
      if (widget.services.pusher != null && _accountChannel == null) {
        debugPrint('[sync-panel] account payload carries no push_channel — polling only');
      }
      return;
    }
    if (channel == _accountChannel) return;
    final previous = _accountChannel;
    if (previous != null) widget.services.pusher?.unsubscribe(previous);
    _accountChannel = channel;
    widget.services.pusher?.subscribe(channel);
    // Now that a push can wake this panel, back the poll off to its
    // fallback cadence.
    if (_accountPollTimer != null) _startWatchingAccount();
  }

  /// The local counts are two fast database queries and must not wait on the
  /// account fetch's network round-trip — offline, that request can take its
  /// full timeout to fail, and the operator's own numbers are knowable the
  /// whole time. The `finally` matters for the same reason the counts do:
  /// `syncAccountData` only swallows `ExtensionHostException`, so anything
  /// else (a dead host, a timeout) would otherwise leave the panel stuck on
  /// "Checking…" with no way back — the Refresh button just re-enters here.
  ///
  /// [quiet] is for the poll and the push: they must not put the Account row
  /// back to "Checking…" behind the operator's back, and "not available"
  /// must not flicker onto the counts row every minute either. Nothing the
  /// operator asked for is quiet.
  Future<void> _refreshSyncAccount({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) setState(() => _loadingSyncAccount = true);
    final operations = await widget.services.operations.syncCounts();
    final qsos = await widget.services.qsos.syncCounts();
    if (!mounted) return;
    setState(() {
      _localOperationCount = operations.total;
      _localQsoCount = qsos.total;
    });
    try {
      final account = await widget.services.extensions.syncAccountData();
      if (!mounted) return;
      // A fetch that couldn't reach the server leaves the panel saying what
      // it last knew. `syncAccountData` returns null only when the host
      // call itself failed — a genuinely unlinked device still answers with
      // a map — so writing that null through would state, falsely and
      // without explanation, that the account is gone, taking the pending
      // email, the resend row and the connection-request row with it. The
      // poll must do it silently; a refresh the operator asked for owes
      // them the reason.
      if (account == null) {
        if (!quiet) _notify(t.switchAccounts.serverUnreachable);
        return;
      }
      setState(() => _syncAccount = account);
      _subscribeToAccountChannel(account);
    } finally {
      if (mounted && !quiet) setState(() => _loadingSyncAccount = false);
    }
  }

  Future<void> _toggleSync(bool enabled) async {
    // A refusal (time travel bars sync) must not be recorded as a change or
    // followed by the watcher setup an enabled sync gets — the notice
    // setSyncEnabled posts is the operator's answer.
    if (!await widget.services.setSyncEnabled(enabled)) {
      if (mounted) setState(() {});
      return;
    }
    widget.services.track(enabled ? 'sync_enabled' : 'sync_disabled');
    // That await reaches secure storage, which can sit on a keyring prompt.
    // Closing Settings meanwhile already ran dispose(), so starting the
    // watch now would install a timer and a stream subscription on a dead
    // State with nothing left to cancel them.
    if (!mounted) return;
    if (enabled) {
      unawaited(_refreshSyncAccount());
      _startWatchingAccount();
    } else {
      _stopWatchingAccount();
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
      //
      unawaited(widget.services.syncEngine.runOneRound());
      unawaited(_refreshSyncAccount());
    }
  }

  /// The current account map from the last fetch — `null` until one lands.
  Map<String, dynamic>? get _currentAccount => (_syncAccount?['current_account'] as Map?)?.cast<String, dynamic>();

  /// The address a confirmation is outstanding for, or null when the
  /// account's email is settled. A `pending_email` equal to the confirmed
  /// one is not a change in flight — same rule syncAccountIdentity applies.
  String? get _pendingEmail {
    final pending = _currentAccount?['pending_email'] as String?;
    if (pending == null || pending.isEmpty) return null;
    return pending == _currentAccount?['email'] ? null : pending;
  }

  /// How many other devices are waiting for this account to let them in —
  /// `getAccountData`'s `pending_challenges`, which counts only permissions
  /// raised AGAINST this account. A blank QR permission has no account
  /// behind it and so never shows up here; that flow arrives as a deep link
  /// instead and opens the same pane directly.
  int get _pendingChallenges => (_syncAccount?['pending_challenges'] as num?)?.toInt() ?? 0;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Surfaces whatever the server said about a rejected account call. Null
  /// from the transport means it was never reached at all.
  void _notifyResult(Map<String, dynamic>? result, String success) {
    if (result == null) {
      _notify(t.switchAccounts.serverUnreachable);
    } else if (result['error'] != null) {
      _notify('${result['error']}');
    } else {
      _notify(success);
    }
  }

  /// Sets or changes the account's email — the same action claims an
  /// anonymous account, which is why the row is live even with no address
  /// yet. The new address only becomes the account's once its confirmation
  /// link is opened, so this reports "sent", never "changed".
  Future<void> _editAccountEmail() async {
    final current = _pendingEmail ?? _currentAccount?['email'] as String? ?? '';
    final entered = await editOneFieldDialog(
      context,
      title: t.settings.syncPanel.accountEmailTitle,
      fieldLabel: t.switchAccounts.emailAddress,
      fieldInitial: current,
      saveLabel: t.common.save,
    );
    if (entered == null) return;
    final email = entered.trim();
    if (email.isEmpty) return;
    // Re-typing the address already awaiting confirmation is the gesture of
    // someone who never got the mail, not a no-op.
    if (email == current) {
      if (_pendingEmail != null) await _resendAccountEmail();
      return;
    }

    final result = await widget.services.extensions.syncSetAccountEmail(email);
    if (!mounted) return;
    _notifyResult(result, t.settings.syncPanel.accountEmailSent(email: email));
    unawaited(_refreshSyncAccount());
  }

  bool _resendingEmail = false;

  Future<void> _resendAccountEmail() async {
    final email = _pendingEmail;
    if (email == null || _resendingEmail) return;
    _resendingEmail = true;
    try {
      final result = await widget.services.extensions.syncResendAccountEmail();
      if (!mounted) return;
      _notifyResult(result, t.settings.syncPanel.accountEmailResent(email: email));
    } finally {
      _resendingEmail = false;
    }
  }

  /// The approving side of linking: another device asks to join THIS
  /// account. The requesting side is [_switchAccounts].
  Future<void> _confirmDevice() async {
    final linked = await showConfirmDeviceDialog(
      context,
      findByCode: widget.services.extensions.syncFindLinkRequest,
      findByClient: widget.services.extensions.syncFindLinkRequestByClient,
      approve: widget.services.extensions.syncApproveLinkRequest,
    );
    if (linked != true || !mounted) return;
    _notify(t.settings.syncPanel.deviceLinked);
    unawaited(_refreshSyncAccount());
  }

  Future<void> _combineAccount() async {
    // The clock is checked BEFORE the call, not inferred from a false return:
    // `resolveAccountChange` also answers false for "nothing was pending" — a
    // second tap, or another surface having resolved it first — and that is a
    // success, not a clock problem. Blaming the clock there would tell an
    // ordinary operator with a real clock to run a developer command that does
    // not exist for them.
    final refusedByClock = widget.services.syncEngine.travelRefusesSync;
    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.combine);
    if (!mounted) return;
    if (refusedByClock) _notify(_syncNeedsRealClock);
    setState(() {});
  }

  /// Developer-facing and in English, like the DEVTT command it names — this is
  /// only reachable with developer mode on (docs/design/time.md §4).
  static const _syncNeedsRealClock =
      'Linking or replacing an account is refused while time travelling — run DEVTT first';

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
            operations:
                context.t.settings.syncPanel.countOperations(count: opCount, n: formatNumber(opCount)),
            qsos: context.t.settings.syncPanel.countQsos(count: qsoCount, n: formatNumber(qsoCount)),
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

    final refusedByClock = widget.services.syncEngine.travelRefusesSync;
    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.replace);
    if (!mounted) return;
    if (refusedByClock) _notify(_syncNeedsRealClock);
    setState(() {});
  }

  String get _syncAccountSubtitle {
    if (_loadingSyncAccount) return t.settings.syncPanel.checking;
    return syncAccountLabel(_syncAccount);
  }

  /// Both sides count the same thing — the log the operator still has, with
  /// tombstones and the QSOs of deleted operations left out (see
  /// `QsosRepository.syncCounts`, and LoFi's `Account#stats`). The two numbers
  /// sit side by side precisely so a difference means work still in flight;
  /// counting them by different rules would turn that signal into noise.
  String _countsLine(String Function({required String operations, required String qsos}) line,
      int operationCount, int qsoCount) {
    return line(
      operations: t.settings.syncPanel.countOperations(count: operationCount, n: formatNumber(operationCount)),
      qsos: t.settings.syncPanel.countQsos(count: qsoCount, n: formatNumber(qsoCount)),
    );
  }

  /// Null until the local counts have been read.
  String? get _localCountsLine {
    final operations = _localOperationCount, qsos = _localQsoCount;
    if (operations == null || qsos == null) return null;
    return _countsLine(t.settings.syncPanel.countsLocal, operations, qsos);
  }

  /// Null when the server did not report BOTH counts — no account payload
  /// yet, or one that predates these fields. Either alone is not enough:
  /// substituting 0 for the missing half would read as the account having
  /// lost everything on that side, which is precisely the alarm this row must
  /// not raise falsely.
  String? get _serverCountsLine {
    final operations = ((_syncAccount?['operations'] as Map?)?['total'] as num?)?.toInt();
    final qsos = ((_syncAccount?['qsos'] as Map?)?['total'] as num?)?.toInt();
    if (operations == null || qsos == null) return null;
    return _countsLine(t.settings.syncPanel.countsServer, operations, qsos);
  }

  /// "not available" is a claim about the server, so it must not be made
  /// while the fetch that would answer it is still in flight.
  String get _serverCountsText =>
      _serverCountsLine ??
      (_loadingSyncAccount
          ? t.settings.syncPanel.countsServerChecking
          : t.settings.syncPanel.countsServerUnavailable);

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            SectionHeader(context.t.settings.syncPanel.configuration),
            // The operator-callsign row lives in the Station Profiles panel
            // (settings.activeProfile).
            SwitchListTile(
              secondary: Icon(settings.syncEnabled ? MdiIcons.cloudSync : MdiIcons.cloudOff),
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
              _PendingAccountBanner(onCombine: _combineAccount, onReplace: _replaceAccount),
            // The footer status bar isn't visible on this screen, so mirror
            // the backfill-progress item here while it's active.
            ListenableBuilder(
              listenable: widget.services.statusBar,
              builder: (context, _) {
                final progress = widget.services.statusBar.itemForKey(HaLoServices.syncProgressStatusKey);
                if (progress == null || !settings.syncEnabled) return const SizedBox.shrink();
                return ListTile(
                  leading: Icon(resolveIconName(progress.icon, fallback: MdiIcons.cloudSync)),
                  title: Text(progress.title ?? context.t.settings.syncPanel.syncing),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (progress.text != null) Text(progress.text!),
                      const SizedBox(height: Space.sm),
                      LinearProgressIndicator(value: progress.progressValue),
                    ],
                  ),
                );
              },
            ),
            if (settings.syncEnabled) ...[
              // Tapping edits the account's email, which IS its identity —
              // the subtitle this row already shows.
              ListTile(
                leading: Icon(MdiIcons.accountCheck),
                title: Text(context.t.settings.syncPanel.account),
                subtitle: Text(_syncAccountSubtitle),
                onTap: _editAccountEmail,
                mouseCursor: SystemMouseCursors.click,
                trailing: IconButton(
                  icon: Icon(MdiIcons.refresh, semanticLabel: context.t.settings.syncPanel.refresh),
                  onPressed: _refreshSyncAccount,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              if (_pendingEmail != null)
                ListTile(
                  leading: Icon(MdiIcons.emailSync),
                  title: Text(context.t.settings.syncPanel.resendConfirmation),
                  subtitle: Text(context.t.settings.syncPanel.resendConfirmationDescription(email: _pendingEmail!)),
                  onTap: _resendAccountEmail,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ListTile(
                leading: const Icon(MdiIcons.database),
                title: Text(context.t.settings.syncPanel.counts),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_localCountsLine ?? context.t.settings.syncPanel.countsLocalChecking),
                    Text(_serverCountsText),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(MdiIcons.accountSwitch),
                title: Text(context.t.settings.syncPanel.switchAccounts),
                subtitle: Text(context.t.settings.syncPanel.switchAccountsDescription),
                onTap: _switchAccounts,
                mouseCursor: SystemMouseCursors.click,
              ),
              // Only present when the server says somebody is actually
              // waiting, and coloured `important` when it is — app-polo's
              // treatment. A permanent row would be an invitation to type a
              // code nobody has issued; this one is a notification.
              if (_pendingChallenges > 0)
                Builder(builder: (context) {
                  final important = HaLoColors.of(context).important;
                  return ListTile(
                    leading: Icon(MdiIcons.accountMultiplePlus, color: important),
                    title: Text(
                      context.t.settings.syncPanel.connectionRequests,
                      style: TextStyle(color: important),
                    ),
                    subtitle: Text(
                      context.t.settings.syncPanel.connectionRequestsDescription(
                        count: _pendingChallenges,
                        n: formatNumber(_pendingChallenges),
                      ),
                      style: TextStyle(color: important),
                    ),
                    onTap: _confirmDevice,
                    mouseCursor: SystemMouseCursors.click,
                  );
                }),
            ],
          ],
        );
      },
    );
  }
}

/// What to say when secure storage cannot be reached.
///
/// The Linux advice names gnome-keyring/KWallet/KeePassXC, which would be
/// nonsense anywhere else — and this IS reachable elsewhere: the darwin plugin
/// turns any non-`noErr` OSStatus into a PlatformException, including the
/// -34018 this project already meets on macOS. Neither string claims WHY: on
/// Linux libsecret reports "nothing running", "no default collection" and
/// "locked" identically, so no message may pick one.
String storageUnavailableMessage(BuildContext context) {
  final t = context.t.settings.accounts;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) return t.noKeyringInline;
  return t.noSecureStorageInline;
}

class _AccountsPanel extends StatefulWidget {
  final HaLoServices services;

  const _AccountsPanel({required this.services});

  @override
  State<_AccountsPanel> createState() => _AccountsPanelState();
}

class _AccountsPanelState extends State<_AccountsPanel> {
  List<Map<String, dynamic>>? _accounts;
  bool _secureStorageUnavailable = false;
  final Map<String, String> _accountIdentities = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await widget.services.extensions.start();
    // A failure (null) shows the panel empty — but this panel
    // re-asks on every open and after every save, so it recovers on its own.
    final accounts = await widget.services.extensions.getAccounts() ?? const <Map<String, dynamic>>[];
    final identities = <String, String>{};
    var storageUnavailable = false;
    for (final account in accounts) {
      final kvKey = account['kvKey'] as String;
      // Null means secure storage could not be reached — not that the account is
      // disconnected. Stop asking (every account would fail the same way)
      // and let the pane say so, rather than throwing out of here and leaving
      // `_accounts` null, which would spin the panel's progress indicator forever.
      final creds = await widget.services.extensions.getAccountCredentials(kvKey);
      if (creds == null) {
        storageUnavailable = true;
        break;
      }
      if (creds.isNotEmpty) {
        identities[kvKey] = ExtensionService.identityFromCredentials(creds) ?? t.settings.accounts.connected;
      }
    }
    if (mounted) {
      setState(() {
        _secureStorageUnavailable = storageUnavailable;
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
      closeLabel: context.t.common.close,
      builder: (context) => _AccountPane(services: widget.services, account: account, onSaved: _loadAccounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Grouped by the category of the extension each account belongs to, and
    // headed the same way the Extensions panel heads its own groups — a flat
    // list of every service the installed extensions offer reads as one
    // undifferentiated pile once there are more than a handful. An account's
    // `kvKey` defaults to its extension's key (docs/extensions/settings.md),
    // which is what ties the two together; anything that doesn't match a
    // known extension falls to "other" rather than being dropped.
    final categoryOf = {
      for (final info in widget.services.extensions.availableExtensions) info.key: info.category ?? 'other',
    };
    String categoryFor(Map<String, dynamic> account) => categoryOf[account['kvKey'] as String] ?? 'other';
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final account in _accounts!) {
      grouped.putIfAbsent(categoryFor(account), () => []).add(account);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.md),
      children: [
        // Said once, at
        // the top — beats each row claiming to be disconnected.
        if (_secureStorageUnavailable)
          ListTile(
            leading: const Icon(MdiIcons.keyRemove),
            title: Text(storageUnavailableMessage(context)),
          ),
        if (_accounts!.isEmpty)
          ListTile(title: Text(context.t.settings.accounts.none))
        else
          for (final category in extensionCategoriesIn(grouped.keys)) ...[
            SectionHeader(extensionCategoryTitle(category)),
            ...grouped[category]!.map((account) {
              final kvKey = account['kvKey'] as String;
              final label = account['label'] as String;
              final description = account['description'] as String?;
              final identity = _accountIdentities[kvKey];
              return ListTile(
                leading: Icon(extensionCategoryIcon(category)),
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
  bool _updatingAll = false;

  /// Every registered settingsPanel (HALO-53). Starts empty rather than
  /// null: the section simply doesn't render until the first load rather
  /// than needing its own separate loading gate from [_files].
  List<Map<String, dynamic>> _extensionPanels = const [];

  /// The subset actually shown in this screen's own "Extensions" section:
  /// only panels that explicitly opted into it (`dataFilesSection: true`) —
  /// NOT every panel that merely opted out of the top-level sidebar. Those
  /// are independent settings (extensions/sdk/src/types.ts); keying this on
  /// `sidebar: false` would sweep in any sidebar-opt-out panel whatever its
  /// reason, whether or not it is about data files.
  List<Map<String, dynamic>> get _dataFileScopedPanels =>
      [for (final p in _extensionPanels) if (p['dataFilesSection'] == true) p];

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
    final panels = await widget.services.extensions.getSettingsPanels();
    if (mounted) {
      setState(() {
        _files = files;
        _extensionPanels = panels;
      });
    }
  }

  /// Modal Pane (docs/design/layouts.md): a full screen on narrow windows,
  /// a centered dialog on wide ones — the same presentation every other
  /// settings-adjacent pane in the app uses, via [showModalPane].
  Future<void> _openExtensionPanel(BuildContext context, Map<String, dynamic> panel) => showModalPane<void>(
    context,
    title: (panel['title'] as String?) ?? (panel['panelKey'] as String?) ?? '',
    builder: (context) => _ExtensionSettingsPanel(services: widget.services, descriptor: panel),
  );

  Future<void> _refresh(DataFileStatus file) async {
    setState(() => _refreshing.add(file.key));
    try {
      // The stamped time comes back from the refresh, so the row updates
      // from it directly — no second listDataFiles round-trip. A failure
      // needs no handling here: processDataFile raises the notice for
      // download/parse failures, and refreshDataFile itself raises one for
      // the no-definition null return — every failure path speaks for
      // itself before this catch sees it.
      final updatedAt = await widget.services.dataFiles.refreshDataFile(file.key);
      if (mounted && updatedAt != null) _applyUpdatedAt(file.key, updatedAt);
    } catch (_) {
      // Swallowed deliberately — see the comment above.
    } finally {
      if (mounted) setState(() => _refreshing.remove(file.key));
    }
  }

  // syncAllDataFiles catches and reports its own per-file failures (see
  // DataFileManager), so there's nothing left to surface here beyond
  // reloading the rows once it settles. Every row is marked as refreshing
  // too, so each shows its own live status-bar progress — the same view
  // an individual Refresh gives — instead of just the summary row above.
  Future<void> _updateAll() async {
    setState(() {
      _updatingAll = true;
      _refreshing.addAll(_files?.map((f) => f.key) ?? const []);
    });
    try {
      await widget.services.dataFiles.syncAllDataFiles(force: true);
      if (mounted) await _load();
    } finally {
      if (mounted) {
        setState(() {
          _updatingAll = false;
          _refreshing.clear();
        });
      }
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

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.md),
      children: [
        SectionHeader(context.t.settings.offlineData.title),
        if (files.isEmpty)
          ListTile(
            title: Text(context.t.settings.offlineData.noFiles),
            subtitle: Text(context.t.settings.offlineData.noFilesDescription),
          )
        else ...[
          _buildUpdateAllRow(context),
          for (final file in files) _buildRow(context, file),
        ],
        if (_dataFileScopedPanels.isNotEmpty) ...[
          SectionHeader(context.t.settings.offlineData.extensionsSection),
          for (final panel in _dataFileScopedPanels) _buildExtensionPanelRow(context, panel),
        ],
      ],
    );
  }

  /// One row per [_dataFileScopedPanels] entry (HALO-53) — call-notes'
  /// builtin/custom-file toggles, and whichever other extensions declare a
  /// `dataFilesSection: true` panel of their own, live there (the same panel
  /// All Settings would show), not in this generic status-and-refresh list.
  Widget _buildExtensionPanelRow(BuildContext context, Map<String, dynamic> panel) {
    final title = (panel['title'] as String?) ?? (panel['panelKey'] as String?) ?? '';
    return ListTile(
      leading: Icon(resolveIconName(panel['icon'] as String?)),
      title: Text(title),
      trailing: const Icon(MdiIcons.chevronRight),
      onTap: () => _openExtensionPanel(context, panel),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  Widget _buildUpdateAllRow(BuildContext context) {
    if (_updatingAll) {
      return ListTile(
        leading: Icon(MdiIcons.refresh),
        title: Text(context.t.settings.offlineData.updateAll),
        subtitle: Text(context.t.settings.offlineData.updatingAll),
        trailing: const SizedBox(
          width: 24,
          height: 24,
          child: Padding(padding: EdgeInsets.all(Space.xxs), child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return ListTile(
      leading: Icon(MdiIcons.refresh),
      title: Text(context.t.settings.offlineData.updateAll),
      onTap: _updateAll,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  Widget _buildRow(BuildContext context, DataFileStatus file) {
    final icon = Icon(resolveIconName(file.icon, fallback: MdiIcons.fileDocumentOutline));

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
                const SizedBox(height: Space.sm),
                LinearProgressIndicator(value: progress?.progressValue),
              ],
            ),
            trailing: const SizedBox(
              width: 24,
              height: 24,
              child: Padding(padding: EdgeInsets.all(Space.xxs), child: CircularProgressIndicator(strokeWidth: 2)),
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
        icon: Icon(MdiIcons.refresh, semanticLabel: context.t.settings.offlineData.refresh),
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
  final diff = nowLocal().difference(updatedAt);
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

  /// Common Preferences mode: keep only elements the extension flagged
  /// `common: true` (settings_registry.dart's [elementIsCommon]) — same
  /// convention as [_SettingsGroupForm]'s `commonOnly`. False shows
  /// everything the panel declares (minus whatever `environment` rules
  /// out — that filter always applies, common or not).
  final bool commonOnly;

  const _ExtensionSettingsPanel({
    required this.services,
    required this.descriptor,
    this.embedded = false,
    this.sectionTitle,
    this.searchQuery = '',
    this.commonOnly = false,
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
    widget.services.extensions.runtimeGeneration.addListener(_runtimeChanged);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_load);
    widget.services.extensions.runtimeGeneration.removeListener(_runtimeChanged);
    super.dispose();
  }

  /// A restart (crash recovery, or the user enabling/disabling an extension)
  /// replaces the whole runtime: the panel's definition and the accounts it
  /// references both belong to the generation they were fetched from, so
  /// neither may outlive it — [_accountsCache] especially, since nothing
  /// else clears it until a dialog saves.
  void _runtimeChanged() {
    _accountsCache = null;
    _load();
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
          final resolved = await widget.services.systemLists
              .resolveInElements((definition!['elements'] as List).cast<Map<String, dynamic>>());
          // Platform-excluded elements don't exist on this session at all —
          // baked in here rather than filtered per-view, same as
          // [_SettingsGroupForm]. _fieldFor/validate/commit only ever look
          // up keys FormRenderer actually rendered, so dropping them here
          // is safe for those paths too.
          definition = {...definition, 'elements': filterElementsForEnvironment(resolved)};
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
      restartOnChange: field['restartOnChange'] == true,
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
    // Cache only a real answer: getAccounts() returns null when the extensions
    // couldn't be asked (dead runtime, a hook timing out), and caching that
    // would freeze this panel into "no accounts" for the rest of its life —
    // every later tap on the field would then do nothing.
    final accounts = _accountsCache ?? await widget.services.extensions.getAccounts();
    if (accounts == null) {
      // Say so: the user pressed Connect and no dialog is coming, which
      // otherwise reads as a dead button with the reason only in the log.
      widget.services.statusBar.setMessage(key: 'accounts:lookup', text: t.settings.accounts.lookupFailed);
      return;
    }
    _accountsCache = accounts;
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
      closeLabel: context.t.common.close,
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
    // Embedded, EVERY return is a sliver: this panel is one section of a
    // CustomScrollView, and a box handed to a viewport fails the whole list,
    // not just this section. See the embedded branch at the end.
    Widget out(Widget box) => widget.embedded ? SliverToBoxAdapter(child: box) : box;
    if (_loading) {
      return out(widget.embedded
          ? const Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: CircularProgressIndicator()))
          : const Center(child: CircularProgressIndicator()));
    }
    var definition = _definition;
    if (definition == null) {
      return out(Center(child: Text(context.t.settings.developer.panelLoadFailed)));
    }
    if (widget.commonOnly) {
      final common = [
        for (final el in (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (elementIsCommon(el)) el,
      ];
      if (common.isEmpty) return out(const SizedBox.shrink());
      definition = {...definition, 'elements': common};
    }
    // Hidden, not unmounted — same rule as the core groups above, and for the
    // same reason. There is one of these per extension, so a query that stops
    // matching takes dozens of panels out of the tree at once; each disposes
    // the FocusNodes its FormRenderer owns, and on web that teardown drops the
    // focus of whatever the operator is typing in. Focus falls back to the
    // route's scope and the next keystroke is lost.
    var searchHidden = false;
    if (widget.searchQuery.isNotEmpty) {
      // Scored and sorted, exactly as [_SettingsGroupForm] does for core
      // groups. Subsequence matching is permissive enough that filtering
      // alone barely narrows anything, so an extension's rows left in
      // declaration order would be the same loose match with none of the
      // ranking that makes it usable — a difference the operator would read
      // as the search working on some sections and not others.
      final panelElements = (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>();
      final scored = <({Map<String, dynamic> element, int score, int index})>[];
      for (var i = 0; i < panelElements.length; i++) {
        final score = elementSearchScore(panelElements[i], widget.searchQuery);
        if (score != null) scored.add((element: panelElements[i], score: score, index: i));
      }
      // See _SettingsGroupForm: Dart's sort is not stable, so ties need an
      // explicit fallback or the rows move about as the query is typed.
      scored.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.index.compareTo(b.index);
      });
      searchHidden = scored.isEmpty;
      if (!searchHidden) definition = {...definition, 'elements': [for (final s in scored) s.element]};
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
      settingsList: true,
      validator: _validate,
      onChange: _autosave,
      onAction: (actionKey, method, state) async {
        final message = await widget.services.extensions.runSettingsAction(
          hookKey: _hookKey,
          panelKey: _panelKey,
          method: method,
          state: state,
        );
        return message == null ? null : FormActionResult(message: message);
      },
      onManageAccount: _manageAccount,
      onOpenLink: openExternalUrl,
      onSubmit: (_) {},
      onCancel: () {},
    );
    // Wrap once, here, so both the embedded and standalone shapes below are
    // covered by the same hide-don't-unmount rule.
    Widget hideIfFiltered(Widget child) => Visibility(
          visible: !searchHidden,
          maintainState: true,
          child: ExcludeFocus(excluding: searchHidden, child: child),
        );
    // Embedded, this panel is one SECTION of the list that hosts it — a
    // sliver, with its band pinned over its own rows, exactly as a core
    // group's is ([_SettingsGroupForm]). An extension's section is one of
    // these, and a plain line of text among banded ones would read as a
    // different kind of thing.
    if (widget.embedded) {
      final title = widget.sectionTitle;
      Widget hideSliverIfFiltered(Widget sliver) =>
          SliverVisibility(visible: !searchHidden, maintainState: true, sliver: sliver);
      final rows = SliverToBoxAdapter(child: ExcludeFocus(excluding: searchHidden, child: form));
      if (title == null) return hideSliverIfFiltered(rows);
      return hideSliverIfFiltered(SliverMainAxisGroup(slivers: [
        SectionHeader.pinned(context, title, width: settingsPaneWidth(context)),
        rows,
      ]));
    }

    return hideIfFiltered(SingleChildScrollView(
      // No horizontal padding: rows run to the pane's edges and inset their
      // own contents from the ambient ListTileTheme.
      padding: const EdgeInsets.symmetric(vertical: Space.xl),
      child: form,
    ));
  }
}

class _DeveloperPanel extends StatelessWidget {
  final HaLoServices services;

  const _DeveloperPanel({required this.services});

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          // No inset of its own: every row here takes the ambient
          // ListTileTheme's, like every other panel's. Its own padding on top
          // pushed these rows in twice as far as the rest of Settings and
          // stopped their backgrounds short of the pane's edges.
          padding: const EdgeInsets.only(bottom: Space.xl),
          children: [
            SectionHeader(context.t.settings.developer.options),
            SwitchListTile(
              title: Text(context.t.settings.developerMode),
              subtitle: Text(context.t.settings.developer.developerModeDescription),
              value: settings.developerMode,
              onChanged: (enabled) => settings.setDeveloperMode(enabled),
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
                    leading: const Icon(MdiIcons.flaskOutline),
                    title: Text(context.t.settings.developer.experiments),
                    subtitle: Text(context.t.settings.developer.experimentsEnabled(count: enabledCount)),
                    mouseCursor: SystemMouseCursors.click,
                    // The pane loads the catalog itself — capturing this
                    // builder's `definitions` would freeze a still-loading
                    // (empty) snapshot into the pane for its whole lifetime.
                    onTap: () => showModalPane<void>(
                      context,
                      title: context.t.settings.developer.experiments,
                      closeLabel: context.t.common.close,
                      builder: (_) => ExperimentsPane(services: services),
                    ),
                  );
                },
              ),
            // Shorebird over-the-air patch track (docs/releases.md §4.3). Only
            // shown when the Shorebird engine is actually present — i.e. a
            // `shorebird release` build, not a local/debug/web one — so it's
            // invisible and inert everywhere it can't do anything.
            if (services.updates.isAvailable) ...[
              const SizedBox(height: Space.xl),
              Text(
                context.t.settings.developer.patchTrack,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HaLoColors.of(context).onSurfaceAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.xs, bottom: Space.md),
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
                padding: const EdgeInsets.only(top: Space.md),
                child: FutureBuilder<({bool resolved, int? number})>(
                  future: services.updates.currentPatchNumber(),
                  builder: (context, snapshot) {
                    final patch = snapshot.data?.number;
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
            const SizedBox(height: Space.xl),
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
            const SizedBox(height: Space.xl),
            const Divider(),
            const SizedBox(height: Space.xl),
            Text(
              context.t.settings.developer.systemInformation,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Space.md),
            _infoRow(context, context.t.settings.sync.deviceKey, settings.syncDeviceKey ?? context.t.settings.developer.loading),
            _infoRowWidget(
              context,
              context.t.settings.developer.appVersion,
              const VersionLabel(style: TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
            // Where the log database and the data-file cache live. Platform-
            // dependent, and relocated out of Documents on Windows and Linux
            // (see app_storage.dart), so it's worth being able to read it back
            // from a running build rather than guessing.
            if (!kIsWeb) _infoRowWidget(context, context.t.settings.developer.dataFolder, const _DataFolderValue()),
            const SizedBox(height: Space.xl),
            const Divider(),
            const SizedBox(height: Space.xl),
            Text(
              context.t.settings.developer.activeExtensions,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Space.md),
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
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
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

/// Where the log database and the data-file cache live. Platform-dependent,
/// and relocated out of Documents on Windows and Linux (see app_storage.dart),
/// so it's worth being able to read it back from a running build rather than
/// guessing.
///
/// Stateful only to hold the future: `appDataDirectory()` hands back a new one
/// on every call, and the Developer panel rebuilds on every settings change —
/// so building it inline would drop the row back to "(loading…)" each time.
class _DataFolderValue extends StatefulWidget {
  const _DataFolderValue();

  @override
  State<_DataFolderValue> createState() => _DataFolderValueState();
}

class _DataFolderValueState extends State<_DataFolderValue> {
  late final _directory = appDataDirectory();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _directory,
      builder: (context, snapshot) => SelectableText(
        snapshot.data?.path ?? context.t.settings.developer.loading,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
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
      'spots': context.t.extensionsPanel.categorySpots,
      'dashboard': context.t.extensionsPanel.categoryDashboard,
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
            padding: const EdgeInsets.only(top: Space.md, bottom: Space.xxs),
            child: Text(
              categoryTitles[category] ?? category,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: HaLoColors.of(context).onSurfaceAccent),
            ),
          ),
          for (final ext in grouped[category]!)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
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
/// preview/modal — a handful of the most recent, not the full history.
const _aboutRecentReleaseCount = 3;

/// Tapping the About screen's version row copies the full app name and
/// version details — handy for pasting into a bug report or support email.
Future<void> _copyVersionDetailsToClipboard(BuildContext context) async {
  await Clipboard.setData(ClipboardData(text: '$ham2kAppName\n${versionDetailsText()}'));
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
            // Ordinary settings rows from here down — no dividers between
            // them and no width cap of their own: this panel reads as one
            // list with the rest of Settings, and its rows take the pane's
            // width and the ambient row inset like every other panel's.
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(MdiIcons.information),
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
            // Both of these hide themselves entirely where they don't apply
            // (no update mechanism for this build; a preference that isn't
            // ours to honour), which is why neither is wrapped in anything
            // that would leave a gap behind.
            SliverToBoxAdapter(child: UpdateCheckRow(services: services)),
            SliverToBoxAdapter(child: AutomaticUpdateCheckRow(services: services)),
            // Notices & Messages sits here, between the version and the
            // release notes, as an entry point into the history view.
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(MdiIcons.bell),
                title: Text(context.t.settings.about.notices),
                subtitle: Text(context.t.settings.about.noticesDescription),
                trailing: const Icon(MdiIcons.chevronRight),
                onTap: () => showModalPane<void>(
                  context,
                  title: context.t.settings.about.notices,
                  closeLabel: context.t.common.close,
                  // NoticeHistoryView is its own scrolling ListView — the
                  // pane must not also wrap it in a SingleChildScrollView.
                  scrollable: false,
                  builder: (context) => NoticeHistoryView(services: services),
                ),
                mouseCursor: SystemMouseCursors.click,
              ),
            ),
            if (recentReleases.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(context.t.settings.about.releaseNotes)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ReleaseNotesPreview(releases: recentReleases),
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
    final styleSheet = withEmojiFallback(MarkdownStyleSheet.fromTheme(Theme.of(context)));
    return GestureDetector(
      key: const Key('aboutReleaseNotesPreview'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showModalPane<void>(
        context,
        title: context.t.settings.about.releaseNotes,
        closeLabel: context.t.common.close,
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
            // The rows' own inset, so the notes start under the section
            // band's title rather than at an inset of their own.
            padding: ListTileTheme.of(context).contentPadding ?? const EdgeInsets.symmetric(horizontal: Space.xl),
            child: MarkdownBody(data: markdown, styleSheet: styleSheet),
          ),
        ),
      ),
    );
  }
}

/// The About screen's top banner: the current release's cover photo fading
/// into the surface color (same technique as `ReleaseOverlayView`), with the
/// ham2k arc and app name over it.
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
            ReleasePhoto(
              imageAssetPath: release!.imageAssetPath,
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
              padding: const EdgeInsets.only(top: Space.xl),
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

class _PendingAccountBanner extends StatelessWidget {
  final VoidCallback onCombine;
  final VoidCallback onReplace;

  const _PendingAccountBanner({required this.onCombine, required this.onReplace});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      // Lined up with the rows it sits among, off the ambient ListTileTheme
      // (grab-strip clearance and pane centring included).
      margin: (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero)
          .add(const EdgeInsets.only(top: Space.xs, bottom: Space.lg)),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(MdiIcons.cloudQuestion, color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    context.t.settings.syncPanel.pendingBannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              context.t.settings.syncPanel.pendingBannerBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(height: Space.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCombine, child: Text(context.t.settings.syncPanel.combine)),
                const SizedBox(width: Space.md),
                FilledButton(onPressed: onReplace, child: Text(context.t.settings.syncPanel.replace)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens [accountKey]'s standalone account dialog from anywhere in the app
/// (declarative `account` actions — e.g. an extension's "reconnect your
/// account" dialog button). `accountKey` matches the account's kvKey.
Future<void> showAccountDialogByKey(HaLoServices services, String accountKey, {String? subkey}) async {
  // Same as the settings panel's own account field: this is a button press
  // with a dialog expected, so a failed lookup has to say so rather than
  // leave the press looking ignored. Nothing is cached here, so the next
  // press asks again.
  final accounts = await services.extensions.getAccounts();
  if (accounts == null) {
    services.statusBar.setMessage(key: 'accounts:lookup', text: t.settings.accounts.lookupFailed);
    return;
  }
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
    closeLabel: context.t.common.close,
    builder: (context) => _AccountPane(services: services, account: account!, onSaved: () {}),
  );
}

/// One extension account's credentials, shown as a Modal Pane
/// (docs/design/layouts.md): a dialog on wide layouts, a full screen on
/// phones. The route provides the
/// title and chrome; the action row renders here because it depends on
/// this State (_testing, _loggedIn).
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
  bool _secureStorageUnavailable = false;

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
    // Null is "secure storage is unreachable", and it must not stop the rest of
    // this: the controllers below are what the fields render from, so throwing
    // here would leave the dialog with no fields at all.
    final stored = await widget.services.extensions.getAccountCredentials(_kvKey);
    final creds = stored ?? const <String, String>{};
    setState(() {
      _secureStorageUnavailable = stored == null;
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
      final stored = _pendingCredentials ?? await widget.services.extensions.getAccountCredentials(_kvKey);
      if (stored == null) {
        // The read failed. Resetting `_testing` is the point: left true, it
        // disables Test AND Connect for as long as the dialog stays open.
        if (mounted && generation == _testGeneration) {
          setState(() {
            _testing = false;
            _secureStorageUnavailable = true;
          });
        }
        return;
      }
      creds = stored;
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
    final scopes = (oauth2['scopes'] as List).cast<String>();
    // Every platform opens the sign-in page in the operator's own browser.
    // What differs is only how the code comes home: Web/Linux/Windows can't
    // receive the native com.ham2k.*.auth:// redirect at all
    // (oauth_browser_login.dart's header explains why), so they go through
    // LoFi's webhook relay; everywhere else the OS delivers it as a deep link.
    final useRelay = oauthUsesWebhookRelay();
    final redirectUrl = (useRelay ? oauth2['webhookRedirectUrl'] : oauth2['redirectUrl']) as String?;

    try {
      if (redirectUrl == null) {
        // Only reachable if some future OAuth2 hook doesn't declare
        // webhookRedirectUrl — SOTA always does. Fail with the same relay
        // message rather than a null-check crash three lines down.
        throw Exception(t.settings.accounts.relayLoginUnavailable);
      }

      // Only the relay path needs this device's LoFi identity — the native
      // webview/deep-link path (used on macOS/Windows/Android/iOS) never
      // touches LoFi at all. Goes through
      // `connectLofiRealtime` itself (register-and-subscribe, same as boot
      // does) rather than re-deriving that sequence inline — boot may not
      // have reached it yet on a fresh device, so it's still called here,
      // just through the one place that knows how, not a second copy of it.
      LofiClientRegistration? registration;
      if (useRelay) {
        registration = await widget.services.connectLofiRealtime();
        if (registration == null) {
          throw Exception(t.settings.accounts.relayLoginUnavailable);
        }
      }

      final userAgent = await ham2kUserAgent();
      final discoveryUrl = Uri.parse('$issuer/.well-known/openid-configuration');
      final response = await http.get(discoveryUrl, headers: {'User-Agent': userAgent});
      if (response.statusCode != 200) throw Exception('Failed to load OIDC discovery: ${response.statusCode}');
      final discovery = jsonDecode(response.body) as Map<String, dynamic>;
      final authEndpoint = discovery['authorization_endpoint'] as String;
      final tokenEndpoint = discovery['token_endpoint'] as String;

      final codeVerifier = _randomString(64);
      final codeChallenge = _sha256Challenge(codeVerifier);
      // On the relay path, `state` carries two jobs at once: a per-attempt
      // CSRF nonce (`n`, so a stale/replayed redirect from a previous
      // attempt can't be mistaken for this one — the whole encoded blob is
      // what gets compared, not just `n` in isolation), and this device's
      // signed webhook-relay token (`t`), which is how LoFi's public
      // callback endpoint knows which client's channel to notify
      // — every compliant OAuth provider is required to echo `state` back
      // unmodified, which is what makes this portable across providers
      // without a per-provider wildcard-redirect negotiation. On the
      // native path `state` is just a plain CSRF nonce, same as always —
      // the redirect_uri itself already identifies this device.
      final state = useRelay
          ? base64Url.encode(utf8.encode(jsonEncode({
              'n': _randomString(16),
              't': registration!.webhookClientToken,
              'p': widget.account['key'],
            })))
          : _randomString(16);

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

      String? authError;
      final String? code;
      if (useRelay) {
        code = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (context) => OAuthBrowserLoginPage(
              accountLabel: '${widget.account['label']}',
              authUri: authUri,
              expectedState: state,
              webhookEvents: widget.services.webhookEvents,
              fetchWebhookEvents: widget.services.extensions.fetchLofiWebhookEvents,
              // A redirect that carries `error` instead of `code` ends the
              // login the same way a code does.
              onError: (error) => authError = error,
            ),
          ),
        );
      } else {
        // The sign-in page opens in the operator's own browser, same as the
        // relay platforms; here the provider redirects to a
        // com.ham2k.*.auth:// URL these platforms register, and the OS hands
        // it back through DeepLinkService. This listener is what completes
        // the login — the waiting page itself carries no relay wiring and
        // never resolves on its own.
        final navigator = Navigator.of(context);
        final linkSub = widget.services.deepLinks.links.listen((uri) {
          if (!DeepLinkService.isAuthCallback(uri)) return;
          if (uri.queryParameters['state'] != state) {
            // A redirect from an attempt the operator abandoned, or one meant
            // for another login. Dropping it is right; dropping it in silence
            // leaves a page waiting with no record that anything came back.
            debugPrint('[oauth] ignoring an auth callback for a different attempt');
            return;
          }
          authError = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
          navigator.pop(uri.queryParameters['code']);
        }, onError: (Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'deep-link:auth-callback'));

        code = await navigator.push<String>(
          MaterialPageRoute(
            builder: (context) => OAuthBrowserLoginPage(
              accountLabel: '${widget.account['label']}',
              authUri: authUri,
            ),
          ),
        );
        await linkSub.cancel();
      }

      if (code == null) {
        if (authError != null) throw Exception(authError);
        return;
      }

      // The pane (an Escape-dismissible ModalPaneRoute) can have been closed
      // while the webview/system-browser login above was in progress —
      // nothing left to update, and no Save button left to hold
      // `_pendingCredentials` for.
      if (!mounted) return;
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

      // Same reason as above — the pane may have closed during the token
      // exchange itself.
      if (!mounted) return;
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
            const SizedBox(height: Space.md),
            Text(
              context.t.settings.accounts.pressSaveToKeep,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (_secureStorageUnavailable) ...[
            Text(
              storageUnavailableMessage(context),
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
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preface != null && preface.isNotEmpty) ...[
                    MarkdownBody(data: preface, styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme))),
                    const SizedBox(height: Space.md),
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
                      selectAllOnFocus: false,
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
                    const SizedBox(height: Space.md),
                    MarkdownBody(data: postface, styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme))),
                  ],
                ],
              ),
            );
          }),
        ],
        if (_loggedIn && _pendingCredentials == null) ...[
          const SizedBox(height: Space.md),
          Center(
            child: OutlinedButton(
              onPressed: _clear,
              child: Text(context.t.settings.accounts.disconnect),
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
        const Divider(),
        const SizedBox(height: Space.md),
        Text(
          context.t.settings.accounts.connectedAs,
          style: theme.textTheme.titleSmall?.copyWith(color: HaLoColors.of(context).onSurfaceAccent),
        ),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _testing
                    ? const SizedBox(
                        height: 20,
                        child: Center(child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : MarkdownBody(
                        data: _testResult ?? '—',
                        styleSheet: withEmojiFallback(MarkdownStyleSheet.fromTheme(theme)),
                      ),
              ),
            ),
            const SizedBox(width: Space.md),
            TextButton(onPressed: _testing ? null : _test, child: Text(context.t.settings.accounts.test)),
          ],
        ),
        const SizedBox(height: Space.xxl),
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
