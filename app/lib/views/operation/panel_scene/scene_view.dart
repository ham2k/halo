// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../panel_environment.dart';
import 'scene_model.dart';
import 'scene_spectrum.dart';

/// Sends one control event and answers with the values to show: a patch keyed
/// by value name, a double for a number and a String for a string.
///
/// MUST settle in bounded time, because the view puts no timeout of its own on
/// it: a timer here can only abandon the wait, not the action. The handler
/// would go on to command the radio after the operator had been shown the
/// action failing and the control snapping back.
typedef SceneEventHandler = Future<Map<String, Object>> Function(Map<String, dynamic> event);

/// The extension supplies state; this widget owns gestures and animation frames.
/// Only committed controls cross the bridge in the prototype. Chart inspection
/// and intermediate drag positions remain entirely local.
class PanelSceneView extends StatefulWidget {
  final PanelScene scene;
  final SceneEventHandler? onEvent;

  /// Where `spectrum` controls get their sweeps — null for a panel that may
  /// not read the radio.
  final SceneSpectrumSource? spectrum;
  const PanelSceneView({super.key, required this.scene, this.onEvent, this.spectrum});
  @override
  State<PanelSceneView> createState() => _PanelSceneViewState();
}

class _PanelSceneViewState extends State<PanelSceneView> with WidgetsBindingObserver {
  late Map<String, double> _values;
  late Map<String, String> _strings;
  final _active = <String>{};

  /// Text fields holding typing not yet committed, by control id: how to
  /// commit each. An action commits them first, so it never reaches the
  /// extension ahead of the text it acts on.
  final _unsent = <String, VoidCallback>{};
  final _dirty = <String>{};
  final _queue = <String, Map<String, dynamic>>{};
  bool _sending = false;

  /// The event awaiting its answer, if any.
  Map<String, dynamic>? _inFlight;

  /// Whether an action is queued or awaiting its answer. Only that disables
  /// action controls: a value commit in flight must not, or the commit a
  /// field sends as a click blurs it would disable the button being clicked
  /// before the click completes.
  bool get _actionPending => _inFlight?['phase'] == 'activate' || _queue.values.any((e) => e['phase'] == 'activate');
  bool _appVisible = true;
  int _sequence = 0;

