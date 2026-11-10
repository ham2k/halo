// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One layer of a scene's artwork — SVG, text or an icon — with its bound
// transforms, transitions and pulse.

part of 'scene_view.dart';

class _SceneLayerView extends StatefulWidget {
  final SceneLayer layer;
  final Map<String, double> values;
  final Map<String, String> strings;
  final bool immediate, reduceMotion;
  const _SceneLayerView({super.key, required this.layer, required this.values, required this.strings, required this.immediate, required this.reduceMotion});

  @override
  State<_SceneLayerView> createState() => _SceneLayerViewState();
}

/// A binding's `hold`: the highest reading it has seen, and when, on the ticker's clock. The ticker
/// runs only while a held reading stands above the live one; the layer redraws only when what a
/// binding shows moves.
class _SceneLayerViewState extends State<_SceneLayerView> with SingleTickerProviderStateMixin {
  /// Made the first time a binding holds: most layers hold nothing, and a scene may have hundreds.
  Ticker? _ticker;
  Duration _now = Duration.zero;
  final _held = <String, ({double peak, Duration at})>{};
  final _shown = <String, double>{};

  bool get _ticking => _ticker?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_SceneLayerView old) {
    super.didUpdateWidget(old);
    // A peak belongs to the reading it was held from: a binding moved to another value, or ramped
    // or held differently, starts over rather than showing the old reading's peak on the new ramp.
    for (final key in [..._held.keys]) {
      final was = old.layer.bindings[key], now = widget.layer.bindings[key];
      if (now?.hold == null || was == null || !_sameHold(was, now!)) {
        _held.remove(key);
        _shown.remove(key);
      }
    }
    _sync();
  }

  static bool _sameHold(SceneBinding a, SceneBinding b) =>
      a.value == b.value && a.scale == b.scale && a.truncate == b.truncate && listEquals(a.input, b.input) && a.hold == b.hold;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    final before = Map.of(_shown);
    _sync();
    if (_shown.entries.any((e) => before[e.key] != e.value)) setState(() {});
  }

  /// Brings each held binding up to the live reading, or holds and then lets it fall once the
  /// reading drops below its peak. The hold counts from the last moment the reading was at the
  /// peak, so a steady reading never holds at all and the ticker stops. A missing reading
  /// (negative infinity) lets a peak fall to the bottom of the range, as a low one would.
  void _sync() {
    var active = false;
    for (final MapEntry(:key, value: binding) in widget.layer.bindings.entries) {
      final hold = binding.hold;
      if (hold == null) continue;
      // Above the top of the range a reading draws the same as at the top: a peak held from higher
      // would fall for seconds with nothing on screen moving.
      final live = math.min(widget.values[binding.value]!, binding.input[1] / binding.scale);
      var held = _held[key];
      if (held == null || live >= held.peak) {
        _held[key] = (peak: live, at: _now);
        _shown[key] = live;
        continue;
      }
      // Dropped below the peak with the ticker stopped: the hold starts now, on a clock it restarts.
      if (!_ticking) {
        _now = Duration.zero;
        held = _held[key] = (peak: held.peak, at: Duration.zero);
      }
      final standing = (_now - held.at).inMicroseconds / 1000 - hold.ms;
      final fallen = standing <= 0 ? held.peak : held.peak - hold.fallPerSecond * standing / 1000;
      // A held binding's scale is positive (the parser's rule), so the bottom of its range is this.
      final floor = live.isFinite ? live : binding.input[0] / binding.scale;
      // Not above the floor, NaN included: done, or a reading no fall would ever meet would keep
      // the ticker running.
      if (!(fallen > floor)) {
        _held[key] = (peak: live, at: _now);
        _shown[key] = live;
      } else {
        _shown[key] = fallen;
        active = true;
      }
    }
    if (active && !_ticking) {
      (_ticker ??= createTicker(_tick)).start();
    } else if (!active && _ticking) {
      _ticker!.stop();
    }
  }

  /// The values [binding] reads, its held reading in place of the live one.
  Map<String, double> _valuesFor(String key, SceneBinding binding) {
    final shown = _shown[key];
    return binding.hold == null || shown == null ? widget.values : {...widget.values, binding.value: shown};
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer, values = widget.values, strings = widget.strings;
    final immediate = widget.immediate, reduceMotion = widget.reduceMotion;
    final text = layer.text;
    final samples = text?['samples'] as List<dynamic>?;
    final bound = strings[text?['value']];
    final rawValue = text?['value'] == null || bound != null ? 0.0 : values[text!['value']]!;
    final sampledValue = bound ?? (samples == null || !rawValue.isFinite ? rawValue : samples[rawValue.round().clamp(0, samples.length - 1)]);
    var textValue = sampledValue is num ? sampledValue * (text?['scale'] as num? ?? 1) : sampledValue;
    // A radio value with no reading is negative infinity, which floor() and round() throw on.
    if (textValue is num && textValue.isFinite) {
      if (text?['truncate'] == true) textValue = (textValue + 1e-7).floor();
      if (text?['modulo'] case final num modulus) textValue = textValue % modulus;
    }
    final decimals = (text?['decimals'] as num? ?? 0).toInt();
    // A radio value with no reading.
    final formatted = textValue is num && !textValue.isFinite
        ? '—'
        : textValue is num
        ? textValue.toStringAsFixed(decimals).padLeft((text?['minIntegerDigits'] as num? ?? 1).toInt() + (decimals > 0 ? decimals + 1 : 0), '0')
        : textValue.toString();
    final icon = layer.icon;
    Widget artwork = icon != null
        ? FittedBox(child: Icon(resolveIconName(icon.name), color: icon.color))
        : layer.svg != null
        ? SvgPicture.string(layer.svg!, fit: BoxFit.fill, errorBuilder: (_, error, stack) => const Icon(MdiIcons.imageBroken))
        : Align(
            alignment: switch (text?['align']) {
              'center' => Alignment.center,
              'end' => AlignmentDirectional.centerEnd,
              _ => AlignmentDirectional.centerStart,
            },
            child: Text(
              text!['literal'] as String? ?? '${text['prefix'] ?? ''}$formatted${text['suffix'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (text['size'] as num? ?? 20).toDouble(),
                fontFeatures: const [FontFeature.tabularFigures()],
                fontFamily: text['fontFamily'] as String? ?? Theme.of(context).textTheme.bodyMedium?.fontFamily,
                fontFamilyFallback: Theme.of(context).textTheme.bodyMedium?.fontFamilyFallback,
                fontWeight: FontWeight.values[((text['fontWeight'] as num? ?? 400) / 100).round().clamp(1, 9) - 1],
                height: (text['lineHeight'] as num? ?? 1.2).toDouble(),
                letterSpacing: (text['letterSpacing'] as num? ?? 0).toDouble(),
                color: text['color'] == null ? null : Color(0xff000000 | int.parse((text['color'] as String).substring(1), radix: 16)),
                // A halo that keeps light text legible over whatever it is drawn on: a tight
                // shadow for the edge, a wider one for the glow.
                shadows: switch (text['glow']) {
                  final String glow => [
                    for (final blur in const [1.5, 4.0]) Shadow(color: Color(0xff000000 | int.parse(glow.substring(1), radix: 16)), blurRadius: blur),
                  ],
                  _ => null,
                },
              ),
            ),
          );
    artwork = RepaintBoundary(child: artwork);
    if (layer.pulse != null && !reduceMotion) {
      artwork = _Pulse(config: layer.pulse!, child: artwork);
    }
    // A single tween interpolates the four properties without rebuilding the
    // artwork. flutter_svg caches unchanged source; no XML parsing per frame.
    double? boundAt(String key) => switch (layer.bindings[key]) {
      final binding? => binding.evaluate(_valuesFor(key, binding)),
      null => null,
    };
    final opacity = layer.bindings['opacity'];
    final target = _Pose(
      boundAt('rotation') ?? 0,
      boundAt('translateX') ?? 0,
      boundAt('translateY') ?? 0,
      layer.opacityAt(opacity == null ? values : _valuesFor('opacity', opacity), strings),
      boundAt('scaleX') ?? 1,
      boundAt('scaleY') ?? 1,
      (boundAt('clipX') ?? 1).clamp(0.0, 1.0),
      (boundAt('clipY') ?? 1).clamp(0.0, 1.0),
    );
    final reveals = layer.bindings.containsKey('clipX') || layer.bindings.containsKey('clipY');
    // Inside the transforms, so a blocking layer blocks where it is drawn;
    // and only while it can be seen, as with controls, or a layer faded out
    // would leave the controls under it dead.
    artwork = layer.blocksPointer && target.opacity > 0 ? AbsorbPointer(child: artwork) : IgnorePointer(child: artwork);
    return TweenAnimationBuilder<_Pose>(
      tween: _PoseTween(end: target),
      duration: Duration(milliseconds: immediate ? 0 : layer.transitionMs),
      curve: Curves.easeOut,
      child: artwork,
      builder: (_, pose, child) => Transform.translate(
        offset: Offset(pose.x, pose.y),
        child: Transform.rotate(
          angle: pose.angle * math.pi / 180,
          alignment: layer.pivot,
          child: Transform(
            transform: Matrix4.diagonal3Values(pose.sx, pose.sy, 1),
            alignment: layer.pivot,
            child: Opacity(
              opacity: pose.opacity,
              child: reveals ? ClipRect(clipper: _Reveal(pose.cx, pose.cy, layer.pivot), child: child) : child,
            ),
          ),
        ),
      ),
    );
  }
}

