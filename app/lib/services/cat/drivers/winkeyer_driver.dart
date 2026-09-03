// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Speaks the K1EL WinKeyer host protocol (WK2 and WK3) over a serial port —
// the keyer's own USB bridge, at its fixed 1200 baud, 8 data bits, no
// parity, TWO stop bits, which is why winkeyerModel pins `stopBits`.
//
// A keyer, not a radio: it has no VFO, so this is a [CwKeyerSession] and
// nothing else. What it has that no CAT keyer does is FEEDBACK — with serial
// echoback on, the keyer echoes each character as it keys it, and its status
// byte says when it is busy and when its buffer is nearly full. So progress
// here is what the keyer reports, not the estimate the CAT drivers pace by,
// and the send is throttled by the keyer's XOFF rather than by arithmetic.
//
// From the K1EL WK2/WK3 host interface documents, not from a keyer: nothing
// here has met hardware. See [WinkeyerDriver.hardwareVerified].

import 'dart:async';
import 'dart:typed_data';

import '../../../i18n/strings.g.dart';
import '../driver.dart';
import 'cw_send_queue.dart';

/// Admin command prefix; the byte after it picks the admin function.
const _admin = 0x00;
const _adminHostOpen = 0x02;
const _adminHostClose = 0x03;

/// Immediate commands.
const _cmdSetSpeed = 0x02;
const _cmdSetPotRange = 0x05;
const _cmdClearBuffer = 0x0A;
const _cmdSetMode = 0x0E;
const _cmdGetSpeedPot = 0x07;
const _cmdRequestStatus = 0x15;

/// Set Mode bit: serial echoback — the keyer echoes each character as it
/// keys it, which is what makes [CwSendProgress.sentCount] real. The other
/// bits (paddle mode, swap, autospace, spacing) are left at zero, iambic B
/// with no autospace; the keyer's standalone settings are not read first.
const _modeSerialEchoback = 0x04;

/// Speed-pot range the session asks for: reports come as `0x80 | position`,
/// position 0..range, WPM being [_potMinWpm] + position.
const _potMinWpm = 5;
const _potRange = 40;

/// What `0x02` accepts.
const winkeyerSpeedMin = 5;
const winkeyerSpeedMax = 99;

/// Status byte: `0xC0` plus flags.
const _statusMask = 0xC0;
const _statusXoff = 0x01;
const _statusBreakIn = 0x02;
const _statusBusy = 0x04;

/// Speed-pot report: `0x80` plus the position, below the status range.
const _potMask = 0x80;

/// How many characters go to the keyer in one burst while it is not saying
/// XOFF. Its buffer holds 128 and it raises XOFF at two thirds; a burst goes
/// out per echo as well as per status, and each echo is a slot freed, so
/// the buffer holds at most a burst past the XOFF mark and never overruns.
const _burst = 24;

/// A keyer in host mode says nothing while idle, so the session asks for
/// its status on this cadence; the answer is what keeps the node from
/// reading as stale.
const winkeyerStatusPoll = Duration(seconds: 10);

/// How long after host open the version byte may take before the port is
/// reported as having no keyer on it.
const winkeyerAnswerTimeout = Duration(seconds: 3);

/// Grace past a message's own timeline before a keyer that has stopped
/// echoing is given up on. Generous: the timeline assumes the speed last
/// reported, and weighting or a pot turn mid-message stretch it.
const winkeyerSendGrace = Duration(seconds: 5);

class WinkeyerDriver extends EquipmentDriver {
  const WinkeyerDriver();

  @override
  String get key => 'winkeyer';

  @override
  String get name => 'K1EL WinKeyer';

  /// Written from the host-interface documents alone.
  @override
  bool get hardwareVerified => false;

  @override
  bool get canKeyCw => true;

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => WinkeyerSession(sink);
}

/// One message as queued: its id for the progress report, and its text.
class _Message {
  final int id;
  final String text;
  _Message(this.id, this.text);
}

class WinkeyerSession implements CwKeyerSession {
  final EquipmentSink _sink;

  WinkeyerSession(this._sink);

  int _nextId = 1;
  final _pending = <_Message>[];
  _Message? _current;

  /// How much of [_current] has been handed to the keyer, and how much the
  /// keyer has echoed back as keyed.
  int _handed = 0;
  int _echoed = 0;

  bool _xoff = false;
  bool _busy = false;

