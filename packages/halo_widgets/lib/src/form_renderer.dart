// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'theme.dart';

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);

/// Renders a form from a dynamic JSON definition, coordinating input fields,
/// headers, section dividers, and markdown text blocks. Supports initial state,
/// actions (Submit/Cancel), and asynchronous JS-backed validation and transformation.
class FormRenderer extends StatefulWidget {
  final Map<String, dynamic> formDefinition;
  final Map<String, dynamic> initialState;
  final FormValidator? validator;
  final FormTransformer? transformer;
  final FormOnChange? onChange;
  final void Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback onCancel;
  final bool showActions;
  final bool showTitle;
  final ValueNotifier<bool>? submittingNotifier;

  const FormRenderer({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    required this.onSubmit,
    required this.onCancel,
    this.showActions = true,
    this.showTitle = true,
    this.submittingNotifier,
  });

  @override
  State<FormRenderer> createState() => FormRendererState();
}

class FormRendererState extends State<FormRenderer> {
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, String> _errors = {};
  bool _isSubmitting = false;

  List<Map<String, dynamic>> get _elements =>
      (widget.formDefinition['elements'] as List? ?? const []).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> get _fields =>
      _elements.where((el) => el['type'] == 'field').toList();

  @override
  void initState() {
    super.initState();
    _initializeFormState();
  }

  void _initializeFormState() {
    for (final field in _fields) {
      final key = field['key'] as String;
      final fieldType = field['fieldType'] as String;
      var val = widget.initialState[key] ?? field['value'];
      if (val == null) {
        if (fieldType == 'checkbox') {
          val = false;
        } else if (['select', 'radio', 'number'].contains(fieldType)) {
          val = null;
        } else {
          val = '';
        }
      }
      _values[key] = val;

      if (['text', 'multiline', 'email', 'callsign', 'number'].contains(fieldType)) {
        final controller = TextEditingController(text: val?.toString() ?? '');
        _controllers[key] = controller;
        controller.addListener(() {
          final text = controller.text;
          dynamic parsed = text;
          if (fieldType == 'number') {
            parsed = num.tryParse(text);
          }
          setState(() {
            _values[key] = parsed;
            _errors.remove(key);
          });
        });

        final focusNode = FocusNode();
        _focusNodes[key] = focusNode;
        focusNode.addListener(() {
          if (!focusNode.hasFocus) {
            _handleFieldBlurOrInteraction(key, _values[key]);
          }
        });
      }
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
                default:
                  return const SizedBox.shrink();
              }
            },
          ),
          if (widget.showActions) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                if (_isSubmitting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton(
                    onPressed: submit,
                    child: const Text('Save'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String? ?? '';
    final subtitle = el['subtitle'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
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
    return MarkdownBody(data: text);
  }

  Widget _buildField(Map<String, dynamic> el, ThemeData theme) {
    final fieldType = el['fieldType'] as String?;
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final placeholder = el['placeholder'] as String?;
    final options = (el['options'] as List? ?? const []).cast<Map<String, dynamic>>();
    final errorText = _errors[key];

    switch (fieldType) {
      case 'text':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          autofillHints: _getAutofillHints(key, 'text'),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
        );
      case 'multiline':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          maxLines: null,
          minLines: 3,
          autofillHints: _getAutofillHints(key, 'multiline'),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
        );
      case 'email':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          keyboardType: TextInputType.emailAddress,
          autofillHints: _getAutofillHints(key, 'email'),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
        );
      case 'callsign':
        return TextField(
          controller: _controllers[key],
          focusNode: _focusNodes[key],
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase())),
          ],
          autofillHints: _getAutofillHints(key, 'callsign'),
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
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
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
        );
      case 'select':
        return DropdownButtonFormField<dynamic>(
          value: _values[key],
          decoration: poloFieldDecoration(context, label, hintText: placeholder, errorText: errorText),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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
        );
      case 'checkbox':
        return CheckboxListTile(
          title: Text(label),
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
        );
      default:
        return const SizedBox.shrink();
    }
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.of(context).pop(null),
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
                      onPressed: () => formKey.currentState?.submit(),
                      child: const Text('Save'),
                    ),
                ],
              ),
            );
          },
        ),
      ],
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
  final void Function(Map<String, dynamic> values) onSubmit;
  final VoidCallback onCancel;

  const FormView({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    required this.onSubmit,
    required this.onCancel,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : widget.onCancel,
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
                        onPressed: () => _formKey.currentState?.submit(),
                        child: const Text('Save'),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
