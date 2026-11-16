// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The audio engine as the app holds it (docs/design/audio.md): one per
// launch, made the first time a radio's audio is wanted, and the operator's
// output devices in it, each opened once and shared by every radio heard on
// it.

import 'package:halo_audio/halo_audio.dart';
import 'package:halo_i18n/halo_i18n.dart';

import '../cat/driver.dart' show RadioAudioLink, TalkAudioLink, TalkRoute;
import '../settings_service.dart' show SettingsService;

/// Whether HaLo carries radio audio on this device: the experiment on, and
/// the audio engine here.
bool radioAudioAvailable(SettingsService settings) => settings.experimentEnabled('audio') /* stored key, see experiments.yaml */ && HaloAudio.isSupported;

/// Whether the operator hears this radio in HaLo, on its equipment node.
const receiveAudioConfigKey = 'receiveAudio';

/// Whether the operator talks through HaLo on this radio, on its equipment
/// node: their key on it sends the station's microphone
/// ([RadioAudioSettings.stationMicrophone]) rather than the radio's own.
const talkAudioConfigKey = 'talkAudio';

/// How far behind the radio its receive audio may fall, in milliseconds, on
/// its equipment node; absent for [receiveAudioDelayDefault]. The route's
/// depth adapts up to it: shorter is more immediate, and drops out at a
/// network stall longer than it. Per radio because it is set by the network
/// the radio is reached over — a wired LAN settles at a few milliseconds,
/// and a Wi-Fi link holds a FlexRadio's packets back for up to 200 ms with
/// nothing lost.
const receiveAudioDelayConfigKey = 'receiveAudioDelay';
const receiveAudioDelays = [40, 100, 250, 500];
const receiveAudioDelayDefault = 250;
const _receiveStart = Duration(milliseconds: 20);

/// A microphone and the radio's sender are both paced every few
/// milliseconds on this computer, with no network between them.
const _talkStart = Duration(milliseconds: 10);
const _talkMax = Duration(milliseconds: 100);

class RadioAudio {
  RadioAudio({
    AudioEngine Function()? engine,
    List<AudioDevice> Function()? outputs,
    List<AudioDevice> Function()? inputs,
    ({String? id, String? name})? Function()? microphone,
    ({String? id, String? name})? Function()? output,
    double Function()? volume,
    double Function(String radio)? level,
    this._onOutputGone,
  }) : _newEngine = engine ?? AudioEngine.new,
       _outputs = outputs ?? HaloAudio.playbackDevices,
       _inputs = inputs ?? HaloAudio.captureDevices,
       _microphone = microphone ?? _systemDefault,
       _output = output ?? _systemDefault,
       _volume = volume ?? _unity,
       _level = level ?? _unityFor;

  final AudioEngine Function() _newEngine;
  final List<AudioDevice> Function() _outputs;
  final List<AudioDevice> Function() _inputs;

  /// The station's microphone, read at each over, so a change takes effect
  /// at the next key; null for the system's default input.
  final ({String? id, String? name})? Function() _microphone;

  /// The station's output, which every radio heard in HaLo is mixed into:
  /// read as a radio's audio is routed, so a change takes effect as each
  /// radio's audio is routed again ([CatService.setStationOutput]).
  final ({String? id, String? name})? Function() _output;

  /// The mix's overall volume, and what each radio is mixed at before it:
  /// a route's gain is the two together ([applyGains]).
  final double Function() _volume;
  final double Function(String radio) _level;

  /// The station's output went away (unplugged): every radio heard on it
  /// has to be routed again, into it once it is back or to say it is not.
  final void Function()? _onOutputGone;

  static ({String? id, String? name})? _systemDefault() => null;
  static double _unity() => 1;
  static double _unityFor(String radio) => 1;
  AudioEngine? _engine;

  /// The output devices open, by the device they were asked for ('' for
  /// the system default).
  final _open = <String, AudioEndpoint>{};

  /// Each radio's routes into the output, to set their gain as the mix
  /// changes: a route the engine no longer has is forgotten as it is found.
  final _routes = <String, List<AudioRoute>>{};

  AudioEngine get engine => _engine ??= _newEngine();

  /// A link for [radio], whose audio may fall [delayMs] behind.
  RadioAudioLink link({required String radio, int delayMs = receiveAudioDelayDefault}) => _Link(this, radio, delayMs);

  /// Sets every route's gain to its radio's level and the overall volume:
  /// as a slider moves, so it is heard as it is set.
  void applyGains() {
    for (final MapEntry(key: radio, value: routes) in _routes.entries) {
      final gain = _gainFor(radio);
      routes.removeWhere((route) {
        try {
          route.setGain(gain, gain);
          return false;
        } on StateError {
          return true;
        }
      });
    }
    _routes.removeWhere((_, routes) => routes.isEmpty);
  }

  double _gainFor(String radio) => _level(radio) * _volume();

