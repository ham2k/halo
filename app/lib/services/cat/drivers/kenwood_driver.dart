// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks Kenwood CAT (see kenwood_cat_codec.dart) over an already-open
// connection — serial, or TCP for the K4. Like every driver here it deals
// only in already-framed bytes handed to it by a transport.
//
// The protocol comes from published CAT references rather than from a
// capture. It has since been run against real hardware — a QRP Labs QMX and
// QCX-mini, Elecraft's KX2 and KX3, and Kenwood's TS-590SG and TS-480. None
// of those reports recorded the TS-2000-era layout, which is where the
// references still carry the risk, and why the one field no document settles
// is learned from the radio instead of assumed.
//
// That field is the mode's position inside the `IF` status packet. The
// widths ahead of it differ between the TS-2000-era layout and the
// TS-480/590/890 one, and getting it wrong would not fail — it would report
// a plausible wrong mode, forever, silently. So `IF` is read for its
// frequency (whose offset is stable across the line) and for nothing else
// until an explicit `MD;` answer has confirmed where the mode lives.
// The named K4 uses its documented K31 status layout instead, including
// the DATA submode; its power ranges also require a separate codec.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../adaptive_poller.dart';
import '../telemetry_poller.dart';
import '../transports/config_field_helpers.dart';
import '../driver.dart';
import '../equipment.dart';
import '../spectrum.dart';
import 'cat_ascii_codec.dart';
import 'cw_send_queue.dart';
import 'kenwood_cat_codec.dart';
import 'k4_codec.dart';
import 'k4_spectrum.dart';
import 'kx3_iq_spectrum.dart';
import '../transports/iq_audio.dart';
import '../transports/iq_audio_errors.dart';
import '../transport.dart';
import '../../error_reporting_service.dart';
import 'keyer_config.dart';
import 'optional_read.dart';
import 'poll_config.dart';
import 'telemetry_config.dart';
import 'voice_activity_tracker.dart';

part 'k4_spectrum_session.dart';
part 'kx3_driver.dart';

class KenwoodDriver extends EquipmentDriver {
  const KenwoodDriver() : isK4 = false, lanSpectrum = false;
  const KenwoodDriver.k4({this.lanSpectrum = false}) : isK4 = true;

  /// Pinned by the model, never inferred from the optional voice dialect.
  final bool isK4;

  /// Pinned by the Ethernet pairing: a serial node can retain a saved host
  /// after switching variants, without that authorizing a second LAN link.
  final bool lanSpectrum;

  /// What most of the Kenwood line ships set to, and what its CAT menu calls
  /// 9600. Only a default — a mismatch answers with garbage and no error, so
  /// the operator has to be able to change it.
  static const defaultBaudRate = 9600;

  @override
  String get key => isK4 ? 'elecraft-k4' : 'kenwood';

  @override
  String get name => isK4 ? 'Elecraft K4 (CAT)' : 'Kenwood (CAT)';

  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder([
    ...kenwoodModeTable(modeDialectFrom(config)).keys,
    if (isK4) ...['DATA-USB', 'DATA-LSB', 'PSK'] else ...dataModeBases.keys,
  ]);

  /// A radio whose `IF` layout we DO know — a specific model built on this
  /// driver — pins the mode's offset here rather than letting the session
  /// work it out. Read straight from the config and never rendered as a
  /// field: it is a fact about the pairing, not a question for the operator,
  /// the same way the IC-705's network controller address is.
  ///
  /// Pinning it does not stop the session checking it. A declared offset that
  /// the radio contradicts is a mistake in OUR table, and the alternative to
  /// noticing is reporting wrong modes forever.
  static const ifModeOffsetKey = 'ifModeOffset';

  /// Which voice-memory dialect the radio speaks ([KenwoodVoiceDialect] by
  /// name) and how many memories it has — pinned per catalogue entry the
  /// way [ifModeOffsetKey] is, since the driver serves a whole line and a
  /// QMX has no voice keyer at all. Absent means none.
  static const voiceDialectKey = 'voiceDialect';
  static const voiceMemoriesKey = voiceMemoriesConfigKey;

  /// Which shape of `KY` keys CW ([KenwoodCwDialect] by name), pinned the
  /// same way. Absent — or a name no dialect answers to — keys nothing.
  static const cwDialectKey = 'cwDialect';

  /// Whether the radio has the `DA` DATA submode (the TS-590 generation),
  /// pinned per entry like the dialects above. Absent means none: on the K4
  /// `DA` is the digital-audio command, and on a radio without it every poll
  /// would ask a question it refuses.
  static const dataModeKey = 'dataMode';

  /// Which receive-filter commands the radio answers
  /// ([KenwoodPassbandDialect] by name), pinned per entry like the dialects
  /// above. Absent means the passband is neither read nor set. The K4 needs
  /// no pin — [isK4] is one.
  static const passbandDialectKey = 'passbandDialect';

  /// Which `AN` the radio answers for its own antenna ports
  /// ([KenwoodAntennaDialect] by name), pinned per entry like the dialects
  /// above. Absent means none is read or offered — a radio with one port
  /// shows no choice. Never the K4's: its `AN` is its own.
  static const antennaDialectKey = 'antennaDialect';

  /// Which `MD` table the radio speaks ([KenwoodModeDialect] by name), pinned
  /// per entry like the dialects above. Absent is Kenwood's own.
  static const modeDialectKey = 'modeDialect';

  static KenwoodModeDialect? modeDialectFrom(Map<String, dynamic> config) =>
      KenwoodModeDialect.values.where((d) => d.name == config[modeDialectKey]).firstOrNull;

  static KenwoodAntennaDialect? antennaDialectFrom(Map<String, dynamic> config) =>
      KenwoodAntennaDialect.values.where((d) => d.name == config[antennaDialectKey]).firstOrNull;

  static KenwoodPassbandDialect? passbandDialectFrom(Map<String, dynamic> config) =>
      KenwoodPassbandDialect.values.where((d) => d.name == config[passbandDialectKey]).firstOrNull;

  static KenwoodCwDialect? cwDialectFrom(Map<String, dynamic> config) => KenwoodCwDialect.values.where((d) => d.name == config[cwDialectKey]).firstOrNull;

  static KenwoodVoiceDialect? voiceDialectFrom(Map<String, dynamic> config) =>
      KenwoodVoiceDialect.values.where((d) => d.name == config[voiceDialectKey]).firstOrNull;

  /// A dialect named with no count — the developer picked one and left the
  /// other — takes the dialect's own: a `pb` TS-590 has four, a K4 eight, a
  /// KX two. A count is never more than the dialect can address.
  static int voiceMemoriesFrom(Map<String, dynamic> config) {
    final dialect = voiceDialectFrom(config);
    if (dialect == null) return 0;
    final own = switch (dialect) {
      KenwoodVoiceDialect.pb => 4,
      KenwoodVoiceDialect.k4 => maxVoiceMemories,
      KenwoodVoiceDialect.kx => kxVoiceMemoryCount,
    };
    final count = voiceMemoriesFromConfig(config, fallback: 0);
    return (count > 0 ? count : own).clamp(0, dialect == KenwoodVoiceDialect.kx ? kxVoiceMemoryCount : maxVoiceMemories);
  }

  /// A whole line on one driver, so the keyer is a fact about the entry —
  /// the named ones pin it, the generics ask under developer mode.
  @override
  bool canKeyCwWith(Map<String, dynamic> config) => cwDialectFrom(config) != null;

  @override
  int voiceMemoryCountWith(Map<String, dynamic> config) => voiceMemoriesFrom(config);

