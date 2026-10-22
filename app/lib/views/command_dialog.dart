// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The command dialog — ⌘K anywhere in the app opens
// a search field with a sheet of results descending from it. One field, four
// kinds of result: the commands extensions advertise through their `catalog`
// hook, whatever the typed text currently interprets as, places to navigate
// to, and — when the text looks like a callsign — the full callsign lookup,
// rendered with the very same `CallInfoPanel` the Call Info pane uses, below
// the selectable rows rather than as one of them.
//
// The typing/interpretation/execution behavior is NOT here: it lives in
// `CommandEngine`, shared with the Home view's Quick Lookup bar so the two
// can't drift. This file is the palette's own concerns — matching the
// catalog, the result list, keyboard selection, and the chrome.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../config/dev_bridge.dart';
import 'package:halo_i18n/halo_i18n.dart';
import '../config/navigation.dart';
import '../services/command_actions.dart';
import '../services/command_picks.dart';
import '../services/halo_services.dart';
import '../services/settings_service.dart';
import '../tools/operation_title.dart';
import 'command_engine.dart';
import 'operation/call_info_panel.dart';
import 'operation_view.dart';
import 'settings_view.dart';

/// Opens the command dialog over whatever's on screen. Escape and a tap
/// outside both dismiss it (the barrier), matching every other dialog in the
/// app (docs/design/user-interface.md).
Future<void> showCommandDialog(BuildContext context, HaLoServices services) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: haloBarrierColor(context, lightColor: Colors.black.withValues(alpha: 0.45)),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, _, _) => HoldSizeWhileCovered(child: CommandDialog(services: services)),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        // Rises very slightly into place — enough to read as "descending
        // from" the field once the sheet opens, without a bouncy entrance.
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.02), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// One row in the results sheet.
sealed class _Result {
  const _Result();

  /// The heading this row groups under.
  String section(Translations t);

  /// What this row IS, for [listContentsKey] — stable across the rebuilds a
  /// keystroke causes, unlike the instances themselves, which are rebuilt
  /// every frame and would remount the list continuously.
  String get identity;

  /// Every row type is pickable today; the callsign lookup, which is
  /// information rather than an action, is rendered outside the row list
  /// entirely (see `_callInfo`) rather than as an unselectable row.
  bool get selectable => true;
}

/// A command an extension advertises through its `catalog` hook.
class _CatalogResult extends _Result {
  final Map<String, dynamic> entry;

  /// True for the sample commands offered on an empty field, which head
  /// their own section so they don't read as search results.
  final bool suggestion;

  const _CatalogResult(this.entry, {this.suggestion = false});

  String get command => entry['command'] as String;

  @override
  String get identity => 'catalog:$command';
  String? get params => entry['params'] as String?;
  String get describe => (entry['describe'] as String?) ?? '';
  String? get category => entry['category'] as String?;
  bool get expectsParams => entry['expectsParams'] == true;

  /// One heading for all of them, NOT the hook's category: rows are ranked
  /// across categories (see `_rank`), so grouping by category would
  /// either reorder them back or repeat the same heading down the list. The
  /// category shows as a trailing label on the row instead.
  @override
  String section(Translations t) => suggestion ? t.commandDialog.sectionSuggestions : t.commandDialog.sectionCommands;
}

/// "Run what's typed" — the live interpretation of the field's text. Only
/// present once a hook actually recognizes it.
class _TypedResult extends _Result {
  final String text;
  final String describe;
  const _TypedResult({required this.text, required this.describe});

  @override
  String get identity => 'typed:$text';

  @override
  String section(Translations t) => t.commandDialog.sectionCommands;
}

/// Somewhere to go: Home, Settings, a new operation.
class _NavResult extends _Result {
  final String label;
  final IconData icon;
  final Future<void> Function() go;
  const _NavResult({required this.label, required this.icon, required this.go});

  @override
  String get identity => 'nav:$label';

  @override
  String section(Translations t) => t.commandDialog.sectionGoTo;
}

/// An existing operation to open.
class _OperationResult extends _Result {
  final Operation operation;
  final String title;
  final String subtitle;
  const _OperationResult({required this.operation, required this.title, required this.subtitle});

  @override
  String get identity => 'operation:${operation.uuid}';

  @override
  String section(Translations t) => t.commandDialog.sectionOperations;
}

class CommandDialog extends StatefulWidget {
  final HaLoServices services;

  const CommandDialog({super.key, required this.services});

  @override
  State<CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<CommandDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final CommandEngine _engine;

  /// The `catalog` entries every command hook advertises, read once when the
  /// dialog opens ([ExtensionService.getCommandCatalog] caches them across
  /// opens, so this is a bridge call only the first time).
  List<Map<String, dynamic>> _catalog = const [];

  /// The sample commands shown while the field is empty — see
  /// [_pickSuggestions]. Empty after [_suggestionsThreshold] opens.
  List<Map<String, dynamic>> _suggestions = const [];

  /// How many times this user has opened the dialog, counting this one.
  late final int _opens;

  /// Past this many opens an empty field shows nothing at all: the samples
  /// exist to make the feature discoverable, and someone who has opened it
  /// this often already knows what's in there.
  static const _suggestionsThreshold = 10;

  /// How many samples to offer while it's still new.
  static const _suggestionCount = 2;

  /// Rows visible before the sheet scrolls. A fixed row height is what makes
  /// this a real count rather than an estimate — see [_rowHeight].
  static const _maxVisibleRows = 5;

  /// Every result row is this tall whether or not it has a subtitle, so the
  /// sheet's height cap is exactly [_maxVisibleRows] rows. Plain logical
  /// pixels — UiScale scales it (docs/design/ui-scaling.md); never multiply
  /// by the font scale here.
  static const _rowHeight = 56.0;

