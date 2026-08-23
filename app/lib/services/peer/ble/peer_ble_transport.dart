// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The BLE peer transport (HALO-342): advertising, scanning, and turning
// GATT connections into ready `PeerLink`s for `PeerService` to attach —
// the same seam inbound WebSocket links use, so the session, protocol and
// trust layers never learn BLE exists.
//
// Both roles run at once. Every device advertises the peer service UUID
// (that alone — iOS peripherals may not advertise custom data, so the
// post-connect protocol hello is the only identity) and scans for it.
// Either side may connect; `PeerService`'s duplicate-session close makes
// the race benign, and the delays below make it rare.
//
// LAN gets a head start on purpose: a shared network is faster and cheaper,
// so BLE waits several seconds after sighting a peer before dialling, and
// skips peers whose advertised name-token matches a device that already has
// a live session. The token is a routing hint, never identity — it can be
// truncated by the platform or absent entirely, and BLE addresses rotate,
// so a missed hint just means one extra connect that the duplicate close
// cleans up.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';

import '../../../tools/backoff.dart';
import 'peer_ble_framing.dart';
import 'peer_ble_gateway.dart';

/// The advertised-name prefix in front of the device-id token.
const String _namePrefix = 'H2K:';

/// A link that died sooner than this counts as a failure for its address —
/// including a duplicate-session close, which is exactly the case the
/// backoff exists for: without it two devices already paired over LAN
/// would open, identify, and close BLE links in a tight loop forever.
const Duration _shortLivedCutoff = Duration(seconds: 30);

const Duration _addressBackoffCap = Duration(minutes: 5);

/// A sighting older than this no longer proves the peer is there.
const Duration _sightingStale = Duration(seconds: 15);

/// Forget an address not seen for this long — RPA rotation mints fresh
/// addresses continuously, and the candidate map must not grow with them.
const Duration _candidateExpiry = Duration(minutes: 10);

/// Outbound bytes a link may hold before it is declared stuck and dropped.
/// A healthy window drains continuously; only a peer that stopped ACKing
/// (or a radio that stopped carrying) lets this pile up.
const int _maxPendingOutbound = 1024 * 1024;

class _BleCandidate {
  _BleCandidate() : lastSeenMillis = realNowMillis();

  /// Real clock throughout — these are protocol timeouts, and developer
  /// time travel must not strand or flood the radio (docs/design/time.md).
  int lastSeenMillis;
  String? token;
  Timer? timer;
  int failures = 0;
  int cooldownUntilMillis = 0;
  bool connecting = false;
  PeerBleLink? activeLink;
}

class PeerBleTransport {
  PeerBleTransport({
    required this.gateway,
    required this.localDeviceId,
    required this.onLink,
    required this.connectedDeviceIds,
    required this.onStatus,
    this.log,
    this.headStart = const Duration(seconds: 5),
    this.handshakeTimeout = const Duration(seconds: 10),
    this.jitter = true,
  });

  final PeerBleGateway gateway;
  final String localDeviceId;

  /// A ready link — HELLOs crossed, sizes agreed. The receiver attaches a
  /// session to it exactly like an inbound LAN link.
  final void Function(PeerLink link) onLink;

  /// Device ids with live sessions right now, any transport — what the
  /// name-token hint is matched against to skip redundant dials.
  final Iterable<String> Function() connectedDeviceIds;

  /// Operator-readable state of the radio, or null when all is well.
  final void Function(String? problem) onStatus;

  final void Function(String message)? log;
  final Duration headStart;
  final Duration handshakeTimeout;

  /// Off in tests, where determinism beats collision avoidance.
  final bool jitter;

  final Random _random = Random();

  bool _running = false;
  bool _serverUp = false;
  bool _scanUp = false;

  /// Retry state for role starts that failed with the radio nominally
  /// ready (Android's "scanning too frequently" class). Without this, one
  /// transient failure leaves BLE off for the whole session: nothing else
  /// re-runs the reconcile until the adapter flaps or the switch toggles.
  int _roleFailures = 0;
  Timer? _roleRetryTimer;

