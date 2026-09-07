// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// One extension's own settings panel, rendered from its declarative
// definition, with its account rows resolved to the accounts dialog.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/link_opener.dart';
import '../../settings/settings_catalog.dart' show elementSearchScore;
import '../../settings/settings_registry.dart';

import 'accounts_panel.dart';
import 'settings_category.dart';

/// Renders one extension-contributed `settingsPanel` panel — the
/// `descriptor` (from `getSettingsPanels()`) says which registration
/// (`hookKey`) and tier (`kind`) it is; `panelKey` disambiguates when a
/// Tier 2 registration serves more than one panel. `FormRenderer`'s
/// `onChange` is repurposed as the autosave point: validate, then (Tier 2
/// only) transform, then commit — nothing is persisted unless it passes
/// validation, but the field keeps whatever the user typed either way,
/// same as any other live form.
class ExtensionSettingsPanel extends StatefulWidget {
  final HaLoServices services;
  final Map<String, dynamic> descriptor;

  /// Embedded: rendered as a shrink-wrapped category inside the Settings
  /// panel's scroll view instead of a standalone scrolling panel.
  final bool embedded;

  /// What heads this panel in embedded mode — the category band it opens
  /// under, or, inside Common Settings, the plain section heading over its
  /// contribution. Lives here (not in the parent) so a search query that
  /// empties the panel hides its heading along with it.
  final String? sectionTitle;

  /// The Settings panel's search query (lowercased); empty shows
  /// everything.
  final String searchQuery;

  /// Common Settings mode: keep only elements the extension flagged
  /// `common: true` (settings_registry.dart's [elementIsCommon]) — same
  /// convention as `_SettingsGroupForm`'s `commonOnly` (settings_view.dart). False shows
  /// everything the panel declares (minus whatever `environment` rules
  /// out — that filter always applies, common or not).
  final bool commonOnly;

  /// Whether this category's rows are showing. Ignored when [onToggle] is
  /// null, and meaningless outside [embedded] mode.
  final bool expanded;

  /// Toggles [expanded], and by being non-null asks for the category
  /// heading — see [_SettingsGroupForm.onToggle], which this mirrors.
  final VoidCallback? onToggle;

  /// See [_SettingsGroupForm.onRowsChanged], which this mirrors: an
  /// extension's definition decides its own element set, and a Tier 2 panel
  /// rebuilds that set on every commit.
  final VoidCallback? onRowsChanged;

  const ExtensionSettingsPanel({
    super.key,
    required this.services,
    required this.descriptor,
    this.embedded = false,
    this.sectionTitle,
    this.searchQuery = '',
    this.commonOnly = false,
    this.expanded = true,
    this.onToggle,
    this.onRowsChanged,
  });

  @override
  State<ExtensionSettingsPanel> createState() => _ExtensionSettingsPanelState();
}

class _ExtensionSettingsPanelState extends State<ExtensionSettingsPanel> {
  Map<String, dynamic>? _definition;
  bool _loading = true;
  List<Map<String, dynamic>>? _accountsCache;
  int? _lastRowIdentity;

  // _load() is called from two places that can fire back-to-back for the
  // same underlying change: _autosave's own reload after a commit, and the
  // SettingsService listener below — committing a core setting notifies
  // listeners synchronously, mid-commit, before _autosave reaches its own
  // reload. Without this guard, one field edit fires two concurrent
  // getSettingsPanelDefinition bridge calls that race on `setState`. This
  // coalesces any _load() calls that arrive while one is already in flight
  // into a single extra pass once the current one finishes, instead of
  // running them in parallel.
  bool _reloading = false;
  bool _reloadPending = false;

  // FormRenderer always calls onChange (_autosave) and then validator
  // (_validate) back-to-back for the same (fieldKey, value) on every blur/
  // interaction — without this, each interaction would run
  // validateSettingsField's bridge call twice (autosave's own gate, then
  // FormRenderer's separate validator call) and, worse, the two calls could
  // disagree. Cache the one real result and let the second call reuse it.
  String? _lastValidatedFieldKey;
  dynamic _lastValidatedValue;
  String? _lastValidationError;

  String get _hookKey => widget.descriptor['hookKey'] as String;
  String get _panelKey => widget.descriptor['panelKey'] as String;
  String get _kind => widget.descriptor['kind'] as String;

