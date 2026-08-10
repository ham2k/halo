// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One clock pane, in one time zone, wearing one of three faces.
//
// The LCD and analog faces change once a second and ride the app's shared
// WallClock heartbeat. The Swiss face SWEEPS, and is the only thing in this
// app that owns a repeating animation controller — which is why most of the
// state below is about when it is allowed to run.

import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../i18n/strings.g.dart';
import '../../../services/panel_service.dart';
import 'clock_faces.dart';
import 'clock_math.dart';
import 'clock_zones.dart';

/// The panel id the view registers this pane under, and the descriptor half
/// of every placement id (`clock#1`). Shared rather than spelled twice: the
/// dock matches placements against it, and a rename that reached only the
/// registration would route every clock pane to the missing-panel fallback.
const String clockPanelId = 'clock';

/// Config keys, shared with the descriptor that declares the form.
const String clockFaceKey = 'face';
const String clockZoneKey = 'zone';
const String clockShowSecondsKey = 'showSeconds';

const String clockFaceLcd = 'lcd';
const String clockFaceAnalog = 'analog';
const String clockFaceSwiss = 'swiss';

class ClockPanel extends StatefulWidget {
  /// The PLACEMENT's id (`clock#1`), never the descriptor's — it is the key
  /// this pane's config is stored under, so two panes handed the same one
  /// would share a zone.
  final String panelId;

  final PanelService panels;

  /// Names the tab after the zone, so two clocks are told apart.
  final ValueChanged<String?>? onTitle;

  /// Whether the sweeping face may run at all. Defaults off under
  /// `flutter test`: a repeating controller never lets `pumpAndSettle`
  /// finish, and the timeout surfaces against whatever unrelated test called
  /// it. A parameter rather than an env check buried in the State, so the
  /// lifecycle tests can turn it ON — a face nothing ever animates is a face
  /// no test can hold to its contract.
  final bool? animate;

  const ClockPanel({
    super.key,
    required this.panelId,
    required this.panels,
    this.onTitle,
    this.animate,
  });

  static bool get _animatesByDefault => kIsWeb || !io.Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends State<ClockPanel> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// A frame pump, not a value. Everything drawn is derived from the app clock
  /// read inside the builder, so a dropped frame, a stop, or a restart
  /// mid-cycle shows the true time instead of resuming a stale phase. Nothing
  /// may read `_sweep.value`.
  late final AnimationController _sweep =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  late final bool _mayAnimate = widget.animate ?? ClockPanel._animatesByDefault;

  /// True outside a dock, where a built pane is a visible one. A dock group
  /// is an IndexedStack — a pane behind another tab stays MOUNTED, and there
  /// is no TickerMode over it, so without this a four-pane layout sweeps at
  /// the display's refresh rate in three panes nobody is looking at.
  bool _dockVisible = true;

