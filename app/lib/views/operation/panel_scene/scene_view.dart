// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
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
import 'scene_gestures.dart';

part 'scene_layer_view.dart';

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
  // A receiver's display keeps its history when the layout changes wrappers
  // between a zero-height hidden slot and a visible flexible slot.
  final _spectrumKeys = <String, GlobalKey>{};

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
    if (widget.scene.scroll case final scroll?) _scrollTo = widget.scene.values[scroll.value];
    _readRadio();
    _listenToRadio(null, widget);
    WidgetsBinding.instance.addObserver(this);
    _appVisible = _visible(WidgetsBinding.instance.lifecycleState);
  }

  /// Writes the radio's live readings into the `radio.` values, straight from
  /// CAT: nothing crosses the bridge, and the extension renders no faster for
  /// a meter that moves four times a second.
  void _readRadio() {
    if (!widget.scene.hasRadio) return;
    final source = widget.spectrum;
    final uuid = source?.resolve(widget.scene.radio);
    final readings = uuid == null ? const <String, num>{} : source!.readings(uuid);
    for (final name in sceneRadioValues) {
      _values[name] = readings[name.substring('radio.'.length)]?.toDouble() ?? double.negativeInfinity;
    }
    // Nothing notifies as time passes, so a scene shortly after a transmission reads again on its
    // own: a hold bound to the seconds since, ends on time.
    final since = _values['radio.secondsSinceTransmit'] ?? double.infinity;
    if (since >= 0 && since < 15) {
      _sinceTransmitTick ??= Timer(const Duration(milliseconds: 250), () {
        _sinceTransmitTick = null;
        _onRadioReading();
      });
    }
  }

  Timer? _sinceTransmitTick;

  void _onRadioReading() {
    if (mounted) setState(_readRadio);
  }

  void _listenToRadio(PanelSceneView? old, PanelSceneView next) {
    final before = old != null && old.scene.hasRadio ? old.spectrum?.readingChanges : null;
    final after = next.scene.hasRadio ? next.spectrum?.readingChanges : null;
    if (identical(before, after)) return;
    before?.removeListener(_onRadioReading);
    after?.addListener(_onRadioReading);
  }

  bool _visible(AppLifecycleState? state) => state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appVisible = _visible(state));
  }

  @override
  void didUpdateWidget(PanelSceneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _spectrumKeys.removeWhere((id, _) => widget.scene.controlsById[id]?.spectrum == null);
    // Local-only values (inspection cursor, a switch that sends nothing)
    // survive document refreshes. A `nativeText` has no event and is not
    // one: it only shows its value, so it follows the document.
    final local = {
      ...widget.scene.controls.where((c) => c.event == null && !c.isAction && c.kind != 'nativeText').map((c) => c.value),
      // Written by the pointer, never by the extension.
      for (final c in widget.scene.controls) ...[?c.spectrum?.hoverHz, ?c.spectrum?.hoverDb],
      // A hover value is the pointer's only while it is over the control; otherwise a render's.
      ..._hovering,
    };
    // A zoom previewed gives way to the render that answers it: the first new scene once its event
    // has been heard. One drawn while it waits — the spots moving on — is still at the old zoom, and
    // dropping the preview for it would flick back to the old zoom and then on to the new.
    if (_zoomStrip == null && !identical(oldWidget.scene, widget.scene) && !_zoomWaiting) _zoom = 1;
    // The scroll position is the operator's until a render moves it: see [_scrollTo].
    if (widget.scene.scroll case final s?) {
      local.add(s.value);
      final asked = widget.scene.values[s.value];
      if (oldWidget.scene.scroll == null || oldWidget.scene.values[s.value] != asked) {
        final echoed = asked == null ? -1 : _scrollsSent.indexWhere((sent) => (sent - asked).abs() < 0.5);
        // Heard back, that position and every one sent before it are spent: the extension has caught
        // up past them, and asking for one again is a move.
        _scrollsSent = echoed < 0 ? const [] : _scrollsSent.sublist(echoed + 1);
        if (echoed < 0) _scrollTo = asked;
      }
    }
    bool keep(String key) => _dirty.contains(key) || _active.contains(key) || local.contains(key);
    _values = {for (final entry in widget.scene.values.entries) entry.key: keep(entry.key) ? _values[entry.key] ?? entry.value : entry.value};
    _strings = {for (final entry in widget.scene.strings.entries) entry.key: keep(entry.key) ? _strings[entry.key] ?? entry.value : entry.value};
    _readRadio();
    _listenToRadio(oldWidget, widget);
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
    // only their newest desired value. Bound by the scene's 256 controls, and
    // a spectrum's 64 annotations each.
    // Move a replacement to the end, preserving commit order across controls
    // that share a value (for example a tuning knob and its band slider).
    // An annotation's click is its own entry: a spot clicked, then the
    // waterfall clicked to tune, are two things the extension must hear.
    final key = annotation != null
        ? '${control.id}\u0000$annotation'
        // A knob's two axes are two values the extension must both hear.
        : control.isYAxis
        ? '${control.id}\u0000y'
        : control.id;
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
          // A scroll or zoom refused moves only the view, and leaves what an action acts on alone.
          if (event['phase'] != 'activate' && !_viewEvent(event)) {
            _queue.removeWhere((_, queued) => queued['phase'] == 'activate' && queued['annotation'] == null);
          }
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
    _zoomHold?.cancel();
    _settle?.cancel();
    _scroller.dispose();
    _sinceTransmitTick?.cancel();
    if (widget.scene.hasRadio) widget.spectrum?.readingChanges.removeListener(_onRadioReading);
    WidgetsBinding.instance.removeObserver(this);
    _queue.clear();
    _spectrumKeys.clear();
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
        child: _hovered(control, Opacity(opacity: opacity, child: child)),
      ),
    );
  }

  /// A control's `hoverSet`, kept on the host: entering sets the value and
  /// leaving puts back the scene's own. The pointer leaves one control before
  /// it enters the next, so moving straight onto a neighbour lights that one.
  /// The `hoverSet` values the pointer holds right now.
  final _hovering = <String>{};

  Widget _hovered(SceneControl control, Widget child) {
    final hover = control.hoverSet;
    if (hover == null) return child;
    return MouseRegion(
      opaque: false,
      onEnter: (_) => setState(() {
        _hovering.add(hover.value);
        _values[hover.value] = hover.to;
      }),
      onExit: (_) {
        if (!mounted) return;
        setState(() {
          _hovering.remove(hover.value);
          _values[hover.value] = widget.scene.values[hover.value] ?? 0;
        });
      },
      child: child,
    );
  }

  Widget _native(SceneControl control) => _faded(control, control.spectrum == null ? _nativeView(control) : _spectrumView(control));

  Widget _spectrumView(SceneControl control) {
    final spec = control.spectrum!;
    return SceneSpectrumView(
      key: _spectrumKeys.putIfAbsent(control.id, GlobalKey.new),
      control: control,
      source: widget.spectrum,
      awake: _appVisible && DockPaneVisibility.of(context) && control.opacityAt(_values) > 0,
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
        child: _zoomed(
          control.fixed ? null : rect,
          false,
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: rect.width, child: _native(control)),
          ),
        ),
      );
    }
    return Positioned.fromRect(
      key: ValueKey('control:${control.id}'),
      rect: rect,
      child: _zoomed(
        control.fixed ? null : rect,
        false,
        _faded(
          control,
          _scrollsThrough(
            control,
            _ControlView(
              key: ValueKey(control.id),
              control: control,
              value: _values[control.value] ?? 0,
              valueY: control.yAxis == null ? null : _values[control.yAxis!.value] ?? 0,
              disabled: control.disabled || (control.isAction && _actionPending),
              // A two-axis knob holds each value only once that axis moves: a drag commits only the
              // axes it moved, and one held without a commit would stop following the document.
              onStart: () {
                if (control.yAxis == null) _active.add(control.value ?? '');
              },
              onCancel: () {
                setState(() {
                  for (final key in [control.value, control.yAxis?.value]) {
                    _active.remove(key);
                    _dirty.remove(key);
                    if (key != null) _values[key] = scene.values[key]!;
                  }
                });
              },
              onChange: (v) {
                if (control.yAxis != null) _active.add(control.value!);
                _change(control, v);
              },
              onCommit: () => _commit(control),
              onChangeY: control.yAxis == null
                  ? null
                  : (v) {
                      _active.add(control.yAxis!.value!);
                      _change(control.yAxis!, v);
                    },
              onCommitY: control.yAxis == null ? null : () => _commit(control.yAxis!),
              onSelect: (action) => _sendControl(control, 'activate', action: action),
            ),
          ),
        ),
      ),
    );
  }

  /// A scroll that lands on a drawn button — one the hit test reached, so nothing above it took the
  /// pointer — goes on beneath it, past other buttons, to a slider or knob with `scrollThrough`: a
  /// label over a knob that scrolls the artwork must not stop the scroll. Anything else on the way
  /// keeps it from there — a native control, a layer that blocks the pointer, a slider or knob that
  /// did not ask — so a scene that never asked keeps its scrolls where they land.
  Widget _scrollsThrough(SceneControl button, Widget child) => button.kind != 'button'
      ? child
      : Listener(behavior: HitTestBehavior.translucent, onPointerSignal: (event) => _scrollThrough(button, event), child: child);

  void _scrollThrough(SceneControl button, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final target = _scrolledBeneath(button, button.rect!.topLeft + event.localPosition);
    if (target == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final step = sceneScrollStep(target, event.scrollDelta);
      final axis = step.second ? target.yAxis! : target;
      if (target.yAxis != null) _active.add(axis.value!);
      _change(axis, (_values[axis.value] ?? 0) + step.delta);
      _commit(axis);
    });
  }

  /// Positions are compared only within [button]'s own stack: a fixed control's rect is in pane
  /// coordinates, a scrolling one's in the content's.
  SceneControl? _scrolledBeneath(SceneControl button, Offset at) {
    final painted = _painted(button.fixed).toList();
    for (final piece in painted.sublist(0, painted.indexOf(button)).reversed) {
      switch (piece) {
        case SceneLayer layer when layer.blocksPointer && layer.rect.contains(at) && (layer.bindings['opacity']?.evaluate(_values) ?? 1) > 0:
          return null;
        case SceneControl control when (control.rect?.contains(at) ?? false) && control.opacityAt(_values) > 0:
          if (control.kind == 'button') continue;
          return control.scrollThrough && !control.disabled ? control : null;
      }
    }
    return null;
  }

  /// A scrolling scene's view of its content, and the scale it is drawn at.
  final _scroller = ScrollController();
  double _scrollScale = 1;

  /// Where a render asked the view to be, in scene units, until the view gets there.
  double? _scrollTo;

  /// The position last told to the extension, and those it has not yet been heard keeping: a render
  /// carrying one of them back is the extension keeping what it heard, not asking to move — jumping
  /// there would yank the view from under an operator who has scrolled on since.
  double? _scrollSent;
  List<double> _scrollsSent = const [];
  Timer? _settle;

  /// A drag or pinch on a `zoom` strip: the strip, how far from the pane's middle a drag began, and
  /// the factor shown — held after release until the extension's render at that zoom replaces it.
  final _pane = GlobalKey();
  SceneControl? _zoomStrip;
  double _zoomFrom = 0, _zoom = 1;

  /// The pane's length along the scroll, in scene units.
  double _paneLength = 0;

  /// While a zoom strip is dragged, each scrolling piece moves to where the zoom puts its middle
  /// and keeps its size — text stays text-sized, a dot a dot — and a `stretch` layer scales along
  /// the scroll instead: a background, or a line that runs the whole way. About the pane's middle.
  /// A null [rect] — a `fixed` piece, over the pane rather than the content — stays put.
  Widget _zoomed(Rect? rect, bool stretch, Widget child) {
    if (rect == null || _zoom == 1 || widget.scene.scroll == null) return child;
    final vertical = widget.scene.scroll!.axis == 'y';
    final middle = (_scroller.hasClients ? _scroller.offset / _scrollScale : 0) + _paneLength / 2;
    if (stretch) {
      return Transform(
        origin: vertical ? Offset(0, middle - rect.top) : Offset(middle - rect.left, 0),
        transform: Matrix4.diagonal3Values(vertical ? 1 : _zoom, vertical ? _zoom : 1, 1),
        child: child,
      );
    }
    final moved = ((vertical ? rect.center.dy : rect.center.dx) - middle) * (_zoom - 1);
    return Transform.translate(offset: vertical ? Offset(0, moved) : Offset(moved, 0), child: child);
  }

  SceneControl? _zoomStripAt(Offset at) => widget.scene.controls.where((c) => c.kind == 'zoom' && !c.disabled && (c.rect?.contains(at) ?? false)).lastOrNull;

  /// How far [global] is from the pane's middle, along the scroll.
  double _fromMiddle(Offset global) {
    final box = _pane.currentContext!.findRenderObject()! as RenderBox, at = box.globalToLocal(global);
    return widget.scene.scroll?.axis == 'x' ? (at.dx - box.size.width / 2).abs() : (at.dy - box.size.height / 2).abs();
  }

  void _zoomStart(DragStartDetails details) {
    _zoomStrip = _zoomStripAt(details.localPosition);
    // A start right on the middle would make every pixel a leap.
    _zoomFrom = math.max(16, _fromMiddle(details.globalPosition));
  }

  void _zoomUpdate(DragUpdateDetails details) {
    final strip = _zoomStrip;
    if (strip == null) return;
    setState(() => _zoom = (_fromMiddle(details.globalPosition) / _zoomFrom).clamp(strip.min, strip.max).toDouble());
  }

  Map<Type, GestureRecognizerFactory> _zoomGestures(bool vertical) {
    bool allowedAt(Offset at) => _zoomStripAt(at) != null;
    // Measured from where the finger came down, not where the drag was recognised past its slop.
    void handlers(DragGestureRecognizer drag) => drag
      ..dragStartBehavior = DragStartBehavior.down
      ..onStart = _zoomStart
      ..onUpdate = _zoomUpdate
      ..onEnd = _zoomEnd
      ..onCancel = () => setState(() {
        _zoomStrip = null;
        _zoom = 1;
      });
    return vertical
        ? {VerticalZoomDrag: GestureRecognizerFactoryWithHandlers<VerticalZoomDrag>(() => VerticalZoomDrag(allowedAt), handlers)}
        : {HorizontalZoomDrag: GestureRecognizerFactoryWithHandlers<HorizontalZoomDrag>(() => HorizontalZoomDrag(allowedAt), handlers)};
  }

  /// The strip a trackpad gesture began on: it zooms only once it pinches, a swipe being a scroll.
  SceneControl? _pinchStrip;

  void _pinchStart(PointerPanZoomStartEvent event) => _pinchStrip = _zoomStripAt(event.localPosition);

  /// The pinch's own scale is the factor, as a drag's ratio of distances is: no anchor to measure from.
  void _pinchUpdate(PointerPanZoomUpdateEvent event) {
    final strip = _pinchStrip;
    if (strip == null || (_zoomStrip == null && (event.scale - 1).abs() < 0.02)) return;
    setState(() {
      _zoomStrip = strip;
      _zoom = event.scale.clamp(strip.min, strip.max).toDouble();
    });
  }

  void _pinchEnd(PointerPanZoomEndEvent _) {
    final pinched = _pinchStrip != null && _zoomStrip == _pinchStrip;
    _pinchStrip = null;
    if (pinched) _zoomCommit();
  }

  void _zoomEnd(DragEndDetails _) => _zoomCommit();

  void _zoomCommit() {
    final strip = _zoomStrip;
    _zoomStrip = null;
    if (strip == null || (_zoom - 1).abs() < 0.02) return setState(() => _zoom = 1);
    _sendControl(strip, 'commit', value: _zoom);
    // An answer that redraws nothing — a zoom the extension clamps away, or refuses — must not
    // leave the preview standing: it would show a zoom the scene does not have.
    _zoomHold?.cancel();
    _zoomHold = Timer(const Duration(seconds: 2), () {
      if (mounted && _zoomStrip == null && _zoom != 1) setState(() => _zoom = 1);
    });
  }

  Timer? _zoomHold;

  bool _zoomEvent(Map<String, dynamic>? event) => event != null && widget.scene.controlsById[event['controlId']]?.kind == 'zoom';

  /// Whether a zoom's event is queued or in flight: the render that answers it is still to come.
  bool get _zoomWaiting => _zoomEvent(_inFlight) || _queue.values.any(_zoomEvent);

  /// A scroll's settle event, or a zoom's: news of the view, not of a value an action acts on.
  bool _viewEvent(Map<String, dynamic> event) => event['controlId'] == '' || _zoomEvent(event);

  /// Whether any layer or control is bound to the scroll's value.
  bool get _boundToScroll {
    final scene = widget.scene;
    if (!identical(_boundFor, scene)) {
      _boundFor = scene;
      final value = scene.scroll?.value;
      _bound =
          value != null &&
          (scene.layers.any((l) => l.text?['value'] == value || l.bindings.values.any((b) => b.value == value)) ||
              scene.controls.any((c) => c.opacityBinding?.value == value));
    }
    return _bound;
  }

  PanelScene? _boundFor;
  bool _bound = false;

  /// The operator's scroll: kept in its value, with no render, and told once it settles.
  bool _onScroll(ScrollNotification note) {
    final scroll = widget.scene.scroll;
    if (scroll == null || note.depth != 0) return false;
    final at = note.metrics.pixels / _scrollScale;
    if (_values[scroll.value] != at) {
      // Redrawn only for artwork that reads the position — a readout of where the view is; the
      // scroll view moves the rest itself, and a rebuild per frame of scrolling would be for nothing.
      if (_boundToScroll) {
        setState(() => _values[scroll.value] = at);
      } else {
        _values[scroll.value] = at;
      }
    }
    // A drag that flings ends twice — the drag, then the coast — and a wheel ends at every notch: only
    // where the scroll has come to rest, and stayed a moment, is news.
    if (note is ScrollEndNotification && scroll.event != null && widget.onEvent != null) {
      _settle?.cancel();
      _settle = Timer(const Duration(milliseconds: 300), () {
        final at = _values[scroll.value];
        if (!mounted || at == null || !_scroller.hasClients || _scroller.position.isScrollingNotifier.value || _scrollSent == at) return;
        _scrollSent = at;
        _scrollsSent = [..._scrollsSent.skip(_scrollsSent.length >= 8 ? 1 : 0), at];
        _queue['\u0000scroll'] = {'controlId': '', 'action': scroll.event, 'phase': 'commit', 'sequence': _sequence, 'value': at};
        _drain();
      });
    }
    return false;
  }

  Widget _artwork(bool reduceMotion) {
    final scene = widget.scene;
    final scroll = scene.scroll;
    if (scroll == null) {
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: scene.width,
            height: scene.height,
            child: ClipRect(child: _stack(reduceMotion)),
          ),
        ),
      );
    }
    final vertical = scroll.axis == 'y';
    return LayoutBuilder(
      builder: (context, box) {
        // Filling the panel across the scroll, as a contained scene would; along it, running on past.
        final scale = vertical ? box.maxWidth / scene.width : box.maxHeight / scene.height;
        // A pane with no room across the scroll, or unbounded: there is no size to draw at, and the
        // scale would put an infinity in the position told to the extension.
        if (!(scale > 0) || !scale.isFinite) return const SizedBox.shrink();
        _scrollScale = scale;
        final panel = Size(vertical ? scene.width : box.maxWidth / scale, vertical ? box.maxHeight / scale : scene.height);
        _paneLength = vertical ? panel.height : panel.width;
        if (_scrollTo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final to = _scrollTo;
            if (!mounted || to == null || !_scroller.hasClients) return;
            _scrollTo = null;
            final pixels = (to * _scrollScale).clamp(0.0, _scroller.position.maxScrollExtent);
            // The extension's own move, not news to send it back.
            _scrollSent = pixels / _scrollScale;
            _scroller.jumpTo(pixels);
          });
        }
        return ClipRect(
          key: _pane,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ScrollConfiguration(
                  // Dragged with a mouse too: on a desktop the artwork is a thing to pull along, not text to select.
                  behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet(), scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scroller,
                    scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
                    child: SizedBox(
                      width: scene.width * scale,
                      height: scene.height * scale,
                      child: FittedBox(
                        child: SizedBox(
                          width: scene.width,
                          height: scene.height,
                          child: Listener(
                            // A trackpad pinch begun on a zoom strip; outside the gesture arena, so
                            // the swipe it may carry still scrolls.
                            behavior: HitTestBehavior.translucent,
                            onPointerPanZoomStart: _pinchStart,
                            onPointerPanZoomUpdate: _pinchUpdate,
                            onPointerPanZoomEnd: _pinchEnd,
                            child: RawGestureDetector(
                              // Over the whole content, so a drag begun on a zoom strip is the strip's
                              // whatever lies on it — a tap there still reaches the button it lands on.
                              behavior: HitTestBehavior.translucent,
                              gestures: _zoomGestures(vertical),
                              child: _stack(reduceMotion, fixed: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: FittedBox(
                  alignment: Alignment.topLeft,
                  child: SizedBox.fromSize(size: panel, child: _stack(reduceMotion, fixed: true)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The scene's layers and the controls placed among them, in paint order, bottom first: all of
  /// them, or with [fixed] only the ones that are, or only the ones that are not.
  Iterable<Object> _painted(bool? fixed) sync* {
    final scene = widget.scene;
    bool drawn(bool isFixed) => fixed == null || isFixed == fixed;
    for (final layer in scene.layers) {
      if (!drawn(layer.fixed)) continue;
      yield layer;
      yield* scene.controls.where((c) => c.after == layer.id);
    }
    // Placed after no layer: above every layer.
    yield* scene.controls.where((c) => c.rect != null && c.after == null && c.kind != 'zoom' && drawn(c.fixed));
  }

  Widget _stack(bool reduceMotion, {bool? fixed}) => Stack(
    children: [
      for (final piece in _painted(fixed))
        if (piece is SceneLayer)
          // Keyed, as is each control's: without it, a layer added
          // before a control shifts the Stack's children, and the
          // control remounts and drops a text field's typing.
          Positioned.fromRect(
            key: ValueKey('layer:${piece.id}'),
            rect: piece.rect,
            child: _zoomed(
              piece.fixed ? null : piece.rect,
              piece.stretch,
              _SceneLayerView(
                key: ValueKey(piece.id),
                layer: piece,
                values: _values,
                strings: _strings,
                immediate: reduceMotion || piece.bindings.values.any((b) => _dirty.contains(b.value)),
                reduceMotion: reduceMotion,
              ),
            ),
          )
        else
          _placed(piece as SceneControl),
    ],
  );

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

class _ControlView extends StatefulWidget {
  final SceneControl control;
  final double value;
  final bool disabled;
  final VoidCallback onStart, onCancel, onCommit;
  final ValueChanged<double> onChange;
  final ValueChanged<String> onSelect;

  /// A knob's second axis — see [SceneControl.yAxis]. Null without one.
  final double? valueY;
  final ValueChanged<double>? onChangeY;
  final VoidCallback? onCommitY;
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
    this.valueY,
    this.onChangeY,
    this.onCommitY,
  });
  @override
  State<_ControlView> createState() => _ControlViewState();
}

class _ControlViewState extends State<_ControlView> {
  bool _focused = false;
  double _dragValue = 0, _dragValueY = 0;
  bool _movedX = false, _movedY = false;
  Offset _tapPosition = Offset.zero;

  /// A drag that began while enabled, and only such a drag: one refused at
  /// its start moves nothing, and one under way still ends with a commit or
  /// a cancel if the control is disabled mid-drag, or its claim on the value
  /// would never be released.
  bool _dragging = false;

  /// A slider or knob clicked into holds focus only briefly — long enough for
  /// the arrow keys to adjust what was just clicked — then hands it back to
  /// where the operator was typing. Focus that arrived by Tab stays.
  static const _pointerFocusHold = Duration(seconds: 3);
  Timer? _releaseFocus;
  FocusNode? _returnFocusTo;

  /// Whether the focus this control holds came from a pointer, and so is
  /// handed back once [_pointerFocusHold] passes without use.
  bool _pointerFocus = false;

  /// [hold] is false at the start of a drag: the hold runs from the release,
  /// or a long drag would lose focus under the operator's hand.
  void _focusFromPointer(FocusNode node, {bool hold = true}) {
    if (!node.hasFocus) {
      _returnFocusTo = FocusManager.instance.primaryFocus;
      _pointerFocus = true;
    }
    node.requestFocus();
    _releaseFocus?.cancel();
    if (hold) _holdPointerFocus(node);
  }

  void _holdPointerFocus(FocusNode node) {
    if (!_pointerFocus) return;
    _releaseFocus?.cancel();
    _releaseFocus = Timer(_pointerFocusHold, () {
      final back = _returnFocusTo;
      _returnFocusTo = null;
      _pointerFocus = false;
      if (!mounted || !node.hasFocus) return;
      if (back != null && back.context != null && back.canRequestFocus) {
        back.requestFocus();
      } else {
        node.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _releaseFocus?.cancel();
    super.dispose();
  }

  void _adjust(double delta) {
    if (widget.disabled) return;
    widget.onChange(widget.value + delta);
    widget.onCommit();
  }

  /// A knob's menu, under it: what a click on it offers while a scroll or a
  /// drag turns it.
  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [for (final item in widget.control.menu!) PopupMenuItem(value: item.event, child: Text(item.label))],
    );
    if (picked != null && mounted) widget.onSelect(picked);
  }

  void _adjustY(double delta) {
    if (widget.disabled || widget.onChangeY == null) return;
    widget.onChangeY!(widget.valueY! + delta);
    widget.onCommitY!();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final button = c.kind == 'button';
    // A knob keeps its own gestures, and opens its menu on a click — see [_openMenu].
    if (c.menu != null && c.kind != 'knob') {
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
        onFocusChange: (v) {
          // Gone elsewhere — by Tab or a click — before the hold ran out.
          if (!v) {
            _releaseFocus?.cancel();
            _returnFocusTo = null;
            _pointerFocus = false;
          }
          setState(() => _focused = v);
        },
        onKeyEvent: (node, event) {
          if (widget.disabled || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (button && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space)) {
            widget.onCommit();
            return KeyEventResult.handled;
          }
          if (!button) {
            final y = c.yAxis;
            final times = HardwareKeyboard.instance.isShiftPressed ? 10 : 1;
            // With a second axis, up and down are its own.
            if (y != null && (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown)) {
              _adjustY(y.step * (key == LogicalKeyboardKey.arrowUp ? 1 : -1) * times);
              _holdPointerFocus(node);
              return KeyEventResult.handled;
            }
            final direction = [LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowUp].contains(key)
                ? 1
                : [LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowDown].contains(key)
                ? -1
                : 0;
            if (direction != 0) {
              _adjust(c.step * direction * times);
              // Still being adjusted: the hold runs from the last key.
              _holdPointerFocus(node);
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
                        final d = event.scrollDelta;
                        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
                          final step = sceneScrollStep(c, d);
                          step.second ? _adjustY(step.delta) : _adjust(step.delta);
                        });
                      }
                    },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: (d) => _tapPosition = d.localPosition,
                onTap: widget.disabled
                    ? null
                    : () {
                        // A button takes no focus from a click: it has nothing to
                        // do with keys afterwards, and the operator's typing stays
                        // where it was. Tab still reaches it. A slider or knob
                        // takes it for [_pointerFocusHold].
                        if (c.kind == 'knob' && c.menu != null) {
                          unawaited(_openMenu(context));
                          return;
                        }
                        if (!button) _focusFromPointer(Focus.of(context));
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
                        _focusFromPointer(Focus.of(context), hold: false);
                        widget.onStart();
                        _dragValue = widget.value;
                        _dragValueY = widget.valueY ?? 0;
                        _movedX = _movedY = false;
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
                          // `invertDrag`: the value moves the other way, as content held under the finger does.
                          final delta = c.invertDrag ? -d.delta : d.delta;
                          if (c.yAxis case final y?) {
                            // Each axis its own: across for the first value, up for the second.
                            if (delta.dx != 0) {
                              _movedX = true;
                              _dragValue = (_dragValue + delta.dx * c.sensitivity).clamp(c.min, c.max).toDouble();
                              widget.onChange(_dragValue);
                            }
                            if (delta.dy != 0) {
                              _movedY = true;
                              _dragValueY = (_dragValueY - delta.dy * y.sensitivity).clamp(y.min, y.max).toDouble();
                              widget.onChangeY!(_dragValueY);
                            }
                          } else {
                            _dragValue = (_dragValue + (delta.dx - delta.dy) * c.sensitivity).clamp(c.min, c.max).toDouble();
                            widget.onChange(_dragValue);
                          }
                        }
                      },
                onPanEnd: button
                    ? null
                    : (_) {
                        if (!_dragging) return;
                        _dragging = false;
                        _holdPointerFocus(Focus.of(context));
                        if (c.yAxis == null || _movedX) widget.onCommit();
                        if (_movedY) widget.onCommitY?.call();
                      },
                onPanCancel: button
                    ? null
                    : () {
                        if (!_dragging) return;
                        _dragging = false;
                        _holdPointerFocus(Focus.of(context));
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
