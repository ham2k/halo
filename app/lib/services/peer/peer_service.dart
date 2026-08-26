// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Ties peer sync together (HALO-310): announces this device, watches for
// others, opens a link to each, and owns one `PeerSession` per peer. Links
// arrive over LAN, and over BLE when its sub-switch adds that transport
// (HALO-342) — sessions never know which carried them.
//
// Per-peer state lives in a map keyed by the peer's device id, never in a
// field — the lesson docs/design/cat.md draws from app-polo's singleton
// connection state, which is what made a second device impossible there.
//
// SCOPE. Only while the master switch is on does anything bind, announce,
// or connect; turning it off tears the whole lot down, so an operator who
// never uses this pays nothing but a null check, and no socket is open that
// the operator did not ask for. Sessions bind to the paired DEVICE (HALO-334)
// and stay up across operation switches — the open operation only decides
// which log, if any, the durable sync carries ([sharedOperationUuid]).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../../tools/backoff.dart';
import '../error_reporting_service.dart';
import 'ble/peer_ble_gateway.dart';
import 'ble/peer_ble_transport.dart';
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

/// Events per sync batch on a BLE link, against the LAN default of 200.
/// A 200-row batch is one ~220 KB frame — half a minute of head-of-line
/// blocking at BLE rates, with every ephemeral message stuck behind it. At
/// 20 rows a frame is ~25 KB, a couple of seconds worst case.
const _bleBatchLimit = 20;

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
    this.bleGateway,
    this.bleHeadStart = const Duration(seconds: 5),
    this.bleJitter = true,
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

  /// What this device offers peers (`cat` when a radio is designated) —
  /// read fresh at each session's construction, since the answer changes
  /// with the station setup. Advisory only: every consumer still gates on
  /// trust, never on this list.
  List<String> Function()? localCapabilities;

  /// This device's cloud account as an opaque tag, or null when signed in to
  /// none — what decides whether a peer's UNSEEN operation may be taken
  /// (`PeerSession`'s header). Read fresh at each session's construction:
  /// the operator can sign in, out, or switch accounts while peers are up.
  ///
  /// A stand-in, never the account itself: the hello crosses before either
  /// side has decided to trust the other, so anything that can open a socket
  /// here can read it.
  String? Function()? localAccountTag;
  final int beaconPort;

  /// The BLE radio, or null where the platform has none (web, tests that
  /// don't care). Constructing it touches nothing; the radio is only woken
  /// by the reconciler when the sub-switch asks.
  final PeerBleGateway? bleGateway;

  /// Timing knobs for the BLE transport, production defaults. The fake-BLE
  /// tests shrink them: at the real five-second head start, a "never
  /// dialled" assertion passes before the dial timer ever comes due and
  /// proves nothing.
  final Duration bleHeadStart;
  final bool bleJitter;

  /// Whether this platform has a BLE transport at all — what the panel
  /// keys the sub-switch row on, so web never shows a switch that would
  /// silently do nothing.
  bool get bleAvailable => bleGateway != null;

  /// Whether the BLE transport is up. With [bleError] null this is the
  /// panel's positive "the radio is on and looking" signal — without one,
  /// a working radio and a switch that silently did nothing look
  /// identical, and the operator has no way to tell which they have.
  bool get bleRunning => _bleTransport != null;

  final Map<String, PeerRuntime> _peers = {};

  /// Sessions on inbound links whose peer has not identified itself yet.
  /// They belong to no [PeerRuntime] until `hello` arrives, so nothing else
  /// holds them — see [_stop].
  final Set<PeerSession> _unidentifiedSessions = {};
  Map<String, PeerRuntime> get peers => Map.unmodifiable(_peers);

  /// Whether discovery/announcement is up — the applied form of the master
  /// switch, distinct from [_enabled] (the intent) only while [_apply] is in
  /// flight.
  bool _running = false;
  bool get running => _running;

  /// The operation offered to the durable sync, or null when none is open.
  /// Independent of [running]: paired devices stay connected for ephemeral
  /// traffic with nothing shared at all.
  String? get sharedOperationUuid => _openOperationUuid;

  /// Ephemeral traffic from any established session — GPS fixes, CAT status,
  /// tune requests — with the sending peer's claimed device id. Set by the
  /// app layer; per-concern routing lives there, not here, so this service
  /// does not grow a dependency on every feature that rides the channel.
  void Function(String peerDeviceId, PeerMessage message)? onEphemeral;

  /// Fired when a session becomes established — the moment to send that
  /// peer the current latest-value snapshots (position, VFO), which it
  /// missed by not being there when they were last broadcast.
  void Function(PeerSession session)? onSessionEstablished;

  /// Fired when a peer connection is made, and again when an established one
  /// is LOST for a reason the operator did not cause. What the app layer
  /// turns into status messages — a peer link is expected to come and go,
  /// and the operator's answer to "is my other device on?" is the only
  /// thing either edge is for.
  ///
  /// Distinct from [onSessionEstablished], which is the latest-value handoff
  /// and has no losing edge. Operator-caused disconnections — peer sync
  /// switched off, trust revoked, the app quitting — are deliberately
  /// silent: the operator just did that, and being told so is noise.
  void Function(String deviceId, String deviceName, {required bool connected})? onPeerConnectionChanged;

  /// Peers reported connected and not yet reported lost. Doubles as the
  /// suppression: an operator-caused disconnection takes the peer OUT of
  /// here before closing its session, so the close finds nothing to report.
  final Set<String> _announcedConnections = {};

  /// Sends [message] to every established session. Lossy by design: a peer
  /// mid-handshake simply misses it and is caught up by its establish-time
  /// snapshot.
  void broadcastEphemeral(PeerMessage message) {
    for (final runtime in _peers.values.toList()) {
      runtime.session?.sendEphemeral(message);
    }
  }

  /// Sends [message] to one peer, and only over a LAN link.
  ///
  /// The BLE exclusion is the point. [broadcastEphemeral] fans out to every
  /// session, and the BLE conduit chunks at a few hundred bytes behind a
  /// 32 KiB credit window — a stream of anything sizeable there is tens of
  /// seconds of head-of-line blocking with every GPS fix and tune request
  /// stuck behind it. Screen sharing is LAN-only for that reason, and this
  /// is where it is enforced rather than at each call site.
  ///
  /// Returns whether it went anywhere. Lossy like the broadcast: a peer
  /// mid-handshake, on Bluetooth, or gone simply does not receive it.
  bool sendEphemeralTo(String peerDeviceId, PeerMessage message) {
    final session = _peers[peerDeviceId]?.session;
    if (session == null || !session.established) return false;
    if (session.link is PeerBleLink) return false;
    session.sendEphemeral(message);
    return true;
  }

  /// Whether [peerDeviceId] is reachable over the LAN right now — what
  /// decides if a media link to it is even possible.
  bool hasLanSession(String peerDeviceId) {
    final session = _peers[peerDeviceId]?.session;
    return session != null && session.established && session.link is! PeerBleLink;
  }

  /// The port this device is listening on, or null while it is not.
  /// Published in the beacon already; named here for the media link, whose
  /// port a viewer must be TOLD when this device was the one that dialled.
  int? get linkServerPort => _linkServer?.port;

  /// Inbound media links (HALO-369), each with the ticket it presented.
  ///
  /// Its own controller rather than a getter onto [_linkServer]: the server
  /// is rebuilt on every start, and a listener bound to one instance would
  /// go deaf the first time peer sync was switched off and on again.
  Stream<PeerMediaConnection> get mediaConnections => _mediaConnections.stream;

  final _mediaConnections = StreamController<PeerMediaConnection>.broadcast();

  PeerBeaconSocket? _beaconSocket;
  PeerLinkServer? _linkServer;
  StreamSubscription<PeerBeacon>? _beaconSubscription;
  StreamSubscription<PeerLink>? _linkSubscription;
  StreamSubscription<PeerMediaConnection>? _mediaSubscription;
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

  /// Same, for the Bluetooth transport alone — kept apart from [error] so a
  /// denied Bluetooth permission does not read as LAN sync being down, or
  /// the other way around.
  String? bleError;

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
  bool _bleEnabled = false;
  String? _openOperationUuid;
  PeerBleTransport? _bleTransport;

  /// The master switch (`SettingsService.peerSyncEnabled`). Off tears
  /// everything down: no socket bound, no beacon sent, this device invisible.
  ///
  /// No unchanged-value early return here or in [setOpenOperation]: these are
  /// declarative inputs to one idempotent reconciler ([_applyNow]), and
  /// skipping it because THIS input did not change also skips reconciling
  /// the other — which is exactly how a device with the switch on and no
  /// operation open would never start at all.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _apply();
  }

  /// The Bluetooth sub-switch (`SettingsService.peerBleEnabled`), effective
  /// only under the master switch. Its own opt-in, unlike location sharing:
  /// starting BLE pops OS permission prompts LAN never did, and keeps a
  /// radio busy.
  Future<void> setBleEnabled(bool enabled) async {
    _bleEnabled = enabled;
    await _apply();
  }

  /// Which operation the operator currently has open, or null for none.
  ///
  /// Sharing is deliberately NOT a per-operation decision: the master switch
  /// is the whole consent, and whichever operation is open follows it. That
  /// is what makes the field case work — open the app on a second device and
  /// it joins, with nothing to remember to switch on per activation.
  ///
  /// This decides what this device SERVES. What it receives follows the
  /// peer's open operation instead, so an operation created over there
  /// arrives here whether or not anything is open (`PeerSession`'s header).
  Future<void> setOpenOperation(String? operationUuid) async {
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
    // Every production caller fires this unawaited, so this handler is the
    // ONLY place a reconciliation failure can surface. Swallowing it here
    // leaves `_running` claiming a state the sockets are not in, with the
    // panel showing the switch on over a device that is invisible and deaf —
    // the exact "indistinguishable from an empty room" failure [error]
    // exists to prevent.
    _applyTail = next.catchError((Object e, StackTrace st) {
      error = 'Peer sync failed: $e';
      debugPrint('[peer] apply FAILED: $e');
      ErrorReportingService.report(e, st, context: 'PeerService:apply');
      notifyListeners();
    });
    return next;
  }

  Future<void> _applyNow() async {
    final shared = _enabled ? _openOperationUuid : null;
    if (outbox.activeOperationUuid != shared) {
      outbox.activeOperationUuid = shared;
      if (shared != null) {
        // Capture what the operation ALREADY holds before any peer asks.
        // The outbox only records what a scan finds, and setting the active
        // operation resets its watermark — so without this first scan an
        // operation with an existing log has nothing for a peer to catch up
        // on, and only QSOs logged from here on would ever cross.
        try {
          await outbox.scanNow();
        } catch (e, st) {
          // Reset, so the next apply retries the capture instead of seeing
          // "already assigned" and skipping it forever. Left assigned, a
          // peer joining specifically to READ this log would catch up
          // against an empty outbox with every panel reading live — and if
          // nothing is ever logged again, that stays permanent.
          outbox.activeOperationUuid = null;
          error = 'Could not prepare the operation for sharing: $e';
          ErrorReportingService.report(e, st, context: 'PeerService:initialScan');
        }
      }
    }

    if (_enabled != _running) {
      if (_enabled) {
        _running = true;
        await _start();
      } else {
        _running = false;
        await _stop();
      }
    }

    // The BLE transport, reconciled on its own axis: it follows the master
    // switch AND the sub-switch, and either flipping re-lands here. Its
    // failures are caught HERE, not left to the apply tail: that handler
    // writes [error] — the LAN field this one's doc promises to keep apart
    // — and a throw escaping the start would leave [_bleTransport] set to a
    // half-started instance this reconciler (which only constructs when
    // null) would never retry.
    try {
      final wantBle = _enabled && _bleEnabled && bleGateway != null;
      if (wantBle && _bleTransport == null) {
        _bleTransport = PeerBleTransport(
          gateway: bleGateway!,
          localDeviceId: localDeviceId,
          onLink: _onBleLink,
          connectedDeviceIds: () =>
              [for (final entry in _peers.entries) if (entry.value.isConnected) entry.key],
          onStatus: (problem) {
            // A late status from a transport being torn down — a reconcile
            // failing mid-dispose, say — must not touch a notifier that may
            // already be disposed, nor resurrect an error field the
            // teardown path just settled.
            if (_disposed) return;
            bleError = problem;
            notifyListeners();
          },
          log: (message) => debugPrint('[peer] $message'),
          headStart: bleHeadStart,
          jitter: bleJitter,
        );
        await _bleTransport!.start();
      } else if (!wantBle && _bleTransport != null) {
        final transport = _bleTransport!;
        _bleTransport = null;
        // The sub-switch is the third operator-caused disconnection, beside
        // the master switch and a revoke: the links this stop is about to
        // close must not report themselves lost. Only the BLE ones — a LAN
        // session dropping at this same moment is still news.
        for (final entry in _peers.entries) {
          if (entry.value.session?.link is PeerBleLink) _announcedConnections.remove(entry.key);
        }
        await transport.stop();
        bleError = null;
      } else if (!wantBle && _bleTransport == null) {
        // Steady-off carries no BLE status. This is also what retires the
        // error a FAILED stop recorded — without it that banner would
        // outlive the sub-switch forever, with nothing left to clear it.
        bleError = null;
      }
    } catch (e, st) {
      // AFTER the cleanup stop, or its own teardown would race this
      // assignment and the operator would see the error flash and vanish.
      final broken = _bleTransport;
      _bleTransport = null;
      if (broken != null) {
        try {
          await broken.stop();
        } catch (_) {
          // The stop of a transport that just failed failing too adds
          // nothing; the original error is the one to report.
        }
      }
      bleError = 'Bluetooth failed: $e';
      debugPrint('[peer] BLE transport FAILED: $e');
      ErrorReportingService.report(e, st, context: 'PeerService:bleTransport');
    }

    // Sessions survive the operation switch — that is the point of binding
    // them to the device. Each is told what this side now shares, and the
    // durable sync engages or idles inside the session accordingly.
    for (final runtime in _peers.values.toList()) {
      await runtime.session?.setSharing(shared);
    }
    for (final session in _unidentifiedSessions.toList()) {
      await session.setSharing(shared);
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
    // Before the close, so the drop this causes is not reported back to the
    // operator who just asked for it.
    _announcedConnections.remove(peerDeviceId);
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
    _discoveryError = null;
    _linkError = null;
    try {
      _linkServer = await PeerLinkServer.bind();
    } catch (e, st) {
      // A device that cannot listen can still dial out, so this is degraded
      // rather than fatal — but it must be visible, since a firewall prompt
      // the operator dismissed is otherwise invisible forever.
      _linkError = 'Cannot accept incoming connections: $e';
      _refreshError();
      debugPrint('[peer] listen bind FAILED: $e');
      ErrorReportingService.report(e, st, context: 'PeerService:bindLinkServer');
    }
    _linkSubscription = _linkServer?.connections.listen(_onInboundLink);
    _mediaSubscription = _linkServer?.mediaConnections.listen((connection) {
      // `hasListener` as well as `isClosed`: this is a BROADCAST controller,
      // so with the screen-sharing experiment off nothing subscribes and an
      // added event is silently dropped — leaving an upgraded socket open
      // forever. Anything on this network segment could then hold file
      // descriptors open on every install with peer sync on, simply by
      // dialling /media repeatedly.
      if (_mediaConnections.isClosed || !_mediaConnections.hasListener) {
        unawaited(connection.link.close());
        return;
      }
      _mediaConnections.add(connection);
    });

    // `openPeerBeaconSocket` owns every way opening a socket can fail — the
    // bind and enabling broadcast on it alike — reporting the reason on
    // `beacons` and retrying on its own backoff. Nothing is expected out of
    // here any more; the catch stays because a throw that reaches it would
    // otherwise leave `_running` true over a device that is deaf, with
    // nothing on screen saying so.
    final PeerBeaconSocket socket;
    try {
      socket = await openPeerBeaconSocket(port: beaconPort);
    } catch (e, st) {
      error = 'Discovery failed: $e';
      debugPrint('[peer] beacon socket FAILED: $e');
      ErrorReportingService.report(e, st, context: 'PeerService:beaconSocket');
      notifyListeners();
      return;
    }
    // The teardown does not wait for this method: `dispose` fires `_stop`
    // outside the apply tail, so a stop can land while this awaits its
    // socket. Assigning one then would hand `_beaconSocket` an object the
    // stop already decided against — bound, listening, and running a retry
    // ladder nothing will ever cancel.
    if (_disposed || !_enabled) {
      await socket.close();
      return;
    }
    _beaconSocket = socket;
    _beaconSubscription = socket.beacons.listen(
      _onBeacon,
      onError: (Object e, StackTrace st) {
        // Once per outage, not once per rebind. The socket now comes back on
        // its own, so a receive-side failure that recurs after every rebind
        // would upload on the announce interval for as long as it lasted —
        // the storm this whole card exists to stop, from the other side.
        final first = _discoveryError == null;
        _discoveryError = 'Discovery failed: $e';
        _refreshError();
        debugPrint('[peer] discovery FAILED: $e');
        if (first) ErrorReportingService.report(e, st, context: 'PeerService:beacons');
        notifyListeners();
      },
    );

    // Logged, not silent. This feature's failure mode is "finds nothing",
    // which is indistinguishable from "working, nobody else here" unless the
    // console says what it is doing — see docs/design/error-reporting.md on
    // why ErrorReportingService alone is not enough for an operator or a
    // developer standing in a field.
    debugPrint('[peer] up as "$localDeviceName" ($localDeviceId), sharing ${_openOperationUuid ?? 'nothing'}, '
        'listening on ${_linkServer?.port}, beacons on $beaconPort');
    _announce();
    _announceTimer = Timer.periodic(_announceInterval, (_) => _announce());
    _sweepTimer = Timer.periodic(_beaconTimeout, (_) => _sweepStalePeers());
    notifyListeners();
  }

  Future<void> _stop() async {
    debugPrint('[peer] peer sync stopped');
    // Cleared first: every session below is about to be closed on the
    // operator's own instruction, and each would otherwise report itself
    // lost on the way out.
    _announcedConnections.clear();
    _announceTimer?.cancel();
    _announceTimer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    await _beaconSubscription?.cancel();
    _beaconSubscription = null;
    await _linkSubscription?.cancel();
    _linkSubscription = null;
    await _mediaSubscription?.cancel();
    _mediaSubscription = null;
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
  }

  /// The two faults [error] can be showing, held apart because they recover
  /// separately: discovery comes back on its own, a refused listen bind does
  /// not. One slot on screen, so [_refreshError] decides which is showing —
  /// without this the recovery of one silently retires the other, and a
  /// device that cannot accept a single inbound link says so nowhere.
  String? _discoveryError;
  String? _linkError;

  void _refreshError() => error = _discoveryError ?? _linkError;

  /// Retires a discovery failure once the socket is back. Without this the
  /// banner outlives the outage — the socket rebinds seconds later and the
  /// operator is left with a red row over a working peer list, and no way
  /// to clear it but toggling the switch.
  void _clearRecoveredDiscoveryError() {
    if (_discoveryError == null || _beaconSocket?.healthy != true) return;
    _discoveryError = null;
    _refreshError();
    notifyListeners();
  }

  void _announce() {
    _clearRecoveredDiscoveryError();
    final port = _linkServer?.port;
    // Nothing to advertise without somewhere to dial back to. A device whose
    // listen bind failed stays silent rather than announcing a port it isn't
    // on: a peer dialling that would just time out, repeatedly.
    if (port == null) return;
    _beaconSocket?.announce(PeerBeacon(
      deviceId: localDeviceId,
      deviceName: localDeviceName,
      operationUuid: _openOperationUuid,
      port: port,
    ));
  }

  void _onBeacon(PeerBeacon beacon) {
    if (beacon.deviceId == localDeviceId) return; // our own, heard back
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
    if (!_running) return;
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
      if (attempt != runtime.attemptSeq || !_running) {
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
    if (!_running) {
      unawaited(link.close());
      return;
    }
    // Which peer this is isn't known until its `hello` arrives, so the
    // session is created first and filed under its peer id once it
    // identifies itself.
    debugPrint('[peer] accepted an inbound link');
    _attach(null, link);
  }

  /// A ready BLE link — either side may have connected, so like an inbound
  /// LAN link it attaches unidentified and is filed once its hello arrives.
  void _onBleLink(PeerLink link) {
    if (!_running) {
      unawaited(link.close());
      return;
    }
    debugPrint('[peer] BLE link ready');
    _attach(null, link, batchLimit: _bleBatchLimit);
  }

  void _attach(PeerRuntime? runtime, PeerLink link, {int batchLimit = PeerSession.defaultBatchLimit}) {
    if (!_running) {
      unawaited(link.close());
      return;
    }
    final session = PeerSession(
      link: link,
      localDeviceId: localDeviceId,
      localDeviceName: localDeviceName,
      localCapabilities: localCapabilities?.call() ?? const [],
      localAccountTag: localAccountTag?.call(),
      sharedOperationUuid: _openOperationUuid,
      outbox: outbox,
      cursors: cursors,
      trust: trust,
      operations: operations,
      qsos: qsos,
      batchLimit: batchLimit,
      onChanged: _onSessionChanged,
      onEphemeral: (session, message) {
        final deviceId = session.peer?.deviceId;
        if (deviceId != null) onEphemeral?.call(deviceId, message);
      },
      onEstablished: (session) {
        onSessionEstablished?.call(session);
        final peer = session.peer;
        if (peer == null) return;
        // A second session for a peer that already has one — a BLE link
        // racing an established LAN session — reaches here before
        // _onSessionChanged closes it, and the operator must not be told
        // twice about one connection.
        if (!_announcedConnections.add(peer.deviceId)) return;
        onPeerConnectionChanged?.call(peer.deviceId, peer.deviceName, connected: true);
      },
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
        // Only for the session this peer is actually filed under, so the
        // duplicate-link teardown above — which closes a session nothing
        // tracks — never reads as the peer going away.
        if (peer != null && _announcedConnections.remove(peer.deviceId)) {
          onPeerConnectionChanged?.call(peer.deviceId, peer.deviceName, connected: false);
        }
        // A refusal is a decision, not a fault — retrying it would just
        // re-refuse in a loop. A plain close is worth reconnecting for.
        if (session.state == PeerSessionState.closed && _running) {
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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    unawaited(_stop());
    // The reconciler owns the transport in life; in teardown nothing will
    // run it again, so the radio is released here. Its async tail can still
    // deliver a status after super.dispose() — [_disposed] is what keeps
    // that from touching the dead notifier.
    final transport = _bleTransport;
    _bleTransport = null;
    if (transport != null) unawaited(transport.stop());
    unawaited(_mediaConnections.close());
    super.dispose();
  }
}
