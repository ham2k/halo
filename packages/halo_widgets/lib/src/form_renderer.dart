// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'halo_dialog.dart';
import 'icon_resolver.dart';
import 'modal_pane.dart';
import 'secret_text_field.dart';
import 'text_formatters.dart';
import 'theme.dart';

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormAction = Future<String?> Function(String actionKey, String method, Map<String, dynamic> state);
typedef FormManageAccount = void Function(String accountKey, String? subkey);
typedef FormOpenLink = void Function(String url);

/// Substitutes `${key}` placeholders in [template] with values from [item].
String _templateString(String template, Map<String, dynamic> item) {
  return template.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (m) => item[m.group(1)]?.toString() ?? '');
}

/// The Cancel/Save (+ submitting spinner) row shared by every presenter of
/// a [FormRenderer] — the renderer's own `showActions` footer,
/// [showFormDialog]'s action bar, [showFormPane]'s pinned footer, and
/// [FormView]'s bottom bar. Only the row lives here; each presenter keeps
/// its own chrome (tinted container, SafeArea, padding) around it, so a
/// change to the submission UX lands in all four at once.
Widget _formActionsRow({
  required bool isSubmitting,
  required VoidCallback? onCancel,
  required VoidCallback? onSave,
}) {
  return Row(
    children: [
      TextButton(
        onPressed: isSubmitting ? null : onCancel,
        child: const Text('Cancel'),
      ),
      // A minimum gap even on a narrow row — Expanded alone only keeps Save
      // from overlapping Cancel, not from sitting flush against it.
      const SizedBox(width: 12),
      // Pins Save (and the submitting spinner) to the trailing edge, leaving
      // Cancel alone at the leading edge instead of merely first in a
      // right-packed group (issue #191, same convention as HaloDialog).
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: onSave,
                  child: const Text('Save'),
                ),
        ),
      ),
    ],
  );
}

/// Renders a form from a dynamic JSON definition, coordinating input fields,
/// headers, section dividers, and markdown text blocks. Supports initial state,
/// actions (Submit/Cancel), and asynchronous JS-backed validation and transformation.
class FormRenderer extends StatefulWidget {
  final Map<String, dynamic> formDefinition;
  final Map<String, dynamic> initialState;
  final FormValidator? validator;
  final FormTransformer? transformer;
  final FormOnChange? onChange;
  final FormAction? onAction;
  final FormManageAccount? onManageAccount;

  /// Opens a `type: 'link'` element's URL. The renderer stays free of any
  /// url_launcher dependency — the app decides how links open.
  final FormOpenLink? onOpenLink;
  final void Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback onCancel;
  final bool showActions;
  final bool showTitle;
  final ValueNotifier<bool>? submittingNotifier;

  /// Whether elements marked `devMode: true` in the definition are shown at
  /// all — hidden entirely (not just disabled) when false, the default.
  final bool developerMode;

  const FormRenderer({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    this.onAction,
    this.onManageAccount,
    this.onOpenLink,
    required this.onSubmit,
    required this.onCancel,
    this.showActions = true,
    this.showTitle = true,
    this.submittingNotifier,
    this.developerMode = false,
  });

  @override
  State<FormRenderer> createState() => FormRendererState();
}

