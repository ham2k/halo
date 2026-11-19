// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Summaries pane: what the Info pane says about an operation —
// its stats, each day, every scorer's tallies — drawn by the Info pane
// itself (`InformationPanel`), with its folds, order, theme and settings.
// Unlike the Info pane it never turns into Call Info: a running score stays
// on screen while the next call is typed.
//
// The picks belong to the PLACEMENT (docs/design/layouts.md), so one pane can
// carry a contest's score while another carries the states grid.

/// The panel id the view registers this pane under, and matches placements
/// against.
const String operationSummariesPanelId = 'summaries';

List<String> summariesKeyList(Object? stored) => stored is List ? stored.whereType<String>().toList() : const [];
