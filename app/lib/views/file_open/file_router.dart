// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every file that reaches the app from outside — opened from Files, Finder,
// Explorer, a share sheet or a browser download, or dropped anywhere on the
// window — goes through one router, which works out where it can go and
// sends it there.
//
// The places a file can go are [FileDestination]s. Some are always there
// (install an extension, import a key set, import into Logs); a view
// suggests its own while it is on screen by wrapping its body in
// [FileSuggestions] (an operation's ADIF import, a dock's layout import).
// Where the file lands on the window makes no difference: what the views on
// screen suggest does. A file with one place to go goes there; with several,
// the router asks, the view's suggestion first and already focused.
//
// One `desktop_drop` target, at the root ([FileDropRoot]). The plugin hands a
// drop to every target whose box holds the point, so targets per view would
// each have to guess whether they were the one in front; one target has
// nothing to guess.

import 'dart:async';
import 'dart:collection' show Queue;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/navigation.dart' show navigatorKey;
import '../../services/error_reporting_service.dart';
import 'file_kind.dart';

/// Somewhere a file can go.
class FileDestination {
  const FileDestination({required this.id, required this.label, this.kind, this.accepts, required this.open});

  /// Names the destination across its providers: a view's suggestion takes
  /// the place of an always-there destination with the same id — the Logs
  /// view's own import in place of the one that first has to bring Logs up.
  final String id;

  /// What the chooser lists, read when it is shown.
  final String Function() label;

  /// The kind of file this takes, unless [accepts] says otherwise.
  final HaloFileKind? kind;

  /// Which files this takes, for one that [kind] alone cannot say.
  final bool Function(HaloFileKind? kind, XFile file)? accepts;

  /// Completes when the destination is done with the file — consent given or
  /// refused, import written or cancelled — since the next file in the queue
  /// waits on it.
  final Future<void> Function(BuildContext context, XFile file) open;

  bool takes(HaloFileKind? kind, XFile file) => accepts?.call(kind, file) ?? (this.kind != null && kind == this.kind);
}

/// A destination, and the context it opens a file on.
typedef FileCandidate = ({FileDestination destination, BuildContext context});

/// The one router. Created at startup ([FileRouter.start]) with the
/// destinations that are always there.
class FileRouter {
  FileRouter({required this.globals});

  static FileRouter? _instance;

  /// The running router, if startup has made one.
  static FileRouter? get instance => _instance;

  static FileRouter start({required List<FileDestination> Function() globals}) => _instance = FileRouter(globals: globals);

  /// The destinations that are there whatever is on screen.
  final List<FileDestination> Function() globals;

  final _queue = Queue<XFile>();
  bool _draining = false;

