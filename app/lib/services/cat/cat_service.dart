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
// nothing now and is a rewrite later. See docs/design/cat.md.

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
import 'vfo_snap.dart';

const _uuidGenerator = Uuid();

/// Bump when the stored shape changes in a way a reader has to know about.
const _storageVersion = 1;

/// Bands where SSB voice conventionally sits on the lower sideband.
/// Everything else is upper — including 60 m, which is channelized USB by
/// international agreement despite being below 10 MHz.
const _lsbBands = {'2190m', '630m', '560m', '160m', '80m', '40m'};

/// How long a connected radio may say NOTHING before the row stops
/// presenting its last reading as current.
///
/// Every driver here either streams (FlexRadio) or polls at a few seconds
/// (CI-V at 5s, the FT-891 adaptively) — so half a minute of total silence
/// from a live connection is not a slow radio, it is a stream that is not
/// carrying anything. Generous enough that a busy rig or a lost datagram
/// never trips it.
const _staleAfter = Duration(seconds: 30);

/// How hard launch tries before leaving it to the user.
const _reconnectRetries = 2;
const _defaultReconnectDelay = Duration(seconds: 3);

/// The floor between automatic reconnect bursts after an unexpected drop.
///
/// Not tuning for its own sake: this radio is on record as getting WORSE when
/// reconnected at speed, so being too eager has a measured cost and being too
/// slow costs one Connect press.
const _autoReconnectCooldown = Duration(seconds: 60);

/// The idle retry: how long to wait before trying the designated radio again
/// while it sits disconnected, and how far to back off when it keeps failing.
///
/// A drop buys one burst (see [_autoReconnectAfterDrop]), and when that burst
/// fails nothing else ever tries — verified on hardware by cutting power to
/// an IC-705 and restoring it: the radio came back and stayed up for two
/// solid minutes while the app sat disconnected, having spent its burst
/// while the radio was still booting. That is the gap this closes.
///
/// It BACKS OFF, because the cost of being eager here is measured. This
/// transport's own notes record that repeated connects make this radio worse —
/// each attempt opens a session it has to track, and three attempts per
/// Connect turned "ignores the login" into "ignores the handshake". A radio
/// that is merely switched off costs nothing to poke; one that is present and
/// refusing is exactly the case that degrades, so the interval doubles until
/// it is only a few attempts an hour.
const _idleRetryFirst = Duration(seconds: 30);
const _idleRetryMax = Duration(minutes: 8);

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

/// [base], or the first `base N` nobody is using yet.
///
/// Pure and top-level so it can be tested without a service, a keychain or a
/// SharedPreferences mock — the same reason `assignWebSerialPortKeys` is its
/// own function.
///
/// The FIRST one is unnumbered: a one-radio shack should read "Icom IC-705",
/// not "Icom IC-705 1". Numbering starts at 2 and skips whatever is taken, so
/// removing the middle of three reuses that number rather than counting ever
/// upward. Comparison ignores surrounding whitespace and case, because two
/// rows differing only in those is the collision this exists to avoid.
String uniqueEquipmentName(String base, Iterable<String> taken) {
  final used = {for (final name in taken) name.trim().toLowerCase()};
  if (!used.contains(base.trim().toLowerCase())) return base;
  // Terminates without needing a bound: every iteration consumes a distinct
  // member of a finite set, so it runs at most `used.length` times. Written
  // this way deliberately — a bounded loop needs a fallback return, and the
  // only value available there is a name already known to be taken, which is
  // the one thing this function exists not to hand back.
  var n = 2;
  while (used.contains('$base $n'.trim().toLowerCase())) {
    n++;
  }
  return '$base $n';
}

class CatService extends ChangeNotifier {
  final SettingsService _settings;
  final EquipmentRegistry registry;

  /// The app's VFO state. [CatService] is its only CAT-origin writer, and it
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

  /// When [_autoReconnectAfterDrop] last let a burst through, so a flapping
  /// radio cannot become a reconnect storm.
  DateTime? _lastAutoReconnect;

  /// The slow retry that runs while the designated radio is disconnected, and
  /// its current backoff. See [_scheduleIdleRetry].
  ///
  /// [idleRetryFirst] is injectable for the same reason [reconnectDelay] is —
  /// a test asserting the loop's DECISIONS should not sit through half a
  /// minute to watch one. It must never be zero: the backoff doubles it, and
  /// zero doubled is still zero, which is a tight loop rather than a retry.
  final Duration idleRetryFirst;
  Timer? _idleRetryTimer;
  late Duration _idleRetryDelay = idleRetryFirst;

  /// Smart VFO Snap's movement tracker and its quiet-period timer. ONE of
  /// each, not one per node: the setting applies to the VFO the app is
  /// driving — `radio1`'s — not separately to every radio in the shack.
  final _snapper = VfoSnapper();
  Timer? _snapTimer;

  /// What stamps each reading for the snapper's speed measurement.
  /// Injectable because how FAST the knob moved is half of what decides the
  /// grid, and a test cannot turn a knob — a `fakeAsync` timer doesn't move
  /// `nowLocal()`, so without this a staged burst always measures as
  /// instantaneous.
  final DateTime Function() now;

  /// Consent-gated analytics hook (HaLoServices.track) for the radio_* events
  /// — optional so tests and standalone use stay silent, same as FlagsService.
  final void Function(String event, [Map<String, Object?> properties])? _onTrack;

