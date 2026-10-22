// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying, for every surface that keys: F1-F8 and the keyer area's buttons,
// the Station dialog's keyer row, the WPM command, both message dialogs
// (docs/design/cat.md § CW keying, § Voice keying).
//
// Split out of `CatService`, which still holds the whole API — every surface
// reads `cat.canKeyCw`, calls `cat.sendCw`, watches `cat.cwProgress`, and
// none of them know this file exists. What lives here is the keying itself:
// which session keys, what it is keying, how a speed is set and remembered,
// how a memory is played, recorded and timed.
//
// Where the rig IS is the one thing this file does not decide. A message goes
// to the key in use, and that key can be on another device (HALO-585) — the
// same call reaches a session here or a `keySet` on the wire, and
// [KeyingStation.peerKeyIsInUse] is what says which. That is why the local
// halves are public: a peer's request is honored through the SAME code a
// local function key takes, and must never be relayed on.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';

import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'driver.dart';
import 'drivers/cw_send_queue.dart' show CwSendProgress;
import 'equipment.dart';
import 'equipment_registry.dart';
import 'keyer_repeat.dart';
import 'peer_keying.dart';

/// What keying needs of the station it runs on — the equipment half of
/// `CatService`, which is where sessions, nodes and the picks live.
///
/// A seam rather than the service itself, for the reason the file exists:
/// keying is a self-contained thing that happens to need a session, and a
/// class that could reach into the registry would grow back into it.
abstract class KeyingStation {
  /// The key in use, as a node uuid — [kCategoryKey]'s designation. Null for
  /// None, and null for a peer's own keying, which is not a node here to
  /// name ([peerKeyIsInUse]).
  String? get keyInUse;

  /// Whether what keys for the radio in use is the PEER's own key: its radio
  /// fills radio1, and this operator either never chose a key for it or
  /// chose that radio itself. An explicit None means None — a default does
  /// not outrank an answer.
  bool get peerKeyIsInUse;

  /// Which radio a keying request is addressed to, or null when radio1 is
  /// not a peer's radio.
  String? get peerRadioId;

  /// Whether [node] is a key or a radio whose CAT keys.
  bool isKeyerNode(EquipmentNode node);

  List<EquipmentNode> get nodes;
  EquipmentNode? nodeFor(String uuid);
  EquipmentType? typeFor(EquipmentNode node);
  EquipmentState stateFor(String uuid);

  /// Physical device identity for logical radios sharing one transmitter.
  /// Null for independent radios, whose node UUID is their identity.
  String? logicalDeviceIdFor(String uuid);

  /// [uuid]'s session, but only while that node is connected — a keyer that
  /// dropped answers null rather than throwing at whatever is keyed into it.
  EquipmentSession? connectedSession(String uuid);

  /// radio1 when it is a rig of this station's own, null when it is a peer's
  /// or none: the memories are audio in the transceiver, and there is
  /// nothing local to play when the transceiver is somewhere else.
  String? get localRadio1;

  Future<void> updateNode(EquipmentNode node);

  /// Quiets every radio but [radio] before it transmits — one transmitter at
  /// a time (CatService.yieldTransmitter, docs/design/cat.md § PTT).
  void yieldTransmitter(String? radio);
}

class CatKeying {
  CatKeying({required this.station, required this.settings, required this.chain, required this.peer}) {
    voiceActivity.addListener(_onVoiceActivityForSequence);
    // A message-1 mark lasts while its message does. Left standing, the
    // next message on a shared transmitter — a peer's, or a third
    // station's on the radio this device follows — would read as this
    // operator's CQ, and a typed call would stop it.
    cwProgress.addListener(() {
      if (cwProgress.value == null) _lastCwHasMessageOne = false;
    });
    voiceActivity.addListener(() {
      if (voiceActivity.value == null) _voiceMessageOne = false;
    });
  }

  final KeyingStation station;
  final SettingsService settings;

  /// Message 1 going again — one engine for both keyers (keyer_repeat.dart).
  final KeyerRepeat chain;

  /// The picked peer radio's keying (peer_keying.dart) — what the far
  /// station will do, and what it says it is doing.
  final PeerKeying peer;

  /// Fires when what an offered radio is keying changes, so the peer bridge
  /// can report it — for the STATION's keying, whether or not anything here
  /// is looking at the strip.
  ///
  /// Its own listenable rather than the service's notifications, for the same
  /// reason [cwProgress] is a notifier: a message advancing character by
  /// character must not rebuild every equipment row in the Station panel.
  Listenable get keyingChanges => _keyingRevision;

  final _keyingRevision = ValueNotifier<int>(0);

  void onKeyingChanged() => _keyingRevision.value++;

  /// Whether CW goes out over the link: the picked peer radio keys, and the
  /// key in use for it is that peer's own.
  bool get keysOverPeer => peer.keysCw && station.peerKeyIsInUse;

  /// Whether the voice memories in play are the picked peer radio's. No
  /// designation in between, the same as for a local rig: the memories
  /// belong to whatever radio fills the role.
  bool get playsVoiceOverPeer => peer.playsVoice;

