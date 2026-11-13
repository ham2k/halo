// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What each logging set shows of the draft suggestions offered for its
// operation (docs/design/logging-fields.md § Draft suggestions): the newest
// list made for what the set's own call field reads, posted since that field
// was last emptied. And the developer's stand-in for an extension
// (`DEVSUGGEST`), which offers the log's own matches.

import 'dart:async';

import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/draft_suggestions_service.dart';
import '../../services/halo_services.dart';

class DraftSuggestionsFeed {
  DraftSuggestionsFeed(this._operationUuid, {required this.services}) {
    _service.addListener(_onListsChanged);
    _service.devStandIn.addListener(_onStandInChanged);
    for (final MapEntry(key: radio, value: set) in sets.entries) {
      set.addListener(() => _onSetChanged(radio));
      // A set's field starts empty: lists kept for the operation from an
      // earlier visit describe its log as it was then.
      _emptiedAt[radio] = _service.posted;
    }
    _onListsChanged();
  }

  final HaLoServices services;

  /// Each set's, by its radio — `A` alone outside SO2R.
  final sets = {'A': DraftSuggestions(), 'B': DraftSuggestions()};

  String _operationUuid;

  DraftSuggestionsService get _service => services.extensions.draftSuggestions;

  /// What each set's call field last read, and how many lists had been
  /// posted when it was last emptied — a log or a wipe — which no list from
  /// before may outlive: its verdicts describe the log as it was.
  final _calls = <String, String>{};
  final _emptiedAt = <String, int>{};

  /// The extension whose list each set shows.
  final _shownFrom = <String, String>{};

  bool _disposed = false;

  set operationUuid(String uuid) {
    if (uuid == _operationUuid) return;
    _operationUuid = uuid;
    _onListsChanged();
  }

  void _onListsChanged() {
    for (final radio in sets.keys) {
      _choose(radio);
    }
  }

  void _onSetChanged(String radio) {
    final call = sets[radio]!.call;
    if (call == _calls[radio]) return;
    _calls[radio] = call;
    if (call.isEmpty) _emptiedAt[radio] = _service.posted;
    _choose(radio);
    if (_service.devStandIn.value) _standInTyped(radio);
  }

  /// [radio]'s list: while a suggestion it showed stays picked, the list
  /// being walked — the extension hearing the picked call posts a list for
  /// it, in place of the one walked, which would take the walk's other calls
  /// away — for as long as that extension has a list up; otherwise the
  /// newest made for what its call field reads, or, with none, the one
  /// shown when it was made for that text: the walk back past the last
  /// suggestion lands on it after its extension replaced it with a list for
  /// a pick.
  void _choose(String radio) {
    final set = sets[radio]!;
    final from = _shownFrom[radio];
    final shown = set.list;
    final shownOffered = shown != null && from != null && _service.offers(_operationUuid, from);
    if (set.picked != null && shownOffered) return;
    final chosen = _service.listFor(_operationUuid, call: set.call, after: _emptiedAt[radio] ?? 0);
    if (chosen == null && shownOffered && shown.forCall == set.call) return;
    if (chosen == null) {
      _shownFrom.remove(radio);
    } else {
      _shownFrom[radio] = chosen.extension;
    }
    set.list = chosen?.list;
  }

  // --- The stand-in (`DEVSUGGEST`) ---

  /// A pause in typing, as an assistant waits for one.
  static const _pause = Duration(milliseconds: 300);

  Timer? _standInTimer;

  void _onStandInChanged() {
    if (_service.devStandIn.value) return;
    _standInTimer?.cancel();
    _service.clear(DraftSuggestionsService.devStandInKey, _operationUuid);
  }

  void _standInTyped(String radio) {
    _standInTimer?.cancel();
    _standInTimer = Timer(_pause, () => unawaited(_offerFromLog(radio)));
  }

  /// The log's matches for what [radio]'s set reads, scored. Not for a call
  /// picked from a list: that is the walk, not typing.
  Future<void> _offerFromLog(String radio) async {
    final set = sets[radio]!;
    final call = set.call;
    final operationUuid = _operationUuid;
    if (call.length < 2 || set.picked != null) return;
    final CallMatch match;
    try {
      match = CallMatch(call, limit: 10);
    } on FormatException {
      return; // A command being typed, or text no call is that long.
    }
    final found = await services.qsos.findCalls(match);
    if (_disposed || set.call != call) return;
    if (found.isEmpty) {
      _service.clear(DraftSuggestionsService.devStandInKey, operationUuid);
      return;
    }
    final vfo = services.radio.vfoA;
    final candidates = {
      for (final f in found)
        f.call: {
          'their': {'call': f.call},
          'band': ?vfo.band,
          'mode': ?vfo.mode,
        },
    };
    final front = services.frontOperationContext;
    final verdicts = front?.uuid == operationUuid ? await front?.scoreCandidates?.call(candidates) : null;
    if (_disposed || set.call != call) return;
    List<String> strings(Object? list) => list is List ? list.whereType<String>().toList() : const [];
    _service.post(
      DraftSuggestionsService.devStandInKey,
      operationUuid,
      DraftSuggestionList(
        forCall: call,
        drafts: [
          for (final f in found)
            DraftSuggestion(
              call: f.call,
              qso: {
                'their': {'call': f.call},
              },
              notices: strings(verdicts?[f.call]?['notices']).toSet(),
              alerts: strings(verdicts?[f.call]?['alerts']).toSet(),
            ),
        ],
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _standInTimer?.cancel();
    _service.removeListener(_onListsChanged);
    _service.devStandIn.removeListener(_onStandInChanged);
    for (final set in sets.values) {
      set.dispose();
    }
  }
}
