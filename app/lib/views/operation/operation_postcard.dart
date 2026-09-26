// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Operation Postcard: the Map tab's view of an operation as an image to
// keep or share — the map, with the operation's title and numbers across the
// top and the app's name at the foot, laid out as app-polo's
// OperationBadgeScreen shows them for an operator to screenshot.
//
// The map is a framed one (MapFrame): the Map tab's own center and zoom,
// laid out at the postcard's logical size and scaled into the preview, so
// the preview IS the image at a smaller scale. The image is that same layout
// rendered at [postcardPixelRatio]: on the GL backends the page re-renders
// the map and Flutter the overlay, composited here; the OSM backend's whole
// postcard is Flutter, captured in one piece.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/android_file_save.dart';
import '../../services/error_reporting_service.dart';
import '../../services/image_clipboard.dart';
import '../../services/settings_service.dart';
import '../../services/web_download.dart';
import '../../tools/operation_title.dart';
import '../map/map_gl_script.dart' show mapGlAttribution, mapLibreStyleUrls, mapStyleIsDark, paintMapSpaceBackground;
import '../map/map_marker_data.dart' show MapMarkerData;
import '../map/map_popup.dart' show MapPopupCard;
import '../map/map_zoom_controller.dart';
import '../map/osm_map_view.dart' show osmAttribution;

/// The postcard's shapes, by logical size — half the image's.
enum PostcardShape {
  portrait(Size(540, 960)),
  landscape(Size(960, 540)),
  square(Size(720, 720));

  final Size logicalSize;
  const PostcardShape(this.logicalSize);
}

/// Image pixels per logical pixel: 1080×1920, 1920×1080 and 1440×1440.
const postcardPixelRatio = 2.0;

/// A marker's place on the map, for [postcardCamera] to keep in the picture.
typedef PostcardMarker = ({double latitude, double longitude});

/// The Map tab's open popup, which the postcard draws over [at] itself — the
/// GL map's is a page element over its canvas, and no snapshot of the canvas
/// has it — and keeps in the picture like the markers. [size] is the card and
/// its tip together.
typedef PostcardCallout = ({PostcardMarker at, Size size});

/// Room around a marker kept clear of the image's edges and the header: a
/// dot's radius at its largest, and its ring.
const postcardMarkerMargin = 12.0;

/// Where a callout's tip ends above its marker: the GL map's popup, at the
/// offset the map script opens it with.
const postcardCalloutGap = 12.0;

