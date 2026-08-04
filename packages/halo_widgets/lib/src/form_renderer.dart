// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'halo_dialog.dart';
import 'icon_resolver.dart';
import 'mdi_icons.g.dart';
import 'modal_pane.dart';
import 'secret_text_field.dart';
import 'spacing.dart';
import 'text_formatters.dart';
import 'theme.dart';

typedef FormValidator = Future<String?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormTransformer = Future<dynamic> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormOnChange = Future<Map<String, dynamic>?> Function(String fieldKey, dynamic value, Map<String, dynamic> state);
typedef FormAction = Future<FormActionResult?> Function(String actionKey, String method, Map<String, dynamic> state);
typedef FormManageAccount = void Function(String accountKey, String? subkey);
typedef FormOpenLink = void Function(String url);

/// What a `type: 'action'` element's handler — or, same contract, a
/// `select` option with `isAction: true` — can do: show the operator a
/// result message, hand values back to sibling fields, replace the form's
/// own element list, or any mix of the three. An action that picks
/// something on the operator's behalf (a serial port their OS just
/// granted, an OAuth-returned identifier) needs the second: a bare result
/// string, the only thing the original contract could return, has nowhere
/// to put a picked value except a message they'd have to retype into the
/// field themselves. [elements] exists for the case a picked value isn't
/// even offered yet by the CURRENT element list — a newly-granted device
/// has to become a selectable option, not just a `_values` entry with no
/// matching item in its own dropdown.
class FormActionResult {
  final String? message;
  final Map<String, dynamic>? fieldUpdates;
  final List<Map<String, dynamic>>? elements;

  const FormActionResult({this.message, this.fieldUpdates, this.elements});
}

/// Substitutes `${key}` placeholders in [template] with values from [item].
String _templateString(String template, Map<String, dynamic> item) {
  return template.replaceAllMapped(RegExp(r'\$\{([^}]+)\}'), (m) => item[m.group(1)]?.toString() ?? '');
}

/// The localizable vocabulary for the renderer's own chrome — action
/// buttons, editor dialogs, icon-button names, and error prefixes. Field labels,
/// titles, and options come from the form definition itself, so localizing
/// those is the definition author's job. Defaults to English so the widget
/// package stays usable standalone (same pattern as QsoListLabels); the app
/// injects a locale-aware instance. Parameterized labels are nullable
/// functions (same convention as LoggingControls' `spotSelfLabel` etc.) so
/// the class stays const-constructible — null falls back to the English
/// composition at the call site.
class FormRendererLabels {
  final String cancel;
  final String save;
  final String done;

  /// A list-editor row whose item has no non-empty field to title it by.
  final String untitledItem;

  /// The multiselect editor's disclosure toggle states.
  final String showMore;
  final String showAll;
  final String showFewer;

  /// The multiselect editor's restore-defaults button.
  final String defaults;

  /// The multiselect editor's search field hint and clear-button name.
  final String searchHint;
  final String clearLabel;

  /// A `type: 'link'` element's open button name.
  final String openPageLabel;

  /// A repeating-list row's remove button name (icon-only).
  final String removeItemLabel;

  /// An `account` field's status line and Manage/Connect button.
  final String connected;
  final String notConnected;

  /// Shown in place of [notConnected] when the account's status says the
  /// credential store could not be reached — "not connected" would be a claim
  /// about the account, when the truth is about the machine.
  final String storageUnavailable;
  final String manage;
  final String connect;

  /// [showFormDialog]'s title when the definition has none.
  final String formTitle;

  /// [showFormPane]'s modal-pane close button name (threaded through to
  /// [showModalPane]).
  final String closeLabel;

  /// The list editor's "Add `<field label>`" / "Edit `<field label>`" titles.
  final String Function(String label)? addItem;
  final String Function(String label)? editItem;

  /// The "Showing X of Y (Z selected)" status line shown while a
  /// multiselect search filter is active.
  final String Function(int shown, int total, int selected)? multiselectStatus;

  /// Error prefixes: field validation/transformation failures at submit
  /// time, and a `type: 'action'` handler throwing.
  final String Function(String error)? validationError;
  final String Function(String error)? transformationError;
  final String Function(String error)? actionError;

  const FormRendererLabels({
    this.cancel = 'Cancel',
    this.save = 'Save',
    this.done = 'Done',
    this.untitledItem = '(untitled)',
    this.showMore = 'Show more',
    this.showAll = 'Show all',
    this.showFewer = 'Show fewer',
    this.defaults = 'Defaults',
    this.searchHint = 'Search',
    this.clearLabel = 'Clear',
    this.openPageLabel = 'Open page',
    this.removeItemLabel = 'Remove',
    this.connected = 'Connected',
    this.notConnected = 'Not Connected',
    this.storageUnavailable = 'Logins unavailable',
    this.manage = 'Manage',
    this.connect = 'Connect',
    this.formTitle = 'Form',
    this.closeLabel = 'Close',
    this.addItem,
    this.editItem,
    this.multiselectStatus,
    this.validationError,
    this.transformationError,
    this.actionError,
  });

