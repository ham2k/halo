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
import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'statusBarNoticeHistory';
const _maxHistory = 50;
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
  final DateTime updatedAt;

  const StatusBarItem({
    required this.key,
    this.icon,
    this.title,
    this.text,
    this.progressValue,
    this.isIndeterminateProgress = false,
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

  const StatusBarNotice({
    required this.key,
    this.icon,
    this.title,
    required this.text,
    this.actions = const [],
    required this.createdAt,
    this.dismissedAt,
  });

  StatusBarNotice copyWith({DateTime? dismissedAt}) => StatusBarNotice(
        key: key,
        icon: icon,
        title: title,
        text: text,
        actions: actions,
        createdAt: createdAt,
        dismissedAt: dismissedAt ?? this.dismissedAt,
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

  /// Notices in creation order (stack order); actions aren't persisted since
  /// a `VoidCallback` can't survive a restart — history entries are
  /// read-only past that point.
  final List<StatusBarNotice> _notices = [];

  StatusBarService(this._prefs) {
    _notices.addAll(_loadHistory().where((n) => n.dismissedAt == null));
  }

  List<StatusBarItem> get items => _items.values.toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  List<StatusBarNotice> get activeNotices => _notices.where((n) => n.dismissedAt == null).toList();

  /// Most-recent-first, including dismissed notices.
  List<StatusBarNotice> get history => _loadHistory().reversed.toList();

  void setMessage({required String key, String? icon, String? title, String? text}) {
    _items[key] = StatusBarItem(key: key, icon: icon, title: title, text: text, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// `value` null means indeterminate; otherwise 0.0-1.0. A completed
  /// (`value >= 1.0`) progress item auto-clears itself 5 seconds later,
  /// unless it's been replaced or cleared by then.
  void setProgress({required String key, String? icon, String? title, String? text, double? value}) {
    _items[key] = StatusBarItem(
      key: key,
      icon: icon,
      title: title,
      text: text,
      progressValue: value,
      isIndeterminateProgress: value == null,
      updatedAt: DateTime.now(),
    );
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
  }) {
    final notice = StatusBarNotice(
      key: key,
      icon: icon,
      title: title,
      text: text,
      actions: actions,
      createdAt: DateTime.now(),
    );
    _notices.removeWhere((n) => n.key == key);
    _notices.add(notice);
    unawaited(_appendToHistory(notice));
    notifyListeners();
  }

  void dismissNotice(String key) {
    final index = _notices.indexWhere((n) => n.key == key && n.dismissedAt == null);
    if (index == -1) return;
    final dismissed = _notices[index].copyWith(dismissedAt: DateTime.now());
    _notices[index] = dismissed;
    unawaited(_markDismissedInHistory(dismissed));
    notifyListeners();
  }

  // Growable lists throughout — `_appendToHistory`/`_markDismissedInHistory`
  // mutate whatever this returns, and a `const []` (or any fixed-length
  // list) would throw on the first `.add()`.
  List<StatusBarNotice> _loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(StatusBarNotice._fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveHistory(List<StatusBarNotice> notices) async {
    final capped = notices.length > _maxHistory ? notices.sublist(notices.length - _maxHistory) : notices;
    await _prefs.setString(_historyKey, jsonEncode(capped.map((n) => n._toJson()).toList()));
  }

  Future<void> _appendToHistory(StatusBarNotice notice) async {
    final history = _loadHistory();
    history.removeWhere((n) => n.key == notice.key && n.dismissedAt == null);
    history.add(notice);
    await _saveHistory(history);
  }

  Future<void> _markDismissedInHistory(StatusBarNotice dismissed) async {
    final history = _loadHistory();
    final index = history.indexWhere((n) => n.key == dismissed.key && n.createdAt == dismissed.createdAt);
    if (index == -1) return;
    history[index] = dismissed;
    await _saveHistory(history);
  }
}
