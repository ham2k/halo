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

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:uuid/uuid.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../error_reporting_service.dart';
import '../hang_watchdog.dart';
import '../peer/peer_station_radios.dart';
import '../radio_service.dart';
import '../settings_service.dart';
import 'auto_connect_guard.dart';
import 'cat_keying.dart';
import 'cat_ptt.dart';
import 'cat_traffic_log.dart';
import 'connect_failure.dart';
import 'equipment_tag.dart';
import 'radio_proof.dart';
import 'spectrum.dart';
import 'transports/k4_shared_connection.dart';
import 'transports/k4_remote_transport.dart';
import 'drivers/kenwood_driver.dart' show KenwoodDriver;
import 'discovery.dart';
import 'driver.dart';
import 'drivers/meter_calibration.dart';
import 'drivers/sdr_spectrum.dart' show SdrSink;
import 'drivers/cw_send_queue.dart' show CwSendProgress;
import 'equipment.dart';
import 'keyer_repeat.dart';
import 'main_vfo.dart';
import 'peer_keying.dart';
import 'equipment_registry.dart';
import 'transport.dart';
import 'vfo_snap.dart';

// The keyer area names a wait; it reads everything else about keying off
// this service, so the type comes with it rather than through a second
// import of an implementation file.
export 'keyer_repeat.dart' show KeyerRepeatWait;
export 'main_vfo.dart';

part 'cat_node_sink.dart';
part 'cat_spectrum.dart';
part 'cat_node_runtime.dart';
part 'cat_radio_controls.dart';
part 'cat_discovery.dart';
part 'cat_vfo_snap.dart';
part 'cat_k4.dart';
part 'cat_credentials.dart';

const _uuidGenerator = Uuid();

/// Bump when the stored shape changes in a way a reader has to know about.
///
/// 2 — `designated` became per radio (radio → category → uuid). Version 1's
/// blob is one flat category → uuid map, and [CatService._load] migrates it.
///
/// 3 — the two `radio1` / `remoteRadio1` keys became one `mainVfo`, holding
/// whichever kind of radio was picked. Older blobs are read from the old
/// pair by [CatService._load].
const _storageVersion = 3;

/// How long a connected node may say NOTHING before the row stops
/// presenting its last reading as current ([EquipmentState.stale]).
///
/// The invariant every driver must hold: a connected node is heard from at
/// least this often. A polling driver holds it by polling (CI-V at 5 s, the
/// FT-891 adaptively). A push-on-change driver — FlexRadio, the Antenna
/// Genius, a WinKeyer — is silent for as long as nothing moves, and is
/// responsible for generating the word itself: a resync inside this window
/// whose reply is a reading, or a ping whose acknowledgement goes to
/// [EquipmentSink.reportAlive]. Public so those drivers' tests can assert
/// their cadence sits inside it, rather than against a literal that drifts.
///
/// Generous enough that a busy rig or a lost datagram never trips it.
const catStaleAfter = Duration(seconds: 30);

/// How long either auto-connect mark may take to reach disk.
///
/// Bounded like the quit path's own breadcrumb (main.dart's `_markBudget`), and
/// for the same reason: a wedged platform channel must not hang in FRONT of the
/// thing the mark describes.
const _markBudget = Duration(seconds: 2);

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

  /// The previous launch was in the middle of connecting this node when it
  /// stopped existing, so nothing automatic goes near it until the operator
  /// asks for it by hand (auto_connect_guard.dart). Also not a failure, and
  /// for the same reason not ours to retry: retrying is precisely what turns
  /// one wedged port into an app that will not start.
  held,

  /// No port or address yet: nothing to try until the operator gives one.
  unconfigured,
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

class CatService extends ChangeNotifier with _RadioControls, _Discovery, _VfoSnap implements PeerStationRadios, KeyingStation {
  @override
  final SettingsService _settings;
  @override
  final EquipmentRegistry registry;

  /// The app's VFO state. [CatService] is its only CAT-origin writer, and it
  /// listens for everyone else's writes so it can retune the radio.
  /// Optional so tests that only exercise equipment config can omit it.
  @override
  final RadioService? _radio;

  /// Configured equipment, in the order it was added.
  @override
  final Map<String, EquipmentNode> _nodes = {};

  /// Live per-node connection state. Never persisted.
  @override
  final Map<String, _NodeRuntime> _runtimes = {};
  late final _k4Connections = K4SharedConnectionPool(onSend: _logK4Sent, onReceive: _logK4Received);

  /// Set by [dispose]. The reconnect loop parks on an uncancellable delay,
  /// so it can outlive the service and must check before touching it again.
  @override
  bool _disposed = false;

  /// How long [reconnectDesignatedRadio] waits between attempts. Tests pass
  /// [Duration.zero] rather than sleeping through it for real.
  final Duration reconnectDelay;

  /// How long an SDR stays connected after the last display leaves it — long
  /// enough that switching dock tabs does not reconnect it.
  final Duration sdrIdleRelease;

  /// How long an SDR a display waits on is left between failed connects.
  /// Its own value rather than [reconnectDelay], which tests zero: a display
  /// left open on a server that is not there would retry in a tight loop.
  final Duration sdrRetryDelay;

  /// When [_autoReconnectAfterDrop] last let a burst through, so a flapping
  /// radio cannot become a reconnect storm.
  /// Per node: radio1 and the keyer flap independently.
  final _lastAutoReconnect = <String, DateTime>{};

  /// The slow retry that runs while the designated radio is disconnected, and
  /// its current backoff. See [_scheduleIdleRetry].
  ///
  /// [idleRetryFirst] is injectable for the same reason [reconnectDelay] is —
  /// a test asserting the loop's DECISIONS should not sit through half a
  /// minute to watch one. It must never be zero: the backoff doubles it, and
  /// zero doubled is still zero, which is a tight loop rather than a retry.
  final Duration idleRetryFirst;

  /// How long a connected node may say nothing before it is marked
  /// [EquipmentState.stale]. Injectable for the same reason [reconnectDelay]
  /// is: a test asserting what feeds the watchdog should not sit through
  /// half a minute to watch it.
  final Duration staleAfter;

  Timer? _idleRetryTimer;
  late Duration _idleRetryDelay = idleRetryFirst;

  /// What stamps each reading for the snapper's speed measurement.
  /// Injectable because how FAST the knob moved is half of what decides the
  /// grid, and a test cannot turn a knob — a `fakeAsync` timer doesn't move
  /// `nowLocal()`, so without this a staged burst always measures as
  /// instantaneous.
  @override
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

  /// The nodes nothing automatic may connect this launch, because the previous
  /// launch was in the middle of connecting them when it stopped existing
  /// (auto_connect_guard.dart).
  ///
  /// A SNAPSHOT of what the last process left, taken lazily — but always
  /// before this one writes a mark of its own, since every write below is
  /// reached through a read of this set. Consulting preferences live instead
  /// would answer "held" for a connect that is merely in flight right now, and
  /// the idle retry would then treat a node it is actively connecting as one
  /// that has settled.
  late final Set<String> _autoConnectHeld = autoConnectMarks(_settings.prefs).toSet();

  /// How many automatic connects are inside a call for each node right now.
  ///
  /// A COUNT, not a flag, because the mark on disk is one bit for a node and
  /// two attempts on that node can overlap: `_connect` sets `connecting` only
  /// after an await or two, so the guards that read that status let a second
  /// attempt start, supersede the first, and then watch the first's `finally`
  /// erase the mark out from under the attempt that is actually inside the FFI
  /// call. Clearing at zero, and marking only on the way from zero, keeps the
  /// mark's meaning: something is in there.
  final Map<String, int> _autoConnectInFlight = {};

  /// Called when a deliberate Connect lifts a hold, so whoever told the
  /// operator to press it can take that notice down. Set by main.dart; null in
  /// tests and standalone use.
  void Function()? onAutoConnectHoldLifted;

  /// Called the first time in a session that a node's radio reports BOTH a
  /// frequency and a mode of its own — the pairing proved, as against merely
  /// connected, which a rig that answers nothing also reaches.
  ///
  /// This service decides only that it happened; the consent gate and the
  /// persisted mark are HaLoServices'. A CAT service that reached the
  /// reporting backend itself would put an upload behind every driver's
  /// reading path.
  void Function(EquipmentNode node)? onRadioProven;

  /// DEVLOGCAT's recorder (cat_traffic_log.dart), handed every byte each way
  /// and the moments that explain them. Owned by HaLoServices, which starts
  /// and stops it; null in a service built without one.
  CatTrafficLog? trafficLog;

  /// How the log names a node: its pairing, which says what protocol the
  /// bytes on that line are in, and the head of its uuid, which tells two
  /// radios of the same model apart.
  String _logLabel(String uuid) => '${_nodes[uuid]?.typeKey ?? 'node'}#${uuid.length > 4 ? uuid.substring(0, 4) : uuid}';

  /// Nodes [onRadioProven] has fired for this session, so a reconnect does
  /// not ask again.
  final Set<String> _provenThisSession = {};

  CatService(
    this._settings, {
    EquipmentRegistry? registry,
    this._radio,
    this._onTrack,
    this.reconnectDelay = _defaultReconnectDelay,
    this.sdrIdleRelease = const Duration(seconds: 5),
    this.sdrRetryDelay = const Duration(seconds: 5),
    this.now = realNowUtc,
    this.idleRetryFirst = _idleRetryFirst,
    this.staleAfter = catStaleAfter,
  }) : assert(idleRetryFirst > Duration.zero, 'a zero first delay makes the backoff a tight loop'),
       assert(sdrRetryDelay > Duration.zero, 'a zero delay retries an absent SDR in a tight loop'),
       registry = registry ?? EquipmentRegistry() {
    _load();
    // The meter calibration tables (drivers/info/), read once. Not awaited
    // by anything: a session asks for its table each time it converts a
    // reading, so one built before this lands simply starts converting when
    // it does — and the panel is told, so a radio's meter slots appear
    // rather than waiting for the next notification of their own.
    unawaited(
      MeterCalibrations.instance.load().then((_) {
        if (!_disposed) notifyListeners();
      }),
    );
    _lastSeenVfoPower = _radio?.vfoA.power;
    _radio?.addListener(_onVfoChanged);
  }

  /// Describes a radio by its catalogue identity — the variant key (a
  /// stable id we ship), its transport and its driver — plus the node's
  /// name. Still never any other config: a serial `port` embeds the
  /// adapter's device serial number on macOS, and the network transports
  /// hold addresses and passwords. See docs/design/telemetry.md.
  ///
  /// Taking the whole [node] (not a separately-passed name) so every call
  /// site gets the same blank-name fallback rather than each one having to
  /// remember it: an unnamed node — freshly loaded from a pre-`name` record,
  /// or blanked out in the editor, which enforces no minimum length — falls
  /// back to the driver's own name, e.g. "Kenwood (CAT)". That is still
  /// bounded (drawn from our own driver catalogue, not typed by the
  /// operator), just less specific than a real name.
  void _trackRadio(String event, EquipmentNode node, {Map<String, Object?> extra = const {}}) {
    final track = _onTrack;
    if (track == null) return;
    final type = registry.typeFor(node.typeKey);
    final name = node.name.isNotEmpty ? node.name : (type?.driver.name ?? node.typeKey);
    track(event, {'radio': node.typeKey, 'transport': type?.transportKey, 'driver': type?.driver.key, 'name': _trackedName(name), ...extra});
  }

