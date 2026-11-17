// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A FlexRadio slice heard in HaLo (docs/design/audio.md § 6): the radio's
// UDP socket opened by the audio engine, since the slice's DAX audio
// arrives on it too ([FlexRadio._startMeters]), and the slice's dax_rx
// stream (flex_dax_rx.dart) kept in step with the radio.

part of 'flexradio_driver.dart';

extension _ReceiveAudio on FlexRadioSession {
  /// The engine's link, while the operator hears this slice in HaLo.
  RadioAudioLink? get _receiveAudio => switch (_sink) {
    final ReceiveAudioSink sink => sink.receiveAudio,
    _ => null,
  };

  /// This slice's audio streams on the radio's [socket], once it is open.
  void _startAudioStreams(FlexUdpSocket socket) {
    _startDaxRx(_receiveAudio, socket);
    _startTalk(_talkAudio, socket);
  }

  /// Withdrawn with the socket they ride on, or as this slice leaves.
  void _stopAudioStreams() {
    if (_radio._handshakeDone) _daxRx?.stop();
    _daxRx = null;
    if (_radio._handshakeDone) _talk?.stop();
    _talk = null;
  }

  /// Not before HaLo's own slice has a number on the radio: its stream is
  /// asked for once it has.
  void _startDaxRx(RadioAudioLink? audio, FlexUdpSocket socket) {
    if (audio == null || socket.audioSocket == null || slice < 0) return;
    _daxRx = FlexDaxReceive(
      link: audio,
      slice: slice,
      send: (command, {onReply}) => _radio._sendCommand(command, onReply: _echoingDax(command, onReply)),
      diagnose: (what) => _sink.reportDiagnostic('Flex DAX receive: $what'),
      problem: (why) {
        _rxProblem = why;
        _reportAudioProblem();
      },
    );
    _updateAudioStreams();
  }

  /// The slice's receive audio and the operator's transmit audio wait on
  /// the engine's socket and the bind to the GUI client — a stream is made
  /// bound, as the capture made it, since an unbound client is given a
  /// transmit object of its own and may be given streams the same way — and
  /// the receive audio on the slice's DAX channel. HaLo's own station is
  /// the GUI client, and binds to nobody.
  void _updateAudioStreams() {
    final socket = _radio._meterSocket;
    if (_daxRx == null && socket != null) _startDaxRx(_receiveAudio, socket);
    _talk?.update(socket: _radio._meterSocket?.audioSocket, bound: _bound);
    _updateDaxRx();
  }

  /// HaLo's own station binds to nobody; one the radio refused is no
  /// client to make a stream for.
  /// A slice another station holds is not: a DAX channel is the bound
  /// station's own, and its channel would carry that station's audio.
  bool get _bound => ((_radio.gui && !_radio._stationRefused) || _radio._boundClientId != null) && _radio._otherStation(this) == null;

  /// What keeps this slice's audio from going through this computer, as
  /// the operator sees it on the radio's row: the radio's socket first,
  /// then whichever way the audio goes wrong. Kept apart, so a microphone
  /// that works does not clear an output that does not.
  void _reportAudioProblem() {
    if (_sink case final AudioProblemSink sink) sink.reportAudioProblem(_socketProblem ?? _rxProblem ?? _talkProblem);
  }

  void _updateDaxRx() => _daxRx?.update(
    socket: _radio._meterSocket?.audioSocket,
    bound: _bound,
    daxChannel: _radio._slices[slice]?.dax,
    // Only this slice's station's: each station numbers its own channels.
    taken: {
      for (final MapEntry(:key, :value) in _radio._slices.entries)
        if (key != slice && (value.dax ?? 0) > 0 && value.clientHandle == _radio._slices[slice]?.clientHandle) value.dax!,
      // Asked for by another slice and not yet stated by the radio: two
      // slices given one channel would each hear both.
      for (final other in _radio._sessions)
        if (!identical(other, this)) ?other._daxRx?.claimed,
    },
  );

  /// An acknowledged `slice set N dax=X` stands for the status the radio
  /// does not always send the client that asked, as a tune's does
  /// ([FlexRadioSession._changeSlice]): without it, the next status still
  /// reads the slice off DAX and the stream is taken down as if the
  /// operator had.
  void Function(int code, String body)? _echoingDax(String command, void Function(int code, String body)? onReply) {
    final set = RegExp(r'^slice set (\d+) dax=(\d+)$').firstMatch(command);
    if (set == null) return onReply;
    return (code, body) {
      if (code == 0) _radio._handleSliceFields(int.parse(set[1]!), {'dax': set[2]!});
      onReply?.call(code, body);
    };
  }
}
