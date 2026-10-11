// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

mixin _SpotsList on State<SpotsPanel> {
  SpotsService get _spots;
  bool get _loading;
  Map<String, SpotCallInfo> get _callNotes;
  List<Map<String, dynamic>> get _activityControls;
  SpotsFilterState get _filterState;
  Set<String> get _ourBaseCalls;
  ({bool worked, bool isSelf, Set<String> notices}) _flagsFor(Map<String, dynamic> spot);
  String? _noteEmojiOf(Map<String, dynamic> spot);
  ScrollController get _scrollController;
  GlobalKey get _currentRowKey;
  GlobalKey get _calibrationKey;
  LayoutMetrics get _metrics;
  SpotRevealState get _reveal;
  SpotWorkedOverrides get _workedOverrides;
  _SlideGroup get _slideGroup;

  /// Sections the already-filtered `filtered` spots per the current
  /// sort/group settings, then renders the scrollable list — split out of
  /// `build()` just for readability.
  ///
  /// `selfSpots` — our own station's spots, unfiltered (see
  /// [SpotsFilterState.summarize]) — pin above everything as their own section.
  /// `groupCallsWithNotes` prepends a "Calls of Note" section (spots whose
  /// callsign has a note, per `_callNotes`) ahead of everything else —
  /// those spots still also appear in their normal section below, same as
  /// app-polo's SpotsPanel.jsx (a pinned duplicate, not an exclusive move).
  /// `groupByBand` then decides band sections vs. one flat section; either
  /// way `filtered` is already sorted per `sortBy`, so that order is what
  /// shows within each band (or across the whole flat list).
  Widget _buildSpotsList(BuildContext context, List<Map<String, dynamic>> filtered, List<Map<String, dynamic>> selfSpots) {
    final t = context.t;
    final theme = Theme.of(context);

    final callsWithNotes = _filterState.groupCallsWithNotes
        ? {
            for (final entry in _callNotes.entries)
              if (entry.value.hasNote) entry.key,
          }
        : const <String>{};
    final rawSections = sectionSpots(filtered, selfSpots: selfSpots, callsWithNotes: callsWithNotes, groupByBand: _filterState.groupByBand);
    final sections = [
      for (final section in rawSections)
        (key: section.key, label: '${_sectionLabel(t, section.key)} - ${t.operation.spots.spotsCount(count: section.spots.length)}', spots: section.spots),
    ];
    // Same adaptive Hz-digit rule as qso_list.dart's DayHeaderRow/QSO rows —
    // computed across every currently-visible spot, not per-tile, so every
    // tile's Hz segment (if any) lines up at the same width. The pinned self
    // spots count too: they can sit outside `filtered`.
    final visibleSpots = [...selfSpots, ...filtered];
    final hzDigits = hzDigitsNeeded(visibleSpots.map(_freqOf));
    // The left column is only as wide as the widest frequency (and mode)
    // actually on screen — HF-only spots pack tighter than the fixed width
    // the widest microwave frequency would need. Shared across tiles so their
    // right-aligned frequencies still line up.
    final leftWidth = _spotLeftColumnWidth(context, visibleSpots, hzDigits);

    final currentCall = widget.callInfo?.call.toUpperCase();
    final highlight = widget.callInfo == null ? null : currentQsoHighlight(theme.colorScheme, editing: widget.callInfo!.isEditing);
    _reveal.locate([for (final section in sections) section.spots], currentCall, declaredHeightOf: _spotRowHeightOf);
    // The height every section header is FORCED into, and the same figure
    // [SpotRevealState.locate] counts a header as — a pinned sliver states its
    // extent before its child is laid out, so the two cannot be allowed to
    // disagree.
    final headerExtent = _reveal.sectionHeaderExtent;
    // Registered before the reveal's own callback so it runs first: a reveal
    // armed this frame is then measured against a scale learned from this
    // frame, rather than spending its one arm on the previous one's.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal.calibrate());
    _reveal.arm(currentCall);

    return RefreshIndicator(
      // Explicit, unlike every other spinner in the app: RefreshIndicator
      // resolves `color ?? colorScheme.primary` directly and never consults
      // ProgressIndicatorTheme, so it is the one progress affordance the
      // theme cannot reach.
      color: HaLoColors.of(context).onSurfaceAccent,
      onRefresh: _spots.refresh,
      // `sections`, not `filtered`: a pinned self spot must survive filters
      // that empty the rest of the board — that is when it is needed.
      child: sections.isEmpty
          // While the initial fetch is still in flight (see the progress bar
          // above), "no spots" would be misleading — none have loaded yet,
          // not necessarily none exist (matches activities_view_sections.dart's
          // own loading/empty-message split).
          ? (_loading
                ? const SizedBox.shrink()
                : ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Space.xxl),
                        child: Center(child: Text(t.operation.spots.empty, style: theme.textTheme.bodyMedium)),
                      ),
                    ],
                  ))
          // Scrolling deliberately leaves an open row open: the operator
          // peeking at one spot's action while scanning the rest of the board
          // is reading, not abandoning the peek, and a row that snapped shut
          // under the scroll took its suggestion out of the logging fields
          // with it.
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Each section's header is grouped with its OWN rows, not
                // listed as a sibling sliver: pinning is coordinated within a
                // group, so a short section's header is pushed off by the next
                // section's instead of both staying stuck at the top at once.
                for (final (sectionIndex, section) in sections.indexed)
                  SliverMainAxisGroup(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SpotsSectionHeaderDelegate(label: section.label, extent: headerExtent),
                      ),
                      SliverList.list(
                        children: [
                          for (final (index, spot) in section.spots.indexed)
                            if (_flagsFor(spot) case final flags)
                              if (_workedOverrides.isWorked(spot, scored: flags.worked) case final worked)
                                // The SAME predicate the pinned section is built from,
                                // so a row under "Your Spots" can never fall through to
                                // the suggest/log affordances — and vice versa.
                                if (spotIsSelfOnly(spot, ourBaseCalls: _ourBaseCalls) case final selfOnly)
                                  // The slide wraps the tile rather than living inside it,
                                  // and carries a key of its OWN that never changes. The
                                  // tile's key does change — it takes `_currentRowKey` on
                                  // becoming the current QSO, which is exactly what a
                                  // slide causes — and a widget whose key changes has its
                                  // subtree discarded. A gesture in there dies mid-drag.
                                  _SlidableSpotRow(
                                    // Keyed on the SECTION's key, not its label: the label
                                    // carries the section's spot count, so keying on it
                                    // would change every row's key on any poll that adds
                                    // or drops one spot — discarding the slide State of
                                    // every row in the section, which is the failure this
                                    // wrapper exists to prevent. The spot's own time
                                    // separates two rows for one call on one frequency,
                                    // which the merge passes allow when they are more
                                    // than 30 minutes apart.
                                    key: ValueKey('${section.key}|${_callOf(spot)}|${_freqOf(spot)}|${_timeOf(spot)}'),
                                    group: _slideGroup,
                                    background: theme.colorScheme.surface,
                                    // Our own station is not a contact to log — no
                                    // slide-to-log on a row that is ours alone, same
                                    // reasoning as the tap below.
                                    leading: widget.onLogQso == null || selfOnly
                                        ? null
                                        : _SlideAction(
                                            icon: MdiIcons.upload,
                                            label: t.operation.spots.slideLogIt,
                                            // The logging panel's own submit accent and
                                            // glyph: the gesture ends in the act that
                                            // button performs, so it may not look like a
                                            // different one.
                                            background: theme.colorScheme.tertiary,
                                            foreground: theme.colorScheme.onTertiary,
                                            // The peek is SPENT here, not withdrawn (see
                                            // [_SlidableSpotRowState._fire]), so nothing
                                            // fires `onWithdrawn` on this path and the
                                            // call has to be given up by hand — otherwise
                                            // it stays this panel's peek for the session,
                                            // and meeting the same station again on
                                            // another band would silently reveal nothing.
                                            onPressed: () {
                                              _reveal.peekedCall = null;
                                              _logSpot(spot);
                                            },
                                            // Opening fills the logging fields with this
                                            // spot, so what the commit is about to log is
                                            // on screen before it is logged.
                                            onRevealed: widget.onSuggestQso == null
                                                ? null
                                                : () {
                                                    _reveal.peekedCall = _callOf(spot)?.toUpperCase();
                                                    widget.onSuggestQso!(suggestedQsoFromSpot(spot), reveal: false);
                                                  },
                                            // The fill lasts as long as the row is open —
                                            // a spot the operator dragged back or set
                                            // aside is not the station they are working,
                                            // and leaving it in the fields makes the next
                                            // Log a contact with whoever was slid last.
                                            // Scrolling is not one of those: it leaves the
                                            // row open, and so leaves the fill alone.
                                            // Unconditional, unlike the suggestion it
                                            // reports: [_reveal.peekedCall] is this panel's own
                                            // state, and hanging its clearing off an
                                            // optional callback would leave the peek
                                            // standing for good wherever that callback is
                                            // absent.
                                            onWithdrawn: () {
                                              // Only its own: dragging out through the
                                              // middle and back out the other side
                                              // withdraws before the incoming side
                                              // reveals, and a blind clear there would
                                              // drop the new peek.
                                              if (_reveal.peekedCall == _callOf(spot)?.toUpperCase()) _reveal.peekedCall = null;
                                              widget.onWithdrawSuggestion?.call(_callOf(spot));
                                            },
                                            onSettled: widget.onSuggestionSettled,
                                          ),
                                    // Always the reverse of what the row currently says, so
                                    // the gesture reads the same whether the row was dimmed
                                    // by scoring or by an earlier slide: undo puts a worked
                                    // spot back on the board, backspace takes a live one off
                                    // it.
                                    trailing: _SlideAction(
                                      icon: worked ? MdiIcons.undoVariant : MdiIcons.backspace,
                                      label: worked ? t.operation.spots.slideRestore : t.operation.spots.slideIgnore,
                                      background: theme.colorScheme.surfaceContainerHighest,
                                      foreground: theme.colorScheme.onSurface,
                                      onPressed: () => setState(() => _workedOverrides.toggle(spot, worked: worked)),
                                    ),
                                    child: _SpotTile(
                                      key: _reveal.isCurrentRow(sectionIndex, index)
                                          ? _currentRowKey
                                          : (sectionIndex == 0 && index == 0 ? _calibrationKey : null),
                                      spot: spot,
                                      noteEmoji: _noteEmojiOf(spot),
                                      hzDigits: hzDigits,
                                      leftWidth: leftWidth,
                                      sortByAge: _filterState.sortBy == 'time',
                                      activityControls: _activityControls,
                                      // A spot set aside by a slide dims like one scoring
                                      // calls worked, and a slide can equally put a scored
                                      // duplicate back on the board — but neither gesture
                                      // touches the strikethrough, which answers only
                                      // "is this call in the log" — see [SpotWorkedOverrides].
                                      worked: worked,
                                      logged: flags.worked,
                                      isSelf: flags.isSelf,
                                      notices: flags.notices,
                                      highlight: spotIsCurrentQso(spot, currentCall: currentCall) ? highlight : null,
                                      // A spot that is ours alone suggests no QSO — there
                                      // is no one to work. Tapping it re-tunes instead:
                                      // the VFO goes back to the spotted state, which is
                                      // what the operator wants back after wandering off
                                      // to hunt.
                                      // Every tap closes whatever is open first: a tap is
                                      // the operator choosing a station outright, which
                                      // answers the question the open row was asking. The
                                      // close runs BEFORE the suggestion so the row's own
                                      // withdrawal cannot land on top of it.
                                      onTap: selfOnly
                                          ? _closingFirst(_retuneActionFor(spot))
                                          : widget.onSuggestQso == null
                                          ? null
                                          : _closingFirst(() => widget.onSuggestQso!(suggestedQsoFromSpot(spot))),
                                    ),
                                  ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  /// What [_SpotTile] paints for [spot], for the reveal's offset arithmetic.
  /// The note emoji is read from the same cache the tile draws it from, so a
  /// board whose note lookups have not landed yet is summed a few pixels short
  /// per noted row — which is what [SpotRevealState]'s measured correction is
  /// left to close.
  double _spotRowHeightOf(Map<String, dynamic> spot) =>
      spotRowHeightFor(metrics: _metrics, hasLabel: _labelOf(spot) != null, hasEmoji: _noteEmojiOf(spot) != null);

  /// Slid right past the commit point, or its button pressed: hand the spot
  /// to the logging panel as the QSO to log. The panel does the logging —
  /// re-deriving RST, `our`, timestamps and the command path here would be a
  /// second implementation of the thing the operator can already see.
  void _logSpot(Map<String, dynamic> spot) {
    widget.onLogQso?.call(suggestedQsoFromSpot(spot));
  }

  /// Wraps a row's tap handler so it closes whatever row is currently open
  /// before it runs — and returns null for a row that has no handler, so a
  /// dead row stays dead rather than becoming tappable just to close another.
  VoidCallback? _closingFirst(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      _slideGroup.closeAll();
      onTap();
    };
  }

  /// The tap for a row that is ours alone, or null when the spot carries
  /// nothing restorable at all — a row must not accept a tap it cannot honor.
  VoidCallback? _retuneActionFor(Map<String, dynamic> spot) {
    if (_freqOf(spot) == null && _bandOf(spot) == null && _modeOf(spot) == null) return null;
    return () => _retuneToSelfSpot(spot);
  }

  /// Tapped a self row: put the VFO back in the state the spot announced —
  /// frequency (band follows it) and mode, everything the VFO holds, but
  /// nothing QSO-shaped. Through [RadioService.setVfo] like the `setVfo`
  /// command action, so CAT re-tunes a connected radio. A freq-less spot
  /// still restores what it can: its band (which clears the frequency,
  /// per setVfo's convention) and/or mode.
  ///
  /// The mode is uppercased for the same reason [spotCandidateQso] does
  /// (sources pass their API's casing through), and more than a display
  /// concern here: the VFO's mode persists and seeds every subsequently logged
  /// QSO. Absent stays null rather than `''`, which would clobber the VFO's
  /// mode where null leaves it alone.
  void _retuneToSelfSpot(Map<String, dynamic> spot) {
    final freq = _freqOf(spot);
    final mode = _modeOf(spot)?.toUpperCase();
    if (freq != null) {
      widget.services.radio.setVfo('vfoA', freq: freq, mode: mode);
    } else {
      widget.services.radio.setVfo('vfoA', band: _bandOf(spot), mode: mode);
    }
  }

  /// Maps a `sectionSpots` section key to its display label. The flat
  /// `'spots'` section reads as the actual band once the Band filter has
  /// narrowed to one — "All Spots" while filtered to a single band would
  /// misleadingly suggest the filter had no effect.
  String _sectionLabel(Translations t, String key) => switch (key) {
    'self' => t.operation.spots.yourSpots,
    'notes' => t.operation.spots.callsOfNote,
    'spots' => _filterState.isSingleBandFilter ? _filterState.bandFilter : t.operation.spots.allSpots,
    '?' => t.operation.spots.unknownBand,
    _ => key,
  };
}

/// Pins a [_SpotsSectionHeader] to the top of the spots list while its own
/// section's rows scroll under it, the way `qso_list.dart` pins its day
/// headers.
class _SpotsSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;

  /// Resolved by the caller: `minExtent`/`maxExtent` are asked for outside
  /// [build], where there is no context to read a metric from.
  final double extent;

  const _SpotsSectionHeaderDelegate({required this.label, required this.extent});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      // Forced to exactly [extent]: a pinned header that paints taller than it
      // declared trips Flutter's "layoutExtent exceeds paintExtent" assertion.
      SizedBox(height: extent, child: _SpotsSectionHeader(label));

  @override
  bool shouldRebuild(_SpotsSectionHeaderDelegate old) => old.label != label || old.extent != extent;
}

