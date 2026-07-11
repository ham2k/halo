// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry controls — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7), ported from app-polo:
//   Enter   logs the QSO from anywhere in the controls
//   Esc     wipes the current entry
//   Space   in the call field: runs command shortcuts (frequency, band,
//           mode — "14285 ", "20m ", "cw ") or advances to Sent;
//           in Sent/Rcvd: advances focus, cycling back to the call
//   focus   always returns to the callsign field after log/wipe;
//           Sent/Rcvd select-all on focus so typing replaces
//
// Frequency/band/mode and the QSO timestamp live behind the secondary
// control row (see secondary_control_row.dart) rather than as
// permanently-visible fields — this is app-polo's SecondaryExchangePanel
// pattern: a chip always shows a compact summary of the control's current
// value ("20m • SSB", a live-ticking "17:06:49z" clock), and tapping it
// expands the actual editable fields. This is what lets extensions keep
// contributing controls (POTA's park reference today, more activities
// later) without the controls' permanent footprint growing — only one
// control is expanded at a time. Command shortcuts still work while a
// control is collapsed, since they mutate the same underlying state the
// expanded fields edit.
//
// Everything here is pure Dart/Flutter; extensions only get debounced,
// async involvement (lookups, ref decoration) off the keystroke path.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'form_renderer.dart';
import 'icon_resolver.dart';
import 'mdi_icons.dart';
import 'ref_chips_input.dart';
import 'secondary_control_row.dart';
import 'theme.dart';

/// Async callsign enrichment (name, location, grid…) from lookup sources.
/// Returning null means "nothing known". Must never throw.
typedef CallLookup = Future<Map<String, dynamic>?> Function(String call);

/// Tries the input as an extension-registered command (band/freq/mode
/// shortcuts, and eventually spotting/operator commands). Returns a
/// field-change map (`{freq?, band?, mode?}`) or a named `{action: ...}`
/// (e.g. `SYNCALL`), or null for "not a command". Must never throw.
typedef CommandInterpreter = Future<Map<String, dynamic>?> Function(
  String input, [
  Map<String, dynamic>? operation,
  Map<String, dynamic>? qso,
]);

/// Handles a named command action — a closed set the core recognizes, not
/// arbitrary state (DESIGN.md §4). `params` carries whatever JSON payload
/// came with that action (e.g. `devNotice`'s icon/title/text).
typedef CommandActionHandler = Future<void> Function(String action, [Map<String, dynamic>? params]);

class LoggingControls extends StatefulWidget {
  final Operation operation;
  final QsosRepository qsosRepository;

  /// Current QSOs in the operation, used for dupe hints.
  final List<Qso> qsos;
  final void Function(Qso qso)? onLogged;

  /// Optional lookup enrichment; fired debounced, off the keystroke path.
  final CallLookup? lookup;

  /// Declarative activity control descriptors from extensions (UI catalog).
  /// v0 supports `input.kind == 'refList'`; each becomes a chip in the
  /// secondary control row alongside the built-in Time and Radio controls.
  final List<Map<String, dynamic>> activityControls;

  /// Async ref decoration via the extension runtime.
  final RefDecorator? decorateRef;

  /// Extension-backed command shortcuts, tried on space in the call field.
  /// When null, space in the call field just advances focus.
  final CommandInterpreter? interpretCommand;

  final void Function(String? message)? onCommandMessageChanged;

  /// Handles a command's named `action` (e.g. `SYNCALL`), when the command
  /// returns one instead of a field change. When null, actions are ignored.
  final CommandActionHandler? onCommandAction;

  /// When set, the controls are editing this already-logged QSO rather than
  /// composing a new one — fields are populated from it, saving calls
  /// `qsosRepository.update` instead of `.add`, and Delete/Revert become
  /// available. The Time control's behavior already depended on the
  /// distinction before this: editing an existing entry shows *its*
  /// recorded time instead of a live clock, and has no "Now" reset (there's
  /// no "automatic" time to reset back to for a historical record).
  final Qso? editingQso;

  /// Fires when an editing session ends without necessarily going through
  /// `onLogged` — a save of an existing QSO, a delete, or an explicit
  /// revert. The caller (which owns the selected-QSO state) clears its
  /// selection in response; this widget's own fields reset via
  /// `didUpdateWidget` once `editingQso` becomes null on the next build.
  final VoidCallback? onEditCanceled;

  /// Settings engine interface.
  final SyncSettings? settings;

  final String? timeLabel;
  final String? dateLabel;
  final String? nowLabel;
  final String? freqLabel;
  final String? modeLabel;
  final String? dupeLabel;
  final String? theirCallLabel;
  final String? sentLabel;
  final String? rcvdLabel;
  final String? moreLabel;
  final String? revertLabel;
  final String? deleteLabel;
  final String? undoDeleteLabel;
  final String? wipeLabel;
  final String? undoLabel;
  final String? pendingDeleteWarning;
  final String? qsoEditFormTitle;
  final String? theirNameLabel;
  final String? theirGridLabel;
  final String? notesLabel;
  final String? bandLabel;

  const LoggingControls({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.qsos = const [],
    this.onLogged,
    this.lookup,
    this.activityControls = const [],
    this.decorateRef,
    this.interpretCommand,
    this.onCommandMessageChanged,
    this.onCommandAction,
    this.editingQso,
    this.onEditCanceled,
    this.settings,
    this.timeLabel,
    this.dateLabel,
    this.nowLabel,
    this.freqLabel,
    this.modeLabel,
    this.dupeLabel,
    this.theirCallLabel,
    this.sentLabel,
    this.rcvdLabel,
    this.moreLabel,
    this.revertLabel,
    this.deleteLabel,
    this.undoDeleteLabel,
    this.wipeLabel,
    this.undoLabel,
    this.pendingDeleteWarning,
    this.qsoEditFormTitle,
    this.theirNameLabel,
    this.theirGridLabel,
    this.notesLabel,
    this.bandLabel,
  });

  @override
  State<LoggingControls> createState() => _LoggingControlsState();
}