  /// Routes [file], after every file handed over before it is done.
  ///
  /// One at a time: two consent screens, or two import summaries, on top of
  /// each other is the shape people click through, and two ADIF imports
  /// planned against the same snapshot of the log overwrite each other.
  void open(XFile file) {
    _queue.add(file);
    if (!_draining) unawaited(_drain());
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final next = _queue.removeFirst();
        try {
          await _route(next);
        } catch (e, stack) {
          // A file that cannot be read, or a destination that fails on it:
          // the operator is waiting on this file, so they hear why.
          final context = navigatorKey.currentContext;
          ErrorReportingService.report(e, stack, context: 'file-open', told: context != null);
          if (context != null && context.mounted) await _cannotOpen(context, next, ErrorReportingService.messageOf(e));
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _route(XFile file) async {
    final context = await _whenClear();
    final kind = await classifyFile(file);

    // Insertion-ordered, the views' suggestions first: the first of them is
    // the default the chooser offers.
    final candidates = <String, FileCandidate>{};
    for (final scope in FileSuggestions._showing()) {
      for (final destination in scope.widget.suggestions) {
        if (destination.takes(kind, file)) candidates.putIfAbsent(destination.id, () => (destination: destination, context: scope.context));
      }
    }
    final suggested = candidates.isNotEmpty;
    for (final destination in globals()) {
      if (destination.takes(kind, file)) candidates.putIfAbsent(destination.id, () => (destination: destination, context: context));
    }

    if (!context.mounted) return;
    if (candidates.isEmpty) {
      await _cannotOpen(context, file, t.fileOpen.cannotOpenDetail);
      return;
    }
    final chosen = candidates.length == 1
        ? candidates.values.single
        : await showHaloDialog<FileCandidate>(
            context: context,
            builder: (dialogContext) => SimpleDialog(
              title: Text(t.fileOpen.chooseTitle(filename: file.name)),
              children: [
                for (final (index, candidate) in candidates.values.indexed)
                  ListTile(
                    // Enter takes what the view on screen suggested.
                    autofocus: suggested && index == 0,
                    title: Text(candidate.destination.label()),
                    onTap: () => Navigator.of(dialogContext).pop(candidate),
                  ),
              ],
            ),
          );
    if (chosen == null || !chosen.context.mounted) return;
    await chosen.destination.open(chosen.context, file);
  }

  /// A dialog, not a toast: the operator just opened or dropped this file
  /// and is waiting on it, and a refusal they can miss reads as the app
  /// having done nothing.
  static Future<void> _cannotOpen(BuildContext context, XFile file, String detail) => showHaloDialog<void>(
    context: context,
    builder: (dialogContext) => HaloDialog(
      title: Text(t.fileOpen.cannotOpen(filename: file.name)),
      content: Text(detail),
      cancel: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(t.common.done)),
    ),
  );

  /// The navigator, once there is one and nothing modal is on top of it.
  ///
  /// With no deadline: a file that cold-launches the app arrives before
  /// there is a navigator, and a first launch can take its time, but the
  /// operator is still waiting for the file. And a dialog or sheet on top
  /// hides the views that would suggest where the file goes, while a
  /// destination that brings up its view first (Logs) would close it, and
  /// whatever the operator had in it, without asking.
  static Future<BuildContext> _whenClear() async {
    while (true) {
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.mounted) {
        Route<dynamic>? top;
        // Reads the top route without popping anything.
        navigator.popUntil((route) {
          top = route;
          return true;
        });
        if (top is! PopupRoute) return navigator.context;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

/// What a view suggests doing with a file while it is on screen: the
/// [suggestions] become the default the router offers for the files they
/// take.
///
/// Scopes nest, and the innermost one suggests first: a dock's layout import
/// inside an operation, which suggests its ADIF import.
class FileSuggestions extends StatefulWidget {
  const FileSuggestions({super.key, required this.suggestions, this.active, required this.child});

  final List<FileDestination> suggestions;

  /// Whether the view is what the operator is looking at, where nothing
  /// else (a route on top, a stopped ticker, a dock tab behind another) says
  /// so. Asked when a file arrives, so it never goes stale.
  final bool Function()? active;

  final Widget child;

  static final _scopes = <_FileSuggestionsState>[];

  /// The scopes on screen, the innermost and the most recently shown first.
  static Iterable<_FileSuggestionsState> _showing() => _scopes.reversed.where((scope) => scope.showing);

  /// What the views on screen suggest, in the order the router offers it.
  @visibleForTesting
  static List<FileDestination> onScreen() => [for (final scope in _showing()) ...scope.widget.suggestions];

  /// Waits up to [timeout] for a view on screen to suggest destination [id]
  /// — for an always-there destination that first brings up the view that
  /// owns the real one.
  static Future<FileCandidate?> waitFor(String id, {Duration timeout = const Duration(seconds: 3)}) async {
    const step = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited <= timeout; waited += step) {
      for (final scope in _showing()) {
        for (final destination in scope.widget.suggestions) {
          if (destination.id == id) return (destination: destination, context: scope.context);
        }
      }
      await Future<void>.delayed(step);
    }
    return null;
  }

  @override
  State<FileSuggestions> createState() => _FileSuggestionsState();
}

class _FileSuggestionsState extends State<FileSuggestions> {
  /// On screen and in front: nothing modal over its route, not in a dock
  /// tab behind another, and not inside a destination that has been slid
  /// away with its tickers stopped.
  bool get showing =>
      mounted &&
      (widget.active?.call() ?? true) &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      DockPaneVisibility.readOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    FileSuggestions._scopes.add(this);
  }

  @override
  void dispose() {
    FileSuggestions._scopes.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The window's one drop target, feeding [FileRouter].
///
/// The overlay shows for any drag, not only one the app can take: what a
/// drag carries is not known until it lands.
class FileDropRoot extends StatefulWidget {
  const FileDropRoot({super.key, required this.child});

  final Widget child;

  @override
  State<FileDropRoot> createState() => _FileDropRootState();
}

class _FileDropRootState extends State<FileDropRoot> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final router = FileRouter.instance;
        if (router == null) return;
        details.files.forEach(router.open);
      },
      child: Stack(
        // Passthrough: the root must not loosen what the app is given.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_dragging) const Positioned.fill(child: FileDropOverlay()),
        ],
      ),
    );
  }
}

/// What the window shows while a file is dragged over it: a dashed, rounded
/// frame half the window's width and height, in its middle.
@visibleForTesting
class FileDropOverlay extends StatelessWidget {
  const FileDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return IgnorePointer(
      child: ColoredBox(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        // The frame is a sign, not the target: the whole window takes the
        // drop, and the wash behind the frame covers all of it.
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 0.5,
            child: CustomPaint(
              painter: _DashedFrame(color: color),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Text(
                    t.fileOpen.dropHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(color: color),
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

class _DashedFrame extends CustomPainter {
  const _DashedFrame({required this.color});

  final Color color;

  static const _stroke = 6.0;
  static const _radius = 16.0;
  static const _dash = 20.0;
  static const _gap = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    // Inset by half the stroke, so the whole line stays inside the frame.
    final frame = RRect.fromRectAndRadius((Offset.zero & size).deflate(_stroke / 2), const Radius.circular(_radius));
    for (final metric in (Path()..addRRect(frame)).computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame oldDelegate) => oldDelegate.color != color;
}
