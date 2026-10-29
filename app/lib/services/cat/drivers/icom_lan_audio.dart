// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// An Icom's transmit audio over its network link, sent by this app itself —
// docs/design/cat.md § The computer's voice keyer. The recording goes on the
// connection's audio stream as 16-bit mono PCM at 48 kHz, the format the
// stream request asks for, and the radio transmits it only while its DATA
// OFF MOD source is LAN (WLAN on the IC-705), which [IcomLanModSwitch] sets
// for each message and puts back after.
//
// Not yet met on hardware: the packet layout and each model's menu item are
// from wfview's source (icom_network_protocol.dart says how), and nothing
// here has keyed a radio.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../error_reporting_service.dart';
import '../transport.dart' show TransmitAudioLink, TransmitAudioUnavailable;
import '../transports/icom_network_protocol.dart' show icomAudioMaxBytes, icomAudioSampleRate;
import 'civ_codec.dart';
import 'paced_transmit_audio.dart';

/// Where a model keeps its DATA OFF MOD setting and which of its values is
/// LAN: `[item high, item low, LAN value]`, the bytes after `0x1A 0x05` —
/// `[0x01, 0x18, 3]` on the IC-705. Pinned on a network variant only: over a
/// serial port there is no LAN audio to switch to.
const civLanModConfigKey = 'civLanMod';

/// Ten milliseconds a packet: 960 bytes, inside [icomAudioMaxBytes].
const _framesPerPacket = 480;

class IcomLanAudioOutput extends PacedTransmitAudio {
  IcomLanAudioOutput({required Future<TransmitAudioLink> link, required super.decode, this.diagnose, super.clockMicros})
    : assert(_framesPerPacket * 2 <= icomAudioMaxBytes),
      super(rate: icomAudioSampleRate, channels: 1, framesPerPacket: _framesPerPacket) {
    unawaited(
      link.then(
        (link) {
          if (closed) return;
          _link = link;
          unawaited(link.gone.then((_) => lost()));
        },
        onError: (Object e) {
          if (closed) return;
          diagnose?.call('the radio did not open its audio stream: ${e is TransmitAudioUnavailable ? e.reason : e.runtimeType}');
          lost();
        },
      ),
    );
  }

  /// Why the radio would not take the audio, for the CAT recording.
  final void Function(String what)? diagnose;

  TransmitAudioLink? _link;

  @override
  bool get ready => _link != null;

  @override
  String get reportContext => 'icom:lan-audio';

  @override
  void sendFrames(Float32List? samples) {
    final pcm = ByteData(_framesPerPacket * 2);
    if (samples != null) {
      for (var i = 0; i < samples.length; i++) {
        final sample = samples[i];
        // A NaN would throw from round() inside the pacing timer, every tick.
        if (sample.isNaN) continue;
        pcm.setInt16(i * 2, (sample.clamp(-1.0, 1.0) * 32767).round(), Endian.little);
      }
    }
    _link!.send(pcm.buffer.asUint8List());
  }
}

/// DATA OFF MOD set to LAN for a message and put back after — with any
/// other source the radio transmits that, its mic most often, and drops the
/// network audio; left on LAN after the message, the operator's mic is dead.
class IcomLanModSwitch {
  IcomLanModSwitch({
    required this.item,
    required this.lan,
    required this.to,
    required this.from,
    required this.send,
    required this.diagnose,
    required this.refused,
    this.host,
  }) : _earlier = host == null ? null : _owedByHost[host];

  /// [civLanModConfigKey]'s value, or null when it does not describe one.
  static IcomLanModSwitch? fromConfig(
    Object? raw, {
    required int to,
    required int from,
    required void Function(List<int> frame) send,
    required void Function(String what) diagnose,
    required void Function(int? source) refused,
    String? host,
  }) {
    if (raw is! List || raw.length != 3 || raw.any((b) => b is! int || b < 0 || b > 0x99)) return null;
    final bytes = raw.cast<int>();
    return IcomLanModSwitch(item: [bytes[0], bytes[1]], lan: bytes[2], to: to, from: from, send: send, diagnose: diagnose, refused: refused, host: host);
  }

  final List<int> item;
  final int lan;
  final int to;
  final int from;
  final void Function(List<int> frame) send;
  final void Function(String what) diagnose;

  /// The radio read something other than LAN just after the key, or refused
  /// the item outright (null): the set did not take, or the item is not this
  /// model's, and its mic is on the air under the recording.
  final void Function(int? source) refused;

  /// The radio's address, which a restore still owed is kept by; null when
  /// the session has none.
  final String? host;

  /// Sources this app set to LAN and has not seen put back, by the radio's
  /// address, for the whole launch: a link that drops mid-message hands the
  /// restore to the next session rather than leaving the mic dead for good.
  static final _owedByHost = <String, int>{};

  /// Forgets every restore owed: the tests' way to start each from a radio
  /// the app never keyed.
  @visibleForTesting
  static void forgetOwed() => _owedByHost.clear();

  /// A restore an earlier session owed this radio, not yet settled.
  int? _earlier;

  /// The source as the radio last answered; null before it has.
  int? _source;

  /// What to put back after the message, once this switch has set LAN.
  int? _owed;
  bool _switched = false;

  /// The read just after the key, which [heard] tells apart by its frame.
  List<int>? _verifying;

  /// A restore sent and not yet read back as taken, and how many times.
  bool _restoreSent = false;
  int _tries = 0;

  /// The next restore, after one read back as not taken: sent at once, it
  /// may land in the radio's own unkeying again.
  Timer? _retry;

  static const _maxTries = 3;
  static const _retryAfter = Duration(milliseconds: 500);

