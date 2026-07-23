// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Activities pane, shown via showModalPane (docs/design/layouts.md —
// full screen on phones, a dialog on wide layouts) with `scrollable: false`
// since its sections divide the pane's height themselves: three accordion
// sections — "Current Activities" (title shows the count; one row per ref,
// tap to edit, delete button to remove; open by default), "Suggestions &
// Search" (the search field itself is the header; open by default and
// expands to fill the remaining space) and "All Options" (every active
// activity type, for adding one manually; closed by default).
// Start/break/end events are deferred — this pane is activities-only for
// now.
//
// A plain ExpansionTile can't "fill the remaining space" (it always sizes
// to its content inside a scrollable list), so the accordion here is a
// small custom widget instead: each section is either content-sized or,
// when marked `fill`, wrapped in Expanded with its own internally
// scrollable body.

import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../main.dart';
import '../../services/location_service.dart';
import '../../services/extension_service.dart';
import 'operation_location_screen.dart';
import '../operation_dialogs.dart';
import '../extensions_panel.dart';
import '../../i18n/strings.g.dart';


/// An icon, circled in [color] at 60% opacity when the control declares an
/// accent (issue #187) — sparingly used, so a control with no color just
/// renders the bare icon as before.
Widget _accentIcon(String? iconName, Color? color) {
  final icon = Icon(resolveIconName(iconName));
  if (color == null) return icon;
  return CircleAvatar(backgroundColor: color.withValues(alpha: 0.6), child: icon);
}

// Close enough that the operation's grid and the caller's live GPS grid
// would round to the same (or an adjacent) square anyway, so adopting it
// isn't a meaningful accuracy loss.
const _nearbyGridAdoptionKm = 15;

/// Decides which grid (if any) an operation should adopt right after a new
/// activity ref is added, given it doesn't already have one:
///  - if live GPS is available, adopt it — but only when the just-added ref
///    is within [_nearbyGridAdoptionKm] of it (a far-away ref added while
///    away from the shack shouldn't imply "this is where I am").
///  - otherwise (no GPS fix), adopt the first ref's own grid, if it has one
///    — the most that can be inferred without a location source at all.
/// A pure function (no Flutter/service dependencies) so this decision is
/// unit-testable without exercising the whole ActivitiesView widget tree.
String? gridToAdoptAfterAddingRef({
  required String? operationGrid,
  required GridLocation? gpsPosition,
  required num? distanceKm,
  required List<Map<String, dynamic>> refsAfterAdd,
}) {
  if (operationGrid != null) return null;

  if (gpsPosition != null) {
    if (distanceKm == null || distanceKm > _nearbyGridAdoptionKm) return null;
    return locationToGrid6(gpsPosition.latitude, gpsPosition.longitude);
  }

  final firstGrid = refsAfterAdd.isEmpty ? null : refsAfterAdd.first['grid'] as String?;
  return (firstGrid != null && firstGrid.isNotEmpty) ? firstGrid : null;
}

class OperationSheet extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueNotifier<bool>? hasUpdatesNotifier;
  final ValueChanged<Operation>? onOperationChanged;
  final VoidCallback? onExport;

  const OperationSheet({
    super.key,
    required this.services,
    required this.operation,
    this.hasUpdatesNotifier,
    this.onOperationChanged,
    this.onExport,
  });

  @override
  State<OperationSheet> createState() => OperationSheetState();
}

class OperationSheetState extends State<OperationSheet> {
  final _baseKey = GlobalKey<_ActivitiesBaseState>();

  void updateOperation(Operation op) => _baseKey.currentState?.updateOperation(op);
  void saveAndClose() => _baseKey.currentState?.saveAndClose();
  void revertAndClose() => _baseKey.currentState?.revertAndClose();

  @override
  Widget build(BuildContext context) {
    return _ActivitiesBase(
      key: _baseKey,
      services: widget.services,
      operation: widget.operation,
      hasUpdatesNotifier: widget.hasUpdatesNotifier,
      onOperationChanged: widget.onOperationChanged,
      onExport: widget.onExport,
      isOperationSheet: true,
    );
  }
}

