// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How an extension's messages reach the operator: the footer items and
// notices it posts, the declarative actions on them, and what becomes of all
// of that when the runtime it came from goes away.
//
// Extension-supplied text is DATA. Everything here renders it — nothing
// evaluates it — and an action is one of three shapes the app knows, never a
// callback back into the extension.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/navigation.dart';
import '../link_opener.dart';
import '../status_bar_service.dart';

/// Opens an account's standalone dialog (Settings → Accounts), behind a
/// declarative `account` action. Supplied by the app shell.
typedef OpenAccount = void Function(String accountKey, {String? subkey});

/// Clears what the extensions in [dying] left in the footer, as their runtime
/// generation goes down.
///
/// A hook that is about to stop existing cannot finish what it started: an
/// item it posted at 40% has nobody left to advance or clear it, and the
/// operator reads work still running that is not.
///
/// [returning] is the set the next generation loads. A key in it keeps its
/// NOTICES — most restarts here are one extension toggled in the panel, and
/// an "account expired, reconnect" card is the operator's to answer, not a
/// casualty of an unrelated toggle. A key that is not coming back — disabled,
/// or a retired built-in whose catalog twin runs instead, as `ham2k-wca` does
/// for `wca`, so nothing will ever post to the old namespace again — loses its
/// notices too, the way an uninstall does. Dismissed, not deleted: Recent
/// Notices keeps them either way.
///
/// Only what an extension posted through its own namespace. A data file's
/// progress is the app's (`dataFile:…`) and outlives any one generation.
void clearGenerationStatus({required StatusBarService? statusBar, required Iterable<String> dying, required Set<String> returning}) {
  if (statusBar == null) return;
  for (final key in dying) {
    statusBar.clearNamespace(key, notices: !returning.contains(key));
  }
}

/// Notice actions from extensions are declarative JSON, not callbacks back
/// into the extension (matches the `activity` hook's "describe UI as data"
/// convention) — `link` opens a URL, `dialog` shows a markdown dialog.
List<StatusBarAction> noticeActionsFromJson(dynamic raw, {required OpenAccount? onOpenAccount}) {
  if (raw is! List) return const [];
  final actions = <StatusBarAction>[];
  for (final entry in raw) {
    if (entry is! Map) continue;
    final map = entry.cast<String, dynamic>();
    final label = map['label'] as String?;
    final handler = declarativeActionHandler(map, onOpenAccount: onOpenAccount);
    if (label == null || handler == null) continue;
    actions.add(StatusBarAction(label: label, onTap: handler));
  }
  return actions;
}

/// The tap handler for one declarative action (the SDK's NoticeAction):
/// `link` opens a URL, `dialog` shows a markdown dialog, `account` opens that
/// account's standalone dialog via [onOpenAccount]. Returns null for
/// malformed or unknown actions, which the caller drops.
VoidCallback? declarativeActionHandler(Map<String, dynamic> map, {required OpenAccount? onOpenAccount}) {
  switch (map['type'] as String?) {
    case 'link':
      final url = map['url'] as String?;
      if (url == null) return null;
      return () => openExternalUrl(url);
    case 'dialog':
      final text = map['text'] as String? ?? '';
      final title = map['title'] as String?;
      return () => showExtensionMarkdownDialog(title: title, text: text, onOpenAccount: onOpenAccount);
    case 'account':
      final key = map['key'] as String?;
      if (key == null) return null;
      return () => onOpenAccount?.call(key, subkey: map['subkey'] as String?);
  }
  return null;
}

void showExtensionMarkdownDialog({String? title, required String text, List<Map<String, dynamic>> actions = const [], required OpenAccount? onOpenAccount}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      wide: true,
      title: title != null ? Text(title) : null,
      content: HaloMarkdown(data: text),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
      actions: [
        for (final action in actions)
          if (action['label'] is String && declarativeActionHandler(action, onOpenAccount: onOpenAccount) != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                declarativeActionHandler(action, onOpenAccount: onOpenAccount)!();
              },
              child: Text(action['label'] as String),
            ),
      ],
    ),
  );
}

/// Presents a ResultMessage (the SDK type of the same name): `status` is a
/// transient status-bar message, `dialog` a modal markdown dialog whose
/// buttons are declarative NoticeActions. Reached from a hook result's
/// `userMessage` or the imperative `showMessage` host call (hooks whose
/// results can't carry one, e.g. lookups).
void presentExtensionResultMessage(
  Map<String, dynamic> message, {
  required StatusBarService? statusBar,
  required OpenAccount? onOpenAccount,
  String ns = 'extensions',
}) {
  final title = message['title'] as String?;
  final text = message['text'] as String? ?? '';
  if (message['presentation'] == 'dialog') {
    final actions = ((message['actions'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().map((a) => a.cast<String, dynamic>()).toList();
    showExtensionMarkdownDialog(title: title, text: text, actions: actions, onOpenAccount: onOpenAccount);
  } else {
    statusBar?.setMessage(key: '$ns:resultMessage', icon: message['icon'] as String?, title: title, text: text);
  }
}
