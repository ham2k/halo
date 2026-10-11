// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A read the radio on the line may not have — its tuner, its filter, its
// antenna ports, a DATA submode — asked until the radio shows it has none,
// and then not for the rest of the session. Shared by the Icom, Yaesu and
// Kenwood drivers; what counts as a refusal or a silence is each protocol's,
// and so is whether an answer heard after giving up reopens the read.

import '../driver.dart';

/// How many refusals without an answer between before a read is given up.
/// More than one because a refusal names no command — a CI-V NG, a `?;` —
/// so one landing late for something else must not cost a radio that has
/// the read its readout for the whole connection.
const optionalReadRefusals = 2;

/// How many silences without an answer between before a read is given up —
/// more than [optionalReadRefusals], since an answer lost on a busy link
/// says less than a refusal does.
const optionalReadSilences = 3;

class OptionalRead {
  /// [asked] false is an entry pinning the read off: never asked, and no
  /// answer reopens it.
  OptionalRead(this._sink, this._diagnostic, {required this._onGiveUp, this._asked = true}) : _available = _asked;

  final EquipmentSink _sink;
  final String _diagnostic;
  final void Function() _onGiveUp;
  final bool _asked;

  bool _available;
  int _refusals = 0;
  int _silences = 0;
  bool _silencePending = false;
  bool _out = false;
  bool _refusedSinceSent = false;

  /// Whether the session still asks.
  bool get available => _available;

  /// For a protocol whose refusal names no command and may answer anything
  /// in the same poll (`?;`): judges the read last [sent], now that its
  /// answer has had a whole poll to arrive — a refusal only if one was heard
  /// while it was out and no answer came. False when the read is not to be
  /// asked: given up before, or by this judgement.
  bool judge() {
    if (!_available) return false;
    if (_out && _refusedSinceSent && refused()) return false;
    return true;
  }

  /// The read went out; [judge] weighs what is heard from here.
  void sent() {
    _out = true;
    _refusedSinceSent = false;
  }

  /// Nothing went out after all — the mode has nothing to ask — so there is
  /// nothing for the next [judge] to weigh.
  void cancel() => _out = false;

  /// A refusal heard on the line, counted against this read only while it is
  /// out — see [judge].
  void heardRefusal() {
    if (_out) _refusedSinceSent = true;
  }

  /// A refusal taken as this read's. True when it is the one that gives the
  /// read up.
  bool refused() => _strike(++_refusals >= optionalReadRefusals);

  /// The read went unanswered — counted only once [heardFromRadio] says the
  /// radio was answering at the time, and dropped by [radioWentSilent] if it
  /// was not. A radio that answers nothing is switched off, not lacking the
  /// read, and must not lose it for the session by being off for a while.
  void unanswered() => _silencePending = true;

  /// Another command went unanswered too: the radio is answering nothing, so
  /// a silence [unanswered] noted was not the read's own. Without this, each
  /// time the radio is switched off leaves a strike on a read it is not asked
  /// again once back on — the width read, in a mode without one.
  void radioWentSilent() => _silencePending = false;

  /// The radio has answered something since: a silence [unanswered] noted
  /// was the read's own.
  void heardFromRadio() {
    if (!_silencePending) return;
    _silencePending = false;
    _strike(++_silences >= optionalReadSilences);
  }

  /// Gives the read up when [enough] — reporting the diagnostic and running
  /// `onGiveUp`, once.
  bool _strike(bool enough) {
    if (!_available || !enough) return false;
    _available = false;
    _out = false;
    _silencePending = false;
    _sink.reportDiagnostic(_diagnostic);
    _onGiveUp();
    return true;
  }

  /// An answer, or a new connection: the read is asked, whatever strikes came
  /// before — a given-up one included, though never one pinned off. A driver
  /// that must not reopen one (the answer being another program's) checks
  /// [available] first.
  void reset() {
    _available = _asked;
    _refusals = 0;
    _silences = 0;
    _silencePending = false;
    _out = false;
  }
}
