// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings "Switch Accounts" dialog (issue #79): moves this device to a
// different Ham2K Log Filer account. Ported from app-polo's
// SyncAccountDialog/SyncLinkingDialog pair, but HaLo is only ever the
// *requesting* side here — approval happens on a device already linked to
// the target account (e.g. PoLo on a phone), so there's no scanner and no
// code-entry view in this dialog.
//
// Three ways in, all backed by `POST v1/client/permissions`:
//  - Quick switch: accounts this client already holds an active permission
//    on (from `getAccountData`'s `accounts`) switch immediately.
//  - Email: a pending permission on that account; its `challenge_token` is
//    shown here for the user to type into an already-linked device, with a
//    confirmation email as fallback.
//  - QR code: a blank ("orphaned") permission encoded as the same
//    `com.ham2k:///link_client?id=…&token=…` deep link app-polo generates,
//    for an already-linked phone to scan and approve.
//
// While a request is pending, the dialog polls `getAccountData` (app-polo
// uses the same 5s cadence) and treats a changed `current_account.uuid` as
// success — the caller then kicks the sync engine, whose own
// account-identity gating raises the combine/replace banner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../i18n/strings.g.dart';

/// How the other device's deep link is assembled — same scheme and params
/// as app-polo's SyncAccountDialog (`com.ham2k:///link_client?id=…&token=…`).
String linkClientQrUrl({required String clientUuid, required String challengeToken}) =>
    'com.ham2k:///link_client?id=$clientUuid&token=$challengeToken';

/// Returns true when the device ended up linked to a different account (the
/// caller should kick a sync round so reconciliation starts right away).
/// A Modal Pane (docs/design/layouts.md): a dialog on wide layouts, a full
/// screen on phones — the QR/code flows want the room there.
Future<bool?> showSwitchAccountsDialog(
  BuildContext context, {
  required Future<Map<String, dynamic>?> Function() fetchAccountData,
  required Future<Map<String, dynamic>?> Function(String? email) linkClient,
  required Future<Map<String, dynamic>?> Function(String email) linkClientWithEmail,
}) {
  return showModalPane<bool>(
    context,
    title: context.t.settings.syncPanel.switchAccounts,
    barrierDismissible: false,
    closeTooltip: context.t.common.close,
    builder: (context) => SwitchAccountsPane(
      fetchAccountData: fetchAccountData,
      linkClient: linkClient,
      linkClientWithEmail: linkClientWithEmail,
    ),
  );
}

enum _Mode { menu, email, code, emailSent, qr }

class SwitchAccountsPane extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() fetchAccountData;
  final Future<Map<String, dynamic>?> Function(String? email) linkClient;
  final Future<Map<String, dynamic>?> Function(String email) linkClientWithEmail;

  final VoidCallback? onLinked;
  final VoidCallback? onCancel;
  final bool hideAccountsList;
  final String? cancelLabel;

  /// Overridable so tests can drive the poll loop without real 5s waits.
  final Duration pollInterval;

  /// Injectable clock so tests can expire a challenge without real waits.
  final DateTime Function() now;

  const SwitchAccountsPane({
    super.key,
    required this.fetchAccountData,
    required this.linkClient,
    required this.linkClientWithEmail,
    this.onLinked,
    this.onCancel,
    this.hideAccountsList = false,
    this.cancelLabel,
    this.pollInterval = const Duration(seconds: 5),
    this.now = DateTime.now,
  });

  @override
  State<SwitchAccountsPane> createState() => _SwitchAccountsPaneState();
}

class _SwitchAccountsPaneState extends State<SwitchAccountsPane> {
  _Mode _mode = _Mode.menu;
  Map<String, dynamic>? _accountData;
  bool _loadingAccountData = true;

  /// The account this device was on when the link request started —
  /// polling declares success when `current_account.uuid` moves off it.
  /// Only refreshed in the menu (pre-request) modes, so a change observed
  /// mid-request can't be absorbed as the new baseline.
  String? _baselineAccountUuid;

