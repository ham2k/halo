// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// "Allow this agent app?" (docs/design/agent-link.md § Grants). The name is
// the app's own word, so the dialog says what allowing it lets the app do,
// never that the app is who it says.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/agent_link/agent_link_model.dart';

/// The operator's answer: an access, or null for a refusal. It stays up
/// until answered, whether or not the app is still [waiting], and closes on
/// its own, answering null, only when [withdrawn] completes: the link
/// stopped.
Future<AgentAccess?> showAgentLinkDialog(
  BuildContext context, {
  required AgentClient client,
  required ValueListenable<bool> waiting,
  required Future<void> withdrawn,
}) {
  return showHaloDialog<AgentAccess>(
    context: context,
    // A stray tap outside must not answer it.
    barrierDismissible: false,
    builder: (dialogContext) {
      unawaited(
        withdrawn.then((_) {
          if (dialogContext.mounted && ModalRoute.of(dialogContext)?.isCurrent == true) Navigator.of(dialogContext).pop();
        }),
      );
      return _AgentLinkDialog(client: client, waiting: waiting);
    },
  );
}

class _AgentLinkDialog extends StatefulWidget {
  final AgentClient client;
  final ValueListenable<bool> waiting;

  const _AgentLinkDialog({required this.client, required this.waiting});

  @override
  State<_AgentLinkDialog> createState() => _AgentLinkDialogState();
}

class _AgentLinkDialogState extends State<_AgentLinkDialog> {
  // Watching is what every allowed app does; changes are the operator's
  // deliberate extra, so they start off.
  bool _watch = true;
  bool _change = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t.settings.agentLink;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final client = widget.client;
    final launcher = client.launcher;
    Widget option({required bool value, required String title, required String detail, required ValueChanged<bool> onChanged}) => CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: (v) => setState(() => onChanged(v ?? false)),
      title: Text(title),
      subtitle: Text(detail),
    );
    return HaloDialog(
      title: Text(t.title(name: client.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(launcher == null ? t.body(name: client.name) : t.bodyLauncher(name: client.name, launcher: launcher)),
          const SizedBox(height: Space.md),
          // Changes without watching would be an app acting blind: checking
          // one checks the other, and unchecking watch takes changes with it.
          option(
            value: _watch,
            title: t.watch,
            detail: t.watchDetail,
            onChanged: (v) {
              _watch = v;
              if (!v) _change = false;
            },
          ),
          option(
            value: _change,
            title: t.change,
            detail: t.changeDetail,
            onChanged: (v) {
              _change = v;
              if (v) _watch = true;
            },
          ),
          ValueListenableBuilder(
            valueListenable: widget.waiting,
            builder: (context, waiting, _) => waiting
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Text(t.stoppedWaiting(name: client.name)),
                  ),
          ),
          const SizedBox(height: Space.lg),
          Text(t.warning, style: muted),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.deny)),
      actions: [
        FilledButton(onPressed: _watch ? () => Navigator.of(context).pop(_change ? AgentAccess.change : AgentAccess.watch) : null, child: Text(t.allow)),
      ],
    );
  }
}
