// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The logging panel's entry row: the callsign, the fields that follow it
// (the reports, the contest exchanges, state, grid) and the log button, laid
// out against whatever width the panel has — or, while an event row is being
// edited, [EventFieldRow] in the fields' place. The panel owns the
// controllers and focus nodes, decides which fields are on and builds the
// button; this widget decides where everything sits and how wide it is
// (docs/design/logging-fields.md § "The three parts", and the squeeze
// concessions [resolveMainFieldLayout] makes when the row is short of room).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:halo_i18n/halo_i18n.dart';

import 'call_field_text.dart';
import 'logging_controls_command.dart';
import 'logging_controls_exchange.dart';
import 'logging_controls_metrics.dart';
import 'platform_chrome.dart';
import 'rebuild_between_frames.dart';
import 'semantic_id.dart';
import 'text_formatters.dart';

/// A main field as the panel hands it over: its text and its focus. Which
/// controller is which never changes; only whether and where it is drawn.
typedef MainFieldSlot = ({TextEditingController controller, FocusNode focus});

/// A report field, with the label the panel resolved for it — the panel
/// keeps the Sent/Rcvd order (`switchSentRcvd`) so every surface that shows
/// the pair reads it from the one place.
typedef RstFieldSlot = ({FocusNode focus, TextEditingController controller, String label});

/// The entry row. See the file comment.
class LoggingEntryRow extends StatefulWidget {
  const LoggingEntryRow({
    super.key,
    required this.call,
    required this.rstFields,
    required this.rstPlaceholder,
    required this.numericKeyboardType,
    required this.exchange,
    required this.textControls,
    required this.state,
    required this.stateHint,
    required this.onStateChanged,
    required this.grid,
    required this.gridHint,
    required this.onGridChanged,
    required this.command,
    required this.virtualSpace,
    required this.commandVirtualSpace,
    required this.enabled,
    required this.leftieMode,
    required this.buttonWidth,
    required this.submitButton,
    required this.eventFields,
    required this.onSubmitted,
    required this.onExchangeSubmitted,
    this.onCallTyped,
  });

  /// The callsign field — `Expanded` over whatever the others leave it, and
  /// never squeezed.
  final MainFieldSlot call;

  /// The report fields in display order, or empty when the panel shows none.
  final List<RstFieldSlot> rstFields;

  /// The hint a blank report field shows, or null while editing a saved
  /// record (there a blank field is stored data, not a stand-in).
  final String? rstPlaceholder;

  /// The keyboard for the numeric-leaning fields (the reports, numeric
  /// exchanges) where the platform wants one — null keeps the field's
  /// default. See the panel's `_numbersAndPunctuationOnIOS`.
  final TextInputType? numericKeyboardType;

  /// The contest exchange fields, inline right after the reports, and the
  /// controls that declare them — see the panel's `_textControls` for why
  /// they are primary fields.
  final ExchangeFieldsModel exchange;
  final Iterable<Map<String, dynamic>> textControls;

  /// The State and Grid fields, null when the panel doesn't show them, with
  /// the guessed value (from a callsign lookup) each shows as a faint
  /// placeholder while empty — never pre-filled as a real value.
  final MainFieldSlot? state;
  final String? stateHint;
  final ValueChanged<String> onStateChanged;
  final MainFieldSlot? grid;
  final String? gridHint;
  final ValueChanged<String> onGridChanged;

  /// Whether the call field is in a command's free-text mode, which changes
  /// what it accepts and how it capitalizes.
  final CommandInterpretationModel command;

  /// The on-screen-keyboard Space interceptors: [virtualSpace] on every
  /// primary field, [commandVirtualSpace] on the call field in command
  /// free-text mode — see [VirtualSpaceFormatter].
  final VirtualSpaceFormatter virtualSpace;
  final VirtualSpaceFormatter commandVirtualSpace;

  /// False while the form is locked (a staged or already-deleted row).
  final bool enabled;

  /// Log button on the left, for a left-handed operator.
  final bool leftieMode;

  /// The log button's width — its measured diameter, or the first-frame
  /// fallback — which the row is reserved against.
  final double buttonWidth;

  /// The log button itself, built by the panel (it measures it, decides
  /// whether it is enabled and colours it).
  final Widget submitButton;

  /// When set, an event row is being edited: it takes the fields' place, and
  /// none of the QSO fields are built. See [EventFieldRow].
  final Widget? eventFields;

  /// Enter in the call field or a fixed field: log.
  final VoidCallback onSubmitted;

  /// Enter in an exchange field, which may be picking a suggestion instead.
  final VoidCallback onExchangeSubmitted;

  /// The operator's own edit of the call field — see
  /// [LoggingSession.onCallTyped].
  final VoidCallback? onCallTyped;

  @override
  State<LoggingEntryRow> createState() => _LoggingEntryRowState();
}