  /// Set once host mode is asked for and cleared by the first byte back,
  /// which is the firmware version rather than an echo or a status.
  bool _awaitingVersion = false;

  int? _speed;

  Timer? _pollTimer;
  Timer? _answerTimer;
  Timer? _sendWatchdog;

  /// Set when a status was asked for, so the reply can stand as a sign of
  /// life rather than as one more busy/XOFF change.
  bool _statusRequested = false;
  bool _problemShown = false;

  void _send(List<int> bytes) => _sink.send(bytes);

  /// Any byte at all is the keyer on the port: the no-answer watch stands
  /// down, and a problem it or the send watchdog raised is withdrawn.
  void _answered() {
    _answerTimer?.cancel();
    _answerTimer = null;
    if (_problemShown) {
      _problemShown = false;
      _sink.reportProblem(null);
    }
  }

  @override
  void handleData(Uint8List chunk) {
    for (final byte in chunk) {
      _handleByte(byte);
    }
  }

  void _handleByte(int byte) {
    _answered();
    // The version is the first byte back after host open, and the one byte
    // below 0x80 that is not an echo. A status or pot report left over from
    // a session that never closed can precede it, and is never a version.
    if (_awaitingVersion && byte < _potMask) {
      _awaitingVersion = false;
      _sink.reportDiagnostic('WinKeyer v${byte ~/ 10}.${byte % 10}');
      return;
    }
    if (byte & _statusMask == _statusMask) {
      final wasBusy = _busy;
      _xoff = byte & _statusXoff != 0;
      _busy = byte & _statusBusy != 0;
      // The paddle: the keyer aborts what it was sending and empties its
      // buffer, so what the app queued is gone too — and must not sit here
      // as "sending" waiting for echoes that will never come.
      if (byte & _statusBreakIn != 0 && _current != null) {
        _pending.clear();
        _current = null;
        _cancelSendWatchdog();
        _sink.reportCwProgress(null);
        return;
      }
      if (_statusRequested) {
        _statusRequested = false;
        // A keyer restating its speed is a keyer that is answering; one
        // whose speed is still unknown is asked for its pot instead, and
        // that answer says the same.
        if (_speed != null) {
          refreshKeyerSpeed();
        } else {
          _send([_cmdGetSpeedPot]);
        }
      }
      if (!_xoff) _pump();
      // Idle again: the message is over once everything has been handed
      // over. The keyer reports busy going low only after its last element,
      // so this — not the last echo — is when a message has finished; an
      // echo that never arrived is not a reason to wait forever.
      if (wasBusy && !_busy) _finishIfDone(force: true);
      return;
    }
    if (byte & _potMask != 0) {
      final wpm = _potMinWpm + (byte & 0x3F);
      _speed = wpm;
      _sink.reportKeyerSpeed(wpm);
      return;
    }
    // Anything else is the keyer echoing a character it has keyed — which
    // also frees a slot in its buffer, so more can go.
    final current = _current;
    if (current == null) return;
    if (_echoed < current.text.length) {
      _echoed++;
      _reportCurrent();
    }
    _pump();
    if (_echoed >= current.text.length && !_busy) _finishIfDone();
  }

  /// Hands the keyer as much of the current message as it will take.
  void _pump() {
    final current = _current;
    if (current == null || _xoff) return;
    if (_handed >= current.text.length) return;
    final end = (_handed + _burst).clamp(0, current.text.length);
    _send(current.text.substring(_handed, end).codeUnits);
    _handed = end;
  }

  /// Ends the current message when the keyer is done with it: every
  /// character echoed — or, with [force] (the keyer reporting idle), every
  /// character handed over, echoes or not.
  void _finishIfDone({bool force = false}) {
    final current = _current;
    if (current == null) return;
    final done = _echoed >= current.text.length || (force && _handed >= current.text.length);
    if (!done) return;
    _current = null;
    _startNext();
  }

  void _startNext() {
    _cancelSendWatchdog();
    if (_pending.isEmpty) {
      _sink.reportCwProgress(null);
      return;
    }
    _current = _pending.removeAt(0);
    _handed = 0;
    _echoed = 0;
    // Once per message, not per echo: the timeline only changes with the
    // message or the speed.
    _currentEnds = cwCharacterEnds(_current!.text, _speed ?? defaultCwSpeedWpm);
    _armSendWatchdog();
    _reportCurrent();
    _pump();
  }

  List<Duration> _currentEnds = const [];