class ActivitiesPane extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueNotifier<bool>? hasUpdatesNotifier;
  final ValueChanged<Operation>? onOperationChanged;
  final VoidCallback? onExport;

  const ActivitiesPane({
    super.key,
    required this.services,
    required this.operation,
    this.hasUpdatesNotifier,
    this.onOperationChanged,
    this.onExport,
  });

  @override
  State<ActivitiesPane> createState() => ActivitiesPaneState();
}

class ActivitiesPaneState extends State<ActivitiesPane> {
  final _baseKey = GlobalKey<_ActivitiesBaseState>();

  void updateOperation(Operation op) => _baseKey.currentState?.updateOperation(op);
  void saveAndClose() => _baseKey.currentState?.saveAndClose();
  void revertAndClose() => _baseKey.currentState?.revertAndClose();

  @override
  Widget build(BuildContext context) {
    return _ActivitiesBase(
      key: _baseKey,
      services: widget.services,
      operation: widget.operation,
      hasUpdatesNotifier: widget.hasUpdatesNotifier,
      onOperationChanged: widget.onOperationChanged,
      onExport: widget.onExport,
      isOperationSheet: false,
    );
  }
}

class _ActivitiesBase extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueNotifier<bool>? hasUpdatesNotifier;
  final ValueChanged<Operation>? onOperationChanged;
  final VoidCallback? onExport;
  final bool isOperationSheet;

  const _ActivitiesBase({
    super.key,
    required this.services,
    required this.operation,
    this.hasUpdatesNotifier,
    this.onOperationChanged,
    this.onExport,
    required this.isOperationSheet,
  });

  @override
  State<_ActivitiesBase> createState() => _ActivitiesBaseState();
}

class _ActivitiesBaseState extends State<_ActivitiesBase> {
  late Operation _operation;

  void updateOperation(Operation op) {
    if (mounted) {
      setState(() => _operation = op);
      widget.hasUpdatesNotifier?.value = _hasUpdates(op, widget.operation);
    }
  }
  List<Map<String, dynamic>> _controls = const [];
  bool _loadingControls = true;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggestions = true;
  // Guards against a slower, earlier-fired search resolving after a faster,
  // more recent one and clobbering its results — only the response whose
  // id still matches the latest request gets applied.
  int _searchRequestId = 0;

  bool _activitiesExpanded = true;
  bool _searchExpanded = true;
  late bool _allOptionsExpanded;
  late bool _allOptionsFullyOpened;

  // Only watched when the operation itself has no grid — its own grid
  // always takes priority over live GPS (see ExtensionService.suggestActivities).
  bool _watchingLocation = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
    widget.hasUpdatesNotifier?.value = _hasUpdates(_operation, widget.operation);
    _loadControls();
    
    final hidden = widget.services.settings.prefs.getBool('activitiesAllOptionsHidden') ?? false;
    _allOptionsExpanded = !hidden;
    _allOptionsFullyOpened = false;

