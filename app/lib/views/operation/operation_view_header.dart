// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation view's header: the title control and its hand-off to the
// setup sheet, the operation's Exports/Imports/Tools, and the Tools menu.

part of '../operation_view.dart';

mixin _OperationHeader on State<OperationView>, DockHost<OperationView> {
  // Owned by `_OperationSheetHost`.
  Animation<double>? get _sheetAnimation;
  Operation? get _draftOperation;
  GlobalKey<OperationSheetState>? get _activeSheetKey;
  Future<void> _editActivities(Operation operation);

  /// The AppBar's own `leadingWidth` — factored out so the sheet's
  /// headerTrailing can size its own (X) copy identically (see
  /// _openOperationSheet): a copy centered in a differently-sized box would
  /// land at a different x than the real one it's standing in for, and the
  /// two would visibly double up rather than the live one simply replacing
  /// the inert one underneath. Explicit 56.0 rather than null for wide's
  /// non-macOS case — AppBar's own default — so both callers agree on an
  /// actual number instead of one of them silently trusting a framework
  /// default the other can't see.
  double _leadingWidthFor(bool isTwoPane, BuildContext context) =>
      isTwoPane ? (macOSAwareLeadingWidth(context) ?? 56.0) : (isMacOSChromelessWindow ? 40 + macOSTrafficLightClearance(context) : 40);

  /// The header's dots-and-title control — measured (not computed from
  /// theme constants) to left-align the operation sheet with it, since
  /// AppBar's actual leading width when `leadingWidth` is null varies by
  /// platform in ways not worth re-deriving here.
  final _headerTitleKey = GlobalKey();

  /// The control's left edge WITHIN this view, or null before its first layout
  /// (falls back to [showTopModalPane]'s default centering).
  ///
  /// Measured against the view rather than the window: this route slides in
  /// from the left, and the sheet opens while it is still travelling — a
  /// window-relative reading taken then is off-screen and puts the sheet
  /// wherever the animation happened to be. At rest the view's origin IS the
  /// window's, so the two agree once it lands.
  double? get _headerTitleLeftInset {
    final box = _headerTitleKey.currentContext?.findRenderObject() as RenderBox?;
    final view = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || view == null || !view.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: view).dx;
  }

  /// The sheet's accept button (headerLeading — see _openOperationSheet)
  /// draws OVER this same corner of the header, not inside its layout, so
  /// nothing here naturally makes room for it — measured so the title Row
  /// can animate its own leading gap open to match, in step with the sheet's
  /// own slide. Null before the button has ever laid out (before the first
  /// open, or between opens): [_leadingGapWidth] falls back to the dots
  /// control's own fixed width then, which is exactly correct at progress 0.
  final _sheetOkButtonKey = GlobalKey();

  double? get _sheetOkButtonWidth {
    // The `.mounted` check alone isn't reliable insurance here — this key's
    // element lives inside the pane's own route, not this state's build, and
    // a resize crossing the narrow/wide boundary can reparent that whole
    // subtree (the route re-presenting itself in place) between the check
    // and the call in ways a `mounted` read a moment earlier can't see
    // coming. `findRenderObject()` throws FlutterError on an inactive
    // element — but only in debug: the check lives inside an `assert`, which
    // release/profile builds strip, so there it just returns the (possibly
    // detached) renderObject instead of throwing. `!box.attached` below is
    // what actually catches that case; the catch only helps in debug.
    final element = _sheetOkButtonKey.currentContext;
    if (element == null || !element.mounted) return null;
    try {
      final box = element.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return null;
      return box.size.width;
    } on FlutterError {
      debugPrint('[operation] sheet-ok-button-race: cross-route RenderBox read hit an inactive element');
      return null;
    }
  }

  /// The title Row's leading gap, animating from the dots control's own
  /// width to the accept button's — see [_sheetOkButtonWidth]'s doc on why
  /// something has to. Reuses [_sheetAnimation]'s value, not a separate
  /// AnimationController: the two need to move together exactly, and a
  /// second controller can drift out of sync with the route's own reverse
  /// transition (variable duration/curve) for no benefit.
  ///
  /// Reaches the target width on the same `progress / sheetHandoffThreshold`
  /// curve the accept button's own grow-in uses (see headerLeading in
  /// _openOperationSheet), not raw progress — the button finishes growing at
  /// that threshold and holds there while the sheet keeps sliding to 1.0, so
  /// a gap that kept widening past that point would still be making room for
  /// a button that had already stopped growing, and one still catching up on
  /// the way in (or shrinking early on the way out) reads as the button
  /// overlapping the title.
  /// Where the sheet's accept button sits on a narrow layout — the header's
  /// own leading corner, less whatever the native window controls need (see
  /// `narrowLeftInset` in [_openOperationSheet]). Shared with
  /// [_leadingGapWidth], which has to know how far LEFT of this control that
  /// button starts.
  double _narrowSheetLeftInset(BuildContext context) => isMacOSChromelessWindow ? macOSTrafficLightClearance(context) : 0;

  double _leadingGapWidth(BuildContext context, {required bool isTwoPane}) {
    const dotsWidth = _headerDotsWidth;
    final progress = _sheetAnimation?.value ?? 0.0;
    if (progress == 0.0) return dotsWidth;
    var targetWidth = _sheetOkButtonWidth ?? dotsWidth;
    if (!isTwoPane) {
      // Narrow starts that button at the header's leading corner, which is
      // the width of the (faded) chevron's own slot to the LEFT of where
      // this control begins — so only the part of it that overhangs into
      // this control needs room made here. Reserving its full width instead
      // would leave exactly that slot's width of dead space between the
      // button and the title. Wide has no overhang: the button starts at
      // this control's own left edge.
      final overhang = targetWidth - (_leadingWidthFor(false, context) - _narrowSheetLeftInset(context));
      targetWidth = math.max(dotsWidth, overhang);
    }
    return sheetLeadingGapWidth(progress, targetWidth);
  }

  /// Shared fade for the AppBar's own leading/Options/Export/layout icons
  /// while the sheet is up — same curve and threshold the falling dots use
  /// ([SheetHeaderDots]), so the whole header's hand-off to the sheet's
  /// live copies reads as one motion instead of several independently-timed
  /// ones.
  double get _headerIconsFadeOpacity {
    final progress = _sheetAnimation?.value ?? 0.0;
    return (1.0 - progress / sheetHandoffThreshold).clamp(0.0, 1.0);
  }

  /// Whether the AppBar's own leading/Options/Export/layout icons should
  /// ignore taps — true for the whole time the sheet is up or animating, not
  /// just once fully faded. The Exports/Tools copy sits exactly over the
  /// group it stands in for and is opaque from the first frame, so the real
  /// one is reachable underneath for as long as anything but this stops it —
  /// and a tap it took would act on the operation behind a sheet that is
  /// buffering edits to it.
  bool get _headerIconsInert => (_sheetAnimation?.value ?? 0.0) > 0.0;

  /// The VIEW's layout controls dim to Material's disabled opacity while the
  /// operation's setup sheet is up, on the same curve everything else in the
  /// header uses.
  ///
  /// Only those. The operation's own Exports/Imports/Tools stay at full
  /// strength and stay pressable (see [_headerTrailingControls]) — what the
  /// sheet edits is the operation, and reaching for its exports mid-edit is
  /// a reasonable thing to do. Rearranging the view is not, so those go
  /// disabled rather than away: they do NOT fade out like the chevron,
  /// because nothing replaces them. [_headerIconsInert] is what actually
  /// stops the taps; this is only how that reads.
  double get _layoutControlsDisabledOpacity {
    final progress = _sheetAnimation?.value ?? 0.0;
    final growth = (progress / sheetHandoffThreshold).clamp(0.0, 1.0);
    return 1.0 - (1.0 - 0.38) * growth;
  }

  Future<void> _export(Operation operation) => showOperationExportPanel(context, services: widget.services, operation: operation);

  Future<void> _import(Operation operation) async {
    if (operation.deleted) return;
    await showOperationImportPanel(context, services: widget.services, operation: operation);
  }

  /// Counted only once it has happened: a refusal throws past the `then`,
  /// and an operation something else already restored reports false.
  void _undelete(Operation operation) {
    unawaited(
      widget.services.undeleteOperation(operation.uuid).then((restored) {
        if (restored) widget.services.track('operation_undeleted');
      }),
    );
  }

  /// The header's trailing controls: the operation's own Exports/Imports/
  /// Tools, and the view's layout controls beside them where the dock layout
  /// is live.
  ///
  /// ONE builder for both the AppBar's own row and the copy the setup sheet
  /// draws above its barrier, so the copy stands exactly over what it
  /// replaces by construction — same children, same order, same widths — with
  /// nothing measured and so nothing to go stale. Copying only the actions
  /// and pinning them to the trailing edge would land them over the layout
  /// controls wherever those are present.
  ///
  /// The copy exists because the real row cannot be pressed while a modal
  /// route is up (see [TopModalPaneRoute.headerTrailing]), and the
  /// operation's actions should still work. The layout controls should not,
  /// so they carry their own inert treatment here, in the shared builder,
  /// rather than at either call site.
  ///
  /// [layoutControlsOpacity] is which of the two rows actually PAINTS those
  /// controls. Both must hold them — they are width the actions have to
  /// clear, and dropping them from one row would misalign it — but the rows
  /// sit exactly on top of each other over an undimmed header, so painting
  /// both at Material's disabled 0.38 composites to about 0.62 and reads as
  /// merely faint. The copy passes 0 and keeps only the space.
  List<Widget> _headerTrailingControls(
    BuildContext context, {
    required bool isTwoPane,
    required bool editingHeader,
    required ({String title, String subtitle}) lines,
    required double layoutControlsOpacity,
    required VoidCallback onOptions,
    required VoidCallback onExport,
    required VoidCallback onImport,
  }) => [
    // Operation-level actions, not scoped to the setup sheet: an operator
    // reaches for Options/Export without necessarily opening it. Gone
    // during layout editing along with the rest of the operation's own
    // identity in this header — nothing about the operation is what's
    // being arranged then. Narrow keeps only the gear — there isn't room
    // for a second icon beside the title — with Export Logs folded into
    // its menu instead of dropped.
    if (!editingHeader)
      _operationHeaderActions(
        context,
        isTwoPane: isTwoPane,
        headerTitle: lines.title,
        headerSubtitle: lines.subtitle,
        onOptions: onOptions,
        onExport: onExport,
        onImport: onImport,
      ),
    // Narrow gives the way IN to the Tools menu (see
    // [_showOperationOptions]) — the header there has room for the title
    // and one button, and the operation's own title has the better claim.
    // Once editing, the controls come back here at every width: a menu is
    // not somewhere to hide the only way out of a mode.
    if (isTwoPane || layoutEditing) ...[
      // The LAYOUT sheet draws its own copy of these while IT is up; two
      // would be one too many, and the one down here would be the
      // unreachable one.
      if (!layoutSheetOpen) ...[
        // Separates it from Exports/Tools rather than the two groups
        // sitting flush — they act on different things (the operation vs.
        // the view's own arrangement), and nothing about a labeled
        // TextButton.icon's own padding guarantees a gap here the way a
        // plain IconButton's did.
        if (!editingHeader) const SizedBox(width: Space.md),
        IgnorePointer(
          ignoring: _headerIconsInert,
          child: Opacity(
            opacity: layoutControlsOpacity,
            child: Row(mainAxisSize: MainAxisSize.min, children: layoutHeaderControls(context)),
          ),
        ),
      ],
    ],
  ];

  /// The header's two title lines as the sheet's copy of the trailing
  /// controls last saw them (headerTrailing in [_openOperationSheet]).
  ///
  /// That copy lives in the sheet's route rather than in this build, and its
  /// own AnimatedBuilder stops ticking once the sheet is open and still — so
  /// adding or removing an activity, which retitles the operation under it,
  /// reaches it through nothing else. Without this it keeps the label fit it
  /// was built with (see [_headerActionsFitLabels]) while the title it was
  /// measured against changes width, and the copy and the row underneath it
  /// disagree about their own size.
  ///
  /// Pushed from a post-frame callback rather than mid-build, where
  /// notifying a listener would rebuild the route's subtree during this
  /// one's build.
  final _sheetHeaderLines = ValueNotifier<({String title, String subtitle})?>(null);

  /// The two lines the header's title control shows for [operation]. One
  /// derivation, read both by the control itself and by
  /// [_headerActionsFitLabels] — a second copy of this would let the labels
  /// be weighed against a title other than the one on screen.
  ///
  /// The ref-derived subtitle only exists once OperationTitleService has run
  /// at least once; until then it falls back to the raw ref labels so the
  /// header isn't blank.
  ({String title, String subtitle}) _headerTitleLines(BuildContext context, Operation operation) {
    final suggested = displaySubtitleFor(operation);
    return (
      title: '${headerCallsignFor(operation)} ${displayTitleFor(context, operation)}',
      subtitle: suggested.isNotEmpty ? suggested : operation.refs.map((r) => r['shortLabel'] ?? r['ref']).whereType<String>().join(' • '),
    );
  }

  /// The falling-dots control's own footprint in the title row — the width
  /// the leading gap rests at while the sheet is closed.
  static const double _headerDotsWidth = sheetHeaderDotsWidth;

  /// A labeled header button's own chrome beyond the 48 logical pixels an
  /// icon-only IconButton spends on the same icon — TextButton.icon's
  /// start/end padding and the gap it sets between icon and label.
  /// Approximate on purpose: it decides only WHERE the labels drop out, and
  /// being a few pixels off moves that point rather than breaking anything.
  static const double _headerLabelChrome = 12.0;

  /// The same measure for the sheet's accept button, which is a
  /// FilledButton.icon rather than a TextButton.icon and carries the heavier
  /// M3 padding of one. Separate from [_headerLabelChrome] because reusing
  /// that one under-counts this button by enough to keep labels at widths
  /// that cannot hold them — the exact failure the fit exists to prevent.
  static const double _acceptButtonChrome = 28.0;

  /// The title control's own insets: the padding either side of the text
  /// plus the dots slot and the gap after it (see the AppBar's `title`
  /// below). Derived rather than typed, so a change to [Space] or to the
  /// dots cannot silently drift the point at which labels drop out. Narrow
  /// drops the left inset, as the title control itself does.
  double _headerTitleChrome(bool isTwoPane) => (isTwoPane ? Space.xs : 0) + _headerDotsWidth + Space.xs + Space.lg;

  /// Whether the header's Exports/Imports/Tools group can afford to carry
  /// its labels.
  ///
  /// The group and the operation's own title share one header, so what the
  /// labels add over the icon-only group comes out of whatever the title
  /// does not need. Measured rather than pinned to a shirt size: the title
  /// runs as long as the operator's callsign, title and refs happen to make
  /// it, and the labels as long as the locale's words, so no fixed width is
  /// the right answer for both — an S window with a short title has room a
  /// wide one with a long title does not.
  ///
  /// The title's NATURAL width is what it is weighed at. It can survive on
  /// less (shrinkToFitText takes it to 75% before ellipsizing), but that
  /// headroom is there for a title too long for the header at any label
  /// setting — spending it to buy labels would shrink the operation's own
  /// name to pay for a word that repeats an icon.
  bool _headerActionsFitLabels(BuildContext context, {required bool isTwoPane, required String title, required String subtitle}) {
    final theme = Theme.of(context);
    final t = context.t.activitiesView;
    final titleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? const TextStyle();
    final subtitleStyle = theme.textTheme.labelMedium ?? const TextStyle();
    final labelStyle = theme.textTheme.labelLarge ?? const TextStyle();

    // What the header gives up to the setup sheet's accept button while the
    // sheet is up ([_leadingGapWidth] widens the title's leading gap to it),
    // costed the same way a labeled button above is. Reserved even while the
    // sheet is closed, and derived rather than read off the live button, so
    // this answers the same either way: a decision that swung on the sheet
    // would drop the labels partway through the opening animation and put
    // them back partway through the close, and [_sheetOkButtonWidth] reads
    // null between opens besides.
    final acceptButtonReserve = kMinInteractiveDimension + _acceptButtonChrome + textWidth(context, context.t.common.ok, labelStyle);

    final labels = isTwoPane ? [t.exports, t.imports, t.tools] : [t.tools];
    final labelsCost = labels.fold<double>(0.0, (sum, label) => sum + _headerLabelChrome + textWidth(context, label, labelStyle));

    final titleWanted = math.max(textWidth(context, title, titleStyle), subtitle.isEmpty ? 0.0 : textWidth(context, subtitle, subtitleStyle));

    // The view's layout controls sit in this same row (see
    // [_headerTrailingControls]) and take width the labels cannot also
    // spend. One button: the three-button editing form only appears while
    // layoutEditing, and that is exactly when these actions are not built at
    // all (`editingHeader`), so it can never coincide with this measurement.
    //
    // Untested, deliberately. [acceptButtonReserve] is charged even with the
    // sheet closed and over-reserves by more than this term is worth, so
    // omitting it only misjudges a band of title widths roughly this button
    // wide, and only while the sheet is open. A test tuned to that band
    // would be measuring the placeholder font's glyph advance more than the
    // arithmetic, and would break on any padding change. It is here because
    // the budget must describe the row it is measuring.
    final layoutControlsWidth = !layoutSheetOpen && (isTwoPane || layoutEditing) ? Space.md + kMinInteractiveDimension : 0.0;

    final slack =
        MediaQuery.sizeOf(context).width -
        _leadingWidthFor(isTwoPane, context) -
        acceptButtonReserve -
        windowsCaptionClearance(context) -
        labels.length * kMinInteractiveDimension -
        layoutControlsWidth -
        _headerTitleChrome(isTwoPane) -
        titleWanted;
    return slack >= labelsCost;
  }

  /// (wide only) Export + Tools — shared between the AppBar's own actions and
  /// their live copy in headerTrailing (see _openOperationSheet): same icons,
  /// only the press handlers differ (immediate here, close-the-sheet-first
  /// there). Export leads and Tools trails: Export is
  /// the more frequent reach of the two, and Tools — being the one that's
  /// always there, narrow included — anchors the group's trailing edge
  /// instead of shifting position as Export appears and disappears across
  /// the width breakpoint.
  ///
  /// Which of the three show at all is L's breakpoint: Exports and Imports
  /// are dropped on S, where their only way in is Tools' own menu (see
  /// [_showOperationOptions]'s `includeExport`/`includeImport`).
  ///
  /// Whether they carry LABELS is not a breakpoint at all — see
  /// [_headerActionsFitLabels], which weighs them against the title they
  /// take the room from.
  Widget _operationHeaderActions(
    BuildContext context, {
    required bool isTwoPane,
    required String headerTitle,
    required String headerSubtitle,
    required VoidCallback onOptions,
    required VoidCallback onExport,
    required VoidCallback onImport,
  }) {
    final t = context.t.activitiesView;
    final labeled = _headerActionsFitLabels(context, isTwoPane: isTwoPane, title: headerTitle, subtitle: headerSubtitle);
    final onHeader = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
    Widget headerButton({required IconData icon, required String label, required VoidCallback onPressed}) => labeled
        ? TextButton.icon(
            icon: Icon(icon),
            label: Text(label),
            style: TextButton.styleFrom(foregroundColor: onHeader),
            onPressed: onPressed,
          )
        : IconButton(
            icon: Icon(icon, semanticLabel: label),
            onPressed: onPressed,
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isTwoPane) headerButton(icon: MdiIcons.export, label: t.exports, onPressed: onExport),
        if (isTwoPane) headerButton(icon: MdiIcons.import, label: t.imports, onPressed: onImport),
        headerButton(icon: MdiIcons.tools, label: t.tools, onPressed: onOptions),
      ],
    );
  }

  /// The operation-level actions that don't belong in the activities list
  /// itself. Share and Archive are declared but inert — the rows are here so
  /// the menu's shape is settled, and they stay disabled until each has an
  /// implementation behind it. Standalone rather than routed through the
  /// setup sheet: reached both from the AppBar's own Options button (sheet
  /// closed) and from its live copy in headerTrailing (sheet open — see
  /// _openOperationSheet), which closes the sheet first and calls this with
  /// its already-saved draft, so [operation] is always current by the time
  /// this actually shows. Editing details here saves directly either way
  /// (editOperationDetails' own `save: true` default), not through a draft.
  ///
  /// [includeExport] and [includeImport] add Export Logs and Imports as the
  /// top two rows, in that order — the header's own group reads
  /// Exports/Imports left to right, and a menu standing in for it keeps that
  /// order rather than inventing a second one. Narrow layouts drop those
  /// icons from the header for lack of room beside the title, so this menu
  /// is their only way in there; wide layouts keep the icons and leave them
  /// out here rather than offer the same action twice.
  ///
  /// [includeEditLayout] adds Edit Layout after them, on the same terms and
  /// for the same reason: a narrow header has room for the title and one
  /// button, and the operation's own title has the better claim on it. The
  /// controls the edit ITSELF needs — the plus, Discard, Save — stay in the
  /// header at every width, because a menu is not somewhere an operator can
  /// be expected to find the way out of a mode.
  Future<void> _showOperationOptions(Operation operation, {bool includeExport = false, bool includeImport = false, bool includeEditLayout = false}) async {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.toolsTitle),
        // The rows ARE the dialog's content, so they take the shell's list
        // padding: to the card's edges, with their contents inset off the
        // same SettingsList every other list in the app reads.
        list: true,
        // The body scrolls itself, because the Paired Devices band at the
        // end of it pins — which needs a sliver viewport, and the shell's
        // plain scroll view is not one.
        scrollable: false,
        content: SectionedListView(
          shrinkWrap: true,
          children: [
            if (includeExport)
              ListTile(
                leading: const Icon(MdiIcons.export),
                title: Text(t.exportLogs),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_export(operation));
                },
              ),
            if (includeImport && !operation.deleted)
              ListTile(
                leading: const Icon(MdiIcons.import),
                title: Text(t.imports),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_import(operation));
                },
              ),
            if (includeEditLayout)
              ListTile(
                leading: const Icon(MdiIcons.viewDashboard),
                title: Text(context.t.operation.layout.editLayout),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  startLayoutEditing();
                },
              ),
            // The header's layout switcher, for a header with no room for it.
            if (includeEditLayout && namedLayoutsOffered)
              ListTile(
                leading: const Icon(MdiIcons.viewDashboardVariantOutline),
                title: Text(context.t.operation.layout.layouts.menuTitle),
                subtitle: Text(layoutName(viewLayouts.activeLayout)),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(showLayoutsSheet(context, this));
                },
              ),
            if (!operation.deleted)
              ListTile(
                leading: const Icon(MdiIcons.noteEditOutline),
                title: Text(t.operationDetails),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(editOperationDetails(context, widget.services, operation));
                },
              ),
            ListTile(enabled: false, leading: const Icon(MdiIcons.shareVariant), title: Text(t.share)),
            ListTile(enabled: false, leading: Icon(MdiIcons.archiveOutline), title: Text(t.archive)),
            if (operation.deleted)
              ListTile(
                leading: Icon(MdiIcons.deleteRestore, color: theme.colorScheme.error),
                title: Text(t.undeleteOperation, style: TextStyle(color: theme.colorScheme.error)),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _undelete(operation);
                },
              )
            else
              ListTile(
                leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
                title: Text(t.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
                // The menu closes with the confirmation: deleting is about the
                // operation as a whole, and its confirmation belongs to the
                // screen underneath, not to a menu that is going away.
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    confirmDeleteOperation(context, widget.services, operation).then((deleted) {
                      if (!deleted || !mounted) return;
                      Navigator.of(context).pop();
                    }),
                  );
                },
              ),
            // Past the destructive row on purpose: it is a readout, not an
            // action, so it must not sit between two things the operator
            // taps.
            //
            // Both gate terms, not just the experiment: with peer sync off
            // every row would read "Not connected", and unlike the Settings
            // panel this dialog carries no switch to say that is the reason.
            if (widget.services.settings.peerSyncEnabled && widget.services.settings.experimentEnabled('p2p') /* stored key, see experiments.yaml */ ) ...[
              SectionHeader(dialogContext.t.settings.peers.pairedDevices),
              LinkedDevicesList(services: widget.services),
            ],
          ],
        ),
        // Every row here closes the menu itself, so this is a way out rather
        // than a confirm — and a dialog without a footer band ends on nothing,
        // which is what sets one apart from the rest.
        cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(context.t.common.done)),
      ),
    );
  }

  /// The view's AppBar: the back control, the dots-and-title control that
  /// opens the setup sheet, and the trailing controls. [editingHeader] is
  /// edit mode as the header sees it — see where [build] computes it.
  PreferredSizeWidget _headerAppBar(
    BuildContext context, {
    required Operation operation,
    required bool isTwoPane,
    required bool editingHeader,
    required ({String title, String subtitle}) headerLines,
  }) {
    final refsLine = headerLines.subtitle;
    return AppBar(
      flexibleSpace: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Inert while editing, for the same reason the title above it
        // is: the operation's own setup is not what is being
        // arranged. Gating one and not the other leaves the empty
        // header between them opening the very sheet the other
        // refuses.
        onTap: editingHeader ? null : () => _editActivities(operation),
        child: Stack(children: [if (windowHeaderGestureArea() != null) windowHeaderGestureArea()!]),
      ),
      leadingWidth: _leadingWidthFor(isTwoPane, context),
      // A chevron even though this view arrives over the whole window
      // (rail and mark included) with no trail to actually step back
      // along — the control closes it and nothing else. Boxed to
      // match the Options/Export/layout icons across the same header
      // (see macOSAwareBackButton's boxSize doc) rather than filling
      // the leading slot's own larger default.
      //
      // Fades out with the rest of the header's own icons while the
      // sheet is up — the falling dots and the accept button they
      // hand off to (headerLeading in _openOperationSheet) already
      // cover dismissal from that corner, so this one steps aside
      // rather than sitting duplicated beside them.
      leading: IgnorePointer(
        ignoring: _headerIconsInert,
        child: Opacity(opacity: _headerIconsFadeOpacity, child: macOSAwareBackButton(context, close: true, boxSize: 40)),
      ),
      // Tight against it — the dots-and-title control
      // supplies its own (small) inset instead of relying on the
      // theme's default gap here.
      titleSpacing: 0,
      // The logging-only settings menu travels with the logging
      // panel itself, not this AppBar (its dock tab or pane header —
      // see _buildLoggingSettingsButton), since none of its toggles
      // apply to the Info/Spots/Map tabs.
      //
      // The layout button, by contrast, is about the arrangement of
      // the whole view, so it belongs here — and only where there IS
      // an arrangement to edit: the dock layout, which is two-pane
      // and experiment-gated.
      actions: [
        // Inert as a whole while the sheet is up: its copy above the
        // barrier (headerTrailing in _openOperationSheet) is the one
        // taking taps then, drawn in this same spot from the same
        // builder. Nothing here moves, fades or duplicates visibly —
        // only the layout controls change, going dim and disabled
        // inside the shared builder.
        IgnorePointer(
          ignoring: _headerIconsInert,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _headerTrailingControls(
              context,
              isTwoPane: isTwoPane,
              editingHeader: editingHeader,
              lines: headerLines,
              layoutControlsOpacity: _layoutControlsDisabledOpacity,
              onOptions: () => unawaited(
                _showOperationOptions(
                  _draftOperation ?? operation,
                  includeExport: !isTwoPane,
                  includeImport: !isTwoPane,
                  includeEditLayout: !isTwoPane && !layoutEditing,
                ),
              ),
              onExport: () => unawaited(_export(_draftOperation ?? operation)),
              onImport: () => unawaited(_import(_draftOperation ?? operation)),
            ),
          ),
        ),
        windowsCaptionSpacer(context),
      ],
      title: InkWell(
        key: _headerTitleKey,
        // Inert while editing: the operation's own setup is not what
        // is being arranged, and the dots that hand off to its sheet
        // would be offering a second thing to do with a header that
        // has just become part of the layout editor.
        onTap: editingHeader
            ? null
            : () {
                final progress = _sheetAnimation?.value ?? 0.0;
                if (progress > 0.5) {
                  _activeSheetKey?.currentState?.saveAndClose();
                } else {
                  _editActivities(operation);
                }
              },
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(8),
        // Default M3 hover/pressed overlays are tuned for a surface-
        // colored widget and barely show up on this teal AppBar —
        // same bump as TabBar's own overlayColor (theme.dart).
        overlayColor: WidgetStateProperty.resolveWith((states) {
          final onPrimary = Theme.of(context).colorScheme.onPrimary;
          if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
            return onPrimary.withValues(alpha: 0.20);
          }
          if (states.contains(WidgetState.hovered)) {
            return onPrimary.withValues(alpha: 0.16);
          }
          return null;
        }),
        child: Padding(
          // Wide keeps a small left inset so the dots control
          // doesn't sit flush against the back button. Narrow sits
          // the title right against it instead — the leading slot is
          // already sized to the button alone there (see
          // leadingWidth above), so there's no residual gap left to
          // close on that side. Both keep a small right inset — the
          // title doesn't stretch to fill the AppBar — so the
          // control's own edge doesn't sit flush against whatever's
          // to its right (actions, or the window's own edge).
          padding: EdgeInsets.only(left: isTwoPane ? Space.xs : 0, right: Space.lg, top: Space.xxs, bottom: Space.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!editingHeader) ...[
                // Widens from the dots control's own footprint to
                // the accept button's as the sheet opens — that
                // button draws OVER this corner via headerLeading,
                // wider than the dots it covers, so without this the
                // title behind it would sit UNDER the button's tail
                // end instead of clear of it (see _leadingGapWidth).
                // The dots stay mounted and animating underneath
                // purely so they're not visibly stuck mid-fall for
                // the instant between the route unmounting at the
                // end of a close and their own progress catching up
                // to 0.
                SizedBox(
                  width: _leadingGapWidth(context, isTwoPane: isTwoPane),
                  height: 32,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SheetHeaderDots(progress: _sheetAnimation?.value ?? 0.0),
                  ),
                ),
                // Separates the title from whichever control
                // precedes it — the dots, or the accept button that
                // grows out of them. Constant, not animated with the
                // gap above: what that gap corrects for is the
                // button's own left overhang, not the breathing room
                // after it, which both states want the same.
                const SizedBox(width: Space.xs),
              ],
              // Flexible (loose), not Expanded (tight): Expanded
              // forces this Column — and so the InkWell's whole
              // tap/hover area above — to stretch to the AppBar's
              // full available width regardless of how little text
              // there is. Flexible still hands shrinkToFitText below
              // a bounded max width to shrink/ellipsize against (a
              // bare, non-flexible Row child gets an UNBOUNDED main-
              // axis constraint instead — Flutter only bounds a
              // Row's main axis for Expanded/Flexible children —
              // which would overflow), without forcing
              // the Column to consume space it doesn't need.
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and description each shrink to fit their own
                    // width independently rather than
                    // truncating — down to 75% of their natural font size,
                    // past which the line ellipsizes instead. The
                    // description tries Roboto's condensed glyph width
                    // first, before shrinking its font size at all.
                    // While editing, the header names the VIEW rather
                    // than the operation in it: what is being
                    // rearranged belongs to the view, and it outlives
                    // this operation and every other one.
                    shrinkToFitText(Text(editingHeader ? (viewOptions.title ?? context.t.operation.layout.viewName) : headerLines.title)),
                    if (!editingHeader && refsLine.isNotEmpty)
                      shrinkToFitText(
                        Text(
                          refsLine,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85)),
                        ),
                        condensed: true,
                      ),
                  ],
                ),
              ),
              ?viewOptionsButton(context, editing: editingHeader),
            ],
          ),
        ),
      ),
    );
  }
}
