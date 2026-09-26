// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Settings "Switch Accounts" dialog: moves this device to a
// different Ham2K Log Filer account. Ported from app-polo's
// SyncAccountDialog/SyncLinkingDialog pair. This pane is the *requesting*
// side only — approval happens in an app already linked to the target
// account, which is HaLo's confirm_device_dialog.dart when the request
// arrives here as a `link_client` deep link, so there's no scanner and no
// code-entry view in this dialog.
//
// Four ways in, all backed by `POST v1/client/permissions`:
//  - Quick switch: accounts this client already holds an active permission
//    on (from `getAccountData`'s `accounts`) switch immediately.
//  - Email: a pending permission on that account; its `challenge_token` is
//    shown here for the user to type into an already-linked device, with a
//    confirmation email as fallback.
//  - QR code: a blank ("orphaned") permission encoded as the same
//    `com.ham2k:///link_client?id=…&token=…` deep link app-polo generates,
//    for an already-linked phone to scan and approve.
//  - A sibling app: the same orphaned permission, but the link is
//    handed to another Ham2K logger on THIS device (SiblingAppsService)
//    instead of painted; the operator approves there and comes back.
//
// While a request is pending, the dialog polls `getAccountData` (app-polo
// uses the same 5s cadence) and treats a changed `current_account.uuid` as
// success — the caller then kicks the sync engine, whose own
// account-identity gating raises the combine/replace banner.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../services/error_reporting_service.dart';
import '../services/sibling_apps_service.dart';
import '../tools/sync_account_identity.dart';

/// How the other device's deep link is assembled — same scheme and params
/// as app-polo's SyncAccountDialog (`com.ham2k:///link_client?id=…&token=…`).
String linkClientQrUrl({required String clientUuid, required String challengeToken}) => 'com.ham2k:///link_client?id=$clientUuid&token=$challengeToken';

/// Returns true when the device ended up linked to a different account (the
/// caller should kick a sync round so reconciliation starts right away).
/// A Modal Pane (docs/design/layouts.md): a dialog on wide layouts, a full
/// screen on phones — the QR/code flows want the room there.
Future<bool?> showSwitchAccountsDialog(
  BuildContext context, {
  required Future<Map<String, dynamic>?> Function() fetchAccountData,
  required Future<Map<String, dynamic>?> Function(String? email) linkClient,
  required Future<Map<String, dynamic>?> Function(String email) linkClientWithEmail,
  List<SiblingApp> siblings = const [],
  Future<bool> Function(SiblingApp app, String url)? openSibling,
}) {
  return showModalPane<bool>(
    context,
    title: context.t.settings.syncPanel.switchAccounts,
    barrierDismissible: false,
    closeLabel: context.t.common.close,
    builder: (context) => SwitchAccountsPane(
      fetchAccountData: fetchAccountData,
      linkClient: linkClient,
      linkClientWithEmail: linkClientWithEmail,
      siblings: siblings,
      openSibling: openSibling,
      hostHasCloseIcon: true,
    ),
  );
}

enum _Mode { menu, email, code, emailSent, qr, sibling }

class SwitchAccountsPane extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function() fetchAccountData;
  final Future<Map<String, dynamic>?> Function(String? email) linkClient;
  final Future<Map<String, dynamic>?> Function(String email) linkClientWithEmail;

  final VoidCallback? onLinked;
  final VoidCallback? onCancel;
  final bool hideAccountsList;
  final String? cancelLabel;

  /// The other Ham2K loggers installed on this device, each offered as a
  /// menu row that hands the link across. Empty everywhere but
  /// mobile. [openSibling] is what does the handing; without it the rows are
  /// not offered at all.
  final List<SiblingApp> siblings;
  final Future<bool> Function(SiblingApp app, String url)? openSibling;

  /// Start straight in the sibling flow with this app rather than on the
  /// menu — onboarding's "we found X" step has already asked.
  final SiblingApp? initialSibling;

  /// An extra way out shown once the operator came back from the sibling
  /// with nothing granted: onboarding offers "set up fresh" here. Null
  /// leaves only the Back button, which is all a Settings pane needs.
  final String? fallbackLabel;
  final VoidCallback? onFallback;

  /// Whether the host surface carries a way out of its own — a Modal Pane's
  /// header close icon. Decides where the footer needs one too; see
  /// [_SwitchAccountsPaneState._showCancel].
  final bool hostHasCloseIcon;

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
    this.siblings = const [],
    this.openSibling,
    this.initialSibling,
    this.fallbackLabel,
    this.onFallback,
    this.hostHasCloseIcon = false,
    this.pollInterval = const Duration(seconds: 5),
    // REAL time: the only thing this is compared against is the server's
    // `challenge_expires_at` (see `_pollForLink`), which is category 1 of
    // realNowUtc's contract — a value measured against someone else's clock.
    // Travelled forward, every poll tick reads the challenge as expired and
    // renews it, replacing the QR/code the operator is mid-way through reading
    // to the other device; travelled backward it is never renewed at all.
    this.now = realNowUtc,
  });

  @override
  State<SwitchAccountsPane> createState() => _SwitchAccountsPaneState();
}

