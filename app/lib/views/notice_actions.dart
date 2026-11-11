// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Interprets a server-notice action button tap (FlagsService pushes notices
// with these descriptors; see notices.dart / flags_service.dart). This is the
// UI-side counterpart to app-polo's `performAction` in Notices.jsx, pared to
// the action types HaLo can honor without app-specific screen knowledge:
//
//   link   — open a URL (`args.url` / `args.link` / `args.href`)
//   dialog — show a modal with `dialogTitle` / `dialogText` (markdown) and
//            nested `dialogActions`
//   donate — present the supporter paywall, where the build can take
//            purchases ([donate])
//   (any)  — if the args carry a URL, open it
//
// app-polo's `subscribe` / `navigate` actions target flows HaLo doesn't have
// yet (different navigation), so those buttons still render and dismiss the
// notice but otherwise no-op — logged, not silently swallowed. So does
// `donate` in a build with no purchases. Wire real handling here as those
// flows land.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../config/navigation.dart';
import '../services/link_opener.dart';

void handleNoticeAction(String noticeKey, Map<String, dynamic> action, {void Function()? donate}) {
  final type = action['action'] as String?;
  final args = action['args'];

  if (type == 'donate' && donate != null) {
    donate();
    return;
  }

  final url = _urlFrom(args);
  if (type == 'link' || (url != null && type != 'dialog')) {
    if (url != null) {
      openExternalUrl(url);
      return;
    }
  }

  if (type == 'dialog' && args is Map) {
    _showNoticeDialog(args.cast<String, dynamic>(), donate: donate);
    return;
  }

  debugPrint('[flags] unhandled notice action "$type" for notice "$noticeKey"');
}

String? _urlFrom(dynamic args) {
  if (args is Map) {
    for (final key in const ['url', 'link', 'href']) {
      final value = args[key];
      if (value is String && value.isNotEmpty) return value;
    }
  } else if (args is String && (args.startsWith('http://') || args.startsWith('https://'))) {
    return args;
  }
  return null;
}

void _showNoticeDialog(Map<String, dynamic> args, {void Function()? donate}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  final title = args['dialogTitle'] as String?;
  final text = (args['dialogText'] as String?) ?? '';
  final dialogActions = ((args['dialogActions'] as List?) ?? const []).whereType<Map<dynamic, dynamic>>().map((a) => a.cast<String, dynamic>()).toList();

  showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      wide: true,
      title: title != null ? Text(title) : null,
      content: HaloMarkdown(data: text),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
      actions: [
        for (final action in dialogActions)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              handleNoticeAction('dialog', action, donate: donate);
            },
            child: Text((action['label'] as String?) ?? 'OK'),
          ),
      ],
    ),
  );
}
