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
import '../../services/error_reporting_service.dart';
import '../../services/location_service.dart';
import '../../services/extension_service.dart';
import '../../services/settings_service.dart';
import 'operation_location_screen.dart';
import '../operation_dialogs.dart';
import '../extensions_panel.dart';
import '../../i18n/strings.g.dart';
import '../../tools/distance_format.dart';
import '../../tools/operation_title.dart';


/// An icon, circled in [color] at 60% opacity when the control declares an
/// accent — sparingly used, so a control with no color just
/// renders the bare icon.
Widget _accentIcon(String? iconName, Color? color) {
  final icon = Icon(resolveIconName(iconName));
  if (color == null) return icon;
  return CircleAvatar(backgroundColor: color.withValues(alpha: 0.6), child: icon);
}

// Close enough that the operation's grid and the caller's live GPS grid
// would round to the same (or an adjacent) square anyway, so adopting it
// isn't a meaningful accuracy loss.
const _nearbyGridAdoptionKm = 15;

/// Height of the search section's progress bar — reserved whether or not a
/// search is running, so the results below never shift. Matches
/// LinearProgressIndicator's own default thickness.
const _searchProgressHeight = 4.0;

/// Height of the search-field band (excluding the progress slot) at text
/// scale 1. A constant because the band rides in a pinned
/// SliverPersistentHeader, which needs an explicit extent it cannot measure:
/// 8px padding + a 44px dense field/button row + 8px. The OS text-scale
/// preference composes on top of the app's own Font Scale (ui-scaling.md
/// rule 3) and grows the field inside it, so callers scale this — see
/// [_PinnedSearchBand].
const _searchBandHeight = 60.0;

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

/// Whether an operation may carry more than one ref of [type] at a time, as
/// the extension declared it: on the [suggestion] being added, or — for a
/// ref typed in by hand, which has no suggestion — on the type's [control]
/// descriptor. Defaults to FALSE: one reference of a kind is the safe
/// assumption, and a type that genuinely stacks (POTA n-fers) says so
/// explicitly. Anything else gets the replace-on-add behavior of
/// [refsKeptWhenAdding].
bool allowsMultipleRefsOfType(
  String? type, {
  Map<String, dynamic>? suggestion,
  Map<String, dynamic>? control,
}) {
  final fromSuggestion = suggestion?['allowsMultiple'];
  if (fromSuggestion is bool) return fromSuggestion;
  final fromControl = control?['allowsMultiple'];
  if (fromControl is bool) return fromControl;
  return false;
}

/// Whether a ref of [type] is form-configured (a contest). Their `label`
/// carries the event name with its variation baked in ("CQ WW CW",
/// "ARRL Field Day 2027"), so lists lead with it — a plain reference
/// activity leads with its code-like `shortLabel` ("POTA US-1234") instead.
///
/// This is the one place an *editor* property decides display. Every other
/// surface reads `shortLabel`, which names the same event abbreviated
/// ("FD 2027"); see the display-key table in docs/design/contests.md §5.4,
/// which extension authors are held to.
bool refTypeIsForm(Map<String, dynamic>? control) => (control?['input'] as Map?)?['kind'] == 'form';

/// Whether a ref of [type] has anything to edit once it's on the operation.
/// Defaults to FALSE — a plain reference activity (POTA, SOTA) carries only
/// the code its own search already resolved, so retyping it by hand invites a
/// typo no lookup would catch. A type whose refs carry more than that says
/// `editable: true` on its control descriptor.
bool refTypeIsEditable(Map<String, dynamic>? control) {
  // A form-configured activity is editable by construction: the form IS the
  // reference, so there is always something to open. Inferring it here rather
  // than making every contest also set `editable: true` — the flag exists to
  // mark the unusual reference type that carries more than a looked-up code,
  // and a form control is that by definition.
  if (refTypeIsForm(control)) return true;
  return control?['editable'] == true;
}

/// What an activity row leads with, for a ref or a suggestion alike — the
/// two must agree, or the same reference reads differently before and after
/// it is added. See [refTypeIsForm] for which field wins.
String activityRowTitle(Map<String, dynamic>? control, Map<String, dynamic> entry) {
  final leading = refTypeIsForm(control) ? entry['label'] ?? entry['shortLabel'] : entry['shortLabel'];
  return (leading ?? entry['ref'] ?? '?') as String;
}

/// An activity row's second line: what the reference IS, beyond its code —
/// a park's name and location, a contest's exchange. Null when the entry
/// carries neither, so the row stays a single line rather than an empty one.
String? activityRowDetail(Map<String, dynamic> entry) {
  final detail = [
    entry['name'],
    entry['location'],
  ].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
  return detail.isEmpty ? null : detail;
}

/// The refs to keep when adding one of [type]: all of them when the type
/// allows multiple, and otherwise everything BUT that type — a single-ref
/// type's new reference replaces the one already there rather than piling up
/// next to it.
List<Map<String, dynamic>> refsKeptWhenAdding({
  required List<Map<String, dynamic>> refs,
  required String? type,
  required bool allowsMultiple,
}) {
  if (type == null || allowsMultiple) return refs;
  return refs.where((r) => r['type'] != type).toList();
}

/// A search box entry split into an optional extension scope and the text
/// after it: `pota:` scopes to POTA's own suggestions, `pota: bear mtn`
/// scopes AND searches, plain `bear mtn` searches everything. The scope is
/// what the "Activity Types" rows insert when tapped.
class ActivitySearchQuery {
  /// The extension key to ask, or null for "every activity hook".
  final String? activityKey;

