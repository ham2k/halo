// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The draft suggestions one set shows (docs/design/logging-fields.md § Draft
// suggestions): the list an extension offered for the call being typed, the
// call the set's field reads, and which suggestion was picked. The set's
// LoggingControls owns the picking — Alt-Y and a tap both land there — and
// its FYI area draws the line from this.

import 'package:flutter/foundation.dart';

/// One suggestion: a draft QSO and what the scorers say logging it would be.
@immutable
class DraftSuggestion {
  const DraftSuggestion({required this.call, required this.qso, this.notices = const {}, this.alerts = const {}});

  /// Trimmed and uppercased, as the call field reads calls.
  final String call;

  /// The fields a pick lays over the contact — `their.call` among them, and
  /// never `freq`, `band` or `mode`: a pick does not move the radio.
  final Map<String, dynamic> qso;

  /// The scorers' verdicts, as the logging fields' pills carry them —
  /// `duplicate`, `newMult` and the rest.
  final Set<String> notices;
  final Set<String> alerts;

  bool get isDuplicate => notices.contains('duplicate') || alerts.contains('duplicate');
}

/// What one extension offered for one text in the call field.
@immutable
class DraftSuggestionList {
  const DraftSuggestionList({required this.forCall, required this.drafts});

  /// The call field's text the list was made for, trimmed and uppercased.
  final String forCall;
  final List<DraftSuggestion> drafts;
}

/// The call field's text as a list is matched against it.
String suggestionCallText(String text) => text.trim().toUpperCase();

class DraftSuggestions extends ChangeNotifier {
  DraftSuggestionList? _list;
  String _call = '';
  int? _picked;
  void Function(int index)? _onTap;

  DraftSuggestionList? get list => _list;

  /// The list for what the set's call field reads, as the app picks it. A
  /// pick survives a new list that still holds its call.
  set list(DraftSuggestionList? list) {
    if (identical(list, _list)) return;
    final pickedCall = _pickedCall;
    _list = list;
    shownCount = null;
    final at = pickedCall == null ? -1 : (list?.drafts.indexWhere((d) => d.call == pickedCall) ?? -1);
    _picked = at < 0 ? null : at;
    notifyListeners();
  }

  /// What the set's call field reads, trimmed and uppercased — fed by the
  /// set on every change. A call that is no longer the one picked unpicks it.
  set call(String text) {
    final call = suggestionCallText(text);
    if (call == _call) return;
    _call = call;
    if (_picked != null && _pickedCall != call) _picked = null;
    notifyListeners();
  }

  String get call => _call;

  /// The suggestion picked, while the call field still reads its call.
  int? get picked => _picked;
  set picked(int? index) {
    if (index == _picked) return;
    _picked = index;
    notifyListeners();
  }

  String? get _pickedCall => switch ((_picked, _list)) {
    (final i?, final list?) when i < list.drafts.length => list.drafts[i].call,
    _ => null,
  };

  /// Whether the line shows: a list made for what the field reads, or one a
  /// suggestion was picked from. Whether a logged contact is open is the
  /// line's own business — it hides then, as the keyer line does.
  bool get showing {
    final list = _list;
    return list != null && list.drafts.isNotEmpty && (list.forCall == _call || _picked != null);
  }

  /// How many of the list's calls the line has room for, from the first —
  /// all Alt-Y walks, since a call the operator cannot see is no pick. Set by
  /// the line as it lays out, so it notifies nothing; null until it has.
  int? shownCount;

  /// Wired by the set's LoggingControls, which picks: a tap on the line lands
  /// there as Alt-Y does.
  set onTap(void Function(int index)? onTap) => _onTap = onTap;

  /// Unwires [onTap], if it is still the one wired: a LoggingControls
  /// remounted over the same set wires its own before the old one goes.
  void releaseTap(void Function(int index) onTap) {
    if (_onTap == onTap) _onTap = null;
  }

  /// A tap on the [index]th call of [drawn], the list the line drew it from —
  /// nothing when a newer list has come since, whose [index]th call is not
  /// the one tapped.
  void tap(DraftSuggestionList drawn, int index) {
    if (identical(drawn, _list)) _onTap?.call(index);
  }
}
