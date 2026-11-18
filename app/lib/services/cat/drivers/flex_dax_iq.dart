// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio connection's DAX IQ streams — docs/design/cat.md § Spectrum.
//
// One stream a pan, however many of the connection's scopes draw it: two of
// HaLo's slices on one pan share it. Each stream draws on the radio's DAX IQ
// budget (16 units, a 192 kHz stream 8: RadioRoom, 4.3.16), and the channel
// HaLo gave a pan is the pan's until the last scope drawing it is gone.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:halo_i18n/halo_i18n.dart';

/// The radio's four DAX IQ channels.
const flexDaxIqChannels = [1, 2, 3, 4];

/// A scope drawing a pan's IQ ([FlexDaxIq.join]).
abstract interface class FlexDaxIqUser {
  /// The rate the samples after it are at: said when the scope joins, when
  /// the stream's status changes it, and when a new stream starts, whose
  /// samples do not continue the last one's.
  void iqRate(int rate);

  /// Interleaved I/Q pairs.
  void iqSamples(Float32List interleaved);

  /// Why the pan's IQ cannot arrive, in words for the operator; null once it can.
  void iqProblem(String? message);
}

class FlexDaxIq {
  /// Sends a command; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;

  /// The connection's record of its pans, which the connection alone merges
  /// the radio's statuses into: what channel each pan has.
  final Map<String, Map<String, String>> _pans;

  FlexDaxIq({required this.send, required this._pans});

  final _streams = <String, _PanIq>{};

  /// The rate each scope's displays asked for, kept across the scope's pans
  /// until it stops: a slice moved to another pan keeps the width asked of
  /// it. A pan's stream runs at the widest its scopes ask.
  final _asks = <FlexDaxIqUser, int>{};

  /// `sub pan all` asked, and answered: the radio describes every pan before
  /// it answers. A free channel is chosen only after, or it may be one a pan
  /// not described yet has.
  bool _subscribed = false, _described = false;

  /// What the radio said about streams before we knew one was ours: it
  /// pushes a new stream's status ahead of the `stream create` reply
  /// (captured on a FLEX-6600), and that status is the only word on its rate.
  final _unclaimed = <String, Map<String, String>>{};

  static const _firstPacketDeadline = Duration(seconds: 5);