  /// A section heading's height, counted once into the cap so the first
  /// heading doesn't eat a row's worth of the visible five.
  static const _headingHeight = 28.0;

  /// The search field's corner radius, and the unit the results card's inset
  /// is expressed in.
  static const _searchRadius = 24.0;

  /// The teal border around the search field.
  static const _searchBorderWidth = 6.0;

  /// The search row's horizontal padding, inside the border.
  static const _fieldPadding = 16.0;

  /// The search bar's inner height. Fixed so the bar can't resize when the
  /// placeholder gives way to typed text.
  static const _fieldHeight = 48.0;

  /// How much narrower the results card is than the search, per side —
  /// derived, not picked: it lands the card's edge exactly under the search
  /// icon's.
  static const _cardInset = _searchBorderWidth + _fieldPadding;

  static const _cardRadius = 16.0;

  /// Index into the *selectable* results. Enter activates this one.
  int _selected = 0;

  /// How soon a reopen puts back the response the last palette closed over
  /// ([HaLoServices.lastPaletteResponse]), for an operator who looked away as
  /// it went by.
  static const _recallWindow = Duration(seconds: 3);

  /// [CommandPicks.commandPicks], read once per open — what the operator
  /// has picked before, per typed text, which [_byPicks] ranks by.
  late final Map<String, dynamic> _picks = widget.services.settings.commandPicks;

  /// Whether THIS open showed a response. One that didn't forgets the last,
  /// so a reopen never brings back an answer older than what was just seen.
  bool _showedResponse = false;

  /// Keeps the field's element identity stable across any restructuring of
  /// the tree around it, so its platform text-input connection is never torn
  /// down and reopened. See the note in initState about why this stays.
  final _fieldKey = GlobalKey();

  /// The rows the last frame was built from. The dev bridge's submit/move
  /// need the same list the user is looking at, and `build` is the only place
  /// the operations stream's data is in hand.
  List<_Result> _lastResults = const [];

  /// Held as a field, not called in `build`: `watchAll()` returns a NEW drift
  /// stream every call, so building it inline would tear down and re-run the
  /// SELECT on every keystroke (the same trap `home_view.dart` calls out for
  /// its own operations list).
  late final Stream<List<Operation>> _operationsStream = widget.services.operations.watchAll();

