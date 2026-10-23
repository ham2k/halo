// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The home view's Quick Lookup bar: a callsign looked up, or a command run,
// without opening an operation.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/command_actions.dart';
import '../services/halo_services.dart';
import '../services/link_opener.dart';
import '../tools/worked_before_label.dart';
import 'command_engine.dart';
import 'operation/call_info_panel.dart';
import 'package:halo_i18n/halo_i18n.dart';

class HomeQuickLookup extends StatefulWidget {
  final HaLoServices services;

  const HomeQuickLookup({super.key, required this.services});

  /// This bar's RESTING height — the field and its padding, before a lookup
  /// line or a command's answer grows it upward.
  ///
  /// Exact rather than an estimate: the field is held to one chrome row below,
  /// so this is the height, and two other things are built to it. The window's
  /// chrome budget reserves it, since the bar is always on screen on the home
  /// layer and a budget blind to it hands the notice and the footer room Home
  /// has already spent. And the rail's Settings cap is this tall, so the two
  /// read as one row across the foot of the window — the cap does NOT follow
  /// the bar when it grows, which is the one direction they may differ.
  static double heightOf(BuildContext context) => LayoutDensity.chromeHeightOf(context) + Space.md * 2;

  @override
  State<HomeQuickLookup> createState() => _HomeQuickLookupState();
}