  final Map<String, _BleCandidate> _candidates = {};
  final Map<String, PeerBleLink> _serverLinks = {};
  final Set<PeerBleLink> _links = {};

  StreamSubscription<void>? _availabilitySub;
  StreamSubscription<PeerBleSighting>? _sightingsSub;
  StreamSubscription<PeerBleServerEvent>? _serverSub;

  String get _compactLocalId => _compact(localDeviceId);
  String get _localToken => _compactLocalId.substring(0, min(8, _compactLocalId.length));

  static String _compact(String deviceId) => deviceId.replaceAll('-', '').toLowerCase();

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _sightingsSub = gateway.sightings.listen(_onSighting);
    _serverSub = gateway.serverEvents.listen(_onServerEvent);
    _availabilitySub = gateway.availabilityChanged.listen((_) => unawaited(_reconcileRadio()));
    // The one prompting pass: turning the sub-switch on is the consent for
    // the OS permission dialog, so only this first prepare asks.
    await _reconcileRadio(requestPermission: true);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    // Let any in-flight reconcile land first: past its _running checks it
    // may still be starting a role, and tearing down under it would leave
    // the radio advertising after "off".
    await _reconcileTail.catchError((Object _) {});
    _roleRetryTimer?.cancel();
    _roleRetryTimer = null;
    await _availabilitySub?.cancel();
    _availabilitySub = null;
    await _sightingsSub?.cancel();
    _sightingsSub = null;
    await _serverSub?.cancel();
    _serverSub = null;
    for (final candidate in _candidates.values) {
      candidate.timer?.cancel();
    }
    _candidates.clear();
    // Closing every link — including ones handed off to sessions — is the
    // point: the sub-switch going off means the radio goes quiet, and a
    // session left talking over it would belie the switch. Concurrently:
    // each close bounds its platform shutdown at 5s, and this stop is
    // awaited through PeerService's serialized apply tail — serial closes
    // would stack those timeouts in front of every later reconfiguration.
    await Future.wait([for (final link in _links.toList()) link.close()]);
    _serverLinks.clear();
    await _stopRoles();
    // No onStatus(null) here: the owner clears its own error field on a
    // deliberate stop, and a stop issued while CLEANING UP a failed start
    // must not erase the very problem the caller just recorded.
  }

  /// Serializes reconciles — availability events burst when a radio flaps,
  /// and two interleaved runs would race their role starts.
  Future<void> _reconcileTail = Future.value();

  Future<void> _reconcileRadio({bool requestPermission = false}) {
    final next = _reconcileTail.then((_) => _reconcileNow(requestPermission: requestPermission));
    _reconcileTail = next.catchError((Object e) {
      log?.call('BLE reconcile failed: $e');
      // The operator's field too, not just the console — this handler is
      // the only thing that sees an escaped reconcile, and leaving the
      // previous (possibly all-well) status standing hides it.
      onStatus('Bluetooth failed: $e');
    });
    return next;
  }

  Future<void> _reconcileNow({bool requestPermission = false}) async {
    if (!_running) return;
    PeerBleReadiness readiness;
    try {
      readiness = await gateway.prepare(requestPermission: requestPermission);
    } catch (e) {
      readiness = PeerBleReadiness(canCentral: false, canPeripheral: false, problem: 'Bluetooth unavailable: $e');
    }
    if (!_running) return;
    var startFailed = false;
    if (readiness.canPeripheral && !_serverUp) {
      try {
        await gateway.startServer(localName: '$_namePrefix$_localToken');
        _serverUp = true;
        log?.call('BLE advertising as $_namePrefix$_localToken');
      } catch (e) {
        startFailed = true;
        // Logged as well as surfaced: a scan failure right after this
        // rebuilds `readiness` wholesale, and without this line the
        // advertise diagnosis would evaporate in exactly the
        // both-roles-broken case.
        log?.call('BLE advertise failed: $e');
        readiness = PeerBleReadiness(
            canCentral: readiness.canCentral, canPeripheral: false, problem: 'Bluetooth advertise failed: $e');
      }
    } else if (!readiness.canPeripheral && _serverUp) {
      _serverUp = false;
      await _guarded(gateway.stopServer, 'stopServer');
    }
    if (readiness.canCentral && !_scanUp) {
      try {
        await gateway.startScan();
        _scanUp = true;
        log?.call('BLE scanning for peers');
      } catch (e) {
        startFailed = true;
        log?.call('BLE scan start failed: $e');
        readiness =
            PeerBleReadiness(canCentral: false, canPeripheral: readiness.canPeripheral, problem: 'Bluetooth scan failed: $e');
      }
    } else if (!readiness.canCentral && _scanUp) {
      _scanUp = false;
      await _guarded(gateway.stopScan, 'stopScan');
    }
    onStatus(readiness.usable ? readiness.problem : (readiness.problem ?? 'Bluetooth unavailable'));

    // Two self-heal classes: a start that failed with the radio nominally
    // ready (Android's "scanning too frequently"), and readiness the
    // gateway itself marked transient (a manager still powering on, which
    // emits no event when it settles). Everything else waits for the
    // availability stream, which fires when a not-ready radio changes.
    if ((startFailed || readiness.transient) && _running) {
      _roleFailures++;
      _roleRetryTimer?.cancel();
      _roleRetryTimer = Timer(exponentialBackoff(_roleFailures, cap: _addressBackoffCap), () {
        _roleRetryTimer = null;
        unawaited(_reconcileRadio());
      });
    } else {
      _roleFailures = 0;
    }
  }

  Future<void> _stopRoles() async {
    if (_scanUp) {
      _scanUp = false;
      await _guarded(gateway.stopScan, 'stopScan');
    }
    if (_serverUp) {
      _serverUp = false;
      await _guarded(gateway.stopServer, 'stopServer');
    }
  }

  Future<void> _guarded(Future<void> Function() action, String what) async {
    try {
      await action();
    } catch (e) {
      // Teardown of a radio that already went away — worth a line, not a
      // failure: the state being torn down no longer exists either way.
      log?.call('BLE $what failed: $e');
    }
  }

  // ---- central side ----

  void _onSighting(PeerBleSighting sighting) {
    if (!_running) return;
    final now = realNowMillis();
    _candidates.removeWhere((_, c) =>
        c.activeLink == null && !c.connecting && now - c.lastSeenMillis > _candidateExpiry.inMilliseconds);

    // Once per fresh address, not per advertisement: the line that says
    // discovery is even happening — RPA rotation keeps the rate to a few
    // an hour.
    if (!_candidates.containsKey(sighting.addressId)) {
      log?.call('BLE sighted ${sighting.addressId} as "${sighting.nameHint}"');
    }
    final candidate = _candidates.putIfAbsent(sighting.addressId, _BleCandidate.new);
    candidate.lastSeenMillis = now;
    final name = sighting.nameHint;
    if (name != null && name.startsWith(_namePrefix)) {
      final token = name.substring(_namePrefix.length).toLowerCase();
      if (token.length >= 4) candidate.token = token;
    }
    if (candidate.timer != null || candidate.connecting || candidate.activeLink != null) return;
    if (now < candidate.cooldownUntilMillis) return;

    // LAN's head start. A token that says the peer has the LOWER id doubles
    // the wait — that side dials first by the same rule the LAN uses, and
    // if it does, its inbound connection lands here before this timer fires.
    var delay = headStart;
    final token = candidate.token;
    if (token != null && _compactLocalId.compareTo(token) > 0) delay *= 2;
    if (jitter) delay += Duration(milliseconds: _random.nextInt(1000));
    candidate.timer = Timer(delay, () => unawaited(_tryConnect(sighting.addressId)));
  }

  Future<void> _tryConnect(String addressId) async {
    final candidate = _candidates[addressId];
    if (candidate == null) return;
    candidate.timer = null;
    if (!_running || candidate.connecting || candidate.activeLink != null) return;
    final now = realNowMillis();
    if (now < candidate.cooldownUntilMillis) return;
    if (now - candidate.lastSeenMillis > _sightingStale.inMilliseconds) return;
    // The hint: a peer already connected (over any transport) is not worth
    // a radio link that would only be duplicate-closed. Next sighting
    // re-evaluates, so a dropped session reopens the door by itself. Logged
    // because the token is a truncatable prefix: a false match suppresses a
    // real peer for as long as the colliding device stays connected, and
    // the line is the only way that is diagnosable.
    final token = candidate.token;
    if (token != null && connectedDeviceIds().any((id) => _compact(id).startsWith(token))) {
      log?.call('BLE skipping $addressId: token $token matches a connected device');
      return;
    }

    candidate.connecting = true;
    log?.call('BLE dialling $addressId');
    // Packets can arrive the moment the subscription lands, before the
    // link object exists — buffered here, drained into the link below.
    // Single-threaded, and no awaits sit between the connect resuming and
    // the drain, so nothing slips between the two.
    final earlyPackets = <Uint8List>[];
    PeerBleLink? link;
    final PeerBleClientConnection connection;
    try {
      connection = await gateway.connect(addressId, onPacket: (packet) {
        final live = link;
        if (live != null) {
          live.feed(packet);
        } else {
          earlyPackets.add(packet);
        }
      });
    } catch (e) {
      candidate.connecting = false;
      candidate.failures++;
      candidate.cooldownUntilMillis =
          realNowMillis() + exponentialBackoff(candidate.failures, cap: _addressBackoffCap).inMilliseconds;
      log?.call('BLE connect to $addressId failed (attempt ${candidate.failures}): $e');
      return;
    }
    if (!_running) {
      // stop() ran while the dial was in flight; it cannot see a
      // connection not yet wrapped in a link, so this path releases it.
      candidate.connecting = false;
      await connection.disconnect();
      return;
    }
    log?.call('BLE connected to $addressId');
    final live = link = PeerBleLink(
      sendPacket: connection.write,
      shutdown: connection.disconnect,
      label: addressId,
      log: log,
    );
    candidate.activeLink = live;
    candidate.connecting = false;
    for (final packet in earlyPackets) {
      live.feed(packet);
    }
    earlyPackets.clear();
    unawaited(connection.disconnected
        .then((_) => live.close(), onError: (Object _) => live.close()));
    _startLink(live, connection.chunkLimit, onClosed: (uptimeMillis) {
      candidate.activeLink = null;
      if (uptimeMillis < _shortLivedCutoff.inMilliseconds) {
        candidate.failures++;
        candidate.cooldownUntilMillis =
            realNowMillis() + exponentialBackoff(candidate.failures, cap: _addressBackoffCap).inMilliseconds;
      } else {
        candidate.failures = 0;
        candidate.cooldownUntilMillis = realNowMillis() + 2000;
      }
    });
  }

  // ---- peripheral side ----

  void _onServerEvent(PeerBleServerEvent event) {
    if (!_running) return;
    switch (event) {
      case PeerBleCentralSubscribed(:final centralId):
        unawaited(_acceptCentral(centralId));
      case PeerBleWriteReceived(:final centralId, :final value):
        // Routed to that central's link. A write from a central that never
        // subscribed — a scanner app poking at the service — has nowhere
        // to go and is dropped.
        _serverLinks[centralId]?.feed(value);
      case PeerBleCentralUnsubscribed(:final centralId):
        unawaited(_serverLinks.remove(centralId)?.close());
    }
  }

  Future<void> _acceptCentral(String centralId) async {
    // A re-subscribe from a central we still track is a stale link on this
    // side — the central reset without a clean unsubscribe.
    await _serverLinks.remove(centralId)?.close();
    if (!_running) return;
    log?.call('BLE central $centralId subscribed');
    final link = PeerBleLink(
      sendPacket: (packet) => gateway.notify(centralId, packet),
      shutdown: () => gateway.disconnectCentral(centralId),
      label: centralId,
      log: log,
    );
    // Installed BEFORE the chunk-limit round trip: the central's first
    // HELLO packets land during that await, and a link not yet in the map
    // would silently drop them — the handshake then times out with both
    // radios working perfectly.
    _serverLinks[centralId] = link;
    int chunk;
    try {
      chunk = await gateway.serverChunkLimit(centralId);
    } catch (_) {
      chunk = bleSafeChunk;
    }
    if (!_running || !identical(_serverLinks[centralId], link)) {
      await link.close();
      return;
    }
    _startLink(link, chunk, onClosed: (_) {
      if (identical(_serverLinks[centralId], link)) _serverLinks.remove(centralId);
    });
  }

  // ---- shared ----

  void _startLink(PeerBleLink link, int chunkLimit, {required void Function(int uptimeMillis) onClosed}) {
    _links.add(link);
    final bornMillis = realNowMillis();
    unawaited(link.closed.then((_) {
      _links.remove(link);
      onClosed(realNowMillis() - bornMillis);
    }));
    link.start(chunkLimit);
    unawaited(link.ready.timeout(handshakeTimeout, onTimeout: () => false).then((ready) {
      if (!ready) {
        // The one line covering every pre-ready death — nothing else logs
        // these, and a peer that connects but never completes the
        // handshake would otherwise leave no evidence it ever tried.
        log?.call('BLE link ${link.label} ended before the handshake completed');
        unawaited(link.close());
        return;
      }
      if (!_running) {
        unawaited(link.close());
        return;
      }
      onLink(link);
    }));
  }
}

