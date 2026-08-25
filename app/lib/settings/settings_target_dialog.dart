// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A settings modal built from a subset of the app's declared settings rather
// than a whole group — the logging panel's tune icon, for one, doesn't want
// All Settings or even the whole `LoggingSettingsGroup`, just the handful
// of elements that opted into `target: 'logging'`, plus a "show more
// settings" disclosure for the `'logging-extended'` bucket. Any part of the
// app can call [showSettingsForTarget] with its own target string; nothing
// here is logging-specific — the title and any Actions-section items are
// entirely the caller's to decide. [showSettingsForKeys] picks by key
// instead, for the SET/SHOW/HIDE commands.
//
// The elements themselves come from [scanSettings] (settings_scan.dart),
// which walks every group in [SettingsRegistry] AND every extension
// settingsPanel, so a dialog can span core groups and extensions alike, and
// so the commands' catalog can't drift from what this dialog would show. All
// this file decides is which scanned elements to keep.
// `type: 'action'` elements and `fieldType: 'account'` fields are both
// wired up (onAction dispatches through [ExtensionService.runSettingsAction];
// onManageAccount reuses [showAccountDialogByKey], reloading once its pane
// closes so a status field this dialog shows doesn't go stale) — the same
// as the full All Settings screen, just reached from a curated target
// instead of a whole panel. Every extension-facing call receives `state`
// scoped to that element's OWN panel (bare field keys, stripped of the
// `<panelKey>.` prefix and of every other panel's/core's keys) — never
// this dialog's combined, cross-panel `_values` map, which an extension's
// hook has no way to make sense of. A caller whose target includes a
// `type: 'action'` element needs a Scaffold ancestor (for the action's
// result-banner SnackBar) — same requirement the full All Settings screen
// already has, just not one this file can enforce on the caller's behalf.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/link_opener.dart';
import '../tools/form_chrome_labels.dart';
import '../views/settings_view.dart' show showAccountDialogByKey;
import 'settings_registry.dart';
import 'settings_scan.dart';

/// One row in the dialog's "Actions" section — caller-supplied, never a
/// declared setting. [onTap] is responsible for closing the dialog itself
/// (via `Navigator.pop`) if that's the desired effect; this widget doesn't
/// assume one way or the other.
typedef TargetDialogAction = ({String icon, String label, VoidCallback onTap});

/// Opens a dialog listing every declared setting whose `target` attribute
/// is [target], with a `'<target>-extended'` bucket hidden behind a "show
/// more settings" toggle. [actions], if given, render as their own banded
/// "Actions" section below the settings — for things the caller needs
/// reachable from here that aren't themselves a persisted setting (e.g. the
/// logging panel's "Lookup all QSOs"), so they never get declared with a
/// `target` of their own.
Future<void> showSettingsForTarget(
  BuildContext context, {
  required HaLoServices services,
  required String target,
  required String title,
  List<TargetDialogAction> actions = const [],
}) =>
    _showSettingsDialog(
      context,
      services: services,
      title: title,
      actions: actions,
      inBase: (scanned) => elementMatchesTarget(scanned.element, target),
      inExtended: (scanned) => elementMatchesTarget(scanned.element, '$target-extended'),
    );

/// The same target-scoped settings form [showSettingsForTarget] renders
/// inside its own dialog, as a plain widget — for a caller that wants to
/// embed it in a surface it already owns (the pane layout options dialog's
/// "Panel Settings" section, for a native panel whose settings are more
/// than [PanelDefinition.formFields] can express) instead of opening a
/// second dialog over it.
Widget settingsFormForTarget({
  required HaLoServices services,
  required String target,
  List<TargetDialogAction> actions = const [],
}) => _TargetSettingsForm(
  services: services,
  inBase: (scanned) => elementMatchesTarget(scanned.element, target),
  inExtended: (scanned) => elementMatchesTarget(scanned.element, '$target-extended'),
  order: null,
  stripVisibleWhen: false,
  actions: actions,
);

