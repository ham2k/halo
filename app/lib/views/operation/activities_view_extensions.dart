// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

part of 'activities_view.dart';

mixin _ActivitiesExtensions on State<OperationSheet>, _ActivitiesRefs {
  Map<String, List<String>> get _activityScopes;
  abstract bool _allOptionsExpanded;
  bool get _controlsUnreliable;
  TextEditingController get _searchController;
  FocusNode get _searchFocusNode;

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
  /// search's enable rows (see `_onSearchAnswered`): a collapsed section
  /// shows nothing, leaving a red row above with its remedy hidden. Not
  /// persisted.
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

  /// Whether the search band's progress bar shows. A gain is a wait of its
  /// own, not the search's: a search answering mid-gain — a location tick's —
  /// must not take the bar down while the install is still running.
  bool get _searchBusy => _searchState.loading || _enablingExtension;

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
    _searchState.searchSoon(_searchController.text);
  }

  bool _dataChangedWhileGaining = false;

  /// The enable and install rows for a search just answered, settled in the
  /// same rebuild as its results (see [ActivitySearchState.onAnswered]).
  void _onSearchAnswered(String term, ActivitySearchQuery query) {
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
    // A box that would match nothing asks the catalog nothing — the same
    // emptiness test the matching uses — and neither does a recognized
    // scope, whose word exists only for a LOADED control, so the extension
    // serving it is installed and excluded from this tier.
    if (query.activityKeys == null && extensionSearchCandidates(term).search.isNotEmpty) _ensureCatalogFetched();
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
    setState(() => _enablingExtension = true);
    try {
      final gained = await gain();
      if (!mounted || !gained) return;
      await _continueAfterExtensionAvailable(key, scopeSearch: scopeSearch);
    } finally {
      _enablingExtension = false;
      if (mounted) setState(() {});
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
      await _searchState.search(_searchController.text);
      return;
    }
    final scoped = ActivitySearchQuery.scopePrefixFor(scopeWord) + searchTextAfterKey(_searchController.text, key);
    _putInSearchBox(scoped);
    await _searchState.search(scoped);
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
    if (!mounted) return;
    _searchState.cancelPending();
    await _loadControls();
    if (!mounted) return;
    unawaited(_searchState.search(_searchController.text));
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
    final scopeWord = OperationSheetState._scopeWordOf(control);
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
    unawaited(_searchState.search(prefix));
  }
}
