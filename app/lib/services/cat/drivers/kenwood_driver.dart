// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks Kenwood CAT (see kenwood_cat_codec.dart) over an already-open
// connection — in practice a serial port. Like every driver here it deals
// only in already-framed bytes handed to it by a transport.
//
// The protocol comes from published CAT references rather than from a
// capture. It has since been run against real hardware — a QRP Labs QMX,
// both directions — but never against a Kenwood-branded radio, which is
// where those references still carry the risk, and why the one field no
// document settles is learned from the radio instead of assumed.
//
// That field is the mode's position inside the `IF` status packet. The
// widths ahead of it differ between the TS-2000-era layout and the
// TS-480/590/890 one, and getting it wrong would not fail — it would report
// a plausible wrong mode, forever, silently. So `IF` is read for its
// frequency (whose offset is stable across the line) and for nothing else
// until an explicit `MD;` answer has confirmed where the mode lives.

import 'dart:convert';
import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import 'cat_ascii_codec.dart';
import 'kenwood_cat_codec.dart';

class KenwoodDriver extends EquipmentDriver {
  const KenwoodDriver();

  /// What most of the Kenwood line ships set to, and what its CAT menu calls
  /// 9600. Only a default — a mismatch answers with garbage and no error, so
  /// the operator has to be able to change it.
  static const defaultBaudRate = 9600;

  @override
  String get key => 'kenwood';

  @override
  String get name => 'Kenwood (CAT)';

  @override
  bool get hardwareVerified => true;

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

  @override
  Set<String> get recognizedConfigKeys => {...super.recognizedConfigKeys, ifModeOffsetKey};

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => KenwoodSession(
        sink,
        declaredModeOffset: switch (config[ifModeOffsetKey]) {
          final int offset when offset >= kenwoodFrequencyDigits => offset,
          _ => null,
        },
      );
}

class KenwoodSession implements EquipmentSession {
  final EquipmentSink _sink;
  final _framer = KenwoodFramer();

  /// Auto-Information is the primary path; this covers what it can't — the
  /// radio's AI menu switched off, or a frame lost to line noise.
  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _requestState);

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

  KenwoodSession(this._sink, {this.declaredModeOffset}) : _modeOffset = declaredModeOffset;

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

  /// `IF` is in here, not only in [startUpdates], and that is what makes the
  /// offset learnable at all. It needs an `IF` paired with a FRESH `MD`
  /// answer, and the two ways those arrive are mutually exclusive: while
  /// Auto-Information is pushing, [AdaptivePoller] sees data and defers, so
  /// no `MD` is asked for; when the radio is quiet enough to poll, it is by
  /// definition not pushing. Asking for all three together is the only way
  /// the pair reliably occurs — otherwise the single `IF` from startUpdates
  /// is the only one that ever arrives on a radio with AI switched off.
  void _requestState() {
    _send(buildKenwoodReadFrequencyCommand());
    _send(buildKenwoodReadModeCommand());
    _send(buildKenwoodReadInfoCommand());
    _send(buildKenwoodReadPowerCommand());
  }

  /// Reports upward, and tells the poller whether the radio is moving.
  void _report(VfoReading reading) {
    final merged = VfoReading(
      freqKHz: reading.freqKHz ?? _lastReported?.freqKHz,
      mode: reading.mode ?? _lastReported?.mode,
    );
    // The FIRST reading is the answer to the question startUpdates just
    // asked, not the radio moving — counting it as movement would drop every
    // connection into fast polling for a radio nobody is touching.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  @override
  void handleData(Uint8List chunk) {
    // Anything at all defers the next poll — the radio has just told us
    // something, so asking now would repeat a question we have the answer to.
    _poller.noteData();
    // ASCII, and `allowInvalid` because a line-noise byte on a serial link
    // must not throw out of a stream callback; the framer simply will not
    // match it as a command.
    for (final command in _framer.add(ascii.decode(chunk, allowInvalid: true))) {
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
        final mode = parseKenwoodModeParams(command.params);
        if (mode == null) return;
        // The raw code, not one rebuilt from the name: `params` IS what the
        // radio sent, and round-tripping it through the name map would go
        // wrong the day two names share a code.
        _pendingModeCode = command.params;
        _report(VfoReading(mode: mode));

      case 'IF':
        _handleInfo(command.params);

      case 'PC':
        final watts = parseKenwoodPowerParams(command.params);
        if (watts != null) _sink.reportPower(watts);
    }
    // Everything else is an acknowledgement or something we don't track;
    // ignoring them is what lets AI mode be noisy without harm.
  }

  void _handleInfo(String params) {
    // Always safe: the eleven-digit frequency opens the packet on every
    // generation of the line.
    final freqHz = parseKenwoodInfoFrequency(params);
    final learned = _modeOffset;
    final mode = learned == null ? null : parseKenwoodInfoModeAt(params, learned);

    if (freqHz != null || mode != null) {
      _report(VfoReading(freqKHz: freqHz == null ? null : freqHz / 1000, mode: mode));
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
        _report(VfoReading(mode: parseKenwoodInfoModeAt(params, offset)));
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
  void setFrequency(double freqKHz) => _send(buildKenwoodSetFrequencyCommand((freqKHz * 1000).round()));

  @override
  void setMode(String mode) {
    final command = buildKenwoodSetModeCommand(mode);
    // A mode the radio has no code for sends nothing, rather than a
    // malformed command it would silently reject.
    if (command != null) _send(command);
  }

  @override
  void setPower(num watts) => _send(buildKenwoodSetPowerCommand(watts));

  @override
  void startUpdates() {
    _framer.reset();
    _started = true;
    if (declaredModeOffset != null) {
      _sink.reportDiagnostic('IF mode offset $declaredModeOffset (declared)');
    }
    _send(buildKenwoodAutoInformationCommand(true));
    _requestState();
    _poller.start();
  }

  @override
  void stopUpdates() {
    _poller.stop();
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
    // Via stopUpdates, so "stop talking to the radio" is written once.
    stopUpdates();
  }
}
