// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'spots_panel.dart';

/// What [SpotRevealState] needs from the list it scrolls: whether it can,
/// where it stands, and two measurements of rows that may or may not be
/// mounted. The panel answers from its ScrollController and two GlobalKeys;
/// a test answers with numbers.
abstract interface class SpotListView {
  /// Whether the pane is the one on screen — its tab selected and its dock
  /// group showing it.
  bool get onScreen;

  /// [onScreen], and the panel mounted with its list attached.
  bool get canScroll;

  /// The list's scroll geometry, or null before its first layout.
  ({double pixels, double viewport, double minExtent, double maxExtent})? get geometry;

  /// The section-header height the current layout density declares.
  double get sectionHeaderHeight;

  Future<void> animateTo(double target);

  /// The current QSO's row as painted, its top relative to the viewport's —
  /// or null when the viewport never mounted it.
  ({double top, double height})? measureCurrentRow();

  /// The calibration row's painted height, or null when it is not mounted.
  double? measureCalibrationRow();

  void afterFrame(VoidCallback callback);

  /// Rebuilds the list, for a row-height scale that just changed.
  void rebuild();
}

/// Bringing the current QSO's row into view on the Spots panel: which row
/// that is, the arithmetic for where it sits, the one measured correction
/// after a scroll lands, and the latches that keep each call to one reveal.
///
/// Works out where the row *is* arithmetically, like `qso_list.dart`'s
/// `_revealSelected` and for the same reason: a row outside the viewport
/// either isn't built or carries a paint transform from wherever it last sat,
/// and both read as a confident, wrong position.
class SpotRevealState {
  SpotRevealState(this._view);

  final SpotListView _view;

  /// The call whose row this panel has already scrolled to. Only ever set
  /// while the panel is visible, so a call typed behind a hidden tab is still
  /// pending when the tab comes back.
  String? _revealedCall;

  /// The copy [_revealedCall]'s reveal chose, held while that call stays
  /// revealed. Each build re-prices the copies against where the list is at
  /// that moment, and a build landing mid-scroll or mid-drag can price the
  /// other copy cheaper — moving the current-row key there and sending
  /// [_correctRevealFor] to a row the reveal never aimed at.
  ({int section, int index})? _revealedRowAt;

  /// Where the current QSO's row sits — the copy [locateCurrentSpotRow] chose
  /// when the call has more than one — as counts of the rows and section
  /// headers above it plus the totals for the whole list — the raw material
  /// for [_revealCurrent]'s arithmetic. Null when no spot matches. Written by
  /// [locate], once per build of the sectioned list.
  ({double top, double height})? _currentRowPosition;

  /// Where the current-row key goes. Placed by `(section, index)` — the one
  /// spot pinned in "Calls of Note" is the same object as its copy in the
  /// band section, so keying by identity would put the key on two tiles at
  /// once and the tree would throw.
  ({int section, int index})? _currentRowAt;

  /// The call the latest build placed a keyed row for — a staleness guard, so
  /// a correction chained to one call's scroll can't measure a row the list has
  /// since given to another. It does NOT say the row was inflated: the list
  /// builds every child widget but the viewport only mounts the ones near it.
  /// Whether there is anything to measure is what
  /// [SpotListView.measureCurrentRow] answers.
  String? _keyedRowCall;

  /// How much taller a row actually paints than [spotRowHeightFor] declares.
  /// 1.0 until a row has been measured, which is exactly right at an OS text
  /// scale of 1.0 and wrong by a fifth at 1.3.
  ///
  /// Measured rather than computed from `MediaQuery.textScalerOf`: a tile is
  /// text lines inside constant padding, so it grows by LESS than the text
  /// scaler (1.22 at a scale of 1.3), and no arithmetic over the tile's font
  /// sizes would survive a change to what it paints. One reading covers every
  /// row shape — plain, labelled and noted rows stretch within about a percent
  /// of each other, which over a long board stays inside what
  /// [_correctRevealFor] can absorb.
  double get rowHeightScale => _rowHeightScale;
  double _rowHeightScale = 1.0;

  /// The height [spotRowHeightFor] declares for the calibration row. Null
  /// when this build placed no calibration row — an empty board, or one whose
  /// first row is the current QSO's and so already carries the current-row
  /// key.
  double? _calibrationDeclared;

  /// The call the open row's peek put in the logging fields, uppercased, or
  /// null when no peek is standing. Written by the same two callbacks that
  /// make and take back the fill, so it tracks the fill rather than the row:
  /// a peek the logging panel held back above work in progress never became
  /// the current call, and must not suppress that call's reveal.
  String? peekedCall;

  /// A density change moves the spacing [rowHeightScale] was measured
  /// against, so carry the learned text stretch across rather than leaving a
  /// ratio that now belongs to the previous rung — see [spotRowScaleFor].
  void densityChanged(LayoutMetrics from, LayoutMetrics to) => _rowHeightScale = spotRowScaleFor(_rowHeightScale, from: from, to: to);

