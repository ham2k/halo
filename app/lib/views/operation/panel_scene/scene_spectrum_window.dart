// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The window a band scope shows: over a sweep, the stretch of it in view, or
// within the scene's own `window`; with no sweep, that window standing in
// for one (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

extension _SpectrumWindow on _SceneSpectrumViewState {
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
        _coverGestureWindow = false;
        _zoomStartedAtWidth = null;
      }
      return;
    }
    if (!_sweepless && _sweep != null && !_stale) return;
    final (low, high) = (window.$1.round(), window.$2.round());
    if (_sweepless && _sweep?.lowHz == low && _sweep?.highHz == high) return;
    _sweepless = true;
    _viewWidth = _viewCenter = _pannedAtVfo = null;
    _coverGestureWindow = false;
    _zoomStartedAtWidth = null;
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
    if (_viewWidth case final width? when span != _zoomedOverSpan) {
      if (span != width.round()) _coverGestureWindow = false;
      _viewWidth = null;
    }
    final width = _viewWidth ?? span;
    // Over a sweep, a scene's own window is where it stays: unpanned, its middle; panned, within it,
    // whatever of it the sweep covers.
    if (_home case final home?) {
      final homeWidth = math.min(width ?? (sweep.highHz - sweep.lowHz).toDouble(), _spec.maxWidthHz ?? double.infinity);
      final center = _homeCenter(_viewCenter ?? _spec.centerHz ?? (home.$1 + home.$2) / 2, homeWidth);
      return SpectrumFrame(
        lowHz: (center - homeWidth / 2).round(),
        highHz: (center + homeWidth / 2).round(),
        levels: Float32List(0),
        floorDb: sweep.floorDb,
        ceilingDb: sweep.ceilingDb,
        noiseDb: sweep.noiseDb,
        atMillis: sweep.atMillis,
      );
    }
    final (low, high) = spectrumWindow(
      sweep,
      width,
      centerHz: _viewCenter ?? _spec.centerHz,
      held: _recenters != true,
      widestHz: _spec.maxWidthHz,
      covered: _coverGestureWindow && !_pastScope(width ?? (sweep.highHz - sweep.lowHz).toDouble()),
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
}
