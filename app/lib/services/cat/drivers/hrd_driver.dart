// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks Ham Radio Deluxe's Rig Control IP protocol (hrd_codec.dart) to an
// HRD the operator already runs, which drives the radio itself — the HRD
// sibling of the flrig and rigctld drivers.
//
// Written from published descriptions of the protocol and pinned against
// HaLo's own HRD emulation; no exchange with a real HRD has been captured.
//
// HRD pushes nothing, and a reply names no command: `get frequency` answers
// `14074000` and nothing else. So exactly one request is on the wire at a
// time and an answer belongs to the oldest question (request_queue.dart,
// which also covers a question HRD never answers, and one it answers late).
//
// HRD's commands name its own window. The mode is an item in a dropdown
// whose name (`Mode`, `Main Mode`, `Mode A`) and items (`PKT-U`, `USB-D`,
// `DATA-U`) are the radio's, so a session starts by asking for both:
//
//   get context            → 1          prefixes every later command, `[1] …`
//   get dropdowns          → Mode,AGC,… the mode dropdown's name
//   get dropdown-list {Mode} → LSB,USB,… the items, in order
//   get buttons            → TX,…       whether PTT can be read
//
// and then polls `get frequency` and `get dropdown-text {Mode}` (`Mode: USB`).

import 'dart:typed_data';

import '../adaptive_poller.dart';
import '../driver.dart';
import '../equipment.dart';
import '../request_queue.dart';
import '../telemetry_poller.dart';
import 'hrd_codec.dart';
import 'poll_config.dart';

class HrdDriver extends EquipmentDriver {
  const HrdDriver();

  /// HRD Rig Control's own default IP server port.
  static const defaultPort = 7809;

  @override
  String get key => 'hrd';

  @override
  String get name => 'Ham Radio Deluxe';

  /// What [HrdSession.setMode] can name, where the radio's own dropdown
  /// offers it — a mode the radio lacks is not sent.
  @override
  List<String> settableModes(Map<String, dynamic> config) => radioModeOrder(hrdModesByAppMode.keys);

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => HrdSession(sink, config);

  @override
  List<Map<String, dynamic>> configElements({Map<String, dynamic> overrides = const {}, Map<String, dynamic> restrictions = const {}}) => [pollConfigElement()];

  @override
  String? validateField(String key, dynamic value, Map<String, dynamic> config) => key == pollIntervalConfigKey ? validatePollInterval(value) : null;
}

/// What the outstanding request will answer.
enum _Ask { context, dropdowns, modeList, buttons, frequency, mode, transmitting, set }

/// Far longer than a local HRD takes to answer, short enough that a command
/// it ignores costs one skipped poll rather than a frozen radio.
const _answerTimeout = Duration(seconds: 2);

/// How many times an opening question may go unanswered before it stops
/// being asked. Each miss stalls the polls behind it for a timeout and a
/// drain; an HRD that ignores the question outright is not going to start.
const _openingTries = 3;

/// The silence that ends a drain after a timeout (request_queue.dart).
const _quiet = Duration(milliseconds: 500);

/// Far past any real reply; reached only when the peer is not HRD.
const _maxFrameLength = 64 * 1024;

final _digits = RegExp(r'^\d+$');

class HrdSession implements TransceiverSession {
  final EquipmentSink _sink;

  final Map<String, dynamic> _config;

  HrdSession(this._sink, [this._config = const {}]);

  late final AdaptivePoller _poller = AdaptivePoller(onPoll: _poll, slow: idlePollIntervalFor(_config));

  /// The PTT watch, started once `get buttons` says there is a TX button.
  late final TelemetryPoller _telemetry = TelemetryPoller(onPoll: _pollTelemetry);

  final _txBackoff = WatchBackoff();

  /// Every request is built when it is SENT, not when it is queued, so
  /// everything queued behind `get context` carries the prefix its answer
  /// brings, and a mode read queued before `get dropdowns` answered still
  /// names the dropdown.
  late final RequestQueue<_Ask> _requests = RequestQueue(send: _sink.send, onUnanswered: _unanswered, answerTimeout: _answerTimeout, quiet: _quiet);

  VfoReading? _lastReported;

  final _buffer = BytesBuilder();

  /// `[n] `, once `get context` has answered.
  String _prefix = '';

  /// The mode dropdown's name and items, once HRD has said them.
  String? _modeDropdown;
  List<String> _modeItems = const [];

  bool _watchesTx = false;

  /// How often each opening question has gone unanswered this connection.
  final _openingMisses = <_Ask, int>{};

  /// The opening questions answered with something usable. One answered
  /// with an error or nothing — an HRD whose radio is not connected yet — is
  /// asked again with the polls, or the mode and PTT it teaches would stay
  /// dead after the radio comes up.
  final _openingLearned = <_Ask>{};