  /// After the session's handshake, with a display open: the radio refuses a
  /// `sub` before it.
  void subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    send(
      'sub pan all',
      onReply: (_, _) {
        _described = true;
        for (final pan in _streams.keys.toList()) {
          settle(pan);
        }
      },
    );
  }

  /// [user] draws [pan]'s IQ from now on. A display that joins is a reason to
  /// ask again for a stream the radio refused.
  void join(String pan, FlexDaxIqUser user) {
    final iq = _streams[pan] ??= _PanIq();
    iq.users.add(user);
    iq.refused = false;
    user.iqRate(iq.rate);
    // Said even when there is none: a scope coming from another pan may still show that pan's.
    user.iqProblem(iq.problem);
    if (iq.stream case final stream?) _askRate(iq, stream);
    settle(pan);
  }

  /// [user] draws nothing any more; [forget] its asked rate too, for a scope
  /// that stopped rather than one moving to another pan. The last to leave a
  /// pan hands back its stream, and the channel HaLo gave it.
  void leave(FlexDaxIqUser user, {bool forget = false}) {
    if (forget) _asks.remove(user);
    for (final MapEntry(key: pan, value: iq) in _streams.entries.toList()) {
      if (!iq.users.remove(user)) continue;
      if (iq.users.isEmpty) {
        _release(pan, iq);
        _streams.remove(pan);
      } else if (iq.stream case final stream?) {
        _askRate(iq, stream);
      }
    }
  }

  /// The rate [user]'s displays ask for.
  void ask(FlexDaxIqUser user, int rate) {
    _asks[user] = rate;
    for (final iq in _streams.values) {
      if (iq.users.contains(user) && iq.stream != null) _askRate(iq, iq.stream!, always: true);
    }
  }

  int? _wanted(_PanIq iq) => iq.users.map((user) => _asks[user]).nonNulls.fold<int?>(null, (a, b) => a == null ? b : math.max(a, b));

  /// The widest rate [iq]'s scopes ask for, sent when it changes, or [always]
  /// for a display's own ask.
  void _askRate(_PanIq iq, String stream, {bool always = false}) {
    final rate = _wanted(iq);
    if (rate == null || (!always && rate == iq.asked)) return;
    iq.asked = rate;
    send(
      'stream set 0x$stream daxiq_rate=$rate',
      onReply: (code, _) {
        // A refusal is the rate's only for the stream still running: one for
        // a stream since removed says nothing about the rate asked of the next.
        if (code == 0 || iq.stream != stream) return;
        _asks.removeWhere((user, asked) => asked == rate && iq.users.contains(user));
        if (iq.asked == rate) iq.asked = null;
        // The narrower rate the pan's other scopes ask, which the refused one stood in for.
        _askRate(iq, stream);
      },
    );
  }

  /// Creates [pan]'s stream once everything it needs is known: what the pan
  /// says, a channel, and the scopes to draw it.
  void settle(String pan) {
    final iq = _streams[pan];
    if (iq == null || iq.stream != null || iq.creating || iq.refused) return;
    final status = _pans[pan];
    if (status == null) return;
    var channel = int.tryParse(status['daxiq_channel'] ?? '') ?? 0;
    if (channel == 0) {
      if (!_described) return;
      final taken = {for (final p in _pans.values) int.tryParse(p['daxiq_channel'] ?? '') ?? 0};
      final free = flexDaxIqChannels.where((c) => !taken.contains(c));
      if (free.isEmpty) return _say(iq, t.settings.station.spectrumNoDaxChannel);
      channel = free.first;
      iq.assigned = channel;
      // Taken at once for every other pan: no status tells this client, and
      // another choosing meanwhile would choose the same one.
      status['daxiq_channel'] = '$channel';
      final epoch = iq.epoch;
      send(
        'display pan set $pan daxiq_channel=$channel',
        onReply: (code, _) {
          // Recorded again once taken: a status already on its way names the
          // pan as it was, and would leave the channel reading as free.
          if (code == 0 && epoch == iq.epoch) _pans[pan]?['daxiq_channel'] = '$channel';
          if (code != 0 && _pans[pan]?['daxiq_channel'] == '$channel') _pans[pan]!['daxiq_channel'] = '0';
          if (code == 0 || epoch != iq.epoch || _streams[pan] != iq) return;
          // Not ours to give back, and the stream asked for beside it would
          // be on a channel no pan feeds.
          iq.assigned = null;
          _release(pan, iq);
          iq.refused = true;
          _say(iq, t.settings.station.spectrumStreamRefused(code: code.toRadixString(16).toUpperCase()));
        },
      );
    }
    _say(iq, null);
    iq.creating = true;
    final epoch = iq.epoch;
    send(
      'stream create type=dax_iq daxiq_channel=$channel',
      onReply: (code, body) {
        final stream = body.replaceFirst('0x', '').toLowerCase();
        if (epoch != iq.epoch || _streams[pan] != iq) {
          if (code == 0 && stream.isNotEmpty) send('stream remove 0x$stream');
          return;
        }
        iq.creating = false;
        final early = _unclaimed.remove(stream);
        if (!_streams.values.any((other) => other.creating)) _unclaimed.clear();
        if (code != 0 || stream.isEmpty) {
          // Refused: the channel goes back now, and the operator is told,
          // rather than a display that waits for IQ that is not coming.
          if (iq.assigned != null) _handBack(pan);
          iq.assigned = null;
          iq.refused = true;
          _say(iq, t.settings.station.spectrumStreamRefused(code: code.toRadixString(16).toUpperCase()));
          return;
        }
        iq.stream = stream;
        iq.streamId = int.tryParse(stream, radix: 16);
        iq.heard = false;
        iq.watchdog?.cancel();
        iq.watchdog = Timer(_firstPacketDeadline, () {
          if (_streams[pan] == iq && iq.stream == stream && !iq.heard) _say(iq, t.settings.station.spectrumNoUdp);
        });
        for (final user in iq.users.toList()) {
          user.iqRate(iq.rate);
        }
        if (early != null) _applyStream(iq, early);
        // Only the new stream's own status says its rate: until it does, the
        // rate known is the last stream's.
        iq.asked = int.tryParse(early?['daxiq_rate'] ?? '');
        _askRate(iq, stream);
      },
    );
  }

  /// `stream 0x20000000 type=dax_iq daxiq_channel=1 pan=0x40000000 daxiq_rate=48000 payload_endian=little`
  void streamStatus(String id, Map<String, String> fields) {
    final key = id.replaceFirst('0x', '').toLowerCase();
    for (final MapEntry(key: pan, value: iq) in _streams.entries.toList()) {
      if (iq.stream != key) continue;
      if (fields.containsKey('removed')) {
        _release(pan, iq, removed: true);
        settle(pan);
      } else {
        _applyStream(iq, fields);
      }
      return;
    }
    if (!_streams.values.any((iq) => iq.creating)) return;
    if (_unclaimed.length >= 8 && !_unclaimed.containsKey(key)) _unclaimed.remove(_unclaimed.keys.first);
    (_unclaimed[key] ??= {}).addAll(fields);
  }

  void _applyStream(_PanIq iq, Map<String, String> fields) {
    if (int.tryParse(fields['daxiq_rate'] ?? '') case final rate? when rate != iq.rate) {
      iq.rate = rate;
      for (final user in iq.users.toList()) {
        user.iqRate(rate);
      }
    }
    if (fields['payload_endian'] case final endian?) iq.littleEndian = endian != 'big';
  }

  /// One UDP datagram; whether it was one of these streams', so the meter
  /// codec does not parse it as well.
  bool packet(Uint8List data) {
    if (data.length < 28) return false;
    final bytes = ByteData.sublistView(data);
    final header = bytes.getUint32(0);
    // IF data with a stream id and a class id: the shape of a DAX IQ packet.
    if (header >> 28 != 1 || header & 0x08000000 == 0) return false;
    final classCode = bytes.getUint16(14);
    if (classCode < 0x02E3 || classCode > 0x02E6) return false;
    final id = bytes.getUint32(4);
    final iq = _streams.values.where((iq) => iq.streamId == id).firstOrNull;
    if (iq == null) return false;
    // The first packet ends the wait, and any word that it was not coming:
    // IQ that arrives late still arrives.
    if (!iq.heard) {
      iq.heard = true;
      iq.watchdog?.cancel();
      iq.watchdog = null;
      _say(iq, null);
    }
    var offset = 16;
    if ((header >> 22) & 3 != 0) offset += 4;
    if ((header >> 20) & 3 != 0) offset += 8;
    final end = math.min(data.length, (header & 0xffff) * 4) - (header & 0x04000000 != 0 ? 4 : 0);
    if (end <= offset) return true;
    final count = (end - offset) ~/ 4;
    final samples = Float32List(count);
    final endian = iq.littleEndian ? Endian.little : Endian.big;
    for (var i = 0; i < count; i++) {
      final sample = bytes.getFloat32(offset + i * 4, endian);
      // One NaN would ride the noise average forever and blank the display.
      samples[i] = sample.isFinite ? sample : 0;
    }
    for (final user in iq.users.toList()) {
      user.iqSamples(samples);
    }
    return true;
  }

  void _say(_PanIq iq, String? problem) {
    iq.problem = problem;
    for (final user in iq.users.toList()) {
      user.iqProblem(problem);
    }
  }

  /// [pan]'s channel, given back in the record too: no status tells this
  /// client, and every other pan's scopes would count it taken.
  void _handBack(String pan) {
    send('display pan set $pan daxiq_channel=0');
    _pans[pan]?['daxiq_channel'] = '0';
  }

  /// Hands back what [settle] took, in reverse: a stream the radio [removed]
  /// itself is not asked removed again, and its channel is the pan's still.
  void _release(String pan, _PanIq iq, {bool removed = false}) {
    iq.watchdog?.cancel();
    iq.watchdog = null;
    iq.epoch++;
    iq.creating = false;
    iq.streamId = null;
    iq.asked = null;
    // Kept, a status for a stream id the radio hands out again would be taken for the new one's.
    if (!_streams.values.any((other) => other.creating)) _unclaimed.clear();
    if (!removed) {
      if (iq.stream case final stream?) send('stream remove 0x$stream');
      if (iq.assigned != null) _handBack(pan);
      iq.assigned = null;
    }
    iq.stream = null;
  }
}

/// One pan's IQ, as this connection draws it.
class _PanIq {
  final users = <FlexDaxIqUser>{};

  /// The channel HaLo gave the pan, to hand back once no scope draws it —
  /// null when the pan already had one, which is then another client's.
  int? assigned;
  bool creating = false;
  String? stream;

  /// [stream] as the number a packet carries: compared as text, an id with
  /// a leading zero would never match.
  int? streamId;

  /// Bumped by every release: a reply that arrives after it is for a stream,
  /// or a channel, that is gone, and is handed straight back rather than
  /// adopted on a channel already given up.
  int epoch = 0;

  /// The radio refused the stream or its channel. Not asked again until a
  /// display joins: pan statuses arrive several times a second, and each one
  /// would otherwise ask again.
  bool refused = false;

  /// The rate last asked of [stream], to send only a change.
  int? asked;
  int rate = 48000;
  bool littleEndian = true;

  /// Runs from the stream's grant to its first packet. A granted stream
  /// whose IQ never arrives — a firewall, a network permission — is
  /// otherwise a display that waits forever.
  Timer? watchdog;
  bool heard = false;

  /// What the users were last told, for one that joins after.
  String? problem;
}
