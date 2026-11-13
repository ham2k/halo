// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's rotator map: one rotator, on an azimuthal equidistant map of the
// world centred on the station (map_projection.dart says why
// that projection), and whatever the scene places over it by bearing and
// distance or by place on Earth. The host draws it and turns the rotator on
// a click or a drag; the extension says what is drawn
// (docs/design/panel-scenes.md § Rotator map).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_svg/flutter_svg.dart' show PictureInfo, SvgStringLoader, vg;
import 'package:halo_core/halo_core.dart' show GridLocation, realNowMillis;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/cat/equipment.dart' show EquipmentStatus, rotatorArrivedWithin, rotatorHeadingGap;
import '../../station_rows.dart' show StationConnectionToggle;
import '../world_map/map_projection.dart';
import 'scene_model.dart';
import 'scene_rotator_frame.dart';
import 'scene_world.dart';

part 'scene_rotator_painter.dart';
part 'scene_rotator_rubber_band.dart';

/// What a rotator map knows of one rotator, in true degrees.
@immutable
class SceneRotatorReading {
  final String name;
  final EquipmentStatus status;

  /// Connected and answering: only then is a heading given and a turn sent.
  final bool live;

  /// Connected, but no longer answering.
  final bool stale;
  final int? azimuth, elevation, target;

  /// The antenna's own beam, where the device knows it — a directional
  /// switch does, a rotator never.
  final int? beamWidth;

  /// Why no heading comes while connected, or why connecting failed.
  final String? problem;

  const SceneRotatorReading({
    required this.name,
    required this.status,
    required this.live,
    this.stale = false,
    this.azimuth,
    this.elevation,
    this.target,
    this.beamWidth,
    this.problem,
  });

  bool get connected => status == EquipmentStatus.connected;
  bool get busy => status == EquipmentStatus.connecting || status == EquipmentStatus.disconnecting;
}

/// Where rotator maps get their rotators, and the places they centre on and mark.
abstract class SceneRotatorSource {
  /// The node a control's `rotator` names; null names the station's first
  /// rotator. Null when there is no such rotator.
  String? resolve(String? rotator);

  SceneRotatorReading read(String uuid);

  /// Fires when what [read] or [resolve] answer may have changed.
  Listenable get changes;

  /// Whether the panel may turn rotators — and connect them — itself.
  bool get canTurn;

  /// Turns [uuid] to [azimuth]; false when nothing was sent.
  bool turn(String uuid, double azimuth);
  void stop(String uuid);
  void connect(String uuid, {required bool on});

  /// The operation's location, the map's centre where the scene names none.
  GridLocation? get home;

  /// The station in the call field, where its lookup puts it.
  GridLocation? get call;
}

const _current = Color(0xFF001EF9);
const _targetColor = Color(0xFFFF4400);
const _aligned = Color(0xFF000000);
const _hud = Color(0xD9C8C8C8);

/// How close to the station, in pixels, a drag takes hold of the view to pan it.
const double _panGrab = 22;

/// How long a turn sent is drawn ahead of the rotator's own report of it.
const int _pendingMillis = 2000;

const double _earthRadiusKm = 6371.0088;

/// The decorations a scene gets when it names no layers of its own: the
/// beam, the target while turning, the heading (dragged to turn it), and
/// the station in the call field (clicked to aim at it).
List<SceneRotatorLayer> defaultRotatorLayers(double beamWidth, MapPalette palette) {
  String hex(Color c, [int? alpha]) =>
      '#${(alpha == null ? c.toARGB32() : c.toARGB32() & 0xFFFFFF | alpha << 24).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  const arrow = {'width': 16, 'length': 16};
  return [
    if (beamWidth > 0)
      SceneRotatorLayer({
        'id': 'beam',
        'kind': 'wedge',
        'az': 'heading-${beamWidth / 2}deg',
        'az2': 'heading+${beamWidth / 2}deg',
        // A light fill and a fine edge: enough to see the beam over sea and
        // land alike, not so much it hides the map under it.
        'fill': hex(palette.heading, 0x48),
        'turningFill': hex(palette.turning, 0x48),
        'color': hex(palette.heading, 0x8C),
        'turningColor': hex(palette.turning, 0x8C),
        'width': 1,
      }),
    SceneRotatorLayer({
      'id': 'target',
      'kind': 'line',
      'from': {'r': 0},
      'to': {'az': 'target', 'r': 'rim'},
      // Thin and dashed, where the heading is solid: one says where the
      // antenna is going, the other where it is. Cased to hold up over the map.
      'color': hex(palette.target),
      'casing': hex(palette.casing),
      'dashed': true,
      'width': 2.5,
      'head': {'width': 12, 'length': 12},
      'clip': false,
    }),
    SceneRotatorLayer({
      'id': 'heading',
      'kind': 'line',
      'from': {'r': 0},
      'to': {'az': 'heading', 'r': 'rim'},
      'color': hex(palette.heading),
      'turningColor': hex(palette.turning),
      'casing': hex(palette.casing),
      'width': 4.5,
      'head': arrow,
      'drag': 'turn',
      'clip': false,
    }),
    SceneRotatorLayer({
      'id': 'call',
      'kind': 'circle',
      'at': {'place': 'call'},
      'radius': 5,
      'fill': '#FFFF0000',
      'color': '#FFFFFFFF',
      'width': 1.5,
      'aim': true,
    }),
  ];
}