class _LoggingControlsState extends State<LoggingControls> {
  final _callController = TextEditingController();
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _freqController = TextEditingController();
  final _timeController = TextEditingController();
  final _dateController = TextEditingController();
  final _callFocus = FocusNode();
  final _sentFocus = FocusNode();
  final _rcvdFocus = FocusNode();
  final _freqFocus = FocusNode();
  final _timeFocus = FocusNode();

  String _mode = 'SSB';

  /// Band set via a "20m " command when no frequency is entered.
  String? _manualBand;
  bool _rstsTouched = false;

  /// Which secondary control (if any) currently has its input expanded.
  String? _selectedControlKey;

  /// Overrides the QSO's timestamp when set via the Time control; null
  /// means "use the current time at the moment of logging."
  int? _manualStartAtMillis;

  /// Ticks once a second so the Time chip shows a live clock while nothing
  /// overrides it — only runs while it's actually needed (see
  /// _updateClockTicker), not for the whole panel's lifetime.
  Timer? _clockTicker;

  Timer? _lookupDebounce;
  String? _lookupFor;
  Map<String, dynamic>? _lookupResult;

  Map<String, dynamic>? _currentInterpretation;
  Timer? _commandDescribeDebounce;
  Timer? _executeMessageTimer;
  String? _commandMessage;
  final Map<String, dynamic> _currentQsoExtra = {};

  /// Refs entered via activity controls for the QSO being composed,
  /// keyed by control key.
  final Map<String, List<Map<String, dynamic>>> _controlRefs = {};

  /// Refs from `editingQso.refs` whose `type` matched no currently
  /// registered activity control — round-tripped back into `refs` on save
  /// rather than silently dropped, even though no UI can show them.
  List<Map<String, dynamic>> _unmatchedRefs = const [];

  /// Set while editing an existing QSO and Delete has been tapped but not
  /// yet saved — mirrors app-polo's `_willBeDeleted` staged-delete flag.
  bool _pendingDelete = false;

  /// Their name/grid overrides, settable only via the "More" edit dialog —
  /// deliberately not full inline fields, to avoid growing the primary
  /// controls' footprint for rarely-edited data.
  String? _theirNameOverride;
  String? _theirGridOverride;

  /// True while `didUpdateWidget` is populating controllers from a newly
  /// selected `editingQso` — suppresses `_onCallChanged`'s lookup/command
  /// side effects, which would otherwise re-query and overwrite stored
  /// `their.*` fields for a call that's already known.
  bool _populating = false;

  /// A wiped-but-not-yet-lost new QSO, stashed by the wipe button so the
  /// same button can flip to "undo" for a few seconds afterward. Only
  /// meaningful while composing a new QSO (`editingQso == null`).
  Map<String, dynamic>? _undoQsoData;
  Timer? _undoExpireTimer;

  /// Guards against double-logging: Enter is bound both as a keyboard
  /// shortcut and as every field's onSubmitted, and can also auto-repeat.
  bool _isLogging = false;

  /// The submit button's rendered diameter, measured post-frame (its own
  /// size comes from IntrinsicHeight/AspectRatio further down the tree, so
  /// it isn't known until after layout) and reused to size the info row's
  /// second button identically — see _buildWipeOrEditButton.
  final GlobalKey _submitButtonKey = GlobalKey();
  double? _editButtonDiameter;

