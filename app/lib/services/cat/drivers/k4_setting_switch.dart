// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A K4 setting put to one value for a phone message from the computer, and
// back after — docs/design/cat.md § The computer's voice keyer. Over USB or
// the LAN CAT port it is MI, the voice modes' transmit input, set to LINE IN
// so the recording on the K4's sound card goes out rather than its mic; over
// the secure remote connection it is EM, the client's audio encoding, set to
// the raw 16-bit format this app sends. Either one left at the message's
// value takes something from the operator — a dead mic, a remote audio
// stream at ten times its bandwidth — so it is read back, retried, and owed
// to the next session to the radio when a link drops before it is put back.
//
// The K4 answers these reads in the order they were asked, and a reply names
// the setting but not the question, so each reply is matched to the oldest
// read still unanswered. A reply that never comes would shift every later
// one onto the wrong question, so reads still unanswered after a quiet spell
// are given up on. Not yet met on hardware.

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../error_reporting_service.dart';

/// `MI2`: the voice modes transmit LINE IN alone — from the source `LI`
/// picks, the K4's USB sound card or its LINE IN jack, which is the shack's
/// wiring and left alone. The data modes always transmit LINE IN.
const k4MicInputLineIn = 2;

/// `EM1`: the remote client's audio as raw 16-bit samples, the format this
/// app sends (k4_remote_audio.dart).
const k4EncodeRaw16 = 1;

enum _Read { plain, verify, restore }

class K4SettingSwitch {
  K4SettingSwitch({required this.command, required this.value, required this.send, required this.diagnose, required this.refused, this.radio})
    : _earlier = radio == null ? null : _owedByRadio['$radio $command'];

  /// The setting's two letters, `MI` or `EM`.
  final String command;

  /// What the message needs it at.
  final int value;

  final void Function(String text) send;
  final void Function(String what) diagnose;

  /// The setting read as something else just after the key: the set did
  /// not take, and the radio is transmitting without the recording.
  final void Function(int read) refused;

  /// What identifies the radio across sessions — its address, or its serial
  /// port — which a restore still owed is kept by; null when nothing does.
  final String? radio;

  /// Settings this app moved and has not seen put back, by radio and
  /// setting, for the whole launch.
  static final _owedByRadio = <String, int>{};

  /// Forgets every restore owed: the tests' way to start each from a radio
  /// the app never keyed.
  @visibleForTesting
  static void forgetOwed() => _owedByRadio.clear();

  String get _key => '$radio $command';

  /// A restore an earlier session owed this radio, not yet settled.
  int? _earlier;

  /// What to put back after the message, once this switch has moved it.
  int? _owed;
  bool _switched = false;
  bool _known = false;
  int? _current;

  /// What each read still unanswered asked for, oldest first.
  final _reads = <_Read>[];

  int _tries = 0;
  Timer? _retry;
  Timer? _unanswered;

  static const _maxTries = 3;
  static const _retryAfter = Duration(milliseconds: 500);

  /// Long past any reply, even over the internet to a remote radio.
  static const _answerWithin = Duration(seconds: 2);

  /// Whether a restore is owed: what an unkey must not skip, even with the
  /// message's output gone.
  bool get owesRestore => _switched;

  String get _query => '$command;';
  String _set(int to) => '$command$to;';

  String _ask(_Read why) {
    _reads.add(why);
    _awaitAnswers();
    return _query;
  }

  void _awaitAnswers() {
    _unanswered?.cancel();
    _unanswered = _reads.isEmpty ? null : Timer(_answerWithin, _giveUp);
  }

  /// The radio went quiet with reads unanswered: none of them is coming. A
  /// restore whose check was among them is sent again.
  void _giveUp() {
    final restoring = _reads.contains(_Read.restore);
    _reads.clear();
    if (restoring && _switched) _restore();
  }

  /// Asks for the setting, so the key needs no question first.
  void read() => send(_ask(_Read.plain));

  /// Settles a restore an earlier session owed this radio: put back when the
  /// setting still reads the message's value, forgotten when the operator has
  /// moved it since.
  void settle() {
    if (_earlier != null) read();
  }

