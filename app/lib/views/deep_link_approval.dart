// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// "Link from <app>": the question a `/vfo`, `/qso` or `/operation` link asks
// before it acts. Any web page or installed app can open a `com.ham2k://`
// link, and these three retune the radio, fill in a contact or create an
// operation, so each asks unless the operator already answered for its
// sender once and for all, either way.
//
// The sender is what the OS says (DeepLinkService.senderOf), and most
// platforms name nobody. Links with no named sender share one entry, the
// empty id, which stands for every other app and every web page at once: it
// can be denied for good, never allowed, or one answer would open the gate
// to all of them.

import 'dart:async';
import 'dart:collection' show Queue;

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/navigation.dart';
import '../services/deep_link_service.dart';
import '../services/error_reporting_service.dart';
import '../services/halo_services.dart';

/// The id [SettingsService.linkSenderDecisions] keeps links with no named
/// sender under.
const unnamedLinkSender = '';

typedef _Request = ({HaLoServices services, Uri uri, Future<LinkSender?> sender, String question, Completer<bool> answer});

/// The links waiting to ask, in arrival order: a companion app that sends a
/// second link while the first is still asking gets its question after the
/// first's, not stacked on top of it.
final _waiting = Queue<_Request>();

/// Whether [_askInTurn] is working through [_waiting]. A flag rather than a
/// chain of futures: a future that has completed runs what is chained on it
/// later in the zone it completed in, which need not be the zone asking now.
bool _asking = false;

/// Whether the operator lets the link [uri] do what [question] says — at
/// once, when they already answered for its sender for good.
///
/// Waits for a navigator to ask on: a link that cold-launches the app
/// arrives before the first frame. One still absent after five seconds is
/// refused and reported, since a link applied unasked is what this exists to
/// prevent.
Future<bool> approveDeepLink(HaLoServices services, Uri uri, String question) {
  final answer = Completer<bool>();
  // Asked now, as the link arrives, not when its turn comes: by then the
  // same link sent again by someone else, or a run of later ones, has
  // replaced what the OS said about this one.
  final sender = services.deepLinks.senderOf(uri);
  // Awaited in its turn, which is when a failure is reported.
  sender.ignore();
  _waiting.add((services: services, uri: uri, sender: sender, question: question, answer: answer));
  if (!_asking) unawaited(_askInTurn());
  return answer.future;
}

Future<void> _askInTurn() async {
  _asking = true;
  try {
    while (_waiting.isNotEmpty) {
      final next = _waiting.removeFirst();
      try {
        next.answer.complete(await _approve(next.services, next.uri, await next.sender, next.question));
      } catch (e, stack) {
        ErrorReportingService.report(e, stack, context: 'deep-link:approve');
        next.answer.complete(false);
      }
    }
  } finally {
    _asking = false;
  }
}

Future<bool> _approve(HaLoServices services, Uri uri, LinkSender? sender, String question) async {
  final id = sender?.id ?? unnamedLinkSender;
  if (services.settings.linkSenderDecisions[id] case final decided? when id != unnamedLinkSender || !decided.allow) {
    if (!decided.allow) debugPrint('[deep-link] $uri refused: its sender is denied in Settings › Integrations');
    return decided.allow;
  }
  BuildContext? context;
  for (var attempt = 0; attempt < 20; attempt++) {
    context = navigatorKey.currentContext;
    if (context != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  if (context == null || !context.mounted) {
    ErrorReportingService.report(StateError('deep link refused: no navigator to ask on after 5s'), StackTrace.current, context: 'deep-link');
    return false;
  }
  final answer = await showHaloDialog<({bool allow, bool remember})>(
    context: context,
    builder: (_) => _DeepLinkApprovalDialog(sender: sender, question: question),
  );
  // Dismissed is not answered: refused this once, and asked again next time.
  if (answer == null) return false;
  if (answer.remember) {
    // The answer stands for this link even when it cannot be kept for the
    // next: the operator gave it.
    try {
      await services.settings.decideLinkSender(id, label: sender?.label ?? '', allow: answer.allow);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'deep-link:remember');
    }
  }
  return answer.allow;
}

class _DeepLinkApprovalDialog extends StatefulWidget {
  final LinkSender? sender;
  final String question;

  const _DeepLinkApprovalDialog({required this.sender, required this.question});

  @override
  State<_DeepLinkApprovalDialog> createState() => _DeepLinkApprovalDialogState();
}

class _DeepLinkApprovalDialogState extends State<_DeepLinkApprovalDialog> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t.deepLink;
    final sender = widget.sender;
    return HaloDialog(
      title: Text(sender == null ? t.askTitleUnknown : t.askTitle(sender: sender.label)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.question),
          const SizedBox(height: Space.md),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _remember,
            onChanged: (v) => setState(() => _remember = v ?? false),
            title: Text(sender == null ? t.askRememberUnknown : t.askRemember(sender: sender.label)),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop((allow: false, remember: _remember)), child: Text(t.deny)),
      actions: [
        FilledButton(
          // Nobody named stands for every app and page: remembered, it can
          // only be refused.
          onPressed: sender == null && _remember ? null : () => Navigator.of(context).pop((allow: true, remember: _remember)),
          child: Text(t.allow),
        ),
      ],
    );
  }
}
