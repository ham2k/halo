// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The operator's voice from the station's microphone to a FlexRadio's
// transmitter, through the audio engine — docs/design/audio.md § 5.
//
// The stream is the voice keyer's (flex_dax_tx.dart, captured on a
// FLEX-6600 4.2.20): a bound client's `stream create type=dax_tx` answers
// with a stream it owns, `stream set <id> tx=1` makes it the radio's DAX
// transmit source, and with DAX on the radio puts on the air what arrives
// at UDP 4991 as VITA type 1. Here the engine's own sender sends it, from
// the engine's socket (halo_audio_net.c), and its gate is the transmit
// gate: open only while the operator holds the key.

import 'dart:async';

import 'package:halo_audio/halo_audio.dart' show AudioEndpoint, AudioSocket, HaloAudioException;
import 'package:halo_i18n/halo_i18n.dart';

import '../driver.dart' show TalkAudioLink, TalkRoute;
import 'flex_dax_tx.dart' show flexDaxPort;

/// How long silence goes on after the gate shuts and the unkey goes out: a
/// FlexRadio on DAX transmits noise when nothing arrives, and it is still
/// on the air until the unkey reaches it.
const flexTalkTail = Duration(milliseconds: 150);

/// How long the microphone's route outlives the gate: the gate's 5 ms ramp
/// down is made of what the route still carries, and cut with it the voice
/// ends in a click on the air.
const _routeAfterGate = Duration(milliseconds: 20);

class FlexDaxTalk {
  FlexDaxTalk({required this.link, required this.host, required this.send, required this.diagnose, this.problem, this.onAirRefused, this.port = flexDaxPort});

  final TalkAudioLink link;

  /// The radio's address, numeric, which the engine sends the stream to.
  final String host;
  final int port;

  /// A command to the radio; [onReply] gets the answer's code and body.
  final void Function(String command, {void Function(int code, String body)? onReply}) send;

  /// Why the operator's voice does not go, for the CAT recording.
  final void Function(String what) diagnose;

  /// Why it does not go, for the operator, on the radio's row; null once
  /// it does.
  final void Function(String? why)? problem;

  /// The radio refused the stream as its transmit source after the key:
  /// keyed on DAX with nothing of HaLo's arriving it transmits noise, so
  /// the key comes off.
  final void Function()? onAirRefused;

  void _why(String why) {
    diagnose(why);
    problem?.call(why);
  }

  int? _streamId;
  AudioEndpoint? _endpoint;
  TalkRoute? _route;

  /// The last over's route, through the gate's ramp down.
  TalkRoute? _ending;
  Timer? _tail;
  bool _pending = false;
  bool _stopped = false;
  bool _gaveUp = false;

  /// Whether a key can carry the operator's voice now: the radio has
  /// granted the stream.
  bool get ready => _endpoint != null;

  /// Called whenever something it waits on changes: the engine's [socket]
  /// (null for one the engine does not own), and whether the session has
  /// [bound] to the GUI client — a stream made unbound would be a transmit
  /// object of the client's own, not the operator's radio's.
  void update({required AudioSocket? socket, required bool bound}) {
    if (_stopped || _gaveUp || _pending || _streamId != null || socket == null || !bound) return;
    _pending = true;
    send(
      'stream create type=dax_tx',
      onReply: (code, body) {
        _pending = false;
        final id = int.tryParse(body.trim().replaceFirst('0x', ''), radix: 16);
        if (_stopped) {
          if (code == 0 && id != null) send('stream remove ${_hex(id)}');
          return;
        }
        if (code != 0 || id == null) {
          _gaveUp = true;
          diagnose('stream create type=dax_tx refused: ${code.toRadixString(16).padLeft(8, '0')} ${body.trim()}'.trim());
          problem?.call(t.settings.station.audioProblemTalkStream);
          return;
        }
        _streamId = id;
        try {
          _endpoint = link.engine.addFlexDaxTx(socket, host: host, port: port, streamId: id);
          problem?.call(null);
        } on HaloAudioException catch (e) {
          // Held on the radio with nothing to send on it, every key would
          // say the stream was not granted.
          diagnose('the engine would not take the stream: ${e.message}');
          problem?.call(t.settings.station.audioProblemEngine);
          send('stream remove ${_hex(id)}');
          _streamId = null;
          _gaveUp = true;
        }
      },
    );
  }

  /// Ahead of the key: the stream claimed as the radio's DAX source — again
  /// for each over, since another client may have claimed its own since —
  /// silence flowing, and the microphone routed in with the gate open.
  /// False, with nothing changed on the radio, when the stream is not
  /// granted or the microphone will not open.
  bool key() {
    final endpoint = _endpoint;
    final id = _streamId;
    if (endpoint == null || id == null) {
      diagnose('the operator keyed before the radio granted the DAX transmit stream');
      if (!_gaveUp) problem?.call(t.settings.station.audioProblemTalkNotReady);
      return false;
    }
    _tail?.cancel();
    _ending?.close();
    _ending = null;
    _route?.close();
    _route = link.speak(endpoint, why: _why);
    if (_route == null) {
      // The last over's tail, cancelled above, is what stops its silence:
      // left sending, the radio gets silence until the slice goes.
      try {
        endpoint.sending = false;
      } on StateError {
        // Closed already: nothing is sending.
      }
      return false;
    }
    send(
      'stream set ${_hex(id)} tx=1',
      onReply: (code, body) {
        if (code == 0) return;
        diagnose('stream set tx=1 refused: ${code.toRadixString(16).padLeft(8, '0')} ${body.trim()}'.trim());
        problem?.call(t.settings.station.audioProblemTalkStream);
        onAirRefused?.call();
      },
    );
    try {
      endpoint.sending = true;
      endpoint.gate = true;
    } on StateError {
      // The endpoint closed under it: the microphone open with nowhere to
      // go is one the system shows listening.
      _route?.close();
      _route = null;
      problem?.call(t.settings.station.audioProblemEngine);
      return false;
    }
    problem?.call(null);
    return true;
  }

  /// After the unkey has gone: the gate shut at once, the microphone a
  /// moment later, and silence until the radio is off the air.
  void unkey() {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    endpoint.gate = false;
    _ending ??= _route;
    _route = null;
    _tail?.cancel();
    _tail = Timer(_routeAfterGate, () {
      _ending?.close();
      _ending = null;
      _tail = Timer(flexTalkTail - _routeAfterGate, () {
        if (!_stopped) endpoint.sending = false;
      });
    });
  }

  /// Ends the stream and the microphone. Safe to call more than once.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    _tail?.cancel();
    _ending?.close();
    _ending = null;
    _route?.close();
    _route = null;
    _endpoint?.close();
    _endpoint = null;
    if (_streamId case final id?) send('stream remove ${_hex(id)}');
    _streamId = null;
  }

  static String _hex(int id) => '0x${id.toRadixString(16).padLeft(8, '0')}';
}
