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
import 'package:halo_audio/halo_audio.dart' show AudioPlayback;
import 'package:halo_core/halo_core.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../error_reporting_service.dart';
import '../hang_watchdog.dart';
import '../peer/peer_station_radios.dart';
import '../radio_service.dart';
import '../settings_service.dart';
import 'auto_connect_guard.dart';
import 'cat_keying.dart';
import 'cat_ptt.dart';
import 'computer_voice_keyer.dart';
import 'cat_traffic_log.dart';
import 'connect_failure.dart';
import 'cw_live_typing.dart';
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
import 'voiced_words.dart';

// The keyer area names a wait; it reads everything else about keying off
// this service, so the type comes with it rather than through a second
// import of an implementation file.
export 'cat_keying.dart' show WaitingSend;
export 'keyer_repeat.dart' show KeyerRepeatWait;
export 'main_vfo.dart';

part 'cat_node_sink.dart';
part 'cat_spectrum.dart';
part 'cat_node_runtime.dart';
part 'cat_radio_controls.dart';
part 'cat_discovery.dart';
part 'cat_vfo_snap.dart';
part 'cat_connection.dart';
part 'cat_readings.dart';
part 'cat_band_pick.dart';
part 'cat_equipment_store.dart';
part 'cat_tracking.dart';
part 'cat_peer_offers.dart';
part 'cat_keying_surface.dart';
part 'cat_so2r.dart';
part 'cat_k4.dart';
part 'cat_credentials.dart';

/// Bump when the stored shape changes in a way a reader has to know about.
///
/// 2 — `designated` became per radio (radio → category → uuid). Version 1's
/// blob is one flat category → uuid map, and `_load`
/// (cat_equipment_store.dart) migrates it.
///
/// 3 — the two `radio1` / `remoteRadio1` keys became one `mainVfo`, holding
/// whichever kind of radio was picked. Older blobs are read from the old
/// pair by `_load` (cat_equipment_store.dart).
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

/// How long a designated radio that has answered may then say nothing before
/// it is dropped and reconnected. Twice [catStaleAfter], so the row reads "not
/// responding" for half a minute before anything is done about it.
const _silentDropAfter = Duration(seconds: 60);

/// How many [CatService.silentDropAfter] windows a radio whose last report
/// said it was transmitting may stay silent before it is dropped. Five
/// minutes: past a long over, and past most radios' own transmit time-out.
const _silentWhileKeyedWindows = 5;

/// How many silent drops in a row, each ending a session that answered for
/// less than [_healthySessionWindows] windows, before the next silence is left
/// as "not responding" for the operator.
const _silentDropsInARow = 3;
const _healthySessionWindows = 10;

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

