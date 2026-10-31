// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Keying a radio that is on another device (HALO-585) — the controller half,
// and the translation both halves share.
//
// `CatService` keeps the whole keying API it always had: the function keys,
// the keyer area, the WPM command and both message dialogs read `canKeyCw`,
// `sendCw`, `cwProgress`, `canPlayVoice`, `playVoiceMemory` and the rest and
// never learn whether the rig answering is plugged in here. What lives in
// this file is everything that is only true of a rig that is NOT: what the
// far station said it can be asked to do, what it last reported it was
// doing, and how a request reaches it.
//
// Which side of the link a message is keyed on is settled entirely by
// `CatService`; this holds no policy about it. In particular the far
// station's own key in use is what keys there — so a request names a radio,
// and what that station keys with is its business (docs/design/cat.md
// § Keying a peer's radio).

import 'package:halo_core/halo_core.dart';

import 'driver.dart' show VoiceActivity, maxVoiceMemories;
import 'drivers/cw_send_queue.dart';

/// The picked peer radio's keying, as far as this device knows it.
///
/// Every getter answers "nothing" when no peer radio is picked or that peer
/// is away, which is what makes the surfaces go quiet rather than address a
/// device that is not there. Not a [ChangeNotifier]: `CatService` owns when
/// its own listeners hear about any of this.
class PeerKeying {
  /// What the last offer naming the picked radio said it can be asked to do.
  PeerRadioOffer? offer;

  /// What it last reported it was keying. The message and the memory are
  /// handed straight to `CatService`'s own notifiers as they arrive; what is
  /// read back from here is what the surfaces ask for by other names — the
  /// speed, the memory labels and their measured lengths.
  PeerKeyStatusPayload? status;

  /// Where a request goes. Set by the peer router while it is up; null on a
  /// build with peer sharing off, which is what makes a peer radio unkeyable
  /// there rather than swallowing messages that reach nothing.
  void Function(PeerKeyRequestPayload request)? send;

  /// What each of the PEERS' radios last offered and last reported, keyed
  /// `deviceId/radioId` — including the radios nobody picked.
  ///
  /// Both are sent when the far station CHANGES, and picking a radio is not
  /// the far station changing: without these, choosing one on a pair that is
  /// already up leaves it unkeyable, its speed unknown and its memories
  /// unnamed until that station happens to key something. The local path has
  /// no such gap, and neither does tuning — `PeerChannels._peerVfos` closes
  /// exactly this hole for `catStatus`.
  final Map<String, PeerRadioOffer> _offers = {};
  final Map<String, PeerKeyStatusPayload> _statuses = {};

  static String _key(String deviceId, String radioId) => '$deviceId/$radioId';

  /// The whole of a device's offer replaces what it last said, absences
  /// included: an offer that stops naming a radio is how a station says that
  /// rig went away — and the radio's STATUS goes with it, or a rig that drops
  /// mid-message and comes back is re-adopted still keying it.
  void rememberOffers(String deviceId, List<PeerRadioOffer> radios) {
    final prefix = '$deviceId/';
    _offers.removeWhere((key, _) => key.startsWith(prefix));
    for (final radio in radios) {
      _offers[_key(deviceId, radio.id)] = radio;
    }
    _statuses.removeWhere((key, _) => key.startsWith(prefix) && !_offers.containsKey(key));
  }

  void rememberStatus(String deviceId, PeerKeyStatusPayload status) => _statuses[_key(deviceId, status.radioId)] = status;

  /// That peer is out of reach — everything it said goes with it.
  void forgetDevice(String deviceId) {
    final prefix = '$deviceId/';
    _offers.removeWhere((key, _) => key.startsWith(prefix));
    _statuses.removeWhere((key, _) => key.startsWith(prefix));
  }

  PeerRadioOffer? offerFor(String? deviceId, String? radioId) => deviceId == null || radioId == null ? null : _offers[_key(deviceId, radioId)];

  PeerKeyStatusPayload? statusFor(String? deviceId, String? radioId) => deviceId == null || radioId == null ? null : _statuses[_key(deviceId, radioId)];

  /// Whether the far station said it will key CW on that radio at all. Not
  /// on its own an answer about where a message goes — a key of this
  /// operator's own, pointed at this radio, outranks it.
  bool get keysCw => offer?.keysCw ?? false;

  /// Whether the memories in play are that radio's. No designation stands
  /// between: the audio is in the rig filling radio1, here or there.
  bool get playsVoice => voiceMemories > 0;