  /// Lets the next build reveal the current call again, for a list that is
  /// not on screen to be revealed on — the error notice replaces it. Left
  /// latched, the call being logged would be retired against a list the
  /// operator never saw, and the rebuilt one would never scroll to it.
  void forget() => _revealedCall = null;

  /// A section header's height: the extent every one of them is pinned at, and
  /// the figure both the reveal's arithmetic and its leading inset count with.
  /// Scaled like the rows for the reasons [rowHeightScale] gives.
  double get sectionHeaderExtent => _view.sectionHeaderHeight * _rowHeightScale;

  /// Whether the tile at `(section, index)` is the current QSO's row, and so
  /// carries the current-row key.
  bool isCurrentRow(int section, int index) {
    final at = _currentRowAt;
    return at != null && at.section == section && at.index == index;
  }

  /// Runs [locateCurrentSpotRow] over this build's sections and keeps what it
  /// found, for [_revealCurrent] and for the row key. [declaredHeightOf] is
  /// what [spotRowHeightFor] says a spot's row is.
  ///
  /// Every declared height goes through [rowHeightScale], headers included:
  /// the headers are text in constant padding like the rows, and a sum that
  /// scaled only one of the two would drift by a header on every section.
  /// For the header that is not an estimate but the extent the sliver is
  /// pinned at — see [sectionHeaderExtent].
  void locate(List<List<Map<String, dynamic>>> sections, String? currentCall, {required double Function(Map<String, dynamic> spot) declaredHeightOf}) {
    final found = locateCurrentSpotRow(
      sections,
      currentCall: currentCall,
      headerHeight: sectionHeaderExtent,
      heightOf: (spot) => declaredHeightOf(spot) * _rowHeightScale,
      // No geometry before the list's first layout, and nothing on screen to
      // stay beside either — the first match is as good as any there.
      scrollCostOf: _view.geometry == null ? null : _scrollCostOf,
      keep: currentCall != null && currentCall == _revealedCall ? _revealedRowAt : null,
    );
    _currentRowAt = found == null ? null : (section: found.section, index: found.index);
    _currentRowPosition = found == null ? null : (top: found.top, height: found.height);
    _keyedRowCall = found == null ? null : currentCall;

    // The first row of the first section is the calibration row: it is the one
    // row that is certainly mounted on a panel that has just been built, which
    // is where the reading has to come from — a scale learned only after the
    // first reveal would be learned one reveal too late.
    final first = sections.isEmpty || sections.first.isEmpty ? null : sections.first.first;
    _calibrationDeclared = first == null || isCurrentRow(0, 0) ? null : declaredHeightOf(first);
  }

  /// Learns [rowHeightScale] from the calibration row, if this build placed
  /// one and the viewport mounted it. Silent when it did not: the row is only
  /// mounted near the top of the list, and a scale already learned holds until
  /// something moves that row back into view.
  void calibrate() {
    final declared = _calibrationDeclared;
    if (declared == null || declared <= 0) return;
    final painted = _view.measureCalibrationRow();
    if (painted == null || painted <= 0) return;

    final scale = painted / declared;
    // A reading this close changes no offset the correction couldn't absorb,
    // and settling for it is what stops a rebuild from re-triggering a rebuild.
    if ((scale - _rowHeightScale).abs() < 0.005) return;
    _rowHeightScale = scale;
    _view.rebuild();
    // The geometry every pending reveal was armed against has just moved, so
    // let the next build arm again rather than leaving a call retired against
    // offsets that were wrong when they were summed.
    _revealedCall = null;
  }

  /// Schedules a scroll when the current QSO's call has changed since the last
  /// one this panel revealed. Skipped entirely while the panel is hidden, and
  /// [_revealedCall] is left alone there rather than cleared — that is what
  /// makes the call still pending when the tab comes back.
  void arm(String? currentCall) {
    if (!_view.onScreen || currentCall == _revealedCall) return;
    // No row for it — on the board a call is typed against, or nothing typed
    // at all. Left un-latched in the first case, so the reveal still happens
    // when the spot for that call arrives on the next fetch.
    if (currentCall != null && _currentRowPosition == null) return;
    _revealedCall = currentCall;
    _revealedRowAt = _currentRowAt;
    if (currentCall == null) return;
    // A slide put this call in the fields — the operator is looking straight
    // at its row and dragging it, so there is nothing to bring into view and
    // moving the list would pull the row out from under the finger. Latched
    // rather than skipped, so the scroll does not simply arrive late once the
    // row closes with the call still in the fields.
    //
    // The peeked call, not merely "some row is open": this is the one give-up
    // in this machine that a later frame does NOT recover from, so it may only
    // retire the call the slide itself put there. A call from anywhere else —
    // typed while a row sits open, or a peek held back above work in progress
    // — is nobody's peek and still reveals.
    if (currentCall == peekedCall) return;
    _view.afterFrame(() {
      // The latch moving between arming and here means something in the same
      // post-frame batch superseded this reveal — [calibrate] clears it when
      // the geometry it was armed against turns out to be wrong. Bail without
      // touching the latch: nulling it would retract whatever re-armed.
      if (_revealedCall != currentCall) return;
      // Un-latched whenever the reveal gave up, which is permission for the
      // next rebuild to try again rather than a retry in itself — deliberately,
      // since a reveal that cannot succeed (a pane collapsed to no height)
      // would otherwise rebuild the panel forever. Every reason it gives up is
      // one a later frame recovers from, and a latch left set would retire that
      // callsign for the rest of the session.
      if (!_revealCurrent(currentCall)) _revealedCall = null;
    });
  }

