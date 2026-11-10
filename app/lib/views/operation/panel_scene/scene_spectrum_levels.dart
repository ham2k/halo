// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The strip beside a spectrum: the panadapter's levels and the waterfall's
// age, each a handle — the panadapter's floor and range, the waterfall's
// speed and, with Alt held, its floor — the host's to move unless the scene's `gestures` say otherwise
// (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

/// The operator's value for one of the scene's numbers, and what the scene's
/// own was when the operator set it: a scene that changes its own takes it back.
typedef _Held = ({double value, double? over});

/// A drag on the level strip: what it moves, where it took hold, and the
/// floor offset, range, rows a second and waterfall floor offset then.
typedef _LevelGrip = ({String what, double y, double floor, double range, double rows, double fall});

/// The host's strip, where a scene names none.
final _defaultLevelScale = SceneSpectrumLevelScale(const {});

/// A drag this far, in pixels, changes the range by e, as one along the
/// frequency axis changes the width.
const _rangePixels = 150.0;

/// The dB an Alt-drag the waterfall's whole length moves its floor: fine
/// steps, for matching a radio's own waterfall by eye.
const _waterfallFloorDbPerLength = 12.0;

/// The dB between level labels, at [pixelsPerDb]: the finest of 1, 2, 5, 10,
/// 20 or 50 that keeps labels [apart] pixels from each other.
@visibleForTesting
double spectrumLevelStep(double pixelsPerDb, {double apart = 18}) {
  for (final step in const [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]) {
    if (step * pixelsPerDb >= apart) return step;
  }
  return 100;
}

/// The seconds between age labels down a waterfall moving [pixelsPerSecond]:
/// the finest of a run from half a second to ten minutes that keeps them
/// [apart] pixels from each other.
@visibleForTesting
double spectrumAgeStep(double pixelsPerSecond, {double apart = 24}) {
  for (final step in const [.5, 1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0, 300.0]) {
    if (step * pixelsPerSecond >= apart) return step;
  }
  return 600;
}

extension _SpectrumLevels on _SceneSpectrumViewState {
  double? _heldOr(_Held? held, SceneNumber? number) {
    final scene = _number(number);
    return held != null && held.over == scene ? held.value : scene;
  }

  /// The floor offset, range and waterfall speed in force: the operator's
  /// where they moved them, the scene's otherwise.
  double? get _floorNow => _heldOr(_floorHeld, _spec.floor);
  double? get _rangeNow => _heldOr(_rangeHeld, _spec.range);
  double? get _speedNow => _heldOr(_speedHeld, _spec.waterfallSpeed);
  double? get _waterfallFloorNow => _heldOr(_waterfallFloorHeld, _spec.waterfallFloor);

  /// Whether levels rise, and ages grow, toward the screen's top or left —
  /// a waterfall flowing up or left — rather than its bottom or right.
  bool _mirrored(_Way way) => way.flow == SceneSpectrumFlow.up || way.flow == SceneSpectrumFlow.left;

  /// The waterfall's time scale, in rows a second: the speed set, or with
  /// none, the sweeps' steady rate. Never the sweeps' rate as it wobbles from
  /// one to the next — every row lies at its age on this scale, so a scale
  /// that moved with each sweep would shake the whole history up and down.
  double? get _rowsPerSecond => _speedNow ?? _steadySweepRate;

  /// The strip in force: the scene's, or from API 17 the host's.
  SceneSpectrumLevelScale? _levelScaleFor(_Way way) {
    // A stand-in for a sweep has no levels to scale.
    if (_sweepless) return null;
    return _spec.levelScale ?? (_spec.noLevelScale || !(widget.source?.nativeGestures ?? true) ? null : _defaultLevelScale);
  }