  /// What's left to search for — empty means "just show me this scope's
  /// nearby suggestions".
  final String term;

  const ActivitySearchQuery({this.activityKey, required this.term});

  static final _scopePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*):(.*)$', dotAll: true);

  /// A leading `key:` only scopes when [knownKeys] actually has that key —
  /// references and park names carry colons too (`US-0001: Something`), and
  /// treating one as a scope would quietly search the wrong extension, or
  /// none, while looking like it worked.
  factory ActivitySearchQuery.parse(String input, Set<String> knownKeys) {
    final trimmed = input.trim();
    final match = _scopePattern.firstMatch(trimmed);
    final key = match?.group(1)?.toLowerCase();
    if (key == null || !knownKeys.contains(key)) return ActivitySearchQuery(term: trimmed);
    return ActivitySearchQuery(activityKey: key, term: (match!.group(2) ?? '').trim());
  }

  /// The text the search field holds for a bare scope — what tapping an
  /// "Activity Types" row types for the user.
  static String scopePrefixFor(String activityKey) => '$activityKey: ';
}

/// The operation sheet's body: the activities list and search, plus the
/// operation's own controls. Driven through its [OperationSheetState] by the
/// screen that presents it (saving, and pushing draft edits back in).
class OperationSheet extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueChanged<Operation>? onOperationChanged;
  final VoidCallback? onDelete;

  /// Opens the operation-details editor (callsign, title, notes) — owned by
  /// the presenting screen, which routes the result back in through
  /// [OperationSheetState.updateOperation].
  final VoidCallback? onEditDetails;

  const OperationSheet({
    super.key,
    required this.services,
    required this.operation,
    this.onOperationChanged,
    this.onDelete,
    this.onEditDetails,
  });

  @override
  State<OperationSheet> createState() => OperationSheetState();
}

class OperationSheetState extends State<OperationSheet> {
  late Operation _operation;

  void updateOperation(Operation op) {
    if (mounted) {
      final before = _operation;
      setState(() => _operation = op);
      _reloadControlsIfRefsChanged(before, op);
    }
  }
  List<Map<String, dynamic>> _controls = const [];
  bool _loadingControls = true;
  int _controlsRequest = 0;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggestions = true;
  // Guards against a slower, earlier-fired search resolving after a faster,
  // more recent one and clobbering its results — only the response whose
  // id still matches the latest request gets applied.
  int _searchRequestId = 0;

  /// Extensions that match what was typed but aren't turned on — offered as
  /// "enable this?" rows above the results, since an activity the user
  /// searched for looking like it simply doesn't exist is worse than one
  /// extra row. Empty unless the box has text in it.
  List<ExtensionInfo> _disabledMatches = const [];

  /// Guards against a second tap while an enable-and-restart is in flight.
  bool _enablingExtension = false;

  /// Whether [_suggestions] came from a typed search rather than the nearby
  /// list. Refs the operation already has are dropped from nearby suggestions
  /// (they're proposals — proposing what you already have is noise), but kept
  /// in search results: searching for something by name and getting nothing
  /// back reads as "not found", which is worse than a marked-up hit.
  bool _suggestionsAreSearchResults = false;

  static const _flashDuration = Duration(milliseconds: 900);

  /// The Current Activities row currently flashing (see [_flashExistingRef]),
  /// as `type/ref`; null when nothing is. [_flashToken] only exists to make
  /// each flash a distinct animation.
  String? _flashingRefRowId;
  int _flashToken = 0;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _refRowKeys = {};

  late bool _allOptionsExpanded;
  late bool _allOptionsFullyOpened;

  // Only watched when the operation itself has no grid — its own grid
  // always takes priority over live GPS (see ExtensionService.suggestActivities).
  bool _watchingLocation = false;

  @override
  void initState() {
    super.initState();
    _operation = widget.operation;
    _loadControls();
    
    final hidden = widget.services.settings.prefs.getBool('activitiesAllOptionsHidden') ?? false;
    _allOptionsExpanded = !hidden;
    _allOptionsFullyOpened = false;

    _watchingLocation = true;
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flashTimer?.cancel();
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
    // Refs change faster than the host answers — adding two activities in a row
    // leaves two lookups in flight, and the slower one must not install the
    // descriptors for the earlier state.
    final request = ++_controlsRequest;
    final controls = await widget.services.extensions.operationControls(_operation.data);
    if (mounted && request == _controlsRequest) {
      setState(() {
        _controls = controls;
        _loadingControls = false;
      });
    }
  }

  /// Rebuilds the descriptors when the operation's REFS change, from wherever
  /// `_operation` was replaced — a save, a revert, or a draft pushed in by the
  /// parent.
  ///
  /// A control's own form is allowed to depend on which refs the operation
  /// carries: State Parks asks Ohio for the park it is in, a power class and an
  /// entry category, Texas for a power class, and an operation with no event
  /// chosen for none of them. The refs are the only part of the operation a
  /// descriptor is built from, so a title or grid edit doesn't pay for a round
  /// trip.
  void _reloadControlsIfRefsChanged(Operation before, Operation after) {
    if (!_areRefsEqual(before.refs, after.refs)) _loadControls();
  }

  bool _matchesPattern(String? pattern, String code) =>
      pattern == null || RegExp('^(?:$pattern)\$', caseSensitive: false).hasMatch(code);

