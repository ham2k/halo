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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:halo_core/halo_core.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

/// Handles a named command action —
/// a closed set the core recognizes, not arbitrary state (DESIGN.md §4).
typedef CommandActionHandler = Future<void> Function(String action);

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
  /// composing a new one. Nothing wires this up yet (there's no tap-to-edit
  /// on QsoList rows), but the Time control's behavior already depends on
  /// the distinction: editing an existing entry shows *its* recorded time
  /// instead of a live clock, and has no "Now" reset (there's no
  /// "automatic" time to reset back to for a historical record).
  final Qso? editingQso;

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
  void didUpdateWidget(LoggingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingQso?.uuid != widget.editingQso?.uuid) _updateClockTicker();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _lookupDebounce?.cancel();
    _commandDescribeDebounce?.cancel();
    _executeMessageTimer?.cancel();
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
        hasValue: _effectiveStartAtMillis != null,
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
              labelColor: Theme.of(context).colorScheme.onTertiaryContainer,
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
      }
    }
  }

  Map<String, dynamic> _getCurrentQsoData() {
    final refs = [for (final list in _controlRefs.values) ...list];
    return {
      if (refs.isNotEmpty) 'refs': refs,
      'our': {
        'call': widget.operation.stationCall,
        'sent': _sentController.text.trim(),
      },
      'their': {
        'call': _callController.text.trim().toUpperCase(),
        'sent': _rcvdController.text.trim(),
        if (_lookupFor == _call && _lookupResult != null)
          ..._lookupResult!,
      },
      if (_freq != null) 'freq': _freq,
      if (_band != null) 'band': _band,
      'mode': _mode,
      if (_effectiveStartAtMillis != null) 'startAtMillis': _effectiveStartAtMillis,
      ..._currentQsoExtra,
    };
  }

  // ---- Lookup enrichment ----

  void _onCallChanged() {
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

    if (widget.interpretCommand != null) {
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

  Future<void> _log() async {
    if (_isLogging) return; // already logging this entry; ignore the repeat

    // Check command
    final call = _call;
    if (call.isNotEmpty && widget.interpretCommand != null) {
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
        ..._currentQsoExtra,
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
    final poloColors = HaLoColors.of(context);

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
                      const SizedBox(height: 6),
                      SecondaryControlRow(
                        controls: _buildSecondaryControls(theme, poloColors),
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
                      // A fixed-height container to prevent layout shifting
                      SizedBox(
                        height: 36,
                        child: _buildInfoArea(theme),
                      ),
                      const SizedBox(height: 8),
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
                          // HaLo's big light-blue log button.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
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
              color: theme.colorScheme.primary,
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
                  color: theme.colorScheme.primary,
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
