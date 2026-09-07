// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The CW message editor: one row per function key — the key, an optional
// label beside it, the template underneath — each opening its own dialog
// with the message and, under a Details band, the label. Reached from the
// Station dialog's Messages button and from the keyer area's dialog.
//
// The messages themselves are settings (`cwMessage1..8`, `cwMessageLabel1..8`
// in the Radio group), so SET and All Settings reach them too; this is the
// editor an operator meets, not the storage.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../services/halo_services.dart';
import '../services/settings_service.dart';

/// The glyph for message `n` (1-based): its key's number in a circle, the
/// same one the settings fields declare by name. Consts, not names resolved
/// from a literal string — a literal icon name in core Dart is invisible to
/// the guard that checks every name resolves.
const cwMessageNumberIcons = [
  MdiIcons.numeric1Circle,
  MdiIcons.numeric2Circle,
  MdiIcons.numeric3Circle,
  MdiIcons.numeric4Circle,
  MdiIcons.numeric5Circle,
  MdiIcons.numeric6Circle,
  MdiIcons.numeric7Circle,
  MdiIcons.numeric8Circle,
];

Future<void> showCwMessagesDialog(BuildContext context, HaLoServices services) => showHaloDialog<void>(
      context: context,
      builder: (context) => _CwMessagesDialog(services: services),
    );

class _CwMessagesDialog extends StatelessWidget {
  final HaLoServices services;

  const _CwMessagesDialog({required this.services});

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    final theme = Theme.of(context);
    final settings = services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => HaloDialog(
        title: Text(m.title),
        // The rows ARE the dialog's content — to the card's edges, inset
        // off the same SettingsList every other list in the app reads.
        list: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var n = 1; n <= SettingsService.cwMessageCount; n++)
              ListTile(
                leading: Icon(cwMessageNumberIcons[n - 1]),
                title: Text.rich(TextSpan(children: [
                  TextSpan(text: m.key(n: n), style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (settings.cwMessageLabel(n).trim().isNotEmpty) TextSpan(text: '  ${settings.cwMessageLabel(n).trim()}'),
                ])),
                subtitle: Text(
                  settings.cwMessage(n).trim().isEmpty ? m.empty : settings.cwMessage(n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: settings.cwMessage(n).trim().isEmpty
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
                onTap: () => showHaloDialog<void>(
                  context: context,
                  builder: (context) => _CwMessageDialog(settings: settings, n: n),
                ),
                mouseCursor: SystemMouseCursors.click,
              ),
          ],
        ),
        // Done, not Close: the footer convention for a dialog with nothing to
        // commit (dialog_footer_convention_test.dart).
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }
}

/// One message: the template first, then its label under a Details band.
class _CwMessageDialog extends StatefulWidget {
  final SettingsService settings;
  final int n;

  const _CwMessageDialog({required this.settings, required this.n});

  @override
  State<_CwMessageDialog> createState() => _CwMessageDialogState();
}

class _CwMessageDialogState extends State<_CwMessageDialog> {
  late final _message = TextEditingController(text: widget.settings.cwMessage(widget.n));
  late final _label = TextEditingController(text: widget.settings.cwMessageLabel(widget.n));

  @override
  void dispose() {
    _message.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    await widget.settings.setCwMessage(widget.n, _message.text.trim());
    await widget.settings.setCwMessageLabel(widget.n, _label.text.trim());
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.t.settings.radio.cwMessages;
    // Zero content inset so the Details band runs edge to edge; the fields
    // take the dialog's usual inset themselves (halo_dialog.dart's default).
    const rowInset = EdgeInsets.symmetric(horizontal: Space.xxl);
    return HaloDialog(
      title: Text(m.messageTitle(n: widget.n)),
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: rowInset.copyWith(top: Space.xl, bottom: Space.xl),
            child: TextField(
              controller: _message,
              autofocus: true,
              // Not uppercased: Liquid's `{{ qso.call }}` is case-sensitive,
              // and the queue uppercases what is keyed anyway.
              decoration: poloFieldDecoration(context, m.key(n: widget.n)),
              onSubmitted: (_) => _save(),
            ),
          ),
          SectionHeader(m.details),
          Padding(
            padding: rowInset.copyWith(top: Space.lg, bottom: Space.xl),
            child: TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: poloFieldDecoration(context, m.labelField),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}
