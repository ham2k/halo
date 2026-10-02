// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What the operator is told once their exports reach Ham2K's File Stash:
// where to fetch them, and a one-tap way to get that link into their inbox —
// the stash is for the phone in the field whose files have to reach a
// computer later, and the inbox is what the computer already has.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import '../../services/link_opener.dart' show openExternalUrl;

/// Shows the dialog for [count] stashed files. [freeAccount] adds the tier
/// note; null (the account couldn't be read) says nothing rather than
/// guessing. [failures] names the files of the same batch that did not
/// arrive, one line each.
Future<void> showStashSentDialog(
  BuildContext context, {
  required HaLoServices services,
  required int count,
  bool? freeAccount,
  List<String> failures = const [],
}) => showHaloDialog<void>(
  context: context,
  builder: (_) => StashSentDialog(services: services, count: count, freeAccount: freeAccount, failures: failures),
);

class StashSentDialog extends StatefulWidget {
  final HaLoServices services;
  final int count;
  final bool? freeAccount;
  final List<String> failures;

  const StashSentDialog({super.key, required this.services, required this.count, this.freeAccount, this.failures = const []});

  @override
  State<StashSentDialog> createState() => _StashSentDialogState();
}

class _StashSentDialogState extends State<StashSentDialog> {
  bool _emailing = false;
  bool _emailSent = false;
  String? _emailError;

  Future<void> _emailLink() async {
    final t = context.t;
    setState(() {
      _emailing = true;
      _emailError = null;
    });
    final result = await widget.services.extensions.emailStashLink();
    if (!mounted) return;
    final error = result?['error'];
    final sent = error == null && result?['ok'] == true;
    // Neither a refusal nor a yes — no runtime, or a reply the transport
    // never documented — has nothing the operator could act on in it.
    if (!sent && error is! String) debugPrint('[stash] emailStashLink answered $result');
    setState(() {
      _emailing = false;
      if (sent) {
        _emailSent = true;
      } else {
        _emailError = t.operation.export.stash.emailFailed(error: error is String && error.isNotEmpty ? error : t.extensionService.stashUnavailable);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.t.operation.export.stash;
    final theme = Theme.of(context);
    return HaloDialog(
      title: Text(s.sentTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InlineMarkdownText(
            s.retrieve(count: widget.count),
            style: theme.textTheme.bodyMedium?.copyWith(fontFamilyFallback: const [emojiFontFamily]),
            onOpenLink: openExternalUrl,
            // An ellipsis with no line limit truncates to ONE line, and the
            // line it cuts is the address the operator came here for.
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          if (widget.failures.isNotEmpty) ...[
            const SizedBox(height: Space.lg),
            Text(
              [s.notArrived(count: widget.failures.length), ...widget.failures].join('\n'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: Space.xl),
          Text(s.emailOffer, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Space.lg),
          Center(
            child: _emailSent
                ? Text(
                    s.emailSent,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_emailError != null) ...[
                        Text(
                          _emailError!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: Space.md),
                      ],
                      FilledButton.icon(
                        onPressed: _emailing ? null : _emailLink,
                        icon: _emailing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(MdiIcons.emailOutline, size: 18),
                        label: Text(s.emailMe),
                      ),
                    ],
                  ),
          ),
          // The tier note is where a Subscribe button joins it once the app
          // can sell a subscription — beside the limit it lifts.
          if (widget.freeAccount == true) ...[
            const SizedBox(height: Space.xl),
            Text(s.freeTier, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      // Nothing left to confirm: Done, in the cancel slot
      // (docs/design/user-interface.md § Dialogs).
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
    );
  }
}