  final _emailController = TextEditingController();
  bool _busy = false;
  String? _error;
  void _onSuccess() {
    _pollTimer?.cancel();
    if (widget.onLinked != null) {
      widget.onLinked!();
    } else if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _doCancel() {
    _pollTimer?.cancel();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  // Email-flow state: the code to type on an already-linked device.
  String? _challengeCode;
  String? _pendingEmail;

  // QR-flow state.
  String? _qrUrl;

  /// When the server-side challenge (QR or on-screen code) dies — 10
  /// minutes; both flows renew it from a poll tick past this instant.
  DateTime? _challengeExpiresAt;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountData() async {
    final data = await widget.fetchAccountData();
    if (!mounted) return;
    setState(() {
      _accountData = data;
      _loadingAccountData = false;
      final uuid = (data?['current_account'] as Map?)?['uuid'] as String?;
      if (_mode == _Mode.menu || _mode == _Mode.email) _baselineAccountUuid = uuid ?? _baselineAccountUuid;
    });
  }

  List<Map<String, dynamic>> get _otherAccounts => ((_accountData?['accounts'] as List?) ?? const [])
      .whereType<Map>()
      .map((a) => a.cast<String, dynamic>())
      .toList();

  /// "N QSOs · M operations", or null when the server sent no counts at all
  /// (e.g. an account payload without stats).
  static String? _countsLine(int? qsoCount, int? operationCount) {
    if (qsoCount == null && operationCount == null) return null;
    return '${t.switchAccounts.qsoCount(count: qsoCount ?? 0)} · ${t.switchAccounts.operationCount(count: operationCount ?? 0)}';
  }

  /// One account row: callsign and email on the first line, QSO/operation
  /// counts on the second. Shared by the current account (not tappable) and
  /// the quick-switch list.
  Widget _accountTile({
    required Map<String, dynamic> account,
    required String iconName,
    int? qsoCount,
    int? operationCount,
    VoidCallback? onTap,
  }) {
    final call = account['call'] as String?;
    final email = account['email'] as String?;
    final firstLine = [if (call?.isNotEmpty == true) call!, if (email?.isNotEmpty == true) email!].join(' — ');
    final counts = _countsLine(qsoCount, operationCount);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(resolveIconName(iconName)),
      // A brand-new client's account can have neither call nor email yet.
      title: Text(firstLine.isNotEmpty ? firstLine : t.switchAccounts.noCallsignOrEmail),
      subtitle: counts == null ? null : Text(counts),
      onTap: onTap,
      mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => unawaited(_pollTick()));
  }

  Future<void> _pollTick() async {
    final data = await widget.fetchAccountData();
    if (!mounted || data == null) return;
    final newUuid = (data['current_account'] as Map?)?['uuid'] as String?;
    if (newUuid != null && _baselineAccountUuid != null && newUuid != _baselineAccountUuid) {
      _onSuccess();
      return;
    }
    // The menu's initial fetch failed (e.g. transient network): first
    // successful contact establishes the baseline instead of a false match.
    _baselineAccountUuid ??= newUuid;

    // A challenge only lives 10 minutes server-side; renew whichever one is
    // on screen (re-requesting regenerates the pending permission's token).
    final expired = _challengeExpiresAt != null && widget.now().isAfter(_challengeExpiresAt!);
    if (expired) {
      if (_mode == _Mode.qr) {
        await _requestQrPermission();
      } else if (_mode == _Mode.code) {
        await _renewEmailChallenge();
      }
    }
  }

  /// The on-screen code expired before the other device confirmed it:
  /// re-request the pending permission, which regenerates its token.
  Future<void> _renewEmailChallenge() async {
    final email = _pendingEmail;
    if (email == null) return;
    final result = _usableResult(await widget.linkClient(email), emailForNotFound: email);
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    if (permission == null) {
      setState(() {}); // surface whatever _usableResult recorded
      return;
    }
    if (permission['status'] == 'active') {
      _onSuccess();
      return;
    }
    setState(_applyChallenge(permission));
  }

  /// Records a pending permission's code + expiry (returned as a closure so
  /// callers compose it into their own setState).
  VoidCallback _applyChallenge(Map<String, dynamic> permission) => () {
    _challengeCode = permission['challenge_token'] as String?;
    final expires = permission['challenge_expires_at'] as String?;
    _challengeExpiresAt = expires != null ? DateTime.tryParse(expires) : null;
  };

  /// Shared shape of every `linkClient` result: null → unreachable,
  /// `error` → the server said no. Returns the map only when usable.
  Map<String, dynamic>? _usableResult(Map<String, dynamic>? result, {String? emailForNotFound}) {
    if (result == null) {
      _error = t.switchAccounts.serverUnreachable;
      return null;
    }
    if (result['error'] != null) {
      _error = result['error_status'] == 404 && emailForNotFound != null
          ? 'No account found for $emailForNotFound.'
          : 'The sync server rejected the request: ${result['error']}';
      return null;
    }
    return result;
  }

  Future<void> _quickSwitch(Map<String, dynamic> account) async {
    final email = account['email'] as String?;
    if (email == null || email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _usableResult(await widget.linkClient(email), emailForNotFound: email);
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    if (permission?['status'] == 'active') {
      setState(() => _busy = false);
      _onSuccess();
      return;
    }
    if (permission?['challenge_token'] != null) {
      // An already-permitted account should switch instantly, but this one
      // came back pending (e.g. the permission was revoked server-side).
      // The response carries a fresh challenge, so go straight to the code
      // view instead of making the user retype the email.
      setState(() {
        _busy = false;
        _pendingEmail = email;
        _applyChallenge(permission!)();
        _mode = _Mode.code;
      });
      _startPolling();
      return;
    }
    setState(() => _busy = false);
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = _usableResult(await widget.linkClient(email), emailForNotFound: email);
    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
      return;
    }
    final permission = (result['permission'] as Map?)?.cast<String, dynamic>();
    if (permission?['status'] == 'active') {
      // Already had a permission on that account — switched immediately.
      setState(() => _busy = false);
      _onSuccess();
      return;
    }
    setState(() {
      _busy = false;
      _pendingEmail = email;
      if (permission != null) _applyChallenge(permission)();
      _mode = _Mode.code;
    });
    _startPolling();
  }

  Future<void> _sendConfirmationEmail() async {
    final email = _pendingEmail;
    if (email == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.linkClientWithEmail(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null) {
        _error = t.switchAccounts.serverUnreachable;
      } else {
        _mode = _Mode.emailSent;
      }
    });
  }

