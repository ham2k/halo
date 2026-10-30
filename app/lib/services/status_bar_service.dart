// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The footer's data model: transient messages/progress bars (in-memory
// only) and dismissible notices (persisted history, capped so a long
// session doesn't grow this file forever — same bounding convention as
// ExtensionHost's `samples` list).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:halo_core/halo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'statusBarNoticeHistory';
const _maxHistory = 50;
const _maxItems = 50;

/// A single-line message or progress bar shown in the footer. Transient —
/// never persisted, cleared by the caller via [StatusBarService.clear] or
/// replaced by a later call with the same [key].
class StatusBarItem {
  final String key;
  final String? icon;
  final String? title;
  final String? text;

  /// Null when this isn't a progress item. 0.0-1.0 when determinate.
  final double? progressValue;
  final bool isIndeterminateProgress;

  /// When this key was FIRST posted — kept across updates, so a message that
  /// keeps refreshing (a download's percentage, a sync's phase) holds its
  /// place in the footer instead of jumping to the end on each tick.
  final DateTime createdAt;

  /// When it was last written. Only [_capItems] reads this: eviction wants
  /// the least recently ACTIVE item, which isn't the same as the oldest.
  final DateTime updatedAt;

  const StatusBarItem({
    required this.key,
    this.icon,
    this.title,
    this.text,
    this.progressValue,
    this.isIndeterminateProgress = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProgress => isIndeterminateProgress || progressValue != null;
}

/// An action button on a notice. Extension-supplied actions get an `onTap`
/// synthesized by the extension bridge (see `ExtensionService`); core Dart
/// callers can pass any closure directly.
class StatusBarAction {
  final String label;
  final VoidCallback onTap;

  /// The notice's own job, drawn as its button on the trailing edge — see
  /// `StatusBarActionData.primary`.
  final bool primary;

  const StatusBarAction({required this.label, required this.onTap, this.primary = false});
}

/// A richer, dismissible notice — markdown body, optional action buttons.
/// Kept in [StatusBarService.history] (persisted) even after dismissal;
/// [dismissedAt] is null while it's still in the active stack.
class StatusBarNotice {
  final String key;
  final String? icon;
  final String? title;
  final String text;
  final List<StatusBarAction> actions;
  final DateTime createdAt;
  final DateTime? dismissedAt;

  /// Whether this notice survives to disk at all. False for notices whose
  /// actions matter enough that showing a stale, action-less copy of them
  /// after a restart would be worse than not showing them again — e.g. an
  /// error notice's actions can't survive a restart anyway (see the
  /// `_notices` field doc below), so an un-dismissed one would otherwise
  /// come back forever as a dead husk of its former self.
  final bool persist;

  const StatusBarNotice({
    required this.key,
    this.icon,
    this.title,
    required this.text,
    this.actions = const [],
    required this.createdAt,
    this.dismissedAt,
    this.persist = true,
  });

  StatusBarNotice copyWith({DateTime? dismissedAt}) => StatusBarNotice(
    key: key,
    icon: icon,
    title: title,
    text: text,
    actions: actions,
    createdAt: createdAt,
    dismissedAt: dismissedAt ?? this.dismissedAt,
    persist: persist,
  );

  Map<String, dynamic> _toJson() => {
    'key': key,
    'icon': icon,
    'title': title,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'dismissedAt': dismissedAt?.toIso8601String(),
  };

  static StatusBarNotice _fromJson(Map<String, dynamic> json) => StatusBarNotice(
    key: json['key'] as String,
    icon: json['icon'] as String?,
    title: json['title'] as String?,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    dismissedAt: json['dismissedAt'] != null ? DateTime.parse(json['dismissedAt'] as String) : null,
  );
}

class StatusBarService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Map<String, StatusBarItem> _items = {};

  /// Notices in creation order (stack order), active and dismissed alike —
  /// the single source of truth for both `activeNotices` and `history`, kept
  /// in sync with the persisted copy by `_persistNotices`. Actions aren't
  /// persisted since a `VoidCallback` can't survive a restart — history
  /// entries are read-only past that point. A notice whose actions matter
  /// enough that a dead, action-less copy of it would be worse than nothing
  /// (see [StatusBarNotice.persist]) skips that round-trip entirely instead.
  final List<StatusBarNotice> _notices = [];

  StatusBarService(this._prefs) {
    _notices.addAll(_loadHistory());
  }

  /// In the order the keys were first posted. Dart maps iterate in insertion
  /// order, and assigning an EXISTING key leaves its position alone, so an
  /// update never reshuffles the footer — deliberately not sorted by
  /// [StatusBarItem.updatedAt], which would make a refreshing
  /// progress bar leapfrog the messages around it.
  List<StatusBarItem> get items => _items.values.toList();

  /// The active progress/message item under [key], or null — a direct map
  /// lookup, so callers watching one keyed item (a data file's download, a
  /// sync round) don't scan and sort the whole [items] list to find it.
  StatusBarItem? itemForKey(String key) => _items[key];

  List<StatusBarNotice> get activeNotices => _notices.where((n) => n.dismissedAt == null).toList();

  /// Most-recent-first, including dismissed notices.
  List<StatusBarNotice> get history => _notices.reversed.toList();

  /// How long a completion message lingers before dismissing itself — shared
  /// by every self-clearing item so "done" reads the same everywhere.
  static const completedDismissDelay = Duration(seconds: 5);

  /// With [dismissAfter], the message clears itself once that much time has
  /// passed — for completion messages ("Imported N contacts") that would
  /// otherwise sit in the footer until something happened to replace them.
  /// Without it the message stays until cleared or replaced.
  void setMessage({required String key, String? icon, String? title, String? text, Duration? dismissAfter}) {
    final now = nowLocal();
    final item = StatusBarItem(key: key, icon: icon, title: title, text: text, createdAt: _items[key]?.createdAt ?? now, updatedAt: now);
    _items[key] = item;
    _capItems();
    notifyListeners();
    if (dismissAfter != null) _dismissLater(item, dismissAfter);
  }

  /// Bounds `_items` the same way `_notices`/history are bounded, evicting
  /// the oldest entry — otherwise a caller that mints a fresh key per call
  /// (e.g. dev-commands' DEVSTATUS, by design, so repeated calls stack up as
  /// separate items) grows this map for the rest of the process's lifetime.
  void _capItems() {
    if (_items.length <= _maxItems) return;
    final oldestKey = _items.entries.reduce((a, b) => a.value.updatedAt.isBefore(b.value.updatedAt) ? a : b).key;
    _items.remove(oldestKey);
  }

  /// `value` null means indeterminate; otherwise 0.0-1.0. A completed
  /// (`value >= 1.0`) progress item auto-clears itself 5 seconds later,
  /// unless it's been replaced or cleared by then.
  void setProgress({required String key, String? icon, String? title, String? text, double? value}) {
    final now = nowLocal();
    final item = StatusBarItem(
      key: key,
      icon: icon,
      title: title,
      text: text,
      progressValue: value,
      isIndeterminateProgress: value == null,
      // A progress bar that switches from indeterminate to determinate, or
      // a message that later becomes a progress bar, is still the same item
      // — it keeps the slot its first post claimed.
      createdAt: _items[key]?.createdAt ?? now,
      updatedAt: now,
    );
    _items[key] = item;
    _capItems();
    notifyListeners();

    if (value != null && value >= 1.0) _dismissLater(item, completedDismissDelay);
  }

  /// Clears [item]'s key after [delay] — unless a later post holds the key by
  /// then. The timer belongs to the POSTING, not the key: matched by identity,
  /// because any looser guard lets a stale timer from an earlier completion
  /// dismiss the next completion on the same key moments after it appears.
  void _dismissLater(StatusBarItem item, Duration delay) {
    Future.delayed(delay, () {
      if (identical(_items[item.key], item)) clear(item.key);
    });
  }

  void clear(String key) {
    if (_items.remove(key) != null) notifyListeners();
  }

  /// Drops every item, and dismisses every active notice, posted under [ns] —
  /// the namespace prefix an extension's own keys carry ('pota:sync').
  ///
  /// For when an extension stops existing in its current form: a dev-loop
  /// reload (docs/extensions/in-repo.md#the-dev-server). Its transient state is the
  /// previous code's, and nothing will ever clear it — a progress bar left at
  /// 40% by a hook that no longer exists sits there for the rest of the
  /// session. Notices are DISMISSED rather than deleted, so the operator's
  /// Recent Notices history keeps them.
  /// [notices] false keeps the namespace's notices on screen: for a restart,
  /// where the extension that posted one is about to be loaded again and
  /// will not post it twice. An "account expired" notice is the operator's to
  /// dismiss, not a side effect of toggling some other extension.
  void clearNamespace(String ns, {bool notices = true}) {
    final prefix = '$ns:';
    final keys = _items.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      _items.remove(key);
    }
    var dismissed = false;
    for (var i = 0; notices && i < _notices.length; i++) {
      final notice = _notices[i];
      if (notice.key.startsWith(prefix) && notice.dismissedAt == null) {
        _notices[i] = notice.copyWith(dismissedAt: nowLocal());
        dismissed = true;
      }
    }
    if (dismissed) unawaited(_persistNotices());
    if (keys.isNotEmpty || dismissed) notifyListeners();
  }