  /// The name field has no length limit in the editor, unlike every other
  /// property this event sends — all bounded by our own catalogue. Capped
  /// here, at the one place all `radio_*` events funnel through, rather than
  /// in the editor: a length limit there is a UX decision for the name
  /// operators see everywhere, not a telemetry one.
  static const _maxTrackedNameLength = 60;

  static String _trackedName(String name) => name.length <= _maxTrackedNameLength ? name : name.substring(0, _maxTrackedNameLength);

  /// The baud rate a failed serial attempt was using — deliberately the ONE
  /// config value that goes out. A mismatch is the classic cause of a silent
  /// port, the set of rates is small and fixed, and it identifies nobody.
  Map<String, Object?> _baudExtra(Map<String, dynamic> config) => config['baudRate'] == null ? const {} : {'baud': config['baudRate']};

  /// First failure per node per session only — see [_trackedFailed]. Not
  /// re-armed by a later success on purpose: a flapping rig would otherwise
  /// report on every cycle, which is the volume this de-dup exists to stop.
  /// The question being answered is "does this pairing ever fail for people",
  /// not "how often".
  void _trackFailure(EquipmentNode node, String reason, {Map<String, Object?> extra = const {}}) {
    if (!_trackedFailed.add(node.uuid)) return;
    _trackRadio('radio_connect_failed', node, extra: {'reason': reason, ...extra});
  }

  @override
  List<EquipmentNode> get nodes => List.unmodifiable(_nodes.values);

  /// The nodes this launch will not connect on its own, and why an operator
  /// might find a radio they expect to be live sitting disconnected
  /// (auto_connect_guard.dart). Boot names them in a notice, which is the only
  /// place that fact is said out loud before they go looking in Settings.
  ///
  /// A mark whose node has since been deleted is simply not listed. Nothing
  /// prunes the stored value: it matches nothing, costs one string, and a
  /// launch is the wrong moment to start rewriting preferences to tidy up.
  List<EquipmentNode> get autoConnectHeldNodes => [
    for (final uuid in _autoConnectHeld)
      if (_autoConnectTargets.contains(uuid)) ?_nodes[uuid],
  ];

  /// The nodes an automatic reconnect aims at: radio1, and the key in use when
  /// it is a device of its own. Both are what the app depends on, and neither
  /// should wait for a button. A K4 also restores the logical receivers
  /// sharing that radio's physical connection, unless explicitly disconnected.
  Set<String> get _autoConnectTargets {
    final keyer = designatedFor(kCategoryKey);
    return {?_localRadio1, if (keyer != null && _isDesignatedKeyerDevice(keyer)) keyer, ..._k4SiblingIds(_localRadio1)};
  }

  @override
  EquipmentNode? nodeFor(String uuid) => _nodes[uuid];

  /// The physical radio shared by logical receiver nodes, when applicable.
  @override
  String? logicalDeviceIdFor(String uuid) {
    final node = _nodes[uuid];
    return node != null && _isK4Remote(node) ? _k4Identity(node) : null;
  }

  Map<String, String>? logicalChannelFor(String uuid) => _k4LogicalChannelFor(uuid);

  // ---------------------------------------------------------- main VFO

  /// What drives the logging panel — `radio1` in data-model.md's terms, the
  /// transceiver whose VFO is `vfoA`, whether it is this device's own or a
  /// peer's.
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
  MainVfo? _radio1;

  MainVfo? get radio1 => _radio1;

  /// The LOCAL node filling the role, or null — which a peer pick also
  /// answers with null, since this app holds no session to a peer's rig.
  /// Everything reaching for a runtime, a session or an [EquipmentNode]
  /// wants this; [radio1] is the role itself.
  @override
  String? get _localRadio1 => switch (_radio1) {
    LocalRadio(:final uuid) => uuid,
    _ => null,
  };

  /// Whether [uuid] is the local node filling the role — a peer pick is no
  /// node of this station's, so it answers false for every uuid.
  bool isRadio1(String uuid) => _localRadio1 == uuid;

  /// The peer bridge's own view of the pick: which peer radio this device
  /// follows, or null when `vfoA` is a local rig's or nothing's.
  ///
  /// A peer pick is kept across launches and across that device walking
  /// away — the picker shows it as unavailable and it re-engages by itself
  /// when the peer comes back. Nothing here checks whether the peer is
  /// present: this service cannot see the sessions, and a selection that
  /// erased itself on a dropped link would be gone before the operator
  /// looked up.
  @override
  PeerRadioSelection? get followedPeerRadio => switch (_radio1) {
    PeerRadio(:final selection) => selection,
    _ => null,
  };