  /// Clamped to the memories any surface can draw: the buttons and the rows
  /// index eight icons, and a peer reporting more — a rig this build has not
  /// met, or a garbled message — would throw inside build rather than show
  /// what it can.
  int get voiceMemories => (offer?.voiceMemories ?? 0).clamp(0, maxVoiceMemories);

  bool get recordsVoice => offer?.recordsVoice ?? false;

  /// The speed as the FAR keyer answered — never a value this side chose, so
  /// what the pill shows is what that radio took, clamping and rounding
  /// included.
  int? get keyerSpeed => status?.keyerSpeedWpm;

  /// The speeds that keyer accepts, for a picker to offer exactly those.
  ({int min, int max})? get keyerSpeedRange {
    final min = status?.keyerSpeedMin;
    final max = status?.keyerSpeedMax;
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  /// What the OWNER calls memory [n], and how long it measured there. Both
  /// belong to the device the audio is in: a label from here would name
  /// somebody else's recording, and a duration from here would pace a bar
  /// against one this station has never played.
  String voiceMessageLabel(int n) {
    final labels = status?.voiceLabels ?? const [];
    return n >= 1 && n <= labels.length ? labels[n - 1] : '';
  }

  int voiceMessageDuration(int n) {
    final durations = status?.voiceDurationsMs ?? const [];
    return n >= 1 && n <= durations.length ? durations[n - 1] : 0;
  }

  /// The message going out over there, in the shape the strip already paces:
  /// the far side's own arithmetic, relayed rather than recomputed, because
  /// that is what its queue is actually waiting on.
  CwSendProgress? get progress => cwProgressFromWire(status?.cw);

  VoiceActivity? get activity => voiceActivityFromWire(status?.voice);

  /// Forgets the far side entirely, answering whether there was anything to
  /// forget — the peer left, or the pick moved off it.
  bool clear() {
    if (offer == null && status == null) return false;
    offer = null;
    status = null;
    return true;
  }

  /// Asks for [op] on [radioId]. Silent when nothing is picked or no bridge
  /// is up: the same no-op every keying surface takes when the radio drops
  /// between the check and the keypress.
  /// Answers whether anything was sent, which is what a caller arming a
  /// repeat on it needs to know.
  bool request(String? radioId, String op, {String text = '', int? wpm, int? memory, int? queuedId}) {
    final send = this.send;
    if (radioId == null || send == null) return false;
    send(PeerKeyRequestPayload(radioId: radioId, op: op, text: text, wpm: wpm, memory: memory, queuedId: queuedId));
    return true;
  }
}

/// A message going out, for the wire. Durations become whole milliseconds:
/// the strip paces to the frame, and a microsecond it cannot draw is not
/// worth a digit in every character of every message.
PeerCwProgressPayload? cwProgressToWire(CwSendProgress? progress) {
  if (progress == null) return null;
  return PeerCwProgressPayload(
    id: progress.id,
    text: progress.text,
    characterEndsMs: [for (final end in progress.characterEnds) end.inMilliseconds],
    pending: progress.pending,
    pendingIds: progress.pendingIds,
    sentCount: progress.sentCount,
  );
}

/// The far side's message, for this device's own strip. The id is kept as
/// sent, which is what tells a re-report from a fresh start — the queue
/// behind a message changes while the message itself does not.
CwSendProgress? cwProgressFromWire(PeerCwProgressPayload? progress) {
  if (progress == null) return null;
  return CwSendProgress(
    id: progress.id,
    text: progress.text,
    characterEnds: [for (final ms in progress.characterEndsMs) Duration(milliseconds: ms)],
    pending: progress.pending,
    pendingIds: progress.pendingIds,
    sentCount: progress.sentCount,
  );
}

PeerVoiceActivityPayload? voiceActivityToWire(VoiceActivity? activity) {
  if (activity == null) return null;
  return PeerVoiceActivityPayload(
    memory: activity.memory,
    recording: activity.recording,
    // Carried as doubt rather than resolved: the controller shows the same
    // question mark the owner's strip does, and it is the owner's polls that
    // will withdraw it.
    doubtful: activity.doubtful,
    lengthMs: activity.lengthMs,
  );
}

VoiceActivity? voiceActivityFromWire(PeerVoiceActivityPayload? activity) {
  if (activity == null) return null;
  return VoiceActivity(memory: activity.memory, recording: activity.recording, doubtful: activity.doubtful, lengthMs: activity.lengthMs);
}
