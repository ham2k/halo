// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A scene's `map` control: the world in Web Mercator, equirectangular,
// Miller's, Patterson's, azimuthal equidistant or Robinson's projection,
// zoomed and panned by the operator within the scene's limits, with the
// scene's markers and the great circles between them over it. The host draws it and moves the view; the extension says
// what is on it (docs/design/panel-scenes.md § Map).

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart' show MdiIcons;

import '../../map/map_grayline.dart' show capAround, capEdgePoints;
import '../world_map/map_camera.dart';
import '../world_map/map_projection.dart';
import '../world_map/world_geometry.dart' show TurningShapes, fillRings;
import 'scene_model.dart';
import 'scene_world.dart';

/// How far, in pixels, a click reaches past a marker's edge or a line's side.
const double _reach = 6;

class SceneMapView extends StatefulWidget {
  final SceneControl control;
  final Map<String, double> values;
  final bool disabled;

  /// The operation's location: the view's middle where the scene names none.
  final GridLocation? home;

  /// A click on the map, off every marker and line that acts.
  final void Function(Map<String, Object> at)? onClick;

  /// A marker's or line's event or menu item: its id, the action, where.
  final void Function(String id, String action, Map<String, Object> at)? onItem;

  /// Where a zoom or a pan ended: `zoom` with the zoom, `pan` with the view's
  /// middle, `reset` from the whole-map button.
  final void Function(String gesture, double? value, Map<String, Object>? at)? onGesture;

  /// Writes a scene value the control owns — the zoom, the place under the pointer.
  final void Function(String name, double value)? onReadout;

  const SceneMapView({
    super.key,
    required this.control,
    required this.values,
    this.disabled = false,
    this.home,
    this.onClick,
    this.onItem,
    this.onGesture,
    this.onReadout,
  });

  @override
  State<SceneMapView> createState() => _SceneMapViewState();
}

class _SceneMapViewState extends State<SceneMapView> {
  SceneMapSpec get _spec => widget.control.map!;

  late final _world = WorldMapBase(onChanged: _onChange, errorContext: 'map');

  /// The operator's zoom and view, held over the scene's until it changes its own.
  double? _zoom;
  double? _sceneZoom;
  Offset? _center;
  GridLocation? _sceneCenter;

  /// The meridian a Robinson map that [_wraps] is turned to: the operator's,
  /// until the scene changes its own view.
  double? _meridian;

  /// The azimuthal map's middle with no `origin`: the scene's view as it
  /// last moved it, not as it hands back where a pan settled — re-centred
  /// on that, the map would move the operator's view off it by the pan
  /// again.
  GridLocation? _middle;

  /// The projection last drawn, by name: a change carries the place in the
  /// view's middle over to the new one.
  String? _drawnAs;

  /// The zoom and the view's middle last sent as where a gesture settled. A
  /// scene that keeps the operator's view hands them back as its own, a
  /// render later; taken as the scene moving the view, that echo would let
  /// go of the operator's, and a gesture already under way when it lands
  /// would draw a frame back where the last one ended.
  double? _sentZoom;
  GridLocation? _sentCenter;

  MapCamera? _camera;
  _Placed? _placed;

  /// Each line's great circle by its ends, kept from render to render: a
  /// panel that keeps the operator's view renders on every pan, and with a
  /// thousand lines, making them all again each time is most of its cost.
  /// The projection, which a pan of a Robinson map turns, only places them.
  Map<_Ends, _Arc> _arcs = const {};

  /// Each circle's edge by its middle and radius, kept the same way.
  Map<_Round, _Circle> _circles = const {};

  /// A gesture under way: where it began, at what zoom and center.
  bool _gesturing = false;
  bool _trackpad = false;
  double _startZoom = 0;
  Offset _startCenter = Offset.zero;
  MapProjection? _startProjection;
  Offset _startFocal = Offset.zero;
  double _scrolled = 0;
  bool _moved = false;
  Timer? _wheelSettle;

  final _written = <String, double>{};

  @override
  void initState() {
    super.initState();
    _world.start();
  }

  @override
  void didUpdateWidget(SceneMapView old) {
    super.didUpdateWidget(old);
    final written = _spec.written.toSet();
    _written.removeWhere((name, _) => !written.contains(name));
  }