  /// Points `vfoA` at a radio — this device's own, a peer's, or None. One
  /// setter because there is one slot: every pick is a statement about the
  /// same VFO, so each displaces whatever filled the role before.
  Future<void> setRadio1(MainVfo? next) async {
    if (_radio1 == next) return;
    final outgoing = _localRadio1;
    // The picks are per radio, so moving `vfoA` moves the key in use with it.
    _withKeyInUseTidied(() {
      // The echo guard is per-node but only meaningful for whichever node is
      // radio1 — the same reason [_closeSession] clears it. The incoming
      // radio was told nothing while it wasn't driving the panel, and the
      // outgoing one stops being asked, so a stale value on either would
      // suppress the first tune to a frequency that radio happens to be on.
      //
      // The incoming side is null for a peer pick, and rightly: there is no
      // local runtime to clear, and the outgoing one still needs clearing.
      for (final id in [
        outgoing,
        switch (next) {
          LocalRadio(:final uuid) => uuid,
          _ => null,
        },
      ]) {
        if (id != null) {
          _runtimes[id]?.lastSent = null;
          _runtimes[id]?.lastSentPower = null;
          cwProgress.value = null;
          voiceActivity.value = null;
        }
      }
      // Same reasoning for the snapper: a movement measured on the outgoing
      // radio says nothing about where the incoming one is sitting.
      _cancelSnap(null);
      _radio1 = next;
    });
    // No status change carries this one: switching vfoA between two
    // CONNECTED rigs fires no _setState, and a peer pick would leave the tag
    // naming a local radio.
    _updateEquipmentTag();
    // The incoming radio's keying is whatever its device last told this one —
    // picking a radio is not the far station changing, so nothing else would
    // arrive to fill it in.
    _adoptPeerKeying();
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------- offered to peers

  @override
  List<PeerRadioOffer> get offeredRadios => [
    for (final node in _nodes.values)
      if (registry.typeFor(node.typeKey)?.category == kCategoryTransceiver && stateFor(node.uuid).status == EquipmentStatus.connected)
        PeerRadioOffer(
          id: node.uuid,
          name: node.name,
          // CW is the STATION's answer, the same for every radio it
          // offers: a request is keyed by whatever this device keys
          // with, which may be a paddle-side keyer rather than the rig
          // named. Voice is the RADIO's, because the audio is in it.
          //
          // What this device keys with ITSELF, never [canKeyCw]: a
          // station whose own radio1 is some third device's rig keys
          // nothing here, and offering that as keyable would advertise a
          // relay nothing implements.
          //
          // All of it behind this device's own keying experiment: a
          // station whose operator has no keyer area and no Escape
          // handler must not be keyed from elsewhere, because nothing
          // here could stop it.
          keysCw: _keyingEnabled && _keying.keysCwLocally,
          voiceMemories: _keyingEnabled ? (_keying.voiceKeyerFor(node.uuid)?.voiceMemoryCount ?? 0) : 0,
          recordsVoice: _keyingEnabled && (_keying.voiceKeyerFor(node.uuid)?.canRecordVoice ?? false),
        ),
  ];

  @override
  void noteOffer(String deviceId, String deviceName, List<PeerRadioOffer> radios) {
    // Kept for every radio that device offers, picked or not — see
    // [_adoptPeerKeying]. The whole of that device's offer replaces what it
    // last said, absences included: an offer that stops naming a radio is
    // how a station says that rig went away.
    _peerKeying.rememberOffers(deviceId, radios);
    _adoptPeerKeying();
    final selection = followedPeerRadio;
    if (selection == null || selection.deviceId != deviceId) return;
    for (final radio in radios) {
      if (radio.id != selection.radioId) continue;
      if (selection.deviceName == deviceName && selection.radioName == radio.name) return;
      // The ids are unchanged, so this is the same pick under new names —
      // which is why [PeerRadioSelection] compares only the ids. Written
      // through rather than held in memory: the name is wanted precisely
      // when the peer is not here to state it, relaunches included.
      _radio1 = PeerRadio(PeerRadioSelection(deviceId: deviceId, radioId: radio.id, deviceName: deviceName, radioName: radio.name));
      unawaited(_save());
      notifyListeners();
      return;
    }
  }

  @override
  VfoReading? vfoForOfferedRadio(String radioId) {
    // Through the offer, not straight to the runtime: a radio that is not
    // offered must not report either, or a controller would keep hearing
    // from a rig it can no longer be given.
    if (!offeredRadios.any((radio) => radio.id == radioId)) return null;
    return stateFor(radioId).vfo;
  }

  @override
  void tuneOfferedRadio(String radioId, {double? freqKHz, String? mode}) {
    if (!offeredRadios.any((radio) => radio.id == radioId)) return;
    // The designated radio keeps going through `RadioService`, which is the
    // funnel a local keystroke takes: the logging panel follows it and Smart
    // VFO Snap measures it. Tuning it directly would move the rig with the
    // operator's own app still showing where it was.
    if (radioId == _localRadio1) {
      _radio?.setVfo('vfoA', freq: freqKHz, mode: mode);
      return;
    }
    tuneNode(radioId, VfoReading(freqKHz: freqKHz, mode: resolveSideband(mode, freqKHz)));
  }

  // --------------------------------------------- keying, over the link

  /// The picked peer radio's keying — what it says it can be asked to do,
  /// what it last reported, and how a request reaches it (peer_keying.dart).
  /// Every keying surface reads it through the same getters a local rig
  /// answers, so a peer that walks off mid-message leaves them empty rather
  /// than addressing a device that is not there.
  final _peerKeying = PeerKeying();

  @override
  Listenable get keyingChanges => _keying.keyingChanges;

  @override
  void Function(PeerKeyRequestPayload request)? get sendPeerKeyRequest => _peerKeying.send;

  @override
  set sendPeerKeyRequest(void Function(PeerKeyRequestPayload request)? send) => _peerKeying.send = send;

  /// What one of [offeredRadios] is keying, for a controller — null for a
  /// radio this device is not offering, the same guard [vfoForOfferedRadio]
  /// applies and for the same reason.
  ///
  /// The CW half is the STATION's, so two controllers following two radios
  /// of this station are both told about the one message going out. There is
  /// one key in use here, and that message is what it is keying. The labels
  /// and lengths are this device's because the audio is: these memories were
  /// named and timed here.
  @override
  PeerKeyStatusPayload? keyStatusForOfferedRadio(String radioId) {
    // Behind the same experiment the offer is: with keying off there is
    // nothing to report, and the memory labels are this operator's own words.
    if (!_keyingEnabled) return null;
    if (!offeredRadios.any((radio) => radio.id == radioId)) return null;
    return _keying.statusForOfferedRadio(radioId);
  }

  /// Keys, stops, or sets a speed on this device's own station for a peer —
  /// through the same funnels a local function key takes, and only for a
  /// radio this device is currently offering.
  ///
  /// Every arm keys HERE or not at all. A request is never relayed onward to
  /// whatever radio1 this device is itself following: an operator who picked
  /// this station's rig asked for this station's rig, and a chain of them
  /// would put a transmitter two devices away on the air for somebody who
  /// picked neither.
  @override
  void handleKeyRequest(PeerKeyRequestPayload request) {
    // Checked again rather than trusted to the offer: the experiment can go
    // off under an established session, and a controller holding a stale
    // offer would go on keying a station that can no longer see it.
    if (!_keyingEnabled) return;
    if (!offeredRadios.any((radio) => radio.id == request.radioId)) return;
    _keying.handleRequest(request);
  }

  /// The far side's account of what the picked radio is keying. Dropped
  /// unless it is about the radio this operator picked — a device offering
  /// radios hears its own controllers' reports too, and a second source
  /// writing the strip fights the first.
  @override
  void notePeerKeyStatus(String deviceId, PeerKeyStatusPayload status) {
    _peerKeying.rememberStatus(deviceId, status);
    if (!(followedPeerRadio?.matches(deviceId, status.radioId) ?? false)) return;
    final before = _keying.peerShownState;
    _keying.notePeerStatus(status);
    // Only when what the SURFACES read has moved. The notifiers this wrote
    // rebuild the strip on their own, and a status arrives per character from
    // a keyer that echoes them — a full notification each would rebuild every
    // equipment row in the Station panel, which is the cost [cwProgress] is a
    // notifier at all to avoid.
    if (_keying.peerShownState != before) notifyListeners();
  }

  /// Points the keying half at whatever the CURRENT pick's device last said
  /// about it — on a new pick, and on a fresh offer. What it remembers, and
  /// why it has to, is [PeerKeying]'s.
  void _adoptPeerKeying() {
    final selection = followedPeerRadio;
    final deviceId = selection?.deviceId;
    final radioId = selection?.radioId;
    if (!_keying.adoptPeer(_peerKeying.offerFor(deviceId, radioId), _peerKeying.statusFor(deviceId, radioId))) {
      return;
    }
    notifyListeners();
  }

  /// That peer's radios are out of reach — it left. The PICK stands, the
  /// same as it does for tuning: what goes is only what it could do, so the
  /// surfaces go quiet instead of addressing a device that is not there.
  @override
  void forgetPeerRadios(String deviceId) {
    _peerKeying.forgetDevice(deviceId);
    if (followedPeerRadio?.deviceId != deviceId) return;
    if (!_keying.forgetPeer()) return;
    notifyListeners();
  }

  // ------------------------------------------------------ antenna1 / key1

  /// Which antenna/key node is "in use", PER RADIO — keyed by the radio the
  /// picks belong to and then by category ([kCategoryAntenna]/
  /// [kCategoryKey]). The outer key is the same value the main-VFO picker
  /// carries: a local node's uuid, `peer:…` for a peer's radio,
  /// [_noRadioKey] for None.
  ///
  /// Per radio because that is what an antenna and a key are physically
  /// attached to. A shack whose second rig runs a different wire and its own
  /// paddle states that once; switching radio1 restores what that radio was
  /// last set to, and switching back restores the first one's.
  ///
  /// An ABSENT category means never decided, and [designatedFor] answers it
  /// with [_defaultDesignation]. A category stored as null is the operator
  /// having answered None, and stays None. The two are not the same, which
  /// is why the inner map holds explicit nulls rather than dropping them.
  final Map<String, Map<String, String?>> _designated = {};

  /// Stands in for "no radio selected" — a real key, since None is a state
  /// an operator can sit in and configure a station from.
  static const _noRadioKey = 'none';

  /// Whose picks [designatedFor] and [setDesignated] are talking about:
  /// whatever is driving `vfoA` right now.
  String _designationKey() => switch (_radio1) {
    LocalRadio(:final uuid) => uuid,
    PeerRadio(:final selection) => peerRadioValue(selection),
    null => _noRadioKey,
  };

  String? designatedFor(String category) {
    final picks = _designated[_designationKey()];
    if (picks != null && picks.containsKey(category)) return picks[category];
    return _defaultDesignation(category);
  }

  /// What a radio that has never been asked keys through: itself, when its
  /// own CAT can key. Computed rather than written, so it follows the radio
  /// without an operator ever confirming it — and only a default, which is
  /// what [setDesignated]'s stored entry then outranks, None included.
  ///
  /// Antennas have no equivalent: nothing about a radio says which wire is
  /// on it. Neither does a peer's radio, whose keying is the other device's
  /// key in use — that default is [peerKeyIsInUse] rather than an answer
  /// here, because what keys there is not a node of this station to name.
  String? _defaultDesignation(String category) {
    if (category != kCategoryKey) return null;
    if (!_settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return null;
    final uuid = _localRadio1;
    if (uuid == null) return null;
    final node = _nodes[uuid];
    if (node == null) return null;
    return _radioKeysCw(node) ? uuid : null;
  }

  /// Whether [node]'s CAT keys CW — the driver's answer for THIS node's
  /// merged config, since on a generic entry that is a per-node fact.
  bool _radioKeysCw(EquipmentNode node) {
    final type = registry.typeFor(node.typeKey);
    return type != null && type.driver.canKeyCwWith(type.driverConfig(node.config));
  }

  bool isDesignated(String category, String uuid) => designatedFor(category) == uuid;

  /// Writes a pick for the radio in use without saving or notifying — the
  /// shared half of [setDesignated] and the rules [addNode] applies.
  void _designateNow(String category, String? uuid) => (_designated[_designationKey()] ??= {})[category] = uuid;

  Future<void> setDesignated(String category, String? uuid) async {
    final previousUuid = designatedFor(category);
    // An ANSWER is stored even when it matches the default it replaces:
    // "nothing chosen" and "chose None" resolve alike right now but are not
    // the same state, and the difference decides whether a default can take
    // over later — a peer radio whose operator said None keys nothing, and
    // one whose operator said nothing keys through that peer.
    final answered = _designated[_designationKey()]?.containsKey(category) ?? false;
    if (answered && previousUuid == uuid) return;
    _designateNow(category, uuid);
    // Only a real CHANGE of key owes the outgoing one anything. A dropdown
    // reports the already-selected item being tapped, and abandoning the
    // message going out because the operator re-picked the key that is
    // keying it would stop a CQ mid-word.
    if (category == kCategoryKey && previousUuid != uuid) _onKeyInUseChanged(previousUuid);
    await _save();
    notifyListeners();
  }

  /// Runs [mutate], then pays the outgoing key whatever a change owes it.
  ///
  /// EVERY path that moves the key in use goes through this, and most of them
  /// never name a key at all: picking a radio, adding a transceiver (the
  /// newest takes the VFO), removing one. The picks belong to the radio, so
  /// a writer of `radio1` is a writer of the key in use whether it meant to
  /// be or not — which is why this is a wrapper rather than a line each of
  /// them has to remember.
  void _withKeyInUseTidied(void Function() mutate) {
    final previous = designatedFor(kCategoryKey);
    mutate();
    if (designatedFor(kCategoryKey) != previous) _onKeyInUseChanged(previous);
  }

  /// What a change of key in use owes the outgoing one — whether the
  /// operator picked a different key or moved to a radio that keys through
  /// something else. The old keyer's message would otherwise finish with
  /// nothing showing it and nothing to stop it; the new one's speed is read
  /// so the row is not left on the old one's.
  void _onKeyInUseChanged(String? previousUuid) => _keying.abandonKeying(previousUuid);

  @override
  EquipmentState stateFor(String uuid) => _runtimes[uuid]?.state ?? const EquipmentState();

  /// [radio1]'s own power reading, when its driver can report one — the
  /// operator's stated power ([Vfo.power]) otherwise, the manual fallback
  /// for a radio that can't report power or isn't connected at all. The one
  /// rule every power surface (Station Configuration's Power field, the
  /// Power logging control, per-QSO station-info capture) shows and
  /// captures, kept in one place so it can't drift between them.
  ///
  /// The pre-VFO home of the manual value, [SettingsService.currentPower],
  /// is migrated into the VFO at startup (`HaLoServices._buildRadioService`)
  /// rather than read as a fallback here — a fallback only this getter
  /// consulted would leave the Power logging control and the More pane, which
  /// read [Vfo.power] directly, showing nothing while this showed 100.
  num? get displayedPower {
    final uuid = _localRadio1;
    final live = uuid == null ? null : stateFor(uuid).power;
    return live ?? _radio?.vfoA.power;
  }

  /// Pushes [watts] to radio1's session, if it has one and is connected — a
  /// no-op otherwise. Like frequency and mode, power reaches this through
  /// [RadioService] ([_onVfoChanged]): several surfaces read and write it,
  /// and one app-wide value is what keeps them agreeing.
  void setPower(num watts) {
    final uuid = _localRadio1;
    if (uuid != null) setNodePower(uuid, watts);
  }

  /// The repeat chain (keyer_repeat.dart) — one engine for both keyers,
  /// since a message and a memory differ only in what is sent again.
  late final _repeat = KeyerRepeat(vfo: () => _radio?.vfoA);

  /// The wait between message 1 finishing and it being keyed again — non-null
  /// only while that wait is running, so the keyer area's countdown bar is
  /// mounted exactly then.
  ValueNotifier<KeyerRepeatWait?> get keyerRepeat => _repeat.wait;

  /// Whether a chain is running at all — armed, keying, waiting, or in the
  /// gap between the wait ending and the next message reaching the radio.
  ValueNotifier<bool> get keyerRepeatActive => _repeat.active;

  /// Whether a repeat is armed or counting down.
  bool get keyerRepeating => _repeat.running;

  /// Arms message 1 to go again [delay] after the one now keying finishes —
  /// see [KeyerRepeat.arm], which is where the five-minute limit lives.
  void armKeyerRepeat({required Duration delay, required String text, required void Function() send, int? memory}) =>
      _repeat.arm(delay: delay, text: text, send: send, memory: memory);

  /// Ends the chain — every stop the operator can make lands here.
  void cancelKeyerRepeat() => _repeat.cancel();

  /// See [KeyerRepeat.deadlineMillis] — the tests' way in.
  @visibleForTesting
  int? get keyerRepeatDeadlineMillis => _repeat.deadlineMillis;

  /// Keying (cat_keying.dart) — which session keys, what it is keying, the
  /// speed, the memories. The API stays HERE: every surface that keys reads
  /// this service and nothing below it, whether the rig answering is plugged
  /// in here or on a peer's desk.
  late final _keying = CatKeying(station: this, settings: _settings, chain: _repeat, peer: _peerKeying);

  bool get canKeyCw => _keying.canKeyCw;
  bool get designatedKeyIsKeyer => _keying.designatedKeyIsKeyer;
  EquipmentNode? get designatedKeyerNode => _keying.designatedKeyerNode;
  List<EquipmentNode> get keyerCandidates => _keying.keyerCandidates;
  int? get keyerSpeed => _keying.keyerSpeed;
  ({int min, int max})? get keyerSpeedRange => _keying.keyerSpeedRange;
  bool get cwSending => _keying.cwSending;
  ValueNotifier<CwSendProgress?> get cwProgress => _keying.cwProgress;
  ValueListenable<int> get cwStops => _keying.cwStops;
  ValueNotifier<bool> get keyerAreaShown => _keying.keyerAreaShown;
  ValueNotifier<int> get keyerShowRequests => _keying.keyerShowRequests;
  ValueListenable<int> get keyboardModeRequests => _keying.keyboardModeRequests;
  void toggleKeyboardMode() => _keying.toggleKeyboardMode();
  void showKeyerArea() => _keying.showKeyerArea();
  void hideKeyerArea() => _keying.hideKeyerArea();
  ValueNotifier<({bool on, bool running})> get enterSends => _keying.enterSends;
  void setEnterSends({bool? on, bool? running}) => _keying.setEnterSends(on: on, running: running);
  bool sendCw(String text, {bool hasMessageOne = false}) => _keying.sendCw(text, hasMessageOne: hasMessageOne);
  void stopCw() => _keying.stopCw();
  void dropQueuedCw(int id) => _keying.dropQueuedCw(id);
  bool setKeyerSpeed(int wpm) => _keying.setKeyerSpeed(wpm);
  void refreshKeyerSpeed() => _keying.refreshKeyerSpeed();

  bool get canPlayVoice => _keying.canPlayVoice;
  bool get radio1HasVoiceMemories => _keying.radio1HasVoiceMemories;
  int get voiceMemoryCount => _keying.voiceMemoryCount;
  bool get canRecordVoice => _keying.canRecordVoice;
  bool get voiceMessagesAreLocal => _keying.voiceMessagesAreLocal;
  bool get voiceMessagesNamedOnRadio => _keying.voiceMessagesNamedOnRadio;
  String voiceMessageLabel(int n) => _keying.voiceMessageLabel(n);
  int voiceMessageDuration(int n) => _keying.voiceMessageDuration(n);
  Future<void> setVoiceMessageLabel(int n, String label) => _keying.setVoiceMessageLabel(n, label);
  ({String model, String text})? get voiceRecordingHelp => _keying.voiceRecordingHelp;
  ValueNotifier<VoiceActivity?> get voiceActivity => _keying.voiceActivity;
  void playVoiceMemory(int n, {bool repeat = true}) => _keying.playVoiceMemory(n, repeat: repeat);
  void recordVoiceMemory(int n) => _keying.recordVoiceMemory(n);
  void stopVoice() => _keying.stopVoice();
  void playVoiceSequence(List<int> memories) => _keying.playVoiceSequence(memories);
  void cancelVoiceSequence() => _keying.cancelVoiceSequence();
  void stopMessageOne() => _keying.stopMessageOne();
  bool stopKeying() {
    final released = _ptt.release(), tuneStopped = stopNodeTunes();
    return _keying.stopKeying(alsoStopped: released || tuneStopped);
  }

  bool get escapeStoppedKeying => _keying.escapeStoppedKeying;

  /// ['] in a Phone mode (cat_ptt.dart) — this station's radios, never a peer's.
  late final _ptt = CatPtt()..held.addListener(notifyListeners);
  late final pttKeys = PttKeyboard(held: _ptt.held, release: _ptt.release, escape: stopKeying, toggle: togglePtt);
  PttSession? _pttSession(String? uuid) => switch (uuid == null ? null : connectedSession(uuid)) {
    final PttSession session => session,
    _ => null,
  };
  bool get canPtt => _pttSession(_localRadio1) != null;

  /// Whether the app's PTT key is on the logging radio — [pttKeys]' `held` is true for a key on any radio.
  bool get pttHeldOnRadio1 => _ptt.heldOn(_pttSession(_localRadio1));
  void togglePtt(String radio) {
    final session = _pttSession(radio);
    if (session == null) return;
    if (!_ptt.heldOn(session)) {
      _keying.stopAll();
      _keying.quietOthers(radio);
    }
    _ptt.toggle(session);
  }

  /// One transmitter at a time, whoever asks: before a CW message or a voice
  /// memory goes out on [radio], the app's PTT key drops — on any radio, the
  /// message takes over — and every other radio stops its CW and voice.
  @override
  void yieldTransmitter(String? radio) {
    _ptt.release();
    _keying.quietOthers(radio);
  }

  // --------------------------------------- what keying asks of the station

  /// The key in use, as a node uuid — null for None, and null for a peer's
  /// own keying, which is no node of this station ([peerKeyIsInUse]).
  @override
  String? get keyInUse => designatedFor(kCategoryKey);

  /// Whether what keys is the picked peer's own key. The DEFAULT for a peer
  /// radio, because its keying is not a node here to designate (see
  /// [_defaultDesignation]) — but an explicit None still means None, and an
  /// explicit local key still wins.
  @override
  bool get peerKeyIsInUse {
    final selection = followedPeerRadio;
    if (selection == null) return false;
    final picks = _designated[_designationKey()];
    if (picks == null || !picks.containsKey(kCategoryKey)) return true;
    return picks[kCategoryKey] == peerRadioValue(selection);
  }

  @override
  String? get peerRadioId => followedPeerRadio?.radioId;

  /// Whether this device's own keying surfaces exist at all — the `keyer`
  /// experiment, which gates what it offers a peer as much as what it shows
  /// its own operator.
  bool get _keyingEnabled => _settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */;

  /// Whether the picked peer radio's station says it will key CW for this
  /// operator. What puts it in the Key in Use list — a device that keys
  /// nothing is not a key.
  bool get peerOffersCwKeying => _peerKeying.keysCw;

  @override
  bool isKeyerNode(EquipmentNode node) => typeFor(node)?.category == kCategoryKeyer || _radioKeysCw(node);

  @override
  EquipmentSession? connectedSession(String uuid) {
    final runtime = _runtimes[uuid];
    if (runtime?.state.status != EquipmentStatus.connected) return null;
    return runtime!.session;
  }

  @override
  String? get localRadio1 => _localRadio1;

  /// Puts radio1 in [mode] without touching VFO A: its report comes back the
  /// usual way. Recorded as sent only once it went, as `tuneNode` does.
  void setRadio1Mode(String mode) {
    final runtime = _runtimes[_localRadio1];
    final session = runtime?.session;
    if (session is! TransceiverSession) return;
    try {
      session.setMode(mode);
    } catch (e, st) {
      return ErrorReportingService.report(e, st, context: 'cat:set-radio-mode');
    }
    runtime!.lastSent = VfoReading(freqKHz: runtime.lastSent?.freqKHz, mode: mode);
  }

  /// Routes an antenna switch's device port to one of its antenna ports.
  ///
  /// Addressed by node uuid rather than through a designation, unlike
  /// [setPower]: a station can run several switches and the operator is
  /// acting on the row in front of them, not on a designated one.
  ///
  /// A no-op on a node that is not connected, or whose driver does not route
  /// anything. The panel only offers this on a connected switch, so both are
  /// races rather than states — the operator tapping a selection as the
  /// connection drops.
  void selectAntenna(String uuid, String portKey, String antennaKey) {
    final session = _runtimes[uuid]?.session;
    if (session is! AntennaSwitchSession) return;
    // Nothing throws a relay under RF: that is what destroys one. A switch
    // that senses its own ports refuses this in its driver and this changes
    // nothing for it — but a switch with no RF sensing at all (the Sierra
    // CX-1 has no PTT input) has only what the RADIO says, and until
    // telemetry there was nothing here that knew.
    //
    // Asked of the designated radio, whose antenna this switch is routing
    // (docs/design/cat.md § The picks belong to the radio). A radio that
    // cannot say — every driver reporting no TX state, which is most of
    // them — leaves `transmitting` null and the selection goes through: a
    // switch an operator could never work would be worse than the switch
    // they have today.
    if (radio1IsTransmitting) {
      // Said out loud, in the one place a developer will look. The refusal
      // is right, but a tap that does nothing at all is indistinguishable
      // from a switch that has stopped working — and the operator has no
      // other way to tell those apart.
      debugPrint('[cat] antenna selection refused: ${_localRadio1 == null ? 'a radio' : displayNameFor(nodeFor(_localRadio1!)!)} is transmitting');
      return;
    }
    try {
      session.selectAntenna(portKey, antennaKey);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:select-antenna');
    }
  }

  /// Whether the radio driving `vfoA` is keyed RIGHT NOW: it says so, or the app
  /// holds its PTT key — unconfirmed, or the radio gone stale (RF in its CAT cable).
  ///
  /// False when nothing knows — a driver that cannot read TX state never
  /// reports one, and both callers want "go ahead unless the radio has said
  /// otherwise" — a shack whose rigs cannot answer must keep working exactly
  /// as it did before there was any telemetry at all.
  @override
  bool get radio1IsTransmitting {
    final uuid = _localRadio1;
    if (uuid == null) return false;
    final state = stateFor(uuid);
    // A radio that has gone SILENT is not a radio that is transmitting, even
    // if the last thing it said was that it had keyed. Nothing in any of
    // these protocols announces an unkey, so a rig unplugged or switched off
    // mid-over leaves that "true" standing for the life of the session —
    // refusing every antenna selection and holding off every snap, with a TX
    // legend lit beside a readout that says NO DATA. [EquipmentState.stale]
    // is what already knows the difference, and a gate that fails closed on
    // an answer known to be out of date, with nothing on screen to say why,
    // is worse than one that reopens.
    if (state.stale) return _ptt.heldOn(connectedSession(uuid));
    return state.telemetry.isTransmitting || _ptt.heldOn(connectedSession(uuid));
  }

  /// The type handling [node], or null if it isn't in the catalogue — a
  /// record written by a newer build, or by a driver that has since been
  /// removed. The node stays in the list and says so rather than vanishing.
  @override
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
    //
    // There is no equivalent node check for a peer, and there cannot be one:
    // a peer radio's existence is a fact about another device, which this
    // one cannot ask about at load. An absent peer reads as an unavailable
    // selection, not as a corrupt one.
    //
    // Version 2 and older wrote the same thing as two keys, which a
    // hand-edited or newer-build blob could set both of; the local one wins,
    // as the version that stored them decided. Written back as one key, so a
    // blob only ever states one.
    // Told apart by the VERSION the blob was written under, not by whether
    // the key is there: version 3 writes an explicit null for None, which a
    // shape probe would read as a version 2 blob and answer out of whatever
    // `radio1` a future writer happened to leave behind — resurrecting a
    // pick the operator had cleared. Same rule as `designated` below.
    final storedVersion = stored['version'];
    final storedVfo = stored['mainVfo'];
    if (storedVersion is int && storedVersion >= 3) {
      if (storedVfo is Map) {
        final uuid = storedVfo['radio'];
        if (uuid is String && _nodes.containsKey(uuid)) {
          _radio1 = LocalRadio(uuid);
        } else if (PeerRadioSelection.from(storedVfo['peer']) case final selection?) {
          _radio1 = PeerRadio(selection);
        }
      }
    } else {
      final legacyRadio1 = stored['radio1'];
      if (legacyRadio1 is String && _nodes.containsKey(legacyRadio1)) {
        _radio1 = LocalRadio(legacyRadio1);
      } else if (PeerRadioSelection.from(stored['remoteRadio1']) case final selection?) {
        _radio1 = PeerRadio(selection);
      }
    }
    final designated = stored['designated'];
    if (designated is Map) {
      // Two shapes, told apart by the version the blob was written under
      // rather than by the shape of its values — a probe would have to
      // assume no category value is ever a Map, which is an invariant
      // nothing enforces, and would read a half-migrated blob as whichever
      // branch its first Map happened to select.
      //
      // Version 1 is one flat category → uuid map, and it belongs to
      // whatever was selected when it was written — which is what is being
      // loaded here, a few lines up.
      //
      // A blob with no key entry at all needs no special case either way: an
      // absent category is "never decided", which is exactly what
      // [_defaultDesignation] answers, so a station that keyed through
      // radio1 goes on doing so.
      final version = stored['version'];
      final perRadio = version is int && version >= 2;
      final byRadio = perRadio ? designated : {_designationKey(): designated};
      for (final entry in byRadio.entries) {
        final picks = entry.value;
        if (picks is! Map) continue;
        for (final pick in picks.entries) {
          final uuid = pick.value;
          // A pick whose node did not load is dropped, for [radio1]'s
          // reason. An explicit null is kept: that is the operator having
          // answered None, not a missing node.
          if (uuid != null && !(uuid is String && _nodes.containsKey(uuid))) continue;
          (_designated['${entry.key}'] ??= {})['${pick.key}'] = uuid as String?;
        }
      }
    }
  }

  Future<void> _save() => _settings.setStationEquipment({
    'version': _storageVersion,
    // Always, null included, so the blob states what is true rather than
    // leaving None to be inferred from a missing key.
    //
    // NOT load-bearing, and worth saying so: nothing derives the main
    // VFO, so an absent key and a stored null both read as None —
    // writing `if (_radio1 != null)` would behave identically and fail
    // no test, and that is correct rather than a hole in the tests.
    'mainVfo': switch (_radio1) {
      LocalRadio(:final uuid) => {'radio': uuid},
      PeerRadio(:final selection) => {'peer': selection.toJson()},
      null => null,
    },
    'designated': _designated,
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
  ///
  /// [EquipmentModel.suggestedName], not [EquipmentModel.name]: a model whose
  /// catalogue entry is a description says separately what to call the rig.
  String suggestedNameFor(String typeKey) =>
      uniqueEquipmentName(registry.typeFor(typeKey)?.model.suggestedName ?? typeKey, _nodes.values.map((node) => node.name));

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
    final stored = await _stashSecrets(await _prepareK4Node(node));
    final category = registry.typeFor(stored.typeKey)?.category;
    // Taking the VFO moves the key in use with it, so the whole block is
    // wrapped: a rig added mid-message would otherwise leave the outgoing
    // one sending with nothing showing it.
    _withKeyInUseTidied(() {
      _nodes[stored.uuid] = stored;
      // The newest transceiver takes the VFO. Only transceivers: radio1 is the
      // rig whose VFO is vfoA, and the category system exists so a rotator or a
      // relay board added later cannot take it.
      //
      // Never over a peer's radio, though: that pick was the operator saying
      // where `vfoA` comes from, and configuring a rig — which is not the same
      // as reaching for it — must not silently take the panel back off the
      // radio they are working through.
      final sibling =
          _isK4Remote(stored) && _nodes.values.any((other) => other.uuid != stored.uuid && _isK4Remote(other) && _k4Identity(other) == _k4Identity(stored));
      if (category == kCategoryTransceiver && _radio1 is! PeerRadio && !sibling) _radio1 = LocalRadio(stored.uuid);
      // Same rule as radio1, for antenna/key, and for the radio in use: the
      // newest one designated, so adding the antenna this rig runs needs no
      // separate picker visit. Only this rig's, since the picks are per
      // radio — another radio's antenna is not decided by what was plugged
      // into this one.
      if (category == kCategoryAntenna) _designateNow(kCategoryAntenna, stored.uuid);
      // The key in use is also what keys, so what a new node does to it
      // depends on what it displaces: a keyer takes over (the newest keyer
      // keys), and a plain paddle takes over only from a paddle or nothing —
      // recording a Bencher for the log must not silently stop the radio's
      // keying. Nothing to do for a transceiver that keys: a radio is its own
      // default key ([_defaultDesignation]), computed rather than written.
      if (category == kCategoryKeyer) _designateNow(kCategoryKey, stored.uuid);
      if (category == kCategoryKey && !designatedKeyIsKeyer) _designateNow(kCategoryKey, stored.uuid);
    });
    await _save();
    _trackRadio('radio_added', stored, extra: {'via': via});
    notifyListeners();
    return stored;
  }

  /// Adds a discovered device as configured equipment, with no typing.
  Future<EquipmentNode> addDiscovered(DiscoveredEquipment found) => addNode(typeKey: found.typeKey, name: found.name, config: found.config, via: 'discovery');

  @override
  Future<void> updateNode(EquipmentNode node) async {
    final previous = _nodes[node.uuid];
    if (previous == null) return;
    if (_isK4Remote(node)) {
      await _updateK4Node(previous, node);
      notifyListeners();
      return;
    }
    // Re-typing a node — the operator switching the same radio from WiFi to
    // USB — replaces both its transport and its driver, and a live runtime
    // holds a session the OLD driver built over a connection the OLD
    // transport opened. Neither can be handed to the new pairing, so the
    // connection goes first and the operator reconnects.
    //
    // Only on a type change. An edited host or baud rate leaves the pairing
    // intact, and disconnecting for those would drop a working radio every
    // time its name was corrected.
    //
    // An SDR, or a node becoming one, reconnects on ANY edit, and not as the
    // operator's Disconnect: its whole setup is read when its session starts,
    // and the display that wants it connects it straight back. Held busy
    // until the new setup is saved, or that display reconnects it on the old.
    final toSdr = typeFor(node)?.category == kCategorySdr;
    final sdrEdited = (isSdr(node.uuid) || toSdr) && (previous.typeKey != node.typeKey || !mapEquals(previous.config, node.config));
    final sdr = sdrEdited ? (_runtimeFor(node.uuid)..cancelSdrTimers()) : null;
    if (sdr != null) sdr.sdrBusy++;
    try {
      if (sdrEdited && stateFor(node.uuid).status != EquipmentStatus.disconnected) {
        await disconnect(node.uuid, byUser: !toSdr);
      } else if (previous.typeKey != node.typeKey && !sdrEdited) {
        await disconnect(node.uuid);
      }
      _nodes[node.uuid] = await _stashSecrets(node);
      await _save();
    } finally {
      if (sdr != null) sdr.sdrBusy--;
    }
    notifyListeners();
    if (sdr != null) _settleSdr(sdr);
    // Given a port or address at last: nothing retried it, and a re-type above
    // marked it disconnected on purpose although it never connected.
    final wasUnconfigured = typeFor(previous)?.isUnconfigured(previous.config) ?? false;
    if (wasUnconfigured && !(typeFor(node)?.isUnconfigured(node.config) ?? true) && _autoConnectTargets.contains(node.uuid)) {
      _runtimes[node.uuid]?.userDisconnected = false;
      unawaited(_reconnectWithRetries(node.uuid));
    }
  }

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
      final value = await _settings.equipmentSecret(_k4Identity(node), field);
      if (value != null && value.isNotEmpty) stored.add(field);
    }
    return stored;
  }