  @override
  Set<String> get recognizedConfigKeys => {
    ...super.recognizedConfigKeys,
    ifModeOffsetKey,
    cwDialectKey,
    voiceDialectKey,
    voiceMemoriesKey,
    voiceCeilingConfigKey,
    dataModeKey,
    passbandDialectKey,
    antennaDialectKey,
    modeDialectKey,
  };

  @override
  int get telemetryWatchBytes => kenwoodTxWatchBytes;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) {
    final modeOffset = switch (config[ifModeOffsetKey]) {
      final int offset when offset >= kenwoodFrequencyDigits => offset,
      _ => null,
    };
    final host = lanSpectrum ? trimmedHost(config) : '';
    if (lanSpectrum && host.isNotEmpty) {
      return K4SpectrumSession(
        sink,
        spectrum: K4Spectrum(host: host, sink: sink is SpectrumSink ? sink as SpectrumSink : null),
        declaredModeOffset: modeOffset,
        cwDialect: cwDialectFrom(config),
        voiceDialect: voiceDialectFrom(config),
        voiceMemories: voiceMemoriesFrom(config),
        voiceMemoryCeiling: voiceCeilingFromConfig(config),
        config: config,
      );
    }
    return KenwoodSession(
      sink,
      isK4: isK4,
      declaredModeOffset: modeOffset,
      cwDialect: cwDialectFrom(config),
      voiceDialect: voiceDialectFrom(config),
      voiceMemories: voiceMemoriesFrom(config),
      voiceMemoryCeiling: voiceCeilingFromConfig(config),
      dataMode: !isK4 && config[dataModeKey] == true,
      passbandDialect: switch (passbandDialectFrom(config)) {
        _ when isK4 => KenwoodPassbandDialect.elecraft,
        // Without `DA` the session cannot tell SSB-DATA from SSB, and the
        // TS-590SG gives each its own menu for what `SL`/`SH` mean.
        KenwoodPassbandDialect.ts590sg when config[dataModeKey] != true => null,
        final dialect => dialect,
      },
      antennaDialect: isK4 ? null : antennaDialectFrom(config),
      modeDialect: isK4 ? null : modeDialectFrom(config),
      config: config,
    );
  }

  /// The keyer facts, asked only where the entry did not pin them — the
  /// generic Kenwood and Elecraft — and only of a developer: which shape of
  /// `KY` the rig takes and which voice keyer it has are things the
  /// catalogue should know, and these fields are how it learns before an
  /// entry exists (docs/design/cat.md § Voice keying).
  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [
    if (!overrides.containsKey(cwDialectKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': cwDialectKey,
        'label': t.settings.station.cwDialect,
        'description': t.settings.station.cwDialectDescription,
        'devMode': true,
        'options': [
          {'value': '', 'label': t.settings.station.keyerNone},
          {'value': KenwoodCwDialect.kenwood.name, 'label': t.settings.station.cwDialectKenwood},
          {'value': KenwoodCwDialect.elecraft.name, 'label': t.settings.station.cwDialectElecraft},
        ],
      },
    if (!overrides.containsKey(voiceDialectKey))
      {
        'type': 'field',
        'fieldType': 'select',
        'key': voiceDialectKey,
        'label': t.settings.station.voiceDialect,
        'description': t.settings.station.voiceDialectDescription,
        'devMode': true,
        'options': [
          {'value': '', 'label': t.settings.station.keyerNone},
          {'value': KenwoodVoiceDialect.pb.name, 'label': t.settings.station.voiceDialectPb},
          {'value': KenwoodVoiceDialect.k4.name, 'label': t.settings.station.voiceDialectK4},
          {'value': KenwoodVoiceDialect.kx.name, 'label': t.settings.station.voiceDialectKx},
        ],
      },
    if (!overrides.containsKey(voiceMemoriesKey)) voiceMemoriesConfigElement(),
    telemetryConfigElement(),
    pollConfigElement(),
  ];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => switch (key) {
    voiceMemoriesKey => validateVoiceMemories(value),
    telemetryIntervalConfigKey => validateTelemetryInterval(value),
    pollIntervalConfigKey => validatePollInterval(value),
    _ => null,
  };
}

/// `IF;` out, and the ~38-byte status packet back — much the largest TX
/// watch of any driver here, because Kenwood is the only line with no
/// narrow question to ask (its `TX;` keys the radio).
const kenwoodTxWatchBytes = 41;

/// How many state polls go by between reads of the tuner: at the default
/// idle poll, one every fifteen seconds. The tuner moves when someone presses
/// a button, and a read on every poll would spend the link's time on an
/// answer that is almost always the last one again.
const kenwoodTunerReadEvery = 5;

/// How many state polls go by between reads of the receive filter — the
/// tuner's rate, for the tuner's reason. A mode change, the one time the
/// filter moves on its own, reads it at once.
const kenwoodPassbandReadEvery = 5;

/// How many state polls go by between reads of the antenna ports — the
/// tuner's rate, for the tuner's reason.
const kenwoodAntennaReadEvery = 5;