  /// Whether the last action failed. A flag, not the message: the banner is
  /// translated when it is built, so it follows a locale change.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _values = {...widget.scene.values};
    _strings = {...widget.scene.strings};
    WidgetsBinding.instance.addObserver(this);
    _appVisible = _visible(WidgetsBinding.instance.lifecycleState);
  }

  bool _visible(AppLifecycleState? state) => state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appVisible = _visible(state));
  }

  @override
  void didUpdateWidget(PanelSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Local-only values (inspection cursor, a switch that sends nothing)
    // survive document refreshes. A `nativeText` has no event and is not
    // one: it only shows its value, so it follows the document.
    final local = {
      ...widget.scene.controls.where((c) => c.event == null && !c.isAction && c.kind != 'nativeText').map((c) => c.value),
      // Written by the pointer, never by the extension.
      for (final c in widget.scene.controls) ...[?c.spectrum?.hoverHz, ?c.spectrum?.hoverDb],
    };
    bool keep(String key) => _dirty.contains(key) || _active.contains(key) || local.contains(key);
    _values = {for (final entry in widget.scene.values.entries) entry.key: keep(entry.key) ? _values[entry.key] ?? entry.value : entry.value};
    _strings = {for (final entry in widget.scene.strings.entries) entry.key: keep(entry.key) ? _strings[entry.key] ?? entry.value : entry.value};
  }

  /// [value] is a String for a string-bound control, a double otherwise.
  void _change(SceneControl control, Object value) {
    setState(() {
      if (control.event != null) _sequence++;
      if (value is String) {
        _strings[control.value!] = value;
      } else {
        final n = value as double;
        _values[control.value!] = const {'slider', 'knob', 'nativeSlider'}.contains(control.kind) ? control.clamp(n) : n;
      }
      _dirty.add(control.value!);
    });
    if (control.continuous) _sendControl(control, 'change');
  }

  void _commit(SceneControl control) {
    _active.remove(control.value);
    _unsent.remove(control.id);
    _sendControl(control, control.isAction ? 'activate' : 'commit');
  }

  void _editing(SceneControl control, bool editing, VoidCallback? commit) {
    if (editing) {
      _active.add(control.value!);
      if (commit != null) _unsent[control.id] = commit;
    } else {
      // Only a control going away ends an edit without committing it: what
      // it held is abandoned, and the value follows the document again.
      _active.remove(control.value);
      _dirty.remove(control.value);
      _unsent.remove(control.id);
    }
  }

  /// [value] stands in for the control's bound value — the frequency a
  /// spectrum was clicked at, which no scene value holds.
  void _sendControl(SceneControl control, String phase, {String? action, double? value, String? annotation}) {
    // Touch never blurs a field by tapping a button, and a Material button
    // takes no focus: without this, Spot goes out before its callsign.
    if (phase == 'activate') {
      for (final commit in [..._unsent.values]) {
        commit();
      }
    }
    if ((control.event == null && action == null) || widget.onEvent == null) {
      _dirty.remove(control.value);
      return;
    }
    final event = <String, dynamic>{
      'controlId': control.id,
      'action': action ?? control.event,
      'phase': phase,
      'sequence': ++_sequence,
      'annotation': ?annotation,
      if (value != null)
        'value': value
      else if (control.value != null)
        if (_strings.containsKey(control.value)) 'text': _strings[control.value] else 'value': _values[control.value],
    };
    // Buttons are disabled while outstanding; repeated control commits keep
    // only their newest desired value. Bound by the scene's 64 controls, and
    // a spectrum's 64 annotations each.
    // Move a replacement to the end, preserving commit order across controls
    // that share a value (for example a tuning knob and its band slider).
    // An annotation's click is its own entry: a spot clicked, then the
    // waterfall clicked to tune, are two things the extension must hear.
    final key = annotation == null ? control.id : '${control.id}\u0000$annotation';
    _queue.remove(key);
    _queue[key] = event;
    setState(() => _failed = false);
    _drain();
  }

  Future<void> _drain() async {
    if (_sending) return;
    _sending = true;
    while (mounted && _queue.isNotEmpty) {
      final id = _queue.keys.first;
      final event = _queue.remove(id)!;
      _inFlight = event;
      try {
        final patch = await widget.onEvent!(event);
        if (!mounted) return;
        if (event['sequence'] == _sequence) {
          setState(() {
            for (final MapEntry(:key, :value) in patch.entries) {
              if (_active.contains(key)) continue;
              if (value is double && _values.containsKey(key)) _values[key] = value;
              if (value is String && _strings.containsKey(key)) _strings[key] = value;
            }
            _dirty.removeWhere((key) => !_active.contains(key));
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          // Said even when a newer interaction has superseded the event: a
          // refused value is news whether or not it is still the one shown.
          _failed = true;
          // An action queued behind a refused value would act on the value
          // the extension has, not the one the operator just gave it.
          // An annotation's click carries its own frequency, so it does not
          // act on a value the extension refused, and still goes.
          if (event['phase'] != 'activate') _queue.removeWhere((_, queued) => queued['phase'] == 'activate' && queued['annotation'] == null);
          if (event['sequence'] == _sequence) {
            for (final key in _dirty) {
              if (_active.contains(key)) continue;
              if (widget.scene.values[key] case final reported?) _values[key] = reported;
              if (widget.scene.strings[key] case final reported?) _strings[key] = reported;
            }
            _dirty.removeWhere((key) => !_active.contains(key));
          }
        });
      } finally {
        _inFlight = null;
      }
      // An action answered re-enables its buttons now, not after whatever
      // is queued behind it.
      if (mounted) setState(() {});
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

  /// The same wrappers at every opacity, so crossing 0 or 1 never remounts
  /// the control and drops a text field's typing. At 0 it takes no clicks
  /// or focus, and Opacity drops its screen-reader node: unseen, it must not
  /// act on what is under it.
  Widget _faded(SceneControl control, Widget child) {
    final opacity = control.opacityAt(_values);
    final hidden = opacity <= 0;
    return ExcludeFocus(
      excluding: hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: Opacity(opacity: opacity, child: child),
      ),
    );
  }

  Widget _native(SceneControl control) => _faded(control, control.spectrum == null ? _nativeView(control) : _spectrumView(control));

  Widget _spectrumView(SceneControl control) {
    final spec = control.spectrum!;
    return SceneSpectrumView(
      key: ValueKey('${control.id}:${control.kind}'),
      control: control,
      source: widget.spectrum,
      awake: _appVisible && DockPaneVisibility.of(context),
      values: _values,
      onHover: spec.hoverHz == null && spec.hoverDb == null
          ? null
          : (hz, db) => setState(() {
              if (spec.hoverHz case final key?) _values[key] = hz;
              if (spec.hoverDb case final key?) _values[key] = db;
            }),
      // Shown but inert, like every disabled control: no tune, no annotation
      // click. Hover still reads, since it acts on nothing.
      onAnnotation: control.disabled
          ? null
          : (annotation, hz) => _sendControl(control, 'activate', action: annotation.event, value: hz, annotation: annotation.id),
      onTune: control.event == null || control.disabled
          ? null
          : (hz) {
              final step = spec.tuneStep?.resolve(_values);
              _sendControl(control, 'commit', value: step == null || step <= 0 ? hz : (hz / step).round() * step);
            },
    );
  }

  Widget _nativeView(SceneControl control) => _NativeControlView(
    // With the kind: a render that turns a control into a text field must not
    // hand it a State built for a dropdown, which has no controller.
    key: ValueKey('${control.id}:${control.kind}'),
    control: control,
    number: _values[control.value] ?? 0,
    text: _strings[control.value],
    disabled: control.disabled || (control.isAction && _actionPending),
    onEditing: (editing, [commit]) => _editing(control, editing, commit),
    onChange: (v) => _change(control, v),
    onCommit: () => _commit(control),
    onSelect: (action) => _sendControl(control, 'activate', action: action),
  );

  /// A control with a rect, over the artwork.
  Widget _placed(SceneControl control) {
    final scene = widget.scene;
    final rect = control.rect!;
    if (control.native) {
      // The rect's full width, and its natural height up to the rect's,
      // centred in it. A rect too short for the control squeezes it.
      return Positioned.fromRect(
        key: ValueKey('control:${control.id}'),
        rect: rect,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: rect.width, child: _native(control)),
        ),
      );
    }
    return Positioned.fromRect(
      key: ValueKey('control:${control.id}'),
      rect: rect,
      child: _faded(
        control,
        _ControlView(
          key: ValueKey(control.id),
          control: control,
          value: _values[control.value] ?? 0,
          disabled: control.disabled || (control.isAction && _actionPending),
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
    );
  }

  Widget _artwork(bool reduceMotion) {
    final scene = widget.scene;
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: scene.width,
          height: scene.height,
          child: ClipRect(
            child: Stack(
              children: [
                for (final layer in scene.layers) ...[
                  // Keyed, as is each control's: without it, a layer added
                  // before a control shifts the Stack's children, and the
                  // control remounts and drops a text field's typing.
                  Positioned.fromRect(
                    key: ValueKey('layer:${layer.id}'),
                    rect: layer.rect,
                    child: _SceneLayerView(
                      key: ValueKey(layer.id),
                      layer: layer,
                      values: _values,
                      strings: _strings,
                      immediate: reduceMotion || layer.bindings.values.any((b) => _dirty.contains(b.value)),
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  for (final control in scene.controls)
                    if (control.after == layer.id) _placed(control),
                ],
                // Placed after no layer: above every layer.
                for (final control in scene.controls)
                  if (control.rect != null && control.after == null) _placed(control),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// [room]: whether the parent row or column has a bounded main axis to
  /// share. A row that is itself an unflexed child of a row has none, and a
  /// Flexible there is a Flutter assertion, so its children lay out unflexed.
  Widget _layout(SceneLayoutNode node, Widget Function() artwork, {bool room = false}) {
    Widget child = switch (node.type) {
      'scene' => artwork(),
      'control' => _native(widget.scene.controlsById[node.control]!),
      'spacer' => const SizedBox.shrink(),
      'wrap' => Wrap(
        spacing: node.spacing,
        runSpacing: node.runSpacing,
        alignment: WrapAlignment.values.byName(node.mainAxisAlignment),
        crossAxisAlignment: WrapCrossAlignment.values.byName(node.crossAxisAlignment),
        children: [for (final c in node.children) _layout(c, artwork)],
      ),
      _ => LayoutBuilder(
        builder: (context, box) {
          final row = node.type == 'row';
          var cross = CrossAxisAlignment.values.byName(node.crossAxisAlignment);
          // Stretch on an unbounded cross axis (a row inside a column, with no
          // flex) is an infinite size Flutter throws on, not a layout.
          if (cross == CrossAxisAlignment.stretch && !(row ? box.hasBoundedHeight : box.hasBoundedWidth)) cross = CrossAxisAlignment.center;
          return Flex(
            direction: row ? Axis.horizontal : Axis.vertical,
            spacing: node.spacing,
            mainAxisAlignment: MainAxisAlignment.values.byName(node.mainAxisAlignment),
            crossAxisAlignment: cross,
            children: [for (final c in node.children) _layout(c, artwork, room: row ? box.hasBoundedWidth : box.hasBoundedHeight)],
          );
        },
      ),
    };
    if (node.width != null || node.height != null) child = SizedBox(width: node.width, height: node.height, child: child);
    if (node.padding != EdgeInsetsDirectional.zero) child = Padding(padding: node.padding, child: child);
    if (node.flex case final flex? when room) child = Flexible(flex: flex, fit: node.tight ? FlexFit.tight : FlexFit.loose, child: child);
    return child;
  }

  @override
  Widget build(BuildContext context) {
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
                actions: [TextButton(onPressed: () => setState(() => _failed = false), child: Text(context.t.common.dismiss))],
              ),
            Expanded(
              child: TickerMode(
                enabled: awake && !reduceMotion,
                child: IgnorePointer(
                  ignoring: !awake,
                  child: widget.scene.layout == null ? _artwork(reduceMotion) : _layout(widget.scene.layout!, () => _artwork(reduceMotion)),
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
  final Map<String, String> strings;
  final bool immediate, reduceMotion;
  const _SceneLayerView({super.key, required this.layer, required this.values, required this.strings, required this.immediate, required this.reduceMotion});
  @override
  Widget build(BuildContext context) {
    final text = layer.text;
    final samples = text?['samples'] as List<dynamic>?;
    final bound = strings[text?['value']];
    final rawValue = text?['value'] == null || bound != null ? 0.0 : values[text!['value']]!;
    final sampledValue = bound ?? (samples == null ? rawValue : samples[rawValue.round().clamp(0, samples.length - 1)]);
    var textValue = sampledValue is num ? sampledValue * (text?['scale'] as num? ?? 1) : sampledValue;
    if (textValue is num) {
      if (text?['truncate'] == true) textValue = (textValue + 1e-7).floor();
      if (text?['modulo'] case final num modulus) textValue = textValue % modulus;
    }
    final decimals = (text?['decimals'] as num? ?? 0).toInt();
    final formatted = textValue is num
        ? textValue.toStringAsFixed(decimals).padLeft((text?['minIntegerDigits'] as num? ?? 1).toInt() + (decimals > 0 ? decimals + 1 : 0), '0')
        : textValue.toString();
    Widget artwork = layer.svg != null
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
  bool operator ==(Object other) => other is _Pose && other.angle == angle && other.x == x && other.y == y && other.opacity == opacity;
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
      final wave = widget.config['flicker'] == true ? (math.sin(phase * 7) + math.sin(phase * 13) + 2) / 4 : (math.sin(phase) + 1) / 2;
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

  /// A drag that began while enabled, and only such a drag: one refused at
  /// its start moves nothing, and one under way still ends with a commit or
  /// a cancel if the control is disabled mid-drag, or its claim on the value
  /// would never be released.
  bool _dragging = false;

  void _adjust(double delta) {
    if (widget.disabled) return;
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
      onIncrease: button || widget.disabled ? null : () => _adjust(c.step),
      onDecrease: button || widget.disabled ? null : () => _adjust(-c.step),
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
              // Disabled, the wheel is left to scroll whatever is under it.
              onPointerSignal: button || widget.disabled
                  ? null
                  : (event) {
                      if (event is PointerScrollEvent) {
                        GestureBinding.instance.pointerSignalResolver.register(event, (_) => _adjust(event.scrollDelta.dy > 0 ? -c.step : c.step));
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
                        if (widget.disabled) return;
                        _dragging = true;
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
                        if (!_dragging) return;
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
                onPanEnd: button
                    ? null
                    : (_) {
                        if (!_dragging) return;
                        _dragging = false;
                        widget.onCommit();
                      },
                onPanCancel: button
                    ? null
                    : () {
                        if (!_dragging) return;
                        _dragging = false;
                        widget.onCancel();
                      },
                child: DecoratedBox(
                  decoration: BoxDecoration(border: _focused ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a field sits with no width of its own — a row child without `flex`
/// or `width`. A text field or dropdown is as wide as it is told; told
/// nothing, Flutter throws rather than guess.
const _unboundedFieldWidth = 200.0;

/// One `native…` control: a Material widget, themed by the app.
///
/// The bound value arrives as [number] or [text]; the widget reports through
/// the same change/commit pair the drawn controls use, so the queue, the
/// pending state and the rollback treat both alike.
class _NativeControlView extends StatefulWidget {
  final SceneControl control;
  final double number;
  final String? text;
  final bool disabled;

  /// A text field holds edits the document has not heard about yet; while it
  /// does, a refresh must not overwrite them. [commit] sends them, for an
  /// action that must not overtake them.
  final void Function(bool editing, [VoidCallback? commit]) onEditing;
  final ValueChanged<Object> onChange;
  final VoidCallback onCommit;
  final ValueChanged<String> onSelect;
  const _NativeControlView({
    super.key,
    required this.control,
    required this.number,
    required this.text,
    required this.disabled,
    required this.onEditing,
    required this.onChange,
    required this.onCommit,
    required this.onSelect,
  });
  @override
  State<_NativeControlView> createState() => _NativeControlViewState();
}

class _NativeControlViewState extends State<_NativeControlView> {
  TextEditingController? _field;
  FocusNode? _fieldFocus;

  /// Typed since the last commit, or a slider mid-drag. Focus alone is not
  /// editing: a field that was only clicked into follows the document, and
  /// commits nothing on blur.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    if (widget.control.kind == 'nativeTextField') {
      _field = TextEditingController(text: widget.text);
      _fieldFocus = FocusNode()
        ..addListener(() {
          if (!_fieldFocus!.hasFocus && _editing) _submit();
        });
    }
  }

  @override
  void didUpdateWidget(_NativeControlView old) {
    super.didUpdateWidget(old);
    final field = _field;
    if (field != null && !_editing && field.text != widget.text) {
      field.value = TextEditingValue(
        text: widget.text ?? '',
        selection: TextSelection.collapsed(offset: widget.text?.length ?? 0),
      );
    }
  }

  @override
  void dispose() {
    // Removed mid-typing or mid-drag (Flutter sends no onChangeEnd to an
    // unmounted slider): the edit goes with it, and so must the claim on its
    // value, or no render or patch would ever update that value again.
    if (_editing) widget.onEditing(false);
    _field?.dispose();
    _fieldFocus?.dispose();
    super.dispose();
  }

  void _submit() {
    _editing = false;
    widget.onChange(_field!.text);
    widget.onCommit();
  }

  void _set(Object value) {
    widget.onChange(value);
    widget.onCommit();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final enabled = !widget.disabled;
    final icon = c.icon == null ? null : Icon(resolveIconName(c.icon));
    Widget captioned(Widget control, VoidCallback? onTap) => LayoutBuilder(
      builder: (context, box) {
        final caption = Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis);
        return MergeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                control,
                const SizedBox(width: Space.sm),
                if (box.hasBoundedWidth) Flexible(child: caption) else caption,
              ],
            ),
          ),
        );
      },
    );
    Widget sized(Widget field) => LayoutBuilder(
      builder: (context, box) => box.hasBoundedWidth ? field : SizedBox(width: _unboundedFieldWidth, child: field),
    );
    final selected = c.options?.map((o) => o.value).where((v) => c.multi ? (widget.text ?? '').split(',').contains(v) : v == widget.text).toSet();
    switch (c.kind) {
      case 'nativeButton':
        Widget button(VoidCallback? onPressed) {
          final label = Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis);
          return switch (c.variant) {
            'tonal' => FilledButton.tonalIcon(onPressed: onPressed, icon: icon, label: label),
            'outlined' => OutlinedButton.icon(onPressed: onPressed, icon: icon, label: label),
            'text' => TextButton.icon(onPressed: onPressed, icon: icon, label: label),
            _ => FilledButton.icon(onPressed: onPressed, icon: icon, label: label),
          };
        }
        if (c.menu == null) return button(enabled ? widget.onCommit : null);
        return MenuAnchor(
          menuChildren: [for (final item in c.menu!) MenuItemButton(onPressed: () => widget.onSelect(item.event), child: Text(item.label))],
          builder: (context, menu, _) => button(enabled ? () => menu.isOpen ? menu.close() : menu.open() : null),
        );
      case 'nativeSlider':
        final steps = ((c.max - c.min) / c.step).round();
        return MergeSemantics(
          child: Semantics(
            label: c.label,
            child: Slider(
              value: c.clamp(widget.number),
              min: c.min,
              max: c.max,
              // Past a hundred, tick marks are a grey smear; `_change` still
              // snaps every value to the step.
              // Only when the steps divide the range: otherwise the ticks and
              // `_change`'s snapping disagree and the thumb jumps back.
              divisions: steps > 0 && steps <= 100 && (steps * c.step - (c.max - c.min)).abs() < 1e-9 * (c.max - c.min) ? steps : null,
              label: c.valueLabels == null ? null : c.describe(widget.number),
              onChangeStart: (_) => widget.onEditing(_editing = true),
              onChanged: enabled ? (v) => widget.onChange(v) : null,
              onChangeEnd: (_) {
                _editing = false;
                widget.onCommit();
              },
            ),
          ),
        );
      case 'nativeTextField':
        return sized(
          TextField(
            controller: _field,
            focusNode: _fieldFocus,
            enabled: enabled,
            selectAllOnFocus: false,
            decoration: poloFieldDecoration(context, c.label, hintText: c.placeholder),
            inputFormatters: [LengthLimitingTextInputFormatter(sceneStringMaxLength)],
            onChanged: (text) {
              if (!_editing) widget.onEditing(_editing = true, _submit);
              if (c.continuous) widget.onChange(text);
            },
            onSubmitted: (_) => _submit(),
          ),
        );
      case 'nativeDropdown':
        // A DropdownButton, not a DropdownButtonFormField: the value is the
        // document's, and a FormField keeps one of its own.
        return sized(
          InputDecorator(
            decoration: poloFieldDecoration(context, c.label),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected!.firstOrNull,
                hint: c.placeholder == null ? null : Text(c.placeholder!),
                isDense: true,
                isExpanded: true,
                icon: dropdownTrailingIcon,
                menuMaxHeight: dropdownMenuMaxHeight(context),
                items: [
                  for (final o in c.options!)
                    DropdownMenuItem(
                      value: o.value,
                      child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: enabled ? (v) => v == null ? null : _set(v) : null,
              ),
            ),
          ),
        );
      case 'nativeSwitch':
        final on = widget.number != 0;
        return captioned(Switch(value: on, onChanged: enabled ? (v) => _set(v ? 1.0 : 0.0) : null), enabled ? () => _set(on ? 0.0 : 1.0) : null);
      case 'nativeCheckbox':
        final on = widget.number != 0;
        return captioned(Checkbox(value: on, onChanged: enabled ? (v) => _set(v == true ? 1.0 : 0.0) : null), enabled ? () => _set(on ? 0.0 : 1.0) : null);
      case 'nativeRadio':
        return Semantics(
          label: c.label,
          container: true,
          child: RadioGroup<String>(
            groupValue: selected!.firstOrNull,
            onChanged: (v) => v == null || !enabled ? null : _set(v),
            child: Wrap(
              spacing: Space.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final o in c.options!)
                  MergeSemantics(
                    child: InkWell(
                      onTap: enabled ? () => _set(o.value) : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(value: o.value, enabled: enabled),
                          Text(o.label),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      case 'nativeSegmented':
        return Semantics(
          label: c.label,
          container: true,
          child: SegmentedButton<String>(
            // MDI-only UI: no framework check mark on the selected segment.
            showSelectedIcon: false,
            segments: [for (final o in c.options!) ButtonSegment(value: o.value, label: Text(o.label))],
            selected: selected!,
            multiSelectionEnabled: c.multi,
            emptySelectionAllowed: c.multi || selected.isEmpty,
            // Joined in option order, whatever order they were tapped in.
            onSelectionChanged: enabled ? (picked) => _set(c.options!.map((o) => o.value).where(picked.contains).join(',')) : null,
          ),
        );
      case 'nativeChip':
        final avatar = icon;
        if (c.value == null) return ActionChip(avatar: avatar, label: Text(c.label), onPressed: enabled ? widget.onCommit : null);
        return FilterChip(
          avatar: avatar,
          // Material paints the check over the avatar; with an icon, the
          // selected fill alone says it is on.
          showCheckmark: avatar == null,
          label: Text(c.label),
          selected: widget.number != 0,
          onSelected: enabled ? (v) => _set(v ? 1.0 : 0.0) : null,
        );
      default: // nativeText
        final n = widget.number;
        final shown = c.value == null ? c.label : widget.text ?? (n == n.roundToDouble() ? n.toInt().toString() : n.toString());
        return Text(
          shown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: switch (c.align) {
            'center' => TextAlign.center,
            'end' => TextAlign.end,
            _ => TextAlign.start,
          },
          style: panelTextRole(context, c.style ?? 'body'),
        );
    }
  }
}