  /// False only while every view is hidden — minimized, a background browser
  /// tab, a paused mobile app. Deliberately not `inactive`: on desktop that
  /// means the window merely lost focus while still on screen, and a clock
  /// frozen there reads as a hang.
  bool _appVisible = true;

  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  @override
  void initState() {
    super.initState();
    // Null before the first platform message, which is not evidence of being
    // hidden.
    final state = WidgetsBinding.instance.lifecycleState;
    _appVisible = state == null || _visibleIn(state);
    // A plain observer, not an AppLifecycleListener: that class validates
    // transitions against its own state machine and drops the ones it judges
    // illegal, so a platform reporting `hidden` straight back to `resumed`
    // never reaches the callback — and the sweep stays stopped for the rest
    // of the session. This is also what main.dart and home_view.dart use.
    WidgetsBinding.instance.addObserver(this);
    widget.panels.addListener(_onCatalogChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    unawaited(_loadConfig());
    // No _syncSweep here: DockPaneVisibility is only readable from
    // didChangeDependencies, and it defaults optimistically to true — a pane
    // mounting behind a tab would run until the first correction.
  }

  static bool _visibleIn(AppLifecycleState state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = _visibleIn(state);
    if (visible == _appVisible) return;
    _appVisible = visible;
    _syncSweep();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dockVisible = DockPaneVisibility.of(context);
    _syncSweep();
  }

  @override
  void didUpdateWidget(ClockPanel old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onCatalogChanged);
      widget.panels.addListener(_onCatalogChanged);
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.panels.configRevision(widget.panelId);
      unawaited(_loadConfig());
    }
  }

  /// This pane's own config was edited. Nothing else would tell it — the form
  /// is host-persisted and the catalog is the only thing that notices.
  void _onCatalogChanged() {
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _configRevision) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    final config = await widget.panels.configFor(panel);
    if (!mounted) return;
    setState(() => _config = config);
    _syncSweep();
    // After the setState, never from build: this reaches the VIEW's state,
    // which setStates in turn.
    final onTitle = widget.onTitle;
    if (onTitle != null) {
      onTitle(zoneShortName(_zoneId, deviceLabel: context.t.operation.layout.panels.clockZoneDevice));
    }
  }

  String get _zoneId => _config[clockZoneKey] as String? ?? utcZoneId;

  /// The stored face, or the default. A value this build does not know falls
  /// back to the default rather than to whichever branch happens to be last:
  /// a saved layout outlives the release that named its face, and "not LCD"
  /// is not the same question as "which of the round ones".
  String get _face {
    final stored = _config[clockFaceKey];
    return const {clockFaceLcd, clockFaceAnalog, clockFaceSwiss}.contains(stored)
        ? stored! as String
        : clockFaceLcd;
  }
  bool get _showSeconds => _config[clockShowSecondsKey] as bool? ?? true;

  /// Whether this pane is drawn from the sweep rather than from the shared
  /// per-second heartbeat. Independent of whether the controller is running
  /// right now — the gates below stop it while nobody is looking, and the
  /// pane must still know which builder owns it.
  bool get _sweeps => _face == clockFaceSwiss && _showSeconds && _mayAnimate;

  void _syncSweep() {
    final shouldRun = _sweeps && _dockVisible && _appVisible;
    if (shouldRun == _sweep.isAnimating) return;
    if (shouldRun) {
      _sweep.repeat();
    } else {
      // Not reset: the value is a frame pump nothing paints from, so where it
      // stopped is not visible anywhere.
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
    WidgetsBinding.instance.removeObserver(this);
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = clockPaletteFor(context, _face);
    final content = Padding(
      padding: EdgeInsets.all(Space.md).add(PaneSafeArea.paddingOf(context)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final box = constraints.biggest;
          // Driven by whether the sweep is actually the clock here, NOT by
          // which face is showing: a Swiss face with its second hand off
          // has no controller running (see [_syncSweep]) and nothing else
          // would ever rebuild it, so it would paint the mount-time minute
          // and hold it for the session.
          //
          // Either way the per-frame or per-second rebuild stops here, at
          // the painted leaf, rather than running the pane's whole subtree.
          return _sweeps
              ? AnimatedBuilder(
                  animation: _sweep,
                  // The app clock, like the OncePerSecond branch below: a
                  // clock FACE showing something other than what the Time
                  // chip beside it reads is the exact contradiction
                  // docs/design/time.md exists to prevent.
                  builder: (context, _) => _readout(box, palette, nowUtc()),
                )
              : OncePerSecond(builder: (context, nowUtc) => _readout(box, palette, nowUtc));
        },
      ),
    );
    // Only the LCD's glass fills the whole panel — it IS the panel's
    // background. The round faces paint their disc in this same colour
    // (clockPaletteFor), so a shared ColoredBox here would erase their rim
    // and leave the hands floating with no dial underneath them.
    return _face == clockFaceLcd ? ColoredBox(color: palette.face, child: content) : content;
  }

  Widget _readout(Size box, ClockPalette palette, DateTime nowUtc) {
    final reading = readZone(_zoneId, nowUtc);
    final wall = reading.wall;
    final round = _face != clockFaceLcd;
    final zoneText = reading.abbreviation ?? offsetLabel(reading.offset);
    final label = '${_two(wall.hour)}:${_two(wall.minute)}'
        '${_showSeconds ? ':${_two(wall.second)}' : ''} $zoneText';

    final form = clockFormFor(box, round: round, showSeconds: _showSeconds);

    return Semantics(
      label: label,
      // Not a liveRegion: a clock that announced itself every second would
      // make a screen reader unusable for everything else in the view.
      excludeSemantics: true,
      child: Center(child: _drawing(box, palette, wall, form, round)),
    );
  }

  Widget _drawing(Size box, ClockPalette palette, DateTime wall, ClockForm form, bool round) {
    if (form == ClockForm.compact) {
      // A hard cut to plain text, never a crossfade — an AnimatedSwitcher
      // here steals the semantics node on web
      // (docs/design/user-interface.md).
      return Text(
        '${_two(wall.hour)}:${_two(wall.minute)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      );
    }

    if (!round) {
      final withSeconds = form == ClockForm.full && _showSeconds;
      final digits = <int?>[
        // A leading zero is suppressed rather than drawn: a 24-hour readout
        // showing `09` reads as a date field, and the blank cell keeps the
        // row from shifting on the hour.
        wall.hour < 10 ? null : wall.hour ~/ 10,
        wall.hour % 10,
        wall.minute ~/ 10,
        wall.minute % 10,
        if (withSeconds) ...[wall.second ~/ 10, wall.second % 10],
      ];
      return CustomPaint(
        size: box,
        painter: LcdFacePainter(
          digits: digits,
          colonsAfter: withSeconds ? const {1, 3} : const {1},
          palette: palette,
        ),
      );
    }

    final diameter = clockDiameterFor(box) ?? minClockDiameter;
    final msIntoMinute = wall.second * 1000 + wall.millisecond;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _face == clockFaceSwiss
            ? SwissFacePainter(
                hourAngle: analogHandAngles(wall).hour,
                minuteAngle: swissMinuteAngle(wall.minute, msIntoMinute),
                secondAngle: swissSecondAngle(msIntoMinute),
                showSeconds: _showSeconds,
                palette: palette,
              )
            : AnalogFacePainter(
                hourAngle: analogHandAngles(wall).hour,
                minuteAngle: analogHandAngles(wall).minute,
                secondAngle: analogHandAngles(wall).second,
                showSeconds: _showSeconds,
                palette: palette,
              ),
      ),
    );
  }

  static String _two(int n) => n < 10 ? '0$n' : '$n';
}