  /// Brings the current QSO's row into view, scrolling the least that does it
  /// — a row already fully visible doesn't move, so typing a call that happens
  /// to be on screen never yanks the list out from under the operator. Returns
  /// whether it got far enough to decide; already-visible counts as revealed.
  ///
  /// [locateCurrentSpotRow] does the arithmetic and says what it is exact
  /// about; [_correctRevealFor] closes the rest — an emoji the note lookup had
  /// not yet reported when the offsets were summed.
  ///
  /// [call] is passed in rather than read back off [_revealedCall]: this runs a
  /// frame after it was scheduled, and reading the latch here means a reveal
  /// can find it moved and quietly scroll nothing while still reporting done.
  bool _revealCurrent(String call) {
    // No geometry is a list attached but not yet laid out — a give-up a later
    // frame recovers from. Without this, [_scrollTo] reads it as "already
    // visible" and the call is retired without a scroll.
    if (!_view.canScroll || _view.geometry == null) return false;
    final at = _currentRowPosition;
    if (at == null) return false;

    final scroll = _scrollTo(at.top, at.top + at.height);
    // Chained to the scroll's completion, because measuring a row in flight
    // reads a position it is about to leave. Scheduled even when nothing
    // moved: "the estimate says it is already on screen" is exactly the claim
    // an accumulated drift makes wrongly, and it is the one case no later
    // step would otherwise check.
    if (scroll == null) {
      _view.afterFrame(() => _correctRevealFor(call));
    } else {
      scroll.whenComplete(() => _correctRevealFor(call));
    }
    return true;
  }

  /// One measured pass over whatever the summed offsets got wrong, once the
  /// row is close enough to measure honestly. That sum is exact for the row
  /// shapes [spotRowHeightFor] knows, so this is a safety net rather than the
  /// thing that lands the scroll: a note emoji the lookup had not reported when
  /// the offsets were summed, or a tile that grew without those constants
  /// growing with it. Not the headers — those are pinned at a stated extent,
  /// which is the same figure the sum counts.
  ///
  /// One per reveal, so a drift it cannot close costs one nudge rather than a
  /// loop: [_revealCurrent] schedules it once per arm, and this ignores its
  /// own scroll's future.
  void _correctRevealFor(String call) {
    if (!_view.canScroll) return;
    if (_revealedCall != call || _keyedRowCall != call) return;
    // Null when the viewport never mounted this row — the list builds every
    // child widget but only inflates the ones within reach of where it landed.
    // Which is the case this correction exists for: the estimate was off by
    // more than that reach, so there is nothing here to measure.
    final row = _view.measureCurrentRow();
    final geometry = _view.geometry;
    if (row == null || geometry == null) return;

    // Beyond what the viewport plus its cache can hold is a stale transform,
    // not a row waiting to be nudged. Measured against the cache extent as well
    // as the viewport: a row laid out in the cache is honestly measurable, and
    // in a pane shorter than the cache the viewport alone would reject it.
    final reach = math.max(geometry.viewport, RenderAbstractViewport.defaultCacheExtent);
    if (row.top < -reach || row.top > geometry.viewport + reach) return;
    _scrollTo(geometry.pixels + row.top, geometry.pixels + row.top + row.height);
  }

  /// How far [_scrollTo] would move the list to bring [top]..[bottom] into
  /// view — zero for a span already fully visible. Read at build time, a frame
  /// before the reveal runs, which is what lets the row the reveal scrolls to
  /// and the row the current-row key marks for [_correctRevealFor] be the same
  /// one.
  double _scrollCostOf(double top, double bottom) {
    final geometry = _view.geometry;
    final target = _scrollTargetFor(top, bottom);
    return target == null || geometry == null ? 0 : (target - geometry.pixels).abs();
  }

  /// [spotScrollTarget] against the list as it stands now.
  double? _scrollTargetFor(double top, double bottom) {
    final geometry = _view.geometry;
    if (geometry == null) return null;
    return spotScrollTarget(
      top: top,
      bottom: bottom,
      headerHeight: sectionHeaderExtent,
      pixels: geometry.pixels,
      viewport: geometry.viewport,
      minExtent: geometry.minExtent,
      maxExtent: geometry.maxExtent,
    );
  }

  /// Scrolls to [spotScrollTarget]'s answer, or not at all when there is none.
  /// Returns the scroll's future, or null when nothing moved.
  Future<void>? _scrollTo(double top, double bottom) {
    final target = _scrollTargetFor(top, bottom);
    if (target == null) return null;
    return _view.animateTo(target);
  }
}
