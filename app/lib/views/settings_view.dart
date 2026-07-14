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
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/extension_service.dart';
import '../services/settings_service.dart';
import 'notice_history_view.dart';
import 'operation_dialogs.dart';

const _appVersion = '0.1.0'; // keep in sync with app/pubspec.yaml

const double _wideLayoutThreshold = 720.0;

/// A sidebar entry: `key` identifies it (a fixed core key, or an
/// extension's `panelKey`); `descriptor` is null for core panels and the
/// raw `getSettingsPanels()` entry for extension-contributed ones (needed
/// downstream by `_buildPanelContent` to route the definition fetch).
/// `order` places it among every other panel — core and extension-
/// contributed alike sort together by this one value, which is how the
/// core/settings extension's "General" panel (order 0, see its
/// `getPanels()`) lands first despite not being one of the hardcoded
/// entries below.
class _SettingsPanelEntry {
  final String key;
  final String title;
  final IconData icon;
  final int order;
  final Map<String, dynamic>? descriptor;

  const _SettingsPanelEntry({required this.key, required this.title, required this.icon, required this.order, this.descriptor});
}

// "General" isn't here — it's the core/settings extension's own
// settingsPanel now (extensions/core/settings), same as any other
// extension-contributed panel, just always installed.
const _fixedCorePanels = [
  _SettingsPanelEntry(key: 'sync', title: 'Sync', icon: Icons.sync, order: 10),
  _SettingsPanelEntry(key: 'accounts', title: 'Accounts', icon: Icons.vpn_key_outlined, order: 20),
];
const _developerPanelOrder = 90;
const _aboutPanelOrder = 100;
const _extensionPanelDefaultOrder = 50;

class SettingsView extends StatefulWidget {
  final HaLoServices services;

