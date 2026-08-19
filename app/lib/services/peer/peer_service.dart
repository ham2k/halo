// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ties peer sync together (HALO-310): announces this device, watches for
// others, opens a link to each, and owns one `PeerSession` per peer.
//
// Per-peer state lives in a map keyed by the peer's device id, never in a
// field — the lesson docs/design/cat.md draws from app-polo's singleton
// connection state, which is what made a second device impossible there.
//
// SCOPE. Only while an operation is actively shared ([activeOperationUuid])
// does anything bind, announce, or connect. Turning sharing off tears the
// whole lot down, so an operator who never uses this pays nothing but a null
// check, and no socket is open that the operator did not ask for.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../../tools/backoff.dart';
import '../error_reporting_service.dart';
import 'peer_beacon.dart';
import 'peer_beacon_types.dart';
import 'peer_link.dart';

/// How often this device says it is here. Frequent enough that opening the
/// app on a second device feels immediate, cheap enough to ignore: one small
/// datagram, and only while sharing is on.
const _announceInterval = Duration(seconds: 3);

/// A peer not heard from in this long is treated as gone. Several beacons'
/// worth, so one dropped datagram never drops a peer off the list.
const _beaconTimeout = Duration(seconds: 15);

const _reconnectCap = Duration(seconds: 30);

/// One discovered peer and whatever session it currently has.
class PeerRuntime {
  PeerRuntime(this.beacon) : lastSeenMillis = realNowMillis();

  PeerBeacon beacon;
  PeerSession? session;

  /// Bumped on every connect attempt and teardown, re-checked after every
  /// await — the CAT `attemptSeq` guard, for the same reason: a dial that
  /// completes after this peer was torn down (or superseded by a newer
  /// beacon) must not install its session over the newer state.
  int attemptSeq = 0;

  int failures = 0;
  Timer? retryTimer;

  /// When a beacon from this peer last arrived — what [_sweepStalePeers]
  /// reads to forget a device that walked out of range.
  ///
  /// The REAL clock, deliberately (docs/design/time.md §1): this is a
  /// protocol timeout, and a developer time-travelling the app must not make
  /// every peer on the network drop off the list or linger forever.
  int lastSeenMillis;

  /// Set once the operator has been asked about this peer, so a peer that is
  /// declined (or simply left unanswered) is not re-prompted on every beacon.
  bool promptDismissed = false;

  bool get isConnected => session != null && session!.state != PeerSessionState.closed;
}

class PeerService extends ChangeNotifier {
  PeerService({
    required this.db,
    required this.outbox,
    required this.operations,
    required this.qsos,
    required this.localDeviceId,
    required this.localDeviceName,
    this.beaconPort = peerBeaconPort,
  })  : cursors = PeerCursorStore(db),
        trust = PeerTrustStore(db) {
    // The ONLY thing that turns a local write into a live push. Without it
    // the outbox fills correctly and no peer is ever told, so a QSO logged
    // while both sides are connected does not cross until the link drops
    // and the reconnect's catch-up happens to pick it up.
    outbox.onScanned = () => unawaited(_pushToPeers());
    outbox.log = (message) => debugPrint('[peer] $message');
  }

  final HaLoDatabase db;
  final PeerOutbox outbox;
  final OperationsRepository operations;
  final QsosRepository qsos;
  final PeerCursorStore cursors;
  final PeerTrustStore trust;
  final String localDeviceId;

  /// Mutable: the operator can rename this device in the Peers panel, and a
  /// `final` here left every peer seeing the old name (in beacons and in
  /// their pairing prompt) until the app restarted. It is also derived from
  /// the operator callsign, which is empty on a device constructed before
  /// onboarding finishes.
  String localDeviceName;
  final int beaconPort;

  final Map<String, PeerRuntime> _peers = {};

  /// Sessions on inbound links whose peer has not identified itself yet.
  /// They belong to no [PeerRuntime] until `hello` arrives, so nothing else
  /// holds them — see [_stop].
  final Set<PeerSession> _unidentifiedSessions = {};
  Map<String, PeerRuntime> get peers => Map.unmodifiable(_peers);