  /// Nothing ends a message but bytes from the keyer, so a keyer that goes
  /// quiet mid-message would leave it "sending" for ever: past its own
  /// timeline plus [winkeyerSendGrace], the message and the queue are given
  /// up and the operator told.
  void _armSendWatchdog() {
    final total = _currentEnds.isEmpty ? Duration.zero : _currentEnds.last;
    _sendWatchdog = Timer(total + winkeyerSendGrace, () {
      _sendWatchdog = null;
      if (_current == null) return;
      _pending.clear();
      _current = null;
      _send([_cmdClearBuffer]);
      _sink.reportCwProgress(null);
      _problemShown = true;
      _sink.reportProblem(t.settings.station.winkeyerStoppedAnswering);
    });
  }

  void _cancelSendWatchdog() {
    _sendWatchdog?.cancel();
    _sendWatchdog = null;
  }

  void _reportCurrent() {
    final current = _current;
    if (current == null) return;
    _sink.reportCwProgress(CwSendProgress(
      id: current.id,
      text: current.text,
      // The timeline is still worth having — a view that only knows the
      // estimate can pace by it — but [sentCount] is what this keyer shows.
      characterEnds: _currentEnds,
      sentCount: _echoed,
      pending: [for (final m in _pending) m.text],
      pendingIds: [for (final m in _pending) m.id],
    ));
  }

  @override
  void sendCw(String text) {
    final sanitized = sanitizeCwText(text);
    if (sanitized.isEmpty) return;
    _pending.add(_Message(_nextId++, sanitized));
    if (_current == null) {
      _startNext();
    } else {
      _reportCurrent();
    }
  }

  /// A real stop: the keyer's buffer is cleared, so only the element in
  /// flight completes.
  @override
  void stopCw() {
    _pending.clear();
    final wasSending = _current != null;
    _current = null;
    _cancelSendWatchdog();
    _send([_cmdClearBuffer]);
    if (wasSending) _sink.reportCwProgress(null);
  }

  @override
  bool get cwSending => _current != null;

  @override
  void dropQueuedCw(int id) {
    final before = _pending.length;
    _pending.removeWhere((m) => m.id == id);
    if (_pending.length != before) _reportCurrent();
  }

  @override
  ({int min, int max}) get keyerSpeedRange => (min: winkeyerSpeedMin, max: winkeyerSpeedMax);

  /// The keyer does not echo a speed set, so the set is reported as taken;
  /// a turn of the speed pot afterwards reports on its own.
  @override
  void setKeyerSpeed(int wpm) {
    final clamped = wpm.clamp(winkeyerSpeedMin, winkeyerSpeedMax);
    _send([_cmdSetSpeed, clamped]);
    _speed = clamped;
    _sink.reportKeyerSpeed(clamped);
  }

  /// Nothing to ask the keyer for: it reports the pot as it moves, and a
  /// set is what the app last said. Re-reports what is known.
  @override
  void refreshKeyerSpeed() {
    final speed = _speed;
    if (speed != null) _sink.reportKeyerSpeed(speed);
  }

  @override
  void startUpdates() {
    _awaitingVersion = true;
    _send([_admin, _adminHostOpen]);
    _send([_cmdSetMode, _modeSerialEchoback]);
    _send([_cmdSetPotRange, _potMinWpm, _potRange, 0x00]);
    // The pot is the keyer's speed until the app sets one; asked once, so
    // the speed is known from connect rather than from the first turn.
    _send([_cmdGetSpeedPot]);
    _answerTimer?.cancel();
    _answerTimer = Timer(winkeyerAnswerTimeout, () {
      _answerTimer = null;
      if (!_awaitingVersion) return;
      _problemShown = true;
      _sink.reportProblem(t.settings.station.winkeyerNoAnswer);
    });
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(winkeyerStatusPoll, (_) {
      _statusRequested = true;
      _send([_cmdRequestStatus]);
    });
  }

  @override
  void stopUpdates() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _answerTimer?.cancel();
    _answerTimer = null;
  }

  /// Pushes: status, echo and pot reports arrive as they happen.
  @override
  Duration? get expectedUpdateInterval => null;

  /// Cleared and closed, so the keyer goes back to keying standalone from
  /// its paddle with nothing of ours left in its buffer.
  @override
  void teardown() {
    stopUpdates();
    _cancelSendWatchdog();
    _pending.clear();
    _current = null;
    _send([_cmdClearBuffer]);
    _send([_admin, _adminHostClose]);
  }
}
