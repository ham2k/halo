// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The FYI area's messages (docs/design/logging-fields.md § The FYI area):
// what the app's components post for the operator to glance at between the
// info area and the entry row, keyed so a poster rewrites or clears its
// own, and each belonging to one radio's set or to both.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color, IconData, VoidCallback;
import 'package:halo_core/halo_core.dart' show nowMillis;

/// Where on the line a message goes (logging-fields.md § The FYI area),
/// most severe first: the room goes to the categories in this order, but
/// for what is under way, which comes before all but a high alert.
enum FyiCategory {
  alert,
  warning,

  /// Something under way — the keyer's message going out, first of them.
  operational,
  info,
}

/// How a message ranks against the others of its category, first to last.
/// A high alert is the one drawn as a filled pill.
enum FyiPriority { high, normal, low }

/// One message in the area: an icon, a line of inline markdown, and what
/// the tap that puts it away does.
class FyiMessage {
  /// The poster's handle on the message: a later post under the same key
  /// replaces it, and `clear` takes it down.
  final String key;
  final FyiCategory category;
  final FyiPriority priority;
  final IconData icon;

  /// Null draws the icon in the category's own colour.
  final Color? iconColor;

  /// One line of inline markdown ([InlineMarkdownText]'s syntax).
  final String text;
  final Color? textColor;

  /// `A` or `B` for a message about one radio, shown in that set's area
  /// alone; null for one about the station, shown in both.
  final String? radio;

  /// Run by the tap that puts the message away — on one shown in full, or
  /// the second on one tapped open — before the dismissal; on a message
  /// that is not [dismissible], by that tap alone.
  final VoidCallback? onTap;

  /// Whether a tap takes the message down. False for a condition only its
  /// poster can answer — No Band, No Mode — which a tap leaves standing.
  final bool dismissible;

  /// Taken down on its own this long after the post. Null stays until the
  /// poster clears it or the operator dismisses it.
  final Duration? expiresIn;

  const FyiMessage({
    required this.key,
    required this.category,
    this.priority = FyiPriority.normal,
    required this.icon,
    this.iconColor,
    required this.text,
    this.textColor,
    this.radio,
    this.onTap,
    this.dismissible = true,
    this.expiresIn,
  });

  /// Whether [other] would draw the same: what decides whether a re-post
  /// under the same key is news to the area. The tap action is not drawn,
  /// so the area runs the one under the key at the tap, never the one it
  /// was built with.
  bool looksLike(FyiMessage other) =>
      category == other.category &&
      priority == other.priority &&
      icon == other.icon &&
      iconColor == other.iconColor &&
      text == other.text &&
      textColor == other.textColor &&
      radio == other.radio &&
      dismissible == other.dismissible;
}

class FyiService extends ChangeNotifier {
  /// In the order first posted; a re-post keeps its place. Read through
  /// [_ordered], which ranks them by priority first.
  final Map<String, FyiMessage> _messages = {};
  final Map<String, Timer> _expiry = {};

  /// What the operator dismissed and when, by key: a re-post inside
  /// [dismissCooldown] is dropped unless it is more severe than what was
  /// dismissed — a higher category, or a higher priority in the same one — so
  /// a persisting condition does not nag and an escalating one does. The app
  /// clock, so a developer travelling past the cooldown ends it as it ends
  /// everything else.
  final Map<String, ({FyiCategory category, FyiPriority priority, int atMillis})> _dismissed = {};

  static const dismissCooldown = Duration(minutes: 3);

  /// By priority, then the order first posted — what decides the order
  /// within a category on the line.
  Iterable<FyiMessage> get _ordered => [
    for (final priority in FyiPriority.values)
      for (final message in _messages.values)
        if (message.priority == priority) message,
  ];

  List<FyiMessage> get messages => List.unmodifiable(_ordered);

  /// The messages [radio]'s set shows: its own and the station's.
  List<FyiMessage> messagesFor(String radio) => [
    for (final message in _ordered)
      if (message.radio == null || message.radio == radio) message,
  ];

  FyiMessage? messageFor(String key) => _messages[key];

  /// Posts [message], replacing the one under its key. False when a
  /// dismissal still holds it back (see [_dismissed]).
  bool post(FyiMessage message) {
    final dismissed = _dismissed[message.key];
    if (dismissed != null) {
      final escalated =
          message.category.index < dismissed.category.index || (message.category == dismissed.category && message.priority.index < dismissed.priority.index);
      if (nowMillis() - dismissed.atMillis < dismissCooldown.inMilliseconds && !escalated) return false;
      _dismissed.remove(message.key);
    }
    final current = _messages[message.key];
    _messages[message.key] = message;
    _expiry.remove(message.key)?.cancel();
    if (message.expiresIn case final expiresIn?) {
      _expiry[message.key] = Timer(expiresIn, () => clear(message.key));
    }
    // A message restated as it was — a meter re-reading the same number —
    // is not news to the area.
    if (current == null || !current.looksLike(message)) notifyListeners();
    return true;
  }

  /// The poster taking its message down. Not a dismissal — the same key
  /// posted again shows at once — nor the end of one: a dismissal's
  /// cooldown outlasts the poster taking the message down in between, or a
  /// condition flapping about its threshold would nag through it.
  void clear(String key) {
    _expiry.remove(key)?.cancel();
    if (_messages.remove(key) != null) notifyListeners();
  }

  /// The key an extension's message goes under, `ext:<extension>:<key>`.
  /// The app's own posters key theirs `<word>:…` — `band:A`, `mode:A`, the
  /// SWR watch's — never under this prefix, so no extension, whatever its
  /// name, reaches a message of the app's: without it, one keyed `band`
  /// would own the No Band pill.
  static String extensionKey(String extension, String key) => '${extensionPrefix(extension)}$key';
  static String extensionPrefix(String extension) => 'ext:$extension:';

  /// Every message of [extension]'s taken down as [clear] takes one, as its
  /// runtime goes (extension_messages.dart).
  void clearExtension(String extension) {
    final prefix = extensionPrefix(extension);
    final keys = [
      for (final key in _messages.keys)
        if (key.startsWith(prefix)) key,
    ];
    for (final key in keys) {
      _expiry.remove(key)?.cancel();
      _messages.remove(key);
    }
    if (keys.isNotEmpty) notifyListeners();
  }

  /// The operator putting a message away — see [_dismissed].
  void dismiss(String key) {
    final message = _messages[key];
    if (message == null) return;
    _dismissed[key] = (category: message.category, priority: message.priority, atMillis: nowMillis());
    clear(key);
  }

  @override
  void dispose() {
    for (final timer in _expiry.values) {
      timer.cancel();
    }
    _expiry.clear();
    super.dispose();
  }
}