/// The postcard's camera for a [frame], from what the Map tab showed
/// ([view]): all of the tab's map fits in the image, the side that runs out
/// first setting the zoom, around the tab's own center. The header is laid
/// over it like everything else, and takes no room of its own. The map still
/// covers the whole image; the other way, it shows more around what was
/// framed. A square is cut from the tab instead: the tab's shorter side spans
/// its width, and the longer one is cropped.
///
/// A flat map ([withinWorld]) is kept inside the Web Mercator world, drawn in
/// [tileSize]-pixel tiles: where the image would reach past a pole the camera
/// slides until its edge is the world's, rather than leave a blank strip, and
/// a world shorter than the image is zoomed until it is not. And every one of
/// [markers] the tab showed stays in the picture — with the [callout] over
/// one of them — clear of the edges and of the top [header] pixels the band
/// covers: the camera zooms out no further, and pans no further, than that
/// takes. A whole-world portrait can be too narrow for them all, the world
/// being only so tall; it is then centered on them. A globe keeps the fit
/// alone — this is flat-map arithmetic.
///
/// A postcard is north-up and flat whatever the tab's bearing and pitch: the
/// callout and the markers are placed on it by flat, unturned arithmetic.
MapCameraPosition postcardCamera(
  MapCameraView view,
  Size frame, {
  required double tileSize,
  bool withinWorld = true,
  List<PostcardMarker> markers = const [],
  PostcardCallout? callout,
  double header = 0,
}) {
  final viewport = view.viewport;
  final scale = frame.width == frame.height
      ? frame.width / math.min(viewport.width, viewport.height)
      : math.min(frame.width / viewport.width, frame.height / viewport.height);
  if (!scale.isFinite || scale <= 0) return MapCameraPosition(latitude: view.camera.latitude, longitude: view.camera.longitude, zoom: view.camera.zoom);
  final fitted = MapCameraPosition(latitude: view.camera.latitude, longitude: view.camera.longitude, zoom: view.camera.zoom + math.log(scale) / math.ln2);
  if (!withinWorld) return fitted;

  // Everything to keep in the picture: a point in world units (see
  // [_tabPoint]) and the pixels it needs around that point, which no zoom
  // changes.
  final cx = (view.camera.longitude + 180) / 360;
  final cy = MapCameraPosition.mercatorY(view.camera.latitude);
  ({double x, double y})? shown(PostcardMarker marker) => _tabPoint(view, marker, tileSize: tileSize);

  const m = postcardMarkerMargin;
  final keepers = <({double x, double y, double left, double right, double up, double down})>[
    for (final marker in markers)
      if (shown(marker) case final p?) (x: p.x, y: p.y, left: m, right: m, up: m, down: m),
    if (callout != null)
      if (shown(callout.at) case final p?)
        (x: p.x, y: p.y, left: callout.size.width / 2, right: callout.size.width / 2, up: postcardCalloutGap + callout.size.height, down: m),
  ];

  // The range of centers, in pixels of a world [world] wide, that keeps every
  // keeper in the clear part of the image — empty (lo > hi) where none can.
  ({double lo, double hi}) xRange(double world) => (
    lo: keepers.map((k) => k.x * world + k.right).fold(double.negativeInfinity, math.max) - frame.width / 2,
    hi: keepers.map((k) => k.x * world - k.left).fold(double.infinity, math.min) + frame.width / 2,
  );
  ({double lo, double hi}) yRange(double world) => (
    lo: keepers.map((k) => k.y * world + k.down).fold(double.negativeInfinity, math.max) - frame.height / 2,
    hi: keepers.map((k) => k.y * world - k.up).fold(double.infinity, math.min) + frame.height / 2 - header,
  );
  bool fits(double zoom) {
    final world = tileSize * math.pow(2, zoom);
    final x = xRange(world), y = yRange(world);
    return x.lo <= x.hi && y.lo <= y.hi;
  }

  // A world shorter than the image leaves a blank above or below it whatever
  // the center — and the GL library would zoom in to fill it anyway.
  final floor = math.log(frame.height / tileSize) / math.ln2;
  var zoom = math.max(fitted.zoom, floor);
  if (keepers.isNotEmpty && !fits(zoom) && fits(floor)) {
    // The widest zoom that still fits: the keepers only spread further apart
    // as the map zooms in, so the zooms that fit are all the ones below it.
    var lo = floor, hi = zoom;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    zoom = lo;
  } else if (keepers.isNotEmpty && !fits(zoom)) {
    zoom = floor;
  }
  final world = tileSize * math.pow(2, zoom);

  // The center: the tab's, moved the least that keeps every keeper in the
  // clear part of the image — or on their middle, where no center can hold
  // them all.
  double keep(double center, ({double lo, double hi}) range) => range.lo <= range.hi ? center.clamp(range.lo, range.hi) : (range.lo + range.hi) / 2;
  var x = cx, y = cy;
  if (keepers.isNotEmpty) {
    x = keep(cx * world, xRange(world)) / world;
    y = keep(cy * world, yRange(world)) / world;
  }
  // Inside the world last: a blank strip is never the answer, even for a
  // marker that close to the pole.
  y = y.clamp(frame.height / 2 / world, 1 - frame.height / 2 / world);
  final longitude = x * 360 - 180;
  return MapCameraPosition(
    // The tab's own numbers where nothing moved them, rather than their round
    // trip through the projection.
    latitude: y == cy ? view.camera.latitude : view.camera.atMercatorY(y).latitude,
    longitude: x == cx ? view.camera.longitude : longitude - 360 * ((longitude + 180) / 360).floorToDouble(),
    zoom: zoom,
  );
}

/// Whether the Map tab ([view]) showed any of [marker]'s dot, on a flat map
/// of [tileSize]-pixel tiles.
bool postcardTabShows(MapCameraView view, PostcardMarker marker, {required double tileSize}) => _tabPoint(view, marker, tileSize: tileSize) != null;

/// [marker] in world units — 0..1 across and down the whole Mercator world,
/// x on the copy of the world nearest the tab's center, which is the one the
/// tab drew it on — or null when the tab showed none of its dot. Half a dot at
/// the tab's edge counts: it is a marker the operator saw.
({double x, double y})? _tabPoint(MapCameraView view, PostcardMarker marker, {required double tileSize}) {
  final cx = (view.camera.longitude + 180) / 360;
  final cy = MapCameraPosition.mercatorY(view.camera.latitude);
  final tabWorld = tileSize * math.pow(2, view.camera.zoom);
  final dx = (marker.longitude + 180) / 360 - cx;
  final x = cx + dx - dx.roundToDouble();
  final y = MapCameraPosition.mercatorY(marker.latitude);
  // Where the tab's rotation put it on screen: a bearing names the direction
  // at the top, so the map is turned back by it. Pitch is not reckoned with.
  final turn = -view.camera.bearing * math.pi / 180;
  final east = (x - cx) * tabWorld, south = (y - cy) * tabWorld;
  final across = east * math.cos(turn) - south * math.sin(turn);
  final down = east * math.sin(turn) + south * math.cos(turn);
  if (across.abs() > view.viewport.width / 2 + postcardMarkerMargin || down.abs() > view.viewport.height / 2 + postcardMarkerMargin) return null;
  return (x: x, y: y);
}