  @override
  void dispose() {
    _world.dispose();
    _wheelSettle?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------- the view

  GridLocation get _sceneCenterNow => switch (_spec.home) {
    final h? => GridLocation(h.lat, h.lon),
    null => widget.home ?? const GridLocation(0, 0),
  };

  /// Whether the view goes on round the world east and west: any map but
  /// the azimuthal, with no pan bounds.
  bool get _wraps => _spec.projection != 'azimuthal' && _spec.panBounds == null;

  /// The scene's own view moved: the operator's, held over it, is let go.
  void _noteScene(GridLocation scene) {
    if (_sceneCenter == scene) return;
    _sceneCenter = scene;
    // Once: a scene that later goes back to that place is moving the view.
    final sent = _sentCenter;
    _sentCenter = null;
    if (sent != null && _same(sent.latitude, scene.latitude) && _same(sent.longitude, scene.longitude)) return;
    _center = null;
    _meridian = null;
    _middle = scene;
  }

  /// Equal as a number that went to the extension and came back.
  static bool _same(double a, double b) => (a - b).abs() < 1e-6;

  /// The azimuthal map is centred on `origin`, or the scene's own view
  /// ([_middle]). A rectangular world repeats east and west, so its meridian
  /// is Greenwich's. Robinson cannot repeat — its world's edges are curves —
  /// so a pan turns the world under the view instead, its meridian always
  /// the view's middle. Pan bounds hold either to the meridian through their
  /// middle, so the seam lies behind them.
  MapProjection _projectionFor(GridLocation sceneCenter) {
    if (_spec.projection == 'azimuthal') {
      return AzimuthalProjection(switch (_spec.origin) {
        final o? => GridLocation(o.lat, o.lon),
        null => _middle ?? sceneCenter,
      });
    }
    final bounded = switch (_spec.panBounds) {
      final b? => wrapLongitude(b.west + (b.east >= b.west ? b.east - b.west : b.east + 360 - b.west) / 2),
      null => null,
    };
    return switch (_spec.projection) {
      'robinson' => RobinsonProjection(bounded ?? _meridian ?? wrapLongitude(sceneCenter.longitude)),
      'equirectangular' => EquirectangularProjection(bounded ?? 0),
      'miller' => MillerProjection(bounded ?? 0),
      'patterson' => PattersonProjection(bounded ?? 0),
      _ => MercatorProjection(bounded ?? 0),
    };
  }

  /// The operator's view at [zoom] with [center], a point of [from], moved
  /// to keep [anchor], the point under the pointer, under it. On a Robinson
  /// map that wraps, the east-west part of a move turns the world instead,
  /// keeping the view's middle on the meridian, by as much as moves the
  /// anchor's parallel that far: they shorten toward the poles.
  void _moveTo(double zoom, Offset center, MapProjection from, Offset anchor) {
    _zoom = zoom;
    if (from is RobinsonProjection && _wraps) {
      final latitude = from.toEarth(0, anchor.dy)?.latitude ?? 0;
      _meridian = wrapLongitude(from.meridian + RobinsonProjection.degreesAcross(center.dx, latitude: latitude));
      _center = Offset(0, center.dy);
    } else {
      _center = center;
    }
  }

  /// The scene's projection changed: the operator's view, in the old one's
  /// units, is the place in its middle in the new one. Kept as it was, it
  /// means somewhere else: a Mercator view of New York is a corner of the
  /// azimuthal disc, near its antipode.
  void _carryOver(GridLocation sceneCenter) {
    final camera = _camera;
    final at = _drawnAs == null || _center == null || camera == null ? null : camera.placeAt(camera.middle);
    _drawnAs = _spec.projection;
    _meridian = null;
    _center = null;
    if (at == null) return;
    if (_spec.projection == 'robinson' && _wraps) _meridian = at.longitude;
    _center = _toMap(_projectionFor(sceneCenter), at.latitude, at.longitude);
  }

  /// The least zoom that fills the pane with the world, for a view that
  /// covers; as of the last layout, since it follows the pane's shape.
  double _coverZoom = 0;

  /// The widest the view may go: the scene's, or the zoom that fills the
  /// pane when it covers, unless that is past the scene's closest.
  double get _zoomFloor => _spec.panCover ? math.min(math.max(_spec.zoomMin, _coverZoom), _spec.zoomMax) : _spec.zoomMin;

  double get _zoomNow {
    final scene = (_spec.zoom?.resolve(widget.values) ?? _spec.zoomMin).clamp(_spec.zoomMin, _spec.zoomMax).toDouble();
    if (_sceneZoom != scene) {
      _sceneZoom = scene;
      // Once, as with the view's middle: a pan settles without sending a
      // zoom, so a zoom sent earlier would still be taken for an echo when
      // the scene comes back to it.
      final echo = _sentZoom != null && _same(_sentZoom!, scene);
      _sentZoom = null;
      if (!echo) _zoom = null;
    }
    return math.max(_zoom ?? scene, _zoomFloor);
  }

  /// The view's middle in [projection]: the operator's, until the scene changes its own.
  Offset _centerNow(MapProjection projection, GridLocation scene) => _center ?? _toMap(projection, scene.latitude, scene.longitude) ?? Offset.zero;

  /// A place in [projection], held to the latitudes a rectangular world is cut at.
  static Offset? _toMap(MapProjection projection, double lat, double lon) => projection.toMap(switch (projection) {
    RectangularProjection(:final maxLatitude) => lat.clamp(-maxLatitude, maxLatitude).toDouble(),
    _ => lat,
  }, lon);

  Rect? _bounds(MapProjection projection) => switch (_spec.panBounds) {
    final b? => projectedBounds(projection, north: b.north, south: b.south, west: b.west, east: b.east),
    null => null,
  };

  /// The view in a pane of [size] as the state holds it now, not as the last
  /// frame drew it: a gesture can end before the frame its last move asked
  /// for is built.
  MapCamera _cameraNow(Size size) {
    final scene = _sceneCenterNow;
    final projection = _projectionFor(scene);
    final bounds = _bounds(projection);
    final wraps = _wraps && projection is RectangularProjection;
    if (_spec.panCover) _coverZoom = MapCamera.coverZoom(size, projection, bounds: bounds, wraps: wraps);
    return MapCamera(size, projection, zoom: _zoomNow, center: _centerNow(projection, scene), bounds: bounds, wraps: wraps, cover: _spec.panCover);
  }

  // ------------------------------------------------------------- gestures

  Map<String, Object> _at(Offset screen, [GridLocation? place]) {
    final where = place ?? _camera?.placeAt(screen);
    return {
      'x': screen.dx,
      'y': screen.dy,
      if (where != null) ...{'lat': where.latitude, 'lon': where.longitude},
    };
  }

  void _onTapUp(TapUpDetails e) {
    final camera = _camera, placed = _placed;
    if (camera == null || placed == null || widget.disabled) return;
    final p = e.localPosition;
    final hit = placed.hit(p, camera, _zoomNow);
    if (hit == null) {
      widget.onClick?.call(_at(p));
      return;
    }
    final at = _at(p, hit.place);
    if (hit.item.menu case final menu?) {
      final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
      final point = overlay.globalToLocal(e.globalPosition);
      showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(point & Size.zero, Offset.zero & overlay.size),
        items: [for (final item in menu) PopupMenuItem(value: item.event, child: Text(item.label))],
      ).then((picked) {
        if (picked != null && mounted) widget.onItem?.call(hit.item.id, picked, at);
      });
      return;
    }
    widget.onItem?.call(hit.item.id, hit.item.event!, at);
  }

