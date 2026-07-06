// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry panel — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7), ported from app-polo:
//   Enter   logs the QSO from anywhere in the panel
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
// later) without the panel's permanent footprint growing — only one
// control is expanded at a time. Command shortcuts still work while a
// control is collapsed, since they mutate the same underlying state the
// expanded fields edit.
//
// Everything here is pure Dart/Flutter; extensions only get debounced,
// async involvement (lookups, ref decoration) off the keystroke path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:polo_core/polo_core.dart';

import 'mdi_icons.dart';
import 'ref_chips_input.dart';
import 'secondary_control_row.dart';
import 'theme.dart';

/// Async callsign enrichment (name, location, grid…) from lookup sources.
/// Returning null means "nothing known". Must never throw.
typedef CallLookup = Future<Map<String, dynamic>?> Function(String call);

/// Tries the input as an extension-registered command (band/freq/mode
/// shortcuts, and eventually spotting/operator commands). Returns a
/// field-change map (`{freq?, band?, mode?}`) or null for "not a command".
/// Must never throw.
typedef CommandHandler = Future<Map<String, dynamic>?> Function(String input);

class LoggingPanel extends StatefulWidget {
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
  final CommandHandler? tryCommand;

  /// When set, the panel is editing this already-logged QSO rather than
  /// composing a new one. Nothing wires this up yet (there's no tap-to-edit
  /// on QsoList rows), but the Time control's behavior already depends on
  /// the distinction: editing an existing entry shows *its* recorded time
  /// instead of a live clock, and has no "Now" reset (there's no
  /// "automatic" time to reset back to for a historical record).
  final Qso? editingQso;

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.qsos = const [],
    this.onLogged,
    this.lookup,
    this.activityControls = const [],
    this.decorateRef,
    this.tryCommand,
    this.editingQso,
  });

  @override
  State<LoggingPanel> createState() => _LoggingPanelState();
}

class _LoggingPanelState extends State<LoggingPanel> {
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

  /// Refs entered via activity controls for the QSO being composed,
  /// keyed by control key.
  final Map<String, List<Map<String, dynamic>>> _controlRefs = {};

