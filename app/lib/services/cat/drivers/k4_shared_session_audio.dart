// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

part of 'k4_shared_session.dart';

extension _K4SharedLiveAudio on K4SharedSession {
  void _startLiveAudio(_K4ReceiverSession facade) {
    if (facade.sink case final TalkAudioSink sink) {
      final talk = sink.talkAudio;
      final send = _sendAudio;
      facade._wantsTalk = talk != null && send != null;
      if (talk != null && send != null) {
        facade._talk = K4RemoteTalk(
          link: talk,
          send: send,
          diagnose: reportDiagnostic,
          problem: (why) {
            facade._talkProblem = why;
            facade._reportAudioProblem();
          },
          onAirRefused: () => _releaseFailedTalk(facade),
        );
      }
    }

    final stream = _audio;
    if (stream == null || facade.sink is! ReceiveAudioSink) return;
    final link = (facade.sink as ReceiveAudioSink).receiveAudio;
    if (link == null) return;
    if (_audioRefused) {
      facade._receiveProblem = t.settings.station.audioProblemStream;
      facade._reportAudioProblem();
      return;
    }
    try {
      final receive = _K4ReceiveAudio(link.engine.addPushed(channels: 2), facade.receiver, link);
      facade._receiveAudio = receive;
      final route = link.hear(receive.source, why: reportDiagnostic);
      if (route == null || !facade._usable) {
        _stopHearing(facade, problem: route == null ? t.settings.station.audioProblemOutputOpen : null);
        return;
      }
    } on HaloAudioException catch (e) {
      reportDiagnostic('the engine would not open K4 receive audio: ${e.message}');
      _stopHearing(facade, problem: t.settings.station.audioProblemEngine);
      return;
    } on StateError {
      _stopHearing(facade, problem: t.settings.station.audioProblemEngine);
      return;
    }
    _audioSubscription ??= stream.listen(_hearAudio, onDone: _receiveStreamEnded);
    _configureRawAudio();
  }

  void _hearAudio(K4RemoteAudioPacket packet) {
    if (!_rawAudioReady) return;
    final listeners = _facades.where((facade) => facade._receiveAudio?.link.selectedForListening ?? false).length;
    final stereo = listeners == 1 && _diversity == true && _subOn == true;
    for (final facade in _facades.toList()) {
      final receive = facade._receiveAudio;
      if (receive == null) continue;
      if (!receive.link.selectedForListening || (facade.receiver == K4Receiver.sub && _subOn != true)) {
        receive.reset();
        continue;
      }
      try {
        // A lone diversity listener hears both physical receivers. With
        // separate listening links the mix keeps each receiver's own mono
        // source, so SO2R can place them without duplicating the pair.
        receive.push(packet, stereo: stereo);
      } on StateError {
        _stopHearing(facade, problem: t.settings.station.audioProblemEngine);
      }
    }
  }

  void _receiveStreamEnded() {
    _audioSubscription = null;
    for (final facade in _facades.toList()) {
      if (facade._receiveAudio != null) _stopHearing(facade, problem: t.settings.station.audioProblemStream);
    }
  }

  void _stopHearing(_K4ReceiverSession facade, {String? problem}) {
    facade._receiveAudio?.source.close();
    facade._receiveAudio = null;
    facade._receiveProblem = problem;
    facade._reportAudioProblem();
    if (!_facades.any((other) => other._receiveAudio != null)) {
      final subscription = _audioSubscription;
      _audioSubscription = null;
      if (subscription != null) unawaited(subscription.cancel());
      _restoreAudioEncoding();
    }
  }

  void _configureRawAudio() {
    if (_rawAudioReady || _checkingRawAudio) return;
    final epoch = ++_audioEncodingEpoch;
    final commands = _encoding.beforeKey();
    final verify = _encoding.verify(
      result: (accepted) {
        if (_closing || _disposed || epoch != _audioEncodingEpoch) return;
        _checkingRawAudio = false;
        if (accepted) {
          _rawAudioReady = true;
          _keyTalk();
        } else {
          _liveEncodingFailed();
        }
      },
    );
    if (verify.isEmpty) {
      _rawAudioReady = true;
      _keyTalk();
    } else {
      _checkingRawAudio = true;
      _send('$commands$verify');
    }
  }

  /// One EM setting is shared by Main, Sub, the microphone and recordings.
  void _restoreAudioEncoding() {
    if (_closing || _audioSubscription != null || _talkOwner != null || _pttOwner != null) return;
    _resetRawAudio();
    _encoding.afterUnkey();
  }

  void _resetRawAudio() {
    _audioEncodingEpoch++;
    _rawAudioReady = _checkingRawAudio = false;
  }

  void _liveEncodingFailed() {
    _resetRawAudio();
    if (_talkOwner case final talking?) {
      talking._talkProblem = t.settings.station.audioProblemTalkStream;
      talking._reportAudioProblem();
      _releaseFailedTalk(talking);
    }
    for (final facade in _facades.toList()) {
      if (facade._receiveAudio != null) _stopHearing(facade, problem: t.settings.station.audioProblemStream);
    }
  }