/// Where [marker] shows in a [frame] held at [camera] on a flat map of
/// [tileSize]-pixel tiles, in the frame's logical pixels from its top left —
/// on the copy of the world nearest the center.
Offset postcardPoint(MapCameraPosition camera, PostcardMarker marker, Size frame, {required double tileSize}) {
  final world = tileSize * math.pow(2, camera.zoom);
  final dx = (marker.longitude - camera.longitude) / 360;
  return Offset(
    (dx - dx.roundToDouble()) * world + frame.width / 2,
    (MapCameraPosition.mercatorY(marker.latitude) - MapCameraPosition.mercatorY(camera.latitude)) * world + frame.height / 2,
  );
}

/// The widest the shape and style pickers grow, stacked.
const _controlsMaxWidth = 480.0;

/// The width at and above which the style picker sits beside the shapes
/// rather than under them: the shapes' three labels about whole beside a
/// [_styleWidth] picker. Under the modal pane's dialog width (650, 602 inside
/// its padding), so a large screen gets the row.
const _controlsSideBySideWidth = 560.0;

/// The widest the shapes and the style picker grow side by side.
const _controlsRowMaxWidth = 640.0;

/// The style picker's width beside the shapes — its longest name, Dark
/// Matter, with room for the menu arrow.
const _styleWidth = 190.0;

/// The live map for [frame] in [style], wired to [controller] — built by the
/// Map tab with its own backend choice, so the postcard draws with the
/// renderer the operator framed it in.
typedef PostcardMapBuilder = Widget Function(MapFrame frame, MapZoomController controller, MapStyle style);

/// What the overlay says, worked out once when the pane opens.
class PostcardText {
  final String title;
  final String subtitle;
  final String stats;
  final String date;

  const PostcardText({required this.title, required this.subtitle, required this.stats, required this.date});

  /// The station call and the operation's title on the left, as the Operation
  /// View's header leads with them; the contact count, the span they took and
  /// when the first was made on the right.
  factory PostcardText.of(BuildContext context, Operation operation, List<Qso> qsos) {
    final t = context.t.loggingControls.info;
    final contacts = [
      for (final q in qsos)
        if (q.isRealContact) q,
    ];
    final firstMs = contacts.map((q) => q.startAtMillis).nonNulls.fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    final lastMs = contacts.map((q) => q.startAtMillis).nonNulls.fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    final count = contacts.length == 1 ? t.qsoCountOne : t.qsoCountOther(count: contacts.length);
    final start = firstMs == null ? null : DateTime.fromMillisecondsSinceEpoch(firstMs, isUtc: true);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return PostcardText(
      title: '${operation.stationCall} ${displayTitleFor(context, operation)}'.trim(),
      subtitle: displaySubtitleFor(operation),
      stats: firstMs != null && lastMs != null ? t.qsosInTime(count: count, time: fmtTimeBetween(firstMs, lastMs)) : count,
      date: start == null ? '' : '${DateFormat('HH:mm').format(start)}z ${DateFormat.yMMMd(locale).format(start)}',
    );
  }
}

Future<void> showOperationPostcard(
  BuildContext context, {
  required Operation operation,
  required List<Qso> qsos,
  required MapCameraView view,
  required List<PostcardMarker> markers,
  required MapMarkerData? callout,
  required bool globe,
  required bool mapIsFlutter,
  required PostcardMapBuilder mapBuilder,
  required SettingsService settings,
}) {
  final text = PostcardText.of(context, operation, qsos);
  return showModalPane<void>(
    context,
    title: context.t.map.postcard.title(title: text.title),
    closeLabel: context.t.common.close,
    scrollable: false,
    fillHeight: true,
    // The footer's Done is the way out — see haloDialogFooterBand.
    closeButton: false,
    builder: (_) => OperationPostcardPanel(
      operation: operation,
      text: text,
      view: view,
      markers: markers,
      callout: callout,
      globe: globe,
      mapIsFlutter: mapIsFlutter,
      mapBuilder: mapBuilder,
      settings: settings,
    ),
  );
}

class OperationPostcardPanel extends StatefulWidget {
  final Operation operation;
  final PostcardText text;