  const SettingsView({super.key, required this.services});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _selectedPanel = 'settings';
  List<Map<String, dynamic>> _extensionPanels = [];
  // 'settings' (the core/settings extension's General panel) only appears
  // in _buildPanelEntries once _loadExtensionPanels's bridge call resolves.
  // Until then, the wide-layout auto-correct below would see _selectedPanel
  // match nothing, snap to whatever's first (Sync), and never revisit it
  // once the real panel list arrives — so it's gated on this flag.
  bool _extensionPanelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadExtensionPanels();
  }

  Future<void> _loadExtensionPanels() async {
    await widget.services.extensions.start();
    final panels = await widget.services.extensions.getSettingsPanels();
    // The extension runtime failing to start is the one failure mode that's
    // both detectable here and not already self-reported elsewhere (a
    // single misbehaving extension's getPanels() failing is caught and
    // isolated per-hook, so it only silently drops its own panels — no
    // signal to surface for that). If the whole runtime never came up,
    // General (and everything else extension-contributed) is missing with
    // no other indication, so show it rather than fail silently.
    if (!widget.services.extensions.ready) {
      widget.services.statusBar.showNotice(
        key: 'settings_extensions_unavailable',
        icon: 'alert-circle-outline',
        title: 'Some settings are unavailable',
        text: 'The extension runtime failed to start, so extension-contributed settings (including General) are missing.',
      );
    }
    if (mounted) {
      setState(() {
        _extensionPanels = panels;
        _extensionPanelsLoaded = true;
      });
    }
  }

  List<_SettingsPanelEntry> _buildPanelEntries(SettingsService settings) {
    final entries = [
      ..._fixedCorePanels,
      for (final p in _extensionPanels)
        _SettingsPanelEntry(
          key: p['panelKey'] as String,
          title: (p['title'] as String?) ?? (p['panelKey'] as String),
          icon: resolveIconName(p['icon'] as String?),
          order: (p['order'] as num?)?.toInt() ?? _extensionPanelDefaultOrder,
          descriptor: p,
        ),
      if (settings.developerMode)
        const _SettingsPanelEntry(key: 'developer', title: 'Developer Settings', icon: Icons.bug_report_outlined, order: _developerPanelOrder),
      const _SettingsPanelEntry(key: 'about', title: 'About', icon: Icons.info_outline, order: _aboutPanelOrder),
    ];
    entries.sort((a, b) => a.order.compareTo(b.order));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => _buildContent(context, settings),
    );
  }

  Widget _buildContent(BuildContext context, SettingsService settings) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isWide = width >= _wideLayoutThreshold;

    final panels = _buildPanelEntries(settings);
    final selectionExists = panels.any((p) => p.key == _selectedPanel);
    final effectivePanel = selectionExists ? panels.firstWhere((p) => p.key == _selectedPanel) : panels.first;
    if (!selectionExists && _extensionPanelsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPanel = effectivePanel.key);
      });
    }

    if (isWide) {
      final theme = Theme.of(context);
      final bool isDark = theme.brightness == Brightness.dark;
      
      final appBarColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
      final Color headerDividerColor;
      if (isDark) {
        headerDividerColor = Colors.grey[600]!;
      } else {
        final appBarHsl = HSLColor.fromColor(appBarColor);
        headerDividerColor = appBarHsl.withLightness((appBarHsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
      }

      final bodyColor = theme.colorScheme.surface;
      final Color bodyDividerColor;
      if (isDark) {
        bodyDividerColor = Colors.grey[600]!;
      } else {
        final bodyHsl = HSLColor.fromColor(bodyColor);
        bodyDividerColor = bodyHsl.withLightness((bodyHsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
      }

      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(Theme.of(context).appBarTheme.toolbarHeight ?? 56.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 320,
                child: AppBar(
                  leadingWidth: macOSAwareLeadingWidth(context),
                  leading: macOSAwareBackButton(context),
                  title: const Text('Settings'),
                ),
              ),
              Container(
                width: 1,
                color: headerDividerColor,
              ),
              Expanded(
                child: AppBar(
                  title: Text(effectivePanel.title),
                  automaticallyImplyLeading: false,
                ),
              ),
            ],
          ),
        ),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 320,
              child: _buildSidebar(context, isWide: true, panels: panels, selectedKey: effectivePanel.key),
            ),
            Container(
              width: 1,
              color: bodyDividerColor,
            ),
            Expanded(
              child: _buildPanelContent(effectivePanel, widget.services),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: macOSAwareLeadingWidth(context),
          leading: macOSAwareBackButton(context),
          title: const Text('Settings'),
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
    return ListView.builder(
      itemCount: panels.length,
      itemBuilder: (context, index) {
        final panel = panels[index];
        final isSelected = isWide && selectedKey == panel.key;

        return ListTile(
          selected: isSelected,
          leading: Icon(panel.icon),
          title: Text(panel.title),
          onTap: () {
            setState(() {
              _selectedPanel = panel.key;
            });
            if (!isWide) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _SettingsPanelScreen(
                    panel: panel,
                    services: widget.services,
                  ),
                ),
              );
            }
          },
          mouseCursor: SystemMouseCursors.click,
        );
      },
    );
  }
}

class _SettingsPanelScreen extends StatelessWidget {
  final _SettingsPanelEntry panel;
  final HaLoServices services;

  const _SettingsPanelScreen({required this.panel, required this.services});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= _wideLayoutThreshold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: macOSAwareLeadingWidth(context),
        leading: macOSAwareBackButton(context),
        title: Text(panel.title),
      ),
      body: _buildPanelContent(panel, services),
    );
  }
}

