// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The Logs view's editor for the selected QSO, pinned above the table.

part of '../logs_view.dart';

/// The edit form for whichever QSO is selected, pinned above the list — the
/// same relationship `LoggingControls` has with the operation view's
/// `QsoList`, adopted here for the same reason: pulling the
/// form out of the row is what lets the row keep a fixed extent (see
/// [_QsoListPanel]'s doc comment). Keyed by the caller on `qso.uuid`, so a
/// fresh selection remounts this with fresh controllers rather than reusing
/// the previous QSO's — no live update arriving mid-edit can overwrite what
/// the operator is typing, because there is no `didUpdateWidget` path that
/// re-seeds an existing instance at all.
///
/// Enter saves and Esc discards while one of its fields has focus; anything
/// else that would close it asks first when it holds an edit ([isDirty],
/// read by `_LogsViewState._settleEditor`).
class _LogQsoEditPanel extends StatefulWidget {
  final HaLoServices services;
  final Qso qso;
  final VoidCallback onDone;

  const _LogQsoEditPanel({super.key, required this.services, required this.qso, required this.onDone});

  @override
  State<_LogQsoEditPanel> createState() => _LogQsoEditPanelState();
}

class _LogQsoEditPanelState extends State<_LogQsoEditPanel> {
  late final TextEditingController _call;
  late final TextEditingController _date;
  late final TextEditingController _time;
  late final TextEditingController _freqOrBand;
  late final TextEditingController _mode;

  /// What [_mode] was seeded with — the DISPLAYED mode, which for a contact
  /// stating neither a frequency nor a band collapses a stored sideband to
  /// `SSB` with nothing to resolve it back from. Saving that would take the
  /// sideband out of the log, so an untouched field keeps what was stored.
  late final String _modeSeed;
  late final TextEditingController _sentRst;
  late final TextEditingController _rcvdRst;
  late final TextEditingController _name;
  late final TextEditingController _grid;
  late final TextEditingController _state;
  late final TextEditingController _notes;

  /// What each field was seeded with, to tell an edit from a field merely
  /// showing a value. Name, grid and state can show the lookup's guess
  /// rather than anything stored; written back untouched, the guess would
  /// become the operator's own statement and stop following the lookup.
  late final Map<TextEditingController, String> _seeds;

  final _callFocus = FocusNode(debugLabel: 'logsEditCall');

  /// Watched once, not per build: a stream made in `build` would be
  /// resubscribed on every keystroke's rebuild. Null for a QSO in no
  /// operation.
  late final Stream<Operation?>? _operationStream = widget.qso.operationUuid.isEmpty
      ? null
      : widget.services.operations.watchOperation(widget.qso.operationUuid);
  bool _saving = false;

  /// Set while Delete has been tapped but not yet saved — mirrors
  /// LoggingControls' `_pendingDelete`: staged, fields locked, and the save
  /// button becomes the actual delete until Undo puts it back.
  bool _pendingDelete = false;

  /// The row as this panel loaded it — the snapshot the controllers were
  /// seeded from, and the `basedOn` the save passes. `widget.qso` cannot
  /// serve: the parent re-resolves it by uuid from the watched stream on
  /// every build, so after a sync pull lands mid-edit it IS the new row —
  /// its stamp equals the stored one, and update()'s concurrent-edit merge
  /// would self-disable in exactly the case it exists for.
  late final Qso _loadedQso;

