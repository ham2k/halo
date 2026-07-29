// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one thing that talks to both transports and drivers: it hands a
// driver nothing but a sink, so a driver never deals with sockets,
// discovery or reconnection, and it is the only writer of CAT-sourced
// state.
//
// Every piece of per-connection state is keyed by node uuid rather than
// held in a field. app-polo's connection layer was module-level singletons
// (`activeConnection`, `connectAttemptSeq`, `vfoSubscriberCount`), which is
// what blocked ever connecting a second device — doing it per-node costs
// nothing now and is a rewrite later. See docs/design/gato.md.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:uuid/uuid.dart';

import '../error_reporting_service.dart';
import '../radio_service.dart';
import '../settings_service.dart';
import 'discovery.dart';
import 'driver.dart';
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transport.dart';

const _uuidGenerator = Uuid();

/// Bump when the stored shape changes in a way a reader has to know about.
const _storageVersion = 1;

/// Bands where SSB voice conventionally sits on the lower sideband.
/// Everything else is upper — including 60 m, which is channelized USB by
/// international agreement despite being below 10 MHz.
const _lsbBands = {'160m', '80m', '40m'};

/// How hard launch tries before leaving it to the user.
const _reconnectRetries = 2;
const _defaultReconnectDelay = Duration(seconds: 3);

enum _ConnectOutcome {
  connected,
  failed,

  /// Something else took the node over — a manual Connect, or a
  /// Disconnect. Not a failure, and not ours to retry.
  superseded,
}

/// No CAT protocol has an "SSB" mode — only the concrete sideband — so the
/// app's generic mode is resolved here, once, before any driver sees it.
///
/// [band] is the fallback when there is no frequency to derive one from —
/// which is exactly what a manual band pick leaves behind. Without it a
/// picked 40m plus SSB resolved to USB.
String? resolveSideband(String? mode, double? freqKHz, {String? band}) {
  if (mode == null || mode.toUpperCase() != 'SSB') return mode;
  final resolved = freqKHz != null ? bandForFrequency(freqKHz) : band;
  return _lsbBands.contains(resolved) ? 'LSB' : 'USB';
}

class GatoService extends ChangeNotifier {
  final SettingsService _settings;
  final EquipmentRegistry registry;

  /// The app's VFO state. GATO is its only CAT-origin writer, and it
  /// listens for everyone else's writes so it can retune the radio.
  /// Optional so tests that only exercise equipment config can omit it.
  final RadioService? _radio;

  /// Configured equipment, in the order it was added.
  final Map<String, EquipmentNode> _nodes = {};

  /// Live per-node connection state. Never persisted.
  final Map<String, _NodeRuntime> _runtimes = {};

  /// Set by [dispose]. The reconnect loop parks on an uncancellable delay,
  /// so it can outlive the service and must check before touching it again.
  bool _disposed = false;

  /// How long [reconnectDesignatedRadio] waits between attempts. Tests pass
  /// [Duration.zero] rather than sleeping through it for real.
  final Duration reconnectDelay;

  GatoService(this._settings,
      {EquipmentRegistry? registry, RadioService? radio, this.reconnectDelay = _defaultReconnectDelay})
      : registry = registry ?? EquipmentRegistry(),
        _radio = radio {
    _load();
    _radio?.addListener(_onVfoChanged);
  }

  List<EquipmentNode> get nodes => List.unmodifiable(_nodes.values);

  EquipmentNode? nodeFor(String uuid) => _nodes[uuid];

  // ----------------------------------------------------------- radio1

  /// Which node drives the logging panel — `radio1` in data-model.md's
  /// terms, the transceiver whose VFO is `vfoA`.
  ///
  /// Auto-assigned to the first transceiver added, so the common
  /// one-radio shack never has to think about it.
  String? _radio1;

  String? get radio1 => _radio1;

  bool isRadio1(String uuid) => _radio1 == uuid;

  Future<void> setRadio1(String? uuid) async {
    if (_radio1 == uuid) return;
    // The echo guard is per-node but only meaningful for whichever node is
    // radio1 — the same reason [_closeSession] clears it. The incoming
    // radio was told nothing while it wasn't driving the panel, and the
    // outgoing one stops being asked, so a stale value on either would
    // suppress the first tune to a frequency that radio happens to be on.
    for (final id in [_radio1, uuid]) {
      if (id != null) _runtimes[id]?.lastSent = null;
    }
    _radio1 = uuid;
    await _save();
    notifyListeners();
  }

