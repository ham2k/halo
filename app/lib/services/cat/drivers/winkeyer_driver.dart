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
// The keyer's OUTPUT ROUTING is ours to set, not the box's to remember. A
// WinKeyer has two key/PTT jacks and a PINCFG register saying which one is
// live; host mode does not restore it, and a host that leaves it alone
// inherits whatever the last program wrote. Leave PTT enabled there with no
// key output and the keyer holds PTT down for a whole message and keys
// nothing — a dead carrier, exactly as long as the text, through the word
// spaces (WK3 datasheet, PTT Functionality). So [_pinConfig] is written on
// every connect.
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
const _cmdSetWeight = 0x03;
const _cmdSetPttTiming = 0x04;
const _cmdSetPotRange = 0x05;
const _cmdClearBuffer = 0x0A;
const _cmdSetMode = 0x0E;
const _cmdGetSpeedPot = 0x07;
const _cmdSetPinConfig = 0x09;
const _cmdSetKeyComp = 0x11;
const _cmdSetRatio = 0x17;
const _cmdRequestStatus = 0x15;

/// Set Mode bit: serial echoback — the keyer echoes each character as it
/// keys it, which is what makes [CwSendProgress.sentCount] real. The other
/// bits (paddle mode, swap, autospace, spacing) are left at zero, iambic B
/// with no autospace; the keyer's standalone settings are not read first.
const _modeSerialEchoback = 0x04;

/// PINCFG bits, which pick which jack the keyer drives:
/// 3 KeyOut 1, 2 KeyOut 2, 1 sidetone, 0 PTT. The upper nibble is ultimatic
/// priority and paddle hang time, left at zero.
const _pinKeyPort1 = 0x08;
const _pinKeyPort2 = 0x04;
const _pinPtt = 0x01;

/// Config keys for the two PINCFG choices the operator has to make: which
/// jack their rig is on, and whether this keyer drives its PTT line.
const winkeyerKeyPortConfigKey = 'winkeyerKeyPort';
const winkeyerPttConfigKey = 'winkeyerPtt';

/// Key port for an entry that has never been edited. A node stored before
/// these fields existed reads as port 1 as well — which is the port a
/// single-rig setup is plugged into, and the value the WK docs' own
/// examples use.
const winkeyerDefaultKeyPort = 1;

/// Timing left deliberately neutral, and WRITTEN rather than assumed: these
/// registers persist in the keyer, so what another program last set is what
/// an unwritten one keys with. Weight and ratio are the "no adjustment"
/// midpoints from the WK docs, and key compensation is off.
const _weightNeutral = 50;
const _ratioNeutral = 50;
const _keyCompNone = 0;

/// The PTT delays, which are only reached with [WinkeyerSession.ptt] on.
/// Zero tail is NOT zero delay — the keyer's tail is three dit times plus
/// this setting — but zero lead-in does key the first element in the same
/// instant PTT asserts, which an amplifier's relay may not have closed by.
/// Both reference clients ship 0/0; exposing them is the follow-up, and
/// until then this is the value an operator turning PTT on inherits.
const _pttLeadIn = 0;
const _pttTail = 0;

/// Speed-pot range the session asks for: reports come as `0x80 | position`,
/// position 0..range, WPM being [_potMinWpm] + position. The position is a
/// SIX bit field — a pot report is `0x80`-`0xBF` and the status range does
/// not start until `0xC0` — and the keyer sends the pot's WPM less
/// [_potMinWpm], so a range wider than 32 still reports a position above 31.
/// Masking any narrower folds the top of the pot's travel back onto the
/// bottom.
const _potMinWpm = 5;
const _potRange = 40;
const _potValueMask = 0x3F;

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
/// XOFF. Its buffer holds 128 on WK2 and 160 on WK3 — the smaller is what
/// this is sized against — and it raises XOFF at two thirds; a burst goes
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

  /// Nothing to ask: a WinKeyer with no speed pot cannot report a speed it
  /// was never told, so an unremembered one resets to the default on every
  /// reconnect — mid-contest, that is a CQ going out slow with no notice.
  @override
  bool get remembersKeyerSpeed => true;

  /// Which jack the rig is on, and whether to drive its PTT line. Neither is
  /// discoverable — the keyer cannot say what is plugged into it — and
  /// getting the first wrong is silence while getting the second wrong keys
  /// a transmitter, so both are asked rather than guessed.
  @override
  List<Map<String, dynamic>> configElements({
    Map<String, dynamic> overrides = const {},
    Map<String, dynamic> restrictions = const {},
  }) =>
      [
        // An overridden key is pinned by the entry and never the operator's
        // to answer, so it shows no field — the contract every other driver
        // with a config field keeps.
        if (!overrides.containsKey(winkeyerKeyPortConfigKey)) {
          'type': 'field',
          'fieldType': 'select',
          'key': winkeyerKeyPortConfigKey,
          'label': t.settings.station.winkeyerKeyPort,
          'description': t.settings.station.winkeyerKeyPortDescription,
          'options': [
            {'value': '1', 'label': t.settings.station.winkeyerKeyPortLabel(n: 1)},
            {'value': '2', 'label': t.settings.station.winkeyerKeyPortLabel(n: 2)},
          ],
        },
        if (!overrides.containsKey(winkeyerPttConfigKey)) {
          'type': 'field',
          'fieldType': 'checkbox',
          'key': winkeyerPttConfigKey,
          'label': t.settings.station.winkeyerPtt,
          'description': t.settings.station.winkeyerPttDescription,
        },
      ];

  @override
  EquipmentSession createSession(EquipmentSink sink, Map<String, dynamic> config) => WinkeyerSession(
        sink,
        keyPort: winkeyerKeyPortFromConfig(config),
        ptt: winkeyerPttFromConfig(config),
        speed: winkeyerSpeedFromConfig(config),
      );
}