class _SwitchAccountsPaneState extends State<SwitchAccountsPane> with WidgetsBindingObserver {
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

  /// Set by whichever exit runs first, and the reason both check it: `mounted`
  /// does NOT mean "still on screen". A route stays mounted for its whole exit
  /// animation, so a host call suspended across a dismissal wakes on a live
  /// State whose route is already leaving — and a second `Navigator.pop` from
  /// there lands on whatever sits underneath, closing the caller's own screen.
  /// The first exit decides; a later one has nothing left to report to.
  bool _closing = false;

  void _onSuccess() {
    if (_closing) return;
    _closing = true;
    _stopPolling();
    if (widget.onLinked != null) {
      widget.onLinked!();
    } else if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _doCancel() {
    if (_closing) return;
    _closing = true;
    _stopPolling();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  // Email-flow state: the code to type on an already-linked device.
  String? _challengeCode;
  String? _pendingEmail;

  // QR-flow state; the sibling flow carries the same URL, on the same
  // permission, to a different reader.
  String? _qrUrl;

  // Sibling-flow state.
  SiblingApp? _sibling;

  /// The app came back to the foreground while the sibling request was
  /// live and the very next poll found no grant. That is the moment the
  /// operator most needs another way out — the only other signal is a
  /// spinner that says "waiting" forever.
  bool _resumedWithoutGrant = false;

  /// The challenge the sibling was handed expired and a fresh one exists
  /// here — the sibling must be opened again to receive it.
  bool _linkRenewed = false;

  /// When the server-side challenge (QR or on-screen code) dies — 10
  /// minutes; both flows renew it from a poll tick past this instant.
  DateTime? _challengeExpiresAt;

  /// Non-null only while a challenge is genuinely being POLLED for — which is
  /// narrower than "a request is in flight", the question [build]'s PopScope
  /// actually asks: `_busy` covers the request that precedes the poll, and the
  /// two disagree for its whole duration.
  ///
  /// Always cleared through [_stopPolling], never a bare `cancel()`, because
  /// `Timer.cancel()` leaves the reference in place and this field is read as
  /// a state, not as a handle.
  Timer? _pollTimer;

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final sibling = widget.initialSibling;
    if (sibling == null) {
      _loadAccountData();
    } else {
      unawaited(_startWithSibling(sibling));
    }
  }

  /// The baseline must be known BEFORE the permission goes out: a poll tick
  /// that first learns the account after the sibling already approved it
  /// would adopt the new account as the baseline and never see the change.
  /// The operator leaves for the other app the instant the request is out,
  /// so "first successful contact" is routinely after the grant — which is
  /// why an unknown baseline stops here, with a retry, rather than going on.
  Future<void> _startWithSibling(SiblingApp sibling) async {
    await _loadAccountData();
    if (!mounted) return;
    if (_baselineAccountUuid == null) {
      setState(() {
        _mode = _Mode.sibling;
        _sibling = sibling;
        _error = t.switchAccounts.serverUnreachable;
      });
      return;
    }
    await _showSibling(sibling);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _emailController.dispose();
    super.dispose();
  }

  /// Coming back from the sibling app is the moment the grant is most
  /// likely to have landed, so poll now rather than waiting out the tick —
  /// and if it has NOT landed, say so, instead of leaving "waiting" on
  /// screen with nothing else to press.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_mode != _Mode.sibling || _pollTimer == null) return;
    unawaited(_pollAfterResume());
  }