/// The colours a face wears.
///
/// The LCD and the Swiss dial own their palettes, because both are replicas
/// of physical objects and a themed one stops being the thing it copies — an
/// SBB dial in the app's surface colour is just a circle. The analog face has
/// no such identity to protect, so it adopts the scheme and sits in the dock
/// like every other pane.
ClockPalette clockPaletteFor(BuildContext context, String face) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  switch (face) {
    case clockFaceLcd:
      return dark
          ? ClockPalette(
              face: const Color(0xFF0D1418),
              ink: fabAccentColor,
              ghost: fabAccentColor.withValues(alpha: 0.13),
              accent: fabAccentColor,
            )
          : ClockPalette(
              face: const Color(0xFFA9B79F),
              ink: const Color(0xFF161A12),
              ghost: const Color(0xFF161A12).withValues(alpha: 0.09),
              accent: const Color(0xFF161A12),
            );
    case clockFaceSwiss:
      return ClockPalette(
        face: dark ? const Color(0xFF151515) : const Color(0xFFFFFFFF),
        ink: dark ? const Color(0xFFFFFFFF) : const Color(0xFF151515),
        ghost: dark ? const Color(0xFFFFFFFF) : const Color(0xFF151515),
        accent: SwissFacePainter.sbbRed,
      );
    default:
      final scheme = theme.colorScheme;
      return ClockPalette(
        face: scheme.surface,
        ink: scheme.onSurface,
        ghost: scheme.outlineVariant,
        accent: HaLoColors.of(context).onSurfaceAccent,
      );
  }
}