/// The speed the operator last picked on this keyer, or [defaultCwSpeedWpm]
/// for one they have never set. Read straight out of the config rather than
/// through a field: it is remembered state, not a setting to edit.
int winkeyerSpeedFromConfig(Map<String, dynamic> config) {
  final raw = config[keyerSpeedConfigKey];
  final wpm = raw is num ? raw.toInt() : int.tryParse('$raw'.trim());
  return wpm == null ? defaultCwSpeedWpm : wpm.clamp(winkeyerSpeedMin, winkeyerSpeedMax);
}

/// Whether to drive the keyer's PTT line. Reads the string spellings too:
/// an entry that PINS this in its overrides carries whatever the catalogue
/// wrote, and the catalogue writes config values as strings.
bool winkeyerPttFromConfig(Map<String, dynamic> config) => switch (config[winkeyerPttConfigKey]) {
      final bool on => on,
      'true' => true,
      'false' => false,
      _ => false,
    };

/// The stored key port, or [winkeyerDefaultKeyPort] for anything that isn't
/// one of the two the hardware has — an entry saved before the field
/// existed, or a value hand-edited into the config blob.
int winkeyerKeyPortFromConfig(Map<String, dynamic> config) {
  final raw = config[winkeyerKeyPortConfigKey];
  final port = raw is num ? raw.toInt() : int.tryParse('$raw'.trim());
  return port == 1 || port == 2 ? port! : winkeyerDefaultKeyPort;
}

/// One message as queued: its id for the progress report, and its text.
class _Message {
  final int id;
  final String text;
  _Message(this.id, this.text);
}

class WinkeyerSession implements CwKeyerSession {
  final EquipmentSink _sink;

  /// Which of the keyer's two key/PTT jacks to drive, and whether its PTT
  /// line is used at all. See [_pinConfig].
  final int keyPort;
  final bool ptt;

  WinkeyerSession(
    this._sink, {
    this.keyPort = winkeyerDefaultKeyPort,
    this.ptt = false,
    this._speed = defaultCwSpeedWpm,
  });

  /// The PINCFG byte this session asserts. Sidetone stays off: the boxes
  /// that have a speaker are keyed next to the operator's own rig, and a
  /// second sidetone against the radio's is worse than none.
  int get _pinConfig =>
      (keyPort == 2 ? _pinKeyPort2 : _pinKeyPort1) | (ptt ? _pinPtt : 0);

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

  /// Seeded from the node's remembered speed, so a reconnect keys at the
  /// speed the operator chose rather than the default.
  int _speed;

  Timer? _pollTimer;
  Timer? _answerTimer;
  Timer? _sendWatchdog;

  /// Set when a status was asked for, so the reply can stand as a sign of
  /// life rather than as one more busy/XOFF change.
  bool _statusRequested = false;
  bool _problemShown = false;

  void _send(List<int> bytes) => _sink.send(bytes);

  /// A byte that is not the version says something is ON the port, never
  /// that host mode is OPEN — so it must not stand the open watch down. A
  /// keyer the last program left open pushes a status or a pot report before
  /// it answers ours, and taking that as the answer would cancel the watch
  /// on a keyer that then never opens: [_configure] would never run, and the
  /// operator would be told nothing while the keyer keys on whatever routing
  /// it was left with.
  void _answered() {
    if (_awaitingVersion) return;
    _withdrawProblem();
  }

