// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The two ways a declared form is PRESENTED: over the surface that opened it,
// as a Modal Pane or as a dialog. The form itself — every element type, and
// the state behind them — is the form_renderer.dart library, it and its parts;
// this is only the shell around one, kept apart because that library's files
// have a size budget and the shell is the part of it that answers to nothing
// else.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'form_renderer.dart';
import 'halo_dialog.dart';
import 'modal_pane.dart';
import 'spacing.dart';

/// [showFormDialog]'s Modal Pane counterpart (see modal_pane.dart): the same
/// form-definition engine presented via [showModalPane], so on XS/S shirt
/// sizes it fills the screen instead of cramming a fixed-width AlertDialog.
/// For pane-sized forms (the QSO full editor); one-or-two-field prompts
/// should keep using [showFormDialog]. Completes with the submitted values,
/// or null on Cancel/close. `barrierDismissible: false` for the same reason
/// showFormDialog passes it to showDialog — a stray tap outside must not
/// discard in-progress edits (the title bar's close button still cancels).
///
/// `scrollable: false` + own Cancel/Save footer, NOT FormRenderer's built-in
/// `showActions` row: that row sits at the bottom of the form content, so on
/// a form taller than the pane it scrolls out of reach — Save must stay
/// pinned below the scrolling fields, same as showFormDialog's action bar.
Future<Map<String, dynamic>?> showFormPane(
  BuildContext context, {
  required Map<String, dynamic> formDefinition,
  required Map<String, dynamic> initialState,
  FormValidator? validator,
  FormTransformer? transformer,
  FormOnChange? onChange,
  FormAction? onAction,
  FormManageAccount? onManageAccount,
  FormOpenLink? onOpenLink,
  bool developerMode = false,
  String? saveLabel,

  /// A destructive action for the footer, beside Cancel and in its own
  /// colour. The PANE CLOSES FIRST and then the callback runs, so the
  /// callback owns only the confirmation. A caller cannot pop it itself
  /// safely: it holds the context it opened the pane from, and popping
  /// through that removes whatever route is topmost — a menu overlay from
  /// one of the form's own select fields, say — leaving the editor open
  /// over equipment that is being deleted underneath it.
  ({String label, VoidCallback onPressed, Color color, IconData? icon})? destructiveAction,

  /// A second thing the operator can do with what they are editing, sitting
  /// beside Save — the equipment editor's "Report this radio".
  ///
  /// Unlike [destructiveAction] the pane STAYS OPEN and the callback runs over
  /// it: this is not a way out of the form, and an operator who reports a
  /// radio and then decides not to report it must find their edits where they
  /// left them. So whatever the callback opens has to be a route of its own.
  ({String label, VoidCallback onPressed})? secondaryAction,

  /// Rebuilds the element list on a timer while the pane is open, for a form
  /// describing something that changes underneath it — the serial port
  /// picker, whose options are whatever is plugged in this second.
  ///
  /// The result is pushed only when it DIFFERS from what is on screen. An
  /// unchanged list must not be republished: it rebuilds every field, which
  /// closes an open dropdown menu under the operator's cursor — so a picker
  /// nobody has touched a cable for stays perfectly still.
  ({Duration every, Future<List<Map<String, dynamic>>> Function() build})? refreshElements,
}) {
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);
  // An action (or an actionable select option) can replace the element
  // list mid-edit — a newly-granted device becoming a selectable option,
  // say — so `formDefinition['elements']` can't just be handed to
  // [FormRenderer] once; this is what [FormRenderer.onElementsChanged]
  // pushes into.
  final elementsNotifier = ValueNotifier<List<Map<String, dynamic>>>((formDefinition['elements'] as List?)?.cast<Map<String, dynamic>>() ?? const []);

  return showModalPane<Map<String, dynamic>>(
    context,
    title: formDefinition['title'] as String?,
    barrierDismissible: false,
    scrollable: false,
    closeLabel: t.common.close,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: submittingNotifier,
      // While a submit's async validators/transformers are in flight the
      // pane must not be dismissible — the pane's title-bar close button,
      // Escape, and the XS/S back button would otherwise pop null mid-submit
      // and silently discard edits the user explicitly saved (submit()'s
      // mounted guard drops the result).
      // All three dismissal paths go through Navigator.maybePop (see
      // modal_pane.dart), which this PopScope blocks; the deliberate pops
      // below (Save's onSubmit, the footer's Cancel) call pop() directly
      // and are unaffected.
      builder: (context, isSubmitting, child) => PopScope(canPop: !isSubmitting, child: child!),
      // min + Flexible, not max + Expanded: the Column asks for only the
      // height the form needs, so the dialog card shrink-wraps a short form
      // instead of stranding the footer at the bottom of a full-height card.
      // spaceBetween is what keeps the footer pinned when the box is taller
      // than the form anyway (the full-screen presentation, which IS the
      // screen): the slack falls between the fields and the footer.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            // A sliver viewport, shrink-wrapped: the form's own section bands
            // pin (docs/design/user-interface.md § Settings lists), which a
            // plain scroll view cannot do, while the pane still sizes to a
            // short form rather than filling the card.
            //
            // The horizontal inset rides the row theme rather than padding
            // the viewport: a FILLED band (`style: 'category'`) runs to the
            // pane's edges, and a padded viewport would leave it floating in
            // a gutter. Every row reads the same theme, so they land where
            // the padding used to put them.
            child: ListTileTheme.merge(
              contentPadding: const EdgeInsets.symmetric(horizontal: Space.xxl),
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: Space.lg),
                    sliver: _PeriodicElements(
                      // Owned by a widget rather than started beside the route:
                      // the timer then dies with the tree that shows the form,
                      // whichever way that tree goes away.
                      refresh: refreshElements,
                      elements: elementsNotifier,
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: elementsNotifier,
                        builder: (context, elements, _) => FormRenderer(
                          key: formKey,
                          formDefinition: {...formDefinition, 'elements': elements},
                          initialState: initialState,
                          validator: validator,
                          transformer: transformer,
                          onChange: onChange,
                          onAction: onAction,
                          onElementsChanged: (updated) => elementsNotifier.value = updated,
                          onManageAccount: onManageAccount,
                          onOpenLink: onOpenLink,
                          developerMode: developerMode,
                          // The pane's own title bar already shows formDefinition['title'].
                          showTitle: false,
                          showActions: false,
                          sliver: true,
                          submittingNotifier: submittingNotifier,
                          onSubmit: (values) => Navigator.of(context).pop(values),
                          onCancel: () => Navigator.of(context).pop(null),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: submittingNotifier,
            builder: (context, isSubmitting, _) => Container(
              decoration: haloDialogFooterBandDecoration(context),
              padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.lg),
              child: formActionsRow(
                saveLabel: saveLabel,
                isSubmitting: isSubmitting,
                onCancel: () => Navigator.of(context).pop(null),
                onSave: () => formKey.currentState?.submit(),
                destructive: destructiveAction == null
                    ? null
                    : (
                        label: destructiveAction.label,
                        color: destructiveAction.color,
                        icon: destructiveAction.icon,
                        // This context is INSIDE the pane, so the pop is
                        // the pane's own, not whatever happens to be on top
                        // of the caller's navigator.
                        onPressed: () {
                          Navigator.of(context).pop(null);
                          destructiveAction.onPressed();
                        },
                      ),
                // Passed through untouched — no pop, deliberately: see
                // [secondaryAction]'s doc.
                secondary: secondaryAction,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Rebuilds [elements] on a timer for as long as this is in the tree — see
/// [showFormPane]'s `refreshElements`. A widget rather than a timer started
/// beside the route, so it is the TREE's life that bounds it: a pane popped
/// normally and a test tearing the tree down both end it, and neither leaves
/// a timer enumerating hardware for a form nobody is looking at.
class _PeriodicElements extends StatefulWidget {
  final ({Duration every, Future<List<Map<String, dynamic>>> Function() build})? refresh;
  final ValueNotifier<List<Map<String, dynamic>>> elements;
  final Widget child;

  const _PeriodicElements({required this.refresh, required this.elements, required this.child});

  @override
  State<_PeriodicElements> createState() => _PeriodicElementsState();
}

class _PeriodicElementsState extends State<_PeriodicElements> {
  Timer? _timer;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    final refresh = widget.refresh;
    if (refresh == null) return;
    _timer = Timer.periodic(refresh.every, (_) => unawaited(_tick(refresh.build)));
  }

  Future<void> _tick(Future<List<Map<String, dynamic>>> Function() build) async {
    // A tick landing while the previous build is still out would enumerate
    // twice over; skipping is right rather than queueing, since the next tick
    // asks the same question again anyway.
    if (_refreshing) return;
    _refreshing = true;
    try {
      final rebuilt = await build();
      // Only once it DIFFERS. An unchanged republish rebuilds every field,
      // which closes an open dropdown menu under the operator's cursor — so a
      // picker nobody has plugged a cable for stays perfectly still.
      if (mounted && !const DeepCollectionEquality().equals(rebuilt, widget.elements.value)) {
        widget.elements.value = rebuilt;
      }
    } catch (e) {
      // Skip the tick, keep the timer. The callback enumerates real hardware
      // and reads live equipment state, so it can throw — and without this
      // every throw is an unhandled async error, repeating for as long as the
      // pane stays open with nothing to stop it. The form goes on showing
      // what it last had, which is the right answer for one missed look.
      debugPrint('[form] periodic element refresh failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
