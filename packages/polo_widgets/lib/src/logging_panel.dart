// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry panel — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7), ported from app-polo:
//   Enter   logs the QSO from anywhere in the panel
//   Esc     wipes the current entry
//   Space   in the call field: runs command shortcuts (frequency, band,
//           mode — "14285 ", "20m ", "cw ") or advances to Sent;
//           in Sent/Rcvd/Freq: advances focus, cycling back to the call
//   focus   always returns to the callsign field after log/wipe;
//           Sent/Rcvd/Freq select-all on focus so typing replaces
// Everything here is pure Dart/Flutter; plugins only get debounced, async
// involvement (lookups, ref decoration) off the keystroke path.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:polo_core/polo_core.dart';

import 'ref_chips_input.dart';
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

  /// Declarative activity control descriptors from plugins (UI catalog).
  /// v0 supports `input.kind == 'refList'`.
  final List<Map<String, dynamic>> activityControls;

  /// Async ref decoration via the plugin runtime.
  final RefDecorator? decorateRef;

  /// Extension-backed command shortcuts, tried on space in the call field.
  /// When null, space in the call field just advances focus.
  final CommandHandler? tryCommand;

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
  });

  @override
  State<LoggingPanel> createState() => _LoggingPanelState();
}

class _LoggingPanelState extends State<LoggingPanel> {
  final _callController = TextEditingController();
  final _sentController = TextEditingController();
  final _rcvdController = TextEditingController();
  final _freqController = TextEditingController();
  final _callFocus = FocusNode();
  final _sentFocus = FocusNode();
  final _rcvdFocus = FocusNode();
  final _freqFocus = FocusNode();

  String _mode = 'SSB';

  /// Band set via a "20m " command when no frequency is entered.
  String? _manualBand;
  bool _rstsTouched = false;

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
    _callController.addListener(_onCallChanged);
    _freqController.addListener(_onFreqChanged);
    // Exchange fields select-all on focus, so typing replaces the default.
    for (final (focus, controller) in [
      (_sentFocus, _sentController),
      (_rcvdFocus, _rcvdController),
      (_freqFocus, _freqController),
    ]) {
      focus.addListener(() {
        if (focus.hasFocus) {
          controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _callFocus.dispose();
    _sentFocus.dispose();
    _rcvdFocus.dispose();
    _freqFocus.dispose();
    super.dispose();
  }

  String get _call => _callController.text.trim().toUpperCase();
  double? get _freq => parseFreq(_freqController.text);
  String? get _band => _freq != null ? bandForFrequency(_freq!) : _manualBand;
  bool get _canLog => looksLikeCallsign(_call);

  bool get _isDupe => widget.qsos.any((qso) =>
      qso.theirCall == _call &&
      qso.mode == _mode &&
      (qso.band ?? '') == (_band ?? ''));

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
              _freqController.text = fmtFreq(freq.toDouble()).replaceAll(',', '');
              _manualBand = null;
            } else if (band is String) {
              _manualBand = band;
              _freqController.clear();
            }
            if (mode is String) {
              _mode = mode;
              if (!_rstsTouched) _applyDefaultRSTs();
            }
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
    final location = [result['city'], result['state']].whereType<String>().where((s) => s.isNotEmpty).join(', ');
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
    _callFocus.requestFocus();
    setState(() {});
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
        'our': {'call': widget.operation.stationCall, 'sent': _sentController.text.trim()},
        'their': {
          'call': _call,
          'sent': _rcvdController.text.trim(),
          if (lookup != null)
            for (final field in const ['name', 'city', 'state', 'country', 'grid'])
              if (lookup[field] != null) field: lookup[field],
        },
        if (_freq != null) 'freq': _freq,
        if (_band != null) 'band': _band,
        'mode': _mode,
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
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top strip: frequency, band, mode, activity controls, DUPE.
                // Wrap so it flows to a second line on narrow screens.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _freqController,
                          focusNode: _freqFocus,
                          style: poloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                          decoration: const InputDecoration(labelText: 'Freq kHz', isDense: true),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          onSubmitted: (_) => _log(),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          _band ?? '',
                          style: poloMonoStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _band == null
                                ? theme.colorScheme.outline
                                : Color.lerp(poloColors.bandColor(_band!), theme.colorScheme.onSurface, 0.25),
                          ),
                        ),
                      ),
                      DropdownMenu<String>(
                        initialSelection: _mode,
                        label: const Text('Mode'),
                        width: 100,
                        textStyle: poloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                        inputDecorationTheme: const InputDecorationTheme(isDense: true),
                        dropdownMenuEntries: [for (final m in modes) DropdownMenuEntry(value: m, label: m)],
                        onSelected: (value) {
                          if (value == null) return;
                          _setMode(value);
                          _callFocus.requestFocus();
                        },
                      ),
                      for (final control in widget.activityControls)
                        if ((control['input'] as Map?)?['kind'] == 'refList')
                          RefChipsInput(
                            key: ValueKey(control['key']),
                            refType: (control['input'] as Map)['refType'] as String,
                            label: (control['label'] as String?) ?? '',
                            placeholder: (control['input'] as Map)['placeholder'] as String?,
                            pattern: (control['input'] as Map)['pattern'] as String?,
                            refs: _controlRefs[control['key']] ?? const [],
                            onChanged: (refs) => setState(() => _controlRefs[control['key'] as String] = refs),
                            decorate: widget.decorateRef,
                            dense: true,
                          ),
                      if (_isDupe)
                        Chip(
                          label: const Text('DUPE'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.errorContainer,
                          labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                    ],
                  ),
                ),
                if (_lookupLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.person_outline, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _lookupLine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _callController,
                      focusNode: _callFocus,
                      autofocus: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/.,]')),
                        _UpperCaseFormatter(),
                      ],
                      style: poloMonoStyle(context, fontSize: 24, fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(labelText: 'Their call', isDense: true),
                      onSubmitted: (_) => _log(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _sentController,
                      focusNode: _sentFocus,
                      style: poloMonoStyle(context, fontSize: 17, fontWeight: FontWeight.w500),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]'))],
                      decoration: const InputDecoration(labelText: 'Sent', isDense: true),
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
                      style: poloMonoStyle(context, fontSize: 17, fontWeight: FontWeight.w500),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]'))],
                      decoration: const InputDecoration(labelText: 'Rcvd', isDense: true),
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
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        minimumSize: const Size(64, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      child: const Icon(Icons.check, size: 28),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