  void _withdrawProblem() {
    if (!_problemShown) return;
    _problemShown = false;
    _sink.reportProblem(null);
  }

  /// Host mode is open — the one byte that proves it. The watch stands down
  /// and the keyer gets told what it is.
  void _hostOpened(int version) {
    _awaitingVersion = false;
    _answerTimer?.cancel();
    _answerTimer = null;
    _withdrawProblem();
    _sink.reportDiagnostic('WinKeyer v${version ~/ 10}.${version % 10}');
    _configure();
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
      _hostOpened(byte);
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
        // A keyer restating its speed is a keyer that is answering. There is
        // always a speed to restate once host mode is open — [_configure]
        // sets one rather than inheriting the box's — so a poll answered
        // before then is the only silent case, and asking a keyer that has
        // not finished opening for its pot would not fill it.
        refreshKeyerSpeed();
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
      final wpm = _potMinWpm + (byte & _potValueMask);
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
  ///
  /// Nothing goes out before host mode is open. A keyer that never answered
  /// ours may still be open from the LAST program, and would key this text
  /// on that program's routing — the dead carrier, reached through the send
  /// path rather than the connect path. The message stays queued; if the
  /// version never comes, the send watchdog gives up and says so.
  void _pump() {
    final current = _current;
    if (current == null || _xoff || _awaitingVersion) return;
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
    _currentEnds = cwCharacterEnds(_current!.text, _speed);
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
  void refreshKeyerSpeed() => _sink.reportKeyerSpeed(_speed);

  /// Everything the keyer must be TOLD, sent once the version byte says host
  /// mode is open.
  ///
  /// Every register here persists in the keyer between sessions, so a value
  /// this driver does not write is one the last program to touch the box
  /// chose. That is not a theoretical worry: a PINCFG with PTT enabled and
  /// no key output makes the keyer hold a dead carrier for the length of
  /// every message and key nothing.
  ///
  /// Written as individual commands rather than the `<0F>` Load Defaults
  /// block the manual recommends, DELIBERATELY: that block is not portable
  /// across firmware. Slot 9 is 1st Extension on WK2 but X2 Mode on WK3, and
  /// slot 15 is unused on WK2 but X1 Mode on WK3 — so one block sent to the
  /// wrong generation loads a millisecond count into a register whose bits
  /// are SO2R mode, paddle mute and paddle-status reporting. These commands
  /// mean the same thing on both.
  void _configure() {
    _send([_cmdSetMode, _modeSerialEchoback]);
    _send([_cmdSetPinConfig, _pinConfig]);
    _send([_cmdSetWeight, _weightNeutral]);
    _send([_cmdSetRatio, _ratioNeutral]);
    _send([_cmdSetKeyComp, _keyCompNone]);
    _send([_cmdSetPttTiming, _pttLeadIn, _pttTail]);
    _send([_cmdSetPotRange, _potMinWpm, _potRange, 0x00]);
    // A speed of our own, not the one the box came up with: on a keyer whose
    // speed is pot-locked and whose pot is absent (WKmini has none) an
    // unwritten speed is whatever the ADC floats at. The service builds a
    // NEW session per connect, so this is the remembered speed the node was
    // built with — see [EquipmentDriver.remembersKeyerSpeed].
    setKeyerSpeed(_speed);
    // The pot, where there is one, outranks that as soon as it reports — and
    // on a keyer with no pot, whatever the absent ADC answers outranks it
    // too, which is the cost of asking.
    _send([_cmdGetSpeedPot]);
    // A message pressed while the open was still outstanding was held by
    // [_pump] rather than keyed on the last program's routing; now it can go.
    _pump();
  }

  @override
  void startUpdates() {
    _awaitingVersion = true;
    // ONLY the open goes out here. "The host must wait for this return code
    // before any other commands or data can be sent" (WK2 and WK3 manuals,
    // Admin:Host Open) — until the version byte lands the keyer is still
    // closed and accepting admin commands only, so anything sent alongside
    // is read against the wrong state. [_configure] is the rest.
    _send([_admin, _adminHostOpen]);
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
  /// its paddle with nothing of ours left in its BUFFER.
  ///
  /// Its registers are another matter: PINCFG and the rest persist, and this
  /// cannot put back what was there — WK3 answers 0 to Get Values, so there
  /// was never anything to read first. So a connect permanently rewrites the
  /// operator's routing, and an operator whose amplifier keys off the PTT
  /// line will find it stops doing so under the paddle once HaLo has
  /// connected with PTT unchecked.
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
