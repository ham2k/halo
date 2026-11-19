// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A map pane's own settings — its basemap, callsign pills, grayline, how it
// moves to the current QSO and how it frames itself without one — kept in
// the placement's config, so
// two map panes are two sets of choices and none of them is an app
// preference. The pane reads them through [MapPaneConfig]; its tab's
// settings button and the pane layout options show [MapPaneSettings].

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/map_preferences.dart';
import '../../services/panel_service.dart';
import '../../services/settings_service.dart';

const mapPaneStyleKey = 'style';
const mapPaneCallsignsKey = 'callsigns';
const mapPaneGraylineKey = 'grayline';
const mapPaneMovementKey = 'movement';
const mapPaneFramingKey = 'framing';

/// Declared so the dock offers the pane's settings, and so a placement's
/// config accepts these keys: no form renders them, [MapPaneSettings] does.
const List<Map<String, dynamic>> mapPaneFields = [
  {'type': 'field', 'key': mapPaneStyleKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': mapPaneCallsignsKey, 'fieldType': 'checkbox', 'label': ''},
  {'type': 'field', 'key': mapPaneGraylineKey, 'fieldType': 'checkbox', 'label': ''},
  {'type': 'field', 'key': mapPaneMovementKey, 'fieldType': 'text', 'label': ''},
  {'type': 'field', 'key': mapPaneFramingKey, 'fieldType': 'text', 'label': ''},
];

/// What a map pane with none of its own settings stored starts from, copied
/// into it on its first read (PanelService.configFor): the app-wide
/// basemap, callsigns and grayline. Without them, an operator whose panes
/// read those app-wide values would find each pane back on the defaults.
/// Movements and framing have no app-wide value to start from.
Map<String, dynamic> mapPaneInitialConfig(SettingsService settings) => {
  mapPaneStyleKey: settings.mapStyle.name,
  mapPaneCallsignsKey: settings.mapShowCallsigns,
  mapPaneGraylineKey: settings.mapShowGrayline,
};

/// How a map pane moves when there is a current QSO — the one in the logging
/// panel, or the Logs view's selection (map_highlight_camera.dart). A zoom
/// frames the QSO's line home, or the region around its location
/// (regionAround); a center keeps the zoom the map is at.
enum MapMovement { zoomLine, zoomLocation, centerLine, centerLocation, none }

/// What a map pane shows with no current QSO: every contact (and the
/// operation's own places), the box of the operator's DXCC entity or of its
/// continent (entity_bounds.dart), or the world. [none] frames the log once,
/// at its first contact, and never moves by itself after that.
enum MapFraming { allQsos, country, continent, world, none }

/// One map pane's settings, as its config holds them.
class MapPaneOptions {
  final MapStyle style;

  /// Each contact drawn as a pill holding its callsign rather than a plain
  /// circle.
  final bool callsigns;

  /// The night side of the Earth shaded (map_grayline.dart).
  final bool grayline;

  final MapMovement movement;
  final MapFraming framing;

  const MapPaneOptions({
    this.style = MapStyle.automatic,
    this.callsigns = false,
    this.grayline = false,
    this.movement = MapMovement.zoomLine,
    this.framing = MapFraming.allQsos,
  });

  /// A stored value this build does not know reads as the default.
  factory MapPaneOptions.fromConfig(Map<String, dynamic> config) => MapPaneOptions(
    style: MapStyle.values.firstWhere((style) => style.name == config[mapPaneStyleKey], orElse: () => MapStyle.automatic),
    callsigns: config[mapPaneCallsignsKey] == true,
    grayline: config[mapPaneGraylineKey] == true,
    movement: MapMovement.values.firstWhere((movement) => movement.name == config[mapPaneMovementKey], orElse: () => MapMovement.zoomLine),
    framing: MapFraming.values.firstWhere((framing) => framing.name == config[mapPaneFramingKey], orElse: () => MapFraming.allQsos),
  );
}

/// Builds [builder] with the map pane [panelId]'s settings, again whenever
/// they change. Nothing until they have loaded: a map drawn from the
/// defaults first would load one basemap and then throw it away.
class MapPaneConfig extends StatefulWidget {
  final PanelService panels;
  final String panelId;
  final Widget Function(BuildContext context, MapPaneOptions options) builder;

  const MapPaneConfig({super.key, required this.panels, required this.panelId, required this.builder});

  @override
  State<MapPaneConfig> createState() => _MapPaneConfigState();
}

class _MapPaneConfigState extends State<MapPaneConfig> {
  MapPaneOptions? _options;
  int _revision = 0;

  /// The latest load: two settings changed in quick succession start two,
  /// and the first can finish last with what it read before the second
  /// change landed.
  int _loading = 0;

  @override
  void initState() {
    super.initState();
    widget.panels.addListener(_onPanelsChanged);
    _revision = widget.panels.configRevision(widget.panelId);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(MapPaneConfig old) {
    super.didUpdateWidget(old);
    if (old.panels != widget.panels) {
      old.panels.removeListener(_onPanelsChanged);
      widget.panels.addListener(_onPanelsChanged);
    }
    if (old.panels != widget.panels || old.panelId != widget.panelId) {
      _revision = widget.panels.configRevision(widget.panelId);
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    widget.panels.removeListener(_onPanelsChanged);
    super.dispose();
  }

  /// The settings bump the revision once they have written; nothing else
  /// tells the pane its settings moved.
  void _onPanelsChanged() {
    final revision = widget.panels.configRevision(widget.panelId);
    if (revision == _revision) return;
    _revision = revision;
    unawaited(_load());
  }

  Future<void> _load() async {
    final load = ++_loading;
    final panel = widget.panels[widget.panelId];
    try {
      final options = panel == null ? const MapPaneOptions() : MapPaneOptions.fromConfig(await widget.panels.configFor(panel));
      // Also a load for the placement this pane showed before.
      if (mounted && load == _loading) setState(() => _options = options);
    } catch (_) {
      // Settings that cannot be read leave the map on what it last read, or
      // on the defaults — never no map at all. The failure goes on to
      // ErrorPolicy.
      if (mounted && load == _loading && _options == null) setState(() => _options = const MapPaneOptions());
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => switch (_options) {
    final options? => widget.builder(context, options),
    null => const SizedBox.shrink(),
  };
}

/// The map pane [panelId]'s settings, saved as each one changes. The one
/// widget behind both routes in, the tab's settings button and the pane
/// layout options' embed.
class MapPaneSettings extends StatefulWidget {
  final String panelId;
  final PanelService panels;

  const MapPaneSettings({super.key, required this.panelId, required this.panels});

  @override
  State<MapPaneSettings> createState() => _MapPaneSettingsState();
}

class _MapPaneSettingsState extends State<MapPaneSettings> {
  MapPaneOptions? _options;

  /// Counts the loads, for the form's key: it reads its initial state only
  /// once, so a load draws a new one — and an edit, which the form already
  /// shows, keeps the one it has, with its focus and scroll.
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final panel = widget.panels[widget.panelId];
    MapPaneOptions? options;
    try {
      options = panel == null ? const MapPaneOptions() : MapPaneOptions.fromConfig(await widget.panels.configFor(panel));
    } catch (_) {
      // Settings that cannot be read are offered from the defaults rather
      // than as an empty sheet. The failure goes on to ErrorPolicy.
      if (_options == null) options = const MapPaneOptions();
      rethrow;
    } finally {
      if (mounted && options != null) {
        setState(() {
          _options = options;
          _loads++;
        });
      }
    }
  }

  Future<void> _write(String key, Object value) async {
    final panel = widget.panels[widget.panelId];
    if (panel == null) return;
    // Bumps the pane's revision even after a failed write, so the pane
    // re-reads whatever did land; these settings re-read it too.
    try {
      await widget.panels.writeConfig(panel, {key: value}, notify: false);
    } catch (_) {
      if (mounted) unawaited(_load());
      rethrow;
    } finally {
      widget.panels.markConfigChanged(widget.panelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final s = context.t.settings.map;
    return CustomScrollView(
      shrinkWrap: true,
      slivers: [
        if (options != null)
          FormRenderer(
            key: ValueKey(_loads),
            formDefinition: {
              'elements': [
                {
                  'type': 'field',
                  'fieldType': 'select',
                  'key': mapPaneStyleKey,
                  'label': s.style.title,
                  'icon': 'map-outline',
                  'options': [
                    for (final style in MapStyle.values) {'value': style.name, 'label': context.t['settings.map.styleOpts.${style.name}'] as String},
                  ],
                },
                {
                  'type': 'field',
                  'fieldType': 'checkbox',
                  'key': mapPaneCallsignsKey,
                  'label': s.showCallsigns.title,
                  'description': s.showCallsigns.description,
                  'icon': 'label-outline',
                },
                {
                  'type': 'field',
                  'fieldType': 'checkbox',
                  'key': mapPaneGraylineKey,
                  'label': s.showGrayline.title,
                  'description': s.showGrayline.description,
                  'icon': 'weather-night',
                },
                {
                  'type': 'field',
                  'fieldType': 'select',
                  'key': mapPaneMovementKey,
                  'label': s.movement.title,
                  'icon': 'crosshairs',
                  'options': [
                    for (final movement in MapMovement.values) {'value': movement.name, 'label': context.t['settings.map.movement.${movement.name}'] as String},
                  ],
                },
                {
                  'type': 'field',
                  'fieldType': 'select',
                  'key': mapPaneFramingKey,
                  'label': s.framing.title,
                  'icon': 'fit-to-screen',
                  'options': [
                    for (final framing in MapFraming.values) {'value': framing.name, 'label': context.t['settings.map.framing.${framing.name}'] as String},
                  ],
                },
              ],
            },
            initialState: {
              mapPaneStyleKey: options.style.name,
              mapPaneCallsignsKey: options.callsigns,
              mapPaneGraylineKey: options.grayline,
              mapPaneMovementKey: options.movement.name,
              mapPaneFramingKey: options.framing.name,
            },
            showActions: false,
            showTitle: false,
            sliver: true,
            settingsList: true,
            onChange: (key, value, state) async {
              if (value is! String && value is! bool) return null;
              final stored = value as Object;
              setState(() => _options = MapPaneOptions.fromConfig({...state, key: stored}));
              // Not awaited: the form renderer would swallow a failed write
              // whole, where unawaited it reaches ErrorPolicy.
              unawaited(_write(key, stored));
              return null;
            },
            onSubmit: (_) {},
            onCancel: () {},
          ),
      ],
    );
  }
}