class CatService extends ChangeNotifier
    with _RadioControls, _Discovery, _VfoSnap, _PeerOffers, _KeyingSurface, _So2r
    implements PeerStationRadios, KeyingStation {
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

  /// How long a designated radio that has answered may then say nothing
  /// before it is dropped and reconnected. Injectable for the same reason
  /// [staleAfter] is.
  final Duration silentDropAfter;

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
    this.silentDropAfter = _silentDropAfter,
    VoiceAudio? voiceAudio,
    Future<String> Function()? voiceMessagesDirectory,
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
    _startSo2r();
    _ptt.held.addListener(_restartSilentDrops);
    // The computer's voice keyer, where this device can run one.
    if (voiceAudio != null && voiceAudio.isSupported && voiceMessagesDirectory != null) {
      _keying
        ..voiceAudio = voiceAudio
        ..voiceMessagesDirectory = voiceMessagesDirectory
        ..onComputerVoiceChanged = () {
          if (!_disposed) notifyListeners();
        };
      // Every change that makes or unmakes one — a session opened, the
      // directory found, a set picked — is one this service announces.
      addListener(_keying.syncComputerKeyers);
      // Made now rather than when first asked for: it is what makes a
      // templated message, and a key can ask for one before any surface has.
      _keying.voicedWords;
    }
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

  /// The nodes an automatic reconnect aims at: radio1 and radio2, and the key
  /// in use when it is a device of its own. All are what the app depends on,
  /// and none should wait for a button. A K4 also restores the logical
  /// receivers sharing either radio's physical connection.
  Set<String> get _autoConnectTargets {
    return {
      ?_localRadio1,
      ?radio2,
      ..._k4SiblingIds(_localRadio1),
      ..._k4SiblingIds(radio2),
      for (final keyer in {designatedFor(kCategoryKey), if (radio2 != null) designatedFor(kCategoryKey, radio: radio2)})
        if (keyer != null && _isKeyerDevice(keyer)) keyer,
    };
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
  @override
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
      // One rig never fills both roles: `vfoA` and `vfoB` would tune it
      // against each other.
      if (next case LocalRadio(:final uuid) when uuid == _radio2) _forgetRadio2();
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

  /// [category]'s pick for [radio] — a local transceiver's uuid, SO2R's
  /// Radio B being the one caller that names one — or for radio1.
  ///
  /// Never one key for both SO2R radios: a key keys one message at a time,
  /// and two keyers sharing it stop each other's. Radio B's key answers
  /// None while it is radio1's — which a change of radio1 can make it,
  /// restoring that radio's own picks.
  String? designatedFor(String category, {String? radio}) {
    final pick = _pickFor(category, radio);
    if (category == kCategoryKey && radio != null && radio == radio2 && pick != null && pick == _pickFor(category, null)) return null;
    return pick;
  }

  String? _pickFor(String category, String? radio) {
    final picks = _designated[radio ?? _designationKey()];
    if (picks != null && picks.containsKey(category)) return picks[category];
    return _defaultDesignation(category, radio ?? _localRadio1);
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
  String? _defaultDesignation(String category, String? uuid) {
    if (category != kCategoryKey) return null;
    if (!_settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */ ) return null;
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

  /// Picks [uuid] as [category] for [radio] — see [designatedFor].
  Future<void> setDesignated(String category, String? uuid, {String? radio}) async {
    final key = radio ?? _designationKey();
    final previousUuid = designatedFor(category, radio: radio);
    // An ANSWER is stored even when it matches the default it replaces:
    // "nothing chosen" and "chose None" resolve alike right now but are not
    // the same state, and the difference decides whether a default can take
    // over later — a peer radio whose operator said None keys nothing, and
    // one whose operator said nothing keys through that peer.
    final answered = _designated[key]?.containsKey(category) ?? false;
    if (answered && previousUuid == uuid) return;
    // One key per SO2R radio, as one rig per role: Radio B is refused
    // radio1's key, and radio1 taking Radio B's leaves Radio B with None.
    final b = radio2;
    final isKey = category == kCategoryKey && uuid != null && b != null;
    if (isKey && radio == b && uuid == designatedFor(category)) return;
    final takesB = isKey && radio == null && uuid == designatedFor(category, radio: b);
    // Only a real CHANGE of the key IN USE owes the outgoing one anything. A
    // dropdown reports the already-selected item being tapped, and abandoning
    // the message going out because the operator re-picked the key that is
    // keying it would stop a CQ mid-word — and under SO2R the radio being
    // edited may not be the one keying at all.
    _withKeyInUseTidied(() {
      (_designated[key] ??= {})[category] = uuid;
      if (takesB) (_designated[b] ??= {})[category] = null;
    });
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
  /// Each radio's keyer has a key in use of its own — radio1's, and under
  /// SO2R Radio B's — and either may move.
  @override
  void _withKeyInUseTidied(void Function() mutate) {
    final keyers = [_keyerOf('A'), _keyerOf('B')];
    final previous = [for (final keyer in keyers) keyer.station.keyInUse];
    mutate();
    for (final (i, keyer) in keyers.indexed) {
      // What a change of key in use owes the outgoing one — whether the
      // operator picked a different key or moved to a radio that keys
      // through something else. The old keyer's message would otherwise
      // finish with nothing showing it and nothing to stop it; the new one's
      // speed is read so the row is not left on the old one's.
      if (keyer.station.keyInUse != previous[i]) keyer.abandonKeying(previous[i]);
    }
  }

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

  // --------------------------------------- what keying asks of the station

  /// Radio1's key in use, as a node uuid — null for None, and null for a
  /// peer's own keying, which is no node of this station ([peerKeyIsInUse]).
  /// Radio B's keyer has its own (`_RadioBKeyingStation`).
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
  @override
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

  String? get localRadio1 => _localRadio1;

  @override
  String? get localKeyingRadio => _localRadio1;

  @override
  bool clearToSend({required bool repeat, bool queuedCw = false}) => _clearToSend('A', repeat: repeat, queuedCw: queuedCw);

  @override
  void _setEnterSendsOf(bool running) => _keying.setEnterSends(running: running);

  @override
  Future<void> _connectRadio2() => _reconnectWithRetries(radio2);

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
    // (docs/design/cat.md § The picks belong to the radio) — and under SO2R
    // of Radio B too: nothing says which radio a two-radio switch's port
    // feeds, so neither may be transmitting. A radio that cannot say — every
    // driver reporting no TX state, which is most of them — leaves
    // `transmitting` null and the selection goes through: a switch an
    // operator could never work would be worse than the switch they have
    // today.
    if (radio1IsTransmitting || _nodeTransmitting(radio2)) {
      // Said out loud, in the one place a developer will look. The refusal
      // is right, but a tap that does nothing at all is indistinguishable
      // from a switch that has stopped working — and the operator has no
      // other way to tell those apart.
      final keyed = radio1IsTransmitting ? _localRadio1 : radio2;
      debugPrint('[cat] antenna selection refused: ${keyed == null ? 'a radio' : displayNameFor(nodeFor(keyed)!)} is transmitting');
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
  bool get radio1IsTransmitting => _nodeTransmitting(_localRadio1);

  @override
  bool _nodeTransmitting(String? uuid) {
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
    final keyed = _ptt.heldOn(connectedSession(uuid)) || _keying.computerKeyed(uuid);
    if (state.stale) return keyed;
    return state.telemetry.isTransmitting || keyed;
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

  @override
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
    'radio2': _radio2,
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
      uuid: uuidGenerator.v4(),
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
      if (_radio2 == uuid) _forgetRadio2();
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
      ..shortSilentDrops = 0
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

  /// Reconnects the designated radio at launch — radio1, and the key in use
  /// when it is a device of its own: both are what the app depends on, and
  /// neither should wait for a button.
  ///
  /// Retried a couple of times because the radio may still be powering up,
  /// or the WiFi still associating — but it gives up quietly rather than
  /// nagging: the user can always connect from Settings.
  ///
  /// The retry never fights the user. It stops the moment anything else
  /// owns the node — a manual Connect, a Disconnect, or a connection that
  /// is already up — which is the failure mode that made polo's
  /// auto-reconnect the source of all four of its connection races.
  Future<void> reconnectDesignatedRadio() async => Future.wait(_autoConnectTargets.map(_reconnectWithRetries)).then((_) {});

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
    // the one that says where it went. Each radio's repeat watches its own
    // VFO: the other one moving is the operator working the other radio.
    final onB = radio.lastVfoKey == 'vfoB';
    if (radio.lastVfoOrigin != VfoOrigin.radio || !_nodeTransmitting(onB ? radio2 : _localRadio1)) {
      _keyerOf(onB ? 'B' : 'A').chain.noteVfo(radio.vfo(radio.lastVfoKey));
    }
    if (onB) return _onVfoBChanged(radio);
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

    _retune(uuid, 'vfoA');
    final vfo = radio.vfoA;
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

  /// Sends [uuid]'s radio where [vfoKey] — the VFO it drives — now says: to
  /// a band picked by name ([_pickBand]), else to the VFO's frequency and
  /// mode.
  @override
  void _retune(String uuid, String vfoKey) {
    final vfo = _radio?.vfo(vfoKey);
    if (vfo == null) return;
    // Whatever the operator says next replaces a band pick still on its way.
    final runtime = _runtimes[uuid];
    final heading = runtime?.bandPick;
    if (runtime != null) _cancelBandPick(runtime);
    if (_pickBand(uuid, vfoKey, vfo, heading: heading)) return;
    tuneNode(
      uuid,
      VfoReading(
        freqKHz: vfo.freq,
        mode: resolveSideband(vfo.mode, vfo.freq, band: vfo.band),
      ),
    );
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
  @override
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
    _stopSo2r();
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
    // Before the notifiers they report into are disposed.
    _keying.disposeComputerKeyers();
    for (final keyer in _keyers.values) {
      keyer.chain.cancel();
      keyer.dispose();
      keyer.chain.dispose();
    }
    pttKeys.dispose();
    _ptt.dispose();
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