/// A section group row (a band or "Calls of Note"), styled to match
/// `qso_list.dart`'s `DayHeaderRow` (same height,
/// background, and bottom border) so the two lists read as the same kind
/// of grouping, not two different UI languages.
class _SpotsSectionHeader extends StatelessWidget {
  final String label;

  const _SpotsSectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      // No height of its own: [_SpotsSectionHeaderDelegate] imposes the one it
      // declared to the sliver protocol, which is a QSO list day header's.
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceContainerHighest,
      foregroundDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 3)),
      ),
      // Background stays edge-to-edge; the label insets by the split's
      // grab-strip clearance and the real device inset, like the spot rows
      // below it.
      padding: PaneSafeArea.symmetricOf(context, horizontal: Space.lg, vertical: LayoutDensity.metricsOf(context).qsoRowPaddingV),
      child: Text(
        label,
        // The band is what the operator is looking for, and the row is exactly
        // one line tall: a label too long for a narrow pane gives up its spot
        // count rather than wrapping into a second line the pinned extent
        // would clip off.
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700, height: 1.0),
      ),
    );
  }
}

/// The panel's spots list as [SpotRevealState] sees it.
class _SpotsListView implements SpotListView {
  _SpotsListView(this._panel, this._rebuild);

  final _SpotsPanelState _panel;
  final VoidCallback _rebuild;

