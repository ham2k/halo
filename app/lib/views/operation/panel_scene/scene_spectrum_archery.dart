// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Archery: with Alt held, a drag of the tuned frequency's line draws it like
// a bow's string, tied at the spectrum's two ends. Let go short of loaded,
// it twangs back straight; loaded, the line itself flies off out of the
// still window, further and faster the wider the window — up to 300 kHz,
// within the band — then the window chases it, overtakes it, and is at rest
// there to watch it land and quiver (docs/design/panel-scenes.md § Spectrum).

part of 'scene_spectrum.dart';

enum _BowPhase { drawn, twang, flight, quiver }

/// The tuned frequency's line as a bow's string, tied at [hz] at both ends
/// of the spectrum, its nock pulled [pull] pixels along the frequency at
/// [nockY] across it, in the spectrum's own frame. In flight the line is the
/// arrow, at [hz] on its way from [from] to [target], [pull] its arch.
class _Bow {
  _Bow(this.hz, this.nockY);

  double hz, nockY, pull = 0;
  _BowPhase phase = _BowPhase.drawn;

  /// The pull a let-go string swings from as it settles.
  double swing = 0;

  double? from, target;

  /// How long the arrow is in the air, and how far into it the window sets
  /// off after it, in ms, and whether it has.
  double flightMs = 0, chaseAt = 0;
  bool chasing = false;

  /// When the phase began, by the ticker; null until its first frame.
  Duration? since;
}

/// Both halves of the string leaning [_loadedDegrees] off straight load it;
/// at [_fullDegrees] it stretches no further. A loaded shot flies a share of
/// a full draw's by how far the string was pulled: a third of it as it
/// loads, all of it fully drawn.
const _loadedDegrees = 30.0, _fullDegrees = 60.0;

/// A full draw flies [_shotWidths] of the window's width, no further than
/// [_maxShotHz], at [_arrowWidthsPerSecond]: 100 kHz in 1.1 s from a window
/// 15 kHz wide, which reads the same at any width, so a wider window shoots
/// further and faster, until the furthest shot flies sooner.
const _shotWidths = 100 / 15, _maxShotHz = 300000.0, _arrowWidthsPerSecond = _shotWidths / 1.1;

/// The window sets off after the arrow once it is out of sight — but at
/// least [_chaseShare] of the flight before it must be at rest, and at rest
/// [_watchShare] of it ahead of the arrow landing — so it always overtakes
/// it. No flight is shorter than [_minFlightMs]: a shot landing beside the
/// dial, at the band's edge, still reads as one.
const _chaseShare = .27, _watchShare = .18, _minFlightMs = 150.0;

/// How far past the window's edge the arrow is out of sight, as a share of
/// the window's width, and how far back from straight its middle trails as
/// it flies, in pixels.
const _outOfSight = .03, _archPx = 8.0;

/// A let-go string swings as swing · e^(−t / [_twangTauMs]) · cos(2π · [_twangHz] · t),
/// done once that is under half a pixel; one arriving from a shot swings
/// from [_quiverPx] the way it flew.
const _twangHz = 7.0, _twangTauMs = 150.0, _quiverPx = 32.0;

BandInfo? _bandOf(double hz) => bands.where((band) => hz >= band.minKHz * 1000 && hz <= band.maxKHz * 1000).firstOrNull;

double _tan(double degrees) => math.tan(degrees * math.pi / 180);

/// How far [bow]'s nock may be pulled across a spectrum [height] deep for
/// both halves to lean [degrees]: the longer half leans least.
double _pullFor(_Bow bow, double height, double degrees) => math.max(bow.nockY, height - bow.nockY) * _tan(degrees);

bool _loaded(_Bow bow, double height) => bow.pull.abs() >= _pullFor(bow, height, _loadedDegrees);

extension _Archery on _SceneSpectrumViewState {
  /// Alt held on the line, where tunes go to the radio from the app: a
  /// shot's flight is the app's own move of the window.
  bool _drawsBow(Offset at) => HardwareKeyboard.instance.isAltPressed && _tunesNatively && _dialAt(at) != null;

  /// The dial as the marks draw it: none while a shot is in flight, when the
  /// line is the arrow, not yet where the dial is.
  double? _drawnDial() => _bow?.phase == _BowPhase.flight ? null : _vfo;

  void _drawBow(Offset at) {
    final vfo = _vfo;
    if (vfo == null) return;
    _archer.stop();
    _bow = _Bow(vfo, _canonicalAt(at).dy.clamp(0.0, _laidOut.height));
    _strummed();
  }

  void _pullBow(Offset at) {
    final (bow, frame, width) = (_bow!, _frame, _laidOut.width);
    if (frame == null || width <= 0 || frame.highHz <= frame.lowHz) return;
    final c = _canonicalAt(at);
    bow.nockY = c.dy.clamp(0.0, _laidOut.height);
    final full = _pullFor(bow, _laidOut.height, _fullDegrees);
    bow.pull = (c.dx - (bow.hz - frame.lowHz) / (frame.highHz - frame.lowHz) * width).clamp(-full, full);
    _panRepaint.value++;
  }

