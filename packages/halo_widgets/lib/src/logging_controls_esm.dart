// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Enter Sends Messages: which messages an Enter keys, and what it does to the
// entry afterwards, for where the contact stands. The panel supplies the
// facts and carries out the answer; the app decides whether ESM is on, which
// side of the pileup the operator is on, and what each message says
// (docs/design/logging-fields.md § Enter Sends Messages).

/// What a message IS in an exchange, independent of which key holds it — the
/// app maps each to its function key.
enum EsmMessage { cq, exchange, thanks, myCall, hisCall, again }

/// What the entry does once the messages are handed over.
enum EsmThen {
  /// Nothing — the call field keeps focus and nothing is logged.
  stay,

  /// Focus moves to the first exchange field still empty, or the first one
  /// when none is — or, with reports only, to the received report.
  toExchange,

  /// The contact is logged, as a plain Enter would.
  log,
}

typedef EsmStep = ({List<EsmMessage> send, EsmThen then});

/// What a step that logs hands its thanks: [qso], the contact as it was
/// saved — after `decorateQsoBeforeSave` and the serial its commit took — and
/// [next], the entry as the log left it, wiped, with the rest of a `//` stack
/// back in the field. A comma list's [qso] is its first call, the one whose
/// serial the operator saw.
typedef EsmLogged = ({Map<String, dynamic> qso, Map<String, dynamic> next});

/// Whether ESM is on, and which side of the exchange the operator is on.
/// [LoggingSession.enterSends] answering null means off — Enter logs, as always.
class EnterSends {
  const EnterSends({required this.running, required this.send});

  /// Run (calling CQ, answering callers) rather than Search & Pounce.
  final bool running;

  /// Keys [messages], in order, rendered against [qso] — the draft as it is at
  /// the keypress, since a log that follows wipes it before any render would
  /// finish.
  ///
  /// [logged], on a step that logs, completes with the contact as saved and
  /// the entry the log left ([EsmLogged]), or null when the log failed. The
  /// thanks renders against that instead: `{{ qso.call }}` in it is the
  /// station just logged, with whatever an extension added on the way to the
  /// log, `{{ next.call }}` the one up next, and a failed log thanks nobody.
  final void Function(List<EsmMessage> messages, Map<String, dynamic> qso, {Future<EsmLogged?>? logged}) send;
}

/// The step an Enter takes, or null when ESM has nothing to say and Enter
/// means what it always does.
///
/// [answered] is the contact's own progress: the first step (calling the
/// station, or giving a caller their exchange) has already gone out for the
/// call now in the field. It is what separates the two Enters of an exchange,
/// rather than which field has focus, so a second Enter from the call field —
/// no exchange field to move to, or the operator went back to it — still
/// completes the contact.
///
/// [exchangeCopied] is whether ANY exchange field holds something, not
/// whether all do: an exchange with a part the other station legitimately
/// omits (a DX station's NAQP location, an optional pick) would otherwise ask
/// again forever and never log. Asking again is for having copied nothing.
///
/// [callFocused] is whether Enter came from the call field. Running, with
/// nothing copied, that re-sends their call and the exchange rather than
/// AGN?: the operator went back to the call to correct it, or moved the
/// cursor to another call in a stack, and either way the station to answer
/// is the one in the field now — asking again would not name it.
///
/// [hasExchange] is whether the contact has fields to copy beyond the reports.
/// With none, the second Enter always completes: the report they send back
/// carries a default, so there is never nothing copied to ask again for. It is
/// still two Enters, running or S&P — running, the caller's report comes back
/// after their exchange, and a thanks keyed with it would talk over them.
///
/// [incompleteCall] is a call with a `?` in it — a partial being asked back,
/// running or S&P. It keys their call as typed, `?` and all, which is the
/// asking, and stays: no exchange goes to a station that has not answered,
/// and the plain log that would follow accepts an incomplete call.
EsmStep? esmStep({
  required bool running,
  required bool callEmpty,
  required bool canLog,
  required bool answered,
  required bool hasExchange,
  required bool exchangeCopied,
  bool callFocused = false,
  bool incompleteCall = false,
}) {
  if (callEmpty) {
    return running ? (send: const [EsmMessage.cq], then: EsmThen.stay) : null;
  }
  if (incompleteCall) return (send: const [EsmMessage.hisCall], then: EsmThen.stay);
  // Not a callsign — the refusal a plain Enter gives is the right answer.
  if (!canLog) return null;
  final copied = !hasExchange || exchangeCopied;
  if (running) {
    if (!answered || (callFocused && !copied)) return (send: const [EsmMessage.hisCall, EsmMessage.exchange], then: EsmThen.toExchange);
    if (!copied) return (send: const [EsmMessage.again], then: EsmThen.toExchange);
    return (send: const [EsmMessage.thanks], then: EsmThen.log);
  }
  if (!answered) return (send: const [EsmMessage.myCall], then: EsmThen.toExchange);
  // Nothing to ask again for in S&P: the station is the one running, and
  // the operator's missing copy is theirs to ask for by hand.
  if (!copied) return (send: const [], then: EsmThen.toExchange);
  return (send: const [EsmMessage.exchange], then: EsmThen.log);
}

/// What [esmStep] reads off the entry — all of it but the side of the
/// pileup, which the app holds. A record, so a repeat compares equal and
/// publishes nothing.
typedef EsmFacts = ({bool callEmpty, bool canLog, bool answered, bool hasExchange, bool exchangeCopied, bool callFocused, bool incompleteCall});

/// [esmStep] for [facts], on the side [running] says.
EsmStep? esmStepFor(EsmFacts facts, {required bool running}) => esmStep(
  running: running,
  callEmpty: facts.callEmpty,
  canLog: facts.canLog,
  answered: facts.answered,
  hasExchange: facts.hasExchange,
  exchangeCopied: facts.exchangeCopied,
  callFocused: facts.callFocused,
  incompleteCall: facts.incompleteCall,
);