  static const english = FormRendererLabels();

  String addItemLabel(String label) => addItem?.call(label) ?? 'Add $label';
  String editItemLabel(String label) => editItem?.call(label) ?? 'Edit $label';
  String multiselectStatusLabel(int shown, int total, int selected) =>
      multiselectStatus?.call(shown, total, selected) ?? 'Showing $shown of $total ($selected selected)';
  String validationErrorLabel(String error) => validationError?.call(error) ?? 'Validation error: $error';
  String transformationErrorLabel(String error) => transformationError?.call(error) ?? 'Transformation error: $error';
  String actionErrorLabel(String error) => actionError?.call(error) ?? 'Error: $error';
}

/// The three callbacks a `fieldType: 'list'` editor needs — built by
/// `_FormRendererState._listFieldActions`, shared by both presentations
/// (`_buildInlineListField`'s inline rows and `_openListEditor`'s dialog).
class _ListFieldActions {
  final Future<void> Function(int? index) editItem;
  final void Function(int index) deleteItem;
  final void Function(int oldIndex, int newIndex) reorder;

  const _ListFieldActions({required this.editItem, required this.deleteItem, required this.reorder});
}

/// The Cancel/Save (+ submitting spinner) row shared by every presenter of
/// a [FormRenderer] — the renderer's own `showActions` footer,
/// [showFormDialog]'s action bar, and [showFormPane]'s pinned footer. Only
/// the row lives here; each presenter keeps its own chrome (tinted
/// container, SafeArea, padding) around it, so a change to the submission
/// UX lands in all three at once.
Widget _formActionsRow({
  required bool isSubmitting,
  required VoidCallback? onCancel,
  required VoidCallback? onSave,
  required FormRendererLabels labels,
  ({String label, VoidCallback onPressed, Color color})? destructive,
}) {
  return Row(
    children: [
      TextButton(
        onPressed: isSubmitting ? null : onCancel,
        child: Text(labels.cancel),
      ),
      // Destructive actions belong in the footer with the other verbs, not
      // in the body among the settings — and in the error colour, at the
      // leading edge, well away from Save.
      if (destructive != null) ...[
        const SizedBox(width: Space.md),
        TextButton(
          // The colour travels WITH the action rather than as a second
          // optional beside it: the point of this button is that a
          // destructive verb reads as destructive, and a caller that
          // supplied one and forgot the other would get a Remove button
          // indistinguishable from Cancel.
          style: TextButton.styleFrom(foregroundColor: destructive.color),
          onPressed: isSubmitting ? null : destructive.onPressed,
          child: Text(destructive.label),
        ),
      ],
      // A minimum gap even on a narrow row — Expanded alone only keeps Save
      // from overlapping Cancel, not from sitting flush against it.
      const SizedBox(width: Space.lg),
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
                  child: Text(labels.save),
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

  /// An action's (or an actionable `select` option's) [FormActionResult.elements]
  /// reaching the caller — the caller owns [formDefinition], not this
  /// widget, so applying a new element list means the caller rebuilding
  /// this widget with it, not something this widget can do to itself. Null
  /// means whoever built this [FormRenderer] never wired the result up —
  /// [FormActionResult.elements] is silently dropped rather than crashing,
  /// same as an ignored [FormAction] result already does elsewhere.
  final ValueChanged<List<Map<String, dynamic>>>? onElementsChanged;

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

  /// Localized chrome vocabulary — defaults to English; the app passes a
  /// locale-aware instance (see FormRendererLabels).
  final FormRendererLabels labels;

  const FormRenderer({
    super.key,
    required this.formDefinition,
    required this.initialState,
    this.validator,
    this.transformer,
    this.onChange,
    this.onAction,
    this.onElementsChanged,
    this.onManageAccount,
    this.onOpenLink,
    required this.onSubmit,
    required this.onCancel,
    this.showActions = true,
    this.showTitle = true,
    this.submittingNotifier,
    this.developerMode = false,
    this.labels = FormRendererLabels.english,
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

  /// Bumped after every action runs, and folded into every `select` field's
  /// widget key. `DropdownButtonFormField` tracks which item is selected
  /// internally once built — an `isAction` option stays visually "selected"
  /// after being tapped no matter what `onChanged` does with `_values`, so
  /// the fix is forcing the field to remount from `_values` fresh rather
  /// than trying to talk it out of what it already decided.
  int _actionGeneration = 0;

  List<Map<String, dynamic>> get _elements => (widget.formDefinition['elements'] as List? ?? const [])
      .cast<Map<String, dynamic>>()
      .where((el) => el['devMode'] != true || widget.developerMode)
      .toList();

  /// The orange "dev mode" accent for an element flagged `devMode: true` —
  /// null once [_elements] has already excluded it, so no builder needs its
  /// own visibility check, only this color check.
  Color? _devModeColor(Map<String, dynamic> el) => el['devMode'] == true ? HaLoColors.of(context).devMode : null;

  /// Every row (ListTile-based or not) aligns to the SAME inset: whatever an
  /// ancestor `ListTileTheme` declares as its default `contentPadding` (e.g.
  /// settings_view.dart's wide-layout wrapper), or none at all for every
  /// other FormRenderer caller (dialogs, embedded forms), which keep the
  /// flush-left look those callers already size their own container for.
  EdgeInsetsGeometry get _rowContentPadding => ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;

  List<Map<String, dynamic>> get _fields =>
      _elements.where((el) => el['type'] == 'field').toList();

  /// [_elements] minus any whose `visibleWhen` predicate doesn't currently
  /// hold (docs/design/contests.md §5.4.1) — IARU HF's setup shows one of three
  /// sent-exchange fields depending on the station type chosen in the same
  /// form, which no static definition and no `onChange` closure can express
  /// across the extension bridge.
  ///
  /// **Only [build] may use this.** [_fields] — and therefore field
  /// registration, [_initializeFormState] and [submit] — stays deliberately
  /// unfiltered: [_buildField] passes `controller: _controllers[key]` with no
  /// lazy creation, so a field first initialized when it became visible would
  /// render against a null controller and silently drop everything typed into
  /// it. Registering every declared field up front is what makes that
  /// impossible.
  ///
  /// The consequence is that a hidden field still submits its value, which is
  /// the behaviour we want: type a zone, switch to HQ, switch back, and the
  /// zone is still there. A form's consumer must therefore choose by the
  /// discriminator field, never by "first non-empty".
  ///
  /// Reads [_values], so any field's `setState` re-evaluates visibility.
  List<Map<String, dynamic>> get _visibleElements => _elements.where(_isVisible).toList();

  /// Whether [el]'s `visibleWhen` holds. `equals` may be a single value or a
  /// list meaning "any of". Naming a field that doesn't exist reads as null and
  /// so hides the element — a definition that points at nothing shows nothing,
  /// rather than throwing in the middle of someone's setup dialog.
  bool _isVisible(Map<String, dynamic> el) {
    final when = el['visibleWhen'];
    if (when is! Map) return true;
    final actual = _values[when['field']];
    final expected = when['equals'];
    return expected is List ? expected.contains(actual) : actual == expected;
  }

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
    if (fieldType == 'select' && val != null) {
      // The state a field is seeded from OUTLIVES the options it is offered.
      // An extension's option list can depend on the rest of the form — State
      // Parks offers Texas three power classes and Ohio two — while the value
      // persists on the ref, so switching that operation to Ohio leaves a `QRP`
      // no Ohio dropdown has an item for. `DropdownButton` asserts that its
      // value is exactly one of its items, so the form would throw instead of
      // rendering. Dropping it here also means Save clears it, rather than
      // writing back a value nothing downstream will honour.
      final options = (field['options'] as List?)?.cast<Map>() ?? const [];
      if (options.isNotEmpty && !options.any((opt) => opt['value'] == val)) {
        val = options.any((opt) => opt['value'] == field['value']) ? field['value'] : null;
      }
    }
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
    } else if (fieldType == 'select') {
      focusNode.onKeyEvent = (node, event) => _handleSelectKeyEvent(key, event);
    }
  }

  /// Up/Down cycle a focused-but-closed `select` field through its options,
  /// wrapping at either end — `DropdownButtonFormField`'s own arrow-key
  /// handling only kicks in once its popup menu is open, so a field that is
  /// merely focused otherwise ignores the keys entirely.
  KeyEventResult _handleSelectKeyEvent(String key, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final logicalKey = event.logicalKey;
    if (logicalKey != LogicalKeyboardKey.arrowDown && logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (_isSubmitting) return KeyEventResult.ignored;
    final field = _fields.firstWhere((f) => f['key'] == key, orElse: () => const {});
    final options = (field['options'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    if (options.isEmpty) return KeyEventResult.ignored;

    final delta = logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final currentIndex = options.indexWhere((opt) => opt['value'] == _values[key]);
    final nextIndex =
        currentIndex < 0 ? (delta > 0 ? 0 : options.length - 1) : (currentIndex + delta) % options.length;
    final nextValue = options[nextIndex]['value'];

    setState(() {
      _values[key] = nextValue;
      _errors.remove(key);
    });
    _handleFieldBlurOrInteraction(key, nextValue);
    return KeyEventResult.handled;
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

  /// Merges externally-supplied values (an `onChange` result, an action's
  /// [FormActionResult.fieldUpdates]) into [_values], keeping any live
  /// `TextEditingController` in sync — a `select`/`checkbox`/etc. field
  /// reads `_values` directly each build, but a text-type field's on-screen
  /// text is the controller's, not `_values`', so `setState` alone would
  /// update the model without the operator seeing it change.
  void _applyFieldUpdates(Map<String, dynamic> updates) {
    if (updates.isEmpty || !mounted) return;
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

  Future<void> _handleFieldBlurOrInteraction(String key, dynamic value) async {
    if (widget.onChange != null) {
      try {
        final updates = await widget.onChange!(key, value, _values);
        if (updates != null) _applyFieldUpdates(updates);
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
          errors[key] = widget.labels.validationErrorLabel(e.toString());
        }
      }

      // Transform if valid
      if (errors[key] == null && widget.transformer != null) {
        try {
          final transformed = await widget.transformer!(key, val, _values);
          transformedValues[key] = transformed;
        } catch (e) {
          errors[key] = widget.labels.transformationErrorLabel(e.toString());
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
    final elements = _visibleElements;

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
                color: HaLoColors.of(context).onSurfaceAccent,
              ),
            ),
            const SizedBox(height: Space.xs),
          ],
          if (widget.showTitle && widget.formDefinition['subtitle'] != null) ...[
            Text(
              widget.formDefinition['subtitle'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.xl),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: elements.length,
            separatorBuilder: (context, index) => const SizedBox(height: Space.xl),
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
            const SizedBox(height: Space.xxl),
            _formActionsRow(isSubmitting: _isSubmitting, onCancel: widget.onCancel, onSave: submit, labels: widget.labels),
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
    // Text on the surface, not a fill — HaLoColors.onSurfaceAccent, not
    // colorScheme.primary directly.
    final onSurfaceAccent = (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent;
    final titleStyle = isSection
        ? theme.textTheme.titleSmall?.copyWith(color: devModeColor ?? onSurfaceAccent)
        : theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'RobotoSlab',
            fontWeight: FontWeight.w900,
            color: devModeColor ?? onSurfaceAccent,
          );
    return Padding(
      padding: _rowContentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: Space.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: devModeColor ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(Map<String, dynamic> el, ThemeData theme) {
    final title = el['title'] as String?;
    if (title == null || title.isEmpty) {
      return const Divider();
    }
    final devModeColor = _devModeColor(el);
    final onSurfaceAccent = (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent;
    return Padding(
      padding: _rowContentPadding,
      child: Row(
        children: [
          // Flexible, not bare: the title is a full sentence in some forms
          // ("If two serial ports show up for the same radio"), and an
          // unbounded Text beside an Expanded divider overflows the row in a
          // narrow pane rather than wrapping.
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: devModeColor ?? onSurfaceAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMarkdown(Map<String, dynamic> el, ThemeData theme) {
    final text = el['text'] as String? ?? '';
    final devModeColor = _devModeColor(el);
    final styleSheet = devModeColor == null ? null : MarkdownStyleSheet(p: TextStyle(color: devModeColor));
    if (el['collapsible'] == true) {
      return Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: _CollapsibleMarkdown(
          title: Text(
            el['title'] as String? ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor),
          ),
          child: Align(alignment: Alignment.centerLeft, child: MarkdownBody(data: text, styleSheet: styleSheet)),
        ),
      );
    }
    return Padding(
      padding: _rowContentPadding,
      child: MarkdownBody(data: text, styleSheet: styleSheet),
    );
  }

  static const _iconRowSupportedTypes = {'text', 'multiline', 'email', 'callsign', 'number', 'secret', 'select', 'checkbox'};

  /// Field types that can take the icon-row shape (see [_buildIconRowField]).
  /// 'list', 'radio', and 'account' fall back to their normal full-width
  /// rendering even when `icon` is set — a multi-option or multi-row control
  /// has no single control to hang off a labeled row.
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
          selectAllOnFocus: false,
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
          // See _actionGeneration: forces a remount from the true
          // _values[key] after any action runs, since this widget
          // otherwise keeps showing whatever item was last tapped —
          // including an isAction option that never became the value.
          key: ValueKey('$key-$_actionGeneration'),
          value: _values[key],
          focusNode: _focusNodes[key],
          icon: dropdownTrailingIcon,
          menuMaxHeight: dropdownMenuMaxHeight(context),
          // Fill the field rather than taking the width of the widest OPTION,
          // which is what an unexpanded dropdown does — one long label (a
          // contest sponsor's own description of an entry category, say)
          // would overflow the whole dialog to the right, for every extension.
          isExpanded: true,
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
                  // An `isAction` option (the web serial transport's
                  // "add a USB device", so far, sitting right in the port
                  // list rather than as a separate button) never becomes
                  // this field's value — picking it runs an action instead,
                  // same contract a `type: 'action'` element's button uses.
                  // Leaving `val` unselected here (rather than setting it
                  // then reverting it once the action resolves) means there
                  // is nothing to revert if the operator cancels the
                  // browser's own picker partway through.
                  final picked = options.firstWhere((o) => o['value'] == val, orElse: () => const {});
                  if (picked['isAction'] == true) {
                    unawaited(_runAction(val as String, picked['method'] as String? ?? ''));
                    return;
                  }
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
              const SizedBox(height: Space.xs),
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
                  contentPadding: _rowContentPadding,
                  dense: true,
                ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs, left: Space.xs),
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
            contentPadding: _rowContentPadding,
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
        contentPadding: _rowContentPadding,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: _buildCompactControl(el, fieldType, devModeColor),
      );
    }

    // Text-like fields: the input renders full-width beneath the title/
    // description rather than trailing beside them, at every panel width.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: _rowContentPadding,
            leading: leading,
            title: title,
            subtitle: subtitle,
          ),
          _buildCompactControl(el, fieldType, devModeColor),
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
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
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
        // Edge to edge, matching SimpleDialog's child layout; the shell
        // scrolls the list when the options outgrow the dialog.
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in options)
              ListTile(
                title: Text(opt['label'] as String),
                trailing: opt['value'] == current ? const Icon(MdiIcons.check) : null,
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
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: description != null && description.isNotEmpty ? Text(description, style: TextStyle(color: devModeColor)) : null,
      trailing: IconButton(
        icon: Icon(
          MdiIcons.openInNew,
          size: 22,
          color: devModeColor,
          semanticLabel: widget.labels.openPageLabel,
        ),
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

  /// The control an icon-row field renders: the trailing Switch for a
  /// 'checkbox', or — for every text-like type — the input the row stacks
  /// full-width beneath its title/description.
  Widget _buildCompactControl(Map<String, dynamic> el, String fieldType, Color? devModeColor) {
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
        // The label lives in the row above, so `placeholder` is the only hint
        // this layout can show — and the full-width layout already honors it
        // (via poloFieldDecoration). Dropping it here would make the same
        // element render differently depending on whether it carried an `icon`.
        //
        // The hint needs dimming to the same 0.38 poloFieldDecoration uses,
        // and for the same reason: Material's default renders it at full
        // strength, which is indistinguishable from an actual value sitting
        // in the field. Only the color, not a font size — this field inherits
        // its size and has no scale factor to apply (ui-scaling.md).
        final hintColor = devModeColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
        final decoration = InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: el['placeholder'] as String?,
          hintStyle: TextStyle(color: hintColor.withValues(alpha: 0.38)),
        );
        // Secret fields get the show/hide toggle (SecretTextField owns the
        // obscuring + the password autofill hint); every other type keeps the
        // plain field with its per-type capitalization/formatters.
        return fieldType == 'secret'
            ? SecretTextField(
                controller: _controllers[key],
                focusNode: _focusNodes[key],
                keyboardType: _keyboardTypeFor(fieldType),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                decoration: decoration,
              )
            : TextField(
                selectAllOnFocus: false,
                controller: _controllers[key],
                focusNode: _focusNodes[key],
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
    }
  }

  String _listItemTitle(Map<String, dynamic> el, Map<String, dynamic> item) {
    final template = el['itemTitle'] as String?;
    return template != null
        ? _templateString(template, item)
        : item.values.firstWhere((v) => v != null && v.toString().isNotEmpty, orElse: () => '').toString();
  }

  /// A `fieldType: 'list'` field. `inline: true` renders the item rows (with
  /// a reorder handle/delete button per row, and an Add row) directly here
  /// — see [_buildInlineListField]. Otherwise: a single row summarizing the
  /// current items as a comma-separated list; tapping it opens
  /// [_openListEditor]'s dialog where the actual add/edit/delete/reorder
  /// happens.
  Widget _buildListField(Map<String, dynamic> el, ThemeData theme) {
    if (el['inline'] == true) return _buildInlineListField(el, theme);

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
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
      onTap: _isSubmitting ? null : () => _openListEditor(el),
      mouseCursor: SystemMouseCursors.click,
    );
  }

  /// `inline: true`'s rendering: the same add/edit/delete/reorder behavior
  /// as [_openListEditor] (both built from [_listFieldActions]), just laid
  /// out directly in the form instead of behind a summary row that opens a
  /// dialog — for a list that IS the section's content (e.g. call-notes'
  /// custom files), not one field among several. Tapping a row (or Add)
  /// still opens the `itemFields` editor dialog; only the outer
  /// reorder/delete/add wrapper is inline instead of a second, nested
  /// dialog.
  Widget _buildInlineListField(Map<String, dynamic> el, ThemeData theme) {
    final key = el['key'] as String;
    final label = el['label'] as String? ?? '';
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;
    final errorText = _errors[key];
    final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    final actions = _listFieldActions(context: context, key: key, el: el, items: items, itemLabel: itemLabel);

    Widget rowFor(int index) {
      final title = _listItemTitle(el, items[index]);
      return ListTile(
        key: ValueKey('$key-item-$index'),
        contentPadding: _rowContentPadding,
        // Leading, not trailing (unlike the dialog editor's drag handle) —
        // the drag gesture is scoped to just this icon via the listener
        // below, so it can't be confused with the row's own onTap.
        leading: orderable
            ? ReorderableDragStartListener(index: index, child: const Icon(MdiIcons.dragHorizontalVariant))
            : null,
        title: Text(title.isEmpty ? widget.labels.untitledItem : title),
        onTap: _isSubmitting ? null : () => actions.editItem(index),
        trailing: IconButton(
          icon: Icon(MdiIcons.delete, size: 20, semanticLabel: widget.labels.removeItemLabel),
          onPressed: _isSubmitting ? null : () => actions.deleteItem(index),
        ),
        mouseCursor: SystemMouseCursors.click,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Padding(
            padding: _rowContentPadding,
            child: Text(errorText, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ),
        if (orderable)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: actions.reorder,
            // Otherwise, on a desktop/web (mouse) platform, the framework
            // auto-adds its OWN trailing drag handle to every row — landing
            // right on top of the delete IconButton above. rowFor already
            // wires up its own leading handle via ReorderableDragStartListener.
            buildDefaultDragHandles: false,
            children: [for (var i = 0; i < items.length; i++) rowFor(i)],
          )
        else
          for (var i = 0; i < items.length; i++) rowFor(i),
        Padding(
          padding: _rowContentPadding,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => actions.editItem(null),
            icon: const Icon(MdiIcons.plus, size: 18),
            label: Text(widget.labels.addItemLabel(itemLabel)),
          ),
        ),
      ],
    );
  }

  /// The add/edit/delete/reorder behavior shared by [_buildInlineListField]
  /// and [_openListEditor] — the only thing that differs between the two
  /// presentations is the surrounding chrome (an inline `Column` vs a
  /// `HaloDialog`) and each row's own layout, both of which stay with their
  /// respective callers. [items] is the current value list at the moment
  /// of the call — both callers already re-derive it from `_values[key]`
  /// on every rebuild they care about (the inline field's own `build`, or
  /// the dialog's `StatefulBuilder`), so a plain list is enough; nothing
  /// here needs to re-read it later. [afterCommit], when given, runs right
  /// after a commit's `setState` — only the dialog needs it, to also
  /// refresh its own `StatefulBuilder` (the inline field's `build` already
  /// covers that).
  _ListFieldActions _listFieldActions({
    required BuildContext context,
    required String key,
    required Map<String, dynamic> el,
    required List<Map<String, dynamic>> items,
    required String itemLabel,
    VoidCallback? afterCommit,
  }) {
    final itemFields = (el['itemFields'] as List? ?? const []).cast<Map<String, dynamic>>();

    Future<void> commit(List<Map<String, dynamic>> newItems) async {
      setState(() {
        _values[key] = newItems;
        _errors.remove(key);
      });
      afterCommit?.call();
      await _handleFieldBlurOrInteraction(key, newItems);
    }

    Future<void> editItem(int? index) async {
      final itemPath = '$key[${index ?? items.length}]';
      final initial = index != null ? Map<String, dynamic>.from(items[index]) : <String, dynamic>{};
      final result = await showFormDialog(
        context,
        formDefinition: {
          'title': index != null ? widget.labels.editItemLabel(itemLabel) : widget.labels.addItemLabel(itemLabel),
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
        labels: widget.labels,
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

    return _ListFieldActions(editItem: editItem, deleteItem: deleteItem, reorder: reorder);
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
    // Matches _buildInlineListField's own fallback — without it, a non-inline
    // list field that declares itemLabel had it silently ignored here,
    // showing the plural container label in the Add/Edit dialog and button
    // instead.
    final itemLabel = el['itemLabel'] as String? ?? label;
    final orderable = el['orderable'] == true;

    await showHaloDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Read through _values each build so both this dialog and the
          // summary row behind it stay live.
          final items = ((_values[key] as List?) ?? const []).cast<Map<String, dynamic>>();
          final actions = _listFieldActions(
            context: dialogContext,
            key: key,
            el: el,
            items: items,
            itemLabel: itemLabel,
            // The inline field's own `build` already picks up a commit via
            // the outer setState; this dialog is a separate overlay that
            // needs telling explicitly to redraw with the new items.
            afterCommit: () => setDialogState(() {}),
          );

          Widget rowFor(int index) {
            final title = _listItemTitle(el, items[index]);
            return ListTile(
              key: ValueKey('$key-item-$index'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(title.isEmpty ? widget.labels.untitledItem : title),
              onTap: _isSubmitting ? null : () => actions.editItem(index),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A real drag listener, not decoration — with the
                  // framework's auto handle off below, this icon IS the
                  // drag affordance (same wiring as the inline editor's
                  // leading handle).
                  if (orderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(MdiIcons.dragHorizontalVariant, size: 20),
                    ),
                  IconButton(
                    icon: Icon(MdiIcons.delete, size: 20, semanticLabel: widget.labels.removeItemLabel),
                    onPressed: _isSubmitting ? null : () => actions.deleteItem(index),
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
            // sizing.
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
                        // Same as the inline editor: on mouse platforms the
                        // framework auto-adds its own trailing handle to
                        // every row, doubling the row's own — the trailing
                        // icon above carries the ReorderableDragStartListener
                        // instead.
                        buildDefaultDragHandles: false,
                        onReorder: actions.reorder,
                        children: [for (var i = 0; i < items.length; i++) rowFor(i)],
                      )
                    else
                      for (var i = 0; i < items.length; i++) rowFor(i),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : () => actions.editItem(null),
                      icon: const Icon(MdiIcons.plus, size: 18),
                      label: Text(widget.labels.addItemLabel(itemLabel)),
                    ),
                  ],
                ),
              ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(widget.labels.done)),
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
      contentPadding: _rowContentPadding,
      leading: icon != null ? Icon(resolveIconName(icon), color: devModeColor) : null,
      title: Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: devModeColor)),
      subtitle: subtitle,
      trailing: Icon(MdiIcons.chevronRight, color: devModeColor ?? theme.colorScheme.onSurfaceVariant),
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
            // sizing.
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
                      padding: const EdgeInsets.only(top: Space.md),
                      child: Text(
                        widget.labels.multiselectStatusLabel(visible.length, options.length, selected.length),
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  if (searchable)
                    Padding(
                      key: const ValueKey('multiselect-search'),
                      padding: const EdgeInsets.only(top: Space.md),
                      child: TextField(
                        selectAllOnFocus: false,
                        controller: searchController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(MdiIcons.magnify, size: 18),
                          suffixIcon: !filtering
                              ? null
                              : IconButton(
                                  icon: Icon(MdiIcons.close, size: 18, semanticLabel: widget.labels.clearLabel),
                                  onPressed: () => setDialogState(() => searchController!.clear()),
                                ),
                          hintText: widget.labels.searchHint,
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
                      icon: Icon(level >= 2 ? MdiIcons.unfoldLessHorizontal : MdiIcons.unfoldMoreHorizontal, size: 18),
                      label: Text(switch (level) {
                        0 when hasUncommon => widget.labels.showMore,
                        0 => widget.labels.showAll,
                        1 => widget.labels.showAll,
                        _ => widget.labels.showFewer,
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
                      icon: const Icon(MdiIcons.restore, size: 18),
                      label: Text(widget.labels.defaults),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(widget.labels.done)),
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
    // The account hook reports this when the credential store threw: the app
    // could not look, which is not the same as a signed-out account, and a
    // Connect button here would walk the operator into a save that fails.
    final unavailable = status['unavailable'] == true;
    final statusLabel = status['label'] as String?;
    final devModeColor = _devModeColor(el);

    return ListTile(
      contentPadding: _rowContentPadding,
      leading: Icon(
        unavailable ? MdiIcons.keyRemove : (connected ? MdiIcons.checkCircle : MdiIcons.radioboxBlank),
        color: devModeColor ??
            (connected
                ? (theme.extension<HaLoColors>() ?? HaLoColors.light).onSurfaceAccent
                : theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(label, style: devModeColor == null ? null : TextStyle(color: devModeColor)),
      subtitle: Text(
        unavailable
            ? widget.labels.storageUnavailable
            : connected
                ? (statusLabel ?? widget.labels.connected)
                : widget.labels.notConnected,
        style: devModeColor == null ? null : TextStyle(color: devModeColor),
      ),
      trailing: TextButton(
        onPressed: accountKey == null || widget.onManageAccount == null || unavailable
            ? null
            : () => widget.onManageAccount!(accountKey, subkey),
        child: Text(connected ? widget.labels.manage : widget.labels.connect),
      ),
    );
  }

  /// Runs [FormAction] for [actionKey]/[method] and applies whatever comes
  /// back — [FormActionResult.fieldUpdates] to the fields they belong to,
  /// [FormActionResult.elements] handed up to whoever owns this form's
  /// definition (see [FormRenderer.onElementsChanged]), and
  /// [FormActionResult.message] as a result banner. Shared by the `action`
  /// element's button and a `select` field's `isAction` option — an
  /// option that grants access to something (a serial port the OS just
  /// authorized) is the same shape of operation as a button that does,
  /// just triggered by a different gesture.
  Future<void> _runAction(String actionKey, String method) async {
    if (widget.onAction == null) return;
    setState(() => _runningActions.add(actionKey));
    FormActionResult? result;
    try {
      result = await widget.onAction!(actionKey, method, _values);
    } catch (e) {
      result = FormActionResult(message: widget.labels.actionErrorLabel(e.toString()));
    }
    if (!mounted) return;
    setState(() {
      _runningActions.remove(actionKey);
      _actionGeneration++;
    });
    final updates = result?.fieldUpdates;
    if (updates != null) _applyFieldUpdates(updates);
    final elements = result?.elements;
    if (elements != null) widget.onElementsChanged?.call(elements);
    final message = result?.message;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// A `type: 'action'` element: a button that runs [_runAction].
  Widget _buildActionElement(Map<String, dynamic> el, ThemeData theme) {
    final actionKey = el['key'] as String? ?? '';
    final label = el['label'] as String? ?? '';
    final method = el['method'] as String? ?? '';
    final isRunning = _runningActions.contains(actionKey);
    final devModeColor = _devModeColor(el);

    return OutlinedButton(
      style: devModeColor == null ? null : OutlinedButton.styleFrom(foregroundColor: devModeColor, side: BorderSide(color: devModeColor)),
      onPressed: widget.onAction == null || isRunning ? null : () => _runAction(actionKey, method),
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
  FormRendererLabels labels = FormRendererLabels.english,
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
          Text(formDefinition['title'] as String? ?? labels.formTitle),
          if (formDefinition['subtitle'] != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              formDefinition['subtitle'] as String,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      // Width comes from the shared sizing, and the shell scrolls the body.
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
        labels: labels,
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
            labels: labels,
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
  FormRendererLabels labels = FormRendererLabels.english,
  /// A destructive action for the footer, beside Cancel and in its own
  /// colour. The PANE CLOSES FIRST and then the callback runs, so the
  /// callback owns only the confirmation. A caller cannot pop it itself
  /// safely: it holds the context it opened the pane from, and popping
  /// through that removes whatever route is topmost — a menu overlay from
  /// one of the form's own select fields, say — leaving the editor open
  /// over equipment that is being deleted underneath it.
  ({String label, VoidCallback onPressed, Color color})? destructiveAction,
}) {
  final formKey = GlobalKey<FormRendererState>();
  final submittingNotifier = ValueNotifier<bool>(false);
  // An action (or an actionable select option) can replace the element
  // list mid-edit — a newly-granted device becoming a selectable option,
  // say — so `formDefinition['elements']` can't just be handed to
  // [FormRenderer] once; this is what [FormRenderer.onElementsChanged]
  // pushes into.
  final elementsNotifier = ValueNotifier<List<Map<String, dynamic>>>(
    (formDefinition['elements'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
  );

  return showModalPane<Map<String, dynamic>>(
    context,
    title: formDefinition['title'] as String?,
    barrierDismissible: false,
    scrollable: false,
    closeLabel: labels.closeLabel,
    builder: (context) => ValueListenableBuilder<bool>(
      valueListenable: submittingNotifier,
      // While a submit's async validators/transformers are in flight the
      // pane must not be dismissible — the pane's title-bar close button,
      // Escape, and the XS/S back button would otherwise pop null mid-submit
      // and silently discard edits the user explicitly saved (submit()'s
      // mounted guard drops the result).
      // All three dismissal paths go through Navigator.maybePop (see
      // modal_pane.dart), which this PopScope blocks; the deliberate pops
      // below (Save's onSubmit, the footer's Cancel) call pop() directly
      // and are unaffected.
      builder: (context, isSubmitting, child) => PopScope(canPop: !isSubmitting, child: child!),
      // min + Flexible, not max + Expanded: the Column asks for only the
      // height the form needs, so the dialog card shrink-wraps a short form
      // instead of stranding the footer at the bottom of a full-height card.
      // spaceBetween is what keeps the footer pinned when the box is taller
      // than the form anyway (the full-screen presentation, which IS the
      // screen): the slack falls between the fields and the footer.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.lg, Space.xxl, Space.lg),
              child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: elementsNotifier,
                builder: (context, elements, _) => FormRenderer(
                  key: formKey,
                  formDefinition: {...formDefinition, 'elements': elements},
                  initialState: initialState,
                  validator: validator,
                  transformer: transformer,
                  onChange: onChange,
                  onAction: onAction,
                  onElementsChanged: (updated) => elementsNotifier.value = updated,
                  onManageAccount: onManageAccount,
                  onOpenLink: onOpenLink,
                  developerMode: developerMode,
                  labels: labels,
                  // The pane's own title bar already shows formDefinition['title'].
                  showTitle: false,
                  showActions: false,
                  submittingNotifier: submittingNotifier,
                  onSubmit: (values) => Navigator.of(context).pop(values),
                  onCancel: () => Navigator.of(context).pop(null),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: submittingNotifier,
            builder: (context, isSubmitting, _) => Padding(
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.md, Space.xxl, Space.xl),
              child: _formActionsRow(
                isSubmitting: isSubmitting,
                onCancel: () => Navigator.of(context).pop(null),
                onSave: () => formKey.currentState?.submit(),
                labels: labels,
                destructive: destructiveAction == null
                    ? null
                    : (
                        label: destructiveAction.label,
                        color: destructiveAction.color,
                        // This context is INSIDE the pane, so the pop is
                        // the pane's own, not whatever happens to be on top
                        // of the caller's navigator.
                        onPressed: () {
                          Navigator.of(context).pop(null);
                          destructiveAction.onPressed();
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


/// A collapsible markdown section: an [ExpansionTile] with an MDI chevron
/// (the framework's default trailing is a Material glyph in an MDI app).
/// A widget of its own because the chevron has to flip with the tile's
/// open/closed state — ExpansionTile rotates only its default trailing; a
/// custom one is never rotated for us.
class _CollapsibleMarkdown extends StatefulWidget {
  final Widget title;
  final Widget child;

  const _CollapsibleMarkdown({required this.title, required this.child});

  @override
  State<_CollapsibleMarkdown> createState() => _CollapsibleMarkdownState();
}

class _CollapsibleMarkdownState extends State<_CollapsibleMarkdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final padding = ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero;
    return ExpansionTile(
      tilePadding: padding,
      childrenPadding: padding,
      trailing: Icon(_expanded ? MdiIcons.chevronUp : MdiIcons.chevronDown),
      onExpansionChanged: (open) => setState(() => _expanded = open),
      title: widget.title,
      children: [widget.child],
    );
  }
}
