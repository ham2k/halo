// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The rubber band: with Alt held, a drag of a line that turns the rotator
// pulls it sideways like a rubber band tied at its two ends, as the band
// scope's line is a bow's string. Let go short of loaded, it twangs back
// straight; loaded, the target spins away the other way from the pull, a few
// turns, and comes to rest on a heading picked at random, where the rotator
// is turned (docs/design/panel-scenes.md § Rotator map).

part of 'scene_rotator.dart';

/// The line [layerId] pulled [pull] pixels across itself — clockwise of it
/// where positive — at [along] of the way from its start to its end.
class _Band {
  _Band(this.layerId, this.rotator);

  final String layerId;
  final String? rotator;
  double along = .5, pull = 0;

  /// Once let go: the pull it swings back from.
  double? swing;

  /// A loaded shot: the target spins from [from] by [degrees] in [spinMs],
  /// and has been sent once [landed].
  double from = 0, degrees = 0, spinMs = 0;
  bool landed = false;

  /// Where the target is drawn while it spins; null otherwise.
  double? target;

  /// When it was let go, by the ticker; null until its first frame.
  Duration? since;
}

/// Both halves of the band leaning [_loadedDegrees] off straight load it; at
/// [_fullDegrees] it stretches no further — the band scope's bow's angles.
const _loadedDegrees = 30.0, _fullDegrees = 60.0;

/// A shot spins [_fewestTurns] whole turns just loaded, [_mostTurns] fully
/// drawn, then on round to where it lands, over [_spinBaseMs] and
/// [_spinPerTurnMs] for each whole turn, slowing all the way.
const _fewestTurns = 2, _mostTurns = 5, _spinBaseMs = 1200.0, _spinPerTurnMs = 350.0;

/// A band let go, and the target come to rest, ring down as
/// amplitude · e^(−t / [_ringTauMs]) at [_ringHz]: the band from its pull,
/// done under half a pixel; the target [_wobbleDegrees] past where it lands
/// the way it spun, done under [_wobbleDoneDegrees].
const _ringHz = 7.0, _ringTauMs = 150.0, _wobbleDegrees = 5.0, _wobbleDoneDegrees = .2;

final _luck = math.Random();

double _bandTan(double degrees) => math.tan(degrees * math.pi / 180);

/// How far [band] may be pulled across a line [length] pixels long for both
/// halves to lean [degrees]: the longer half leans least.
double _bandPullFor(_Band band, double length, double degrees) => math.max(band.along, 1 - band.along) * length * _bandTan(degrees);

bool _bandLoaded(_Band band, double length) => band.pull.abs() >= _bandPullFor(band, length, _loadedDegrees);

/// [amplitude] ringing down [ms] in, through [wave]; null once it swings less than [until].
double? _ringDown(double amplitude, double ms, double until, double Function(double) wave) {
  final fade = math.exp(-ms / _ringTauMs);
  if (amplitude.abs() * fade < until) return null;
  return amplitude * fade * wave(2 * math.pi * _ringHz * ms / 1000);
}

extension _RubberBand on _SceneRotatorViewState {
  bool _drawsBand(_Drawn grabbed) => HardwareKeyboard.instance.isAltPressed && grabbed.layer.kind == SceneRotatorLayerKind.line;

  _Drawn? _banded(_Band band) => _drawn.where((d) => d.layer.id == band.layerId && d.from != null && d.to != null).firstOrNull;

  void _drawBand(_Drawn grabbed, Offset at) {
    _dropBand();
    _band = _Band(grabbed.layer.id, grabbed.layer.rotator);
    _pullBand(at);
  }

  void _pullBand(Offset at) {
    final band = _band!;
    final line = _banded(band);
    if (line == null) return;
    final (a, b) = (line.from!, line.to!);
    final length = (b - a).distance;
    if (length == 0) return;
    final dir = (b - a) / length;
    final p = at - a;
    // Short of either end: tied right at one, the band would bend on a point.
    band.along = ((p.dx * dir.dx + p.dy * dir.dy) / length).clamp(.1, .9);
    final full = _bandPullFor(band, length, _fullDegrees);
    band.pull = (p.dy * dir.dx - p.dx * dir.dy).clamp(-full, full);
    _bandMoved();
  }

  /// Let go, the band swings back straight; loaded, the target spins the
  /// other way from the pull, further the further it was pulled, to a
  /// heading picked at random.
  void _looseBand() {
    final band = _band!;
    final line = _banded(band);
    band
      ..swing = band.pull
      ..since = null;
    final length = line == null ? 0.0 : (line.to! - line.from!).distance;
    // A line of no length has no way across it to pull.
    if (line != null && line.bearing != null && length > 0 && _bandLoaded(band, length)) {
      // A third of a full draw just loaded (tan 30° / tan 60°), all of it fully drawn.
      final share = ((band.pull.abs() / _bandPullFor(band, length, _fullDegrees) - 1 / 3) * 1.5).clamp(0.0, 1.0);
      final turns = (_fewestTurns + share * (_mostTurns - _fewestTurns)).floor();
      final from = line.bearing!;
      final way = -band.pull.sign;
      final onward = ((_stopped(_luck.nextDouble() * 360) - from) * way % 360 + 360) % 360;
      band
        ..from = from
        ..degrees = way * (turns * 360 + onward)
        ..spinMs = _spinBaseMs + _spinPerTurnMs * turns
        ..target = from;
    }
    final spinner = _spinner ??= createTicker(_onBand);
    if (!spinner.isActive) spinner.start();
    _bandMoved();
  }

  void _onBand(Duration elapsed) {
    final band = _band;
    if (band == null || band.swing == null) return _spinner?.stop();
    final ms = (elapsed - (band.since ??= elapsed)).inMicroseconds / 1000;
    band.pull = _ringDown(band.swing!, ms, .5, math.cos) ?? 0;
    if (band.target != null) {
      final landing = band.from + band.degrees;
      if (ms < band.spinMs) {
        band.target = band.from + band.degrees * Curves.easeOutCubic.transform(ms / band.spinMs);
      } else {
        if (!band.landed) {
          band.landed = true;
          if (!widget.disabled) _turn(band.rotator, landing);
        }
        final wobble = _ringDown(_wobbleDegrees, ms - band.spinMs, _wobbleDoneDegrees, math.sin);
        band.target = wobble == null ? null : landing + band.degrees.sign * wobble;
      }
    }
    if (band.pull == 0 && band.target == null) return _dropBand();
    _bandMoved();
  }

  /// Where [uuid]'s target is drawn while a shot spins it.
  double? _spinningTarget(String uuid) {
    final band = _band;
    if (band?.target case final target? when _uuidFor(band!.rotator) == uuid) return (target % 360 + 360) % 360;
    return null;
  }

  /// The band straight again and any shot dropped: a turn or a stop this map
  /// sends overtakes one still spinning, which would land somewhere else.
  void _dropBand() {
    _spinner?.stop();
    if (_band == null) return;
    _band = null;
    _bandMoved();
  }
}
