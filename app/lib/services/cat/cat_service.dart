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

import '../../i18n/strings.g.dart';
import '../error_reporting_service.dart';
import '../peer/peer_station_radios.dart';
import '../radio_service.dart';
import '../settings_service.dart';
import 'discovery.dart';
import 'driver.dart';
import 'drivers/cw_send_queue.dart' show CwSendProgress;
import 'equipment.dart';
import 'equipment_registry.dart';
import 'transport.dart';
import 'vfo_snap.dart';

const _uuidGenerator = Uuid();

/// Bump when the stored shape changes in a way a reader has to know about.
const _storageVersion = 1;

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

class CatService extends ChangeNotifier implements PeerStationRadios {
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
      this.idleRetryFirst = _idleRetryFirst,
      this.staleAfter = _staleAfter})
      : assert(idleRetryFirst > Duration.zero, 'a zero first delay makes the backoff a tight loop'),
        registry = registry ?? EquipmentRegistry(),
        _onTrack = onTrack,
        _radio = radio {
    _load();
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
    track(event, {
      'radio': node.typeKey,
      'transport': type?.transportKey,
      'driver': type?.driver.key,
      'name': _trackedName(name),
      ...extra,
    });
  }

  /// The name field has no length limit in the editor, unlike every other
  /// property this event sends — all bounded by our own catalogue. Capped
  /// here, at the one place all `radio_*` events funnel through, rather than
  /// in the editor: a length limit there is a UX decision for the name
  /// operators see everywhere, not a telemetry one.
  static const _maxTrackedNameLength = 60;

  static String _trackedName(String name) =>
      name.length <= _maxTrackedNameLength ? name : name.substring(0, _maxTrackedNameLength);

  /// A bounded classification, never the exception's text: `'$e'` routinely
  /// carries the port path or host that failed. Matched on the type NAME for
  /// SocketException because dart:io does not exist on web, where this same
  /// service runs over Web Serial.
  static String _failureReason(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error.runtimeType.toString() == 'SocketException') return 'network';
    return 'other';
  }

  /// What the equipment row shows for a failed connect. [reason] is
  /// [_failureReason]'s classification, reused rather than re-derived so
  /// there's one place deciding what counts as a network or timeout error.
  /// `'other'` keeps the exception's own words — `error.toString()` — since
  /// guessing at an unfamiliar cause would be more likely to mislead an
  /// operator than a raw Dart message already is.
  static String _friendlyConnectError(String reason, Object error) {
    switch (reason) {
      case 'timeout':
        return t.settings.station.connectFailedTimeout;
      case 'network':
        return t.settings.station.connectFailedNetwork;
      default:
        return '$error';
    }
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
  void _trackFailure(EquipmentNode node, String reason, {Map<String, Object?> extra = const {}}) {
    if (!_trackedFailed.add(node.uuid)) return;
    _trackRadio('radio_connect_failed', node, extra: {'reason': reason, ...extra});
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

  /// The peer radio driving `vfoA`, when it is not a local one (HALO-416).
  ///
  /// Plain stored state beside [radio1], and MUTUALLY EXCLUSIVE with it:
  /// `vfoA` is one VFO, so two things writing it fight, and the dropdown
  /// that sets these is one list for exactly that reason.
  ///
  /// Kept across launches and across the peer walking away, like [radio1] is
  /// — the picker shows it as unavailable and it re-engages by itself when
  /// that device comes back. Nothing here checks whether the peer is
  /// present: this service cannot see the sessions, and a selection that
  /// erased itself on a dropped link would be gone before the operator
  /// looked up.
  PeerRadioSelection? _remoteRadio1;

  @override
  PeerRadioSelection? get remoteRadio1 => _remoteRadio1;

  /// Points `vfoA` at a peer's radio, clearing [radio1] — see
  /// [remoteRadio1] for why the two cannot both be set.
  Future<void> setRemoteRadio1(PeerRadioSelection? selection) async {
    if (_remoteRadio1 == selection && (selection == null || _radio1 == null)) return;
    _remoteRadio1 = selection;
    if (selection != null && _radio1 != null) {
      // The same two clears [setRadio1] does, and for the same reasons: the
      // outgoing radio stops being told anything, and a movement measured on
      // it says nothing about where the peer's rig is sitting.
      _runtimes[_radio1!]?.lastSent = null;
      _runtimes[_radio1!]?.lastSentPower = null;
      cwProgress.value = null;
      _cancelSnap(null);
      _radio1 = null;
    }
    await _save();
    notifyListeners();
  }

  Future<void> setRadio1(String? uuid) async {
    // Picking a local radio — None included — is a statement about `vfoA`,
    // which a remote pick also claims. Picking None while a remote radio is
    // selected is therefore a real change even though `_radio1` is already
    // null, which is what this has to be checked ahead of the early return.
    final clearingRemote = _remoteRadio1 != null;
    if (_radio1 == uuid && !clearingRemote) return;
    _remoteRadio1 = null;
    // The echo guard is per-node but only meaningful for whichever node is
    // radio1 — the same reason [_closeSession] clears it. The incoming
    // radio was told nothing while it wasn't driving the panel, and the
    // outgoing one stops being asked, so a stale value on either would
    // suppress the first tune to a frequency that radio happens to be on.
    for (final id in [_radio1, uuid]) {
      if (id != null) {
        _runtimes[id]?.lastSent = null;
        _runtimes[id]?.lastSentPower = null;
        cwProgress.value = null;
      }
    }
    // Same reasoning for the snapper: a movement measured on the outgoing
    // radio says nothing about where the incoming one is sitting.
    _cancelSnap(null);
    _radio1 = uuid;
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------- offered to peers

  @override
  List<PeerRadioOffer> get offeredRadios => [
        for (final node in _nodes.values)
          if (registry.typeFor(node.typeKey)?.category == kCategoryTransceiver &&
              stateFor(node.uuid).status == EquipmentStatus.connected)
            PeerRadioOffer(id: node.uuid, name: node.name),
      ];

  @override
  void noteOffer(String deviceId, String deviceName, List<PeerRadioOffer> radios) {
    final selection = _remoteRadio1;
    if (selection == null || selection.deviceId != deviceId) return;
    for (final radio in radios) {
      if (radio.id != selection.radioId) continue;
      if (selection.deviceName == deviceName && selection.radioName == radio.name) return;
      // The ids are unchanged, so this is the same pick under new names —
      // which is why [PeerRadioSelection] compares only the ids. Written
      // through rather than held in memory: the name is wanted precisely
      // when the peer is not here to state it, relaunches included.
      _remoteRadio1 = PeerRadioSelection(
        deviceId: deviceId,
        radioId: radio.id,
        deviceName: deviceName,
        radioName: radio.name,
      );
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
    if (radioId == _radio1) {
      _radio?.setVfo('vfoA', freq: freqKHz, mode: mode);
      return;
    }
    tuneNode(radioId, VfoReading(freqKHz: freqKHz, mode: resolveSideband(mode, freqKHz)));
  }

  // ------------------------------------------------------ antenna1 / key1

  /// Which antenna/key node is "in use" — the same plain-stored,
  /// operator-or-auto-designated pointer as [radio1], for the categories
  /// that only ever have one thing connected at a time and never a
  /// session to disrupt. Keyed by category ([kCategoryAntenna]/
  /// [kCategoryKey]) rather than given their own fields, since both follow
  /// [radio1]'s three rules identically and neither carries radio1's
  /// connect/session bookkeeping.
  final Map<String, String?> _designated = {};

  String? designatedFor(String category) => _designated[category];

  bool isDesignated(String category, String uuid) => _designated[category] == uuid;

  Future<void> setDesignated(String category, String? uuid) async {
    if (_designated[category] == uuid) return;
    final previousUuid = _designated[category];
    _designated[category] = uuid;
    if (category == kCategoryKey) {
      // The old keyer's message would otherwise finish with nothing showing
      // it and nothing to stop it; the new one's speed is read so the row is
      // not left on the old one's.
      final previous = _runtimes[previousUuid]?.session;
      if (previous is CwKeyerSession && previous.cwSending) {
        try {
          previous.stopCw();
        } catch (e, st) {
          ErrorReportingService.report(e, st, context: 'cat:stop-cw');
        }
      }
      cwProgress.value = null;
      refreshKeyerSpeed();
    }
    await _save();
    notifyListeners();
  }

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
    final uuid = _radio1;
    final live = uuid == null ? null : stateFor(uuid).power;
    return live ?? _radio?.vfoA.power;
  }

  /// Pushes [watts] to radio1's session, if it has one and is connected — a
  /// no-op otherwise. Like frequency and mode, power reaches this through
  /// [RadioService] ([_onVfoChanged]): several surfaces read and write it,
  /// and one app-wide value is what keeps them agreeing.
  void setPower(num watts) {
    final uuid = _radio1;
    if (uuid == null) return;
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    // Only a transceiver has RF output to set. radio1 is always one today,
    // so this is a type narrowing rather than a reachable branch — but the
    // designation is a stored uuid, and nothing stops a record naming a
    // switch from being read back into it.
    if (session is! TransceiverSession) return;
    // The same echo guard [tuneNode] applies, and needed for the same
    // reason: every VFO notification — a typed frequency, a band pick —
    // arrives here too, and without this each one re-sends a power command
    // the radio already obeyed. Recorded only after the command lands, so a
    // throw doesn't leave a value remembered as delivered.
    if (runtime!.lastSentPower == watts) return;
    try {
      session.setPower(watts);
      runtime.lastSentPower = watts;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-power');
    }
  }

  /// Makes [uuid] the key in use when it can key and nothing is — the rule
  /// [addNode] applies, and what [_load] applies once for a station whose
  /// radio keyed before the key in use decided that.
  void _designateFirstKeyingRadio(String uuid) {
    if (_designated[kCategoryKey] != null) return;
    if (!_settings.experimentEnabled('keyer') /* stored key, see experiments.yaml */) return;
    final node = _nodes[uuid];
    if (node == null || !(registry.typeFor(node.typeKey)?.driver.canKeyCw ?? false)) return;
    _designated[kCategoryKey] = uuid;
  }

  /// The node keying for the app: the designated key ([kCategoryKey]'s
  /// designation), when it is connected through a [CwKeyerSession] — a
  /// Winkeyer, or a radio whose CAT can key and was picked as the key in
  /// use. Null otherwise. Every keying surface (the keyer row in the Station
  /// dialog, F1-F8, the WPM command) exists only while this is non-null.
  ///
  /// The designation, not radio1: a station with both a Winkeyer and a
  /// keying radio has to say which one the messages go through, and the
  /// "key in use" pick is where a key is already chosen.
  String? get _cwKeyerUuid {
    final uuid = _designated[kCategoryKey];
    if (uuid == null) return null;
    final runtime = _runtimes[uuid];
    if (runtime?.state.status != EquipmentStatus.connected) return null;
    return runtime!.session is CwKeyerSession ? uuid : null;
  }

  CwKeyerSession? get _cwKeyer {
    final uuid = _cwKeyerUuid;
    if (uuid == null) return null;
    return _runtimes[uuid]!.session as CwKeyerSession;
  }

  /// Whether the designated key is connected and can key CW.
  bool get canKeyCw => _cwKeyer != null;

  /// Whether the designated key COULD key — a keyer, or a radio whose
  /// driver keys — whether or not it is connected right now. What decides
  /// the Station dialog shows the keyer row at all: a disconnected Winkeyer
  /// still wants its connect button and its messages reachable.
  bool get designatedKeyIsKeyer {
    final uuid = _designated[kCategoryKey];
    if (uuid == null) return false;
    final node = nodeFor(uuid);
    if (node == null) return false;
    return _isKeyerType(typeFor(node));
  }

  /// The designated key's node, when [designatedKeyIsKeyer].
  EquipmentNode? get designatedKeyerNode {
    if (!designatedKeyIsKeyer) return null;
    return nodeFor(_designated[kCategoryKey]!);
  }

  /// Every node the "key in use" pick may offer as a keying source: keyers,
  /// and radios whose driver can key.
  List<EquipmentNode> get keyerCandidates => [
        for (final node in nodes)
          if (_isKeyerType(typeFor(node))) node,
      ];

  static bool _isKeyerType(EquipmentType? type) =>
      type != null && (type.category == kCategoryKeyer || type.driver.canKeyCw);

  /// The keyer's speed as it reported it, or null while unknown — also null
  /// when nothing can key.
  int? get keyerSpeed {
    final uuid = _cwKeyerUuid;
    if (uuid == null) return null;
    return stateFor(uuid).keyerSpeed;
  }

  /// The speeds the key in use accepts — for a picker to offer exactly
  /// those. Null when nothing can key.
  ({int min, int max})? get keyerSpeedRange => _cwKeyer?.keyerSpeedRange;

  /// Whether the key in use is still keying something [sendCw] gave it.
  bool get cwSending => _cwKeyer?.cwSending ?? false;

  /// What the key in use is sending for the app right now, or null — for
  /// the status bar's indicator. Its own notifier rather than a field on
  /// [EquipmentState]: it changes with every message and clears seconds
  /// later, and a state change rebuilds every equipment row for a value only
  /// one small widget reads.
  final cwProgress = ValueNotifier<CwSendProgress?>(null);

  /// Whether the keyer area is shown — the logging panel's strip follows
  /// it, the Station dialog's toggle and the KEYER command set it, and the
  /// area's own X and its linger clear it.
  final keyerAreaShown = ValueNotifier<bool>(false);

  /// Bumped by every [showKeyerArea], shown already or not: the area's
  /// linger has to end on an explicit ask even when the flag does not move.
  final keyerShowRequests = ValueNotifier<int>(0);

  void showKeyerArea() {
    keyerAreaShown.value = true;
    keyerShowRequests.value++;
  }

  void hideKeyerArea() => keyerAreaShown.value = false;

  /// Keys [text] on the key in use — a no-op, not an error, when nothing can key:
  /// the surfaces that call this only exist while [canKeyCw], so reaching
  /// here without a keyer is the radio dropping between the check and the
  /// keypress.
  void sendCw(String text) {
    final session = _cwKeyer;
    if (session == null) return;
    try {
      session.sendCw(text);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:send-cw');
    }
  }

  /// Stops whatever [sendCw] still has to send — see [CwKeyerSession.stopCw]
  /// for how much of what is already on the radio this can reach.
  void stopCw() {
    final session = _cwKeyer;
    if (session == null) return;
    try {
      session.stopCw();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:stop-cw');
    }
  }

  /// Drops one message waiting behind the one the key in use is keying — see
  /// [CwKeyerSession.dropQueuedCw].
  void dropQueuedCw(int id) {
    final session = _cwKeyer;
    if (session == null) return;
    try {
      session.dropQueuedCw(id);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:drop-queued-cw');
    }
  }

  /// Sets the key in use's keyer speed. Returns false when nothing can key, or the
  /// send threw, so the WPM command can say so rather than confirm a change
  /// that never left the app.
  ///
  /// No echo guard, unlike [setPower]: power is re-sent on every VFO
  /// notification and needs one, while this is only ever an operator's
  /// explicit ask — and neither radio announces a front-panel knob turn,
  /// so the last value the app saw is not the value the radio is on.
  bool setKeyerSpeed(int wpm) {
    final session = _cwKeyer;
    if (session == null) return false;
    try {
      session.setKeyerSpeed(wpm);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-keyer-speed');
      return false;
    }
    return true;
  }

  /// Asks the key in use for its keyer speed again — for a surface about to show it,
  /// since sessions read it once at connect and the radio never volunteers a
  /// knob turn.
  void refreshKeyerSpeed() {
    final session = _cwKeyer;
    if (session == null) return;
    try {
      session.refreshKeyerSpeed();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:refresh-keyer-speed');
    }
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
    try {
      session.selectAntenna(portKey, antennaKey);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:select-antenna');
    }
  }

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
    // No equivalent of the node check above, and there cannot be one: a peer
    // radio's existence is a fact about another device, which this one
    // cannot ask about at load. An absent peer reads as an unavailable
    // selection, not as a corrupt one. Exclusivity is enforced on the way in
    // — refusing to load both keeps a hand-edited or newer-build blob from
    // pointing `vfoA` at two things at once.
    if (_radio1 == null) _remoteRadio1 = PeerRadioSelection.from(stored['remoteRadio1']);
    final designated = stored['designated'];
    if (designated is Map) {
      for (final entry in designated.entries) {
        final uuid = entry.value;
        if (uuid is String && _nodes.containsKey(uuid)) _designated['${entry.key}'] = uuid;
      }
    }
    // No key entry at all means the key in use has never been decided, and
    // a station that keyed through radio1 until then would lose keying with
    // nothing to say why. An explicit None is stored as null and kept.
    final keyDecided = designated is Map && designated.containsKey(kCategoryKey);
    if (!keyDecided) {
      if (_radio1 case final uuid?) _designateFirstKeyingRadio(uuid);
    }
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
        'remoteRadio1': _remoteRadio1?.toJson(),
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
    final category = registry.typeFor(stored.typeKey)?.category;
    // Never over a peer's radio, though: that pick was the operator saying
    // where `vfoA` comes from, and configuring a rig — which is not the same
    // as reaching for it — must not silently take the panel back off the
    // radio they are working through.
    if (category == kCategoryTransceiver && _remoteRadio1 == null) _radio1 = stored.uuid;
    // Same rule as radio1, for antenna/key: the newest one designated, so
    // adding the shack's only antenna or key needs no separate picker visit.
    if (category == kCategoryAntenna) _designated[kCategoryAntenna] = stored.uuid;
    // The key in use is also what keys, so what a new node does to it
    // depends on what it displaces: a keyer takes over (the newest keyer
    // keys), a plain paddle takes over only from a paddle or nothing —
    // recording a Bencher for the log must not silently stop the radio's
    // keying — and a radio that can key is picked only when nothing was,
    // and only with the keyer experiment on (without it the pick never
    // shows radios, so the designation would be one nobody could see).
    if (category == kCategoryKeyer) _designated[kCategoryKey] = stored.uuid;
    if (category == kCategoryKey && !designatedKeyIsKeyer) _designated[kCategoryKey] = stored.uuid;
    if (category == kCategoryTransceiver) _designateFirstKeyingRadio(stored.uuid);
    await _save();
    _trackRadio('radio_added', stored, extra: {'via': via});
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
    // Same rule for antenna/key designations.
    _designated.removeWhere((_, designatedUuid) => designatedUuid == uuid);
    await _save();
    notifyListeners();
  }

  // ------------------------------------------------------------ discovery

  final Map<String, DiscoveredEquipment> _discovered = {};
  final List<StreamSubscription<DiscoveredEquipment>> _discoverySubscriptions = [];

  /// Equipment that has announced itself and isn't configured yet, newest
  /// announcement wins. Already-configured equipment is filtered out — the
  /// point of the list is what you could still add.
  ///
  /// "Configured" is per CHANNEL, not per radio, for equipment that has
  /// several ([EquipmentDriver.channelKey]): a FlexRadio with only slice A
  /// set up is still something you could add, and dropping it from the list
  /// after the first add is what would make the second slice reachable only
  /// by typing the address in by hand. Each offer carries the lowest channel
  /// not yet spoken for, so accepting one twice does not produce two nodes
  /// on the same slice.
  List<DiscoveredEquipment> get discovered {
    final configured = <String>{};
    for (final node in _nodes.values) {
      final type = registry.typeFor(node.typeKey);
      if (type != null) configured.add(_targetKey(type, node.config));
    }
    return [
      for (final found in _discovered.values)
        if (_offerFor(found, configured) case final offer?) offer,
    ];
  }

  /// [found] as it should be added next, or null when every channel it
  /// offers is already configured.
  DiscoveredEquipment? _offerFor(DiscoveredEquipment found, Set<String> configured) {
    final type = registry.typeFor(found.typeKey);
    if (type == null) return configured.contains(_discoveryKey(found)) ? null : found;

    final channelKey = type.driver.channelKey;
    // Single-channel equipment: one target is one node, as it always was.
    if (channelKey == null) {
      return configured.contains(_targetKeyFor(found)) ? null : found;
    }

    // A discovered device carries only what the announcement said, so the
    // type's own prefill is what decides which channel "no channel named"
    // means — the same merge the Add form opens with.
    final base = {...type.defaultConfig, ...found.config};
    for (final value in type.driver.channelValues) {
      final config = {...base, channelKey: value};
      if (configured.contains(_targetKey(type, config))) continue;
      final suffix = type.driver.describeSuffix(config, overrides: type.variant.overrides);
      return DiscoveredEquipment(
        typeKey: found.typeKey,
        // The channel is part of what this offer IS: two rows for the same
        // radio would otherwise collapse into one in any id-keyed list, and
        // the second slice would be unofferable again.
        id: '${found.id}|$channelKey=$value',
        // Named for its channel from the SECOND one on. The first keeps the
        // radio's own name: a shack with one Flex on slice A should not have
        // its name grow a suffix it never asked for.
        name: value == type.driver.channelValues.first || suffix == null ? found.name : '${found.name}$suffix',
        detail: found.detail,
        config: config,
      );
    }
    return null;
  }

  /// What makes two nodes the same thing: where the equipment is, plus which
  /// of its channels the node tracks. [config] contributes only the driver's
  /// [EquipmentDriver.channelKey], never the rest — a node differing in baud
  /// rate or CI-V address is still the same radio on the same port.
  ///
  /// Read through [EquipmentType.driverConfig], the same merge the SESSION
  /// is built from, so a pairing that pins its channel in `overrides` keys
  /// as the channel it actually follows. Reading the node's raw config
  /// instead would key every such node as the driver's first channel: two of
  /// them would collide, and the first channel would stop being offered on a
  /// radio nobody is on.
  String _targetKey(EquipmentType type, Map<String, dynamic> config) {
    final merged = type.driverConfig(config);
    final channelKey = type.driver.channelKey;
    // A node stored before the channel setting existed names none, and is
    // tracking the driver's first — the same fallback the driver itself
    // applies when it reads the config.
    final channel =
        channelKey == null ? '' : '|$channelKey=${merged[channelKey] ?? type.driver.channelValues.first}';
    final target = type.targetFor(config);
    return '${type.key}|${target.entries.map((e) => '${e.key}=${e.value}').join(',')}$channel';
  }

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
    if (type == null) return _discoveryKey(found);
    return _targetKey(type, {...type.defaultConfig, ...found.config});
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
      _setState(
        uuid,
        EquipmentState(
          status: EquipmentStatus.error,
          error: t.settings.station.configUnreadable,
          errorDetail: '$e',
        ),
      );
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
      // switched-off rig out of the backend. The state below shows a
      // translated reason for a recognized cause, or the underlying error's
      // own words otherwise — [errorDetail] keeps those words either way,
      // for the equipment report a developer reads.
      ErrorReportingService.report(CatConnectFailure(node.typeKey, e), st, context: 'cat:connect');
      final reason = _failureReason(e);
      final friendly = _friendlyConnectError(reason, e);
      final raw = '$e';
      _setState(
        uuid,
        EquipmentState(status: EquipmentStatus.error, error: friendly, errorDetail: friendly == raw ? null : raw),
      );
      _trackFailure(node, reason, extra: _baudExtra(config));
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
        if (uuid == _radio1) {
          _lastSeenVfoPower = watts;
          _radio?.setVfo('vfoA', power: watts, origin: VfoOrigin.radio);
        }
      },
      onCwProgress: (progress) {
        if (runtime.connection != connection) return;
        // A keyer has no VFO to feed the silence watch with — see the
        // reasoning at onSwitchState.
        _noteAlive(uuid, runtime);
        // Only the designated key keys for the app, so only it is shown.
        if (uuid == _cwKeyerUuid) cwProgress.value = progress;
      },
      onKeyerSpeed: (wpm) {
        if (runtime.connection != connection) return;
        _noteAlive(uuid, runtime);
        if (stateFor(uuid).keyerSpeed != wpm) _setState(uuid, stateFor(uuid).copyWith(keyerSpeed: wpm));
      },
      onProblem: (message) {
        if (runtime.connection != connection) return;
        if (stateFor(uuid).problem == message) return;
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
      // Unconditional on purpose. A guard on which node dropped would be
      // dead code: [_scheduleIdleRetry] reads the nodes it covers itself and
      // stops on the first tick if each is connected or absent, so the guard
      // could not change any outcome. One place decides, and it is the loop.
      _scheduleIdleRetry();
    }));

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
      final keyer = _designated[kCategoryKey];
      final wanted = <String>{
        if (_radio1 case final uuid?) uuid,
        if (keyer != null && _isDesignatedKeyerDevice(keyer)) keyer,
      };

      // STOP only for a reason that will not resolve itself: there is nothing
      // designated, the node is gone, the operator switched it off, or it is
      // already connected. connect/disconnect and a dropped session restart it.
      bool settled(String uuid) =>
          !_nodes.containsKey(uuid) ||
          (_runtimes[uuid]?.userDisconnected ?? false) ||
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
      unawaited(Future.wait(open.map(_connect)).then((outcomes) {
        if (outcomes.every((outcome) => outcome == _ConnectOutcome.connected)) {
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

  /// Whether [uuid] is the key in use and a device of its own (a keyer node,
  /// not a radio doubling as one) — what the app's keying depends on, so it
  /// is brought back the way radio1 is.
  bool _isDesignatedKeyerDevice(String uuid) {
    if (_designated[kCategoryKey] != uuid) return false;
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
    if (_disposed || !(isRadio1(uuid) || _isDesignatedKeyerDevice(uuid))) return;
    final last = _lastAutoReconnect[uuid];
    // Real time: this cooldown rate-limits real reconnect attempts against a
    // real radio, so a rescaled clock would let a storm through.
    final now = realNowUtc();
    if (last != null && now.difference(last) < _autoReconnectCooldown) {
      debugPrint('[cat] auto-reconnect suppressed: last was ${now.difference(last).inSeconds}s ago');
      return;
    }
    _lastAutoReconnect[uuid] = now;
    unawaited(reconnectDesignatedRadio());
  }

  /// radio1, and the key in use when it is a device of its own: both are
  /// what the app depends on, and neither should wait for a button.
  Future<void> reconnectDesignatedRadio() async {
    final keyer = _designated[kCategoryKey];
    await Future.wait([
      _reconnectWithRetries(_radio1),
      if (keyer != null && keyer != _radio1 && _isDesignatedKeyerDevice(keyer)) _reconnectWithRetries(keyer),
    ]);
  }

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

  /// The equipment just spoke: restart the silence watch, and drop the stale
  /// mark if it was set.
  ///
  /// Anything at all counts, including a report identical to the last one —
  /// a radio answering "still 14074" is a radio that is answering, and a
  /// switch restating its routing is a switch with a live socket.
  void _noteAlive(String uuid, _NodeRuntime runtime) {
    _armStaleWatch(uuid, runtime);
    if (runtime.state.stale) _setState(uuid, runtime.state.copyWith(stale: false));
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
      _setState(uuid, current.state.copyWith(stale: true));
    });
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
    if (uuid != _radio1) return;
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

    // The baseline moves here, ahead of the returns below, so it tracks the
    // app's power whether or not there is a radio to tell. A power stated
    // while the rig is absent is lost exactly as a frequency typed then is —
    // and on the next connect the radio's own reading is what both sides
    // take, rather than a stale value being pushed at it.
    final powerChanged = radio.vfoA.power != _lastSeenVfoPower;
    _lastSeenVfoPower = radio.vfoA.power;

    final uuid = _radio1;
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
    tuneNode(uuid, VfoReading(freqKHz: vfo.freq, mode: resolveSideband(vfo.mode, vfo.freq, band: vfo.band)));
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
  void tuneNode(String uuid, VfoReading wanted) {
    final runtime = _runtimes[uuid];
    final session = runtime?.session;
    if (session == null) return;
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
    if (identical(_runtimes[_designated[kCategoryKey]], runtime)) cwProgress.value = null;
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
    // After the teardowns, whose synchronous prefix clears cwProgress for
    // the designated radio — a notifier disposed first would be notified.
    cwProgress.dispose();
    keyerAreaShown.dispose();
    keyerShowRequests.dispose();
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

  /// [lastSent]'s counterpart for transmit power, which travels on its own
  /// commands rather than inside a [VfoReading].
  num? lastSentPower;

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
  final void Function(num) onPower;
  final void Function(int) onKeyerSpeed;
  final void Function(CwSendProgress?) onCwProgress;
  final void Function(String?) onDiagnostic;
  final void Function(String?) onProblem;
  final void Function(List<EquipmentChannel>) onChannels;
  final void Function(List<SwitchAntenna>, List<SwitchPort>) onSwitchState;

  _NodeSink({
    required this.connection,
    required this.onReading,
    required this.onPower,
    required this.onKeyerSpeed,
    required this.onCwProgress,
    required this.onDiagnostic,
    required this.onProblem,
    required this.onChannels,
    required this.onSwitchState,
  });

  @override
  void send(List<int> bytes) => connection.send(bytes);

  @override
  void report(VfoReading reading) => onReading(reading);

  @override
  void reportPower(num watts) => onPower(watts);

  @override
  void reportKeyerSpeed(int wpm) => onKeyerSpeed(wpm);

  @override
  void reportCwProgress(CwSendProgress? progress) => onCwProgress(progress);

  @override
  void reportDiagnostic(String? note) => onDiagnostic(note);

  @override
  void reportProblem(String? message) => onProblem(message);

  @override
  void reportChannels(List<EquipmentChannel> channels) => onChannels(channels);

  @override
  void reportSwitchState(List<SwitchAntenna> antennas, List<SwitchPort> ports) =>
      onSwitchState(antennas, ports);
}