  String? _activeOperationUuid;
  String? get activeOperationUuid => _activeOperationUuid;

  PeerBeaconSocket? _beaconSocket;
  PeerLinkServer? _linkServer;
  StreamSubscription<PeerBeacon>? _beaconSubscription;
  StreamSubscription<PeerLink>? _linkSubscription;
  Timer? _announceTimer;
  Timer? _sweepTimer;

  /// Why peer sync isn't working, if it isn't.
  ///
  /// A separate field rather than only a crash report, for the reason
  /// `InboundQsoListenerService` learned: `ErrorReportingService.report` never
  /// puts anything on screen, so without this a refused bind looks exactly
  /// like "no other devices here" — and the operator has no way to tell a
  /// broken feature from an empty room.
  String? error;

  /// Whichever peer is waiting on the operator, if any. The UI prompts for
  /// this one and re-reads after answering.
  PeerRuntime? get pendingPairing {
    for (final runtime in _peers.values) {
      final session = runtime.session;
      if (session != null && session.state == PeerSessionState.needsPairing && !runtime.promptDismissed) {
        return runtime;
      }
    }
    return null;
  }

  bool _enabled = true;
  String? _openOperationUuid;

  /// The master switch (`SettingsService.peerSyncEnabled`). Off tears
  /// everything down: no socket bound, no beacon sent, this device invisible.
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    await _apply();
  }

  /// Which operation the operator currently has open, or null for none.
  ///
  /// Sharing is deliberately NOT a per-operation decision: the master switch
  /// is the whole consent, and whichever operation is open follows it. That
  /// is what makes the field case work — open the app on a second device and
  /// it joins, with nothing to remember to switch on per activation.
  Future<void> setOpenOperation(String? operationUuid) async {
    if (_openOperationUuid == operationUuid) return;
    _openOperationUuid = operationUuid;
    await _apply();
  }

  /// Serializes [_apply]. `updatePeerSharing` fires setEnabled and
  /// setOpenOperation back to back without awaiting either, and _apply has
  /// awaits (a teardown, a scan, two socket binds) between reading
  /// `_activeOperationUuid` and assigning it — so two overlapping calls can
  /// both pass the early-return, both reach `_start`, bind a second pair of
  /// sockets over the first, and settle on whichever finishes last rather
  /// than on the latest intent.
  Future<void> _applyTail = Future.value();

  /// Recomputes what should be shared and moves to it. Both inputs land here
  /// so there is one place that decides, rather than two setters each
  /// half-knowing the rule.
  Future<void> _apply() {
    final next = _applyTail.then((_) => _applyNow());
    _applyTail = next.catchError((Object _) {});
    return next;
  }

  Future<void> _applyNow() async {
    final wanted = _enabled ? _openOperationUuid : null;
    if (_activeOperationUuid == wanted) return;
    await _stop();
    _activeOperationUuid = wanted;
    outbox.activeOperationUuid = wanted;
    if (wanted != null) {
      // Capture what the operation ALREADY holds before anyone can connect.
      // The outbox only records what a scan finds, and setting the active
      // operation resets its watermark — so without this first scan an
      // operation with an existing log has nothing for a peer to catch up
      // on, and only QSOs logged from here on would ever cross.
      await outbox.scanNow();
      await _start();
    }
    notifyListeners();
  }

  /// The local outbox grew — push to every live session. Wired to the same
  /// `onChange` fan-out `PeerOutbox.notifyChanged` already sits on, so the
  /// scan and the push happen off one signal.
  Future<void> pushLocal() async {
    await outbox.scanNow();
    await _pushToPeers();
  }

  /// Snapshotted before iterating: a beacon or a session identifying itself
  /// can insert into [_peers] from a stream event while this is awaiting a
  /// send, which would otherwise throw ConcurrentModificationError.
  Future<void> _pushToPeers() async {
    for (final runtime in _peers.values.toList()) {
      await runtime.session?.pushLocal();
    }
  }

  Future<void> acceptPairing(String peerDeviceId) async {
    final runtime = _peers[peerDeviceId];
    if (runtime?.session == null) return;
    runtime!.promptDismissed = false;
    await runtime.session!.acceptPairing();
    notifyListeners();
  }

  /// Offers a previously-declined (or forgotten) device again.
  ///
  /// [PeerRuntime.promptDismissed] stops a refused device re-asking on every
  /// beacon, but it must not be permanent: without a way to clear it, an
  /// operator who taps Forget can never pair that device again short of
  /// restarting the app, because `pendingPairing` skips it and the panel's
  /// Allow button reads `pendingPairing`.
  void offerPairingAgain(String peerDeviceId) {
    final runtime = _peers[peerDeviceId];
    if (runtime == null || !runtime.promptDismissed) return;
    runtime.promptDismissed = false;
    // A refused session is terminal, so a fresh one has to be dialled or
    // accepted before anything can be allowed.
    if (runtime.session == null) unawaited(_maybeDial(runtime));
    notifyListeners();
  }

  Future<void> rejectPairing(String peerDeviceId) async {
    final runtime = _peers[peerDeviceId];
    if (runtime == null) return;
    runtime.promptDismissed = true;
    await runtime.session?.rejectPairing();
    notifyListeners();
  }

  /// Withdraws trust and drops the peer's live session — a peer that stays
  /// connected after being un-trusted would keep syncing until it happened
  /// to disconnect.
  Future<void> revokeTrust(String peerDeviceId) async {
    await trust.revoke(peerDeviceId);
    final runtime = _peers[peerDeviceId];
    if (runtime != null) {
      runtime.attemptSeq++;
      runtime.retryTimer?.cancel();
      await runtime.session?.close();
      runtime.session = null;
      runtime.promptDismissed = true;
    }
    notifyListeners();
  }

  Future<void> _start() async {
    error = null;
    try {
      _linkServer = await PeerLinkServer.bind();
    } catch (e, st) {
      // A device that cannot listen can still dial out, so this is degraded
      // rather than fatal — but it must be visible, since a firewall prompt
      // the operator dismissed is otherwise invisible forever.
      error = 'Cannot accept incoming connections: $e';
      debugPrint('[peer] listen bind FAILED: $e');
      ErrorReportingService.report(e, st, context: 'PeerService:bindLinkServer');
    }
    _linkSubscription = _linkServer?.connections.listen(_onInboundLink);

    final socket = await openPeerBeaconSocket(port: beaconPort);
    _beaconSocket = socket;
    _beaconSubscription = socket.beacons.listen(
      _onBeacon,
      onError: (Object e, StackTrace st) {
        error = 'Discovery failed: $e';
        debugPrint('[peer] discovery FAILED: $e');
        ErrorReportingService.report(e, st, context: 'PeerService:beacons');
        notifyListeners();
      },
    );

    // Logged, not silent. This feature's failure mode is "finds nothing",
    // which is indistinguishable from "working, nobody else here" unless the
    // console says what it is doing — see docs/design/error-reporting.md on
    // why ErrorReportingService alone is not enough for an operator or a
    // developer standing in a field.
    debugPrint('[peer] sharing $_activeOperationUuid as "$localDeviceName" ($localDeviceId), '
        'listening on ${_linkServer?.port}, beacons on $beaconPort');
    _announce();
    _announceTimer = Timer.periodic(_announceInterval, (_) => _announce());
    _sweepTimer = Timer.periodic(_beaconTimeout, (_) => _sweepStalePeers());
    notifyListeners();
  }

  Future<void> _stop() async {
    if (_activeOperationUuid != null) debugPrint('[peer] stopped sharing $_activeOperationUuid');
    _announceTimer?.cancel();
    _announceTimer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    await _beaconSubscription?.cancel();
    _beaconSubscription = null;
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    // Snapshotted: a session identifying itself can putIfAbsent into
    // _peers while this awaits a close (see _pushToPeers).
    for (final runtime in _peers.values.toList()) {
      runtime.attemptSeq++;
      runtime.retryTimer?.cancel();
      await runtime.session?.close();
    }
    // Sessions from links that never sent a valid hello are filed under no
    // peer id at all, so the loop above cannot reach them — closing the
    // server does not close an already-upgraded socket, and each would keep
    // a live PeerSession behind it.
    for (final session in _unidentifiedSessions.toList()) {
      await session.close();
    }
    _unidentifiedSessions.clear();
    _peers.clear();
    await _beaconSocket?.close();
    _beaconSocket = null;
    await _linkServer?.close();
    _linkServer = null;
    outbox.activeOperationUuid = null;
    _activeOperationUuid = null;
  }

  void _announce() {
    final operationUuid = _activeOperationUuid;
    final port = _linkServer?.port;
    // Nothing to advertise without somewhere to dial back to. A device whose
    // listen bind failed stays silent rather than announcing a port it isn't
    // on: a peer dialling that would just time out, repeatedly.
    if (operationUuid == null || port == null) return;
    _beaconSocket?.announce(PeerBeacon(
      deviceId: localDeviceId,
      deviceName: localDeviceName,
      operationUuid: operationUuid,
      port: port,
    ));
  }

  void _onBeacon(PeerBeacon beacon) {
    if (beacon.deviceId == localDeviceId) return; // our own, heard back
    if (beacon.operationUuid != _activeOperationUuid) return;
    if (beacon.address == null) return;

    final existing = _peers[beacon.deviceId];
    if (existing == null) {
      debugPrint('[peer] discovered "${beacon.deviceName}" (${beacon.deviceId}) '
          'at ${beacon.address}:${beacon.port}');
      final runtime = PeerRuntime(beacon);
      _peers[beacon.deviceId] = runtime;
      notifyListeners();
      unawaited(_maybeDial(runtime));
      return;
    }
    existing.lastSeenMillis = realNowMillis();
    // A peer that restarted is listening on a NEW ephemeral port, so a stale
    // address/port must not be dialled forever.
    final moved = existing.beacon.port != beacon.port || existing.beacon.address != beacon.address;
    existing.beacon = beacon;
    if (moved && !existing.isConnected) unawaited(_maybeDial(existing));
  }

  /// Who dials, deterministically: the lexicographically lower device id.
  ///
  /// Both sides announce and both listen, so either could dial — and if both
  /// did, each would open a link the other also opened, leaving two
  /// half-sessions per pair to reconcile. Picking a side by comparing ids
  /// costs nothing, needs no negotiation, and removes that race outright.
  /// The cost is a pair where the lower id can dial out but the higher
  /// cannot accept (a one-sided firewall) never connects, where a
  /// both-sides-dial design might have. That is worth revisiting only if it
  /// shows up in the field.
  bool _weDial(String peerDeviceId) => localDeviceId.compareTo(peerDeviceId) < 0;

  Future<void> _maybeDial(PeerRuntime runtime) async {
    if (_activeOperationUuid == null) return;
    if (!_weDial(runtime.beacon.deviceId)) return;
    if (runtime.isConnected) return;
    // A runtime synthesized from an inbound session (rather than a beacon)
    // has no address to dial. Retrying it would fail on `address!` forever,
    // inflating the backoff against a peer we simply have not heard announce
    // yet — the real beacon replaces this and dialling resumes.
    if (runtime.beacon.address == null || runtime.beacon.port == 0) return;
    final attempt = ++runtime.attemptSeq;
    final beacon = runtime.beacon;

    try {
      final link = await dialPeerLink(beacon.address!, beacon.port);
      // Superseded while the dial was in flight — a teardown, a revoke, or a
      // newer beacon. Closing the link we just opened is the only way it
      // gets released.
      if (attempt != runtime.attemptSeq || _activeOperationUuid == null) {
        await link.close();
        return;
      }
      debugPrint('[peer] dialled ${beacon.deviceId} at ${beacon.address}:${beacon.port}');
      _attach(runtime, link);
      runtime.failures = 0;
    } catch (e) {
      if (attempt != runtime.attemptSeq) return;
      runtime.failures++;
      debugPrint('[peer] dial to ${beacon.deviceId} failed (attempt ${runtime.failures}): $e');
      _scheduleRetry(runtime);
    }
  }

  void _scheduleRetry(PeerRuntime runtime) {
    runtime.retryTimer?.cancel();
    // Retries as long as the peer keeps announcing — unlike CAT, which gives
    // up after two tries because a radio that isn't answering usually isn't
    // there. A peer that is still beaconing IS there; it may just be mid-boot
    // or briefly firewalled.
    runtime.retryTimer = Timer(exponentialBackoff(runtime.failures, cap: _reconnectCap), () {
      if (_peers.containsValue(runtime)) unawaited(_maybeDial(runtime));
    });
  }

  void _onInboundLink(PeerLink link) {
    final operationUuid = _activeOperationUuid;
    if (operationUuid == null) {
      unawaited(link.close());
      return;
    }
    // Which peer this is isn't known until its `hello` arrives, so the
    // session is created first and filed under its peer id once it
    // identifies itself.
    debugPrint('[peer] accepted an inbound link');
    _attach(null, link);
  }

  void _attach(PeerRuntime? runtime, PeerLink link) {
    final operationUuid = _activeOperationUuid;
    if (operationUuid == null) {
      unawaited(link.close());
      return;
    }
    final session = PeerSession(
      link: link,
      localDeviceId: localDeviceId,
      localDeviceName: localDeviceName,
      operationUuid: operationUuid,
      outbox: outbox,
      cursors: cursors,
      trust: trust,
      operations: operations,
      qsos: qsos,
      onChanged: _onSessionChanged,
      log: (message) => debugPrint('[peer] $message'),
    );
    if (runtime != null) {
      runtime.session = session;
    } else {
      _unidentifiedSessions.add(session);
    }
    unawaited(session.start());
    notifyListeners();
  }

  void _onSessionChanged(PeerSession session) {
    final peer = session.peer;
    if (peer != null) _unidentifiedSessions.remove(session);
    debugPrint('[peer] ${peer?.deviceId ?? 'unidentified'} → ${session.state.name}'
        '${session.refusedReason == null ? '' : ' (${session.refusedReason})'}');
    if (peer != null) {
      // File an inbound session under its peer once it says who it is. A
      // runtime may not exist yet if this device heard the link before the
      // beacon — the peer is real either way.
      final runtime = _peers.putIfAbsent(
        peer.deviceId,
        () => PeerRuntime(PeerBeacon(
          deviceId: peer.deviceId,
          deviceName: peer.deviceName,
          operationUuid: peer.operationUuid,
          port: 0,
        )),
      );
      if (runtime.session == null) {
        runtime.session = session;
      } else if (!identical(runtime.session, session)) {
        // Both sides opened one after all (a duplicate id, or a peer that
        // ignores the dial rule). Keep the established one and close this,
        // rather than leaving a live link nothing tracks or tears down.
        unawaited(session.close());
        return;
      }
    }

    if (session.state == PeerSessionState.closed || session.state == PeerSessionState.refused) {
      _unidentifiedSessions.remove(session);
      for (final runtime in _peers.values.toList()) {
        if (!identical(runtime.session, session)) continue;
        runtime.session = null;
        // A refusal is a decision, not a fault — retrying it would just
        // re-refuse in a loop. A plain close is worth reconnecting for.
        if (session.state == PeerSessionState.closed && _activeOperationUuid != null) {
          runtime.failures++;
          _scheduleRetry(runtime);
        }
      }
    }
    notifyListeners();
  }

  void _sweepStalePeers() {
    final cutoff = realNowMillis() - _beaconTimeout.inMilliseconds;
    final gone = [
      for (final entry in _peers.entries)
        // A connected peer is kept regardless of its beacons: the link is
        // better evidence it is there than a datagram that may simply have
        // been dropped.
        if (!entry.value.isConnected && entry.value.lastSeenMillis < cutoff) entry.key,
    ];
    if (gone.isEmpty) return;
    for (final deviceId in gone) {
      final runtime = _peers.remove(deviceId);
      runtime?.attemptSeq++;
      runtime?.retryTimer?.cancel();
      unawaited(runtime?.session?.close());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }
}
