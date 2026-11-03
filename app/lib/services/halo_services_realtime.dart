// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// LoFi's realtime pushes (ham2k-push, via PushService): building the client,
// keeping it connected across network changes and app resumes, and the
// subscriptions — this device's own channel, and the synced account's, whose
// `operation` events bring the sync loop's next pull forward.

part of 'halo_services.dart';

mixin _Realtime {
  PushService? get push;
  ExtensionService get extensions;
  SyncEngine get syncEngine;

  PushService? _pushFromConfig() {
    if (!kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST')) return null;
    final host = secrets['HAM2K_PUSH_HOST'];
    final key = secrets['HAM2K_PUSH_KEY'];
    final service = PushService(
      host: (host?.isNotEmpty ?? false) ? host! : PushService.defaultHost,
      appKey: (key?.isNotEmpty ?? false) ? key! : PushService.defaultAppKey,
    );
    // Nothing closes a socket the network took with it: a dead connection is
    // only found by its missing pong, and a dropped one waits out its
    // backoff. Both are worth cutting short at the two moments a connection
    // is most likely to have died, or to be possible again.
    ConnectivityService.offlineChanges.listen((offline) {
      if (!offline) service.reconnectNow();
    });
    _pushLifecycle ??= AppLifecycleListener(onResume: service.checkConnection);
    return service;
  }

  /// One per services instance: a second [_pushFromConfig] must not stack
  /// another resume check on top of this one.
  AppLifecycleListener? _pushLifecycle;

  /// Registers this device with the sync server — independent of QSO sync
  /// being enabled, deliberately — and, once that succeeds,
  /// subscribes the realtime client to its push channel. Safe to call
  /// repeatedly (boot, and every [setOperatorCall]):
  /// `ensureLofiClientRegistered` is idempotent, and re-subscribing an
  /// already-subscribed channel is a no-op ([PushService.subscribe]).
  ///
  /// Returns the registration so a caller that also needs it directly (e.g.
  /// `_doOAuth`, for the `webhookClientToken` its `state` param carries) can
  /// go through this one place rather than re-registering by hand.
  Future<LofiClientRegistration?> connectLofiRealtime({bool refreshWebhookToken = false}) async {
    final registration = await extensions.ensureLofiClientRegistered(refreshWebhookToken: refreshWebhookToken);
    if (registration != null) push?.subscribe(registration.pushChannelName);
    return registration;
  }

  /// Webhook-relay events on this device's push channel — an
  /// OAuth flow waiting on a provider redirect listens here for
  /// the ping, then calls [ExtensionService.fetchLofiWebhookEvents] for the
  /// payload (the push itself only ever carries an event id, never the
  /// sensitive payload — deliberately).
  Stream<PushEvent> get webhookEvents => push?.events.where((e) => e.event == 'webhook_event') ?? const Stream.empty();

  /// The synced account's push channel, while sync is on and the server has
  /// named one. Owned here rather than by any one screen, because the sync
  /// loop and the Sync settings panel both listen on it and a subscription
  /// is not counted: a screen unsubscribing on close would silence the loop.
  String? get accountPushChannel => _accountPushChannel.value;

  /// [accountPushChannel] as it changes. A sync round can clear it behind an
  /// open screen's back (an operation-scoped grant names no channel), and a
  /// screen pacing itself on pushes must then fall back to its poll.
  ValueListenable<String?> get accountPushChannelChanges => _accountPushChannel;
  final _accountPushChannel = ValueNotifier<String?>(null);
  StreamSubscription<PushEvent>? _accountPushEvents;

  /// Points the account subscription at [channel] — what every sync response
  /// and every account fetch reports (`account.push_channel`). Null clears it.
  void setAccountPushChannel(String? channel) {
    final previous = _accountPushChannel.value;
    if (channel == previous) return;
    if (previous != null) push?.unsubscribe(previous);
    if (channel != null) {
      push?.subscribe(channel);
      _accountPushEvents ??= push?.events.listen(_onAccountPushEvent);
    }
    _accountPushChannel.value = channel;
  }

  /// Another device changed an operation in this account — including adding
  /// contacts to one, which restamps its count and dates (api-lofi's
  /// `Operation#update_cached_info`). The payload is not applied; it brings
  /// the next pull forward, and the pull stays the one way data arrives.
  void _onAccountPushEvent(PushEvent event) {
    if (event.channel != _accountPushChannel.value || event.event != 'operation') return;
    // Read leniently: a cast that throws here escapes the stream to the zone,
    // and ErrorPolicy would report every such push as an unknown fault.
    final uuid = event.data['uuid'];
    syncEngine.notifyRemoteChanged(operationUuid: uuid is String ? uuid : null);
  }
}