class SceneRotatorView extends StatefulWidget {
  final SceneControl control;
  final SceneRotatorSource? source;
  final Map<String, double> values;
  final bool disabled;

  /// The rotator a control's or a decoration's `rotator` names: the id its
  /// scene's rotator source of that name gives (`PanelScene.rotatorNodeFor`),
  /// or the name as given.
  final String? Function(String? rotator) rotatorNode;

  /// A click or a drag's turn, where the scene hears its turns.
  final ValueChanged<double>? onTurn;

  /// A layer's event or menu item: the layer, the action, the bearing clicked.
  final void Function(SceneRotatorLayer layer, String action, double bearing, Map<String, Object> at)? onLayer;

  /// Where a zoom or a pan ended: `zoom` with the zoom, `pan` with where the station is.
  final void Function(String gesture, double value, Map<String, Object>? at)? onGesture;

  /// Writes a scene value the control owns — the heading, the pointer's bearing.
  final void Function(String name, double value)? onReadout;

  /// Writes a scene string the control owns — the rotator's state.
  final void Function(String name, String value)? onReadoutString;

  const SceneRotatorView({
    super.key,
    required this.control,
    required this.source,
    required this.values,
    this.disabled = false,
    this.rotatorNode = _asGiven,
    this.onTurn,
    this.onLayer,
    this.onGesture,
    this.onReadout,
    this.onReadoutString,
  });

  static String? _asGiven(String? rotator) => rotator;

  @override
  State<SceneRotatorView> createState() => _SceneRotatorViewState();
}

enum _DragMode { none, pinch, pan, layer, band }

class _SceneRotatorViewState extends State<SceneRotatorView> with SingleTickerProviderStateMixin {
  SceneRotatorSpec get _spec => widget.control.rotatorMap!;

  late final _world = WorldMapBase(onChanged: _onChange, errorContext: 'rotator');

  AzimuthalProjection? get _projection => _world.projection as AzimuthalProjection?;

  /// The operator's zoom and pan, held over the scene's until it changes its own.
  double? _zoom;
  double? _sceneZoom;
  Offset? _pan;
  Offset? _scenePan;

  /// A turn sent, by rotator, drawn as its target until the rotator reports one there.
  final _pending = <String, ({double azimuth, int atMillis})>{};

  _DragMode _mode = _DragMode.none;
  double _dragZoom = 1;

  /// How far a trackpad's two-finger scroll has gone since it began, in pixels.
  double _scrolled = 0;
  Offset _dragFrom = Offset.zero;
  _Drawn? _dragging;
  double _dragStart = 0;

  /// A line pulled as a rubber band, and its twang and spin a frame at a time.
  _Band? _band;
  Ticker? _spinner;

  /// Redrawn as the band moves: an extension of this State may not call setState itself.
  void _bandMoved() => setState(() {});

  final _pictures = <String, PictureInfo>{};
  final _loading = <String>{};
  final _written = <String, double>{};

  /// Each rotator's last heading while it answered, by node: what its
  /// `headingDeg` keeps saying once it stops, for a readout to show greyed
  /// beside a `status` that says why.
  final _lastHeading = <String, double>{};

  double _headingOf(_Rotator? r) {
    if (r == null) return double.negativeInfinity;
    if (r.reading.azimuth case final azimuth?) return _lastHeading[r.uuid] = azimuth.toDouble();
    return _lastHeading[r.uuid] ?? double.negativeInfinity;
  }

  final _writtenStatus = <String, String>{};

  RotatorFrame? _frame;
  List<_Drawn> _drawn = const [];

  @override
  void initState() {
    super.initState();
    widget.source?.changes.addListener(_onChange);
    _world.start();
  }

  @override
  void didUpdateWidget(SceneRotatorView old) {
    super.didUpdateWidget(old);
    if (!identical(old.source?.changes, widget.source?.changes)) {
      old.source?.changes.removeListener(_onChange);
      widget.source?.changes.addListener(_onChange);
    }
    _pictures.removeWhere((svg, art) {
      final gone = !(_spec.layers ?? const []).any((l) => l.svg == svg);
      if (gone) {
        art.picture.dispose();
        _loading.remove(svg);
      }
      return gone;
    });
    // A name the scene dropped comes back at the scene's default: forgotten
    // here, it is written again rather than taken as already said.
    final written = _spec.written.toSet();
    _written.removeWhere((name, _) => !written.contains(name));
    _writtenStatus.removeWhere((name, _) => !written.contains(name));
  }