class FormRendererState extends State<FormRenderer> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _errors = {};
  final Set<String> _runningActions = {};
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _elements => (widget.formDefinition['elements'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((el) => el['devMode'] != true || widget.developerMode)
      .toList();

  /// The orange "dev mode" accent for an element flagged `devMode: true` —
  /// null once [_elements] has already excluded it, so no builder needs its
  /// own visibility check, only this color check.
  Color? _devModeColor(Map<String, dynamic> el) => el['devMode'] == true ? HaLoColors.of(context).devMode : null;

  List<Map<String, dynamic>> get _fields =>
      _elements.where((el) => el['type'] == 'field').toList();

  @override
  void initState() {
    super.initState();
    _initializeFormState();
  }

  @override
  void didUpdateWidget(covariant FormRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.formDefinition, widget.formDefinition)) {
      _syncFieldValuesFromDefinition(oldWidget.formDefinition);
    }
  }

  static List<Map<String, dynamic>> _fieldsIn(Map<String, dynamic> definition) => (definition['elements'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((el) => el['type'] == 'field')
      .toList();

  /// A field's `value` here is the source of truth — set by whatever last
  /// called [FormRenderer] with a new [formDefinition] (e.g. a settings
  /// panel re-fetching after a value changed outside this widget entirely,
  /// like a keyboard shortcut). [initState] only ever sees this once, so
  /// without this, [_values] would silently go stale on every subsequent
  /// formDefinition change. A field absent from the OLD definition (e.g.
  /// one that only appears once another field reaches some value) is never
  /// "updated" — it's brand new — so it goes through [_initializeField]
  /// instead, same as every field does on first mount; without that, it
  /// would render with no controller/focus node and silently drop input.
  /// For a field present in both, only overwrites [_values] when it still
  /// matches what the OLD definition said — a field the user has locally
  /// edited but not yet had committed back through [onChange] is left
  /// alone, since here we can't tell that apart from a real external update
  /// racing it.
  void _syncFieldValuesFromDefinition(Map<String, dynamic> oldDefinition) {
    final oldValues = {for (final f in _fieldsIn(oldDefinition)) f['key'] as String: f['value']};
    final changes = <String, dynamic>{};
    final newFields = <Map<String, dynamic>>[];
    for (final field in _fields) {
      final key = field['key'] as String;
      if (!oldValues.containsKey(key)) {
        if (!_values.containsKey(key)) newFields.add(field);
        continue;
      }
      final newVal = field['value'];
      if (newVal != oldValues[key] && _values[key] == oldValues[key]) {
        changes[key] = newVal;
      }
    }
    if (changes.isEmpty && newFields.isEmpty) return;
    setState(() {
      for (final entry in changes.entries) {
        _values[entry.key] = entry.value;
        final controller = _controllers[entry.key];
        if (controller != null && controller.text != (entry.value?.toString() ?? '')) {
          controller.text = entry.value?.toString() ?? '';
        }
      }
      for (final field in newFields) {
        _initializeField(field);
      }
    });
  }

  void _initializeFormState() {
    for (final field in _fields) {
      _initializeField(field);
    }
  }

  void _initializeField(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final fieldType = field['fieldType'] as String;
    var val = widget.initialState[key] ?? field['value'];
    if (val == null) {
      if (fieldType == 'checkbox') {
        val = false;
      } else if (fieldType == 'list') {
        val = <Map<String, dynamic>>[];
      } else if (fieldType == 'multiselect') {
        val = <String>[];
      } else if (['select', 'radio', 'number', 'account'].contains(fieldType)) {
        val = null;
      } else {
        val = '';
      }
    }
    _values[key] = val;

    final focusNode = FocusNode();
    _focusNodes[key] = focusNode;

    if (['text', 'multiline', 'email', 'callsign', 'number', 'secret'].contains(fieldType)) {
      final controller = TextEditingController(text: val?.toString() ?? '');
      _controllers[key] = controller;
      controller.addListener(() {
        final text = controller.text;
        dynamic parsed = text;
        if (fieldType == 'number') {
          parsed = num.tryParse(text);
        }
        if (_values[key] != parsed) {
          setState(() {
            _values[key] = parsed;
            _errors.remove(key);
          });
        }
      });

      focusNode.addListener(() {
        if (!focusNode.hasFocus) {
          _handleFieldBlurOrInteraction(key, _values[key]);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    super.dispose();
  }

  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value) async {
    if (widget.onChange != null) {
      try {
        final updates = await widget.onChange!(key, value, _values);
        if (updates != null && updates.isNotEmpty && mounted) {
          setState(() {
            for (final entry in updates.entries) {
              _values[entry.key] = entry.value;
              final controller = _controllers[entry.key];
              if (controller != null) {
                if (controller.text != entry.value?.toString()) {
                  controller.text = entry.value?.toString() ?? '';
                }
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error running onChange for $key: $e');
      }
    }

    if (widget.validator != null) {
      final error = await widget.validator!(key, value, _values);
      if (!mounted) return;
      setState(() {
        if (error != null && error.isNotEmpty) {
          _errors[key] = error;
        } else {
          _errors.remove(key);
        }
      });
    }
  }

  Iterable<String>? _getAutofillHints(String key, String fieldType) {
    if (fieldType == 'email') {
      return const [AutofillHints.email];
    }
    if (fieldType == 'text') {
      final k = key.toLowerCase();
      if (k.contains('name')) {
        return const [AutofillHints.name];
      }
      if (k.contains('phone') || k.contains('tel')) {
        return const [AutofillHints.telephoneNumber];
      }
      if (k.contains('address')) {
        return const [AutofillHints.fullStreetAddress];
      }
    }
    return null;
  }

  Future<void> submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errors.clear();
    });
    widget.submittingNotifier?.value = true;

    final errors = <String, String>{};
    final transformedValues = <String, dynamic>{..._values};

    for (final field in _fields) {
      final key = field['key'] as String;
      final val = _values[key];

      // Validate
      if (widget.validator != null) {
        try {
          final error = await widget.validator!(key, val, _values);
          if (error != null && error.isNotEmpty) {
            errors[key] = error;
          }
        } catch (e) {
          errors[key] = 'Validation error: $e';
        }
      }

      // Transform if valid
      if (errors[key] == null && widget.transformer != null) {
        try {
          final transformed = await widget.transformer!(key, val, _values);
          transformedValues[key] = transformed;
        } catch (e) {
          errors[key] = 'Transformation error: $e';
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        widget.submittingNotifier?.value = false;
        if (errors.isNotEmpty) {
          _errors.addAll(errors);

          // Scroll first error into view
          for (final field in _fields) {
            final key = field['key'] as String;
            if (errors.containsKey(key)) {
              _focusNodes[key]?.requestFocus();
              break;
            }
          }
        } else {
          widget.onSubmit(transformedValues);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elements = _elements;

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTitle && widget.formDefinition['title'] != null) ...[
            Text(
              widget.formDefinition['title'] as String,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: 'RobotoSlab',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (widget.showTitle && widget.formDefinition['subtitle'] != null) ...[
            Text(
              widget.formDefinition['subtitle'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: elements.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final el = elements[index];
              final type = el['type'] as String?;
              switch (type) {
                case 'header':
                  return _buildHeader(el, theme);
                case 'divider':
                  return _buildDivider(el, theme);
                case 'markdown':
                  return _buildMarkdown(el, theme);
                case 'field':
                  return _buildField(el, theme);
                case 'link':
                  return _buildLink(el, theme);
                case 'action':
                  return _buildActionElement(el, theme);
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
          if (widget.showActions) ...[
            const SizedBox(height: 24),
            _formActionsRow(isSubmitting: _isSubmitting, onCancel: widget.onCancel, onSave: submit),
          ],
        ],
      ),
    );
  }

  /// `style: 'section'` opts into the same typography as the section
  /// headers used in the Sync/Accounts settings panels (see SectionHeader)
  /// — smaller and less bold than the default. Opt-in, not the default,
  /// because `_buildHeader` renders `type: 'header'` elements for every
  /// FormRenderer caller, not just settings panels — an ad hoc extension
  /// form's own section headers keep the original bold look unless they
  /// explicitly ask for the settings-panel one. Doesn't reuse SectionHeader
  /// itself even when 'section' is requested: that widget bakes in its own
  /// 16px horizontal padding, sized for a container with none of its own
  /// (Sync/Accounts' ListView) — here, the horizontal inset already comes
  /// from the outer SingleChildScrollView every field in this form shares,
  /// so adding SectionHeader's on top would double it.
  Widget _buildHeader(Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String? ?? '';
    final subtitle = el['subtitle'] as String?;
    final devModeColor = _devModeColor(el);
    final isSection = el['style'] == 'section';
    final titleStyle = isSection
        ? theme.textTheme.titleSmall?.copyWith(color: devModeColor ?? theme.colorScheme.primary)
        : theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w900,
            color: devModeColor ?? theme.colorScheme.primary,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: devModeColor ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider(Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String?;
    if (title == null || title.isEmpty) {
      return const Divider();
    }
    final devModeColor = _devModeColor(el);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: devModeColor ?? theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildMarkdown(Map<String, dynamic> el, ThemeData theme) {
    final text = el['text'] as String? ?? '';
    final devModeColor = _devModeColor(el);
    return MarkdownBody(
      data: text,
      styleSheet: devModeColor == null ? null : MarkdownStyleSheet(p: TextStyle(color: devModeColor)),
    );
  }

  static const _iconRowSupportedTypes = {'text', 'multiline', 'email', 'callsign', 'number', 'secret', 'select', 'checkbox'};

  /// Field types whose compact trailing control this can build. 'list',
  /// 'radio', and 'account' fall back to their normal full-width rendering
  /// even when `icon` is set — a multi-option or multi-row control doesn't
  /// have an obvious single-line compact form.
  Widget _buildField(Map<String, dynamic> el, ThemeData theme) {
    final fieldType = el['fieldType'] as String?;
    if (el['icon'] != null && _iconRowSupportedTypes.contains(fieldType)) {
      return _buildIconRowField(el, fieldType!, theme);
    }

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final placeholder = el['placeholder'] as String?;
    // `options` may be an app-resolved '$name' String that a caller failed
    // to resolve — degrade to no options instead of crashing the form.
    final options =
        (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    switch (fieldType) {
      case 'text':
      case 'multiline':
      case 'email':
      case 'callsign':
      case 'number':
        // One parametrized TextField, same axes _buildCompactControl already
        // uses. Two type-specific behaviors: 'multiline' gets no
        // textInputAction/onSubmitted (Enter must insert a newline, not
        // submit), and 'number' keeps default capitalization — its digit
        // filter makes `uppercase: true` meaningless, and the full-width
        // layout has never honored it there.
        final multiline = fieldType == 'multiline';
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          maxLines: multiline ? null : 1,
          minLines: multiline ? 3 : null,
          keyboardType: _keyboardTypeFor(fieldType!),
          textCapitalization: fieldType == 'number' ? TextCapitalization.none : _capitalizationFor(fieldType, el),
          inputFormatters: _inputFormattersFor(fieldType, el),
          autofillHints: _getAutofillHints(key, fieldType),
          textInputAction: multiline ? null : TextInputAction.done,
          onSubmitted: multiline ? null : (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'secret':
        return SecretTextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'list':
        return _buildListField(el, theme);
      case 'multiselect':
        return _buildMultiselectField(el, theme);
      case 'account':
        return _buildAccountField(el, theme);
      case 'select':
        return DropdownButtonFormField<dynamic>(
          value: _values[key],
          focusNode: _focusNodes[key],
          menuMaxHeight: dropdownMenuMaxHeight(context),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
          hint: placeholder != null ? Text(placeholder) : null,
          items: [
            for (final opt in options)
              DropdownMenuItem(
                value: opt['value'],
                child: Text(opt['label'] as String),
              )
          ],
          onChanged: _isSubmitting
              ? null
              : (val) {
                  setState(() {
                    _values[key] = val;
                    _errors.remove(key);
                  });
                  _handleFieldBlurOrInteraction(key, val);
                },
        );
      case 'radio':
        return Focus(
          focusNode: _focusNodes[key],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: devModeColor ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              for (final opt in options)
                RadioListTile<dynamic>(
                  title: Text(opt['label'] as String),
                  value: opt['value'],
                  groupValue: _values[key],
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _values[key] = val;
                            _errors.remove(key);
                          });
                          _handleFieldBlurOrInteraction(key, val);
                        },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    errorText,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      case 'checkbox':
        return Focus(
          focusNode: _focusNodes[key],
          child: CheckboxListTile(
            title: Text(label, style: devModeColor == null ? null : TextStyle(color: devModeColor)),
            value: _values[key] == true,
            onChanged: _isSubmitting
                ? null
                : (val) {
                    final finalVal = val ?? false;
                    setState(() {
                      _values[key] = finalVal;
                      _errors.remove(key);
                    });
                    _handleFieldBlurOrInteraction(key, finalVal);
                  },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            subtitle: errorText != null
                ? Text(
                    errorText,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  )
                : null,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// The settings-panel row shape: leading icon, bold title, an optional
  /// description underneath (or the validation error, in its place). The
  /// trailing/stacked control depends on the field type:
  ///  - a toggle (checkbox) keeps its Switch trailing on the right;
  ///  - a `select` becomes a tap-to-open picker dialog; the row shows the
  ///    field's description (written to explain the current value — see the
  ///    settings definitions), not the raw value on its own (see
  ///    [_buildSelectRow]);
  ///  - every other (text-like) field renders its input full-width, stacked
  ///    beneath the title/description.
  Widget _buildIconRowField(Map<String, dynamic> el, String fieldType, ThemeData theme) {
    if (fieldType == 'select') {
      return _buildSelectRow(el, theme);
    }

    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    final leading = icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null;
    final title = Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor));

    if (fieldType == 'checkbox') {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: _buildCompactControl(el, fieldType, devModeColor, expanded: false),
      );
    }

    // Text-like fields: the input renders full-width beneath the title/
    // description rather than trailing beside them, at every panel width.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: leading,
            title: title,
            subtitle: subtitle,
          ),
          _buildCompactControl(el, fieldType, devModeColor, expanded: true),
        ],
      ),
    );
  }

  /// A `fieldType: 'select'` icon-row field: a tappable row showing the
  /// field's own description as the subtitle (that description is written to
  /// explain the current value — see the settings definitions), with the
  /// options picked in a dialog ([_openSelectDialog]) rather than an inline
  /// dropdown. The raw value is not shown on its own line.
  Widget _buildSelectRow(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final desc = el['description'] as String? ?? '';
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    // The row shows the setting's own description, which is written to
    // explain the current value (see the settings definitions); the raw
    // value is not repeated as a separate line.
    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (desc.isNotEmpty) {
      subtitle = Text(desc, style: TextStyle(color: devModeColor));
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(resolveIconName('chevron-right'), color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting ? null : () => _openSelectDialog(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// The picker dialog for a `select` icon-row field: one row per option,
  /// checked against the current value; tapping one commits it (exactly as
  /// the inline control did) and closes.
  Future<void> _openSelectDialog(Map<String, dynamic> el) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final options =
        (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final current = _values[key];

    // Wrap the chosen value in a one-element list so a dismissed dialog
    // (null) is distinguishable from picking an option whose value is null.
    final picked = await showHaloDialog<List<dynamic>>(
      context: context,
      builder: (dialogContext) => HaloDialog(
        title: Text(label),
        // Edge to edge, the way SimpleDialog laid its children out; the shell
        // scrolls the list when the options outgrow the dialog.
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              ListTile(
                title: Text(opt['label'] as String),
                trailing: opt['value'] == current ? Icon(resolveIconName('check')) : null,
                onTap: () => Navigator.pop(dialogContext, [opt['value']]),
                mouseCursor: SystemMouseCursors.click,
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final val = picked.first;
    setState(() {
      _values[key] = val;
      _errors.remove(key);
    });
    _handleFieldBlurOrInteraction(key, val);
  }

  /// `{type: 'link', label, url, icon?, description?}` — an icon-row-styled
  /// tile that hands its URL to [FormRenderer.onOpenLink] (no-op when the
  /// presenter didn't wire one).
  Widget _buildLink(Map<String, dynamic> el, ThemeData theme) {
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final url = el['url'] as String? ?? '';
    final devModeColor = _devModeColor(el);

    final open = url.isEmpty || widget.onOpenLink == null ? null : () => widget.onOpenLink!(url);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: description != null && description.isNotEmpty ? Text(description, style: TextStyle(color: devModeColor)) : null,
      trailing: IconButton(
        icon: Icon(resolveIconName('open-in-new'), size: 22, color: devModeColor),
        tooltip: 'Open page',
        onPressed: open,
      ),
      onTap: open,
      mouseCursor: SystemMouseCursors.click,
    );
  }

  TextInputType? _keyboardTypeFor(String fieldType) => switch (fieldType) {
        'email' => TextInputType.emailAddress,
        'number' => const TextInputType.numberWithOptions(decimal: true, signed: true),
        _ => null,
      };

  /// The one predicate for "does this field force uppercase?": callsign
  /// fields always do; any other text-like field opts in with
  /// `uppercase: true` in its definition (see FormField in the SDK's
  /// types.ts). Both the standard builders (_buildField's text/multiline/
  /// email/callsign cases) and the compact icon-row path derive BOTH
  /// capitalization and formatters from this, so the two layouts can't
  /// disagree on a field's casing.
  bool _isUppercase(String fieldType, Map<String, dynamic> el) =>
      fieldType == 'callsign' || el['uppercase'] == true;

  TextCapitalization _capitalizationFor(String fieldType, Map<String, dynamic> el) =>
      _isUppercase(fieldType, el) ? TextCapitalization.characters : TextCapitalization.none;

  List<TextInputFormatter>? _inputFormattersFor(String fieldType, Map<String, dynamic> el) => switch (fieldType) {
        'number' => [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))],
        _ => _isUppercase(fieldType, el) ? const [UpperCaseTextFormatter()] : null,
      };

  /// The input a text-like icon-row field renders full-width, stacked
  /// beneath its title/description (the caller passes `expanded: true`,
  /// selecting start-aligned full-width text), or the trailing Switch for a
  /// 'checkbox' (which ignores `expanded`).
  Widget _buildCompactControl(Map<String, dynamic> el, String fieldType, Color? devModeColor,
      {required bool expanded}) {
    final key = el['key'] as String;

    switch (fieldType) {
      case 'checkbox':
        return Switch(
          value: _values[key] == true,
          onChanged: _isSubmitting
              ? null
              : (val) {
                  setState(() {
                    _values[key] = val;
                    _errors.remove(key);
                  });
                  _handleFieldBlurOrInteraction(key, val);
                },
        );
      default: // text, multiline, email, callsign, number, secret
        const decoration = InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero);
        // Secret fields get the show/hide toggle (SecretTextField owns the
        // obscuring + the password autofill hint); every other type keeps the
        // plain field with its per-type capitalization/formatters.
        final Widget field = fieldType == 'secret'
            ? SecretTextField(
                controller: _controllers[key],
                focusNode: _focusNodes[key],
                textAlign: expanded ? TextAlign.start : TextAlign.end,
                keyboardType: _keyboardTypeFor(fieldType),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: decoration,
              )
            : TextField(
                controller: _controllers[key],
                focusNode: _focusNodes[key],
                textAlign: expanded ? TextAlign.start : TextAlign.end,
                maxLines: fieldType == 'multiline' ? null : 1,
                minLines: fieldType == 'multiline' ? 3 : null,
                textCapitalization: _capitalizationFor(fieldType, el),
                keyboardType: _keyboardTypeFor(fieldType),
                inputFormatters: _inputFormattersFor(fieldType, el),
                autofillHints: _getAutofillHints(key, fieldType),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: decoration,
              );
        // Stacked (expanded) fields fill the available width; an unexpanded
        // field keeps the legacy 140px compact width.
        return expanded ? field : SizedBox(width: 140, child: field);
    }
  }

  String _listItemTitle(Map<String, dynamic> el, Map<String, dynamic> item) {
    final template = el['itemTitle'] as String?;
    return template != null
        ? _templateString(template, item)
        : item.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => '').toString();
  }

  /// A `fieldType: 'list'` field: a single row summarizing the current
  /// items as a comma-separated list; tapping it opens [_openListEditor]'s
  /// dialog where the actual add/edit/delete/reorder happens.
  Widget _buildListField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final devModeColor = _devModeColor(el);
    final summary = [
      for (final item in items)
        if (_listItemTitle(el, item).isNotEmpty) _listItemTitle(el, item),
    ].join(', ');

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (summary.isNotEmpty) {
      subtitle = Text(summary, style: TextStyle(color: devModeColor));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(resolveIconName('chevron-right'), color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting ? null : () => _openListEditor(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// The list field's editor dialog: a summary row per item plus an "Add"
  /// row. Every mutation commits immediately (autosave, like every other
  /// field) — Done just closes. Editing or adding an item reopens the same
  /// form renderer recursively (via [showFormDialog]) scoped to
  /// `itemFields`, so there's no separate "list item editor" widget — just
  /// a smaller [FormDefinition].
  Future<void> _openListEditor(Map<String, dynamic> el) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final itemFields = (el['itemFields'] as List? ?? const []).cast<Map<String, dynamic>>();
    final orderable = el['orderable'] == true;

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Read through _values each build so both this dialog and the
          // summary row behind it stay live.
          final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();

          Future<void> commit(List<Map<String, dynamic>> newItems) async {
            setState(() {
              _values[key] = newItems;
              _errors.remove(key);
            });
            setDialogState(() {});
            await _handleFieldBlurOrInteraction(key, newItems);
          }

          Future<void> editItem(int? index) async {
            final itemPath = '$key[${index ?? items.length}]';
            final initial = index != null ? Map<String, dynamic>.from(items[index]) : <String, dynamic>{};
            final result = await showFormDialog(
              dialogContext,
              formDefinition: {
                'title': index != null ? 'Edit $label' : 'Add $label',
                'elements': itemFields,
              },
              initialState: initial,
              validator: widget.validator == null
                  ? null
                  : (fieldKey, value, state) => widget.validator!('$itemPath.$fieldKey', value, state),
              transformer: widget.transformer == null
                  ? null
                  : (fieldKey, value, state) => widget.transformer!('$itemPath.$fieldKey', value, state),
              developerMode: widget.developerMode,
            );
            if (result == null) return;
            final newItems = List<Map<String, dynamic>>.from(items);
            if (index != null) {
              newItems[index] = result;
            } else {
              newItems.add(result);
            }
            await commit(newItems);
          }

          void deleteItem(int index) {
            final newItems = List<Map<String, dynamic>>.from(items)..removeAt(index);
            commit(newItems);
          }

          void reorder(int oldIndex, int newIndex) {
            final newItems = List<Map<String, dynamic>>.from(items);
            if (newIndex > oldIndex) newIndex -= 1;
            newItems.insert(newIndex, newItems.removeAt(oldIndex));
            commit(newItems);
          }

          Widget rowFor(int index) {
            final title = _listItemTitle(el, items[index]);
            return ListTile(
              key: ValueKey('$key-item-$index'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(title.isEmpty ? '(untitled)' : title),
              onTap: _isSubmitting ? null : () => editItem(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (orderable) const Icon(Icons.drag_handle, size: 20),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: _isSubmitting ? null : () => deleteItem(index),
                  ),
                ],
              ),
            );
          }

          return HaloDialog(
            wide: true,
            title: Text(label),
            // Rows run edge to edge; the shell's own scroll view is off because
            // this content scrolls itself, and its width comes from the shared
            // sizing rather than a fixed 420.
            contentPadding: EdgeInsets.zero,
            scrollable: false,
            content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (orderable)
                      ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: reorder,
                        children: [for (var i = 0; i < items.length; i++) rowFor(i)],
                      )
                    else
                      for (var i = 0; i < items.length; i++) rowFor(i),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : () => editItem(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add $label'),
                    ),
                  ],
                ),
              ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done')),
            ],
          );
        },
      ),
    );
  }

  /// A `fieldType: 'multiselect'` field: pick several values from a fixed
  /// vocabulary — a single row summarizing the selection as a
  /// comma-separated list, tapping opens [_openMultiselectEditor]. The
  /// dialect: `value` is a plain string list; `options` is
  /// `[{label, value, common?}]` (or an app-resolved `"$system.list"`
  /// name — an unresolved string renders as no options). Options flagged
  /// `common: true` show upfront; the rest sit behind "Show all". The
  /// selection always keeps the canonical order of `options` (`orderable`
  /// is reserved for a future manual-ordering variant).
  Widget _buildMultiselectField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final description = el['description'] as String?;
    final icon = el['icon'] as String?;
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);
    final options = (el['options'] is List) ? (el['options'] as List).cast<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final selected = ((_values[key] as List?) ?? const []).cast<String>();
    final labelFor = {for (final opt in options) opt['value']: opt['label'] as String?};
    final summary = [for (final v in selected) labelFor[v] ?? v].join(', ');

    Widget? subtitle;
    if (errorText != null) {
      subtitle = Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12));
    } else if (summary.isNotEmpty) {
      subtitle = Text(summary, style: TextStyle(color: devModeColor));
    } else if (description != null && description.isNotEmpty) {
      subtitle = Text(description, style: TextStyle(color: devModeColor));
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(resolveIconName('chevron-right'), color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting || options.isEmpty ? null : () => _openMultiselectEditor(el, options),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// The multiselect editor dialog: a switch per option, common ones
  /// upfront, the rest behind a disclosure toggle on the action row (two-
  /// or three-tier — see `tierOf` below). Toggles commit immediately in
  /// canonical `options` order; Done just closes.
  Future<void> _openMultiselectEditor(Map<String, dynamic> el, List<Map<String, dynamic>> options) async {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final defaultValue = el['defaultValue'] is List ? (el['defaultValue'] as List).toSet() : null;

    // Three disclosure tiers: `common: true` options at level 0, unflagged
    // at level 1, `uncommon: true` at level 2. With no uncommon options the
    // toggle is two-state (Show all / Show fewer); with them it cycles
    // Show more → Show all → Show fewer. A vocabulary with no common
    // options at all opens fully expanded with no toggle — collapsing it
    // would leave an empty list.
    int tierOf(Map<String, dynamic> opt) =>
        opt['common'] == true ? 0 : (opt['uncommon'] == true ? 2 : 1);
    final hasCommon = options.any((opt) => tierOf(opt) == 0);
    final hasUncommon = options.any((opt) => tierOf(opt) == 2);
    final hasDisclosure = hasCommon && options.any((opt) => tierOf(opt) > 0);
    var level = hasCommon ? 0 : 2;

    // Vocabularies past browsing size get a search field pinned under the
    // list. While a query is active it matches the ENTIRE vocabulary
    // (ignoring disclosure tiers — that's the point of searching).
    final searchable = options.length > 20;
    final searchController = searchable ? TextEditingController() : null;

    // Uncommon values that earned a place in the common-only view: selected
    // when the dialog opened, or selected at any point while it's open.
    // They stay visible (even deselected, even after "Show fewer") for the
    // dialog's lifetime, so a just-toggled row can't vanish mid-interaction.
    final pinned = ((_values[key] as List?) ?? const []).toSet();

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final theme = Theme.of(dialogContext);
          // Values are treated as opaque (FormFieldOption.value is `any` in
          // the SDK) — membership by equality, never a String cast.
          final currentValue = ((_values[key] as List?) ?? const []);
          final selected = currentValue.toSet();

          // Stored values outside the vocabulary (written by another build,
          // or synced from an app with a newer band/mode table) must
          // neither disappear from the editor nor be silently dropped from
          // the committed value — they render as synthesized rows and are
          // preserved until the user explicitly toggles them off.
          final optionValues = {for (final opt in options) opt['value']};
          List<dynamic> unknownIn(Set<dynamic> values) =>
              [for (final v in currentValue) if (values.contains(v) && !optionValues.contains(v)) v];

          Future<void> commit(Set<dynamic> newSelected) async {
            // Canonical order: filter the vocabulary, don't append; unknown
            // selected values keep their stored order at the end.
            final newValue = [
              for (final opt in options)
                if (newSelected.contains(opt['value'])) opt['value'],
              ...unknownIn(newSelected),
            ];
            setState(() {
              _values[key] = newValue;
              _errors.remove(key);
            });
            setDialogState(() {});
            await _handleFieldBlurOrInteraction(key, newValue);
          }

          Future<void> toggle(dynamic value, bool on) {
            final newSelected = {...selected};
            if (on) {
              newSelected.add(value);
              pinned.add(value);
            } else {
              newSelected.remove(value);
            }
            return commit(newSelected);
          }

          final query = searchController?.text.trim().toLowerCase() ?? '';
          final filtering = query.isNotEmpty;
          final unknownRows = [
            for (final v in currentValue)
              if (!optionValues.contains(v)) {'label': v.toString(), 'value': v},
          ];
          final visible = [
            ...filtering
                ? [
                    for (final opt in options)
                      if (((opt['label'] as String?) ?? opt['value'].toString()).toLowerCase().contains(query)) opt,
                  ]
                : [
                    for (final opt in options)
                      if (tierOf(opt) <= level || pinned.contains(opt['value'])) opt,
                  ],
            ...filtering ? unknownRows.where((r) => (r['label'] as String).toLowerCase().contains(query)) : unknownRows,
          ];
          return HaloDialog(
            wide: true,
            title: Text(label),
            // Rows run edge to edge; the shell's own scroll view is off because
            // this content scrolls itself, and its width comes from the shared
            // sizing rather than a fixed 360.
            contentPadding: EdgeInsets.zero,
            scrollable: false,
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final opt in visible)
                            SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              // Selected values read bold, unselected ones
                              // greyed, so the states scan apart without
                              // hunting for the switch thumbs.
                              title: Text(
                                (opt['label'] as String?) ?? opt['value'].toString(),
                                style: selected.contains(opt['value'])
                                    ? const TextStyle(fontWeight: FontWeight.bold)
                                    : TextStyle(color: theme.disabledColor),
                              ),
                              value: selected.contains(opt['value']),
                              onChanged: _isSubmitting ? null : (on) => toggle(opt['value'], on),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // The filter status sits between the list and the search
                  // field it describes. Both slots carry keys: when the
                  // status row pops in/out the field shifts index, and
                  // without a key Flutter would remold the field's element
                  // into the status row and recreate the field — dropping
                  // its focus mid-typing.
                  if (filtering)
                    Padding(
                      key: const ValueKey('multiselect-status'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Showing ${visible.length} of ${options.length} (${selected.length} selected)',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  if (searchable)
                    Padding(
                      key: const ValueKey('multiselect-search'),
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: !filtering
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'Clear',
                                  onPressed: () => setDialogState(() => searchController!.clear()),
                                ),
                          hintText: 'Search',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ],
              ),
            actions: [
              // One full-width row: the disclosure toggle and Reset live
              // outside the scroll area, on the action row's left, with
              // Done on the right.
              Row(
                children: [
                  // Tier disclosure is meaningless while a query overrides
                  // it — the status row's Reveal takes its place.
                  if (hasDisclosure && !filtering)
                    TextButton.icon(
                      onPressed: () => setDialogState(() {
                        level = switch (level) {
                          0 => hasUncommon ? 1 : 2,
                          1 => 2,
                          _ => 0,
                        };
                      }),
                      icon: Icon(level >= 2 ? Icons.unfold_less : Icons.unfold_more, size: 18),
                      label: Text(switch (level) {
                        0 when hasUncommon => 'Show more',
                        0 => 'Show all',
                        1 => 'Show all',
                        _ => 'Show fewer',
                      }),
                    ),
                  if (defaultValue != null)
                    TextButton.icon(
                      // Restored defaults pin so uncommon ones stay
                      // visible. Deliberately drops any out-of-vocabulary
                      // stored values — Defaults means the declared set.
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              pinned.addAll(defaultValue);
                              commit({...defaultValue});
                            },
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Defaults'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Done')),
                ],
              ),
            ],
          );
        },
      ),
    );
    searchController?.dispose();
  }

  /// A `fieldType: 'account'` field: a read-only reference into the
  /// separate `account` hook system (see docs/extensions/settings.md's
  /// "account field type") — never defines or stores account data itself.
  /// Status is whatever the caller put in the field's `value`, shaped
  /// `{connected: bool, label: String?}`; tapping Manage/Connect calls
  /// [FormManageAccount] with the field's `account.key`/`account.subkey`,
  /// which is expected to open that account's own standalone dialog.
  Widget _buildAccountField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final account = (el['account'] as Map?)?.cast<String, dynamic>();
    final accountKey = account?['key'] as String?;
    final subkey = account?['subkey'] as String?;
    final status = (_values[key] is Map) ? (_values[key] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final connected = status['connected'] == true;
    final statusLabel = status['label'] as String?;
    final devModeColor = _devModeColor(el);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        connected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: devModeColor ?? (connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(label, style: devModeColor == null ? null : TextStyle(color: devModeColor)),
      subtitle: Text(
        connected ? (statusLabel ?? 'Connected') : 'Not Connected',
        style: devModeColor == null ? null : TextStyle(color: devModeColor),
      ),
      trailing: TextButton(
        onPressed: accountKey == null || widget.onManageAccount == null ? null : () => widget.onManageAccount!(accountKey, subkey),
        child: Text(connected ? 'Manage' : 'Connect'),
      ),
    );
  }

  /// A `type: 'action'` element: a button that invokes [FormAction] and
  /// shows the returned string as a result banner.
  Widget _buildActionElement(Map<String, dynamic> el, ThemeData theme) {
    final actionKey = el['key'] as String? ?? '';
    final label = el['label'] as String? ?? '';
    final method = el['method'] as String? ?? '';
    final isRunning = _runningActions.contains(actionKey);
    final devModeColor = _devModeColor(el);

    return OutlinedButton(
      style: devModeColor == null ? null : OutlinedButton.styleFrom(foregroundColor: devModeColor, side: BorderSide(color: devModeColor)),
      onPressed: widget.onAction == null || isRunning
          ? null
          : () async {
              setState(() => _runningActions.add(actionKey));
              String? result;
              try {
                result = await widget.onAction!(actionKey, method, _values);
              } catch (e) {
                result = 'Error: $e';
              }
              if (!mounted) return;
              setState(() => _runningActions.remove(actionKey));
              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
              }
            },
      child: isRunning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// Helper function to display the FormRenderer inside an AlertDialog.
Future<Map<String, dynamic>?> showFormDialog(
  BuildContext context, {
  required Map<String, dynamic> formDefinition,
  required Map<String, dynamic> initialState,
  FormValidator? validator,
  FormTransformer? transformer,
  FormOnChange? onChange,
  FormAction? onAction,
  FormManageAccount? onManageAccount,
  FormOpenLink? onOpenLink,
  bool developerMode = false,
}) {
  final theme = Theme.of(context);
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);

  return showHaloDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HaloDialog(
      wide: true,
      // The shell supplies the header band, its padding AND the title type
      // (the view-header style), so only the subtitle styles itself.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formDefinition['title'] as String? ?? 'Form'),
          if (formDefinition['subtitle'] != null) ...[
            const SizedBox(height: 4),
            Text(
              formDefinition['subtitle'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      // Width comes from the shared sizing now, and the shell scrolls the body.
      content: FormRenderer(
        key: formKey,
        formDefinition: formDefinition,
        initialState: initialState,
        validator: validator,
        transformer: transformer,
        onChange: onChange,
        onAction: onAction,
        onManageAccount: onManageAccount,
        onOpenLink: onOpenLink,
        developerMode: developerMode,
        showActions: false,
        showTitle: false,
        submittingNotifier: submittingNotifier,
        onSubmit: (values) => Navigator.of(context).pop(values),
        onCancel: () => Navigator.of(context).pop(null),
      ),
      // The shell's footer band supplies the background and padding.
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: submittingNotifier,
          builder: (context, isSubmitting, _) => _formActionsRow(
            isSubmitting: isSubmitting,
            onCancel: () => Navigator.of(context).pop(null),
            onSave: () => formKey.currentState?.submit(),
          ),
        ),
      ],
    ),
  );
}

/// [showFormDialog]'s Modal Pane counterpart (see modal_pane.dart): the same
/// form-definition engine presented via [showModalPane], so on XS/S shirt
/// sizes it fills the screen instead of cramming a fixed-width AlertDialog.
/// For pane-sized forms (the QSO full editor); one-or-two-field prompts
/// should keep using [showFormDialog]. Completes with the submitted values,
/// or null on Cancel/close. `barrierDismissible: false` for the same reason
/// showFormDialog passes it to showDialog — a stray tap outside must not
/// discard in-progress edits (the title bar's close button still cancels).
///
/// `scrollable: false` + own Cancel/Save footer, NOT FormRenderer's built-in
/// `showActions` row: that row sits at the bottom of the form content, so on
/// a form taller than the pane it scrolls out of reach — Save must stay
/// pinned below the scrolling fields, same as showFormDialog's action bar.
Future<Map<String, dynamic>?> showFormPane(
  BuildContext context, {
  required Map<String, dynamic> formDefinition,
  required Map<String, dynamic> initialState,
  FormValidator? validator,
  FormTransformer? transformer,
  FormOnChange? onChange,
  FormAction? onAction,
  FormManageAccount? onManageAccount,
  FormOpenLink? onOpenLink,
  bool developerMode = false,
}) {
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);

  return showModalPane<Map<String, dynamic>>(
    context,
    title: formDefinition['title'] as String?,
    barrierDismissible: false,
    scrollable: false,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: submittingNotifier,
      // While a submit's async validators/transformers are in flight the
      // pane must not be dismissible — the old AlertDialog guaranteed this
      // with barrierDismissible:false plus a disabled Cancel, but the
      // pane's title-bar close button, Escape, and the XS/S back button
      // would otherwise pop null mid-submit and silently discard edits the
      // user explicitly saved (submit()'s mounted guard drops the result).
      // All three dismissal paths go through Navigator.maybePop (see
      // modal_pane.dart), which this PopScope blocks; the deliberate pops
      // below (Save's onSubmit, the footer's Cancel) call pop() directly
      // and are unaffected.
      builder: (context, isSubmitting, child) => PopScope(canPop: !isSubmitting, child: child!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: FormRenderer(
                key: formKey,
                formDefinition: formDefinition,
                initialState: initialState,
                validator: validator,
                transformer: transformer,
                onChange: onChange,
                onAction: onAction,
                onManageAccount: onManageAccount,
                onOpenLink: onOpenLink,
                developerMode: developerMode,
                // The pane's own title bar already shows formDefinition['title'].
                showTitle: false,
                showActions: false,
                submittingNotifier: submittingNotifier,
                onSubmit: (values) => Navigator.of(context).pop(values),
                onCancel: () => Navigator.of(context).pop(null),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: submittingNotifier,
            builder: (context, isSubmitting, _) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _formActionsRow(
                isSubmitting: isSubmitting,
                onCancel: () => Navigator.of(context).pop(null),
                onSave: () => formKey.currentState?.submit(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A fullscreen view wrapping the FormRenderer.
class FormView extends StatefulWidget {
  final Map<String, dynamic> formDefinition;
  final Map<String, dynamic> initialState;
  final FormValidator? validator;
  final FormTransformer? transformer;
  final FormOnChange? onChange;
  final FormAction? onAction;
  final FormManageAccount? onManageAccount;
  final FormOpenLink? onOpenLink;
  final void Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback onCancel;
  final bool developerMode;

  const FormView({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    this.onAction,
    this.onManageAccount,
    this.onOpenLink,
    required this.onSubmit,
    required this.onCancel,
    this.developerMode = false,
  });

  @override
  State<FormView> createState() => _FormViewState();
}

class _FormViewState extends State<FormView> {
  final _formKey = GlobalKey<FormRendererState>();
  final _submittingNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _submittingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.formDefinition['title'] as String? ?? 'Form'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: FormRenderer(
              key: _formKey,
              formDefinition: widget.formDefinition,
              initialState: widget.initialState,
              validator: widget.validator,
              transformer: widget.transformer,
              onChange: widget.onChange,
              onAction: widget.onAction,
              onManageAccount: widget.onManageAccount,
              onOpenLink: widget.onOpenLink,
              developerMode: widget.developerMode,
              showActions: false,
              showTitle: false,
              submittingNotifier: _submittingNotifier,
              onSubmit: widget.onSubmit,
              onCancel: widget.onCancel,
            ),
          ),
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _submittingNotifier,
        builder: (context, isSubmitting, _) {
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _formActionsRow(
                  isSubmitting: isSubmitting,
                  onCancel: widget.onCancel,
                  onSave: () => _formKey.currentState?.submit(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
