// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the FlexRadio SmartSDR API: a line-oriented protocol over a single
// TCP stream, mixing command/response pairs ("C<seq>|command" /
// "R<seq>|code|result") with unsolicited status pushes ("S<handle>|...").
// One connection is the radio ([FlexRadio], flex_radio.dart); each slice the
// station uses is a [FlexRadioSession] on it.
//
// Ported from app-polo's FlexRadioDriver.js, which was verified against a
// live FLEX-6600. Two deliberate divergences: readings go to a sink
// instead of straight into the store, and chunks are reassembled into lines
// (polo split each chunk on '\n' with no residual buffer, so a status line
// straddling two TCP reads was mangled).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:halo_audio/halo_audio.dart' show AudioEngine, AudioOutput, HaloAudioException;
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';
import 'cw_send_queue.dart';
import 'line_framer.dart';
import 'flex_so2r_audio.dart';
import '../so2r_audio.dart';
import 'flex_meter_codec.dart';
import 'flex_slice_config.dart';
import 'voice_activity_tracker.dart';
import 'flex_pan_spectrum.dart';
import 'flex_spectrum.dart';
import 'flex_dax_iq.dart';
import 'flex_dax_switch.dart';
import 'flex_dax_rx.dart';
import 'flex_dax_talk.dart';
import 'flex_dax_tx.dart';
import '../transports/flex_meter_socket.dart';
import '../transports/shared_connection.dart';

part 'flex_radio.dart';
part 'flexradio_receive_audio.dart';
part 'flexradio_talk.dart';
part 'flexradio_slice_status.dart';
part 'flexradio_own_pans.dart';

/// App mode names → SmartSDR's, where the spellings differ. SmartSDR calls
/// its data sidebands `DIGU`/`DIGL`; the app names them the way every other
/// driver reports them.
const flexModesByAppMode = <String, String>{'DATA-USB': 'DIGU', 'DATA-LSB': 'DIGL', 'DATA-FM': 'DFM'};

final appModesByFlexMode = {for (final entry in flexModesByAppMode.entries) entry.value: entry.key};

/// The manager marks a node "Not responding" after 30 s without a word from
/// it, and this radio says nothing while the dial is still. A `ping` gives
/// the radio something to answer inside the window; the `R` line it sends
/// back is the proof of life. One ping per window is enough because TCP
/// delivers late but never drops.
///
/// A ping and NOT a periodic re-subscribe (the Antenna Genius way).
/// Re-subscribing to a slice, `all` or one by number, breaks its receive
/// audio for a moment, in the radio's own headphones as much as in any
/// client's — heard on RadioRoom (FLEX-6600, 4.2.20); the tx, client, cwx,
/// dvk, license and atu subscriptions are silent. So each subscription is
/// sent once per session, and everything on it is pushed from then on. The
/// trade: a subscription dying over a healthy socket, never seen on
/// hardware, would show frozen values until the next connect.
const flexRadioPingInterval = Duration(seconds: 25);

/// How long a subscription's full status refresh is given to arrive before
/// a slice that has not appeared is taken to be one the radio does not
/// have.
///
/// A slice in use announces itself; a slice that does not exist announces
/// nothing, and silence is only distinguishable from a slow refresh by
/// waiting. Long enough that a busy radio is not accused of missing a slice
/// it is about to report, short enough that the operator is not left staring
/// at a blank row wondering.
const _sliceRefreshSettle = Duration(seconds: 3);

/// What HaLo's station on a Flex is called in every client's list:
/// `Ham2K (Chirimena)`. No space: the radio's status splits on them.
const flexProgramName = 'Ham2K';

/// A Flex node that is HaLo's own station's slice: [flexOwnSliceConfigKey]
/// holds its letter, the receiver it attaches as is `own-<letter>`, and
/// its connection is HaLo's station, not bound to another.
const flexOwnSliceConfigKey = 'flexOwnSlice';
const flexOwnSlicePrefix = 'own-';

/// Whether a connection is HaLo's station; and, on the radio's entry, the
/// id the radio keeps that station's slices by.
const flexGuiConfigKey = 'flexGui';
const flexClientIdConfigKey = 'flexClientId';

/// On a Flex's device entry: the pans HaLo made on its station for sweeps of
/// their own and has not seen removed ([FlexRadio.sweepPans]).
const flexSweepPansConfigKey = 'flexSweepPans';

