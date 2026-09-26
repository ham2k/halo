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
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/android_file_save.dart';
import '../../services/error_reporting_service.dart';
import '../../services/image_clipboard.dart';
import '../../services/settings_service.dart';
import '../../services/web_download.dart';
import '../../tools/operation_title.dart';
import '../map/map_gl_script.dart' show mapGlAttribution, mapLibreStyleUrls, mapStyleIsDark, paintMapSpaceBackground;
import '../map/map_marker_data.dart' show MapMarkerData;
import '../map/map_zoom_controller.dart';
import '../map/osm_map_view.dart' show osmAttribution;
import 'postcard_framing.dart';
import 'postcard_overlay.dart';
import 'postcard_sections_dialog.dart';
import 'postcard_summary.dart';

export 'postcard_framing.dart';
export 'postcard_overlay.dart';

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

/// The widest the shape and style pickers grow, stacked.
const _controlsMaxWidth = 480.0;

/// The width at and above which the style picker sits beside the shapes
/// rather than under them: the shapes' three labels about whole beside a
/// [_styleWidth] picker. Under the modal pane's dialog width (650, 602 inside
/// its padding), so a large screen gets the row.
const _controlsSideBySideWidth = 560.0;

/// The widest the shapes and the style picker grow side by side.
const _controlsRowMaxWidth = 640.0;

/// The style picker's width beside the shapes: enough for most of its names
/// whole, the longest ellipsized.
const _styleWidth = 152.0;

