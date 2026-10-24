// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What working a station would do for a chasing program's checklist
// (docs/design/claims.md §8): the claims a candidate contact makes, compared
// against the slots already held.

import 'claims.dart';

/// Ordered worst first: [rank] says how much a verdict is worth chasing.
enum ChaseVerdict {
  worked,
  unconfirmed,
  newMode,
  newBand,
  newRef;

  /// A new band and a new mode are worth the same: the program counts each
  /// slot once, whichever kind it is.
  int get rank => switch (this) {
    worked => 0,
    unconfirmed => 1,
    newMode || newBand => 2,
    newRef => 3,
  };

  static ChaseVerdict? tryParse(Object? value) => ChaseVerdict.values.asNameMap()[value];
}

/// One program's verdict on one candidate contact.
class ChaseJudgement {
  const ChaseJudgement({required this.program, required this.verdicts, this.guess = false, this.refs = const {}, this.band, this.mode});

  final String program;

  /// Every verdict at the best rank the candidate reaches: a new band and a
  /// new mode both, when the contact would fill one slot of each.
  final List<ChaseVerdict> verdicts;

  /// The claim deciding it names a reference the program inferred: "probably
  /// new", since a state guessed from a callsign is wrong for a station away
  /// from home.
  final bool guess;

  /// The references of the claims deciding it: for a new reference, the
  /// references the checklist lacks, which a spot row can point out among
  /// the ones it shows.
  final Set<String> refs;

  /// The band a new-band verdict is about, and the mode a new-mode one is:
  /// what a program's own notice names ("DXCC in 80m").
  final String? band;
  final String? mode;

  int get rank => verdicts.first.rank;

  @override
  bool operator ==(Object other) =>
      other is ChaseJudgement &&
      other.program == program &&
      other.guess == guess &&
      other.verdicts.join(',') == verdicts.join(',') &&
      other.refs.length == refs.length &&
      other.refs.containsAll(refs) &&
      other.band == band &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(program, guess, verdicts.join(','), Object.hashAllUnordered(refs), band, mode);

  @override
  String toString() => 'ChaseJudgement($program ${verdicts.map((v) => v.name).join('+')}${guess ? ' guess' : ''})';
}

/// The slot [claim] would fill, as [chaseSlotKeyOf] keys a stored one.
String chaseSlotKey(QsoClaim claim) => _slotKey(claim.holder, claim.edition, claim.ref, claim.band, claim.mode);

String chaseSlotKeyOf(StoredClaim claim) => _slotKey(claim.holder, claim.edition, claim.ref, claim.band, claim.mode);

String _slotKey(String holder, String edition, String ref, String? band, String? mode) =>
    '$holder\u0000$edition\u0000$ref\u0000${band ?? ''}\u0000${mode ?? ''}';

/// [program]'s verdict on a candidate making [claims], with [held] the level
/// of each slot already filled, by [chaseSlotKey]. Null when the candidate
/// claims nothing: the program does not apply to it.
///
/// A missing any-band, any-mode slot is a new reference, whatever else is
/// missing: the narrower slots of a reference never worked are new too, and
/// saying so adds nothing. Otherwise a missing slot naming a band is a new
/// band, and one naming only a mode a new mode. With every slot filled, one
/// still at `worked` makes it unconfirmed: working the station again may
/// bring the QSL.
ChaseJudgement? judgeChaseClaims(String program, List<QsoClaim> claims, Map<String, ClaimLevel> held) {
  if (claims.isEmpty) return null;
  final missing = [
    for (final claim in claims)
      if (!held.containsKey(chaseSlotKey(claim))) claim,
  ];
  ChaseJudgement judged(List<ChaseVerdict> verdicts, Iterable<QsoClaim> deciding, {String? band, String? mode}) => ChaseJudgement(
    program: program,
    verdicts: verdicts,
    guess: deciding.any((claim) => claim.guess),
    refs: {for (final claim in deciding) claim.ref},
    band: band,
    mode: mode,
  );

  final newRefs = missing.where((claim) => claim.band == null && claim.mode == null);
  if (newRefs.isNotEmpty) return judged(const [ChaseVerdict.newRef], newRefs);
  final newBands = missing.where((claim) => claim.band != null);
  final newModes = missing.where((claim) => claim.band == null && claim.mode != null);
  if (missing.isNotEmpty) {
    return judged(
      [if (newBands.isNotEmpty) ChaseVerdict.newBand, if (newModes.isNotEmpty) ChaseVerdict.newMode],
      missing,
      band: newBands.firstOrNull?.band,
      mode: newModes.firstOrNull?.mode,
    );
  }
  final unconfirmed = claims.where((claim) => held[chaseSlotKey(claim)] == ClaimLevel.worked);
  if (unconfirmed.isNotEmpty) return judged(const [ChaseVerdict.unconfirmed], unconfirmed);
  return judged(const [ChaseVerdict.worked], const []);
}

/// A chasing verdict as a scoring notice key, so the call-info pills and the
/// spot rows carry it beside the scorers' own (`newBand`, `duplicate`…).
/// [alerting] marks a verdict the operator asked to be alerted to. A new
/// band carries its [band] and a new mode its [mode], for a program that
/// names them in its own words; a reader that knows neither flag skips it.
class ChaseNotice {
  const ChaseNotice({required this.program, required this.verdict, this.guess = false, this.alerting = false, this.band, this.mode});

  static const _prefix = 'chase:';

  final String program;
  final ChaseVerdict verdict;
  final bool guess;
  final bool alerting;
  final String? band;
  final String? mode;

  String get key =>
      '$_prefix$program:${verdict.name}${guess ? ':guess' : ''}${alerting ? ':alert' : ''}'
      '${band != null ? ':band=${Uri.encodeComponent(band!)}' : ''}${mode != null ? ':mode=${Uri.encodeComponent(mode!)}' : ''}';

  /// Null for a key that is not a chasing notice: every other scorer's.
  static ChaseNotice? tryParse(String key) {
    if (!key.startsWith(_prefix)) return null;
    final parts = key.substring(_prefix.length).split(':');
    if (parts.length < 2) return null;
    final verdict = ChaseVerdict.tryParse(parts[1]);
    if (parts[0].isEmpty || verdict == null) return null;
    final flags = parts.skip(2).toSet();
    String? valueOf(String name) {
      final flag = flags.where((flag) => flag.startsWith('$name=')).firstOrNull;
      return flag == null ? null : Uri.decodeComponent(flag.substring(name.length + 1));
    }

    return ChaseNotice(
      program: parts[0],
      verdict: verdict,
      guess: flags.contains('guess'),
      alerting: flags.contains('alert'),
      band: valueOf('band'),
      mode: valueOf('mode'),
    );
  }
}