/// A [PeerLink] over one BLE connection — either side. Same contract as
/// `WebSocketPeerLink`: [send] never throws, liveness is reported only
/// through [closed], and [close] is idempotent.
class PeerBleLink implements PeerLink {
  PeerBleLink({
    required this.sendPacket,
    required this.shutdown,
    this.label = '',
    this.log,
    this.keepaliveInterval = const Duration(seconds: 20),
    this.idleCutoff = const Duration(seconds: 65),
  });

  /// Names this link in log lines — the address or central id.
  final String label;

  /// Puts one packet on the air. A throw means the connection is gone and
  /// closes the link.
  final Future<void> Function(Uint8List packet) sendPacket;

  /// Tears down the underlying connection. Best-effort; failures are the
  /// connection already being gone.
  final Future<void> Function() shutdown;

  final void Function(String message)? log;

  /// How often to prove this side is alive, and how much silence from the
  /// peer means it is not. The cutoff spans three missed pings, so one
  /// dropped-by-overrun keepalive never kills a healthy link. GATT itself
  /// reports a dropped RADIO connection; this pair exists for the case it
  /// cannot see — the peer's app-level link died while the connection
  /// idles on.
  final Duration keepaliveInterval;
  final Duration idleCutoff;

  late final BleFrameConduit _conduit = BleFrameConduit(
    onMessage: (message) {
      if (!_controller.isClosed) _controller.add(message);
    },
    onSendable: _wake,
    onError: (problem) {
      log?.call('BLE link $label dropped: $problem');
      unawaited(close());
    },
  );

