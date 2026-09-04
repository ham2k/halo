// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What editing an operation's station or operator callsign means for the
// contacts already logged under the old one.
//
// Changing the call in the Operation Details dialog only decides what FUTURE
// contacts are stamped with. Everything already logged keeps the call it was
// made under, which is right when the operator genuinely swapped calls
// mid-operation and wrong when they were fixing a typo — and only they know
// which. So the dialog states what is in the log and offers the restamp,
// rather than choosing for them (app-polo's `OperationStationInfoScreen`
// does the same).

/// What the log has to say about a callsign the operator is typing.
enum CallChange {
  /// Nothing to say: no contacts yet, or no callsign typed.
  quiet,

  /// Every contact already carries the typed call. Nothing to offer.
  agrees,

  /// The contacts that don't carry the typed call carry one OTHER call, or
  /// none at all ([CallChangeAdvice.previous] is then empty). This is the
  /// restamp offer.
  ///
  /// A partly-stamped log lands here, not in [agrees]: an operator named
  /// halfway through an operation leaves every earlier contact blank, and
  /// reading that as "the log already agrees" is what would strand them.
  single,

  /// Contacts carry several different calls. Nothing safe to offer: no single
  /// old value means "the one that was wrong".
  several,
}

/// [CallChange] plus what a message needs to name it.
class CallChangeAdvice {
  final CallChange change;

  /// The call every contact in [CallChangeAdvice.count] carries, for
  /// [CallChange.single] — empty when those contacts carry no call at all.
  /// The calls in use, for [CallChange.several]. Empty otherwise.
  final List<String> previous;

  /// How many contacts a restamp would rewrite: those not already carrying
  /// the typed call. Contacts that already carry it are not counted, and are
  /// not written — the number on the offer is what actually changes.
  final int count;

  const CallChangeAdvice(this.change, {this.previous = const [], this.count = 0});
}

/// Whether a restamp to [typed] would change a contact carrying [call].
///
/// The advice's count and the caller's list of records to write both come
/// through here, so the number the operator agreed to cannot drift from the
/// set that gets written.
bool callNeedsChange(String call, String typed) => call.trim().toUpperCase() != typed.trim().toUpperCase();

/// Read [calls] — one entry per contact in scope, `''` where the contact
/// carries no such call — against the [typed] value.
///
/// Contacts, not distinct calls, is what comes in: the count of what a
/// restamp would rewrite has to come from the same scan, and deriving it from
/// a set of distinct values would lose it.
CallChangeAdvice adviceForCallChange({required Iterable<String> calls, required String typed}) {
  final wanted = typed.trim().toUpperCase();
  final scanned = calls.toList();
  if (wanted.isEmpty || scanned.isEmpty) return const CallChangeAdvice(CallChange.quiet);

  final changing = [
    for (final call in scanned)
      if (callNeedsChange(call, wanted)) call,
  ];
  if (changing.isEmpty) return const CallChangeAdvice(CallChange.agrees);

  final others = <String>{
    for (final call in changing)
      if (call.trim().isNotEmpty) call.trim().toUpperCase(),
  };
  // Several other calls in use: no single old value means "the one that was
  // wrong", so there is nothing safe to offer. What gets NAMED is every call
  // in the log, the typed one included — "already has contacts under N0DEV,
  // W2XYZ" is false when a third of them are already under the call being
  // typed.
  if (others.length > 1) {
    final inUse = <String>{
      for (final call in scanned)
        if (call.trim().isNotEmpty) call.trim().toUpperCase(),
    };
    return CallChangeAdvice(CallChange.several, previous: inUse.toList()..sort());
  }
  return CallChangeAdvice(CallChange.single, previous: others.toList(), count: changing.length);
}
