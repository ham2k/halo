// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Find bar over a logging panel's QSO list, and the chord that opens it.
// What its text means is LogFindQuery's (tools/log_find_query.dart); what it
// does to the list is the panel's (LoggingPanel).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

class LogFindBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  /// Escape in the field, or the close button: clear the find and hide the
  /// bar.
  final VoidCallback onClose;

  /// A walk key in the field ([qsoListWalkFor]), offered to the list below
  /// it; returns whether it took the key, which is otherwise the field's.
  final bool Function(QsoListWalk walk) onWalk;

  /// Whether Escape is already spoken for by something that runs ahead of
  /// the field — a CW message it just stopped — and so must not also close
  /// the bar. See `CatService.escapeStoppedKeying`.
  final bool Function() escapeClaimed;

  /// What the find came to — a match count, or that nothing matched — shown
  /// at the field's end. Null shows nothing.
  final String? result;

  const LogFindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onWalk,
    required this.escapeClaimed,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: PaneSafeArea.symmetricOf(context, horizontal: Space.lg, vertical: Space.sm),
        child: SizedBox(
          height: 36,
          // The field's own node, not a binding over the panel: Escape and
          // the walk keys mean this here, and anywhere else in the panel they
          // keep their usual meanings (docs/design/logging-fields.md).
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                if (!escapeClaimed()) onClose();
                return KeyEventResult.handled;
              }
              final walk = qsoListWalkFor(event);
              return walk != null && onWalk(walk) ? KeyEventResult.handled : KeyEventResult.ignored;
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              // Enter acts on the find; it must not drop the keyboard on the
              // way, since acting on it is what puts the keyboard somewhere.
              onEditingComplete: () {},
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: const [UpperCaseTextFormatter()],
              style: haloMonoStyle(context, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
                prefixIcon: const Icon(MdiIcons.magnify),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (result != null) Text(result, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    IconButton(
                      icon: Icon(MdiIcons.close, semanticLabel: context.t.common.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
                hintText: context.t.qsoList.find.hint,
                // Dimmed by hand: nothing themed does it for a hand-built
                // decoration, and at full strength the hint reads as a find
                // already typed.
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu item that opens Find, naming [isFindChord] as the operator would
/// press it: ⌘F on Apple platforms (a browser's included), Ctrl+F elsewhere,
/// unless rebound — and no key at all with none bound.
String findMenuItemLabel(Translations t) => switch (keyBindings.value.label('logView.find')) {
  final shortcut? => t.qsoList.find.menuItem(shortcut: shortcut),
  null => t.qsoList.find.menuItemNoShortcut,
};

/// What opens Find in a view whose context is a log: ⌘F, or Ctrl+F off a
/// Mac, unless rebound (`logView.find`). Taken on every platform, the way ⌘K
/// is (halo_app.dart).
bool isFindChord(KeyEvent event) => event is KeyDownEvent && keyBindings.value.claim('logView.find', event) != null;
