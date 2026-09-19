// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'scene_model.dart';

typedef SceneEventHandler = Future<Map<String, double>> Function(Map<String, dynamic> event);

/// The extension supplies state; this widget owns gestures and animation frames.
/// Only committed controls cross the bridge in the prototype. Chart inspection
/// and intermediate drag positions remain entirely local.
class SvgSceneView extends StatefulWidget {
  final SvgScene scene;
  final SceneEventHandler? onEvent;
  const SvgSceneView({super.key, required this.scene, this.onEvent});
  @override
  State<SvgSceneView> createState() => _SvgSceneViewState();
}

class _SvgSceneViewState extends State<SvgSceneView> with WidgetsBindingObserver {
  late Map<String, double> _values;
  final _active = <String>{};
  final _dirty = <String>{};
  final _queue = <String, Map<String, dynamic>>{};
  bool _sending = false;
  bool _appVisible = true;
  int _sequence = 0;
  /// Whether the last action failed. A flag, not the message: the banner is
  /// translated when it is built, so it follows a locale change.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _values = {...widget.scene.values};
    WidgetsBinding.instance.addObserver(this);
    _appVisible = _visible(WidgetsBinding.instance.lifecycleState);
  }

  bool _visible(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appVisible = _visible(state));
  }

  @override
  void didUpdateWidget(SvgSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Local-only values (inspection cursor) survive document refreshes.
    final local = widget.scene.controls.where((c) => c.event == null).map((c) => c.value).toSet();
    _values = {
      for (final entry in widget.scene.values.entries)
        entry.key: (_dirty.contains(entry.key) || _active.contains(entry.key) || local.contains(entry.key))
            ? _values[entry.key] ?? entry.value
            : entry.value,
    };
  }

  void _change(SceneControl control, double value) {
    setState(() {
      if (control.event != null) _sequence++;
      _values[control.value!] = control.clamp(value);
      _dirty.add(control.value!);
    });
    if (control.continuous) _sendControl(control, 'change');
  }

  void _commit(SceneControl control) {
    _active.remove(control.value);
    _sendControl(control, control.kind == 'button' ? 'activate' : 'commit');
  }

  void _sendControl(SceneControl control, String phase, {String? action}) {
    if ((control.event == null && action == null) || widget.onEvent == null) {
      _dirty.remove(control.value);
      return;
    }
    final event = <String, dynamic>{
      'controlId': control.id,
      'action': action ?? control.event,
      'phase': phase,
      'sequence': ++_sequence,
      if (control.value != null) 'value': _values[control.value],
    };
    // Buttons are disabled while outstanding; repeated control commits keep
    // only their newest desired value. Bound by the scene's 64 controls.
    // Move a replacement to the end, preserving commit order across controls
    // that share a value (for example a tuning knob and its band slider).
    _queue.remove(control.id);
    _queue[control.id] = event;
    setState(() => _failed = false);
    _drain();
  }

  Future<void> _drain() async {
    if (_sending) return;
    _sending = true;
    while (mounted && _queue.isNotEmpty) {
      final id = _queue.keys.first;
      final event = _queue.remove(id)!;
      try {
        final patch = await widget.onEvent!(event).timeout(const Duration(seconds: 5));
        if (!mounted) return;
        if (event['sequence'] == _sequence) {
          setState(() {
            for (final entry in patch.entries) {
              if (_values.containsKey(entry.key) && !_active.contains(entry.key)) {
                _values[entry.key] = entry.value;
              }
            }
            _dirty.removeWhere((key) => !_active.contains(key));
          });
        }
      } catch (_) {
        if (!mounted) return;
        if (event['sequence'] == _sequence) {
          setState(() {
            _failed = true;
            for (final key in _dirty) {
              if (!_active.contains(key) && widget.scene.values.containsKey(key)) {
                _values[key] = widget.scene.values[key]!;
              }
            }
            _dirty.removeWhere((key) => !_active.contains(key));
          });
        }
      }
    }
    _sending = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queue.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final awake = _appVisible && DockPaneVisibility.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ExcludeFocus(
      excluding: !awake,
      child: ExcludeSemantics(
        excluding: !awake,
        child: Column(
          children: [
            if (_failed)
              MaterialBanner(
                content: Text(context.t.operation.layout.panelActionFailed),
                actions: [
                  TextButton(onPressed: () => setState(() => _failed = false), child: Text(context.t.common.dismiss)),
                ],
              ),
            Expanded(
              child: TickerMode(
                enabled: awake && !reduceMotion,
                child: IgnorePointer(
                  ignoring: !awake,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: scene.width,
                        height: scene.height,
                        child: ClipRect(
                          child: Stack(
                            children: [
                              for (final layer in scene.layers)
                                Positioned.fromRect(
                                  rect: layer.rect,
                                  child: _SceneLayerView(
                                    key: ValueKey(layer.id),
                                    layer: layer,
                                    values: _values,
                                    immediate:
                                        reduceMotion || layer.bindings.values.any((b) => _dirty.contains(b.value)),
                                    reduceMotion: reduceMotion,
                                  ),
                                ),
                              for (final control in scene.controls)
                                Positioned.fromRect(
                                  rect: control.rect,
                                  child: _ControlView(
                                    key: ValueKey(control.id),
                                    control: control,
                                    value: _values[control.value] ?? 0,
                                    disabled: control.kind == 'button' && _sending,
                                    onStart: () => _active.add(control.value ?? ''),
                                    onCancel: () {
                                      setState(() {
                                        _active.remove(control.value);
                                        _dirty.remove(control.value);
                                        if (control.value != null) {
                                          _values[control.value!] = scene.values[control.value]!;
                                        }
                                      });
                                    },
                                    onChange: (v) => _change(control, v),
                                    onCommit: () => _commit(control),
                                    onSelect: (action) => _sendControl(control, 'activate', action: action),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneLayerView extends StatelessWidget {
  final SceneLayer layer;
  final Map<String, double> values;
  final bool immediate, reduceMotion;
  const _SceneLayerView({
    super.key,
    required this.layer,
    required this.values,
    required this.immediate,
    required this.reduceMotion,
  });
  @override
  Widget build(BuildContext context) {
    final text = layer.text;
    final samples = text?['samples'] as List<dynamic>?;
    final rawValue = text?['value'] == null ? 0.0 : values[text!['value']]!;
    final sampledValue = samples == null ? rawValue : samples[rawValue.round().clamp(0, samples.length - 1)];
    var textValue = sampledValue is num ? sampledValue * (text?['scale'] as num? ?? 1) : sampledValue;
    if (textValue is num) {
      if (text?['truncate'] == true) textValue = (textValue + 1e-7).floor();
      if (text?['modulo'] case final num modulus) textValue = textValue % modulus;
    }
    final decimals = (text?['decimals'] as num? ?? 0).toInt();
    final formatted = textValue is num
        ? textValue
              .toStringAsFixed(decimals)
              .padLeft((text?['minIntegerDigits'] as num? ?? 1).toInt() + (decimals > 0 ? decimals + 1 : 0), '0')
        : textValue.toString();
    Widget artwork = layer.svg != null
        ? SvgPicture.string(
            layer.svg!,
            fit: BoxFit.fill,
            errorBuilder: (_, error, stack) => const Icon(MdiIcons.imageBroken),
          )
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
                color: text['color'] == null
                    ? null
                    : Color(0xff000000 | int.parse((text['color'] as String).substring(1), radix: 16)),
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
    );
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
          child: Opacity(opacity: pose.opacity, child: child),
        ),
      ),
    );
  }
}

class _Pose {
  final double angle, x, y, opacity;
  const _Pose(this.angle, this.x, this.y, this.opacity);
  @override
  bool operator ==(Object other) =>
      other is _Pose && other.angle == angle && other.x == x && other.y == y && other.opacity == opacity;
  @override
  int get hashCode => Object.hash(angle, x, y, opacity);
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({required super.end});
  @override
  _Pose lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    double mix(double x, double y) => x + (y - x) * t;
    return _Pose(mix(a.angle, b.angle), mix(a.x, b.x), mix(a.y, b.y), mix(a.opacity, b.opacity));
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
      final wave = widget.config['flicker'] == true
          ? (math.sin(phase * 7) + math.sin(phase * 13) + 2) / 4
          : (math.sin(phase) + 1) / 2;
      final min = (widget.config['minOpacity'] as num).toDouble();
      return Opacity(opacity: min + (1 - min) * wave, child: child);
    },
  );
}

class _ControlView extends StatefulWidget {
  final SceneControl control;
  final double value;
  final bool disabled;
  final VoidCallback onStart, onCancel, onCommit;
  final ValueChanged<double> onChange;
  final ValueChanged<String> onSelect;
  const _ControlView({
    super.key,
    required this.control,
    required this.value,
    required this.disabled,
    required this.onStart,
    required this.onCancel,
    required this.onChange,
    required this.onCommit,
    required this.onSelect,
  });
  @override
  State<_ControlView> createState() => _ControlViewState();
}

class _ControlViewState extends State<_ControlView> {
  bool _focused = false;
  double _dragValue = 0;
  Offset _tapPosition = Offset.zero;
  void _adjust(double delta) {
    widget.onChange(widget.value + delta);
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final button = c.kind == 'button';
    if (c.menu != null) {
      return PopupMenuButton<String>(
        enabled: !widget.disabled,
        position: PopupMenuPosition.under,
        onSelected: widget.onSelect,
        itemBuilder: (_) => [for (final item in c.menu!) PopupMenuItem(value: item.event, child: Text(item.label))],
        child: Semantics(label: c.label, button: true, child: const SizedBox.expand()),
      );
    }
    return Semantics(
      label: c.label,
      button: button,
      slider: !button,
      enabled: !widget.disabled,
      value: button ? null : c.describe(widget.value),
      increasedValue: button ? null : c.describe(widget.value + c.step),
      decreasedValue: button ? null : c.describe(widget.value - c.step),
      onTap: button && !widget.disabled ? widget.onCommit : null,
      onIncrease: button ? null : () => _adjust(c.step),
      onDecrease: button ? null : () => _adjust(-c.step),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (_, event) {
          if (widget.disabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (button && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
            widget.onCommit();
            return KeyEventResult.handled;
          }
          if (!button) {
            final direction = [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowUp].contains(key)
                ? 1
                : [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowDown].contains(key)
                ? -1
                : 0;
            if (direction != 0) {
              _adjust(c.step * direction * (HardwareKeyboard.instance.isShiftPressed ? 10 : 1));
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) => MouseRegion(
            onHover: !c.hover || widget.disabled
                ? null
                : (event) {
                    final next = c.atX(event.localPosition.dx);
                    if (next != widget.value) {
                      widget.onChange(next);
                      widget.onCommit();
                    }
                  },
            cursor: button ? SystemMouseCursors.click : SystemMouseCursors.resizeLeftRight,
            child: Listener(
              onPointerSignal: button
                  ? null
                  : (event) {
                      if (event is PointerScrollEvent) {
                        GestureBinding.instance.pointerSignalResolver.register(
                          event,
                          (_) => _adjust(event.scrollDelta.dy > 0 ? -c.step : c.step),
                        );
                      }
                    },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: (d) => _tapPosition = d.localPosition,
                onTap: widget.disabled
                    ? null
                    : () {
                        Focus.of(context).requestFocus();
                        if (c.kind == 'slider') {
                          widget.onChange(c.atX(_tapPosition.dx));
                        }
                        if (button || c.kind == 'slider') widget.onCommit();
                      },
                onPanStart: button
                    ? null
                    : (d) {
                        Focus.of(context).requestFocus();
                        widget.onStart();
                        _dragValue = widget.value;
                        if (c.kind == 'slider') {
                          widget.onChange(c.atX(d.localPosition.dx));
                        }
                      },
                onPanUpdate: button
                    ? null
                    : (d) {
                        if (c.kind == 'slider') {
                          widget.onChange(c.atX(d.localPosition.dx));
                        } else {
                          // Range only, not `c.clamp`: that also snaps to the step, and
                          // a slow drag whose deltas are under half a step would never
                          // move. Unclamped, a drag past an end stop owes the same
                          // distance back before the value moves again.
                          _dragValue = (_dragValue + (d.delta.dx - d.delta.dy) * c.sensitivity).clamp(c.min, c.max).toDouble();
                          widget.onChange(_dragValue);
                        }
                      },
                onPanEnd: button ? null : (_) => widget.onCommit(),
                onPanCancel: button ? null : widget.onCancel,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: _focused ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