  bool _setTalkPtt(_K4ReceiverSession facade, bool on) {
    if (!on) {
      if (_talkOwner == facade) _stopTalk();
      return true;
    }
    if (_talkOwner == facade) return true;
    final talk = facade._talk;
    if (talk == null || _audioRefused) {
      facade._talkProblem = t.settings.station.audioProblemTalkStream;
      facade._reportAudioProblem();
      return false;
    }
    // Only one transmitter. The microphone cannot take over a key already
    // held by the radio, a client, CW, or either phone keyer.
    if (_talkOwner != null || _transmitting || _pttOwner != null || _cwOwner != null || _voiceOwner != null) return false;
    if (!talk.prepare() || !facade._usable) return false;
    _talkOwner = facade;
    if (_rawAudioReady) {
      _keyTalk();
    } else {
      _configureRawAudio();
    }
    return _talkOwner == facade;
  }

  void _keyTalk() {
    final facade = _talkOwner;
    if (facade == null || _talkKeyed) return;
    if (!facade._talk!.keyed()) return _releaseFailedTalk(facade);
    // A tunnel packet keys the K4 with the streamed input. A CAT TX
    // would key the radio's own input (QK4 protocol quirks §4).
    _pttOwner = facade;
    _talkKeyed = true;
  }

  void _stopTalk() {
    final facade = _talkOwner;
    if (facade == null) return;
    _talkOwner = null;
    facade._talk?.unkey();
    if (_talkKeyed) {
      _talkKeyed = false;
      // The K4 comes off the air when the stream stops. An RX here could
      // cut off audio the radio is still playing from the final frame.
      _pttOwner = null;
    }
    _restoreAudioEncoding();
  }

  void _releaseFailedTalk(_K4ReceiverSession facade) {
    if (_talkOwner != facade) return;
    try {
      _stopTalk();
    } finally {
      if (facade.sink case final AudioProblemSink sink) sink.releaseKey();
    }
  }

  void _preemptTalk() {
    if (_talkOwner case final facade?) _releaseFailedTalk(facade);
  }

  void _detachLiveAudio(_K4ReceiverSession facade) {
    if (_talkOwner == facade) _stopTalk();
    facade._talk?.stop();
    facade._talk = null;
    facade._wantsTalk = false;
    facade._talkProblem = null;
    if (facade._receiveAudio != null || facade._receiveProblem != null) _stopHearing(facade);
  }

  void _closeLiveAudio() {
    // Stop the stream before KenwoodSession tears down CAT and EM is put back.
    _talkOwner = null;
    _talkKeyed = false;
    for (final facade in _facades.toList()) {
      _detachLiveAudio(facade);
    }
    _resetRawAudio();
  }
}

/// Interpolates 12 kHz audio to the engine's 48 kHz rate. The endpoint stays
/// stereo: normally the selected receiver in both ears, or Main left/Sub
/// right for a lone diversity listener. The route still owns gain and pan.
/// Reset at gaps and layout changes so unrelated samples cannot blend.
class _K4ReceiveAudio {
  _K4ReceiveAudio(this.source, this.receiver, this.link);

  final AudioEndpoint source;
  final K4Receiver receiver;
  final RadioAudioLink link;
  double? _lastLeft, _lastRight;
  bool? _stereo;
  int? _sequence;
  Float32List? _buffer;

  // K4 raw audio is about 30 dB below full scale (QK4 protocol quirks §11).
  static const _gain = 32;
  static const _factor = AudioEngine.rate ~/ k4RemoteAudioRate;

  void reset() {
    _lastLeft = _lastRight = null;
    _stereo = null;
    _sequence = null;
  }

  void push(K4RemoteAudioPacket packet, {required bool stereo}) {
    if (_sequence != ((packet.sequence - 1) & 0xff) || _stereo != stereo) _lastLeft = _lastRight = null;
    _sequence = packet.sequence;
    _stereo = stereo;
    final count = packet.frames * _factor * 2;
    final output = _buffer?.length == count ? _buffer! : (_buffer = Float32List(count));
    final channel = receiver == K4Receiver.main ? 0 : 1;
    var at = 0;
    for (var input = 0; input < packet.samples.length; input += 2) {
      final left = (packet.samples[input + (stereo ? 0 : channel)] * _gain).clamp(-1.0, 1.0);
      final right = (packet.samples[input + (stereo ? 1 : channel)] * _gain).clamp(-1.0, 1.0);
      final lastLeft = _lastLeft ?? left, lastRight = _lastRight ?? right;
      for (var step = 1; step <= _factor; step++) {
        output[at++] = lastLeft + (left - lastLeft) * (step / _factor);
        output[at++] = lastRight + (right - lastRight) * (step / _factor);
      }
      _lastLeft = left;
      _lastRight = right;
    }
    source.push(output);
  }
}
