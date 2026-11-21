// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The audio engine as the app holds it (docs/design/audio.md): one per
// launch, made the first time a radio's audio is wanted, and the operator's
// output devices in it, each opened once and shared by every radio heard on
// it.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:halo_audio/halo_audio.dart';
import 'package:halo_core/halo_core.dart' show realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';

import '../cat/driver.dart' show RadioAudioLink, TalkAudioLink, TalkRoute;
import '../cat/so2r_audio.dart' show So2rEar;
import '../error_reporting_service.dart';
import '../settings_service.dart' show SettingsService;

/// Whether HaLo carries radio audio on this device: the experiment on, and
/// the audio engine here.
bool radioAudioAvailable(SettingsService settings) => settings.experimentEnabled('audio') /* stored key, see experiments.yaml */ && HaloAudio.isSupported;

/// Whether the operator hears this radio in HaLo, and talks through it, as
/// flags on its equipment node: what builds before a position's audio slots
/// read (`kSlotReceiveAudio`, `kSlotTransmitAudio`). Read once, to move them
/// there (`CatService._moveAudioChoices`), and left for an older build.
const receiveAudioConfigKey = 'receiveAudio';
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

/// How far behind its card a radio on a sound card may fall: both ends are
/// this computer's, with no network between them.
const _cardDelayMs = 50;

/// A microphone and the radio's sender are both paced every few
/// milliseconds on this computer, with no network between them.
const _talkStart = Duration(milliseconds: 10);
const _talkMax = Duration(milliseconds: 100);

class RadioAudio {
  RadioAudio({
    AudioEngine Function()? engine,
    List<AudioDevice> Function()? outputs,
    List<AudioDevice> Function()? inputs,
    ({List<AudioDevice> playback, List<AudioDevice> capture}) Function()? soundCards,
    ({String? id, String? name})? Function()? microphone,
    ({String? id, String? name})? Function()? output,
    double Function()? volume,
    double Function(String radio)? level,
    So2rEar? Function(String radio)? ear,
    this._onOutputGone,
  }) : _newEngine = engine ?? AudioEngine.new,
       _outputs = outputs ?? HaloAudio.playbackDevices,
       _inputs = inputs ?? HaloAudio.captureDevices,
       // Without one of its own, the lists given for routing: a caller that
       // keeps the native library out of a test keeps it out of this too.
       _soundCards =
           soundCards ??
           (outputs == null && inputs == null
               ? _countedCards
               : () => (playback: (outputs ?? HaloAudio.playbackDevices)(), capture: (inputs ?? HaloAudio.captureDevices)())),
       _microphone = microphone ?? _systemDefault,
       _output = output ?? _systemDefault,
       _volume = volume ?? _unity,
       _level = level ?? _unityFor,
       _ear = ear ?? _noEar;

  final AudioEngine Function() _newEngine;
  final List<AudioDevice> Function() _outputs;
  final List<AudioDevice> Function() _inputs;

  /// The lists with their channel counts, which [_outputs] and [_inputs]
  /// leave out: counting probes every device, and those are read on the way
  /// to a key-down.
  final ({List<AudioDevice> playback, List<AudioDevice> capture}) Function() _soundCards;

  static ({List<AudioDevice> playback, List<AudioDevice> capture}) _countedCards() =>
      (playback: HaloAudio.playbackDevices(channels: true), capture: HaloAudio.captureDevices(channels: true));

  /// The operator's microphone, read at each over, so a change takes effect
  /// at the next key; null for the system's default input.
  final ({String? id, String? name})? Function() _microphone;

  /// The operator's headphones, which every radio heard in HaLo is mixed
  /// into: read as a radio's audio is routed, so a change takes effect as
  /// each radio's audio is routed again ([CatService.setOperatorHeadphones]).
  final ({String? id, String? name})? Function() _output;

  /// The mix's overall volume, and what each radio is mixed at before it:
  /// a route's gain is the two together ([applyGains]).
  final double Function() _volume;
  final double Function(String radio) _level;

  /// Which ears each radio is heard in, as SO2R's switcher puts it when this
  /// computer is the switcher (`so2rSwitchComputer`): null for both, at its
  /// level, as with no switcher. Read with the gains ([applyGains]).
  final So2rEar? Function(String radio) _ear;

  /// The station's output went away (unplugged): every radio heard on it
  /// has to be routed again, into it once it is back or to say it is not.
  final void Function()? _onOutputGone;