class KenwoodSession
    implements TransceiverSession, CwKeyerSession, VoiceKeyerSession, PttSession, AntennaTunerSession, PassbandSession, RadioAntennaSession, RawCommandSession {
  final EquipmentSink _sink;
  final bool isK4;
  num? _pendingK4Power;
  Timer? _k4PowerTimeout;

  /// Set while the `PCX;` that follows a refused or expired power write is
  /// outstanding: that reply restores the app's value but must not also clear
  /// the refusal it was sent with — the next one does.
  bool _k4PowerResync = false;
  int? _k4Band;

  /// One diagnostic per connection: a status reply outside the K31 layout
  /// leaves mode and transmit state unreported, and nothing else says so.
  bool _k4InfoRejected = false;

  /// GPS sentences dropped for the TX-500 line: the LiNK500MP made for it
  /// can interleave its receiver's NMEA with the radio's CAT on one channel.
  late final _framer = KenwoodFramer(dropsNmea: modeDialect == KenwoodModeDialect.lab599);

  /// Auto-Information is the primary path; this covers what it can't — the
  /// radio's AI menu switched off, or a frame lost to line noise.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestState, slow: idlePollIntervalFor(_config));

  /// Watches for the operator to key the rig, by asking for the `IF` packet
  /// that carries the flag — see [_handleInfo].
  ///
  /// The watch has no meter half. Kenwood's meter reads (`RM`) require
  /// SELECTING which meter the radio displays, so reading SWR would change
  /// what is on the operator's own front panel; and the scale behind the
  /// answer is unpublished besides. That is a bench question, not a
  /// guess-in-code one, so this driver declares no meters at all.
  late final TelemetryPoller _telemetry = TelemetryPoller(
    onPoll: (_) => _send(buildKenwoodReadInfoCommand()),
    idleInterval: telemetryIntervalFor(_config, cycleBytes: _txWatchBytes, baudRate: serialBaudRateOrNull(_config)),
    txInterval: telemetryIntervalFor(_config, cycleBytes: _txWatchBytes, baudRate: serialBaudRateOrNull(_config)),
  );

  /// `IF;` out, and the ~38-byte status packet back — much the largest TX
  /// watch of any driver here, because it is the only one that cannot ask
  /// the narrow question.
  static const _txWatchBytes = kenwoodTxWatchBytes;

  /// What was last reported upward, so a repeat can be told from a move.
  VfoReading? _lastReported;

  /// What a specific radio's definition says its `IF` layout is, if anything.
  /// Used from the first packet — but still checked, see [_learnModeOffset].
  final int? declaredModeOffset;

  /// Where the mode sits inside an `IF` packet: declared, or confirmed by
  /// watching. Null means neither, and the session keeps reading mode from
  /// `MD;` — correct, just slower.
  int? _modeOffset;

  /// The mode code from the most recent `MD;` answer, held only until the
  /// next `IF` arrives to be measured against it. Cleared once used, so a
  /// stale reading can never confirm an offset for a mode the radio has
  /// since left.
  String? _pendingModeCode;

  /// How many separate `IF` packets have agreed on [_modeOffset]-to-be.
  /// One agreement is not enough: a mode code is a single character, and on
  /// any given packet several fields can happen to hold it. Requiring two
  /// sightings of the SAME position, each against a fresh `MD;`, is what
  /// makes a coincidence unlikely rather than merely improbable.
  int _offsetAgreements = 0;
  int? _candidateOffset;

  /// Nothing left to decide — learned and confirmed, declared and confirmed,
  /// or declared and contradicted. Stops the per-packet scan for the rest of
  /// the connection; a radio does not change its own `IF` layout mid-session.
  bool _settled = false;

  /// Whether [startUpdates] has run. [teardown] goes through [stopUpdates],
  /// which would otherwise write to a connection this session never
  /// configured — a superseded handshake, or an immediate disconnect.
  bool _started = false;

  static const _agreementsNeeded = 2;

  /// See [KenwoodDriver.cwDialectKey]. Null keys nothing: the session still
  /// implements [CwKeyerSession] — one class serves the line — and the
  /// service reads [EquipmentDriver.canKeyCwWith] before offering it.
  final KenwoodCwDialect? cwDialect;

  /// What the radio last said its keyer runs at — the pace [_cwQueue]
  /// spaces chunks by.
  int? _keyerSpeed;

  /// `KY` takes 24 characters and `KY;` only says whether the buffer is
  /// full, never when it empties — so the queue paces by arithmetic like
  /// the Icom and Yaesu sessions do (cw_send_queue.dart).
  late final CwSendQueue _cwQueue = CwSendQueue(
    maxChunkLength: kenwoodKeyerMaxChars,
    send: (chunk) {
      final dialect = cwDialect;
      if (dialect != null) _send(buildKenwoodSendCwCommand(dialect, chunk));
    },
    speedWpm: () => _keyerSpeed,
    onProgress: _sink.reportCwProgress,
  );

  /// See [KenwoodDriver.voiceDialectKey]. Null with no voice keyer, in which
  /// case [voiceMemoryCount] is zero whatever was declared.
  final KenwoodVoiceDialect? voiceDialect;
  final int _voiceMemories;

  @override
  final Duration voiceMemoryCeiling;

  /// Each dialect has its own "still going?": `PB;` on a Kenwood, `DA;` on
  /// the K4, `TQ;` (transmitting?) on a KX — see voice_activity_tracker.dart.
  late final VoiceActivityTracker _voice = VoiceActivityTracker(
    report: _sink.reportVoiceActivity,
    stop: stopVoice,
    ceiling: () => voiceMemoryCeiling,
    onCeiling: (limit) => _sink.reportDiagnostic('voice memory stopped at the ${limit.inSeconds} s ceiling'),
    poll: () {
      final command = switch (voiceDialect) {
        KenwoodVoiceDialect.pb => buildKenwoodReadVoicePlaybackCommand(),
        KenwoodVoiceDialect.k4 => buildK4ReadDigitalAudioCommand(),
        KenwoodVoiceDialect.kx => buildElecraftReadTransmitQueryCommand(),
        null => null,
      };
      if (command != null) _send(command);
    },
  );

  KenwoodSession(
    this._sink, {
    this.isK4 = false,
    this.declaredModeOffset,
    this.cwDialect,
    this.voiceDialect,
    this._voiceMemories = 0,
    this.voiceMemoryCeiling = voiceActivityCeiling,
    this.dataMode = false,
    this.passbandDialect,
    this.antennaDialect,
    this.modeDialect,
    Map<String, dynamic> config = const {},
  }) : _modeOffset = declaredModeOffset,
       // ignore: prefer_initializing_formals
       _config = config;

  /// The node's merged config, kept for [_telemetry]'s cadence.
  final Map<String, dynamic> _config;

  /// See [KenwoodDriver.dataModeKey].
  final bool dataMode;

  /// See [KenwoodDriver.modeDialectKey].
  final KenwoodModeDialect? modeDialect;

  /// Whether a [KenwoodModeDialect.lab599] radio's CAT menu is on the LAB599
  /// protocol, from its `ID;` answer. Null until it answers. Only that
  /// protocol has a command for DIG: on TS-2000 a DIG request is sent as its
  /// USB base, as on a radio without a DATA submode.
  bool? _lab599Protocol;

  bool get _digSettable => modeDialect == KenwoodModeDialect.lab599 && _lab599Protocol == true;

  /// Whether the DATA submode was last reported on, and the base mode it was
  /// last reported against — `MD` and `IF` never say DATA, so [_withData]
  /// combines them.
  bool _dataOn = false;
  String? _baseMode;

  String? _withData(String? mode) {
    if (mode == null || !dataMode) return mode;
    _baseMode = mode;
    return modeNameWithData(mode, data: _dataOn);
  }

  /// Where the mode is being read from, whether that was declared by the
  /// radio's own definition or worked out here — [declaredModeOffset] is what
  /// tells the two apart. Null means neither, and mode comes from `MD;`.
  ///
  /// Exposed for the developer-mode readout: a rig that defeats detection can
  /// then be diagnosed from a screenshot rather than a bench session.
  int? get modeOffset => _modeOffset;

  /// The cadence the poller has settled on — for tests, which otherwise
  /// could only infer it from timing.
  Duration get pollInterval => _poller.interval;

  /// This session polls, so a quiet VFO is only settled once a poll has come
  /// and gone without a change. Auto-Information rides on top of that and
  /// only ever makes readings arrive sooner, never later, so the poll cadence
  /// is the honest upper bound.
  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  void _send(String command) => _sink.send(ascii.encode(command));

  /// An extension's raw commands, written as given: every answer names the
  /// command it answers, so none is taken for another's.
  @override
  int? sendRaw(List<int> bytes, {void Function(List<int> answer)? onAnswer}) {
    _rawGrace.sent();
    _sink.send(bytes);
    return null;
  }

  final _rawGrace = RawRefusalGrace();

  /// `IF` is in here, not only in [startUpdates], and that is what makes the
  /// offset learnable at all. It needs an `IF` paired with a FRESH `MD`
  /// answer, and the two ways those arrive are mutually exclusive: while
  /// Auto-Information is pushing, [AdaptivePoller] sees data and defers, so
  /// no `MD` is asked for; when the radio is quiet enough to poll, it is by
  /// definition not pushing. Asking for all three together is the only way
  /// the pair reliably occurs — otherwise the single `IF` from startUpdates
  /// is the only one that ever arrives on a radio with AI switched off.
  void _requestState() {
    if (isK4) {
      _send('IF;PCX;');
      _requestPassband();
      return;
    }
    // DATA first: `MD` and `IF` are reported against the flag as it stands,
    // and a flag read after them would report the base mode alone in between.
    if (dataMode) _send(buildKenwoodReadDataModeCommand());
    _send(buildKenwoodReadFrequencyCommand());
    _send(buildKenwoodReadModeCommand());
    _send(buildKenwoodReadInfoCommand());
    _send(buildKenwoodReadPowerCommand());
    _requestTuner();
    _requestPassband();
    _requestAntennas();
  }

  /// The last `AC` answer, and with it the receive-side AT [setTuner] hands
  /// back unchanged. Null until the radio has answered in Kenwood's shape —
  /// which is also what lets [setTuner] write on a radio whose `AC` means
  /// something else, or nothing: it never does.
  ({bool rxInline, bool txInline, bool tuning})? _tunerFlags;

  int _tunerPollsToSkip = 0;

  /// `AC;`, judged by the `?;`s heard while it is out with no `AC` answer
  /// back. Only the pair says "refused": a `?;` alone may answer any other
  /// question in the same poll, and an `AC` answer arriving after it proves
  /// it did.
  late final _tunerRead = OptionalRead(
    _sink,
    'radio refuses AC; no antenna tuner, not asked again',
    onGiveUp: () {
      _tunerFlags = null;
      _reportTuner(null);
    },
  );

  /// Every [kenwoodTunerReadEvery]th poll, first thing on a connection. The
  /// previous read is judged when the next falls due — by then its answer
  /// has long arrived if it was ever coming.
  void _requestTuner() {
    if (!_tunerRead.available) return;
    if (_tunerPollsToSkip > 0) {
      _tunerPollsToSkip--;
      return;
    }
    _tunerPollsToSkip = kenwoodTunerReadEvery - 1;
    if (_tunerRead.judge()) _readTuner();
  }

  void _readTuner() {
    _tunerRead.sent();
    _send(buildKenwoodReadTunerCommand());
  }

  void _reportTuner(TunerStatus? status) {
    if (_sink case final TunerSink sink) sink.reportTuner(status);
  }

  /// See [KenwoodDriver.passbandDialectKey]. Null reads and sets nothing.
  final KenwoodPassbandDialect? passbandDialect;

  /// The filter as the radio last answered, in the mode now in use: width
  /// (`BW`, or `FW` in CW on the TS-590SG), AF centre (`IS`) and the TS-590SG's
  /// `SL`/`SH` indexes. Cleared on a mode change — the same number means
  /// another thing in another mode.
  int? _filterWidthHz;
  int? _filterCentreHz;
  int? _lowCutIndex;
  int? _highCutIndex;

  /// Settings that hold across modes: the CW pitch, and the TS-590SG's
  /// choice of what `SL`/`SH` mean in SSB and in SSB-DATA (true: width/shift).
  int? _cwPitchHz;
  bool? _ssbWidthShift;
  bool? _ssbDataWidthShift;

  /// What [_reportPassband] last said, and whether it has said anything.
  Passband? _passband;
  bool _passbandReported = false;

  int _passbandPollsToSkip = 0;

  /// The same refusal bookkeeping as the tuner's — see [_tunerRead].
  late final _passbandRead = OptionalRead(_sink, 'radio refuses its filter reads; passband not asked again', onGiveUp: _reportPassband);

  /// Every [kenwoodPassbandReadEvery]th poll, never while transmitting: the
  /// K3 line answers `?;` to commands it will not handle on the air, and two
  /// of those would stop the reads for the connection.
  void _requestPassband() {
    if (passbandDialect == null || !_passbandRead.available || _telemetry.transmitting) return;
    if (_passbandPollsToSkip > 0) {
      _passbandPollsToSkip--;
      return;
    }
    _passbandPollsToSkip = kenwoodPassbandReadEvery - 1;
    if (_passbandRead.judge()) _readPassband();
  }

  /// Only the questions the current mode answers — the TS-590SG refuses `IS`
  /// and `FW` in SSB, an Elecraft `IS` in FM — so a refusal is never just a
  /// mode without a passband.
  void _readPassband() {
    final reads = _passbandReads(_lastReported?.mode);
    if (reads.isEmpty) {
      _passbandRead.cancel();
    } else {
      _passbandRead.sent();
    }
    reads.forEach(_send);
  }

  List<String> _passbandReads(String? mode) => switch ((passbandDialect, mode)) {
    (KenwoodPassbandDialect.elecraft, 'USB' || 'LSB') => [buildElecraftReadBandwidthCommand(), buildKenwoodReadShiftCommand()],
    (KenwoodPassbandDialect.elecraft, 'CW' || 'CW-R') => [buildElecraftReadBandwidthCommand(), buildKenwoodReadShiftCommand(), buildElecraftReadPitchCommand()],
    (KenwoodPassbandDialect.ts590sg, 'USB' || 'LSB' || 'DATA-USB' || 'DATA-LSB') => [
      buildKenwoodReadMenuCommand(mode!.startsWith('DATA') ? ts590sgSsbDataFilterMenu : ts590sgSsbFilterMenu),
      buildKenwoodReadLowCutCommand(),
      buildKenwoodReadHighCutCommand(),
    ],
    (KenwoodPassbandDialect.ts590sg, 'CW' || 'CW-R') => [
      buildKenwoodReadFilterWidthCommand(),
      buildKenwoodReadShiftCommand(),
      buildKenwoodReadMenuCommand(ts590sgCwPitchMenu),
    ],
    _ => const [],
  };

  /// Any answer proves the radio takes the filter reads, whatever refusals
  /// were taken for a lack of them before.
  void _passbandAnswered() {
    _passbandRead.reset();
    _reportPassband();
  }

  void _passbandModeChanged() {
    if (passbandDialect == null) return;
    _filterWidthHz = null;
    _filterCentreHz = null;
    _lowCutIndex = null;
    _highCutIndex = null;
    _reportPassband();
    if (_passbandRead.available) _readPassband();
  }

  /// The passband in the current mode, where the readings place it:
  ///
  /// - SSB: the AF passband IS the offset from the carrier — above it in USB,
  ///   mirrored below in LSB. The TS-590SG's SSB-DATA too; the Elecraft DATA
  ///   modes are not, their centre moving with a pitch and the displayed
  ///   frequency's meaning moving with the submode.
  /// - CW: only while the filter's AF centre sits on the pitch, which puts it
  ///   centred on the tuned frequency whichever side the radio receives on.
  ///   Shifted, the side decides where it lies, and neither reference says
  ///   which side `CW` and `CW-R` are.
  /// - Anything else: null, no reference placing it.
  Passband? _passbandNow() {
    final mode = _lastReported?.mode;
    if (!_passbandRead.available || mode == null) return null;
    if (mode == 'CW' || mode == 'CW-R') {
      final width = _filterWidthHz;
      if (width == null || _filterCentreHz == null || _filterCentreHz != _cwPitchHz) return null;
      return _around(0, width);
    }
    final base = dataModeBases[mode] ?? mode;
    if (base != 'USB' && base != 'LSB') return null;
    final audio = switch (passbandDialect) {
      KenwoodPassbandDialect.elecraft when base == mode => _around(_filterCentreHz, _filterWidthHz),
      KenwoodPassbandDialect.ts590sg => _ts590sgSsbAudio(data: base != mode),
      _ => null,
    };
    if (audio == null) return null;
    return base == 'LSB' ? Passband(-audio.highHz, -audio.lowHz) : audio;
  }

  static Passband? _around(int? centre, int? width) {
    if (centre == null || width == null) return null;
    final low = centre - width ~/ 2;
    return Passband(low, low + width);
  }

  Passband? _ts590sgSsbAudio({required bool data}) {
    final widthShift = data ? _ssbDataWidthShift : _ssbWidthShift;
    final low = _lowCutIndex, high = _highCutIndex;
    if (widthShift == null || low == null || high == null) return null;
    if (widthShift) return _around(ts590sgShiftsHz.elementAtOrNull(high), ts590sgWidthsHz.elementAtOrNull(low));
    final lowHz = ts590sgLowCutsHz.elementAtOrNull(low), highHz = ts590sgHighCutsHz.elementAtOrNull(high);
    return lowHz == null || highHz == null ? null : Passband(lowHz, highHz);
  }

  /// Only on a change, like the tuner: the poll restates the filter every
  /// few seconds.
  void _reportPassband() {
    final passband = _passbandNow();
    if (_passbandReported && passband == _passband) return;
    _passbandReported = true;
    _passband = passband;
    if (_sink case final PassbandSink sink) sink.reportPassband(passband);
  }

  /// See [KenwoodDriver.antennaDialectKey]. Null reads and sets nothing.
  final KenwoodAntennaDialect? antennaDialect;

  /// The ports as the radio last answered `AN` in [antennaDialect]'s shape.
  /// Null until it has — which is what keeps [setAntenna] from writing to a
  /// radio whose `AN` is not known to be this one.
  RadioAntennas? _antennas;

  int _antennaPollsToSkip = 0;

  /// The same refusal bookkeeping as the tuner's — see [_tunerRead].
  late final _antennaRead = OptionalRead(
    _sink,
    'radio refuses AN; antenna ports not asked again',
    onGiveUp: () {
      _antennas = null;
      _reportAntennas(null);
    },
  );

  /// Every [kenwoodAntennaReadEvery]th poll, never while transmitting — the
  /// passband's reason: a K3-line `?;` on the air would count as a refusal.
  void _requestAntennas() {
    if (antennaDialect == null || !_antennaRead.available || _telemetry.transmitting) return;
    if (_antennaPollsToSkip > 0) {
      _antennaPollsToSkip--;
      return;
    }
    _antennaPollsToSkip = kenwoodAntennaReadEvery - 1;
    if (_antennaRead.judge()) _readAntennas();
  }

  void _readAntennas() {
    _antennaRead.sent();
    _send(buildKenwoodReadAntennaCommand());
  }

  void _reportAntennas(RadioAntennas? antennas) {
    if (_sink case final RadioAntennaSink sink) sink.reportAntennas(antennas);
  }

  /// `AN`'s answer as ports, or null when it is not in [antennaDialect]'s
  /// shape.
  ///
  /// The TS-590 transmits on ANT1 or ANT2 and receives there too unless its
  /// RX ANT jack is switched in. So it is [RadioAntennas.separate], but its
  /// receive choice is only ever the transmit port or RX ANT: offering the
  /// other transmit port for receive would offer a pairing it cannot make.
  RadioAntennas? _parseAntennas(String params) {
    switch (antennaDialect) {
      case KenwoodAntennaDialect.twoPort:
        final port = parseKenwoodAntennaParams(params);
        if (port == null) return null;
        final name = kenwoodAntennaPorts[port - 1];
        return RadioAntennas(rxPorts: kenwoodAntennaPorts, txPorts: kenwoodAntennaPorts, rx: name, tx: name);
      case KenwoodAntennaDialect.ts590:
        final answer = parseTs590AntennaParams(params);
        if (answer == null) return null;
        final tx = kenwoodAntennaPorts[answer.port - 1];
        return RadioAntennas(
          rxPorts: [tx, ts590RxAntennaPort],
          txPorts: kenwoodAntennaPorts,
          rx: answer.rxAntenna ? ts590RxAntennaPort : tx,
          tx: tx,
          separate: true,
        );
      case null:
        return null;
    }
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    if (isK4 && reading.freqKHz != null) _k4Band = k4BandNumber(reading.freqKHz!);
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The FIRST reading is the answer to the question startUpdates just
    // asked, not the radio moving — counting it as movement would drop every
    // connection into fast polling for a radio nobody is touching.
    final first = _lastReported == null;
    final modeChanged = merged.mode != _lastReported?.mode;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
    if (modeChanged) _passbandModeChanged();
  }

  @override
  void handleData(Uint8List chunk) {
    // Anything at all defers the next poll — the radio has just told us
    // something, so asking now would repeat a question we have the answer to.
    _poller.noteData();
    // ASCII, and `allowInvalid` because a line-noise byte on a serial link
    // must not throw out of a stream callback; the framer simply will not
    // match it as a command.
    final text = ascii.decode(chunk, allowInvalid: true);
    // Before the framer, which drops `?;` — it has no letters to frame.
    // Not on the air: the K3 line answers `?;` to commands it will not handle
    // while transmitting, which says nothing about whether it has them.
    if (!_telemetry.transmitting && !_rawGrace.active && text.contains(kenwoodRefusal)) {
      _tunerRead.heardRefusal();
      _passbandRead.heardRefusal();
      _antennaRead.heardRefusal();
    }
    for (final command in _framer.add(text)) {
      _handle(command);
    }
  }

  void _handle(AsciiCatCommand command) {
    switch (command.command) {
      case 'FA':
        final freqHz = parseKenwoodFrequencyParams(command.params);
        // The radio reports exact Hz; everything above here speaks kHz.
        if (freqHz != null) _report(VfoReading(freqKHz: freqHz / 1000));

      case 'MD':
        if (isK4) {
          // MD has no DATA submode. Ask for the complete snapshot instead
          // of publishing a mode guessed from an old DT answer.
          if (RegExp(r'^[1-79]$').hasMatch(command.params)) _send('IF;');
          return;
        }
        final mode = parseKenwoodModeParams(command.params, dialect: modeDialect);
        if (mode == null) return;
        // The raw code, not one rebuilt from the name: `params` IS what the
        // radio sent, and round-tripping it through the name map would go
        // wrong the day two names share a code.
        _pendingModeCode = command.params;
        _report(VfoReading(mode: _withData(mode)));

      case 'IF':
        _handleInfo(command.params);

      case 'DT':
        if (isK4 && RegExp(r'^[0-3]$').hasMatch(command.params)) _send('IF;');

      case 'PC':
        if (isK4) {
          final power = parseK4Power(command.params);
          if (power == null) return;
          _sink.reportPower(power.watts);
          final pending = _pendingK4Power;
          _pendingK4Power = null;
          _k4PowerTimeout?.cancel();
          if (pending == null) {
            // Any later answer proves the radio is taking power commands, so a
            // refusal or timeout does not outlive it.
            if (_k4PowerResync) {
              _k4PowerResync = false;
            } else {
              _sink.reportProblem(null);
            }
          } else {
            final write = buildK4SetPowerCommand(pending, transverter: power.transverter);
            if (write == null) {
              _sink.reportProblem(t.settings.station.k4PowerRange);
            } else {
              _sink.reportProblem(null);
              _send(write);
              _send('PCX;');
            }
          }
          return;
        }
        final watts = parseKenwoodPowerParams(command.params);
        if (watts != null) _sink.reportPower(watts);

      case 'KS':
        if (cwDialect == null) return;
        final wpm = parseKenwoodKeyerSpeedParams(command.params);
        if (isK4 && wpm != null && (wpm < 8 || wpm > 100)) return;
        if (wpm != null) {
          _keyerSpeed = wpm;
          _sink.reportKeyerSpeed(wpm);
        }

      // Answers to [_voice]'s polls, each dialect its own: "going" confirms,
      // "not going" ends — a refusal when nothing confirmed first.
      case 'PB':
        if (voiceDialect != KenwoodVoiceDialect.pb) return;
        final channel = parseKenwoodVoicePlaybackParams(command.params);
        if (channel == null) return;
        _voicePollSays(going: channel != 0);
      case 'DA':
        if (dataMode) {
          final on = parseKenwoodDataModeParams(command.params);
          if (on == null || on == _dataOn) return;
          _dataOn = on;
          final base = _baseMode;
          if (base != null) _report(VfoReading(mode: modeNameWithData(base, data: on)));
          return;
        }
        // Only the K4's: on a Kenwood `DA` is the DATA-mode command, whose
        // `DA0;` would otherwise read as "idle" and end a memory on the air.
        if (voiceDialect != KenwoodVoiceDialect.k4) return;
        final state = parseK4DigitalAudioParams(command.params);
        final activity = _voice.activity;
        if (state == null || activity == null) return;
        _voicePollSays(going: activity.recording ? state.recording : state.playing);
      case 'AC':
        // Never asked of the K4, whose command set is its own.
        if (isK4) return;
        final flags = parseKenwoodTunerParams(command.params);
        if (flags == null) return;
        _tunerFlags = flags;
        // A radio that answers has a tuner, whatever refusals were taken for
        // one before.
        _tunerRead.reset();
        // Only the transmit side counts as in line: the receive-side AT alone
        // matches nothing the transmitter sees.
        _reportTuner(
          flags.tuning
              ? TunerStatus.tuning
              : flags.txInline
              ? TunerStatus.inline
              : TunerStatus.bypassed,
        );

      case 'AN':
        final antennas = _parseAntennas(command.params);
        if (antennas == null) return;
        _antennas = antennas;
        _antennaRead.reset();
        _reportAntennas(antennas);

      // The receive filter, each answer only in the dialect that asks for it:
      // the same letters elsewhere carry other units, or other meanings.
      case 'BW' when passbandDialect == KenwoodPassbandDialect.elecraft:
        final hz = parseElecraftBandwidthParams(command.params);
        if (hz == null) return;
        _filterWidthHz = hz;
        _passbandAnswered();
      case 'CW' when passbandDialect == KenwoodPassbandDialect.elecraft:
        final hz = parseElecraftPitchParams(command.params);
        if (hz == null) return;
        _cwPitchHz = hz;
        _passbandAnswered();
      case 'IS' when passbandDialect != null:
        final hz = parseKenwoodShiftParams(command.params, k4: isK4);
        if (hz == null) return;
        _filterCentreHz = hz;
        _passbandAnswered();
      case 'FW' when passbandDialect == KenwoodPassbandDialect.ts590sg:
        final hz = parseKenwoodFilterWidthParams(command.params);
        if (hz == null) return;
        _filterWidthHz = hz;
        _passbandAnswered();
      case 'SL' || 'SH' when passbandDialect == KenwoodPassbandDialect.ts590sg:
        final index = parseKenwoodCutIndexParams(command.params);
        if (index == null) return;
        if (command.command == 'SL') {
          _lowCutIndex = index;
        } else {
          _highCutIndex = index;
        }
        _passbandAnswered();
      case 'EX' when passbandDialect == KenwoodPassbandDialect.ts590sg:
        final menu = parseKenwoodMenuParams(command.params);
        if (menu == null) return;
        // Settings outside the guide's lists are not guessed at.
        switch (menu.menu) {
          case ts590sgSsbFilterMenu when menu.value <= 1:
            _ssbWidthShift = menu.value == 1;
          case ts590sgSsbDataFilterMenu when menu.value <= 1:
            _ssbDataWidthShift = menu.value == 1;
          case ts590sgCwPitchMenu when menu.value <= 14:
            _cwPitchHz = 300 + 50 * menu.value;
          default:
            return;
        }
        _passbandAnswered();
      case 'ID' when modeDialect == KenwoodModeDialect.lab599:
        _lab599Protocol = lab599ProtocolIds.contains(command.params);
        _sink.reportDiagnostic('CAT protocol ${_lab599Protocol! ? 'LAB599' : 'TS-2000, no DIG'} (ID${command.params})');
      case 'ER':
        if (isK4) _sink.reportDiagnostic('K4 refused a command: ER${command.params}');
      case 'TQ':
        if (voiceDialect != KenwoodVoiceDialect.kx) return;
        final transmitting = parseElecraftTransmitQueryParams(command.params);
        if (transmitting == null) return;
        _voicePollSays(going: transmitting);
    }
    // Everything else is an acknowledgement or something we don't track;
    // ignoring them is what lets AI mode be noisy without harm.
  }

  void _handleInfo(String params) {
    if (isK4) {
      final info = parseK4Info(params);
      if (info == null) {
        if (!_k4InfoRejected) _sink.reportDiagnostic('K4 IF reply not in the K31 layout: "$params"');
        _k4InfoRejected = true;
        return;
      }
      _report(VfoReading(freqKHz: info.freqHz / 1000, mode: info.mode));
      if (_telemetry.noteTransmitting(info.transmitting)) _sink.reportTransmitting(info.transmitting);
      return;
    }
    // Always safe: the eleven-digit frequency opens the packet on every
    // generation of the line.
    final freqHz = parseKenwoodInfoFrequency(params);
    final learned = _modeOffset;
    final mode = learned == null ? null : _withData(parseKenwoodInfoModeAt(params, learned, dialect: modeDialect));

    if (freqHz != null || mode != null) {
      _report(VfoReading(freqKHz: freqHz == null ? null : freqHz / 1000, mode: mode));
    }

    // The transmit flag rides in the same packet, one character ahead of the
    // mode — the only way to ask a Kenwood, whose `TX;` is the command that
    // keys the radio rather than a question about it. Only once the mode
    // offset is known, because that is what locates it: an unlearned layout
    // reports nothing rather than a character read from the wrong place.
    if (learned != null) {
      final transmitting = parseKenwoodInfoTransmittingBeforeMode(params, learned);
      if (transmitting != null && _telemetry.noteTransmitting(transmitting)) {
        _sink.reportTransmitting(transmitting);
      }
    }

    // Not `if (learned == null)`: a DECLARED offset arrives already set, and
    // gating on that would skip the very check that makes declaring one safe.
    _checkModeOffset(params);
  }

  /// Uses the radio as its own oracle: a `MD;` answer says what the mode IS,
  /// so the position holding that code in a packet from the same moment is
  /// where the mode lives.
  ///
  /// Learns when nothing was declared, polices when something was, and does
  /// nothing once a learned offset has settled.
  void _checkModeOffset(String params) {
    if (_settled) return;
    final code = _pendingModeCode;
    if (code == null) return;
    // Spent either way — a second IF must be matched against a fresh MD, or
    // two packets from one reading would "agree" without proving anything.
    _pendingModeCode = null;

    final offset = kenwoodModeOffsetIn(params, code);
    // Ambiguous (several fields hold that character) or absent: learn
    // nothing. Mode keeps coming from MD, which is correct, just slower.
    if (offset == null) return;

    final declared = declaredModeOffset;
    if (declared != null) {
      // Not learning any more — policing. A radio that contradicts what its
      // own definition claims is reporting the wrong mode right now, and this
      // is the only place that could ever notice.
      if (offset != declared) {
        _sink.reportDiagnostic('IF mode offset $declared declared, radio says $offset');
        // The declared index must not be read again. Noticing a wrong
        // declaration and going on parsing at it is the failure policing
        // exists to prevent: an index that happens to hold a valid mode code
        // reports a plausible wrong mode for the rest of the connection, with
        // one developer-only line as the only trace. Mode falls back to `MD;`
        // — correct, just slower — and this packet's own reading is corrected
        // from where the radio says the mode actually is, so the wrong one
        // just reported upward does not stand until the next poll.
        _modeOffset = null;
        _report(VfoReading(mode: _withData(parseKenwoodInfoModeAt(params, offset, dialect: modeDialect))));
        // Said once and done: the layout does not change mid-session, so
        // re-deciding it on every packet forever would add nothing.
        _settled = true;
        return;
      }
      // Enough agreements and the declaration is confirmed; stop scanning
      // every packet for the rest of the connection.
      if (++_offsetAgreements >= _agreementsNeeded) _settled = true;
      return;
    }

    if (offset != _candidateOffset) {
      _candidateOffset = offset;
      _offsetAgreements = 1;
      return;
    }
    if (++_offsetAgreements >= _agreementsNeeded) {
      _modeOffset = offset;
      _settled = true;
      _sink.reportDiagnostic('IF mode offset $offset (learned)');
    }
  }

  @override
  void setFrequency(double freqKHz) {
    if (isK4) {
      final band = k4BandNumber(freqKHz);
      // FA alone can strand VFO B above the TX low-pass filter (ER04).
      // Select the band as the front-panel BAND control does before tuning.
      if (band != null && band != _k4Band) _send('BN${band.toString().padLeft(2, '0')};');
      // CatService sends frequency, mode, frequency on a band change. Do
      // not recall the band again between the mode and that final frequency.
      _k4Band = band;
    }
    _send(buildKenwoodSetFrequencyCommand((freqKHz * 1000).round()));
  }

  @override
  void setMode(String mode) {
    if (isK4) {
      final command = buildK4SetModeCommand(mode);
      if (command != null) {
        _send(command);
        _send('IF;');
      }
      return;
    }
    // A data mode is its base mode with the DATA submode on; a radio without
    // one is at least put in the base mode, rather than left in whatever a
    // band recall brought back.
    // DIG is a mode of its own in the LAB599 protocol, not a base plus a
    // submode.
    final ownCode = _digSettable && kenwoodCodeForMode(mode, dialect: modeDialect) != null;
    final dataBase = ownCode ? null : dataModeBases[mode.toUpperCase()];
    final base = dataBase ?? mode;
    // A mode the radio has no code for sends nothing, rather than a
    // malformed command it would silently reject.
    final command = buildKenwoodSetModeCommand(base, dialect: modeDialect);
    if (command == null) return;
    _send(command);
    // Stated either way wherever the base mode has a submode, so plain USB
    // after FT8 does not stay in USB-DATA.
    if (dataMode && dataModeBases.containsValue(base.toUpperCase())) {
      _send(buildKenwoodSetDataModeCommand(on: dataBase != null));
      // Taken as set: the next `MD`/`IF` would otherwise be reported against
      // the flag from before. A refused set is corrected by the next `DA;`.
      _dataOn = dataBase != null;
    }
  }

  @override
  void setPower(num watts) {
    if (!isK4) {
      _send(buildKenwoodSetPowerCommand(watts));
      return;
    }
    // Read the range each time: the operator can change to a transverter
    // band without a power response arriving before this request.
    _pendingK4Power = null;
    _k4PowerTimeout?.cancel();
    if (!watts.isFinite || watts < 0.0001 || watts > 110) {
      _sink.reportProblem(t.settings.station.k4PowerRange);
      _resyncK4Power();
      return;
    }
    _pendingK4Power = watts;
    _k4PowerTimeout = Timer(const Duration(seconds: 2), () {
      _pendingK4Power = null;
      _sink.reportProblem(t.settings.station.k4PowerTimeout);
      _resyncK4Power();
    });
    _send('PCX;');
  }

  /// Writes nothing until the radio has answered `AC` in Kenwood's shape: the
  /// write must carry the receive-side AT as the radio has it, and on a
  /// radio that never answered, `AC` is not known to be a tuner at all.
  /// Then reads back, so what is shown is what the radio took.
  @override
  void setTuner({required bool inline}) {
    final flags = _tunerFlags;
    if (flags == null) return;
    _send(buildKenwoodSetTunerCommand(rxInline: flags.rxInline, inline: inline));
    _readTuner();
  }

  /// Like [setTuner], only once the radio has answered `AC` in Kenwood's shape.
  @override
  bool get canStartTune => _tunerFlags != null;

  @override
  void startTune() {
    final flags = _tunerFlags;
    if (flags == null || _telemetry.transmitting || flags.tuning) return;
    _send(buildKenwoodStartTuneCommand(rxInline: flags.rxInline));
    _readTuner();
  }

  /// P3 `0` with the transmit-side AT in line ends a tune. From the CAT
  /// manuals, not a capture.
  @override
  void stopTune() => setTuner(inline: true);

  /// Writes nothing until the radio has answered `AN` in [antennaDialect]'s
  /// shape, nothing while it is transmitting — no antenna relay moves under
  /// RF, and a refused switch is not queued for after the over — and nothing
  /// for a name the radio did not offer. Then reads back, so what is shown
  /// is what the radio took.
  ///
  /// The TS-590 receives on RX ANT or on the transmit port: [rx] naming the
  /// transmit port it is left on switches RX ANT out, and naming the other
  /// transmit port asks for a pairing the radio cannot make, so sets nothing.
  @override
  void setAntenna({String? rx, String? tx}) {
    final antennas = _antennas;
    if (antennas == null || _telemetry.transmitting) return;
    final txIndex = tx == null ? -1 : kenwoodAntennaPorts.indexOf(tx);
    switch (antennaDialect) {
      case KenwoodAntennaDialect.twoPort:
        // One port for both: either names it.
        final port = txIndex >= 0 ? txIndex : (rx == null ? -1 : kenwoodAntennaPorts.indexOf(rx));
        if (port < 0) return;
        _send(buildKenwoodSetAntennaCommand(port + 1));
      case KenwoodAntennaDialect.ts590:
        final txAfter = txIndex >= 0 ? kenwoodAntennaPorts[txIndex] : antennas.tx;
        final rxAntenna = switch (rx) {
          ts590RxAntennaPort => true,
          final String name when name == txAfter => false,
          _ => null,
        };
        if (txIndex < 0 && rxAntenna == null) return;
        _send(buildTs590SetAntennaCommand(port: txIndex < 0 ? null : txIndex + 1, rxAntenna: rxAntenna));
      case null:
        return;
    }
    _readAntennas();
  }

  /// Writes nothing until the passband has been read in the current mode:
  /// that read is what says the dialect holds on this radio and, on the
  /// TS-590SG, whether `SL`/`SH` are cuts or width/shift right now. Then
  /// reads back, so what is shown is where the radio landed.
  ///
  /// SSB sets both edges — the TS-590SG to its nearest table entries, an
  /// Elecraft to width and centre — except on the K4, whose `IS` set format
  /// under the `K40` this driver selects is not settled, so it takes the
  /// width and keeps its centre. CW sets the width and keeps the shift: the
  /// centre is the pitch, an operator setting.
  @override
  void setPassband(Passband passband) {
    final mode = _lastReported?.mode;
    if (_passband == null || mode == null) return;
    final cw = mode == 'CW' || mode == 'CW-R';
    // The radio's AF edges: LSB mirrors them below the carrier.
    final lsb = mode == 'LSB' || mode == 'DATA-LSB';
    final low = lsb ? -passband.highHz : passband.lowHz;
    final high = lsb ? -passband.lowHz : passband.highHz;
    final centre = ((low + high) / 2).round();
    switch (passbandDialect) {
      case KenwoodPassbandDialect.elecraft:
        _send(buildElecraftSetBandwidthCommand(passband.widthHz));
        final setCentre = cw || isK4 ? null : buildElecraftSetCentreCommand(centre);
        if (setCentre != null) _send(setCentre);
      case KenwoodPassbandDialect.ts590sg when cw:
        _send(buildKenwoodSetFilterWidthCommand(ts590sgWidthsHz[nearestIndex(ts590sgWidthsHz, passband.widthHz)]));
      case KenwoodPassbandDialect.ts590sg:
        final widthShift = mode.startsWith('DATA') ? _ssbDataWidthShift : _ssbWidthShift;
        if (widthShift == true) {
          _send(buildKenwoodSetLowCutCommand(nearestIndex(ts590sgWidthsHz, passband.widthHz)));
          _send(buildKenwoodSetHighCutCommand(nearestIndex(ts590sgShiftsHz, centre)));
        } else {
          _send(buildKenwoodSetLowCutCommand(nearestIndex(ts590sgLowCutsHz, low)));
          _send(buildKenwoodSetHighCutCommand(nearestIndex(ts590sgHighCutsHz, high)));
        }
      case null:
        return;
    }
    _readPassband();
  }

  /// Without this read the app keeps showing, and logging, the power it asked
  /// for until the next poll — which AI traffic can defer indefinitely.
  void _resyncK4Power() {
    _k4PowerResync = true;
    _send('PCX;');
  }

  @override
  void sendCw(String text) {
    if (cwDialect != null) _cwQueue.enqueue(text);
  }

  /// Empties the queue and the radio's buffer both — each dialect has a
  /// terminator, unlike Yaesu's memory playback.
  @override
  void stopCw() {
    _cwQueue.clear();
    final dialect = cwDialect;
    if (dialect != null) _send(buildKenwoodStopCwCommand(dialect));
  }

  @override
  bool get cwSending => _cwQueue.sending;

  @override
  void dropQueuedCw(int id) => _cwQueue.dropPending(id);

  @override
  ({int min, int max}) get keyerSpeedRange => isK4 ? (min: 8, max: 100) : kenwoodKeyerSpeedRange(cwDialect ?? KenwoodCwDialect.elecraft);

  /// Sets, then reads back, so the value shown is what the radio took.
  @override
  void setKeyerSpeed(int wpm) {
    final dialect = cwDialect;
    if (dialect == null) return;
    _send(isK4 ? buildK4SetKeyerSpeedCommand(wpm) : buildKenwoodSetKeyerSpeedCommand(dialect, wpm));
    _send(buildKenwoodReadKeyerSpeedCommand());
  }

  /// Asks the radio for its keyer speed again — see [startUpdates].
  @override
  void refreshKeyerSpeed() {
    if (cwDialect != null) _send(buildKenwoodReadKeyerSpeedCommand());
  }

  @override
  int get voiceMemoryCount => voiceDialect == null ? 0 : _voiceMemories;

  /// Only the K4 documents recording over CAT.
  @override
  bool get canRecordVoice => voiceDialect == KenwoodVoiceDialect.k4;

  void _voicePollSays({required bool going}) {
    if (going) {
      _voice.confirm();
    } else {
      _voice.endFromPoll();
    }
  }

  @override
  void playVoiceMemory(int n) {
    switch (voiceDialect) {
      case KenwoodVoiceDialect.pb:
      case KenwoodVoiceDialect.k4:
        _send(buildKenwoodPlayVoiceCommand(n));
      case KenwoodVoiceDialect.kx:
        buildKxPlayVoiceCommands(n).forEach(_send);
      case null:
        return;
    }
    _voice.start(VoiceActivity(memory: n));
  }

  @override
  void recordVoiceMemory(int n) {
    if (!canRecordVoice) return;
    _send(buildK4RecordVoiceCommand());
    _voice.start(VoiceActivity(memory: n, recording: true));
  }

  /// On the K4 a recording is not a memory until saved: the stop is
  /// `DA0;` — the verb its reference gives for ending ANY digital-audio
  /// action, playback included, where `PB0;` is documented only as
  /// playback's — and then `DAMSn;` for the memory the recording was for.
  @override
  void stopVoice() {
    final activity = _voice.activity;
    if (activity == null) return;
    switch (voiceDialect) {
      case KenwoodVoiceDialect.pb:
        _send(buildKenwoodStopVoiceCommand());
      case KenwoodVoiceDialect.k4:
        _send(buildK4StopDigitalAudioCommand());
        if (activity.recording) _send(buildK4SaveVoiceCommand(activity.memory));
      case KenwoodVoiceDialect.kx:
        _send(buildKxStopVoiceCommand());
      case null:
        break;
    }
    _voice.end();
  }

  /// Whether the app keyed the radio, so [teardown] can unkey it.
  bool _keyedByUs = false;

  @override
  void setPtt(bool on) {
    // Set before a key and cleared only after an unkey: either one that
    // throws leaves [teardown] an unkey to send.
    _keyedByUs |= on;
    _send(buildKenwoodSetTxCommand(on));
    _keyedByUs = on;
  }

  @override
  void startUpdates() {
    _framer.reset();
    _k4Band = null;
    _pendingK4Power = null;
    _k4PowerResync = false;
    _k4InfoRejected = false;
    _k4PowerTimeout?.cancel();
    _tunerFlags = null;
    _tunerPollsToSkip = 0;
    _tunerRead.reset();
    _filterWidthHz = _filterCentreHz = _lowCutIndex = _highCutIndex = _cwPitchHz = null;
    _ssbWidthShift = _ssbDataWidthShift = null;
    _passband = null;
    _passbandReported = false;
    _passbandPollsToSkip = 0;
    _passbandRead.reset();
    _antennas = null;
    _antennaPollsToSkip = 0;
    _antennaRead.reset();
    _lab599Protocol = null;
    _started = true;
    // K4n clears K2 meta mode; K31 explicitly includes the DATA submode in
    // IF. Do this before AI or any reads, on each USB or TCP connection.
    if (isK4) _send('K40;K31;');
    if (declaredModeOffset != null) {
      _sink.reportDiagnostic('IF mode offset $declaredModeOffset (declared)');
    }
    // Once: the protocol is a menu setting, not something that changes while
    // connected.
    if (modeDialect == KenwoodModeDialect.lab599) _send(buildKenwoodReadIdCommand());
    _send(buildKenwoodAutoInformationCommand(true));
    _requestState();
    _telemetry.start();
    // Once, not per poll — the same reasoning as the Icom driver's: the
    // speed changes only when someone turns the knob, and the dialog that
    // shows it re-reads it when it opens.
    if (cwDialect != null) _send(buildKenwoodReadKeyerSpeedCommand());
    _poller.start();
  }

  @override
  void stopUpdates() {
    _k4Band = null;
    _pendingK4Power = null;
    _k4PowerResync = false;
    _k4PowerTimeout?.cancel();
    _poller.stop();
    _telemetry.stop();
    // Leave the radio as we found it: AI persists across a disconnect, so a
    // logger that never turns it off leaves the rig chattering at whatever
    // connects next. Only if we turned it on — teardown reaches here for a
    // session that was superseded before it ever spoke.
    if (!_started) return;
    _started = false;
    _send(buildKenwoodAutoInformationCommand(false));
  }

  @override
  void teardown() {
    if (_keyedByUs) {
      // First, and sent even though the connection is closing: nothing else
      // will unkey this radio.
      _keyedByUs = false;
      _send(buildKenwoodSetTxCommand(false));
    }
    _cwQueue.clear();
    _voice.dispose();
    // Via stopUpdates, so "stop talking to the radio" is written once.
    stopUpdates();
    _telemetry.dispose();
  }
}