/// The station a bound connection speaks for, by the radio's id for it:
/// under multiFLEX a key, the power read back and a DAX channel are each
/// the bound station's own, so a slice is followed on a connection bound
/// to the station that holds it.
const flexBindConfigKey = 'flexBind';

/// What the operator calls this computer on the radio, kept on the radio's
/// entry; absent for the computer's own name.
const flexStationNameConfigKey = 'flexStationName';

/// The panadapter a new slice comes with, in pixels and rows: what the
/// radio's FFT is computed for until the display says what it draws.
const _panPixels = 1024;
const _panRows = 400;

/// How long a new slice's panadapter is given to bring its slice.
const _sliceOpenWait = Duration(seconds: 5);

class FlexRadioDriver extends EquipmentDriver with AlwaysOffersScope {
  const FlexRadioDriver();

  static const defaultPort = 4992;

  @override
  String get key => 'flexradio';

  @override
  String get name => 'FlexRadio (SmartSDR)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(['LSB', 'USB', 'CW', 'AM', 'FM', 'RTTY', ...flexModesByAppMode.keys]);

  /// A FLEX-6600 runs up to eight slices; smaller models run fewer, and the
  /// radio says how many in its `radio slices=` status. Offering all eight
  /// regardless is deliberate — the list is built before any connection
  /// exists, and a slice the radio does not have is reported as missing once
  /// connected (see [FlexRadioSession._reportProblem]) rather than being
  /// silently unofferable.
  static const sliceLabels = flexSliceLabels;

  static const sliceConfigKey = 'slice';

  @override
  String? get channelKey => sliceConfigKey;

  @override
  List<String> get channelValues => [for (var i = 0; i < sliceLabels.length; i++) '$i'];

  @override
  String offerKeyWith(Map<String, dynamic> config) => '${sliceFromConfig(config)}';

  @override
  bool get canKeyCw => true;

  /// A slice's DAX receive audio, through the engine (flex_dax_rx.dart).
  @override
  bool get carriesReceiveAudio => true;

  /// The station's microphone to the transmitter, through the engine
  /// (flex_dax_talk.dart).
  @override
  bool get carriesTalkAudio => true;

  /// The DVK holds twelve; the app offers one per function key. Whether the
  /// radio's licence lets it play any is known only once connected, when
  /// the session's own count says so ([FlexRadioSession.voiceMemoryCount]).
  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => maxVoiceMemories;

  /// Its address and slice: two slices of one radio are switched by the radio.
  @override
  ({String radio, int receiver})? so2rAudioReceiverWith(Map<String, dynamic> config) => switch (config['host']) {
    final String host => (radio: host, receiver: sliceFromConfig(config)),
    _ => null,
  };

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, voiceCeilingConfigKey, sliceConfigKey};

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) =>
      FlexRadioSession(sink, slice: sliceFromConfig(config), meterHost: config['host'] as String?, voiceMemoryCeiling: voiceCeilingFromConfig(config));

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) {
    if (key != sliceConfigKey) return null;
    // Unset is slice A, not a rejection: a node configured before this
    // setting existed carries no `slice` at all, and failing it here would
    // stop a radio that has been connecting fine from connecting at all.
    if (value == null || '$value'.trim().isEmpty) return null;
    return parseFlexSlice(value) == null ? t.settings.station.flexSliceInvalid : null;
  }

  @override
  String? describeSuffix(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    final channel = describeChannel(config, overrides: overrides);
    return channel == null ? null : ' · $channel';
  }

  @override
  String? describeChannel(Map<String, dynamic> config, {Map<String, dynamic> overrides = const {}}) {
    if (overrides.containsKey(sliceConfigKey)) return null;
    return t.settings.station.flexSliceLabel(letter: sliceLabel(sliceFromConfig(config)));
  }

  /// The configured slice, defaulting to 0 — a node stored before this
  /// setting existed has no `slice` key at all, and slice A is what it was
  /// tracking.
  static int sliceFromConfig(Map<String, dynamic> config) => parseFlexSlice(config[sliceConfigKey]) ?? 0;

  /// The radio's own letter for a slice index; the index itself for one
  /// past the letters we name, which the radio would have to have invented.
  static String sliceLabel(int slice) => slice >= 0 && slice < sliceLabels.length ? sliceLabels[slice] : '$slice';
}

