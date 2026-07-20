// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Modal Panes (docs/design/layouts.md): pane-sized modal content, designed
// at idealPaneWidth. On XS/S shirt sizes it presents as a full screen whose
// AppBar back button IS the dismissal; on L/XL as a centered dialog with
// barrier/Escape dismissal. It is ONE route that checks the shirt size on
// every build, so a pane that's open while the window is resized across the
// S/L boundary re-presents in place — no pop-and-reshow, no lost state, and
// `Navigator.pop(context, result)` resolves the same `await` either way.
//
// For brief messages or one-or-two-field prompts keep using plain
// `showDialog` — Modal Panes are for content that fills a pane.

import 'package:flutter/material.dart';

import 'halo_dialog.dart';
import 'layout.dart';
import 'platform_chrome.dart';
import 'theme.dart';

/// `showDialog` with the app's shared modal sizing applied
/// ([haloDialogConstraints]) — use this instead of `showDialog` directly so
/// every dialog is held to the same box as a Modal Pane rather than each
/// growing to fit its own content.
Future<T?> showHaloDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  // Center first: showDialog hands its builder TIGHT full-screen constraints,
  // and a ConstrainedBox can't shrink below a tight incoming width — the cap
  // would silently do nothing. Center loosens them so the cap actually bites.
  builder: (context) => Center(
    child: ConstrainedBox(constraints: haloDialogConstraints(context), child: builder(context)),
  ),
);

/// Shows [builder]'s content as a Modal Pane and completes with the value
/// passed to `Navigator.pop`. Call it like `showDialog`.
///
/// With `scrollable: false` the body is NOT wrapped in a scroll view:
/// it gets the pane's full bounded height (edge to edge, no padding) and
/// manages its own layout — for content built around Expanded sections or
/// its own scrollables (e.g. the Activities pane's accordion), which would
/// otherwise sit in unbounded height and fail to lay out.
///
/// Action rows are the pane's own job (every current pane's buttons depend
/// on its State — _busy, _testing, mode — which a route-level builder can't
/// see), so there is deliberately no `actions` parameter here.
Future<T?> showModalPane<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool barrierDismissible = true,
  bool scrollable = true,
}) => Navigator.of(context).push(
  ModalPaneRoute<T>(builder: builder, title: title, barrierDismissible: barrierDismissible, scrollable: scrollable),
);

class ModalPaneRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final String? title;
  final bool scrollable;
  final bool _barrierDismissible;

  /// Carries the body's Element (and State) across the presentation flip:
  /// the two presentations have different widget trees, so without this
  /// GlobalKey a resize across the S/L boundary would re-inflate the body
  /// and destroy in-progress input.
  final _bodyKey = GlobalKey();

  ModalPaneRoute({required this.builder, this.title, this._barrierDismissible = true, this.scrollable = true});

  @override
  Color? get barrierColor => Colors.black54;

  /// Also enables Escape-to-dismiss (ModalRoute handles DismissIntent).
  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _ModalPaneScaffold(route: this);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}

class _ModalPaneScaffold extends StatelessWidget {
  final ModalPaneRoute<dynamic> route;

  const _ModalPaneScaffold({required this.route});

  @override
  Widget build(BuildContext context) {
    // Checked on every build: a window resize across the S/L boundary
    // re-presents the open pane in place. Both presentations share the
    // GlobalKey'd body (so its State reparents instead of re-inflating) and
    // scope their own ScaffoldMessenger: without it, SnackBars raised from
    // pane content land on the Scaffold BENEATH the route — dimmed behind
    // the dialog's barrier and invisible.
    if (ShirtSize.of(context).isTwoPane) return _buildDialog(context);
    return _buildFullScreen(context);
  }

  /// The Builder matters: it hands [ModalPaneRoute.builder] a context that
  /// lives INSIDE the route's scoped ScaffoldMessenger (and Scaffold), so
  /// `ScaffoldMessenger.of` / `Scaffold.of` from the builder's own context
  /// resolve to the route's — same contract as `showDialog`.
  Widget _body() => KeyedSubtree(
    key: route._bodyKey,
    child: Builder(builder: route.builder),
  );

  Widget _buildFullScreen(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        appBar: AppBar(
          // Full-screen presentation puts this AppBar at the window top, so
          // it doubles as the window header.
          flexibleSpace: windowHeaderGestureArea(),
          // The back button is the dismissal — same Navigator.pop as the
          // dialog presentation's close button.
          leadingWidth: macOSAwareLeadingWidth(context),
          leading: macOSAwareBackButton(context),
          title: route.title == null ? null : Text(route.title!),
          actions: [windowsCaptionSpacer(context)],
        ),
        body: SafeArea(
          child: route.scrollable ? SingleChildScrollView(padding: const EdgeInsets.all(24), child: _body()) : _body(),
        ),
      ),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final theme = Theme.of(context);
    // The same box every dialog gets, so panes and plain dialogs read as one
    // family (haloDialogConstraints also guards the height against going
    // negative on a window shorter than the header clearance).
    final dialogConstraints = haloDialogConstraints(context);
    final maxPaneHeight = dialogConstraints.maxHeight;
    // The transparent full-screen Scaffold exists so the route-scoped
    // ScaffoldMessenger has somewhere to show SnackBars ABOVE the barrier
    // (and it absorbs the keyboard inset like any Scaffold). It covers the
    // framework's ModalBarrier, so the outer GestureDetector re-provides
    // tap-outside dismissal; Escape still goes through the route's own
    // barrierDismissible handling.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // maybePop, not pop: dismissals (barrier, close button, Escape,
          // the full-screen back button) must respect a PopScope inside the
          // pane's own content — e.g. showFormPane blocks dismissal while a
          // submit is in flight. Deliberate pops (a pane's own Save/Cancel)
          // still call Navigator.pop directly.
          onTap: route.barrierDismissible ? () => Navigator.of(context).maybePop() : null,
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                // Taps on the card itself must not fall through to the
                // barrier handler above.
                onTap: () {},
                child: ConstrainedBox(
                  // A non-scrollable body needs a DETERMINATE height for
                  // its own Expanded sections to divide, so the card
                  // commits to full height instead of shrink-wrapping.
                  constraints: dialogConstraints.copyWith(minHeight: route.scrollable ? 0 : maxPaneHeight),
                  child: Material(
                    color: theme.dialogTheme.backgroundColor ?? haloDialogBandColor(context),
                    elevation: 6,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: theme.colorScheme.surfaceTint,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The same banded header a dialog gets — one shared
                        // widget, so the two families can't drift apart.
                        HaloDialogHeader(
                          title: route.title == null ? null : Text(route.title!),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                            // maybePop — see the barrier handler above.
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        // Surface-coloured body framed by the bands. Material,
                        // not ColoredBox: InkWell content paints its splashes
                        // on the nearest Material ancestor.
                        if (route.scrollable)
                          Flexible(
                            child: Material(
                              color: theme.colorScheme.surface,
                              child: SizedBox(
                                width: double.infinity,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                                  child: _body(),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            // Edge to edge, no padding — a non-scrollable body
                            // manages its own layout (see showModalPane's doc).
                            child: Material(color: theme.colorScheme.surface, child: _body()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
