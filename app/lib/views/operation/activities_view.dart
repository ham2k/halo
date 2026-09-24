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
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../services/halo_services.dart';
import 'package:halo_extension_host/halo_extension_host.dart';

import '../../services/catalog_service.dart';
import '../../services/error_reporting_service.dart';
import '../../services/location_service.dart';
import '../../services/extension_service.dart';
import '../../services/link_opener.dart';
import '../../services/settings_service.dart';
import 'activities_catalog_tier.dart';
import 'activities_enable_tier.dart';
import 'operation_location_screen.dart';
import '../accordion_section.dart';
import '../operation_dialogs.dart';
import '../extensions_panel.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../../tools/distance_format.dart';
import '../../tools/operation_title.dart';
import '../map/map_zoom_controller.dart';
import 'activities_results_map.dart';

/// An icon, circled in [color] at 60% opacity when the control declares an
/// accent — sparingly used, so a control with no color just
/// renders the bare icon.
Widget _accentIcon(String? iconName, Color? color) {
  final icon = Icon(resolveIconName(iconName));
  if (color == null) return icon;
  return CircleAvatar(backgroundColor: color.withValues(alpha: 0.6), child: icon);
}

/// The operation pills' own geometry — shared by the rows that lay them out and
/// by the width arithmetic that decides how many pills there are, which only
/// agrees with the layout while these are the same numbers.
const _pillSpacing = 8.0;
const _pillRunSpacing = 4.0;
const _pillPadding = Space.md;
const _pillIconSize = 16.0;

/// The narrowest an icon-only pill gets (pills carrying a value take exactly
/// the width their value needs).
const _pillMinWidth = 40.0;

/// A free-text operation title ellipsizes here rather than pushing the
/// callsign pills aside — room for a couple of words, no more: the whole title
/// is one tap away in the details editor.
const _titlePillMaxWidth = 140.0;

/// One operation pill, with the width it will take once laid out and how
/// eagerly it is dropped when the group would otherwise run past
/// [_maxPillLines]: the lowest non-zero [dropOrder] goes first, and 0 never
/// goes.
class _HeaderPill {
  final Widget widget;
  final double width;
  final int dropOrder;

  /// Whether this pill gives up the difference when its run is laid out in
  /// less width than it needs — `Flexible`, so the run never overflows. Only
  /// the identity run can be in that position (its pills never shed), and only
  /// its station pill carries this.
  final bool absorbsShortfall;

  const _HeaderPill(this.widget, this.width, {this.dropOrder = 0, this.absorbsShortfall = false});
}

/// What the header row keeps for its "N Activities Selected" title and
/// subtitle before the operation pills are allowed to wrap: enough for the
/// title at its usual length, plus the [Space.xl] gutter it holds against the
/// pills. Wide enough to matter, narrow enough that the pills stay on one
/// line in every layout they fit.
const _headerTitleMinWidth = 200.0;

// Close enough that the operation's grid and the caller's live GPS grid
// would round to the same (or an adjacent) square anyway, so adopting it
// isn't a meaningful accuracy loss.
const _nearbyGridAdoptionKm = 15;

/// Height of the search section's progress bar — reserved whether or not a
/// search is running, so the results below never shift. Matches
/// LinearProgressIndicator's own default thickness.
const _searchProgressHeight = 4.0;

/// The map pin drawn inline in the "no location" hint, sized to match the
/// search band's own pin so the two read as the same object. The band's comes
/// from M3's button-icon default, which this tracks by hand: a `WidgetSpan`
/// inside a `Text` has no button style to inherit it from.
const _locationPinSize = 18.0;

/// Height of the search-field band (excluding the progress slot) at text
/// scale 1. A constant because the band rides in a pinned
/// SliverPersistentHeader, which needs an explicit extent it cannot measure:
/// 8px padding + a 44px dense field/button row + 8px. The OS text-scale
/// preference composes on top of the app's own Font Scale (ui-scaling.md
/// rule 3) and grows the field inside it, so callers scale this — see
/// [_PinnedSearchBand].
const _searchBandHeight = 60.0;

/// Material's single-line ListTile: a plain Activity Types row.
const _optionRowHeight = 56.0;

/// A two-line ListTile — an enable-extension row (title + hint), and the
/// result rows, which carry a detail line.
const _twoLineRowHeight = 72.0;

/// A row and a half, the height a peeking list is cut to. Half a row is the
/// point: a list cut mid-row reads as scrollable, where a whole number of
/// rows reads as the whole list.
const _peekRows = 1.5;

/// The collapsed Activity Types section's default height.
const _optionsPeekHeight = _optionRowHeight * _peekRows;

/// What the results list keeps for itself no matter how far Activity Types
/// grows — see [OperationSheetState._optionsPeekHeightFor].
const _resultsMinPeekHeight = _twoLineRowHeight * _peekRows;

/// The map presentation's own cap on "Current Activities": tall enough to
/// read as more than a sliver, bounded so the map — the reason the operator
/// switched views — still gets most of the height. Internally scrollable
/// past this, same as the list presentation's own peeking sections.
const _currentActivitiesMapMaxHeight = _twoLineRowHeight * 2.5;

/// The accordion header's own height: an IconButton (48, Material's minimum
/// tap target) inside [AccordionSection]'s `Space.sm` vertical padding.
/// Deliberately a fixed allowance rather than a measurement — it is only
/// ever subtracted, so erring high costs the peek a few pixels and erring
/// low would eat the results area it is there to protect.
const _accordionHeaderHeight = 48.0 + Space.sm * 2;

/// Decides which location (if any) an operation should adopt right after a new
/// activity ref is added, given it has no resolved location of its own:
///  - if live GPS is available, adopt it — but only when the just-added ref
///    is within [_nearbyGridAdoptionKm] of it (a far-away ref added while
///    away from the shack shouldn't imply "this is where I am").
///  - otherwise (no GPS fix), adopt the first ref's own location, if it has
///    one — the most that can be inferred without a location source at all.
///
/// Returns a coordinate as well as the locator, since that pair is what the
/// operation stores: the source's own where it knew one (a fix always does; a
/// ref does when its table publishes coordinates), otherwise the square's own
/// center, exactly as a hand-stated grid is written (docs/design/locations.md).
/// `grid` is always the locator for `location`, so they can't disagree.
///
/// A pure function (no Flutter/service dependencies) so this decision is
/// unit-testable without exercising the whole ActivitiesView widget tree.
({String grid, GridLocation location, String source})? locationToAdoptAfterAddingRef({
  required GridLocation? operationLocation,
  required GridLocation? gpsPosition,
  required num? distanceKm,
  required List<Map<String, dynamic>> refsAfterAdd,
}) {
  if (operationLocation != null) return null;

  if (gpsPosition != null) {
    if (distanceKm == null || distanceKm > _nearbyGridAdoptionKm) return null;
    return (grid: gridForLocation(gpsPosition.latitude, gpsPosition.longitude), location: gpsPosition, source: 'gps');
  }

  if (refsAfterAdd.isEmpty) return null;
  final first = refsAfterAdd.first;
  final grid = gridForDisplay(lat: first['lat'], lon: first['lon'], grid: first['grid'] as String?);
  final location = locationFromLatLon(first['lat'], first['lon']) ?? locationForStatedGrid(grid);
  if (grid == null || location == null) return null;
  return (grid: grid, location: location, source: 'manual');
}

/// Whether an operation may carry more than one ref of [type] at a time, as
/// the extension declared it: on the [suggestion] being added, or — for a
/// ref typed in by hand, which has no suggestion — on the type's [control]
/// descriptor. Defaults to FALSE: one reference of a kind is the safe
/// assumption, and a type that genuinely stacks (POTA n-fers) says so
/// explicitly. Anything else gets the replace-on-add behavior of
/// [refsKeptWhenAdding].
bool allowsMultipleRefsOfType(String? type, {Map<String, dynamic>? suggestion, Map<String, dynamic>? control}) {
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

/// Where tapping a Current Activities row should point the results map, or
/// null for a row that must stay inert.
///
/// Null with the list showing: there is no camera to move, and a row that
/// silently did nothing in one mode and something in the other would read as
/// broken in whichever the operator met first. Null too for a reference with
/// no resolvable location — a program whose codes carry no coordinate has
/// nowhere to point at, and no marker on the map either.
///
/// The editor takes precedence over this at the call site (see
/// `_moveMapToRef`'s caller): a form-configured reference has nothing else
/// that opens its form.
GridLocation? refRowMapTarget(Map<String, dynamic> ref, {required bool mapShowing}) {
  if (!mapShowing) return null;
  return locationForSuggestion(ref);
}

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
  final detail = [entry['name'], entry['location']].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
  return detail.isEmpty ? null : detail;
}

/// Whether an already-added suggestion should be hidden rather than shown
/// (faded) — the one rule both the results list (`resultRows`, below) and the
/// results map (`activitySuggestionMarkers`, activities_results_map.dart)
/// apply to the same `_suggestions`/`refs` inputs, kept in one place so they
/// can't quietly disagree. A nearby suggestion already on the operation is
/// just noise; a SEARCH hit has to stay — dropping what the operator
/// searched for reads as "no such reference".
bool suggestionHidesAsAlreadyAdded({required bool alreadyAdded, required bool suggestionsAreSearchResults}) => alreadyAdded && !suggestionsAreSearchResults;

/// The refs to keep when adding one of [type]: all of them when the type
/// allows multiple, and otherwise everything BUT that type — a single-ref
/// type's new reference replaces the one already there rather than piling up
/// next to it.
List<Map<String, dynamic>> refsKeptWhenAdding({required List<Map<String, dynamic>> refs, required String? type, required bool allowsMultiple}) {
  if (type == null || allowsMultiple) return refs;
  return refs.where((r) => r['type'] != type).toList();
}

/// The word the search box scopes a reference type by: the type's base name,
/// lowercased — `potaActivation` and `pota` are both `pota`.
///
/// A ref TYPE, not the extension's key, on purpose: a user-published
/// extension is keyed by its author's callsign (`ki2d-pota`), and the
/// operator adding parks from it is still adding POTA parks. The scope names
/// what is being searched for, and two extensions serving the same type
/// share it.
///
/// `<base>Activation` / `<base>` is the convention every activity's pair of
/// ref types follows (see `activityRefTypes`), which is what makes the base
/// name derivable at all.
String activityScopeWord(String refType) => refType.replaceFirst(RegExp(r'Activation$'), '').toLowerCase();

/// A search box entry split into an optional scope and the text after it:
/// `pota:` scopes to POTA's own suggestions, `pota: bear mtn` scopes AND
/// searches, `pota bear mtn` merely gives POTA precedence, and plain `bear
/// mtn` searches everything evenly. The scope is what the "Activity Types"
/// rows insert when tapped, and is a ref type's [activityScopeWord] rather
/// than an extension key — see there for why.
class ActivitySearchQuery {
  /// The activity hook keys to ask — every extension serving the scoped ref
  /// type — or null for "every activity hook".
  final List<String>? activityKeys;

  /// The extensions whose suggestions rank ahead of every other one's, or
  /// null when no leading word was typed. Never set together with
  /// [activityKeys] — preferring is the soft form of scoping, for when the
  /// word came without a colon and the rest of the box may still be meant for
  /// someone else.
  final List<String>? preferredKeys;

  /// What [activityKeys] / [preferredKeys] search for — empty means "just
  /// show me this scope's nearby suggestions".
  final String term;

  /// What every OTHER hook searches for: the raw input, leading key word and
  /// all. Only the named extension gets its own key stripped — handing the
  /// leftover text to the rest would bury `sota bear` under every park named
  /// Bear, and precedence is supposed to narrow the list, not widen it.
  /// Equals [term] whenever [preferredKeys] is null.
  final String otherTerm;

  const ActivitySearchQuery({this.activityKeys, this.preferredKeys, required this.term, required this.otherTerm});

