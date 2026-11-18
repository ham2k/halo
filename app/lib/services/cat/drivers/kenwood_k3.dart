// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Elecraft K3 and K3S's side of a Kenwood session
// ([KenwoodDriver.k3Key]): the option modules `OM;` reports, which decide
// whether its voice keyer, its antenna ports and its ATU exist; the `K31`
// command mode its ATU state needs; the transmit meters it reads with `BG`,
// `TM` and `SW` rather than Kenwood's `SM`/`RM`; and the VOX that decides
// whether its CW goes on the air at all.
// See docs/design/cat.md § Telemetry, § Tuner, § CW keying and § Voice keying.

part of 'kenwood_driver.dart';

mixin _ElecraftK3 {
  EquipmentSink get _sink;
  bool get _transmitting;
  void _send(String command);
  void _hold(RadioMeter meter, num value, {required bool keyed});
  void _reportTuner(TunerStatus? status);
  VfoReading? get _lastReported;

  /// Pinned by the K3 and K3S entries.
  bool get _k3;

  /// What `OM;` said is fitted. Null until it answers, and asked on every
  /// poll until then — the same reason as the TX-500's `ID;`.
  K3Modules? _k3Modules;

  /// The set power, from `PC`: what the bargraph's power scale follows.
  num? _k3SetWatts;

  /// The bargraph's transmit mode, from `TM`: null until read, true while it
  /// shows ALC rather than power.
  bool? _k3MeterAlc;

  /// RX ANT switched in, from `AR`. Read ahead of `AN`, whose answer reports
  /// both.
  bool _k3RxAntenna = false;

  /// The command mode the radio was in before this connection: the first
  /// `K3` answer, null until it arrives. Asked on every poll until then, like
  /// `OM`. False means this session switched `K31` on, and switches it back
  /// off when it stops.
  bool? _k3WasExtended;

  /// `K31` in effect, as the radio last answered `K3`: what `IF`'s DATA
  /// submode and `DS`'s ATU flag both need. Asked on every poll until true,
  /// so an `IF` already on its way under `K30` is never read as `K31`'s.
  bool _k3Extended = false;

  /// The ATU in line, from `DS`. Null until read.
  bool? _k3AtuInline;

  /// An `OM` answer in no shape [parseK3ModulesParams] reads has been
  /// reported: once per connection, not once per poll.
  bool _k3ModulesRejected = false;

  /// VOX in CW, from `VX`, which answers for the mode the radio is in: read
  /// only in CW. Null until read.
  bool? _k3CwVox;

  void _resetK3() {
    _k3Modules = null;
    _k3SetWatts = null;
    _k3MeterAlc = null;
    _k3RxAntenna = false;
    _k3WasExtended = null;
    _k3Extended = false;
    _k3AtuInline = null;
    _k3ModulesRejected = false;
    _k3CwVox = null;
  }

  void _requestK3State() {
    if (!_k3) return;
    if (_k3Modules == null) _send(buildK3ReadModulesCommand());
    if (!_k3Extended) _send(buildK3ReadCommandModeCommand());
  }

  /// Every poll, not once: VOX is a front-panel key. After the poll's `MD`
  /// and `IF`, whose answers arrive first and say whether this one is CW's.
  void _requestK3Vox() {
    if (_k3 && _k3InCw) _send(buildK3ReadVoxCommand());
  }

  bool get _k3InCw => switch (_lastReported?.mode) {
    'CW' || 'CW-R' => true,
    _ => false,
  };

  /// A `VX` answered after a switch out of CW is the new mode's VOX.
  void _handleK3Vox(String params) {
    final on = parseK3VoxParams(params);
    if (on != null && _k3InCw) _k3CwVox = on;
  }

  /// With VOX off in CW, the K3 sends `KY` text and its key jack in sidetone
  /// only, until PTT is keyed. See [CwSidetoneSession].
  String? get cwSidetoneOnly => _k3InCw && _k3CwVox == false ? t.settings.station.k3CwVoxOff : null;

  /// Only the first answer is the radio's own mode: any later one may be
  /// this session's `K31` read back.
  void _handleK3CommandMode(String params) {
    final extended = parseK3CommandModeParams(params);
    if (extended == null) return;
    _k3Extended = extended;
    if (_k3WasExtended != null) return;
    _k3WasExtended = extended;
    if (!extended) _send(buildK3SetCommandModeCommand(true));
  }

  /// Puts the command mode back the way this session found it. Only an
  /// orderly stop gets to: a connection that drops leaves `K31` on.
  void _restoreK3CommandMode() {
    if (_k3WasExtended == false) _send(buildK3SetCommandModeCommand(false));
    _k3WasExtended = null;
    _k3Extended = false;
  }

  /// `MD6`/`MD9` say DATA without the submode, which only `IF` carries, and
  /// only under `K31`. A K3 in DATA reports no mode without it: RTTY reported
  /// meanwhile would replace an FT8 the operator set, and the DATA-USB after
  /// it would not bring FT8 back.
  bool _k3DataModeCode(String code) => _k3 && (code == '6' || code == '9');

  bool _k3InfoIsData(String params, int offset) => offset < params.length && _k3DataModeCode(params[offset]);

  /// The DATA mode an `IF` names, from its mode at [offset] and the submode
  /// five places on. Null before `K31`, when the submode position holds a
  /// fixed `0`.
  String? _k3InfoDataMode(String params, int offset) {
    if (!_k3Extended || offset + 5 >= params.length) return null;
    return k4ModeForCodes(params[offset], params[offset + 5]);
  }

  /// `DS` reports the ATU only under `K31`, and there is one to report only
  /// with the KAT3.
  bool get _k3CanReadTuner => _k3Extended && _k3Modules?.atu == true;

  void _readK3Tuner() => _send(buildK3ReadDisplayCommand());

  void _handleK3Display(String params) {
    final inline = parseK3DisplayAtuInlineParams(params);
    if (inline == null || !_k3CanReadTuner) return;
    _k3AtuInline = inline;
    _reportTuner(inline ? TunerStatus.inline : TunerStatus.bypassed);
  }

  /// The ATU key toggles, so it is held only when the last read differs from
  /// [inline], and the read is taken as done until the next `DS` says
  /// otherwise: a second request before that would otherwise toggle it back.
  void _setK3Tuner(bool inline) {
    final current = _k3AtuInline;
    if (current == null || current == inline || _transmitting) return;
    _k3AtuInline = inline;
    _send(buildK3ToggleAtuCommand());
    _readK3Tuner();
  }

  void _handleK3Modules(String params) {
    final modules = parseK3ModulesParams(params);
    if (modules == null) {
      // Unread, the modules leave the voice memories offered and the ATU and
      // antenna ports unread for the whole connection.
      if (!_k3ModulesRejected) _sink.reportDiagnostic('K3: OM answer not understood: "OM$params"');
      _k3ModulesRejected = true;
      return;
    }
    _k3Modules = modules;
    _sink.reportDiagnostic(
      '${modules.k3s ? 'K3S' : 'K3'}: OM$params'
      '${modules.voiceRecorder ? '' : ', no KDVR3 (no voice memories)'}',
    );
  }

  /// Keyed only: `TM;` first, so the `BG` after it is read on the scale the
  /// panel is on now.
  void _readK3Meters(bool transmitting) {
    if (!_k3 || !transmitting) return;
    _send(buildK3ReadTransmitMeterModeCommand());
    _send(buildK3ReadBargraphCommand());
    _send(buildK3ReadSwrCommand());
  }

  void _handleK3MeterMode(String params) {
    final alc = parseK3TransmitMeterAlcParams(params);
    if (alc != null) _k3MeterAlc = alc;
  }

  /// Only a bargraph that says it is transmitting, on a known scale: a `BG`
  /// read across the unkey is the S-meter.
  void _handleK3Bargraph(String params) {
    final reading = parseK3BargraphParams(params);
    final alc = _k3MeterAlc;
    if (reading == null || !reading.transmitting || alc == null) return;
    if (alc) {
      _hold(RadioMeter.alc, (reading.bars / k3AlcBars).clamp(0, 1), keyed: true);
    } else if (_k3SetWatts case final setWatts?) {
      // Not before `PC` answers: the scale is a tenth of the other one.
      _hold(RadioMeter.powerOut, reading.bars * k3WattsPerPowerBar(setWatts), keyed: true);
    }
  }

  /// `SW` holds the last transmission's figure after the unkey, so only a
  /// reading taken keyed is one.
  void _handleK3Swr(String params) {
    final swr = parseK3SwrParams(params);
    if (swr != null && _transmitting) _hold(RadioMeter.swr, swr, keyed: true);
  }

  /// ANT2 needs the KAT3, RX ANT the KXV3; with neither there is no choice to
  /// offer, and nothing is read.
  bool get _k3HasAntennaChoice => _k3Modules != null && (_k3Modules!.atu || _k3Modules!.rxAntenna);

  List<String> get _k3TxPorts => _k3Modules?.atu == true ? kenwoodAntennaPorts : kenwoodAntennaPorts.sublist(0, 1);

  /// The K3 transmits on ANT1 or ANT2 and receives there too unless RX ANT is
  /// switched in — the TS-590's shape, in two commands.
  RadioAntennas? _parseK3Antennas(String params) {
    final port = parseKenwoodAntennaParams(params);
    final modules = _k3Modules;
    if (port == null || modules == null) return null;
    final tx = kenwoodAntennaPorts[port - 1];
    if (!modules.rxAntenna) return RadioAntennas(rxPorts: _k3TxPorts, txPorts: _k3TxPorts, rx: tx, tx: tx);
    return RadioAntennas(rxPorts: [tx, k3RxAntennaPort], txPorts: _k3TxPorts, rx: _k3RxAntenna ? k3RxAntennaPort : tx, tx: tx, separate: true);
  }

  void _handleK3RxAntenna(String params) {
    final on = parseK3RxAntennaParams(params);
    if (on != null) _k3RxAntenna = on;
  }

  /// [rx] naming RX ANT switches it in; naming the transmit port switches it
  /// out; naming the other transmit port asks for a pairing the radio cannot
  /// make. False when nothing was sent.
  bool _setK3Antenna(RadioAntennas antennas, {String? rx, String? tx}) {
    final txIndex = tx == null ? -1 : _k3TxPorts.indexOf(tx);
    final txAfter = txIndex >= 0 ? _k3TxPorts[txIndex] : antennas.tx;
    final rxAntenna = _k3Modules?.rxAntenna != true
        ? null
        : switch (rx) {
            k3RxAntennaPort => true,
            final String name when name == txAfter => false,
            _ => null,
          };
    if (txIndex < 0 && rxAntenna == null) return false;
    if (txIndex >= 0) _send(buildKenwoodSetAntennaCommand(txIndex + 1));
    if (rxAntenna != null) _send(buildK3SetRxAntennaCommand(rxAntenna));
    return true;
  }
}
