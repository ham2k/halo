// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One rotator, on a map of the world centred on the station: where the
// antenna points, where it was told to go, and a tap to turn it. The heading
// and the target come from CatService (docs/design/cat.md § Rotators), which
// this pane reads and turns through and never writes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart' show GridLocation;
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../../services/cat/cat_service.dart';
import '../../../services/cat/equipment.dart';
import '../../../services/halo_services.dart';
import '../../station_rows.dart' show StationConnectionToggle;
import '../weather/weather_reading.dart' show parseWeatherPlace;
import 'rotator_map.dart';

/// The panel id the views register this pane under, and the descriptor half
/// of every placement id (`rotator#1`) — see [radioPanelId].
const String rotatorPanelId = 'rotator';

/// Config keys, shared with the descriptor that declares the form.
const String rotatorNodeKey = 'rotator';
const String rotatorBeamWidthKey = 'beamWidth';
const String rotatorLocationKey = 'location';
const String rotatorGraylineKey = 'grayline';
const String rotatorThemeKey = 'theme';

/// [rotatorThemeKey]'s values — see [RotatorMapPalette].
const String rotatorThemeColor = 'color';
const String rotatorThemeGray = 'gray';
const String rotatorThemeMuted = 'muted';

/// [rotatorNodeKey]'s value for "the station's first rotator" — a pointer
/// rather than a uuid, for [radioNodeAuto]'s reason: adding the rotator
/// after placing the pane must not leave the pane pointing at nothing.
const String rotatorNodeAuto = 'auto';

/// The red-ham-toolkit widget's default: a typical HF Yagi's half-power
/// width, near enough.
const int rotatorBeamWidthDefault = 30;

/// The map's centre: the pane's own [stored] location when it names one —
/// a grid square or a `lat, lon` pair, as the Weather pane reads them — else
/// [operation]'s. One it names and cannot read is `unreadable`, never the
/// operation's: a map centred somewhere the operator did not ask for turns
/// the antenna by headings from the wrong place, and nothing on it says so.
({GridLocation? home, bool unreadable}) rotatorPanelHome(Object? stored, GridLocation? operation) {
  final text = stored is String ? stored.trim() : '';
  if (text.isEmpty) return (home: operation, unreadable: false);
  return switch (parseWeatherPlace(text)) {
    final place? => (home: GridLocation(place.latitude, place.longitude), unreadable: false),
    null => (home: null, unreadable: true),
  };
}

class RotatorPanel extends StatefulWidget {
  /// The PLACEMENT's id (`rotator#1`) — the key this pane's config is
  /// stored under.
  final String panelId;

  final HaLoServices services;

  /// Where the operation is, the map's centre when the pane's settings name
  /// none. Null outside an operation.
  final GridLocation? operationLocation;

  /// The station in the call field, marked on the map.
  final GridLocation? dx;

  /// Names the tab after the rotator, so two of these are told apart.
  final ValueChanged<String?>? onTitle;

  const RotatorPanel({super.key, required this.panelId, required this.services, this.operationLocation, this.dx, this.onTitle});

  @override
  State<RotatorPanel> createState() => _RotatorPanelState();
}

class _RotatorPanelState extends State<RotatorPanel> {
  Map<String, dynamic> _config = const {};
  int _configRevision = 0;

  /// See [_RadioPanelState._configLoaded]: a pane that mounts before its
  /// descriptor is registered has to keep listening for it.
  bool _configLoaded = false;
  int _loadSeq = 0;
  String? _announcedTitle;

  /// What the pane last drew, so a CatService change to any OTHER node —
  /// every reading from a live radio — is not a rebuild here.
  EquipmentNode? _node;
  EquipmentState? _state;

  CatService get _cat => widget.services.cat;

  @override
  void initState() {
    super.initState();
    widget.services.panels.addListener(_onCatalogChanged);
    _cat.addListener(_onEquipmentChanged);
    _configRevision = widget.services.panels.configRevision(widget.panelId);
    _node = _selectedNode();
    _state = _node == null ? null : _cat.stateFor(_node!.uuid);
    unawaited(_loadConfig());
  }

  @override
  void didUpdateWidget(RotatorPanel old) {
    super.didUpdateWidget(old);
    if (old.services != widget.services) {
      old.services.panels.removeListener(_onCatalogChanged);
      old.services.cat.removeListener(_onEquipmentChanged);
      widget.services.panels.addListener(_onCatalogChanged);
      widget.services.cat.addListener(_onEquipmentChanged);
      _onEquipmentChanged();
    }
    if (old.panelId != widget.panelId) {
      _configRevision = widget.services.panels.configRevision(widget.panelId);
      _configLoaded = false;
      unawaited(_loadConfig());
    }
  }

  @override
  void dispose() {
    widget.services.panels.removeListener(_onCatalogChanged);
    _cat.removeListener(_onEquipmentChanged);
    super.dispose();
  }