  /// The strip, styled as the scene says, else as the frequency axis [scale]
  /// is: its background, label text and ticks.
  Widget _levelStrip(SceneSpectrumLevelScale levels, SceneSpectrumScale? scale, _Way way, double width, ColorScheme scheme, TextStyle text) {
    final g = _gestures.levels;
    final labels = levels.labels ?? scale?.labels, ticks = levels.ticks ?? scale?.ticks;
    final ink = labels?.color ?? scheme.onSurfaceVariant;
    final background = levels.background ?? scale?.background;
    final painter = CustomPaint(
      painter: _LevelPainter(
        repaint: _panRepaint,
        texts: _texts,
        start: levels.start,
        turned: _turned(way),
        mirrored: _mirrored(way),
        pan: () => _panBand,
        fall: () => _fallBand,
        scale: () => switch (_frame) {
          final frame? => _panScale(frame),
          null => null,
        },
        secondsPerPixel: _secondsPerPixel,
        text: text.copyWith(
          color: ink,
          fontSize: _number(labels?.size),
          fontWeight: _weight(_number(labels?.weight)),
          fontFamily: labels?.fontFamily,
          fontStyle: labels?.italic ?? false ? FontStyle.italic : null,
        ),
        tick: Paint()
          ..color = ticks?.color ?? ink
          ..strokeWidth = _number(ticks?.width) ?? 1,
        tickLength: _number(ticks?.length) ?? 4,
        // Over the picture, see-through: the trace and the waterfall show under it.
        background: levels.over ? _seeThrough(background ?? _spec.backgroundColor ?? scheme.surfaceContainerLowest) : background,
      ),
    );
    final turned = _turned(way);
    final body = turned ? SizedBox(height: width, child: painter) : SizedBox(width: width, child: painter);
    // Off, it takes nothing: over the picture it lies on top, and would swallow the clicks and pans beneath.
    if (g == SceneSpectrumGesture.off) return IgnorePointer(child: body);
    // Dragged along the flow, as its labels run.
    double along(Offset at) => turned ? at.dx : at.dy;
    return MouseRegion(
      cursor: turned ? SystemMouseCursors.resizeLeftRight : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onVerticalDragStart: turned ? null : (d) => _levelGrip = _levelGripAt(along(d.localPosition)),
        onVerticalDragUpdate: turned ? null : (d) => _levelDrag(along(d.localPosition)),
        onVerticalDragEnd: turned ? null : (_) => _levelEnd(),
        onVerticalDragCancel: turned ? null : _levelEnd,
        onHorizontalDragStart: turned ? (d) => _levelGrip = _levelGripAt(along(d.localPosition)) : null,
        onHorizontalDragUpdate: turned ? (d) => _levelDrag(along(d.localPosition)) : null,
        onHorizontalDragEnd: turned ? (_) => _levelEnd() : null,
        onHorizontalDragCancel: turned ? _levelEnd : null,
        onDoubleTap: _resetLevels,
        child: body,
      ),
    );
  }

  /// Where [band] lies along the flow: its top and bottom upright, its left
  /// and right sideways.
  (double, double) _alongFlow(Rect band) => _turned(_way) ? (band.left, band.right) : (band.top, band.bottom);

  /// What a drag at [y], along the flow, takes hold of: on the waterfall
  /// its speed, or with Alt held its floor; on the panadapter its floor in
  /// the third by its base, its range beyond.
  _LevelGrip? _levelGripAt(double y) {
    final frame = _frame;
    if (frame == null) return null;
    final (floor, range) = _panScale(frame);
    final offset = floor - frame.floorDb, rows = _rowsPerSecond ?? 0, fallFloor = _waterfallFloorNow ?? 0;
    if (_fallBand case final fall?) {
      final (top, bottom) = _alongFlow(fall);
      if (y >= top && y <= bottom) {
        if (HardwareKeyboard.instance.isAltPressed) return (what: 'waterfallFloor', y: y, floor: offset, range: range, rows: rows, fall: fallFloor);
        return rows > 0 ? (what: 'speed', y: y, floor: offset, range: range, rows: rows, fall: fallFloor) : null;
      }
    }
    if (_panBand case final pan?) {
      final (top, bottom) = _alongFlow(pan);
      if (y < top || y > bottom) return null;
      final third = (bottom - top) / 3;
      final low = _mirrored(_way) ? y < top + third : y > bottom - third;
      return (what: low ? 'floor' : 'range', y: y, floor: offset, range: range, rows: rows, fall: fallFloor);
    }
    return null;
  }

  void _levelDrag(double y) {
    final grip = _levelGrip, frame = _frame, mirrored = _mirrored(_way);
    if (grip == null || frame == null) return;
    switch (grip.what) {
      case 'speed':
        // The age taken hold of stays under the pointer: twice as far down
        // the waterfall, twice as many rows a second.
        final (top, bottom) = _alongFlow(_fallBand!);
        double depth(double at) => math.max(8.0, mirrored ? bottom - at : at - top);
        _setLevel('speed', (grip.rows * depth(y) / depth(grip.y)).clamp(.1, 60));
      case 'waterfallFloor':
        // Toward the spectrum lowers the floor and brightens the waterfall, as a floor drag lifts the trace.
        final (top, bottom) = _alongFlow(_fallBand!);
        final dy = (y - grip.y) * (mirrored ? -1 : 1);
        _setLevel('waterfallFloor', (grip.fall + dy * _waterfallFloorDbPerLength / math.max(1.0, bottom - top)).clamp(-200, 200));
      case 'floor':
        // The trace follows the pointer along the flow.
        final (top, bottom) = _alongFlow(_panBand!);
        final dy = (y - grip.y) * (mirrored ? -1 : 1);
        _setLevel('floor', (grip.floor + dy * grip.range / (bottom - top)).clamp(-200, 200));
      default:
        // Away from the middle narrows the range, toward it widens it; the
        // level taken hold of stays under the pointer.
        final (top, bottom) = _alongFlow(_panBand!);
        final height = bottom - top;
        double share(double at) => mirrored ? (at - top) / height : (bottom - at) / height;
        final grabbed = frame.floorDb + grip.floor + share(grip.y) * grip.range;
        final away = grip.y < (top + bottom) / 2 ? grip.y - y : y - grip.y;
        final range = (grip.range / math.exp(away / _rangePixels)).clamp(1.0, 200.0);
        _setLevel('range', range);
        _setLevel('floor', (grabbed - share(y) * range - frame.floorDb).clamp(-200, 200));
    }
  }

  void _setLevel(String what, double value) {
    switch (_gestures.levels) {
      case SceneSpectrumGesture.off:
        return;
      case SceneSpectrumGesture.event:
        if (what == _levelGrip?.what) _hear(what, value);
      case SceneSpectrumGesture.native:
        final held = (
          value: value,
          over: _number(switch (what) {
            'speed' => _spec.waterfallSpeed,
            'floor' => _spec.floor,
            'waterfallFloor' => _spec.waterfallFloor,
            _ => _spec.range,
          }),
        );
        switch (what) {
          case 'speed':
            _speedHeld = held;
          case 'waterfallFloor':
            _waterfallFloorHeld = held;
          case 'floor':
            _floorHeld = held;
          default:
            _rangeHeld = held;
        }
        _toReport.add(what);
        _reframe();
    }
  }

  /// A double click on the strip: the scene's own floor, range and speed
  /// again, and the scene told so as each at 0 — a scene keeping the
  /// operator's in its own numbers puts its defaults back.
  void _resetLevels() {
    // The waterfall's floor goes back to the scene's too, unannounced: a scene keeps it as a
    // setting, which a reset of the strip's drags is not.
    _floorHeld = _rangeHeld = _speedHeld = _waterfallFloorHeld = null;
    _toReport.removeAll(const ['floor', 'range', 'speed']);
    if (widget.source?.nativeGestures ?? true) {
      for (final what in const ['floor', 'range', 'speed']) {
        widget.onGesture?.call(what, 'commit', 0);
      }
    }
    _reframe();
  }

  void _levelEnd() {
    if (_levelGrip == null) return;
    _levelGrip = null;
    _settle();
  }
}