  static ({String? id, String? name})? _systemDefault() => null;
  static double _unity() => 1;
  static double _unityFor(String radio) => 1;
  static So2rEar? _noEar(String radio) => null;
  AudioEngine? _engine;

  /// The output devices open, by the device they were asked for ('' for
  /// the system default).
  final _open = <String, AudioEndpoint>{};

  /// Each radio's routes into the output, to set their gain as the mix
  /// changes: a route the engine no longer has is forgotten as it is found.
  final _routes = <String, List<AudioRoute>>{};

  AudioEngine get engine => _engine ??= _newEngine();

  /// The sound cards this computer lists each way, each with how many
  /// channels it has: none when they will not list.
  ///
  /// Read again once [soundCardsFresh] has passed rather than on a change,
  /// which the engine is not told of: each read probes every card, and a
  /// picker or the resolver asks on every build.
  ({List<AudioDevice> playback, List<AudioDevice> capture}) get soundCards {
    final now = realNowMillis();
    if (_cards case final cards? when now - _cardsAt < soundCardsFresh.inMilliseconds) return cards;
    _cardsAt = now;
    try {
      return _cards = _soundCards();
    } on HaloAudioException {
      // No backend opened: the shack's state, which the audio mixing
      // settings' pickers say where the operator can act on it.
    } catch (e, st) {
      if (!_cardsFailureReported) ErrorReportingService.report(e, st, context: 'audio:sound-cards');
      _cardsFailureReported = true;
    }
    return _cards = (playback: const [], capture: const []);
  }

  static const soundCardsFresh = Duration(seconds: 5);
  ({List<AudioDevice> playback, List<AudioDevice> capture})? _cards;
  int _cardsAt = 0;

  /// One report a launch: the same failure comes back at every read.
  bool _cardsFailureReported = false;

  /// A link for [radio], whose audio may fall [delayMs] behind.
  RadioAudioLink link({required String radio, int delayMs = receiveAudioDelayDefault, bool Function()? selectedForListening}) =>
      _Link(this, radio, delayMs, selectedForListening);

  /// Sets every route's gain to its radio's level and the overall volume,
  /// in the ears it is put in: as a slider moves, so it is heard as it is
  /// set.
  ///
  /// Sent to the engine only where a radio's gains changed: this runs at
  /// every change of what the operator hears, a radio's every report among
  /// them, and each route's gain is a call into the engine.
  void applyGains() {
    for (final MapEntry(key: radio, value: routes) in _routes.entries) {
      final gains = _gainsFor(radio);
      if (_applied[radio] == gains) continue;
      _applied[radio] = gains;
      final (left, right) = gains;
      routes.removeWhere((route) {
        try {
          route.setGain(left, right);
          return false;
        } on StateError {
          return true;
        }
      });
    }
    _routes.removeWhere((_, routes) => routes.isEmpty);
    _applied.removeWhere((radio, _) => !_routes.containsKey(radio));
  }

  /// The gains each radio's routes were last set to ([applyGains]).
  final _applied = <String, (double, double)>{};

  /// [radio]'s gain in each ear, as its routes are set to it.
  (double, double) gainsFor(String radio) => _gainsFor(radio);