  /// What the Map tab showed when the camera button was pressed.
  final MapCameraView view;

  /// Where the tab's markers are — those it showed stay in the picture (see
  /// [postcardCamera]).
  final List<PostcardMarker> markers;

  /// The marker whose popup was open in the tab — drawn over the postcard,
  /// and kept in it, when the tab showed it.
  final MapMarkerData? callout;

  /// Whether the map is drawn as a globe, whose surroundings are space by
  /// design rather than an edge of the world to keep off (see
  /// [postcardCamera]).
  final bool globe;

  /// Whether [mapBuilder]'s map is drawn by Flutter (OSM) rather than in a
  /// browser engine: it is then scaled by Flutter and captured with the
  /// overlay, where a GL map scales itself and snapshots through
  /// [MapZoomController.snapshot].
  final bool mapIsFlutter;
  final PostcardMapBuilder mapBuilder;

  /// Where the last shape and style picked here are kept, and the export
  /// file-name form.
  final SettingsService settings;

  const OperationPostcardPanel({
    super.key,
    required this.operation,
    required this.text,
    required this.view,
    required this.markers,
    this.callout,
    required this.globe,
    required this.mapIsFlutter,
    required this.mapBuilder,
    required this.settings,
  });

  @override
  State<OperationPostcardPanel> createState() => _OperationPostcardPanelState();
}

class _OperationPostcardPanelState extends State<OperationPostcardPanel> {
  final _controller = MapZoomController();
  final _overlayKey = GlobalKey();
  final _flutterPictureKey = GlobalKey();
  final _headerKey = GlobalKey();
  final _calloutKey = GlobalKey();
  Size? _calloutSize;

  double get _tileSize => widget.mapIsFlutter ? 256 : 512;

  /// The tab's popup, where there is one to draw: the tab showed its marker —
  /// a popup follows its marker off the tab — and the map is flat, which is
  /// what places a callout over its marker (see [postcardPoint]).
  late final MapMarkerData? _callout = switch (widget.callout) {
    final marker? when !widget.globe && postcardTabShows(widget.view, (latitude: marker.latitude, longitude: marker.longitude), tileSize: _tileSize) => marker,
    _ => null,
  };

  /// The header band's height in each shape, measured once it is laid out:
  /// a marker must land below it (see [postcardCamera]), so the map waits
  /// for it.
  final _headerHeights = <PostcardShape, double>{};
  late PostcardShape _shape = PostcardShape.values.where((s) => s.name == widget.settings.postcardShape).firstOrNull ?? PostcardShape.portrait;

  /// Liberty until the operator picks another: a postcard's look is its own,
  /// and follows neither the Map tab's style nor the app's dark mode — which
  /// is also why [MapStyle.automatic] is not offered here. Always Liberty's
  /// light tone on the OSM backend, which has no picker to change it back
  /// with.
  late MapStyle _style = switch (widget.settings.postcardMapStyle) {
    _ when widget.mapIsFlutter => MapStyle.liberty,
    null || MapStyle.automatic => MapStyle.liberty,
    final style => style,
  };

  /// The basemap's tone, which the overlay's band follows so that it reads as
  /// part of the map rather than a panel laid on it. Never [MapStyle.automatic]
  /// here, so the app's tone is never consulted.
  bool get _isDark => mapStyleIsDark(_style, appIsDark: false);

  String get _attribution {
    if (widget.mapIsFlutter) return osmAttribution(isDark: _isDark);
    final urls = mapLibreStyleUrls(_style);
    return mapGlAttribution(_isDark ? urls.dark : urls.light);
  }

  /// One render per shape and style, shared by every action taken on it: a
  /// Copy and then a Save are the same image, and the map snapshot is the
  /// slow part. The PNG only — a decoded image each is megabytes of memory
  /// held for nothing, with a phone's two map webviews beside them.
  final _pictures = <(PostcardShape, MapStyle), Future<Uint8List>>{};

  bool _busy = false;

  /// The last action's outcome, under the preview — see
  /// user-interface.md's feedback policy: the result belongs on the surface
  /// that did the work, and a SnackBar would land behind this pane's barrier.
  String? _status;
  bool _statusIsError = false;

  /// The renders in [_pictures] that have finished; the rest are in flight.
  final _finished = <(PostcardShape, MapStyle)>{};

  Future<Uint8List> _picture() {
    final key = (_shape, _style);
    final picture = _pictures[key] ??= _render(_shape, _style);
    // A failure is not kept: the next action tries again, and a map that
    // was still loading tiles may well have them by then.
    picture.then(
      (_) {
        if (identical(_pictures[key], picture)) _finished.add(key);
      },
      onError: (Object _) {
        if (identical(_pictures[key], picture)) _pictures.remove(key);
      },
    );
    return picture;
  }

