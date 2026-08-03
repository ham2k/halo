// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// A settings modal built from a `target` (settings_registry.dart) rather
// than a whole group — the logging panel's tune icon, for one, doesn't want
// All Settings or even the whole `LoggingSettingsGroup`, just the handful
// of elements that opted into `target: 'logging'`, plus a "show more
// settings" disclosure for the `'logging-extended'` bucket. Any part of the
// app can call [showSettingsForTarget] with its own target string; nothing
// here is logging-specific — the title and any Actions-section items are
// entirely the caller's to decide.
//
// Scans every group in [SettingsRegistry] AND every extension settingsPanel
// (a separate registry, reached through [ExtensionService]), so a target can
// span core groups and extensions alike. Extension-sourced `field` and
// `action` elements get their rendered `key` namespaced `<panelKey>.<key>`
// (mirroring the `<panelKey>.<fieldKey>` persistence convention
// docs/extensions/settings.md already documents) so two panels sharing a
// key — or an extension element colliding with a core one — can never
// misroute a commit or an action dispatch; core-group elements stay
// bare-keyed.
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

/// One row in the dialog's "Actions" section — caller-supplied, never a
/// declared setting. [onTap] is responsible for closing the dialog itself
/// (via `Navigator.pop`) if that's the desired effect; this widget doesn't
/// assume one way or the other.
typedef TargetDialogAction = ({String icon, String label, VoidCallback onTap});

/// Opens a dialog listing every declared setting whose `target` attribute
/// is [target], with a `'<target>-extended'` bucket hidden behind a "show
/// more settings" toggle. [actions], if given, render as their own
/// "Actions" section at the top of the list — for things the caller needs
/// reachable from here that aren't themselves a persisted setting (e.g. the
/// logging panel's "Lookup all QSOs"), so they never get declared with a
/// `target` of their own.
Future<void> showSettingsForTarget(
  BuildContext context, {
  required HaLoServices services,
  required String target,
  required String title,
  List<TargetDialogAction> actions = const [],
}) {
  final t = context.t;
  return showHaloDialog<void>(
    context: context,
    builder: (context) => _AnimatedDialogEntrance(
      child: HaloDialog(
        title: Text(title),
        wide: true,
        // No horizontal inset here — each row (SectionHeader, the settings
        // themselves, the Actions items) carries its own via the ambient
        // ListTileTheme set up in _TargetSettingsFormState.build, so it
        // isn't stacked on top of a second, outer padding.
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: _TargetSettingsForm(services: services, target: target, actions: actions),
        actions: [
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.done)),
        ],
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

class _TargetSettingsForm extends StatefulWidget {
  final HaLoServices services;
  final String target;
  final List<TargetDialogAction> actions;

  const _TargetSettingsForm({required this.services, required this.target, required this.actions});

  @override
  State<_TargetSettingsForm> createState() => _TargetSettingsFormState();
}

/// Where an extension-sourced field routes on validate/commit — [field] is
/// the ORIGINAL (bare-keyed) element map, as declared by the extension,
/// distinct from the namespaced copy actually handed to FormRenderer (see
/// this file's header comment).
typedef _ExtensionFieldRoute = ({String hookKey, String panelKey, String kind, String fieldKey, Map<String, dynamic> field});

/// Where an extension-sourced `type: 'action'` element dispatches — no
/// `kind` needed, unlike [_ExtensionFieldRoute]: [ExtensionService.runSettingsAction]
/// always goes through the extension host regardless of panel tier.
typedef _ExtensionActionRoute = ({String hookKey, String panelKey});

class _TargetSettingsFormState extends State<_TargetSettingsForm> {
  List<Map<String, dynamic>>? _baseElements;
  List<Map<String, dynamic>>? _extendedElements;
  final _groupForKey = <String, SettingsGroup>{};
  final _extensionFieldForKey = <String, _ExtensionFieldRoute>{};
  final _extensionActionForKey = <String, _ExtensionActionRoute>{};
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
        final base = <Map<String, dynamic>>[];
        final extended = <Map<String, dynamic>>[];
        final groupForKey = <String, SettingsGroup>{};
        final extensionFieldForKey = <String, _ExtensionFieldRoute>{};
        final extensionActionForKey = <String, _ExtensionActionRoute>{};
        for (final group in _groups) {
          final resolved = await widget.services.systemLists.resolveInElements(await group.buildElements());
          for (final el in filterElementsForEnvironment(resolved)) {
            final key = el['key'];
            if (elementMatchesTarget(el, widget.target)) {
              base.add(el);
              if (key is String) groupForKey[key] = group;
            } else if (elementMatchesTarget(el, '${widget.target}-extended')) {
              extended.add(el);
              if (key is String) groupForKey[key] = group;
            }
          }
        }
        for (final panel in await widget.services.extensions.getSettingsPanels()) {
          final hookKey = panel['hookKey'] as String?;
          final panelKey = panel['panelKey'] as String?;
          final kind = panel['kind'] as String?;
          if (hookKey == null || panelKey == null || kind == null) continue;
          final definition = await widget.services.extensions.getSettingsPanelDefinition(
            hookKey: hookKey,
            panelKey: panelKey,
            kind: kind,
          );
          final rawElements = (definition?['elements'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          final resolved = await widget.services.systemLists.resolveInElements(rawElements);
          for (final el in filterElementsForEnvironment(resolved)) {
            final type = el['type'];
            if (type != 'field' && type != 'action') continue;
            final elementKey = el['key'];
            if (elementKey is! String) continue;
            final inBase = elementMatchesTarget(el, widget.target);
            final inExtended = !inBase && elementMatchesTarget(el, '${widget.target}-extended');
            if (!inBase && !inExtended) continue;
            // Namespaced so it can never collide with a core group's bare
            // key or another panel's same-named field/action — see header
            // comment. (An `account`-typed field is still `type: 'field'`;
            // it's namespaced and routed the same as any other field.)
            final namespacedKey = '$panelKey.$elementKey';
            (inBase ? base : extended).add({...el, 'key': namespacedKey});
            if (type == 'field') {
              extensionFieldForKey[namespacedKey] = (hookKey: hookKey, panelKey: panelKey, kind: kind, fieldKey: elementKey, field: el);
            } else {
              extensionActionForKey[namespacedKey] = (hookKey: hookKey, panelKey: panelKey);
            }
          }
        }
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
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    // One shared inset for every row in this dialog — Actions items and the
    // settings rows alike — so padding lives on each row (which is what
    // FormRenderer's own rows already read this from) rather than as a
    // separate wrapper around the whole list stacking on top of it.
    return ListTileTheme(
      data: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caller-supplied, not a declared setting — never routed through
          // elementMatchesTarget, so it can't be mistaken for one.
          if (widget.actions.isNotEmpty) ...[
            SectionHeader(context.t.operation.menu.actionsSection),
            for (final action in widget.actions)
              ListTile(
                leading: Icon(resolveIconName(action.icon)),
                title: Text(action.label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                onTap: action.onTap,
              ),
          ],
          SectionHeader(context.t.operation.menu.relevantSettingsSection),
          // One FormRenderer whose element list grows, not two separate
          // FormRenderer widgets swapped/composited — the extended fields
          // are simply spliced into the same array once _showExtended
          // flips, so they're absent from the tree (and from find.text in
          // a test) until then, with a plain
          // widget subtree AnimatedSize can safely resize around.
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
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => setState(() => _showExtended = true),
                child: Text(context.t.settings.showMoreSettings),
              ),
            ),
        ],
      ),
    );
  }
}