  bool _isDuplicateRef(String type, String code) =>
      _operation.refs.any((ref) => ref['type'] == type && ref['ref'] == code);

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
      final before = _operation;
      setState(() => _operation = updated);
      widget.onOperationChanged?.call(updated);
      _reloadControlsIfRefsChanged(before, updated);
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

  /// Opens an `input.kind == 'form'` control's setup form (a contest's
  /// identifier, sent exchange, mode…), pre-filled from [existing] if this ref
  /// is already on the operation. Returns the ref to save, or null if the
  /// operator cancelled.
  ///
  /// The form's values live directly on the ref, so they persist through the
  /// same `_saveRefs` path every other activity ref uses — no separate
  /// operation write-path is involved.
  Future<Map<String, dynamic>?> _runSetupForm(
    Map<String, dynamic> control, {
    Map<String, dynamic>? existing,
  }) async {
    final input = (control['input'] as Map?) ?? const {};
    final refType = input['refType'] as String?;
    final form = (input['form'] as Map?)?.cast<String, dynamic>();
    if (refType == null || form == null) return null;

    // Seed from the ref itself: every field key is a key on the ref.
    final initialState = <String, dynamic>{
      for (final entry in (existing ?? const <String, dynamic>{}).entries)
        if (entry.key != 'type') entry.key: entry.value,
    };

    final result = await showFormDialog(
      context,
      formDefinition: form,
      initialState: initialState,
      developerMode: widget.services.settings.developerMode,
    );
    if (result == null || !mounted) return null;

    return {...?existing, 'type': refType, ...result};
  }

  /// Only reachable for a ref type that declares `editable` (see
  /// [refTypeIsEditable]).
  Future<void> _editRef(Map<String, dynamic> ref) async {
    final t = context.t.activitiesView;

    // A form-configured activity (a contest) edits through its own setup form
    // rather than the single reference-code field below — it has no code.
    final formControl = controlForRefType(_controls, ref['type'] as String?);
    if ((formControl?['input'] as Map?)?['kind'] == 'form') {
      final updated = await _runSetupForm(formControl!, existing: ref);
      if (updated == null) return;
      final refs = _operation.refs;
      final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
      if (index < 0) return;
      final decorated = await widget.services.extensions.decorateRef(updated);
      _saveRefs([...refs]..[index] = decorated);
      return;
    }

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

    // The ref being edited is not its own duplicate.
    if (refs.indexWhere((r) => r['type'] == type && r['ref'] == trimmed) case final existing when existing >= 0 && existing != index) {
      widget.services.statusBar.setMessage(key: 'activities:duplicate', text: t.duplicateReference);
      return;
    }

    final decorated = await widget.services.extensions.decorateRef({...ref, 'ref': trimmed});
    _saveRefs([...refs]..[index] = decorated);
  }

