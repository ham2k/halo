// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Cluster Console, opened from the DX Cluster section and by the CLUSTER
// command: the session as it happens — what the node sends, what goes out,
// the connection's ups and downs — and a field to type commands into
// (docs/design/cluster.md § Console).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/cluster/cluster_service.dart';
import 'cluster_settings_group.dart';

/// How many characters of a line the console shows before wrapping, where
/// the window has room: a node formats its tables and `DX de` lines for an
/// 80-column terminal, and some run a little past it.
const _lineLength = 100;

TextStyle _transcriptStyle(BuildContext context) => Theme.of(context).textTheme.bodySmall!.copyWith(fontFamily: 'RobotoMono');

Future<void> showClusterConsole(BuildContext context, ClusterService cluster) {
  final line = textWidth(context, 'M' * _lineLength, _transcriptStyle(context));
  return showModalPane<void>(
    context,
    title: context.t.settings.cluster.consoleTitle,
    scrollable: false,
    fillHeight: true,
    closeLabel: context.t.common.close,
    maxWidth: math.max(maxDialogWidth, line + Space.xl * 2),
    builder: (_) => ClusterConsole(cluster: cluster),
  );
}

class ClusterConsole extends StatefulWidget {
  const ClusterConsole({super.key, required this.cluster});

  final ClusterService cluster;

  @override
  State<ClusterConsole> createState() => _ClusterConsoleState();
}

class _ClusterConsoleState extends State<ClusterConsole> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  late final _changes = Listenable.merge([widget.cluster, widget.cluster.transcript]);

  @override
  void dispose() {
    // Connect holds the session only while the console is open.
    widget.cluster.release();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final command = text.trim();
    if (command.isNotEmpty) unawaited(widget.cluster.send(command));
    _input.clear();
    _inputFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.t.settings.cluster;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final status = widget.cluster.status;
        final usable = status.error != 'off' && status.error != 'unsupported';
        final live = status.state == ClusterState.connected || status.state == ClusterState.connecting;
        final entries = widget.cluster.transcript.entries;
        return CallbackShortcuts(
          // The command field holds focus, and a focused field stops Escape
          // before the pane's own dismissal hears it.
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(Navigator.maybePop(context))},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.md, Space.sm),
                child: Row(
                  children: [
                    Expanded(child: Text(clusterStatusText(status), style: theme.textTheme.bodyMedium)),
                    const SizedBox(width: Space.md),
                    TextButton(
                      onPressed: !usable ? null : (live ? widget.cluster.disconnect : () => unawaited(widget.cluster.stayConnected())),
                      child: Text(live ? s.consoleDisconnect : s.consoleConnect),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Text(
                            s.consoleEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : SelectionArea(
                        // Reversed, so the newest line sits at the bottom and the
                        // view stays there as lines arrive.
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
                          itemCount: entries.length,
                          itemBuilder: (context, i) => _TranscriptLine(entry: entries[entries.length - 1 - i]),
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.md),
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  enabled: usable,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'RobotoMono'),
                  decoration: poloFieldDecoration(context, s.consoleCommand, hintText: 'sh/dx'),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _submit,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.entry});

  final ClusterTranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = _transcriptStyle(context);
    final muted = base.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic);
    final s = context.t.settings.cluster;
    return switch (entry.kind) {
      ClusterTranscriptKind.received => Text(entry.text, style: base),
      ClusterTranscriptKind.sent => Text(
        '> ${entry.text}',
        style: base.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
      ClusterTranscriptKind.status => Text('— ${clusterStatusText(entry.status!)}', style: muted),
      ClusterTranscriptKind.retry => Text('— ${s.consoleRetry(command: entry.text)}', style: muted),
      ClusterTranscriptKind.gaveUp => Text(
        '— ${s.consoleGaveUp(command: entry.text, reason: clusterFailureReason(entry.status!))}',
        style: muted,
      ),
    };
  }
}