  /// Picks a `radio1` when there isn't a valid one — after loading, after
  /// adding the first transceiver, or after removing the designated node.
  /// Returns true if it changed.
  bool _ensureRadio1() {
    if (_radio1 != null && _nodes.containsKey(_radio1)) return false;
    for (final node in _nodes.values) {
      if (registry.typeFor(node.typeKey)?.category == kCategoryTransceiver) {
        _radio1 = node.uuid;
        return true;
      }
    }
    final had = _radio1 != null;
    _radio1 = null;
    return had;
  }

  EquipmentState stateFor(String uuid) => _runtimes[uuid]?.state ?? const EquipmentState();

  /// The type handling [node], or null if it isn't in the catalogue — a
  /// record written by a newer build, or by a driver that has since been
  /// removed. The node stays in the list and says so rather than vanishing.
  EquipmentType? typeFor(EquipmentNode node) => registry.typeFor(node.typeKey);

  void _load() {
    final stored = _settings.stationEquipment;
    final nodes = stored['nodes'];
    if (nodes is Map) {
      for (final entry in nodes.entries) {
        final node = EquipmentNode.fromJson('${entry.key}', entry.value);
        // A single corrupt record drops that node, not the whole list.
        if (node != null) _nodes[node.uuid] = node;
      }
    }
    final radio1 = stored['radio1'];
    if (radio1 is String && _nodes.containsKey(radio1)) _radio1 = radio1;
    _ensureRadio1();
  }

  Future<void> _save() => _settings.setStationEquipment({
        'version': _storageVersion,
        if (_radio1 != null) 'radio1': _radio1,
        'nodes': {for (final node in _nodes.values) node.uuid: node.toJson()},
      });

  Future<EquipmentNode> addNode({
    required String typeKey,
    String name = '',
    Map<String, dynamic> config = const {},
  }) async {
    final node = EquipmentNode(
      uuid: _uuidGenerator.v4(),
      typeKey: typeKey,
      name: name,
      config: config,
    );
    _nodes[node.uuid] = node;
    _ensureRadio1();
    await _save();
    notifyListeners();
    return node;
  }

  Future<void> updateNode(EquipmentNode node) async {
    if (!_nodes.containsKey(node.uuid)) return;
    _nodes[node.uuid] = node;
    await _save();
    notifyListeners();
  }