  final _controller = StreamController<List<int>>();
  final _closedCompleter = Completer<void>();
  final _readyCompleter = Completer<bool>();
  Completer<void> _wakeCompleter = Completer<void>();
  bool _isClosed = false;
  bool _started = false;
  Timer? _keepaliveTimer;
  Timer? _helloRetryTimer;

  /// Real clock — a protocol timeout (docs/design/time.md).
  int _lastHeardMillis = realNowMillis();

  /// Completes true when both HELLOs have crossed, false if the link dies
  /// first. The transport gates [PeerLink] hand-off on it.
  Future<bool> get ready => _readyCompleter.future;

  /// Sends this side's HELLO and starts the send worker. Called once, with
  /// this side's packet-size view.
  void start(int chunkLimit) {
    if (_started || _isClosed) return;
    _started = true;
    _conduit.sendHello(chunkLimit);
    // Retransmitted until the peer's ACK proves it landed: macOS
    // peripherals silently eat notifies fired right after a central
    // subscribes, and a hello that died there would otherwise strand the
    // far side until the handshake timeout, every single attempt.
    _helloRetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_conduit.ready) {
        _helloRetryTimer?.cancel();
        _helloRetryTimer = null;
        return;
      }
      _conduit.resendHello();
    });
    unawaited(_sendWorker());
  }

  /// One received packet from the air.
  void feed(Uint8List packet) {
    if (_isClosed) return;
    _lastHeardMillis = realNowMillis();
    _conduit.feed(packet);
    _checkReady();
  }

  /// From both directions of traffic: the handshake's last event can be
  /// RECEIVING the peer's hello or finishing the SEND of our own —
  /// whichever lands second completes [ready], and checking only one side
  /// leaves the other ordering hanging until the timeout.
  void _checkReady() {
    if (_isClosed || !_conduit.ready || _readyCompleter.isCompleted) return;
    _readyCompleter.complete(true);
    // The negotiated sizes, in one place: a side that silently fell back to
    // the ATT floor drags both directions to 20-byte packets, and this line
    // is what separates "BLE is just slow" from "negotiation failed".
    log?.call('BLE link $label ready '
        '(packet size: local ${_conduit.localChunkLimit}, peer ${_conduit.peerChunkLimit})');
    _keepaliveTimer = Timer.periodic(keepaliveInterval, (_) {
      if (realNowMillis() - _lastHeardMillis > idleCutoff.inMilliseconds) {
        log?.call('BLE link $label silent past ${idleCutoff.inSeconds}s; dropping');
        unawaited(close());
        return;
      }
      _conduit.sendPing();
    });
  }

  Future<void> _sendWorker() async {
    while (!_isClosed) {
      final wait = _wakeCompleter = Completer<void>();
      final packet = _conduit.nextPacket();
      if (packet == null) {
        // The completer was created BEFORE nextPacket looked, so a wake
        // that fired in between is already latched — no lost signal.
        await wait.future;
        continue;
      }
      try {
        await sendPacket(packet);
      } catch (e) {
        log?.call('BLE link $label send failed: $e');
        await close();
        return;
      }
      _checkReady();
    }
  }

  void _wake() {
    if (!_wakeCompleter.isCompleted) _wakeCompleter.complete();
  }

  @override
  Stream<List<int>> get inbound => _controller.stream;

  @override
  void send(List<int> message) {
    if (_isClosed) return;
    if (_conduit.pendingOutboundBytes > _maxPendingOutbound) {
      // The peer stopped ACKing or the radio stopped carrying; holding an
      // unbounded queue for it would grow forever. Dropping the link lets
      // the session's reconnect-and-catch-up path recover instead.
      log?.call('BLE link $label stuck with ${_conduit.pendingOutboundBytes} bytes pending; dropping');
      unawaited(close());
      return;
    }
    _conduit.enqueueMessage(message);
  }

  @override
  Future<void> get closed => _closedCompleter.future;

  @override
  Future<void> close() async {
    if (_isClosed) {
      await _closedCompleter.future;
      return;
    }
    _isClosed = true;
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _helloRetryTimer?.cancel();
    _helloRetryTimer = null;
    _wake();
    if (!_readyCompleter.isCompleted) _readyCompleter.complete(false);
    try {
      // Bounded: this close is awaited through the transport's stop and
      // PeerService's serialized apply tail, so a platform disconnect that
      // never completes would wedge every later switch and operation
      // change behind it.
      await shutdown().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Closing a connection that already dropped is not a failure.
    }
    if (!_controller.isClosed) unawaited(_controller.close());
    if (!_closedCompleter.isCompleted) _closedCompleter.complete();
  }
}