  /// Guards against double-logging: Enter is bound both as a keyboard
  /// shortcut and as every field's onSubmitted, and can also auto-repeat.
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _applyDefaultRSTs();
    _seedTimeFields();
    _updateClockTicker();
    _callController.addListener(_onCallChanged);
    _freqController.addListener(_onFreqChanged);
    _timeController.addListener(_onTimeOrDateFieldChanged);
    _dateController.addListener(_onTimeOrDateFieldChanged);
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
  void didUpdateWidget(LoggingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingQso?.uuid != widget.editingQso?.uuid) _updateClockTicker();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _lookupDebounce?.cancel();
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
    setState(() {
      if (key == 'time' && _selectedControlKey != 'time') _seedTimeFields();
      _selectedControlKey = key;
    });
  }

  /// Shared look for the primary logging row (Their call/Sent/Rcvd) — same
  /// font size and field padding across all three, and the label always
  /// pinned to the top-left corner (not the "large placeholder until
  /// focused" default) so the row's shape doesn't shift as you type.
  TextStyle _primaryFieldStyle(BuildContext context, {required FontWeight fontWeight}) =>
      poloMonoStyle(context, fontSize: 20, fontWeight: fontWeight);

  InputDecoration _primaryFieldDecoration(BuildContext context, String label) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      isDense: true,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      // A smaller floating label reserves less vertical space for itself,
      // which is what actually pulls the value up closer to it — the
      // surrounding contentPadding alone hits a floor set by Material's
      // default (much larger) floating label metrics. Explicit here (rather
      // than inheriting the ambient scoped theme's floatingLabelStyle)
      // since setting one at all replaces the other outright rather than
      // merging, so the color has to come along with the smaller size.
      floatingLabelStyle: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onTertiaryContainer,
      ),
      contentPadding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
    );
  }

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

  IconData _iconForControlName(String? name) {
    switch (name) {
      case 'pota':
        return MdiIcons.pineTree;
      default:
        return MdiIcons.puzzleOutline;
    }
  }

  List<SecondaryControlSpec> _buildSecondaryControls(
    ThemeData theme,
    PoloColors poloColors,
  ) {
    return [
      SecondaryControlSpec(
        key: 'time',
        icon: MdiIcons.clockOutline,
        summary: _timeSummary,
        hasValue: _effectiveStartAtMillis != null,
        expandedBuilder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 74,
              child: TextField(
                controller: _timeController,
                focusNode: _timeFocus,
                style: poloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  labelText: 'Time (UTC)',
                  isDense: true,
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
                style: poloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  labelText: 'Date',
                  isDense: true,
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
              TextButton(onPressed: _resetTimeToNow, child: const Text('Now')),
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
                style: poloMonoStyle(
                  context,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  labelText: 'Freq kHz',
                  isDense: true,
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
                style: poloMonoStyle(
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
              label: const Text('Mode'),
              width: 104,
              textStyle: poloMonoStyle(
                context,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surface,
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
            icon: _iconForControlName(control['icon'] as String?),
            summary: (control['label'] as String?) ?? control['key'] as String,
            hasValue: (_controlRefs[control['key']]?.isNotEmpty) ?? false,
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
            ),
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
      final tryCommand = widget.tryCommand;
      if (call.isNotEmpty && tryCommand != null) {
        final result = await tryCommand(call);
        if (!mounted) return;
        if (result != null) {
          setState(() {
            final freq = result['freq'];
            final band = result['band'];
            final mode = result['mode'];
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
            // Show the result — otherwise a typed command would silently
            // change state behind a collapsed chip with no feedback.
            _selectedControlKey = 'radio';
          });
          _callController.clear();
          return;
        }
      }
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

  // ---- Lookup enrichment ----

  void _onCallChanged() {
    setState(() {});
    _lookupDebounce?.cancel();
    if (widget.lookup == null) return;

    final call = _call;
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
    _lookupFor = null;
    _lookupResult = null;
    _controlRefs.clear();
    _manualStartAtMillis = null;
    _selectedControlKey = null;
    _callFocus.requestFocus();
    setState(_updateClockTicker);
  }

  Future<void> _log() async {
    if (_isLogging) return; // already logging this entry; ignore the repeat
    if (!_canLog) {
      _callFocus.requestFocus();
      return;
    }
    _isLogging = true;
    try {
      // Fold lookup enrichment into `their` if it belongs to this call.
      final lookup = _lookupFor == _call ? _lookupResult : null;
      final refs = [for (final list in _controlRefs.values) ...list];
      final qso = await widget.qsosRepository.add(widget.operation.uuid, {
        if (refs.isNotEmpty) 'refs': refs,
        'our': {
          'call': widget.operation.stationCall,
          'sent': _sentController.text.trim(),
        },
        'their': {
          'call': _call,
          'sent': _rcvdController.text.trim(),
          if (lookup != null)
            for (final field in const [
              'name',
              'city',
              'state',
              'country',
              'grid',
            ])
              if (lookup[field] != null) field: lookup[field],
        },
        if (_freq != null) 'freq': _freq,
        if (_band != null) 'band': _band,
        'mode': _mode,
        if (_effectiveStartAtMillis != null) 'startAtMillis': _effectiveStartAtMillis,
      });
      widget.onLogged?.call(qso);
      _wipe();
    } finally {
      _isLogging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poloColors = PoloColors.of(context);

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
          // (tertiary here) as its background, with a divider line in the
          // same tertiaryLight tone as the unselected chips separating it
          // from the QSO list above.
          color: theme.colorScheme.tertiaryContainer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 2, color: poloColors.tertiaryLight),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                // Scoped so every field's label/underline reads clearly
                // against the tertiary-tinted panel, without touching the
                // rest of the theme (the log button keeps its own
                // deliberate primaryContainer styling below).
                child: Theme(
                  data: theme.copyWith(
                    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                      // Matches app-polo's H2kTextInput, whose fields sit on
                      // a near-white `colors.background` fill regardless of
                      // the panel's own (tertiary-tinted) background.
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.85,
                        ),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.tertiary,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecondaryControlRow(
                        controls: _buildSecondaryControls(theme, poloColors),
                        selectedKey: _selectedControlKey,
                        onSelect: _onSelectControl,
                        trailing: _isDupe
                            ? Chip(
                                label: const Text('DUPE'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor:
                                    theme.colorScheme.errorContainer,
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              )
                            : null,
                      ),
                      if (_lookupLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
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
                                  _lookupLine!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _callController,
                              focusNode: _callFocus,
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
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w700),
                              decoration: _primaryFieldDecoration(context, 'Their call'),
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _sentController,
                              focusNode: _sentFocus,
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-]'),
                                ),
                              ],
                              decoration: _primaryFieldDecoration(context, 'Sent'),
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
                              style: _primaryFieldStyle(context, fontWeight: FontWeight.w500),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+\-]'),
                                ),
                              ],
                              decoration: _primaryFieldDecoration(context, 'Rcvd'),
                              onChanged: (_) => _rstsTouched = true,
                              onSubmitted: (_) => _log(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // PoLo's big light-blue log button.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: FilledButton(
                              onPressed: _canLog ? _log : null,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                foregroundColor:
                                    theme.colorScheme.onPrimaryContainer,
                                minimumSize: const Size(64, 44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Icon(Icons.check, size: 28),
                            ),
                          ),
                        ],
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