/// How much of its row the style picker takes under the shapes, its button
/// kept at the row's end.
const _styleShare = 0.8;

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
  List<Map<String, dynamic>> activityControls = const [],
}) {
  final text = PostcardText.of(context, operation, qsos);
  final sections = postcardSummarySections(context, operation: operation, qsos: qsos, activityControls: activityControls);
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
      sections: sections,
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

  /// What the summary pages say, after the map's.
  final List<PostcardSummarySection> sections;

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
    this.sections = const [],
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
  final _mapKey = GlobalKey();
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
  /// a marker must land below it (see [postcardCamera]), and the summary
  /// starts below it, so the map and the summary's pages wait for it.
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

  final _layouts = <PostcardShape, PostcardSummaryLayout>{};

  /// The sections the operator picked, and their order — kept across
  /// operations, so it names sections this one may not have.
  late var _picks = widget.settings.postcardSections;

  /// The summary's pages in [shape], once its header has been measured.
  PostcardSummaryLayout? _layout(PostcardShape shape) {
    final header = _headerHeights[shape];
    if (header == null) return null;
    return _layouts[shape] ??= postcardSummaryLayout(
      postcardSectionsPicked(widget.sections, order: _picks.order, hidden: _picks.hidden),
      page: shape.logicalSize,
      header: header,
      continued: (title) => context.t.map.postcard.continued(title: title),
    );
  }

  /// The map postcard, then the summary's pages — the map's alone until they
  /// are laid out.
  int get _pageCount => 1 + (_layout(_shape)?.pages.length ?? 0);

  /// The page on show, which Copy takes.
  int _page = 0;
  PageController? _pages;

  /// The map alone, for the shape and style on show: under the map
  /// postcard's overlay, and veiled under every summary page.
  final _maps = _Renders<(PostcardShape, MapStyle), Uint8List>();

  /// Every page's image, for the shape and style on show only. The PNG only —
  /// a decoded image each is megabytes of memory held for nothing, with a
  /// phone's two map webviews beside them.
  final _pictures = _Renders<(PostcardShape, MapStyle, int), Uint8List>();

  /// Moved on whenever what the pages hold changes — a shape, a style, the
  /// sections — so that a run of renders begun before stops rather than
  /// draws pages that are no longer there.
  int _generation = 0;

  bool _busy = false;

  /// The last action's outcome, under the preview — see
  /// user-interface.md's feedback policy: the result belongs on the surface
  /// that did the work, and a SnackBar would land behind this pane's barrier.
  String? _status;
  bool _statusIsError = false;

  /// The polls of [_mapUp] under way, ended with the pane rather than left
  /// to find it gone.
  final _waits = <Completer<void>, Timer>{};

  @override
  void dispose() {
    for (final MapEntry(key: wait, value: timer) in _waits.entries) {
      timer.cancel();
      wait.complete();
    }
    _waits.clear();
    _pages?.dispose();
    super.dispose();
  }

  Future<Uint8List> _mapPicture(PostcardShape shape, MapStyle style) => _maps.get(
    (shape, style),
    () => _renderMap(shape, style),
    // The summary pages' previews lay it under their veil once there is one,
    // and the pages made over the veil alone meanwhile are made again.
    onDone: () {
      _mapFailed = false;
      if (_bareRenders) {
        _bareRenders = false;
        _pictures.clear();
      }
      if (mounted) setState(() {});
    },
    onFailed: (error) {
      if (error is MapSnapshotException) _mapFailed = true;
    },
  );

  /// Whether the map's last try would not load — offline in the field — so
  /// that an export goes on over the veil without waiting it out again: the
  /// map page's builds keep trying it meanwhile.
  bool _mapFailed = false;

  /// Whether pages made over the veil alone are among [_pictures], to be
  /// made again once the map comes.
  bool _bareRenders = false;

  /// The map's picture for an export: the one there is, or none — without
  /// trying again — where the last try failed and another page can go on
  /// without it; otherwise one try, waited for.
  Future<ui.Image?> _mapFor(PostcardShape shape, MapStyle style, {required bool orNone}) async {
    if (_maps.done((shape, style)) == null && _mapFailed && orNone) return null;
    try {
      return await decodeImageFromList(await _mapPicture(shape, style));
    } on MapSnapshotException {
      if (!orNone) rethrow;
      return null;
    }
  }

  Future<Uint8List> _picture(PostcardShape shape, MapStyle style, int page, {ui.Image? map, bool withoutMap = false}) =>
      _pictures.get((shape, style, page), () => _render(shape, style, page, generation: _generation, map: map, withoutMap: withoutMap));

  /// Every page's image, one after another, the map's picture decoded once
  /// for all of them.
  ///
  /// A map that would not load is left out, with [mapLeftOut] saying so,
  /// where there are summary pages to go on with: they are the map's words
  /// over a veil, and offline in the field they are still to be had.
  Future<({List<Uint8List> pngs, bool mapLeftOut})> _allPictures(PostcardShape shape, MapStyle style, int count) async {
    final generation = _generation;
    // Decided once for the whole run: every page with the map, or the map's
    // page left out and every other over the veil alone.
    final map = await _mapFor(shape, style, orNone: count > 1);
    if (generation != _generation) {
      map?.dispose();
      throw const MapSnapshotException(_changed);
    }
    final mapLeftOut = map == null;
    try {
      return (
        pngs: [
          for (var page = mapLeftOut ? 1 : 0; page < count; page++)
            if (generation != _generation) throw const MapSnapshotException(_changed) else await _picture(shape, style, page, map: map, withoutMap: mapLeftOut),
        ],
        mapLeftOut: mapLeftOut,
      );
    } finally {
      map?.dispose();
    }
  }

  void _dropAll() {
    _generation++;
    _mapFailed = false;
    _bareRenders = false;
    _maps.clear();
    _pictures.clear();
  }

  /// A shape or style picked starts over at the map: it is the page that
  /// changed most, and a map comes up — or restyles — only while on show.
  void _repicked(void Function() change) {
    setState(() {
      change();
      _status = null;
      _page = 0;
      _dropAll();
    });
    if (_pages?.hasClients ?? false) _pages!.jumpToPage(0);
  }

  Future<Uint8List> _renderMap(PostcardShape shape, MapStyle style) async {
    await _mapUp();
    if (!widget.mapIsFlutter) {
      await _showMap();
      final png = await _controller.snapshot(postcardPixelRatio)!;
      _stillShowing(shape, style);
      return png;
    }
    await _controller.onSettled!();
    await _showMap();
    _stillShowing(shape, style);
    return _png(await _boundary(_mapKey).toImage(pixelRatio: postcardPixelRatio));
  }

  /// Whether the map's page is drawn: on show, or beside the page that is.
  /// Kept while scrolled further off, it is not — a picture taken of it then
  /// is of whatever it drew last, tiles missing and all.
  bool get _mapOnShow => _page <= 1;

  /// Brings the map's page back on show for a picture of it, and waits for it
  /// to be drawn there.
  Future<void> _showMap() async {
    if (_mapOnShow || !mounted || !(_pages?.hasClients ?? false)) return;
    _pages!.jumpToPage(0);
    await WidgetsBinding.instance.endOfFrame;
  }

  /// [page]'s image, over [map] where the caller has decoded it already —
  /// and otherwise over a map decoded here, or on a summary page, over the
  /// veil alone where the map would not load.
  Future<Uint8List> _render(PostcardShape shape, MapStyle style, int page, {required int generation, ui.Image? map, bool withoutMap = false}) async {
    final own = map == null && !withoutMap;
    if (own) map = await _mapFor(shape, style, orNone: page > 0);
    if (map == null) _bareRenders = true;
    try {
      _stillShowing(shape, style);
      if (page > 0) {
        if (!mounted) throw StateError('the postcard was closed');
        final layout = _layout(shape);
        if (generation != _generation || layout == null || page > layout.pages.length) throw const MapSnapshotException(_changed);
        return _png(
          await paintOffscreen(
            PostcardSummaryPage(
              shape: shape,
              text: widget.text,
              attribution: _attribution,
              isDark: _isDark,
              // Laid out before any of its pages can be asked for: the
              // carousel offers none until then.
              layout: layout,
              page: page - 1,
              map: map == null ? null : _mapLayer(RawImage(image: map, fit: BoxFit.cover, filterQuality: FilterQuality.medium)),
            ),
            size: shape.logicalSize,
            pixelRatio: postcardPixelRatio,
            view: View.of(context),
          ),
        );
      }
      final size = shape.logicalSize * postcardPixelRatio;
      map!;
      final overlay = await _boundary(_overlayKey).toImage(pixelRatio: postcardPixelRatio);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Under the map, which is transparent wherever a globe leaves space
      // showing: in the preview the page's own backdrop shows through there.
      if (!widget.mapIsFlutter) paintMapSpaceBackground(canvas, size, pixelRatio: postcardPixelRatio);
      canvas.drawImageRect(
        map,
        Offset.zero & Size(map.width.toDouble(), map.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.drawImage(overlay, Offset.zero, Paint());
      overlay.dispose();
      final picture = recorder.endRecording();
      try {
        return _png(await picture.toImage(size.width.round(), size.height.round()));
      } finally {
        picture.dispose();
      }
    } finally {
      if (own) map?.dispose();
    }
  }

  static Future<Uint8List> _png(ui.Image image) async {
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('the image could not be encoded');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// The map's picture laid as the map postcard lays it: over the backdrop a
  /// globe leaves showing.
  Widget _mapLayer(Widget picture) => widget.mapIsFlutter
      ? picture
      : Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _SpacePainter()),
            picture,
          ],
        );

  /// Until the map for the shape on show has come up: it is built only once
  /// the header is measured, and an operator can press Copy the moment the
  /// pane opens.
  Future<void> _mapUp() async {
    const step = Duration(milliseconds: 50);
    for (var waited = Duration.zero; waited < mapSnapshotTimeout; waited += step) {
      if (!mounted) break;
      if (_mapIsUp) return;
      final wait = Completer<void>();
      _waits[wait] = Timer(step, wait.complete);
      await wait.future;
      _waits.remove(wait);
    }
    throw const MapSnapshotException('the map never came up');
  }

  /// Whether the map on show has hooked itself up, which a backend does as
  /// it is built.
  bool get _mapIsUp => widget.mapIsFlutter ? _controller.onSettled != null : _controller.onSnapshot != null;

  /// A render is of whatever map is on show when it reads it; one that
  /// outlasted a change of shape or style — an early render, which runs with
  /// the pickers live — would file that picture under the wrong ones.
  void _stillShowing(PostcardShape shape, MapStyle style) {
    if (shape != _shape || style != _style) throw const MapSnapshotException(_changed);
  }

  static const _changed = 'the postcard changed while it was drawn';

  RenderRepaintBoundary _boundary(GlobalKey key) {
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) throw StateError('the postcard is not on screen');
    return boundary;
  }

  /// A file name for each of [count] pages, numbered when there are several.
  List<String> _fileNames(int count) {
    final firstQso = widget.operation.startAtMillisMin;
    final day = (firstQso == null ? nowUtc() : DateTime.fromMillisecondsSinceEpoch(firstQso, isUtc: true)).toIso8601String().substring(0, 10);
    // The first call, as the exports name theirs: a multi-operator
    // operation's station call holds every call, comma-separated.
    final call = (widget.operation.stationCalls.firstOrNull ?? '').replaceAll('/', '-');
    final word = context.t.map.postcard.fileName;
    String name(int? page) => widget.settings.useCompactFileNames
        ? '${[if (call.isNotEmpty) call, day.replaceAll('-', ''), word, if (page != null) '$page'].join('-')}.png'
        : '${[day, if (call.isNotEmpty) call, word, if (page != null) '$page'].join(' ')}.png';
    return count == 1 ? [name(null)] : [for (var page = 1; page <= count; page++) name(page)];
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

  void _copy() {
    final (shape, style, page) = (_shape, _style, _page);
    _run('copy', () async {
      await copyImageToClipboard(_picture(shape, style, page));
      return mounted ? context.t.map.postcard.copied : null;
    });
  }

  /// Every page: on a desktop, into a folder picked for them when there are
  /// several; on Android, a dialog each, as the exports save several files.
  void _save() {
    final (shape, style, count) = (_shape, _style, _pageCount);
    _run('save', () async {
      final t = context.t.map.postcard;
      final all = await _allPictures(shape, style, count);
      final pngs = all.pngs;
      final names = _fileNames(count).sublist(count - pngs.length);
      String left(String? outcome) => !all.mapLeftOut
          ? outcome ?? ''
          : outcome == null
          ? t.mapLeftOut
          : t.withMapLeftOut(outcome: outcome);
      // What already landed goes into a failure's words: an error naming only
      // the image that failed sends the operator looking for the others.
      final saved = <String>[];
      String failed(String error) => saved.isEmpty
          ? t.saveFailed(error: error)
          : t.savePartial(
              error: t.saveFailed(error: error),
              names: saved.join(', '),
            );
      if (kIsWeb) {
        for (var page = 0; page < pngs.length; page++) {
          downloadBytes(filename: names[page], bytes: pngs[page], mimeType: 'image/png');
        }
        // Handed over, not landed: a browser asks before letting a page
        // download more than one file, and the answer never comes back here.
        return left(pngs.length == 1 ? t.downloaded(name: names.single) : t.downloadedMany(count: pngs.length));
      }
      // No file_selector save on Android — see AndroidFileSave.
      if (defaultTargetPlatform == TargetPlatform.android) {
        for (var page = 0; page < pngs.length; page++) {
          final String? name;
          try {
            name = await const AndroidFileSave().saveBytes(filename: names[page], bytes: pngs[page]);
          } on PlatformException catch (e) {
            // The platform's own answer; the channel's other codes are this
            // side asking wrongly, and faults.
            if (e.code != 'save_failed') rethrow;
            throw _Refused(failed(e.message ?? e.code), e);
          }
          // Cancelling one dialog abandons the images still to come, rather
          // than asking again for every one of them.
          if (name == null) break;
          saved.add(name);
        }
        if (saved.isEmpty) return null;
        return left(saved.length == 1 ? t.saved(path: saved.single) : t.savedFiles(names: saved.join(', ')));
      }
      if (pngs.length == 1) {
        final location = await getSaveLocation(
          suggestedName: names.single,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'PNG', extensions: ['png'], mimeTypes: ['image/png'], uniformTypeIdentifiers: ['public.png']),
          ],
        );
        if (location == null) return null;
        try {
          await File(location.path).writeAsBytes(pngs.single);
        } on FileSystemException catch (e) {
          throw _Refused(failed(e.osError?.message ?? e.message), e);
        }
        return left(t.saved(path: location.path));
      }
      // A folder rather than a save dialog each: a sandboxed app may write
      // only the file a save dialog names, and none beside it. A postcard
      // saved there before under the same names is replaced, as a save
      // dialog's own would be.
      final directory = await getDirectoryPath();
      if (directory == null) return null;
      for (var page = 0; page < pngs.length; page++) {
        try {
          await File(p.join(directory, names[page])).writeAsBytes(pngs[page]);
        } on FileSystemException catch (e) {
          throw _Refused(failed(e.osError?.message ?? e.message), e);
        }
        saved.add(names[page]);
      }
      return left(t.savedMany(count: pngs.length, path: directory));
    });
  }

  /// Every page, in one share.
  void _share() {
    // The iPad share sheet is a popover and needs an anchor; captured before
    // the render, which a layout change could make stale.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    final (shape, style, count) = (_shape, _style, _pageCount);
    _run('share', () async {
      final t = context.t.map.postcard;
      final all = await _allPictures(shape, style, count);
      final pngs = all.pngs;
      final names = _fileNames(count).sublist(count - pngs.length);
      final files = <XFile>[];
      if (kIsWeb) {
        for (var page = 0; page < pngs.length; page++) {
          files.add(XFile.fromData(pngs[page], mimeType: 'image/png', name: names[page]));
        }
      } else {
        // Files of our naming: shared from memory, Android names them after
        // the MIME type instead.
        final directory = (await getTemporaryDirectory()).path;
        for (var page = 0; page < pngs.length; page++) {
          final path = p.join(directory, names[page]);
          try {
            await File(path).writeAsBytes(pngs[page]);
          } on FileSystemException catch (e) {
            throw _Refused(t.shareFailed, e);
          }
          files.add(XFile(path, mimeType: 'image/png'));
        }
      }
      try {
        await SharePlus.instance.share(ShareParams(files: files, sharePositionOrigin: origin, downloadFallbackEnabled: false));
      } on Exception catch (e) {
        // A browser refuses a share it thinks the page asked for on its own
        // — past the tap that asked, when the images were not ready in time
        // — and share_plus hands that on as an Exception; an Error is a fault.
        if (!kIsWeb) rethrow;
        throw _Refused(t.shareFailed, e);
      }
      return all.mapLeftOut ? t.mapLeftOut : null;
    });
  }

  /// Starts the map's picture as soon as the map is built, for the summary
  /// pages' previews to lie over — and on the web every page's image besides:
  /// a browser shares only inside the tap that asked, and rendering takes
  /// longer than a tap lasts, so Share must find them done.
  void _prerender() {
    // Not waited for: it is started again with every build of the map's page.
    if (!mounted || !_mapIsUp || !_mapOnShow) return;
    final (shape, style) = (_shape, _style);
    _mapPicture(shape, style).ignore();
    final count = _pageCount;
    if (kIsWeb && !List.generate(count, (page) => _pictures.done((shape, style, page)) != null).every((done) => done)) {
      _allPictures(shape, style, count).ignore();
    }
  }

  Future<void> _pickSections() async {
    final here = {for (final section in widget.sections) section.key};
    final picked = await showPostcardSectionsDialog(
      context,
      choices: postcardSectionChoices(postcardSectionsPicked(widget.sections, order: _picks.order), daysLabel: context.t.map.postcard.sectionDays),
      hidden: _picks.hidden,
      custom: _custom,
    );
    if (picked == null || !mounted) return;
    // What another operation's sections were given stays as it was.
    final elsewhere = [..._picks.order.where((key) => !here.contains(key)), ..._picks.hidden.where((key) => !here.contains(key))];
    final order = picked.reset ? const <String>[] : postcardSectionsOrder(_picks.order, picked.order, here: here);
    final hidden = picked.reset ? const <String>{} : {...picked.hidden, ..._picks.hidden.where((key) => !here.contains(key))};
    // Saved as they came, and nothing picked elsewhere: nothing to remember.
    final plain =
        picked.reset ||
        (elsewhere.isEmpty &&
            hidden.isEmpty &&
            listEquals(order, [
              ...{for (final section in widget.sections) section.key},
            ]));
    setState(() {
      _picks = plain ? (order: const [], hidden: const {}) : (order: order, hidden: hidden);
      _layouts.clear();
      _generation++;
      _pictures.clear();
      _status = null;
      _page = math.min(_page, _pageCount - 1);
    });
    if (_pages?.hasClients ?? false) _pages!.jumpToPage(_page);
    unawaited(plain ? widget.settings.clearPostcardSections() : widget.settings.setPostcardSections(order, hidden));
  }

  /// Whether picks are remembered, which the sections button says in teal.
  bool get _custom => _picks.order.isNotEmpty || _picks.hidden.isNotEmpty;

  /// Bright enough to be seen as a mark, on a light pane and a dark one.
  static const _customColor = Color(0xFF00BFA5);

  void _goTo(int page) => _pages?.animateToPage(page, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

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

    final actions = <_Action>[
      if (canShare) (icon: MdiIcons.shareVariant, label: t.share, onPressed: _share),
      (icon: MdiIcons.contentCopy, label: t.copy, onPressed: _copy),
      if (canSave) (icon: kIsWeb ? MdiIcons.download : MdiIcons.contentSave, label: kIsWeb ? t.download : t.save, onPressed: _save),
    ];

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
              _repicked(() => _shape = selection.first);
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
                    _repicked(() => _style = style);
                    unawaited(widget.settings.setPostcardMapStyle(style));
                  },
          );

    final sections = MergeSemantics(
      child: Semantics(
        label: t.sections,
        child: IconButton(
          onPressed: _busy || widget.sections.isEmpty ? null : _pickSections,
          icon: Icon(MdiIcons.formatListBulleted, color: _custom ? _customColor : null),
        ),
      ),
    );

    // Under the whole pane: on the web a map beneath it — the Map tab's own,
    // which the pane opens over — would otherwise take every click and drag
    // over it that lands on anything short of a button.
    return PointerInterceptor(
      intercepting: kIsWeb,
      child: Column(
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
                            const SizedBox(width: Space.md),
                            sections,
                          ],
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _controlsMaxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Beside the style, or where there is none to pick,
                            // beside the shapes.
                            if (style == null)
                              Row(
                                children: [
                                  Expanded(child: shapes),
                                  const SizedBox(width: Space.md),
                                  sections,
                                ],
                              )
                            else ...[
                              shapes,
                              const SizedBox(height: Space.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _styleShare, child: style),
                                  ),
                                  const SizedBox(width: Space.md),
                                  sections,
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Expanded(child: LayoutBuilder(builder: (context, constraints) => _carousel(constraints.biggest))),
          _pager(),
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
          _footer(actions),
        ],
      ),
    );
  }

  /// Each form of the footer's action row at its natural width — none, then
  /// one, two… of them from the trailing edge showing their icon alone — as
  /// measured for [_formsOf]; null until measured.
  List<double>? _formWidths;
  String? _formsOf;
  final _forms = <GlobalKey>[];

  /// The actions at the footer's leading edge and Done at its trailing one,
  /// the actions' labels given up from the trailing edge in until they fit
  /// the room Done leaves them.
  ///
  /// Which of them fits is read off the buttons themselves: every form of the
  /// row laid out unseen at its natural width once, and then, whatever the
  /// room, the first no wider than it taken — no arithmetic about buttons'
  /// padding to go stale. Measured again only when the labels or the text
  /// size change.
  Widget _footer(List<_Action> actions) {
    Widget row(int bare) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.md,
      children: [
        for (final (i, action) in actions.indexed)
          if (i >= actions.length - bare)
            MergeSemantics(
              child: Semantics(
                label: action.label,
                child: FilledButton(onPressed: _busy ? null : action.onPressed, child: Icon(action.icon)),
              ),
            )
          else
            FilledButton.icon(onPressed: _busy ? null : action.onPressed, icon: Icon(action.icon), label: Text(action.label)),
      ],
    );

    final forms = '${[for (final action in actions) action.label].join('|')}@${MediaQuery.textScalerOf(context).scale(100)}';
    final widths = forms == _formsOf ? _formWidths : null;
    while (_forms.length < actions.length + 1) {
      _forms.add(GlobalKey());
    }
    if (widths == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final measured = [
          for (var bare = 0; bare <= actions.length; bare++)
            switch (_forms[bare].currentContext?.findRenderObject()) {
              final RenderBox box when box.hasSize => box.size.width,
              _ => null,
            },
        ];
        if (measured.contains(null)) return;
        setState(() {
          _formWidths = measured.cast<double>();
          _formsOf = forms;
        });
      });
    }
    return haloDialogFooterBand(
      context,
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      tools: widths == null
          // Icons alone until measured: the narrowest form, so nothing jumps.
          ? Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(fit: BoxFit.scaleDown, child: row(actions.length)),
                ),
                for (var bare = 0; bare <= actions.length; bare++)
                  Offstage(
                    child: ExcludeFocus(
                      child: UnconstrainedBox(
                        child: KeyedSubtree(key: _forms[bare], child: row(bare)),
                      ),
                    ),
                  ),
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // The fewest bare that fits; where none does, all of them, so
                // that narrowing the pane never brings a label back.
                final fits = widths.indexWhere((width) => width <= constraints.maxWidth + 0.5);
                return Align(
                  alignment: Alignment.centerLeft,
                  // Scaled down only where even the icons alone do not fit.
                  child: FittedBox(fit: BoxFit.scaleDown, child: row(fits < 0 ? actions.length : fits)),
                );
              },
            ),
    );
  }

  /// The least of a page beside the one on show that shows, once set back.
  static const _peek = Space.xxl;

  /// How much smaller a page beside the one on show is drawn.
  static const _behindScale = 0.08;

  /// The pages side by side in [area], the one on show as large as it fits
  /// with at least [_peek] of each neighbour showing beside it.
  Widget _carousel(Size area) {
    const top = Space.lg, bottom = Space.md, gap = Space.lg;
    final aspect = _shape.logicalSize.aspectRatio;
    // A neighbour's near edge sits a gap past the page's, drawn in by its
    // setting back: what shows of it is half of what the page leaves of the
    // area, less the gap, less its own shrinking on that side.
    final fits = (area.width - 2 * (gap + _peek)) / (1 + _behindScale);
    final width = math.max(0.0, math.min(fits, (area.height - top - bottom) * aspect));
    final pages = _controllerFor((width + gap) / area.width);
    final theme = Theme.of(context);
    final border = Border.all(color: theme.colorScheme.outlineVariant);
    // A dark postcard on a dark pane, or a light one on a light pane, would
    // melt into it: a glow of the other tone sets it off.
    final glow = _isDark != (theme.brightness == Brightness.dark)
        ? null
        : [BoxShadow(color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.35), blurRadius: Space.lg)];
    Widget framed(int index) => Padding(
      padding: const EdgeInsets.only(top: top, bottom: bottom),
      child: Center(
        child: SizedBox(
          width: width,
          height: width / aspect,
          // Every page drags the carousel along.
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: DecoratedBox(
              decoration: BoxDecoration(border: border, boxShadow: glow),
              child: ClipRect(child: index == 0 ? _preview() : _summaryPreview(index - 1)),
            ),
          ),
        ),
      ),
    );
    return ScrollConfiguration(
      // A mouse drags the pages along as a finger does.
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: ui.PointerDeviceKind.values.toSet(), scrollbars: false),
      child: PageView.builder(
        controller: pages,
        itemCount: _pageCount,
        onPageChanged: (page) => setState(() {
          _page = page;
          _status = null;
        }),
        // The map's page is kept when it scrolls out of sight: a map taken
        // down is a map to load again, and its picture is taken from it.
        itemBuilder: (context, index) => index == 0 ? _KeepAlive(child: _behind(0, framed(0))) : _behind(index, framed(index)),
      ),
    );
  }

  /// A page's controller at [fraction] of the width a page: a new one when it
  /// changes, which is only when the shape or the pane's size does.
  PageController _controllerFor(double fraction) {
    final current = _pages;
    fraction = fraction.clamp(0.05, 1.0);
    if (current != null && (current.viewportFraction - fraction).abs() < 0.01) return current;
    // Disposed after the frame, once the page view has let go of it.
    if (current != null) WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    return _pages = PageController(viewportFraction: fraction, initialPage: _page);
  }

  /// A page beside the one on show — the map's among them — sits back a
  /// little, and a tap brings it forward.
  Widget _behind(int index, Widget page) {
    final pages = _pages!;
    return AnimatedBuilder(
      animation: pages,
      builder: (context, child) {
        final at = pages.hasClients && pages.position.hasContentDimensions ? pages.page ?? _page.toDouble() : _page.toDouble();
        return Transform.scale(scale: 1 - _behindScale * (index - at).abs().clamp(0.0, 1.0), child: child);
      },
      child: GestureDetector(onTap: () => _goTo(index), child: page),
    );
  }

  static const _maxDots = 9;

  /// Arrows and a dot per page, under the pages — for a mouse, which has no
  /// swipe, and to say how many there are.
  Widget _pager() {
    final count = _pageCount;
    if (count < 2) return const SizedBox.shrink();
    final t = context.t.map.postcard;
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MergeSemantics(
          child: Semantics(
            label: t.previousPage,
            child: IconButton(onPressed: _page > 0 ? () => _goTo(_page - 1) : null, icon: Icon(MdiIcons.chevronLeft)),
          ),
        ),
        Semantics(
          label: t.pageOf(page: _page + 1, count: count),
          excludeSemantics: true,
          // A dot a page while they fit a phone's width; the numbers past that.
          child: count > _maxDots
              ? Text('${_page + 1} / $count', style: Theme.of(context).textTheme.labelLarge)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var page = 0; page < count; page++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                        child: DecoratedBox(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: page == _page ? colors.primary : colors.outlineVariant),
                          child: const SizedBox.square(dimension: Space.md),
                        ),
                      ),
                  ],
                ),
        ),
        MergeSemantics(
          child: Semantics(
            label: t.nextPage,
            child: IconButton(onPressed: _page < count - 1 ? () => _goTo(_page + 1) : null, icon: Icon(MdiIcons.chevronRight)),
          ),
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

  Widget _summaryPreview(int index) {
    final map = _maps.done((_shape, _style));
    return FittedBox(
      child: PostcardSummaryPage(
        shape: _shape,
        text: widget.text,
        attribution: _attribution,
        isDark: _isDark,
        layout: _layout(_shape)!,
        page: index,
        map: map == null ? null : _mapLayer(Image.memory(map, fit: BoxFit.cover, gaplessPlayback: true)),
      ),
    );
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
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _prerender());
    }
    final overlay = RepaintBoundary(
      key: _overlayKey,
      child: SizedBox.fromSize(
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
      ),
    );
    if (widget.mapIsFlutter) {
      return FittedBox(
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(key: _mapKey, child: map),
              ),
              Positioned.fill(child: overlay),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned.fill(child: FittedBox(child: overlay)),
        // A picture's map takes no input, and on the web its element would
        // otherwise keep every click and drag over it from the carousel: a
        // tap that brings this page forward, a swipe to the next.
        Positioned.fill(
          child: PointerInterceptor(intercepting: kIsWeb, child: const SizedBox.expand()),
        ),
      ],
    );
  }
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