  /// Each said once, as a diagnostic: the first things to look at when HRD
  /// half-works.
  bool _reportedTimeout = false;
  bool _reportedNoModeDropdown = false;
  bool _reportedUnframed = false;

  Duration get pollInterval => _poller.interval;

  List<int>? Function() _command(String? Function() text) => () {
    final command = text();
    return command == null ? null : encodeHrdFrame('$_prefix$command');
  };

  void _ask(_Ask ask, String? Function() text) => _requests.ask(ask, _command(text));

  /// One of the questions a session opens with, asked ahead of everything
  /// waiting when [retry] — what it learns is needed by the polls behind it.
  void _askOpening(_Ask ask, {bool retry = false}) {
    final String? Function() text = switch (ask) {
      _Ask.context => () => 'get context',
      _Ask.dropdowns => () => 'get dropdowns',
      _Ask.modeList => () => _modeDropdown == null ? null : 'get dropdown-list {$_modeDropdown}',
      _Ask.buttons => () => 'get buttons',
      _ => throw ArgumentError.value(ask, 'ask', 'not an opening question'),
    };
    _requests.ask(ask, _command(text), first: retry);
  }

  void _unanswered(_Ask ask) {
    if (ask == _Ask.transmitting) _txBackoff.unanswered();
    if (_isOpening(ask)) {
      final misses = _openingMisses[ask] = (_openingMisses[ask] ?? 0) + 1;
      if (misses < _openingTries) _askOpening(ask, retry: true);
    }
    if (!_reportedTimeout) {
      _reportedTimeout = true;
      _sink.reportDiagnostic('HRD did not answer a ${ask.name} request');
    }
  }

  static bool _isOpening(_Ask ask) => const {_Ask.context, _Ask.dropdowns, _Ask.modeList, _Ask.buttons}.contains(ask);

  void _poll() {
    if (_requests.backlogged) return;
    for (final ask in const [_Ask.dropdowns, _Ask.modeList, _Ask.buttons]) {
      if (_openingLearned.contains(ask) || (_openingMisses[ask] ?? 0) >= _openingTries || _requests.holds(ask)) continue;
      if (ask == _Ask.modeList && _modeDropdown == null) continue;
      _askOpening(ask);
    }
    _requestFrequencyAndMode();
  }

  void _requestFrequencyAndMode() {
    _ask(_Ask.frequency, () => 'get frequency');
    _ask(_Ask.mode, () => _modeDropdown == null ? null : 'get dropdown-text {$_modeDropdown}');
  }

  void _pollTelemetry(bool transmitting) {
    if (_requests.backlogged || _requests.holds(_Ask.transmitting) || !_txBackoff.shouldAsk()) return;
    _ask(_Ask.transmitting, () => 'get button-select TX');
  }

  @override
  void handleData(Uint8List chunk) {
    _buffer.add(chunk);
    while (true) {
      final pending = _buffer.toBytes();
      final ({int consumed, String text})? frame;
      try {
        frame = takeHrdFrame(pending, maxLength: _maxFrameLength);
      } on FormatException catch (e) {
        // Not HRD's framing, so nothing after it can be found either — a
        // wrong port, or a peer answering in plain text.
        _buffer.clear();
        if (!_reportedUnframed) {
          _reportedUnframed = true;
          _sink.reportDiagnostic('HRD reply is not an HRD frame (${e.message})');
        }
        return;
      }
      if (frame == null) return;
      _buffer
        ..clear()
        ..add(pending.sublist(frame.consumed));
      final ask = _requests.replyArrived();
      if (ask == null) continue;
      _handleAnswer(ask, frame.text.trim());
      _requests.settle();
    }
  }

  void _handleAnswer(_Ask ask, String text) {
    // Deferring the poll is for what HRD says about the radio, never for the
    // PTT watch's answers — see RigctldSession._stateLabels.
    if (ask == _Ask.frequency || ask == _Ask.mode) _poller.noteData();
    if (ask == _Ask.transmitting) _txBackoff.answered();
    if (text.isEmpty || text.toUpperCase().startsWith('ERROR')) return;
    switch (ask) {
      case _Ask.context:
        final context = int.tryParse(text);
        if (context != null) _prefix = '[$context] ';
      case _Ask.dropdowns:
        final dropdowns = _list(text);
        _openingLearned.add(ask);
        _modeDropdown = _pickModeDropdown(dropdowns);
        if (_modeDropdown != null) {
          _askOpening(_Ask.modeList);
        } else if (!_reportedNoModeDropdown) {
          // A radio naming its mode dropdown in a way nothing here expects:
          // its mode is neither read nor set, and the names are what a fix
          // needs.
          _reportedNoModeDropdown = true;
          _sink.reportDiagnostic('HRD offers no mode dropdown among: ${dropdowns.join(', ')}');
        }
      case _Ask.modeList:
        _modeItems = _list(text);
        if (_modeItems.isNotEmpty) _openingLearned.add(ask);
      case _Ask.buttons:
        _openingLearned.add(ask);
        if (!_watchesTx && _list(text).any((b) => b.toUpperCase() == 'TX')) {
          _watchesTx = true;
          _telemetry.start();
        }
      case _Ask.frequency:
        // Only an answer shaped like one: whole Hz, at least a kHz. Anything
        // else is an answer out of step — a frequency read from the PTT
        // watch's `1` would put the radio at 0.001 kHz.
        final hz = _digits.hasMatch(text) ? double.parse(text) : null;
        if (hz != null && hz >= 1000) _report(VfoReading(freqKHz: double.parse((hz / 1000).toStringAsFixed(3))));
      case _Ask.mode:
        // `Mode: USB` — the dropdown's name, then the item. A bare number is
        // an answer out of step, not a mode.
        final colon = text.indexOf(':');
        final item = (colon < 0 ? text : text.substring(colon + 1)).trim();
        if (item.isNotEmpty && !_digits.hasMatch(item)) _report(VfoReading(mode: appModeForHrdMode(item)));
      case _Ask.transmitting:
        // `1` or `0`; anything else leaves "nobody knows" standing.
        final pressed = switch (text) {
          '1' => true,
          '0' => false,
          _ => null,
        };
        if (pressed != null && _telemetry.noteTransmitting(pressed)) _sink.reportTransmitting(pressed);
      case _Ask.set:
        break;
    }
  }

