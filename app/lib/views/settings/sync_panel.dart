// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Sync: the LoFi account, its counts, and the combine-or-replace choice an
// existing account puts to a fresh install.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/pusher_service.dart';
import '../../tools/sync_account_identity.dart';
import '../confirm_device_dialog.dart';
import '../operation_dialogs.dart';
import '../switch_accounts_dialog.dart';

class SyncPanel extends StatefulWidget {
  final HaLoServices services;

  const SyncPanel({super.key, required this.services});

  @override
  State<SyncPanel> createState() => _SyncPanelState();
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

class _SyncPanelState extends State<SyncPanel> {
  Map<String, dynamic>? _syncAccount;
  bool _loadingSyncAccount = false;
  int? _localOperationCount;
  int? _localQsoCount;
  int? _pendingOperationCount;
  int? _pendingQsoCount;

  Timer? _accountPollTimer;
  Timer? _localCountsTimer;
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
    // On its own cadence, never the account poll's: these are three counts
    // against the local database with no network in them, while that poll
    // drops to a minute precisely to spare the server. Tying them together
    // would leave "Waiting to upload" announcing a backlog for up to a
    // minute after it finished draining — and a number that lags the thing
    // it exists to track is worse than no number, because it is read as
    // "still stuck".
    _localCountsTimer?.cancel();
    _localCountsTimer = Timer.periodic(
      syncAccountPollWithoutRealtime,
      (_) => unawaited(_refreshLocalCounts().catchError(
        (Object error) => debugPrint('[sync-panel] local count refresh failed: $error'),
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
    _localCountsTimer?.cancel();
    _localCountsTimer = null;
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

  /// The four numbers that come from this device's own database — no network,
  /// so this runs on its own short cadence rather than the account poll's.
  Future<void> _refreshLocalCounts() async {
    final operations = await widget.services.operations.syncCounts();
    final qsos = await widget.services.qsos.syncCounts();
    // NOT the `pending` either of those reports, which counts every dirty ROW
    // — tombstones and event markers included — because it answers the sync
    // loop's "anything to push?". The pending line sits directly under one
    // counting what the device HOLDS, and two numbers on one row counting
    // different things is how a panel teaches an operator to distrust it: a
    // handful of offline deletions would put the pending figure above the
    // total.
    final pendingQsos = await widget.services.qsos.unsyncedContactCount();
    final pendingOperations = await widget.services.operations.unsyncedOperationCount();
    if (!mounted) return;
    setState(() {
      _localOperationCount = operations.total;
      _localQsoCount = qsos.total;
      _pendingOperationCount = pendingOperations;
      _pendingQsoCount = pendingQsos;
    });
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
    await _refreshLocalCounts();
    if (!mounted) return;
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
  /// tombstones, event markers and the QSOs of deleted operations left out
  /// (see `QsosRepository.syncCounts`, and LoFi's `QSO.contacts`). The two
  /// numbers sit side by side precisely so a difference means work still in
  /// flight; counting them by different rules would turn that signal into
  /// noise.
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

  /// What this device still owes the server, or null when it owes nothing —
  /// the row above states two totals and nothing else, so a device holding a
  /// large backlog (an ADIF import made while the app was not running long
  /// enough to drain it) reads exactly like an idle one whose numbers happen
  /// to differ. Only the sides with something waiting are named: "0
  /// operations" is not news, and padding the line with it buries the half
  /// that is.
  String? get _pendingCountsLine {
    final operations = _pendingOperationCount, qsos = _pendingQsoCount;
    if (operations == null || qsos == null) return null;
    if (operations == 0 && qsos == 0) return null;
    final items = [
      if (qsos > 0) t.settings.syncPanel.countQsos(count: qsos, n: formatNumber(qsos)),
      if (operations > 0)
        t.settings.syncPanel.countOperations(count: operations, n: formatNumber(operations)),
    ];
    return t.settings.syncPanel.countsPending(items: items.join(' · '));
  }

  /// Null when the server did not report BOTH counts — no account payload
  /// yet, or one that predates these fields. Either alone is not enough:
  /// substituting 0 for the missing half would read as the account having
  /// lost everything on that side, which is precisely the alarm this row must
  /// not raise falsely.
  String? get _serverCountsLine {
    final (:operations, :qsos) = syncAccountCounts(_syncAccount);
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
                    if (_pendingCountsLine case final pending?) Text(pending),
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