/// A footer action: its icon, and the label it shows where there is room.
typedef _Action = ({IconData icon, String label, VoidCallback onPressed});

/// Renders shared by every action taken on them: a Copy and then a Save are
/// the same image, and the map's picture under it is the slow part. A failure
/// is not kept — the next action tries again, and a map that was still loading
/// tiles may well have them by then.
class _Renders<K, V extends Object> {
  final _futures = <K, Future<V>>{};
  final _values = <K, V>{};

  /// The render for [key] when it has finished.
  V? done(K key) => _values[key];

  Future<V> get(K key, Future<V> Function() render, {void Function()? onDone, void Function(Object error)? onFailed}) {
    if (_futures[key] case final future?) return future;
    final future = _futures[key] = render();
    future.then(
      (value) {
        if (!identical(_futures[key], future)) return;
        _values[key] = value;
        onDone?.call();
      },
      onError: (Object error) {
        if (!identical(_futures[key], future)) return;
        _futures.remove(key);
        onFailed?.call(error);
      },
    );
    return future;
  }

  /// Every render forgotten, finished or not: what they drew has changed.
  void clear() {
    _futures.clear();
    _values.clear();
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The backdrop a globe leaves showing, under a summary page's map as the map
/// postcard's image lays it.
class _SpacePainter extends CustomPainter {
  const _SpacePainter();

  @override
  void paint(Canvas canvas, Size size) => paintMapSpaceBackground(canvas, size, pixelRatio: 1);

  @override
  bool shouldRepaint(_SpacePainter oldDelegate) => false;
}
