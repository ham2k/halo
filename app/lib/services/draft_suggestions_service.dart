// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The draft suggestions extensions offer (docs/design/logging-fields.md §
// Draft suggestions; `host.draftSuggestions`): each extension's latest list
// for each operation, numbered in the order they were posted. Each set's
// logging panel shows the newest made for what its call field reads, so a
// list left behind by typing on is never shown, and nothing here has to
// expire it.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:halo_widgets/halo_widgets.dart';

class DraftSuggestionsService extends ChangeNotifier {
  /// By operation, then by extension, each list with its place in [posted].
  final _lists = <String, Map<String, ({DraftSuggestionList list, int posted})>>{};

  /// How many lists have been posted: a later post has a larger number.
  int get posted => _posted;
  int _posted = 0;

  /// The developer's stand-in for an extension (`DEVSUGGEST`): the logging
  /// panel offers the log's own matches while it is on.
  final devStandIn = ValueNotifier<bool>(false);

  /// The key the stand-in posts under — no extension's, which are
  /// `ham2k-…` or reverse domains.
  static const devStandInKey = '\u0000dev';

  /// [extension]'s list for [operationUuid], in place of its last.
  void post(String extension, String operationUuid, DraftSuggestionList list) {
    _lists.putIfAbsent(operationUuid, () => {})[extension] = (list: list, posted: ++_posted);
    notifyListeners();
  }

  /// Takes down [extension]'s list for [operationUuid].
  void clear(String extension, String operationUuid) {
    final byExtension = _lists[operationUuid];
    if (byExtension?.remove(extension) == null) return;
    if (byExtension!.isEmpty) _lists.remove(operationUuid);
    notifyListeners();
  }

  /// Every list of [extension]'s, as its runtime goes (extension_messages.dart)
  /// — and with [owns], every one posted under a key it answers for, as its
  /// sub-extensions post.
  void clearExtension(String extension, {bool Function(String key)? owns}) {
    final ours = owns ?? (key) => key == extension;
    var any = false;
    for (final byExtension in _lists.values) {
      final keys = byExtension.keys.where(ours).toList();
      for (final key in keys) {
        byExtension.remove(key);
      }
      any = any || keys.isNotEmpty;
    }
    _lists.removeWhere((_, byExtension) => byExtension.isEmpty);
    if (any) notifyListeners();
  }

  /// The newest list offered for [operationUuid] that was made for [call]
  /// and posted after [after] — a call field emptied since a list came, by a
  /// log or a wipe, leaves that list's verdicts behind with the contact.
  ({String extension, DraftSuggestionList list})? listFor(String operationUuid, {required String call, int after = 0}) => _lists[operationUuid]?.entries
      .where((entry) => entry.value.list.forCall == call && entry.value.posted > after)
      .sorted((a, b) => a.value.posted.compareTo(b.value.posted))
      .map((entry) => (extension: entry.key, list: entry.value.list))
      .lastOrNull;

  /// Whether [extension] has a list up for [operationUuid] — taken down, or
  /// gone with its runtime, it has none.
  bool offers(String operationUuid, String extension) => _lists[operationUuid]?.containsKey(extension) ?? false;

  @override
  void dispose() {
    devStandIn.dispose();
    super.dispose();
  }
}