String? _nonEmpty(String? value) => (value == null || value.isEmpty) ? null : value;

/// SmartSDR's CWX buffer takes a whole message at once, so a chunk here is
/// only what keeps one `cwx send` line a sane length — not a radio limit.
const _cwxChunkLength = 128;

/// `cw wpm` per the SmartSDR API.
const _flexKeyerSpeedMin = 5;
const _flexKeyerSpeedMax = 100;

/// Past a recording's own length, how long a play may run before the session
/// stops it: the radio's end report travels the same socket as everything
/// else, and a busy link should not cut the last word of a CQ.
const _dvkPlayMargin = Duration(seconds: 3);

/// What SmartSDR names a DVK slot nobody has named. Shown as no label at
/// all, so the key ("M3") stands in for it the way it does for every other
/// radio's unnamed memory.
String _dvkDefaultName(int id) => 'Recording $id';

/// One slice of a [FlexRadio], as one node's session: what it reads, tunes
/// and keys is its slice, and whatever is the radio's goes through the
/// radio it is attached to.
///
/// Built alone, it is a radio with one slice on its own connection — what
/// [FlexRadioDriver.createSession] makes and the driver's tests speak to.
/// Built by [FlexRadio.attach], it is one of the slices sharing that
/// radio's connection, and the radio, not it, reads the wire.
class FlexRadioSession
    implements
        TransceiverSession,
        CwKeyerSession,
        NetworkTransmitAudioSession,
        RadioNamedVoiceMemories,
        MultiScopeSession,
        AntennaTunerSession,
        PassbandSession,
        RadioAntennaSession,
        So2rRadioAudioSession,
        RawCommandSession,
        ReceiveLevelSession,
        TransmitGatedSession,
        TalkPttSession {
  final EquipmentSink _sink;

  /// Which slice this node reads from and tunes. Symmetric on purpose: a
  /// node that watched one slice and tuned another would log a frequency
  /// the operator never transmitted on.
  ///
  /// HaLo's own slice is looked up each time, not kept: its number, once the
  /// radio closes it, may go to another station's slice, and kept it would
  /// tune that one.
  int get slice => _index ?? _radio._ownedIndex(ownLetter!) ?? -1;
  final int? _index;

  /// HaLo's own slice's letter on its station, for a slice HaLo owns; its
  /// [slice] number is found once the radio has described it, and is -1
  /// until then.
  final String? ownLetter;

  final FlexRadio _radio;

  /// Whether this session reads the wire itself: a radio of its own.
  final bool _ownsWire;

  FlexRadioSession(
    EquipmentSink sink, {
    int slice = 0,
    String? meterHost,
    FlexUdpSocketOpener openMeterSocket = FlexMeterSocket.open,
    Duration voiceMemoryCeiling = voiceActivityCeiling,
  }) : _sink = sink,
       _index = slice,
       ownLetter = null,
       _ownsWire = true,
       _radio = FlexRadio(send: sink.send, meterHost: meterHost, openMeterSocket: openMeterSocket, voiceMemoryCeiling: voiceMemoryCeiling) {
    _radio._sessions.add(this);
  }

  FlexRadioSession._on(this._radio, this._sink, {int? slice, this.ownLetter}) : _index = slice, _ownsWire = false {
    _radio._sessions.add(this);
  }

  String? get meterHost => _radio.meterHost;

  /// The radio this slice is on, which reads the wire for every slice of it.
  @visibleForTesting
  FlexRadio get radio => _radio;

  /// Whether this slice wants updates: started and not yet stopped.
  bool _active = false;

  /// The slice's receive audio, and the operator's voice to the radio,
  /// while the audio engine carries them.
  FlexDaxReceive? _daxRx;
  FlexDaxTalk? _talk;

  /// Why this slice's audio does not go through this computer: the radio's
  /// socket, its receive audio, its microphone ([_reportAudioProblem]).
  String? _socketProblem, _rxProblem, _talkProblem;

  final _signalThrottle = FlexSignalThrottle();

  void _meterPacket(Uint8List data, int now) {
    if (_radio._meters.signal(data, of: slice) case final dbm?) {
      if (_signalThrottle.accept(dbm, now) case final value?) _sink.reportMeter(RadioMeter.signalDbm, value);
    }
  }

  /// An extension's raw commands, one per line, each numbered like the
  /// driver's own: a line is a command without its `C<seq>|`, and its answer
  /// is its `R` line. A slice change sent this way reads back only if the
  /// radio echoes it (a mode change): the radio sends the client that made
  /// a tune, filter or antenna change no status, and a re-read would break
  /// the slice's audio ([flexRadioPingInterval]).
  @override
  int sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) => _radio._sendRaw(bytes, onAnswer: onAnswer);

  /// HaLo's own station takes the radio's FFT of its own pans. Bound to
  /// another station, the pan's FFT goes to that station alone, so the
  /// spectrum is mirrored through DAX IQ (flex_spectrum.dart).
  late final FlexSliceSpectrum _spectrum = _radio.gui
      ? FlexPanSpectrum(send: _sendForSpectrum, sink: _spectrumSink, pans: _radio._pans, accepted: _radio._panAccepted)
      : FlexDaxSpectrum(send: _sendForSpectrum, sink: _spectrumSink, pans: _radio._pans, iq: _radio._daxIq);

  int _sendForSpectrum(String command, {void Function(int code, String body)? onReply}) => _radio._sendForSpectrum(command, onReply: onReply);

  /// Sweeps beyond the slice's own, each a pan HaLo makes on its own
  /// station, for a display at another span (docs/design/cat.md § Several
  /// scopes). Bound to another station there is no pan to make: a slice's
  /// sweeps beyond its own come from its pan's DAX IQ ([FlexDaxSpectrum.openSub]).
  final _extraScopes = <FlexPanSpectrum>[];

  /// What the connection says to this slice's scopes: its own and [_extraScopes].
  late final _scopes = _FlexScopes(this);

  /// A sweep from DAX IQ takes any span; a pan of HaLo's own the spans a pan has.
  @override
  bool get scopesTakeAnySpan => !_radio.gui;

  @override
  SpectrumScope? openScope(SpectrumSink sink) {
    if (!_spectrum.wanted) return null;
    // Bound to another station: from the pan's DAX IQ, which the slice's own scope receives already.
    if (_spectrum case final FlexDaxSpectrum dax) {
      return dax.openSub(
        sink,
        receiverHz: () => switch (_radio._slices[slice]?.freqKHz) {
          final khz? => (khz * 1000).round(),
          null => null,
        },
      );
    }
    final scope = FlexPanSpectrum(
      send: _sendForSpectrum,
      sink: sink,
      pans: _radio._pans,
      ownPanAt: () => _radio._slices[slice]?.freqKHz,
      makePan: _radio._sweeps.make,
      accepted: _radio._panAccepted,
    );
    _extraScopes.add(scope);
    scope.start();
    if (_radio._handshakeDone) scope.subscribe();
    if (_radio._meterSocket != null) scope.socketReady();
    if (_radio._metersUnavailable) scope.socketUnavailable();
    return _FlexExtraScope(scope, () => _extraScopes.remove(scope));
  }

  SpectrumSink? get _spectrumSink => switch (_sink) {
    final SpectrumSink sink => sink,
    _ => null,
  };

  @override
  String? get spectrumUnavailable => meterHost == null ? t.settings.station.spectrumUnsupported : null;

  @override
  SpectrumCapabilities get spectrumCapabilities => _spectrum.capabilities;

  @override
  void startSpectrum() => _spectrum.start();

  @override
  void stopSpectrum() => _spectrum.stop();

  @override
  bool setSpectrum(SpectrumRequest request) => _spectrum.set(request);

  @override
  void handleData(Uint8List chunk) {
    if (_ownsWire) _radio.handleData(chunk);
  }

  /// The radio said something about this slice: [freqKHz] and [mode] are
  /// what changed. [whole] is this slice starting on a radio that has
  /// already described it, whose node hears all of it.
  void _sliceChanged({double? freqKHz, String? mode, bool whole = false}) {
    final status = _radio._slices[slice];
    _so2rAudio.apply(_sliceAudio);
    _reportOnAir();
    _spectrum.slicePan(status?.pan?.toLowerCase());
    _checkTrackedSlice();
    final reading = whole ? VfoReading(freqKHz: status?.freqKHz, mode: status?.mode) : VfoReading(freqKHz: freqKHz, mode: mode);
    if (!reading.isEmpty) _sink.report(reading);
    // `filter_lo=100 filter_hi=2800`, as RadioRoom (FLEX-6600, 4.2.20) states
    // them: already Hz from the slice frequency, the convention [Passband] uses.
    if (status case _SliceStatus(:final filterLo?, :final filterHi?) when filterLo < filterHi) {
      if (_sink case final PassbandSink sink) sink.reportPassband(Passband(filterLo, filterHi));
    }
    // `rxant=ANT1 txant=ANT1 ant_list=ANT1,ANT2,RX_A,RX_B,XVTA,XVTB tx_ant_list=ANT1,ANT2,XVTA,XVTB`,
    // as RadioRoom (FLEX-6600, 4.2.20) states slice A: a slice picks each independently.
    if (status case _SliceStatus(:final rxPorts?, :final txPorts?, :final rxant, :final txant)) {
      if (_sink case final RadioAntennaSink sink) sink.reportAntennas(RadioAntennas(rxPorts: rxPorts, txPorts: txPorts, rx: rxant, tx: txant, separate: true));
    }
  }

  /// What [_reportOnAir] last said, so a restatement is not re-reported —
  /// SmartSDR refreshes the whole object on every subscribe.
  bool? _reportedOnAir;

  /// This slice is on the air while the radio is, unless the transmit flag
  /// is on another of the app's slices of this radio: two slices of one
  /// radio, as SO2R's two radios, are not both transmitting when one is —
  /// nor is a slice the radio does not have, which keys nothing
  /// ([cannotTransmit]). The flag on a slice no session reads is a split set
  /// up on the radio, and the transmitter is this radio's — what reads this
  /// is the rule that no relay moves under RF.
  void _reportOnAir() {
    final interlock = _radio._transmitting;
    if (interlock == null) return;
    final onAir = interlock && !_radio._txOnAnotherSlice(this);
    if (onAir == _reportedOnAir) return;
    _reportedOnAir = onAir;
    _sink.reportTransmitting(onAir);
  }

  /// Moves the radio's transmit flag to this slice from another of the app's
  /// slices. `xmit`, `cwx send` and a DVK playback all go out on whichever
  /// slice holds it, so without this Radio B's message goes out on Radio A's
  /// frequency. A flag on a slice no session reads is the operator's split,
  /// and stays where it is.
  void _takeTx() {
    if (slice >= 0 && _radio._txOnAnotherSlice(this)) _radio._sendCommand('slice set $slice tx=1');
  }

  /// The slice's own audio level (0–100) and mute. Its RF gain is the
  /// panadapter's, in steps each model sets, and is not offered.
  @override
  ReceiveLevels get receiveLevels => (af: true, rf: false, mute: true);

  @override
  void setAfGain(double level) {
    if (slice >= 0) _radio._sendCommand('slice set $slice audio_level=${receiveLevelOn(level, 100)}');
  }

  @override
  void setRfGain(double level) {}

  @override
  void setMute(bool muted) {
    if (slice >= 0) _radio._sendCommand('slice set $slice audio_mute=${muted ? 1 : 0}');
  }

  /// The slice's receive and transmit antennas, each its own setting.
  @override
  void setAntenna({String? rx, String? tx}) {
    if (slice < 0) return;
    if (rx != null) _changeSlice('slice set $slice rxant=$rx', {'rxant': rx});
    if (tx != null) _changeSlice('slice set $slice txant=$tx', {'txant': tx});
  }

  /// SmartSDR's `filt`: the slice's edges, in Hz from its frequency. The
  /// radio takes edges exactly as sent or refuses them whole (inverted, or
  /// too wide); it never clamps, so an acknowledged pair is the slice's —
  /// seen on RadioRoom (FLEX-6600, 4.2.20).
  @override
  void setPassband(Passband passband) {
    if (slice < 0) return;
    _changeSlice('filt $slice ${passband.lowHz} ${passband.highHz}', {'filter_lo': '${passband.lowHz}', 'filter_hi': '${passband.highHz}'});
  }

  /// The tracked slice not being in use is a configuration mistake the
  /// operator has to fix — the radio is fine, the link is fine, and there is
  /// simply nothing at the address they picked. Left unsaid it looks exactly
  /// like a dead radio: a connected row with a frequency that never arrives.
  ///
  /// Three outcomes, and conflating any two of them sends the operator to
  /// the wrong remedy:
  ///
  /// - the radio has described slices and this one is not among them, or
  ///   says it is not in use — the slice is wrong, change it;
  /// - the radio has described NO slices at all — the subscription or the
  ///   handshake failed, and telling someone to pick another slice would
  ///   send them to change a setting that was right;
  /// - the radio mentioned the slice without saying whether it runs — no
  ///   verdict, so the last one stands.
  ///
  /// Reported unconditionally rather than on transitions: `CatService`
  /// dedupes what it holds, and a driver keeping its own copy of what it
  /// last said is what [EquipmentSink.reportDiagnostic]'s own note forbids.
  void _checkTrackedSlice() {
    if (_radio._stationRefused) return _sink.reportProblem(t.settings.station.flexStationRefused);
    final slices = _radio._slices;
    if (slices.isEmpty) {
      _sink.reportProblem(t.settings.station.flexNoSlices);
      return;
    }
    final inUse = slices[slice]?.inUse;
    // Not described while the refresh is still arriving: a slice starting on
    // a connection whose other slices the radio has just described is not
    // missing yet.
    if (!slices.containsKey(slice) && !_radio._settled) return;
    // Mentioned, but the radio never said whether it runs: no verdict to
    // give, so whatever was last reported stands.
    if (slices.containsKey(slice) && inUse == null) return;
    _sliceMissing = inUse != true;
    _sink.reportProblem(cannotTransmit);
  }

  /// The radio has described its slices, and [slice] is not among those
  /// open — [_checkTrackedSlice]'s verdict.
  bool _sliceMissing = false;
  bool get sliceClosed => _sliceMissing;

  /// Null before any verdict: the slice is presumed open until the radio
  /// has described its slices without it.
  @override
  String? get cannotTransmit => _radio._stationRefused
      ? t.settings.station.flexStationRefused
      : _sliceMissing
      ? t.settings.station.flexSliceMissing(letter: ownLetter ?? FlexRadioDriver.sliceLabel(slice))
      : switch (_radio._otherStation(this)) {
          final station? => t.settings.station.flexSliceOtherStation(station: station),
          null => null,
        };

  /// Nothing to HaLo's own slice before the radio has said which it is
  /// ([slice] is -1): the radio refuses a slice it does not have. The slice
  /// then reads as the radio has it, and a tune made before is not sent.
  @override
  void setFrequency(double freqKHz) {
    if (slice < 0) return;
    final mhz = (freqKHz / 1000).toStringAsFixed(6);
    _changeSlice('slice tune $slice $mhz', {'RF_frequency': mhz});
  }

  /// Read back from the radio's echo, not the acknowledgement: a mode change
  /// is the one slice change the radio does push to the client that made it,
  /// with that mode's own filter edges, ahead of its `R|0|`. And what it took
  /// is not always what was sent — a mode name it does not know is accepted,
  /// as DIGU — seen on RadioRoom (FLEX-6600, 4.2.20).
  @override
  void setMode(String mode) {
    final flexMode = flexModesByAppMode[mode.toUpperCase()] ?? mode.toUpperCase(), command = 'slice set $slice mode=$flexMode';
    if (!isModeName(flexMode) || slice < 0) return;
    _radio._sendCommand(
      command,
      onReply: (code, _) {
        if (code == 0 || !_active || !_radio._handshakeDone) return;
        // As a refused tune does ([_changeSlice]): the app shows the mode as
        // set before the radio answers.
        _reportRefusal(command, code);
        if (_radio._slices[slice]?.mode case final mode?) _sink.report(VfoReading(mode: mode));
      },
    );
  }

  /// Which command last set each slice field, so that the acknowledgement
  /// of an older one — a dial turned faster than the radio answers — does
  /// not put the slice back where that one left it.
  final _latestSliceChange = <String, int>{};

  /// Sends a change to the tracked slice that sets [fields], as the radio
  /// names them in its status.
  ///
  /// Flex sends the client that changed a slice no status for a tune, filter
  /// or antenna change, and asking again by re-subscribing breaks the slice's
  /// audio ([flexRadioPingInterval]). So the acknowledgement is the
  /// confirmation: on `R<seq>|0|` the slice reads as [fields], as if the
  /// radio had pushed them. A refused tune or filter comes with a push of
  /// where the slice stayed, ahead of the refusal, and a refused antenna
  /// leaves the one already read — seen on RadioRoom (FLEX-6600, 4.2.20). A
  /// refused tune still reports the frequency the slice last read: the app
  /// shows a tune as made before the radio answers, and a refusal that came
  /// with no push would otherwise leave it there.
  void _changeSlice(String command, Map<String, String> fields) {
    late final int seq;
    seq = _radio._sendCommand(
      command,
      onReply: (code, _) {
        final current = {
          for (final MapEntry(:key, :value) in fields.entries)
            if (_latestSliceChange[key] == seq) key: value,
        };
        for (final key in current.keys) {
          _latestSliceChange.remove(key);
        }
        if (!_active || !_radio._handshakeDone) return;
        if (code == 0) {
          if (current.isNotEmpty) _radio._handleSliceFields(slice, current);
          return;
        }
        _reportRefusal(command, code);
        if (current.containsKey('RF_frequency') && _radio._slices[slice]?.freqKHz != null) {
          _sink.report(VfoReading(freqKHz: _radio._slices[slice]!.freqKHz));
        }
      },
    );
    for (final key in fields.keys) {
      _latestSliceChange[key] = seq;
    }
  }

  void _reportRefusal(String command, int code) => _sink.reportDiagnostic('Flex refused "$command": 0x${code.toRadixString(16).toUpperCase()}');

  @override
  void setPower(num watts) => _radio._setPower(watts);

  /// A Flex has no "in line" switch: its tuner engages by tuning, which keys
  /// a carrier — briefly, from its memory for the frequency when it has one
  /// and memories are on. Bypass transmits nothing.
  @override
  void setTuner({required bool inline}) => _radio._setTuner(inline: inline);

  /// In line already is the tune here.
  @override
  bool get canStartTune => false;

  @override
  void startTune() {}

  @override
  void stopTune() {}

  @override
  void sendCw(String text) => _radio._sendCw(this, text);

  @override
  void stopCw() => _radio._stopCw();

  @override
  bool get cwSending => _radio._cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _radio._cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => (min: _flexKeyerSpeedMin, max: _flexKeyerSpeedMax);

  /// The radio answers a `cw wpm` with a `cwx wpm=` status push, which is
  /// the read-back the other drivers have to ask for.
  @override
  void setKeyerSpeed(int wpm) => _radio._sendCommand('cw wpm ${wpm.clamp(_flexKeyerSpeedMin, _flexKeyerSpeedMax)}');

  /// Nothing to ask: the speed is pushed. Re-subscribing answers with a
  /// full refresh, which carries it.
  @override
  void refreshKeyerSpeed() => _radio._refreshKeyerSpeed();

  @override
  bool get talksThroughHalo => _talkAudio != null;

  @override
  bool setPttTalking(bool on) => _setPttTalking(on);

  /// Keys the radio on this slice: the transmit flag comes here first, since
  /// `xmit` names none. Whether it keyed comes back as the interlock push.
  @override
  void setPtt(bool on) {
    if (on && cannotTransmit != null) return;
    if (on) _radio._daxSwitch.beforePlainKey();
    _radio._key(this, on);
  }

  late final _so2rAudio = FlexSo2rAudio(slice: slice, host: () => meterHost, send: _radio._sendCommand);

  FlexSliceAudio get _sliceAudio => (pan: _radio._slices[slice]?.audioPan, mute: _radio._slices[slice]?.audioMute);

  @override
  void setSo2rEar(So2rEar? ear) {
    if (slice >= 0) _so2rAudio.set(ear, _sliceAudio);
  }

  /// How many more slices the radio can open, as it last said.
  int? get freeSlices => _radio.freeSlices;

  /// A new slice on HaLo's station ([FlexRadio.openSlice]); null where this
  /// slice is not on HaLo's station.
  Future<String?> openSlice() => _radio.openSlice();

  /// Renames HaLo's station on the radio, as every client lists it.
  void renameStation(String name) => _radio.renameStation(name);

  /// Closes this slice on the radio, where it is HaLo's own; whether the
  /// radio did.
  Future<bool> closeSlice() async {
    final letter = ownLetter;
    return letter != null && await _radio.closeSlice(letter);
  }

  @override
  bool get switchesToComputerAudio => true;

  /// Not once the UDP socket the audio goes on has failed to open — the web
  /// has none.
  @override
  bool get sendsTransmitAudio => _radio._sendsTransmitAudio;

  @override
  AudioOutput? openTransmitAudio(PcmDecoder decode) => _radio._openTransmitAudio(decode);

  /// DAX on for the message and off again after, unless the operator had it
  /// on already (flex_dax_switch.dart).
  @override
  void setPttWithComputerAudio(bool on, {void Function()? refused}) {
    if (on && cannotTransmit != null) {
      refused?.call();
      return;
    }
    if (on) {
      _radio._daxSwitch.beforeKey();
      _radio._key(this, true);
    } else {
      _radio._key(this, false);
      _radio._daxSwitch.afterUnkey();
    }
  }

  /// The memory length the entry pinned, or [voiceActivityCeiling]: what
  /// bounds a RECORDING, as a backstop to the radio's own ten-second limit.
  /// A play is bounded by its slot's own length instead.
  @override
  Duration get voiceMemoryCeiling => _radio.voiceMemoryCeiling;

  @override
  int get voiceMemoryCount => _radio._voiceMemoryCount;

  @override
  bool get canRecordVoice => true;

  @override
  void playVoiceMemory(int n) => _radio._playVoiceMemory(this, n);

  @override
  void recordVoiceMemory(int n) => _radio._recordVoiceMemory(this, n);

  /// Whichever slice started it: there is one DVK, which every slice shows
  /// playing, as [stopCw] stops the one CWX buffer.
  @override
  void stopVoice() => _radio.stopVoice();

  @override
  void renameVoiceMemory(int n, String name) => _radio._renameVoiceMemory(n, name);

  /// FlexRadio pushes status on its own — "starting updates" just means
  /// subscribing, which the radio does once for all its slices.
  @override
  void startUpdates() => _radio._start(this);

  @override
  void stopUpdates() => _radio._stop(this);

  /// Null: this radio pushes a slice status the moment the dial moves, so a
  /// quiet VFO is a still one.
  @override
  Duration? get expectedUpdateInterval => null;

  bool _left = false;

  /// What this slice set on the radio, put back as it leaves: its audio
  /// pan and mute, its spectrum's stream.
  void _leaveSlice() {
    if (_left) return;
    _left = true;
    _stopAudioStreams();
    if (slice >= 0) _so2rAudio.teardown(_sliceAudio);
    _spectrum.teardown();
    for (final scope in _extraScopes.toList()) {
      scope.teardown();
    }
    _extraScopes.clear();
  }

  @override
  void teardown() {
    _radio._release(this);
    _leaveSlice();
    _radio._detach(this);
    if (_ownsWire) _radio.teardown();
  }
}