  @override
  void rebuild() => _rebuild();

  ScrollController get _scroll => _panel._scrollController;

  @override
  bool get onScreen => _panel._onScreen;

  @override
  bool get canScroll => _panel.mounted && _scroll.hasClients && _panel._onScreen;

  @override
  ({double pixels, double viewport, double minExtent, double maxExtent})? get geometry {
    if (!_scroll.hasClients) return null;
    final position = _scroll.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) return null;
    return (pixels: position.pixels, viewport: position.viewportDimension, minExtent: position.minScrollExtent, maxExtent: position.maxScrollExtent);
  }

  @override
  double get sectionHeaderHeight => _panel._metrics.sectionHeaderHeight;

  @override
  Future<void> animateTo(double target) => _scroll.animateTo(target, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);

  @override
  ({double top, double height})? measureCurrentRow() {
    final box = _panel._currentRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport is! RenderBox || !viewport.attached) return null;
    return (top: box.localToGlobal(Offset.zero, ancestor: viewport).dy, height: box.size.height);
  }

  @override
  double? measureCalibrationRow() {
    if (!_panel.mounted) return null;
    final box = _panel._calibrationKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.size.height;
  }

  @override
  void afterFrame(VoidCallback callback) => WidgetsBinding.instance.addPostFrameCallback((_) => callback());
}