  /// Nodes already reported this session, per event. The retry loop below
  /// pokes an unreachable radio every 30s rising to every 8 minutes, for the
  /// whole session — reporting per ATTEMPT would bury every other event and
  /// skew the data toward whoever left a rig switched off.
  final Set<String> _trackedConnected = {};
  final Set<String> _trackedFailed = {};

  CatService(this._settings,
      {EquipmentRegistry? registry,
      RadioService? radio,
      void Function(String event, [Map<String, Object?> properties])? onTrack,
      this.reconnectDelay = _defaultReconnectDelay,
      this.now = realNowUtc,
      this.idleRetryFirst = _idleRetryFirst})
      : assert(idleRetryFirst > Duration.zero, 'a zero first delay makes the backoff a tight loop'),
        registry = registry ?? EquipmentRegistry(),
        _onTrack = onTrack,
        _radio = radio {
    _load();
    _radio?.addListener(_onVfoChanged);
  }

  /// Describes a radio by its CATALOGUE identity only — the variant key (a
  /// stable id we ship), its transport and its driver. Never anything from
  /// the node's config: a serial `port` embeds the adapter's device serial
  /// number on macOS, and the network transports hold addresses and
  /// passwords. See docs/design/telemetry.md.
  void _trackRadio(String event, String typeKey, {Map<String, Object?> extra = const {}}) {
    final track = _onTrack;
    if (track == null) return;
    final type = registry.typeFor(typeKey);
    track(event, {
      'radio': typeKey,
      'transport': type?.transportKey,
      'driver': type?.driver.key,
      ...extra,
    });
  }