/// Opens the same dialog around a specific set of settings, named by the
/// `key`s [scanSettings] reports — how SET/SHOW/HIDE show every setting a
/// query matched (settings_command.dart).
///
/// Selecting by key rather than by `target` is the whole reason this file's
/// element collection is predicate-driven: a command can name any setting at
/// all, including ones no target-scoped modal was ever meant to show, and it
/// still gets that setting's real commit, validation and account routing
/// rather than a second, thinner editor.
///
/// [keys] order is preserved. Callers pass them best-match-first, and the
/// command's preview line names that first one — listing them in
/// settings-screen order instead would put the setting the operator was just
/// told about somewhere down the list.
Future<void> showSettingsForKeys(
  BuildContext context, {
  required HaLoServices services,
  required List<String> keys,
  required String title,
}) {
  final rank = {for (var i = 0; i < keys.length; i++) keys[i]: i};
  return _showSettingsDialog(
    context,
    services: services,
    title: title,
    inBase: (scanned) => rank.containsKey(scanned.key),
    // Nothing is held back: the caller named exactly what it wants shown, so
    // a "show more settings" disclosure would have nothing behind it.
    inExtended: (_) => false,
    order: (a, b) => (rank[a.key] ?? 0).compareTo(rank[b.key] ?? 0),
    // `visibleWhen` is dropped, not evaluated. It names a SIBLING field, and a
    // dialog built from a handful of keys usually doesn't contain that
    // sibling — FormRenderer would read it as null and hide the very setting
    // the caller asked for, leaving an empty dialog after a preview that said
    // "Grid Field: On". Whoever picked these keys has already decided they are
    // reachable (settings_catalog.dart evaluates `visibleWhen` against the
    // group's full values before a command can name one), so re-deciding it
    // here against a subset can only be wrong.
    stripVisibleWhen: true,
  );
}

Future<void> _showSettingsDialog(
  BuildContext context, {
  required HaLoServices services,
  required String title,
  required ScannedSettingPredicate inBase,
  required ScannedSettingPredicate inExtended,
  ScannedSettingOrder? order,
  bool stripVisibleWhen = false,
  List<TargetDialogAction> actions = const [],
}) {
  final t = context.t;
  return showHaloDialog<void>(
    context: context,
    builder: (context) => _AnimatedDialogEntrance(
      child: HaloDialog(
        title: Text(title),
        wide: true,
        // _TargetSettingsFormState scrolls its own settings section — see
        // its own comment — so this dialog's body must not also try to,
        // or the nested scrollables fail to lay out.
        scrollable: false,
        // Rows to the card's edges, contents inset — the shell publishes the
        // settings row inset every row here reads from, so nothing stacks a
        // second, outer padding on top of it.
        list: true,
        content: _TargetSettingsForm(
          services: services,
          inBase: inBase,
          inExtended: inExtended,
          order: order,
          stripVisibleWhen: stripVisibleWhen,
          actions: actions,
        ),
        // Settings commit as each control changes, so this closes rather
        // than confirms: a plain Done in the cancel slot.
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.done)),
      ),
    ),
  );
}

/// Fades and scales the dialog card in on open — [showHaloDialog] itself
/// (a plain `showDialog`) applies no transition of its own, so without this
/// the dialog would simply appear.
class _AnimatedDialogEntrance extends StatefulWidget {
  final Widget child;

  const _AnimatedDialogEntrance({required this.child});

  @override
  State<_AnimatedDialogEntrance> createState() => _AnimatedDialogEntranceState();
}

class _AnimatedDialogEntranceState extends State<_AnimatedDialogEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  late final Animation<double> _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curved,
    child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(_curved), child: widget.child),
  );
}

/// Which scanned elements a dialog shows, and which it holds back behind its
/// "show more settings" disclosure.
typedef ScannedSettingPredicate = bool Function(ScannedSetting scanned);

/// How to sort the kept elements. Null keeps [scanSettings]' own order, which
/// is the order the settings screen itself shows them in.
typedef ScannedSettingOrder = int Function(ScannedSetting a, ScannedSetting b);

class _TargetSettingsForm extends StatefulWidget {
  final HaLoServices services;
  final ScannedSettingPredicate inBase;
  final ScannedSettingPredicate inExtended;
  final ScannedSettingOrder? order;

  /// Drops each kept element's `visibleWhen` instead of letting FormRenderer
  /// evaluate it — see [showSettingsForKeys], which is the only caller that
  /// shows a subset small enough for the named sibling to be missing.
  final bool stripVisibleWhen;

  final List<TargetDialogAction> actions;

  const _TargetSettingsForm({
    required this.services,
    required this.inBase,
    required this.inExtended,
    required this.order,
    required this.stripVisibleWhen,
    required this.actions,
  });

  @override
  State<_TargetSettingsForm> createState() => _TargetSettingsFormState();
}

class _TargetSettingsFormState extends State<_TargetSettingsForm> {
  List<Map<String, dynamic>>? _baseElements;
  List<Map<String, dynamic>>? _extendedElements;
  final _groupForKey = <String, SettingsGroup>{};
  final _extensionFieldForKey = <String, ExtensionFieldRoute>{};
  final _extensionActionForKey = <String, ExtensionActionRoute>{};
  bool _showExtended = false;
  bool _reloading = false;
  bool _reloadPending = false;