  @override
  void initState() {
    super.initState();
    final qso = _loadedQso = widget.qso;
    final start = qso.startAtMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(qso.startAtMillis!, isUtc: true);
    _call = TextEditingController(text: qso.theirCall);
    _date = TextEditingController(text: start == null ? '' : _dateFormat.format(start));
    _time = TextEditingController(text: start == null ? '' : _timeFormat.format(start));
    // kHz, seeded by the same formatter the logging panel's own frequency
    // field uses — and, critically, the inverse of the `parseFreq` that reads
    // this box back on save. A hand-built MHz string is not: it writes a
    // period whatever the operator's Number Formatting setting says, so on a
    // locale whose decimal is a comma `14.285` reads back as grouped kHz and
    // the QSO is saved three orders of magnitude off, having never been
    // touched. `fmtFreqInput` also emits no thousands separator at all, which
    // is what keeps 1296 MHz from parsing as 1296 kHz.
    _freqOrBand = TextEditingController(text: qso.freq != null ? fmtFreqInput(qso.freq!) : (qso.band ?? ''));
    // The mode as the row above shows it, or the dialog would read `LSB`
    // under a row reading `SSB`. Resolved again on save, against the seed
    // kept here so an untouched field cannot write the collapse back.
    _modeSeed = displayMode(qso.mode, freqKHz: qso.freq, band: qso.band) ?? '';
    _mode = TextEditingController(text: _modeSeed);
    _sentRst = TextEditingController(text: qso.sentRST ?? '');
    _rcvdRst = TextEditingController(text: qso.receivedRST ?? '');
    _name = TextEditingController(text: qso.theirName ?? '');
    _grid = TextEditingController(text: _theirGridText(qso));
    _state = TextEditingController(text: qso.theirState ?? '');
    _notes = TextEditingController(text: qso.notes ?? '');
    _seeds = {for (final controller in _controllers) controller: controller.text};
  }

  List<TextEditingController> get _controllers => [_call, _date, _time, _freqOrBand, _mode, _sentRst, _rcvdRst, _name, _grid, _state, _notes];

  bool _touched(TextEditingController controller) => controller.text != _seeds[controller];

  /// Whether closing now would lose something: a changed field, or a delete
  /// staged but not yet committed.
  bool get isDirty => _pendingDelete || _controllers.any(_touched);

  /// The write in flight, if any: a second [commit] joins it rather than
  /// writing the edit twice, and `_LogsViewState._settleEditor` waits on it
  /// rather than ask about an edit that is already on its way to the log.
  Future<bool>? get inFlight => _inFlight;
  Future<bool>? _inFlight;

  /// Whether what is pending is a staged delete, which Save commits.
  bool get isDeleting => _pendingDelete;

