// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// This device's identity on the sync server across a macOS keychain move
// (edition_keychain.dart): a client of its own once the move has brought along
// a device key other editions may share, and the notice for the one account
// change the move can cause.

part of 'halo_services.dart';

mixin _SyncIdentity {
  SettingsService get settings;
  ExtensionService get extensions;
  StatusBarService get statusBar;
  void openSettingsPanel(String panel);

  static const syncAccountReplacedNoticeKey = 'sync:account-replaced';

  /// Gives this device a sync client of its own, on the account it is on,
  /// once a keychain move has brought along a device key other editions on
  /// this Mac may share ([MacKeychainMove.syncClientSplitDue]): one client
  /// shared by several apps is one sync cooldown they fight over. The current
  /// client approves the new one, so the account never changes and nothing is
  /// asked; the current client stays on the account for whoever else uses it.
  /// Anything short of a finished split leaves the device as it was, to try
  /// again on the next launch. One attempt at a time.
  Future<void> splitSyncClientIfDue() => _syncClientSplit ??= _splitSyncClient().whenComplete(() => _syncClientSplit = null);
  Future<void>? _syncClientSplit;

  Future<void> _splitSyncClient() async {
    if (!MacKeychainMove.syncClientSplitDue || settings.syncDeviceKey == null) return;
    final key = uuidGenerator.v4();
    final result = await extensions.syncMoveToNewClient(key);
    if (result == null || result['client'] is! String) {
      debugPrint('[sync] client split not done this launch: ${result?['error'] ?? 'no answer'}');
      return;
    }
    // The transport speaks as the new client from here on, so the key must
    // follow; a write that fails leaves the next launch on the old client,
    // still on this account, and the split due again.
    try {
      await settings.adoptSyncDeviceKey(key);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'sync:client-split');
      return;
    }
    await extensions.setSyncCredentials(deviceKey: key, operatorCall: settings.activeProfile.operatorCall);
    await MacKeychainMove.settleSyncClientSplit();
  }

  /// The sync engine moved this device to a new account without asking
  /// ([SyncEngine.onAccountReplaced]): its sync identity was left behind by a
  /// keychain move, and the server gave the new one an account of its own.
  /// Sync goes on there, so nothing is lost; the operator is told which
  /// account it left, so they can link back to it.
  void _showSyncAccountReplacedNotice(String from, String to) {
    statusBar.showNotice(
      key: syncAccountReplacedNoticeKey,
      icon: 'account-switch',
      title: t.notices.syncAccountReplacedTitle,
      text: t.notices.syncAccountReplaced(previous: syncAccountShortId(from), account: syncAccountShortId(to)),
      actions: [StatusBarAction(label: t.settings.syncPanel.openSettings, onTap: () => openSettingsPanel('sync'))],
    );
  }
}