  void _onScaleStart(ScaleStartDetails e) {
    final camera = _camera;
    if (camera == null || widget.disabled) return;
    _gesturing = true;
    _trackpad = e.kind == PointerDeviceKind.trackpad;
    _moved = false;
    _startZoom = _zoomNow;
    _startCenter = camera.center;
    _startProjection = camera.projection;
    _startFocal = e.localFocalPoint;
    _scrolled = 0;
  }

  void _onScaleUpdate(ScaleUpdateDetails e) {
    final camera = _camera, from = _startProjection;
    if (camera == null || from == null || !_gesturing) return;
    final trackpad = _trackpad;
    var zoom = _startZoom;
    if (_spec.zoomGesture != 'off') {
      if (trackpad) {
        // A trackpad's two-finger scroll comes as the focal point moving: up zooms in, as the wheel does.
        _scrolled += e.focalPointDelta.dy;
        zoom = _startZoom + _scrolled / 200 + math.log(e.scale) / math.ln2;
      } else {
        zoom = _startZoom + math.log(e.scale) / math.ln2;
      }
      zoom = zoom.clamp(_zoomFloor, _spec.zoomMax).toDouble();
    }
    final start = MapCamera(camera.size, from, zoom: _startZoom, center: _startCenter, wraps: camera.wraps);
    final anchor = start.toMap(_startFocal);
    final focal = trackpad || _spec.panGesture == 'off' ? _startFocal : e.localFocalPoint;
    final center = start.centerKeeping(anchor, focal, zoom);
    _moved = _moved || zoom != _startZoom || center != _startCenter;
    setState(() => _moveTo(zoom, center, from, anchor));
  }