  /// Where Enter from the list lands.
  void focusFirstField() => _callFocus.requestFocus();

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _callFocus.dispose();
    super.dispose();
  }

  /// `null` when the typed date/time doesn't parse — the save then keeps
  /// whatever `startAtMillis` the QSO already had rather than blanking it.
  int? _parsedStartAtMillis() {
    try {
      final dateParts = _date.text.trim().split('-').map(int.parse).toList();
      final timeParts = _time.text.trim().split(':').map(int.parse).toList();
      final parsed = DateTime.utc(dateParts[0], dateParts[1], dateParts[2], timeParts[0], timeParts[1]);
      // DateTime.utc normalizes out-of-range components (e.g. day 30 in
      // February) instead of throwing — round-tripping catches what the
      // FormatException/RangeError guards below can't.
      final roundTrips =
          parsed.year == dateParts[0] &&
          parsed.month == dateParts[1] &&
          parsed.day == dateParts[2] &&
          parsed.hour == timeParts[0] &&
          parsed.minute == timeParts[1];
      return roundTrips ? parsed.millisecondsSinceEpoch : null;
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// Saves the edit, or commits the staged delete — whichever the Save
  /// button would do right now. False when the write failed, which the
  /// status bar has already said; the editor stays open with what was typed.
  Future<bool> commit() => _inFlight ??= (_pendingDelete ? _delete() : _save()).whenComplete(() {
    _inFlight = null;
  });

  Future<void> _commitAndClose() async {
    if (_saving) return;
    if (await commit() && mounted) widget.onDone();
  }

  Future<bool> _save() async {
    // Composed from the SNAPSHOT the form was seeded from, not the live
    // `widget.qso` — the edit is "what the operator saw plus what they
    // typed", and update()'s merge below reconciles it against whatever the
    // row holds by now.
    final qso = _loadedQso;
    // Taken before the write: the editor can be gone by the time it fails,
    // and the operator still has to hear that it did.
    final statusBar = widget.services.statusBar;
    final t = context.t;
    setState(() => _saving = true);
    try {
      final their = <String, dynamic>{...?asQsonMap(qso.data['their'])};
      final our = <String, dynamic>{...?asQsonMap(qso.data['our'])};
      their['call'] = _call.text.trim().toUpperCase();
      their['sent'] = _rcvdRst.text.trim();
      our['sent'] = _sentRst.text.trim();
      // Only what was edited, and then even when emptied: an empty value
      // stored is the operator clearing the lookup's guess, which a removed
      // key would bring straight back (see [_seeds]).
      if (_touched(_name)) their['name'] = _name.text.trim();
      if (_touched(_state)) their['state'] = _state.text.trim().toUpperCase();
      final grid = _grid.text.trim();
      // Only a locator that is one, or an emptied field; anything else
      // changes nothing, the rule the date and frequency follow below.
      // Stored, "FN3" would name no square and — through the pair written
      // with it — erase the coordinate the QSO had.
      if (_touched(_grid) && (grid.isEmpty || isWellFormedGrid(grid))) {
        // A stated grid replaces the pair in the same write, with the
        // square's own center — a leftover coordinate would outrank it
        // everywhere it is read (docs/design/locations.md). `locSource`
        // goes too, or it would go on tagging a pair it no longer describes.
        final center = locationForStatedGrid(grid);
        their['grid'] = normalizeGrid(grid);
        their['lat'] = center?.latitude;
        their['lon'] = center?.longitude;
        their['locSource'] = null;
      }
      final startAtMillis = _parsedStartAtMillis() ?? qso.startAtMillis;
      final freqOrBand = _freqOrBand.text.trim();
      // Same parsing the main logging fields use — [parseFreq] accepts kHz or
      // MHz-with-decimal, [parseBandInput] a band name when it isn't a
      // frequency at all. Both keys are always written (one to its parsed
      // value, the other to null) rather than only the one that matched: the
      // `...qso.data` spread below carries the OLD value of both forward, so
      // a band-only edit that only set `band` would leave the QSO's old
      // `freq` in place — and the row and edit form both prefer `freq` when
      // it's present, so the edit would look like it silently didn't take.
      final parsedFreqKHz = parseFreq(freqOrBand);
      final parsedBand = parsedFreqKHz == null ? parseBandInput(freqOrBand) : null;
      // Neither parsed — text that names no frequency and no band, e.g. a
      // stray character or an accidental clear — keeps the QSO's existing
      // values rather than wiping both to null; same "unparseable input
      // changes nothing" rule `_parsedStartAtMillis` follows below.
      final freqFieldUnparseable = parsedFreqKHz == null && parsedBand == null;
      final updated = Qso(
        uuid: qso.uuid,
        operationUuid: qso.operationUuid,
        data: {
          ...qso.data,
          'their': their,
          'our': our,
          'freq': freqFieldUnparseable ? qso.freq : parsedFreqKHz,
          'band': freqFieldUnparseable ? qso.band : parsedBand,
          // Resolved against the freq/band this save settles on, like every
          // other mode a person types: a typed `SSB` is not a mode a radio can
          // be in, and storing it would put a generic mode in a log the rest
          // of the app keeps concrete.
          'mode': (() {
            final typed = _mode.text.trim().toUpperCase();
            final freq = freqFieldUnparseable ? qso.freq : parsedFreqKHz;
            final band = freqFieldUnparseable ? qso.band : parsedBand;
            // Nothing to resolve against, and the field was never touched:
            // the seed is a collapsed view of the stored mode, so writing it
            // through would swap a recorded `LSB` for a generic `SSB` that no
            // frequency can ever turn back.
            if (expectedSideband(freqKHz: freq, band: band) == null) {
              return typed == _modeSeed ? (qso.mode ?? typed) : typed;
            }
            return resolveSideband(typed, freq, band: band) ?? typed;
          })(),
          'notes': _notes.text,
          'startAtMillis': ?startAtMillis,
        },
        scoreCache: qso.scoreCache,
      );
      // `basedOn` is the same snapshot: if a sync pull moved the row while
      // the panel sat open, only the fields edited here overwrite it (see
      // mergeConcurrentEdit).
      await widget.services.qsos.update(updated, basedOn: _loadedQso);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsQsoEdit:save');
      statusBar.showNotice(
        key: 'logsQsoEdit:save',
        text: t.loggingControls.saveFailed(error: e),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    return true;
  }

  Future<bool> _delete() async {
    // Taken before the write, as in [_save].
    final statusBar = widget.services.statusBar;
    final t = context.t;
    setState(() => _saving = true);
    try {
      await widget.services.qsos.softDelete(widget.qso);
    } catch (e, stack) {
      ErrorReportingService.report(e, stack, context: 'logsQsoEdit:delete');
      statusBar.showNotice(
        key: 'logsQsoEdit:delete',
        text: t.loggingControls.deleteFailed(error: e),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    // Bottom border only, unlike the row's own symmetric accent — this
    // panel is pinned above the pane's own top edge, not sitting directly
    // under a row (a long list scrolls the selected row out of view while
    // this stays put), so only the edge shared with the scrolling list
    // below needs marking.
    return Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: _buildPanel(context, theme, t));
  }

  /// Enter saves from a text field, and only from one: on a focused button
  /// Enter is the button's own activation — the delete button's Undo, the
  /// operation button — and taking it here would save instead, or on Undo
  /// commit the very delete being undone. Plain Enter only, so Shift+Enter
  /// still reaches the notes field as a new line. Esc discards from
  /// anywhere in the panel, but not mid-write: closing then would leave a
  /// failure with no editor to report it against.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (!_saving) widget.onDone();
      return KeyEventResult.handled;
    }
    final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final inField = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;
    final keyboard = HardwareKeyboard.instance;
    final modified = keyboard.isShiftPressed || keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed;
    if (!enter || !inField || modified) return KeyEventResult.ignored;
    unawaited(_commitAndClose());
    return KeyEventResult.handled;
  }

  Widget _buildPanel(BuildContext context, ThemeData theme, Translations t) {
    return Material(
      color: theme.colorScheme.secondaryContainer,
      elevation: 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.secondary, width: 3)),
        ),
        child: Padding(
          // Room above the first row for its fields' floating labels, which
          // sit on the top edge of each outline.
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_pendingDelete)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Text(
                    isMobilePlatform ? t.loggingControls.pendingDeleteTapWarning : t.loggingControls.pendingDeleteClickWarning,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w700),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _field(t.loggingControls.theirCall, _call, width: 140, focusNode: _callFocus),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.date, _date, width: 110),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.timeUtc, _time, width: 90),
                  const Spacer(),
                  _saveButton(theme),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _field(t.loggingControls.frequency, _freqOrBand, width: 100),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.mode, _mode, width: 90),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.sent, _sentRst, width: 70),
                  const SizedBox(width: Space.md),
                  _field(t.loggingControls.rcvd, _rcvdRst, width: 70),
                  const Spacer(),
                  _deleteButton(context, theme),
                ],
              ),
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _textField(t.qsoEditForm.theirName, _name)),
                  const SizedBox(width: Space.md),
                  _field(t.qsoEditForm.theirGrid, _grid, width: 100),
                  const SizedBox(width: Space.md),
                  _field(t.qsoEditForm.theirState, _state, width: 90),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _notes,
                enabled: !_pendingDelete,
                readOnly: _saving,
                decoration: _fieldDecoration(context, t.qsoEditForm.notes),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: Space.md),
              Align(alignment: AlignmentDirectional.centerStart, child: _operationButton(context, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {required double width, FocusNode? focusNode}) => SizedBox(
    width: width,
    child: _textField(label, controller, focusNode: focusNode),
  );

  Widget _textField(String label, TextEditingController controller, {FocusNode? focusNode}) =>
      // Read-only mid-write: what is typed then isn't in the write, and the
      // editor closes when it lands.
      TextField(controller: controller, focusNode: focusNode, enabled: !_pendingDelete, readOnly: _saving, decoration: _fieldDecoration(context, label));

  /// The operation the QSO belongs to, as the button that opens it — in a
  /// log that spans every operation, where it leads is worth saying. A QSO
  /// in none has nowhere to go, so it says that instead of offering a
  /// button.
  ///
  /// Named by the title alone: Flutter web lays a button's name out as DOM
  /// text inside it with its overflow showing, and one run together with
  /// "open operation" could wrap out of the button onto what lies below.
  Widget _operationButton(BuildContext context, ThemeData theme) {
    final foreground = theme.colorScheme.onSecondaryContainer;
    final stream = _operationStream;
    if (stream == null) {
      return Text(
        context.t.home.logs.noOperation,
        style: theme.textTheme.bodyMedium?.copyWith(color: foreground, fontStyle: FontStyle.italic),
      );
    }
    return StreamBuilder<Operation?>(
      stream: stream,
      builder: (context, snapshot) {
        final operation = snapshot.data;
        // Nothing until the row arrives, rather than a placeholder title
        // flashing first.
        if (operation == null) return const SizedBox(height: kMinInteractiveDimension);
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: foreground),
          icon: const Icon(MdiIcons.openInNew),
          iconAlignment: IconAlignment.end,
          // The station call leads, the way the operation list shows it:
          // across every operation it is the first thing that tells them
          // apart.
          label: Text.rich(
            TextSpan(
              children: [
                if (operation.stationCall.isNotEmpty) ...[
                  TextSpan(
                    text: operation.stationCall,
                    style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: ' '),
                ],
                TextSpan(text: displayTitleFor(context, operation)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () => Navigator.of(context).push(slideInFromRight<void>((_) => OperationView(services: widget.services, operationUuid: operation.uuid))),
        );
      },
    );
  }

  /// Filled, matching the one documented "fields need a background"
  /// convention in the app (`LoggingControls`' secondary-fields panel, which
  /// paints its fields on `colorScheme.surface` regardless of the panel's
  /// own tinted background) — this panel's own background is the selection
  /// tint, same reasoning applies.
  InputDecoration _fieldDecoration(BuildContext context, String label) =>
      InputDecoration(labelText: label, isDense: true, filled: true, fillColor: Theme.of(context).colorScheme.surface, border: const OutlineInputBorder());

  /// Same circular, `secondary`-filled button `LoggingControls` shows while
  /// editing (there it's a `tertiary`→`secondary` theme remap; here the
  /// panel's own accent already IS secondary, so this just paints straight
  /// from it). Becomes the actual delete action while [_pendingDelete].
  Widget _saveButton(ThemeData theme) {
    const diameter = 44.0;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        onPressed: _saving ? null : _commitAndClose,
        child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            // Same 60%-of-diameter sizing the delete button below uses —
            // `Icon`'s own default (24) reads small against a 44px button.
            : Icon(_pendingDelete ? MdiIcons.trashCan : MdiIcons.contentSave, size: diameter * 0.6),
      ),
    );
  }

  /// Delete → staged (`_pendingDelete = true`, nothing written yet) → Save
  /// commits the delete, or Undo (this same slot) drops the stage — the same
  /// three-state cycle `LoggingControls` runs its own delete button through.
  /// Icon-only, at the exact footprint the logging panel gives its own
  /// wipe/delete button (`LoggingActionButton`, in
  /// `logging_controls_info_frame.dart`): a `SizedBox`-authoritative
  /// 44×44 box, zero internal padding, an icon at 60% of that diameter —
  /// not `IconButton`'s own default constraints, which run smaller.
  Widget _deleteButton(BuildContext context, ThemeData theme) {
    const diameter = 44.0;
    final t = context.t.loggingControls;
    final IconData icon;
    final String label;
    final VoidCallback onPressed;
    if (_pendingDelete) {
      icon = MdiIcons.undo;
      label = t.undoDelete;
      onPressed = () => setState(() => _pendingDelete = false);
    } else {
      icon = MdiIcons.trashCanOutline;
      label = context.t.common.delete;
      onPressed = () => setState(() => _pendingDelete = true);
    }
    return SizedBox(
      width: diameter,
      height: diameter,
      child: IconButton(
        icon: Icon(icon, semanticLabel: label),
        iconSize: diameter * 0.6,
        padding: EdgeInsets.zero,
        color: theme.colorScheme.secondary,
        // Mid-write the stage it would flip is already decided: an Undo then
        // would be overridden by the delete landing, and a delete staged
        // during a save would close with the editor unasked.
        onPressed: _saving ? null : onPressed,
      ),
    );
  }
}