  /// Closes every output but the station's: once each radio's audio has
  /// been routed again into the one now picked, the old one plays nothing.
  void closeOtherOutputs() {
    final keep = _outputKey(_output());
    for (final key in [..._open.keys]) {
      if (key != keep) _open.remove(key)?.close();
    }
  }

  static String _outputKey(({String? id, String? name})? device) => device == null ? '' : device.id ?? device.name ?? '';

  AudioRoute? _hear(String radio, int delayMs, AudioEndpoint source, void Function(String reason) why) {
    final output = _openOutput(why);
    if (output == null) return null;
    // The bridge's target stays under half its maximum. A route the engine
    // cannot make (no room for another, an endpoint gone) is the slice not
    // heard, said as such, not an error out of the radio's answer handler.
    try {
      final route = engine.connect(
        source,
        output,
        start: _receiveStart,
        max: Duration(milliseconds: 2 * delayMs),
      );
      final gain = _gainFor(radio);
      if (gain != 1) route.setGain(gain, gain);
      (_routes[radio] ??= []).add(route);
      return route;
    } on ArgumentError {
      why(t.settings.station.audioProblemRoute);
      return null;
    }
  }

  /// A link that carries the station's microphone to a radio.
  TalkAudioLink talkLink() => _Talk(this);

  TalkRoute? _speak(AudioEndpoint sink, void Function(String reason) why) {
    final wanted = _microphone();
    String? deviceId;
    if (wanted != null) {
      final List<AudioDevice> devices;
      try {
        devices = _inputs();
      } on HaloAudioException {
        why(t.settings.station.audioProblemMicrophoneOpen);
        return null;
      }
      final device = matchAudioDevice(devices, id: wanted.id, name: wanted.name);
      if (device == null) {
        why(t.settings.station.audioProblemMicrophone(name: wanted.name ?? wanted.id ?? ''));
        return null;
      }
      deviceId = device.id;
    }
    final AudioEndpoint microphone;
    try {
      // Opened for the over and closed after it: an open microphone is one
      // the system shows as listening, and HaLo listens only to transmit.
      microphone = engine.openInput(deviceId: deviceId);
    } on HaloAudioException {
      why(t.settings.station.audioProblemMicrophoneOpen);
      return null;
    }
    try {
      engine.connect(microphone, sink, start: _talkStart, max: _talkMax);
    } on ArgumentError {
      // Closed: left open, the system shows HaLo listening for nothing.
      microphone.close();
      why(t.settings.station.audioProblemMicrophoneOpen);
      return null;
    }
    return _Over(microphone);
  }

  AudioEndpoint? _openOutput(void Function(String reason) why) {
    final wanted = _output();
    final name = _outputKey(wanted);
    final open = _open[name];
    if (open != null) return open;
    String? deviceId;
    if (wanted != null) {
      final List<AudioDevice> devices;
      try {
        devices = _outputs();
      } on HaloAudioException {
        why(t.settings.station.audioProblemOutputOpen);
        return null;
      }
      final device = matchAudioDevice(devices, id: wanted.id, name: wanted.name);
      if (device == null) {
        why(t.settings.station.audioProblemOutput(name: wanted.name ?? wanted.id ?? ''));
        return null;
      }
      deviceId = device.id;
    }
    try {
      final endpoint = engine.openOutput(deviceId: deviceId);
      _open[name] = endpoint;
      // Unplugged: every route into it died with it, so each radio heard on
      // it is routed again ([_onOutputGone]), into it if it is back or to
      // say it is not.
      endpoint.gone.then((_) {
        if (!identical(_open[name], endpoint)) return;
        _open.remove(name)?.close();
        _onOutputGone?.call();
      }).ignore();
      return endpoint;
    } on HaloAudioException {
      // Not uploaded: a device another program holds, or one just
      // unplugged, is the shack's state, not a defect.
      why(t.settings.station.audioProblemOutputOpen);
      return null;
    }
  }

  void close() {
    _open.clear();
    _routes.clear();
    _engine?.close();
    _engine = null;
  }
}

class _Link implements RadioAudioLink {
  _Link(this._audio, this._radio, this._delayMs);

  final RadioAudio _audio;
  final String _radio;
  final int _delayMs;

  @override
  AudioEngine get engine => _audio.engine;

  @override
  AudioRoute? hear(AudioEndpoint source, {required void Function(String reason) why}) => _audio._hear(_radio, _delayMs, source, why);
}

class _Talk implements TalkAudioLink {
  _Talk(this._audio);

  final RadioAudio _audio;

  @override
  AudioEngine get engine => _audio.engine;

  @override
  TalkRoute? speak(AudioEndpoint sink, {required void Function(String reason) why}) => _audio._speak(sink, why);
}

/// One over: the microphone, whose route goes with it.
class _Over implements TalkRoute {
  _Over(this._microphone);

  final AudioEndpoint _microphone;

  @override
  void close() => _microphone.close();
}