  // FormRenderer calls the validator and onChange separately for the same
  // (fieldKey, value) on every edit — cache the one real validate call so an
  // extension field's edit doesn't cost two bridge round trips, or risk the
  // two calls disagreeing. Same pattern as _ExtensionSettingsPanel's own
  // _validate in settings_view.dart.
  String? _lastValidatedFieldKey;
  dynamic _lastValidatedValue;
  String? _lastValidationError;

  List<SettingsGroup> get _groups => widget.services.settingsRegistry.groups;

  // Several groups share the same underlying Listenable (SettingsService
  // itself, in every core group's case) — a Set so each distinct one is
  // subscribed once, not once per group that happens to expose it.
  // runtimeGeneration ticks on a restart (crash recovery, the user
  // enabling/disabling an extension) — without it, a dialog left open
  // across one would keep showing extension panel data from the runtime
  // generation it was first built with.
  List<Listenable> get _listenables => {
    for (final g in _groups)
      if (g.listenable != null) g.listenable!,
    widget.services.extensions.runtimeGeneration,
  }.toList();

  @override
  void initState() {
    super.initState();
    _load();
    for (final listenable in _listenables) {
      listenable.addListener(_load);
    }
  }

  @override
  void dispose() {
    for (final listenable in _listenables) {
      listenable.removeListener(_load);
    }
    super.dispose();
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
        final baseScanned = <ScannedSetting>[];
        final extendedScanned = <ScannedSetting>[];
        final groupForKey = <String, SettingsGroup>{};
        final extensionFieldForKey = <String, ExtensionFieldRoute>{};
        final extensionActionForKey = <String, ExtensionActionRoute>{};
        for (final scanned in await scanSettings(widget.services)) {
          final inBase = widget.inBase(scanned);
          if (!inBase && !widget.inExtended(scanned)) continue;
          (inBase ? baseScanned : extendedScanned).add(scanned);
          if (scanned.key.isEmpty) continue;
          if (scanned.group != null) groupForKey[scanned.key] = scanned.group!;
          if (scanned.fieldRoute != null) extensionFieldForKey[scanned.key] = scanned.fieldRoute!;
          if (scanned.actionRoute != null) extensionActionForKey[scanned.key] = scanned.actionRoute!;
        }
        // Sorted AFTER collection, not during: the caller's order (e.g. a
        // command's ranking) has nothing to do with the order the groups
        // declare their elements in, which is what the scan yields.
        final order = widget.order;
        if (order != null) {
          baseScanned.sort(order);
          extendedScanned.sort(order);
        }
        Map<String, dynamic> render(ScannedSetting scanned) =>
            widget.stripVisibleWhen && scanned.element.containsKey('visibleWhen')
                ? {for (final e in scanned.element.entries) if (e.key != 'visibleWhen') e.key: e.value}
                : scanned.element;
        final base = [for (final scanned in baseScanned) render(scanned)];
        final extended = [for (final scanned in extendedScanned) render(scanned)];
        if (mounted) {
          setState(() {
            _baseElements = base;
            _extendedElements = extended;
            _groupForKey
              ..clear()
              ..addAll(groupForKey);
            _extensionFieldForKey
              ..clear()
              ..addAll(extensionFieldForKey);
            _extensionActionForKey
              ..clear()
              ..addAll(extensionActionForKey);
          });
        }
      } while (_reloadPending && mounted);
    } finally {
      _reloading = false;
    }
  }

  /// An extension hook's `state` argument is documented (docs/extensions/
  /// settings.md) as that panel's own bare-keyed field values — never this
  /// dialog's combined `_values` map, which mixes bare core keys with every
  /// scanned panel's `<panelKey>.`-namespaced ones. Strips the prefix and
  /// drops everything that isn't [panelKey]'s own, so a hook sees exactly
  /// what a single-panel form (e.g. [_ExtensionSettingsPanel] in
  /// settings_view.dart) would give it.
  Map<String, dynamic> _panelState(Map<String, dynamic> state, String panelKey) {
    final prefix = '$panelKey.';
    return {
      for (final entry in state.entries)
        if (entry.key.startsWith(prefix)) entry.key.substring(prefix.length): entry.value,
    };
  }

  Future<String?> _validate(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    final route = _extensionFieldForKey[fieldKey];
    if (route == null) return null; // core-group fields: no validation today.
    if (_lastValidatedFieldKey == fieldKey && _lastValidatedValue == value) return _lastValidationError;
    final error = await widget.services.extensions.validateSettingsField(
      kind: route.kind,
      hookKey: route.hookKey,
      panelKey: route.panelKey,
      field: route.field,
      fieldKey: route.fieldKey,
      value: value,
      state: _panelState(state, route.panelKey),
    );
    _lastValidatedFieldKey = fieldKey;
    _lastValidatedValue = value;
    _lastValidationError = error;
    return error;
  }

  Future<Map<String, dynamic>?> _autosave(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    final group = _groupForKey[fieldKey];
    if (group != null) {
      await group.commit(fieldKey, value);
      if (mounted) await _load();
      return null;
    }
    final route = _extensionFieldForKey[fieldKey];
    if (route != null) {
      if (await _validate(fieldKey, value, state) != null) return null;
      final scopedState = _panelState(state, route.panelKey);
      final committedValue = route.kind == 'dynamic'
          ? await widget.services.extensions.transformSettingsField(
              hookKey: route.hookKey,
              panelKey: route.panelKey,
              fieldKey: route.fieldKey,
              value: value,
              state: scopedState,
            )
          : value;
      await widget.services.extensions.commitSettingsFieldValue(
        kind: route.kind,
        hookKey: route.hookKey,
        panelKey: route.panelKey,
        fieldKey: route.fieldKey,
        value: committedValue,
        state: scopedState,
        isSecret: route.field['fieldType'] == 'secret',
        restartOnChange: route.field['restartOnChange'] == true,
      );
    }
    if (mounted) await _load();
    return null;
  }

  Future<FormActionResult?> _onAction(String actionKey, String method, Map<String, dynamic> state) async {
    final route = _extensionActionForKey[actionKey];
    if (route == null) return null; // core groups declare no actions today.
    final message = await widget.services.extensions.runSettingsAction(
      hookKey: route.hookKey,
      panelKey: route.panelKey,
      method: method,
      state: _panelState(state, route.panelKey),
    );
    return message == null ? null : FormActionResult(message: message);
  }

  // showAccountDialogByKey's own account pane has no way to notify this
  // dialog when it saves (unlike _ExtensionSettingsPanel's _manageAccount,
  // which passes itself an onSaved callback) — reload unconditionally once
  // it closes, for any reason, so a status field this dialog is showing
  // ("Not Connected"/"Connected as X") doesn't go stale after Connect/
  // Disconnect. Harmless on a plain cancel: _load() re-fetching unchanged
  // data is the same no-op it already is after every core-group commit.
  void _onManageAccount(String accountKey, String? subkey) {
    showAccountDialogByKey(widget.services, accountKey, subkey: subkey).then((_) {
      if (mounted) _load();
    });
  }

  Widget _buildFormRenderer(List<Map<String, dynamic>> elements) => FormRenderer(
    formDefinition: {'elements': elements},
    initialState: const {},
    showActions: false,
    showTitle: false,
    validator: _validate,
    developerMode: widget.services.settings.developerMode,
    labels: formRendererLabelsFor(context.t),
    settingsList: true,
    onChange: _autosave,
    onAction: _onAction,
    onManageAccount: _onManageAccount,
    onOpenLink: openExternalUrl,
    onSubmit: (_) {},
    onCancel: () {},
  );

  @override
  Widget build(BuildContext context) {
    final base = _baseElements;
    final extended = _extendedElements;
    if (base == null || extended == null) {
      return const Padding(padding: EdgeInsets.all(Space.xxl), child: Center(child: CircularProgressIndicator()));
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings lead, and scroll in their own bounded region — no
          // "Relevant Settings" label above them; with Actions moved below,
          // there is no sibling section left for the name to distinguish
          // them from. Flexible, not Expanded, so a short settings list (no
          // extended fields, or already showing them) sizes to its own
          // content and leaves Actions directly beneath it; only a list
          // long enough to reach the dialog's own height limit clips and
          // scrolls, instead of pushing Actions off the bottom.
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // One FormRenderer whose element list grows, not two
                  // separate FormRenderer widgets swapped/composited — the
                  // extended fields are simply spliced into the same array
                  // once _showExtended flips, so they're absent from the
                  // tree (and from find.text in a test) until then, with a
                  // plain widget subtree AnimatedSize can safely resize
                  // around.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _buildFormRenderer([
                      ...base,
                      if (_showExtended) ...extended,
                    ]),
                  ),
                  if (!_showExtended && extended.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: TextButton(
                        onPressed: () => setState(() => _showExtended = true),
                        child: Text(context.t.settings.showMoreSettings),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Caller-supplied, not a declared setting — never routed through
          // elementMatchesTarget, so it can't be mistaken for one. Banded
          // and trailing, the same shape a Panel Settings section takes in
          // the pane layout options dialog.
          if (widget.actions.isNotEmpty) ...[
            SectionHeader(context.t.operation.menu.actionsSection),
            for (final action in widget.actions)
              ListTile(
                leading: Icon(resolveIconName(action.icon)),
                title: Text(
                  action.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                onTap: action.onTap,
              ),
          ],
      ],
    );
  }
}
