// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';
import 'package:halo_core/halo_core.dart' show ChaseNotice, ChaseVerdict, ChasingProgram;

import 'package:halo_i18n/halo_i18n.dart';

/// Localized pill text for a scoring notice/alert key, falling back to the raw
/// key. Shared by the compact call-info line (`logging_panel.dart`) and the
/// call-info detail panel.
///
/// The vocabulary is open — a contest may emit its own keys — but every notice
/// a shipped scorer produces belongs here: an unlabelled key reaches the
/// operator as raw camelCase, which is worse than useless mid-contest.
///
/// A chasing verdict ([ChaseNotice]) reads with what its program calls one
/// reference ([ChasingProgram.refLabel]), from [programs]; a program no
/// longer registered reads by its key.
String scoreNoticeLabel(BuildContext context, String key, {Map<String, ChasingProgram> programs = const {}}) {
  if (ChaseNotice.tryParse(key) case final chase?) return _chaseNoticeLabel(context, chase, programs[chase.program]?.refLabel ?? chase.program);
  final t = context.t.loggingControls.info;
  return switch (key) {
    'duplicate' => t.noticeDupe,
    'newBand' => t.noticeNewBand,
    'newMode' => t.noticeNewMode,
    'newDXCC' => t.noticeNewDXCC,
    // States and provinces are tracked only for North American operators, so
    // these two never reach a DX operator's pill row at all.
    'newState' => t.noticeNewState,
    'newProvince' => t.noticeNewProvince,
    // Activity scorers: a repeat contact that counts again because the award's
    // `uniquePer` axes make it fresh (docs/design/activities.md §4).
    'newDay' => t.noticeNewDay,
    'newRef' => t.noticeNewRef,
    // Contest scorers (docs/design/contests.md M2 onward).
    'newMult' => t.noticeNewMult,
    'newSection' => t.noticeNewSection,
    'newZone' => t.noticeNewZone,
    'workedBefore' => t.noticeWorkedBefore,
    // A park new to the log (M5's state-park events), and a station the event
    // pays a bonus for working.
    'newPark' => t.noticeNewPark,
    'bonusStation' => t.noticeBonusStation,
    // Alerts: the QSO doesn't count toward this contest.
    'invalidMode' => t.noticeInvalidMode,
    'invalidBand' => t.noticeInvalidBand,
    'invalidCategory' => t.noticeInvalidCategory,
    // The QSO counts, but its exchange doesn't — nothing was sent, or what was
    // sent isn't a value this contest recognizes. Either way a multiplier is
    // being lost silently unless the operator is told (M4).
    'missingExchange' => t.noticeMissingExchange,
    'invalidExchange' => t.noticeInvalidExchange,
    // A QSO party's rare county (NC), worth several times an ordinary contact.
    'rareCounty' => t.noticeRareCounty,
    // The operation carries no county yet — a QSO party scores every contact as
    // ours × theirs, so until the operator says where they are, nothing counts.
    'ourLocation' => t.noticeOurLocation,
    // The operation carries no grid yet — a distance-scoring contest
    // (arrl-vhf-tests) can't score anything until the operator sets one.
    'ourGrid' => t.noticeOurGrid,
    // The grid is there but shorter than the event's exchange (a 4-character
    // entry in a 6-character 10 GHz event): the distance still scores, the
    // QSO points don't, and the operator can still ask for the rest.
    'shortGrid' => t.noticeShortGrid,
    // The operation names an event this build doesn't know — a log from a newer
    // app, or next year's event added elsewhere first. Nothing scores, and the
    // operator has to be told why rather than reading a silent zero.
    'unknownEvent' => t.noticeUnknownEvent,
    // Not a scorer's: the panel's own answer for a call with a `?` in it,
    // which no scorer is shown (`isIncompleteCall`).
    'incompleteCall' => t.noticeIncompleteCall,
    _ => key,
  };
}

String _chaseNoticeLabel(BuildContext context, ChaseNotice notice, String program) {
  final t = context.t.chase.notice;
  return switch (notice.verdict) {
    ChaseVerdict.newRef => notice.guess ? t.newRefGuess(program: program) : t.newRef(program: program),
    ChaseVerdict.newBand => notice.guess ? t.newBandGuess(program: program) : t.newBand(program: program),
    ChaseVerdict.newMode => notice.guess ? t.newModeGuess(program: program) : t.newMode(program: program),
    ChaseVerdict.unconfirmed => t.unconfirmed(program: program),
    ChaseVerdict.worked => program,
  };
}