    _watchingLocation = true;
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
    _search('');
    // Focusing the search field always reveals its results, even if the
    // user (or a previous collapse) had left the accordion closed.
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && !_searchExpanded) {
        setState(() => _searchExpanded = true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    if (_watchingLocation) {
      widget.services.location.removeListener(_onLocationChanged);
      widget.services.location.stop();
    }
    super.dispose();
  }

  // Re-runs the current search once the device's first GPS fix comes in (or
  // its status otherwise changes), so nearby suggestions appear without the
  // user having to touch the search field themselves. Routed through the
  // same debounce as typed search — the position stream can otherwise fire
  // every few seconds while moving (e.g. driving), each one triggering a
  // fresh round of extension-hook lookups.
  void _onLocationChanged() {
    if (mounted) _onSearchChanged(_searchController.text);
  }

  Future<void> _loadControls() async {
    final controls = await widget.services.extensions.operationControls(_operation.data);
    if (mounted) {
      setState(() {
        _controls = controls;
        _loadingControls = false;
      });
    }
  }

  bool _matchesPattern(String? pattern, String code) =>
      pattern == null || RegExp('^(?:$pattern)\$', caseSensitive: false).hasMatch(code);

  bool _isDuplicateRef(String type, String code, {int? excludingIndex}) {
    final refs = _operation.refs;
    for (var i = 0; i < refs.length; i++) {
      if (i == excludingIndex) continue;
      if (refs[i]['type'] == type && refs[i]['ref'] == code) return true;
    }
    return false;
  }

  bool _areRefsEqual(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final mapA = a[i] as Map?;
      final mapB = b[i] as Map?;
      if (mapA == null || mapB == null) {
        if (mapA != mapB) return false;
        continue;
      }
      if (!mapEquals(mapA, mapB)) return false;
    }
    return true;
  }

  bool _hasUpdates(Operation current, Operation initial) {
    if (current.grid != initial.grid) return true;
    if (current.stationCall != initial.stationCall) return true;
    if (current.title != initial.title) return true;
    if (((current.data['operatorCall'] as String?) ?? '') != ((initial.data['operatorCall'] as String?) ?? '')) return true;
    if (((current.data['notes'] as String?) ?? '') != ((initial.data['notes'] as String?) ?? '')) return true;
    return !_areRefsEqual(current.refs, initial.refs);
  }

  void _saveOperationData(Map<String, dynamic> patch) {
    final updated = Operation(
      uuid: _operation.uuid,
      data: {..._operation.data, ...patch},
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    if (mounted) {
      setState(() => _operation = updated);
      widget.hasUpdatesNotifier?.value = _hasUpdates(updated, widget.operation);
      widget.onOperationChanged?.call(updated);
    }
  }

  void _saveRefs(List<Map<String, dynamic>> refs) => _saveOperationData({'refs': refs});

  /// Opportunistically fills in the operation's own (still-unset) grid right
  /// after a new activity ref is added — from live GPS if that ref is close
  /// by, or otherwise from the first ref's own grid once GPS isn't available
  /// — so features that need a grid (nearby suggestions, the Map tab) work
  /// without the user having to set one by hand via OperationLocationScreen.
  void _maybeAdoptGridFromNewRef({num? distanceKm}) {
    final position = widget.services.location.position;
    final grid = gridToAdoptAfterAddingRef(
      operationGrid: _operation.grid,
      gpsPosition: position == null ? null : GridLocation(position.latitude, position.longitude),
      distanceKm: distanceKm,
      refsAfterAdd: _operation.refs,
    );
    if (grid != null) {
      final isGpsGrid = position != null && grid == locationToGrid6(position.latitude, position.longitude);
      _saveOperationData({
        'grid': grid,
        'gridSource': isGpsGrid ? 'gps' : 'manual',
      });
    }
  }

  Future<void> _editRef(Map<String, dynamic> ref) async {
    final t = context.t.activitiesView;
    final code = await editOneFieldDialog(
      context,
      title: t.editActivity,
      fieldLabel: t.reference,
      fieldInitial: (ref['ref'] as String?) ?? '',
      fieldCapitalization: TextCapitalization.characters,
      saveLabel: context.t.common.save,
    );
    if (code == null || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    final type = ref['type'] as String?;
    final pattern = (controlForRefType(_controls, type)?['input'] as Map?)?['pattern'] as String?;
    if (!_matchesPattern(pattern, trimmed)) {
      widget.services.statusBar.setMessage(key: 'activities:invalid', text: t.invalidReference);
      return;
    }

    final refs = _operation.refs;
    final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
    if (index < 0) return;

    if (_isDuplicateRef(type ?? '', trimmed, excludingIndex: index)) {
      widget.services.statusBar.setMessage(key: 'activities:duplicate', text: t.duplicateReference);
      return;
    }

    final decorated = await widget.services.extensions.decorateRef({...ref, 'ref': trimmed});
    _saveRefs([...refs]..[index] = decorated);
  }

  Future<void> _deleteRef(Map<String, dynamic> ref) async {
    final refs = _operation.refs.where((r) => !(r['type'] == ref['type'] && r['ref'] == ref['ref'])).toList();
    _saveRefs(refs);
    if (!mounted) return;
    // Removing an activity is often a mistake to undo, so surface it back as
    // a suggestion — but only until the next search resolves (or this view
    // closes), rather than sticking around as stale state.
    final alreadySuggested = _suggestions.any((s) => s['type'] == ref['type'] && s['ref'] == ref['ref']);
    if (!alreadySuggested) {
      setState(() => _suggestions = [ref, ..._suggestions]);
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String term) async {
    final requestId = ++_searchRequestId;
    setState(() => _loadingSuggestions = true);
    final trimmed = term.trim();
    final location = widget.services.location;
    final fallbackPosition = location.position;
    final results = await widget.services.extensions.suggestActivities(
      _operation.data,
      searchTerm: trimmed.isEmpty ? null : trimmed,
      fallbackLocation:
          fallbackPosition == null ? null : GridLocation(fallbackPosition.latitude, fallbackPosition.longitude),
    );
    // A newer search may have fired (and even resolved) while this one was
    // in flight — only the still-current request gets to apply its results.
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _suggestions = results;
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _addSuggestion(Map<String, dynamic> suggestion) async {
    final type = suggestion['type'] as String?;
    final code = suggestion['ref'] as String?;
    if (type != null && code != null && _isDuplicateRef(type, code)) {
      widget.services.statusBar.setMessage(key: 'activities:duplicate', text: context.t.activitiesView.duplicateReference);
      return;
    }
    _saveRefs([..._operation.refs, suggestion]);
    _maybeAdoptGridFromNewRef(distanceKm: suggestion['distance'] as num?);
  }

  Future<void> _addManually(Map<String, dynamic> control) async {
    final t = context.t.activitiesView;
    final input = (control['input'] as Map?) ?? const {};
    final refType = input['refType'] as String?;
    if (refType == null) return;

    final code = await editOneFieldDialog(
      context,
      title: (control['label'] as String?) ?? t.addActivity,
      fieldLabel: t.reference,
      fieldInitial: '',
      fieldCapitalization: TextCapitalization.characters,
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final trimmed = code.trim().toUpperCase();
    if (!_matchesPattern(input['pattern'] as String?, trimmed)) {
      widget.services.statusBar.setMessage(key: 'activities:invalid', text: t.invalidReference);
      return;
    }
    if (_isDuplicateRef(refType, trimmed)) {
      widget.services.statusBar.setMessage(key: 'activities:duplicate', text: t.duplicateReference);
      return;
    }

    final ref = <String, dynamic>{'type': refType, 'ref': trimmed};
    final decorated = await widget.services.extensions.decorateRef(ref);
    _saveRefs([..._operation.refs, decorated]);
    // No distance to check here (a manually-typed ref wasn't looked up
    // relative to any location) — only the no-GPS, first-ref-grid path
    // inside `_maybeAdoptGridFromNewRef` can apply.
    _maybeAdoptGridFromNewRef();
  }

  /// The message shown in the Suggestions & Search section when there are
  /// no results: while there's a search term, a plain "no matches" message
  /// always applies; with an empty term (nearby suggestions) and no
  /// operation grid, the three location-driven states from issue #6 kick in
  /// instead — determining the device's location, or location known to be
  /// unavailable.
  String get _suggestionsEmptyMessage {
    final t = context.t.activitiesView;
    if (_searchController.text.trim().isNotEmpty || _operation.grid != null) return t.noSuggestions;
    return switch (widget.services.location.status) {
      LocationStatus.unknown || LocationStatus.determining => t.determiningLocation,
      LocationStatus.available => t.noSuggestions,
      LocationStatus.permissionDenied || LocationStatus.unavailable => t.noNearbySuggestions,
    };
  }

  String _activitiesTitle(int count) {
    final t = context.t.activitiesView;
    if (count == 0) return t.activitiesCountZero;
    if (count == 1) return t.activitiesCountOne;
    return t.activitiesCountOther(count: count);
  }

  String _groupedActivitiesSubtitle(List<Map<String, dynamic>> refs) {
    final types = refs.map((r) => r['type'] as String?).whereType<String>().where((t) => t.isNotEmpty).toList();
    final counts = <String, int>{};
    for (final type in types) {
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final parts = <String>[];
    for (final entry in counts.entries) {
      final shortName = _shortNameForType(entry.key);
      if (entry.value > 1) {
        parts.add('$shortName×${entry.value}');
      } else {
        parts.add(shortName);
      }
    }
    return parts.join(', ');
  }

  String _shortNameForType(String type) {
    final control = controlForRefType(_controls, type);
    if (control != null) {
      final controlKey = control['key'] as String? ?? '';
      final extensionKey = controlKey.split('/').first;
      final extension = widget.services.extensions.availableExtensions.cast<ExtensionInfo?>().firstWhere(
        (info) => info?.key == extensionKey,
        orElse: () => null,
      );
      final label = extension?.effectiveShortName ?? (control['label'] as String?) ?? '';
      if (label.isNotEmpty) return label;
    }
    return type.toUpperCase();
  }

  String _allOptionsTitle(TranslationsEn t) {
    final refListControls = _controls.where((c) => (c['input'] as Map?)?['kind'] == 'refList').toList();
    final labels = <String>[];
    for (final control in refListControls) {
      final controlKey = control['key'] as String? ?? '';
      final extensionKey = controlKey.split('/').first;
      final extension = widget.services.extensions.availableExtensions.cast<ExtensionInfo?>().firstWhere(
        (info) => info?.key == extensionKey,
        orElse: () => null,
      );
      final label = extension?.effectiveShortName ?? (control['label'] as String?) ?? '';
      if (label.isNotEmpty && !labels.contains(label)) {
        labels.add(label);
      }
    }
    if (labels.isEmpty) return t.activitiesView.allOptions;
    if (labels.length == 1) {
      return t.activitiesView.activitiesTitle1(first: labels[0]);
    } else if (labels.length == 2) {
      return t.activitiesView.activitiesTitle2(first: labels[0], second: labels[1]);
    } else {
      return t.activitiesView.activitiesTitleMore(
        first: labels[0],
        second: labels[1],
        more: (labels.length - 2).toString(),
      );
    }
  }

  /// Builds a section's body from a list of (already opaquely white) rows:
  /// content-sized when [fill] is false, or a scrollable list when [fill]
  /// is true — the leftover space below the last row then shows the
  /// Scaffold's own gray background straight through, since neither
  /// ListView nor its rows' surrounding space paint anything there. [fill]
  /// varies at runtime (Current Activities only fills when Search is
  /// collapsed), so this shape has to be chosen here rather than baked
  /// into a fixed widget tree.
  Widget _sectionBody({required bool fill, required List<Widget> rows, required Widget emptyPlaceholder}) {
    if (rows.isEmpty) return emptyPlaceholder;
    if (!fill) return Column(mainAxisSize: MainAxisSize.min, children: rows);
    return ListView(children: rows);
  }

  Future<void> saveAndClose() async {
    await widget.services.operations.saveData(_operation);
    if (mounted) Navigator.of(context).pop();
  }

  void revertAndClose() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    final refs = _operation.refs;
    final isDark = theme.brightness == Brightness.dark;
    final accordionColor = theme.colorScheme.surfaceContainerHighest;
    final onAccordionColor = theme.colorScheme.onSurfaceVariant;
    // Rows paint an opaque color so they read distinctly from the pane's
    // gray/dark background (the ColoredBox below), which otherwise shows
    // straight through wherever a filling section has no row to draw. The
    // pane brings this background itself so both Modal Pane presentations
    // (full screen and dialog card) look the same.
    final listBgColor = isDark ? const Color(0xFF141618) : const Color(0xFFF3F4F6);
    final rowColor = isDark ? const Color(0xFF212426) : Colors.white;
    // Current Activities only takes the flexible remaining space when
    // Search isn't there to claim it.
    final activitiesFill = !_searchExpanded;

    return Material(
      color: listBgColor,
      child: Column(
        children: [
          _AccordionSection(
            title: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isOperationSheet
                        ? _activitiesTitle(
                            refs.map((r) => r['type'] as String?).whereType<String>().where((t) => t.isNotEmpty).toSet().length,
                          )
                        : context.t.operation.sections.activities,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: onAccordionColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isOperationSheet
                        ? (refs.isEmpty
                            ? context.t.activitiesView.emptySheet
                            : _groupedActivitiesSubtitle(refs))
                        : (refs.isEmpty
                            ? context.t.operation.activitiesNone
                            : context.t.activitiesView.activeCount(count: refs.length)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            expanded: _activitiesExpanded,
            fill: activitiesFill,
            onToggle: () => setState(() => _activitiesExpanded = !_activitiesExpanded),
            headerColor: accordionColor,
            onHeaderColor: onAccordionColor,
            trailing: widget.isOperationSheet
                ? Opacity(
                    opacity: _operation.qsoCount == 0 ? 0.8 : 1.0,
                    child: TextButton.icon(
                      onPressed: widget.onExport,
                      icon: Icon(resolveIconName('file-export-outline'), size: 18),
                      label: Text(context.t.activitiesView.exports),
                      style: TextButton.styleFrom(
                        foregroundColor: onAccordionColor,
                      ),
                    ),
                  )
                : null,
            child: _sectionBody(
              fill: activitiesFill,
              emptyPlaceholder: const SizedBox.shrink(),
              rows: [
                for (final ref in refs)
                  ListTile(
                    tileColor: _loadingControls
                        ? rowColor
                        : (isUnknownRefType(_controls, ref['type'] as String?)
                            ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                            : rowColor),
                    // Right padding matches the accordion header's own
                    // horizontal inset, so this trailing icon button lines
                    // up under the search row's options button — same
                    // IconButton defaults (no custom size/padding) too.
                    contentPadding: const EdgeInsets.only(left: 16, right: 4),
                    leading: _loadingControls
                        ? Icon(resolveIconName('puzzle'))
                        : activityRefIcon(_controls, ref['type'] as String?),
                    title: Text(
                      (ref['shortLabel'] ?? ref['ref'] ?? '?') as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: (ref['name'] as String?) != null ? Text(ref['name'] as String) : null,
                    onTap: () => _editRef(ref),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: t.removeActivity,
                      onPressed: () => _deleteRef(ref),
                    ),
                  ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final locStatus = widget.services.location.status;
              final operationGrid = _operation.grid;

              final Widget locationPin;
              final String label;
              Color? textColor;

              if (operationGrid != null && operationGrid.isNotEmpty) {
                final gridSource = _operation.data['gridSource'] as String? ?? (
                  (widget.services.location.grid != null && operationGrid == widget.services.location.grid)
                      ? 'gps'
                      : 'manual'
                );

                if (gridSource == 'gps') {
                  locationPin = Icon(resolveIconName('map-marker'), color: const Color(0xFF1B5E20));
                  label = operationGrid;
                  textColor = const Color(0xFF1B5E20);
                } else {
                  locationPin = Icon(resolveIconName('pin'));
                  label = operationGrid;
                  textColor = null;
                }
              } else {
                if (locStatus == LocationStatus.unknown || locStatus == LocationStatus.determining) {
                  locationPin = const _PulsingGpsPin();
                  label = 'GPS…';
                  textColor = Colors.blue;
                } else if (locStatus == LocationStatus.available && widget.services.location.grid != null) {
                  locationPin = Icon(resolveIconName('map-marker'), color: const Color(0xFF1B5E20));
                  label = widget.services.location.grid!;
                  textColor = const Color(0xFF1B5E20);
                } else if (locStatus == LocationStatus.available && widget.services.location.grid == null) {
                  locationPin = const _PulsingGpsPin();
                  label = 'GPS…';
                  textColor = Colors.blue;
                } else {
                  locationPin = Icon(resolveIconName('map-marker-off'), color: const Color(0xFFC62828));
                  label = '';
                  textColor = const Color(0xFFC62828);
                }
              }

              return _AccordionSection(
                title: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: t.searchHint,
                    prefixIcon: Icon(Icons.search, color: onAccordionColor.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: Color.alphaBlend(onAccordionColor.withValues(alpha: 0.06), accordionColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: onAccordionColor.withValues(alpha: 0.25)),
                    ),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                ),
                titleIsInteractive: true,
                trailing: widget.isOperationSheet
                    ? TextButton.icon(
                        icon: locationPin,
                        label: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: textColor ?? onAccordionColor,
                        ),
                        onPressed: () async {
                          final patch = await showHaloDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (_) => OperationLocationScreen(
                              services: widget.services,
                              operation: _operation,
                            ),
                          );
                          if (patch != null && mounted) {
                            final updated = Operation(
                              uuid: _operation.uuid,
                              data: {..._operation.data, ...patch},
                              qsoCount: _operation.qsoCount,
                              startAtMillisMin: _operation.startAtMillisMin,
                              startAtMillisMax: _operation.startAtMillisMax,
                              localData: _operation.localData,
                            );
                            updateOperation(updated);
                            widget.onOperationChanged?.call(updated);
                          }
                        },
                      )
                    : null,
                expanded: _searchExpanded,
                fill: true,
                onToggle: () => setState(() => _searchExpanded = !_searchExpanded),
                headerColor: accordionColor,
                onHeaderColor: onAccordionColor,
            child: Column(
              children: [
                if (_loadingSuggestions) const LinearProgressIndicator(),
                Expanded(
                  child: _sectionBody(
                    fill: true,
                    emptyPlaceholder: _loadingSuggestions
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(_suggestionsEmptyMessage, style: TextStyle(color: theme.colorScheme.outline)),
                          ),
                    rows: [
                      for (final suggestion in _suggestions)
                        if (!refs.any((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']))
                          ListTile(
                            tileColor: _loadingControls
                                ? rowColor
                                : (isUnknownRefType(_controls, suggestion['type'] as String?)
                                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                    : rowColor),
                            leading: _loadingControls
                                ? Icon(resolveIconName('puzzle'))
                                : activityRefIcon(_controls, suggestion['type'] as String?),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    (suggestion['shortLabel'] ?? suggestion['ref'] ?? '?') as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (suggestion['distance'] is num)
                                  Text(
                                    t.distanceKm(distance: formatNumber((suggestion['distance'] as num).round())),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              [
                                suggestion['name'],
                                suggestion['location'],
                              ].whereType<String>().where((s) => s.isNotEmpty).join(' • '),
                            ),
                            onTap: () => _addSuggestion(suggestion),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
          _AccordionSection(
            title: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                widget.isOperationSheet ? _allOptionsTitle(context.t) : t.allOptions,
                style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
              ),
            ),
            expanded: _allOptionsExpanded,
            onToggle: () {
              setState(() {
                if (_allOptionsExpanded) {
                  _allOptionsExpanded = false;
                  widget.services.settings.prefs.setBool('activitiesAllOptionsHidden', true);
                } else {
                  _allOptionsExpanded = true;
                  _allOptionsFullyOpened = true;
                  widget.services.settings.prefs.setBool('activitiesAllOptionsHidden', false);
                }
              });
            },
            headerColor: accordionColor,
            onHeaderColor: onAccordionColor,
            trailing: TextButton.icon(
              onPressed: () async {
                final isTwoPane = ShirtSize.of(context).isTwoPane;
                await showModalPane<void>(
                  context,
                  title: t.manageExtensions,
                  closeTooltip: context.t.common.close,
                  scrollable: false,
                  trailing: isTwoPane
                      ? TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Text(context.t.common.done),
                        )
                      : null,
                  builder: (_) => ExtensionsPanel(services: widget.services),
                );
                if (mounted) {
                  _debounce?.cancel();
                  await _loadControls();
                  _search(_searchController.text);
                }
              },
              icon: Icon(Icons.extension, size: 18, color: onAccordionColor),
              label: Text(
                t.manage,
                style: TextStyle(color: onAccordionColor),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            child: () {
              final allOptionsContent = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final control in _controls)
                    if ((control['input'] as Map?)?['kind'] == 'refList')
                      ListTile(
                        tileColor: rowColor,
                        leading: _accentIcon(control['icon'] as String?, resolveExtensionColor(control['color'] as String?)),
                        title: Text((control['label'] as String?) ?? ''),
                        onTap: () => _addManually(control),
                      ),
                ],
              );
              return _allOptionsFullyOpened
                  ? allOptionsContent
                  : SizedBox(
                      height: 84.0,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: allOptionsContent,
                      ),
                    );
            }(),
          ),
        ],
      ),
    );
  }
}

/// One collapsible section. The tinted header always shows, arrow on the
/// left; the body appears below it only while expanded, using the default
/// (untinted) background. When [fill] and expanded, the whole section
/// (header + body) is wrapped in [Expanded] so it consumes whatever
/// vertical space its siblings don't need — [child] must then provide its
/// own bounded/scrollable content (see the Suggestions & Search section's
/// `ListView`).
///
/// The arrow rotates and (for non-[fill] sections) the body cross-fades and
/// resizes smoothly. A [fill] section's own Expanded/flex toggle stays
/// instant — animating who claims leftover flex space between sibling
/// sections isn't something Flutter's implicit animations do — but its
/// arrow still animates like every other section's.
class _AccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;
  final Widget child;
  final bool fill;

  /// True when [title] is itself an interactive control (the search field)
  /// that shouldn't also toggle expand/collapse on tap — only the arrow
  /// button does, in that case.
  final bool titleIsInteractive;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the search section's options button).
  final Widget? trailing;

  const _AccordionSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    required this.child,
    this.fill = false,
    this.titleIsInteractive = false,
    this.trailing,
  });

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final arrow = IconButton(
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: _duration,
        curve: Curves.easeInOut,
        child: Icon(Icons.expand_more, color: onHeaderColor),
      ),
      onPressed: onToggle,
    );

    final headerRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          arrow,
          Expanded(child: title),
          if (trailing != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorbs taps so they don't propagate to InkWell
              child: trailing!,
            ),
        ],
      ),
    );

    final header = Material(
      color: headerColor,
      child: titleIsInteractive ? headerRow : InkWell(onTap: onToggle, child: headerRow),
    );

    if (fill) {
      if (!expanded) return header;
      // The Expanded/flex allocation itself can't be smoothly animated
      // (space redistribution between flex siblings isn't something
      // Flutter's layout interpolates, and attempting it risks overflow
      // mid-animation) — fading the newly-revealed content in is the safe
      // way to still give this section a visible reveal animation. Same
      // widget position across rebuilds (e.g. every search keystroke) keeps
      // the fade's AnimationController alive, so it only actually plays
      // once, right when the section opens.
      return Expanded(
        child: Column(
          children: [
            header,
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: _duration,
                curve: Curves.easeIn,
                builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    final body = AnimatedCrossFade(
      firstChild: child,
      secondChild: const SizedBox(width: double.infinity),
      crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: _duration,
      sizeCurve: Curves.easeInOut,
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [header, body]);
  }
}

class _PulsingGpsPin extends StatefulWidget {
  const _PulsingGpsPin();

  @override
  State<_PulsingGpsPin> createState() => _PulsingGpsPinState();
}

class _PulsingGpsPinState extends State<_PulsingGpsPin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    final isTest = !kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(resolveIconName('map-marker'), color: Colors.blue),
    );
  }
}