  /// Whether a restore is owed: what the session's unkey must not skip, even
  /// with its output gone.
  bool get owesRestore => _switched;

  /// The menu item's read frame, a new one each time.
  List<int> get readFrame => buildCivFrame(to: to, from: from, command: CivCommand.settings, data: [civSettingMenu, ...item]);

  List<int> _setFrame(int value) => buildCivFrame(to: to, from: from, command: CivCommand.settings, data: [civSettingMenu, ...item, value]);

  /// Whether [frame], a whole CI-V frame, reads or sets this item.
  bool owns(List<int> frame) => frame.length > 8 && frame[4] == CivCommand.settings && frame[5] == civSettingMenu && frame[6] == item[0] && frame[7] == item[1];

  /// Asks the radio for the source, so the key needs no question first.
  void read() => send(readFrame);

  /// Settles a restore an earlier session owed this radio: put back when the
  /// radio is still on LAN, forgotten when the operator has moved it since.
  void settle() {
    if (_earlier != null) read();
  }

  /// The frames to go out ahead of the key, in order: the LAN set, or none
  /// when the radio already takes LAN — the operator's own choice, left alone
  /// after. With the source still unknown the set goes behind a read, whose
  /// answer is what is put back.
  List<List<int>> beforeKey() {
    _retry?.cancel();
    _restoreSent = false;
    _tries = 0;
    if (_earlier case final earlier?) {
      // Put back after this message instead.
      _earlier = null;
      _switched = true;
      _owed = earlier;
    }
    if (_switched) return [_setFrame(lan)];
    if (_source == lan) return const [];
    _switched = true;
    _owed = _source;
    _remember();
    return [if (_source == null) readFrame, _setFrame(lan)];
  }

  /// The read to follow the key, checking the LAN set took.
  List<int> verifyFrame() => _verifying = readFrame;

  /// The radio refused [frame]: a read of this item or the LAN set is a
  /// model without the item, and refused for good. A refused restore is not:
  /// its read-back retries it.
  void nakked(List<int> frame) {
    if (!owns(frame)) return;
    final isRead = frame.length == readFrame.length;
    if (!isRead && frame[8] != lan) return;
    _verifying = null;
    // Nothing to put back that the radio would take.
    if (_owed == null) _switched = false;
    refused(null);
  }

  /// The source put back, after the unkey, and read to see it took.
  void afterUnkey() {
    if (!_switched) return;
    _restore();
  }

  /// A closing connection. Keyed, only the session's unkey goes: a radio
  /// keeps the last of two frames sent back to back, and a restore that took
  /// the unkey's place would leave it transmitting. The restore stays owed to
  /// the next session.
  void teardown(void Function(List<int> frame) direct, {required bool keyed}) {
    _retry?.cancel();
    final owed = _owed;
    if (!keyed && _switched && owed != null) direct(_setFrame(owed));
  }

  void _remember() {
    if (host case final at? when _owed != null) _owedByHost[at] = _owed!;
  }

  void _forget() {
    if (host case final at?) _owedByHost.remove(at);
  }

  void _restore() {
    final owed = _owed;
    if (owed == null) {
      // The source was never read: there is nothing known to put back.
      _switched = false;
      diagnose('DATA OFF MOD left on LAN: its setting before the message was never read');
      return;
    }
    if (_tries >= _maxTries) {
      _switched = false;
      _restoreSent = false;
      _forget();
      diagnose('DATA OFF MOD left on LAN after $_tries restores');
      ErrorReportingService.report(const IcomLanModLeftOn(), StackTrace.current, context: 'icom:lan-mod-restore');
      return;
    }
    _tries++;
    _restoreSent = true;
    send(_setFrame(owed));
    read();
  }

  /// A 0x1A answer's data, and the frame it answers; true when it was this
  /// item's.
  bool heard(List<int> data, {List<int>? answering}) {
    if (data.length != 4 || data[0] != civSettingMenu || data[1] != item[0] || data[2] != item[1]) return false;
    final value = data[3];
    _source = value;
    if (_earlier case final earlier? when !_switched) {
      _earlier = null;
      if (value == lan) {
        _switched = true;
        _owed = earlier;
        _restore();
      } else {
        _forget();
      }
      return true;
    }
    final verifying = identical(answering, _verifying);
    if (_switched && _owed == null && !verifying) {
      if (value == lan) {
        // Already LAN before the set: the operator's own choice.
        _switched = false;
      } else {
        _owed = value;
        _remember();
      }
    }
    if (verifying) {
      _verifying = null;
      if (value != lan) refused(value);
      return true;
    }
    if (_restoreSent) {
      if (value == _owed) {
        _switched = false;
        _restoreSent = false;
        _tries = 0;
        _forget();
      } else {
        _restoreSent = false;
        _retry?.cancel();
        _retry = Timer(_retryAfter, _restore);
      }
    }
    return true;
  }
}

/// The DATA OFF MOD source this app set to LAN for a message, still LAN after
/// every restore it sent: the radio transmits no mic until the operator sets
/// it back in the radio's menu.
class IcomLanModLeftOn implements Exception {
  const IcomLanModLeftOn();

  @override
  String toString() => 'IcomLanModLeftOn: DATA OFF MOD left on LAN after the restores sent did not take';
}

/// The LAN set refused just after the key — the model's item may not be the
/// one its entry pins — and the radio read [source] instead.
class IcomLanModRefused implements Exception {
  /// What it read instead; null for a radio that refused the item outright.
  final int? source;

  const IcomLanModRefused(this.source);

  @override
  String toString() => 'IcomLanModRefused: ${source == null ? 'DATA OFF MOD refused' : 'DATA OFF MOD read $source after the LAN set'}';
}
