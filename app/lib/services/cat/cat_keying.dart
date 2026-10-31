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
import 'package:halo_audio/halo_audio.dart' show AudioPlayback, HaloAudioException;
import 'package:halo_core/halo_core.dart';

import '../error_reporting_service.dart';
import '../settings_service.dart';
import 'computer_voice_keyer.dart';
import 'driver.dart';
import 'drivers/cw_send_queue.dart' show CwSendProgress;
import 'equipment.dart';
import 'equipment_registry.dart';
import 'keyer_repeat.dart';
import 'peer_keying.dart';

part 'cat_keying_computer_voice.dart';
part 'cat_keying_peer_bridge.dart';

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

  /// The local rig this keyer keys: radio1 when it is a rig of this
  /// station's own — or, for SO2R's second keyer, Radio B — and null when
  /// radio1 is a peer's or none: the memories are audio in the transceiver,
  /// and there is nothing local to play when the transceiver is somewhere
  /// else.
  String? get localKeyingRadio;

  /// SO2R's turn-taking (docs/design/cat.md § Radio B, for SO2R): whether
  /// this keyer may go on the air now. False holds the send ([CatKeying.waiting])
  /// until the other radio is quiet. [repeat] is a repeat chain's own send,
  /// which always waits its turn; an operator's may instead stop the other
  /// radio, which this does before answering true. Always true for a station
  /// with one radio.
  /// [queuedCw] can append to a shared CAT queue; voice never can.
  bool clearToSend({required bool repeat, bool queuedCw = false});

  /// SO2R's Radio B, or null — whose voice memories are named and timed
  /// apart from radio1's.
  String? get radio2;

  Future<void> updateNode(EquipmentNode node);

  /// Quiets every radio but [radio] before it transmits — one transmitter at
  /// a time (CatService.yieldTransmitter, docs/design/cat.md § PTT).
  void yieldTransmitter(String? radio);
}

class CatKeying {
  CatKeying({required this.station, required this.settings, required this.chain, required this.peer, this.radio = 'A'}) {
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
    // A repeat's send held for the other radio belongs to its chain: once
    // the chain ends — an entered call, a tap, a QSY — it must not go out.
    chain.active.addListener(() {
      if (!chain.active.value) _dropWaiting((send) => send.repeat);
    });
  }

  final KeyingStation station;
  final SettingsService settings;

  /// Message 1 going again — one engine for both keyers (keyer_repeat.dart).
  final KeyerRepeat chain;

  /// The picked peer radio's keying (peer_keying.dart) — what the far
  /// station will do, and what it says it is doing.
  final PeerKeying peer;

  /// Which of the station's radios this keys for, `A` or `B` — whose Phone
  /// Keying pick is this keyer's (SettingsService.voiceKeyingSourceFor).
  final String radio;

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
  /// belong to whatever radio fills the role — never while keying is SO2R's
  /// Radio B, whose memories are in that rig, as [peerKeyIsInUse] says for
  /// CW.
  bool get playsVoiceOverPeer => peer.playsVoice && (station.radio2 == null || station.localKeyingRadio != station.radio2);

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

  /// Bumped by KEYER: the logging panel opens its keyer control.
  final keyerOpenRequests = ValueNotifier<int>(0);

  /// Bumped as keyboard mode starts: the logging panel opens its keyer
  /// control, where the mode's field is.
  final keyboardModeRequests = ValueNotifier<int>(0);