  static final _scopePattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*):(.*)$', dotAll: true);
  static final _leadingWordPattern = RegExp(r'^([a-zA-Z][a-zA-Z0-9_-]*)(?:\s+(.*))?$', dotAll: true);

  /// A leading scope word, with or without its colon, only counts when
  /// [scopes] actually has it — references and park names carry colons and
  /// lead with words too (`US-0001: Something`, `bear mountain`), and treating
  /// one as a scope would quietly search the wrong extension, or none, while
  /// looking like it worked. [scopes] maps each word to the activity hook
  /// keys that serve it, which is what the query carries: the word is the
  /// operator's, the keys are the runtime's.
  factory ActivitySearchQuery.parse(String input, Map<String, List<String>> scopes) {
    final trimmed = input.trim();

    final scope = _scopePattern.firstMatch(trimmed);
    final scopeKeys = scopes[scope?.group(1)?.toLowerCase()];
    if (scopeKeys != null) {
      final term = (scope!.group(2) ?? '').trim();
      return ActivitySearchQuery(activityKeys: scopeKeys, term: term, otherTerm: term);
    }

    final word = _leadingWordPattern.firstMatch(trimmed);
    final wordKeys = scopes[word?.group(1)?.toLowerCase()];
    if (wordKeys != null) {
      final rest = (word!.group(2) ?? '').trim();
      // A word on its own scopes exactly like `word:` does: there is nothing
      // else in the box that the other extensions could be answering.
      if (rest.isEmpty) return ActivitySearchQuery(activityKeys: wordKeys, term: '', otherTerm: '');
      return ActivitySearchQuery(preferredKeys: wordKeys, term: rest, otherTerm: trimmed);
    }

    return ActivitySearchQuery(term: trimmed, otherTerm: trimmed);
  }

  /// The text the search field holds for a bare scope — what tapping an
  /// "Activity Types" row types for the user.
  static String scopePrefixFor(String scopeWord) => '$scopeWord: ';
}

/// What's in [typed] past a leading [key], or empty when it doesn't lead with
/// that key at all — an extension matched by its name or a keyword leaves
/// nothing worth carrying into its scope.
String searchTextAfterKey(String typed, String key) {
  final trimmed = typed.trim();
  final firstWord = trimmed.split(RegExp(r'\s')).first;
  if (firstWord.replaceFirst(RegExp(r':$'), '').toLowerCase() != key.toLowerCase()) return '';
  return trimmed.substring(firstWord.length).trim();
}

/// The operation sheet's body: the activities list and search, plus the
/// operation's own controls. Driven through its [OperationSheetState] by the
/// screen that presents it (saving, and pushing draft edits back in).
class OperationSheet extends StatefulWidget {
  final HaLoServices services;
  final Operation operation;
  final ValueChanged<Operation>? onOperationChanged;

  /// Opens the operation-details editor (callsign, title, notes) — owned by
  /// the presenting screen, which routes the result back in through
  /// [OperationSheetState.updateOperation].
  final VoidCallback? onEditDetails;