/// The level strip: dB along the panadapter with no unit, as a radio's scale
/// reads; seconds along the waterfall with theirs, since a bare number there
/// could be anything. Upright it stands at the side, sideways it lies along
/// the top or bottom, its labels upright either way.
class _LevelPainter extends CustomPainter {
  final SpectrumTextCache texts;
  final bool start, turned, mirrored;
  final Rect? Function() pan, fall;
  final (double, double)? Function() scale;
  final double? Function() secondsPerPixel;
  final TextStyle text;
  final Paint tick;
  final double tickLength;
  final Color? background;

  _LevelPainter({
    required Listenable repaint,
    required this.texts,
    required this.start,
    required this.turned,
    required this.mirrored,
    required this.pan,
    required this.fall,
    required this.scale,
    required this.secondsPerPixel,
    required this.text,
    required this.tick,
    required this.tickLength,
    required this.background,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (background case final color?) canvas.drawRect(Offset.zero & size, Paint()..color = color);
    // Positions run along the flow; the ticks reach across it, into the strip from its edge toward the picture.
    Offset point(double along, double across) => turned ? Offset(along, across) : Offset(across, along);
    (double, double) ends(Rect band) => turned ? (band.left, band.right) : (band.top, band.bottom);
    final depth = turned ? size.height : size.width, sign = start ? -1.0 : 1.0;
    final edge = start ? depth - tick.strokeWidth / 2 : tick.strokeWidth / 2;
    canvas.drawLine(point(0, edge), point(turned ? size.width : size.height, edge), tick);
    void mark(double at, String label, {required double from, required double to}) {
      const gap = 2.0;
      canvas.drawLine(point(at, edge), point(at, edge + sign * tickLength), tick);
      final painter = texts.get(label, text);
      final (long, deep) = turned ? (painter.width, painter.height) : (painter.height, painter.width);
      final lead = at - long / 2;
      // A label cut off by its part's edge is left out, its tick kept.
      if (lead < from || lead + long > to) return;
      final near = edge + sign * (tickLength + gap);
      painter.paint(canvas, point(lead, start ? near - deep : near));
    }

    // Side by side, labels need more room between them than stacked.
    final (levelsApart, agesApart) = turned ? (32.0, 40.0) : (18.0, 24.0);
    if ((pan(), scale()) case (final band?, (final floor, final range)) when range > 0) {
      final (from, to) = ends(band);
      if (to > from) {
        final perDb = (to - from) / range, step = spectrumLevelStep(perDb, apart: levelsApart);
        for (var db = (floor / step).ceil() * step; db <= floor + range; db += step) {
          mark(mirrored ? from + (db - floor) * perDb : to - (db - floor) * perDb, db.round().toString(), from: from, to: to);
        }
      }
    }
    if ((fall(), secondsPerPixel()) case (final band?, final perPixel?) when perPixel > 0) {
      final (from, to) = ends(band);
      final step = spectrumAgeStep(1 / perPixel, apart: agesApart);
      for (var seconds = step; seconds / perPixel <= to - from; seconds += step) {
        final label = seconds < 1 ? '${seconds}s' : '${seconds.round()}s';
        mark(mirrored ? to - seconds / perPixel : from + seconds / perPixel, label, from: from, to: to);
      }
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) => true;
}
