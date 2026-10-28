// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The peer bridge as CatKeying runs it, both directions: what this station
// reports for a radio it offers, the requests a peer sends it, and pointing
// the strip at what the picked peer radio is doing (docs/design/cat.md
// § Keying a peer's radio). A part of cat_keying.dart, and an extension for
// the reason cat_keying_computer_voice.dart is one: the state it reads and
// writes is CatKeying's.

part of 'cat_keying.dart';

extension PeerKeyBridge on CatKeying {
  /// What this station is keying, for a peer that picked [radioId] — the
  /// offerer's half of the bridge. The caller has already checked that the
  /// radio is offered and that keying is switched on here.
  ///
  /// Everything in it is this station's OWN: publishing what it is itself
  /// following would be a relay by another name (see the header of cat_keying.dart).
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
}