/// Each of a slice's scopes, told what the connection hears: a copy of the
/// list each time, since a scope that fails is closed and leaves it.
class _FlexScopes {
  final FlexRadioSession _session;
  _FlexScopes(this._session);

  List<FlexSliceSpectrum> get _all => [_session._spectrum, ..._session._extraScopes];

  void _each(void Function(FlexSliceSpectrum scope) tell) {
    for (final scope in _all) {
      tell(scope);
    }
  }

  void subscribe() => _each((s) => s.subscribe());
  void socketReady() => _each((s) => s.socketReady());
  void socketLost() => _each((s) => s.socketLost());
  void socketUnavailable() => _each((s) => s.socketUnavailable());
  void panStatus(String id, Map<String, String> fields) => _each((s) => s.panStatus(id, fields));

  /// Whether any of them took it, every one being offered it.
  bool packet(Uint8List data) => _all.fold(false, (taken, s) => s.packet(data) || taken);
}

/// A slice's sweep beyond its own, as CatService holds it: closing it leaves
/// the slice's list.
class _FlexExtraScope implements SpectrumScope {
  final FlexPanSpectrum _scope;
  final void Function() _left;
  _FlexExtraScope(this._scope, this._left);

  @override
  bool setSpectrum(SpectrumRequest request) => _scope.setSpectrum(request);

  @override
  bool get turnedDown => _scope.turnedDown;

  @override
  void close() {
    _left();
    _scope.close();
  }
}