Widget _buildPanelContent(_SettingsPanelEntry panel, HaLoServices services) {
  switch (panel.key) {
    case 'sync':
      return _SyncPanel(services: services);
    case 'accounts':
      return _AccountsPanel(services: services);
    case 'developer':
      return _DeveloperPanel(services: services);
    case 'about':
      return _AboutPanel(services: services);
    default:
      final descriptor = panel.descriptor;
      if (descriptor == null) return const SizedBox.shrink();
      return _ExtensionSettingsPanel(services: services, descriptor: descriptor);
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

  Future<void> _editOperatorCall() async {
    final settings = widget.services.settings;
    final result = await editOneFieldDialog(
      context,
      title: 'Operator callsign',
      fieldLabel: 'Callsign',
      fieldInitial: settings.operatorCall,
      fieldCapitalization: TextCapitalization.characters,
    );
    if (result == null) return;
    await widget.services.setOperatorCall(result);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSync(bool enabled) async {
    await widget.services.setSyncEnabled(enabled);
    if (enabled) {
      unawaited(_refreshSyncAccount());
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _linkByEmail() async {
    final email = await editOneFieldDialog(
      context,
      title: 'Link to an existing account',
      fieldLabel: 'Email address',
      fieldInitial: '',
      saveLabel: 'Send link',
    );
    if (email == null || email.trim().isEmpty) return;

    final result = await widget.services.extensions.syncLinkClientWithEmail(email.trim());
    if (!mounted) return;
    final message = result == null
        ? 'Could not reach the sync server. Try again later.'
        : 'Check $email for a confirmation link.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _combineAccount() async {
    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.combine);
    if (mounted) setState(() {});
  }

  Future<void> _replaceAccount() async {
    final opCount = (await widget.services.operations.syncCounts()).total;
    final qsoCount = (await widget.services.qsos.syncCounts()).total;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace local data?'),
        content: Text(
          'This backs up and clears $opCount operation${opCount == 1 ? '' : 's'} and $qsoCount '
          'QSO${qsoCount == 1 ? '' : 's'} from this device, then downloads the account\'s data '
          'instead. The backup stays in this device\'s database.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Replace')),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.services.syncEngine.resolveAccountChange(SyncAccountChoice.replace);
    if (mounted) setState(() {});
  }

  String get _syncAccountSubtitle {
    if (_loadingSyncAccount) return 'Checking…';
    final account = _syncAccount?['current_account'] as Map?;
    final call = account?['call'] as String?;
    if (call == null || call.isEmpty) return 'Not linked yet';
    final email = account?['email'] as String?;
    return (email == null || email.isEmpty) ? 'Linked as $call' : 'Linked as $call ($email)';
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const SectionHeader('Sync Configuration'),
            ListTile(
              leading: Icon(resolveIconName('account-outline')),
              title: const Text('Operator callsign'),
              subtitle: Text(settings.operatorCall.isEmpty ? 'Not set' : settings.operatorCall),
              onTap: _editOperatorCall,
              mouseCursor: SystemMouseCursors.click,
            ),
            SwitchListTile(
              secondary: Icon(resolveIconName(settings.syncEnabled ? 'cloud-sync-outline' : 'cloud-off-outline')),
              title: const Text('Sync with Ham2K Log Filer'),
              subtitle: Text(
                settings.syncEnabled
                    ? 'Backs up and syncs your log across devices'
                    : 'Off — your log stays on this device only',
              ),
              value: settings.syncEnabled,
              onChanged: _toggleSync,
              mouseCursor: SystemMouseCursors.click,
            ),
            if (settings.syncState['pendingAccountUUID'] != null)
              _PendingAccountBanner(onCombine: _combineAccount, onReplace: _replaceAccount),
            if (settings.syncEnabled) ...[
              ListTile(
                leading: Icon(resolveIconName('account-check-outline')),
                title: const Text('Account'),
                subtitle: Text(_syncAccountSubtitle),
                trailing: IconButton(
                  icon: Icon(resolveIconName('refresh')),
                  tooltip: 'Refresh',
                  onPressed: _refreshSyncAccount,
                  mouseCursor: SystemMouseCursors.click,
                ),
              ),
              ListTile(
                leading: Icon(resolveIconName('email-outline')),
                title: const Text('Link to an existing account'),
                subtitle: const Text('Sync this device into an account you already use elsewhere'),
                onTap: _linkByEmail,
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
  final Map<String, String> _accountSubtitles = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    await widget.services.extensions.start();
    final accounts = await widget.services.extensions.getAccounts();
    final subtitles = <String, String>{};
    for (final account in accounts) {
      final kvKey = account['kvKey'] as String;
      final creds = await widget.services.extensions.getAccountCredentials(kvKey);
      final subtitle = creds.isEmpty ? 'Not configured' : (ExtensionService.identityFromCredentials(creds) ?? 'Configured');
      subtitles[kvKey] = subtitle;
    }
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _accountSubtitles.clear();
        _accountSubtitles.addAll(subtitles);
      });
    }
  }

  Future<void> _openAccountDialog(Map<String, dynamic> account) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AccountDialog(
        services: widget.services,
        account: account,
        onSaved: _loadAccounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_accounts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SectionHeader('Accounts & Services'),
        if (_accounts!.isEmpty)
          const ListTile(
            title: Text('No active extensions with accounts'),
          )
        else
          ..._accounts!.map((account) {
            final kvKey = account['kvKey'] as String;
            final label = account['label'] as String;
            final subtitle = _accountSubtitles[kvKey] ?? 'Not configured';
            return ListTile(
              leading: Icon(MdiIcons.keyChain),
              title: Text(label),
              subtitle: Text(subtitle),
              onTap: () => _openAccountDialog(account),
              mouseCursor: SystemMouseCursors.click,
            );
          }),
      ],
    );
  }
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

  const _ExtensionSettingsPanel({required this.services, required this.descriptor});

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
        final definition = await widget.services.extensions.getSettingsPanelDefinition(
          hookKey: _hookKey,
          panelKey: _panelKey,
          kind: _kind,
        );
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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AccountDialog(
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
      return const Center(child: CircularProgressIndicator());
    }
    final definition = _definition;
    if (definition == null) {
      return const Center(child: Text('Could not load this settings panel.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FormRenderer(
        formDefinition: definition,
        initialState: const {},
        showActions: false,
        developerMode: widget.services.settings.developerMode,
        validator: _validate,
        onChange: _autosave,
        onAction: (actionKey, method, state) => widget.services.extensions.runSettingsAction(
          hookKey: _hookKey,
          panelKey: _panelKey,
          method: method,
          state: state,
        ),
        onManageAccount: _manageAccount,
        onSubmit: (_) {},
        onCancel: () {},
      ),
    );
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
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Developer Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Developer Mode'),
              subtitle: const Text('Enable developer warnings, debug logs, and tools.'),
              value: settings.developerMode,
              onChanged: (enabled) => settings.setDeveloperMode(enabled),
              contentPadding: EdgeInsets.zero,
            ),
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
                    {
                      'type': 'divider',
                      'title': 'Contact Details',
                    },
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
                    {
                      'type': 'markdown',
                      'text': 'Please make sure to **validate** the information before saving.',
                    },
                    {
                      'type': 'divider',
                      'title': 'Preferences',
                    },
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
                    {
                      'type': 'field',
                      'fieldType': 'checkbox',
                      'key': 'subscribe',
                      'label': 'Subscribe to newsletter',
                    },
                  ],
                };

                final initialState = {
                  'name': 'Sebastian Delmont',
                  'license': 'extra',
                  'subscribe': true,
                };

                final result = await showFormDialog(
                  context,
                  formDefinition: formDefinition,
                  initialState: initialState,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved: ${result.toString()}')),
                  );
                }
              },
              child: const Text('Test Custom Form Dialog'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'System Information',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _infoRow(context, 'Sync Device Key', settings.syncDeviceKey ?? '(loading…)'),
            _infoRow(context, 'App Version', '$_appVersion (dev build)'),
          ],
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  final HaLoServices services;

  const _AboutPanel({required this.services});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/images/ham2k-icon.png', width: 96, height: 96),
              ),
              const SizedBox(height: 16),
              Text(
                'Ham2K Logger',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Version $_appVersion (dev build)',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'About the App',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ham2K Logger is the next-generation Portable Logger for amateur radio operators. '
          'It is designed to be lightweight, cross-platform, and extensible.',
          style: TextStyle(height: 1.4, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Recent Notices'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => NoticeHistoryView(services: services)),
          ),
          mouseCursor: SystemMouseCursors.click,
        ),
      ],
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

  const _PendingAccountBanner({required this.onCombine, required this.onReplace});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(resolveIconName('cloud-question-outline'), color: theme.colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New Ham2K Log Filer account detected',
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Keep this device's existing operations and QSOs and merge them into the account, "
              'or replace them with the account\'s data (a backup stays on this device either way).',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCombine, child: const Text('Combine')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onReplace, child: const Text('Replace')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final HaLoServices services;
  final Map<String, dynamic> account;
  final VoidCallback onSaved;

  const _AccountDialog({
    required this.services,
    required this.account,
    required this.onSaved,
  });

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final Map<String, TextEditingController> _controllers = {};
  bool _testing = false;
  String? _testResult;
  bool _loggedIn = false;

  String? _fieldError(String key, String value) {
    if (widget.account['key'] == 'qrz' && key == 'username' && value.contains('@')) {
      return "Don't use your email for login.";
    }
    return null;
  }

  List<Map<String, dynamic>> get _fields =>
      (widget.account['fields'] as List? ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _oauth2 =>
      widget.account['oauth2'] as Map<String, dynamic>?;

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
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_oauth2 == null) {
      final creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
      await widget.services.extensions.setAccountCredentials(_kvKey, creds);
    }
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await widget.services.extensions.clearAccount(_kvKey);
    for (final c in _controllers.values) {
      c.clear();
    }
    setState(() {
      _loggedIn = false;
      _testResult = null;
    });
    widget.onSaved();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final Map<String, String> creds;
    if (_oauth2 != null) {
      creds = await widget.services.extensions.getAccountCredentials(_kvKey);
    } else {
      creds = _controllers.map((key, controller) => MapEntry(key, controller.text.trim()));
    }

    final res = await widget.services.extensions.testCredentials(
      widget.account['key'] as String,
      creds,
    );

    if (mounted) {
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
      final discoveryUrl = Uri.parse('$issuer/.well-known/openid-configuration');
      final response = await http.get(discoveryUrl);
      if (response.statusCode != 200) throw Exception('Failed to load OIDC discovery: ${response.statusCode}');
      final discovery = jsonDecode(response.body) as Map<String, dynamic>;
      final authEndpoint = discovery['authorization_endpoint'] as String;
      final tokenEndpoint = discovery['token_endpoint'] as String;

      final codeVerifier = _randomString(64);
      final codeChallenge = _sha256Challenge(codeVerifier);
      final state = _randomString(16);

      final authUri = Uri.parse(authEndpoint).replace(queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUrl,
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      if (!mounted) return;

      final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('Connect to ${widget.account['label']}'),
              leadingWidth: macOSAwareLeadingWidth(context),
              leading: isMacOSChromelessWindow
                  ? Padding(
                      padding: EdgeInsets.only(left: macOSTrafficLightClearance(context)),
                      child: CloseButton(onPressed: () => Navigator.of(context).pop()),
                    )
                  : CloseButton(onPressed: () => Navigator.of(context).pop()),
            ),
            body: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(authUri.toString())),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
              ),
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

      if (code == null) return;

      setState(() => _testing = true);

      final tokenResponse = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
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

      await widget.services.extensions.setAccountCredentials(_kvKey, credentials);

      setState(() {
        _loggedIn = true;
        _testing = false;
      });
      widget.onSaved();

    } catch (e) {
      if (mounted) {
        setState(() => _testing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
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

    return AlertDialog(
      title: Text(widget.account['label'] as String),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_oauth2 != null) ...[
              if (_loggedIn) ...[
                Text(
                  'Connected to ${widget.account['label']}',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _clear,
                  child: const Text('Disconnect'),
                ),
              ] else ...[
                OutlinedButton(
                  onPressed: _testing ? null : _doOAuth,
                  child: const Text('Login'),
                ),
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
                      TextField(
                        controller: controller,
                        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                        obscureText: field['type'] == 'secret',
                        keyboardType: field['type'] == 'email'
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        decoration: poloFieldDecoration(context, field['label'] as String).copyWith(
                          errorText: _fieldError(key, controller.text),
                        ),
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
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Test Connection Result:',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(data: _testResult!),
              ),
            ],
            if (_testing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_oauth2 == null && _loggedIn)
          TextButton(
            onPressed: _clear,
            child: const Text('Clear'),
          ),
        if (!_testing)
          TextButton(
            onPressed: _test,
            child: const Text('Test'),
          ),
        if (_oauth2 == null)
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
      ],
    );
  }
}