  Future<void> removeNode(String uuid) async {
    await disconnect(uuid);
    // The keychain entry outlives the prefs blob unless we say otherwise —
    // and catalogue-wide, since a node re-typed away from the pairing that
    // stored a secret would otherwise leave it behind with nothing left that
    // could ever name it.
    final node = _nodes[uuid];
    final owner = node == null ? uuid : _k4Identity(node);
    if (!_nodes.values.any((other) => other.uuid != uuid && _k4Identity(other) == owner)) {
      for (final field in registry.allSecretFields) {
        await _settings.setEquipmentSecret(owner, field, null);
      }
    }
    // A node re-added later can take the same uuid, and a mark left behind
    // would silence the report for the setup somebody just rebuilt by hand.
    await clearRadioProof(_settings.prefs, uuid);
    _provenThisSession.remove(uuid);
    // Both clears below can move the key in use — off the removed node, or
    // off a radio that is going with it — and a keyer that is NOT the node
    // being removed goes on sending regardless.
    _withKeyInUseTidied(() {
      _nodes.remove(uuid);
      final removed = _runtimes.remove(uuid);
      removed?.cancelSdrTimers();
      unawaited(removed?.spectrum?.close());
      // Removing the designated radio clears the choice rather than quietly
      // moving the logging panel onto a different rig immediately after a
      // destructive action. The dropdown is right there.
      if (_localRadio1 == uuid) _radio1 = null;
      // Same rule for antenna/key designations — across EVERY radio's picks,
      // not just the selected one's, and the removed radio's own set of picks
      // goes with it. A pick that disappears this way is "never decided"
      // again, so a radio that keys goes back to keying for itself.
      _designated.remove(uuid);
      for (final picks in _designated.values) {
        picks.removeWhere((_, designatedUuid) => designatedUuid == uuid);
      }
    });
    await _save();
    notifyListeners();
  }

