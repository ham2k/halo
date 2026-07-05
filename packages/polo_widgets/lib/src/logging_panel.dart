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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:polo_core/polo_core.dart';

class LoggingPanel extends StatefulWidget {
  final Operation operation;
  final QsosRepository qsosRepository;

  /// Current QSOs in the operation, used for dupe hints.
  final List<Qso> qsos;
  final void Function(Qso qso)? onLogged;

  const LoggingPanel({
    super.key,
    required this.operation,
    required this.qsosRepository,
    this.qsos = const [],
    this.onLogged,
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

  @override
  void initState() {
    super.initState();
    _applyDefaultRSTs();
    _callController.addListener(() => setState(() {}));
    _freqController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _callController.dispose();
    _sentController.dispose();
    _rcvdController.dispose();
    _freqController.dispose();
    _callFocus.dispose();
    super.dispose();
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
    _callFocus.requestFocus();
    setState(() {});
  }

  Future<void> _log() async {
    if (!_canLog) {
      _callFocus.requestFocus();
      return;
    }
    final qso = await widget.qsosRepository.add(widget.operation.uuid, {
      'our': {'call': widget.operation.stationCall, 'sent': _sentController.text.trim()},
      'their': {'call': _call, 'sent': _rcvdController.text.trim()},
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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _wipe,
        const SingleActivator(LogicalKeyboardKey.enter): _log,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _log,
      },
      child: FocusTraversalGroup(
        child: Material(
          elevation: 4,
          color: theme.colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _freqController,
                      decoration: InputDecoration(
                        labelText: 'Freq kHz',
                        isDense: true,
                        helperText: _band ?? ' ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownMenu<String>(
                    initialSelection: _mode,
                    label: const Text('Mode'),
                    width: 110,
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
                const SizedBox(height: 8),
                Row(children: [
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
                      style: theme.textTheme.headlineSmall?.copyWith(fontFeatures: const []),
                      decoration: const InputDecoration(labelText: 'Their call', isDense: true),
                      onSubmitted: (_) => _log(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _sentController,
                      decoration: const InputDecoration(labelText: 'Sent', isDense: true),
                      onChanged: (_) => _rstsTouched = true,
                      onSubmitted: (_) => _log(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _rcvdController,
                      decoration: const InputDecoration(labelText: 'Rcvd', isDense: true),
                      onChanged: (_) => _rstsTouched = true,
                      onSubmitted: (_) => _log(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _canLog ? _log : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Log'),
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