  static List<String> _list(String text) => [
    for (final item in text.split(','))
      if (item.trim().isNotEmpty) item.trim(),
  ];

  /// `Mode` itself where the radio has one, then one that starts with it
  /// (`Mode A`), then `Main Mode`, and only then any dropdown naming a mode:
  /// `AGC Mode` or `Scope Mode` listed first would otherwise be read as the
  /// radio's mode, and set as one.
  static String? _pickModeDropdown(List<String> dropdowns) {
    final rules = <bool Function(String)>[
      (name) => name == 'mode',
      (name) => name.startsWith('mode'),
      (name) => name == 'main mode',
      (name) => name.contains('mode'),
    ];
    for (final rule in rules) {
      for (final name in dropdowns) {
        if (rule(name.toLowerCase())) return name;
      }
    }
    return null;
  }

  void _report(VfoReading reading) {
    final merged = VfoReading(freqKHz: reading.freqKHz ?? _lastReported?.freqKHz, mode: reading.mode ?? _lastReported?.mode);
    // The first reading answers startUpdates' question — see Ft891Session._report.
    final first = _lastReported == null;
    if (merged != _lastReported) {
      _lastReported = merged;
      if (!first) _poller.noteChange();
    }
    _sink.report(reading);
  }

  /// A set's reply (`OK`, or an error) says nothing the next poll will not,
  /// but it still has to be waited for: taken as the answer to the question
  /// behind it, it would put every later answer one question late.
  @override
  void setFrequency(double freqKHz) => _ask(_Ask.set, () => 'set frequency-hz ${(freqKHz * 1000).round()}');

  /// Sends the radio's own name for [mode], at its place in the dropdown.
  /// Nothing is sent until HRD has listed the dropdown, or for a mode the
  /// radio does not offer: HRD's `set dropdown` names an item and its
  /// index, and a guessed pair selects whatever sits at that index.
  ///
  /// Both sides are read through [appModeForHrdMode], so the app's `RTTY`
  /// finds a Kenwood's `FSK` as surely as `RTTY-LSB` does.
  @override
  void setMode(String mode) {
    final dropdown = _modeDropdown;
    if (dropdown == null) return;
    final wanted = appModeForHrdMode(mode);
    final index = _modeItems.indexWhere((item) => appModeForHrdMode(item) == wanted);
    if (index < 0) return;
    final item = _modeItems[index];
    _ask(_Ask.set, () => 'set dropdown ${_tilde(dropdown)} ${_tilde(item)} $index');
  }

  /// A name with spaces, as a `set` command carries it.
  static String _tilde(String name) => name.replaceAll(' ', '~');

  /// HRD's power is a slider named differently on every radio, in a unit
  /// its reply does not state.
  @override
  void setPower(num watts) {}

  @override
  void startUpdates() {
    _buffer.clear();
    _requests.clear();
    _txBackoff.reset();
    _prefix = '';
    _modeDropdown = null;
    _modeItems = const [];
    _watchesTx = false;
    _openingMisses.clear();
    _openingLearned.clear();
    _askOpening(_Ask.context);
    _askOpening(_Ask.dropdowns);
    _askOpening(_Ask.buttons);
    _requestFrequencyAndMode();
    _poller.start();
  }

  @override
  void stopUpdates() {
    _poller.stop();
    _telemetry.stop();
  }

  @override
  Duration? get expectedUpdateInterval => _poller.interval;

  @override
  void teardown() {
    // HRD holds no per-client state; stopping the poll is the farewell.
    stopUpdates();
    _requests.clear();
    _telemetry.dispose();
  }
}
