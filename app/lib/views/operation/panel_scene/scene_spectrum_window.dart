// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The window a band scope shows: over a sweep, the stretch of it in view, or
// within the scene's own `window`; with no sweep, that window standing in
// for one (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

/// How long a crop caption stays up ([_SpectrumWindow._cropCaption]).
const _cropShowFor = Duration(seconds: 10);

extension _SpectrumWindow on _SceneSpectrumViewState {
  /// The crop captions shown so far, which the display hidden, another radio
  /// shown, or the radio's picture gone makes worth showing again.
  void _forgetCrops() {
    _cropsShown.clear();
    _cropShowing = null;
    _cropTimer?.cancel();
    _cropTimer = null;
  }

  /// The scene's `window` over a live sweep: where the window shown stays.
  /// Null with none, and while it stands in for the sweep, which holds it.
  (double, double)? get _home => _sweepless ? null : _spec.window;

  /// [center] for a window [width] wide, kept within [_home] where it is narrower.
  double _homeCenter(double center, double width) {
    final home = _home!, half = math.min(width, home.$2 - home.$1) / 2;
    return center.clamp(home.$1 + half, home.$2 - half);
  }

  /// The scene's `window` as the sweep while none comes — no
  /// radio, one without a scope or with it off, before the first sweep, or
  /// none for [_staleAfter] — a sweep with no levels, so the axis, overlays,
  /// annotations and layers are drawn and the gestures work over a blank
  /// picture: a scope the app cannot move, as wide as the window. A sweep
  /// takes its place as it arrives ([_onFrame]); a window that changes, or
  /// one standing in for a sweep that stopped, starts unzoomed.
  void _standIn() {
    final window = _spec.window;
    if (window == null) {
      if (_sweepless) {
        _sweepless = false;
        _sweep = _frame = null;
        _viewWidth = _viewCenter = _pannedAtVfo = _recenters = null;
      }
      return;
    }
    if (!_sweepless && _sweep != null && !_stale) return;
    final (low, high) = (window.$1.round(), window.$2.round());
    if (_sweepless && _sweep?.lowHz == low && _sweep?.highHz == high) return;
    _sweepless = true;
    _viewWidth = _viewCenter = _pannedAtVfo = null;
    _recenters = false;
    _sweep = SpectrumFrame(lowHz: low, highHz: high, levels: Float32List(0), floorDb: 0, ceilingDb: 80, atMillis: nowMillis());
    _frame = _window(_sweep!);
    _panRepaint.value++;
    // Not now: this runs as the tree builds, and a readout sets the scene's values.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tellReadouts();
    });
  }

  /// The window shown over [sweep]. Held inside it, except where the radio
  /// moves its scope: there the window runs ahead of the sweeps, its unswept
  /// part blank until they catch up, so a pan or zoom keeps the pointer's
  /// pace rather than waiting on the radio's.
  SpectrumFrame _window(SpectrumFrame sweep) {
    final span = _number(_spec.span);
    if (_viewWidth != null && span != _zoomedOverSpan) _viewWidth = null;
    // Over a sweep, a scene's own window is where it stays: unpanned, its middle; panned, within it,
    // whatever of it the sweep covers.
    if (_home case final home?) {
      final width = math.min(_viewWidth ?? span ?? (sweep.highHz - sweep.lowHz).toDouble(), _spec.maxWidthHz ?? double.infinity);
      final center = _homeCenter(_viewCenter ?? _spec.centerHz ?? (home.$1 + home.$2) / 2, width);
      return SpectrumFrame(
        lowHz: (center - width / 2).round(),
        highHz: (center + width / 2).round(),
        levels: Float32List(0),
        floorDb: sweep.floorDb,
        ceilingDb: sweep.ceilingDb,
        noiseDb: sweep.noiseDb,
        atMillis: sweep.atMillis,
      );
    }
    final (low, high) = spectrumWindow(
      sweep,
      _viewWidth ?? span,
      centerHz: _viewCenter ?? _spec.centerHz,
      // A secondary scope's window is its own, past the sweep as within it.
      held: _recenters != true && !_secondary,
      widestHz: _spec.maxWidthHz,
    );
    return SpectrumFrame(
      lowHz: low.round(),
      highHz: high.round(),
      levels: Float32List(0),
      floorDb: sweep.floorDb,
      ceilingDb: sweep.ceilingDb,
      noiseDb: sweep.noiseDb,
      atMillis: sweep.atMillis,
    );
  }

  /// Puts a crop's reason up for [_cropShowFor] the first time this display
  /// can show it ([_cropCaption]), and not again until the display is hidden,
  /// shows another radio, or the radio's picture goes ([_forgetCrops]): a
  /// zoom, a pan or a retry refused alike says nothing the operator has not
  /// read. One a problem or a pause in the sweeps covers before its time is
  /// up is taken back, to show in full once the picture returns. The crop
  /// ending takes it down for good. True when what is up changed, which a
  /// sweep that does not otherwise rebuild the display must then do.
  bool _noteCrop() {
    final (source, uuid, was) = (widget.source, _uuid, _cropShowing);
    final why = source == null || uuid == null ? null : source.cropped(uuid, this);
    if (why == null) {
      _cropShowing = null;
      _cropTimer?.cancel();
    } else if (_sweepless || _stale || source!.problem(uuid!) != null) {
      if (_cropShowing == why) {
        _cropsShown.remove(why);
        _cropShowing = null;
        _cropTimer?.cancel();
      }
    } else if (_cropsShown.add(why)) {
      _cropShowing = why;
      _cropTimer?.cancel();
      _cropTimer = Timer(_cropShowFor, _cropShown);
    }
    return _cropShowing != was;
  }

  /// Why this display crops a coarser sweep than its own, in a corner of the
  /// picture, while [_noteCrop] has it up: small, as what it draws is still
  /// the receiver, and letting clicks and drags through to the sweep beneath.
  Widget? _cropCaption(BuildContext context, String? uuid) {
    final why = uuid == null ? null : widget.source?.cropped(uuid, this);
    if (why == null || why != _cropShowing) return null;
    final theme = Theme.of(context);
    return Positioned(
      left: Space.xs,
      right: Space.xs,
      bottom: Space.xs,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.colorScheme.surface.withValues(alpha: .75), borderRadius: BorderRadius.circular(Space.xs)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
              child: Text(
                why,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