  const OperationSheet({super.key, required this.services, required this.operation, this.onOperationChanged, this.onEditDetails});

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
      _researchIfLocationChanged(before, op);
    }
  }

  List<Map<String, dynamic>> _controls = const [];
  ControlsLoadState _controlsState = ControlsLoadState.loading;

  /// Where each of the operation's refs can be read about on the web, keyed by
  /// [_refLinkKey]. Resolved for display only — a link is never written onto
  /// the ref, so it follows the extension rather than the saved operation.
  Map<String, RefLink> _refLinks = const {};
  int _refLinksRequest = 0;

  /// The same for the current search results and nearby suggestions, kept
  /// apart from [_refLinks] because the two lists change on their own
  /// schedules and a shared map would have each clobber the other's answers.
  Map<String, RefLink> _suggestionLinks = const {};
  int _suggestionLinksRequest = 0;

  /// Whether the descriptors are good enough to judge a ref type by. Both
  /// non-loaded states say no: an absent control means "not loaded yet" or
  /// "the hook could not answer", and rendering either as the unknown-type
  /// treatment tells the operator an installed extension isn't there.
  bool get _controlsUnreliable => _controlsState != ControlsLoadState.loaded;
  int _controlsRequest = 0;

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  /// Flips only when [_searchController]'s text crosses empty/non-empty —
  /// not on every keystroke once it's non-empty, and not on a caret move at
  /// all — so the clear button's AnimatedBuilder rebuilds the search field
  /// only when whether the button shows actually changes, not on every
  /// notification the controller fires.
  late final ValueNotifier<bool> _searchIsEmpty;
  void _onSearchControllerChanged() {
    final isEmpty = _searchController.text.isEmpty;
    if (isEmpty != _searchIsEmpty.value) _searchIsEmpty.value = isEmpty;
  }

  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];
  bool _loadingSuggestions = true;
  // Guards against a slower, earlier-fired search resolving after a faster,
  // more recent one and clobbering its results — only the response whose
  // id still matches the latest request gets applied.
  int _searchRequestId = 0;

  /// Extensions that match what was typed but aren't running — offered as
  /// rows of the Activity Types section (see activities_enable_tier.dart),
  /// since an activity searched for looking like it simply doesn't exist is
  /// worse than one extra row. Empty unless the box has text in it.
  List<ExtensionInfo> _disabledMatches = const [];

  /// The catalog tier's own state — the listing, the one fetch that gets it,
  /// and what it matches. The search's third tier, below enabled and
  /// installed-but-off: it closes the case of an activity the operator
  /// searched for looking like it does not exist.
  final CatalogTier _catalogTier = CatalogTier();

  /// Extensions that aren't running and declare a ref type the operation
  /// carries but no loaded control handles — the remedy for a red "unknown"
  /// row in Current Activities, offered as the same rows. An
  /// extension the search already offers is left to [_disabledMatches], so
  /// it never shows twice.
  ///
  /// Refreshed by [_refreshUnhandledRefMatches] wherever its inputs change,
  /// not derived on read: the sheet body's LayoutBuilder re-runs on every
  /// constraint change (a keyboard sliding in, a window resize), and this
  /// walks the refs, the descriptors and the whole catalog.
  List<ExtensionInfo> _unhandledRefMatches = const [];

  /// The extensions an unhandled ref has already opened the Activity Types
  /// section for. The section opens itself when a NEW one appears, and only
  /// then: the descriptors reload on every ref change, and an operator who
  /// saw the offer, declined it and collapsed the section must not have it
  /// reopen under their hand each time they add or remove an activity.
  final Set<String> _unhandledRefKeysOffered = {};

  /// Recomputes [_unhandledRefMatches] — inside the setState that changed
  /// the refs, the descriptors or [_disabledMatches] — and opens the section
  /// for any extension offered for the first time. Same reasoning as the
  /// search's enable rows (see `_search`): a collapsed section shows nothing,
  /// leaving a red row above with its remedy hidden. Not persisted.
  void _refreshUnhandledRefMatches() {
    final unhandledRefs = _unhandledRefs();
    // Nothing installed answers these; the catalog may. Asked only when there
    // is a reference to ask about, so an operation whose activities all load
    // reaches the catalog no more than an empty search box does.
    if (unhandledRefs.isNotEmpty) _ensureCatalogFetched();
    _catalogTier.refMatches = _catalogTier.matchingRefs(widget.services, unhandledRefs, alreadyOffered: {for (final entry in _catalogTier.matches) entry.key});
    final unhandled = notRunningExtensionsForRefs(widget.services.extensions, unhandledRefs);
    // Recorded BEFORE the search's matches are subtracted: an extension the
    // box happens to name right now is still one the operator has seen
    // offered, and forgetting it would reopen the section as soon as the box
    // clears and a later reload finds it "new".
    final keys = {for (final info in unhandled) info.key};
    if (!_unhandledRefKeysOffered.containsAll(keys)) _allOptionsExpanded = true;
    _unhandledRefKeysOffered.addAll(keys);
    final offeredBySearch = {for (final info in _disabledMatches) info.key};
    _unhandledRefMatches = [
      for (final info in unhandled)
        if (!offeredBySearch.contains(info.key)) info,
    ];
  }

  /// The operation's references no loaded control handles. Empty while the
  /// descriptors are unreliable — an absent control then means "not loaded
  /// yet", not "no extension has it".
  List<({String type, String? code})> _unhandledRefs() => _controlsUnreliable ? const [] : unhandledRefsIn(_operation.refs, _controls);

  /// Guards against a second tap while an enable-and-restart is in flight.
  bool _enablingExtension = false;

  /// Whether [_suggestions] came from a typed search rather than the nearby
  /// list. Refs the operation already has are dropped from nearby suggestions
  /// (they're proposals — proposing what you already have is noise), but kept
  /// in search results: searching for something by name and getting nothing
  /// back reads as "not found", which is worse than a marked-up hit.
  bool _suggestionsAreSearchResults = false;

  /// Whether the last search came back with every source broken rather than
  /// merely empty-handed. The two are the same empty list, and only one of
  /// them is worth an apology.
  bool _searchFailed = false;

  static const _flashDuration = Duration(milliseconds: 900);

  /// The Current Activities row currently flashing (see [_flashExistingRef]),
  /// as `type/ref`; null when nothing is. [_flashToken] only exists to make
  /// each flash a distinct animation.
  String? _flashingRefRowId;
  int _flashToken = 0;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _refRowKeys = {};

  /// Whether the results/suggestions area shows the map toggle's map instead
  /// of the ordinary list — ephemeral per sheet open, not a persisted
  /// preference like [_allOptionsExpanded].
  bool _showResultsMap = false;

  /// The results map's camera, so a Current Activities row can point it at
  /// its own reference. Lives here rather than inside the map because the
  /// rows are this widget's, not the map's; whichever backend the platform
  /// picks wires itself into it when it mounts, and nothing is wired at all
  /// while the list is showing — which is why [_moveMapToRef] is null then.
  final MapZoomController _resultsCamera = MapZoomController();

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
    _searchIsEmpty = ValueNotifier(_searchController.text.isEmpty);
    _searchController.addListener(_onSearchControllerChanged);

    final hidden = widget.services.settings.prefs.getBool('activitiesAllOptionsHidden') ?? false;
    _allOptionsExpanded = !hidden;
    _allOptionsFullyOpened = false;

    _watchingLocation = true;
    widget.services.location.start();
    widget.services.location.addListener(_onLocationChanged);
    widget.services.dataRevision.addListener(_onDataFilesChanged);
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _flashTimer?.cancel();
    _searchController.removeListener(_onSearchControllerChanged);
    widget.services.dataRevision.removeListener(_onDataFilesChanged);
    _searchIsEmpty.dispose();
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

  // Re-runs the current search once new data files land. Enabling an
  // extension here restarts the runtime and searches straight away, while
  // its data-file sync runs on after the restart: without this, a freshly
  // enabled extension answers from data it has not downloaded yet and the
  // results stay that way until the operator types again. Debounced like
  // location. Held while an extension is being gained: that flow restarts the
  // runtime before its controls reload, and a search run in between asks the
  // old scopes and drops the spinner mid-install — so the tick waits for the
  // gain to finish rather than being lost.
  void _onDataFilesChanged() {
    if (!mounted) return;
    if (_enablingExtension) {
      _dataChangedWhileGaining = true;
      return;
    }
    _onSearchChanged(_searchController.text);
  }

  bool _dataChangedWhileGaining = false;

  Future<void> _loadControls() async {
    // Refs change faster than the host answers — adding two activities in a row
    // leaves two lookups in flight, and the slower one must not install the
    // descriptors for the earlier state.
    final request = ++_controlsRequest;
    ControlsResult result;
    try {
      // A runtime still booting has no host, which `_collectControls` reports
      // as a failure — correctly, but the sheet can open inside that window
      // (the onboarding auto-open fires on a ~300ms transition) and "could not
      // load" is a lie about a runtime that is merely starting. Idempotent, so
      // every call after the first costs nothing.
      await widget.services.extensions.start();
      if (!mounted) return;
      result = await widget.services.extensions.operationControls(_operation.data);
    } on ExtensionHostException catch (e) {
      // An extension misbehaving: logged, never uploaded. A report the
      // maintainer cannot act on is noise (docs/design/error-reporting.md).
      debugPrint('[extensions] operationControls failed: $e');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    } catch (e, stack) {
      // Anything else reaching here is OUR bug, not an extension's, and a
      // bare catch would bury it for good. Uploaded without a notice: the
      // failed state below is what the operator needs to see.
      //
      // The state machine has to terminate on every path either way. Without
      // it the sheet sits on `loading` forever — the placeholder has no
      // terminal state of its own, and `_controlsUnreliable` suppresses the
      // very treatment that would show something is wrong.
      ErrorReportingService.report(e, stack, context: 'activities:operationControls');
      result = (controls: const <Map<String, dynamic>>[], loadFailed: true);
    }
    if (mounted && request == _controlsRequest) {
      setState(() {
        _controls = result.controls;
        _controlsState = result.loadFailed ? ControlsLoadState.failed : ControlsLoadState.loaded;
        _refreshUnhandledRefMatches();
      });
      // Links come from the same runtime the descriptors do, so they are
      // reloaded together rather than on triggers of their own. Enabling an
      // extension from Manage Extensions, retrying failed controls and a
      // restart after a failed boot all reload the descriptors — and each
      // one can change what `linkForRef` answers, for refs that never
      // changed.
      unawaited(_loadRefLinks());
    }
  }

  /// A reference row's title line, in both lists.
  ///
  /// A reference is an identifier — half of one is not a shorter version of
  /// it, it is the wrong reference — so this shrinks rather than truncates,
  /// trying Roboto's condensed width before giving up any point size.
  /// [shrinkToFitText] reserves condensing for secondary lines; the trade is
  /// deliberately different here, where the line is a code rather than prose.
  /// Its 75% floor still stands: below that a code stops being readable, and
  /// an ellipsis is the better failure.
  Widget _activityRowTitleText(String title) => shrinkToFitText(Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), condensed: true);

  /// A search result's distance and its web button, or `null` when it has
  /// neither — an empty `Row` would still claim the tile's trailing slot and
  /// pull the title in from the edge.
  Widget? _suggestionTrailing(ThemeData theme, Map<String, dynamic> suggestion, {required RefLink? link, required Map<String, dynamic>? control}) {
    final distance = suggestion['distance'];
    if (distance is! num && link == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (distance is num)
          Text(
            fmtDistance(distance.toDouble(), miles: widget.services.settings.distanceUnits == DistanceUnits.miles),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (link != null) ...[const SizedBox(width: Space.md), _refLinkButton(link, fallbackName: activityRowTitle(control, suggestion))],
      ],
    );
  }

  /// The web button both lists end with. [fallbackName] names the row for
  /// assistive technology when the extension offered no name of its own.
  Widget _refLinkButton(RefLink link, {required String fallbackName}) {
    return IconButton(
      icon: Icon(MdiIcons.web, semanticLabel: context.t.activitiesView.openReferenceLink(name: link.label ?? fallbackName)),
      onPressed: () => openExternalUrl(link.url),
    );
  }

  /// The key a ref's link is cached under. Null for a ref with nothing to ask
  /// about — an activity the operator has added but not yet filled in.
  String? _refLinkKey(Map<String, dynamic> ref) {
    final type = ref['type'] as String?;
    final reference = ref['ref'] as String?;
    if (type == null || reference == null || reference.isEmpty) return null;
    return '$type:$reference';
  }

  /// Resolves one link per ref, in parallel — a list shouldn't pay the SUM of
  /// each hook's latency when the MAX is all that's needed, the same trade-off
  /// [OperationTitleService] makes.
  ///
  /// The hooks build a URL from the reference and nothing else (no network —
  /// `docs/extensions/hooks.md`), which is what makes it affordable to ask
  /// again for a whole list of search results on every keystroke's search.
  Future<Map<String, RefLink>> _resolveRefLinks(List<Map<String, dynamic>> refs) async {
    // The sheet can open while the runtime is still booting — without this the
    // cold-boot case resolves every link against a null host. Idempotent, so
    // every call after the first costs nothing.
    await widget.services.extensions.start();
    final keyed = <String, Map<String, dynamic>>{};
    for (final ref in refs) {
      final key = _refLinkKey(ref);
      if (key != null) keyed.putIfAbsent(key, () => ref);
    }
    final resolved = await Future.wait(
      keyed.entries.map((entry) async {
        try {
          return MapEntry(entry.key, await widget.services.extensions.linkForRef(entry.value));
        } catch (e, stack) {
          // Caught PER ENTRY, because `Future.wait` completes with the first
          // error and discards every value the others already resolved — one
          // malformed ref would otherwise cost the whole list its links, and
          // (nothing else catching it) spend the session's one "something went
          // wrong" notice on a missing icon.
          //
          // An extension's own failure never reaches here — `linkForRef`
          // swallows those — so what does is OUR bug, and is reported the way
          // `_loadControls` reports its own: uploaded, with no notice, because
          // the row showing no button is all the operator can act on.
          ErrorReportingService.report(e, stack, context: 'activities:linkForRef');
          return MapEntry(entry.key, null);
        }
      }),
    );
    return {
      for (final entry in resolved)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  /// Rebuilt from scratch on every reload rather than accumulated: a ref the
  /// operator removed must take its link with it, and so must one whose
  /// extension has just been switched off.
  Future<void> _loadRefLinks() async {
    final request = ++_refLinksRequest;
    final links = await _resolveRefLinks(_operation.refs);
    if (!mounted || request != _refLinksRequest) return;
    setState(() => _refLinks = links);
  }

  /// The suggestions list is replaced wholesale by each search, so its links
  /// are too — and the request counter is what keeps a slow search from
  /// installing links for results the operator has already typed past.
  Future<void> _loadSuggestionLinks() async {
    final request = ++_suggestionLinksRequest;
    final links = await _resolveRefLinks(_suggestions);
    if (!mounted || request != _suggestionLinksRequest) return;
    setState(() => _suggestionLinks = links);
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

  /// Re-runs the search when the operation's LOCATION changes, from wherever
  /// `_operation` was replaced.
  ///
  /// Nearby suggestions are computed from the grid
  /// ([ExtensionService.suggestActivities]), which outranks the device's own
  /// position — so a location the operator just typed has to produce results
  /// now, not on their next keystroke. The device's GPS has
  /// [_onLocationChanged] to lean on; a hand-typed grid has nothing, and in
  /// the states where the operator is invited to type one there is no fix
  /// coming to fire that listener.
  ///
  /// State and county count too. They are not part of `suggestActivities`'
  /// own `location` argument, but the whole operation map goes to the hooks,
  /// and a program whose references are administrative rather than geographic
  /// answers off exactly those — and the location editor returns all three
  /// together, so filling in only State is an ordinary thing to do.
  ///
  /// Guarded on a real change: every ref added re-enters here. Unset and blank
  /// are the same location — the editor returns `''` for a field never filled
  /// in, so comparing raw would make an unchanged Save pay for a fan-out.
  void _researchIfLocationChanged(Operation before, Operation after) {
    // `lat`/`lon` alongside the grid: adopting a ref's own coordinate moves
    // the search's centre by up to a few kilometres without the grid changing
    // at all, and a nearby search run from the wrong one of those two points
    // is exactly what this whole path exists to prevent.
    const keys = ['grid', 'lat', 'lon', 'state', 'county'];
    if (keys.every((key) => (before.data[key] ?? '') == (after.data[key] ?? ''))) return;
    _debounce?.cancel();
    unawaited(_search(_searchController.text));
  }

  bool _isInvalidRef(Map<String, dynamic> entry) => activityRowIsInvalid(_controls, entry);

  bool _isDuplicateRef(String type, String code) => _operation.refs.any((ref) => ref['type'] == type && ref['ref'] == code);

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
      // The other path that replaces `_operation` — adopting a grid off a
      // newly added ref comes through here, not through [updateOperation].
      _researchIfLocationChanged(before, updated);
    }
  }

  void _saveRefs(List<Map<String, dynamic>> refs) => _saveOperationData({'refs': refs});

  /// Opportunistically fills in the operation's own (still-unset) location
  /// right after a new activity ref is added — from live GPS if that ref is
  /// close by, or otherwise from the first ref's own position once GPS isn't
  /// available — so features that need a location (nearby suggestions, the
  /// Map tab) work without the user having to set one by hand via
  /// OperationLocationScreen. The coordinate is stored with the locator
  /// wherever the source knew one; see [locationToAdoptAfterAddingRef].
  void _maybeAdoptLocationFromNewRef({num? distanceKm}) {
    final adopted = locationToAdoptAfterAddingRef(
      operationLocation: _operation.location,
      gpsPosition: widget.services.location.location,
      distanceKm: distanceKm,
      refsAfterAdd: _operation.refs,
    );
    if (adopted != null) {
      _saveOperationData({
        'grid': adopted.grid,
        'gridSource': adopted.source,
        // Written unconditionally: the pair belongs to the grid beside it, and
        // a stale one from whatever set the location before would outrank both.
        'lat': adopted.location.latitude,
        'lon': adopted.location.longitude,
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
  Future<Map<String, dynamic>?> _runSetupForm(Map<String, dynamic> control, {Map<String, dynamic>? existing}) async {
    final input = (control['input'] as Map?) ?? const {};
    final refType = input['refType'] as String?;
    final form = (input['form'] as Map?)?.cast<String, dynamic>();
    if (refType == null || form == null) return null;

    // Seed from the ref itself: every field key is a key on the ref.
    final initialState = <String, dynamic>{
      for (final entry in (existing ?? const <String, dynamic>{}).entries)
        if (entry.key != 'type') entry.key: entry.value,
    };

    final result = await showFormDialog(context, formDefinition: form, initialState: initialState, developerMode: widget.services.settings.developerMode);
    if (result == null || !mounted) return null;

    return refWithFormResult(existing, result, refType: refType);
  }

  /// Only reachable for a ref type that declares `editable` (see
  /// [refTypeIsEditable]).
  Future<void> _editRef(Map<String, dynamic> ref) async {
    final t = context.t.activitiesView;

    // A form-configured activity (a contest) edits through its own setup form
    // rather than the single reference-code field below — it has no code.
    final formControl = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
    if ((formControl?['input'] as Map?)?['kind'] == 'form') {
      final updated = await _runSetupForm(formControl!, existing: ref);
      if (updated == null || !mounted) return;
      final decorated = await widget.services.extensions.decorateRef(updated);
      if (!mounted) return;
      // Read the refs AFTER every await, never across one — see
      // [_configureNewRef], which reaches the same place by the other path.
      // The dialog is gone while `decorateRef` runs to its hook timeout, so a
      // list captured earlier silently undoes whatever the operator did in
      // between.
      final refs = _operation.refs;
      final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
      if (index < 0) return;
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
      unawaited(_loadSuggestionLinks());
    }
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    unawaited(_search(''));
    _searchFocusNode.requestFocus();
  }

  /// The scope words the loaded controls answer to, each mapped to the
  /// activity hook keys serving it (the control key's namespace,
  /// `ki2d-pota/activation` -> `ki2d-pota`) — what a leading word in the
  /// search box is checked against, and what tapping a row inserts. Two
  /// extensions serving one ref type share the word and are BOTH asked: the
  /// operator scoped to parks, not to one supplier of them.
  ///
  /// Form controls count too: a contest lists no references, but its
  /// `suggest` still answers a scope (`cwt: 1300` narrows the sessions), so
  /// dropping it here would leave that hook's `scoped` branch unreachable.
  Map<String, List<String>> get _activityScopes {
    final scopes = <String, List<String>>{};
    for (final control in _controls) {
      final word = _scopeWordOf(control);
      final hookKey = ((control['key'] as String?) ?? '').split('/').first;
      if (word == null || hookKey.isEmpty) continue;
      final keys = scopes.putIfAbsent(word, () => []);
      if (!keys.contains(hookKey)) keys.add(hookKey);
    }
    return scopes;
  }

  /// [control]'s scope word, or null for a control declaring no ref type —
  /// which every activity control is required to (docs/extensions/hooks.md),
  /// so null is a malformed descriptor, not a kind of control.
  static String? _scopeWordOf(Map<String, dynamic> control) {
    final refType = (control['input'] as Map?)?['refType'];
    if (refType is! String || refType.isEmpty) return null;
    final word = activityScopeWord(refType);
    return word.isEmpty ? null : word;
  }

  Future<void> _search(String term) async {
    final requestId = ++_searchRequestId;
    setState(() => _loadingSuggestions = true);
    final query = ActivitySearchQuery.parse(term, _activityScopes);
    final trimmed = query.term;
    final location = widget.services.location;
    final fallbackPosition = location.position;
    final results = await widget.services.extensions.suggestActivities(
      _operation.data,
      searchTerm: query.otherTerm.isEmpty ? null : query.otherTerm,
      activityKeys: query.activityKeys,
      preferredKeys: query.preferredKeys,
      preferredSearchTerm: trimmed.isEmpty ? null : trimmed,
      fallbackLocation: fallbackPosition == null ? null : GridLocation(fallbackPosition.latitude, fallbackPosition.longitude),
    );
    // A newer search may have fired (and even resolved) while this one was
    // in flight — only the still-current request gets to apply its results.
    if (mounted && requestId == _searchRequestId) {
      setState(() {
        _suggestions = results.suggestions;
        _searchFailed = results.allSourcesFailed;
        _suggestionsAreSearchResults = trimmed.isNotEmpty;
        // A recognized scope (`query.activityKeys` set) already names KNOWN,
        // enabled extensions — the box's fuzzy search text still reaches
        // `notRunningExtensionsMatching` otherwise, and an unrelated disabled
        // extension whose keywords happen to mention this one's name (`pota:`
        // matching State Parks' "similar to POTA" blurb, say) would offer to
        // enable it above the very extension the operator just scoped to.
        // The exact key still counts inside a scope: the word is shared by
        // every extension serving the type, so `pota` parses as a scope while
        // stock POTA is off and a user-published one serves parks — and
        // typing its key is how stock POTA gets switched back on from here.
        _disabledMatches = notRunningExtensionsMatching(widget.services.extensions, term, keyOnly: query.activityKeys != null);
        _refreshCatalogMatches();
        // These rows live in the Activity Types section, which the operator
        // may have collapsed — so a search that finds only an extension that
        // is not running would otherwise answer with nothing at all.
        //
        // Deliberately NOT written to `activitiesAllOptionsHidden`: the
        // preference is the operator's, and a search must not rewrite it. The
        // section then stays open for the rest of this sheet — it is not
        // re-collapsed when the next search stops matching, because a section
        // closing itself under the hand reaching for it is worse than one left
        // open. Reopening the sheet restores the preference.
        //
        // No fight with `_scopeSearchTo`, which collapses the section and then
        // searches: it can only scope to a type whose control is loaded, and a
        // loaded control means an enabled extension, which never matches here.
        if (_disabledMatches.isNotEmpty) _allOptionsExpanded = true;
        _loadingSuggestions = false;
      });
      // A box that would match nothing asks the catalog nothing — the same
      // emptiness test the matching uses — and neither does a recognized
      // scope, whose word exists only for a LOADED control, so the extension
      // serving it is installed and excluded from this tier.
      if (query.activityKeys == null && extensionSearchCandidates(term).search.isNotEmpty) _ensureCatalogFetched();
      // After the assignment, not before: it reads `_suggestions`.
      unawaited(_loadSuggestionLinks());
    }
  }

  /// The operation's refs minus the ones a new ref of [type] displaces (see
  /// [refsKeptWhenAdding]), reading the type's multiplicity off the
  /// suggestion being added or, for a hand-typed ref, its control descriptor.
  List<Map<String, dynamic>> _refsKeeping(String? type, {Map<String, dynamic>? suggestion}) => refsKeptWhenAdding(
    refs: _operation.refs,
    type: type,
    allowsMultiple: allowsMultipleRefsOfType(type, suggestion: suggestion, control: controlForRefType(_controls, type)),
  );

  Future<void> _addSuggestion(Map<String, dynamic> suggestion) async {
    final type = suggestion['type'] as String?;
    final code = suggestion['ref'] as String?;
    if (type != null && code != null && _isDuplicateRef(type, code)) {
      await _flashExistingRef(type, code);
      return;
    }
    _saveRefs([..._refsKeeping(type, suggestion: suggestion), suggestion]);
    widget.services.track('activity_added', {'activity': type});
    _maybeAdoptLocationFromNewRef(distanceKm: suggestion['distance'] as num?);

    // SAVE FIRST, then configure — the opposite order from [_addFormActivity],
    // and deliberately so. That path runs the form as the act of adding, with
    // nothing on the operation until it is submitted; here the tap on a
    // suggestion IS the add, so backing out of the form leaves the activity in
    // place, unconfigured. A tap that can end with nothing added reads as a tap
    // that didn't work.
    await _configureNewRef(suggestion);
  }

  /// Opens a freshly-added ref's setup form, for a type that has one.
  ///
  /// A contest added from the search is unusable until its exchange is set, and
  /// nothing on the row says so — the operator has to know it is tappable. Only
  /// form-configured types prompt: a reference type's suggestion already
  /// carries the code that identifies it, so the only thing an editor could ask
  /// is that they retype what they just picked.
  Future<void> _configureNewRef(Map<String, dynamic> ref) async {
    // Descriptors FIRST, and freshly: a form is allowed to depend on the refs
    // the operation carries (see [_reloadControlsIfRefsChanged]), and the ref
    // this is about to configure was saved a moment ago. State Parks asks Ohio
    // for its park, power class and entry category only once its own ref is on
    // the operation — read before the reload lands, its descriptor offers the
    // event select alone and the operator saves a setup missing everything the
    // scorer and the Cabrillo export need.
    //
    // This also settles the cold-boot case: `_controls` starts empty while
    // suggestion rows are already tappable, and an absent control is
    // indistinguishable from a type that has no form.
    await _loadControls();
    if (!mounted) return;

    final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
    // Which of the two absences this is, is now answerable, and they call for
    // opposite things. A type with no form is done here; a form that could
    // not be FETCHED leaves the operator with an unconfigured contest, a row
    // that renders non-editable because `refTypeIsEditable(null)` is false,
    // and — silently — no way back to the setup they were about to be shown.
    if (control == null && _controlsState == ControlsLoadState.failed) {
      widget.services.statusBar.setMessage(key: 'activities:setup-unavailable', text: context.t.activitiesView.setupUnavailable);
      return;
    }
    if (!refTypeIsForm(control)) return;

    final updated = await _runSetupForm(control!, existing: ref);
    if (!mounted) return;
    // Decorate even on a CANCEL — that is the whole point of decorating here.
    // A suggestion is persisted verbatim, and its `name` describes the event
    // for the search list it was written for ("the ARRL's June operating
    // event"). Left at that, a contest the operator backed out of reads like a
    // configured activity. Running the hook over the ref as it stands lets the
    // extension say what is actually true of it — that it is not set up.
    final decorated = await widget.services.extensions.decorateRef(updated ?? ref);
    if (!mounted) return;
    // Read the refs AFTER every await, never across one. The dialog is gone by
    // now and the sheet is live, while `decorateRef` can run to its 10s hook
    // timeout — a list captured earlier and written here silently undoes an
    // activity the operator added or deleted in between. Identity, not a
    // remembered index, for the same reason.
    final refs = _operation.refs;
    final index = refs.indexWhere((r) => r['type'] == ref['type'] && r['ref'] == ref['ref']);
    if (index < 0) return;
    _saveRefs([...refs]..[index] = decorated);
  }

  /// Both catalog tiers re-matched against the box as it is NOW: a listing
  /// can land while the operator is still typing, and matching the term they
  /// have moved on from offers rows for a search no longer on screen.
  void _refreshCatalogMatches() {
    final term = _searchController.text;
    final query = ActivitySearchQuery.parse(term, _activityScopes);
    _catalogTier.matches = _catalogTier.matching(widget.services, extensionSearchCandidates(term), keyOnly: query.activityKeys != null);
    _refreshUnhandledRefMatches();
    if (_catalogTier.matches.isNotEmpty || _catalogTier.refMatches.isNotEmpty) _allOptionsExpanded = true;
  }

  void _ensureCatalogFetched() {
    if (!CatalogTier.shownFor(widget.services)) return;
    _catalogTier.ensureFetched(widget.services, () {
      if (mounted) setState(_refreshCatalogMatches);
    });
  }

  /// Installs a catalog extension from the search results, and lands where
  /// the enable row lands. The consent screen, the refusals and the failure
  /// report are all [installCatalogExtension]'s; false covers every one.
  Future<void> _installCatalogExtension(CatalogEntry entry) => _gainExtension(
    entry.key,
    scopeSearch: true,
    gain: () => installCatalogExtension(context, services: widget.services, entry: entry),
  );

  /// Turns an extension on from the search results, then scopes the search to
  /// the ref type it lists. Text that merely NAMED the extension is dropped —
  /// its own suggestions are what the operator wants next — but a reference
  /// typed after its key (`sota w7a/mn-001`) is carried across into the
  /// scope, since that half of the box was never about naming the extension.
  ///
  /// [scopeSearch] is false for an extension enabled on behalf of a ref the
  /// operation already carries: nothing was typed, and the operator wants
  /// that row recognized, not a search for more of its kind. The current
  /// search is re-run as-is, which also settles the results spinner. The
  /// same happens for an extension whose controls declare no ref type: there
  /// is no word to type.
  Future<void> _enableExtension(ExtensionInfo info, {bool scopeSearch = true}) => _gainExtension(
    info.key,
    scopeSearch: scopeSearch,
    gain: () async {
      try {
        await widget.services.extensions.setExtensionEnabled(info.key, true);
        return true;
      } catch (e, st) {
        // A failed restart must not strand the section on its spinner.
        debugPrint('[activities] enabling ${info.key} failed: $e');
        ErrorReportingService.report(e, st, context: 'activities:enable-extension');
        return false;
      }
    },
  );

  /// Gaining an extension, however it is gained: [gain] acquires it and
  /// answers whether it worked, then the search lands on it. The guard is
  /// held across the reload and re-search too — both ways end in a runtime
  /// restart, and releasing it earlier frees the second tap to queue one on
  /// top of the first.
  Future<void> _gainExtension(String key, {required bool scopeSearch, required Future<bool> Function() gain}) async {
    if (_enablingExtension) return;
    _enablingExtension = true;
    setState(() => _loadingSuggestions = true);
    try {
      final gained = await gain();
      if (!mounted) return;
      if (!gained) {
        setState(() => _loadingSuggestions = false);
        return;
      }
      await _continueAfterExtensionAvailable(key, scopeSearch: scopeSearch);
    } finally {
      _enablingExtension = false;
      if (_dataChangedWhileGaining) {
        _dataChangedWhileGaining = false;
        _onDataFilesChanged();
      }
    }
  }

  /// Where both ways of gaining an extension end — the enable row above and a
  /// catalog install. The descriptors are reloaded (the new type has to appear
  /// under "Activity Types", and its scope word only exists once its control
  /// is among the loaded ones) and the search is scoped to it, so what comes
  /// back is the extension's own suggestions.
  ///
  /// Called with the guard held, and awaited by the caller for that reason.
  Future<void> _continueAfterExtensionAvailable(String key, {required bool scopeSearch}) async {
    // Nothing is rewritten. An extension that claims a legacy reference
    // answers for it as it stands — `ref:qp/ny` on the New York QSO Party
    // handles `{type: 'qp', ref: 'NY'}` — so the operation the operator logged
    // years ago is the operation they keep.
    await _loadControls();
    if (!mounted) return;
    final scopeWord = scopeSearch ? _scopeWordServedBy(key) : null;
    if (scopeWord == null) {
      _debounce?.cancel();
      await _search(_searchController.text);
      return;
    }
    final scoped = ActivitySearchQuery.scopePrefixFor(scopeWord) + searchTextAfterKey(_searchController.text, key);
    _putInSearchBox(scoped);
    _debounce?.cancel();
    await _search(scoped);
  }

  /// Replaces the search box, caret at the end — every caller has just
  /// written a scope prefix for a reference to be typed after.
  void _putInSearchBox(String text) => _searchController.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  /// The scope word any of [hookKey]'s loaded controls answers to, or null
  /// when none declares a ref type. A word shared with another extension
  /// still counts: the scope asks every hook serving it.
  String? _scopeWordServedBy(String hookKey) {
    for (final entry in _activityScopes.entries) {
      if (entry.value.contains(hookKey)) return entry.key;
    }
    return null;
  }

  /// A row of the Activity Types section for an extension the search matched
  /// or one an unhandled ref needs — the same row, told apart by [hint] and
  /// by whether enabling then scopes the search to it.
  Widget _notRunningRow(ExtensionInfo info, {required String hint, required bool scopeSearch}) => NotRunningExtensionRow(
    extensions: widget.services.extensions,
    info: info,
    leading: _accentIcon(info.icon, resolveExtensionColor(info.accentColor)),
    enableHint: hint,
    onEnable: () => _enableExtension(info, scopeSearch: scopeSearch),
    onOpenExtensions: () => unawaited(_openExtensionsPanel()),
  );

  /// The Extensions panel, then the descriptors and search again — whatever
  /// the operator changed there may have added or removed activity types.
  Future<void> _openExtensionsPanel() async {
    await showModalPane<void>(
      context,
      title: context.t.activitiesView.manageExtensions,
      closeLabel: context.t.common.close,
      // The list scrolls; the footer stays pinned under it and its Done is
      // the way out — so no X in the header (see haloDialogFooterBand).
      scrollable: false,
      closeButton: false,
      builder: (_) => ExtensionsPanel(services: widget.services, footer: true),
    );
    if (mounted) {
      _debounce?.cancel();
      await _loadControls();
      unawaited(_search(_searchController.text));
    }
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
    final scopeWord = _scopeWordOf(control);
    if (scopeWord == null) {
      // A malformed descriptor; without this line the tap is a silent no-op.
      debugPrint('[activities] control ${control['key']} declares no refType, nothing to scope to');
      return;
    }
    final prefix = ActivitySearchQuery.scopePrefixFor(scopeWord);
    _putInSearchBox(prefix);
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
    widget.services.track('activity_added', {'activity': refType});
  }

  /// How tall the collapsed Activity Types section stands, given the height
  /// [available] to the results list and this section together.
  ///
  /// The default peek is a row and a half of the types already loaded — enough
  /// to read as a scrollable list. When the section is also carrying enable
  /// rows, that default can cut the first one in half, and those rows are the
  /// answer to the search the operator just typed. So it grows to hold them
  /// ALL, plus one ordinary row beneath: the extra row is what still says
  /// "there is more below" once the enable rows fill the window.
  ///
  /// Bounded, because the space comes out of the results list directly above —
  /// which keeps its own row and a half whatever this returns. On a window too
  /// short to honor both, the results win and this falls back to the default:
  /// the section can be opened by hand, while a results list squeezed to
  /// nothing has no such escape.
  double _optionsPeekHeightFor(BuildContext context, double available) {
    final scale = MediaQuery.textScalerOf(context);
    final floor = scale.scale(_optionsPeekHeight);
    final enableRows = _disabledMatches.length + _unhandledRefMatches.length + _catalogTier.matches.length + _catalogTier.refMatches.length;
    if (enableRows == 0) return floor;

    final wanted = scale.scale(enableRows * _twoLineRowHeight + _optionRowHeight);
    return clampDouble(wanted, floor, _optionsMaxHeightFor(context, available));
  }

  /// The tallest the Activity Types section may stand, peeking or opened, out
  /// of the [available] box it shares with the results list — which keeps its
  /// own row and a half plus the search band whatever this returns.
  ///
  /// Never below the default peek: on a window too short to honor both, the
  /// results win and the section falls back to peeking, because a section cut
  /// short can be opened by hand while a results list squeezed to nothing has
  /// no such escape.
  double _optionsMaxHeightFor(BuildContext context, double available) {
    final scale = MediaQuery.textScalerOf(context);
    return math.max(
      scale.scale(_optionsPeekHeight),
      available - scale.scale(_accordionHeaderHeight) - scale.scale(_searchBandHeight) - _searchProgressHeight - scale.scale(_resultsMinPeekHeight),
    );
  }

  /// Opens the operation's location editor and folds whatever it returns back
  /// into the operation. Shared by the search band's location pill and the
  /// empty state's hint, which point at the same thing.
  Future<void> _editLocation() async {
    final patch = await showHaloDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => OperationLocationScreen(services: widget.services, operation: _operation),
    );
    if (patch == null) return;
    if (!mounted) {
      // Not the same as cancelling: the operator entered a location and it is
      // going nowhere. Takes a route popping out from under the open editor.
      debugPrint('[activities] location edit discarded: the sheet unmounted while the editor was open');
      return;
    }
    final updated = Operation(
      uuid: _operation.uuid,
      data: {..._operation.data, ...patch},
      qsoCount: _operation.qsoCount,
      startAtMillisMin: _operation.startAtMillisMin,
      startAtMillisMax: _operation.startAtMillisMax,
      localData: _operation.localData,
    );
    // A location arriving here re-runs the search — see
    // [_researchIfLocationChanged].
    updateOperation(updated);
    widget.onOperationChanged?.call(updated);
  }

  /// Whether the operation carries a location of its own, and so needs nothing
  /// from the device.
  ///
  /// Measured by what the SEARCH can do with it, not by the field being
  /// filled: `suggestActivities` runs the grid through [gridToLocation] and
  /// gets nothing for `''`, which still arrives through sync and import. The
  /// location editor now refuses a locator this can't place, so it is no
  /// longer a source of them — but it is not the only door into the field, and
  /// one read as a location would answer a muted "No suggestions" over a grid
  /// the hooks were never given: the "there is nothing near you" misreading
  /// this whole notice exists to prevent, reached by way of taking its advice.
  bool get _hasOperationGrid => _operation.location != null;

  /// The empty state for the Suggestions & Search section.
  ///
  /// ONE decision, deliberately: a second getter answering "is this a location
  /// problem?" alongside this one drifts the moment a guard is added to only
  /// one of them, and the result is a red headline over "No suggestions", or a
  /// bare reason line with no headline — the two failures this notice exists
  /// to prevent.
  ///
  /// An empty-state message whose headline and body are one string, split on
  /// its own FIRST newline — so which words lead is the translator's call and
  /// not a second key to keep aligned. A message with no newline is all
  /// headline, which is right for the one-liners.
  ///
  /// Only for the single-key messages. Where the two halves are already
  /// separate keys, pass them separately: joining them to re-split here would
  /// give `\n` two meanings at once, and a translator wrapping a long title —
  /// which this very file's messages already do — would silently demote the
  /// tail of their headline into the muted body.
  Widget _emptyStateFromMessage(ThemeData theme, String message) {
    final split = message.indexOf('\n');
    return _emptyStateMessage(theme, title: split < 0 ? message : message.substring(0, split), body: split < 0 ? '' : message.substring(split + 1));
  }

  /// An empty-state message: [title] bold and in [titleColor], [body] muted
  /// under it, centred.
  Widget _emptyStateMessage(ThemeData theme, {required String title, required String body, Color? titleColor}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: TextStyle(color: titleColor ?? theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
          ),
          if (body.isNotEmpty)
            TextSpan(
              text: '\n$body',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Why the refs below are showing without their activities' controls.
  ///
  /// Says the refs are safe on purpose: the rows lose their icons, labels and
  /// tap targets all at once, which reads like the operation lost the refs
  /// themselves. Retry re-runs the fan-out — a hook that timed out on a cold
  /// cache usually answers the second time.
  Widget _controlsFailedNotice(ThemeData theme) {
    final t = context.t.activitiesView;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _emptyStateMessage(theme, title: t.controlsUnavailableTitle, body: t.controlsUnavailableReason, titleColor: theme.colorScheme.error),
          ),
          TextButton(
            onPressed: () {
              setState(() => _controlsState = ControlsLoadState.loading);
              _loadControls();
            },
            child: Text(t.controlsUnavailableRetry),
          ),
        ],
      ),
    );
  }

  /// The padding every empty state stands in, so the loud one and the quiet
  /// ones sit at the same height under the search band rather than the notice
  /// looking like a different kind of thing.
  Widget _emptyStatePadding({required Widget child}) => Padding(
    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
    child: child,
  );

  /// What to do about a location the OS is withholding, or null when the OS
  /// isn't the thing in the way (no GPS at all, or a fix still coming).
  VoidCallback? get _locationPermissionAction => switch (widget.services.location.status) {
    LocationStatus.permissionDenied => () => unawaited(_grantLocationPermission()),
    LocationStatus.permissionBlocked => () => unawaited(_openLocationSettings()),
    _ => null,
  };

  /// Sends the operator to the OS settings page, or tells them where to go
  /// when the platform has none — a button that silently does nothing is the
  /// worst of the three outcomes.
  Future<void> _openLocationSettings() async {
    final opened = await widget.services.location.openSystemSettings();
    if (opened || !mounted) return;
    widget.services.statusBar.setMessage(key: 'activities:location-permission', text: context.t.activitiesView.locationSettingsUnavailable);
  }

  /// Asks the OS again, and says so when the answer is still no — a button
  /// that appears to do nothing is worse than no button, and "denied again"
  /// and "denied forever" look identical from here.
  Future<void> _grantLocationPermission() async {
    final granted = await widget.services.location.requestPermissionAgain();
    if (!mounted) return;
    if (granted) {
      // The fix that just arrived is what nearby suggestions are computed
      // from; nothing else re-runs the search for a permission grant.
      _debounce?.cancel();
      unawaited(_search(_searchController.text));
    } else {
      widget.services.statusBar.setMessage(key: 'activities:location-permission', text: context.t.activitiesView.locationGrantRefused);
    }
  }

  /// A location problem gets the loud treatment: a red headline, and the way
  /// out spelled with the very pin that opens the location editor. Muted grey
  /// saying nothing is nearby reads as "there is nothing nearby" — the
  /// opposite of what it means, and the operator stops looking. Every other
  /// empty state is the same shape without the red or the way out.
  Widget _suggestionsEmptyContent(ThemeData theme) {
    final t = context.t.activitiesView;

    // A bare "no suggestions" here would contradict the enable row sitting in
    // the expanded section below: the activity they searched for does exist.
    // Ahead of the failure state below, because that row comes from extension
    // metadata rather than from the hooks — it is a real answer even when
    // every hook is broken.
    if (_disabledMatches.isNotEmpty || _catalogTier.matches.isNotEmpty) {
      // Three sentences, because the remedies differ: a switch for what is
      // installed and off, the Extensions panel for what is on and still not
      // running (there is no switch to flip), and a download and a consent
      // screen for what is not installed.
      final extensions = widget.services.extensions;
      final only = _disabledMatches.isEmpty
          ? t.onlyCatalogMatches
          : _disabledMatches.every(extensions.isExtensionSwitchedOn)
          ? t.onlyNotRunningMatches
          : t.onlyDisabledMatches;
      return _emptyStatePadding(child: _emptyStateFromMessage(theme, only));
    }
    // Nobody could answer, which is not the same as nobody having anything —
    // and telling the operator "no suggestions" for it sends them looking for
    // a reference that may well be there.
    if (_searchFailed) {
      return _emptyStatePadding(
        child: _emptyStateMessage(theme, title: t.searchUnavailableTitle, body: t.searchUnavailableReason, titleColor: theme.colorScheme.error),
      );
    }
    // A typed search, or a location the search could actually use, was
    // answerable — it simply found nothing, and location has no part in that.
    // The device's own last fix counts even under a bad status: it is never
    // cleared, so `suggestActivities` searched WITH it, and blaming the
    // location for an empty answer it had nothing to do with sends the
    // operator to type a grid that will change none of it.
    if (_searchController.text.trim().isNotEmpty || _hasOperationGrid || widget.services.location.position != null) {
      return _emptyStatePadding(
        child: _emptyStateMessage(theme, title: t.noSuggestions, body: '${t.noSuggestionsHint}\n${t.noSuggestionsExample}'),
      );
    }

    // Denied permission and a location the device can't produce are named
    // apart: only one of them is the operator's to grant.
    final (String? title, String plain) = switch (widget.services.location.status) {
      LocationStatus.permissionDenied => (t.locationDeniedTitle, t.noNearbyReason),
      LocationStatus.permissionBlocked => (t.locationBlockedTitle, t.noNearbyReason),
      LocationStatus.unavailable => (t.locationUnavailableTitle, t.noNearbyReason),
      LocationStatus.unknown || LocationStatus.determining => (null, t.determiningLocation),
      LocationStatus.available => (null, t.noSuggestions),
    };
    if (title == null) return _emptyStatePadding(child: _emptyStateFromMessage(theme, plain));

    final muted = TextStyle(color: theme.colorScheme.outline);

    // The hint's pin is a placeholder in the translation rather than a fixed
    // position, so a language that needs the icon elsewhere in the sentence can
    // put it there. U+FFFC is the character that exists to stand in for an
    // embedded object, written as an escape because it renders as nothing in a
    // source file and cannot be reviewed. Every segment is rendered and every
    // seam gets a pin: a translation is free to use the placeholder twice, or
    // not at all, and must not lose the words between them either way.
    const iconMark = '\u{FFFC}';
    final hint = t.locationManualHint(icon: iconMark).split(iconMark);

    // The ink layer must be the notice itself. Taken from the sheet's root
    // Material instead, the highlight paints outside this viewport's clip and
    // keeps drawing over the pinned search band as the list scrolls under it.
    return Material(
      type: MaterialType.transparency,
      // A paragraph that happens to be tappable announces itself as prose: the
      // one operator who most needs the way out spelled aloud is told there
      // isn't one.
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: _editLocation,
          child: _emptyStatePadding(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _emptyStateMessage(theme, title: title, body: plain, titleColor: theme.colorScheme.error),
                // The fix the OS will actually accept, when there is one: a
                // permission the app may ask for again is a button that asks,
                // and one the operator has already refused for good is a button
                // that opens the settings page where it can be undone. Offering
                // either in the other's place wastes the tap.
                if (_locationPermissionAction != null) ...[
                  const SizedBox(height: Space.lg),
                  FilledButton(
                    onPressed: _locationPermissionAction,
                    child: Text(widget.services.location.status == LocationStatus.permissionDenied ? t.locationGrantAction : t.locationSettingsAction),
                  ),
                ],
                // What to do about it is its own paragraph, not a third line of
                // the diagnosis.
                const SizedBox(height: Space.lg),
                Text.rich(
                  TextSpan(
                    children: [
                      for (var i = 0; i < hint.length; i++) ...[
                        if (i > 0)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(MdiIcons.mapMarkerOff, size: _locationPinSize, color: theme.colorScheme.error),
                          ),
                        TextSpan(text: hint[i], style: muted),
                      ],
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final refListControls = _controls.where((c) => (c['input'] as Map?)?['kind'] == 'refList' || (c['input'] as Map?)?['kind'] == 'form').toList();
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
      return t.activitiesView.activitiesTitleMore(first: labels[0], second: labels[1], more: (labels.length - 2).toString());
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
    final rowContext = _refRowKeys[_refRowKeyId(id)]?.currentContext;
    if (rowContext != null && rowContext.mounted) {
      await Scrollable.ensureVisible(rowContext, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: 0.5);
    }
    if (!mounted) return;
    _flashTimer = Timer(_flashDuration, () {
      if (mounted && _flashingRefRowId == id) setState(() => _flashingRefRowId = null);
    });
  }

  /// A row's GlobalKey is scoped to the mode that built it: the list and the
  /// map put the Current Activities rows under different parents, and one
  /// GlobalKey spanning both migrates its elements — and their semantics
  /// nodes — to the new parent while the old parent is torn down in the same
  /// frame. Flutter's semantics update can't express that pairing (the child
  /// is re-parented, the old parent never dropped), and the web engine
  /// rejects the whole update with "Semantics node map was inconsistent".
  /// Nothing needs the key across a toggle — [_flashExistingRef] only ever
  /// looks up a row in the mode currently on screen.
  String _refRowKeyId(String id) => '${_showResultsMap ? 'map' : 'list'}/$id';

  /// Tags a Current Activities row so [_flashExistingRef] can find it, and
  /// paints the fading highlight over it while it's the flashing one.
  Widget _flashableRow(Map<String, dynamic> ref, Widget row) {
    final id = _refRowId(ref['type'] as String?, ref['ref'] as String?);
    final rowKey = _refRowKeys.putIfAbsent(_refRowKeyId(id), () => GlobalKey());
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
                  // onSurfaceAccent: a flash has to be a change the eye
                  // catches, which means lightening a dark row rather than
                  // washing it with the near-invisible dark teal primary is.
                  color: HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.35 * value),
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
    final data = fragments == null ? _operation.data : {..._operation.data, 'title': buildGeneratedTitle(t, fragments)};
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
  /// title, a notes marker and the pencil that advertises the whole group is
  /// tappable — shown at the far right of the always-visible header row,
  /// wrapping onto at most [_maxPillLines] runs within [availableWidth] and dropping
  /// its least informative members rather than take a third. Tapping any of it
  /// opens the details editor (see [OperationSheet.onEditDetails]).
  Widget _operationPills(ThemeData theme, double availableWidth) {
    final stationCall = _operation.stationCall;
    final operatorCall = operatorCallFor(_operation);
    final operationTitle = _operation.userTitle;
    final notes = asQsonString(_operation.data['notes']) ?? '';
    final multiIdentifier = asQsonString(_operation.localData['multiIdentifier']) ?? '';

    // Only the station chip carries the full teal; its companions are the
    // same hue a step lighter, so the station callsign reads first.
    final chipColor = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final lightChipColor = Color.lerp(chipColor, Colors.white, 0.25)!;
    // Carried on the spans themselves rather than left to the chip's
    // DefaultTextStyle: the measuring below has to see the very style the
    // pill renders at, or the line count it predicts is not the one the Wrap
    // produces.
    final pillTextStyle = theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold);
    // [minWidth] is for the icon-only pills, whose glyph alone reads as a blob
    // rather than as one of the row's chips. A pill carrying a value is never
    // padded out past it: the callsigns' widths are information.
    Widget chip(Widget child, {bool light = false, double? minWidth, bool ellipsize = true}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: _pillPadding, vertical: Space.xs),
      // Constraints only, never `alignment`: a Container with an alignment
      // takes ALL the width it is offered instead of hugging its child, so
      // the floor would become the whole row. The centering that goes with
      // it rides on the text style below.
      constraints: minWidth == null ? null : BoxConstraints(minWidth: minWidth),
      decoration: BoxDecoration(color: light ? lightChipColor : chipColor, borderRadius: BorderRadius.circular(12)),
      // A pill is one line, always: a callsign broken across two lines
      // inside a rounded chip reads as damage, so a squeezed pill
      // ellipsizes instead (and the whole group sheds pills before it
      // gets that tight — see below). Where [ellipsize] is off the text
      // runs past the chip rather than lose a character — a half-read
      // callsign is worse than an untidy one.
      child: DefaultTextStyle.merge(
        style: pillTextStyle,
        textAlign: TextAlign.center,
        softWrap: false,
        maxLines: 1,
        overflow: ellipsize ? TextOverflow.ellipsis : TextOverflow.visible,
        child: child,
      ),
    );

    // The glyph rides inside a Text so the chip takes its height from the
    // same line box as its text-bearing siblings, rather than from the
    // glyph. Nudged up 1px: the glyph's own bearing sits it slightly low
    // against the text line box that PlaceholderAlignment.middle centers on.
    Widget iconPill(IconData icon, {String? semanticLabel, double? minWidth = _pillMinWidth}) => chip(
      light: true,
      minWidth: minWidth,
      Text.rich(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Transform.translate(
            offset: const Offset(0, -1),
            child: Icon(icon, size: _pillIconSize, color: theme.colorScheme.onPrimary, semanticLabel: semanticLabel),
          ),
        ),
      ),
    );

    // The shared measurer: it folds in the ambient DefaultTextStyle the chip
    // renders through and disposes its painter, both of which a hand-rolled
    // TextPainter here would get wrong.
    // Rounded UP: a paragraph lays out a hair wider than its measured width,
    // and a prediction that lands a tenth of a pixel short is still a row
    // overflow.
    double measure(List<InlineSpan> spans) => (spansWidth(context, spans, pillTextStyle) + _pillPadding * 2).ceilToDouble();

    // An icon inside a WidgetSpan is scaled by the text scaler like the text
    // around it, so the icon pills' widths cannot be constants — a declared
    // width that lags the rendered one is how the two-run cap silently
    // becomes three.
    final scaledIcon = MediaQuery.textScalerOf(context).scale(_pillIconSize);
    final iconPillNaturalWidth = scaledIcon + _pillPadding * 2;
    final iconPillWidth = math.max(_pillMinWidth, iconPillNaturalWidth);

    const callStyle = TextStyle(fontFamily: 'RobotoMono');
    final stationSpans = [const TextSpan(text: 'Station: '), TextSpan(text: stationCall, style: callStyle)];
    final operatorSpans = [const TextSpan(text: 'Op: '), TextSpan(text: operatorCall, style: callStyle)];
    // Shown to anyone who has a position set, developer mode or not: the
    // identifier keeps suffixing this device's spots (`K2SUL/OP2`) after
    // developer mode goes off, and this pill is the only thing on the sheet
    // that explains where that came from.
    final positionSpans = [const TextSpan(text: 'Pos: '), TextSpan(text: multiIdentifier, style: callStyle)];

    // What the pills may take before they start shedding: the title keeps
    // _headerTitleMinWidth of the row for its count and subtitle. They can
    // still end up wider than this — the station callsign and the pencil never
    // go — but only after everything sheddable has gone.
    final pillBudget = math.max(0.0, availableWidth - _headerTitleMinWidth);
    final stationWidth = measure(stationSpans);

    // The operation's identity — always the top line, in this order.
    final identity = <_HeaderPill>[
      if (multiIdentifier.isNotEmpty)
        _HeaderPill(
          chip(light: true, Text.rich(TextSpan(children: positionSpans))),
          measure(positionSpans),
          // Last of the droppable pills to go: it is short, and losing it
          // leaves the row saying nothing about a call that goes out modified.
          dropOrder: 4,
        ),
      if (operatorCall.isNotEmpty) _HeaderPill(chip(light: true, Text.rich(TextSpan(children: operatorSpans))), measure(operatorSpans), dropOrder: 2),
      // The station callsign is the one value the header exists to show, so it
      // never truncates and never goes.
      _HeaderPill(chip(Text.rich(TextSpan(children: stationSpans)), ellipsize: false), stationWidth, absorbsShortfall: true),
      // The affordance for what the whole group already does: the pencil
      // carries no tap of its own, so it can't drift from the pills'. Sized to
      // its glyph and nothing more — it is furniture, not a value. It rides
      // with the identity so the row always advertises the tap, whatever else
      // the width forces out.
      _HeaderPill(iconPill(MdiIcons.pencil, semanticLabel: context.t.activitiesView.operationDetails, minWidth: null), iconPillNaturalWidth),
    ];

    // What the operation says about itself beyond its callsigns — the second
    // line when there has to be one.
    final extras = <_HeaderPill>[
      // Notes have no useful short form, so this chip only says that there
      // ARE notes — the details are one tap away, in the same
      // operation-details dialog. Last to go: it is the only place the sheet
      // admits the notes exist at all, where every other pill's value is also
      // spelled out inside the editor.
      if (notes.trim().isNotEmpty) _HeaderPill(iconPill(MdiIcons.fileDocument, semanticLabel: context.t.dialogs.notes), iconPillWidth, dropOrder: 3),
      // A title is free text and can run long — it ellipsizes rather than
      // pushing the callsign chips aside, and it is the first pill to go.
      if (operationTitle.isNotEmpty)
        _HeaderPill(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _titlePillMaxWidth),
            child: chip(light: true, Text(operationTitle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
          math.min(measure([TextSpan(text: operationTitle)]), _titlePillMaxWidth),
          dropOrder: 1,
        ),
    ];

    // What a shed pill leaves behind: one marker per run, standing where the
    // first of them sat. Without it the row can't be told apart from an
    // operation that simply has no title, no notes and no separate operator —
    // and there would be nothing to say the details editor holds more.
    final ellipsisPill = _HeaderPill(
      chip(light: true, minWidth: _pillMinWidth, const Text('…')),
      math.max(_pillMinWidth, measure([const TextSpan(text: '…')])),
    );

    double runWidth(List<_HeaderPill> run) => run.fold(0.0, (total, pill) => total + pill.width) + math.max(0, run.length - 1) * _pillSpacing;

    /// [run] narrowed to [budget] by shedding its least informative pills
    /// (lowest non-zero [_HeaderPill.dropOrder] first; 0 never goes), with what
    /// went alongside what stayed.
    (List<_HeaderPill>, List<_HeaderPill>) fitRun(List<_HeaderPill> run, double budget) {
      final kept = run.toList();
      final shed = <_HeaderPill>[];
      while (runWidth(kept) > budget) {
        final droppable = kept.where((pill) => pill.dropOrder > 0).toList()..sort((a, b) => a.dropOrder.compareTo(b.dropOrder));
        if (droppable.isEmpty) break;
        kept.remove(droppable.first);
        shed.add(droppable.first);
      }
      return (kept, shed);
    }

    /// [fitRun] for a run whose shed pills are gone for good: one
    /// [ellipsisPill] takes the first one's place, and since the marker is
    /// itself part of what has to fit, making room for it can cost one more.
    List<_HeaderPill> fitAndMark(List<_HeaderPill> run, double budget) {
      final (kept, shed) = fitRun(run, budget);
      if (shed.isEmpty) return kept;
      kept.insert(run.indexOf(shed.first).clamp(0, kept.length), ellipsisPill);
      return fitRun(kept, budget).$1;
    }

    // One line while everything fits on one; otherwise exactly two, identity on
    // top. Never three: a third run reads as a wall across the header. Each run
    // is fitted on its own — a pill the identity line has no room for becomes a
    // "…" there rather than moving down to the extras, because the callsigns
    // and the pencil are what the top line is FOR, and a reader looking for the
    // operator should not have to find it on another line.
    final oneLine = [...extras, ...identity];
    final runs = runWidth(oneLine) <= pillBudget
        ? [oneLine]
        : [fitAndMark(identity, pillBudget), fitAndMark(extras, pillBudget)].where((run) => run.isNotEmpty).toList();

    // The box is sized to the widest run rather than to the budget: sized any
    // narrower, a run that outgrew the budget (the station callsign and the
    // pencil, which never shed) would lay out in less room than it occupies
    // and paint over itself. The title keeps whatever is left — down to
    // nothing in that same extreme, which beats overlapping text.
    final pillsWidth = math.min(availableWidth, runs.map(runWidth).reduce(math.max));

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: pillsWidth),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Opaque: a tap in the gaps between chips still opens the editor
        // rather than falling through to anything behind the pills.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onEditDetails,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: _pillRunSpacing,
            children: [
              for (final run in runs)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: _pillSpacing,
                  children: [for (final pill in run) pill.absorbsShortfall ? Flexible(child: pill.widget) : pill.widget],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// What tapping a reference's row does while the map is showing: point the
  /// camera at that reference, the same as tapping its own dot. Null leaves
  /// the row inert, exactly as it was before — see [refRowMapTarget] for
  /// when.
  VoidCallback? _moveMapToRef(Map<String, dynamic> ref) {
    final target = refRowMapTarget(ref, mapShowing: _showResultsMap);
    if (target == null) return null;
    return () => _resultsCamera.moveTo(target.latitude, target.longitude);
  }

  /// The "Current Activities" rows (plus the controls-failed notice, when
  /// relevant) — shared between the list presentation's `SliverList` and the
  /// map presentation's plain `Column`, so an operator toggling to the map
  /// doesn't lose sight of what's already on the operation.
  List<Widget> _currentActivityRows(ThemeData theme, Color rowColor) {
    final t = context.t.activitiesView;
    final refs = _operation.refs;
    return [
      if (_controlsState == ControlsLoadState.failed && refs.isNotEmpty) _controlsFailedNotice(theme),
      for (final ref in refs)
        Builder(
          builder: (context) {
            final control = controlForRef(_controls, type: ref['type'] as String?, code: refCodeOf(ref));
            final detail = activityRowDetail(ref);
            final linkKey = _refLinkKey(ref);
            final link = linkKey == null ? null : _refLinks[linkKey];
            return Material(
              type: MaterialType.transparency,
              child: _flashableRow(
                ref,
                ListTile(
                  tileColor: _controlsUnreliable ? rowColor : (control == null ? theme.colorScheme.errorContainer.withValues(alpha: 0.4) : rowColor),
                  // Right padding matches the header rows' own horizontal
                  // inset, so the RIGHTMOST trailing button lines up under the
                  // search row's location button — same IconButton defaults
                  // (no custom size/padding) too. Any button added left of it
                  // hangs off that alignment rather than moving it, which is
                  // why the web button — the one every list here ends with —
                  // is the rightmost, and Remove sits inside it.
                  contentPadding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
                  leading: _controlsUnreliable && control == null
                      ? const Icon(MdiIcons.toyBrick)
                      // With the code: a reference answered under a legacy type
                      // draws its extension's icon, not the unknown marker.
                      : activityRefIcon(_controls, ref['type'] as String?, code: refCodeOf(ref)),
                  title: Row(
                    children: [
                      Flexible(child: _activityRowTitleText(activityRowTitle(control, ref))),
                      if (_isInvalidRef(ref))
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: ActivityRowChip(label: t.invalidReference, unavailable: true),
                        ),
                      if (activityRowIsRetired(ref))
                        Padding(
                          padding: const EdgeInsets.only(left: Space.md),
                          child: ActivityRowChip(label: t.retiredReference, unavailable: true),
                        ),
                    ],
                  ),
                  subtitle: detail == null ? null : Text(detail),
                  // Tappable only for a type that declares it has something to
                  // edit — a plain ref activity doesn't, so the row stays inert
                  // rather than offering to retype a code its own search
                  // already resolved.
                  // The editor wins where a type has one: the tune button
                  // beside it opens the same thing, but a form-configured
                  // reference has nothing else that does, and a row that
                  // panned the map instead would strand it.
                  onTap: refTypeIsEditable(control) ? () => _editRef(ref) : _moveMapToRef(ref),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The row has always opened the editor on tap, with
                      // nothing to say so. This is that affordance made
                      // visible, not a second way in — same condition as the
                      // tap above, so the two can never disagree about whether
                      // a row is configurable.
                      if (refTypeIsEditable(control))
                        IconButton(
                          icon: Icon(MdiIcons.tune, semanticLabel: t.editActivity),
                          onPressed: () => _editRef(ref),
                        ),
                      IconButton(
                        icon: Icon(MdiIcons.delete, semanticLabel: t.removeActivity),
                        onPressed: () => _deleteRef(ref),
                      ),
                      // Absent, not disabled, when the program has no page for
                      // this reference (and while the hook is still answering):
                      // a placeholder would be a dead control rather than free
                      // space. Its gap is wider than the one between the other
                      // buttons — leaving a reference and destroying one are
                      // different enough that they should not sit a thumb's
                      // width apart.
                      if (link != null) ...[const SizedBox(width: Space.md), _refLinkButton(link, fallbackName: activityRowTitle(control, ref))],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.activitiesView;
    final theme = Theme.of(context);
    final refs = _operation.refs;
    // The same color the sheet's top row shows — matching it by hand would
    // drift the moment the pane's own banding changes.
    final accordionColor = haloDialogBandColorAt(context);
    final onAccordionColor = theme.colorScheme.onSurfaceVariant;
    // Rows paint an opaque color so they read distinctly from the pane's
    // gray/dark background (the ColoredBox below), which otherwise shows
    // straight through wherever a filling section has no row to draw. The
    // pane brings this background itself so both Modal Pane presentations
    // (full screen and dialog card) look the same. Shared with the Layout
    // Setup sheet through theme.dart — two list sheets a shade apart read
    // as a mistake.
    final listBgColor = haloSheetListBackground(context);
    final rowColor = haloSheetRowColor(context);

    return Material(
      color: listBgColor,
      child: Column(
        children: [
          // The operation's own header row — always visible, no accordion:
          // the activities count and subtitle at left, the operation pills
          // at right. The pills measure first, at their natural width, and
          // the title takes everything they leave — a flex share instead
          // would ellipsize the title while the pills sat in space they
          // never asked for. The cap is what keeps that honest in the other
          // direction: past it the pills wrap onto a second line rather than
          // squeezing the title away, and it is also what makes an
          // inflexible Row child measurable at all (it is handed unbounded
          // width otherwise, and an unbounded Wrap never wraps).
          Material(
            color: accordionColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.lg, Space.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: Space.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _activitiesTitle(refs.map((r) => r['type'] as String?).whereType<String>().where((t) => t.isNotEmpty).toSet().length),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(color: onAccordionColor, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: Space.xxs),
                              Text(
                                refs.isEmpty ? context.t.activitiesView.emptySheet : _groupedActivitiesSubtitle(refs),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _operationPills(theme, constraints.maxWidth),
                    ],
                  );
                },
              ),
            ),
          ),
          // The results list and Activity Types share what the header leaves,
          // and this LayoutBuilder is what measures it: the peek height below
          // is carved out of exactly this box, so the two cannot both claim
          // the same pixels. Measuring the results list itself instead would
          // be circular — its height is what the peek decides.
          Expanded(
            child: LayoutBuilder(
              builder: (context, sheetBody) {
                final optionsPeekHeight = _optionsPeekHeightFor(context, sheetBody.maxHeight);
                final optionsMaxHeight = _optionsMaxHeightFor(context, sheetBody.maxHeight);
                return Column(
                  children: [
                    // Selected activities, the search field and its results live in
                    // ONE clipped scroll area — only Activity Types below keeps the
                    // accordion behavior.
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final locStatus = widget.services.location.status;
                          final operationGrid = _operation.displayGrid;

                          // Every variation is the same filled button: white icon and
                          // label on a state color, rather than colored text on nothing.
                          const onLocationColor = Colors.white;
                          final Widget locationPin;
                          final String label;
                          final Color locationColor;
                          // The glyph behind [locationPin], for the results map's own
                          // dot — the pill's widget can't be handed to a map backend
                          // that draws pixels rather than widgets.
                          final IconData locationIcon;

                          // The SAME question the empty state asks, so the two can't
                          // contradict each other over a grid the search can't place:
                          // a half-typed `FN` saved unvalidated must not label this
                          // button "located" under a notice still saying it isn't.
                          if (_hasOperationGrid) {
                            // Only for operations stored before `gridSource` existed, and
                            // compared at SIX characters on both sides: those carry a
                            // 6-character grid, so matching them against a fix's own
                            // displayed locator could never be reliably equal, and every
                            // legacy GPS-set operation would quietly lose its green pin.
                            final gridSource =
                                asQsonString(_operation.data['gridSource']) ??
                                ((_operation.location != null &&
                                        widget.services.location.grid != null &&
                                        locationToGrid6(_operation.location!.latitude, _operation.location!.longitude) == widget.services.location.grid)
                                    ? 'gps'
                                    : 'manual');

                            if (gridSource == 'gps') {
                              locationIcon = MdiIcons.mapMarker;
                              locationPin = Icon(locationIcon, color: onLocationColor);
                              label = operationGrid!;
                              locationColor = const Color(0xFF1B5E20);
                            } else {
                              locationIcon = MdiIcons.pin;
                              locationPin = Icon(locationIcon, color: onLocationColor);
                              label = operationGrid!;
                              locationColor = const Color(0xFF455A64);
                            }
                          } else {
                            if (locStatus == LocationStatus.unknown || locStatus == LocationStatus.determining) {
                              // The pulse is an animation over the same glyph, and a
                              // map marker takes one frame of it.
                              locationIcon = MdiIcons.mapMarker;
                              locationPin = const _PulsingGpsPin(color: onLocationColor);
                              label = 'GPS…';
                              locationColor = const Color(0xFF1565C0);
                            } else if (locStatus == LocationStatus.available && widget.services.location.displayGrid != null) {
                              locationIcon = MdiIcons.mapMarker;
                              locationPin = Icon(locationIcon, color: onLocationColor);
                              label = widget.services.location.displayGrid!;
                              locationColor = const Color(0xFF1B5E20);
                            } else if (locStatus == LocationStatus.available && widget.services.location.displayGrid == null) {
                              locationIcon = MdiIcons.mapMarker;
                              locationPin = const _PulsingGpsPin(color: onLocationColor);
                              label = 'GPS…';
                              locationColor = const Color(0xFF1565C0);
                            } else {
                              // The only variant that can end up with no label, so the
                              // only one that would otherwise announce nothing — and it
                              // is on screen exactly while the notice below tells the
                              // operator to tap it. Named the way this app names an
                              // icon-only button (see no_hover_tooltips_test).
                              locationIcon = MdiIcons.mapMarkerOff;
                              locationPin = Icon(locationIcon, color: onLocationColor, semanticLabel: context.t.operationLocationScreen.title);
                              // A grid that got this far is one the search can't place.
                              // Keeping it on the button, in the red state, says which
                              // text is the problem; dropping it would leave the operator
                              // wondering where what they typed went.
                              label = operationGrid ?? '';
                              locationColor = const Color(0xFFC62828);
                            }
                          }

                          // The results map's own "you are here" dot — the same
                          // coordinate and color as the pill above, computed by the
                          // same two branches (operation grid first, then a live GPS
                          // fix) so the dot and the pill can never disagree about
                          // where "here" is. Null exactly when the pill has nothing to
                          // show either (still determining, denied, or an unplaceable
                          // grid) — there's nothing to plot in that state.
                          final currentLocation = _hasOperationGrid
                              ? _operation.location
                              : (locStatus == LocationStatus.available ? widget.services.location.location : null);

                          final searchBorder = OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: onAccordionColor.withValues(alpha: 0.25)),
                          );

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
                                          // Listens to _searchIsEmpty, not the controller
                                          // directly nor the outer rebuild cycle:
                                          // _onSearchChanged only sets state after its 400ms
                                          // debounce fires, which would leave the clear
                                          // button lagging a beat behind every keystroke
                                          // instead of tracking the field live — and
                                          // _searchIsEmpty only flips (so only rebuilds)
                                          // when the button's own presence actually changes,
                                          // not on every keystroke or caret move.
                                          child: AnimatedBuilder(
                                            animation: _searchIsEmpty,
                                            builder: (context, _) => TextField(
                                              selectAllOnFocus: false,
                                              controller: _searchController,
                                              focusNode: _searchFocusNode,
                                              decoration: InputDecoration(
                                                hintText: t.searchHint,
                                                prefixIcon: Icon(MdiIcons.magnify, color: onAccordionColor.withValues(alpha: 0.6)),
                                                suffixIcon: _searchIsEmpty.value
                                                    ? null
                                                    : IconButton(
                                                        icon: Icon(
                                                          MdiIcons.close,
                                                          color: onAccordionColor.withValues(alpha: 0.6),
                                                          semanticLabel: context.t.common.clear,
                                                        ),
                                                        onPressed: _clearSearch,
                                                      ),
                                                filled: true,
                                                // Paler than the band it sits on, so the field
                                                // reads as a well rather than blending in.
                                                fillColor: theme.colorScheme.surface,
                                                border: searchBorder,
                                                // Contrast is against the field's own `surface`
                                                // fill, not the accordion band around it — the
                                                // indicator is drawn over the well.
                                                focusedBorder: haloFocusedBorder(searchBorder, context),
                                                isDense: true,
                                              ),
                                              onChanged: _onSearchChanged,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: Space.md),
                                          // Full-strength, unlike the magnify and clear icons
                                          // inside the field: those decorate the well they sit
                                          // in, while this is an action of its own alongside
                                          // it, and dimming it reads as disabled.
                                          child: IconButton(
                                            icon: Icon(
                                              _showResultsMap ? MdiIcons.formatListBulleted : MdiIcons.map,
                                              color: onAccordionColor,
                                              semanticLabel: _showResultsMap ? t.showResultsList : t.showResultsMap,
                                            ),
                                            onPressed: () => setState(() => _showResultsMap = !_showResultsMap),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(left: Space.md),
                                          // With no grid to show there is no label, and
                                          // TextButton.icon still reserves the 8px gap before
                                          // one plus M3's wider trailing inset — which reads as
                                          // the pin sitting off-centre in its own button. The
                                          // plain button centres it, at the same size: both
                                          // variants share one defaultStyleOf.
                                          child: label.isEmpty
                                              ? TextButton(
                                                  style: TextButton.styleFrom(backgroundColor: locationColor, foregroundColor: onLocationColor),
                                                  onPressed: _editLocation,
                                                  child: locationPin,
                                                )
                                              : TextButton.icon(
                                                  icon: locationPin,
                                                  label: Text(
                                                    label,
                                                    style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
                                                  ),
                                                  style: TextButton.styleFrom(backgroundColor: locationColor, foregroundColor: onLocationColor),
                                                  onPressed: _editLocation,
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
                                  child: _loadingSuggestions ? const LinearProgressIndicator(minHeight: _searchProgressHeight) : null,
                                ),
                              ],
                            ),
                          );

                          final resultRows = <Widget>[
                            // Switched-off extensions that match are NOT here: they
                            // answer "which activities exist", not "which reference do I
                            // add", so they live in the Activity Types section below and
                            // this list stays what the operator searched for.
                            for (final suggestion in _suggestions)
                              Builder(
                                builder: (context) {
                                  final alreadySelected = refs.any((r) => r['type'] == suggestion['type'] && r['ref'] == suggestion['ref']);
                                  if (suggestionHidesAsAlreadyAdded(alreadyAdded: alreadySelected, suggestionsAreSearchResults: _suggestionsAreSearchResults)) {
                                    return const SizedBox.shrink();
                                  }
                                  final suggestionControl = controlForRefType(_controls, suggestion['type'] as String?);
                                  final suggestionLinkKey = _refLinkKey(suggestion);
                                  final suggestionLink = suggestionLinkKey == null ? null : _suggestionLinks[suggestionLinkKey];
                                  return ListTile(
                                    tileColor: _controlsUnreliable
                                        ? rowColor
                                        : (isUnknownRefType(_controls, suggestion['type'] as String?)
                                              ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                                              : rowColor),
                                    // Only a ref with NO control is ambiguous. A partial
                                    // failure leaves the hooks that did answer perfectly
                                    // usable, and blanking their icons too overstates the
                                    // damage.
                                    leading: _controlsUnreliable && suggestionControl == null
                                        ? const Icon(MdiIcons.toyBrick)
                                        : activityRefIcon(_controls, suggestion['type'] as String?),
                                    title: Row(
                                      children: [
                                        // Not `spaceBetween` with a trailing `Spacer`: a
                                        // Spacer is a flex child, so it would split the
                                        // row's free space with the title's own `Flexible`
                                        // and cap the reference at half the width before
                                        // it had shrunk a single point. Laid out from the
                                        // start, the chips take what they need and the
                                        // reference takes the rest.
                                        Flexible(child: _activityRowTitleText(activityRowTitle(suggestionControl, suggestion))),
                                        if (_isInvalidRef(suggestion))
                                          Padding(
                                            padding: const EdgeInsets.only(left: Space.md),
                                            child: ActivityRowChip(label: t.invalidReference, unavailable: true),
                                          ),
                                        if (activityRowIsRetired(suggestion))
                                          Padding(
                                            padding: const EdgeInsets.only(left: Space.md),
                                            child: ActivityRowChip(label: t.retiredReference, unavailable: true),
                                          ),
                                        // Marked, not disabled: tapping still goes through
                                        // `_addSuggestion`, which flashes the existing
                                        // Current Activities row rather than adding a
                                        // second copy.
                                        if (alreadySelected)
                                          Padding(
                                            padding: const EdgeInsets.only(left: Space.md),
                                            child: ActivityRowChip(label: t.alreadySelected),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(activityRowDetail(suggestion) ?? ''),
                                    // Same inset as the Current Activities rows, so the
                                    // web button sits at the same distance from the edge
                                    // in both lists — clear of the scrollbar, and lined up
                                    // with the search row's location button above.
                                    contentPadding: const EdgeInsets.only(left: Space.xl, right: Space.lg),
                                    // The distance rides in the trailing group rather than
                                    // in the title row: `trailing` is centred against the
                                    // whole two-line tile, where the title row would pin it
                                    // to the first line. It stays LEFT of the button — the
                                    // edge belongs to the same web button the Current
                                    // Activities rows end with, whichever list a reference
                                    // is being read about from.
                                    trailing: _suggestionTrailing(theme, suggestion, link: suggestionLink, control: suggestionControl),
                                    onTap: () => _addSuggestion(suggestion),
                                  );
                                },
                              ),
                          ];

                          // The map is a sibling of the scroll area, never a sliver
                          // inside it: a platform-view-backed map backend (the GL
                          // webview/web view — see activities_results_map.dart) loses
                          // pointer events to the CustomScrollView's own drag
                          // recognizer when embedded as one of its slivers, so every
                          // tap on a marker is swallowed before the map ever sees it.
                          // OsmMapView's pure-Flutter canvas isn't affected, but
                          // routing every backend through the same sibling structure
                          // keeps this one thing true regardless of which backend a
                          // platform happens to pick.
                          if (_showResultsMap) {
                            final currentActivityRows = _currentActivityRows(theme, rowColor);
                            return Column(
                              children: [
                                if (currentActivityRows.isNotEmpty)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: MediaQuery.textScalerOf(context).scale(_currentActivitiesMapMaxHeight)),
                                    child: SingleChildScrollView(
                                      physics: const ClampingScrollPhysics(),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: Column(mainAxisSize: MainAxisSize.min, children: currentActivityRows),
                                      ),
                                    ),
                                  ),
                                searchBand,
                                Expanded(
                                  child: ActivitiesResultsMap(
                                    suggestions: _suggestions,
                                    controls: _controls,
                                    refs: refs,
                                    settings: widget.services.settings,
                                    geoshapes: widget.services.geoshapes,
                                    camera: _resultsCamera,
                                    onAdd: _addSuggestion,
                                    currentLocation: currentLocation,
                                    currentLocationColor: locationColor,
                                    currentLocationIcon: locationIcon,
                                    currentLocationIconColor: onLocationColor,
                                  ),
                                ),
                              ],
                            );
                          }

                          // One ink layer PER ROW: a ListTile's tileColor/splash ink
                          // clips to the nearest Material's bounds, which must be the
                          // row itself for rows scrolled out of this viewport to stop
                          // painting.
                          return CustomScrollView(
                            slivers: [
                              SliverList(delegate: SliverChildListDelegate(_currentActivityRows(theme, rowColor))),
                              // The band pins below the sheet's header once the
                              // activity rows above it scroll away; the results keep
                              // scrolling underneath it.
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _PinnedSearchBand(
                                  height: MediaQuery.textScalerOf(context).scale(_searchBandHeight) + _searchProgressHeight,
                                  child: searchBand,
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildListDelegate([
                                  if (resultRows.isEmpty && !_loadingSuggestions)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.md),
                                      child: _suggestionsEmptyContent(theme),
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
                    AccordionSection(
                      title: Padding(
                        padding: const EdgeInsets.only(right: Space.xl),
                        child: Text(
                          _allOptionsTitle(context.t),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        onPressed: _openExtensionsPanel,
                        icon: Icon(MdiIcons.toyBrick, size: 18, color: onAccordionColor),
                        label: Text(t.manage, style: TextStyle(color: onAccordionColor)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
                      ),
                      child: () {
                        final allOptionsContent = Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // FIRST in the section, because this is the one row that
                            // answers the search the operator just typed. The section
                            // grows to hold these ([_optionsPeekHeightFor]) but is
                            // bounded by the results list's own claim, so on a short
                            // window they are the rows that have to fit; below the
                            // loaded types they would be the rows that get cut.
                            for (final info in _disabledMatches) _notRunningRow(info, hint: t.enableExtensionHint, scopeSearch: true),
                            // Next, and for the same reason: the remedy for a red
                            // "unknown" row in Current Activities.
                            for (final info in _unhandledRefMatches) _notRunningRow(info, hint: t.enableExtensionForRefHint, scopeSearch: false),
                            // Last of the three tiers, and last for a reason: what the
                            // app already has is always the cheaper answer, so an
                            // install is offered only under the rows that need no
                            // download at all.
                            for (final entry in [..._catalogTier.matches, ..._catalogTier.refMatches])
                              InstallExtensionRow(entry: entry, onTap: () => unawaited(_installCatalogExtension(entry))),
                            for (final control in _controls)
                              if ((control['input'] as Map?)?['kind'] == 'refList' || (control['input'] as Map?)?['kind'] == 'form')
                                ListTile(
                                  tileColor: rowColor,
                                  leading: _accentIcon(control['icon'] as String?, resolveExtensionColor(control['color'] as String?)),
                                  title: Text((control['label'] as String?) ?? ''),
                                  onTap: () => _scopeSearchTo(control),
                                ),
                          ],
                        );
                        return _allOptionsFullyOpened
                            // Bounded and scrollable even when opened: this list holds
                            // every loaded type AND every enable row a search turns up,
                            // and as an unbounded Column beside the results list it
                            // squeezes them out from under the operator as they type.
                            // That failure is a RenderFlex overflow, which ErrorPolicy
                            // treats as `logOnly` — release builds clip it silently, so
                            // nothing would ever report it.
                            ? ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: optionsMaxHeight),
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  // Same ink-clipping reason as the peeking branch below.
                                  child: Material(type: MaterialType.transparency, child: allOptionsContent),
                                ),
                              )
                            : SizedBox(
                                height: optionsPeekHeight,
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  // Its own ink layer, INSIDE the scroll view, so the
                                  // viewport clips it along with the rows. A ListTile
                                  // paints `tileColor` with `Ink`, onto the nearest
                                  // ancestor Material — without this that's the
                                  // sheet's root, above this scroll view, and ink is
                                  // clipped to that Material's bounds rather than to
                                  // the viewport in between, so
                                  // rows scrolled out of this peeking window would still
                                  // paint their backgrounds over the sections above.
                                  // MaterialType.transparency: an ink layer, no
                                  // surface of its own.
                                  child: Material(type: MaterialType.transparency, child: allOptionsContent),
                                ),
                              );
                      }(),
                    ),
                  ],
                );
              },
            ),
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

/// A short marker beside an activity row's title — "already selected" on a
/// suggestion the operation carries, "retired" on a reference its program has
/// delisted.
///
/// [unavailable] paints the error role rather than the secondary one. The two
/// say different things and must not read alike: one is a reference the
/// operator already has, the other is one they cannot activate at all.
class ActivityRowChip extends StatelessWidget {
  final String label;
  final bool unavailable;

  const ActivityRowChip({super.key, required this.label, this.unavailable = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xxs),
      decoration: BoxDecoration(color: unavailable ? scheme.errorContainer : scheme.secondaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: unavailable ? scheme.onErrorContainer : scheme.onSecondaryContainer)),
    );
  }
}

/// Whether an entry's program has retired this reference, so it can no longer
/// be activated. Set by the extension's `suggest` hook and persisted with the
/// ref (see the SDK's `ActivitySuggestion.disabled`).
bool activityRowIsRetired(Map<String, dynamic> entry) => entry['retired'] == true;

/// Whether an entry's code fails the pattern its program's control declares —
/// what the "Not valid" mark on a row reports.
///
/// A reference like this is kept, never refused: the pattern is HaLo's idea of
/// the program rather than the program's own, so a format that changed — or one
/// this app simply has wrong — must not cost the operator a code they were
/// given on the air. The mark is the whole of the app's opinion about it, and
/// the reference reaches the log and the exports either way.
///
/// A ref type with no control at all has no pattern to fail: that is a
/// different problem, and [isUnknownRefType] already colors the row for it. The
/// same silence covers a sheet whose controls did not load — `_controls` is
/// then empty and every reference reads as fine. Unmarked is the safe direction
/// of the two, and `_controlsUnreliable` already says on the row itself that
/// the sheet cannot vouch for what it is showing.
bool activityRowIsInvalid(List<Map<String, dynamic>> controls, Map<String, dynamic> entry) {
  // The widgets' own helper, so a row, the field that typed the code and the
  // chip that summarizes it cannot disagree about the same reference — and so a
  // regex an extension got wrong disables the mark rather than throwing into a
  // build that runs this for every row.
  final control = controlForRefType(controls, entry['type'] as String?);
  return anyRefFailsPattern([entry], (control?['input'] as Map?)?['pattern'] as String?);
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
    _controller = AnimationController(duration: _pulsePeriod, vsync: this);
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