class _Pose {
  /// [cx] and [cy]: the share of the layer shown across and down, by `clipX` and `clipY`.
  final double angle, x, y, opacity, sx, sy, cx, cy;
  const _Pose(this.angle, this.x, this.y, this.opacity, this.sx, this.sy, this.cx, this.cy);
  @override
  bool operator ==(Object other) =>
      other is _Pose &&
      other.angle == angle &&
      other.x == x &&
      other.y == y &&
      other.opacity == opacity &&
      other.sx == sx &&
      other.sy == sy &&
      other.cx == cx &&
      other.cy == cy;
  @override
  int get hashCode => Object.hash(angle, x, y, opacity, sx, sy, cx, cy);
}

/// The share of a layer `clipX` and `clipY` show, growing from its pivot as `scaleX` does: a pivot
/// at the left shows the left end first, one at the middle grows out both ways. Unlike a scale, the
/// artwork keeps its shape, so a bar of LED segments lights segment by segment rather than squashing.
class _Reveal extends CustomClipper<Rect> {
  final double across, down;
  final Alignment pivot;
  const _Reveal(this.across, this.down, this.pivot);

  @override
  Rect getClip(Size size) {
    final w = size.width * across, h = size.height * down;
    return Rect.fromLTWH((size.width - w) * (pivot.x + 1) / 2, (size.height - h) * (pivot.y + 1) / 2, w, h);
  }