  @override
  void initState() {
    super.initState();
    // Counted before the catalog lands, so this open is included in the
    // threshold test. Reuses the per-flow counter the onboarding nudges
    // already use rather than adding a preference of its own.
    final settings = widget.services.settings;
    _opens = settings.onboardingShownCount(OnboardingFlows.commandDialog) + 1;
    unawaited(settings.recordOnboardingShown(OnboardingFlows.commandDialog));
    _engine = CommandEngine(
      services: widget.services,
      operationContext: () => widget.services.currentOperationContext,
      runAction: (action, params) => runCommandAction(widget.services, action, params, context),
      onExecuted: _onExecuted,
      onResponseExpired: _onResponseExpired,
      // Not just `mounted`: a pop starts the exit transition and only
      // disposes this State when it finishes, so for those 140ms the
      // palette is alive and already unreadable.
      canShowResponse: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
      // Enter on a callsign must not wipe it: the lookup below the field IS
      // the result, and clearing would drop the palette back to suggestions.
      clearOnNoMatch: false,
      // Long enough to read a confirmation, short enough that the palette is
      // gone before the operator's next keystroke lands in it.
      responseDuration: const Duration(milliseconds: 1200),
    )..attach(_controller);
    _engine.addListener(_onEngineChanged);
    _controller.addListener(_onTextChanged);
    _loadCatalog();
    unawaited(_loadLooseTestContacts());
    // Focus requested ONCE rather than `autofocus: true` on the field.
    // Autofocus re-fires whenever the field's Focus node is re-attached, and
    // a re-request reopens the platform text-input connection.
    //
    // Empirically load-bearing: this, the static "looking up" glyph, and the
    // GlobalKey below were all in the build that the developer confirmed
    // working, and the callsign lookup broke again when I removed them on the
    // grounds that my explanation for each had been disproven. It had — but
    // the combination works and the individual contributions are unknown, so
    // they stay until something identifies which one matters.
    //
    // Requested when the route's entrance transition COMPLETES, not on the
    // first frame: on web, focusing while the dialog is still animating in
    // can leave the browser's own focus on the canvas rather than the text
    // input's DOM element — Flutter believes the field is focused, but typed
    // keys never reach it. Anything animating alongside the open (a status
    // bar progress item) makes that race reliable. Once the tree has
    // stopped moving a single request sticks, so wait for it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recallLastResponse();
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        _focusNode.requestFocus();
        return;
      }
      // If the dialog is dismissed before the entrance completes, this
      // listener is never removed here — cleanup then comes from the route
      // disposing its own animation controller in the same teardown that
      // disposes this State, and the mounted guard keeps the disposed focus
      // node untouched.
      late final AnimationStatusListener onStatus;
      onStatus = (status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        if (mounted) _focusNode.requestFocus();
      };
      animation.addStatusListener(onStatus);
    });
    if (DevBridge.instance.installed) {
      DevBridge.instance.commandTextHandler = _devSetText;
      DevBridge.instance.commandSubmitHandler = _devSubmit;
      DevBridge.instance.commandMoveHandler = _devMove;
      DevBridge.instance.commandBarStateProvider = _devState;
      // Resolves the promise `openCommandBar()` handed back — the route
      // mounts a frame after the call, and reading/​typing before that
      // silently does nothing.
      DevBridge.instance.signalCommandBarOpen();
    }
  }

  // ── Dev bridge ────────────────────────────────────────────────────────────
  // The whole dialog is unreachable from outside the app without these: its
  // shortcut is a modifier combo, and those don't reach the Flutter canvas.

  /// Sets the field as if typed. Assigning `text` bypasses the input
  /// formatters, which is fine — callers send text that's already in the
  /// shape the field would have produced — and still fires the engine.
  void _devSetText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _devSubmit() => unawaited(_activate(_lastResults));

  void _devMove(int delta) => _moveSelection(delta, _lastResults);

  Map<String, dynamic> _devState() => {
    'open': true,
    'text': _controller.text,
    'focused': _focusNode.hasFocus,
    'selected': _selected,
    'results': [
      for (final result in _lastResults)
        switch (result) {
          _CatalogResult(:final command, :final params, :final describe, :final category) => {
            'type': 'command',
            'command': command,
            'params': ?params,
            'describe': describe,
            'category': ?category,
          },
          _TypedResult(:final text, :final describe) => {'type': 'typed', 'text': text, 'describe': describe},
          _NavResult(:final label) => {'type': 'nav', 'label': label},
          _OperationResult(:final title, :final subtitle) => {'type': 'operation', 'title': title, 'subtitle': subtitle},
        },
    ],
    'lookupStage': _engine.lookupStage.name,
    if (_engine.lookupCall != null) 'lookupCall': _engine.lookupCall,
    if (_engine.lookupGuess != null) 'lookupGuess': _engine.lookupGuess,
    if (_engine.message != null) 'message': _engine.message,
  };

  /// Puts back the response the previous palette closed over, when it closed
  /// less than [_recallWindow] ago. Not on the response clock: a palette
  /// reopened to read it stays until Enter or a keystroke, like any response.
  void _recallLastResponse() {
    final last = widget.services.lastPaletteResponse;
    final closedAt = widget.services.lastPaletteClosedAt;
    // Real time, not the app clock: this is how long ago the operator saw
    // it, which developer time travel does not change (docs/design/time.md).
    if (last == null || closedAt == null || realNowMillis() - closedAt >= _recallWindow.inMilliseconds) return;
    _engine.showResponse(last.text, failed: last.failed);
  }

  @override
  void dispose() {
    if (_showedResponse) {
      widget.services.lastPaletteClosedAt = realNowMillis();
    } else {
      widget.services.lastPaletteResponse = null;
    }
    if (DevBridge.instance.commandBarStateProvider == _devState) {
      DevBridge.instance.commandTextHandler = null;
      DevBridge.instance.commandSubmitHandler = null;
      DevBridge.instance.commandMoveHandler = null;
      DevBridge.instance.commandBarStateProvider = null;
    }
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final catalog = await widget.services.extensions.getCommandCatalog();
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _suggestions = _pickSuggestions();
    });
  }

  /// Only the commands that can actually run right now. An operation-scoped
  /// one (SEED, NOTE, SPOT) with nothing open isn't offered at all — listing
  /// something the user can't pick is just noise, and picking it would only
  /// produce the hook's "needs an open operation" error. Nor is one that
  /// acts on test data (PURGETESTS) while the device holds none.
  List<Map<String, dynamic>> _availableAmong(List<Operation> operations) {
    final hasTestData = _hasLooseTestContacts || operations.any((op) => op.isTestOperation);
    return [
      for (final entry in _catalog)
        if ((_hasOperation || entry['needsOperation'] != true) && (hasTestData || entry['needsTestData'] != true)) entry,
    ];
  }

  /// Whether the device holds test contacts that belong to no operation —
  /// test data no Test Operation shows, which PURGETESTS also clears. Read
  /// once per open, like the catalog.
  bool _hasLooseTestContacts = false;

  Future<void> _loadLooseTestContacts() async {
    final loose = await widget.services.qsos.testQsosWithoutOperation();
    if (!mounted || loose.isEmpty) return;
    setState(() => _hasLooseTestContacts = true);
  }

  /// Two sample commands for an empty field, chosen once per open (not per
  /// keystroke — they must not reshuffle while the user reads them). Empty
  /// once the dialog is familiar: see [_suggestionsThreshold].
  ///
  /// Only entries that opted in with `suggest` are eligible: the samples go
  /// to users who don't yet know what a command does, so destructive,
  /// heavyweight or developer commands must never be volunteered here, even
  /// though all of them stay listed and searchable in the palette.
  List<Map<String, dynamic>> _pickSuggestions() {
    if (_opens > _suggestionsThreshold) return const [];
    // No operations in hand here, so a Test Operation command never counts as
    // available — and as a destructive one it is never volunteered anyway.
    final pool = _availableAmong(const []).where((e) => e['suggest'] == true).toList();
    if (pool.length <= _suggestionCount) return pool;
    pool.shuffle();
    return pool.take(_suggestionCount).toList();
  }

  void _onEngineChanged() {
    if (_engine.isResponse) {
      _showedResponse = true;
      widget.services.lastPaletteResponse = (text: _engine.message!, failed: _engine.messageKind == CommandMessageKind.failure);
    }
    _scheduleRebuild();
  }

  /// Any edit invalidates the highlighted row's position, so selection goes
  /// back to the top rather than pointing at whatever now occupies that index.
  void _onTextChanged() => _scheduleRebuild(() => _selected = 0);

  /// Rebuilds on a microtask rather than synchronously.
  ///
  /// Both callers are reached from `TextEditingController.notifyListeners()`,
  /// which Flutter fires from inside `EditableTextState._formatAndSetValue`
  /// while it is still applying an incoming edit. Rebuilding this whole tree
  /// there — the results card appearing restructures the column around the
  /// field — means mutating the widget tree around a text field mid-edit,
  /// which is worth not doing on principle. A microtask lets
  /// `_formatAndSetValue` unwind first and still lands before the next frame,
  /// so nothing is visibly deferred. Coalesced, so the two listeners firing
  /// for one keystroke schedule one rebuild.
  void _scheduleRebuild([VoidCallback? mutate]) {
    if (!mounted) return;
    mutate?.call();
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    scheduleMicrotask(() {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  bool _rebuildScheduled = false;

  /// Dismisses THIS dialog — specifically this one, not whatever happens to be
  /// on top of the navigator.
  ///
  /// A command's actions are dispatched before this runs, and one of them can
  /// push a route of its own (SET/SHOW/HIDE open a settings form). A bare
  /// `pop()` would then dismiss that form instead and leave the palette
  /// standing, which reads to the operator as Enter doing nothing at all.
  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    // Already on its way out: GO HOME pops everything above Home, this
    // palette included, and removing a route that is popping trips the
    // navigator.
    if (route != null && !route.isActive) return;
    if (route == null || route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  /// A command has run. The palette STAYS UP to show what it said — a
  /// command's answer belongs where it was typed, not in the status bar the
  /// operator isn't looking at — and dismisses itself once that answer has
  /// had its [CommandEngine.responseDuration] ([_onResponseExpired]).
  ///
  /// Two cases close at once instead. A command with nothing to say would
  /// otherwise hold an empty card open for no reason; and one whose action
  /// pushed a route over us (SET on a multiselect opens the settings form)
  /// has already buried the response, so lingering underneath it just delays
  /// the palette popping out from under the form.
  void _onExecuted() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (_engine.message == null || !(route?.isCurrent ?? true)) _close();
  }

  /// The response has had its [CommandEngine.responseDuration] — unless the operator started
  /// typing again, in which case the palette is back in use and the response
  /// was merely the last thing on the line.
  void _onResponseExpired() {
    if (!mounted || _controller.text.isNotEmpty) return;
    _close();
  }

  bool get _hasOperation => widget.services.currentOperationContext != null;

  /// Case-insensitive, anchored at a word start ([matchesWordStart]), and
  /// host-side — the same rule `interpret` follows about never compiling
  /// extension-supplied patterns.
  bool _matches(String haystack, String needle) => matchesWordStart(haystack, needle);

  /// How well [entry] answers [query], lower being better; null means no
  /// match at all. The command's own name first, then its `keywords` — the
  /// aliases it accepts and the plain words for what it does.
  ///
  /// The description is never searched: prose matches whatever its words
  /// happen to start with, so "dev" would find POSITION by "this device's".
  /// A word that should find a command belongs in its keywords. Nothing
  /// matches mid-word either ([matchesWordStart]).
  int? _rank(Map<String, dynamic> entry, String query) {
    final command = entry['command'] as String;
    final keywords = (entry['keywords'] as List?)?.whereType<String>() ?? const <String>[];

    if (command.toUpperCase() == query) return 0;
    if (command.toUpperCase().startsWith(query)) return 1;
    if (matchesWordStart(command, query)) return 2;
    if (keywords.any((keyword) => keyword.toUpperCase() == query)) return 3;
    if (keywords.any((keyword) => matchesWordStart(keyword, query))) return 4;
    return null;
  }

  /// Whether the card is given over to a just-run command's answer.
  ///
  /// The field is cleared on execution, so this is an EMPTY field with a
  /// finished command's answer on it — confirmation or failure alike. That is
  /// what separates it from the operator typing over that answer, where the
  /// message is merely the last thing on the line and the results belong to
  /// what they are typing now.
  bool get _showingResponse => _engine.isResponse && _controller.text.trim().isEmpty;

  /// Every row to show, in display order, for the current text.
  List<_Result> _buildResults(List<Operation> operations) {
    final t = context.t;
    final query = _controller.text.trim().toUpperCase();
    final results = <_Result>[];

    // A command's answer gets the card to itself. The samples below would
    // otherwise crowd in under it the moment the field clears, and reading as
    // "here is what happened, and here are two unrelated things to try" is
    // exactly the wrong emphasis for the second or two it is up.
    if (_showingResponse) return results;

    // The typed text's own interpretation comes first — when a hook
    // recognizes it, running it is almost always what Enter should do.
    final interpretation = _engine.currentInterpretation;
    final describe = interpretation?['describe'];
    if (query.isNotEmpty && interpretation != null && interpretation['error'] is! String && interpretation['expectsParams'] != true && describe is String) {
      results.add(_TypedResult(text: _controller.text.trim(), describe: describe));
    }

    if (query.isEmpty) {
      // An empty field is not a browse-everything list. For the first few
      // opens it offers a couple of samples so the feature is discoverable;
      // after that it stays quiet until the user types.
      results.addAll(_suggestions.map((e) => _CatalogResult(e, suggestion: true)));
      return results;
    }

    // Ranked, not catalog order — see [_rank]. Equal ranks keep hook-priority
    // order by their catalog index: Dart's `sort` is not stable past 32
    // elements, and a one-letter query matches more than that.
    final ranked = <({int rank, int index, Map<String, dynamic> entry})>[];
    for (final entry in _availableAmong(operations)) {
      final command = entry['command'] as String;
      // Already offered as "run what's typed" — don't list it twice.
      if (results.any((r) => r is _TypedResult && r.text.toUpperCase() == command.toUpperCase())) continue;
      final rank = _rank(entry, query);
      if (rank != null) ranked.add((rank: rank, index: ranked.length, entry: entry));
    }
    ranked.sort((a, b) => a.rank != b.rank ? a.rank.compareTo(b.rank) : a.index.compareTo(b.index));
    results.addAll(ranked.map((r) => _CatalogResult(r.entry)));

    for (final nav in _navResults(t)) {
      if (_matches(nav.label, query)) results.add(nav);
    }

    for (final operation in operations) {
      final title = displayTitleFor(context, operation);
      final subtitle = displaySubtitleFor(operation);
      if (_matches(title, query) || _matches(subtitle, query)) {
        results.add(_OperationResult(operation: operation, title: title, subtitle: subtitle));
      }
    }

    return _byPicks(results, query);
  }

  /// [results] ranked by what the operator has picked for exactly this
  /// [query] before: a row they keep scrolling down to comes up first, where
  /// Enter runs it. Rows stay under their headings — a section moves as a
  /// block, ahead of those with fewer picks, and its rows reorder within it.
  /// Ties keep the order they came in, so text nobody has picked from ranks
  /// exactly as before.
  List<_Result> _byPicks(List<_Result> results, String query) {
    final stored = _picks[query];
    if (stored is! Map || stored.isEmpty) return results;
    int picksOf(_Result result) => switch (stored[result.identity]) {
      final num count => count.toInt(),
      _ => 0,
    };
    // Index-tiebroken rather than relying on `sort`, which is not stable past
    // 32 elements in Dart.
    List<T> byCountThenOrder<T>(List<T> items, int Function(T) count) {
      final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
      indexed.sort((a, b) {
        final byCount = count(b.$2).compareTo(count(a.$2));
        return byCount != 0 ? byCount : a.$1.compareTo(b.$1);
      });
      return [for (final (_, item) in indexed) item];
    }

    final t = context.t;
    final sections = <String, List<_Result>>{};
    for (final result in results) {
      (sections[result.section(t)] ??= []).add(result);
    }
    final blocks = [for (final rows in sections.values) byCountThenOrder(rows, picksOf)];
    return [for (final rows in byCountThenOrder(blocks, (rows) => picksOf(rows.first))) ...rows];
  }

  /// Navigation is done through [navigatorKey], not this dialog's own
  /// `context`: by the time these run the dialog route has been popped, so
  /// its context is defunct.
  List<_NavResult> _navResults(Translations t) => [
    _NavResult(label: t.commandDialog.goNewOperation, icon: MdiIcons.plus, go: _createOperation),
    _NavResult(label: t.commandDialog.goHome, icon: MdiIcons.homeOutline, go: () async => navigatorKey.currentState?.popUntil((route) => route.isFirst)),
    _NavResult(
      label: t.commandDialog.goSettings,
      icon: MdiIcons.cogOutline,
      go: () async => navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => SettingsView(services: widget.services))),
    ),
  ];

  /// Same flow as the Home view's own "+" (`_newOperation`): create against
  /// the active profile's callsign, then open it on the Activities pane,
  /// where the title and everything else get set. The home version's
  /// double-tap guard isn't needed here — the dialog is gone before this
  /// runs, so there's no second row left to tap.
  Future<void> _createOperation() async {
    final services = widget.services;
    final operation = await services.operations.create(stationCall: services.settings.activeProfile.operatorCall);
    services.track('operation_created');
    unawaited(services.settings.recordOnboardingShown(OnboardingFlows.newOperation));
    unawaited(
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => OperationView(services: services, operationUuid: operation.uuid, openActivities: true),
        ),
      ),
    );
  }

  List<_Result> _selectableOf(List<_Result> results) => results.where((r) => r.selectable).toList();

  void _moveSelection(int delta, List<_Result> results) {
    final selectable = _selectableOf(results);
    if (selectable.isEmpty) return;
    setState(() => _selected = (_selected + delta) % selectable.length);
  }

  Future<void> _activate(List<_Result> results) async {
    // The card is showing a command's answer, and the field it was typed into
    // is empty — so Enter has nothing left to run, and the only thing the
    // operator can mean by it is "yes, read it, now go away". Without this it
    // is the one key on the keyboard that does nothing at all here.
    if (_showingResponse) {
      _close();
      return;
    }
    final selectable = _selectableOf(results);
    if (selectable.isEmpty || _selected >= selectable.length) {
      // Nothing to pick — run whatever's typed, same as the Home bar's Enter.
      await _engine.submit();
      return;
    }
    await _activateResult(selectable[_selected]);
  }

  Future<void> _activateResult(_Result result) async {
    // Counted only when there was a choice to make: a lone row says nothing
    // about which of several the operator wants for this text.
    final query = _controller.text.trim().toUpperCase();
    if (query.isNotEmpty && _selectableOf(_lastResults).length > 1) {
      unawaited(widget.services.settings.recordCommandPick(query, result.identity));
    }
    switch (result) {
      case _TypedResult():
        await _engine.submit();
      case _CatalogResult(:final command, :final expectsParams):
        // A command that takes parameters is typed INTO the field rather than
        // run: the user still has to say which band, which experiment, what
        // the note says.
        _controller.text = expectsParams ? '$command ' : command;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        _focusNode.requestFocus();
        if (!expectsParams) await _engine.submit();
      case _NavResult(:final go):
        _close();
        await go();
      case _OperationResult(:final operation):
        _close();
        unawaited(
          navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => OperationView(services: widget.services, operationUuid: operation.uuid),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;

    return StreamBuilder<List<Operation>>(
      stream: _operationsStream,
      builder: (context, snapshot) {
        final operations = snapshot.data ?? const <Operation>[];
        final results = _buildResults(operations);
        _lastResults = results;
        final selectable = _selectableOf(results);

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): _close,
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveSelection(1, results),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveSelection(-1, results),
          },
          // No Focus wrapper here: CallbackShortcuts installs its own
          // non-focusable node, and a second autofocus would race the text
          // field's for the initial focus.
          child: LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.topCenter,
              child: Padding(
                // The field sits around the upper-middle of the window so
                // the sheet has room to descend below it without the field
                // itself moving as results come and go.
                padding: EdgeInsets.only(top: (constraints.maxHeight * 0.22).clamp(24.0, 220.0), left: Space.xl, right: Space.xl, bottom: Space.xxl),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: _panel(theme, t, results, selectable)),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The field and its sheet as one object: a teal-bordered rounded panel
  /// whose lower half grows as results appear.
  Widget _panel(ThemeData theme, Translations t, List<_Result> results, List<_Result> selectable) {
    final searching = _engine.lookupStage == CallLookupStage.searching;
    final hasCallInfo = _engine.lookupStage != CallLookupStage.none && _engine.lookupGuess != null;
    // This generic fallback is the LAST thing to fall back to, so it must not
    // pre-empt a hook that is mid-sentence. `message` is cleared on every
    // keystroke and refilled ~150ms later, so without the pending check this
    // paints "Nothing matches …" in the gap after each character and is
    // replaced by the hook's own wording a moment later — two messages
    // flickering against each other on the same line.
    final hasEmptyState =
        results.isEmpty && _controller.text.trim().isNotEmpty && _engine.message == null && !_engine.interpretationPending && !searching && !hasCallInfo;
    // An error or a confirmation ALWAYS shows. Both are things that have
    // happened — a command that can't run here, or one that just ran — and
    // neither is repeated by any row, so suppressing them behind a result
    // list loses them outright: `SEED` with no operation still matches the
    // SEED catalog row, and its "needs an open operation" would vanish
    // behind it.
    //
    // A `describe` is different. It has to reach the screen for a command
    // that recognizes the text but can't run it yet (`expectsParams`, which
    // is exactly what keeps it out of the results list), but only when there
    // is nothing else to show: with results on screen it is already the "run
    // what's typed" row's own subtitle, and repeating it below reads as a
    // second, competing answer.
    final hasMessage = _engine.isError || _engine.isConfirmation || (_engine.message != null && results.isEmpty);
    final hasCard = results.isNotEmpty || searching || hasCallInfo || hasEmptyState || hasMessage;

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _searchBox(theme, t, results),
          if (hasCard)
            // Flush against the bar, and narrower than it by exactly the
            // search icon's own inset. Painted AFTER the bar, which is what
            // keeps the bar's drop shadow off it — the two read as one
            // object rather than as a card floating under a separate bar.
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _cardInset),
                // Deliberately NOT animated. An AnimatedSize here clips
                // HIT-TESTING to its in-progress box, so result rows are laid
                // out, painted and returned by getRect while being silently
                // untappable. The card
                // just appears; the route's own fade is the entrance.
                child: _resultsCard(
                  theme,
                  t,
                  results,
                  selectable,
                  searching: searching,
                  hasCallInfo: hasCallInfo,
                  hasEmptyState: hasEmptyState,
                  hasMessage: hasMessage,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The search field itself: rounded, with the thick teal border that is the
  /// dialog's whole visual signature.
  Widget _searchBox(ThemeData theme, Translations t, List<_Result> results) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_searchRadius),
        // onSurfaceAccent, like every icon in this dialog: the border sits on
        // `surface` and a stroke needs 3:1 against it, which primary's dark
        // value doesn't reach.
        border: Border.all(color: HaLoColors.of(context).onSurfaceAccent, width: _searchBorderWidth),
        boxShadow: [
          // Tight and dark rather than a wide haze — the bar has to sit
          // clearly ON TOP of whatever view it opened over.
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _field(theme, t, results),
    );
  }

  Widget _resultsCard(
    ThemeData theme,
    Translations t,
    List<_Result> results,
    List<_Result> selectable, {
    required bool searching,
    required bool hasCallInfo,
    required bool hasEmptyState,
    required bool hasMessage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        // Bottom corners only: the top edge butts against the bar, and
        // rounding it would carve a notch out of the join.
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_cardRadius)),
        boxShadow: [
          // Offset down and pulled in (negative spread) so the shadow starts
          // BELOW the card's top edge — otherwise it would smear up across
          // the bar it's attached to.
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: -4, offset: const Offset(0, 6)),
        ],
      ),
      // So the results list can't paint outside the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (results.isNotEmpty)
            // Two ceilings, both needed. ConstrainedBox stops the list after
            // [_maxVisibleRows] rows — the rest scrolls — and Flexible stops
            // it at whatever the window actually leaves, which is what keeps
            // a short window from overflowing.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: _sheetMaxHeight(results)),
                child: _sheet(theme, t, results, selectable),
              ),
            ),
          // The callsign block sits BELOW any matching rows and takes
          // whatever height is left. It's a separate scrollable rather than
          // another row because `CallInfoPanel` is itself a ListView — the
          // same widget the Call Info pane uses, so a lookup here reads
          // exactly as it does there (notes, emoji, distance, history).
          if (searching) _lookingUpLine(theme, t),
          if (hasCallInfo) Flexible(child: _callInfo(theme)),
          if (hasEmptyState) _emptyState(theme, t),
          if (hasMessage) _messageLine(theme),
        ],
      ),
    );
  }

  /// The sheet's height cap: exactly [_maxVisibleRows] rows, plus whatever
  /// section headings fall among them.
  ///
  /// Counting headings as they actually occur — rather than assuming one —
  /// is what makes "5 rows" true. A query matching commands AND navigation
  /// carries two headings, and a flat allowance for one left the fifth row
  /// sliced in half at the card's edge.
  double _sheetMaxHeight(List<_Result> results) {
    var height = 0.0;
    var rows = 0;
    String? lastSection;
    final t = context.t;
    for (final result in results) {
      if (rows >= _maxVisibleRows) break;
      final section = result.section(t);
      if (section != lastSection) {
        lastSection = section;
        height += _headingHeight;
      }
      height += _rowHeight;
      rows++;
    }
    return height + 8; // + the list's own bottom padding
  }

  Widget _field(ThemeData theme, Translations t, List<_Result> results) {
    // The icon is a sibling of the field, not an InputDecoration prefixIcon:
    // a borderless decoration's own content padding sits the text above the
    // icon's centre, and a Row with centred cross-axis alignment simply
    // can't drift.
    return SizedBox(
      // Fixed, so the bar doesn't change height between the placeholder and
      // typed text. Two things would otherwise resize it: the hint and the
      // input are set in different faces (see the field's `hintStyle`) with
      // different line heights, and the clear button — a 48pt tap target —
      // only exists once there's text.
      height: _fieldHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _fieldPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // A console, not a magnifier: this bar runs commands as much as it
            // searches, and the magnifier undersold it as a search box.
            Icon(MdiIcons.console, color: HaLoColors.of(context).onSurfaceAccent),
            const SizedBox(width: Space.lg),
            Expanded(
              child: KeyedSubtree(key: _fieldKey, child: _textField(theme, t, results)),
            ),
            // Sized to the row rather than its own 48pt default, which would
            // otherwise set the bar's height on its own.
            SizedBox(
              width: 32,
              child: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                      icon: Icon(MdiIcons.close, semanticLabel: t.common.clear),
                      onPressed: () => _controller.clear(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(ThemeData theme, Translations t, List<_Result> results) {
    return TextField(
      selectAllOnFocus: false,
      controller: _controller,
      focusNode: _focusNode,
      style: haloMonoStyle(context, fontSize: 17),
      // The formatters own casing, not the keyboard: a soft keyboard's
      // capitalization is fixed when the input connection opens and is not
      // re-sent on rebuild, so a mode chosen here could never follow the text
      // turning from a callsign into a command mid-typing.
      textCapitalization: TextCapitalization.none,
      inputFormatters: commandFieldFormatters,
      decoration: InputDecoration(
        border: InputBorder.none,
        // isCollapsed: the Row above owns the spacing, so the decoration
        // must not add padding of its own — that padding is exactly what
        // pushed the text off the icon's centre line.
        isCollapsed: true,
        hintText: t.commandDialog.hint,
        // The placeholder is prose, so it reads in the regular face; what
        // the user types is a callsign or a command, which is monospaced
        // (the field's own `style`). Without this the hint would inherit
        // that mono style and read as if it were already input.
        hintStyle: theme.textTheme.bodyLarge?.copyWith(fontSize: 17, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      // A tap on a result row is a tap OUTSIDE this field, and Flutter's
      // default for that is to unfocus — which tears the field's focus down
      // mid-gesture and the row's tap never completes. Keeping focus is
      // also what we want anyway: picking a row shouldn't drop the caret
      // (or, on mobile, the keyboard) out from under the next command.
      onTapOutside: (_) {},
      // Not onSubmitted: the default TextInputAction.done handling
      // unfocuses before onSubmitted runs, closing the on-screen keyboard
      // under the dialog. onEditingComplete replaces that default entirely.
      // The results this frame was built from — the same list the arrow
      // keys moved [_selected] through, so Enter activates the row the
      // user is actually looking at.
      onEditingComplete: () => _activate(results),
    );
  }

  Widget _sheet(ThemeData theme, Translations t, List<_Result> results, List<_Result> selectable) {
    String? lastSection;
    final children = <Widget>[];

    for (final result in results) {
      final section = result.section(t);
      if (section != lastSection) {
        lastSection = section;
        children.add(_sectionHeading(theme, section));
      }
      final index = result.selectable ? selectable.indexOf(result) : -1;
      children.add(_row(theme, t, result, isSelected: index >= 0 && index == _selected));
    }

    return ListView(
      // Rows change with every keystroke and every lookup that answers, and
      // each one runs a command on tap (docs/quirks.md).
      key: listContentsKey([for (final result in results) result.identity]),
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: Space.md),
      children: children,
    );
  }

  /// Shown the instant the text reads as a callsign, before either lookup
  /// pass has answered — the offline one is quick but the online one is a
  /// network round trip, and an empty panel meanwhile reads as "nothing
  /// found".
  Widget _lookingUpLine(ThemeData theme, Translations t) => Container(
    height: _rowHeight,
    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        // Static, not a CircularProgressIndicator: a continuous animation
        // over a focused field, for the length of the lookup. See the
        // note in initState — kept because the working build had it.
        Icon(MdiIcons.console, size: 16, color: HaLoColors.of(context).onSurfaceAccent),
        const SizedBox(width: Space.lg),
        Text(t.commandDialog.lookingUp, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
      ],
    ),
  );

  /// The same panel the Call Info pane renders, so a callsign looked up here
  /// shows everything it shows there. With no operation open there's simply
  /// no `grid` to measure a distance from, and the history is empty — the
  /// panel handles both.
  Widget _callInfo(ThemeData theme) {
    return CallInfoPanel(
      operation: operationForCallInfo(widget.services),
      services: widget.services,
      call: _engine.lookupCall ?? '',
      guess: _engine.lookupGuess,
      lookups: _engine.lookupRecords,
      // Sized to its content here, unlike in the pane where it fills a
      // column: a short lookup (no image, no history) would otherwise leave
      // the card stretched to the bottom of the window with nothing in it.
      // The Flexible around it still caps it at the space available.
      shrinkWrap: true,
    );
  }

  Widget _sectionHeading(ThemeData theme, String label) => Container(
    height: _headingHeight,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.fromLTRB(Space.xl, Space.md, Space.xl, Space.xxs),
    child: Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(color: HaLoColors.of(context).onSurfaceAccent, fontWeight: FontWeight.w700, letterSpacing: 0.6),
    ),
  );

  Widget _row(ThemeData theme, Translations t, _Result result, {required bool isSelected}) {
    final (IconData icon, String title, String? trailing, String? subtitle) = switch (result) {
      _TypedResult(:final text, :final describe) => (MdiIcons.play, text, null, describe),
      // The category rides along as a trailing label instead of a grouping
      // heading: results are ranked across every category, so grouping
      // them would either fight the ranking or repeat headings.
      // console-line, not console: the bar's own field icon is the console
      // glyph, and a row glyph that matches it would make the samples read
      // as more search bars (and defeat counting them in tests).
      _CatalogResult(:final command, :final params, :final describe, :final category) => (
        MdiIcons.consoleLine,
        params == null ? command : '$command $params',
        category,
        describe,
      ),
      _NavResult(:final label, :final icon) => (icon, label, null, null),
      _OperationResult(:final title, :final subtitle) => (MdiIcons.folderOutline, title, null, subtitle.isEmpty ? null : subtitle),
    };

    // Only extension-authored text is parsed as markdown. An operation's
    // title or a callsign note is the user's own data, where a stray asterisk
    // is punctuation, not markup.
    final markdownSubtitle = result is _TypedResult || result is _CatalogResult;

    final foreground = theme.colorScheme.onSurface;

    final row = Container(
      // Fixed, so [_maxVisibleRows] is an exact count rather than a guess —
      // rows with and without a subtitle have to measure the same.
      height: _rowHeight,
      // onSurfaceAccent: a wash this faint has to be the accent that CONTRASTS
      // with the surface, so it lightens a dark row and darkens a light one.
      // primary is dark in both, so in dark mode this highlight — the only
      // thing marking which result Enter will run — is invisible.
      color: isSelected ? HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.14) : null,
      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HaLoColors.of(context).onSurfaceAccent),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (result is _CatalogResult || result is _TypedResult ? haloMonoStyle(context, fontSize: 15) : theme.textTheme.bodyLarge)?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  if (markdownSubtitle)
                    // No `onOpenLink`: picking the row runs the command, so a
                    // link must not be a second target. With no handler the
                    // widget builds no recognizer at all, which is what keeps
                    // the tap reaching the row (see its own test) — a link in
                    // `describe` text just reads as one.
                    InlineMarkdownText(subtitle, codeStyle: haloMonoStyle(context, fontSize: 12), maxLines: 1, style: _subtitleStyle(theme, foreground))
                  else
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _subtitleStyle(theme, foreground)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Space.lg),
            Text(trailing, style: theme.textTheme.labelSmall?.copyWith(color: foreground.withValues(alpha: 0.5))),
          ],
        ],
      ),
    );

    if (!result.selectable) return row;

    // GestureDetector, not InkWell: selection is already shown by the row's
    // own background, so the ink ripple buys nothing — and `opaque` makes the
    // WHOLE row tappable (gaps included) rather than just the painted glyphs.
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _activateResult(result), child: row);
  }

  /// Shared by both subtitle branches, so the markdown and plain renderings of
  /// a row measure and read identically.
  /// Names the emoji font rather than relying on the theme's own fallback:
  /// a row's subtitle is an extension's `describe` text, and this style is
  /// what the markdown rendering of it resolves glyphs through.
  TextStyle? _subtitleStyle(ThemeData theme, Color foreground) =>
      theme.textTheme.bodySmall?.copyWith(color: foreground.withValues(alpha: 0.75), fontFamilyFallback: const [emojiFontFamily]);

  Widget _emptyState(ThemeData theme, Translations t) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xl, Space.xs, Space.xl, Space.xl),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t.commandDialog.noResults(text: _controller.text.trim()),
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    ),
  );

  /// The engine's own message — a command's `describe` preview while typing,
  /// its `error` when it can't run here, or its `confirm` just after running.
  Widget _messageLine(ThemeData theme) {
    final message = _engine.message!;
    final isError = _engine.isError;
    // A response has the card to itself ([_showingResponse]) and is the thing
    // the operator pressed Enter for, so it is set at the field's own size
    // rather than a footnote's. A describe or an interpret-time error is
    // commentary on text still being typed, and stays out of the way of it.
    final response = _showingResponse;
    return Container(
      width: double.infinity,
      // Same reason as the selected row's wash: at 10% alpha the color has to
      // contrast with the surface, which primary's dark value does not.
      color: isError ? theme.colorScheme.errorContainer : HaLoColors.of(context).onSurfaceAccent.withValues(alpha: 0.10),
      padding: EdgeInsets.symmetric(horizontal: Space.xl, vertical: response ? Space.lg : Space.md),
      child: Row(
        children: [
          if (isError) ...[Icon(MdiIcons.alertCircle, size: response ? 20 : 16, color: theme.colorScheme.onErrorContainer), const SizedBox(width: Space.md)],
          Expanded(
            child: MarkdownBody(
              data: message,
              styleSheet: withEmojiFallback(
                MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyMedium?.copyWith(
                    // The field's own size, in plain logical pixels — UiScale
                    // scales the whole tree (docs/design/ui-scaling.md); never
                    // multiply by the font scale here.
                    fontSize: response ? 17 : null,
                    color: isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
