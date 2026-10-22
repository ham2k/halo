// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator picks in the ⌘K palette, per typed text — the record the
// palette ranks its rows by (command_dialog.dart). Device-local preferences:
// it is this operator's habit on this device, not data to sync.

import 'dart:convert';

import 'settings_service.dart';

const _commandPicksKey = 'commandPalettePicks';

/// How many distinct texts [CommandPicks.commandPicks] remembers. The least
/// recently picked go first: the map is kept in pick order, most recent last.
const commandPicksLimit = 200;

extension CommandPicks on SettingsService {
  /// `{TEXT: {resultIdentity: count}}`, the text trimmed and uppercased. The
  /// palette ranks a text's rows by these counts, so a row the operator keeps
  /// scrolling down to comes up first next time.
  Map<String, dynamic> get commandPicks => jsonMapPref(_commandPicksKey);

  /// Counts one pick of [identity] for [text]. No `notifyListeners`: nothing
  /// on screen shows these, and every settings listener rebuilding on each
  /// pick would be all cost.
  Future<void> recordCommandPick(String text, String identity) async {
    final picks = {...commandPicks};
    final previous = picks.remove(text);
    final counts = <String, dynamic>{if (previous is Map) ...previous.cast<String, dynamic>()};
    final count = counts[identity];
    counts[identity] = (count is num ? count.toInt() : 0) + 1;
    picks[text] = counts;
    while (picks.length > commandPicksLimit) {
      picks.remove(picks.keys.first);
    }
    await prefs.setString(_commandPicksKey, jsonEncode(picks));
  }
}