  Future<void> removeNode(String uuid) async {
    await disconnect(uuid);
    _nodes.remove(uuid);
    _runtimes.remove(uuid);
    // Removing the designated radio hands the job to another transceiver
    // rather than leaving the logging panel with nothing driving it.
    _ensureRadio1();
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------ discovery

  final Map<String, DiscoveredEquipment> _discovered = {};
  final List<StreamSubscription<DiscoveredEquipment>> _discoverySubscriptions = [];

  /// Equipment that has announced itself and isn't configured yet, newest
  /// announcement wins. Already-configured equipment is filtered out — the
  /// point of the list is what you could still add.
  List<DiscoveredEquipment> get discovered {
    final configured = <String>{};
    for (final node in _nodes.values) {
      final type = registry.typeFor(node.typeKey);
      if (type != null) configured.add(_targetKey(node.typeKey, type.targetFor(node.config)));
    }
    return [
      for (final found in _discovered.values)
        if (!configured.contains(_targetKeyFor(found))) found,
    ];
  }

  String _targetKey(String typeKey, Map<String, dynamic> target) =>
      '$typeKey|${target.entries.map((e) => '${e.key}=${e.value}').join(',')}';

  String? _discoveryError;

  /// Why nothing is being found, when the reason is knowable — a port
  /// already held by something else, or a sandbox refusing the bind. Silent
  /// emptiness and "your radio is off" look identical otherwise.
  String? get discoveryError => _discoveryError;

  bool get isDiscovering => _discoverySubscriptions.isNotEmpty;

  /// Starts listening on every type that announces itself. Safe to call
  /// again while running; call [stopDiscovery] when the UI that wants it
  /// goes away, since this holds a bound socket.
  void startDiscovery() {
    if (isDiscovering) return;
    _discoveryError = null;

    for (final type in registry.types) {
      if (type is! EquipmentDiscoverer) continue;
      _discoverySubscriptions.add((type as EquipmentDiscoverer).discover().listen(
        (found) {
          _discovered[_discoveryKey(found)] = found;
          notifyListeners();
        },
        onError: (Object e, StackTrace st) {
          ErrorReportingService.report(e, st, context: 'gato:discovery:${type.key}');
          _discoveryError = '$e';
          notifyListeners();
        },
      ));
    }
    notifyListeners();
  }

  void stopDiscovery() {
    if (!isDiscovering) return;
    for (final subscription in _discoverySubscriptions) {
      unawaited(subscription.cancel());
    }
    _discoverySubscriptions.clear();
    // Findings are kept: reopening the Add dialog shows what was already
    // seen instead of an empty list waiting on the next announcement, which
    // for a Flex is several seconds away.
    notifyListeners();
  }

  String _discoveryKey(DiscoveredEquipment found) => '${found.typeKey}|${found.id}';

  String _targetKeyFor(DiscoveredEquipment found) {
    final type = registry.typeFor(found.typeKey);
    return type == null ? _discoveryKey(found) : _targetKey(found.typeKey, type.targetFor(found.config));
  }

  /// Adds a discovered device as configured equipment, with no typing.
  Future<EquipmentNode> addDiscovered(DiscoveredEquipment found) =>
      addNode(typeKey: found.typeKey, name: found.name, config: found.config);

  // -------------------------------------------------------------- runtime

  _NodeRuntime _runtimeFor(String uuid) => _runtimes.putIfAbsent(uuid, _NodeRuntime.new);

  void _setState(String uuid, EquipmentState state) {
    if (_disposed) return;
    _runtimeFor(uuid).state = state;
    notifyListeners();
  }

  Future<void> connect(String uuid) => _connect(uuid);

  /// The outcome matters only to [reconnectDesignatedRadio]: a retry loop
  /// must keep trying after a *failure* but stop dead when something else
  /// has taken the node over. app-polo conflated the two and its
  /// auto-reconnect ended up fighting the user's own Connect.
  Future<_ConnectOutcome> _connect(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return _ConnectOutcome.failed;

    final type = registry.typeFor(node.typeKey);
    final transport = registry.transportFor(type?.transportKey);
    if (type == null || transport == null) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: 'Unknown equipment type "${node.typeKey}"'));
      return _ConnectOutcome.failed;
    }

    final invalid = type.validate(node.config);
    if (invalid != null) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: invalid));
      return _ConnectOutcome.failed;
    }

    final runtime = _runtimeFor(uuid);

    // Supersede whatever this node already has going: cancel an in-flight
    // attempt so it stops hammering the radio, and tear down a live
    // connection before opening another.
    runtime.cancel?.cancel();
    await _teardown(runtime);

    final attempt = ++runtime.attemptSeq;
    final cancel = CatCancelToken();
    runtime.cancel = cancel;
    _setState(uuid, const EquipmentState(status: EquipmentStatus.connecting));

    final EquipmentConnection connection;
    try {
      connection = await transport.connect(type.targetFor(node.config), cancel: cancel);
    } on CatCancelledException {
      // A newer connect (or a disconnect) owns this node now — not a
      // failure, and not ours to report.
      return _ConnectOutcome.superseded;
    } catch (e, st) {
      if (attempt != runtime.attemptSeq) return _ConnectOutcome.superseded;
      ErrorReportingService.report(e, st, context: 'gato:connect');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: '$e'));
      return _ConnectOutcome.failed;
    }

    if (attempt != runtime.attemptSeq) {
      // Superseded while the handshake was running. Don't resurrect a
      // connection nothing is expecting any more — just close it, or it
      // leaks (the exact bug polo's attempt sequence was added to fix).
      unawaited(connection.close());
      return _ConnectOutcome.superseded;
    }

    final session = type.driver.createSession(_NodeSink(
      connection: connection,
      onReading: (reading) {
        // A session from a superseded connection must not write state.
        if (runtime.connection != connection) return;
        _applyReading(uuid, reading);
      },
    ));

    runtime.connection = connection;
    runtime.session = session;
    runtime.subscription = connection.data.listen((chunk) {
      try {
        session.handleData(chunk);
      } catch (e, st) {
        // One malformed frame must not kill the connection.
        ErrorReportingService.report(e, st, context: 'gato:handle-data:${type.driver.key}');
      }
    });

    unawaited(connection.closed.then((_) {
      // A stale connection's close must not clobber a live one's status.
      if (runtime.connection != connection) return;
      // The driver keeps its own timers (FlexRadio resyncs every 60s, the
      // CI-V drivers poll every 5s). Dropping the session without tearing
      // it down leaves them ticking for the life of the process — once per
      // drop — each one retaining its sink and this dead connection.
      unawaited(_closeSession(runtime));
      _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
    }));

    _setState(uuid, const EquipmentState(status: EquipmentStatus.connected));

    // Start updates on connect rather than when a UI subscriber shows up:
    // polo gated this on a refcount, so connecting with no screen mounted
    // succeeded and then never asked the radio anything.
    try {
      session.startUpdates();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'gato:start-updates:${type.driver.key}');
    }
    return _ConnectOutcome.connected;
  }

  /// Reconnects the designated radio at launch.
  ///
  /// Retried a couple of times because the radio may still be powering up,
  /// or the WiFi still associating — but it gives up quietly rather than
  /// nagging: the user can always connect from Settings.
  ///
  /// The retry never fights the user. It stops the moment anything else
  /// owns the node — a manual Connect, a Disconnect, or a connection that
  /// is already up — which is the failure mode that made polo's
  /// auto-reconnect the source of all four of its connection races.
  Future<void> reconnectDesignatedRadio() async {
    final uuid = _radio1;
    if (uuid == null || !_nodes.containsKey(uuid)) return;

    for (var attempt = 0; attempt <= _reconnectRetries; attempt++) {
      // The delay below can't be cancelled, so the service may have been
      // disposed while this loop was parked on it.
      if (_disposed) return;

      final status = stateFor(uuid).status;
      // Connected already, or someone is mid-connect — either way, not ours.
      if (status == EquipmentStatus.connected || status == EquipmentStatus.connecting) return;

      final outcome = await _connect(uuid);
      if (outcome != _ConnectOutcome.failed) return;

      if (attempt == _reconnectRetries) return;
      await Future<void>.delayed(reconnectDelay);
    }
  }

  Future<void> disconnect(String uuid) async {
    final runtime = _runtimes[uuid];
    if (runtime == null) return;
    runtime.cancel?.cancel();
    runtime.cancel = null;
    // Bump the sequence so an attempt still in flight knows it lost.
    runtime.attemptSeq += 1;
    await _teardown(runtime);
    _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
  }

  void _applyReading(String uuid, VfoReading reading) {
    final runtime = _runtimeFor(uuid);
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? runtime.state.vfo.freqKHz,
      mode: reading.mode ?? runtime.state.vfo.mode,
    );
    // A radio echoing back what it already reported shouldn't churn this
    // service's own listeners — but it must still reach RadioService.
    //
    // Returning here instead was a permanent desync: pick a band (or clear
    // the frequency field) and vfoA.freq goes null while the radio has not
    // moved, so every later report matches this cache and is swallowed. The
    // panel then showed a band with no frequency, and logged QSOs with it,
    // until the operator physically turned the knob. RadioService.setVfo
    // does its own no-op check, so forwarding unconditionally is free.
    if (merged != runtime.state.vfo) _setState(uuid, runtime.state.copyWith(vfo: merged));

    // Only the designated radio drives the app's VFO. Tagging the write
    // `radio` is what lets _onVfoChanged recognise the notification it's
    // about to receive as its own, instead of re-tuning the radio to the
    // value the radio just gave it.
    if (uuid != _radio1) return;
    runtime.lastSent = merged;
    _radio?.setVfo('vfoA', freq: merged.freqKHz, mode: merged.mode, origin: VfoOrigin.radio);
  }

  /// The app's VFO moved — the operator typed a frequency, picked a band,
  /// ran a command, or clicked a spot. Retune the radio to match.
  void _onVfoChanged() {
    final radio = _radio;
    if (radio == null) return;
    // Our own write, coming back around. Forwarding it would tell the radio
    // to go where it already is, and its confirmation would arrive as
    // another notification.
    if (radio.lastVfoOrigin == VfoOrigin.radio) return;

    final uuid = _radio1;
    if (uuid == null) return;
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    if (session == null) return;

    final vfo = radio.vfoA;
    final wanted = VfoReading(freqKHz: vfo.freq, mode: resolveSideband(vfo.mode, vfo.freq, band: vfo.band));
    // Nothing the radio doesn't already have. A band pick with no
    // frequency, or a mode restatement, must not re-send a tune command.
    final previous = runtime!.lastSent;
    if (wanted == previous) return;

    try {
      // Per field, and against what was last SENT rather than what the
      // radio last reported: a radio that hasn't confirmed yet would
      // otherwise get the frequency re-sent every time the mode changed.
      if (wanted.freqKHz != null && wanted.freqKHz != previous?.freqKHz) {
        session.setFrequency(wanted.freqKHz!);
      }
      if (wanted.mode != null && wanted.mode != previous?.mode) {
        session.setMode(wanted.mode!);
      }
      // Only once both landed. Recording it up front would remember a
      // command that threw as delivered, and every later attempt at the
      // same value would then short-circuit as already-sent — leaving the
      // radio somewhere the app doesn't think it is. Re-sending a tune the
      // radio already has is harmless by comparison.
      runtime.lastSent = wanted;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'gato:set-vfo-on-radio');
    }
  }

  /// Drops the session and everything that belongs to it, and gives the
  /// driver its chance to stop timers. Everything up to the first `await`
  /// runs synchronously, so a caller that has just checked
  /// `runtime.connection` can rely on it being cleared before anything else
  /// gets a turn.
  ///
  /// Separate from [_teardown] because a connection that closed on its own
  /// still needs all of this — only the socket is already gone.
  Future<void> _closeSession(_NodeRuntime runtime) async {
    final session = runtime.session;
    final subscription = runtime.subscription;
    runtime.session = null;
    runtime.connection = null;
    runtime.subscription = null;
    // The echo guard describes what THIS session was told. Carrying it into
    // the next connection would suppress the first tune to a frequency the
    // previous session happened to be on, leaving the app and a
    // freshly-reconnected radio silently disagreeing.
    runtime.lastSent = null;

    if (subscription != null) await subscription.cancel();

    if (session != null) {
      try {
        session.teardown();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'gato:teardown-session');
      }
    }
  }

  /// Says goodbye over a still-open connection, then closes it. Two
  /// independent guards: a throwing teardown must not skip the close.
  /// polo found abandoned sessions accumulating on a radio until it refused
  /// new connections — across a power cycle.
  Future<void> _teardown(_NodeRuntime runtime) async {
    final connection = runtime.connection;
    await _closeSession(runtime);
    if (connection != null) {
      try {
        await connection.close();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'gato:close-connection');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _radio?.removeListener(_onVfoChanged);
    stopDiscovery();
    for (final runtime in _runtimes.values) {
      runtime.cancel?.cancel();
      unawaited(_teardown(runtime));
    }
    _runtimes.clear();
    super.dispose();
  }
}

class _NodeRuntime {
  EquipmentState state = const EquipmentState();
  EquipmentConnection? connection;
  EquipmentSession? session;
  StreamSubscription<Uint8List>? subscription;
  CatCancelToken? cancel;

  /// The last value moved between this node and the app's VFO, in either
  /// direction — the echo guard. Without it an app→radio tune and the
  /// radio's confirmation of it keep re-triggering each other.
  VfoReading? lastSent;

  /// Per-node, deliberately: two overlapping connects to the SAME node race
  /// to own it, and the loser must not install its connection.
  int attemptSeq = 0;
}

class _NodeSink implements EquipmentSink {
  final EquipmentConnection connection;
  final void Function(VfoReading) onReading;

  _NodeSink({required this.connection, required this.onReading});

  @override
  void send(List<int> bytes) => connection.send(bytes);

  @override
  void report(VfoReading reading) => onReading(reading);
}