  Future<void> _requestQrPermission() async {
    final result = _usableResult(await widget.linkClient(null));
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    final clientUuid = permission?['client'] as String?;
    final token = permission?['challenge_token'] as String?;
    setState(() {
      _busy = false;
      if (clientUuid != null && token != null) {
        _qrUrl = linkClientQrUrl(clientUuid: clientUuid, challengeToken: token);
        _applyChallenge(permission!)();
      } else {
        _error ??= 'The sync server did not return a link code. Try again later.';
      }
    });
  }

  Future<void> _showQr() async {
    setState(() {
      _busy = true;
      _error = null;
      _mode = _Mode.qr;
      _qrUrl = null;
    });
    await _requestQrPermission();
    _startPolling();
  }

  void _backToMenu() {
    _pollTimer?.cancel();
    setState(() {
      _mode = _Mode.menu;
      _error = null;
      _busy = false;
      _challengeCode = null;
      _pendingEmail = null;
      _qrUrl = null;
      _challengeExpiresAt = null;
    });
    unawaited(_loadAccountData());
  }

  @override
  Widget build(BuildContext context) {
    // The Modal Pane route provides the chrome (title, scrolling, width);
    // the action row lives here because it depends on this State (_mode,
    // _busy) — the same coupling AlertDialog had.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContent(context),
        const SizedBox(height: 24),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            if (_mode != _Mode.menu) TextButton(onPressed: _busy ? null : _backToMenu, child: Text(context.t.onboarding.back)),
            if (_mode == _Mode.email)
              FilledButton(onPressed: _busy ? null : _submitEmail, child: Text(context.t.switchAccounts.linkAccount)),
            TextButton(onPressed: _doCancel, child: Text(widget.cancelLabel ?? context.t.common.cancel)),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_mode) {
      case _Mode.menu:
        return _buildMenu(context);
      case _Mode.email:
        return _buildEmailEntry(context);
      case _Mode.code:
        return _buildCode(context);
      case _Mode.emailSent:
        return _buildEmailSent(context);
      case _Mode.qr:
        return _buildQr(context);
    }
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);
    final current = (_accountData?['current_account'] as Map?)?.cast<String, dynamic>();
    final others = _otherAccounts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.hideAccountsList) ...[
          if (_loadingAccountData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(context.t.switchAccounts.currentAccount, style: theme.textTheme.titleSmall),
            _accountTile(
              account: current ?? const {},
              iconName: 'account-check',
              // The current account's counts come from the getAccountData
              // response's top-level totals, not per-account stats.
              qsoCount: ((_accountData?['qsos'] as Map?)?['total'] as num?)?.toInt(),
              operationCount: ((_accountData?['operations'] as Map?)?['total'] as num?)?.toInt(),
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(context.t.switchAccounts.otherAccounts, style: theme.textTheme.titleSmall),
              ...others.map((account) {
                final stats = (account['stats'] as Map?)?.cast<String, dynamic>();
                return _accountTile(
                  account: account,
                  iconName: 'account',
                  qsoCount: (stats?['qso_count'] as num?)?.toInt(),
                  operationCount: (stats?['operation_count'] as num?)?.toInt(),
                  onTap: _busy ? null : () => _quickSwitch(account),
                );
              }),
            ],
          ],
          const SizedBox(height: 12),
          Text(context.t.switchAccounts.linkToAnother, style: theme.textTheme.titleSmall),
        ],
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(resolveIconName('qrcode')),
          title: Text(context.t.switchAccounts.linkWithQr),
          subtitle: Text(context.t.switchAccounts.linkWithQrDescription),
          enabled: !_busy,
          onTap: _showQr,
          mouseCursor: SystemMouseCursors.click,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(resolveIconName('email')),
          title: Text(context.t.switchAccounts.linkWithEmail),
          subtitle: Text(context.t.switchAccounts.linkWithEmailDescription),
          enabled: !_busy,
          onTap: () => setState(() {
            _error = null;
            _mode = _Mode.email;
          }),
          mouseCursor: SystemMouseCursors.click,
        ),
        ..._errorAndBusy(context),
      ],
    );
  }

  Widget _buildEmailEntry(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.switchAccounts.enterEmailPrompt),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: context.t.switchAccounts.emailAddress, border: const OutlineInputBorder()),
          onSubmitted: (_) => _submitEmail(),
        ),
        ..._errorAndBusy(context),
      ],
    );
  }

  Future<void> _copyChallengeCode(BuildContext context) async {
    final code = _challengeCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t.switchAccounts.copiedCode)));
  }

  Widget _buildCode(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t.switchAccounts.codePrompt(email: '$_pendingEmail'),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _challengeCode ?? '—',
                style: theme.textTheme.displayMedium?.copyWith(fontFamily: 'RobotoMono', letterSpacing: 4),
              ),
              if (_challengeCode != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(resolveIconName('content-copy')),
                  tooltip: context.t.switchAccounts.copyCode,
                  onPressed: () => _copyChallengeCode(context),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(context.t.switchAccounts.waitingForConfirmation)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: _busy ? null : _sendConfirmationEmail,
            child: Text(context.t.switchAccounts.sendEmailInstead),
          ),
        ),
        ..._errorAndBusy(context),
      ],
    );
  }

  Widget _buildEmailSent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.switchAccounts.emailSent(email: '$_pendingEmail')),
        const SizedBox(height: 16),
        Center(child: Text(context.t.switchAccounts.waitingForConfirmation)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(onPressed: _busy ? null : _sendConfirmationEmail, child: Text(context.t.switchAccounts.resendEmail)),
        ),
        ..._errorAndBusy(context),
      ],
    );
  }

  Widget _buildQr(BuildContext context) {
    final url = _qrUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t.switchAccounts.qrPrompt,
        ),
        const SizedBox(height: 16),
        Center(
          child: url == null
              ? const Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())
              // White quiet zone regardless of theme so cameras can read it.
              : Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  // Keyed by payload so a regenerated challenge (expiry)
                  // replaces, not just repaints, the QR widget.
                  child: QrImageView(key: ValueKey(url), data: url, size: 200),
                ),
        ),
        if (url != null) ...[const SizedBox(height: 16), Center(child: Text(context.t.switchAccounts.waitingForConfirmation))],
        ..._errorAndBusy(context),
      ],
    );
  }

  List<Widget> _errorAndBusy(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
      ],
      if (_busy) ...[const SizedBox(height: 12), const Center(child: CircularProgressIndicator())],
    ];
  }
}
