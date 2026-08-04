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
import '../i18n/strings.g.dart';
import '../main.dart';
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
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (context, _, _) => CommandDialog(services: services),
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
  String? get params => entry['params'] as String?;
  String get describe => (entry['describe'] as String?) ?? '';
  String? get category => entry['category'] as String?;
  bool get expectsParams => entry['expectsParams'] == true;

  /// One heading for all of them, NOT the hook's category: rows are ranked
  /// across categories (see `_rank`), so grouping by category would
  /// either reorder them back or repeat the same heading down the list. The
  /// category shows as a trailing label on the row instead.
  @override
  String section(Translations t) =>
      suggestion ? t.commandDialog.sectionSuggestions : t.commandDialog.sectionCommands;
}

/// "Run what's typed" — the live interpretation of the field's text. Only
/// present once a hook actually recognizes it.
class _TypedResult extends _Result {
  final String text;
  final String describe;
  const _TypedResult({required this.text, required this.describe});

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
  String section(Translations t) => t.commandDialog.sectionGoTo;
}

/// An existing operation to open.
class _OperationResult extends _Result {
  final Operation operation;
  final String title;
  final String subtitle;
  const _OperationResult({required this.operation, required this.title, required this.subtitle});

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
      runAction: (action, params) => runCommandAction(widget.services, this, action, params),
      onExecuted: _close,
      // Enter on a callsign must not wipe it: the lookup below the field IS
      // the result, and clearing would drop the palette back to suggestions.
      clearOnNoMatch: false,
    )..attach(_controller);
    _engine.addListener(_onEngineChanged);
    _controller.addListener(_onTextChanged);
    _loadCatalog();
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
                  if (params != null) 'params': params,
                  'describe': describe,
                  if (category != null) 'category': category,
                },
              _TypedResult(:final text, :final describe) => {'type': 'typed', 'text': text, 'describe': describe},
              _NavResult(:final label) => {'type': 'nav', 'label': label},
              _OperationResult(:final title, :final subtitle) => {
                  'type': 'operation',
                  'title': title,
                  'subtitle': subtitle,
                },
            },
        ],
        'lookupStage': _engine.lookupStage.name,
        if (_engine.lookupCall != null) 'lookupCall': _engine.lookupCall,
        if (_engine.lookupGuess != null) 'lookupGuess': _engine.lookupGuess,
        if (_engine.message != null) 'message': _engine.message,
      };

  @override
  void dispose() {
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
  /// produce the hook's "needs an open operation" error.
  List<Map<String, dynamic>> get _available =>
      _hasOperation ? _catalog : _catalog.where((e) => e['needsOperation'] != true).toList();

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
    final pool = _available.where((e) => e['suggest'] == true).toList();
    if (pool.length <= _suggestionCount) return pool;
    pool.shuffle();
    return pool.take(_suggestionCount).toList();
  }

  void _onEngineChanged() => _scheduleRebuild();

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

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  bool get _hasOperation => widget.services.currentOperationContext != null;

  /// Plain case-insensitive substring matching, host-side — the same rule
  /// `interpret` follows about never compiling extension-supplied patterns.
  bool _matches(String haystack, String needle) => haystack.toUpperCase().contains(needle);

  /// How well [entry] answers [query], lower being better; null means no
  /// match at all. What the user typed is nearly always the start of a
  /// command's NAME, so every name-based rank beats every description-based
  /// one — otherwise typing "SET" puts 20M first (its description reads "Set
  /// the band") ahead of every command actually called SET-something.
  int? _rank(Map<String, dynamic> entry, String query) {
    final command = (entry['command'] as String).toUpperCase();
    final describe = ((entry['describe'] as String?) ?? '').toUpperCase();

    if (command == query) return 0;
    if (command.startsWith(query)) return 1;
    if (command.contains(query)) return 2;
    if (describe.startsWith(query)) return 3;
    // Prefer a word-initial hit in the description ("… the Band") over one
    // buried mid-word, which is usually coincidence.
    if (RegExp('\\b${RegExp.escape(query)}').hasMatch(describe)) return 4;
    if (describe.contains(query)) return 5;
    return null;
  }

  /// Every row to show, in display order, for the current text.
  List<_Result> _buildResults(List<Operation> operations) {
    final t = context.t;
    final query = _controller.text.trim().toUpperCase();
    final results = <_Result>[];

    // The typed text's own interpretation comes first — when a hook
    // recognizes it, running it is almost always what Enter should do.
    final interpretation = _engine.currentInterpretation;
    final describe = interpretation?['describe'];
    if (query.isNotEmpty &&
        interpretation != null &&
        interpretation['error'] is! String &&
        interpretation['expectsParams'] != true &&
        describe is String) {
      results.add(_TypedResult(text: _controller.text.trim(), describe: describe));
    }

    if (query.isEmpty) {
      // An empty field is not a browse-everything list. For the first few
      // opens it offers a couple of samples so the feature is discoverable;
      // after that it stays quiet until the user types.
      results.addAll(_suggestions.map((e) => _CatalogResult(e, suggestion: true)));
      return results;
    }

    // Ranked, not catalog order — see [_rank]. `sort` is stable in Dart, so
    // entries of equal rank keep hook-priority order.
    final ranked = <({int rank, Map<String, dynamic> entry})>[];
    for (final entry in _available) {
      final command = entry['command'] as String;
      // Already offered as "run what's typed" — don't list it twice.
      if (results.any((r) => r is _TypedResult && r.text.toUpperCase() == command.toUpperCase())) continue;
      final rank = _rank(entry, query);
      if (rank != null) ranked.add((rank: rank, entry: entry));
    }
    ranked.sort((a, b) => a.rank.compareTo(b.rank));
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

    return results;
  }

  /// Navigation is done through [navigatorKey], not this dialog's own
  /// `context`: by the time these run the dialog route has been popped, so
  /// its context is defunct.
  List<_NavResult> _navResults(Translations t) => [
        _NavResult(
          label: t.commandDialog.goNewOperation,
          icon: MdiIcons.plus,
          go: _createOperation,
        ),
        _NavResult(
          label: t.commandDialog.goHome,
          icon: MdiIcons.homeOutline,
          go: () async => navigatorKey.currentState?.popUntil((route) => route.isFirst),
        ),
        _NavResult(
          label: t.commandDialog.goSettings,
          icon: MdiIcons.cogOutline,
          go: () async => navigatorKey.currentState
              ?.push(MaterialPageRoute(builder: (_) => SettingsView(services: widget.services))),
        ),
      ];

  /// Same flow as the Home view's own "+" (`_newOperation`): create against
  /// the active profile's callsign, then open it on the Activities pane,
  /// where the title and everything else get set. The home version's
  /// double-tap guard isn't needed here — the dialog is gone before this
  /// runs, so there's no second row left to tap.
  Future<void> _createOperation() async {
    final services = widget.services;
    final operation = await services.operations.create(
      stationCall: services.settings.activeProfile.operatorCall,
    );
    services.track('operation_created');
    unawaited(services.settings.recordOnboardingShown(OnboardingFlows.newOperation));
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => OperationView(services: services, operationUuid: operation.uuid, openActivities: true),
    ));
  }

  List<_Result> _selectableOf(List<_Result> results) => results.where((r) => r.selectable).toList();

  void _moveSelection(int delta, List<_Result> results) {
    final selectable = _selectableOf(results);
    if (selectable.isEmpty) return;
    setState(() => _selected = (_selected + delta) % selectable.length);
  }

  Future<void> _activate(List<_Result> results) async {
    final selectable = _selectableOf(results);
    if (selectable.isEmpty || _selected >= selectable.length) {
      // Nothing to pick — run whatever's typed, same as the Home bar's Enter.
      await _engine.submit();
      return;
    }
    await _activateResult(selectable[_selected]);
  }

  Future<void> _activateResult(_Result result) async {
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
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => OperationView(services: widget.services, operationUuid: operation.uuid),
        ));
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
                padding: EdgeInsets.only(
                  top: (constraints.maxHeight * 0.22).clamp(24.0, 220.0),
                  left: 16,
                  right: 16,
                  bottom: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _panel(theme, t, results, selectable),
                ),
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
    final hasEmptyState = results.isEmpty && _controller.text.trim().isNotEmpty && _engine.message == null && !searching && !hasCallInfo;
    final hasMessage = _engine.isError || _engine.isConfirmation;
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
                child: _resultsCard(theme, t, results, selectable,
                    searching: searching, hasCallInfo: hasCallInfo, hasEmptyState: hasEmptyState, hasMessage: hasMessage),
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
        border: Border.all(color: theme.colorScheme.primary, width: _searchBorderWidth),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
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
          // Only errors and confirmations: a plain `describe` preview is
          // already the "run what's typed" row's own subtitle, and showing it
          // twice reads as two different results.
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
            const SizedBox(width: 12),
            Expanded(child: KeyedSubtree(key: _fieldKey, child: _textField(theme, t, results))),
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
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          if (isMobilePlatform) MobileDotToSlashFormatter(),
          // Spaces are only meaningful mid-command (a command's free-text
          // parameters, e.g. "NOTE hello") — otherwise they'd just corrupt a
          // callsign/command being typed.
          if (!_engine.commandExpectsParams && !_engine.commandMixedCase)
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
          // Uppercase unless the live command declared `mixedCase` — the rule
          // as documented for the call field (hooks.md, `command`), so a NOTE
          // typed here keeps its prose as written. The Home bar's own copy of
          // this list deliberately uppercases unconditionally.
          if (!_engine.commandMixedCase)
            TextInputFormatter.withFunction(
              (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
            ),
        ],
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
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 17,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
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
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: children,
    );
  }


  /// Shown the instant the text reads as a callsign, before either lookup
  /// pass has answered — the offline one is quick but the online one is a
  /// network round trip, and an empty panel meanwhile reads as "nothing
  /// found".
  Widget _lookingUpLine(ThemeData theme, Translations t) => Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            // Static, not a CircularProgressIndicator: a continuous animation
            // over a focused field, for the length of the lookup. See the
            // note in initState — kept because the working build had it.
            Icon(MdiIcons.console, size: 16, color: HaLoColors.of(context).onSurfaceAccent),
            const SizedBox(width: 14),
            Text(
              t.commandDialog.lookingUp,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      );

  /// The same panel the Call Info pane renders, so a callsign looked up here
  /// shows everything it shows there. With no operation open there's simply
  /// no `grid` to measure a distance from, and the history is empty — the
  /// panel handles both.
  Widget _callInfo(ThemeData theme) {
    final context = widget.services.currentOperationContext;
    final operation = context == null
        ? const Operation(uuid: '', data: {})
        : Operation(uuid: (context['uuid'] as String?) ?? '', data: context);
    return CallInfoPanel(
      operation: operation,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: HaLoColors.of(context).onSurfaceAccent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
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
      _OperationResult(:final title, :final subtitle) => (
          MdiIcons.folderOutline,
          title,
          null,
          subtitle.isEmpty ? null : subtitle,
        ),
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
      color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.14) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HaLoColors.of(context).onSurfaceAccent),
          const SizedBox(width: 12),
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
                  style: (result is _CatalogResult || result is _TypedResult
                          ? haloMonoStyle(context, fontSize: 15)
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  if (markdownSubtitle)
                    // No `onOpenLink`: picking the row runs the command, so a
                    // link must not be a second target. With no handler the
                    // widget builds no recognizer at all, which is what keeps
                    // the tap reaching the row (see its own test) — a link in
                    // `describe` text just reads as one.
                    InlineMarkdownText(
                      subtitle,
                      codeStyle: haloMonoStyle(context, fontSize: 12),
                      maxLines: 1,
                      style: _subtitleStyle(theme, foreground),
                    )
                  else
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _subtitleStyle(theme, foreground),
                    ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Text(
              trailing,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );

    if (!result.selectable) return row;

    // GestureDetector, not InkWell: selection is already shown by the row's
    // own background, so the ink ripple buys nothing — and `opaque` makes the
    // WHOLE row tappable (gaps included) rather than just the painted glyphs.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _activateResult(result),
      child: row,
    );
  }

  /// Shared by both subtitle branches, so the markdown and plain renderings of
  /// a row measure and read identically.
  TextStyle? _subtitleStyle(ThemeData theme, Color foreground) =>
      theme.textTheme.bodySmall?.copyWith(color: foreground.withValues(alpha: 0.75));

  Widget _emptyState(ThemeData theme, Translations t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.commandDialog.noResults(text: _controller.text.trim()),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );

  /// The engine's own message — a command's `describe` preview while typing,
  /// its `error` when it can't run here, or its `confirm` just after running.
  Widget _messageLine(ThemeData theme) {
    final message = _engine.message!;
    final isError = _engine.isError;
    return Container(
      width: double.infinity,
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primary.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (isError) ...[
            Icon(MdiIcons.alertCircle, size: 16, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: MarkdownBody(
              data: message,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                  color: isError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