  // -------------------------------------------------------------- runtime

  _NodeRuntime _runtimeFor(String uuid) => _runtimes.putIfAbsent(uuid, () => _NodeRuntime(uuid));

  /// [notify] false stores the state without waking a listener — for a
  /// change nothing on screen can render. Only the meter refresh below uses
  /// it, and it is the one place where a write that changes the state and a
  /// write worth a repaint genuinely differ.
  void _setState(String uuid, EquipmentState state, {bool notify = true}) {
    if (_disposed) return;
    _runtimeFor(uuid).state = state;
    if (isRadio1(uuid)) _updateEquipmentTag();
    if (notify) notifyListeners();
  }

  /// What every crash report says the operator was driving ([EquipmentTag]).
  /// Fed from [_setState], the one funnel every status change passes
  /// through — including the ones that are not a connect at all.
  void _updateEquipmentTag() {
    final uuid = _localRadio1;
    final node = uuid == null ? null : _nodes[uuid];
    final connected = node != null && stateFor(uuid!).status == EquipmentStatus.connected;
    // The VARIANT key, which says the transport too: an IC-705 that fails
    // over WiFi and one that fails over USB are different reports.
    _equipmentTag.update(connected ? registry.typeFor(node.typeKey)?.key ?? node.typeKey : null);
  }

  final _equipmentTag = EquipmentTag();

  Future<void> connect(String uuid) async {
    // Asking for it back cancels a previous Disconnect, so the idle retry may
    // resume looking after this node.
    _runtimeFor(uuid)
      ..userDisconnected = false
      ..linesRefused = false
      ..sdrPinned = isSdr(uuid);
    // And it is the way back from a held auto-connect: the operator asking for
    // this node by hand is both the deliberate act the hold waits for and the
    // evidence it wants, since a port that opens on request is one worth
    // opening automatically again. Awaited so the lift outlives this process —
    // but only when there is something to lift, so an ordinary Connect never
    // waits on a preferences write.
    if (_autoConnectHeld.remove(uuid)) {
      await _writeAutoConnectMark(() => clearAutoConnectMark(_settings.prefs, uuid), 'cat:clear-auto-connect');
      onAutoConnectHoldLifted?.call();
    }
    // The backoff belongs to the designated radio's loop, so only that radio's
    // Connect may reset it. Done unconditionally, connecting a SECOND rig
    // would drag radio1's wait from eight minutes back to thirty seconds — an
    // unrelated action re-entering the eager-poking regime the backoff exists
    // to avoid.
    if (isRadio1(uuid)) _idleRetryDelay = idleRetryFirst;
    // Watched, though not marked. The mark is skipped deliberately — this is
    // the attempt somebody is watching, and the one that lifts a hold — but the
    // port it opens is the same port, with the same synchronous FFI behind it,
    // so pressing Connect on a wedged radio must not be a way to leave a corpse
    // holding the window.
    await HangWatchdog.guard(() => _connect(uuid));
  }

