// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// How a spectrum keeps the dial in view as it moves — chasing a spin,
// gliding to a jump, at once to a band change — and how the dial's label
// keeps its digits while it moves (docs/design/panel-scenes.md § Band scope).

part of 'scene_spectrum.dart';

/// How long, in ms, a jump of the dial — a click, a memory, a frequency
/// typed in — must stand before the window glides to it: a run of clicks
/// glides once, from the last, rather than jerking the picture to each.
const _jumpRestMs = 200;

/// The furthest a window glides, in its own widths; it is at a jump further
/// than that — a band change — at once.
const _glideWidths = 3;

/// How long, in ms, the dial must stand before its label drops the zeros it
/// kept while it moved, and how long a digit takes to come or go.
const _labelSettleMs = 300, _labelDigitMs = 150;

/// A move of the dial of at most this share of the window's width is a step
/// of a spin — a knob, the wheel, a trackpad, a drag of the line, whatever
/// turns it — which the window chases; a longer one is a jump.
const _spinStepShare = .1;

/// How closely, in ms, the window chases a spinning dial: the time it takes
/// to close two thirds of the way. It trails a spin by as far as the dial
/// goes in this time, so a slow one closely and a fast one further.
const _chaseMs = 120;

extension _SpectrumFollow on _SceneSpectrumViewState {
  /// Keeps the label's digits while the dial moves; see [_SceneSpectrumViewState._labelDigits].
  /// The frequency the dial's label shows: the dial's, but on the fine step
  /// while its line is dragged, which moves it smoothly through every Hz.
  double? get _labelHz {
    final (vfo, fine) = (_vfo, _dial == null ? null : _fineStep());
    return vfo == null || fine == null || fine <= 0 ? vfo : (vfo / fine).round() * fine;
  }

  void _labelDial() {
    final vfo = _labelHz;
    if (vfo == null || vfo == _labelledVfo) return;
    final first = _labelledVfo == null;
    _labelledVfo = vfo;
    final digits = spectrumVfoDigits(vfo).toDouble();
    if (first) {
      _labelDigits.value = _labelTarget = digits;
      return;
    }
    // Every digit shown or on its way stays while the dial moves, one being dropped included.
    final keep = math.max(digits, _labelDigits.value.ceilToDouble());
    if (keep != _labelTarget) _labelDigits.animateTo(_labelTarget = keep);
    _labelSettle?.cancel();
    _labelSettle = Timer(const Duration(milliseconds: _labelSettleMs), () {
      _labelSettle = null;
      final hz = mounted ? _labelHz : null;
      if (hz == null) return;
      final settled = spectrumVfoDigits(hz).toDouble();
      if (settled != _labelTarget) _labelDigits.animateTo(_labelTarget = settled);
    });
  }

  /// [SceneSpectrumSpec.follow]: with the tuned frequency inside the margin
  /// at either edge — or off the window altogether — the window moves just
  /// far enough to put it ON that margin, so the picture scrolls with the
  /// dial rather than jumping to centre it — a crop within the sweep, the
  /// scope where it is not. A spinning dial the window chases, trailing it
  /// by as much as it is spun faster; a jump it glides to once the dial has
  /// stood [_jumpRestMs], as an edge click does; a jump of more than
  /// [_glideWidths] — a band change — it is at at once, since a glide there
  /// would sweep across frequencies the operator never tuned.
  void _keepInView(int now) {
    final (margin, frame, vfo) = (_spec.follow, _frame, _vfo);
    if (margin == null || frame == null || vfo == null || _uuid == null || widget.source == null) return;
    final width = (frame.highHz - frame.lowHz).toDouble();
    if (width <= 0) return;
    _noteDial(now, width);
    if (_pannedAtVfo != null) {
      if (vfo == _pannedAtVfo) return;
      _pannedAtVfo = null;
    }
    if (!_spinning || _dial != null) _chaser.stop();
    // A dragged line pans the window itself, keeping the dial under the pointer; a jump's glide
    // is waiting for the dial to stand; or a shot flies the window there itself.
    if (_dial != null || _edgeGlide != null || _bow != null) return;
    final center = _keptCenter(vfo, frame, margin);
    if (center == null) return;
    if ((center - (frame.lowHz + frame.highHz) / 2).abs() > _glideWidths * width) {
      _chaser.stop();
      return _glideTo(center, jump: true);
    }
    if (_spinning) return _chase();
    // A glide already on its way there.
    if (_glideSpan case (_, final to) when (to - center).abs() < 1) return;
    final wait = _jumpRestMs - (now - _vfoMovedMillis);
    if (wait > 0) {
      _edgeGlide = Timer(Duration(milliseconds: wait), () {
        _edgeGlide = null;
        if (mounted) _keepInView(realNowMillis());
      });
      return;
    }
    // Held absolute by the glide, so the window waits there for the sweeps to catch up rather than snapping back.
    _glideTo(center);
  }

  /// Where the window's middle goes to put [vfo] on [margin] of [frame]'s
  /// width in from its nearer edge; null where it is already further in.
  double? _keptCenter(double vfo, SpectrumFrame frame, double margin) {
    final width = (frame.highHz - frame.lowHz).toDouble(), edge = margin * width;
    if (vfo < frame.lowHz + edge) return vfo + (.5 - margin) * width;
    if (vfo > frame.highHz - edge) return vfo - (.5 - margin) * width;
    return null;
  }

  void _chase() {
    if (_glideSpan != null) {
      _glide.stop();
      _glideSpan = null;
    }
    if (_chaser.isActive) return;
    _chasedAt = null;
    _chaseFree = _viewCenter == null && _releaseAt == null;
    _chaser.start();
  }

  /// A frame of the chase: the window closes on where the dial needs it by
  /// the share of the way [_chaseMs] says for the time since the last.
  void _onChase(Duration elapsed) {
    final ms = _chasedAt == null ? 1000 / 60 : (elapsed - _chasedAt!).inMicroseconds / 1000;
    _chasedAt = elapsed;
    final (frame, vfo, margin) = (_frame, _vfo, _spec.follow);
    final target = frame == null || vfo == null || margin == null ? null : _keptCenter(vfo, frame, margin);
    if (target == null) return _endChase();
    final from = _viewCenter ?? (frame!.lowHz + frame.highHz) / 2;
    if ((target - from).abs() < (frame!.highHz - frame.lowHz) / 2000) return _endChase(at: target);
    _moveTo(from + (target - from) * (1 - math.exp(-ms / _chaseMs)));
    _reframe();
    // Held against the sweep's edge, on a scope that will not move: as far as it goes.
    if (_viewCenter == from) _endChase();
  }

  void _endChase({double? at}) {
    _chaser.stop();
    if (at != null) {
      _moveTo(at, last: true);
      _reframe();
    }
    // A window that was the radio's sweep is its sweeps' again once they arrive from where it was taken.
    _releaseAt = _chaseFree && _recenters == true ? _viewCenter : null;
  }

  /// Marks when the dial last moved, as soon as the radio says so, for follow's rest.
  void _noteDial(int now, double width) {
    final (vfo, was) = (_vfo, _followedVfo);
    if (vfo == was) return;
    _followedVfo = vfo;
    // The dial first seen has not moved: a panel opened on a dial off the window brings it in at once.
    if (vfo == null || was == null) return;
    _vfoMovedMillis = now;
    _spinning = (vfo - was).abs() <= _spinStepShare * width;
  }
}