  @override
  void initState() {
    super.initState();
    _load();
    // Picks up changes made outside this panel — e.g. font scale via
    // keyboard shortcuts (main.dart) — which call SettingsService directly
    // and never go through _autosave's own reload.
    widget.services.settings.addListener(_load);
    widget.services.extensions.runtimeGeneration.addListener(_runtimeChanged);
    // A commit made by ANOTHER instance of this same panel — the Settings
    // panel shows a `common: true` field both under Common Settings and in
    // the panel's own category. Neither commit path notifies
    // SettingsService, so the listener above never hears it, and the copy
    // left holding the old value writes it back on the next interaction.
    widget.services.extensions.settingsGeneration.addListener(_load);
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_load);
    widget.services.extensions.runtimeGeneration.removeListener(_runtimeChanged);
    widget.services.extensions.settingsGeneration.removeListener(_load);
    super.dispose();
  }

  /// A restart (crash recovery, or the user enabling/disabling an extension)
  /// replaces the whole runtime: the panel's definition and the accounts it
  /// references both belong to the generation they were fetched from, so
  /// neither may outlive it — [_accountsCache] especially, since nothing
  /// else clears it until a dialog saves.
  void _runtimeChanged() {
    _accountsCache = null;
    _load();
  }

  Future<void> _load() async {
    if (_reloading) {
      _reloadPending = true;
      return;
    }
    _reloading = true;
    try {
      do {
        _reloadPending = false;
        var definition = await widget.services.extensions.getSettingsPanelDefinition(
          hookKey: _hookKey,
          panelKey: _panelKey,
          kind: _kind,
        );
        // Extension-declared fields can reference system lists too.
        if (definition?['elements'] is List) {
          final resolved = await widget.services.systemLists
              .resolveInElements((definition!['elements'] as List).cast<Map<String, dynamic>>());
          // Platform-excluded elements don't exist on this session at all —
          // baked in here rather than filtered per-view, same as
          // `_SettingsGroupForm` (settings_view.dart). _fieldFor/validate/commit only ever look
          // up keys FormRenderer actually rendered, so dropping them here
          // is safe for those paths too.
          definition = {...definition, 'elements': filterElementsForEnvironment(resolved)};
        }
        if (!mounted) continue;
        final elements = (definition?['elements'] as List? ?? const []).cast<Map<String, dynamic>>();
        final identity = settingsRowIdentity(elements);
        setState(() {
          _definition = definition;
          _loading = false;
        });
        if (identity != _lastRowIdentity) {
          _lastRowIdentity = identity;
          widget.onRowsChanged?.call();
        }
      } while (_reloadPending && mounted);
    } finally {
      _reloading = false;
    }
  }

  Map<String, dynamic> _fieldFor(String fieldKey) {
    final elements = (_definition?['elements'] as List? ?? const []).cast<Map<dynamic, dynamic>>();
    for (final el in elements) {
      if (el['type'] == 'field' && el['key'] == fieldKey) return el.cast<String, dynamic>();
    }
    return const {};
  }

  Future<String?> _validate(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    if (_lastValidatedFieldKey == fieldKey && _lastValidatedValue == value) {
      return _lastValidationError;
    }
    final error = await widget.services.extensions.validateSettingsField(
      kind: _kind,
      hookKey: _hookKey,
      panelKey: _panelKey,
      field: _fieldFor(fieldKey),
      fieldKey: fieldKey,
      value: value,
      state: state,
    );
    _lastValidatedFieldKey = fieldKey;
    _lastValidatedValue = value;
    _lastValidationError = error;
    return error;
  }

  Future<Map<String, dynamic>?> _autosave(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    if (await _validate(fieldKey, value, state) != null) return null;
    final field = _fieldFor(fieldKey);
    final committedValue = _kind == 'dynamic'
        ? await widget.services.extensions.transformSettingsField(
            hookKey: _hookKey,
            panelKey: _panelKey,
            fieldKey: fieldKey,
            value: value,
            state: state,
          )
        : value;
    await widget.services.extensions.commitSettingsFieldValue(
      kind: _kind,
      hookKey: _hookKey,
      panelKey: _panelKey,
      fieldKey: fieldKey,
      value: committedValue,
      state: state,
      isSecret: field['fieldType'] == 'secret',
      restartOnChange: field['restartOnChange'] == true,
    );
    // Re-fetch so the panel reflects whatever the commit actually changed —
    // not just this field's own value, but anything getDefinition derives
    // from it (a hook keying labels off ctx.locale, fields that appear/
    // disappear based on another field's value, etc.). _load() only shows
    // its loading spinner on the very first call (_loading starts true);
    // by now it's already false, so this swaps _definition in place with
    // no flash.
    if (mounted) await _load();
    return null;
  }

  Future<void> _manageAccount(String accountKey, String? subkey) async {
    if (subkey != null) {
      // No AccountHook registration today can produce more than one account
      // under the same kvKey, so there's nothing to disambiguate against
      // yet — surfaced rather than silently ignored (see
      // docs/extensions/settings.md's account field type note on subkey).
      debugPrint(
        '[settings] account field requested subkey "$subkey" for "$accountKey", but '
        'subkey-based account disambiguation is not implemented yet — matching by kvKey only.',
      );
    }
    // Cache only a real answer: getAccounts() returns null when the extensions
    // couldn't be asked (dead runtime, a hook timing out), and caching that
    // would freeze this panel into "no accounts" for the rest of its life —
    // every later tap on the field would then do nothing.
    final accounts = _accountsCache ?? await widget.services.extensions.getAccounts();
    if (accounts == null) {
      // Say so: the user pressed Connect and no dialog is coming, which
      // otherwise reads as a dead button with the reason only in the log.
      widget.services.statusBar.setMessage(key: 'accounts:lookup', text: t.settings.accounts.lookupFailed);
      return;
    }
    _accountsCache = accounts;
    Map<String, dynamic>? account;
    for (final a in accounts) {
      if (a['kvKey'] == accountKey) {
        account = a;
        break;
      }
    }
    if (account == null || !mounted) return;
    await showModalPane<void>(
      context,
      title: account['label'] as String,
      barrierDismissible: false,
      closeLabel: context.t.common.close,
      builder: (context) => AccountPane(
        services: widget.services,
        account: account!,
        onSaved: () {
          _accountsCache = null;
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.embedded
          ? const Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: CircularProgressIndicator()))
          : const Center(child: CircularProgressIndicator());
    }
    var definition = _definition;
    if (definition == null) {
      return Center(child: Text(context.t.settings.developer.panelLoadFailed));
    }
    if (widget.commonOnly) {
      final common = [
        for (final el in (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>())
          if (elementIsCommon(el)) el,
      ];
      if (common.isEmpty) return const SizedBox.shrink();
      definition = {...definition, 'elements': common};
    }
    // Hidden, not unmounted — same rule as the core groups above, and for
    // the same reason ([settingsCategory]). There is one of these per
    // extension, so a query that stops matching would otherwise take dozens
    // of them out of the tree at once.
    var searchHidden = false;
    if (widget.searchQuery.isNotEmpty) {
      // Scored and sorted, exactly as `_SettingsGroupForm` (settings_view.dart) does for core
      // groups. Subsequence matching is permissive enough that filtering
      // alone barely narrows anything, so an extension's rows left in
      // declaration order would be the same loose match with none of the
      // ranking that makes it usable — a difference the operator would read
      // as the search working on some categories and not others.
      final panelElements = (definition['elements'] as List? ?? const []).cast<Map<String, dynamic>>();
      final scored = <({Map<String, dynamic> element, int score, int index})>[];
      for (var i = 0; i < panelElements.length; i++) {
        final score = elementSearchScore(panelElements[i], widget.searchQuery);
        if (score != null) scored.add((element: panelElements[i], score: score, index: i));
      }
      // See _SettingsGroupForm: Dart's sort is not stable, so ties need an
      // explicit fallback or the rows move about as the query is typed.
      scored.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore != 0 ? byScore : a.index.compareTo(b.index);
      });
      searchHidden = scored.isEmpty;
      if (!searchHidden) definition = {...definition, 'elements': [for (final s in scored) s.element]};
    }

    final form = FormRenderer(
      formDefinition: definition,
      initialState: const {},
      showActions: false,
      // Embedded, the heading above the form names it — the form's own
      // definition title would double it.
      showTitle: !widget.embedded,
      developerMode: widget.services.settings.developerMode,
      settingsList: true,
      validator: _validate,
      onChange: _autosave,
      onAction: (actionKey, method, state) async {
        final message = await widget.services.extensions.runSettingsAction(
          hookKey: _hookKey,
          panelKey: _panelKey,
          method: method,
          state: state,
        );
        return message == null ? null : FormActionResult(message: message);
      },
      onManageAccount: _manageAccount,
      onOpenLink: openExternalUrl,
      onSubmit: (_) {},
      onCancel: () {},
    );
    // Embedded, this panel is one CATEGORY of the list that hosts it,
    // headed and collapsible exactly as a core group's is
    // (`_SettingsGroupForm`, settings_view.dart) — an extension's settings are one of these,
    // and a plain line of text among headed ones would read as a different
    // kind of thing.
    if (widget.embedded) {
      final title = widget.sectionTitle;
      if (title == null) {
        return Visibility(
          visible: !searchHidden,
          maintainState: true,
          child: ExcludeFocus(excluding: searchHidden, child: form),
        );
      }
      return settingsCategory(
        context,
        title: title,
        expanded: widget.expanded,
        onToggle: widget.onToggle,
        hidden: searchHidden,
        child: form,
      );
    }

    return Visibility(
      visible: !searchHidden,
      maintainState: true,
      child: ExcludeFocus(
        excluding: searchHidden,
        child: SingleChildScrollView(
          // No horizontal padding: rows run to the pane's edges and inset
          // their own contents from the ambient ListTileTheme.
          padding: const EdgeInsets.symmetric(vertical: Space.xl),
          child: form,
        ),
      ),
    );
  }
}