  @override
  bool shouldReclip(_Reveal old) => old.across != across || old.down != down || old.pivot != pivot;
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({required super.end});
  @override
  _Pose lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    double mix(double x, double y) => x + (y - x) * t;
    return _Pose(
      mix(a.angle, b.angle),
      mix(a.x, b.x),
      mix(a.y, b.y),
      mix(a.opacity, b.opacity),
      mix(a.sx, b.sx),
      mix(a.sy, b.sy),
      mix(a.cx, b.cx),
      mix(a.cy, b.cy),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Map<dynamic, dynamic> config;
  final Widget child;
  const _Pulse({required this.config, required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.config['periodMs'] as num).round()),
  )..repeat();
  @override
  void initState() {
    super.initState();
    _clock;
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (old.config['periodMs'] != widget.config['periodMs']) {
      _clock.duration = Duration(milliseconds: (widget.config['periodMs'] as num).round());
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    child: widget.child,
    builder: (_, child) {
      final phase = _clock.value * math.pi * 2;
      final wave = widget.config['flicker'] == true ? (math.sin(phase * 7) + math.sin(phase * 13) + 2) / 4 : (math.sin(phase) + 1) / 2;
      final min = (widget.config['minOpacity'] as num).toDouble();
      return Opacity(opacity: min + (1 - min) * wave, child: child);
    },
  );
}
