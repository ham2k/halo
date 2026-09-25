// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The `syncTransport` hook calls: LoFi account, device and link-request
// traffic, the webhook poll, and the in-app report.

part of 'extension_service.dart';

/// This device's LoFi identity: the Pusher channel to subscribe
/// to, and the signed token a webhook-relayed OAuth login embeds in its
/// `state` param. Returned by [ExtensionService.ensureLofiClientRegistered]
/// and [HaLoServices.connectLofiRealtime] alike.
typedef LofiClientRegistration = ({String pushChannelName, String webhookClientToken});

mixin _ExtensionSyncCalls {
  // Owned by the class or by another part of this library.
  ExtensionHost? get host;
  SettingsService? get settings;

  /// The current LoFi account/device/client info, for display in Settings.
  /// Returns null if the runtime isn't up or the request failed (e.g. no
  /// network) — callers should treat that as "status unknown", not "no sync".
  ///
  /// Every fresh fetch also persists the snapshot into
  /// `settings.syncState['accountData']` — the static copy the declarative
  /// sync settings group displays, so building a settings schema never
  /// needs a network round-trip. Only this method (called from the Sync
  /// panel's refreshes and post-link flows) updates it.
  Future<Map<String, dynamic>?> syncAccountData() async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.syncTransportGetAccountData, args: const {});
      final data = result is Map ? result.cast<String, dynamic>() : null;
      final currentSettings = settings;
      if (data != null && currentSettings != null) {
        final state = currentSettings.syncState;
        // Only write (and notify) on a real change — the Sync panel
        // refreshes on every open.
        if (jsonEncode(state['accountData']) != jsonEncode(data)) {
          await currentSettings.setSyncState({...state, 'accountData': data});
        }
      }
      return data;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncAccountData failed: $e');
      return null;
    }
  }

  /// Requests a link permission from the sync server: a pending challenge
  /// for [email] (or an immediate switch when this client already has a
  /// permission on that account), or — with null — a blank permission for
  /// QR-code linking. Server rejections (e.g. no account with that email)
  /// come back as `{'error': ..., 'error_status': ...}` in the map; null
  /// means the server couldn't be reached at all.
  Future<Map<String, dynamic>?> syncLinkClient(String? email) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.syncTransportLinkClient, args: {'email': ?email});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClient failed: $e');
      return null;
    }
  }

  /// Requests a link-by-email challenge from the sync server. Returns null
  /// on failure; callers should surface that as "couldn't reach the server".
  Future<Map<String, dynamic>?> syncLinkClientWithEmail(String email) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.syncTransportLinkClientWithEmail, args: {'email': email});
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] syncLinkClientWithEmail failed: $e');
      return null;
    }
  }

  /// Sets the sync account's email address — a change, or the first claim
  /// on an anonymous account. The server records it as `pending_email` and
  /// mails a confirmation link; only following that link makes it the
  /// account's real address. [syncResendAccountEmail] mails it again.
  ///
  /// Both return `{'error': ..., 'error_status': ...}` for a rejection the
  /// operator can act on (the address is taken, nothing is pending), and
  /// null when the server couldn't be reached at all.
  Future<Map<String, dynamic>?> syncSetAccountEmail(String email) => _syncTransportCall(Hooks.syncTransportSetAccountEmail, {'email': email});

  Future<Map<String, dynamic>?> syncResendAccountEmail() => _syncTransportCall(Hooks.syncTransportResendAccountEmail, const {});

  /// Finds the pending link request a challenge code refers to — the
  /// confirming side of the flow [syncLinkClient] starts on the other
  /// device. Returns the server's `{'permissions': [...]}`; an expired or
  /// mistyped code simply yields an empty list.
  Future<Map<String, dynamic>?> syncFindLinkRequest(String challengeToken) =>
      _syncTransportCall(Hooks.syncTransportFindLinkRequest, {'challenge_token': challengeToken});

  /// The same lookup for a request that arrived as a `link_client` deep
  /// link, which names the requesting device outright. Returns the server's
  /// `{'permission': ...}`, whose value is null when the link has expired.
  Future<Map<String, dynamic>?> syncFindLinkRequestByClient({required String clientUuid, required String challengeToken}) =>
      _syncTransportCall(Hooks.syncTransportFindLinkRequestByClient, {'client': clientUuid, 'challenge_token': challengeToken});

  /// Grants a link request: the other device joins this account.
  /// [challengeToken] is what binds an orphaned (QR/deep-link) permission to
  /// this account, so it must be passed back for those; a request raised by
  /// email is already attached and ignores it.
  Future<Map<String, dynamic>?> syncApproveLinkRequest({required String clientUuid, String? challengeToken}) =>
      _syncTransportCall(Hooks.syncTransportApproveLinkRequest, {'client': clientUuid, 'challenge_token': ?challengeToken});

  /// Shared shape of the account/linking calls above: null when the runtime
  /// isn't up or the host call failed, the server's map otherwise —
  /// including the `error`/`error_status` maps those endpoints return for
  /// rejections that belong to the UI flow rather than to error reporting.
  Future<Map<String, dynamic>?> _syncTransportCall(HookRef hook, Map<String, dynamic> args) async {
    final host = this.host;
    if (host == null) return null;
    final streakKey = '${hook.category}:${hook.method}';
    try {
      final result = await host.invoke(hook, args: args);
      ErrorReportingService.recordSuccess(streakKey);
      return result is Map ? result.cast<String, dynamic>() : null;
    } on ExtensionHostException catch (e, stackTrace) {
      // Every one of these is an operator waiting on a button they just
      // pressed. One failure is the network; the same one failing every
      // time is a defect whose only other trace would be somebody writing
      // in to say nothing happened. Keyed per method so a broken
      // approveLinkRequest isn't hidden by a healthy getAccountData.
      debugPrint('[extensions] ${hook.method} failed: $e');
      ErrorReportingService.reportIfRepeated(streakKey, e, stackTrace, context: streakKey);
      return null;
    }
  }

  /// Ensures this device is registered with the sync server — independent
  /// of whether the operator has QSO sync enabled; registration
  /// establishes device identity and the realtime push channel, it never
  /// pushes log data. Returns null if the runtime isn't up or registration
  /// failed (e.g. no network) — callers should treat that as "not
  /// available yet", not as "sync is off".
  ///
  /// [refreshWebhookToken] makes this fetch a CURRENT webhook token instead of
  /// returning the cached one, at the cost of a round trip. Required of any
  /// caller putting that token in an OAuth `state`: it is a one-hour signed
  /// message, so a device registered longer ago than that carries one the
  /// relay refuses. Off by default because `pushChannelName` — what boot and
  /// operator-callsign changes come here for — never expires, and they must
  /// keep working offline.
  Future<LofiClientRegistration?> ensureLofiClientRegistered({bool refreshWebhookToken = false}) async {
    final host = this.host;
    if (host == null) return null;
    try {
      final result = await host.invoke(Hooks.syncTransportEnsureClientRegistered, args: {'refreshWebhookToken': refreshWebhookToken});
      if (result is! Map) return null;
      final map = result.cast<String, dynamic>();
      final pushChannelName = map['push_channel_name'] as String?;
      final webhookClientToken = map['webhook_client_token'] as String?;
      if (pushChannelName == null || webhookClientToken == null) return null;
      return (pushChannelName: pushChannelName, webhookClientToken: webhookClientToken);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] ensureLofiClientRegistered failed: $e');
      return null;
    }
  }

  /// Fetches this device's pending webhook events — the poll
  /// fallback, and how a caller retrieves the actual payload after a
  /// [HaLoServices.webhookEvents] Pusher ping (which intentionally carries
  /// only an id, never the sensitive payload).
  Future<List<Map<String, dynamic>>> fetchLofiWebhookEvents() async {
    final host = this.host;
    if (host == null) return const [];
    try {
      final result = await host.invoke(Hooks.syncTransportFetchWebhookEvents, args: const {});
      final events = result is Map ? result['webhook_events'] : null;
      if (events is! List) return const [];
      return events.whereType<Map<dynamic, dynamic>>().map((e) => e.cast<String, dynamic>()).toList();
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] fetchLofiWebhookEvents failed: $e');
      return const [];
    }
  }

  /// Files a report the app composed itself — the equipment editor's radio
  /// report — as a real CaBo card, through whichever sync transport is
  /// registered. [kind] must be one of `idea`/`task`/`bug`; anything else is
  /// silently downgraded to `bug` server-side.
  ///
  /// Returns the card's ref on success (null when the server filed it but
  /// named no ref), or the failure as operator-facing text — including the
  /// refusal when no account is configured, which the transport owns so both
  /// this and the REPORT command refuse in the same words.
  ///
  /// A transport that predates `submitReport` (or no transport at all) is
  /// reported as an error rather than as a silent no-op: the operator has just
  /// written a report and pressed Send.
  Future<({String? ref, String? error})> submitReport({required String title, required String body, required String kind}) async {
    final host = this.host;
    if (host == null) {
      debugPrint('[extensions] submitReport: no runtime');
      return (ref: null, error: t.extensionService.reportUnavailable);
    }
    try {
      final result = await host.invoke(
        Hooks.syncTransportSubmitReport,
        args: {'title': title, 'body': body, 'kind': kind},
        // The same room `interpretCommand` gives an executing command: this is
        // two round trips (device registration, then the report itself)
        // against a server that may be reached over a slow link.
        timeout: const Duration(seconds: 30),
      );
      if (result is! Map) {
        // A transport with no `submitReport` lands exactly here: the kernel's
        // callHookMethod returns a missing member as-is, so the hook resolves
        // ok with null rather than throwing. The operator's message cannot say
        // that, so the console has to — otherwise a hook renamed in a refactor
        // is an app that quietly stops accepting reports, in the field,
        // forever, with nothing anywhere to say why.
        debugPrint('[extensions] submitReport: transport answered ${result.runtimeType}, not a Map');
        return (ref: null, error: t.extensionService.reportUnavailable);
      }
      final error = result['error'];
      if (error is String && error.isNotEmpty) return (ref: null, error: error);
      final ref = result['ref'];
      return (ref: ref is String && ref.isNotEmpty ? ref : null, error: null);
    } on ExtensionHostException catch (e) {
      debugPrint('[extensions] submitReport failed: $e');
      return (ref: null, error: t.extensionService.reportUnavailable);
    }
  }
}
