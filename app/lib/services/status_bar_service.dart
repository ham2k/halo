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
const _progressCompleteDismissDelay = Duration(seconds: 5);

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

  const StatusBarAction({required this.label, required this.onTap});
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

  void setMessage({required String key, String? icon, String? title, String? text}) {
    final now = nowLocal();
    _items[key] = StatusBarItem(
      key: key,
      icon: icon,
      title: title,
      text: text,
      createdAt: _items[key]?.createdAt ?? now,
      updatedAt: now,
    );
    _capItems();
    notifyListeners();
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
    _items[key] = StatusBarItem(
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
    _capItems();
    notifyListeners();

    if (value != null && value >= 1.0) {
      Future.delayed(_progressCompleteDismissDelay, () {
        final current = _items[key];
        if (current != null && (current.progressValue ?? 0) >= 1.0) clear(key);
      });
    }
  }

  void clear(String key) {
    if (_items.remove(key) != null) notifyListeners();
  }

  void showNotice({
    required String key,
    String? icon,
    String? title,
    required String text,
    List<StatusBarAction> actions = const [],
    bool persist = true,
  }) {
    final notice = StatusBarNotice(
      key: key,
      icon: icon,
      title: title,
      text: text,
      actions: actions,
      createdAt: nowLocal(),
      persist: persist,
    );
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
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(StatusBarNotice._fromJson)
          .toList();
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