  (double, double) _gainsFor(String radio) {
    final gain = _level(radio) * _volume();
    return switch (_ear(radio)) {
      null || So2rEar.both => (gain, gain),
      So2rEar.left => (gain, 0.0),
      So2rEar.right => (0.0, gain),
      So2rEar.muted => (0.0, 0.0),
    };
  }

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
      final gains = _gainsFor(radio);
      final (left, right) = gains;
      if (left != 1 || right != 1) route.setGain(left, right);
      // The radio's first route says what its routes are at; a later one
      // must not, over routes the next [applyGains] has yet to bring to it.
      if (!_routes.containsKey(radio)) _applied[radio] = gains;
      (_routes[radio] ??= []).add(route);
      return route;
    } on ArgumentError {
      why(t.settings.station.audioProblemRoute);
      return null;
    }
  }

  /// The sound card each radio is heard from ([hearCard]), by radio, and
  /// which card it was asked for: an input that would not open is null, and
  /// asked again for the same card does nothing, so its problem is said
  /// once rather than at every change of the radio's state.
  final _cardInputs = <String, ({String card, AudioEndpoint? input})>{};

  /// Plays [card], a sound card on this computer, into the operator's
  /// headphones as [radio]'s receive audio: a radio on a USB codec. Opened
  /// in stereo, as a codec carries a radio's two receivers left and right;
  /// one with a single channel is heard in both ears.
  void hearCard(String radio, ({String? id, String? name}) card, void Function(String reason) why) {
    final key = card.id ?? card.name ?? '';
    if (_cardInputs[radio]?.card == key) return;
    dropCard(radio);
    final reasons = <String>[];
    AudioEndpoint? input;
    try {
      final device = matchAudioDevice(_inputs(), id: card.id, name: card.name);
      if (device == null) {
        reasons.add(t.settings.station.audioProblemReceiveCard(name: card.name ?? card.id ?? ''));
      } else {
        input = engine.openInput(deviceId: device.id, channels: 2);
        if (_hear(radio, _cardDelayMs, input, reasons.add) == null) {
          input.close();
          input = null;
        }
      }
    } on HaloAudioException {
      // Not uploaded: a card another program holds is the shack's state.
      input?.close();
      input = null;
      reasons.add(t.settings.station.audioProblemReceiveCardOpen);
    }
    _cardInputs[radio] = (card: key, input: input);
    // Said only once the attempt is recorded: a reason given changes the
    // radio's state, which asks for its card again.
    reasons.forEach(why);
  }

  /// Whether [radio] is heard from its sound card now.
  @visibleForTesting
  bool hearsCard(String radio) => _cardInputs[radio]?.input != null;

  /// The input [radio] is heard from now: a new one each time it is routed
  /// again.
  @visibleForTesting
  AudioEndpoint? cardInput(String radio) => _cardInputs[radio]?.input;

  /// Whether an over is going out through a sound card now.
  @visibleForTesting
  bool get talksToCard => _cardOver != null;

  /// Stops hearing [radio]'s sound card: its route goes with its input.
  void dropCard(String radio) => _cardInputs.remove(radio)?.input?.close();

  /// The over going out through a sound card ([speakToCard]): the
  /// microphone and the card, closed together after it.
  ({AudioEndpoint microphone, AudioEndpoint card})? _cardOver;

  /// Opens the operator's microphone and [card], a sound card on this
  /// computer, and routes the one into the other, for one over: a radio on
  /// a USB codec takes its transmit audio from the card. False, with the
  /// reason given to [why], when either will not open.
  bool speakToCard(({String? id, String? name}) card, void Function(String reason) why) {
    endCardOver();
    final AudioEndpoint output;
    try {
      final device = matchAudioDevice(_outputs(), id: card.id, name: card.name);
      if (device == null) {
        why(t.settings.station.audioProblemTalkCard(name: card.name ?? card.id ?? ''));
        return false;
      }
      output = engine.openOutput(deviceId: device.id);
    } on HaloAudioException {
      why(t.settings.station.audioProblemTalkCardOpen);
      return false;
    }
    final microphone = _openMicrophone(why);
    if (microphone == null) {
      output.close();
      return false;
    }
    try {
      engine.connect(microphone, output, start: _talkStart, max: _talkMax);
    } on ArgumentError {
      microphone.close();
      output.close();
      why(t.settings.station.audioProblemMicrophoneOpen);
      return false;
    }
    _cardOver = (microphone: microphone, card: output);
    return true;
  }

  /// Closes the over [speakToCard] opened: the microphone first, so the card
  /// is not left playing what it last had.
  void endCardOver() {
    final over = _cardOver;
    _cardOver = null;
    over?.microphone.close();
    over?.card.close();
  }

  /// A link that carries the station's microphone to a radio.
  TalkAudioLink talkLink() => _Talk(this);

  TalkRoute? _speak(AudioEndpoint sink, void Function(String reason) why) {
    final microphone = _openMicrophone(why);
    if (microphone == null) return null;
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

  /// The operator's microphone, opened for one over and closed after it: an
  /// open microphone is one the system shows as listening, and HaLo listens
  /// only to transmit.
  AudioEndpoint? _openMicrophone(void Function(String reason) why) {
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
    try {
      return engine.openInput(deviceId: deviceId);
    } on HaloAudioException {
      why(t.settings.station.audioProblemMicrophoneOpen);
      return null;
    }
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
    _applied.clear();
    _cardOver = null;
    _cardInputs.clear();
    _open.clear();
    _routes.clear();
    _engine?.close();
    _engine = null;
  }
}

class _Link implements RadioAudioLink {
  _Link(this._audio, this._radio, this._delayMs, this._selectedForListening);

  final RadioAudio _audio;
  final String _radio;
  final int _delayMs;
  final bool Function()? _selectedForListening;

  @override
  AudioEngine get engine => _audio.engine;

  @override
  bool get selectedForListening => _selectedForListening?.call() ?? true;

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