class _HomeQuickLookupState extends State<HomeQuickLookup> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  /// Lookup, command interpretation and execution all live in the shared
  /// engine — the ⌘K command dialog runs on the same one, so the debounce,
  /// space-retention and execute rules can't drift
  /// between the two. This widget only renders it.
  late final CommandEngine _engine;

  /// Whether an Enter is still being resolved — see [_submit].
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _engine = CommandEngine(
      services: widget.services,
      // The home screen has no open operation, so operation-scoped commands
      // (SEED, NOTE, SPOT) answer with their own error here.
      operationContext: () => null,
      runAction: (action, params) => runCommandAction(widget.services, action, params, context),
      // HomeView stays mounted under every pushed route, so being alive
      // says nothing about being on screen.
      canShowResponse: () => mounted && (ModalRoute.of(context)?.isCurrent ?? false),
    )..attach(_controller);
    _engine.addListener(_onEngineChanged);
    // The clear button and the numbers row's contextual key both key off the
    // text, and the numbers row shows only while this field has focus, so
    // rebuild for both.
    _controller.addListener(_onEngineChanged);
    _focusNode.addListener(_onFocusChanged);
    // The numbers row and the bottom reserve both ask the raw FlutterView
    // whether the keyboard is up, because StatusBarOverlay consumes the inset
    // from MediaQuery — and the raw view carries no rebuild dependency, so
    // this is what notices the keyboard opening and closing.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    if (isMobilePlatform && mounted) setState(() {});
  }

  @override
  void dispose() {
    // A published row would otherwise outlive this field, floating over
    // whatever replaces it with a dead key handler. The controller defers the
    // write while the tree is locked, which it is here.
    widget.services.keyboardAccessory.clearIfOwner(this);
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onEngineChanged);
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Whether to float the mobile numbers row above the keyboard right now: the
  /// setting is on, we're on a phone/tablet, this field has focus, and a real
  /// on-screen keyboard is up (`virtualKeyboardIsUp`'s >100px threshold ignores
  /// iOS's thin hardware-keyboard accessory bar, ~45–55px).
  ///
  /// Reads the raw `FlutterView`, not MediaQuery: `StatusBarOverlay`
  /// consumes the bottom inset for everything below it, so MediaQuery reports 0
  /// here even with the keyboard up. That is deliberate — it stops every route
  /// reserving the keyboard a second time — but it means "is the keyboard up?"
  /// has to be asked of the view. The raw view has no rebuild dependency, hence
  /// `didChangeMetrics` below.
  bool _shouldShowNumbersRow(BuildContext context) =>
      isMobilePlatform && widget.services.settings.showNumbersRow && _focusNode.hasFocus && virtualKeyboardIsUp(context);

  /// Publishes (or withdraws) this field's numbers row. Written after the
  /// frame, never during build: the overlay that draws it is an ancestor, and
  /// notifying it mid-build would rebuild a widget already being built.
  void _syncNumbersRow(BuildContext context, ThemeData theme) {
    final accessory = widget.services.keyboardAccessory;
    final spec = _shouldShowNumbersRow(context)
        ? KeyboardAccessorySpec(
            onKey: _handleNumberKey,
            extraKey: _numbersRowExtraKey,
            vibrate: widget.services.settings.vibrateNumbersRow,
            backgroundColor: (theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary).toARGB32(),
            foregroundColor: (theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary).toARGB32(),
          )
        : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (spec == null) {
        accessory.clearIfOwner(this);
      } else {
        accessory.publish(this, spec);
      }
    });
  }

  /// The contextual extra key: "/" once a callsign (letters, not just digits)
  /// is being composed — for portable calls like W1AW/P — otherwise ".". Same
  /// rule as the logging panel; null when the extra key is turned off.
  String? get _numbersRowExtraKey {
    if (!widget.services.settings.showExtraInNumbersRow) return null;
    final text = _controller.text;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(text);
    final onlyDigits = RegExp(r'^[0-9]+$').hasMatch(text);
    return (hasLetter && !onlyDigits) ? '/' : '.';
  }

  /// Inserts a tapped numbers-row character at the cursor. Sets the controller
  /// value directly (bypassing the field's input formatters, which is fine —
  /// digits and "/"/"." need no transform), which fires `_onTextChanged` so
  /// the lookup/command interpretation runs just as if it were typed.
  void _handleNumberKey(String key) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.start < 0 ? value.text.length : selection.start;
    final end = selection.end < 0 ? value.text.length : selection.end;
    _controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, key),
      selection: TextSelection.collapsed(offset: start + key.length),
      composing: TextRange.empty,
    );
  }

  /// Enter: run whatever is typed, and — only when nothing ran and the engine
  /// had nothing to say about why — open the full Call Info for the callsign
  /// that was looked up.
  ///
  /// The command wins outright. A callsign that is also a command word must
  /// keep running as a command, and a command that refused (an error on the
  /// message line) has already answered the Enter; opening a panel over either
  /// would bury the answer.
  Future<void> _submit() async {
    // A second Enter while the first is still in `interpretCommand` gets
    // `false` back from the engine's own re-entrancy guard, which is not
    // "nothing ran" — without this, key auto-repeat stacks a Call Info modal
    // on top of another one, and the operator dismisses the same panel twice.
    if (_submitting) return;
    _submitting = true;
    try {
      // Read BEFORE submitting. Enter on this bar clears the field, which
      // resets the lookup state on the way through `_onTextChanged` — so by
      // the time the panel is opened there is nothing left to open it with.
      final info = _engine.callInfo;
      final executed = await _engine.submit();
      // `isError`, not `message != null`: the message line also carries a
      // previous command's confirmation, which `_onTextChanged` deliberately
      // holds until this keystroke's interpretation answers. Reading that as
      // "already answered" would eat an Enter typed inside the window.
      if (!mounted || executed || _engine.isError) return;
      if (info != null) await _openCallInfo(info);
    } finally {
      _submitting = false;
    }
  }

  /// Escape empties the bar, wherever the operator got to — a half-typed
  /// callsign, a command mid-parameter, or an answer still on the line.
  /// Clearing the controller runs the engine's own text handler, so the lookup
  /// state and the message go with it.
  void _clearField() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
  }

  /// The full Call Info panel — the same one the Call Info pane and the ⌘K
  /// dialog render, so what Enter opens here is not a second, thinner view of
  /// the same callsign.
  Future<void> _openCallInfo(CallInfoData info) => showModalPane<void>(
    context,
    title: info.call,
    closeLabel: context.t.common.close,
    // The panel is a ListView and scrolls itself; wrapped in the pane's own
    // scroll view it would sit in unbounded height and lay out blank.
    scrollable: false,
    builder: (context) =>
        CallInfoPanel(operation: operationForCallInfo(widget.services), services: widget.services, call: info.call, guess: info.guess, lookups: info.lookups),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final callInfo = _engine.callInfo;

    final commandMessage = _engine.message;
    // A guess is what the summary draws from; without one there is nothing to
    // paint but the icon and a blank line. Enter still opens the panel, which
    // has the QSO history to show even when no callbook answered.
    final hasSummary = callInfo?.guess != null;
    final hasContent = commandMessage != null || hasSummary;

    // The Home Scaffold doesn't resize for the keyboard, so this bar
    // reserves the bottom safe area itself below the field (and the numbers
    // row, when shown), and its Material fills that strip so the teal forms
    // the home-indicator strip. NOT the keyboard: `StatusBarOverlay` reserves
    // that for the whole app so the status footer rides above it instead of
    // hiding, which means the space this bar is given already ends above the
    // keyboard. And nothing at all while the keyboard is up, since it covers
    // the home indicator: the strip the overlay is already holding back IS
    // that space.
    //
    // Nothing either while the status footer is drawn: it paints over that
    // same strip and holds it with a `SafeArea` of its own. The shell takes
    // the inset out of the MediaQuery this reads whenever that is so (see
    // `HomeRailShell.bottomInsetHeldByChrome`), so this follows it from there
    // rather than deciding for itself.
    //
    // The keyboard question goes to the raw view, not MediaQuery — the overlay
    // consumes that inset on the way down precisely so no route reserves it
    // twice, which also means MediaQuery reports 0 here in both states and
    // could not tell them apart.
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final keyboardUp = view.viewInsets.bottom > 0;
    final bottomReserve = keyboardUp ? 0.0 : mq.padding.bottom;
    _syncNumbersRow(context, theme);

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clearField},
      child: Material(
        elevation: 8,
        color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasContent)
              Container(
                width: double.infinity,
                padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (commandMessage != null)
                      Row(
                        children: [
                          if (_engine.isError) ...[Icon(MdiIcons.alertCircle, size: 16, color: theme.colorScheme.onPrimary), const SizedBox(width: Space.md)],
                          Expanded(
                            child: MarkdownBody(
                              data: commandMessage,
                              styleSheet: withEmojiFallback(
                                MarkdownStyleSheet.fromTheme(theme).copyWith(
                                  p: theme.textTheme.bodyLarge?.copyWith(
                                    color: _engine.isConfirmation ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // The very widget the logging panel's info area is, so a
                    // callsign reads the same in both places. No distance line:
                    // Home has no operation, so there is no location to measure
                    // from, and no scoring keys for the same reason — see
                    // `CommandEngine.lookupLocationLine`.
                    if (commandMessage == null && hasSummary)
                      InkWell(
                        onTap: () => _openCallInfo(callInfo),
                        child: CallInfoSummary(
                          data: callInfo!,
                          locationLine: _engine.lookupLocationLine,
                          workedBeforeLabel: (times) => workedBeforeLabel(context, times),
                          foregroundColor: theme.colorScheme.onPrimary,
                          iconColor: theme.colorScheme.onPrimary,
                          linkColor: theme.colorScheme.onPrimary,
                          onOpenLink: openExternalUrl,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: PaneSafeArea.symmetricOf(context, horizontal: 16, vertical: 8),
              // One chrome row exactly, rather than whatever a dense
              // `InputDecoration` and a prefix icon happen to measure. [heightOf]
              // is what the rail's Settings cap is built to and what the window's
              // chrome budget reserves, and both are wrong the moment this bar
              // is a few pixels off it — a cap that does not line up with the bar
              // beside it reads as one of them being misaligned.
              child: SizedBox(
                height: LayoutDensity.chromeHeightOf(context),
                // A callsign field that keeps focus after Enter — see
                // keyboard_dismiss.dart.
                child: TapToDismissEmptyField(
                  focusNode: _focusNode,
                  controller: _controller,
                  child: TextField(
                    selectAllOnFocus: false,
                    controller: _controller,
                    focusNode: _focusNode,
                    style: haloMonoStyle(context, fontSize: 15),
                    // The formatters own casing, not the keyboard: a soft keyboard's
                    // capitalization is fixed when the input connection opens and is not
                    // re-sent on rebuild, so a mode chosen here could never follow the
                    // text turning from a callsign into a command mid-typing.
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: commandFieldFormatters,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      prefixIcon: const Icon(MdiIcons.magnify),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(MdiIcons.close, semanticLabel: context.t.common.clear),
                              onPressed: () {
                                _controller.clear();
                              },
                            )
                          : null,
                      hintText: context.t.home.quickLookup,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.0), borderSide: BorderSide.none),
                    ),
                    // Not onSubmitted: the default TextInputAction.done handling
                    // unfocuses (closing the keyboard) before onSubmitted even
                    // runs. onEditingComplete replaces that default entirely, so
                    // the field keeps focus for the next command.
                    onEditingComplete: _submit,
                  ),
                ),
              ),
            ),
            // The numbers row is not drawn here — it is published to
            // `StatusBarOverlay`, which draws it below the status footer and
            // directly on the keyboard (see `_syncNumbersRow`). Same reason as
            // the logging panel: the footer is one level up, so no route can put
            // itself under it.
            if (bottomReserve > 0) SizedBox(width: double.infinity, height: bottomReserve),
          ],
        ),
      ),
    );
  }
}