  /// Every connect the app decides on by itself goes through here — the boot
  /// reconnect, the burst after a drop, the idle ladder — so that the attempt
  /// is on disk before it is made and gone once it returns
  /// (auto_connect_guard.dart). A Connect the operator pressed does not: it is
  /// the one attempt somebody is watching, and the one that lifts a hold.
  Future<_ConnectOutcome> _autoConnect(String uuid) async {
    final node = _nodes[uuid];
    if (node == null) return _ConnectOutcome.failed;
    if (_autoConnectHeld.contains(uuid)) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: t.settings.station.autoConnectHeld));
      // Through the same first-failure-per-node de-dup as a real connect
      // failure: how often this fires in the field is the only measure of how
      // often a launch is actually dying inside a connect, which is the thing
      // no crash report can show — the process that hangs never reports.
      _trackFailure(node, 'auto_connect_held');
      return _ConnectOutcome.held;
    }
    final prefs = _settings.prefs;
    if ((_autoConnectInFlight[uuid] = (_autoConnectInFlight[uuid] ?? 0) + 1) == 1) {
      await _writeAutoConnectMark(() => markAutoConnectStarted(prefs, uuid), 'cat:mark-auto-connect');
    }
    try {
      // Under the watchdog as well as the mark: the mark keeps the NEXT launch
      // out of a call that does not return, and the watchdog ends the one
      // stuck in it, so that there is a next launch rather than a corpse
      // holding the window.
      return await HangWatchdog.guard(() => _connect(uuid));
    } finally {
      // Every ordinary ending clears it — connected, refused, superseded, or
      // thrown. Only a process that never reaches here at all leaves the mark
      // standing, which is the single case it is written for.
      if ((_autoConnectInFlight[uuid] = _autoConnectInFlight[uuid]! - 1) <= 0) {
        _autoConnectInFlight.remove(uuid);
        await _writeAutoConnectMark(() => clearAutoConnectMark(prefs, uuid), 'cat:clear-auto-connect');
      }
    }
  }

  /// Writes one of the auto-connect marks, and never lets the writing of it
  /// become the failure.
  ///
  /// [_connect] answers with an outcome and never throws, and two callers are
  /// built on that: the idle ladder's `.then` reschedules itself from there,
  /// and the boot burst hands over to that ladder on its way out. An exception
  /// escaping from here — an unwritable preferences file, a wedged platform
  /// channel — would skip both, and the designated radio would then never
  /// connect again for the whole session, with nothing on the row and nothing
  /// in a report to say why. Bounded for the same reason it is caught: the
  /// mark is worth less than the connect it describes.
  ///
  /// So a mark that cannot be written leaves the call UNMARKED and proceeds.
  /// The alternative — refusing to connect a radio because a breadcrumb could
  /// not be written — trades a possible hang for a certain loss of the feature,
  /// on machines whose preference store is already in trouble.
  Future<void> _writeAutoConnectMark(Future<void> Function() write, String context) async {
    try {
      await write().timeout(_markBudget);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: context);
    }
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
      // Translated like every other error this sets, because [error] is not
      // only a diagnostic: the Radio panel renders it as its primary text and
      // its Semantics label, in the slot a frequency belongs in. The raw key
      // survives in [errorDetail] for an equipment report.
      _setState(
        uuid,
        EquipmentState(
          status: EquipmentStatus.error,
          error: t.settings.station.unknownType(typeKey: node.typeKey),
          errorDetail: 'Unknown equipment type "${node.typeKey}"',
        ),
      );
      _trackFailure(node, 'unknown_type');
      return _ConnectOutcome.failed;
    }

    final config = await _configWithSecrets(node);

    if (type.isUnconfigured(config)) {
      // A port just cleared may have a session up, or an attempt that (as in disconnect()) must learn it lost.
      final runtime = _runtimeFor(uuid)..cancel?.cancel();
      runtime.attemptSeq += 1;
      await _teardown(runtime);
      _setState(uuid, const EquipmentState(status: EquipmentStatus.disconnected));
      return _ConnectOutcome.unconfigured;
    }

    // Guarded, unlike the transport's own connect below, because validate()
    // reads the stored config directly: a value of the wrong shape that gets
    // past every reader in config_field_helpers would otherwise escape as an
    // unhandled async error from a fire-and-forget reconnect. A node whose
    // config cannot even be read is exactly a node to ignore and say so about.
    final String? invalid;
    try {
      invalid = type.validate(config);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:validate-config');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: t.settings.station.configUnreadable, errorDetail: '$e'));
      _trackFailure(node, 'invalid_config', extra: _baudExtra(config));
      return _ConnectOutcome.failed;
    }
    if (invalid != null) {
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: invalid));
      _trackFailure(node, 'invalid_config', extra: _baudExtra(config));
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
    trafficLog?.note(_logLabel(uuid), 'connecting');

    final EquipmentConnection connection;
    try {
      connection = _isK4Remote(node)
          ? await _k4Connections.acquire(
              key: _k4Identity(node),
              target: type.targetFor(config),
              config: type.driverConfig({...config, _k4ConnectionId: _k4Identity(node)}),
              open: transport.connect,
              cancel: cancel,
            )
          : await transport.connect(type.targetFor(config), cancel: cancel);
    } on CatCancelledException {
      // A newer connect (or a disconnect) owns this node now — not a
      // failure, and not ours to report.
      return _ConnectOutcome.superseded;
    } catch (e, st) {
      if (attempt != runtime.attemptSeq) return _ConnectOutcome.superseded;
      // Wrapped for the report only: ErrorPolicy needs to know a bare
      // SocketException came from a connect attempt before it can keep a
      // switched-off rig out of the backend. The state below shows a
      // translated reason for a recognized cause, or the underlying error's
      // own words otherwise — [errorDetail] keeps those words either way,
      // for the equipment report a developer reads.
      ErrorReportingService.report(CatConnectFailure(node.typeKey, e), st, context: 'cat:connect');
      final reason = connectFailureReason(e);
      final friendly = friendlyConnectError(reason, e);
      final raw = '$e';
      // The classified reason, not the error's text: a serial open failure
      // names the port, and the port carries the adapter's serial number.
      trafficLog?.note(_logLabel(uuid), 'connect failed: $reason (${e.runtimeType})');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: friendly, errorDetail: friendly == raw ? null : raw));
      _trackFailure(node, reason, extra: _baudExtra(config));
      if (e is SerialPortProblem && e.failure == SerialFailure.lines) runtime.linesRefused = true;
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
      linkedVfo: () => _linkedVfoHz(uuid),
      onSend: (bytes) => trafficLog?.sent(_logLabel(uuid), bytes),
      onReading: (reading) {
        // A session from a superseded connection must not write state.
        if (runtime.connection != connection) return;
        _applyReading(uuid, reading);
      },
      onPower: (watts) {
        if (runtime.connection != connection) return;
        // What the radio just said is now what it has been told — the same
        // echo discipline [_applyReading] keeps for freq/mode.
        runtime.lastSentPower = watts;
        if (stateFor(uuid).power != watts) _setState(uuid, stateFor(uuid).copyWith(power: watts));
        // Only the designated radio drives the app's power, and tagged
        // `radio` so [_onVfoChanged] doesn't send it straight back. The
        // baseline moves with it: what the radio reports is where the app
        // now is, so the next operator change is measured from there.
        if (uuid == _localRadio1) {
          _lastSeenVfoPower = watts;
          _radio?.setVfo('vfoA', power: watts, origin: VfoOrigin.radio);
        }
      },
      onTransmitting: (transmitting) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a driver may know this WITHOUT the radio saying
        // so — the app keys the rig itself for a CW or voice message — and
        // the silence watch exists to catch a live session over a dead
        // reading stream. A driver whose TX state arrived off the wire
        // reports it as a reading or calls reportAlive itself.
        final state = stateFor(uuid);
        if (state.telemetry.transmitting == transmitting) return;
        if (transmitting) {
          runtime.startTransmission();
        } else if (state.telemetry.transmitting == true) {
          runtime.endTransmission();
        }
        _setState(uuid, state.copyWith(telemetry: state.telemetry.withTransmitting(transmitting)));
        _ptt.onTransmitting(runtime.session, transmitting);
        _meterReadings.notify();
      },
      onMeter: (meter, value) {
        if (runtime.connection != connection) return;
        final state = stateFor(uuid);
        final previous = state.telemetry.meters[meter];
        // Stamped with the app clock, never DateTime.now()
        // (docs/design/time.md) — developer time travel moves the whole app,
        // expiry included.
        final telemetry = state.telemetry.withMeter(meter, value, nowMillis());
        if (meter == RadioMeter.swr) {
          runtime.noteSwr(value, powerOut: state.telemetry.meters[RadioMeter.powerOut]?.value, transmitting: state.telemetry.transmitting);
        }
        // A meter answering with the number it answered with last time is
        // not news. The timestamp still has to move — that is what keeps
        // the reading from expiring under a steady transmission — but at
        // three meters on a 200 ms cycle, repainting every listener fifteen
        // times a second to redraw an unchanged 1.2 is work nobody sees.
        //
        // The receive signal is never news to a listener: band noise moves it
        // by a dB or more between samples, so it would notify for as long as
        // the radio is connected — and what reads it, an extension's
        // `readRadio`, polls the state rather than listening for it.
        _setState(uuid, state.copyWith(telemetry: telemetry), notify: meter != RadioMeter.signalDbm && previous?.value != value);
        // An SWR reading moves the running average even when it repeats the last one.
        if (previous?.value != value || meter == RadioMeter.swr) _meterReadings.notify();
      },
      onCwProgress: (progress) {
        if (runtime.connection != connection) return;
        // A keyer has no VFO to feed the silence watch with — see the
        // reasoning at onSwitchState.
        _noteAlive(uuid, runtime);
        // Only the designated key keys for the app, so only its progress is
        // shown — and reported to a peer following one of this station's
        // radios, which is why it crosses whether or not anything here is
        // looking at the strip.
        _keying.noteCwProgress(uuid, progress);
      },
      onKeyerSpeed: (wpm) {
        if (runtime.connection != connection) return;
        _noteAlive(uuid, runtime);
        if (stateFor(uuid).keyerSpeed != wpm) _setState(uuid, stateFor(uuid).copyWith(keyerSpeed: wpm));
        if (uuid == keyInUse) _keying.onKeyingChanged();
      },
      onVoiceActivity: (activity) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive, unlike onCwProgress: a voice report is made at the
        // app's own keypress and at a local ceiling timer, never from a byte
        // off the radio, so it says nothing about the link. The poll answers
        // that end one feed the watch through the normal reading path.
        _keying.noteVoiceActivity(uuid, activity);
      },
      onVoiceMemories: (memories) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a rename reports the slots itself, from the app's
        // own keypress rather than a byte off the radio.
        if (listEquals(stateFor(uuid).voiceMemories, memories)) return;
        _setState(uuid, stateFor(uuid).copyWith(voiceMemories: memories));
        // A peer following this radio reads the names and lengths off its
        // status, which only a keying change republishes.
        _keying.onKeyingChanged();
      },
      onProblem: (message) {
        if (runtime.connection != connection) return;
        if (stateFor(uuid).problem == message) return;
        if (message != null) trafficLog?.note(_logLabel(uuid), 'problem: $message');
        _setState(uuid, stateFor(uuid).copyWith(problem: message, clearProblem: message == null));
      },
      onChannels: (channels) {
        if (runtime.connection != connection) return;
        if (listEquals(stateFor(uuid).channels, channels)) return;
        _setState(uuid, stateFor(uuid).copyWith(channels: channels));
      },
      onSwitchState: (antennas, ports) {
        if (runtime.connection != connection) return;
        // The switch said something, so it is not silent — whatever it said,
        // and whether or not any of it differs from last time.
        //
        // Without this the watchdog is fed by VfoReadings alone, and
        // equipment that has no VFO to report goes stale 30 s after every
        // connect however healthy it is. That was invisible while the only
        // thing in this layer was radios.
        _noteAlive(uuid, runtime);
        final state = stateFor(uuid);
        // Both compared before either is written: a switch reports the whole
        // picture on every port change, so the antenna list is identical
        // almost every time and only the ports actually moved.
        if (listEquals(state.switchAntennas, antennas) && listEquals(state.switchPorts, ports)) return;
        _setState(uuid, state.copyWith(switchAntennas: antennas, switchPorts: ports));
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
        // In the log as well: the screen shows it only in developer mode,
        // and the operators who run DEVLOGCAT are not in it.
        if (note != null) trafficLog?.note(_logLabel(uuid), 'driver: $note');
        _setState(uuid, stateFor(uuid).copyWith(diagnostic: note, clearDiagnostic: note == null));
      },
      onAlive: () {
        if (runtime.connection != connection) return;
        _noteAlive(uuid, runtime);
      },
      onSpectrum: (frame) {
        if (runtime.connection != connection) return;
        // NOT _noteAlive: a Flex sweep is computed from a UDP stream that
        // outlives the command socket the silence watch is about.
        runtime.spectrum?.add(frame);
      },
      onSpectrumSettings: _spectrumSettingsListener(uuid, runtime, connection),
      onSpectrumProblem: (message) {
        if (runtime.connection != connection || stateFor(uuid).spectrumProblem == message) return;
        _setState(uuid, stateFor(uuid).copyWith(spectrumProblem: message, clearSpectrumProblem: message == null));
      },
      onTuner: (status) {
        if (runtime.connection != connection || stateFor(uuid).tuner == status) return;
        _setState(uuid, stateFor(uuid).copyWith(tuner: status, clearTuner: status == null));
      },
      onPassband: (passband) {
        if (runtime.connection != connection || stateFor(uuid).passband == passband) return;
        _setState(uuid, stateFor(uuid).copyWith(passband: passband, clearPassband: passband == null));
      },
      onAntennas: (antennas) {
        if (runtime.connection != connection || stateFor(uuid).antennas == antennas) return;
        _setState(uuid, stateFor(uuid).copyWith(antennas: antennas, clearAntennas: antennas == null));
      },
    );
    // driverConfig, not config: a type may know something about its
    // protocol that is not a setting anyone should be asked for — the
    // IC-705's network controller address, for one.
    final EquipmentSession session;
    try {
      session = connection is K4ReceiverConnection
          ? connection.createSession(sink, receiver: _k4Receiver(node))
          : type.driver.createSession(sink, type.driverConfig(config));
    } catch (e, st) {
      // The physical connection can end while an acquired lease is queued
      // for attachment. A failed attachment must release its connection.
      unawaited(connection.close());
      ErrorReportingService.report(CatConnectFailure(node.typeKey, e), st, context: 'cat:create-session');
      _setState(uuid, EquipmentState(status: EquipmentStatus.error, error: friendlyConnectError(connectFailureReason(e), e)));
      return _ConnectOutcome.failed;
    }

    runtime.connection = connection;
    runtime.session = session;
    // This connection has heard nothing yet, whatever the last one heard.
    runtime.proof.reset();
    // The baud rate and nothing else of the config: the log leaves the device,
    // and a serial port name carries the adapter's serial number on macOS.
    trafficLog?.note(_logLabel(uuid), config['baudRate'] == null ? 'connected' : 'connected at ${config['baudRate']} baud');
    runtime.subscription = connection.data.listen((chunk) {
      // Not an SDR's IQ: megabytes a second of it would fill the log in
      // moments and end the recording of the CAT traffic it exists for.
      // Shared K4 CAT is recorded once at the physical connection boundary.
      if (type.category != kCategorySdr && connection is! K4ReceiverConnection) trafficLog?.received(_logLabel(uuid), chunk);
      runtime.heard(chunk);
      try {
        session.handleData(chunk);
      } catch (e, st) {
        // One malformed frame must not kill the connection.
        ErrorReportingService.report(e, st, context: 'cat:handle-data:${type.driver.key}');
      }
    });

    unawaited(
      connection.closed.then((_) {
        // A stale connection's close must not clobber a live one's status.
        if (runtime.connection != connection) return;
        trafficLog?.note(_logLabel(uuid), 'connection closed by the transport');
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
        // An SDR comes back for the display still waiting on it.
        _retrySdr(runtime);
        // And keep trying slowly afterwards, in case that burst is spent before
        // the radio is back.
        //
        // Unconditional on purpose. A guard on which node dropped would be
        // dead code: [_scheduleIdleRetry] reads the nodes it covers itself and
        // stops on the first tick if each is connected or absent, so the guard
        // could not change any outcome. One place decides, and it is the loop.
        _scheduleIdleRetry();
      }),
    );

    _setState(uuid, const EquipmentState(status: EquipmentStatus.connected));
    if (_trackedConnected.add(uuid)) _trackRadio('radio_connected', node);
    _armStaleWatch(uuid, runtime);

    // Start updates on connect rather than when a UI subscriber shows up:
    // polo gated this on a refcount, so connecting with no screen mounted
    // succeeded and then never asked the radio anything.
    try {
      session.startUpdates();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:start-updates:${type.driver.key}');
    }
    runtime.spectrumStarted = false;
    if (runtime.spectrum?.hasListener ?? false) _spectrumDemand(runtime, true);
    _settleSdr(runtime);
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
      // radio1, and the key in use when it is a device of its own: the two
      // nodes the app depends on, so the two this loop brings back.
      final wanted = _autoConnectTargets;

      // STOP only for a reason that will not resolve itself: there is nothing
      // designated, the node is gone, the operator switched it off, its port
      // was refused over its control lines, it is held from a launch that
      // died connecting it, or it is already connected.
      // connect/disconnect and a dropped session restart it.
      bool settled(String uuid) =>
          !_nodes.containsKey(uuid) ||
          (_runtimes[uuid]?.userDisconnected ?? false) ||
          (_runtimes[uuid]?.linesRefused ?? false) ||
          _autoConnectHeld.contains(uuid) ||
          stateFor(uuid).status == EquipmentStatus.connected;
      final open = wanted.where((uuid) => !settled(uuid)).toList();
      if (open.isEmpty) {
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
      if (open.any((uuid) {
        final status = stateFor(uuid).status;
        return status == EquipmentStatus.connecting || status == EquipmentStatus.disconnecting;
      })) {
        _scheduleIdleRetry();
        return;
      }

      // Double first, so a failure that arrives after this fire still leaves
      // the next wait longer than this one.
      _idleRetryDelay = _idleRetryDelay * 2 > _idleRetryMax ? _idleRetryMax : _idleRetryDelay * 2;
      unawaited(
        Future.wait(open.map(_autoConnect)).then((outcomes) {
          if (outcomes.every((outcome) => outcome == _ConnectOutcome.connected || outcome == _ConnectOutcome.unconfigured)) {
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
        }),
      );
    });
  }

  /// Whether [uuid] is the key in use and a device of its own (a keyer node,
  /// not a radio doubling as one) — what the app's keying depends on, so it
  /// is brought back the way radio1 is.
  bool _isDesignatedKeyerDevice(String uuid) {
    if (designatedFor(kCategoryKey) != uuid) return false;
    final node = _nodes[uuid];
    return node != null && typeFor(node)?.category == kCategoryKeyer;
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
    if (_disposed || !_autoConnectTargets.contains(uuid)) return;
    final reconnectKey = logicalDeviceIdFor(uuid) ?? uuid;
    final last = _lastAutoReconnect[reconnectKey];
    // Real time: this cooldown rate-limits real reconnect attempts against a
    // real radio, so a rescaled clock would let a storm through.
    final now = realNowUtc();
    if (last != null && now.difference(last) < _autoReconnectCooldown) {
      debugPrint('[cat] auto-reconnect suppressed: last was ${now.difference(last).inSeconds}s ago');
      return;
    }
    _lastAutoReconnect[reconnectKey] = now;
    // A shared link completes every lease's `closed` future together. Let
    // all of those callbacks mark their receivers disconnected before the
    // one permitted burst checks them; the sibling's cooldown skips its own
    // burst, and a still-connected status would otherwise leave it behind.
    unawaited(Future<void>.microtask(reconnectDesignatedRadio));
  }

  /// radio1, and the key in use when it is a device of its own: both are
  /// what the app depends on, and neither should wait for a button.
  Future<void> reconnectDesignatedRadio() async => Future.wait(_autoConnectTargets.map(_reconnectWithRetries)).then((_) {});

  Future<void> _reconnectWithRetries(String? uuid) async {
    if (uuid == null || !_nodes.containsKey(uuid)) return;
    // A deliberate Disconnect holds whatever else drops: the other device
    // coming back must not bring this one with it.
    if (_runtimes[uuid]?.userDisconnected ?? false) return;

    for (var attempt = 0; attempt <= _reconnectRetries; attempt++) {
      // The delay below can't be cancelled, so the service may have been
      // disposed while this loop was parked on it.
      if (_disposed) return;

      final status = stateFor(uuid).status;
      // Connected already, or someone is mid-connect — either way, not ours.
      if (status == EquipmentStatus.connected || status == EquipmentStatus.connecting) return;

      final outcome = await _autoConnect(uuid);
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

  /// [byUser] false is the app letting go of a node it connected for itself
  /// — an SDR no display wants any more — which must not read as the
  /// operator switching it off.
  Future<void> disconnect(String uuid, {bool byUser = true}) async {
    final runtime = _runtimes[uuid];
    if (runtime == null) return;
    // Recorded BEFORE the teardown, because the retry loop reads it later and
    // has no other way to tell this from a radio that vanished.
    if (byUser) {
      runtime.userDisconnected = true;
      runtime.sdrPinned = false;
    }
    runtime.cancelSdrTimers();
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
    _settleSdr(runtime);
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

  /// The equipment just spoke: restart the silence watch, and drop the stale
  /// mark if it was set.
  ///
  /// Anything at all counts, including a report identical to the last one —
  /// a radio answering "still 14074" is a radio that is answering, and a
  /// switch restating its routing is a switch with a live socket.
  void _noteAlive(String uuid, _NodeRuntime runtime) {
    _armStaleWatch(uuid, runtime);
    if (!runtime.state.stale) return;
    trafficLog?.note(_logLabel(uuid), 'answering again');
    _setState(uuid, runtime.state.copyWith(stale: false));
  }

  /// Restarts the silence watch. Any reading at all counts, including one
  /// that repeats the last: a radio answering "still 14074" is a radio that
  /// is answering.
  void _armStaleWatch(String uuid, _NodeRuntime runtime) {
    runtime.staleTimer?.cancel();
    runtime.staleTimer = Timer(staleAfter, () {
      if (_disposed) return;
      final current = _runtimes[uuid];
      if (current == null || current.state.status != EquipmentStatus.connected) return;
      if (current.state.stale) return;
      trafficLog?.note(_logLabel(uuid), 'nothing heard for ${staleAfter.inSeconds} s: marked not responding');
      _setState(uuid, current.state.copyWith(stale: true));
    });
  }

  /// Fires [onRadioProven] on the reading that completes the pair. [reading]
  /// is the driver's RAW frame — [RadioProofWatch] says why that matters.
  void _noteProven(String uuid, _NodeRuntime runtime, VfoReading reading) {
    if (!runtime.proof.note(reading)) return;
    if (!_provenThisSession.add(uuid)) return;
    final node = _nodes[uuid];
    if (node == null) return;
    // Never let a reporting failure reach the reading path: this runs on
    // every frame a radio sends, and a throw here would take down the
    // session that is working — the one outcome a success report must not
    // produce.
    try {
      onRadioProven?.call(node);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:radio-proven');
    }
  }

  void _applyReading(String uuid, VfoReading reading) {
    final runtime = _runtimeFor(uuid);
    // The radio said something, so it is not silent — whatever it said.
    _noteAlive(uuid, runtime);
    // A partial reading is completed from what the radio was last TOLD
    // before what it last SAID. The two agree except in one window: a tune
    // carrying both fields sends them as two commands, and the rig echoes
    // the first before the second has landed. Filling from the rig's own
    // last word there would answer a mode echo with the PRE-tune frequency
    // and push that back to the panel — a spot tap would visibly bounce the
    // frequency and band back to where the rig came from. `lastSent` falls
    // back per field, so a deliberately cleared frequency (a band pick)
    // still reads through to the radio's value rather than resurrecting one.
    _noteProven(uuid, runtime, reading);

    final sent = runtime.lastSent;
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? sent?.freqKHz ?? runtime.state.vfo.freqKHz,
      // CW-R is reverse-sideband CW, not a mode of its own to the rest of the
      // app — every driver's own vocabulary keeps it (a radio must still be
      // told to flip sideband), but nothing past this point should learn a
      // mode ADIF and the log don't have.
      mode: (reading.mode == 'CW-R' ? 'CW' : reading.mode) ?? sent?.mode ?? runtime.state.vfo.mode,
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

    // What the radio just said is now what it has been told — [tuneNode]'s
    // echo guard, and what keeps a knob turn from coming back to the rig as
    // a command. EVERY node, not just radio1: a radio a peer is driving
    // (HALO-416) needs the same guard and never passes through
    // [_onVfoChanged].
    runtime.lastSent = merged;

    // Only the designated radio drives the app's VFO. Tagging the write
    // `radio` is what lets _onVfoChanged recognise the notification it's
    // about to receive as its own, instead of re-tuning the radio to the
    // value the radio just gave it.
    if (uuid != _localRadio1) return;
    final mode = appModeForRadioReport(current: _radio?.vfoA.mode, reported: merged.mode, freqKHz: merged.freqKHz);
    _radio?.setVfo('vfoA', freq: merged.freqKHz, mode: mode, origin: VfoOrigin.radio);
    _noteSnapReading(merged);
  }

  /// The app's VFO moved — the operator typed a frequency, picked a band,
  /// ran a command, or clicked a spot. Retune the radio to match.
  void _onVfoChanged() {
    final radio = _radio;
    if (radio == null) return;
    // Ahead of the echo check below: the radio's own knob moving off the CQ
    // frequency ends a repeat as surely as a frequency typed in the app. But
    // not the radio's reading while it transmits: working split, a rig may
    // report the frequency it is transmitting on, which is no QSY — and would
    // end every split CQ at its first send. The reading after it unkeys is
    // the one that says where it went.
    if (radio.lastVfoOrigin != VfoOrigin.radio || !radio1IsTransmitting) _repeat.noteVfo(radio.vfoA);
    // Our own write, coming back around. Forwarding it would tell the radio
    // to go where it already is, and its confirmation would arrive as
    // another notification.
    if (radio.lastVfoOrigin == VfoOrigin.radio) return;
    // Whatever the operator just stated — typed, picked, or tapped from a
    // spot — is exact intent and is where the next knob turn is measured
    // from. Any snap still pending was decided against a frequency nobody is
    // on any more. (Our OWN snap arrives here too, harmlessly: it rebases to
    // the value the snapper already settled on.) An on-screen dial is the
    // exception: it is a knob turning, measured like the radio's own.
    if (radio.lastVfoOrigin == VfoOrigin.dial) {
      _noteSnapReading(VfoReading(freqKHz: radio.vfoA.freq, mode: radio.vfoA.mode));
    } else {
      _cancelSnap(radio.vfoA.freq);
    }

    // The baseline moves here, ahead of the returns below, so it tracks the
    // app's power whether or not there is a radio to tell. A power stated
    // while the rig is absent is lost exactly as a frequency typed then is —
    // and on the next connect the radio's own reading is what both sides
    // take, rather than a stale value being pushed at it.
    final powerChanged = radio.vfoA.power != _lastSeenVfoPower;
    _lastSeenVfoPower = radio.vfoA.power;

    final uuid = _localRadio1;
    if (uuid == null) return;
    if (_runtimes[uuid]?.session == null) {
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
    tuneNode(
      uuid,
      VfoReading(
        freqKHz: vfo.freq,
        mode: resolveSideband(vfo.mode, vfo.freq, band: vfo.band),
      ),
    );
    // Only a CHANGE of the app's power is a command to the radio. Every VFO
    // notification arrives here — a typed frequency, a band pick — and a
    // remembered power sent on the first of them would re-assert a value
    // nobody stated this session: on an IC-705 the last thing the app heard
    // may be a battery-derated READING (`icom_civ_driver`), and pushing that
    // back would turn a display cap into the rig's actual power. A cleared
    // power is the operator saying they don't know it, not a command to run
    // the radio at nothing.
    if (powerChanged && vfo.power != null) setPower(vfo.power!);
  }

  /// The app's power as this service last saw it — the baseline
  /// [_onVfoChanged] measures a real change against. Seeded in the
  /// constructor from what the VFO already holds (NOT lazily: a `late`
  /// initializer would run on its first read, inside [_onVfoChanged], and
  /// record the very value it is being asked to compare against), so a
  /// restored session starts agreed with the VFO rather than treating a
  /// remembered power as something to send.
  num? _lastSeenVfoPower;

  /// Puts one node's radio on [wanted], echo discipline included.
  ///
  /// Public because `radio1` is no longer the only radio that gets tuned:
  /// one this device OFFERS to a peer (HALO-416) is driven from the far
  /// side's operator and never passes through [_onVfoChanged], which reads
  /// `vfoA` — a VFO that rig is not attached to.
  void tuneNode(String uuid, VfoReading requested) {
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    if (session == null) return;
    // Drivers speak the radio's modes, and `lastSent` records them: an FT8
    // VFO goes out as DATA-USB, and the rig's DATA-USB echo then matches it.
    final wanted = VfoReading(freqKHz: requested.freqKHz, mode: radioModeForAppMode(requested.mode, requested.freqKHz));
    // Nothing the radio doesn't already have. A band pick with no
    // frequency, or a mode restatement, must not re-send a tune command.
    final previous = runtime!.lastSent;
    if (wanted == previous) return;

    // Same narrowing as setPower: nothing without a VFO is tunable.
    if (session is! TransceiverSession) return;

    try {
      // Per field, and against what was last SENT rather than what the
      // radio last reported: a radio that hasn't confirmed yet would
      // otherwise get the frequency re-sent every time the mode changed.
      final freqKHz = wanted.freqKHz;
      final mode = wanted.mode;
      final freqChanged = freqKHz != null && freqKHz != previous?.freqKHz;
      final modeChanged = mode != null && mode != previous?.mode;
      // Measured against what was last sent, and any UNKNOWN counts as
      // changed: a freshly connected rig is wherever its operator left it,
      // and a frequency outside every band plan has no band to compare —
      // two of those are not "the same band" just because both are null.
      // Both are exactly when the recall below bites.
      final previousFreqKHz = previous?.freqKHz;
      final previousBand = previousFreqKHz == null ? null : bandForFrequency(previousFreqKHz);
      final newBand = freqChanged ? bandForFrequency(freqKHz) : null;
      final bandChanged = freqChanged && (previousBand == null || newBand == null || newBand != previousBand);

      if (bandChanged && mode != null) {
        // Crossing a band, the order is frequency, mode, FREQUENCY AGAIN,
        // and the mode goes out EVEN WHEN IT HASN'T CHANGED. Two rig
        // behaviours have to be survived at once and each defeats the
        // other's remedy: a rig that recalls a per-band mode overwrites a
        // mode sent before the frequency, and a rig that reads a frequency
        // against the mode in force (a per-mode offset or band edge) lands
        // off-target when the mode arrives after. So: get onto the band,
        // state the mode there — after any recall has had its say — and
        // re-state the frequency in case setting the mode moved it.
        session.setFrequency(freqKHz);
        session.setMode(mode);
        session.setFrequency(freqKHz);
      } else {
        // Within a band nothing recalls anything, so the mode leads and the
        // frequency lands in the mode it belongs to.
        if (modeChanged) session.setMode(mode);
        if (freqChanged) session.setFrequency(freqKHz);
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
    runtime.lastSentPower = null;
    // Whatever this node was keying is not keying now — and a radio that is
    // gone is playing nothing, which a peer following it has to be told.
    for (final entry in _runtimes.entries) {
      if (!identical(entry.value, runtime)) continue;
      if (session != null) trafficLog?.note(_logLabel(entry.key), 'session closed');
      _keying.forgetNode(entry.key, wasKeyInUse: entry.key == keyInUse, wasRadio1: entry.key == _localRadio1);
    }
    // A pending snap belongs to the session that reported the movement. It
    // has nowhere to be sent now, and the next session's first reading is a
    // fresh resting point, not the continuation of a knob turn. Only for the
    // designated radio — nothing else ever feeds the snapper, and clearing it
    // when some other node disconnects would drop a live knob turn.
    if (_localRadio1 != null && identical(_runtimes[_localRadio1], runtime)) _cancelSnap(null);

    if (subscription != null) await subscription.cancel();

    if (session != null) {
      _ptt.forget(session);
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

  /// Fires on every meter reading that changed and every TX change, the
  /// receive signal included — unlike the service itself, which stays quiet
  /// for the signal because band noise would rebuild every listener for as
  /// long as a radio is connected — and whenever the service notifies: a
  /// radio that disconnects or goes stale sends no reading to say so. For
  /// what draws meters live (a scene's `radio.` values), and nothing else.
  late final Listenable meterReadings = Listenable.merge([_meterReadings, this]);
  final _meterReadings = _MeterReadings();

  @override
  void dispose() {
    _disposed = true;
    _radio?.removeListener(_onVfoChanged);
    // Cancelled, not merely guarded: the callback checks _disposed, but a
    // pending timer can still sit scheduled for minutes, and a test harness
    // will rightly complain about one outliving its service.
    _idleRetryTimer?.cancel();
    _idleRetryTimer = null;
    _cancelSnap(null);
    stopDiscovery();
    for (final runtime in _runtimes.values) {
      runtime.cancel?.cancel();
      runtime.cancelSdrTimers();
      unawaited(_teardown(runtime));
      unawaited(runtime.spectrum?.close());
    }
    unawaited(_k4Connections.dispose());
    // After the teardowns, whose synchronous prefix clears cwProgress for
    // the designated radio — a notifier disposed first would be notified.
    cancelKeyerRepeat();
    _keying.dispose();
    pttKeys.dispose();
    _ptt.dispose();
    _repeat.dispose();
    _meterReadings.dispose();
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