  void _scheduleSubmitButtonMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = _submitButtonKey.currentContext?.size;
      if (size != null && (_editButtonDiameter == null || (size.height - _editButtonDiameter!).abs() > 0.5)) {
        setState(() => _editButtonDiameter = size.height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _applyDefaultRSTs();
    // Population normally happens in didUpdateWidget, as editingQso
    // transitions from null to a selected QSO — but if this widget is ever
    // constructed with editingQso already set (rather than transitioning
    // into it), that transition never fires. Applying it here too, before
    // any listeners are attached below, covers that case for free with no
    // risk of triggering their side effects.
    if (widget.editingQso != null) _applyFieldsFromData(widget.editingQso!.data);
    _seedTimeFields();
    _updateClockTicker();
    _callController.addListener(_onCallChanged);
    _freqController.addListener(_onFreqChanged);
    _timeController.addListener(_onTimeOrDateFieldChanged);
    _dateController.addListener(_onTimeOrDateFieldChanged);
    // Sent/Rcvd don't otherwise need a rebuild on every keystroke, but the
    // info row's second button (_buildWipeOrEditButton) re-evaluates
    // _qsoDataChanged() on every build, which reads these controllers —
    // without a rebuild, editing just the RST wouldn't flip that button
    // from "delete" to "revert changes".
    _sentController.addListener(_onSentOrRcvdChanged);
    _rcvdController.addListener(_onSentOrRcvdChanged);
    // Exchange fields select-all on focus, so typing replaces the default.
    for (final (focus, controller) in [
      (_sentFocus, _sentController),
      (_rcvdFocus, _rcvdController),
      (_freqFocus, _freqController),
      (_timeFocus, _timeController),
    ]) {
      focus.addListener(() {
        if (focus.hasFocus) {
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(LoggingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingQso?.uuid != widget.editingQso?.uuid) {
      _pendingDelete = false;
      _theirNameOverride = null;
      _theirGridOverride = null;
      _undoExpireTimer?.cancel();
      _undoExpireTimer = null;
      _undoQsoData = null;
      if (widget.editingQso != null) {
        _populateFromEditingQso(widget.editingQso!);
      } else {
        _resetLocalFields();
      }
      _updateClockTicker();
    }
  }

  /// Populates controllers/state from an existing QSO selected for editing.
  /// Local-state only — never calls parent-notifying callbacks (this runs
  /// from `didUpdateWidget`, where a synchronous `setState` back up the
  /// tree could throw).
  void _populateFromEditingQso(Qso qso) {
    _populating = true;
    _applyFieldsFromData(qso.data);
    _manualStartAtMillis = null; // _effectiveStartAtMillis falls back to editingQso.startAtMillis
    setState(() {});
    _populating = false;
  }

  /// Shared by `_populateFromEditingQso` (loading an existing record for
  /// editing) and `_restoreFromUndoSlot` (undoing a wipe) — both need to
  /// push a `data` map from a `Qso`/`_getCurrentQsoData()` shape back into
  /// the live controllers/state.
  void _applyFieldsFromData(Map<String, dynamic> data) {
    final our = data['our'] as Map<String, dynamic>? ?? const {};
    final their = data['their'] as Map<String, dynamic>? ?? const {};
    _callController.text = (their['call'] as String?) ?? '';
    _sentController.text = (our['sent'] as String?) ?? '';
    _rcvdController.text = (their['sent'] as String?) ?? '';
    _rstsTouched = true;
    final freq = (data['freq'] as num?)?.toDouble();
    _freqController.text = freq != null ? fmtFreq(freq).replaceAll(',', '') : '';
    _mode = data['mode'] as String? ?? _mode;
    _manualBand = freq == null ? data['band'] as String? : null;
    _currentQsoExtra
      ..clear()
      ..addAll(data)
      ..remove('refs')
      ..remove('our')
      ..remove('their')
      ..remove('freq')
      ..remove('band')
      ..remove('mode')
      ..remove('startAtMillis');
    _controlRefs.clear();
    _unmatchedRefs = [];
    final refs = (data['refs'] as List?)?.whereType<Map>().map((r) => r.cast<String, dynamic>()) ?? const [];
    for (final ref in refs) {
      final control = widget.activityControls.firstWhere(
        (c) => (c['input'] as Map?)?['refType'] == ref['type'],
        orElse: () => const {},
      );
      final key = control['key'] as String?;
      if (key != null) {
        (_controlRefs[key] ??= []).add(ref);
      } else {
        _unmatchedRefs.add(ref);
      }
    }
    _lookupFor = null;
    _lookupResult = null;
    _selectedControlKey = null;
  }

  /// Clears local fields when an editing session ends (mirrors the
  /// local-state portion of `_wipe()`, without `_wipe()`'s parent callback —
  /// see `didUpdateWidget`).
  void _resetLocalFields() {
    // Guards _onCallChanged (fired synchronously by _callController.clear()
    // below) from calling widget.onCommandMessageChanged — a parent-state
    // setState — while still inside didUpdateWidget.
    _populating = true;
    _callController.clear();
    _applyDefaultRSTs();
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupFor = null;
    _lookupResult = null;
    _controlRefs.clear();
    _unmatchedRefs = [];
    _currentQsoExtra.clear();
    _manualStartAtMillis = null;
    _manualBand = null;
    _selectedControlKey = null;
    setState(() {
      _commandMessage = null;
      _currentInterpretation = null;
    });
    _populating = false;
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _undoExpireTimer?.cancel();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _timeController.dispose();
    _dateController.dispose();
    _callFocus.dispose();
    _sentFocus.dispose();
    _rcvdFocus.dispose();
    _freqFocus.dispose();
    _timeFocus.dispose();
    super.dispose();
  }

  String get _call => _callController.text.trim().toUpperCase();
  double? get _freq => parseFreq(_freqController.text);
  String? get _band => _freq != null ? bandForFrequency(_freq!) : _manualBand;
  bool get _canLog => looksLikeCallsign(_call);

  bool get _isDupe => widget.qsos.any(
    (qso) =>
        qso.theirCall == _call &&
        qso.mode == _mode &&
        (qso.band ?? '') == (_band ?? ''),
  );

  void _onFreqChanged() {
    if (_freq != null) _manualBand = null;
    setState(() {});
  }

  void _onSentOrRcvdChanged() => setState(() {});

  void _applyDefaultRSTs() {
    _sentController.text = defaultRSTFor(_mode);
    _rcvdController.text = defaultRSTFor(_mode);
    _rstsTouched = false;
  }

  void _setMode(String mode) {
    setState(() {
      _mode = mode;
      if (!_rstsTouched) _applyDefaultRSTs();
    });
  }

  // ---- Secondary control row ----

  void _onSelectControl(String? key) {
    if (key == 'more') {
      _openMoreEditor();
      return;
    }
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _seedTimeFields();
      _selectedControlKey = key;
    });
  }

  /// Shared look for the primary logging row (Their call/Sent/Rcvd) — same
  /// font size and field padding across all three, and the label always
  /// pinned to the top-left corner (not the "large placeholder until
  /// focused" default) so the row's shape doesn't shift as you type. Built
  /// on the app-wide poloFieldDecoration (theme.dart), tinted to read
  /// against this panel's tertiaryContainer background.
  TextStyle _primaryFieldStyle(BuildContext context, {required FontWeight fontWeight}) =>
      haloMonoStyle(context, fontSize: 15, fontWeight: fontWeight);

  InputDecoration _primaryFieldDecoration(BuildContext context, String label) => poloFieldDecoration(
        context,
        label,
        labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
      );

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  String _fmtTimeWithSeconds(DateTime dt) =>
      '${_fmtTime(dt)}:${dt.second.toString().padLeft(2, '0')}';
  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// The best-known timestamp for the entry being composed/edited: a manual
  /// override if one's been set, else the existing QSO's recorded time when
  /// editing one, else null — meaning "still automatic, tracks live now."
  int? get _effectiveStartAtMillis => _manualStartAtMillis ?? widget.editingQso?.startAtMillis;

  /// (Re-)populates the time/date fields from [_effectiveStartAtMillis], or
  /// from the current time if that's null — called whenever the Time
  /// control is opened, so it never shows a stale snapshot from an earlier
  /// open.
  void _seedTimeFields() {
    final millis = _effectiveStartAtMillis;
    final dt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : DateTime.now().toUtc();
    _timeController.text = _fmtTime(dt);
    _dateController.text = _fmtDate(dt);
  }

  void _onTimeOrDateFieldChanged() {
    final time = _timeController.text.split(':');
    final date = _dateController.text.split('-');
    if (time.length != 2 || date.length != 3) return;
    final hour = int.tryParse(time[0]);
    final minute = int.tryParse(time[1]);
    final year = int.tryParse(date[0]);
    final month = int.tryParse(date[1]);
    final day = int.tryParse(date[2]);
    if (hour == null || minute == null || year == null || month == null || day == null) {
      return;
    }
    setState(() {
      _manualStartAtMillis = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
      _updateClockTicker();
    });
  }

  void _resetTimeToNow() {
    setState(() {
      _manualStartAtMillis = null;
      _seedTimeFields();
      _updateClockTicker();
    });
  }

  /// Starts or stops the live-clock ticker to match whether the Time chip
  /// currently needs one — only while nothing overrides the timestamp and
  /// we're not editing an existing (necessarily historical) QSO.
  void _updateClockTicker() {
    final needsTicking = _effectiveStartAtMillis == null;
    if (needsTicking && _clockTicker == null) {
      _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!needsTicking && _clockTicker != null) {
      _clockTicker!.cancel();
      _clockTicker = null;
    }
  }

  String get _timeSummary {
    final millis = _effectiveStartAtMillis;
    if (millis == null) {
      return '${_fmtTimeWithSeconds(DateTime.now().toUtc())}z';
    }
    return '${_fmtTime(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true))}z';
  }

  String get _radioSummary {
    final parts = <String>[
      _freq != null ? fmtFreq(_freq!) : (_band ?? 'Band???'),
    ];
    parts.add(_mode);
    return parts.join(' • ');
  }

  List<SecondaryControlSpec> _buildSecondaryControls(
    ThemeData theme,
    HaLoColors poloColors,
  ) {
    return [
      SecondaryControlSpec(
        key: 'time',
        icon: MdiIcons.clockOutline,
        summary: _timeSummary,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 74,
              child: TextField(
                controller: _timeController,
                focusNode: _timeFocus,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.timeLabel ?? 'Time (UTC)',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _dateController,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.dateLabel ?? 'Date',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
              ),
            ),
            // Only offer to reset back to automatic timestamping while
            // composing a new QSO with a manual override in effect — there's
            // no "automatic" time to reset to when editing an existing,
            // necessarily historical, entry.
            if (widget.editingQso == null && _manualStartAtMillis != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: _resetTimeToNow, child: Text(widget.nowLabel ?? 'Now')),
            ],
          ],
        ),
      ),
      SecondaryControlSpec(
        key: 'radio',
        icon: MdiIcons.radio,
        summary: _radioSummary,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              child: TextField(
                controller: _freqController,
                focusNode: _freqFocus,
                style: haloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: poloFieldDecoration(
                  context,
                  widget.freqLabel ?? 'Freq kHz',
                  labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onSubmitted: (_) => _log(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: Text(
                _band ?? '',
                style: haloMonoStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _band == null
                      ? theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.6,
                        )
                      : Color.lerp(
                          poloColors.bandColor(_band!),
                          theme.colorScheme.onTertiaryContainer,
                          0.25,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            DropdownMenu<String>(
              initialSelection: _mode,
              label: Text(widget.modeLabel ?? 'Mode'),
              width: 104,
              textStyle: haloMonoStyle(
                context,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                floatingLabelStyle: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                contentPadding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              ),
              dropdownMenuEntries: [
                for (final m in modes) DropdownMenuEntry(value: m, label: m),
              ],
              onSelected: (value) {
                if (value == null) return;
                _setMode(value);
                _callFocus.requestFocus();
              },
            ),
          ],
        ),
      ),
      for (final control in widget.activityControls)
        if ((control['input'] as Map?)?['kind'] == 'refList')
          SecondaryControlSpec(
            key: control['key'] as String,
            icon: resolveIconName(control['icon'] as String?),
            summary: (control['label'] as String?) ?? control['key'] as String,
            expandedBuilder: (context) => RefChipsInput(
              refType: (control['input'] as Map)['refType'] as String,
              label: (control['label'] as String?) ?? '',
              placeholder: (control['input'] as Map)['placeholder'] as String?,
              pattern: (control['input'] as Map)['pattern'] as String?,
              refs: _controlRefs[control['key']] ?? const [],
              onChanged: (refs) =>
                  setState(() => _controlRefs[control['key'] as String] = refs),
              decorate: widget.decorateRef,
              dense: true,
              labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
          ),
      SecondaryControlSpec(
        key: 'more',
        icon: resolveIconName('pencil'),
        summary: widget.moreLabel ?? 'More',
        // Never actually shown — _onSelectControl special-cases 'more' to
        // open the full-edit dialog instead of expanding inline.
        expandedBuilder: (context) => const SizedBox.shrink(),
      ),
    ];
  }

  // ---- Command shortcuts ----
  //
  // Space in the call field first tries the text as an extension command
  // (band/frequency/mode shortcuts live in the `radio-commands` extension;
  // see docs/extensions/hooks.md's `command` category). This is a real bridge
  // round-trip, not a Dart regex — command matching and frequency parsing
  // are extension/domain-library territory, not core UI territory.

  Future<void> _handleSpace() async {
    if (_callFocus.hasFocus) {
      final call = _call;
      if (call.isNotEmpty) {
        _sentFocus.requestFocus();
      }
    } else if (_sentFocus.hasFocus) {
      _rcvdFocus.requestFocus();
    } else if (_rcvdFocus.hasFocus || _freqFocus.hasFocus) {
      _callFocus.requestFocus();
    }
    // Space in other fields (e.g. activity ref inputs) is deliberately inert.
  }

  Future<void> _dispatchActions(List<dynamic> actions) async {
    for (final action in actions) {
      if (action is! Map) continue;
      final map = action.cast<String, dynamic>();

      if (map.containsKey('setVfo')) {
        final params = map['setVfo'] as Map;
        setState(() {
          final freq = params['freq'];
          final band = params['band'];
          final mode = params['mode'];
          if (freq is num) {
            _freqController.text = fmtFreq(
              freq.toDouble(),
            ).replaceAll(',', '');
            _manualBand = null;
          } else if (band is String) {
            _manualBand = band;
            _freqController.clear();
          }
          if (mode is String) {
            _mode = mode;
            if (!_rstsTouched) _applyDefaultRSTs();
          }
          _selectedControlKey = 'radio';
        });
      } else if (map.containsKey('updateQso')) {
        final params = (map['updateQso'] as Map).cast<String, dynamic>();
        setState(() {
          _currentQsoExtra.addAll(params);
        });
      } else if (map.containsKey('addQso')) {
        final params = (map['addQso'] as Map).cast<String, dynamic>();
        final qso = await widget.qsosRepository.add(widget.operation.uuid, params);
        widget.onLogged?.call(qso);
      } else if (map.containsKey('updateSettings')) {
        final params = (map['updateSettings'] as Map).cast<String, dynamic>();
        if (widget.settings != null) {
          if (params.containsKey('developerMode')) {
            await widget.settings!.setDeveloperMode(params['developerMode'] as bool);
          }
        }
      } else if (map.containsKey('syncAll')) {
        await widget.onCommandAction?.call('syncAll');
      } else if (map.containsKey('sendSpots')) {
        debugPrint('[extensions] sendSpots action: ${map['sendSpots']}');
      } else if (map['devNotice'] is Map) {
        await widget.onCommandAction?.call('devNotice', (map['devNotice'] as Map).cast<String, dynamic>());
      } else if (map['devStatus'] is Map) {
        await widget.onCommandAction?.call('devStatus', (map['devStatus'] as Map).cast<String, dynamic>());
      } else if (map['devProgress'] is Map) {
        await widget.onCommandAction?.call('devProgress', (map['devProgress'] as Map).cast<String, dynamic>());
      }
    }
  }

  Map<String, dynamic> _getCurrentQsoData() {
    final base = widget.editingQso?.data ?? const <String, dynamic>{};
    final refs = [
      for (final list in _controlRefs.values) ...list,
      ..._unmatchedRefs,
    ];
    return {
      ...base,
      // Unconditional (not `if (refs.isNotEmpty)`/`if (_freq != null)`):
      // `base` may already carry a non-empty value for these from the
      // record being edited, and a merge-style `...base` above won't drop
      // a stale one just because the live value is now empty/null — these
      // have to actively overwrite every time, including with null/empty,
      // for clearing a ref/freq/band during an edit to actually stick.
      'refs': refs,
      'our': {
        ...?(base['our'] as Map<String, dynamic>?),
        'call': widget.operation.stationCall,
        'sent': _sentController.text.trim(),
      },
      'their': {
        ...?(base['their'] as Map<String, dynamic>?),
        if (_theirNameOverride != null) 'name': _theirNameOverride,
        if (_theirGridOverride != null) 'grid': _theirGridOverride,
        'call': _call,
        'sent': _rcvdController.text.trim(),
        if (_lookupFor == _call && _lookupResult != null) ..._lookupResult!,
      },
      'freq': _freq,
      'band': _band,
      'mode': _mode,
      if (_effectiveStartAtMillis != null) 'startAtMillis': _effectiveStartAtMillis,
      ..._currentQsoExtra,
    };
  }

  // ---- "More" full-edit dialog ----
  //
  // A secondary control that bypasses the usual inline-expand behavior
  // (special-cased in _onSelectControl) to open a dialog covering fields
  // the primary/secondary controls don't otherwise expose: their name,
  // grid, and notes. Reuses the existing FormRenderer/showFormDialog
  // engine (see form_renderer.dart) rather than a new navigation route.

  Map<String, dynamic> _buildQsoEditFormDefinition() {
    return {
      'title': widget.qsoEditFormTitle ?? 'Edit QSO',
      'elements': [
        {'type': 'field', 'key': 'theirCall', 'fieldType': 'callsign', 'label': widget.theirCallLabel ?? 'Their call'},
        {'type': 'field', 'key': 'theirName', 'fieldType': 'text', 'label': widget.theirNameLabel ?? 'Name'},
        {'type': 'field', 'key': 'theirGrid', 'fieldType': 'text', 'label': widget.theirGridLabel ?? 'Grid'},
        {'type': 'field', 'key': 'sent', 'fieldType': 'text', 'label': widget.sentLabel ?? 'Sent'},
        {'type': 'field', 'key': 'rcvd', 'fieldType': 'text', 'label': widget.rcvdLabel ?? 'Rcvd'},
        {'type': 'field', 'key': 'freq', 'fieldType': 'number', 'label': widget.freqLabel ?? 'Freq kHz'},
        {'type': 'field', 'key': 'band', 'fieldType': 'text', 'label': widget.bandLabel ?? 'Band'},
        {
          'type': 'field',
          'key': 'mode',
          'fieldType': 'select',
          'label': widget.modeLabel ?? 'Mode',
          'options': [for (final m in modes) {'value': m, 'label': m}],
        },
        {'type': 'field', 'key': 'date', 'fieldType': 'text', 'label': widget.dateLabel ?? 'Date'},
        {'type': 'field', 'key': 'time', 'fieldType': 'text', 'label': widget.timeLabel ?? 'Time (UTC)'},
        {'type': 'field', 'key': 'notes', 'fieldType': 'multiline', 'label': widget.notesLabel ?? 'Notes'},
      ],
    };
  }

  Future<void> _openMoreEditor() async {
    final millis = _effectiveStartAtMillis;
    final dt = millis != null
        ? DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
        : DateTime.now().toUtc();

    final result = await showFormDialog(
      context,
      formDefinition: _buildQsoEditFormDefinition(),
      initialState: {
        'theirCall': _call,
        'theirName': _theirNameOverride ?? widget.editingQso?.theirName ?? '',
        'theirGrid': _theirGridOverride ?? widget.editingQso?.theirGrid ?? '',
        'sent': _sentController.text.trim(),
        'rcvd': _rcvdController.text.trim(),
        'freq': _freq,
        'band': _band ?? '',
        'mode': _mode,
        'date': _fmtDate(dt),
        'time': _fmtTime(dt),
        'notes': (_currentQsoExtra['notes'] as String?) ?? '',
      },
      onChange: (key, value, state) async {
        // Freq wins over a manually-typed band, matching _onFreqChanged's
        // existing precedence for the inline Radio control.
        if (key == 'freq' && value is num) {
          final band = bandForFrequency(value.toDouble());
          if (band != null) return {'band': band};
        }
        return null;
      },
    );
    if (result == null || !mounted) return;

    setState(() {
      _callController.text = ((result['theirCall'] as String?) ?? '').toUpperCase();
      final name = (result['theirName'] as String?)?.trim();
      _theirNameOverride = (name == null || name.isEmpty) ? null : name;
      final grid = (result['theirGrid'] as String?)?.trim();
      _theirGridOverride = (grid == null || grid.isEmpty) ? null : grid;
      _sentController.text = (result['sent'] as String?) ?? '';
      _rcvdController.text = (result['rcvd'] as String?) ?? '';
      _rstsTouched = true;

      final freq = result['freq'];
      if (freq is num) {
        _freqController.text = fmtFreq(freq.toDouble()).replaceAll(',', '');
        _manualBand = null;
      } else {
        _freqController.clear();
        final band = (result['band'] as String?)?.trim();
        _manualBand = (band == null || band.isEmpty) ? null : band;
      }

      _mode = (result['mode'] as String?) ?? _mode;

      final dateParts = ((result['date'] as String?) ?? '').split('-');
      final timeParts = ((result['time'] as String?) ?? '').split(':');
      if (dateParts.length == 3 && timeParts.length == 2) {
        final year = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final day = int.tryParse(dateParts[2]);
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (year != null && month != null && day != null && hour != null && minute != null) {
          _manualStartAtMillis = DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;
        }
      }

      final notes = ((result['notes'] as String?) ?? '').trim();
      if (notes.isEmpty) {
        _currentQsoExtra.remove('notes');
      } else {
        _currentQsoExtra['notes'] = notes;
      }

      _seedTimeFields();
      _updateClockTicker();
    });
  }

  // ---- Lookup enrichment ----

  void _onCallChanged() {
    if (_populating) return;
    setState(() {});
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    
    // Clear any active execution confirmation message when the user types
    _executeMessageTimer?.cancel();
    _currentInterpretation = null;
    _commandMessage = null;
    widget.onCommandMessageChanged?.call(null);

    final call = _call;
    if (call.isEmpty) {
      if (_lookupFor != null) {
        setState(() {
          _lookupFor = null;
          _lookupResult = null;
        });
      }
      return;
    }

    // Command shortcuts only apply while composing a new QSO — see _log().
    if (widget.editingQso == null && widget.interpretCommand != null) {
      _commandDescribeDebounce = Timer(const Duration(milliseconds: 150), () async {
        final qsoData = _getCurrentQsoData();
        final result = await widget.interpretCommand!(
          call,
          widget.operation.data,
          qsoData,
        );
        if (!mounted || _call != call) return;
        setState(() {
          _currentInterpretation = result;
          if (result != null && result['describe'] is String) {
            _commandMessage = result['describe'] as String;
          } else {
            _commandMessage = null;
          }
        });
        widget.onCommandMessageChanged?.call(_commandMessage);
      });
    }

    if (widget.lookup == null) return;
    if (_lookupFor == call) return;
    if (!looksLikeCallsign(call)) {
      setState(() {
        _lookupFor = null;
        _lookupResult = null;
      });
      return;
    }

    _lookupDebounce = Timer(const Duration(milliseconds: 300), () async {
      final result = await widget.lookup!(call);
      if (!mounted || _call != call) return; // stale — the call changed
      setState(() {
        _lookupFor = call;
        _lookupResult = result;
      });
    });
  }

  String? get _lookupLine {
    final result = _lookupResult;
    if (result == null || _lookupFor != _call) return null;
    final location = [
      result['city'],
      result['state'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final parts = [
      result['name'],
      location.isEmpty ? null : location,
      result['country'],
      result['grid'],
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  // ---- Logging ----

  void _wipe() {
    _callController.clear();
    _applyDefaultRSTs();
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
    _lookupFor = null;
    _lookupResult = null;
    _controlRefs.clear();
    _currentQsoExtra.clear();
    _manualStartAtMillis = null;
    _selectedControlKey = null;
    _callFocus.requestFocus();
    setState(() {
      _commandMessage = null;
      _currentInterpretation = null;
      _updateClockTicker();
    });
    widget.onCommandMessageChanged?.call(null);
  }

  // ---- Wipe/undo, delete/undo, revert-changes: the info row's second button ----

  /// Whether the in-progress new QSO has anything actually worth wiping —
  /// the wipe button stays visible but disabled when this is false.
  bool get _hasComposedValues =>
      _call.isNotEmpty ||
      _freqController.text.trim().isNotEmpty ||
      _manualBand != null ||
      _manualStartAtMillis != null ||
      _controlRefs.values.any((refs) => refs.isNotEmpty) ||
      _unmatchedRefs.isNotEmpty ||
      _currentQsoExtra.isNotEmpty;

  /// Stashes the in-progress new QSO into the undo slot (for 5 seconds,
  /// even if the user keeps typing — see `_buildWipeOrEditButton`), then
  /// wipes the form.
  void _handleWipeTap() {
    _undoQsoData = _getCurrentQsoData();
    _undoExpireTimer?.cancel();
    _undoExpireTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _undoQsoData = null);
    });
    _wipe();
  }

  void _restoreFromUndoSlot() {
    final data = _undoQsoData;
    if (data == null) return;
    _undoExpireTimer?.cancel();
    _undoExpireTimer = null;
    _populating = true;
    _applyFieldsFromData(data);
    _manualStartAtMillis = data['startAtMillis'] as int?;
    _undoQsoData = null;
    setState(() => _updateClockTicker());
    _populating = false;
  }

  /// Deep, order-insensitive-for-lists equality — used to detect whether
  /// the fields being edited still match the stored record. Lists compare
  /// as multisets (via sorted JSON) rather than element-by-element, since
  /// `refs` is the only list-valued field here and its order is an
  /// artifact of how `_controlRefs` iterates, not a meaningful edit. A key
  /// missing entirely, an empty Map/List/String, and an explicit null all
  /// count as equivalent — `_getCurrentQsoData()` always emits fields like
  /// `their.sent`/`mode`/`freq`/`band`/`refs`, even when blank/null/empty,
  /// but a record with nothing recorded there yet might simply lack the
  /// key, which isn't a meaningful edit either.
  bool _deepEquals(dynamic a, dynamic b) {
    if (_isEmptyish(a) && _isEmptyish(b)) return true;
    if (a is Map || b is Map) {
      final ma = a is Map ? a : const {};
      final mb = b is Map ? b : const {};
      for (final key in {...ma.keys, ...mb.keys}) {
        if (!_deepEquals(ma[key], mb[key])) return false;
      }
      return true;
    }
    if (a is List || b is List) {
      final la = a is List ? a : const [];
      final lb = b is List ? b : const [];
      if (la.length != lb.length) return false;
      final sa = la.map(jsonEncode).toList()..sort();
      final sb = lb.map(jsonEncode).toList()..sort();
      for (var i = 0; i < sa.length; i++) {
        if (sa[i] != sb[i]) return false;
      }
      return true;
    }
    return a == b;
  }

  bool _isEmptyish(dynamic v) =>
      v == null ||
      (v is String && v.isEmpty) ||
      (v is Map && v.isEmpty) ||
      (v is List && v.isEmpty);

  /// Whether the fields being edited differ from the stored record — drives
  /// the "revert changes" vs. "delete" state of the info row's second
  /// button while editing.
  bool _qsoDataChanged() {
    final editingQso = widget.editingQso;
    if (editingQso == null) return false;
    return !_deepEquals(_getCurrentQsoData(), editingQso.data);
  }

  /// The info row's second (no-background) button — a single control whose
  /// icon/action depends on whether we're composing a new QSO or editing
  /// an existing one, per the state machine in the class doc comment above.
  Widget _buildWipeOrEditButton(ThemeData accentTheme) {
    final editingQso = widget.editingQso;
    final IconData icon;
    final String? tooltip;
    final VoidCallback? onPressed;

    if (editingQso == null) {
      if (_undoQsoData != null) {
        icon = resolveIconName('undo');
        tooltip = widget.undoLabel ?? 'Undo';
        onPressed = _restoreFromUndoSlot;
      } else {
        icon = resolveIconName('backspace-outline');
        tooltip = widget.wipeLabel ?? 'Wipe';
        onPressed = _hasComposedValues ? _handleWipeTap : null;
      }
    } else if (_pendingDelete) {
      icon = resolveIconName('undo');
      tooltip = widget.undoDeleteLabel ?? 'Undo delete';
      onPressed = () => setState(() => _pendingDelete = false);
    } else if (_qsoDataChanged()) {
      icon = resolveIconName('undo');
      tooltip = widget.revertLabel ?? 'Revert';
      onPressed = () => _populateFromEditingQso(editingQso);
    } else {
      icon = resolveIconName('trash-can-outline');
      tooltip = widget.deleteLabel ?? 'Delete';
      onPressed = () => setState(() => _pendingDelete = true);
    }

    // Same footprint as the submit button (measured post-frame, since that
    // button's own size is layout-derived — see _editButtonDiameter), no
    // background of its own, and its icon tinted with the color the submit
    // button uses as its *background*, tying the two together visually.
    final diameter = _editButtonDiameter ?? 44;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: accentTheme.colorScheme.tertiary,
        padding: EdgeInsets.zero,
        iconSize: diameter * 0.5 * 1.2,
      ),
    );
  }

  Future<void> _log() async {
    if (_isLogging) return; // already logging this entry; ignore the repeat

    // Check command — shortcuts (band/freq/mode, etc.) only apply while
    // composing a new QSO. A real callsign is exceedingly unlikely to
    // parse as one, but editing an existing entry shouldn't run it through
    // command interpretation at all, least of all while confirming a
    // staged delete.
    final call = _call;
    if (widget.editingQso == null && call.isNotEmpty && widget.interpretCommand != null) {
      _commandDescribeDebounce?.cancel();
      final qsoData = _getCurrentQsoData();
      final interpretation = _currentInterpretation ?? await widget.interpretCommand!(
        call,
        widget.operation.data,
        qsoData,
      );
      if (!mounted) return;
      if (interpretation != null) {
        _isLogging = true;
        try {
          _callController.clear();
          _currentInterpretation = null;
          _executeMessageTimer?.cancel();

          final confirmMarkdown = interpretation['confirm'];
          setState(() {
            _currentInterpretation = null;
            if (confirmMarkdown is String) {
              _commandMessage = confirmMarkdown;
              _executeMessageTimer = Timer(const Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    _commandMessage = null;
                  });
                  widget.onCommandMessageChanged?.call(null);
                }
              });
            } else {
              _commandMessage = null;
            }
          });
          widget.onCommandMessageChanged?.call(_commandMessage);

          final commands = interpretation['commands'];
          if (commands is List) {
            await _dispatchActions(commands);
          }
        } finally {
          _isLogging = false;
        }
        return;
      }
    }

    final editingQso = widget.editingQso;

    if (editingQso != null && _pendingDelete) {
      _isLogging = true;
      try {
        await widget.qsosRepository.softDelete(editingQso);
        widget.onEditCanceled?.call();
      } finally {
        _isLogging = false;
      }
      return;
    }

    if (!_canLog) {
      _callFocus.requestFocus();
      return;
    }
    _isLogging = true;
    try {
      if (editingQso != null) {
        await widget.qsosRepository.update(
          Qso(
            uuid: editingQso.uuid,
            operationUuid: widget.operation.uuid,
            data: _getCurrentQsoData(),
          ),
        );
        widget.onEditCanceled?.call();
      } else {
        final qso = await widget.qsosRepository.add(widget.operation.uuid, _getCurrentQsoData());
        widget.onLogged?.call(qso);
        _wipe();
      }
    } finally {
      _isLogging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSubmitButtonMeasurement();
    final theme = Theme.of(context);
    final poloColors = HaLoColors.of(context);

    // While editing an existing QSO, the panel swaps its tertiary ("new
    // QSO") accent for the secondary ("editing") accent — mirrors
    // app-polo's `themeColor` switching. Only the tertiary* tokens are
    // remapped (not a full ColorScheme swap), so unrelated colors
    // (primary, error) are unaffected. `accentTheme` carries the remapped
    // HaLoColors extension too, so SecondaryControlRow's chips (which read
    // HaLoColors.of(context)/Theme.of(context) ambiently) pick it up.
    final editing = widget.editingQso != null;
    final accentPoloColors = editing
        ? poloColors.copyWith(tertiaryLight: poloColors.secondaryLight)
        : poloColors;
    final accentTheme = editing
        ? theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              tertiary: theme.colorScheme.secondary,
              onTertiary: theme.colorScheme.onSecondary,
              tertiaryContainer: theme.colorScheme.secondaryContainer,
              onTertiaryContainer: theme.colorScheme.onSecondaryContainer,
            ),
            extensions: [accentPoloColors],
          )
        : theme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _wipe,
        const SingleActivator(LogicalKeyboardKey.enter): _log,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _log,
        const SingleActivator(LogicalKeyboardKey.space): _handleSpace,
      },
      child: FocusTraversalGroup(
        child: Material(
          elevation: 4,
          // app-polo's logging panel uses the operation's theme color
          // (tertiary here, secondary while editing) as its background,
          // with a divider line in the same tint separating it from the
          // QSO list above.
          color: accentTheme.colorScheme.tertiaryContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 2, color: accentPoloColors.tertiaryLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                // Scoped so every field's label/underline reads clearly
                // against the tertiary-tinted panel, without touching the
                // rest of the theme (the log button keeps its own
                // deliberate primaryContainer styling below).
                child: Theme(
                  data: accentTheme.copyWith(
                    inputDecorationTheme: accentTheme.inputDecorationTheme.copyWith(
                      // Matches app-polo's H2kTextInput, whose fields sit on
                      // a near-white `colors.background` fill regardless of
                      // the panel's own (tertiary-tinted) background.
                      filled: true,
                      fillColor: accentTheme.colorScheme.surface,
                      labelStyle: TextStyle(
                        color: accentTheme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: accentTheme.colorScheme.onTertiaryContainer,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: accentTheme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: accentTheme.colorScheme.tertiary,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      AbsorbPointer(
                        absorbing: _pendingDelete,
                        child: Opacity(
                          opacity: _pendingDelete ? 0.5 : 1,
                          child: SecondaryControlRow(
                            controls: _buildSecondaryControls(accentTheme, accentPoloColors),
                            selectedKey: _selectedControlKey,
                            onSelect: _onSelectControl,
                            trailing: _isDupe
                                ? Chip(
                                    label: Text(widget.dupeLabel ?? 'DUPE'),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor:
                                        theme.colorScheme.errorContainer,
                                    labelStyle: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // A fixed-height container to prevent layout shifting.
                      // Sized to the second edit button's own diameter (see
                      // _buildWipeOrEditButton) — that button is the same
                      // size as the submit button, well over the 36px this
                      // row used to be, and a shorter row would have it
                      // overflowing upward into the secondary control row's
                      // chips above.
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            height: _editButtonDiameter ?? 44,
                            width: double.infinity,
                            // Reserves room for the button positioned on
                            // top of this box (below), so text truncates
                            // before it rather than rendering underneath.
                            child: Padding(
                              padding: EdgeInsets.only(right: (_editButtonDiameter ?? 44) + 8),
                              child: _pendingDelete
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          Icon(
                                            resolveIconName('alert'),
                                            size: 16,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              widget.pendingDeleteWarning ?? 'QSO will be deleted when you save',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: theme.colorScheme.error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _buildInfoArea(theme),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _buildWipeOrEditButton(accentTheme),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // IntrinsicHeight + stretch, rather than a guessed
                      // pixel height, so the submit button (an AspectRatio
                      // circle) is guaranteed to exactly match whatever
                      // height the text fields actually render at — not an
                      // eyeballed constant that drifts if their font size,
                      // padding, or text scale ever changes.
                      IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _callController,
                              focusNode: _callFocus,
                              enabled: !_pendingDelete,
                              autofocus: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9/.,]'),
                                ),
                                _UpperCaseFormatter(),
                              ],
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              decoration: _primaryFieldDecoration(context, widget.theirCallLabel ?? 'Their call'),
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _sentController,
                              focusNode: _sentFocus,
                              enabled: !_pendingDelete,
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-]'),
                                ),
                              ],
                              decoration: _primaryFieldDecoration(context, widget.sentLabel ?? 'Sent'),
                              onChanged: (_) => _rstsTouched = true,
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _rcvdController,
                              focusNode: _rcvdFocus,
                              enabled: !_pendingDelete,
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-]'),
                                ),
                              ],
                              decoration: _primaryFieldDecoration(context, widget.rcvdLabel ?? 'Rcvd'),
                              onChanged: (_) => _rstsTouched = true,
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // HaLo's big light-blue log button — a circle as
                          // tall as the text fields beside it. (A
                          // LayoutBuilder here to size the icon off the
                          // button's resolved constraints would seem
                          // natural, but IntrinsicHeight above needs to
                          // query this subtree's intrinsic dimensions, which
                          // LayoutBuilder explicitly doesn't support — so
                          // the icon just uses a fixed, comfortable size.)
                          AspectRatio(
                            key: _submitButtonKey,
                            aspectRatio: 1,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: FilledButton(
                                onPressed: (_pendingDelete || _canLog) ? _log : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      accentTheme.colorScheme.tertiary,
                                  foregroundColor:
                                      accentTheme.colorScheme.onTertiary,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                child: Icon(
                                  _pendingDelete
                                      ? resolveIconName('trash-can')
                                      : (editing ? resolveIconName('content-save') : Icons.upload),
                                  size: 24 * 1.2 * MediaQuery.textScalerOf(context).scale(1.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoArea(ThemeData theme) {
    final message = _commandMessage;
    final lookup = _lookupLine;

    if (message != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: MarkdownBody(
          data: message,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (lookup != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(
              MdiIcons.accountSearch,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                lookup,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