  void _onCatalogChanged() {
    final revision = widget.services.panels.configRevision(widget.panelId);
    if (revision == _configRevision && _configLoaded) return;
    _configRevision = revision;
    unawaited(_loadConfig());
  }

  void _onEquipmentChanged() {
    if (!mounted) return;
    final node = _selectedNode();
    final state = node == null ? null : _cat.stateFor(node.uuid);
    if (!identical(node, _node) || !identical(state, _state)) {
      setState(() {
        _node = node;
        _state = state;
      });
    }
    _announceTitle();
  }

  Future<void> _loadConfig() async {
    final panel = widget.services.panels[widget.panelId];
    if (panel == null) return;
    final seq = ++_loadSeq;
    final config = await widget.services.panels.configFor(panel);
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _config = config;
      _configLoaded = true;
    });
    _onEquipmentChanged();
  }

  /// After a setState or from a listener, never from build: this reaches the
  /// VIEW's state, which setStates in turn.
  void _announceTitle() {
    final onTitle = widget.onTitle;
    if (onTitle == null) return;
    final node = _node;
    final title = node == null ? null : _cat.displayNameFor(node);
    if (title == _announcedTitle) return;
    _announcedTitle = title;
    onTitle(title);
  }

  /// Read defensively: this runs from build, and a stored value of the wrong
  /// type must not throw out of a frame.
  EquipmentNode? _selectedNode() {
    final stored = _config[rotatorNodeKey];
    if (stored is String && stored != rotatorNodeAuto) return _cat.nodeFor(stored);
    for (final node in _cat.nodes) {
      if (_cat.typeFor(node)?.category == kCategoryRotator) return node;
    }
    return null;
  }

  int get _beamWidth {
    final stored = _config[rotatorBeamWidthKey];
    return stored is num ? stored.round().clamp(0, 360) : rotatorBeamWidthDefault;
  }

  bool get _grayline => switch (_config[rotatorGraylineKey]) {
    final bool stored => stored,
    _ => true,
  };

  RotatorMapPalette get _palette => switch (_config[rotatorThemeKey]) {
    rotatorThemeGray => RotatorMapPalette.gray,
    rotatorThemeMuted => RotatorMapPalette.muted,
    _ => RotatorMapPalette.color,
  };

  ({GridLocation? home, bool unreadable}) get _home => rotatorPanelHome(_config[rotatorLocationKey], widget.operationLocation);

  @override
  Widget build(BuildContext context) {
    final p = context.t.operation.layout.panels;
    // The whole pane wears the map's theme, as the Radio pane's LCD glass
    // does, so the disc does not sit on a surface of another colour.
    Widget pane(Widget child) => ColoredBox(
      color: _palette.backgroundFor(dark: Theme.of(context).brightness == Brightness.dark),
      child: Padding(padding: EdgeInsets.all(Space.md).add(PaneSafeArea.paddingOf(context)), child: child),
    );
    Widget message(String text) => pane(Center(child: Text(text, textAlign: TextAlign.center)));

    final node = _node;
    if (node == null) return message(p.rotatorNoRotator);
    final (:home, :unreadable) = _home;
    if (unreadable) return message(p.rotatorLocationInvalid);
    final state = _state ?? const EquipmentState();
    final connected = state.status == EquipmentStatus.connected;
    // A stale heading is where the antenna WAS, and a turn sent now goes to
    // a controller that is not answering.
    final live = connected && !state.stale;
    final notes = [
      if (home == null) p.rotatorNoLocation,
      if (!connected && state.error != null) state.error!,
      // Why no heading comes, when the controller answers but refuses.
      if (connected && state.problem != null) state.problem!,
    ];
    return pane(
      Column(
        children: [
          Expanded(
            child: RotatorMap(
              home: home,
              dx: widget.dx,
              azimuth: state.rotator == null ? null : state.rotator!.azimuth % 360,
              target: state.rotatorTarget?.azimuth,
              elevation: state.rotator?.elevation,
              beamWidth: _beamWidth,
              palette: _palette,
              grayline: _grayline,
              live: live,
              stale: connected && state.stale,
              onTurn: (azimuth) => _cat.rotateTo(node.uuid, azimuth: azimuth),
              actions: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (live && state.rotatorTarget != null)
                    IconButton(
                      icon: Icon(MdiIcons.stopCircleOutline, semanticLabel: context.t.settings.station.rotatorStop),
                      onPressed: () => _cat.stopRotator(node.uuid),
                    ),
                  StationConnectionToggle(
                    busy: state.status == EquipmentStatus.connecting || state.status == EquipmentStatus.disconnecting,
                    connected: connected,
                    onConnect: () => unawaited(_cat.connect(node.uuid)),
                    onDisconnect: () => unawaited(_cat.disconnect(node.uuid)),
                  ),
                ],
              ),
            ),
          ),
          for (final note in notes) Text(note, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
