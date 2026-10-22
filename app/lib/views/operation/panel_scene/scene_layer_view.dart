// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One layer of a scene's artwork — SVG, text or an icon — with its bound
// transforms, transitions and pulse.

part of 'scene_view.dart';

class _SceneLayerView extends StatelessWidget {
  final SceneLayer layer;
  final Map<String, double> values;
  final Map<String, String> strings;
  final bool immediate, reduceMotion;
  const _SceneLayerView({super.key, required this.layer, required this.values, required this.strings, required this.immediate, required this.reduceMotion});
  @override
  Widget build(BuildContext context) {
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
    final target = _Pose(
      layer.bindings['rotation']?.evaluate(values) ?? 0,
      layer.bindings['translateX']?.evaluate(values) ?? 0,
      layer.bindings['translateY']?.evaluate(values) ?? 0,
      (layer.bindings['opacity']?.evaluate(values) ?? 1).clamp(0, 1).toDouble(),
      layer.bindings['scaleX']?.evaluate(values) ?? 1,
      layer.bindings['scaleY']?.evaluate(values) ?? 1,
    );
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
            child: Opacity(opacity: pose.opacity, child: child),
          ),
        ),
      ),
    );
  }
}

class _Pose {
  final double angle, x, y, opacity, sx, sy;
  const _Pose(this.angle, this.x, this.y, this.opacity, this.sx, this.sy);
  @override
  bool operator ==(Object other) =>
      other is _Pose && other.angle == angle && other.x == x && other.y == y && other.opacity == opacity && other.sx == sx && other.sy == sy;
  @override
  int get hashCode => Object.hash(angle, x, y, opacity, sx, sy);
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({required super.end});
  @override
  _Pose lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    double mix(double x, double y) => x + (y - x) * t;
    return _Pose(mix(a.angle, b.angle), mix(a.x, b.x), mix(a.y, b.y), mix(a.opacity, b.opacity), mix(a.sx, b.sx), mix(a.sy, b.sy));
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