class _LoggingEntryRowState extends State<LoggingEntryRow> with RebuildsBetweenFrames {
  /// Whether the last layout couldn't give every main field its declared
  /// minimum ([resolveMainFieldLayout]). A squeezed row hands the focused
  /// field its full width back, which only happens if a focus change
  /// rebuilds — and off a squeezed row it would be a rebuild that changes
  /// nothing, so the focus listener is gated on this.
  bool _squeezed = false;

  /// The trailing fields' focus nodes this row listens to. They are the
  /// panel's and the exchange model's — never disposed here.
  final _watched = <FocusNode>{};

  @override
  void dispose() {
    _watchFields(const []);
    super.dispose();
  }

  /// Re-registered from inside layout, over the fields the row is about to
  /// build — never from a widget update. A layout is the only place a field
  /// is known to exist: asking the exchange model for a node outside one
  /// mints an orphan with no context (a panel kept alive in a hidden tab
  /// updates without laying out), which focus traversal null-checks while
  /// sorting. The set is small and the listener only marks dirty, so it is
  /// replaced whole rather than diffed.
  void _watchFields(List<MainField> fields) {
    for (final node in _watched) {
      node.removeListener(_onFieldFocusChanged);
    }
    _watched
      ..clear()
      ..addAll(fields.map((f) => f.focusNode));
    for (final node in _watched) {
      node.addListener(_onFieldFocusChanged);
    }
  }

  void _onFieldFocusChanged() {
    if (_squeezed) rebuildBetweenFrames();
  }

  /// The geometry the row was last laid out against, so a change in the space
  /// available can be told apart from a change in what wants it — see
  /// [_widthDuration].
  (double, double)? _lastRowGeometry;

  /// How long the fields take to reach a new width: [fieldWidthDuration] when
  /// the space available hasn't changed, and **instantly** when it has.
  ///
  /// Animating a resize would be worse, not better. The callsign is `Expanded`
  /// and so is never animated — it takes whatever the others leave, the moment
  /// they leave it. Animate the others through a window drag and the callsign
  /// spends the whole gesture absorbing their lag, jittering while every field
  /// beside it glides. A focus change is the opposite case: nothing else about
  /// the row is moving, so the one field that is should be followed rather than
  /// snapped at.
  ///
  /// [buttonWidth] counts as much as [rowWidth]: it is measured off the
  /// rendered row, so the first frame of a freshly opened panel always resolves
  /// against the fallback and the second against the real thing. Left out, that
  /// correction would animate — the whole row visibly gliding a few pixels
  /// every time the panel appears.
  Duration _widthDuration(double rowWidth, double buttonWidth) {
    final geometry = (rowWidth, buttonWidth);
    final changed = _lastRowGeometry != geometry;
    _lastRowGeometry = geometry;
    return changed ? Duration.zero : fieldWidthDuration;
  }