  /// A bounded classification, never the exception's text: `'$e'` routinely
  /// carries the port path or host that failed. Matched on the type NAME for
  /// SocketException because dart:io does not exist on web, where this same
  /// service runs over Web Serial.
  static String _failureReason(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error.runtimeType.toString() == 'SocketException') return 'network';
    return 'other';
  }

  /// The baud rate a failed serial attempt was using — deliberately the ONE
  /// config value that goes out. A mismatch is the classic cause of a silent
  /// port, the set of rates is small and fixed, and it identifies nobody.
  Map<String, Object?> _baudExtra(Map<String, dynamic> config) =>
      config['baudRate'] == null ? const {} : {'baud': config['baudRate']};

  /// First failure per node per session only — see [_trackedFailed]. Not
  /// re-armed by a later success on purpose: a flapping rig would otherwise
  /// report on every cycle, which is the volume this de-dup exists to stop.
  /// The question being answered is "does this pairing ever fail for people",
  /// not "how often".
  void _trackFailure(String uuid, String typeKey, String reason, {Map<String, Object?> extra = const {}}) {
    if (!_trackedFailed.add(uuid)) return;
    _trackRadio('radio_connect_failed', typeKey, extra: {'reason': reason, ...extra});
  }

  List<EquipmentNode> get nodes => List.unmodifiable(_nodes.values);

  EquipmentNode? nodeFor(String uuid) => _nodes[uuid];

  // ----------------------------------------------------------- radio1

  /// Which node drives the logging panel — `radio1` in data-model.md's
  /// terms, the transceiver whose VFO is `vfoA`.
  ///
  /// PLAIN STORED STATE. Nothing derives it, and that is the design: three
  /// simple rules, each triggered by something the operator did.
  ///
  ///  * adding a transceiver points it at that transceiver — the newest one
  ///    wins, so a one-radio shack never has to think about it and a
  ///    multi-radio one lands on the rig it just set up;
  ///  * removing the designated node clears it to None, rather than quietly
  ///    moving the logging panel onto a different radio right after a
  ///    destructive action;
  ///  * [setRadio1] is the operator saying so directly, None included.
  ///
  /// Do NOT re-derive it on load (e.g. designating the first transceiver
  /// found whenever the stored value is not valid): a stored None is
  /// indistinguishable from never having chosen, so picking None and
  /// relaunching would hand the VFO back to a rig the operator deliberately
  /// freed for another program. Deriving it would also make a
  /// merely-unloadable record look like None, and let the designation move
  /// between launches if a node's driver key stopped resolving. Storing the
  /// value outright removes that whole class of question.
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
    // Same reasoning for the snapper: a movement measured on the outgoing
    // radio says nothing about where the incoming one is sitting.
    _cancelSnap(null);
    _radio1 = uuid;
    await _save();
    notifyListeners();
  }

  EquipmentState stateFor(String uuid) => _runtimes[uuid]?.state ?? const EquipmentState();

  /// The type handling [node], or null if it isn't in the catalogue — a
  /// record written by a newer build, or by a driver that has since been
  /// removed. The node stays in the list and says so rather than vanishing.
  EquipmentType? typeFor(EquipmentNode node) => registry.typeFor(node.typeKey);

  /// What to call [node] in the UI: the operator's own name for it, or the
  /// type's name, or — a record written by a newer build, or by a driver
  /// that has since been removed — its bare stored typeKey. One place, so
  /// the Station Configuration list and the Radio control agree on it.
  String displayNameFor(EquipmentNode node) {
    if (node.name.isNotEmpty) return node.name;
    return typeFor(node)?.name ?? node.typeKey;
  }

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
    // Read, not derived. A stored uuid whose node did not load — a corrupt
    // record, or one written by a newer build — leaves this None rather than
    // silently designating some other radio.
    final radio1 = stored['radio1'];
    if (radio1 is String && _nodes.containsKey(radio1)) _radio1 = radio1;
  }

  Future<void> _save() => _settings.setStationEquipment({
        'version': _storageVersion,
        // Always, null included, so the blob states what is true rather than
        // leaving None to be inferred from a missing key.
        //
        // NOT load-bearing, and worth saying so: nothing derives radio1, so
        // an absent key and a stored null both read as None — writing
        // `if (_radio1 != null)` would behave identically and fail no test,
        // and that is correct rather than a hole in the tests.
        'radio1': _radio1,
        'nodes': {for (final node in _nodes.values) node.uuid: node.toJson()},
      });

  /// What to call a new node of [typeKey] — the radio's own name, numbered
  /// if the shack already has one.
  ///
  /// The model's name rather than the pairing's: "Icom IC-705", not
  /// "Icom IC-705 — WiFi". How it is connected is already shown by the row's
  /// transport icon and its address, so spelling it into the name too would
  /// say the same thing three times — and the name outlives the choice,
  /// since the transport can be changed in the editor afterwards.
  String suggestedNameFor(String typeKey) => uniqueEquipmentName(
        registry.typeFor(typeKey)?.model.name ?? typeKey,
        _nodes.values.map((node) => node.name),
      );

  Future<EquipmentNode> addNode({
    required String typeKey,
    String name = '',
    Map<String, dynamic> config = const {},
    /// How the operator got here: `discovery` when the Add dialog found the
    /// radio itself, `manual` when they filled the form. The gap between
    /// these and radio_connected is what says a pairing is configurable but
    /// not usable.
    String via = 'manual',
  }) async {
    final node = EquipmentNode(
      uuid: _uuidGenerator.v4(),
      typeKey: typeKey,
      // Named here rather than only in the editor, because the editor is not
      // the only way in: `addDiscovered` goes straight to this method, and a
      // radio that announced itself under a blank name would list as nothing
      // but its type.
      name: name.trim().isEmpty ? suggestedNameFor(typeKey) : name,
      config: config,
    );
    final stored = await _stashSecrets(node);
    _nodes[stored.uuid] = stored;
    // The newest transceiver takes the VFO. Only transceivers: radio1 is the
    // rig whose VFO is vfoA, and the category system exists so a rotator or a
    // relay board added later cannot take it.
    if (registry.typeFor(stored.typeKey)?.category == kCategoryTransceiver) _radio1 = stored.uuid;
    await _save();
    _trackRadio('radio_added', stored.typeKey, extra: {'via': via});
    notifyListeners();
    return stored;
  }

  Future<void> updateNode(EquipmentNode node) async {
    final previous = _nodes[node.uuid];
    if (previous == null) return;
    // Re-typing a node — the operator switching the same radio from WiFi to
    // USB — replaces both its transport and its driver, and a live runtime
    // holds a session the OLD driver built over a connection the OLD
    // transport opened. Neither can be handed to the new pairing, so the
    // connection goes first and the operator reconnects.
    //
    // Only on a type change. An edited host or baud rate leaves the pairing
    // intact, and disconnecting for those would drop a working radio every
    // time its name was corrected.
    if (previous.typeKey != node.typeKey) await disconnect(node.uuid);
    _nodes[node.uuid] = await _stashSecrets(node);
    await _save();
    notifyListeners();
  }

  /// Moves secret fields out of the config and into the platform keychain.
  /// The stored config is a plain SharedPreferences JSON blob — the right
  /// home for a hostname, the wrong one for a radio password.
  ///
  /// Asks the whole CATALOGUE what counts as a secret, not this node's own
  /// pairing. The editor renders every variant's fields at once, so a node
  /// bound to a transport with no secrets of its own still arrives here
  /// carrying the password belonging to the transport beside it — an IC-705
  /// switched from WiFi to USB is exactly that. Scoped to the node's pairing,
  /// this method hands that password straight to the prefs blob in clear.
  Future<EquipmentNode> _stashSecrets(EquipmentNode node) async {
    final secretKeys = registry.allSecretFields;
    if (secretKeys.isEmpty) return node;

    final cleaned = <String, dynamic>{};
    for (final entry in node.config.entries) {
      if (secretKeys.contains(entry.key)) {
        // An empty value means "unchanged" — the editor shows secrets
        // blank, so saving a form without retyping must not wipe them.
        final value = entry.value as String? ?? '';
        if (value.isNotEmpty) {
          final stored = await _settings.setEquipmentSecret(node.uuid, entry.key, value);
          // The keychain refused it — a locked keyring, a headless box.
          // Neither silent option is acceptable: dropping the value loses
          // the password entirely behind a save that looked like it worked,
          // and keeping it in `cleaned` writes a password into the plain
          // prefs blob the user has every reason to think it is NOT in.
          // So fail the save out loud instead.
          if (!stored) throw const EquipmentSecretNotStored();
        }
      } else {
        cleaned[entry.key] = entry.value;
      }
    }
    return node.copyWith(config: cleaned);
  }

  /// What THIS pairing needs to open its connection — narrower than
  /// [EquipmentRegistry.allSecretFields], and deliberately so: injecting
  /// every catalogue secret into a connect-time config would hand a serial
  /// driver an empty `password` key it never asked for.
  Set<String> _secretFieldsFor(String typeKey) => registry.typeFor(typeKey)?.secretFields ?? const {};

  /// Which of a node's secret fields have something stored — the field KEYS,
  /// never the values.
  ///
  /// The editor needs to show that a password exists without ever loading it
  /// into a form: a form's values get written back on save, and the whole
  /// point of [_stashSecrets] is that a secret never travels in the config
  /// blob. So the editor asks which fields are populated and renders a
  /// placeholder, and an untouched field still submits empty — which
  /// [_stashSecrets] reads as "unchanged".
  Future<Set<String>> storedSecretFields(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return const {};
    final stored = <String>{};
    // Catalogue-wide, because the editor renders every variant's fields: a
    // password stored while the node was on WiFi has to show its placeholder
    // when the operator switches back to it, whatever the node is bound to
    // right now. Reporting only the current pairing's shows an empty box
    // beside a password that is still in force.
    for (final field in registry.allSecretFields) {
      final value = await _settings.equipmentSecret(uuid, field);
      if (value != null && value.isNotEmpty) stored.add(field);
    }
    return stored;
  }

  /// The node's config with its secrets read back in — only ever built at
  /// connect time, never stored.
  Future<Map<String, dynamic>> _configWithSecrets(EquipmentNode node) async {
    final secretKeys = _secretFieldsFor(node.typeKey);
    if (secretKeys.isEmpty) return node.config;
    final merged = <String, dynamic>{...node.config};
    for (final field in secretKeys) {
      merged[field] = await _settings.equipmentSecret(node.uuid, field) ?? '';
    }
    return merged;
  }

  Future<void> removeNode(String uuid) async {
    await disconnect(uuid);
    // The keychain entry outlives the prefs blob unless we say otherwise —
    // and catalogue-wide, since a node re-typed away from the pairing that
    // stored a secret would otherwise leave it behind with nothing left that
    // could ever name it.
    for (final field in registry.allSecretFields) {
      await _settings.setEquipmentSecret(uuid, field, null);
    }
    _nodes.remove(uuid);
    _runtimes.remove(uuid);
    // Removing the designated radio clears the choice rather than quietly
    // moving the logging panel onto a different rig immediately after a
    // destructive action. The dropdown is right there.
    if (_radio1 == uuid) _radio1 = null;
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
      final stream = type.discover();
      if (stream == null) continue;
      _discoverySubscriptions.add(stream.listen(
        (found) {
          _discovered[_discoveryKey(found)] = found;
          notifyListeners();
        },
        onError: (Object e, StackTrace st) {
          ErrorReportingService.report(e, st, context: 'cat:discovery:${type.key}');
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
      addNode(typeKey: found.typeKey, name: found.name, config: found.config, via: 'discovery');

  // -------------------------------------------------------------- runtime

  _NodeRuntime _runtimeFor(String uuid) => _runtimes.putIfAbsent(uuid, _NodeRuntime.new);

  void _setState(String uuid, EquipmentState state) {
    if (_disposed) return;
    _runtimeFor(uuid).state = state;
    notifyListeners();
  }

  Future<void> connect(String uuid) {
    // Asking for it back cancels a previous Disconnect, so the idle retry may
    // resume looking after this node.
    _runtimeFor(uuid).userDisconnected = false;
    // The backoff belongs to the designated radio's loop, so only that radio's
    // Connect may reset it. Done unconditionally, connecting a SECOND rig
    // would drag radio1's wait from eight minutes back to thirty seconds — an
    // unrelated action re-entering the eager-poking regime the backoff exists
    // to avoid.
    if (isRadio1(uuid)) _idleRetryDelay = idleRetryFirst;
    return _connect(uuid);
  }

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
      _trackFailure(uuid, node.typeKey, 'unknown_type');
      return _ConnectOutcome.failed;
    }

    final config = await _configWithSecrets(node);

    final invalid = type.validate(config);
    if (invalid != null) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: invalid));
      _trackFailure(uuid, node.typeKey, 'invalid_config', extra: _baudExtra(config));
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
      connection = await transport.connect(type.targetFor(config), cancel: cancel);
    } on CatCancelledException {
      // A newer connect (or a disconnect) owns this node now — not a
      // failure, and not ours to report.
      return _ConnectOutcome.superseded;
    } catch (e, st) {
      if (attempt != runtime.attemptSeq) return _ConnectOutcome.superseded;
      // Wrapped for the report only: ErrorPolicy needs to know a bare
      // SocketException came from a connect attempt before it can keep a
      // switched-off rig out of the backend. The state below keeps the
      // underlying error's own words, which is what the operator reads.
      ErrorReportingService.report(CatConnectFailure(node.typeKey, e), st, context: 'cat:connect');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: '$e'));
      _trackFailure(uuid, node.typeKey, _failureReason(e), extra: _baudExtra(config));
      return _ConnectOutcome.failed;
    }

    if (attempt != runtime.attemptSeq) {
      // Superseded while the handshake was running. Don't resurrect a
      // connection nothing is expecting any more — just close it, or it
      // leaks (the exact bug polo's attempt sequence was added to fix).
      unawaited(connection.close());
      return _ConnectOutcome.superseded;
    }

    final sink = _NodeSink(
      connection: connection,
      onReading: (reading) {
        // A session from a superseded connection must not write state.
        if (runtime.connection != connection) return;
        _applyReading(uuid, reading);
      },
      onDiagnostic: (note) {
        // Same guard, same reason: a superseded session's account of itself
        // is about a connection nobody is looking at any more.
        if (runtime.connection != connection) return;
        // Deduped HERE rather than in the driver, because this is what holds
        // the value: a driver remembering what it last said would be wrong
        // the moment a status transition replaced the state underneath it,
        // and every driver would have to remember separately.
        if (stateFor(uuid).diagnostic == note) return;
        _setState(uuid, stateFor(uuid).copyWith(diagnostic: note, clearDiagnostic: note == null));
      },
    );
    // driverConfig, not config: a type may know something about its
    // protocol that is not a setting anyone should be asked for — the
    // IC-705's network controller address, for one.
    final session = type.driver.createSession(sink, type.driverConfig(config));

    runtime.connection = connection;
    runtime.session = session;
    runtime.subscription = connection.data.listen((chunk) {
      try {
        session.handleData(chunk);
      } catch (e, st) {
        // One malformed frame must not kill the connection.
        ErrorReportingService.report(e, st, context: 'cat:handle-data:${type.driver.key}');
      }
    });

    unawaited(connection.closed.then((_) {
      // A stale connection's close must not clobber a live one's status.
      if (runtime.connection != connection) return;
      // NOTE on deliberate disconnects: there is no guard for them here, and
      // none is needed. _teardown calls _closeSession FIRST, which sets
      // runtime.connection = null, and only then closes the connection — so a
      // disconnect the operator asked for exits at the guard above and never
      // reaches this line. A `status == disconnecting` check here would be
      // dead code for the same reason. If teardown's ordering ever changes,
      // the test 'a DELIBERATE disconnect is never undone' is what will
      // catch it.
      // The driver keeps its own timers (FlexRadio resyncs every 60s, the
      // CI-V drivers poll every 5s). Dropping the session without tearing
      // it down leaves them ticking for the life of the process — once per
      // drop — each one retaining its sink and this dead connection.
      unawaited(_closeSession(runtime));
      _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
      _autoReconnectAfterDrop(uuid);
      // And keep trying slowly afterwards, in case that burst is spent before
      // the radio is back.
      //
      // Unconditional on purpose. An `isRadio1(uuid)` guard here would be
      // dead code: [_scheduleIdleRetry] reads _radio1 itself and stops on
      // the first tick if that radio is connected or absent, so the guard
      // could not change any outcome. One place decides, and it is the loop.
      _scheduleIdleRetry();
    }));

    _setState(uuid, const EquipmentState(status: EquipmentStatus.connected));
    if (_trackedConnected.add(uuid)) _trackRadio('radio_connected', node.typeKey);
    _armStaleWatch(uuid, runtime);

    // Start updates on connect rather than when a UI subscriber shows up:
    // polo gated this on a refcount, so connecting with no screen mounted
    // succeeded and then never asked the radio anything.
    try {
      session.startUpdates();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:start-updates:${type.driver.key}');
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
  /// Keeps trying the designated radio, slowly, while it sits disconnected.
  ///
  /// [_autoReconnectAfterDrop] handles the moment a live session dies. This
  /// handles everything after: a radio that was switched off, or was still
  /// booting when that burst was spent, or that refused because another client
  /// held it. A real gap, verified on hardware — see [_idleRetryFirst].
  ///
  /// Three things keep it from becoming the bug it is meant to fix:
  ///
  ///  * it never touches a node the operator switched off — [disconnect]
  ///    records that, and only [connect] clears it;
  ///  * it only ever looks at the designated radio, so a station full of
  ///    equipment does not generate traffic nobody asked for. With no radio
  ///    designated (None) it does nothing at all;
  ///  * it backs off to [_idleRetryMax]. This radio measurably degrades when
  ///    reconnected at speed, so a rig that is present and refusing must not
  ///    be poked on a fixed short cycle.
  void _scheduleIdleRetry() {
    if (_disposed) return;
    _idleRetryTimer?.cancel();
    _idleRetryTimer = Timer(_idleRetryDelay, () {
      if (_disposed) return;
      final uuid = _radio1;
      final runtime = uuid == null ? null : _runtimes[uuid];
      final status = uuid == null ? null : stateFor(uuid).status;

      // STOP only for a reason that will not resolve itself: there is nothing
      // designated, the node is gone, the operator switched it off, or it is
      // already connected. connect/disconnect and a dropped session restart it.
      final settled = uuid == null ||
          !_nodes.containsKey(uuid) ||
          (runtime?.userDisconnected ?? false) ||
          status == EquipmentStatus.connected;
      if (settled) {
        _idleRetryTimer = null;
        return;
      }

      // WAIT, without counting it as an attempt, while something else is
      // mid-flight. Only these two mean "in progress"; `error` is a FAILED
      // attempt and is exactly what we are here to retry.
      //
      // Both tempting simplifications are wrong. Treating `connecting` as
      // nothing-to-do and STOPPING shuts the loop down permanently when the
      // drop burst is still in flight on the first tick — reintroducing the
      // gap this exists to close. Waiting on anything that is not
      // `disconnected` includes `error`, so after the first failure it would
      // wait for ever and never retry at all.
      if (status == EquipmentStatus.connecting || status == EquipmentStatus.disconnecting) {
        _scheduleIdleRetry();
        return;
      }

      // Double first, so a failure that arrives after this fire still leaves
      // the next wait longer than this one.
      _idleRetryDelay = _idleRetryDelay * 2 > _idleRetryMax ? _idleRetryMax : _idleRetryDelay * 2;
      unawaited(_connect(uuid).then((outcome) {
        if (outcome == _ConnectOutcome.connected) {
          _idleRetryDelay = idleRetryFirst;
          // CANCEL, not just forget. There is an async gap above while the
          // connect runs, and _scheduleIdleRetry may have been called during
          // it — a drop on any node calls it. Nulling alone would leave that
          // timer pending and unreachable: dispose() could no longer stop it,
          // and if the radio drops again before it fires it runs a second
          // retry chain alongside the real one, doubling the connect rate
          // against the radio whose backoff exists to prevent exactly that.
          _idleRetryTimer?.cancel();
          _idleRetryTimer = null;
          return;
        }
        _scheduleIdleRetry();
      }));
    });
  }

  /// When the designated radio's connection dies on its own, try to get it
  /// back — once, and then leave it alone.
  ///
  /// The radio can end a session without us doing anything wrong: it says so
  /// with an 0x50 (see the Icom transport, which listens for that), or it
  /// simply stops answering. Without this, the row goes disconnected and stays
  /// there until the operator notices and presses Connect — a poor answer from
  /// a logger whose job is to follow the VFO.
  ///
  /// DELIBERATELY TIMID, for a reason recorded in hardware terms.
  /// IcomNetworkTransport.connect documents that retrying a refused login
  /// makes this radio WORSE: every attempt opens a session it must track, and
  /// measured on hardware, three attempts per Connect turned "ignores the
  /// login" into "ignores the handshake". app-polo's auto-reconnect also ended
  /// up fighting the user's own Connect (see [_ConnectOutcome]). So:
  ///
  ///  * only the designated radio, the one the logging panel depends on;
  ///  * never after a deliberate Disconnect;
  ///  * at most one burst per [_autoReconnectCooldown], so a flapping radio —
  ///    or a second client holding its only session slot — gets a few attempts
  ///    a minute rather than a storm.
  ///
  /// [reconnectDesignatedRadio] supplies the retry policy; this only decides
  /// whether it may run at all.
  void _autoReconnectAfterDrop(String uuid) {
    if (_disposed || !isRadio1(uuid)) return;
    final last = _lastAutoReconnect;
    // Real time: this cooldown rate-limits real reconnect attempts against a
    // real radio, so a rescaled clock would let a storm through.
    final now = realNowUtc();
    if (last != null && now.difference(last) < _autoReconnectCooldown) {
      debugPrint('[cat] auto-reconnect suppressed: last was ${now.difference(last).inSeconds}s ago');
      return;
    }
    _lastAutoReconnect = now;
    unawaited(reconnectDesignatedRadio());
  }

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

      if (attempt == _reconnectRetries) break;
      await Future<void>.delayed(reconnectDelay);
    }

    // The burst is spent and the radio still is not there, so hand over to the
    // slow loop. Without this, main.dart's boot call meant three attempts in a
    // few seconds and then silence for the rest of the session: the loop was
    // only ever started by a drop, and at boot nothing has dropped. That is the
    // same gap the loop exists to close, on the one path most likely to hit it
    // — the operator switches the rig on after the app, not before.
    //
    // Only reached when the burst EXHAUSTED. Connected, superseded and disposed
    // all return above, because in each of those cases something else is
    // already driving this node.
    _scheduleIdleRetry();
  }

  Future<void> disconnect(String uuid) async {
    final runtime = _runtimes[uuid];
    if (runtime == null) return;
    // Recorded BEFORE the teardown, because the retry loop reads it later and
    // has no other way to tell this from a radio that vanished.
    runtime.userDisconnected = true;
    runtime.cancel?.cancel();
    runtime.cancel = null;
    // Bump the sequence so an attempt still in flight knows it lost.
    runtime.attemptSeq += 1;
    // Said before the teardown, not after: the Icom network goodbye alone is
    // most of a second of deliberately spaced datagrams, and a row that
    // still claims to be connected through all of it reads as a hang.
    _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnecting));
    await _teardown(runtime);
    _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
  }

  /// Closes every live session and **waits for it**, for use when the app is
  /// about to stop existing.
  ///
  /// This is not tidiness. A session the radio is never told to end is one it
  /// keeps holding: the IC-705 has a single remote-control slot and holds the
  /// login until it times out on its own, so quitting without a disconnect is
  /// what makes the NEXT connect fail.
  ///
  /// It is NOT about an audio flood: measured on hardware, the radio only
  /// streams audio to a client that completes a session handshake on port
  /// 50003, which we never do — so quitting without a disconnect leaves no
  /// stray audio stream, only the held session slot above.
  ///
  /// [dispose] cannot serve this purpose: it is synchronous and leaves the
  /// teardown unawaited, so the process can exit before the datagrams are
  /// even sent.
  Future<void> shutdown() async {
    // A copy: disconnect mutates state the iteration would otherwise be
    // walking, and a node may remove itself on the way down.
    for (final uuid in _runtimes.keys.toList()) {
      try {
        await disconnect(uuid);
      } catch (e, st) {
        // Never let one stuck radio keep the others connected — every one of
        // them is streaming at us.
        ErrorReportingService.report(e, st, context: 'cat:shutdown:$uuid');
      }
    }
  }

  /// Restarts the silence watch. Any reading at all counts, including one
  /// that repeats the last: a radio answering "still 14074" is a radio that
  /// is answering.
  void _armStaleWatch(String uuid, _NodeRuntime runtime) {
    runtime.staleTimer?.cancel();
    runtime.staleTimer = Timer(_staleAfter, () {
      if (_disposed) return;
      final current = _runtimes[uuid];
      if (current == null || current.state.status != EquipmentStatus.connected) return;
      if (current.state.stale) return;
      _setState(uuid, current.state.copyWith(stale: true));
    });
  }

  void _applyReading(String uuid, VfoReading reading) {
    final runtime = _runtimeFor(uuid);
    // The radio said something, so it is not silent — whatever it said.
    _armStaleWatch(uuid, runtime);
    if (runtime.state.stale) _setState(uuid, runtime.state.copyWith(stale: false));
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? runtime.state.vfo.freqKHz,
      mode: reading.mode ?? runtime.state.vfo.mode,
    );
    // A radio echoing back what it already reported shouldn't churn this
    // service's own listeners — but it must still reach RadioService.
    //
    // Returning here instead would be a permanent desync: pick a band (or
    // clear the frequency field) and vfoA.freq goes null while the radio has
    // not moved, so every later report matches this cache and is swallowed.
    // The panel then shows a band with no frequency, and logs QSOs with it,
    // until the operator physically turns the knob. RadioService.setVfo
    // does its own no-op check, so forwarding unconditionally is free.
    if (merged != runtime.state.vfo) _setState(uuid, runtime.state.copyWith(vfo: merged));

    // Only the designated radio drives the app's VFO. Tagging the write
    // `radio` is what lets _onVfoChanged recognise the notification it's
    // about to receive as its own, instead of re-tuning the radio to the
    // value the radio just gave it.
    if (uuid != _radio1) return;
    runtime.lastSent = merged;
    _radio?.setVfo('vfoA', freq: merged.freqKHz, mode: merged.mode, origin: VfoOrigin.radio);
    _noteSnapReading(merged);
  }

  // ------------------------------------------------- smart VFO snap
  //
  // The knob's own moves, rounded to a sensible number once the operator
  // stops turning (docs/design/cat.md § Smart VFO Snap). The rules live in
  // vfo_snap.dart; what is here is when to ask them.

  /// Feeds `radio1`'s reading to the snapper and re-arms the quiet period.
  ///
  /// Phone only, and checked on every reading rather than once: a radio
  /// switched from SSB to CW mid-burst must abandon the burst, not settle it
  /// under the old mode. CW and data operators tune to exact frequencies and
  /// snapping under them would be the app moving the rig off a signal.
  void _noteSnapReading(VfoReading reading) {
    final freqKHz = reading.freqKHz;
    if (!_settings.smartVfoSnap || freqKHz == null || superModeForMode(reading.mode) != 'Phone') {
      _cancelSnap(freqKHz);
      return;
    }
    if (!_snapper.report(freqKHz, now())) return;
    _snapTimer?.cancel();
    // Read per reading, not cached: the operator tuning this setting is
    // turning the knob to feel the difference, and a cached period would make
    // the change take effect only after a reconnect.
    _snapTimer = Timer(_snapQuietPeriod, _settleSnap);
  }

  /// How long the VFO must hold still before [_settleSnap] believes it.
  ///
  /// The operator's setting is how long a SETTLED VFO should sit before the
  /// app acts. On a polling session that is not the same as how long the app
  /// must wait: between polls no readings arrive whether the dial is still or
  /// spinning, so the first poll period carries no information at all. Adding
  /// it means the delay always measures silence we could have heard something
  /// in — and a pushing session (`expectedUpdateInterval` null) adds nothing,
  /// because there every quiet millisecond is evidence.
  ///
  /// Read at arming time, from the cadence in force DURING the movement —
  /// AdaptivePoller is at its fast interval then, having just seen a change.
  /// Re-reading it later would chase the back-off the moment the dial stops.
  Duration get _snapQuietPeriod {
    final configured = _settings.smartVfoSnapDebounce;
    final expected = _runtimes[_radio1]?.session?.expectedUpdateInterval;
    return expected == null ? configured : configured + expected;
  }

  /// Abandons any pending snap and takes [freqKHz] as the new resting point.
  /// For everything that is not the knob turning: a typed frequency, a spot,
  /// a session ending, the setting going off.
  void _cancelSnap(double? freqKHz) {
    _snapTimer?.cancel();
    _snapTimer = null;
    _snapper.rebase(freqKHz);
  }

  /// The VFO held still long enough. Retunes the radio if the movement
  /// earned a snap.
  void _settleSnap() {
    _snapTimer = null;
    final target = _snapper.settle(VfoSnapTuning(
      longMoveKHz: _settings.smartVfoSnapLongMoveKHz,
      minMoveKHz: _settings.smartVfoSnapMinMoveKHz,
      minSpeedKHzPerSec: _settings.smartVfoSnapMinSpeed,
    ));
    // Settled first, so the movement is consumed either way: switching the
    // setting off during a turn must not leave a burst behind to be settled
    // by whatever reading follows it being switched back on.
    if (target == null || _disposed || !_settings.smartVfoSnap) return;
    // Written as the OPERATOR, deliberately: the snap is a decision about
    // where they meant to be, so it takes the same path a typed frequency
    // does — RadioService notifies, [_onVfoChanged] tunes the radio. Tagging
    // it `radio` would leave the app showing a frequency the rig is not on.
    _radio?.setVfo('vfoA', freq: target);
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
    // Whatever the operator just stated — typed, picked, or tapped from a
    // spot — is exact intent and is where the next knob turn is measured
    // from. Any snap still pending was decided against a frequency nobody is
    // on any more. (Our OWN snap arrives here too, harmlessly: it rebases to
    // the value the snapper already settled on.)
    _cancelSnap(radio.vfoA.freq);

    final uuid = _radio1;
    if (uuid == null) return;
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    if (session == null) {
      // The operator is working the controls of a radio that is not there.
      // That is the clearest signal we get that they want it back, so pull the
      // idle retry down off its ceiling — otherwise someone actively using the
      // app can sit up to [_idleRetryMax] with nothing visibly trying.
      //
      // Deliberately NOT a connect attempt. The tune would be lost either
      // way — connecting is async and this call is long gone by the time a
      // session exists — and then `startUpdates` polls the radio, so the
      // radio's own frequency would overwrite what was just typed: the app
      // visibly undoing the operator. It would also put a connect behind every
      // keystroke, and repeated connects are what this radio degrades on.
      //
      // The condition is load-bearing twice over, and is deliberately the ONLY
      // one. Tuning faster than the retry interval would otherwise re-arm the
      // timer on every keystroke and the loop would never fire at all — and at
      // rest the delay sits at its floor, so tuning cannot start dialling a
      // radio nobody has switched on.
      //
      // An `_idleRetryTimer != null` guard here would be dead code, like the
      // guards discussed in the drop handler and [_scheduleIdleRetry].
      // Reaching a null timer with a backed-off delay means the loop settled,
      // and every reason it settles — node gone, nothing designated, switched
      // off by hand, or connected — either returns above or settles the new
      // loop again before it can attempt anything.
      if (_idleRetryDelay != idleRetryFirst) {
        _idleRetryDelay = idleRetryFirst;
        _scheduleIdleRetry();
      }
      return;
    }

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
      ErrorReportingService.report(e, st, context: 'cat:set-vfo-on-radio');
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
    runtime.staleTimer?.cancel();
    runtime.staleTimer = null;
    // The echo guard describes what THIS session was told. Carrying it into
    // the next connection would suppress the first tune to a frequency the
    // previous session happened to be on, leaving the app and a
    // freshly-reconnected radio silently disagreeing.
    runtime.lastSent = null;
    // A pending snap belongs to the session that reported the movement. It
    // has nowhere to be sent now, and the next session's first reading is a
    // fresh resting point, not the continuation of a knob turn. Only for the
    // designated radio — nothing else ever feeds the snapper, and clearing it
    // when some other node disconnects would drop a live knob turn.
    if (_radio1 != null && identical(_runtimes[_radio1], runtime)) _cancelSnap(null);

    if (subscription != null) await subscription.cancel();

    if (session != null) {
      try {
        session.teardown();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:teardown-session');
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
        ErrorReportingService.report(e, st, context: 'cat:close-connection');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _radio?.removeListener(_onVfoChanged);
    // Cancelled, not merely guarded: the callback checks _disposed, but a
    // pending timer can still sit scheduled for minutes, and a test harness
    // will rightly complain about one outliving its service.
    _idleRetryTimer?.cancel();
    _idleRetryTimer = null;
    _snapTimer?.cancel();
    _snapTimer = null;
    stopDiscovery();
    for (final runtime in _runtimes.values) {
      runtime.cancel?.cancel();
      unawaited(_teardown(runtime));
    }
    _runtimes.clear();
    super.dispose();
  }
}

/// A credential could not reach the platform keychain, so the save was
/// abandoned rather than completed in a way that either loses the password
/// or writes it in plaintext.
class EquipmentSecretNotStored implements Exception {
  const EquipmentSecretNotStored();

  @override
  String toString() =>
      "Could not save the radio's password to the system keychain. It may be "
      'locked, or unavailable on this machine.';
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

  /// Watches for a connection that is up but saying nothing — see
  /// [EquipmentState.stale].
  Timer? staleTimer;

  /// The operator pressed Disconnect. Distinct from every other route to
  /// `disconnected`, and the distinction is the whole safety of the idle
  /// retry: without it, "off because I said so" and "off because the radio
  /// vanished" are the same state, and a retry loop would keep switching the
  /// radio back on under the operator. app-polo's auto-reconnect did exactly
  /// that. Cleared by [connect], so asking for it again resumes retrying.
  bool userDisconnected = false;
}

class _NodeSink implements EquipmentSink {
  final EquipmentConnection connection;
  final void Function(VfoReading) onReading;
  final void Function(String?) onDiagnostic;

  _NodeSink({required this.connection, required this.onReading, required this.onDiagnostic});

  @override
  void send(List<int> bytes) => connection.send(bytes);

  @override
  void report(VfoReading reading) => onReading(reading);

  @override
  void reportDiagnostic(String? note) => onDiagnostic(note);
}