  void openKeyerControl() => keyerOpenRequests.value++;

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
  bool sendCw(String text, {bool hasMessageOne = false, bool repeat = false}) {
    // Asked before the turn is: a key this radio cannot send must not stop
    // the other radio's message for nothing.
    if (!canKeyCw) return false;
    if (!station.clearToSend(repeat: repeat, queuedCw: true)) {
      _hold(
        text: text,
        repeat: repeat,
        messageOne: hasMessageOne || repeat,
        send: () => sendCw(text, hasMessageOne: hasMessageOne, repeat: repeat),
      );
      return true;
    }
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
    station.yieldTransmitter(station.connectedSession(_cwKeyerUuid!) is TransceiverSession ? _cwKeyerUuid : station.localKeyingRadio);
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
    _dropWaiting((send) => send.messageOne);
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

  /// Whether a message, chain or repeat is under way — anything Escape would
  /// stop.
  bool get busy => chain.running || _voiceSequence.isNotEmpty || voiceActivity.value != null || voiceStarting.value || cwSending || waiting.value.isNotEmpty;

  /// Whether this keyer's radio is on the air for the app: a message keying,
  /// or a memory playing or asked for and not yet heard starting. A
  /// recording is not: nothing goes out.
  bool get onAir => cwSending || voiceStarting.value || (voiceActivity.value != null && !voiceActivity.value!.recording);

  /// Whether anything but a repeat waits to go out on this radio — behind
  /// the message keying, behind the memory playing, or for the other radio.
  bool get hasQueued =>
      waiting.value.any((send) => !send.repeat) || (cwSending && (cwProgress.value?.pending.isNotEmpty ?? false)) || _voiceSequence.isNotEmpty;

  /// Escape: stops every message, chain and repeat, whatever the keyer, the
  /// mode, or whose they are. False when there was nothing to stop, so the
  /// key keeps its usual meaning in the logging fields. [alsoStopped] says
  /// the same Escape already stopped something outside the keyers (a held
  /// PTT key), which the logging fields must hear about the same way.
  bool stopKeying({bool alsoStopped = false}) {
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
    // A memory asked for and not yet heard starting is as much on its way
    // out as one playing.
    final voice = voiceActivity.value != null || voiceStarting.value;
    clearWaiting();
    chain.cancel();
    cancelVoiceSequence();
    if (voice) stopVoice();
    if (cwSending) stopCw();
  }

  /// Stops whatever [sendCw] still has to send — see [CwKeyerSession.stopCw]
  /// for how much of what is already on the radio this can reach.
  void stopCw() {
    // A stop is a stop: the operator who cut this message short did not ask
    // for it again in five seconds, nor for what waits behind it.
    chain.cancel();
    _dropWaiting((send) => send.text != null);
    _stopCw();
  }

  /// [stopCw] without ending the repeat chain — see [interrupt].
  void _stopCw() {
    cwStops.value++;
    if (keysOverPeer) {
      // The strip is left to the far side's next status rather than cleared
      // here: on some keyers a stop empties the queue and lets the piece
      // already going play out, and a strip that went blank would say the
      // transmitter was quiet while it was still keying.
      requestPeerKey(PeerKeyOp.stopCw);
      return;
    }
    _stopCwSession();
  }

  void stopCwLocally() {
    // Again for a far station's stop, which arrives here without [stopCw].
    cwStops.value++;
    // Whoever asked for silence gets it, chain included — a stop that left an
    // unattended CQ re-keying this station's transmitter in five seconds is
    // the one outcome worse than a message cut short. The voice half says the
    // same thing at [stopVoiceLocally].
    chain.cancel();
    _stopCwSession();
  }

  void _stopCwSession() {
    final session = _cwKeyer;
    if (session == null) return;
    try {
      session.stopCw();
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'cat:stop-cw');
    }
  }

  // ----------------------------------------------- SO2R's turn-taking

  /// What waits to go out on this radio for the other one to fall quiet
  /// ([KeyingStation.clearToSend]), oldest first — for the keyer area, which
  /// shows it under an indeterminate bar.
  final waiting = ValueNotifier<List<WaitingSend>>(const []);

  /// Orders the holds of both of a station's keyers: the oldest goes first.
  static int _holdSequence = 0;

  /// [sequence] keeps the place of a hold this one replaces.
  void _hold({
    String? text,
    int? memory,
    List<int> then = const [],
    required bool repeat,
    bool messageOne = false,
    required void Function() send,
    int? sequence,
  }) {
    final held = WaitingSend._(sequence ?? ++_holdSequence, text: text, memory: memory, then: then, repeat: repeat, messageOne: messageOne, send: send);
    waiting.value = [...waiting.value, held];
  }

  /// [memories] held whole: one message, whose memories follow each other
  /// with nothing of the other radio's between them.
  void _holdVoiceSequence(List<int> memories, {required bool repeat, int? sequence}) => _hold(
    memory: memories.first,
    then: memories.sublist(1),
    repeat: false,
    messageOne: memories.contains(1),
    send: () => playVoiceSequence(memories, repeat: repeat),
    sequence: sequence,
  );

  void _dropWaiting(bool Function(WaitingSend send) test) {
    if (waiting.value.any(test)) waiting.value = [...waiting.value.where((send) => !test(send))];
  }

