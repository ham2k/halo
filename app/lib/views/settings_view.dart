// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// App-wide settings: appearance, QRZ.com credentials, and about/version —
// a small, single-screen start (no app-polo-style nested settings stack;
// there's nowhere near enough settings yet to need one).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../main.dart';
import 'operation_dialogs.dart';

const _appVersion = '0.1.0'; // keep in sync with app/pubspec.yaml

class SettingsView extends StatefulWidget {
  final HaLoServices services;

  const SettingsView({super.key, required this.services});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Map<String, dynamic>? _syncAccount;
  bool _loadingSyncAccount = false;

  @override
  void initState() {
    super.initState();
    if (widget.services.settings.syncEnabled) _refreshSyncAccount();
  }

  Future<void> _editQrzCredentials() async {
    final settings = widget.services.settings;
    final result = await editTwoFieldDialog(
      context,
      title: 'QRZ.com credentials',
      field1Label: 'Username',
      field1Initial: settings.qrzUsername,
      field2Label: 'Password',
      field2Initial: settings.qrzPassword,
      field2Obscure: true,
    );
    if (result == null) return;

    await widget.services.setQrzCredentials(username: result.$1.trim(), password: result.$2);
    if (mounted) setState(() {});
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

  Future<void> _refreshSyncAccount() async {
    setState(() => _loadingSyncAccount = true);
    final account = await widget.services.extensions.syncAccountData();
    if (!mounted) return;
    setState(() {
      _syncAccount = account;
      _loadingSyncAccount = false;
    });
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

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isMacOSChromelessWindow ? 56 + macOSTrafficLightInset + macOSTrafficLightGap : null,
        leading: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: isMacOSChromelessWindow
              ? const Padding(
                  padding: EdgeInsets.only(left: macOSTrafficLightInset + macOSTrafficLightGap),
                  child: BackButton(),
                )
              : const BackButton(),
        ),
        title: const Text('Settings'),
        actions: const [SizedBox(width: 16)],
      ),
      body: ListView(
        children: [
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
            ),
          ),
          const _SectionHeader('Accounts & services'),
          ListTile(
            leading: Icon(MdiIcons.keyChain),
            title: const Text('QRZ.com credentials'),
            subtitle: Text(settings.hasQrzCredentials ? settings.qrzUsername : 'Not configured'),
            onTap: _editQrzCredentials,
            mouseCursor: SystemMouseCursors.click,
          ),
          const _SectionHeader('Sync'),
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
          const _SectionHeader('About'),
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/ham2k-icon.png', width: 40, height: 40),
            ),
            title: const Text('HaLo Next'),
            subtitle: const Text('Version $_appVersion (dev build)'),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}
