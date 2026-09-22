// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// Holds [child] inert, under a notice offering Undelete, for as long as
/// [operation] is deleted.
///
/// A deleted operation is read-only until it is undeleted. Saving one
/// re-stamps it, and that stamp is what `undeleteOperationWithQsos` finds its
/// QSOs by; a QSO logged into one is invisible to call history here and lands
/// in an operation every other device treats as gone.
///
/// The same tree at every state, not only while deleted, so that undeleting
/// does not reparent — and so rebuild from scratch — the panel underneath.
class ReadOnlyWhileDeleted extends StatelessWidget {
  final Operation operation;
  final VoidCallback onUndelete;
  final Widget child;

  const ReadOnlyWhileDeleted({super.key, required this.operation, required this.onUndelete, required this.child});

  @override
  Widget build(BuildContext context) {
    final deleted = operation.deleted;
    return Stack(
      // The panel gets the constraints its pane hands down, as it would
      // unwrapped.
      fit: StackFit.passthrough,
      children: [
        ExcludeFocus(
          excluding: deleted,
          child: AbsorbPointer(
            absorbing: deleted,
            child: Opacity(opacity: deleted ? 0.5 : 1, child: child),
          ),
        ),
        if (deleted)
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.t.operation.deletedReadOnly, textAlign: TextAlign.center),
                    const SizedBox(height: Space.md),
                    FilledButton.icon(icon: const Icon(MdiIcons.deleteRestore), label: Text(context.t.activitiesView.undeleteOperation), onPressed: onUndelete),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