  void clearWaiting() {
    if (waiting.value.isNotEmpty) waiting.value = const [];
  }

  /// Drops the operator's messages waiting here, a repeat's own send kept:
  /// keyed over from the other radio, with messages not queued.
  void dropWaitingMessages() => _dropWaiting((send) => !send.repeat);

  /// Sends what [waiting] holds, the other radio having fallen quiet. CW
  /// queues behind itself on the key; a memory plays one at a time, so the
  /// sends stop at the first one and the rest wait for it to end.
  void flushWaiting() {
    final held = waiting.value;
    if (held.isEmpty) return;
    var sent = 0;
    while (sent < held.length) {
      final send = held[sent++];
      if (send.memory != null) break;
      if (sent < held.length && held[sent].memory != null) break;
    }
    waiting.value = held.sublist(sent);
    for (final send in held.take(sent)) {
      send.send();
    }
  }

  /// Takes this radio off the air for the other one, the repeat chain kept:
  /// the message or memory going out stops, and so does a sequence it is
  /// part of, but a CQ repeating here resumes once the other radio is done.
  void interrupt() {
    cancelVoiceSequence();
    if (cwSending) _stopCw();
    if (voiceActivity.value != null || voiceStarting.value) _stopVoice();
  }

  /// Escape while messages wait (SO2R's "Messages queued instead of
  /// interrupting"): only what is on the air stops. What keyed behind it on
  /// this radio waits instead, and the repeat chain stays.
  void stopCurrent() {
    final queued = cwSending ? cwProgress.value?.pending ?? const <String>[] : const <String>[];
    final memories = [..._voiceSequence];
    interrupt();
    for (final text in queued) {
      _hold(text: text, repeat: false, send: () => sendCw(text));
    }
    // Queued, a memory 1 never repeats: held as a sequence of one, it would.
    if (memories.isNotEmpty) _holdVoiceSequence(memories, repeat: false);
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

  /// This radio's Phone Keying pick (`VoiceKeyingSource`). Each radio's is
  /// its own: each rig has a sound card of its own, or none, and None on
  /// one must not silence the other.
  VoiceKeyingSource get voiceSource => settings.voiceKeyingSourceFor(radio);

  /// The sound system the computer's voice keyer plays through, and the
  /// directory its recordings live in — both null where it cannot run (the
  /// web, mobile, and tests that do not ask for it; CatService sets it only
  /// where it is supported), and the directory null until the app's data
  /// directory has been resolved.
  VoiceAudio? voiceAudio;
  String? voiceMessagesDir;

  /// Resolves [voiceMessagesDir], asked for only once something needs it: a
  /// set of recordings in use, or the dialog that makes one.
  Future<String> Function()? voiceMessagesDirectory;

  /// Announces a change the computer's voice keyer depends on — the
  /// directory found, the set in use picked — as the service's own, which is
  /// what [syncComputerKeyers] runs on.
  void Function()? onComputerVoiceChanged;
  bool _directoryAsked = false;

  /// The computer's voice keyer for each radio that plays from it, built
  /// against the session it keys and rebuilt when that session changes.
  final Map<String, ComputerVoiceKeyer> _computerKeyers = {};

  /// See [ComputerVoiceKeying._deskRecorder].
  ComputerVoiceKeyer? _recorder;

  /// [radio1]'s session, when it is connected and has voice memories to
  /// play. Radio1 and not the key in use: the memories are audio held by
  /// the transceiver itself, so there is nothing to designate — a WinKeyer
  /// has none, and a second radio's memories are that radio's. Every voice
  /// surface (the Phone-mode message buttons, F1-F8 in a Phone mode, the
  /// Phone Keyer dialog's Play and Record) exists only while this is
  /// non-null.
  VoiceKeyer? get _voiceKeyer {
    final uuid = station.localKeyingRadio;
    if (uuid == null) return null;
    return voiceKeyerFor(uuid);
  }

  /// [uuid]'s session as a voice keyer, connected and with memories in it —
  /// the per-node form of [_voiceKeyer], which asks only about radio1. A
  /// radio this device merely OFFERS plays its own memories: the audio is in
  /// that rig, so radio1 cannot answer for it.
  VoiceKeyer? voiceKeyerFor(String uuid) {
    // Never the radio's own memories in its place: the operator picked the
    // computer, and a radio it cannot key plays nothing rather than
    // something else (computerVoiceProblem says why).
    if (_playsFromComputer(uuid)) return _computerKeyers[uuid];
    if (voiceSource != VoiceKeyingSource.radio) return null;
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
    final uuid = station.localKeyingRadio;
    if (_playsFromComputer(uuid)) return true;
    if (uuid == null) return false;
    return voiceSource == VoiceKeyingSource.radio && radio1OffersVoiceMemories;
  }

  /// Whether radio1's entry holds voice memories of its own, whichever source
  /// is picked — what decides whether the radio is offered as one.
  bool get radio1OffersVoiceMemories {
    final uuid = station.localKeyingRadio;
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
  bool get canRecordVoice => _voiceKeyer?.canRecordVoice ?? (playsVoiceOverPeer ? peer.recordsVoice : _deskRecorder != null);

  /// What the memories are CALLED, and how long each was measured to run.
  ///
  /// The owner's, always: a peer radio's memories are named and timed on the
  /// device they are recorded in, and a label from here would name somebody
  /// else's audio while a duration from here would pace a bar against a
  /// recording this station has never played. Editing one is therefore the
  /// owner's too — [voiceMessagesAreLocal] is what a surface asks before it
  /// offers to.
  String voiceMessageLabel(int n) {
    if (!playsVoiceOverPeer) return _localVoiceLabel(station.localKeyingRadio, n);
    return peer.voiceMessageLabel(n);
  }

  int voiceMessageDuration(int n) {
    if (!playsVoiceOverPeer) return _localVoiceDuration(station.localKeyingRadio, n);
    return peer.voiceMessageDuration(n);
  }

  /// What [uuid] itself says about its memories — empty unless it is a radio
  /// that names and times them on the radio (a FlexRadio's DVK), and is
  /// connected and has said so. Where it is not empty it is the whole
  /// answer: the settings' labels and measured lengths are for radios that
  /// keep neither, and one shown over the radio's own would name audio by a
  /// label no other client of that radio sees. Empty too while the computer
  /// plays the messages: the radio's memories are then not what plays, and a
  /// label typed for a recording here would rename one of them instead.
  List<VoiceMemory> _radioHeldMemories(String? uuid) {
    if (uuid == null || _playsFromComputer(uuid)) return const [];
    return station.stateFor(uuid).voiceMemories ?? const [];
  }

  /// [uuid]'s own account of memory [n]: null when it keeps none, so the
  /// settings answer, and an empty memory when it keeps them but not this one.
  VoiceMemory? _radioHeldMemory(String? uuid, int n) {
    final held = _radioHeldMemories(uuid);
    if (held.isEmpty) return null;
    return held.where((m) => m.memory == n).firstOrNull ?? VoiceMemory(memory: n);
  }

  String _localVoiceLabel(String? uuid, int n) {
    if (_playsFromComputer(uuid)) return settings.activeVoiceMessageSet.label(n);
    return _radioHeldMemory(uuid, n)?.name ?? settings.voiceMessageLabel(n, radio: _settingsRadio(uuid));
  }

  int _localVoiceDuration(String? uuid, int n) {
    // A recording's length is read off the file, exact and known before the first play. A message said
    // with words has none until it is made: the recording beside it is not what plays.
    if (_playsFromComputer(uuid)) return voiceMessageVoiced(n) ? 0 : voiceAudio!.lengthOf(_voiceFile(n))?.inMilliseconds ?? 0;
    return _radioHeldMemory(uuid, n)?.durationMs ?? settings.voiceMessageDuration(n, radio: _settingsRadio(uuid));
  }

  /// Which radio's labels and lengths the settings keep for [uuid]: Radio
  /// B's for radio2, radio1's for any other — an offered radio's included,
  /// whatever set this operator is in.
  String _settingsRadio(String? uuid) => uuid != null && uuid == station.radio2 ? 'B' : 'A';

  /// Names memory [n] — in the set in use when it is recordings, on the
  /// radio when radio1 holds its own names, in the settings otherwise.
  /// Nothing for a peer's memory: the name is that device's
  /// ([voiceMessagesAreLocal]).
  Future<void> setVoiceMessageLabel(int n, String label) async {
    if (!voiceMessagesAreLocal) return;
    final uuid = station.localKeyingRadio;
    if (_playsFromComputer(uuid)) {
      final id = settings.voiceMessageSetId;
      final sets = [for (final set in settings.voiceMessageSets) set.id == id ? set.withLabel(n, label) : set];
      await settings.setVoiceMessageSets(sets, active: id);
      onKeyingChanged();
      return;
    }
    final session = uuid == null ? null : station.connectedSession(uuid);
    if (session is RadioNamedVoiceMemories && _radioHeldMemories(uuid).isNotEmpty) {
      session.renameVoiceMemory(n, label);
      return;
    }
    await settings.setVoiceMessageLabel(n, label, radio: _settingsRadio(uuid));
  }

  /// Whether the memories in play are this device's own — false while a
  /// peer's radio holds them, which is what stops a label editor from
  /// writing a name onto audio it is not about.
  bool get voiceMessagesAreLocal => !playsVoiceOverPeer;

  /// Whether radio1 names its memories itself, so a label typed here is
  /// written to the radio rather than kept in the app.
  bool get voiceMessagesNamedOnRadio => voiceMessagesAreLocal && _radioHeldMemories(station.localKeyingRadio).isNotEmpty;

  /// How to record a memory on radio1, where the radio needs saying — see
  /// [EquipmentModel.recordingHelp]. Null when nothing can record, or when
  /// the radio's own procedure needs no explaining. Carries the model's NAME
  /// with it: the note is about one rig's front panel, and the operator has
  /// to know which rig is being described.
  ({String model, String text})? get voiceRecordingHelp {
    if (_voiceKeyer?.canRecordVoice != true || _voiceKeyer is ComputerVoiceKeyer) return null;
    // The LOCAL node: a peer's rig has a front panel nobody here can reach.
    final uuid = station.localKeyingRadio;
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
  void playVoiceMemory(int n, {bool repeat = true}) => _playVoiceMemory(n, repeat: repeat, fromChain: false);

  void _playVoiceMemory(int n, {required bool repeat, required bool fromChain}) {
    // Asked before the turn is, as [sendCw] does.
    if (!canPlayVoice) return;
    if (!station.clearToSend(repeat: fromChain)) {
      _hold(
        memory: n,
        repeat: fromChain,
        messageOne: n == 1,
        send: () => _playVoiceMemory(n, repeat: repeat, fromChain: fromChain),
      );
      return;
    }
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
        chain.arm(delay: settings.voiceRepeatDelay, text: '', memory: n, send: () => _playVoiceMemory(n, repeat: true, fromChain: true));
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
      station.yieldTransmitter(station.localKeyingRadio);
      // A recording's length is its file's; timing a play would add the
      // lead and tail to it.
      if (session is! ComputerVoiceKeyer) _startMeasurement(n);
      _awaitVoiceStart();
      session.playVoiceMemory(n);
      _voiceMessageOne = n == 1;
      // Armed only once the session has taken it: a throw above would
      // otherwise leave a chain armed with nothing playing, and nothing
      // ending to start its next wait.
      if (chaining) {
        chain.arm(delay: settings.voiceRepeatDelay, text: '', memory: n, send: () => _playVoiceMemory(n, repeat: true, fromChain: true));
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
    if (_voiceKeyer == null) return _recordWithoutRadio(n);
    recordVoiceLocally(station.localKeyingRadio, n);
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
    if (_sameTransmitter(uuid, station.localKeyingRadio)) _voiceMessageOne = false;
    try {
      // Measured only on this device's own keying radio, the rig whose memory
      // lengths it stores — a second offered radio's memories are timed by
      // whoever has it as their radio1.
      station.yieldTransmitter(uuid);
      if (_sameTransmitter(uuid, station.localKeyingRadio) && session is! ComputerVoiceKeyer) _startMeasurement(n);
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
    if (_sameTransmitter(uuid, station.localKeyingRadio)) {
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

  /// The radio the timed play is on: by its end report keying may have
  /// moved to the other one, whose memory [_playMemory] is not.
  String? _playOn;

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
    _playOn = station.localKeyingRadio;
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
    final on = _playOn;
    final doubted = _playDoubted;
    _playMemory = null;
    _playStart = null;
    _playOn = null;
    _playDoubted = false;
    if (memory == null || start == null || on == null || doubted) return;
    // A radio that times its own memories has already said how long this
    // one runs, and a measurement stored here would never be read.
    if (_radioHeldMemories(on).isNotEmpty) return;
    final elapsed = realNowMillis() - start;
    final ceiling = voiceKeyerFor(on)?.voiceMemoryCeiling ?? voiceActivityCeiling;
    if (elapsed >= ceiling.inMilliseconds) return;
    if (elapsed <= 0) return;
    await settings.setVoiceMessageDuration(memory, elapsed, radio: _settingsRadio(on));
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

  /// [_voiceSequence] as the keyer line shows it, behind the memory playing.
  final voiceQueue = ValueNotifier<List<int>>(const []);

  void _voiceQueueChanged() {
    if (_voiceSequence.isEmpty && voiceQueue.value.isEmpty) return;
    voiceQueue.value = List.unmodifiable(_voiceSequence);
  }

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

  /// Plays memory [n] after what this radio is already playing, as CW
  /// queues behind itself on the key — the operator's message keys. With
  /// nothing playing it plays as [playVoiceMemory] would, a CQ's repeat
  /// included; queued, it never repeats, and it ends a repeat as any other
  /// memory does. The radio stays this one's until the queue is done: the
  /// other SO2R radio's turn comes after it. The computer's keyer plays the
  /// queue under one key ([ComputerVoiceKeyer.following]); a radio's own
  /// memories each key and unkey.
  void queueVoiceMemory(int n) {
    final playing = voiceActivity.value;
    final going = voiceStarting.value || (playing != null && !playing.recording);
    if (!going && _voiceSequence.isEmpty) {
      // Behind a memory held for the other radio, it joins that one, in its
      // place: one turn, as behind a memory playing.
      final held = waiting.value.lastOrNull;
      if (held?.memory case final first? when !held!.repeat && canPlayVoice) {
        chain.cancel();
        waiting.value = waiting.value.sublist(0, waiting.value.length - 1);
        return _holdVoiceSequence([first, ...held.then, n], repeat: false, sequence: held.sequence);
      }
      return playVoiceMemory(n);
    }
    if (!canPlayVoice) return;
    chain.cancel();
    _voiceSequence.add(n);
    _voiceQueueChanged();
    if (_voiceSequence.length == 1) {
      if (playing != null) {
        _sequenceStarted = true;
      } else {
        _awaitSequenceStart();
      }
    }
    // What a callsign entered stops goes by the newest message, as for CW
    // ([stopMessageOne]).
    _voiceSequenceHasOne = n == 1;
    if (n != 1) _voiceMessageOne = false;
  }

  /// The next memory queued here, for a keyer that plays it under the key it
  /// holds rather than ending first.
  int? _takeQueuedVoice() {
    if (_voiceSequence.isEmpty) return null;
    final n = _voiceSequence.removeAt(0);
    _voiceQueueChanged();
    _voiceMessageOne = n == 1;
    return n;
  }

  /// Drops the memory queued at [index] behind the one playing, the rest
  /// left to play — a tap on it, as on a CW message waiting on the key.
  void dropQueuedVoice(int index) {
    if (index < 0 || index >= _voiceSequence.length) return;
    _voiceSequence.removeAt(index);
    _voiceQueueChanged();
    if (!_voiceSequence.contains(1)) _voiceSequenceHasOne = false;
  }

  /// Plays [memories] one after another. Only a single memory repeats, as
  /// [playVoiceMemory] would: a CQ, never an exchange — and not even that
  /// without [repeat].
  void playVoiceSequence(List<int> memories, {bool repeat = true}) {
    cancelVoiceSequence();
    if (memories.isEmpty) return;
    if (memories.length > 1 && canPlayVoice && !station.clearToSend(repeat: false)) {
      _holdVoiceSequence(memories, repeat: repeat);
      return;
    }
    _voiceSequenceHasOne = memories.length > 1 && memories.contains(1);
    _voiceSequence.addAll(memories.skip(1));
    _voiceQueueChanged();
    _awaitSequenceStart();
    playVoiceMemory(memories.first, repeat: repeat && memories.length == 1);
  }

  /// A memory asked to play here and not yet heard starting — keying is busy
  /// with it all the same. Between a sequence's memories, and between any
  /// play and the radio's first report, nothing else says a memory is about
  /// to go out, and keying following the operator to the other radio then
  /// would leave it playing where nothing shows or stops it. Given up after
  /// [voiceSequenceStartGrace], as a sequence is.
  final voiceStarting = ValueNotifier<bool>(false);
  Timer? _voiceStartTimer;

  void _awaitVoiceStart() {
    _voiceStartTimer?.cancel();
    _voiceStartTimer = Timer(voiceSequenceStartGrace, _voiceStarted);
    voiceStarting.value = true;
  }

  void _voiceStarted() {
    _voiceStartTimer?.cancel();
    _voiceStartTimer = null;
    voiceStarting.value = false;
  }

  void cancelVoiceSequence() {
    _voiceSequence.clear();
    _voiceQueueChanged();
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
    _voiceQueueChanged();
    _awaitSequenceStart();
    playVoiceMemory(next, repeat: false);
  }

  void stopVoice() {
    // A stop is a stop, the same as [stopCw]'s.
    chain.cancel();
    _dropWaiting((send) => send.memory != null);
    _stopVoice();
  }

  /// [stopVoice] without ending the repeat chain — see [interrupt].
  void _stopVoice() {
    cancelVoiceSequence();
    _voiceStarted();
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
    final session = _voiceKeyer ?? _recorder;
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

  /// Whether what the strip is showing came off the WIRE. The pick moving, or
  /// the peer leaving, may only clear what that peer was filling: a local
  /// keyer's message blanked under the operator is a transmitter still keying
  /// with nothing left to stop it, and a peer's activity left standing keeps
  /// Escape claimed for the rest of the session
  /// (docs/design/logging-fields.md).
  bool _cwFromPeer = false;
  bool _voiceFromPeer = false;

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
    if (uuid != station.localKeyingRadio) return;
    _voiceFromPeer = false;
    final ending = voiceActivity.value;
    voiceActivity.value = activity;
    // After the activity is in place, so keying never reads idle between.
    if (activity != null) _voiceStarted();
    // These same reports time the play: a doubtful one is the radio never
    // confirming, and the end is what the clock stops at. Only around the
    // timing — a computer recording is not timed, and its end must still
    // start the repeat below.
    if (_playMemory != null) {
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
    }
    // The memory ending is where a voice repeat's wait begins — the
    // counterpart of cwProgress going null for a message. One that ends
    // doubtful was refused or failed: repeated, it would only fail again,
    // and a computer keyer keys the radio for its lead each time.
    if (activity == null && chain.memory != null) {
      if (ending?.doubtful ?? false) {
        chain.cancel();
      } else {
        chain.startWait();
      }
    }
  }

  /// A node's link went down, or the key in use moved off it: whatever it was
  /// keying is not keying now.
  void forgetNode(String uuid) {
    if (uuid == station.keyInUse) cwProgress.value = null;
    if (uuid == station.localKeyingRadio) {
      // The silence is the radio going, not a memory ending.
      cancelVoiceSequence();
      _voiceStarted();
      voiceActivity.value = null;
    }
    // The session is closing, and its own teardown unkeys the radio.
    _dropComputerKeyer(uuid, sessionClosing: true);
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
        final voice = voiceKeyerFor(node.uuid);
        if (voice != null && _voiceActivityByNode.containsKey(node.uuid)) {
          if (node.uuid == station.localKeyingRadio) {
            if (chain.memory != null) chain.cancel();
            cancelVoiceSequence();
            // Cut short, so not a measurement — [stopVoice]'s rule.
            _playMemory = null;
            _playStart = null;
            _playDoubted = false;
          }
          voice.stopVoice();
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
    _voiceStartTimer?.cancel();
    voiceStarting.dispose();
    voiceQueue.dispose();
    waiting.dispose();
    _keyingRevision.dispose();
    cwProgress.dispose();
    cwStops.dispose();
    voiceActivity.dispose();
    enterSends.dispose();
    keyerOpenRequests.dispose();
    keyboardModeRequests.dispose();
  }
}

/// A send SO2R holds for the other radio ([CatKeying.waiting]): a CW
/// message's text or a memory's number, and whether a repeat chain sent it.
class WaitingSend {
  WaitingSend._(this.sequence, {this.text, this.memory, this.then = const [], required this.repeat, required this.messageOne, required this.send});

  /// When it was held, across both keyers — the oldest goes first.
  final int sequence;
  final String? text;
  final int? memory;

  /// The memories that follow [memory] in the same turn, under its key.
  final List<int> then;
  final bool repeat;

  /// Whether it is message 1 — what a callsign entered over it stops
  /// ([CatKeying.stopMessageOne]).
  final bool messageOne;

  /// Sends it, once the other radio is quiet.
  final void Function() send;
}
