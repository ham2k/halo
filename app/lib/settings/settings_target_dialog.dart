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
// Scans every group in [SettingsRegistry] (core groups only — extension
// settingsPanels aren't included, since they're reached through a separate
// registry; an extension field wanting a target-scoped modal is a
// follow-up), so a target can span more than one group if it needs to.

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../i18n/strings.g.dart';
import '../main.dart';
import '../services/link_opener.dart';
import '../tools/form_chrome_labels.dart';
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

class _TargetSettingsFormState extends State<_TargetSettingsForm> {
  List<Map<String, dynamic>>? _baseElements;
  List<Map<String, dynamic>>? _extendedElements;
  final _groupForKey = <String, SettingsGroup>{};
  bool _showExtended = false;
  bool _reloading = false;
  bool _reloadPending = false;

  List<SettingsGroup> get _groups => widget.services.settingsRegistry.groups;

  // Several groups share the same underlying Listenable (SettingsService
  // itself, in every core group's case) — a Set so each distinct one is
  // subscribed once, not once per group that happens to expose it.
  List<Listenable> get _listenables => {for (final g in _groups) if (g.listenable != null) g.listenable!}.toList();

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
        if (mounted) {
          setState(() {
            _baseElements = base;
            _extendedElements = extended;
            _groupForKey
              ..clear()
              ..addAll(groupForKey);
          });
        }
      } while (_reloadPending && mounted);
    } finally {
      _reloading = false;
    }
  }

  Future<Map<String, dynamic>?> _autosave(String fieldKey, dynamic value, Map<String, dynamic> state) async {
    final group = _groupForKey[fieldKey];
    if (group != null) await group.commit(fieldKey, value);
    if (mounted) await _load();
    return null;
  }

  Widget _buildFormRenderer(List<Map<String, dynamic>> elements) => FormRenderer(
    formDefinition: {'elements': elements},
    initialState: const {},
    showActions: false,
    showTitle: false,
    developerMode: widget.services.settings.developerMode,
    labels: formRendererLabelsFor(context.t),
    onChange: _autosave,
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
          // a test) until then, same contract as before, with a plain
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