  /// A render still in flight when the shape or style changes is of a map
  /// that is going or changing: coming back to it must start afresh, not
  /// wait on one that can only fail.
  void _dropUnfinished() => _pictures.removeWhere((key, _) => !_finished.contains(key));

  Future<Uint8List> _render(PostcardShape shape, MapStyle style) async {
    await _mapUp();
    final size = shape.logicalSize * postcardPixelRatio;
    final ui.Image image;
    if (widget.mapIsFlutter) {
      await _controller.onSettled!();
      _stillShowing(shape, style);
      image = await _boundary(_flutterPictureKey).toImage(pixelRatio: postcardPixelRatio);
    } else {
      final map = await decodeImageFromList(await _controller.snapshot(postcardPixelRatio)!);
      _stillShowing(shape, style);
      final overlay = await _boundary(_overlayKey).toImage(pixelRatio: postcardPixelRatio);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Under the map, which is transparent wherever a globe leaves space
      // showing: in the preview the page's own backdrop shows through there.
      paintMapSpaceBackground(canvas, size, pixelRatio: postcardPixelRatio);
      canvas.drawImageRect(
        map,
        Offset.zero & Size(map.width.toDouble(), map.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.drawImage(overlay, Offset.zero, Paint());
      final picture = recorder.endRecording();
      image = await picture.toImage(size.width.round(), size.height.round());
      picture.dispose();
      map.dispose();
      overlay.dispose();
    }
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('the image could not be encoded');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Until the map for the shape on show has come up: it is built only once
  /// the header is measured, and an operator can press Copy the moment the
  /// pane opens.
  Future<void> _mapUp() async {
    const step = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < mapSnapshotTimeout; waited += step) {
      if (!mounted) break;
      if (widget.mapIsFlutter ? _controller.onSettled != null : _controller.onSnapshot != null) return;
      await Future<void>.delayed(step);
    }
    throw const MapSnapshotException('the map never came up');
  }

  /// A render is of whatever map is on show when it reads it; one that
  /// outlasted a change of shape or style — the web's early render, which
  /// runs with the pickers live — would file that picture under the wrong
  /// ones.
  void _stillShowing(PostcardShape shape, MapStyle style) {
    if (shape != _shape || style != _style) throw const MapSnapshotException('the postcard changed while it was drawn');
  }

  RenderRepaintBoundary _boundary(GlobalKey key) {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) throw StateError('the postcard is not on screen');
    return boundary;
  }

  String get _fileName {
    final firstQso = widget.operation.startAtMillisMin;
    final day = (firstQso == null ? nowUtc() : DateTime.fromMillisecondsSinceEpoch(firstQso, isUtc: true)).toIso8601String().substring(0, 10);
    // The first call, as the exports name theirs: a multi-operator
    // operation's station call holds every call, comma-separated.
    final call = (widget.operation.stationCalls.firstOrNull ?? '').replaceAll('/', '-');
    final word = context.t.map.postcard.fileName;
    if (widget.settings.useCompactFileNames) return '${[if (call.isNotEmpty) call, day.replaceAll('-', ''), word].join('-')}.png';
    return '${[day, if (call.isNotEmpty) call, word].join(' ')}.png';
  }

  /// Runs [action], which starts its work before its first await — on the
  /// web the clipboard only takes a write begun inside the tap.
  ///
  /// What goes wrong in the ordinary run of things — a map that never
  /// loaded, a full disk, a clipboard or browser that said no — is told to
  /// the operator in words of its own and not reported: it is an answer, not
  /// a fault, the way `ExportException` is for the exports. Anything else is
  /// a fault, and uploaded.
  Future<void> _run(String action, Future<String?> Function() work) async {
    final t = context.t.map.postcard;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? outcome;
    String? failure;
    try {
      outcome = await work();
    } on MapSnapshotException catch (e) {
      failure = t.mapNotReady;
      debugPrint('[postcard] $action: $e');
    } on ImageClipboardException catch (e) {
      failure = t.copyFailed;
      debugPrint('[postcard] $action: $e');
    } on _Refused catch (e) {
      failure = e.message;
      debugPrint('[postcard] $action: ${e.cause}');
    } catch (e, stack) {
      failure = t.failed(error: '$e');
      debugPrint('[postcard] $action failed: $e\n$stack');
      // Work the operator walked away from — the pane closed under it, its
      // map torn down mid-snapshot — is not a fault.
      if (mounted) ErrorReportingService.report(e, stack, context: 'postcard:$action');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusIsError = failure != null;
      _status = failure ?? outcome;
    });
  }