  void showNotice({required String key, String? icon, String? title, required String text, List<StatusBarAction> actions = const [], bool persist = true}) {
    final notice = StatusBarNotice(key: key, icon: icon, title: title, text: text, actions: actions, createdAt: nowLocal(), persist: persist);
    _notices.removeWhere((n) => n.key == key);
    _notices.add(notice);
    if (_notices.length > _maxHistory) _notices.removeRange(0, _notices.length - _maxHistory);
    unawaited(_persistNotices());
    notifyListeners();
  }

  void dismissNotice(String key) {
    final index = _notices.indexWhere((n) => n.key == key && n.dismissedAt == null);
    if (index == -1) return;
    _notices[index] = _notices[index].copyWith(dismissedAt: nowLocal());
    unawaited(_persistNotices());
    notifyListeners();
  }

  // Growable — a `const []` (or any fixed-length list) would throw on the
  // first `.add()` in the constructor/`showNotice`.
  List<StatusBarNotice> _loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(StatusBarNotice._fromJson).toList();
    } catch (e) {
      debugPrint('[statusBar] failed to parse persisted notice history, discarding it: $e');
      return [];
    }
  }

  Future<void> _persistNotices() async {
    final persisted = _notices.where((n) => n.persist);
    await _prefs.setString(_historyKey, jsonEncode(persisted.map((n) => n._toJson()).toList()));
  }
}