  void _onScaleEnd(ScaleEndDetails e) {
    if (!_gesturing) return;
    _gesturing = false;
    if (!_moved) return;
    final camera = switch (_camera) {
      final drawn? => _cameraNow(drawn.size),
      null => null,
    };
    if (camera != null) _settled(camera, zoomed: _zoomNow != _startZoom);
  }

  /// A gesture done: the view held where the limits put it, so the next one
  /// starts from what is drawn, and where it settled sent to the scene.
  void _settled(MapCamera camera, {required bool zoomed}) {
    setState(() => _center = camera.center);
    if (zoomed) widget.onGesture?.call('zoom', _sentZoom = _zoomNow, null);
    final middle = _sentCenter = camera.placeAt(camera.middle);
    widget.onGesture?.call('pan', null, _at(camera.middle, middle));
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (_spec.zoomGesture == 'off' || widget.disabled) return;
    final steps = switch (e) {
      PointerScrollEvent(:final scrollDelta) => -scrollDelta.dy / 200,
      // A trackpad's pinch in a browser: it never reaches the scale gesture.
      PointerScaleEvent(:final scale) when scale > 0 => math.log(scale) / math.ln2,
      _ => null,
    };
    if (steps == null) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final camera = _camera;
      if (camera == null) return;
      final zoom = (_zoomNow + steps).clamp(_zoomFloor, _spec.zoomMax).toDouble();
      final anchor = camera.toMap(event.localPosition);
      final center = camera.centerKeeping(anchor, event.localPosition, zoom);
      setState(() => _moveTo(zoom, center, camera.projection, anchor));
      _wheelSettle?.cancel();
      _wheelSettle = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final held = switch (_camera) {
          final drawn? => _cameraNow(drawn.size),
          null => null,
        };
        if (held != null) _settled(held, zoomed: true);
      });
    });
  }

  void _onHover(PointerHoverEvent e) {
    final camera = _camera;
    final onReadout = widget.onReadout;
    if (camera == null || onReadout == null || (_spec.hoverLat == null && _spec.hoverLon == null)) return;
    final place = camera.placeAt(e.localPosition);
    if (_spec.hoverLat case final name?) onReadout(name, place?.latitude ?? double.negativeInfinity);
    if (_spec.hoverLon case final name?) onReadout(name, place?.longitude ?? double.negativeInfinity);
  }

  /// Back to the scene's own view, forgetting the operator's.
  void _resetView() {
    // A wheel's settle still to come would hold the view it left and send
    // it, undoing the reset.
    _wheelSettle?.cancel();
    setState(() {
      _zoom = null;
      _center = null;
      _meridian = null;
    });
    widget.onGesture?.call('reset', null, null);
  }

  /// The scene values the control writes, as they change; after the frame,
  /// since a write is a setState of the scene's.
  void _writeReadouts() {
    final onReadout = widget.onReadout;
    final name = _spec.zoomValue;
    if (onReadout == null || name == null || _written[name] == _zoomNow) return;
    final zoom = _written[name] = _zoomNow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onReadout(name, zoom);
    });
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final palette = MapPalette.named(_spec.map.palette);
    final background = _spec.map.background ?? palette.backgroundFor(dark);
    final sceneCenter = _sceneCenterNow;
    _noteScene(sceneCenter);
    if (_drawnAs != _spec.projection) _carryOver(sceneCenter);
    final projection = _projectionFor(sceneCenter);
    _world.project(_spec.map.world ? projection : null);
    if (_placed?.spec != _spec || _placed?.projection != projection) {
      if (_placed?.spec != _spec) {
        _arcs = _Placed.arcsOf(_spec, _arcs);
        _circles = _Placed.circlesOf(_spec, _circles);
      }
      _placed = _Placed(_spec, projection, _arcs, _circles, _placed);
    }
    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final camera = _camera = _cameraNow(size);
          // After the layout: a view that covers zooms by the pane's shape.
          _writeReadouts();
          final moved = _zoom != null || _center != null;
          final still = _spec.panGesture == 'off' && _spec.zoomGesture == 'off';
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
                      // With nothing to do, no recognizer at all: one that
                      // only ignores a drag still wins it from a scroll round the map.
                      onScaleStart: still ? null : _onScaleStart,
                      onScaleUpdate: still ? null : _onScaleUpdate,
                      onScaleEnd: still ? null : _onScaleEnd,
                      child: CustomPaint(
                        painter: _MapPainter(
                          camera: camera,
                          spec: _spec,
                          world: _world,
                          placed: _placed!,
                          colors: mapColorsOf(_spec.map, dark: dark),
                          dark: dark,
                          palette: palette,
                          sea: _spec.map.world ? mapColorsOf(_spec.map, dark: dark).sea : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (moved && _spec.actions)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton(
                    icon: Icon(MdiIcons.fitToScreenOutline, semanticLabel: context.t.operation.layout.panels.mapResetView),
                    onPressed: widget.disabled ? null : _resetView,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A line's ends, latitude and longitude, from and to: all its great circle
/// depends on.
typedef _Ends = (double, double, double, double);

/// How many great circles the maps have made, for a test to see they are
/// made again only when a line's ends move.
@visibleForTesting
int mapGreatCirclesMade = 0;

/// A line's great circle, as longitude, latitude pairs, and made ready for
/// the last cylindrical projection it was placed in to turn.
class _Arc {
  final Float32List points;
  TurningShapes? _turning;

  _Arc(_Ends e)
    : points = Float32List.fromList([
        for (final p in greatCircle(GridLocation(e.$1, e.$2), GridLocation(e.$3, e.$4))) ...[p.longitude, p.latitude],
      ]) {
    mapGreatCirclesMade++;
  }

  TurningShapes turning(CylindricalProjection projection) => switch (_turning) {
    final t? when t.family == projection.runtimeType => t,
    _ => _turning = TurningShapes.lines(projection, [points]),
  };
}

/// A circle's middle, latitude and longitude, and its radius in km.
typedef _Round = (double, double, double);

/// A circle's edge, as longitude, latitude pairs: once round, closed, to
/// stroke; and as the grayline's caps are laid out, round the pole it holds
/// if it holds one, to fill.
class _Circle {
  final Float32List edge, ring;

  /// Whether [ring] is the edge laid round the circle's antipode, and the
  /// circle what lies outside it: one that holds both poles. Its edge, a
  /// loop round neither, is laid out as plain as a small one, and filled
  /// as it is, it would be the antipode's side of the Earth.
  final bool outside;
  TurningShapes? _edge, _ring;

  _Circle._(this.edge, this.ring, this.outside);

  factory _Circle(_Round r) {
    // A degree of a great circle is the Earth's circumference over 360, on
    // the sphere distanceOnEarthKm measures: a circle at a contact's
    // distance passes through it.
    final degrees = r.$3 / (2 * math.pi * 6371.0 / 360);
    final center = GridLocation(r.$1, r.$2);
    final outside = degrees > 90 + center.latitude.abs();
    final ring = outside ? capAround(GridLocation(-center.latitude, wrapLongitude(center.longitude + 180)), 180 - degrees) : capAround(center, degrees);
    final edge = ring.take(capEdgePoints).toList();
    return _Circle._(
      Float32List.fromList([
        for (final p in [...edge, edge.first]) ...[p.longitude, p.latitude],
      ]),
      Float32List.fromList([
        for (final p in ring) ...[p.longitude, p.latitude],
      ]),
      outside,
    );
  }

  List<List<Offset>> edgeIn(MapProjection projection) => switch (projection) {
    final CylindricalProjection c => (_edge = _turned(_edge, c, () => TurningShapes.lines(c, [edge]))).runs(c.meridian),
    _ => projectRuns(projection, edge),
  };

  /// What the circle holds, filled even-odd: past the world's edges where
  /// it is [outside], a box round everything else turning it over.
  Path fillIn(MapProjection projection) {
    final fill = switch (projection) {
      final CylindricalProjection c => (_ring = _turned(_ring, c, () => TurningShapes.rings(c, [ring]))).fill(c.meridian),
      _ => fillRings(projection, [ring]),
    };
    final world = projection.world;
    return outside ? (fill..addRect(world.inflate(world.width))) : fill;
  }

  static TurningShapes _turned(TurningShapes? kept, CylindricalProjection projection, TurningShapes Function() make) =>
      kept != null && kept.family == projection.runtimeType ? kept : make();
}

/// What a circle [km] round [center] holds in [projection], as the map fills it.
@visibleForTesting
Path mapCircleFill(MapProjection projection, GridLocation center, double km) => _Circle((center.latitude, center.longitude, km)).fillIn(projection);

/// The markers, lines and circles placed in one projection, in its units:
/// placed once per scene and projection, moved onto the screen each frame.
class _Placed {
  final SceneMapSpec spec;
  final MapProjection projection;

  /// Each line's ends, in [spec]'s order.
  final List<_Ends> ends;

  /// Each marker's point, null where the projection does not draw it.
  final List<Offset?> markers;

  /// Each line's great circle, broken at the projection's seams.
  final List<Path> lines;

  /// Each line's stretches, as points, for a click to be measured against.
  final List<List<List<Offset>>> stretches;

  /// Each circle's middle and radius, in [spec]'s order.
  final List<_Round> rounds;

  /// Each circle's edge, as a path and as stretches of points, and what it
  /// holds, filled where its look has a fill.
  final List<Path> edges;
  final List<Path?> fills;
  final List<List<List<Offset>>> edgeStretches;

  /// Each marker's, line's and circle's look, worked out once per scene:
  /// with thousands of markers, merging each one's again on every frame and
  /// every click check is most of what drawing them costs.
  final List<SceneMapLook> markerLooks, lineLooks, circleLooks;

  _Placed._(
    this.spec,
    this.projection,
    this.ends,
    this.markers,
    this.lines,
    this.stretches,
    this.rounds,
    this.edges,
    this.edgeStretches,
    this.fills,
    this.markerLooks,
    this.lineLooks,
    this.circleLooks,
  );

  static List<_Round> _roundsOf(SceneMapSpec spec) {
    final byId = {for (final m in spec.markers) m.id: m};
    return [
      for (final c in spec.circles)
        switch (c.at) {
          final String id => (byId[id]!.lat, byId[id]!.lon, c.km),
          final ({double lat, double lon}) at => (at.lat, at.lon, c.km),
          _ => throw StateError('A map circle is round a marker or a place'),
        },
    ];
  }

  /// Each circle of [spec]'s edge, by its middle and radius: the one
  /// [before] has where neither has changed.
  static Map<_Round, _Circle> circlesOf(SceneMapSpec spec, Map<_Round, _Circle> before) => {for (final r in _roundsOf(spec)) r: before[r] ?? _Circle(r)};

  static List<_Ends> _endsOf(SceneMapSpec spec) {
    final byId = {for (final m in spec.markers) m.id: m};
    (double, double) end(Object e) => switch (e) {
      final String id => (byId[id]!.lat, byId[id]!.lon),
      final ({double lat, double lon}) at => (at.lat, at.lon),
      _ => throw StateError('A map line end is a marker or a place'),
    };
    return [
      for (final line in spec.lines)
        switch ((end(line.from), end(line.to))) {
          ((final a, final b), (final c, final d)) => (a, b, c, d),
        },
    ];
  }

  /// The great circle of each line of [spec], by its ends: the one [before]
  /// has where its ends have not moved.
  static Map<_Ends, _Arc> arcsOf(SceneMapSpec spec, Map<_Ends, _Arc> before) => {for (final e in _endsOf(spec)) e: before[e] ?? _Arc(e)};

  /// [spec]'s markers and lines in [projection]; a line [before] placed in
  /// the same projection with the same ends is taken as it is.
  factory _Placed(SceneMapSpec spec, MapProjection projection, Map<_Ends, _Arc> arcs, Map<_Round, _Circle> circles, _Placed? before) {
    // Past Web Mercator's cut, a marker sits on the edge, where its lines end.
    final markers = [for (final m in spec.markers) _SceneMapViewState._toMap(projection, m.lat, m.lon)];
    final ends = _endsOf(spec);
    final kept = <_Ends, (Path, List<List<Offset>>)>{
      if (before != null && before.projection == projection)
        for (final (i, e) in before.ends.indexed) e: (before.lines[i], before.stretches[i]),
    };
    final lines = <Path>[];
    final stretches = <List<List<Offset>>>[];
    for (final e in ends) {
      final (path, runs) = kept[e] ??= () {
        final arc = arcs[e]!;
        final runs = projection is CylindricalProjection ? arc.turning(projection).runs(projection.meridian) : projectRuns(projection, arc.points);
        final path = Path();
        for (final r in runs) {
          path.addPolygon(r, false);
        }
        return (path, runs);
      }();
      lines.add(path);
      stretches.add(runs);
    }
    final sameSpec = before?.spec == spec;
    final markerLooks = sameSpec ? before!.markerLooks : [for (final m in spec.markers) spec.lookOf(m)];
    final lineLooks = sameSpec ? before!.lineLooks : [for (final l in spec.lines) spec.lookOf(l)];
    final circleLooks = sameSpec ? before!.circleLooks : [for (final c in spec.circles) spec.lookOf(c)];
    final rounds = _roundsOf(spec);
    final keptRounds = <_Round, (Path, List<List<Offset>>, Path?)>{
      if (before != null && before.projection == projection)
        for (final (i, r) in before.rounds.indexed) r: (before.edges[i], before.edgeStretches[i], before.fills[i]),
    };
    final edges = <Path>[], edgeStretches = <List<List<Offset>>>[], fills = <Path?>[];
    for (final (i, r) in rounds.indexed) {
      final (edge, runs, kept) = keptRounds[r] ??= () {
        final runs = circles[r]!.edgeIn(projection);
        final edge = Path();
        for (final run in runs) {
          edge.addPolygon(run, false);
        }
        return (edge, runs, null);
      }();
      final fill = circleLooks[i].fill == null ? null : kept ?? circles[r]!.fillIn(projection);
      keptRounds[r] = (edge, runs, fill ?? kept);
      edges.add(edge);
      edgeStretches.add(runs);
      fills.add(fill);
    }
    return _Placed._(spec, projection, ends, markers, lines, stretches, rounds, edges, edgeStretches, fills, markerLooks, lineLooks, circleLooks);
  }

  /// How far past its point, in pixels, the largest marker is drawn at
  /// [zoom]: a copy of the world off the pane by less has a marker in it.
  double reachAt(double zoom) {
    if (_reachZoom == zoom) return _mostReach;
    var most = 0.0;
    for (final look in markerLooks) {
      most = math.max(most, _markerReach(look, zoom));
    }
    _reachZoom = zoom;
    return _mostReach = most;
  }

  double? _reachZoom;
  double _mostReach = 0;

  /// How far past its point a marker in [look] is drawn: its edge's stroke
  /// and the casing a pixel round it.
  static double _markerReach(SceneMapLook look, double zoom) => (look.radius?.at(zoom) ?? _markerRadius) + (look.width?.at(zoom) ?? 1) / 2 + 2;

  /// The marker, line or circle that acts under [p], the topmost: markers
  /// over lines over circles' edges, a later one over an earlier, in
  /// whichever copy of the world [p] is on. A circle is clicked on its edge
  /// alone: a wide one would take every click inside it from the map.
  ({SceneMapItem item, GridLocation? place})? hit(Offset p, MapCamera camera, double zoom) {
    for (final copy in camera.copiesWithin(reachAt(zoom) + _reach)) {
      final found = _hitIn(p - Offset(copy * camera.scale, 0), camera, zoom);
      if (found != null) return found;
    }
    return null;
  }

  ({SceneMapItem item, GridLocation? place})? _hitIn(Offset p, MapCamera camera, double zoom) {
    for (var i = spec.markers.length - 1; i >= 0; i--) {
      final marker = spec.markers[i];
      final at = markers[i];
      if (!marker.acts || at == null) continue;
      // One not drawn at this zoom is not there to click.
      final radius = markerLooks[i].radius?.at(zoom) ?? _markerRadius;
      if (radius <= 0) continue;
      if ((camera.toScreen(at) - p).distance <= radius + _reach) return (item: marker, place: GridLocation(marker.lat, marker.lon));
    }
    for (final (items, looks, runs) in [(spec.lines, lineLooks, stretches), (spec.circles, circleLooks, edgeStretches)]) {
      for (var i = items.length - 1; i >= 0; i--) {
        final item = items[i];
        if (!item.acts) continue;
        final width = looks[i].width?.at(zoom) ?? _lineWidth;
        if (width <= 0) continue;
        if (_near(p, runs[i], camera, width / 2 + _reach)) return (item: item, place: null);
      }
    }
    return null;
  }

  static bool _near(Offset p, List<List<Offset>> runs, MapCamera camera, double reach) {
    for (final run in runs) {
      for (var j = 0; j + 1 < run.length; j++) {
        final a = camera.toScreen(run[j]), b = camera.toScreen(run[j + 1]);
        final ab = b - a;
        final t = ab.distanceSquared == 0 ? 0.0 : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared).clamp(0.0, 1.0);
        if ((a + ab * t - p).distance <= reach) return true;
      }
    }
    return false;
  }
}

const double _markerRadius = 4;
const double _lineWidth = 1.5;

class _MapPainter extends CustomPainter {
  final MapCamera camera;
  final SceneMapSpec spec;
  final WorldMapBase world;
  final _Placed placed;
  final MapColors colors;
  final bool dark;
  final MapPalette palette;
  final Color sea;

  _MapPainter({
    required this.camera,
    required this.spec,
    required this.world,
    required this.placed,
    required this.colors,
    required this.dark,
    required this.palette,
    required this.sea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (camera.scale <= 0) return;
    // Zoomed in, the world and the markers on it run far past the pane, and
    // nothing above this painter cuts them: the rest of the panel would be
    // painted over.
    canvas.clipRect(Offset.zero & size);
    final zoom = camera.zoom;
    // Each copy of the world inside its own edge: a line or the night that
    // runs on past the edge is the next copy's to draw, and drawn twice it
    // would show darker there. A rectangle's edge is cut on whole pixels, so
    // two copies side by side meet with no seam between them.
    for (final copy in camera.copies) {
      final origin = camera.origin + Offset(copy * camera.scale, 0);
      final toScreen = Float64List.fromList([camera.scale, 0, 0, 0, 0, camera.scale, 0, 0, 0, 0, 1, 0, origin.dx, origin.dy, 0, 1]);
      canvas.save();
      if (camera.projection is RectangularProjection) {
        final world = camera.projection.world;
        canvas.clipRect(
          Rect.fromLTRB(
            origin.dx + world.left * camera.scale,
            origin.dy + world.top * camera.scale,
            origin.dx + world.right * camera.scale,
            origin.dy + world.bottom * camera.scale,
          ),
          doAntiAlias: false,
        );
      } else {
        canvas.clipPath(camera.projection.edge.transform(toScreen));
      }
      canvas.drawPaint(Paint()..color = sea);
      world.paint(canvas, origin: origin, scale: camera.scale, style: spec.map, colors: colors, closeness: math.pow(2, zoom).toDouble(), dark: dark);
      for (final (i, look) in placed.circleLooks.indexed) {
        if ((look.fill, placed.fills[i]) case (final fill?, final path?)) canvas.drawPath(path.transform(toScreen), Paint()..color = fill);
        _stroke(canvas, placed.edges[i].transform(toScreen), look, zoom);
      }
      for (final (i, look) in placed.lineLooks.indexed) {
        _stroke(canvas, placed.lines[i].transform(toScreen), look, zoom);
      }
      canvas.restore();
    }
    for (final copy in camera.copiesWithin(placed.reachAt(zoom))) {
      final shift = Offset(copy * camera.scale, 0);
      for (final (i, look) in placed.markerLooks.indexed) {
        final at = placed.markers[i];
        if (at == null) continue;
        final radius = look.radius?.at(zoom) ?? _markerRadius;
        if (radius <= 0) continue;
        final c = camera.toScreen(at) + shift;
        // Its edge and casing reach past the radius: culled at the radius, a
        // wide-edged marker pops in and out at the pane's sides.
        if (!(Offset.zero & size).inflate(_Placed._markerReach(look, zoom)).contains(c)) continue;
        final width = look.width?.at(zoom) ?? 1;
        if (look.casing case final casing?) canvas.drawCircle(c, radius + width / 2 + 1, Paint()..color = casing);
        canvas.drawCircle(c, radius, Paint()..color = look.fill ?? palette.target);
        if (width > 0) {
          canvas.drawCircle(
            c,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..color = look.color ?? palette.casing,
          );
        }
      }
    }
  }

  /// A line, or a circle's edge, in its look: under it its casing, a pixel
  /// wider either side.
  void _stroke(Canvas canvas, Path path, SceneMapLook look, double zoom) {
    final width = look.width?.at(zoom) ?? _lineWidth;
    if (width <= 0) return;
    if (look.dashed == true) path = dashedPath(path);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (look.casing case final casing?) {
      canvas.drawPath(
        path,
        stroke
          ..color = casing
          ..strokeWidth = width + 2,
      );
    }
    canvas.drawPath(
      path,
      stroke
        ..color = look.color ?? palette.heading
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