  void _copy() => _run('copy', () async {
    await copyImageToClipboard(_picture());
    return mounted ? context.t.map.postcard.copied : null;
  });

  void _save() => _run('save', () async {
    final t = context.t.map.postcard;
    final name = _fileName;
    final png = await _picture();
    if (kIsWeb) {
      downloadBytes(filename: name, bytes: png, mimeType: 'image/png');
      return t.downloaded(name: name);
    }
    // No file_selector save on Android — see AndroidFileSave.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final String? saved;
      try {
        saved = await const AndroidFileSave().saveBytes(filename: name, bytes: png);
      } on PlatformException catch (e) {
        // The platform's own answer; the channel's other codes are this side
        // asking wrongly, and faults.
        if (e.code != 'save_failed') rethrow;
        throw _Refused(t.saveFailed(error: e.message ?? e.code), e);
      }
      return saved == null ? null : t.saved(path: saved);
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG', extensions: ['png'], mimeTypes: ['image/png'], uniformTypeIdentifiers: ['public.png']),
      ],
    );
    if (location == null) return null;
    try {
      await File(location.path).writeAsBytes(png);
    } on FileSystemException catch (e) {
      throw _Refused(t.saveFailed(error: e.osError?.message ?? e.message), e);
    }
    return t.saved(path: location.path);
  });

  void _share() {
    // The iPad share sheet is a popover and needs an anchor; captured before
    // the render, which a layout change could make stale.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    _run('share', () async {
      final t = context.t.map.postcard;
      final name = _fileName;
      final png = await _picture();
      final XFile file;
      if (kIsWeb) {
        file = XFile.fromData(png, mimeType: 'image/png', name: name);
      } else {
        // A file of our naming: shared from memory, Android names it after
        // the MIME type instead.
        final path = p.join((await getTemporaryDirectory()).path, name);
        try {
          await File(path).writeAsBytes(png);
        } on FileSystemException catch (e) {
          throw _Refused(t.shareFailed, e);
        }
        file = XFile(path, mimeType: 'image/png');
      }
      try {
        await SharePlus.instance.share(ShareParams(files: [file], sharePositionOrigin: origin, downloadFallbackEnabled: false));
      } on Exception catch (e) {
        // A browser refuses a share it thinks the page asked for on its own
        // — past the tap that asked, when the image was not ready in time —
        // and share_plus hands that on as an Exception; an Error is a fault.
        if (!kIsWeb) rethrow;
        throw _Refused(t.shareFailed, e);
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.map.postcard;
    final theme = Theme.of(context);
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    // iOS saves an image from the share sheet (Save Image), which is where
    // an iOS operator looks for it; a Save button beside it would be a
    // second way to the same place.
    final canSave = !ios;
    final canShare = kIsWeb ? browserCanShareImages() : defaultTargetPlatform != TargetPlatform.linux;

    final copy = OutlinedButton.icon(onPressed: _busy ? null : _copy, icon: Icon(MdiIcons.contentCopy), label: Text(t.copy));
    Widget share({required bool primary}) => primary
        ? FilledButton.icon(onPressed: _busy ? null : _share, icon: Icon(MdiIcons.shareVariant), label: Text(t.share))
        : OutlinedButton.icon(onPressed: _busy ? null : _share, icon: Icon(MdiIcons.shareVariant), label: Text(t.share));
    final save = FilledButton.icon(
      onPressed: _busy ? null : _save,
      icon: Icon(kIsWeb ? MdiIcons.download : MdiIcons.contentSave),
      label: Text(kIsWeb ? t.download : t.save),
    );

    final shapes = SegmentedButton<PostcardShape>(
      // MDI-only UI: skip the framework's Material check on the
      // selected segment (same as settings_view).
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: [
        for (final (shape, icon, label) in [
          (PostcardShape.portrait, MdiIcons.cropPortrait, t.portrait),
          (PostcardShape.landscape, MdiIcons.cropLandscape, t.landscape),
          (PostcardShape.square, MdiIcons.cropSquare, t.square),
        ])
          ButtonSegment(
            value: shape,
            icon: Icon(icon),
            label: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          ),
      ],
      selected: {_shape},
      onSelectionChanged: _busy
          ? null
          : (selection) {
              setState(() {
                _shape = selection.first;
                _status = null;
                _dropUnfinished();
              });
              unawaited(widget.settings.setPostcardShape(selection.first.name));
            },
    );
    // The OSM backend has one tile source per tone and no styles to pick.
    final style = widget.mapIsFlutter
        ? null
        : DropdownButtonFormField<MapStyle>(
            initialValue: _style,
            isExpanded: true,
            icon: dropdownTrailingIcon,
            decoration: poloFieldDecoration(context, context.t.settings.map.style.title),
            menuMaxHeight: dropdownMenuMaxHeight(context),
            items: [
              for (final style in MapStyle.values)
                if (style != MapStyle.automatic) DropdownMenuItem(value: style, child: Text(context.t['settings.map.styleOpts.${style.name}'] as String)),
            ],
            onChanged: _busy
                ? null
                : (style) {
                    if (style == null) return;
                    setState(() {
                      _style = style;
                      _status = null;
                      _dropUnfinished();
                    });
                    unawaited(widget.settings.setPostcardMapStyle(style));
                  },
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.md),
          child: LayoutBuilder(
            // Side by side where both fit — the dialog on a large screen —
            // and stacked on a phone. Capped either way, so that on a wide
            // window the pickers do not stretch across it; filled up to
            // that, so that on a narrow one the shape labels ellipsize rather
            // than overflow.
            builder: (context, constraints) => Center(
              child: style != null && constraints.maxWidth >= _controlsSideBySideWidth
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _controlsRowMaxWidth),
                      child: Row(
                        children: [
                          Expanded(child: shapes),
                          const SizedBox(width: Space.lg),
                          SizedBox(width: _styleWidth, child: style),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _controlsMaxWidth),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          shapes,
                          if (style != null) ...[const SizedBox(height: Space.lg), style],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.md),
            child: Center(
              child: AspectRatio(
                aspectRatio: _shape.logicalSize.aspectRatio,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
                  child: ClipRect(child: _preview()),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
          child: OverflowBar(
            alignment: MainAxisAlignment.center,
            overflowAlignment: OverflowBarAlignment.center,
            spacing: Space.md,
            overflowSpacing: Space.md,
            children: [
              copy,
              if (canShare) share(primary: !canSave),
              if (canSave) save,
            ],
          ),
        ),
        SizedBox(
          height: Space.xxl + Space.md,
          child: Center(
            child: _busy
                ? const SizedBox.square(dimension: Space.xl, child: CircularProgressIndicator(strokeWidth: 2))
                : _status == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                    child: Text(
                      _status!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: _statusIsError ? theme.colorScheme.error : null),
                    ),
                  ),
          ),
        ),
        haloDialogFooterBand(
          context,
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
        ),
      ],
    );
  }

  /// The header's height for [shape], and the callout's size, which the
  /// framing needs before the map can be built.
  void _measure(PostcardShape shape) {
    if (!mounted || shape != _shape) return;
    final header = _headerKey.currentContext?.findRenderObject();
    final callout = _calloutKey.currentContext?.findRenderObject();
    setState(() {
      if (header is RenderBox && header.hasSize) _headerHeights[shape] ??= header.size.height;
      if (callout is RenderBox && callout.hasSize) _calloutSize ??= callout.size;
    });
  }

  Widget _preview() {
    final size = _shape.logicalSize;
    final header = _headerHeights[_shape];
    final callout = _callout;
    final calloutSize = _calloutSize;
    final Widget map;
    Offset? calloutAt;
    if (header == null || (callout != null && calloutSize == null)) {
      final shape = _shape;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(shape));
      map = const SizedBox.expand();
    } else {
      final at = callout == null ? null : (latitude: callout.latitude, longitude: callout.longitude);
      final camera = postcardCamera(
        widget.view,
        size,
        tileSize: _tileSize,
        withinWorld: !widget.globe,
        markers: widget.markers,
        callout: at == null ? null : (at: at, size: calloutSize!),
        header: header,
      );
      if (at != null) calloutAt = postcardPoint(camera, at, size, tileSize: _tileSize);
      // A new map per shape: a frame's size is fixed for the map's life. A
      // new style is not a new map — the backends swap styles in place.
      map = KeyedSubtree(
        key: ValueKey(_shape),
        child: widget.mapBuilder(MapFrame(width: size.width, height: size.height, camera: camera), _controller, _style),
      ); // A browser shares only inside the tap that asked, and rendering takes
      // longer than a tap lasts: on the web the picture is made as soon as
      // it can be, so that Share finds it done.
      if (kIsWeb && !_pictures.containsKey((_shape, _style))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_pictures.containsKey((_shape, _style))) _picture().ignore();
        });
      }
    }
    final overlay = SizedBox.fromSize(
      size: size,
      child: PostcardOverlay(
        shape: _shape,
        text: widget.text,
        attribution: _attribution,
        isDark: _isDark,
        headerKey: _headerKey,
        callout: callout,
        calloutAt: calloutAt,
        calloutKey: _calloutKey,
      ),
    );
    if (widget.mapIsFlutter) {
      return FittedBox(
        child: RepaintBoundary(
          key: _flutterPictureKey,
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              children: [
                Positioned.fill(child: map),
                Positioned.fill(child: overlay),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned.fill(
          child: FittedBox(
            child: RepaintBoundary(key: _overlayKey, child: overlay),
          ),
        ),
      ],
    );
  }
}