  /// What goes out ahead of the key: the set, behind a read when the
  /// setting is not yet known — that answer is what is put back — or nothing
  /// when it already reads the message's value, the operator's own choice,
  /// left alone after.
  String beforeKey() {
    _retry?.cancel();
    _tries = 0;
    // A restore's check still on its way answers for the message before:
    // taken as this one's, it would say the setting is back while this
    // message has it at [value].
    for (var i = 0; i < _reads.length; i++) {
      if (_reads[i] == _Read.restore) _reads[i] = _Read.plain;
    }
    if (_earlier case final earlier?) {
      // Put back after this message instead.
      _earlier = null;
      _switched = true;
      _owed = earlier;
    }
    if (_switched) return _set(value);
    if (_known && _current == value) return '';
    _switched = true;
    _owed = _known ? _current : null;
    _remember();
    return '${_known ? '' : _ask(_Read.plain)}${_set(value)}';
  }

  /// The read to follow the key, checking the set took; empty when nothing
  /// was set.
  String verify() => _switched ? _ask(_Read.verify) : '';

  /// Puts the setting back after the unkey, and reads it to see it took.
  void afterUnkey() {
    if (_switched) _restore();
  }

  /// A closing connection: the restore goes out behind the unkey — the K4
  /// takes ASCII commands in order — but nothing will read it back, so it
  /// stays owed to the next session.
  void teardown(void Function(String text) direct) {
    _retry?.cancel();
    _unanswered?.cancel();
    _reads.clear();
    if (_switched && _owed != null) direct(_set(_owed!));
  }

  void _remember() {
    if (radio != null && _owed != null) _owedByRadio[_key] = _owed!;
  }

  void _forget() {
    if (radio != null) _owedByRadio.remove(_key);
  }

  void _restore() {
    final owed = _owed;
    if (owed == null) {
      // The setting was never read: there is nothing known to put back.
      _switched = false;
      diagnose('$command left at $value: its setting before the message was never read');
      return;
    }
    if (_tries >= _maxTries) {
      _switched = false;
      _forget();
      diagnose('$command left at $value after $_tries restores');
      ErrorReportingService.report(K4SettingLeftOn(command, value), StackTrace.current, context: 'k4:setting-restore');
      return;
    }
    _tries++;
    send('${_set(owed)}${_ask(_Read.restore)}');
  }

  /// A reply to this setting's command, by its parameters; true when it was
  /// this setting's.
  bool heard(String params) {
    if (params.length != 1) return false;
    final read = int.tryParse(params);
    if (read == null) return false;
    _known = true;
    _current = read;
    final why = _reads.isEmpty ? _Read.plain : _reads.removeAt(0);
    _awaitAnswers();
    if (_earlier case final earlier? when !_switched) {
      _earlier = null;
      if (read == value) {
        _switched = true;
        _owed = earlier;
        _restore();
      } else {
        _forget();
      }
      return true;
    }
    switch (why) {
      case _Read.plain:
        if (_switched && _owed == null) {
          if (read == value) {
            // Already at the message's value before the set.
            _switched = false;
          } else {
            _owed = read;
            _remember();
          }
        }
      case _Read.verify:
        if (read != value) refused(read);
      case _Read.restore:
        if (!_switched) return true;
        if (read == _owed) {
          _switched = false;
          _tries = 0;
          _forget();
        } else {
          _retry?.cancel();
          _retry = Timer(_retryAfter, _restore);
        }
    }
    return true;
  }

  void dispose() {
    _retry?.cancel();
    _unanswered?.cancel();
  }
}

/// A setting this app moved for a message, still at the message's value
/// after every restore it sent: for MI, the operator's mic is dead until they
/// set it back on the radio.
class K4SettingLeftOn implements Exception {
  final String command;
  final int value;

  const K4SettingLeftOn(this.command, this.value);

  @override
  String toString() => 'K4SettingLeftOn: $command left at $value after the restores sent did not take';
}

/// The set refused just after the key: the radio read [read] instead.
class K4SettingRefused implements Exception {
  final String command;
  final int read;

  const K4SettingRefused(this.command, this.read);

  @override
  String toString() => 'K4SettingRefused: $command read $read after the set';
}
