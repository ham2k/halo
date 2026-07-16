// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'icon_resolver.dart';
import 'modal_pane.dart';
import 'text_formatters.dart';
import 'theme.dart';

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormAction = Future<String?> Function(String actionKey, String method, Map<String, dynamic> state);
typedef FormManageAccount = void Function(String accountKey, String? subkey);

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
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        onPressed: isSubmitting ? null : onCancel,
        child: const Text('Cancel'),
      ),
      const SizedBox(width: 12),
      if (isSubmitting)
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      else
        FilledButton(
          onPressed: onSave,
          child: const Text('Save'),
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
    final options = (el['options'] as List? ?? const []).cast<Map<String, dynamic>>();
    final errorText = _errors[key];
    final devModeColor = _devModeColor(el);

    switch (fieldType) {
      case 'text':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          textCapitalization: _capitalizationFor('text', el),
          inputFormatters: _inputFormattersFor('text', el),
          autofillHints: _getAutofillHints(key, 'text'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'multiline':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          maxLines: null,
          minLines: 3,
          textCapitalization: _capitalizationFor('multiline', el),
          inputFormatters: _inputFormattersFor('multiline', el),
          autofillHints: _getAutofillHints(key, 'multiline'),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'email':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          keyboardType: TextInputType.emailAddress,
          textCapitalization: _capitalizationFor('email', el),
          inputFormatters: _inputFormattersFor('email', el),
          autofillHints: _getAutofillHints(key, 'email'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'callsign':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          textCapitalization: _capitalizationFor('callsign', el),
          inputFormatters: _inputFormattersFor('callsign', el),
          autofillHints: _getAutofillHints(key, 'callsign'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'number':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
          ],
          autofillHints: _getAutofillHints(key, 'number'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'secret':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText, labelColor: devModeColor),
        );
      case 'list':
        return _buildListField(el, theme);
      case 'account':
        return _buildAccountField(el, theme);
      case 'select':
        return DropdownButtonFormField<dynamic>(
          value: _values[key],
          focusNode: _focusNodes[key],
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

  /// Below this width, an icon-row field stacks its control under the
  /// title/description instead of trailing beside them — a compact
  /// dropdown or 140px text field next to a label leaves too little room
  /// for either on a narrow panel/phone screen. A toggle is exempt (see
  /// [_buildIconRowField]): a Switch is already as small as it gets, and
  /// stacking it under a one-line label would waste more space than it
  /// saves.
  static const _iconRowStackBreakpoint = 400.0;

  /// The Sync/Accounts panel row shape: leading icon, bold title, an
  /// optional description underneath (or the validation error, in its
  /// place), and a compact version of the field's control on the trailing
  /// side — as opposed to the standalone Material input the default
  /// [_buildField] switch renders. Below [_iconRowStackBreakpoint], the
  /// control instead renders full-width on its own row underneath, unless
  /// it's a toggle (checkbox), which always stays trailing.
  Widget _buildIconRowField(Map<String, dynamic> el, String fieldType, ThemeData theme) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _iconRowStackBreakpoint) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailing: _buildCompactControl(el, fieldType, devModeColor, expanded: false),
          );
        }
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
      },
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

  /// `expanded` is the narrow-layout, stacked-under-the-title form: full
  /// width instead of a fixed compact size, start-aligned text instead of
  /// end-aligned (there's no label/description to its left to align
  /// against anymore). Ignored for 'checkbox', which is never stacked.
  Widget _buildCompactControl(Map<String, dynamic> el, String fieldType, Color? devModeColor, {required bool expanded}) {
    final key = el['key'] as String;
    final options = (el['options'] as List? ?? const []).cast<Map<String, dynamic>>();

    switch (fieldType) {
      case 'select':
        final dropdown = DropdownButtonHideUnderline(
          child: DropdownButton<dynamic>(
            value: _values[key],
            isExpanded: expanded,
            items: [for (final opt in options) DropdownMenuItem(value: opt['value'], child: Text(opt['label'] as String))],
            onChanged: _isSubmitting
                ? null
                : (val) {
                    setState(() {
                      _values[key] = val;
                      _errors.remove(key);
                    });
                    _handleFieldBlurOrInteraction(key, val);
                  },
          ),
        );
        return expanded ? SizedBox(width: double.infinity, child: dropdown) : dropdown;
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
        final field = TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          textAlign: expanded ? TextAlign.start : TextAlign.end,
          obscureText: fieldType == 'secret',
          maxLines: fieldType == 'multiline' ? null : 1,
          minLines: fieldType == 'multiline' ? 3 : null,
          textCapitalization: _capitalizationFor(fieldType, el),
          keyboardType: _keyboardTypeFor(fieldType),
          inputFormatters: _inputFormattersFor(fieldType, el),
          autofillHints: fieldType == 'secret' ? const [AutofillHints.password] : _getAutofillHints(key, fieldType),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => submit(),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
        );
        return expanded ? field : SizedBox(width: 140, child: field);
    }
  }

  /// A `fieldType: 'list'` field: a summary row per item plus an "Add" row.
  /// Editing or adding an item reopens the same form renderer recursively
  /// (via [showFormDialog]) scoped to `itemFields`, so there's no separate
  /// "list item editor" widget — just a smaller [FormDefinition].
  Widget _buildListField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final itemFields = (el['itemFields'] as List? ?? const []).cast<Map<String, dynamic>>();
    final itemTitleTemplate = el['itemTitle'] as String?;
    final orderable = el['orderable'] == true;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final devModeColor = _devModeColor(el);

    Future<void> commit(List<Map<String, dynamic>> newItems) async {
      setState(() {
        _values[key] = newItems;
        _errors.remove(key);
      });
      await _handleFieldBlurOrInteraction(key, newItems);
    }

    Future<void> editItem(int? index) async {
      final itemPath = '$key[${index ?? items.length}]';
      final initial = index != null ? Map<String, dynamic>.from(items[index]) : <String, dynamic>{};
      final result = await showFormDialog(
        context,
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
      final item = items[index];
      final title = itemTitleTemplate != null
          ? _templateString(itemTitleTemplate, item)
          : item.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => '').toString();
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
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _isSubmitting ? null : () => deleteItem(index),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
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
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
      ],
    );
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
  bool developerMode = false,
}) {
  final theme = Theme.of(context);
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      clipBehavior: Clip.antiAlias,
      titlePadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      title: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.08),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formDefinition['title'] as String? ?? 'Form',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'RobotoSlab',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
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
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: FormRenderer(
            key: formKey,
            formDefinition: formDefinition,
            initialState: initialState,
            validator: validator,
            transformer: transformer,
            onChange: onChange,
            onAction: onAction,
            onManageAccount: onManageAccount,
            developerMode: developerMode,
            showActions: false,
            showTitle: false,
            submittingNotifier: submittingNotifier,
            onSubmit: (values) => Navigator.of(context).pop(values),
            onCancel: () => Navigator.of(context).pop(null),
          ),
        ),
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: submittingNotifier,
          builder: (context, isSubmitting, _) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _formActionsRow(
                isSubmitting: isSubmitting,
                onCancel: () => Navigator.of(context).pop(null),
                onSave: () => formKey.currentState?.submit(),
              ),
            );
          },
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