  /// Let go, the string swings back straight; loaded, the line flies the
  /// other way from the pull as the arrow, to where the dial goes, on the
  /// coarse step.
  void _looseBow() {
    final (bow, frame) = (_bow!, _frame);
    bow.swing = bow.pull;
    if (!_loaded(bow, _laidOut.height) || frame == null) {
      bow.phase = _BowPhase.twang;
    } else {
      final width = (frame.highHz - frame.lowHz).toDouble();
      final share = bow.pull.abs() / _pullFor(bow, _laidOut.height, _fullDegrees);
      final step = _coarseStep();
      var target = bow.hz - bow.pull.sign * share * math.min(_maxShotHz, _shotWidths * width);
      if (step != null) target = (target / step).round() * step;
      // No further than the band the dial was in: past its edge is somewhere the operator cannot transmit.
      if (_bandOf(bow.hz) case final band?) target = target.clamp(band.minKHz * 1000, band.maxKHz * 1000);
      final from = bow.hz;
      // Out of sight past the edge it flies toward; a shot landing in sight is chased only to be centred.
      final ahead = (target > from ? frame.highHz - from : from - frame.lowHz) + _outOfSight * width;
      final distance = (target - from).abs();
      final flight = math.max(_minFlightMs, distance / (_arrowWidthsPerSecond * width) * 1000);
      bow
        ..phase = _BowPhase.flight
        ..from = from
        ..target = target
        ..pull = (from - target).sign * _archPx
        ..chasing = false
        ..flightMs = flight
        ..chaseAt = distance <= 0 ? 0 : math.min(flight * ahead / distance, flight * (1 - _watchShare - _chaseShare));
    }
    bow.since = null;
    _strummed();
    if (!_archer.isActive) _archer.start();
  }

  void _onBow(Duration elapsed) {
    final bow = _bow;
    if (bow == null) return _archer.stop();
    final ms = (elapsed - (bow.since ??= elapsed)).inMicroseconds / 1000;
    switch (bow.phase) {
      case _BowPhase.drawn:
        return;
      case _BowPhase.flight:
        final (from, target) = (bow.from!, bow.target!);
        bow.hz = from + (target - from) * math.min(1, ms / bow.flightMs);
        _panRepaint.value++;
        if (!bow.chasing && ms >= bow.chaseAt) {
          bow.chasing = true;
          // The radio goes as the window does, not as the arrow leaves: a scope centred on the
          // dial would carry the window off with it, and the arrow would leave nothing behind.
          _holdDial(target);
          _tuneTo(target);
          // Slow to set off, quick to close: it catches the arrow up mid-chase and stops short of its landing.
          _glideTo(target, ms: (bow.flightMs * (1 - _watchShare) - bow.chaseAt).round(), curve: Curves.easeInOutCubic);
        }
        if (ms < bow.flightMs) return;
        bow
          ..phase = _BowPhase.quiver
          ..swing = (target - from).sign * _quiverPx
          ..hz = target
          ..nockY = _laidOut.height / 2
          ..pull = bow.swing
          ..since = elapsed;
        _strummed();
      case _BowPhase.twang || _BowPhase.quiver:
        final pull = _swung(bow.swing, ms);
        if (pull == null) return _unstring();
        bow.pull = pull;
        _panRepaint.value++;
    }
  }

  /// A string let go from [swing], [ms] on; null once it has settled.
  double? _swung(double swing, double ms) {
    final fade = math.exp(-ms / _twangTauMs);
    if (swing.abs() * fade < .5) return null;
    return swing * fade * math.cos(2 * math.pi * _twangHz * ms / 1000);
  }

  /// The string straight again, the line drawn as ever.
  void _unstring() {
    _archer.stop();
    if (_bow == null) return;
    _bow = null;
    _strummed();
  }

  /// Every part redrawn: the string and the line are in all of them.
  void _strummed() {
    _panRepaint.value++;
    _waterfallRepaint.value++;
  }
}

/// The bow's string, over the whole spectrum, in place of the tuned frequency's line.
class _BowPainter extends CustomPainter {
  final _Way way;
  final _Bow? Function() bow;
  final SpectrumFrame? Function() frame;
  final Color color;
  final double width;

  _BowPainter({required Listenable repaint, required this.way, required this.bow, required this.frame, required this.color, required this.width})
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size screen) => _inFlow(canvas, screen, way, (size) {
    final (b, current) = (bow(), frame());
    if (b == null || current == null || current.highHz <= current.lowHz) return;
    final x = (b.hz - current.lowHz) / (current.highHz - current.lowHz) * size.width;
    final line = Path()..moveTo(x, 0);
    if (b.phase == _BowPhase.flight) {
      // The arrow arched, its middle [pull] behind its ends.
      line.quadraticBezierTo(x + 2 * b.pull, size.height / 2, x, size.height);
    } else {
      line
        ..lineTo(x + b.pull, b.nockY)
        ..lineTo(x, size.height);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        // Thicker once loaded: the operator can feel for the point a shot flies.
        ..strokeWidth = b.phase == _BowPhase.drawn && _loaded(b, size.height) ? width + 1 : width
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  });

  @override
  bool shouldRepaint(_BowPainter old) => true;
}
