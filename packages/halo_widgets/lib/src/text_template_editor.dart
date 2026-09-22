// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'halo_dialog.dart';
import 'modal_pane.dart';
import 'spacing.dart';
import 'section_header.dart';
import 'category_band.dart';
import 'mdi_icons.g.dart';
import 'theme.dart';

typedef TemplatePreview = Future<String?> Function(String template, Map<String, dynamic> sample);

/// The app supplies its template runtime; forms remain independent of extensions.
class TemplateEditorScope extends InheritedWidget {
  final TemplatePreview preview;
  const TemplateEditorScope({super.key, required this.preview, required super.child});
  static TemplatePreview? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TemplateEditorScope>()?.preview;
  @override
  bool updateShouldNotify(TemplateEditorScope oldWidget) => preview != oldWidget.preview;
}

Future<String?> showTextTemplateEditor(BuildContext context, {required Map<String, dynamic> field, required String value}) => showHaloDialog<String>(
  context: context,
  builder: (_) => _TextTemplateEditor(field: field, value: value, preview: TemplateEditorScope.of(context)),
);

Map<String, dynamic> templateSampleFor(Map<String, dynamic> field) {
  final adif = field['templateContext'] == 'adif';
  final sample = <String, dynamic>{
    'operation': {
      'stationCall': 'N0CALL',
      'operator': 'K2HRC',
      'title': 'Park activation',
      'grid': 'FN31',
      'uuid': 'example-operation',
      'startAtMillisMin': DateTime.utc(2026, 7, 15, 14, 30).millisecondsSinceEpoch,
      'refs': [
        {'type': 'potaActivation', 'ref': 'US-1234'},
      ],
    },
    'log': {'station': 'N0CALL', 'ref': 'US-1234', 'refName': 'Example Park', 'activity': 'POTA', 'format': 'adif', 'extension': 'adi'},
    if (adif)
      'qso': {
        'their': {'call': 'W1AW', 'name': 'Alex', 'sent': '59'},
        'our': {'call': 'N0CALL', 'sent': '59'},
        'band': '20m',
        'mode': 'SSB',
        'notes': 'Thanks for the contact',
      },
  };
  final extra = field['templateSample'] as Map? ?? const {};
  for (final key in extra.keys) {
    sample[key as String] = extra[key] is Map ? {...?sample[key] as Map?, ...extra[key] as Map} : extra[key];
  }
  return sample;
}

class _TextTemplateEditor extends StatefulWidget {
  final Map<String, dynamic> field;
  final String value;
  final TemplatePreview? preview;
  const _TextTemplateEditor({required this.field, required this.value, this.preview});
  @override
  State<_TextTemplateEditor> createState() => _TextTemplateEditorState();
}