/// Everything the postcard draws over the map, at its logical size. Its
/// colours are the picture's own, not the app theme's: the band follows the
/// basemap's tone, and the image looks the same whichever theme made it.
class PostcardOverlay extends StatelessWidget {
  final PostcardShape shape;
  final PostcardText text;
  final String attribution;
  final bool isDark;

  /// On the header band, for the pane to measure it by.
  final Key? headerKey;

  /// The Map tab's open popup, drawn with its tip on [calloutAt] — or laid out
  /// unseen, for [calloutKey] to be measured by, until the pane knows where.
  final MapMarkerData? callout;
  final Offset? calloutAt;
  final Key? calloutKey;

  const PostcardOverlay({
    super.key,
    required this.shape,
    required this.text,
    required this.attribution,
    required this.isDark,
    this.headerKey,
    this.callout,
    this.calloutAt,
    this.calloutKey,
  });

  static const _lightBand = Color(0xB3F2F8FA);
  static const _lightInk = Color(0xFF222222);
  static const _darkBand = Color(0xB3121A20);
  static const _darkInk = Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    final band = isDark ? _darkBand : _lightBand;
    final ink = isDark ? _darkInk : _lightInk;
    final heading = TextStyle(fontFamily: 'RobotoSlab', fontWeight: FontWeight.w900, fontSize: 24, height: 1.2, color: ink);
    final body = TextStyle(fontFamily: 'Roboto', fontSize: 18, height: 1.25, color: ink);

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.title, style: heading, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (text.subtitle.isNotEmpty) Text(text.subtitle, style: body, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text.stats, style: heading, textAlign: TextAlign.right, maxLines: 1),
        if (text.date.isNotEmpty) Text(text.date, style: body, textAlign: TextAlign.right, maxLines: 1),
      ],
    );

    // Pinned to a plain text theme: the overlay is a picture, and the app's
    // text scaling or a platform's default font must not change it.
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: body,
        child: Stack(
          children: [
            if (callout case final marker?)
              switch (calloutAt) {
                null => Positioned(
                  left: 0,
                  top: 0,
                  child: Opacity(
                    opacity: 0,
                    child: _PostcardCallout(key: calloutKey, marker: marker),
                  ),
                ),
                final at => Positioned(
                  left: at.dx,
                  top: at.dy - postcardCalloutGap,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1),
                    child: _PostcardCallout(key: calloutKey, marker: marker),
                  ),
                ),
              },
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ColoredBox(
                key: headerKey,
                color: band,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xxl, vertical: Space.xl),
                  child: shape == PostcardShape.landscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: Space.xxl),
                            right,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            left,
                            const SizedBox(height: Space.md),
                            Align(alignment: Alignment.centerRight, child: right),
                          ],
                        ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: band, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.sm),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          // The brand, which is never translated.
                          TextSpan(text: 'Ham2K ', style: body.copyWith(fontSize: 20)),
                          TextSpan(text: ham2kProductName, style: heading.copyWith(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Text(attribution, style: body.copyWith(fontSize: 9, color: ink.withValues(alpha: 0.8))),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Map tab's popup as the GL map draws it — a light card with a tip
/// pointing down at its marker — whatever the app's theme or the basemap's
/// tone.
class _PostcardCallout extends StatelessWidget {
  final MapMarkerData marker;

  const _PostcardCallout({super.key, required this.marker});

  static const _tip = Size(20, 10);

  @override
  Widget build(BuildContext context) {
    final light = buildHaLoTheme(Brightness.light);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Theme(
          data: light,
          child: MapPopupCard(marker: marker),
        ),
        CustomPaint(size: _tip, painter: _TipPainter(light.colorScheme.surface)),
      ],
    );
  }
}

class _TipPainter extends CustomPainter {
  final Color color;

  _TipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TipPainter oldDelegate) => oldDelegate.color != color;
}

/// An action the platform turned down — a full disk, a browser that would
/// not share — with the words to tell the operator: an answer, not a fault
/// (see [_OperationPostcardPanelState._run]).
class _Refused implements Exception {
  final String message;

  /// What the platform said, for the console.
  final Object cause;

  const _Refused(this.message, this.cause);
}
