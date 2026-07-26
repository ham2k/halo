// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/widgets.dart';

import '../i18n/strings.g.dart';

/// Localized pill text for a scoring notice/alert key, falling back to the raw
/// key. Shared by the compact call-info line (`logging_panel.dart`) and the
/// call-info detail panel.
///
/// The vocabulary is open — a contest may emit its own keys — but every notice
/// a shipped scorer produces belongs here: an unlabelled key reaches the
/// operator as raw camelCase, which is worse than useless mid-contest.
String scoreNoticeLabel(BuildContext context, String key) {
  final t = context.t.loggingControls.info;
  return switch (key) {
    'duplicate' => t.noticeDupe,
    'newBand' => t.noticeNewBand,
    'newMode' => t.noticeNewMode,
    'newDXCC' => t.noticeNewDXCC,
    // Activity scorers: a repeat contact that counts again because the award's
    // `uniquePer` axes make it fresh (docs/design/activities.md §4).
    'newDay' => t.noticeNewDay,
    'newRef' => t.noticeNewRef,
    // Contest scorers (docs/design/contests.md M2 onward).
    'newMult' => t.noticeNewMult,
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
    // The operation names an event this build doesn't know — a log from a newer
    // app, or next year's event added elsewhere first. Nothing scores, and the
    // operator has to be told why rather than reading a silent zero.
    'unknownEvent' => t.noticeUnknownEvent,
    _ => key,
  };
}