  Future<void> _deleteRef(Map<String, dynamic> ref) async {
    final refs = _operation.refs.where((r) => !(r['type'] == ref['type'] && r['ref'] == ref['ref'])).toList();
    _saveRefs(refs);
    widget.services.track('activity_removed', {'activity': ref['type']});
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

  /// The extension keys the loaded activity controls belong to — what a
  /// `key:` prefix in the search box is checked against.
  Set<String> get _activityKeys => _controls
      .map((control) => ((control['key'] as String?) ?? '').split('/').first)
      .where((key) => key.isNotEmpty)
      .toSet();

  Future<void> _search(String term) async {
    final requestId = ++_searchRequestId;
    setState(() => _loadingSuggestions = true);
    final query = ActivitySearchQuery.parse(term, _activityKeys);
    final trimmed = query.term;
    final location = widget.services.location;
    final fallbackPosition = location.position;
    final results = await widget.services.extensions.suggestActivities(
      _operation.data,
      searchTerm: trimmed.isEmpty ? null : trimmed,
      activityKey: query.activityKey,
      fallbackLocation:
          fallbackPosition == null ? null : GridLocation(fallbackPosition.latitude, fallbackPosition.longitude),
    );
    // A newer search may have fired (and even resolved) while this one was
    // in flight — only the still-current request gets to apply its results.
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _suggestions = results;
        _suggestionsAreSearchResults = trimmed.isNotEmpty;
        _disabledMatches = _disabledExtensionsMatching(term);
        _loadingSuggestions = false;
      });
    }
  }

  /// The operation's refs minus the ones a new ref of [type] displaces (see
  /// [refsKeptWhenAdding]), reading the type's multiplicity off the
  /// suggestion being added or, for a hand-typed ref, its control descriptor.
  List<Map<String, dynamic>> _refsKeeping(String? type, {Map<String, dynamic>? suggestion}) => refsKeptWhenAdding(
        refs: _operation.refs,
        type: type,
        allowsMultiple: allowsMultipleRefsOfType(
          type,
          suggestion: suggestion,
          control: controlForRefType(_controls, type),
        ),
      );

  /// The operation-level actions that don't belong in the activities list
  /// itself. Share and Archive are declared but inert — the rows are here so
  /// the menu's shape is settled, and they stay disabled until each has an
  /// implementation behind it. Public: the sheet's Options button lives in
  /// the modal route's own header, which reaches in through the sheet key.
  Future<void> showOptions() async {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(t.optionsTitle),
        // The rows are the dialog's whole content, so they get the header's
        // horizontal inset from the ListTiles themselves rather than a
        // content padding that would double it.
        contentPadding: const EdgeInsets.symmetric(vertical: Space.md),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(MdiIcons.noteEditOutline),
              title: Text(t.operationDetails),
              // Same editor the pills open — the menu closes first so the
              // details dialog isn't stacked on top of it.
              onTap: () {
                Navigator.of(dialogContext).pop();
                widget.onEditDetails?.call();
              },
            ),
            ListTile(
              enabled: false,
              leading: const Icon(MdiIcons.shareVariant),
              title: Text(t.share),
            ),
            ListTile(
              enabled: false,
              leading: Icon(MdiIcons.archiveOutline),
              title: Text(t.archive),
            ),
            ListTile(
              leading: Icon(MdiIcons.delete, color: theme.colorScheme.error),
              title: Text(t.deleteOperation, style: TextStyle(color: theme.colorScheme.error)),
              // The sheet closes with the menu: deleting is about the
              // operation as a whole, and its confirmation belongs to the
              // screen underneath, not to a pane over a row that's going away.
              onTap: () {
                Navigator.of(dialogContext).pop();
                widget.onDelete?.call();
              },
            ),
          ],
        ),
        cancel: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.t.common.close),
        ),
      ),
    );
  }

  Future<void> _addSuggestion(Map<String, dynamic> suggestion) async {
    final type = suggestion['type'] as String?;
    final code = suggestion['ref'] as String?;
    if (type != null && code != null && _isDuplicateRef(type, code)) {
      await _flashExistingRef(type, code);
      return;
    }
    _saveRefs([..._refsKeeping(type, suggestion: suggestion), suggestion]);
    widget.services.track('activity_added', {'activity': type});
    _maybeAdoptGridFromNewRef(distanceKm: suggestion['distance'] as num?);
  }

  /// Non-core extensions that match [input] but are switched off. A lone
  /// trailing colon is dropped first, so a half-typed scope (`sota:` for an
  /// extension that isn't on, and so has no controls to validate against)
  /// still finds it.
  List<ExtensionInfo> _disabledExtensionsMatching(String input) {
    final query = input.trim().replaceFirst(RegExp(r':$'), '').trim();
    if (query.isEmpty) return const [];
    final locale = LocaleSettings.currentLocale.languageCode;
    final extensions = widget.services.extensions;
    return [
      for (final info in extensions.availableExtensions)
        if (!info.core && !extensions.isExtensionEnabled(info) && info.matchesSearch(query, locale: locale)) info,
    ];
  }

  /// Turns an extension on from the search results, then scopes the search
  /// to it — the user went looking for this activity, so its own suggestions
  /// are what they want next, not the text that merely named it. Enabling
  /// restarts the extension runtime, so the controls are reloaded too: the
  /// new type has to appear under "Activity Types" as well, and the scope
  /// prefix only parses once its key is among the loaded ones.
  Future<void> _enableExtension(ExtensionInfo info) async {
    // Enabling restarts the runtime, which takes a moment — a second tap
    // would queue a second restart on top of the first.
    if (_enablingExtension) return;
    _enablingExtension = true;
    setState(() => _loadingSuggestions = true);
    try {
      await widget.services.extensions.setExtensionEnabled(info.key, true);
    } catch (e, st) {
      // A failed restart must not strand the section on its spinner.
      debugPrint('[activities] enabling ${info.key} failed: $e');
      ErrorReportingService.report(e, st, context: 'activities:enable-extension');
      if (mounted) setState(() => _loadingSuggestions = false);
      return;
    } finally {
      _enablingExtension = false;
    }
    if (!mounted) return;
    await _loadControls();
    if (!mounted) return;
    final prefix = ActivitySearchQuery.scopePrefixFor(info.key);
    _searchController.value = TextEditingValue(
      text: prefix,
      selection: TextSelection.collapsed(offset: prefix.length),
    );
    _debounce?.cancel();
    await _search(prefix);
  }

  /// Tapping an activity type scopes the search to it (`pota: `) rather than
  /// prompting for a reference: the extension's own suggestions and search
  /// know its references — including ones it hasn't got data for yet, which
  /// it offers verbatim — so there's nothing a free-text box adds beyond a
  /// second place to typo.
  ///
  /// A form-configured activity (a contest) is the exception: it has no
  /// references at all, so there is nothing to scope a search to. Tapping it
  /// opens its setup form instead.
  void _scopeSearchTo(Map<String, dynamic> control) {
    if ((control['input'] as Map?)?['kind'] == 'form') {
      unawaited(_addFormActivity(control));
      return;
    }
    final activityKey = ((control['key'] as String?) ?? '').split('/').first;
    if (activityKey.isEmpty) return;
    final prefix = ActivitySearchQuery.scopePrefixFor(activityKey);
    _searchController.value = TextEditingValue(
      text: prefix,
      selection: TextSelection.collapsed(offset: prefix.length),
    );
    setState(() {
      // The results live in the scroll area above, so close this section and
      // put the caret in the field ready for the reference or name.
      _allOptionsExpanded = false;
    });
    _searchFocusNode.requestFocus();
    _debounce?.cancel();
    unawaited(_search(prefix));
  }

  /// Adds a form-configured activity by running its setup form. One per
  /// operation: a second CQ WW ref would be meaningless, unlike a second park,
  /// so tapping an already-added contest edits it instead.
  Future<void> _addFormActivity(Map<String, dynamic> control) async {
    final refType = ((control['input'] as Map?) ?? const {})['refType'] as String?;
    if (refType == null) return;

    final existing = _operation.refs.where((r) => r['type'] == refType).firstOrNull;
    if (existing != null) {
      await _editRef(existing);
      return;
    }

    final ref = await _runSetupForm(control);
    if (ref == null) return;
    final decorated = await widget.services.extensions.decorateRef(ref);
    _saveRefs([..._operation.refs, decorated]);
    widget.services.track('activity_added', {'activity': refType});  }

  /// The message shown in the Suggestions & Search section when there are
  /// no results: while there's a search term, a plain "no matches" message
  /// always applies; with an empty term (nearby suggestions) and no
  /// operation grid, the location-driven states kick in
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
    final refListControls = _controls
        .where((c) => (c['input'] as Map?)?['kind'] == 'refList' || (c['input'] as Map?)?['kind'] == 'form')
        .toList();
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

  String _refRowId(String? type, String? code) => '$type/$code';

  /// Points at the ref the user just tried to add again. Rather than telling
  /// them it's a duplicate, we show them: the Current Activities row for it
  /// is scrolled into view and flashes once, which also answers the question
  /// behind the mistake ("is this one already on the list?").
  Future<void> _flashExistingRef(String type, String code) async {
    final id = _refRowId(type, code);
    setState(() {
      _flashingRefRowId = id;
      _flashToken++;
    });
    _flashTimer?.cancel();

    // The row may have only just been built (this can be the first frame it
    // exists on), so wait for it to be laid out before asking the list to
    // bring it into view.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _flashingRefRowId != id) return;
    final rowContext = _refRowKeys[id]?.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
    if (!mounted) return;
    _flashTimer = Timer(_flashDuration, () {
      if (mounted && _flashingRefRowId == id) setState(() => _flashingRefRowId = null);
    });
  }

  /// Tags a Current Activities row so [_flashExistingRef] can find it, and
  /// paints the fading highlight over it while it's the flashing one.
  Widget _flashableRow(Map<String, dynamic> ref, Widget row) {
    final id = _refRowId(ref['type'] as String?, ref['ref'] as String?);
    final rowKey = _refRowKeys.putIfAbsent(id, () => GlobalKey());
    if (id != _flashingRefRowId) return KeyedSubtree(key: rowKey, child: row);
    return KeyedSubtree(
      key: rowKey,
      child: TweenAnimationBuilder<double>(
        // Re-keyed per flash so selecting the same duplicate twice replays
        // the animation instead of sitting at its finished value.
        key: ValueKey(_flashToken),
        tween: Tween(begin: 1, end: 0),
        duration: _flashDuration,
        curve: Curves.easeOut,
        builder: (context, value, child) => Stack(
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35 * value),
                ),
              ),
            ),
          ],
        ),
        child: row,
      ),
    );
  }

  /// Persists [_operation], refreshing `data['title']` from a FRESH
  /// suggestion first — the sheet's own live-preview title (driven by
  /// OperationView's `_draftTitleFragments`) never lands in `_operation`
  /// itself, only in the header's ephemeral preview, so without this an
  /// explicit save could commit a stale generated title for refs edited
  /// just now. Left untouched when the extension runtime isn't up
  /// (suggestFragments returns null) — same "degrade silently" rule as
  /// OperationTitleService's own live retitles, so a host hiccup at save
  /// time doesn't wipe out a previously generated title.
  ///
  /// The save itself must run regardless of `mounted` — this widget can be
  /// disposed while `suggestFragments` is still awaiting the extension host
  /// (up to its own 10s-per-ref timeout), and skipping the write in that case
  /// would silently drop the whole edit (refs, notes, callsign, everything),
  /// not just the title. Uses the module-level `t`, not `context.t`, so the
  /// title can still be assembled after unmount; only the navigation pop is
  /// gated on `mounted`.
  Future<void> saveAndClose() async {
    final fragments = await widget.services.operationTitles.suggestFragments(_operation);
    final data = fragments == null
        ? _operation.data
        : {..._operation.data, 'title': buildGeneratedTitle(t, fragments)};
    await widget.services.operations.saveData(
      Operation(
        uuid: _operation.uuid,
        data: data,
        qsoCount: _operation.qsoCount,
        startAtMillisMin: _operation.startAtMillisMin,
        startAtMillisMax: _operation.startAtMillisMax,
        localData: _operation.localData,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// The operation's own identity — Station/Op callsign chips, the free-text
  /// title, and a notes marker — shown at the far right of the always-visible
  /// header row. Tapping any of it opens the details editor (see
  /// [OperationSheet.onEditDetails]).
  Widget _operationPills(ThemeData theme) {
    final stationCall = _operation.stationCall;
    final operatorCall = _operation.data['operatorCall'] as String?;
    final operationTitle = _operation.userTitle;
    final notes = (_operation.data['notes'] as String?) ?? '';

    // Only the station chip carries the full teal; its companions are the
    // same hue a step lighter, so the station callsign reads first.
    final chipColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final lightChipColor = Color.lerp(chipColor, Colors.white, 0.25)!;
    Widget chip(Widget child, {bool light = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
          decoration: BoxDecoration(
            color: light ? lightChipColor : chipColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            child: child,
          ),
        );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // Opaque: a tap in the gaps between chips still opens the editor
      // rather than falling through to anything behind the pills.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onEditDetails,
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Notes have no useful short form, so this chip only says that
            // there ARE notes — the details are one tap away, in the same
            // operation-details dialog. The icon rides inside a Text so the
            // chip takes its height from the same line box as its
            // text-bearing siblings, rather than from the glyph.
            if (notes.trim().isNotEmpty)
              chip(
                light: true,
                Text.rich(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    // Nudged up 1px: the glyph's own bearing sits it slightly
                    // low against the text line box that
                    // PlaceholderAlignment.middle centers on.
                    child: Transform.translate(
                      offset: const Offset(0, -1),
                      child: Icon(
                        MdiIcons.fileDocument,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            // A title is free text and can run long — it ellipsizes rather
            // than pushing the callsign chips aside (or wrapping the whole
            // row onto extra lines).
            if (operationTitle.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: chip(
                  light: true,
                  Text(operationTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            if (operatorCall != null && operatorCall.isNotEmpty)
              chip(
                light: true,
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Op: '),
                      TextSpan(
                        text: operatorCall,
                        style: const TextStyle(fontFamily: 'RobotoMono'),
                      ),
                    ],
                  ),
                ),
              ),
            chip(
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Station: '),
                    TextSpan(
                      text: stationCall,
                      style: const TextStyle(fontFamily: 'RobotoMono'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    final refs = _operation.refs;
    final isDark = theme.brightness == Brightness.dark;
    // The same color the sheet's top row shows — matching it by hand would
    // drift the moment the pane's own banding changes.
    final accordionColor = haloDialogBandColorAt(context);
    final onAccordionColor = theme.colorScheme.onSurfaceVariant;
    // Rows paint an opaque color so they read distinctly from the pane's
    // gray/dark background (the ColoredBox below), which otherwise shows
    // straight through wherever a filling section has no row to draw. The
    // pane brings this background itself so both Modal Pane presentations
    // (full screen and dialog card) look the same.
    final listBgColor = isDark ? const Color(0xFF141618) : const Color(0xFFF3F4F6);
    final rowColor = isDark ? const Color(0xFF212426) : Colors.white;

    return Material(
      color: listBgColor,
      child: Column(
        children: [
          // The operation's own header row — always visible, no accordion:
          // the activities count and subtitle at left, the operation pills
          // at right. The pills get most of the row (loose 3:1 against the
          // title), and the title's lines ellipsize rather than pushing them
          // aside; leftover space lands between the two (spaceBetween), so
          // the pills stay flush right.
          Material(
            color: accordionColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(right: Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activitiesTitle(
                              refs
                                  .map((r) => r['type'] as String?)
                                  .whereType<String>()
                                  .where((t) => t.isNotEmpty)
                                  .toSet()
                                  .length,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: onAccordionColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: Space.xxs),
                          Text(
                            refs.isEmpty ? context.t.activitiesView.emptySheet : _groupedActivitiesSubtitle(refs),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(flex: 3, child: _operationPills(theme)),
                ],
              ),
            ),
          ),
          // Selected activities, the search field and its results live in
          // ONE clipped scroll area — only Activity Types below keeps the
          // accordion behavior.
          Expanded(
            child: Builder(
              builder: (context) {
                final locStatus = widget.services.location.status;
                final operationGrid = _operation.grid;

                // Every variation is the same filled button: white icon and
                // label on a state color, rather than colored text on nothing.
                const onLocationColor = Colors.white;
                final Widget locationPin;
                final String label;
                final Color locationColor;

                if (operationGrid != null && operationGrid.isNotEmpty) {
                  final gridSource = _operation.data['gridSource'] as String? ?? (
                    (widget.services.location.grid != null && operationGrid == widget.services.location.grid)
                        ? 'gps'
                        : 'manual'
                  );

                  if (gridSource == 'gps') {
                    locationPin = Icon(MdiIcons.mapMarker, color: onLocationColor);
                    label = operationGrid;
                    locationColor = const Color(0xFF1B5E20);
                  } else {
                    locationPin = Icon(MdiIcons.pin, color: onLocationColor);
                    label = operationGrid;
                    locationColor = const Color(0xFF455A64);
                  }
                } else {
                  if (locStatus == LocationStatus.unknown || locStatus == LocationStatus.determining) {
                    locationPin = const _PulsingGpsPin(color: onLocationColor);
                    label = 'GPS…';
                    locationColor = const Color(0xFF1565C0);
                  } else if (locStatus == LocationStatus.available && widget.services.location.grid != null) {
                    locationPin = Icon(MdiIcons.mapMarker, color: onLocationColor);
                    label = widget.services.location.grid!;
                    locationColor = const Color(0xFF1B5E20);
                  } else if (locStatus == LocationStatus.available && widget.services.location.grid == null) {
                    locationPin = const _PulsingGpsPin(color: onLocationColor);
                    label = 'GPS…';
                    locationColor = const Color(0xFF1565C0);
                  } else {
                    locationPin = Icon(MdiIcons.mapMarkerOff, color: onLocationColor);
                    label = '';
                    locationColor = const Color(0xFFC62828);
                  }
                }

                final searchBand = Material(
                  color: accordionColor,
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(_searchBandHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
                          child: Row(
                            children: [
                        Expanded(
                          child: TextField(
                            selectAllOnFocus: false,
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            decoration: InputDecoration(
                              hintText: t.searchHint,
                              prefixIcon: Icon(MdiIcons.magnify, color: onAccordionColor.withValues(alpha: 0.6)),
                              filled: true,
                              // Paler than the band it sits on, so the field
                              // reads as a well rather than blending in.
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: onAccordionColor.withValues(alpha: 0.25)),
                              ),
                              isDense: true,
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: TextButton.icon(
                            icon: locationPin,
                            label: Text(
                              label,
                              style: const TextStyle(
                                fontFamily: 'RobotoMono',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: locationColor,
                              foregroundColor: onLocationColor,
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
                          ),
                        ),
                            ],
                          ),
                        ),
                      ),
                      // The slot is always there, empty when idle: showing
                      // and hiding the bar itself would move every row under
                      // it by its height each time a search resolved.
                      SizedBox(
                        height: _searchProgressHeight,
                        child: _loadingSuggestions
                            ? const LinearProgressIndicator(minHeight: _searchProgressHeight)
                            : null,
                      ),
                    ],
                  ),
                );

                final resultRows = <Widget>[
                  // Above the hits: an activity the user asked for by name
                  // that's simply switched off would otherwise look like it
                  // doesn't exist.
                  for (final info in _disabledMatches)
                    ListTile(
                      tileColor: theme.colorScheme.secondaryContainer,
                      leading: _accentIcon(info.icon, resolveExtensionColor(info.accentColor)),
                      title: Text(
                        t.enableExtension(name: info.nameFor(LocaleSettings.currentLocale.languageCode)),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(t.enableExtensionHint),
                      trailing: const Icon(MdiIcons.plus),
                      onTap: () => _enableExtension(info),
                    ),
                  for (final suggestion in _suggestions)
                    Builder(builder: (context) {
                      final alreadySelected =
                          refs.any((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']);
                      // A nearby suggestion for a ref already on the
                      // operation is just noise, but a SEARCH hit has to
                      // stay: dropping what you searched for reads as
                      // "no such reference". Marked, not hidden.
                      if (alreadySelected && !_suggestionsAreSearchResults) {
                        return const SizedBox.shrink();
                      }
                      final suggestionControl = controlForRefType(_controls, suggestion['type'] as String?);
                      return ListTile(
                        tileColor: _loadingControls
                            ? rowColor
                            : (isUnknownRefType(_controls, suggestion['type'] as String?)
                                ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                : rowColor),
                        leading: _loadingControls
                            ? const Icon(MdiIcons.puzzle)
                            : activityRefIcon(_controls, suggestion['type'] as String?),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                activityRowTitle(suggestionControl, suggestion),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (alreadySelected)
                              Padding(
                                padding: const EdgeInsets.only(left: Space.md),
                                child: _AlreadySelectedChip(label: t.alreadySelected),
                              ),
                            const Spacer(),
                            if (suggestion['distance'] is num)
                              Text(
                                fmtDistance(
                                  (suggestion['distance'] as num).toDouble(),
                                  miles: widget.services.settings.distanceUnits == DistanceUnits.miles,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(activityRowDetail(suggestion) ?? ''),
                        onTap: () => _addSuggestion(suggestion),
                      );
                    }),
                ];

                // One ink layer PER ROW: a ListTile's tileColor/splash ink
                // clips to the nearest Material's bounds, which must be the
                // row itself for rows scrolled out of this viewport to stop
                // painting.
                return CustomScrollView(
                  slivers: [
                    SliverList(
                      delegate: SliverChildListDelegate([
                    for (final ref in refs)
                      Builder(builder: (context) {
                        final control = controlForRefType(_controls, ref['type'] as String?);
                        final detail = activityRowDetail(ref);
                        return Material(
                          type: MaterialType.transparency,
                          child: _flashableRow(
                            ref,
                            ListTile(
                              tileColor: _loadingControls
                                  ? rowColor
                                  : (control == null
                                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                      : rowColor),
                              // Right padding matches the header rows' own
                              // horizontal inset, so this trailing icon button
                              // lines up under the search row's location
                              // button — same IconButton defaults (no custom
                              // size/padding) too.
                              contentPadding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
                              leading: _loadingControls
                                  ? const Icon(MdiIcons.puzzle)
                                  : activityRefIcon(_controls, ref['type'] as String?),
                              title: Text(
                                activityRowTitle(control, ref),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: detail == null ? null : Text(detail),
                              // Tappable only for a type that declares it has
                              // something to edit — a plain ref activity
                              // doesn't, so the row stays inert rather than
                              // offering to retype a code its own search
                              // already resolved.
                              onTap: refTypeIsEditable(control) ? () => _editRef(ref) : null,
                              trailing: IconButton(
                                icon: Icon(MdiIcons.delete, semanticLabel: t.removeActivity),
                                onPressed: () => _deleteRef(ref),
                              ),
                            ),
                          ),
                        );
                      }),
                      ]),
                    ),
                    // The band pins below the sheet's header once the
                    // activity rows above it scroll away; the results keep
                    // scrolling underneath it.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedSearchBand(
                        height: MediaQuery.textScalerOf(context).scale(_searchBandHeight) +
                            _searchProgressHeight,
                        child: searchBand,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        if (resultRows.isEmpty && !_loadingSuggestions)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
                            child: Text(_suggestionsEmptyMessage, style: TextStyle(color: theme.colorScheme.outline)),
                          )
                        else
                          for (final row in resultRows) Material(type: MaterialType.transparency, child: row),
                      ]),
                    ),
                  ],
                );
              },
            ),
          ),
          _AccordionSection(
            title: Padding(
              padding: const EdgeInsets.only(right: Space.xl),
              child: Text(
                _allOptionsTitle(context.t),
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
                  closeLabel: context.t.common.close,
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
              icon: Icon(MdiIcons.puzzle, size: 18, color: onAccordionColor),
              label: Text(
                t.manage,
                style: TextStyle(color: onAccordionColor),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              ),
            ),
            child: () {
              final allOptionsContent = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final control in _controls)
                    if ((control['input'] as Map?)?['kind'] == 'refList' ||
                        (control['input'] as Map?)?['kind'] == 'form')
                      ListTile(
                        tileColor: rowColor,
                        leading: _accentIcon(control['icon'] as String?, resolveExtensionColor(control['color'] as String?)),
                        title: Text((control['label'] as String?) ?? ''),
                        onTap: () => _scopeSearchTo(control),
                      ),
                ],
              );
              return _allOptionsFullyOpened
                  ? allOptionsContent
                  : SizedBox(
                      height: 84.0,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        // Its own ink layer, INSIDE the scroll view, so the
                        // viewport clips it along with the rows. A ListTile
                        // paints `tileColor` with `Ink`, onto the nearest
                        // ancestor Material — without this that's the
                        // sheet's root, above this scroll view, and ink is
                        // clipped to that Material's bounds rather than to
                        // the viewport in between, so
                        // rows scrolled out of this 84px window would still
                        // paint their backgrounds over the sections above.
                        // MaterialType.transparency: an ink layer, no
                        // surface of its own.
                        child: Material(
                          type: MaterialType.transparency,
                          child: allOptionsContent,
                        ),
                      ),
                    );
            }(),
          ),
        ],
      ),
    );
  }
}

/// The search band's pinned-sliver delegate — fixed extent
/// ([_searchBandHeight] + [_searchProgressHeight]), since a
/// SliverPersistentHeader can't size itself to its child.
class _PinnedSearchBand extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _PinnedSearchBand({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  // A pinned sliver whose child paints shorter or taller than the extent it
  // declared throws ("layoutExtent exceeds paintExtent"), so the child is
  // held to exactly that box rather than trusted to match it.
  Widget _sized(Widget child) => SizedBox(height: height, child: child);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => _sized(child);

  // Always true: [child] is rebuilt fresh by the enclosing build, so the
  // comparison would never match anyway — and a false here would leave the
  // stale band on screen, since RenderSliverPersistentHeader only picks up a
  // new delegate when this says so.
  @override
  bool shouldRebuild(_PinnedSearchBand oldDelegate) => true;
}

/// Marks a suggestion the operation already carries. Tapping the row still
/// goes through `_addSuggestion`, which flashes the existing Current
/// Activities row rather than adding a second copy.
class _AlreadySelectedChip extends StatelessWidget {
  final String label;

  const _AlreadySelectedChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}

/// One collapsible section. The tinted header always shows, arrow on the
/// left; the body appears below it only while expanded, using the default
/// (untinted) background. The arrow rotates and the body cross-fades and
/// resizes smoothly.
class _AccordionSection extends StatelessWidget {
  final Widget title;
  final bool expanded;
  final VoidCallback onToggle;
  final Color headerColor;
  final Color onHeaderColor;
  final Widget child;

  /// An optional extra control at the far right of the header, after
  /// [title] (e.g. the Manage extensions button).
  final Widget? trailing;

  const _AccordionSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.headerColor,
    required this.onHeaderColor,
    required this.child,
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
        child: Icon(
          MdiIcons.chevronDown,
          color: onHeaderColor,
          semanticLabel: expanded ? context.t.common.collapse : context.t.common.expand,
        ),
      ),
      onPressed: onToggle,
    );

    final headerRow = Padding(
      // Extra room on the right so the trailing control doesn't sit flush
      // against the pane's edge — the rows below match it, see
      // `contentPadding`.
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.lg, Space.sm),
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
      child: InkWell(onTap: onToggle, child: headerRow),
    );

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
  final Color color;

  const _PulsingGpsPin({this.color = Colors.blue});

  @override
  State<_PulsingGpsPin> createState() => _PulsingGpsPinState();
}

class _PulsingGpsPinState extends State<_PulsingGpsPin> with SingleTickerProviderStateMixin {
  // A repeating controller repaints the scene at the display's refresh rate
  // for as long as the pin is mounted — on the web, where a GPS fix can stay
  // pending indefinitely (unanswered permission prompt), that pegs a CPU
  // core. So the pulse winds down in phases: smooth for a few full cycles,
  // then a brief dim blip every couple of seconds (frames are only drawn
  // during the blip), then a static icon.
  static const _pulsePeriod = Duration(milliseconds: 1000);
  static const _smoothPhase = Duration(seconds: 6); // 3 full out-and-back pulses
  static const _blipInterval = Duration(seconds: 2);
  static const _blipFade = Duration(milliseconds: 250);
  static const _animationCutoff = Duration(seconds: 30);

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _phaseTimer;
  Timer? _blipTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _pulsePeriod,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    final isTest = !kIsWeb && io.Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _controller.repeat(reverse: true);
      _phaseTimer = Timer(_smoothPhase, _startBlipPhase);
    } else {
      _controller.value = 1.0;
    }
  }

  void _startBlipPhase() {
    _controller.stop();
    _controller.animateTo(1.0, duration: _blipFade);
    _blipTimer = Timer.periodic(_blipInterval, (_) => _blip());
    _phaseTimer = Timer(_animationCutoff - _smoothPhase, _settle);
  }

  void _blip() {
    _controller.animateTo(0.35, duration: _blipFade).whenCompleteOrCancel(() {
      if (!mounted || _blipTimer == null) return;
      _controller.animateTo(1.0, duration: _blipFade);
    });
  }

  void _settle() {
    _blipTimer?.cancel();
    _blipTimer = null;
    _controller.stop();
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    // Null (not just cancel) before disposing the controller: disposal
    // cancels an in-flight blip, which fires its whenCompleteOrCancel
    // callback synchronously while mounted is still true — the null check
    // in _blip is what stops it from touching the disposed controller.
    _blipTimer?.cancel();
    _blipTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Icon(MdiIcons.mapMarker, color: widget.color),
    );
  }
}
