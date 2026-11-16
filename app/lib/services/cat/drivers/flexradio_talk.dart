// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio slice keyed for the operator's own voice from the station's
// microphone (docs/design/audio.md § 5): the DAX transmit stream
// (flex_dax_talk.dart) kept in step with the radio, and the key around it.

part of 'flexradio_driver.dart';

extension _Talk on FlexRadioSession {
  /// The engine's link, while the operator talks through HaLo on this radio.
  TalkAudioLink? get _talkAudio => switch (_sink) {
    final TalkAudioSink sink => sink.talkAudio,
    _ => null,
  };

  void _startTalk(TalkAudioLink? talk, FlexUdpSocket socket) {
    if (talk == null || socket.audioSocket == null) return;
    _talk = FlexDaxTalk(
      link: talk,
      host: socket.radioAddress,
      send: (command, {onReply}) => _radio._sendCommand(command, onReply: onReply),
      diagnose: (what) => _sink.reportDiagnostic('Flex talk: $what'),
      problem: (why) {
        _talkProblem = why;
        _reportAudioProblem();
      },
      // Through the app's key, which the operator's release goes through:
      // unkeyed behind it, the app would hold the key for its timeout and
      // the next press would key nothing.
      onAirRefused: () => switch (_sink) {
        final AudioProblemSink sink => sink.releaseKey(),
        _ => _setPttTalking(false),
      },
    );
    _updateAudioStreams();
  }

  /// DAX on, as for the voice keyer, with the microphone flowing ahead of
  /// the key; off, the gate shut ahead of the unkey. Nothing keyed where
  /// the slice cannot transmit, or the stream and the microphone are not
  /// both there: the radio's own mic is not what the operator speaks into.
  ///
  /// Asked of every slice the operator talks through HaLo on, ready or not
  /// ([talksThroughHalo]): one whose stream is not up yet refuses the key
  /// and says why, rather than keying the radio's own microphone.
  bool _setPttTalking(bool on) {
    final talk = _talk;
    if (!on) {
      talk?.unkey();
      setPttWithComputerAudio(false);
      return true;
    }
    if (talk == null) {
      _talkProblem = _socketProblem ?? t.settings.station.audioProblemTalkNotReady;
      _reportAudioProblem();
      return false;
    }
    if (cannotTransmit != null || !talk.key()) return false;
    setPttWithComputerAudio(true);
    return true;
  }
}
