// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation view's setup sheet: opening it (or the callsign prompt in
// its place), the draft it buffers, and the draft's live title.

part of '../operation_view.dart';

mixin _OperationSheetHost on State<OperationView>, DockHost<OperationView>, _OperationHeader {
  // Owned by `_OperationViewState`.
  Operation? get _operation;
  set _operation(Operation? operation);
  OperationRuntimeState get _runtime;

  @override
  Operation? _draftOperation;

  /// The draft's ref-derived title fragments, suggested but deliberately not
  /// cached (the draft has no saved row to cache into) — null until the first
  /// suggestion for the current draft lands, at which point the header stops
  /// using the saved row's now-stale cache. Same generation-counter guard as
  /// OperationTitleService: an older, slower fan-out must not overwrite a
  /// newer one's result.
  OperationTitleFragments? _draftTitleFragments;
  int _draftTitleGeneration = 0;

  /// Carries the draft's last-known-good title fragments PAST the moment the
  /// sheet closes and _draftTitleFragments is dropped — saveAndClose()
  /// persists the sheet's own (still stale-titleSuggestion) operation, so
  /// watchOperation's very next emission reads that stale cache straight
  /// back over whatever _withTitleSuggestion patched into _operation at
  /// close. Kept alive and re-applied to every incoming stream emission
  /// (see [_onOperationChanged]) until the row's OWN persisted cache
  /// actually catches up — the separate, async
  /// OperationTitleService.retitleOperation() call that same emission
  /// triggers — at which point it's cleared as redundant.
  OperationTitleFragments? _pendingTitleFragments;

  bool _sameTitleFragments(OperationTitleFragments a, OperationTitleFragments b) =>
      a.title == b.title && a.forText == b.forText && a.atText == b.atText && a.subtitle == b.subtitle;

  /// Re-suggests the header title for the sheet's buffered draft. Fire-and-
  /// forget, like the saved-row retitle — the title is a display enhancement,
  /// so a failed or superseded run just leaves the previous one showing.
  Future<void> _retitleDraft(Operation draft) async {
    final generation = ++_draftTitleGeneration;
    final fragments = await widget.services.operationTitles.suggestFragments(draft);
    if (!mounted || fragments == null || generation != _draftTitleGeneration) return;
    setState(() => _draftTitleFragments = fragments);
  }

  /// Runs [action] once this view's push transition has settled. The pane
  /// showModalPane opens sizes itself against this view, so it must not go up
  /// before the view is laid out — and pushing it mid-transition races the
  /// teardown of the screen we were pushed over.
  void _afterPushTransition(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        action();
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        if (mounted) action();
      }

      animation.addStatusListener(onStatus);
    });
  }

  /// The same Callsign field as Settings → Callsign, offered when a new
  /// operation was started with no profile callsign: the save lands in the
  /// profile (like the settings panel) AND on this operation, which was
  /// created before the callsign existed. Cancelling leaves both unset —
  /// the operation's own settings can fix it later.
  Future<void> _promptForCallsign(Operation operation) async {
    final result = await editOneFieldDialog(context, title: context.t.common.callsign, fieldLabel: context.t.common.callsign, fieldInitial: '', callsign: true);
    if (result == null || result.trim().isEmpty) return;
    // Profile first, because the operation write is the one that can fail:
    // `WritePolicy` refuses it on a travelled clock, and an operation created
    // while travelling is born `/TEST`, so the very callsign this prompt
    // exists to collect is one the gate declines to store. Sequencing the
    // operation first would take the profile write down with it and leave the
    // operator with neither.
    await widget.services.setOperatorCall(result);
    await widget.services.operations.saveData(
      Operation(
        uuid: operation.uuid,
        data: {...operation.data, 'stationCall': result.trim().toUpperCase()},
        qsoCount: operation.qsoCount,
        startAtMillisMin: operation.startAtMillisMin,
        startAtMillisMax: operation.startAtMillisMax,
        localData: operation.localData,
      ),
    );
  }

  @override
  Future<void> _editActivities(Operation operation) async {
    if (operation.deleted) return;
    await _openOperationSheet(operation);
  }

  /// Opens the operation sheet, or — if the profile still has no operator
  /// callsign (fresh install, no onboarding flow existed for it before) —
  /// the callsign prompt in its place. [markOnboardingSeen] records the
  /// 'operation-sheet' onboarding flow as shown, but only once the sheet
  /// ITSELF actually opens: the callsign prompt isn't the sheet, so hitting
  /// that branch must not count as having seen it.
  void _openActivitiesOrPromptForCallsign(Operation operation, {required bool markOnboardingSeen}) {
    // Both branches write to the operation, and a deleted one is read-only.
    if (operation.deleted) return;
    // The screen we were pushed over can still hold focus while its
    // subtree goes away; leaving it focused lets the engine move DOM
    // focus through a Focus node that is already inactive (web).
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.services.settings.activeProfile.operatorCall.isEmpty) {
      _promptForCallsign(operation);
    } else {
      if (markOnboardingSeen) {
        unawaited(widget.services.settings.recordOnboardingShown(OnboardingFlows.operationSheet));
      }
      _editActivities(operation);
    }
  }

  @override
  Animation<double>? _sheetAnimation;
  VoidCallback? _sheetAnimationListener;
  @override
  GlobalKey<OperationSheetState>? _activeSheetKey;

  Future<void> _openOperationSheet(Operation operation) async {
    // No manual re-fetch on pop: watchOperation streams the change back.
    // Non-scrollable: the pane's accordion sections divide its height
    // themselves (see activities_view.dart). A barrier tap, Escape and a
    // system back all reach the sheet's own PopScope, which saves it.
    final sheetKey = GlobalKey<OperationSheetState>();
    // Not disposed with the sheet: the accept button listens through the
    // reverse transition, which outlives this method's `finally`.
    final sheetClosing = ValueNotifier(false);
    if (!mounted) return;
    setState(() {
      _draftOperation = operation;
      _activeSheetKey = sheetKey;
    });

    // Captured so the `finally` block below can arm a defensive fallback
    // against this specific animation object — see its own comment.
    Animation<double>? sheetAnim;
    try {
      await showTopModalPane<void>(
        context,
        onAnimation: (anim) {
          sheetAnim = anim;
          _sheetAnimationListener?.call();
          _sheetAnimation = anim;
          void animListener() {
            if (mounted) setState(() {});
          }

          // Navigator.push()'s Future (what `await showTopModalPane` below
          // is waiting on) completes the instant saveAndClose()/revert-
          // AndClose() calls pop() — well before the route's reverse
          // transition actually finishes playing. If this listener were
          // torn down in that `finally` block instead, _sheetAnimation
          // would go null immediately, snapping the header's dots
          // control straight to "closed" while the sheet itself keeps
          // sliding away for the rest of its 600ms. So this detaches
          // itself only once the animation genuinely reaches
          // AnimationStatus.dismissed, keeping the header in sync with
          // the pane for the whole reverse transition; the `identical`
          // check guards against a late-firing dismissal from a PREVIOUS
          // sheet clobbering a new one that's already open.
          void statusListener(AnimationStatus status) {
            if (status != AnimationStatus.dismissed) return;
            anim.removeListener(animListener);
            anim.removeStatusListener(statusListener);
            if (mounted && identical(_sheetAnimation, anim)) {
              setState(() => _sheetAnimation = null);
            }
          }

          anim.addListener(animListener);
          anim.addStatusListener(statusListener);
          _sheetAnimationListener = () {
            anim.removeListener(animListener);
            anim.removeStatusListener(statusListener);
          };
        },
        // Left-aligned with the dots-and-title control that opens it,
        // rather than centered in the pane.
        leftInset: _headerTitleLeftInset,
        // Narrow has no card edge to line the accept button up with (the
        // pane is full-bleed there), and the control it stands in for — the
        // header's own chevron — has faded out of that corner, so it takes
        // the corner itself rather than sitting indented behind nothing.
        // Only the native window controls still get their room.
        narrowLeftInset: _narrowSheetLeftInset(context),
        scrollable: false,
        barrierDismissible: true,
        // The view's AppBar (X, title, Options/Export, the accept button
        // below) stays visible on narrow too instead of the sheet covering
        // the whole screen — the same header serves both layouts, so there
        // is no separate narrow-only header to keep in sync with it. Actual
        // reachability for X/Options/Export is headerTrailing's job, below —
        // this alone only stops the sheet from painting over them.
        keepHeaderVisible: true,
        // No header band of its own: the accept control lives in the strip
        // of VIEW header this pane leaves uncovered instead (headerLeading,
        // reachable above the pane's own dismiss layer — see its doc in
        // modal_pane.dart), left-aligned with the title it covers. Dismissal
        // still works via the barrier tap, Escape, and onDismiss above.
        showHeader: false,
        headerLeading: Builder(
          builder: (context) => SheetAcceptHandoff(
            animation: _sheetAnimation,
            child: KeyedSubtree(key: _sheetOkButtonKey, child: _sheetOkButton(context, sheetKey, sheetClosing)),
          ),
        ),
        // Live copies of the AppBar's own X and Options/Export, reachable
        // above the barrier the same way the accept button is — the real
        // ones fade out and stop taking taps in step with this (see the
        // AppBar's own `leading`/`actions`). Each closes the sheet before
        // applying its own action, rather than just dismissing it the way an
        // ordinary barrier tap does: the operator tapped a specific control,
        // not empty space, so it should do what it says.
        //
        // Both copies stay put, exactly over the real ones they stand in
        // for — nothing in this header moves because a sheet opened.
        // `SizedBox` sizes this to the full header width so each can
        // `Positioned` itself within it independently.
        // Only the chevron has a copy up here. The operation's own
        // Exports/Imports/Tools group — and the layout controls beside it —
        // stay exactly where they are in the AppBar below, untouched and
        // merely disabled while the sheet is up (see the AppBar's own
        // `actions`), so nothing about that end of the header moves,
        // recolours or duplicates itself around a sheet. The chevron is the
        // exception because something really does replace it: the accept
        // button takes its corner.
        headerTrailing: Builder(
          builder: (context) {
            final isTwoPane = ShirtSize.of(context).isTwoPane;
            final toolbarHeight = Theme.of(context).appBarTheme.toolbarHeight ?? kToolbarHeight;
            return SizedBox(
              width: double.infinity,
              height: toolbarHeight,
              child: ValueListenableBuilder<({String title, String subtitle})?>(
                valueListenable: _sheetHeaderLines,
                builder: (context, pushedLines, _) => AnimatedBuilder(
                  animation: _sheetAnimation ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, _) {
                    final growth = ((_sheetAnimation?.value ?? 1.0) / sheetHandoffThreshold).clamp(0.0, 1.0);
                    final lines = pushedLines ?? _headerTitleLines(context, _draftOperation ?? operation);
                    return Stack(
                      children: [
                        // Fades out on the same curve as the real one it stood
                        // in for — the accept button (headerLeading) is the
                        // sheet's dismiss control once it's up, so this doesn't
                        // need to keep offering a second one once that button
                        // has taken over.
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _leadingWidthFor(isTwoPane, context),
                          child: IgnorePointer(
                            ignoring: _headerIconsInert,
                            child: Opacity(
                              opacity: _headerIconsFadeOpacity,
                              // macOSAwareBackButton, not a bare IconButton:
                              // it's the one place that already knows to clear
                              // the traffic lights on a chromeless macOS window.
                              child: Center(
                                child: macOSAwareBackButton(
                                  context,
                                  close: true,
                                  boxSize: 40,
                                  onPressed: () async {
                                    await sheetKey.currentState?.saveAndClose();
                                    if (context.mounted) unawaited(Navigator.of(context).maybePop());
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The trailing row, live, standing exactly over the
                        // inert one in the AppBar — same builder, same children,
                        // so it lines up without measuring anything. This is the
                        // copy that makes Exports/Imports/Tools pressable at
                        // all while the sheet is up; the layout controls come
                        // along disabled, both to match what is underneath and
                        // because they occupy width the actions must clear.
                        //
                        // Opaque is not the same as live: at progress 0 the REAL
                        // row underneath is the one taking taps (see
                        // [_headerIconsInert]), so without the IgnorePointer
                        // this copy would swallow the tap meant for it.
                        Positioned(
                          right: windowsCaptionClearance(context),
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            ignoring: growth <= 0,
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _headerTrailingControls(
                                  context,
                                  isTwoPane: isTwoPane,
                                  // The sheet cannot coexist with layout
                                  // editing: the title control that opens it is
                                  // inert while editing, and the layout button
                                  // that would start editing is inert while the
                                  // sheet is up. False is the only value this
                                  // call site can see.
                                  editingHeader: false,
                                  lines: lines,
                                  // Width only — the AppBar's row underneath is
                                  // the one that paints them.
                                  layoutControlsOpacity: 0.0,
                                  onOptions: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) {
                                      unawaited(
                                        _showOperationOptions(
                                          op,
                                          includeExport: !isTwoPane,
                                          includeImport: !isTwoPane,
                                          includeEditLayout: !isTwoPane && !layoutEditing,
                                        ),
                                      );
                                    }
                                  },
                                  onExport: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) unawaited(_export(op));
                                  },
                                  onImport: () async {
                                    final op = _draftOperation ?? operation;
                                    await sheetKey.currentState?.saveAndClose();
                                    if (mounted) unawaited(_import(op));
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(right: 0, top: 0, bottom: 0, child: Center(child: windowsCaptionSpacer(context))),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
        builder: (_) => OperationSheet(
          key: sheetKey,
          services: widget.services,
          operation: operation,
          onClosingChanged: (closing) => sheetClosing.value = closing,
          onOperationChanged: (updated) {
            if (!mounted) return;
            final previous = _draftOperation;
            setState(() => _draftOperation = updated);
            // Refs are the only input the title (and the logging row's
            // activity fields) are built from, so nothing else in the draft
            // is worth a hook fan-out.
            //
            // The build method reads `_draftOperation ?? _operation`, so the
            // LoggingPanel below sees a ref the operator just added
            // immediately — but its `activityControls` (the descriptor that
            // actually makes the field render) only ever refreshes off the
            // COMMITTED operation, via `_onOperationChanged`'s own ref-diff.
            // A draft edit never reaches the database until the sheet
            // closes, so without this call that hook never fires for it: the
            // ref shows on the operation but the field it should turn on
            // stays missing until something else (any unrelated cause of
            // `_onOperationChanged` firing, or a per-QSO refresh landing
            // once a callsign is typed) happens to catch it up.
            if (previous == null || !sameRefs(previous.data['refs'], updated.data['refs'])) {
              unawaited(_retitleDraft(updated));
              unawaited(_runtime.refreshControls(updated));
            }
          },
          onEditDetails: () async {
            final updated = await editOperationDetails(context, widget.services, _draftOperation ?? operation, save: false);
            if (updated != null && mounted) {
              setState(() {
                _draftOperation = Operation(
                  uuid: _draftOperation!.uuid,
                  data: {..._draftOperation!.data, ...updated.data},
                  qsoCount: _draftOperation!.qsoCount,
                  startAtMillisMin: _draftOperation!.startAtMillisMin,
                  startAtMillisMax: _draftOperation!.startAtMillisMax,
                  // The dialog persists local data itself, so the draft takes
                  // what came back rather than keeping its own stale copy.
                  localData: updated.localData,
                );
              });
              sheetKey.currentState?.updateOperation(_draftOperation!);
            }
          },
        ),
      );
    } finally {
      // _sheetAnimation/_sheetAnimationListener are NOT reset here — this
      // `finally` runs as soon as Navigator.push() resolves, which is at
      // pop() time, well before the route's reverse transition actually
      // finishes. The status listener attached in onAnimation above cleans
      // both up itself once the animation truly reaches
      // AnimationStatus.dismissed (with a defensive re-detach at the top of
      // the next onAnimation call, in case a sheet reopens before that
      // fires).
      // True from the moment a save starts, back to false only if it fails. A
      // close without one — a failed save left by Escape, a navigation past
      // the sheet — keeps nothing of the draft.
      final saved = sheetClosing.value;
      final draft = _draftOperation;
      final fragments = _draftTitleFragments;
      if (mounted) {
        setState(() {
          _activeSheetKey = null;
          // Back to the live fallback, so the next open's first frame reads
          // the title that is on screen rather than the one this session
          // left behind (see [_sheetHeaderLines]).
          _sheetHeaderLines.value = null;
          // A close that saved — or is still saving — carries the draft's
          // final values into _operation BEFORE dropping the draft, rather
          // than leaving the header to fall back on _operation as it stood
          // before this edit session and wait for watchOperation's stream to
          // catch up. That gap
          // would show a flicker of stale values in the header for a
          // frame or two while the sheet was still closing. If a live
          // title-preview was showing (refs edited during this session),
          // bake ITS suggestion into the carried-forward operation too —
          // otherwise the draft's own titleSuggestion cache is still the
          // PRE-edit one (only the ephemeral preview knew about the new
          // refs), so dropping _draftTitleFragments in the same breath
          // would swap the correct preview for that stale cached title.
          // The fragments also live on as _pendingTitleFragments (NOT
          // cleared here) — saveAndClose() persisted the sheet's own,
          // still stale-titleSuggestion operation, so watchOperation's very
          // next emission would read that stale cache straight back over
          // this fix; _onOperationChanged keeps re-patching it in until the
          // row's real cache (retitleOperation's separate async write)
          // actually catches up.
          if (saved && draft != null) {
            _operation = fragments == null ? draft : _withTitleSuggestion(draft, fragments);
            _pendingTitleFragments = fragments ?? _pendingTitleFragments;
          }
          _draftOperation = null;
          _draftTitleFragments = null;
          _draftTitleGeneration++;
        });
        // Every refs edit in the draft re-derived the logging row's and the
        // map's controls from it (see onOperationChanged above). A close that
        // kept nothing wrote nothing, so no stream emission will put them
        // back: without this, the row keeps the fields of refs the operation
        // does not have.
        final stored = _operation;
        if (!saved && draft != null && stored != null && !sameRefs(draft.data['refs'], stored.data['refs'])) {
          unawaited(_runtime.refreshControls(stored));
        }
      }
      // Defensive fallback: the header's own leading/Tools/Export/layout
      // icons stay faded and non-interactive for as long as _sheetAnimation
      // is non-null (see _headerIconsFadeOpacity/_headerIconsInert), and the
      // ONLY path that clears it is onAnimation's statusListener reaching
      // AnimationStatus.dismissed above. If the route is torn down some
      // other way that skips that status (a forcibly reset Navigator, a
      // disposed AnimationController mid-transition), nothing else would
      // ever un-stick those controls. TopModalPaneRoute's own
      // transitionDuration is 600ms; comfortably past that, if this is
      // still the SAME animation onAnimation captured (a newer sheet
      // reopening would have replaced it already), force it null rather
      // than trust a status change that evidently isn't coming.
      final anim = sheetAnim;
      if (anim != null) {
        unawaited(
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && identical(_sheetAnimation, anim)) {
              debugPrint('[operation] sheet-animation-stuck: dismissed status never fired within the fallback window');
              setState(() => _sheetAnimation = null);
            }
          }),
        );
      }
    }
  }

  /// Bakes [fragments] into [operation]'s own `localData['titleSuggestion']`
  /// — the same shape `OperationTitleService` persists, and the one
  /// `displayTitleFor`/`operation.titleFragments` actually reads. Used both
  /// by the live preview in [build] and, on close, to carry that preview's
  /// result into `_operation` in the same breath the draft is dropped — see
  /// the `finally` block in [_openOperationSheet] for why the LATTER matters:
  /// without it, the header falls back to whatever stale titleSuggestion is
  /// still cached on the saved row until retitleOperation's own async
  /// refresh catches up, flickering back to the pre-edit title in between.
  Operation _withTitleSuggestion(Operation operation, OperationTitleFragments fragments) => Operation(
    uuid: operation.uuid,
    data: operation.data,
    qsoCount: operation.qsoCount,
    startAtMillisMin: operation.startAtMillisMin,
    startAtMillisMax: operation.startAtMillisMax,
    localData: {
      ...operation.localData,
      'titleSuggestion': fragments.isEmpty
          ? null
          : {'title': fragments.title, 'for': fragments.forText, 'at': fragments.atText, 'subtitle': fragments.subtitle},
    },
  );
}

/// The operation sheet's accept button, shown in the VIEW's own header (left
/// of the title) via `headerLeading` while the sheet is open — it has no
/// header band of its own to carry this (see `_openOperationSheet`'s
/// `showHeader: false`). `headerLeading` draws above the pane's own dismiss
/// layer, which is what makes this reachable at all: the same button placed
/// directly in the view's AppBar sits BELOW that layer and never receives a
/// tap (see `headerLeading`'s own doc in modal_pane.dart).
///
/// Once the sheet starts closing ([closing]), it shows a spinner and takes no
/// more presses while the save waits on the extension host, rather than
/// looking dead. The disabled colours are the enabled ones: a greyed-out OK
/// reads as "can't", not "working on it".
Widget _sheetOkButton(BuildContext context, GlobalKey<OperationSheetState> sheetKey, ValueListenable<bool> closing) {
  final onPrimary = Theme.of(context).colorScheme.onPrimary;
  return ValueListenableBuilder<bool>(
    valueListenable: closing,
    builder: (context, isClosing, _) => FilledButton.icon(
      icon: isClosing ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimary)) : const Icon(MdiIcons.check),
      label: Text(context.t.common.ok),
      style: FilledButton.styleFrom(
        backgroundColor: fabAccentColor,
        foregroundColor: onPrimary,
        disabledBackgroundColor: fabAccentColor,
        disabledForegroundColor: onPrimary,
      ),
      onPressed: isClosing ? null : () => sheetKey.currentState?.saveAndClose(),
    ),
  );
}