  @override
  void dispose() {
    widget.source?.changes.removeListener(_onChange);
    _world.dispose();
    _spinner?.dispose();
    for (final art in _pictures.values) {
      art.picture.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- the view

  double get _sceneZoomNow => (_spec.zoom?.resolve(widget.values) ?? 1).clamp(_spec.zoomMin, _spec.zoomMax).toDouble();

  /// The zoom drawn: the operator's, until the scene changes its own.
  double get _zoomNow {
    final scene = _sceneZoomNow;
    if (_sceneZoom != scene) {
      _sceneZoom = scene;
      _zoom = null;
    }
    return _zoom ?? scene;
  }

  Offset get _scenePanNow => Offset(_spec.panX?.resolve(widget.values) ?? 0, _spec.panY?.resolve(widget.values) ?? 0);

  /// The pan asked for: the operator's, until the scene changes its own.
  Offset get _panNow {
    final scene = _scenePanNow;
    if (_scenePan != scene) {
      _scenePan = scene;
      _pan = null;
    }
    return _pan ?? scene;
  }

  GridLocation? get _home => switch (_spec.home) {
    final h? => GridLocation(h.lat, h.lon),
    null => widget.source?.home,
  };

  void _syncProjection() {
    final home = _home;
    _world.project(home == null || !_spec.map.world ? null : AzimuthalProjection(home));
  }

  void _loadArt(String svg) {
    if (!_loading.add(svg)) return;
    vg.loadPicture(SvgStringLoader(svg), null).then((art) {
      if (!mounted || !(_spec.layers ?? const []).any((l) => l.svg == svg)) {
        _loading.remove(svg);
        return art.picture.dispose();
      }
      setState(() => _pictures[svg] = art);
    }, onError: (Object e) => debugPrint('[panel scene] rotator layer artwork failed: $e'));
  }

  // ------------------------------------------------------------- rotators

  String? _uuidFor(String? rotator) => widget.source?.resolve(widget.rotatorNode(rotator ?? _spec.rotator));

  /// A rotator's reading, its target drawn ahead where a turn was just sent.
  _Rotator? _rotator(String? rotator) {
    final source = widget.source;
    final uuid = _uuidFor(rotator);
    if (source == null || uuid == null) return null;
    final reading = source.read(uuid);
    var target = reading.target?.toDouble();
    if (_pending[uuid] case final pending?) {
      final reported = reading.target;
      final age = realNowMillis() - pending.atMillis;
      if ((reported != null && rotatorHeadingGap(reported, pending.azimuth.round()) <= 1) || age > _pendingMillis || !reading.live) {
        _pending.remove(uuid);
      } else {
        target = pending.azimuth;
      }
    }
    if (_dragging case final drag? when _uuidFor(drag.layer.rotator) == uuid) target = drag.preview;
    final spinning = _spinningTarget(uuid);
    target = spinning ?? target;
    final azimuth = reading.azimuth;
    final turning = azimuth != null && target != null && rotatorHeadingGap(azimuth, target.round()) > rotatorArrivedWithin;
    return _Rotator(uuid, reading, target: turning || _dragging != null || spinning != null ? target : null, turning: turning);
  }

  /// [bearing], or where the antenna can point that is nearest it.
  double _stopped(double bearing) {
    final b = (bearing % 360 + 360) % 360;
    if (_spec.stops.isEmpty) return b;
    double gap(double s) => ((s - b + 540) % 360 - 180).abs();
    return _spec.stops.reduce((a, s) => gap(s) < gap(a) ? s : a);
  }

  /// Sends a turn to [azimuth] — natively where the scene and the panel's
  /// grant allow, as the scene's event where it hears its turns — or to the
  /// nearest of the scene's stops.
  void _turn(String? rotator, double azimuth) {
    final heading = _stopped(azimuth);
    final uuid = _uuidFor(rotator);
    final source = widget.source;
    if (_spec.turn == 'native' && source != null && uuid != null && source.canTurn) {
      if (source.turn(uuid, heading)) setState(() => _pending[uuid] = (azimuth: heading, atMillis: realNowMillis()));
      return;
    }
    if (_spec.turn != 'off') widget.onTurn?.call(heading);
  }

  // ------------------------------------------------------------- gestures

  _Drawn? _hit(Offset at, bool Function(_Drawn d) wanted) {
    for (final d in _drawn.reversed) {
      if (wanted(d) && d.hits(at)) return d;
    }
    return null;
  }

  Map<String, Object> _at(Offset p) {
    final frame = _frame!;
    return {'x': p.dx, 'y': p.dy, 'bearing': frame.bearingOf(p), if (_projection != null) 'km': (p - frame.station).distance / frame.pxPerKm};
  }

  void _onTapUp(TapUpDetails e) {
    final frame = _frame;
    if (frame == null || widget.disabled) return;
    _dropBand();
    final p = e.localPosition;
    final hit = _hit(p, (d) => d.layer.aim || d.layer.event != null || d.layer.menu != null);
    if (hit != null) {
      final layer = hit.layer;
      if (layer.aim) {
        if (hit.bearing case final bearing?) _turn(layer.rotator, bearing);
        return;
      }
      final at = _at(p);
      final bearing = frame.bearingOf(p);
      if (layer.menu case final menu?) {
        final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
        final point = overlay.globalToLocal(e.globalPosition);
        showMenu<String>(
          context: context,
          position: RelativeRect.fromRect(point & Size.zero, Offset.zero & overlay.size),
          items: [for (final item in menu) PopupMenuItem(value: item.event, child: Text(item.label))],
        ).then((picked) {
          if (picked != null && mounted) widget.onLayer?.call(layer, picked, bearing, at);
        });
        return;
      }
      widget.onLayer?.call(layer, layer.event!, bearing, at);
      return;
    }
    if (!frame.contains(p) || _spec.turn == 'off') return;
    var bearing = frame.bearingOf(p);
    // Near the station in the call field, its own bearing rather than the
    // point's: the operator meant the station, and a few pixels off is
    // degrees off on a world map.
    if (_callPoint case final call? when (call - p).distance <= _spec.snap) bearing = frame.bearingOf(call);
    _turn(null, bearing);
  }

  Offset? get _callPoint {
    final call = widget.source?.call;
    final projection = _projection, frame = _frame;
    if (call == null || projection == null || frame == null) return null;
    final spot = projection.project(call.latitude, call.longitude);
    return frame.toScreen(spot.x, spot.y);
  }

  void _onScaleStart(ScaleStartDetails e) {
    final frame = _frame;
    if (frame == null || widget.disabled) return;
    final p = e.localFocalPoint;
    _dragFrom = p;
    _dragZoom = _zoomNow;
    _scrolled = 0;
    // Two fingers — on a screen or a trackpad — zoom: a pinch by its scale,
    // a trackpad's scroll as the wheel does.
    if (e.pointerCount >= 2 || e.kind == PointerDeviceKind.trackpad) {
      _mode = _spec.zoomGesture == 'off' ? _DragMode.none : _DragMode.pinch;
      return;
    }
    // The station first: the heading starts there, and taken by it a drag
    // meant to pan would turn the rotator.
    if (_spec.panGesture != 'off' && (p - frame.station).distance <= _panGrab) {
      _mode = RotatorFrame.zoomPanLimit(_zoomNow) > 0 ? _DragMode.pan : _DragMode.none;
      // Held from where it is, so a pan asked past the limits does not have to be undone first.
      _pan = frame.pan;
      return;
    }
    final grabbed = _spec.turn == 'off' ? null : _hit(p, (d) => d.layer.drag != null);
    if (grabbed != null) {
      final r = _rotator(grabbed.layer.rotator);
      if (r == null || !r.reading.live) {
        _mode = _DragMode.none;
        return;
      }
      if (_drawsBand(grabbed)) {
        _mode = _DragMode.band;
        return _drawBand(grabbed, p);
      }
      _dropBand();
      _mode = _DragMode.layer;
      _dragStart = r.target ?? r.reading.azimuth?.toDouble() ?? 0;
      setState(() => _dragging = grabbed..preview = grabbed.layer.drag!.turn ? _stopped(frame.bearingOf(p)) : _dragStart);
      return;
    }
    // A drag on the map itself does nothing: the wheel zooms, the station pans.
    _mode = _DragMode.none;
  }

  void _onScaleUpdate(ScaleUpdateDetails e) {
    final frame = _frame;
    if (frame == null) return;
    final p = e.localFocalPoint;
    switch (_mode) {
      case _DragMode.none:
        return;
      case _DragMode.pinch:
        // A trackpad's two-finger scroll comes as the focal point moving: up zooms in, as the wheel.
        _scrolled += e.focalPointDelta.dy;
        setState(() => _zoom = (_dragZoom * e.scale * math.exp(_scrolled / 400)).clamp(_spec.zoomMin, _spec.zoomMax).toDouble());
      case _DragMode.pan:
        // The station follows the pointer; the frame holds it to its limits.
        setState(() => _pan = p - frame.size.center(Offset.zero));
      case _DragMode.layer:
        final drag = _dragging!.layer.drag!;
        final d = p - _dragFrom;
        setState(() => _dragging!.preview = _stopped(drag.turn ? frame.bearingOf(p) : _dragStart + (drag.axis == 'x' ? d.dx : d.dy) * drag.degPerPx));
      case _DragMode.band:
        _pullBand(p);
    }
  }

  void _onScaleEnd(ScaleEndDetails e) {
    final mode = _mode;
    _mode = _DragMode.none;
    switch (mode) {
      case _DragMode.layer:
        final drag = _dragging!;
        setState(() => _dragging = null);
        if (drag.preview case final preview?) _turn(drag.layer.rotator, preview);
      case _DragMode.band:
        _looseBand();
      case _DragMode.pinch:
        widget.onGesture?.call('zoom', _zoomNow, null);
      case _DragMode.pan:
        final held = _frame?.pan ?? _panNow;
        setState(() => _pan = held);
        widget.onGesture?.call('pan', 0, {'x': held.dx, 'y': held.dy});
      case _DragMode.none:
        break;
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || _spec.zoomGesture == 'off' || widget.disabled) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      setState(() => _zoom = (_zoomNow * math.exp(-dy / 400)).clamp(_spec.zoomMin, _spec.zoomMax).toDouble());
      _wheelSettle?.cancel();
      _wheelSettle = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        widget.onGesture?.call('zoom', _zoomNow, null);
      });
    });
  }

  Timer? _wheelSettle;

  void _onHover(PointerHoverEvent e) {
    final frame = _frame;
    final onReadout = widget.onReadout;
    if (frame == null || onReadout == null) return;
    if (_spec.hoverAz case final name?) onReadout(name, frame.bearingOf(e.localPosition));
    if (_spec.hoverKm case final name? when _projection != null) onReadout(name, (e.localPosition - frame.station).distance / frame.pxPerKm);
  }

  /// All the way out, unpanned. Reported as a zoom of 0, for a scene that
  /// keeps the operator's view to forget it rather than give it back.
  void _resetView() {
    setState(() {
      _zoom = _spec.zoomMin;
      _pan = Offset.zero;
    });
    widget.onGesture?.call('zoom', 0, null);
  }

  /// The scene values the control writes, as they change; after the frame,
  /// since a write is a setState of the scene's.
  void _writeReadouts(_Rotator? r) {
    final onReadout = widget.onReadout;
    if (onReadout == null) return;
    final next = <String, double>{
      ?_spec.headingDeg: _headingOf(r),
      ?_spec.targetDeg: r?.target ?? double.negativeInfinity,
      ?_spec.elevationDeg: r?.reading.elevation?.toDouble() ?? double.negativeInfinity,
      ?_spec.zoomValue: _zoomNow,
    };
    String statusOf(_Rotator? r) => r == null
        ? 'none'
        : r.reading.live
        ? (r.target != null ? 'turning' : 'connected')
        : r.reading.stale
        ? 'stale'
        : r.reading.status.name;
    final words = <String, String>{?_spec.status: statusOf(r), for (final other in _spec.rotators) ?other.status: statusOf(_rotator(other.rotator))};
    final saying = {
      for (final MapEntry(:key, :value) in words.entries)
        if (_writtenStatus[key] != value) key: value,
    };
    if (saying.isNotEmpty && widget.onReadoutString != null) {
      _writtenStatus.addAll(saying);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final MapEntry(:key, :value) in saying.entries) {
          widget.onReadoutString!(key, value);
        }
      });
    }
    for (final other in _spec.rotators) {
      final o = _rotator(other.rotator);
      if (other.headingDeg case final n?) next[n] = _headingOf(o);
      if (other.targetDeg case final n?) next[n] = o?.target ?? double.negativeInfinity;
    }
    final changed = {
      for (final MapEntry(:key, :value) in next.entries)
        if (_written[key] != value) key: value,
    };
    if (changed.isEmpty) return;
    _written.addAll(changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final MapEntry(:key, :value) in changed.entries) {
        onReadout(key, value);
      }
    });
  }

  // ------------------------------------------------------------- layout

  /// Every layer placed: its geometry, and its text laid out.
  List<_Drawn> _resolve(RotatorFrame frame, List<SceneRotatorLayer> layers, TextStyle baseText) {
    for (final d in _drawn) {
      d.text?.dispose();
    }
    final values = widget.values;
    final projection = _projection;
    final call = widget.source?.call;
    final rotators = <String?, _Rotator?>{};
    _Rotator? rotatorOf(String? id) => rotators.putIfAbsent(id, () => _rotator(id));
    final lines = <String, (Offset, Offset)>{};
    final out = <_Drawn>[];

    double? angle(SceneRotatorAngle? a, String? rotator) {
      if (a == null) return 0;
      final r = rotatorOf(rotator);
      final base = switch (a.base) {
        SceneRotatorAngleBase.heading => r?.reading.azimuth?.toDouble(),
        SceneRotatorAngleBase.target => r?.target,
        SceneRotatorAngleBase.call => switch ((projection, call)) {
          (final p?, final c?) => headingOf(p.project(c.latitude, c.longitude).x, p.project(c.latitude, c.longitude).y),
          _ => null,
        },
        SceneRotatorAngleBase.az => a.degrees!.resolve(values),
      };
      return base == null ? null : base + a.offset;
    }

    double radius(SceneRotatorRadius? r, double bearing) => (r ?? SceneRotatorRadius.atRim).resolve(frame.rimAt(bearing), frame.pxPerKm);

    // A point on screen, and the bearing and distance it stands for.
    ({Offset at, double bearing, double? km})? point(SceneRotatorPoint p, String? rotator) {
      ({Offset at, double bearing, double? km})? base;
      if (p.on case final on?) {
        final line = lines[on];
        if (line == null) return null;
        final at = Offset.lerp(line.$1, line.$2, p.along)!;
        base = (at: at, bearing: frame.bearingOf(at), km: _projection == null ? null : (at - frame.station).distance / frame.pxPerKm);
      } else if (p.geographic) {
        final place = p.call ? call : GridLocation(p.lat!, p.lon!);
        if (place == null || projection == null) return null;
        final spot = projection.project(place.latitude, place.longitude);
        // Past the rim's antipode it would be drawn on the wrong side of the world.
        if (spot.distance > math.pi * AzimuthalProjection.antipodeCutoff) return null;
        base = (at: frame.toScreen(spot.x, spot.y), bearing: headingOf(spot.x, spot.y), km: spot.distance * _earthRadiusKm);
      } else {
        final bearing = angle(p.az, rotator);
        if (bearing == null) return null;
        final distance = radius(p.r, bearing);
        base = (at: frame.along(bearing, distance), bearing: (bearing % 360 + 360) % 360, km: projection == null ? null : distance / frame.pxPerKm);
      }
      return (at: base.at + Offset(p.dx, p.dy), bearing: base.bearing, km: base.km);
    }

    for (final layer in layers) {
      final r = rotatorOf(layer.rotator);
      final turning = r?.turning == true;
      final d = _Drawn(
        layer,
        color: turning && layer.turningColor != null ? layer.turningColor : layer.color,
        fill: turning && layer.turningFill != null ? layer.turningFill : layer.fill,
      );
      switch (layer.kind) {
        // Expanded into the host's own decorations before anything is placed.
        case SceneRotatorLayerKind.defaults:
          continue;
        case SceneRotatorLayerKind.line:
          final a = point(layer.from!, layer.rotator), b = point(layer.to!, layer.rotator);
          if (a == null || b == null) continue;
          lines[layer.id] = (a.at, b.at);
          d
            ..from = a.at
            ..to = b.at
            ..bearing = b.bearing;
          if (_band case final band? when band.layerId == layer.id && band.pull != 0) {
            final length = (b.at - a.at).distance;
            final dir = length == 0 ? Offset.zero : (b.at - a.at) / length;
            d
              ..nock = Offset.lerp(a.at, b.at, band.along)! + Offset(-dir.dy, dir.dx) * band.pull
              ..loaded = band.swing == null && _bandLoaded(band, length);
          }
        case SceneRotatorLayerKind.wedge:
          final a1 = angle(layer.az, layer.rotator), a2 = angle(layer.az2, layer.rotator);
          if (a1 == null || a2 == null) continue;
          var sweep = (a2 - a1) % 360;
          if (sweep == 0 && a2 != a1) sweep = 360;
          final outer = <Offset>[], inner = <Offset>[];
          final steps = math.max(2, (sweep / 2).ceil());
          for (var i = 0; i <= steps; i++) {
            final b = a1 + sweep * i / steps;
            outer.add(frame.along(b, radius(layer.r2, b)));
            inner.add(frame.along(b, layer.r == null ? 0 : radius(layer.r, b)));
          }
          d
            ..path = (Path()..addPolygon([...outer, ...inner.reversed], true))
            // Each side with the way out of the wedge across it: counterclockwise of the first, clockwise of the last.
            ..sides = [(inner.first, outer.first, RotatorFrame.direction(a1 - 90)), (inner.last, outer.last, RotatorFrame.direction(a1 + sweep + 90))]
            ..bearing = a1 + sweep / 2;
        case SceneRotatorLayerKind.circle || SceneRotatorLayerKind.text || SceneRotatorLayerKind.svg:
          final at = point(layer.at!, layer.rotator);
          if (at == null) continue;
          d
            ..from = at.at
            ..bearing = at.bearing;
          if (layer.kind == SceneRotatorLayerKind.text) {
            final words = _words(layer, r, at.bearing, at.km);
            if (words == null) continue;
            final size = layer.size?.resolve(values) ?? baseText.fontSize ?? 12;
            final weight = layer.weight?.resolve(values);
            d.text = TextPainter(
              text: TextSpan(
                text: words,
                style: baseText.copyWith(
                  color: d.color ?? baseText.color,
                  fontSize: size,
                  fontFamily: layer.fontFamily,
                  fontStyle: layer.italic ? FontStyle.italic : null,
                  fontWeight: weight == null ? null : FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
          }
      }
      out.add(d);
    }
    return out;
  }

  /// What a text layer says, or null where what it shows is not known.
  String? _words(SceneRotatorLayer layer, _Rotator? r, double bearing, double? km) {
    String formatted(double n) => '${layer.prefix ?? ''}${n.toStringAsFixed(layer.decimals)}${layer.suffix ?? ''}';
    if (layer.text case final text?) return text;
    if (layer.value case final name?) {
      final n = widget.values[name];
      return n == null || !n.isFinite ? null : formatted(n);
    }
    final n = switch (layer.show) {
      'heading' => r?.reading.azimuth?.toDouble(),
      'target' => r?.target,
      'elevation' => r?.reading.elevation?.toDouble(),
      'bearing' => bearing,
      'km' => km,
      'mi' => km == null ? null : km / 1.609344,
      _ => null,
    };
    return n == null ? null : formatted(n);
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final p = context.t.operation.layout.panels;
    final source = widget.source;
    final palette = MapPalette.named(_spec.map.palette);
    final background = _spec.map.background ?? palette.backgroundFor(dark);
    final r = _rotator(null);
    _writeReadouts(r);

    if (source == null || r == null) {
      return ColoredBox(
        color: background,
        child: Center(child: Text(p.rotatorNoRotator, textAlign: TextAlign.center)),
      );
    }
    _syncProjection();
    final baseText = theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurface);
    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final frame = RotatorFrame(size, zoom: _zoomNow, widest: _spec.zoomMin, pan: _panNow, panArea: _spec.panArea, panMargin: _spec.panMargin);
          _frame = frame;
          // The antenna's own beam over the scene's: a 90° 4-square drawn at a beam's 30 would show a third of what it covers.
          final defaults = defaultRotatorLayers(r.reading.beamWidth?.toDouble() ?? _spec.beamWidth?.resolve(widget.values) ?? 30, palette);
          final layers = switch (_spec.layers) {
            null => defaults,
            final own => [
              for (final layer in own)
                if (layer.kind == SceneRotatorLayerKind.defaults) ...defaults else layer,
            ],
          };
          _drawn = _resolve(frame, layers, baseText);
          final zoomed = (_zoomNow - _spec.zoomMin).abs() > 0.01 || frame.pan != Offset.zero;
          return Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  onPointerSignal: _onPointerSignal,
                  child: MouseRegion(
                    onHover: _onHover,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _onTapUp,
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      onScaleEnd: _onScaleEnd,
                      child: CustomPaint(
                        painter: _RotatorMapPainter(
                          frame: frame,
                          spec: _spec,
                          world: _world,
                          colors: mapColorsOf(_spec.map, dark: dark),
                          dark: dark,
                          palette: palette,
                          drawn: _drawn,
                          pictures: _pictures,
                          load: _loadArt,
                          values: widget.values,
                          rimColor: theme.colorScheme.onSurface,
                          labelStyle: theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.bold),
                          compass: [p.rotatorNorth, p.rotatorEast, p.rotatorSouth, p.rotatorWest],
                          showStation: _projection != null,
                          sea: _projection == null ? theme.colorScheme.onSurface.withValues(alpha: 0.06) : mapColorsOf(_spec.map, dark: dark).sea,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_spec.hud)
                Positioned(
                  left: Space.sm,
                  top: Space.sm,
                  child: _Hud(reading: r.reading, target: r.target),
                ),
              if (_spec.actions && source.canTurn)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.reading.live && r.target != null)
                        IconButton(
                          icon: Icon(MdiIcons.stopCircleOutline, semanticLabel: context.t.settings.station.rotatorStop),
                          onPressed: widget.disabled
                              ? null
                              : () {
                                  // A shot still spinning would turn it again as it landed.
                                  _dropBand();
                                  source.stop(r.uuid);
                                },
                        ),
                      StationConnectionToggle(
                        busy: r.reading.busy,
                        connected: r.reading.connected,
                        onConnect: widget.disabled ? null : () => source.connect(r.uuid, on: true),
                        onDisconnect: () => source.connect(r.uuid, on: false),
                      ),
                    ],
                  ),
                ),
              // One of the map's own buttons: a scene drawing its own hides it with them.
              if (zoomed && _spec.zoomGesture == 'native' && _spec.actions)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: Icon(MdiIcons.fitToScreenOutline, semanticLabel: p.rotatorResetView),
                    onPressed: _resetView,
                  ),
                ),
              if ([if (_home == null && _spec.map.world) p.rotatorNoLocation, ?r.reading.problem] case final notes when notes.isNotEmpty)
                Positioned(
                  left: Space.md,
                  right: Space.md,
                  bottom: Space.sm,
                  child: Text(notes.join('\n'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Rotator {
  final String uuid;
  final SceneRotatorReading reading;

  /// Where it was told to go — or is being dragged to — while short of it.
  final double? target;
  final bool turning;

  _Rotator(this.uuid, this.reading, {this.target, required this.turning});
}

/// A layer as placed this frame.
class _Drawn {
  final SceneRotatorLayer layer;
  final Color? color, fill;
  Offset? from, to;
  Path? path;

  /// A wedge's two straight sides, without the arcs, each with the way out
  /// of the wedge across it: where its casing goes.
  List<(Offset, Offset, Offset)>? sides;
  TextPainter? text;

  /// The bearing this layer stands at: where a click on it aims.
  double? bearing;

  /// While dragged: the bearing the drag would turn to.
  double? preview;

  /// A line pulled as a rubber band: the point its two halves meet at, and
  /// whether it is pulled far enough that letting go spins the target.
  Offset? nock;
  bool loaded = false;

  _Drawn(this.layer, {this.color, this.fill});

  Rect? get textBox {
    final t = text, at = from;
    if (t == null || at == null) return null;
    final pad = layer.padding?.literal ?? 2;
    final x = switch (layer.align) {
      'start' => at.dx,
      'end' => at.dx - t.width,
      _ => at.dx - t.width / 2,
    };
    final y = switch (layer.valign) {
      'top' => at.dy,
      'bottom' => at.dy - t.height,
      _ => at.dy - t.height / 2,
    };
    return Rect.fromLTWH(x, y, t.width, t.height).inflate(pad);
  }

  /// Whether a pointer at [p] is on it, with a finger's reach around a thin line.
  bool hits(Offset p) {
    switch (layer.kind) {
      case SceneRotatorLayerKind.defaults:
        return false;
      case SceneRotatorLayerKind.line:
        final (a, b) = (from!, to!);
        final ab = b - a;
        final t = ab.distanceSquared == 0 ? 0.0 : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared).clamp(0.0, 1.0);
        final reach = math.max(8.0, (layer.width?.literal ?? 1) / 2 + 6) + (layer.head != null && t > 0.9 ? layer.head!.width / 2 : 0);
        return (a + ab * t - p).distance <= reach;
      case SceneRotatorLayerKind.wedge:
        return path!.contains(p);
      case SceneRotatorLayerKind.circle:
        return (from! - p).distance <= (layer.radius?.literal ?? 4) + 6;
      case SceneRotatorLayerKind.text:
        return textBox?.contains(p) ?? false;
      case SceneRotatorLayerKind.svg:
        return Rect.fromCenter(center: from!, width: layer.svgWidth, height: layer.svgHeight).contains(p);
    }
  }
}

/// The heading and the target, as red-ham-toolkit's corner pill puts them:
/// "45° ➜ 290°" while turning, "290°" once there.
class _Hud extends StatelessWidget {
  final SceneRotatorReading reading;
  final double? target;

  const _Hud({required this.reading, this.target});

  @override
  Widget build(BuildContext context) {
    final p = context.t.operation.layout.panels;
    final style = Theme.of(context).textTheme.titleSmall!.copyWith(fontFamily: 'RobotoMono', fontWeight: FontWeight.bold);
    final azimuth = reading.azimuth;
    final target = this.target?.round();
    final heading = !reading.live
        ? TextSpan(
            text: reading.stale ? p.rotatorNotResponding : p.rotatorDisconnected,
            style: style.copyWith(color: Colors.black54, fontFamily: null),
          )
        : azimuth == null
        ? TextSpan(
            text: p.rotatorNoReading,
            style: style.copyWith(color: _aligned),
          )
        : target != null
        ? TextSpan(
            style: style,
            children: [
              TextSpan(
                text: '$azimuth°',
                style: const TextStyle(color: _current),
              ),
              const TextSpan(
                text: ' ➜ ',
                style: TextStyle(color: _aligned),
              ),
              TextSpan(
                text: '${(target % 360 + 360) % 360}°',
                style: const TextStyle(color: _targetColor),
              ),
            ],
          )
        : TextSpan(
            text: '$azimuth°',
            style: style.copyWith(color: _aligned),
          );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      decoration: BoxDecoration(color: _hud, borderRadius: BorderRadius.circular(Space.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(heading),
          if (reading.live && reading.elevation != null)
            Text(
              p.rotatorElevation(degrees: reading.elevation!),
              style: style.copyWith(color: _aligned, fontSize: (style.fontSize ?? 14) * 0.8),
            ),
        ],
      ),
    );
  }
}