  Future<void> _pollAfterResume() async {
    final answered = await _pollTick();
    if (!mounted || _closing || _mode != _Mode.sibling) return;
    // "Didn't work?" is a claim about the server's answer. A tick that got
    // none says nothing about the grant — and the fallback it would offer,
    // in onboarding, is "set up fresh" against an account that may well be
    // linked by now.
    setState(() {
      if (answered) {
        _resumedWithoutGrant = true;
      } else {
        _error = t.switchAccounts.serverUnreachable;
      }
    });
  }

  Future<void> _loadAccountData() async {
    final data = await _attempt('account-data', widget.fetchAccountData, paintError: false, operatorAction: false);
    if (!mounted) return;
    setState(() {
      _accountData = data;
      _loadingAccountData = false;
      final uuid = (data?['current_account'] as Map?)?['uuid'] as String?;
      // A sibling retry (_startWithSibling) reloads from sibling mode with
      // no request out yet, which is the one other moment a baseline may be
      // taken: nothing has been granted that could be absorbed.
      if (_mode == _Mode.menu || _mode == _Mode.email || _baselineAccountUuid == null) {
        _baselineAccountUuid = uuid ?? _baselineAccountUuid;
      }
    });
  }

  List<Map<String, dynamic>> get _otherAccounts =>
      ((_accountData?['accounts'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().map((a) => a.cast<String, dynamic>()).toList();

  /// "N QSOs · M operations", or null when the server sent no counts at all
  /// (e.g. an account payload without stats).
  static String? _countsLine(int? qsoCount, int? operationCount) {
    if (qsoCount == null && operationCount == null) return null;
    return '${t.switchAccounts.qsoCount(count: qsoCount ?? 0)} · ${t.switchAccounts.operationCount(count: operationCount ?? 0)}';
  }

  /// One account row: the account's identity (email or anonymous id — see
  /// syncAccountIdentity; accounts are identified by email, not callsign)
  /// on the first line, QSO/operation counts on the second. Shared by the
  /// current account (not tappable) and the quick-switch list, which passes
  /// [includePending] false: its tap links by the confirmed email, so the
  /// row must not display a pending address the action won't use.
  Widget _accountTile({
    required Map<String, dynamic> account,
    required IconData icon,
    bool includePending = true,
    int? qsoCount,
    int? operationCount,
    VoidCallback? onTap,
  }) {
    final identity = syncAccountIdentity(account, includePending: includePending);
    final counts = _countsLine(qsoCount, operationCount);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      // The placeholder shown before account data has loaded carries no
      // identity at all.
      title: Text(identity ?? t.switchAccounts.noAccountDetails),
      subtitle: counts == null ? null : Text(counts),
      onTap: onTap,
      mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    );
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(widget.pollInterval, (_) => unawaited(_pollTick()));
  }

  /// Returns whether the server answered at all — false says nothing about
  /// the challenge, and callers that turn a tick into a message must not
  /// read it as "not yet".
  Future<bool> _pollTick() async {
    // Deliberately NOT through _attempt: a tick's own fetch failing says
    // nothing about the challenge on screen, which is still perfectly valid,
    // so painting an error over it would be a lie. The renewals this tick may
    // go on to call DO paint — an expired challenge really is dead — but they
    // pass operatorAction: false, because a timer retrying every five seconds
    // is not the "somebody pressed this three times" the streak measures.
    // That a poll which never succeeds still says nothing is a separate gap,
    // and not one this catch closes.
    //
    // A try/catch, not `.catchError((_) => null)`: that handler's inferred
    // return type is Null, which the typed future rejects with an
    // ArgumentError of its own — the tick then dies on exactly the fetch
    // failure it meant to shrug off.
    Map<String, dynamic>? data;
    try {
      data = await widget.fetchAccountData();
    } catch (_) {
      data = null;
    }
    if (!mounted || data == null) return false;
    final newUuid = (data['current_account'] as Map?)?['uuid'] as String?;
    if (newUuid != null && _baselineAccountUuid != null && newUuid != _baselineAccountUuid) {
      _onSuccess();
      return true;
    }
    // The menu's initial fetch failed (e.g. transient network): first
    // successful contact establishes the baseline instead of a false match.
    _baselineAccountUuid ??= newUuid;

    // A challenge only lives 10 minutes server-side; renew whichever one is
    // on screen (re-requesting regenerates the pending permission's token).
    final expired = _challengeExpiresAt != null && widget.now().isAfter(_challengeExpiresAt!);
    if (expired) {
      if (_mode == _Mode.qr) {
        await _requestQrPermission(operatorAction: false);
      } else if (_mode == _Mode.sibling) {
        // A QR repaints itself; the sibling still holds the dead link and
        // nothing here can reach into it. Say so — but never auto-reopen,
        // which would steal the screen from whatever the operator is doing.
        await _requestQrPermission(operatorAction: false);
        if (mounted && _qrUrl != null) setState(() => _linkRenewed = true);
      } else if (_mode == _Mode.code) {
        await _renewEmailChallenge(operatorAction: false);
      }
    }
    return true;
  }

  /// The on-screen code expired before the other device confirmed it:
  /// re-request the pending permission, which regenerates its token.
  Future<void> _renewEmailChallenge({bool operatorAction = true}) async {
    final email = _pendingEmail;
    if (email == null) return;
    final result = await _attempt('renew-challenge', () => widget.linkClient(email), emailForNotFound: email, operatorAction: operatorAction);
    if (!mounted) return;
    final permission = (result?['permission'] as Map?)?.cast<String, dynamic>();
    if (permission == null) {
      setState(() {}); // surface whatever _attempt recorded
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

  /// Every host call goes through here, so that "did this give me something I
  /// can use?" is one question with one answer however the call failed —
  /// thrown, null, or an error payload. Returns the map only when usable, and
  /// records the reason in [_error] otherwise; callers `setState` around it.
  ///
  /// A throw is the case that has no other safety net. `syncLinkClient`
  /// converts only `ExtensionHostException` into a null, so anything else
  /// escapes an `await` here and takes `_busy` with it — the operator is left
  /// with a spinner and every control disabled. Catching keeps the pane
  /// answerable; it does not decide the error is uninteresting, which is
  /// [ErrorPolicy]'s job alone (error-reporting.md).
  ///
  /// [key] separates the streaks: reporting is per call, not per pane, so a
  /// broken QR request is not masked by a working email one.
  ///
  /// [paintError] is false for a call the operator did not make — the fetch on
  /// mount — where a red line about account data would greet a step that never
  /// shows any and whose linking flows work without it.
  ///
  /// [operatorAction] is false for anything a timer drove. The streak exists to
  /// separate "the world is unreliable" from "this is broken", and only a
  /// person pressing a button carries that meaning; a poll retrying every five
  /// seconds would reach the threshold on its own, with nobody having asked
  /// for anything.
  Future<Map<String, dynamic>?> _attempt(
    String key,
    Future<Map<String, dynamic>?> Function() call, {
    String? emailForNotFound,
    bool paintError = true,
    bool operatorAction = true,
  }) async {
    Map<String, dynamic>? result;
    try {
      result = await call();
    } catch (e, st) {
      // Unconditional, and the reason it is not left to reportIfRepeated: that
      // one prints only on the throw that reaches the threshold, so a call
      // failing intermittently — the flaky-backend case — would otherwise
      // leave no trace anywhere at all. The console is where an error without
      // a notice is supposed to be findable (error-reporting.md).
      debugPrint('[switch-accounts] $key failed: $e\n$st');
      // Not report(): a link the operator triggers by hand fails for a tunnel
      // or a captive portal far more often than for a defect, and uploading
      // every one of those tells nobody anything. The same call failing three
      // times running is the defect, and that does report.
      if (operatorAction) {
        ErrorReportingService.reportIfRepeated('switch-accounts:$key', e, st, context: 'switch-accounts:$key');
      }
      if (paintError) _error = t.switchAccounts.requestFailed;
      return null;
    }
    // Anything that RETURNED proves the call itself works, so it ends the
    // streak — including "unreachable" and a rejection. Only a throw counts,
    // which is what lets the report say "in a row" and mean it.
    if (operatorAction) ErrorReportingService.recordSuccess('switch-accounts:$key');
    if (result == null) {
      if (paintError) _error = t.switchAccounts.serverUnreachable;
      return null;
    }
    if (result['error'] != null) {
      if (paintError) {
        _error = result['error_status'] == 404 && emailForNotFound != null
            ? t.switchAccounts.noAccountForEmail(email: emailForNotFound)
            : t.switchAccounts.serverRejected(error: '${result['error']}');
      }
      return null;
    }
    // A usable answer retires the previous failure's message. Callers below
    // then use `??=` for their own "usable but not what I needed" cases, which
    // is only correct because nothing stale can be sitting here.
    if (paintError) _error = null;
    return result;
  }

  Future<void> _quickSwitch(Map<String, dynamic> account) async {
    final email = account['email'] as String?;
    if (email == null || email.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _attempt('quick-switch', () => widget.linkClient(email), emailForNotFound: email);
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
    // Reachable, no error, and neither switched nor challenged — a shape this
    // client has no move for. Saying nothing here is what makes the row read
    // as a dead control; _attempt cannot catch it, because the call worked.
    setState(() {
      _busy = false;
      _error ??= t.switchAccounts.switchNotAccepted;
    });
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    // Reached both by the button and by the soft keyboard's Go key. Returning
    // in silence makes whichever one they pressed a control that does nothing
    // — and it returns before the _error reset below, so the previous
    // attempt's message sits there unchanged, saying something else entirely.
    if (email.isEmpty) {
      setState(() => _error = t.switchAccounts.emailRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _attempt('link-by-email', () => widget.linkClient(email), emailForNotFound: email);
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
    // No challenge means there is no code to show and nothing for the poll to
    // wait for: the code view would render an em dash under "Waiting for
    // confirmation…" forever. Stay put and say so.
    if (permission?['challenge_token'] == null) {
      setState(() {
        _busy = false;
        _error = t.switchAccounts.noConfirmationCode;
      });
      return;
    }
    setState(() {
      _busy = false;
      _pendingEmail = email;
      _applyChallenge(permission!)();
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
    final result = await _attempt('send-confirmation', () => widget.linkClientWithEmail(email));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result != null) _mode = _Mode.emailSent;
    });
  }

  Future<void> _requestQrPermission({bool operatorAction = true}) async {
    final result = await _attempt('request-qr', () => widget.linkClient(null), operatorAction: operatorAction);
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
        // `??=`, so _attempt's specific reason (unreachable, rejected, 404)
        // outranks this generic one — it cannot be stale, since a usable
        // answer clears _error.
        _error ??= t.switchAccounts.noLinkCode;
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
    // The dismissal that happened while the request was in flight has already
    // disposed this State and stopped its poll; starting one here would assign
    // a periodic Timer to a dead object, and nothing could ever cancel it.
    if (!mounted) return;
    _startPolling();
  }

  /// Same permission as the QR flow — [linkClientQrUrl] builds the link for
  /// both, so the two cannot drift — handed to [sibling] instead of painted.
  Future<void> _showSibling(SiblingApp sibling) async {
    setState(() {
      _busy = true;
      _error = null;
      _mode = _Mode.sibling;
      _sibling = sibling;
      _qrUrl = null;
      _resumedWithoutGrant = false;
      _linkRenewed = false;
    });
    await _requestQrPermission();
    if (!mounted) return;
    if (_qrUrl != null) await _openSibling();
    // See _showQr: a dismissal during the request has already disposed this
    // State, and a poll started now could never be cancelled.
    if (!mounted) return;
    _startPolling();
  }

  /// Hands the current link to the sibling; a refusal paints, since the
  /// operator is otherwise left waiting for an app that never opened.
  Future<void> _openSibling() async {
    final sibling = _sibling;
    final url = _qrUrl;
    final open = widget.openSibling;
    if (sibling == null || url == null || open == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _resumedWithoutGrant = false;
      _linkRenewed = false;
    });
    var ok = false;
    try {
      ok = await open(sibling, url);
      // Same streak discipline as _attempt: a launch that works ends it, so
      // three failures spread over months are not reported as "in a row".
      ErrorReportingService.recordSuccess('switch-accounts:open-sibling');
    } catch (e, st) {
      debugPrint('[switch-accounts] open-sibling failed: $e\n$st');
      ErrorReportingService.reportIfRepeated('switch-accounts:open-sibling', e, st, context: 'switch-accounts:open-sibling');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = t.switchAccounts.siblingOpenFailed(app: sibling.name);
    });
  }

  void _backToMenu() {
    _stopPolling();
    setState(() {
      _mode = _Mode.menu;
      _error = null;
      _busy = false;
      _challengeCode = null;
      _pendingEmail = null;
      _qrUrl = null;
      _sibling = null;
      _resumedWithoutGrant = false;
      _linkRenewed = false;
      _challengeExpiresAt = null;
    });
    unawaited(_loadAccountData());
  }

  /// Whether an enabled [_backToMenu] is on screen. A sub-mode's Back walks
  /// back one level, which is the whole way out of that sub-mode — but it
  /// stands down while a request is in flight, and a disabled button is not
  /// a way out.
  bool get _backIsUsable => _mode != _Mode.menu && !_busy;

  /// Whether the footer carries a way out of the pane itself, beside the
  /// [_backToMenu] button. One rule, both hosts: **only where the Back beside
  /// it cannot act.**
  ///
  /// A sub-mode that can go Back needs nothing else. Cancel there would be a
  /// second dismiss next to a first — and in a Modal Pane a third, next to
  /// the header's close icon. The menu has no Back, so it carries the way
  /// out itself: Done in a dialog, where a quick switch has already taken
  /// effect and there is nothing to abandon (user-interface.md §Dialogs), and
  /// Back in the onboarding step, which walks back to the callsign question.
  ///
  /// The exception is the onboarding step with a request in flight, where
  /// Back is disabled and the step has no chrome of its own: without this the
  /// footer would offer nothing that works. A Modal Pane needs no such
  /// exception — its header icon and Escape dismiss from every state, the
  /// [PopScope] below turning a live poll into an abandon rather than a
  /// refusal.
  bool get _showCancel => _mode == _Mode.menu || (!_backIsUsable && !widget.hostHasCloseIcon);

  /// Rendered whenever there is a menu to go back to — except in the
  /// onboarding step, where a disabled Back beside an exit that also says
  /// "Back" is the two-buttons-one-word problem this footer exists to avoid.
  bool get _showBackToMenu => _mode != _Mode.menu && (widget.hostHasCloseIcon || !_busy);

  /// The host's own word for it wins — onboarding's exit walks back a step,
  /// so it says Back. Otherwise the verb follows what leaving would discard:
  /// Cancel abandons the challenge a sub-mode has in flight, while the menu
  /// has nothing outstanding to abandon.
  String get _cancelLabel => widget.cancelLabel ?? (_mode == _Mode.menu ? t.common.done : t.common.cancel);

  bool get _showPrimaryAction => _mode == _Mode.email;

  bool get _hasFooter => _showBackToMenu || _showCancel || _showPrimaryAction;

  @override
  Widget build(BuildContext context) {
    // The Modal Pane route provides the chrome (title, scrolling, width);
    // the action row lives here because it depends on this State (_mode,
    // _busy).
    return PopScope(
      // A request in flight is intercepted, not refused. Escape, the header
      // close icon and the system back gesture all route through
      // `Navigator.maybePop()`, which this gates: a deliberate dismissal gets
      // to abandon the request, but it goes through [_doCancel] so the poll
      // stops and the caller is told the account did not change, rather than
      // the route vanishing out from under a running timer.
      //
      // Both flags, not just the poll: a challenge is requested BEFORE it is
      // polled for, and a guard watching only the poll leaves that gap open —
      // a dismissal there slips past uninterrupted, handing the caller a null
      // where it needs "not switched".
      //
      // This is the Modal Pane's story alone. An onboarding step mounts above
      // the Navigator (main.dart wraps it in its own Overlay), so there is no
      // ModalRoute to register against and nothing here runs at all: that host
      // has no Escape and no icon, and its footer is the whole control surface.
      //
      // A tap OUTSIDE stays inert throughout, and is not this flag's doing —
      // the pane opens with `barrierDismissible: false`, which nulls the
      // barrier's own tap handler (modal_pane.dart's `_tapOutsideDismissible`).
      // Losing a challenge to a stray tap means a trip back to the other
      // device for a fresh code; losing it to Escape is something the
      // operator asked for.
      canPop: _pollTimer == null && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _doCancel();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContent(context),
          // The gap belongs to the footer, not the content: a state with no
          // footer button at all (the Modal Pane's menu) would otherwise end
          // in Space.xxl of blank pane below its last row.
          if (_hasFooter) const SizedBox(height: Space.xxl),
          // The shared footer rather than a hand-rolled OverflowBar: an
          // end-aligned bar of its own puts Cancel wherever it happens to fall
          // in the child list — here, last, i.e. exactly where every other
          // dialog in the app puts its confirm action.
          haloDialogFooterRow(
            secondary: _showBackToMenu ? TextButton(onPressed: _busy ? null : _backToMenu, child: Text(context.t.onboarding.back)) : null,
            cancel: _showCancel ? TextButton(onPressed: _doCancel, child: Text(_cancelLabel)) : null,
            actions: [if (_showPrimaryAction) FilledButton(onPressed: _busy ? null : _submitEmail, child: Text(context.t.switchAccounts.linkAccount))],
          ),
        ],
      ),
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
      case _Mode.sibling:
        return _buildSibling(context);
    }
  }

  Widget _buildMenu(BuildContext context) {
    final theme = Theme.of(context);
    final current = (_accountData?['current_account'] as Map?)?.cast<String, dynamic>();
    final currentCounts = syncAccountCounts(_accountData);
    final others = _otherAccounts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.hideAccountsList) ...[
          if (_loadingAccountData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Space.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Text(context.t.switchAccounts.currentAccount, style: theme.textTheme.titleSmall),
            _accountTile(
              account: current ?? const {},
              icon: MdiIcons.accountCheck,
              // The current account's counts come from the getAccountData
              // response's top-level counts, not per-account stats.
              qsoCount: currentCounts.qsos,
              operationCount: currentCounts.operations,
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: Space.lg),
              Text(context.t.switchAccounts.otherAccounts, style: theme.textTheme.titleSmall),
              ...others.map((account) {
                final stats = (account['stats'] as Map?)?.cast<String, dynamic>();
                // Quick switch links by the confirmed email — the only
                // address the server resolves — so an email-less account
                // has nothing to switch to and must not look tappable.
                final email = account['email'] as String?;
                final canSwitch = email != null && email.isNotEmpty;
                return _accountTile(
                  account: account,
                  icon: MdiIcons.account,
                  includePending: false,
                  qsoCount: (stats?['qso_count'] as num?)?.toInt(),
                  operationCount: (stats?['operation_count'] as num?)?.toInt(),
                  onTap: _busy || !canSwitch ? null : () => _quickSwitch(account),
                );
              }),
            ],
          ],
          const SizedBox(height: Space.lg),
          Text(context.t.switchAccounts.linkToAnother, style: theme.textTheme.titleSmall),
        ],
        if (widget.openSibling != null)
          for (final sibling in widget.siblings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(MdiIcons.cellphoneLink),
              // PoLo is "the older version" — it is the app most operators
              // are coming from; another HaLo edition is just "other". Two
              // PoLo flavors side by side would read identically, so then
              // each is named.
              title: Text(switch (sibling) {
                SiblingApp(edition: null) when onlyPolo(widget.siblings) => context.t.switchAccounts.linkWithPolo,
                SiblingApp(edition: null) => context.t.onboarding.linkWithApp(app: sibling.name),
                _ => context.t.switchAccounts.linkWithSibling,
              }),
              subtitle: Text(context.t.switchAccounts.linkWithSiblingDescription),
              enabled: !_busy,
              onTap: () => _showSibling(sibling),
              mouseCursor: SystemMouseCursors.click,
            ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(MdiIcons.qrcode),
          title: Text(context.t.switchAccounts.linkWithQr),
          subtitle: Text(context.t.switchAccounts.linkWithQrDescription),
          enabled: !_busy,
          onTap: _showQr,
          mouseCursor: SystemMouseCursors.click,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(MdiIcons.email),
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
        const SizedBox(height: Space.lg),
        TextField(
          selectAllOnFocus: false,
          controller: _emailController,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          decoration: poloFieldDecoration(context, context.t.switchAccounts.emailAddress),
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
    ScaffoldMessenger.of(context).showSnackBar(haloSnackBar(context.t.switchAccounts.copiedCode));
  }

  Widget _buildCode(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.switchAccounts.codePrompt(email: '$_pendingEmail')),
        const SizedBox(height: Space.xl),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_challengeCode ?? '—', style: theme.textTheme.displayMedium?.copyWith(fontFamily: 'RobotoMono', letterSpacing: 4)),
              if (_challengeCode != null) ...[
                const SizedBox(width: Space.md),
                IconButton(
                  icon: Icon(MdiIcons.contentCopy, semanticLabel: context.t.switchAccounts.copyCode),
                  onPressed: () => _copyChallengeCode(context),
                  mouseCursor: SystemMouseCursors.click,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        Center(child: Text(context.t.switchAccounts.waitingForConfirmation)),
        const SizedBox(height: Space.lg),
        Center(
          child: OutlinedButton(onPressed: _busy ? null : _sendConfirmationEmail, child: Text(context.t.switchAccounts.sendEmailInstead)),
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
        const SizedBox(height: Space.xl),
        Center(child: Text(context.t.switchAccounts.waitingForConfirmation)),
        const SizedBox(height: Space.lg),
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
        Text(context.t.switchAccounts.qrPrompt),
        const SizedBox(height: Space.xl),
        // The spinner belongs to the request, not to the absence of a code:
        // gated on _qrUrl alone it spins forever after a failed one, saying
        // "loading" over an error message that says the opposite.
        if (url != null || _busy)
          Center(
            child: url == null
                ? const Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())
                // White quiet zone regardless of theme so cameras can read it.
                : Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(Space.lg),
                    // Keyed by payload so a regenerated challenge (expiry)
                    // replaces, not just repaints, the QR widget.
                    child: QrImageView(key: ValueKey(url), data: url, size: 200),
                  ),
          ),
        if (url != null) ...[const SizedBox(height: Space.xl), Center(child: Text(context.t.switchAccounts.waitingForConfirmation))],
        ..._errorAndBusy(context),
      ],
    );
  }

  Widget _buildSibling(BuildContext context) {
    final sibling = _sibling;
    final name = sibling?.name ?? '';
    // No link means the request (or the baseline fetch before it) failed:
    // the button then starts the whole request over, since re-opening the
    // sibling with nothing to hand it would only say "waiting" again.
    final hasLink = _qrUrl != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.switchAccounts.siblingPrompt(app: name)),
        if (hasLink) ...[const SizedBox(height: Space.xl), Center(child: Text(context.t.switchAccounts.waitingForConfirmation))],
        if (_linkRenewed) ...[const SizedBox(height: Space.lg), Text(context.t.switchAccounts.siblingLinkRenewed(app: name), textAlign: TextAlign.center)],
        const SizedBox(height: Space.lg),
        Center(
          child: OutlinedButton(
            onPressed: _busy || sibling == null
                ? null
                : hasLink
                ? _openSibling
                : () => _startWithSibling(sibling),
            child: Text(hasLink ? context.t.switchAccounts.openSiblingAgain(app: name) : context.t.switchAccounts.tryAgain),
          ),
        ),
        if (_resumedWithoutGrant) ...[
          const SizedBox(height: Space.xl),
          Text(context.t.switchAccounts.siblingNoGrant, textAlign: TextAlign.center),
          if (widget.onFallback != null && widget.fallbackLabel != null) ...[
            const SizedBox(height: Space.md),
            Center(
              child: OutlinedButton(onPressed: _fallback, child: Text(widget.fallbackLabel!)),
            ),
          ],
        ],
        ..._errorAndBusy(context),
      ],
    );
  }

  /// The host's own way out — same exit discipline as [_doCancel], since it
  /// leaves a live poll behind otherwise.
  void _fallback() {
    if (_closing) return;
    _closing = true;
    _stopPolling();
    widget.onFallback?.call();
  }

  List<Widget> _errorAndBusy(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (_error != null) ...[const SizedBox(height: Space.lg), Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))],
      if (_busy) ...[const SizedBox(height: Space.lg), const Center(child: CircularProgressIndicator())],
    ];
  }
}
