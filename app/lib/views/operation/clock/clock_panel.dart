// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One clock pane, in one time zone, wearing one of two faces.
//
// Both faces change once a second and ride the app's shared WallClock
// heartbeat — nothing here owns a timer or a repeating animation of its own.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
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

class ClockPanel extends StatefulWidget {
  /// The PLACEMENT's id (`clock#1`), never the descriptor's — it is the key
  /// this pane's config is stored under, so two panes handed the same one
  /// would share a zone.
  final String panelId;

  final PanelService panels;

  /// Names the tab after the zone, so two clocks are told apart.
  final ValueChanged<String?>? onTitle;

  const ClockPanel({
    super.key,
    required this.panelId,
    required this.panels,
    this.onTitle,
  });

  @override
  State<ClockPanel> createState() => _ClockPanelState();
}

class _ClockPanelState extends State<ClockPanel> {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.panels.addListener(_onCatalogChanged);
    _configRevision = widget.panels.configRevision(widget.panelId);
    unawaited(_loadConfig());
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
    // After the setState, never from build: this reaches the VIEW's state,
    // which setStates in turn.
    final onTitle = widget.onTitle;
    if (onTitle != null) {
      onTitle(zoneShortName(_zoneId, deviceLabel: context.t.operation.layout.panels.clockZoneDevice));
    }
  }

  String get _zoneId => _config[clockZoneKey] as String? ?? utcZoneId;

  /// The stored face, nothing-stored default LCD, or an unrecognized STORED
  /// value's fallback to analog. Those are different cases: nothing stored is
  /// an untouched new pane, while an explicit value this build does not know
  /// is a saved layout that outlived the release that named its face — a
  /// stored `swiss` from before the SBB face's removal is the case that
  /// exists for, and the round analog face is the closer substitute for it
  /// than the LCD.
  String get _face {
    final stored = _config[clockFaceKey];
    if (stored == null) return clockFaceLcd;
    return const {clockFaceLcd, clockFaceAnalog}.contains(stored) ? stored as String : clockFaceAnalog;
  }

  bool get _showSeconds => _config[clockShowSecondsKey] as bool? ?? true;

  @override
  void dispose() {
    widget.panels.removeListener(_onCatalogChanged);
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
          return OncePerSecond(builder: (context, nowUtc) => _readout(box, palette, nowUtc));
        },
      ),
    );
    // Only the LCD's glass fills the whole panel — it IS the panel's
    // background. The round face paints its disc in this same colour
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
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: AnalogFacePainter(
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
/// The LCD owns its palette, because it is a replica of a physical object and
/// a themed one stops being the thing it copies. The analog face has no such
/// identity to protect, so it adopts the scheme and sits in the dock like
/// every other pane.
ClockPalette clockPaletteFor(BuildContext context, String face) {
  final theme = Theme.of(context);
  switch (face) {
    case clockFaceLcd:
      return lcdPalette(theme.brightness);
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
