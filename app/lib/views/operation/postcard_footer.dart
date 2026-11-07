// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Postcard's footer: its actions at the leading edge, Done at
// the trailing one.

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

/// A footer action: its icon, the label it shows where there is room, and
/// [onPressed] or a [menu] of actions to pick from.
typedef PostcardAction = ({IconData icon, String label, VoidCallback? onPressed, List<PostcardMenuAction>? menu});
typedef PostcardMenuAction = ({IconData icon, String label, VoidCallback onPressed});

/// The actions at the footer's leading edge and Done at its trailing one,
/// the actions' labels given up from the trailing edge in until they fit
/// the room Done leaves them. All of them disabled while [busy].
///
/// Which of them fits is read off the buttons themselves: every form of the
/// row laid out unseen at its natural width once, and then, whatever the
/// room, the first no wider than it taken — no arithmetic about buttons'
/// padding to go stale. Measured again only when the labels or the text
/// size change.
class PostcardFooter extends StatefulWidget {
  final List<PostcardAction> actions;
  final bool busy;

  const PostcardFooter({super.key, required this.actions, required this.busy});

  @override
  State<PostcardFooter> createState() => _PostcardFooterState();
}

class _PostcardFooterState extends State<PostcardFooter> {
  /// Each form of the footer's action row at its natural width — none, then
  /// one, two… of them from the trailing edge showing their icon alone — as
  /// measured for [_formsOf]; null until measured.
  List<double>? _formWidths;
  String? _formsOf;
  final _forms = <GlobalKey>[];

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    final busy = widget.busy;
    Widget button(PostcardAction action, {required bool bare}) {
      Widget make(VoidCallback? onPressed) => bare
          ? MergeSemantics(
              child: Semantics(
                label: action.label,
                child: FilledButton(onPressed: onPressed, child: Icon(action.icon)),
              ),
            )
          : FilledButton.icon(onPressed: onPressed, icon: Icon(action.icon), label: Text(action.label));
      final menu = action.menu;
      if (menu == null) return make(busy ? null : action.onPressed);
      return MenuAnchor(
        menuChildren: [
          PlatformViewShield(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final item in menu) MenuItemButton(leadingIcon: Icon(item.icon), onPressed: item.onPressed, child: Text(item.label))],
            ),
          ),
        ],
        builder: (context, controller, _) => make(busy ? null : () => controller.isOpen ? controller.close() : controller.open()),
      );
    }

    Widget row(int bare) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.md,
      children: [for (final (i, action) in actions.indexed) button(action, bare: i >= actions.length - bare)],
    );

    final forms = '${[for (final action in actions) action.label].join('|')}@${MediaQuery.textScalerOf(context).scale(100)}';
    final widths = forms == _formsOf ? _formWidths : null;
    while (_forms.length < actions.length + 1) {
      _forms.add(GlobalKey());
    }
    if (widths == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final measured = [
          for (var bare = 0; bare <= actions.length; bare++)
            switch (_forms[bare].currentContext?.findRenderObject()) {
              final RenderBox box when box.hasSize => box.size.width,
              _ => null,
            },
        ];
        if (measured.contains(null)) return;
        setState(() {
          _formWidths = measured.cast<double>();
          _formsOf = forms;
        });
      });
    }
    return haloDialogFooterBand(
      context,
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      tools: widths == null
          // Icons alone until measured: the narrowest form, so nothing jumps.
          ? Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: row(actions.length)),
                ),
                for (var bare = 0; bare <= actions.length; bare++)
                  Offstage(
                    child: ExcludeFocus(
                      child: UnconstrainedBox(
                        child: KeyedSubtree(key: _forms[bare], child: row(bare)),
                      ),
                    ),
                  ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // The fewest bare that fits; where none does, all of them, so
                // that narrowing the pane never brings a label back.
                final fits = widths.indexWhere((width) => width <= constraints.maxWidth + 0.5);
                return Align(
                  alignment: Alignment.centerLeft,
                  // Scaled down only where even the icons alone do not fit.
                  child: FittedBox(fit: BoxFit.scaleDown, child: row(fits < 0 ? actions.length : fits)),
                );
              },
            ),
    );
  }
}