  /// One of the narrow secondary logging fields — Sent, Rcvd, State, Grid —
  /// which share everything but their controller/label and a couple of
  /// input-shaping knobs. Amateur-radio codes, not prose: stop the
  /// soft keyboard from autocorrecting, spell-checking, suggesting, or
  /// smart-punctuating the value into garbage (autocorrect:false also turns
  /// off iOS spell check; the smart types stop "-" → "–"). Uppercased like
  /// all logging input, and Enter logs.
  ///
  /// [width] and [padding] are resolved by [resolveMainFieldLayout], not
  /// chosen here: [fixedFieldMinWidth] whenever the row has room, and less
  /// when it doesn't.
  Widget _fixedField(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required double width,
    required double padding,
    required Duration duration,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputFormatter? filter,
    String? hintText,

    /// Only for a field that tracks whether the operator has touched it.
    /// Typing already reaches the controller's own listeners, so a field with
    /// nothing extra to record omits this rather than passing a no-op.
    ValueChanged<String>? onChanged,
  }) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        selectAllOnFocus: false,
        enabled: widget.enabled,
        style: mainFieldStyle(context, fontWeight: FontWeight.w500),
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        inputFormatters: [widget.virtualSpace, ?filter, const UpperCaseTextFormatter()],
        decoration: mainFieldDecoration(context, label, hintText: hintText, horizontalPadding: padding),
        onChanged: onChanged,
        onEditingComplete: () => finishEditingWithoutBlur(controller),
        onSubmitted: (_) => widget.onSubmitted(),
      ),
    );
  }

  /// Sent and Rcvd, in the order the operator reads them.
  ///
  /// The gaps belong to the POSITION, not to the field: whichever report comes
  /// first opens the group after the callsign, and the second sits a plain
  /// field gap along from it. Reversing the pair alone would carry the wide
  /// gap into the middle of it.
  List<MainField> _rstMainFields(BuildContext context) => [
    for (final (index, field) in widget.rstFields.indexed)
      (
        gapBefore: index == 0 ? mainFieldGroupGap : mainFieldGap,
        minWidth: fixedFieldMinWidth,
        focusNode: field.focus,
        build: (width, padding, duration) => _fixedField(
          context,
          controller: field.controller,
          focusNode: field.focus,
          label: field.label,
          width: width,
          padding: padding,
          duration: duration,
          // Letters are legitimate in RSTs (CW's "5NN" shorthand, aurora
          // "59A") and the Edit QSO pane accepts them — a digits-only
          // filter here would silently strip a pane-saved letter on the
          // next keystroke, since filtering formatters re-run over the
          // whole text.
          keyboardType: widget.numericKeyboardType,
          filter: FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z+\-]')),
          hintText: widget.rstPlaceholder,
        ),
      ),
  ];

  /// The main logging fields that follow the callsign, in row order.
  ///
  /// The single source of truth for both [resolveMainFieldLayout] and the row
  /// that renders them in [build], so a field can never be in the layout
  /// arithmetic and missing from the row (or the reverse) — the same drift
  /// the panel's `_primaryFields` exists to prevent for the keyboard, and the
  /// same order.
  ///
  /// The callsign is deliberately not here: it is `Expanded` over whatever
  /// these leave it, and it is never squeezed.
  List<MainField> _trailingMainFields(BuildContext context) => [
    ..._rstMainFields(context),
    // Contest exchanges, inline right after the RSTs.
    for (final control in widget.textControls)
      (
        gapBefore: mainFieldGap,
        minWidth: exchangeFieldMinWidth,
        focusNode: widget.exchange.focusFor(control['key'] as String),
        build: (width, padding, duration) => ExchangeField(
          model: widget.exchange,
          control: control,
          enabled: widget.enabled,
          width: width,
          padding: padding,
          duration: duration,
          virtualSpace: widget.virtualSpace,
          numericKeyboardType: widget.numericKeyboardType,
          onSubmitted: widget.onExchangeSubmitted,
        ),
      ),
    if (widget.state case final state?)
      (
        gapBefore: mainFieldGroupGap,
        minWidth: fixedFieldMinWidth,
        focusNode: state.focus,
        build: (width, padding, duration) => _fixedField(
          context,
          controller: state.controller,
          focusNode: state.focus,
          label: t.qsoEditForm.theirState,
          width: width,
          padding: padding,
          duration: duration,
          textCapitalization: TextCapitalization.characters,
          hintText: widget.stateHint,
          onChanged: widget.onStateChanged,
        ),
      ),
    if (widget.grid case final grid?)
      (
        gapBefore: mainFieldGroupGap,
        minWidth: fixedFieldMinWidth,
        focusNode: grid.focus,
        build: (width, padding, duration) => _fixedField(
          context,
          controller: grid.controller,
          focusNode: grid.focus,
          label: t.qsoEditForm.theirGrid,
          width: width,
          padding: padding,
          duration: duration,
          textCapitalization: TextCapitalization.characters,
          hintText: widget.gridHint,
          onChanged: widget.onGridChanged,
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    // A LayoutBuilder OUTSIDE the IntrinsicHeight below, never within it: a
    // LayoutBuilder cannot answer an intrinsic-dimension query, and
    // IntrinsicHeight asks its whole subtree one. Out here it sees exactly
    // the width the Row will get, which is all `resolveMainFieldLayout`
    // needs.
    return LayoutBuilder(
      builder: (context, constraints) {
        final command = widget.command;

        // An event/annotation row has no callsign or exchange — just a kind
        // label and, for NOTE/TODO, the text (and done state) the annotation
        // commands wrote. Swap the whole main-fields row for that instead of
        // running it through `_trailingMainFields`/`resolveMainFieldLayout`,
        // which only make sense for a QSO's field set.
        if (widget.eventFields case final eventFields?) {
          _watchFields(const []);
          return _withButton([Expanded(child: eventFields)], gapScale: 1);
        }

        final trailingFields = _trailingMainFields(context);
        _watchFields(trailingFields);
        final (layout: fieldLayout, :squeezed) = resolveMainFieldLayout(
          fields: trailingFields,
          maxWidth: constraints.maxWidth,
          buttonWidth: widget.buttonWidth,
          floors: mainFieldFloors(context),
        );
        _squeezed = squeezed;
        final widthDuration = _widthDuration(constraints.maxWidth, widget.buttonWidth);

        return _withButton(gapScale: fieldLayout.gapScale, [
          Expanded(
            // #236: stable id for agent/browser tooling.
            child: semanticId(
              'field.call',
              TextField(
                controller: widget.call.controller,
                focusNode: widget.call.focus,
                // Desktop platforms (see selectAllOnFocus's default)
                // select-all on focus by default, which runs *after* the
                // panel's own focus listener and silently overwrites its
                // cursor-at-end placement — this is the only way to
                // actually suppress it.
                selectAllOnFocus: false,
                enabled: widget.enabled,
                // The callsign field is the default focus — except on
                // mobile with no physical keyboard, where the view starts
                // unfocused so the operator isn't met with a virtual
                // keyboard covering half the screen
                // (docs/design/logging-fields.md). Read per build, not
                // watched: the channel's answer normally beats navigation
                // into an operation, and losing that race only costs one
                // tap.
                autofocus: !isMobilePlatform || hardwareKeyboardAttached.value,
                autocorrect: command.mixedCase,
                enableSuggestions: command.mixedCase,
                // A command awaiting parameters (expectsParams) switches
                // the field to free-text entry — spaces allowed, no
                // callsign character restriction — but stays
                // uppercase-only unless the command itself declared
                // `mixedCase: true` (e.g. NOTE, whose parameter is free
                // prose): all logging input is uppercase unless explicitly
                // mixed-case.
                textCapitalization: command.mixedCase ? TextCapitalization.sentences : TextCapitalization.characters,
                // In command free-text modes a space is a literal parameter
                // character, so those modes take the narrower interceptor:
                // it stands aside for every space but the double-space that
                // leaves the field. Normal callsign mode routes every space
                // to focus/command handling. Asked via
                // [CommandInterpretationModel.fieldAcceptsSpaces], the same
                // getter the panel's Space handler uses to decide the exit —
                // the two must never disagree about the field's mode.
                inputFormatters: !command.fieldAcceptsSpaces
                    ? [
                        widget.virtualSpace,
                        FilteringTextInputFormatter.allow(RegExp('[$callsignCharacters]')),
                        if (isMobilePlatform) MobileDotToSlashFormatter(),
                        const UpperCaseTextFormatter(),
                      ]
                    : command.mixedCase
                    ? [widget.commandVirtualSpace]
                    : [widget.commandVirtualSpace, const UpperCaseTextFormatter()],
                style: mainFieldStyle(context, fontWeight: FontWeight.w500),
                decoration: mainFieldDecoration(context, t.loggingControls.theirCall, horizontalPadding: fieldLayout.fieldPadding),
                // `onChanged`, not the controller: it hears only what the
                // operator entered, never the panel's own writes.
                onChanged: widget.onCallTyped == null ? null : (_) => widget.onCallTyped!(),
                onEditingComplete: () => finishEditingWithoutBlur(widget.call.controller),
                onSubmitted: (_) => widget.onSubmitted(),
              ),
            ),
          ),
          // Declared and sized in `_trailingMainFields` /
          // `resolveMainFieldLayout` above, so the row and the width
          // arithmetic can't disagree about which fields are on and how
          // much room they take. The gaps carry the same scale as the
          // padding inside the fields — they are given up together, as one
          // concession.
          for (var i = 0; i < trailingFields.length; i++) ...[
            SizedBox(width: trailingFields[i].gapBefore * fieldLayout.gapScale),
            trailingFields[i].build(fieldLayout.widths[i], fieldLayout.fieldPadding, widthDuration),
          ],
        ]);
      },
    );
  }

  /// The row's frame around [fields]: the log button at the trailing end, or
  /// the leading one for a left-handed operator, a gap along from them.
  ///
  /// IntrinsicHeight + stretch, rather than a guessed pixel height, so the
  /// submit button (an AspectRatio circle) is guaranteed to exactly match
  /// whatever height the text fields actually render at — not an eyeballed
  /// constant that drifts if their font size, padding, or text scale ever
  /// changes.
  ///
  /// The button is keyed HERE, on the widget actually sitting in
  /// `Row.children`, because leftieMode moves it between the Row's first and
  /// last slot: without that key Flutter's positional matching sees a plain,
  /// unkeyed widget at each slot and treats the move as two unrelated widgets
  /// (drop one, mount another) rather than one widget relocating. Harmless on
  /// its own, but doing it while a Dialog route is simultaneously open above
  /// this screen (the settings dialog, for one) corrupts the semantics tree —
  /// `identical(childRenderObject, parentRenderObject)` asserting in
  /// RenderObject.computeChildGeometry — a live crash toggling Leftie Mode
  /// from that dialog. A key the panel put on the button would not do: it is
  /// this Row that moves it.
  Widget _withButton(List<Widget> fields, {required double gapScale}) {
    final button = KeyedSubtree(key: const ValueKey('logging-controls-submit-button'), child: widget.submitButton);
    final gap = SizedBox(width: logButtonGap * gapScale);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.leftieMode) ...[button, gap],
          ...fields,
          if (!widget.leftieMode) ...[gap, button],
        ],
      ),
    );
  }
}