class _TextTemplateEditorState extends State<_TextTemplateEditor> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  Timer? _debounce;
  int _request = 0;
  String? _result;
  String? _error;
  bool _pending = true;
  bool _showDocs = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value)..addListener(_changed);
    _changed();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    final request = ++_request;
    _debounce?.cancel();
    setState(() {
      _pending = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      String? result;
      String? error;
      try {
        final sample = templateSampleFor(widget.field);
        result = await widget.preview?.call(_controller.text, sample);
      } catch (e) {
        error = '$e';
      }
      if (!mounted || request != _request) return;
      setState(() {
        _pending = false;
        _result = result;
        _error = error;
      });
    });
  }

  void _insert(String value) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _focus.requestFocus();
  }

  Widget _examples(String title, List<String> examples, {bool attribute = false, bool readOnly = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(title),
      if (readOnly)
        for (final example in examples)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: SelectableText(example, style: haloMonoStyle(context)),
          )
      else
        Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          children: [for (final example in examples) ActionChip(label: Text(example), onPressed: () => _insert(attribute ? '{{ $example }}' : example))],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final labels = context.t.templateEditor;
    final adif = widget.field['templateContext'] == 'adif';
    return HaloDialog(
      wide: true,
      title: Text(widget.field['label'] as String? ?? ''),
      scrollable: false,
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: ListTileTheme(
              contentPadding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: haloMonoStyle(context),
                    decoration: InputDecoration(errorText: _error),
                  ),
                  const SizedBox(height: Space.md),
                  Container(
                    padding: const EdgeInsets.all(Space.sm),
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(labels.previewLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: Space.xxl),
                                child: Opacity(
                                  opacity: _pending ? 0.5 : 1,
                                  child: SelectableText(
                                    _result == null
                                        ? (_pending ? '' : labels.unavailable)
                                        : _result!.isEmpty
                                        ? labels.empty
                                        : _result!,
                                    minLines: 2,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              if (_pending)
                                const Positioned(
                                  top: 0,
                                  right: 0,
                                  child: SizedBox(width: Space.lg, height: Space.lg, child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTileTheme(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: InkWell(
              onTap: () => setState(() => _showDocs = !_showDocs),
              child: CategoryBand(labels.docs, leading: Icon(_showDocs ? MdiIcons.chevronDown : MdiIcons.chevronRight)),
            ),
          ),
          if (_showDocs)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Space.lg),
                child: ListTileTheme(
                  contentPadding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _examples(labels.attributes, [
                        'op.station',
                        'op.operator',
                        'op.title',
                        'op.userTitle',
                        'op.grid',
                        'op.uuid',
                        'op.qsoCount',
                        'op.date',
                        'op.dateCompact',
                        'op.time',
                        'op.startAt',
                        'op.endAt',
                        'op.refs',
                        'log.station',
                        'log.ref',
                        'log.refName',
                        'log.activity',
                        'log.format',
                        'log.exportType',
                        'log.modifier',
                        'log.extension',
                        if (adif) ...[
                          'qso.call',
                          'qso.band',
                          'qso.mode',
                          'qso.freq',
                          'qso.notes',
                          'qso.rstSent',
                          'qso.rstRcvd',
                          'qso.their.name',
                          'qso.their.guess.name',
                          'qso.date',
                        ],
                      ], attribute: true),
                      _examples(labels.filters, [
                        '{{ log.station | dash }}',
                        '{{ log.activity | downcase }}',
                        '{{ log.ref | upcase }}',
                        '{{ op.date | alnum }}',
                        '{{ op.startAt | date: "%Y-%m-%d" }}',
                        '{{ log.ref | default: "log" }}',
                        '{{ op.refs | map: "ref" | compact | join: ", " }}',
                        '{{ op.refs | refLabels | sentence }}',
                        '{{ op.title | strip | replace: " ", "-" }}',
                      ], readOnly: true),
                      _examples(labels.flowControl, [
                        '{% if log.ref != blank %}{{ log.ref }}{% else %}{{ log.activity }}{% endif %}',
                        '{% for ref in op.refs %}{{ ref.ref }} {% endfor %}',
                        '{% assign name = log.station | dash %}{{ name }}',
                        '{% if op.qsoCount >= 10 and log.ref != blank %}{{ log.ref }}{% endif %}',
                        '{% raw %}{{ literal }}{% endraw %}',
                      ]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      destructive: widget.field.containsKey('defaultValue')
          ? TextButton(onPressed: () => _controller.text = widget.field['defaultValue']?.toString() ?? '', child: Text(context.t.templateEditor.reset))
          : null,
      cancel: TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _pending || _error != null ? null : () => Navigator.pop(context, _controller.text), child: Text(context.t.common.save)),
      ],
    );
  }
}

/// A rendered example beneath a template setting, using the editor's sample.
class TemplateSamplePreview extends StatelessWidget {
  final Map<String, dynamic> field;
  final String value;
  const TemplateSamplePreview({super.key, required this.field, required this.value});

  @override
  Widget build(BuildContext context) {
    final preview = TemplateEditorScope.of(context);
    if (preview == null) return const SizedBox.shrink();
    return FutureBuilder<String?>(
      future: preview(value, templateSampleFor(field)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final labels = context.t.templateEditor;
        final text = snapshot.hasError
            ? snapshot.error.toString()
            : snapshot.data == null
            ? labels.unavailable
            : snapshot.data!.isEmpty
            ? labels.empty
            : snapshot.data!;
        return Text('${labels.preview}: $text', maxLines: 2, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