  /// Asks the device whose radio is picked for [op] — a no-op when nothing is
  /// picked or no bridge is up, the same no-op every keying surface takes
  /// when the radio drops between the check and the keypress.
  /// Answers whether it went anywhere: a build with no bridge, or a pick that
  /// moved, leaves nothing to send to — and a chain armed on a request that
  /// reached nothing waits forever for an end nothing will report.
  bool requestPeerKey(String op, {String text = '', int? wpm, int? memory, int? queuedId}) =>
      peer.request(station.peerRadioId, op, text: text, wpm: wpm, memory: memory, queuedId: queuedId);

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
    final uuid = station.keyInUse;
    if (uuid == null) return null;
    if (station.connectedSession(uuid) is! CwKeyerSession) return null;
    // A session class serves a whole line (Kenwood's), so being a
    // CwKeyerSession is not being a keyer: the node's entry decides.
    final node = station.nodeFor(uuid);
    if (node != null && !station.isKeyerNode(node)) return null;
    return uuid;
  }

  CwKeyerSession? get _cwKeyer {
    final uuid = _cwKeyerUuid;
    if (uuid == null) return null;
    return station.connectedSession(uuid)! as CwKeyerSession;
  }

  /// Whether the key in use is a keyer of this station's own, connected and
  /// able to key. What a radio offered to a peer advertises: this device keys
  /// with what it has, and a relay of a request onto some third device's rig
  /// is not something to offer.
  bool get keysCwLocally => _cwKeyer != null;

  /// Whether the designated key is connected and can key CW — or, when
  /// `radio1` is a peer's radio that keys and nothing here was designated
  /// for it, whether that station will key on this operator's behalf.
  bool get canKeyCw => _cwKeyer != null || keysOverPeer;

  /// Whether the designated key COULD key — a keyer, or a radio whose
  /// driver keys — whether or not it is connected right now. What decides
  /// the Station dialog shows the keyer row at all: a disconnected Winkeyer
  /// still wants its connect button and its messages reachable.
  bool get designatedKeyIsKeyer {
    // A peer's keying has no node here to ask, and the row is wanted for the
    // same reason a disconnected WinKeyer's is: it is where the speed and
    // the messages are reached from.
    if (keysOverPeer) return true;
    final uuid = station.keyInUse;
    if (uuid == null) return false;
    final node = station.nodeFor(uuid);
    if (node == null) return false;
    return station.isKeyerNode(node);
  }

  /// The designated key's node, when there IS one — null while what keys is
  /// a peer's own key, which is no node of this station: [designatedKeyIsKeyer]
  /// is true for it, and nothing here can be asked about it.
  EquipmentNode? get designatedKeyerNode {
    if (!designatedKeyIsKeyer) return null;
    final uuid = station.keyInUse;
    if (uuid == null) return null;
    return station.nodeFor(uuid);
  }

  /// Every node the "key in use" pick may offer as a keying source: keyers,
  /// and radios whose driver can key.
  List<EquipmentNode> get keyerCandidates => [
    for (final node in station.nodes)
      if (station.isKeyerNode(node)) node,
  ];

  /// The keyer's speed as it reported it, or null while unknown — also null
  /// when nothing can key.
  int? get keyerSpeed {
    final uuid = _cwKeyerUuid;
    // The far keyer's own answer, never a value this side chose: what the
    // pill shows is what that radio took, clamping and rounding included.
    if (uuid == null) return keysOverPeer ? peer.keyerSpeed : null;
    return station.stateFor(uuid).keyerSpeed;
  }

  /// The speeds the key in use accepts — for a picker to offer exactly
  /// those. Null when nothing can key.
  ({int min, int max})? get keyerSpeedRange {
    final local = _cwKeyer?.keyerSpeedRange;
    if (local != null || !keysOverPeer) return local;
    return peer.keyerSpeedRange;
  }

  /// Whether the key in use is still keying something [sendCw] gave it.
  bool get cwSending => keysOverPeer ? cwProgress.value != null : (_cwKeyer?.cwSending ?? false);

  /// What the key in use is sending for the app right now, or null — for
  /// the status bar's indicator. Its own notifier rather than a field on
  /// [EquipmentState]: it changes with every message and clears seconds
  /// later, and a state change rebuilds every equipment row for a value only
  /// one small widget reads.
  final cwProgress = ValueNotifier<CwSendProgress?>(null);

  /// Bumped by every [stopCw], BEFORE the key hears it. A stop empties the
  /// queue, and its report is the same null [cwProgress] a message ending
  /// gives — this is how a listener that feeds the key (keyboard mode,
  /// cw_live_typing.dart) tells "stopped" from "free for the next piece",
  /// rather than keying what it holds the moment the operator asked for
  /// silence.
  final cwStops = ValueNotifier<int>(0);

  /// Whether the keyer area is shown — the logging panel's strip follows
  /// it, the Station dialog's toggle and the KEYER command set it, and the
  /// area's own X and its linger clear it.
  late final keyerAreaShown = ValueNotifier<bool>(settings.keyerAreaShown);

  /// Bumped by every [showKeyerArea], shown already or not: the area's
  /// linger has to end on an explicit ask even when the flag does not move.
  final keyerShowRequests = ValueNotifier<int>(0);

  /// Bumped by ⌥K / Alt+K: the keyer area turns keyboard mode on or off
  /// (cw_live_typing.dart). A request rather than a flag, since the mode is
  /// the area's own — it ends by itself on Enter, a pause, Escape or the key
  /// going away.
  final keyboardModeRequests = ValueNotifier<int>(0);

  void toggleKeyboardMode() => keyboardModeRequests.value++;

  void showKeyerArea() {
    // Only when it MOVES: a message starting shows the area, so an
    // unconditional write would re-encode the whole radio group — the
    // message sets included — and rebuild every settings listener on each
    // press of a function key.
    final moved = !keyerAreaShown.value;
    keyerAreaShown.value = true;
    keyerShowRequests.value++;
    if (moved) unawaited(settings.setKeyerAreaShown(true));
  }

  void hideKeyerArea() {
    if (!keyerAreaShown.value) return;
    keyerAreaShown.value = false;
    unawaited(settings.setKeyerAreaShown(false));
  }

  /// Enter Sends Messages, and Run versus S&P — the keyer area's pill and the
  /// ESM/RUN/SP commands set it, the logging panel reads it.
  late final enterSends = ValueNotifier<({bool on, bool running})>((on: settings.enterSendsMessages, running: settings.enterSendsRunning));

  void setEnterSends({bool? on, bool? running}) {
    final next = (on: on ?? enterSends.value.on, running: running ?? enterSends.value.running);
    if (next == enterSends.value) return;
    enterSends.value = next;
    unawaited(settings.setEnterSends(on: next.on, running: next.running));
  }

  /// Keys [text] on the key in use — a no-op, not an error, when nothing can key:
  /// the surfaces that call this only exist while [canKeyCw], so reaching
  /// here without a keyer is the radio dropping between the check and the
  /// keypress. Answers whether the key took it — over a peer, whether the
  /// request went out, since nothing is keying here until the peer reports.
  bool sendCw(String text, {bool hasMessageOne = false}) {
    // Marked only on a send that was taken: a lost request leaves nothing on
    // the air to end the mark, and the next message on a shared radio —
    // somebody else's — would inherit it.
    _lastCwHasMessageOne = false;
    // Already rendered by the time it gets here — a template is rendered
    // against the DRAFT contact of whoever pressed the key, so text is the
    // only thing a far station could act on. Sanitizing it is still the
    // receiving queue's job, exactly as it is for a message typed here.
    final taken = keysOverPeer ? requestPeerKey(PeerKeyOp.cw, text: text) : sendCwLocally(text);
    _lastCwHasMessageOne = taken && hasMessageOne;
    return taken;
  }

  /// Whether the key in use took [text].
  bool sendCwLocally(String text) {
    final session = _cwKeyer;
    if (session == null) return false;
    // The radio that transmits it: the key in use itself when that is a
    // radio's own keyer, radio1 when it is a keyer that keys radio1.
    station.yieldTransmitter(station.connectedSession(_cwKeyerUuid!) is TransceiverSession ? _cwKeyerUuid : station.localRadio1);
    try {
      session.sendCw(text);
      return true;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:send-cw');
      return false;
    }
  }

  /// Whether the memory this operator last played is memory 1 — cleared
  /// when a peer's request plays one here, and when the play ends, so a
  /// memory 1 somebody else put on the air is theirs to stop.
  bool _voiceMessageOne = false;

  /// Whether [stopKeying] stopped something on the keystroke being
  /// dispatched — true only until that dispatch returns.
  bool escapeStoppedKeying = false;

  /// Whether the newest [sendCw] carried message 1 — alone, or as part of
  /// an Enter Sends Messages chain keyed as one message. The queue carries
  /// no message numbers, so "message 1 is on the air" is read as "the
  /// newest send held message 1 and the key is still busy".
  bool _lastCwHasMessageOne = false;

  /// A callsign entered over message 1: message 1 stops, CW or voice, along
  /// with any Enter Sends Messages chain holding it and any repeat — the
  /// operator has an answer, and a CQ keying over it is the one thing a
  /// repeat must not do. Any other message is left to finish: an exchange
  /// or a TU is the contact being worked (docs/design/cat.md § CW keying).
  void stopMessageOne() {
    chain.cancel();
    final playing = voiceActivity.value;
    if (_voiceSequenceHasOne || (playing != null && !playing.recording && _voiceMessageOne)) {
      if (playing != null && !playing.recording) {
        stopVoice();
      } else {
        cancelVoiceSequence();
      }
    }
    // stopCw empties the whole queue, so a message queued AHEAD of the CQ
    // goes with it; one queued behind it moves [_lastCwHasMessageOne] off.
    if (_lastCwHasMessageOne && cwSending) stopCw();
  }

  /// Escape: stops every message, chain and repeat, whatever the keyer, the
  /// mode, or whose they are. False when there was nothing to stop, so the
  /// key keeps its usual meaning in the logging fields. [alsoStopped] says
  /// the same Escape already stopped something outside the keyers (a held
  /// PTT key), which the logging fields must hear about the same way.
  bool stopKeying({bool alsoStopped = false}) {
    final busy = chain.running || _voiceSequence.isNotEmpty || voiceActivity.value != null || cwSending;
    if (!busy && !alsoStopped) return false;
    // The logging fields hear the same keystroke AFTER the operation view's
    // key handler has run this, and read the answer through
    // [escapeStoppedKeying] rather than asking again: asked again, the stop
    // just made reads as nothing running, and the same Escape also ends a
    // QSO edit.
    escapeStoppedKeying = true;
    scheduleMicrotask(() => escapeStoppedKeying = false);
    stopAll();
    return true;
  }

  /// Ends every message, chain and repeat of this operator's own — Escape's
  /// stop, and the operator keying PTT, whose own voice replaces whatever was
  /// queued: a CQ repeat left armed would play over them when its wait ran
  /// out, and a memory left playing ends with an unkey under their key.
  void stopAll() {
    chain.cancel();
    cancelVoiceSequence();
    if (voiceActivity.value != null) stopVoice();
    if (cwSending) stopCw();
  }

  /// Stops whatever [sendCw] still has to send — see [CwKeyerSession.stopCw]
  /// for how much of what is already on the radio this can reach.
  void stopCw() {
    cwStops.value++;
    // A stop is a stop: the operator who cut this message short did not ask
    // for it again in five seconds.
    chain.cancel();
    if (keysOverPeer) {
      // The strip is left to the far side's next status rather than cleared
      // here: on some keyers a stop empties the queue and lets the piece
      // already going play out, and a strip that went blank would say the
      // transmitter was quiet while it was still keying.
      requestPeerKey(PeerKeyOp.stopCw);
      return;
    }
    stopCwLocally();
  }

  void stopCwLocally() {
    // Again for a far station's stop, which arrives here without [stopCw].
    cwStops.value++;
    // Whoever asked for silence gets it, chain included — a stop that left an
    // unattended CQ re-keying this station's transmitter in five seconds is
    // the one outcome worse than a message cut short. The voice half says the
    // same thing at [stopVoiceLocally].
    chain.cancel();
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
    if (keysOverPeer) {
      // The id is the far queue's own, handed back from its status: the
      // waiting message is named rather than counted, so a queue that moved
      // between the report and the tap drops nothing instead of the wrong one.
      requestPeerKey(PeerKeyOp.dropCw, queuedId: id);
      return;
    }
    dropQueuedCwLocally(id);
  }

  void dropQueuedCwLocally(int id) {
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
    if (keysOverPeer) {
      if (station.peerRadioId == null || peer.send == null) return false;
      requestPeerKey(PeerKeyOp.wpm, wpm: wpm);
      // True for "somebody took it", not for "the radio is on it": the far
      // keyer's read-back is what the speed then shows, and a WPM command
      // that waited for a round trip before answering would sit silent
      // mid-QSO for the one operator who most needs to know it landed.
      return true;
    }
    return setKeyerSpeedLocally(wpm);
  }

  bool setKeyerSpeedLocally(int wpm) {
    final uuid = _cwKeyerUuid;
    final session = _cwKeyer;
    if (uuid == null || session == null) return false;
    try {
      session.setKeyerSpeed(wpm);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:set-keyer-speed');
      return false;
    }
    _rememberKeyerSpeed(uuid, wpm);
    return true;
  }

  /// Stores the speed on the node, for equipment that cannot be asked what
  /// its speed is ([EquipmentDriver.remembersKeyerSpeed]).
  ///
  /// From the OPERATOR'S set only, never from [EquipmentSink.reportKeyerSpeed].
  /// A report is also how a speed pot answers — and on a keyer whose pot is
  /// absent, how its floating ADC answers — so remembering reports would
  /// write that reading to disk and hand it back on every connect after.
  /// What is worth keeping is the speed somebody chose.
  void _rememberKeyerSpeed(String uuid, int wpm) {
    final node = station.nodeFor(uuid);
    if (node == null) return;
    if (station.typeFor(node)?.driver.remembersKeyerSpeed != true) return;
    if (node.config[keyerSpeedConfigKey] == wpm) return;
    unawaited(
      station
          .updateNode(node.copyWith(config: {...node.config, keyerSpeedConfigKey: wpm}))
          .catchError((Object e, StackTrace st) => ErrorReportingService.report(e, st, context: 'cat:remember-keyer-speed')),
    );
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

  /// [radio1]'s session, when it is connected and has voice memories to
  /// play. Radio1 and not the key in use: the memories are audio held by
  /// the transceiver itself, so there is nothing to designate — a WinKeyer
  /// has none, and a second radio's memories are that radio's. Every voice
  /// surface (the Phone-mode message buttons, F1-F8 in a Phone mode, the
  /// Phone Keyer dialog's Play and Record) exists only while this is
  /// non-null.
  VoiceKeyerSession? get _voiceKeyer {
    final uuid = station.localRadio1;
    if (uuid == null) return null;
    return voiceKeyerFor(uuid);
  }

  /// [uuid]'s session as a voice keyer, connected and with memories in it —
  /// the per-node form of [_voiceKeyer], which asks only about radio1. A
  /// radio this device merely OFFERS plays its own memories: the audio is in
  /// that rig, so radio1 cannot answer for it.
  VoiceKeyerSession? voiceKeyerFor(String uuid) {
    final session = station.connectedSession(uuid);
    if (session is! VoiceKeyerSession || session.voiceMemoryCount <= 0) return null;
    return session;
  }

  /// Whether radio1 is connected and can play its voice memories — a peer's
  /// radio through the link, exactly as a local one through its session.
  bool get canPlayVoice => _voiceKeyer != null || playsVoiceOverPeer;

  /// Whether radio1 COULD play voice memories — its entry holds some —
  /// whether or not it is connected right now. The voice counterpart of
  /// [designatedKeyIsKeyer], and what the Station panel lays the keyer row
  /// out from: a radio that keys is a fact about the station, and a row that
  /// appeared on connecting and vanished on dropping would move under the
  /// operator every time the link blinked.
  ///
  /// A PEER's radio answers from its offer instead — there is no entry here
  /// to ask, and what that station is willing to have played is the only
  /// fact about it this device has.
  ///
  /// Never a substitute for [canPlayVoice] at the moment of PLAYING: only a
  /// live session knows what the radio actually answered.
  bool get radio1HasVoiceMemories {
    if (playsVoiceOverPeer) return true;
    final uuid = station.localRadio1;
    if (uuid == null) return false;
    final node = station.nodeFor(uuid);
    if (node == null) return false;
    final type = station.typeFor(node);
    if (type == null) return false;
    return type.driver.voiceMemoryCountWith(type.driverConfig(node.config)) > 0;
  }

  /// How many memories radio1 has, 0 when nothing can play — the surfaces
  /// offer exactly that many.
  int get voiceMemoryCount => _voiceKeyer?.voiceMemoryCount ?? peer.voiceMemories;

  /// Whether radio1's CAT can also record a memory (docs/design/cat.md
  /// § Voice keying lists which can).
  bool get canRecordVoice => _voiceKeyer?.canRecordVoice ?? (playsVoiceOverPeer && peer.recordsVoice);

  /// What the memories are CALLED, and how long each was measured to run.
  ///
  /// The owner's, always: a peer radio's memories are named and timed on the
  /// device they are recorded in, and a label from here would name somebody
  /// else's audio while a duration from here would pace a bar against a
  /// recording this station has never played. Editing one is therefore the
  /// owner's too — [voiceMessagesAreLocal] is what a surface asks before it
  /// offers to.
  String voiceMessageLabel(int n) {
    if (!playsVoiceOverPeer) return _localVoiceLabel(station.localRadio1, n);
    return peer.voiceMessageLabel(n);
  }

  int voiceMessageDuration(int n) {
    if (!playsVoiceOverPeer) return _localVoiceDuration(station.localRadio1, n);
    return peer.voiceMessageDuration(n);
  }

  /// What [uuid] itself says about its memories — empty unless it is a radio
  /// that names and times them on the radio (a FlexRadio's DVK), and is
  /// connected and has said so. Where it is not empty it is the whole
  /// answer: the settings' labels and measured lengths are for radios that
  /// keep neither, and one shown over the radio's own would name audio by a
  /// label no other client of that radio sees.
  List<VoiceMemory> _radioHeldMemories(String? uuid) => uuid == null ? const [] : station.stateFor(uuid).voiceMemories ?? const [];

  /// [uuid]'s own account of memory [n]: null when it keeps none, so the
  /// settings answer, and an empty memory when it keeps them but not this one.
  VoiceMemory? _radioHeldMemory(String? uuid, int n) {
    final held = _radioHeldMemories(uuid);
    if (held.isEmpty) return null;
    return held.where((m) => m.memory == n).firstOrNull ?? VoiceMemory(memory: n);
  }

  String _localVoiceLabel(String? uuid, int n) => _radioHeldMemory(uuid, n)?.name ?? settings.voiceMessageLabel(n);

  int _localVoiceDuration(String? uuid, int n) => _radioHeldMemory(uuid, n)?.durationMs ?? settings.voiceMessageDuration(n);

  /// Names memory [n] — on the radio when radio1 holds its own names, in
  /// the settings otherwise. Nothing for a peer's memory: the name is that
  /// device's ([voiceMessagesAreLocal]).
  Future<void> setVoiceMessageLabel(int n, String label) async {
    if (!voiceMessagesAreLocal) return;
    final uuid = station.localRadio1;
    final session = uuid == null ? null : station.connectedSession(uuid);
    if (session is RadioNamedVoiceMemories && _radioHeldMemories(uuid).isNotEmpty) {
      session.renameVoiceMemory(n, label);
      return;
    }
    await settings.setVoiceMessageLabel(n, label);
  }

  /// Whether the memories in play are this device's own — false while a
  /// peer's radio holds them, which is what stops a label editor from
  /// writing a name onto audio it is not about.
  bool get voiceMessagesAreLocal => !playsVoiceOverPeer;

  /// Whether radio1 names its memories itself, so a label typed here is
  /// written to the radio rather than kept in the app.
  bool get voiceMessagesNamedOnRadio => voiceMessagesAreLocal && _radioHeldMemories(station.localRadio1).isNotEmpty;

  /// How to record a memory on radio1, where the radio needs saying — see
  /// [EquipmentModel.recordingHelp]. Null when nothing can record, or when
  /// the radio's own procedure needs no explaining. Carries the model's NAME
  /// with it: the note is about one rig's front panel, and the operator has
  /// to know which rig is being described.
  ({String model, String text})? get voiceRecordingHelp {
    if (_voiceKeyer?.canRecordVoice != true) return null;
    // The LOCAL node: a peer's rig has a front panel nobody here can reach.
    final uuid = station.localRadio1;
    if (uuid == null) return null;
    final node = station.nodeFor(uuid);
    if (node == null) return null;
    final model = station.typeFor(node)?.model;
    final text = model?.recordingHelp;
    if (model == null || text == null) return null;
    return (model: model.name, text: text);
  }

  /// What radio1's voice keyer is doing for the app, or null — for the keyer
  /// area. Its own notifier for the same reason [cwProgress] is.
  final voiceActivity = ValueNotifier<VoiceActivity?>(null);

  /// Plays memory [n] on radio1 — a no-op, not an error, when nothing can
  /// play: the surfaces that call this only exist while [canPlayVoice], so
  /// reaching here without one is the radio dropping between the check and
  /// the keypress.
  /// [repeat] is what separates KEYING a memory from auditioning one: the
  /// editor's Play is the operator listening to what they recorded, and a CQ
  /// that started repeating from inside a settings dialog would be one
  /// nobody was watching the air for.
  void playVoiceMemory(int n, {bool repeat = true}) {
    // Whether this play is the next link in a chain, or the end of one. A
    // cancel before an arm would reset the five-minute limit on every repeat
    // (`KeyerRepeat.arm` keeps the deadline it inherits, and a cancel drops
    // it), so an unattended CQ would key forever — over the link, somebody
    // else's transmitter.
    final chaining = repeat && n == 1 && settings.voiceRepeatDelay > Duration.zero;
    // Marked only once the play is taken, the same rule [sendCw] states.
    _voiceMessageOne = false;
    if (playsVoiceOverPeer) {
      // The chain is armed HERE and the memory plays THERE: the repeat
      // engine waits on the activity ending, which arrives as the far
      // radio's status, and a chain must break on the Escape or the
      // entered call of the operator who started it.
      if (!chaining) chain.cancel();
      // Armed only once the request has gone, the same rule the local branch
      // states for a session that throws: the M1 button is live off the last
      // offer heard, so it can be pressed with no bridge under it.
      if (!requestPeerKey(PeerKeyOp.voice, memory: n)) {
        chain.cancel();
        return;
      }
      _voiceMessageOne = n == 1;
      if (chaining) {
        chain.arm(delay: settings.voiceRepeatDelay, text: '', memory: n, send: () => playVoiceMemory(n));
      }
      return;
    }
    final session = _voiceKeyer;
    if (session == null) return;
    try {
      // Message 1 only, the same rule as CW (SettingsService.voiceRepeatDelay).
      // Armed HERE rather than at the surfaces, because a memory needs no
      // rendering: the app has nothing to prepare, so every way of playing
      // one — a key, a button, the dialog — repeats alike. Any OTHER memory
      // ends a chain: the operator has moved on.
      if (!chaining) chain.cancel();
      station.yieldTransmitter(station.localRadio1);
      _startMeasurement(n);
      session.playVoiceMemory(n);
      _voiceMessageOne = n == 1;
      // Armed only once the session has taken it: a throw above would
      // otherwise leave a chain armed with nothing playing, and nothing
      // ending to start its next wait.
      if (chaining) {
        chain.arm(delay: settings.voiceRepeatDelay, text: '', memory: n, send: () => playVoiceMemory(n));
      }
    } catch (e, st) {
      chain.cancel();
      ErrorReportingService.report(e, st, context: 'cat:play-voice-memory');
    }
  }

  /// Starts recording memory [n] on radio1 — see [VoiceKeyerSession.recordVoiceMemory].
  void recordVoiceMemory(int n) {
    if (playsVoiceOverPeer) {
      if (peer.recordsVoice) requestPeerKey(PeerKeyOp.record, memory: n);
      return;
    }
    recordVoiceLocally(station.localRadio1, n);
  }

  /// Records into [uuid]'s memory [n] — radio1's for this operator, or an
  /// offered radio's for a peer's.
  void recordVoiceLocally(String? uuid, int n) {
    final session = uuid == null ? null : voiceKeyerFor(uuid);
    if (session == null || !session.canRecordVoice) return;
    try {
      session.recordVoiceMemory(n);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:record-voice-memory');
    }
  }

  /// Plays [uuid]'s memory [n] for a peer. No repeat is armed: the chain
  /// belongs to the operator who asked, on their own device. Nor is this
  /// station's own chain ended — unlike a STOP, which is an ask for silence
  /// on the shared transmitter and takes the chain with it.
  void playVoiceLocally(String uuid, int n) {
    final session = voiceKeyerFor(uuid);
    if (session == null) return;
    // A peer's memory 1 is not this operator's CQ, the same rule the CW
    // request states at [handleRequest].
    if (_sameTransmitter(uuid, station.localRadio1)) _voiceMessageOne = false;
    try {
      // Measured only on radio1, which is the rig whose memory lengths this
      // device stores — a second offered radio's memories are timed by
      // whoever has it as their radio1.
      station.yieldTransmitter(uuid);
      if (_sameTransmitter(uuid, station.localRadio1)) _startMeasurement(n);
      session.playVoiceMemory(n);
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:play-voice-memory');
    }
  }

  /// Stops whatever [uuid] is playing or recording, for a peer.
  void stopVoiceLocally(String uuid) {
    // The chain goes too, the same rule [stopCwLocally] states: a memory
    // stopped for a peer must not start playing again on this operator's
    // repeat delay.
    chain.cancel();
    if (_sameTransmitter(uuid, station.localRadio1)) {
      cancelVoiceSequence();
      // What a stop cut short is not a measurement, the same rule
      // [stopVoice] applies to this operator's own.
      _playMemory = null;
      _playStart = null;
      _playDoubted = false;
    }
    final session = voiceKeyerFor(uuid);
    if (session == null) return;
    try {
      session.stopVoice();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:stop-voice');
    }
  }

  /// Real milliseconds at the play that is being timed, and which memory it
  /// is — real, because the length of a message must not stretch with the
  /// app clock (docs/design/time.md). Null while nothing is being timed.
  int? _playStart;
  int? _playMemory;

  /// Whether the radio ever DOUBTED this play — answered "not going" before
  /// it ever answered "going" (voice_activity_tracker.dart). That is what a
  /// refused memory looks like, and it is not something to measure.
  bool _playDoubted = false;

  /// Times the play that just started, so ordinary use measures the memory:
  /// every play is a measurement, and no operator has to ask for one. Safe
  /// on any radio, since it times what the radio itself reports rather than
  /// anything it is told.
  void _startMeasurement(int n) {
    _playStart = realNowMillis();
    _playMemory = n;
    _playDoubted = false;
  }

  /// Stores what the play lasted, when the radio said it was playing at all.
  /// In milliseconds, as measured: the number paces a progress bar, and a
  /// value rounded to the second finishes visibly early or late.
  ///
  /// Three plays are NOT measurements. One the radio DOUBTED: "idle" before
  /// ever "going" is a refused memory, and storing its doubt linger as a
  /// length invents one. One the CEILING stopped: that timed the app's own
  /// limit, not the audio. And a recording, which times how long the
  /// operator held the button — [stopVoice] drops the timing outright, since
  /// a play the operator cut short did not reach its end either.
  Future<void> _endMeasurement() async {
    final memory = _playMemory;
    final start = _playStart;
    final doubted = _playDoubted;
    _playMemory = null;
    _playStart = null;
    _playDoubted = false;
    if (memory == null || start == null || doubted) return;
    // A radio that times its own memories has already said how long this
    // one runs, and a measurement stored here would never be read.
    if (_radioHeldMemories(station.localRadio1).isNotEmpty) return;
    final elapsed = realNowMillis() - start;
    final ceiling = _voiceKeyer?.voiceMemoryCeiling ?? voiceActivityCeiling;
    if (elapsed >= ceiling.inMilliseconds) return;
    if (elapsed <= 0) return;
    await settings.setVoiceMessageDuration(memory, elapsed);
  }

  /// Stops whatever radio1's voice keyer is playing or recording.
  /// Memories an Enter Sends Messages step still has to play, after the one
  /// on the air (docs/design/logging-fields.md § Enter Sends Messages). A
  /// radio plays one memory at a time, so each waits for the last to END —
  /// [voiceActivity] going quiet after it was seen playing, since over a peer
  /// the start arrives later than the ask. Every stop clears it: a sequence
  /// cut short by the operator must not put its thanks on the air anyway.
  final List<int> _voiceSequence = [];
  bool _sequenceStarted = false;

  /// Whether the sequence running holds memory 1 anywhere — played, playing
  /// or still waiting — until its last memory ends. Set only for two or
  /// more memories: a lone one is a plain play, marked by [_voiceMessageOne],
  /// and has no start timeout to clear a mark its play never ended.
  bool _voiceSequenceHasOne = false;

  /// How long a queued memory waits to be heard starting before the
  /// sequence is given up: a play refused or lost on the way would otherwise
  /// leave the rest queued behind the next memory the operator plays by
  /// hand. Real time, never the app clock — it becomes a [Timer].
  static const voiceSequenceStartGrace = Duration(seconds: 3);
  Timer? _sequenceStartTimer;

  /// Plays [memories] one after another. Only a single memory repeats, as
  /// [playVoiceMemory] would: a CQ, never an exchange.
  void playVoiceSequence(List<int> memories) {
    cancelVoiceSequence();
    if (memories.isEmpty) return;
    _voiceSequenceHasOne = memories.length > 1 && memories.contains(1);
    _voiceSequence.addAll(memories.skip(1));
    _awaitSequenceStart();
    playVoiceMemory(memories.first, repeat: memories.length == 1);
  }

  void cancelVoiceSequence() {
    _voiceSequence.clear();
    _voiceSequenceHasOne = false;
    _sequenceStarted = false;
    _sequenceStartTimer?.cancel();
    _sequenceStartTimer = null;
  }

  void _awaitSequenceStart() {
    if (_voiceSequence.isEmpty) return;
    _sequenceStarted = false;
    _sequenceStartTimer?.cancel();
    _sequenceStartTimer = Timer(voiceSequenceStartGrace, cancelVoiceSequence);
  }

  void _onVoiceActivityForSequence() {
    final activity = voiceActivity.value;
    if (_voiceSequence.isEmpty) {
      // The last memory has ended, and the sequence with it.
      if (activity == null) _voiceSequenceHasOne = false;
      return;
    }
    if (activity != null) {
      // A recording is nobody's sequence; the operator is at the editor.
      if (activity.recording) return cancelVoiceSequence();
      _sequenceStarted = true;
      _sequenceStartTimer?.cancel();
      return;
    }
    if (!_sequenceStarted) return;
    final next = _voiceSequence.removeAt(0);
    _awaitSequenceStart();
    playVoiceMemory(next, repeat: false);
  }

  void stopVoice() {
    // A stop is a stop, the same as [stopCw]'s.
    chain.cancel();
    cancelVoiceSequence();
    // And what it stopped is NOT a measurement: the memory did not play to
    // its end, so timing it would store a length shorter than the audio and
    // pace every later bar to finish early.
    _playMemory = null;
    _playStart = null;
    _playDoubted = false;
    if (playsVoiceOverPeer) {
      requestPeerKey(PeerKeyOp.stopVoice);
      return;
    }
    final session = _voiceKeyer;
    if (session == null) return;
    try {
      session.stopVoice();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:stop-voice');
    }
  }

  /// A keyer reported its progress. Shown, and reported onward, only for the
  /// key in use: another node's queue is not what the app handed a message to.
  void noteCwProgress(String uuid, CwSendProgress? progress) {
    if (uuid != _cwKeyerUuid) return;
    _cwFromPeer = false;
    cwProgress.value = progress;
    // Nothing left keying is where a CW repeat's wait begins.
    if (progress == null && chain.memory == null) chain.startWait();
    onKeyingChanged();
  }

  /// The far side's account of what the picked radio is keying, for the
  /// halves this operator is watching — the strip is the peer's only while
  /// the peer is what keys, and an operator who picked a local keyer for that
  /// radio watches THAT keyer's message go out.
  void notePeerStatus(PeerKeyStatusPayload status) {
    peer.status = status;
    if (keysOverPeer) {
      _writePeerProgress(peer.progress);
      if (status.cw == null && chain.memory == null) chain.startWait();
    }
    if (playsVoiceOverPeer) {
      _writePeerActivity(peer.activity);
      if (status.voice == null && chain.memory != null) chain.startWait();
    }
  }

  /// What this station's own key is doing, for a peer's status — never the
  /// keying it is itself FOLLOWING. A station that offers a rig while
  /// following a third device would otherwise publish that device's message
  /// and speed as its own radio's, which is the relay the header forbids.
  int? get localKeyerSpeed => keysOverPeer ? null : keyerSpeed;

  ({int min, int max})? get localKeyerSpeedRange => keysOverPeer ? null : keyerSpeedRange;

  CwSendProgress? get localCwProgress => keysOverPeer ? null : cwProgress.value;

  /// What the surfaces read off a peer's status BESIDE the notifiers — the
  /// speed, the speeds it accepts, and the memories' names and lengths.
  ///
  /// Compared rather than notified on: a status arrives per character from a
  /// keyer that echoes them, and a service-wide notification each would
  /// rebuild every equipment row in the Station panel for a value only the
  /// keyer row reads. The strip follows [cwProgress] and [voiceActivity],
  /// which this does not speak for.
  Object get peerShownState => (
    peer.keyerSpeed,
    peer.keyerSpeedRange,
    Object.hashAll(peer.status?.voiceLabels ?? const []),
    Object.hashAll(peer.status?.voiceDurationsMs ?? const []),
    peer.voiceMemories,
  );

  // ------------------------------------------- the bridge, both directions

  /// What this station is keying, for a peer that picked [radioId] — the
  /// offerer's half of the bridge. The caller has already checked that the
  /// radio is offered and that keying is switched on here.
  ///
  /// Everything in it is this station's OWN: publishing what it is itself
  /// following would be a relay by another name (see the header).
  PeerKeyStatusPayload statusForOfferedRadio(String radioId) {
    final range = localKeyerSpeedRange;
    final memories = voiceKeyerFor(radioId)?.voiceMemoryCount ?? 0;
    return PeerKeyStatusPayload(
      radioId: radioId,
      keyerSpeedWpm: localKeyerSpeed,
      keyerSpeedMin: range?.min,
      keyerSpeedMax: range?.max,
      cw: cwProgressToWire(localCwProgress),
      voice: voiceActivityToWire(voiceActivityFor(radioId)),
      // Only as many as that radio has: a label for a ninth memory is a
      // label for a button nobody will be shown.
      voiceLabels: [for (var n = 1; n <= memories; n++) _localVoiceLabel(radioId, n)],
      voiceDurationsMs: [for (var n = 1; n <= memories; n++) _localVoiceDuration(radioId, n)],
    );
  }

  /// Keys, stops, or sets a speed here for a peer — through the same funnels
  /// a local function key takes. The caller has checked that the radio is one
  /// this station offers.
  ///
  /// Every arm keys HERE or not at all. A request is never relayed onward to
  /// whatever radio1 this device is itself following: an operator who picked
  /// this station's rig asked for this station's rig, and a chain of them
  /// would put a transmitter two devices away on the air for somebody who
  /// picked neither.
  void handleRequest(PeerKeyRequestPayload request) {
    switch (request.op) {
      case PeerKeyOp.cw:
        // The peer's message is now the newest on this transmitter, and it
        // is not this operator's message 1.
        _lastCwHasMessageOne = false;
        sendCwLocally(request.text);
      case PeerKeyOp.stopCw:
        stopCwLocally();
      case PeerKeyOp.dropCw:
        if (request.queuedId != null) dropQueuedCwLocally(request.queuedId!);
      case PeerKeyOp.wpm:
        if (request.wpm != null) setKeyerSpeedLocally(request.wpm!);
      case PeerKeyOp.voice:
        if (request.memory != null) playVoiceLocally(request.radioId, request.memory!);
      case PeerKeyOp.record:
        if (request.memory != null) recordVoiceLocally(request.radioId, request.memory!);
      case PeerKeyOp.stopVoice:
        stopVoiceLocally(request.radioId);
    }
  }

  /// Points this at what a peer last said about the radio now picked — a new
  /// pick, or a fresh offer for the one already picked. Answers whether
  /// anything moved.
  ///
  /// What the peer was filling never outlives it. A pick that moves off a
  /// peer radio leaves the strip showing a message over a rig nobody is
  /// following, and a voice activity nothing can stop keeps Escape claimed
  /// (docs/design/logging-fields.md) — the logging fields then stop clearing
  /// on Escape for the rest of the session.
  bool adoptPeer(PeerRadioOffer? offer, PeerKeyStatusPayload? status) {
    if (offer == peer.offer && status == peer.status) return false;
    peer.offer = offer;
    peer.status = status;
    if (keysOverPeer) {
      _writePeerProgress(peer.progress);
    } else if (_cwFromPeer) {
      _writePeerProgress(null);
    }
    if (playsVoiceOverPeer) {
      _writePeerActivity(peer.activity);
    } else if (_voiceFromPeer) {
      _writePeerActivity(null);
    }
    return true;
  }

  /// Whether what the strip is showing came off the WIRE. The pick moving, or
  /// the peer leaving, may only clear what that peer was filling: a local
  /// keyer's message blanked under the operator is a transmitter still keying
  /// with nothing left to stop it, and a peer's activity left standing keeps
  /// Escape claimed for the rest of the session
  /// (docs/design/logging-fields.md).
  bool _cwFromPeer = false;
  bool _voiceFromPeer = false;

  void _writePeerProgress(CwSendProgress? progress) {
    _cwFromPeer = progress != null;
    cwProgress.value = progress;
  }

  void _writePeerActivity(VoiceActivity? activity) {
    _voiceFromPeer = activity != null;
    voiceActivity.value = activity;
  }

  /// That peer is out of reach, so nothing of its keying stands. Answers
  /// whether anything had to be forgotten.
  ///
  /// What is cleared is only what the PEER was filling. An operator who
  /// pointed this radio at a key of their own is watching that key's message
  /// go out, and a strip blanked under them would be a transmitter still
  /// keying with nothing on screen to stop it.
  bool forgetPeer() {
    // The chain waits on the far side saying the message or the memory ended,
    // and that report can no longer arrive: left armed it latches the strip's
    // repeat indicator on with nothing playing, and — if that peer comes back
    // inside the five minutes — its first idle status starts the wait and the
    // chain keys somebody else's transmitter minutes after the operator lost
    // sight of it. Only the chain THIS peer would have ended: a local keyer's
    // is none of its business.
    final endedByPeer = chain.memory == null ? keysOverPeer : playsVoiceOverPeer;
    if (!peer.clear()) return false;
    if (chain.running && endedByPeer) chain.cancel();
    if (_cwFromPeer) _writePeerProgress(null);
    // The silence below is the link going, not a memory ending.
    if (_voiceFromPeer) {
      cancelVoiceSequence();
      _writePeerActivity(null);
    }
    return true;
  }

  /// What each node's voice keyer is doing, for the nodes doing something.
  /// Radio1's is also [voiceActivity]; this is what answers for a radio this
  /// device is only offering.
  final Map<String, VoiceActivity> _voiceActivityByNode = {};

  /// What [uuid]'s voice keyer is doing, for a radio this device is only
  /// OFFERING — its play is somebody else's operator's, and has to reach them.
  VoiceActivity? voiceActivityFor(String uuid) => _voiceActivityByNode[uuid];

  /// A radio reported what its voice keyer is doing.
  void noteVoiceActivity(String uuid, VoiceActivity? activity) {
    // Held per node, because a radio this device merely OFFERS plays for
    // somebody else's operator and that play has to be reportable.
    if (activity == null) {
      _voiceActivityByNode.remove(uuid);
    } else {
      _voiceActivityByNode[uuid] = activity;
    }
    onKeyingChanged();
    // Only radio1's memories play for THIS app, so only its are shown.
    // The LOCAL radio1: a peer's arrive as that peer's status instead.
    if (uuid != station.localRadio1) return;
    _voiceFromPeer = false;
    voiceActivity.value = activity;
    if (_playMemory == null) return;
    // These same reports time the play: a doubtful one is the radio never
    // confirming, and the end is what the clock stops at.
    if (activity == null) {
      unawaited(_endMeasurement());
    } else if (activity.doubtful) {
      // The radio said "not going" before it ever said "going": a refused
      // memory, whose "length" would be the doubt linger rather than any
      // audio. Watched rather than asked about, because a confirmed play
      // reports nothing new to see (the tracker only re-reports an activity
      // whose doubt it is WITHDRAWING).
      _playDoubted = true;
    }
    // The memory ending is where a voice repeat's wait begins — the
    // counterpart of cwProgress going null for a message.
    if (activity == null && chain.memory != null) chain.startWait();
  }

  /// A node's link went down, or the key in use moved off it: whatever it was
  /// keying is not keying now.
  void forgetNode(String uuid, {required bool wasKeyInUse, required bool wasRadio1}) {
    if (wasKeyInUse) cwProgress.value = null;
    if (wasRadio1) {
      // The silence is the radio going, not a memory ending.
      cancelVoiceSequence();
      voiceActivity.value = null;
    }
    // A radio that is gone is playing nothing. Left behind, its last
    // activity would be reported to a peer forever — the radio is no longer
    // offered, but the memory of it playing would outlive the offer.
    _voiceActivityByNode.remove(uuid);
    onKeyingChanged();
  }

  bool _sameTransmitter(String? a, String? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    final device = station.logicalDeviceIdFor(a);
    return device != null && device == station.logicalDeviceIdFor(b);
  }

  /// Stops the CW and voice of other physical transmitters. Logical receiver
  /// siblings share the target's queue, so stopping one would cancel the
  /// message this send must queue behind. A standalone keyer is left alone.
  void quietOthers(String? radio) {
    for (final node in station.nodes) {
      if (_sameTransmitter(node.uuid, radio)) continue;
      if (station.connectedSession(node.uuid) is! TransceiverSession) continue;
      final session = station.connectedSession(node.uuid);
      try {
        // Only the chain of what is stopped here: this runs inside a chain's
        // own send too, and that chain is not what went quiet. Left armed, a
        // stopped CQ would come back after its wait and take the transmitter
        // back from the radio that took it.
        if (session is CwKeyerSession && session.cwSending) {
          if (node.uuid == _cwKeyerUuid && chain.memory == null) chain.cancel();
          session.stopCw();
        }
        if (session is VoiceKeyerSession && _voiceActivityByNode.containsKey(node.uuid)) {
          if (node.uuid == station.localRadio1) {
            if (chain.memory != null) chain.cancel();
            cancelVoiceSequence();
            // Cut short, so not a measurement — [stopVoice]'s rule.
            _playMemory = null;
            _playStart = null;
            _playDoubted = false;
          }
          session.stopVoice();
        }
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:quiet-others');
      }
    }
  }

  /// Stops what the OUTGOING key was keying when the key in use changes —
  /// that message would otherwise finish with nothing showing it and nothing
  /// to stop it.
  void abandonKeying(String? previousUuid) {
    final previous = previousUuid == null ? null : station.connectedSession(previousUuid);
    if (previous is CwKeyerSession && previous.cwSending) {
      try {
        previous.stopCw();
      } catch (e, st) {
        ErrorReportingService.report(e, st, context: 'cat:stop-cw');
      }
    }
    // Cleared only when what keys has actually moved AWAY from the peer: an
    // operator re-picking `Key on ‹device›` would otherwise blank the message
    // that peer is keying until its next character report.
    if (!keysOverPeer) _writePeerProgress(null);
    refreshKeyerSpeed();
  }

  void dispose() {
    cancelVoiceSequence();
    _keyingRevision.dispose();
    cwProgress.dispose();
    cwStops.dispose();
    voiceActivity.dispose();
    keyerAreaShown.dispose();
    enterSends.dispose();
    keyerShowRequests.dispose();
    keyboardModeRequests.dispose();
  }
}
