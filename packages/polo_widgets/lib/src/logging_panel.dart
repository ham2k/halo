// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The QSO entry panel — the hottest path in the whole app. Keyboard
// ergonomics are the contract (DESIGN.md §7):
//   Enter  logs the QSO from anywhere in the panel
//   Esc    wipes the current entry
//   focus  always returns to the callsign field after log/wipe
// Everything here is pure Dart/Flutter; plugins only ever get debounced,
// async involvement (lookups, validation) and none are wired yet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:polo_core/polo_core.dart';

import 'ref_chips_input.dart';
import 'theme.dart';

/// Async callsign enrichment (name, location, grid…) from lookup sources.
/// Returning null means "nothing known". Must never throw.
typedef CallLookup = Future<Map<String, dynamic>?> Function(String call);

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

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.qsos = const [],
    this.onLogged,
    this.lookup,
    this.activityControls = const [],
    this.decorateRef,
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

  String _mode = 'SSB';
  bool _rstsTouched = false;

  Timer? _lookupDebounce;
  String? _lookupFor;
  Map<String, dynamic>? _lookupResult;

  /// Refs entered via activity controls for the QSO being composed,
  /// keyed by control key.
  final Map<String, List<Map<String, dynamic>>> _controlRefs = {};

  @override
  void initState() {
    super.initState();
    _applyDefaultRSTs();
    _callController.addListener(_onCallChanged);
    _freqController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _callFocus.dispose();
    super.dispose();
  }

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

  String get _call => _callController.text.trim().toUpperCase();
  double? get _freq => parseFreq(_freqController.text);
  String? get _band => _freq == null ? null : bandForFrequency(_freq!);
  bool get _canLog => looksLikeCallsign(_call);

  bool get _isDupe => widget.qsos.any((qso) =>
      qso.theirCall == _call &&
      qso.mode == _mode &&
      (qso.band ?? '') == (_band ?? ''));

  void _applyDefaultRSTs() {
    _sentController.text = defaultRSTFor(_mode);
    _rcvdController.text = defaultRSTFor(_mode);
    _rstsTouched = false;
  }

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
    if (!_canLog) {
      _callFocus.requestFocus();
      return;
    }
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
      },
      child: FocusTraversalGroup(
        child: Material(
          elevation: 4,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  SizedBox(
                    width: 104,
                    child: TextField(
                      controller: _freqController,
                      style: poloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(labelText: 'Freq kHz', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            ? theme.colorScheme.outline
                            : Color.lerp(poloColors.bandColor(_band!), theme.colorScheme.onSurface, 0.25),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  DropdownMenu<String>(
                    initialSelection: _mode,
                    label: const Text('Mode'),
                    width: 104,
                    textStyle: poloMonoStyle(context, fontSize: 15, fontWeight: FontWeight.w500),
                    inputDecorationTheme: const InputDecorationTheme(isDense: true),
                    dropdownMenuEntries: [for (final m in modes) DropdownMenuEntry(value: m, label: m)],
                    onSelected: (value) {
                      if (value == null) return;
                      setState(() {
                        _mode = value;
                        if (!_rstsTouched) _applyDefaultRSTs();
                      });
                      _callFocus.requestFocus();
                    },
                  ),
                  const Spacer(),
                  if (_isDupe)
                    Chip(
                      label: const Text('DUPE'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.errorContainer,
                      labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                ]),
                for (final control in widget.activityControls)
                  if ((control['input'] as Map?)?['kind'] == 'refList')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: RefChipsInput(
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
                      ),
                    ),
                if (_lookupLine != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
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
                const SizedBox(height: 6),
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
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9/]')),
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
                      style: poloMonoStyle(context, fontSize: 17, fontWeight: FontWeight.w500),
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
                      style: poloMonoStyle(context, fontSize: 17, fontWeight: FontWeight.w500),
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
                        minimumSize: const Size(64, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
