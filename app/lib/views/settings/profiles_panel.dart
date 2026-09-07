// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Profiles: the operator's callsign and personal details, one profile per
// callsign the station is used under.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';

import 'package:halo_i18n/halo_i18n.dart';
import '../../services/halo_services.dart';
import '../../services/settings_service.dart';
import '../operation_dialogs.dart';

/// The "profiles" panel — callsign profiles. Until multi-profile features
/// are enabled it presents itself as just "Callsign": a single field, saved
/// as the default profile's `operatorCall` (see [SettingsService.activeProfile]),
/// followed by the optional personal details log generators may need.
class ProfilesPanel extends StatefulWidget {
  final HaLoServices services;

  const ProfilesPanel({super.key, required this.services});

  @override
  State<ProfilesPanel> createState() => _ProfilesPanelState();
}

class _ProfilesPanelState extends State<ProfilesPanel> {
  /// The DXCC entity of the profile callsign, resolved through the extension
  /// runtime's offline lookup — Dart has no callsign parser of its own. Null
  /// while unresolved, which [_sectionLabel] reads as "don't know" rather than
  /// as an answer.
  String? _entityPrefix;

  /// The callsign [_entityPrefix] was resolved for, so a rebuild triggered by
  /// any other setting doesn't re-annotate. Only ever set from a lookup that
  /// ANSWERED: recording a failed one would cache "don't know" for the rest of
  /// the panel's life, and the operator's only way out would be to leave and
  /// come back. Same rule as FlagsService's `_lastFetchedCall`.
  String? _annotatedCall;

  @override
  void initState() {
    super.initState();
    _resolveEntityPrefix();
  }

  /// Bumped per resolve so a slow one can't install its answer over a newer
  /// one's — `lookupCall` waits on the whole hook pipeline (8s timeout), long
  /// enough for the operator to edit the callsign while one is in flight, and
  /// the loser would otherwise repaint the label for the callsign they just
  /// left. Same guard as `activities_view.dart`'s `_controlsRequest`.
  int _resolveRequest = 0;

  Future<void> _resolveEntityPrefix() async {
    final call = widget.services.settings.activeProfile.operatorCall;
    if (call.isEmpty || call == _annotatedCall) return;
    final request = ++_resolveRequest;
    // Idempotent and memoized (ExtensionService.start), so this waits out a
    // boot still in flight instead of reading a not-yet-running runtime as
    // "this callsign has no entity" — the first-run path, where a US operator
    // opening Settings early would otherwise never be offered a section.
    await widget.services.extensions.start();
    final info = await widget.services.extensions.lookupCall(
      call,
      qso: const {},
      operation: const {},
      online: false,
    );
    if (!mounted || request != _resolveRequest) return;
    final prefix = (info?['guess'] as Map<String, dynamic>?)?['entityPrefix'] as String?;
    if (prefix == null) {
      debugPrint('[settings] no DXCC entity for "$call" — the section field stays hidden');
      return;
    }
    _annotatedCall = call;
    setState(() => _entityPrefix = prefix);
  }

  /// What to call the section field, or null to leave it out entirely.
  ///
  /// Sections are an ARRL/RAC construct: every US entity — the lower 48 plus
  /// Alaska, Hawaii, the Pacific islands, Puerto Rico and the Virgin Islands —
  /// carries a `K…` entity prefix, and Canada is `VE`. An unresolved prefix
  /// hides the field rather than guessing, EXCEPT when a section is already
  /// stored: a value the operator can't see is a value they can't correct. That
  /// case gets the bare "Section" — naming a society we have not established
  /// would tell a VE operator their RAC section is an ARRL one.
  String? _sectionLabel(BuildContext context, String section) {
    final t = context.t.settings.profiles;
    final prefix = _entityPrefix;
    if (prefix != null && prefix.startsWith('K')) return t.arrlSection;
    if (prefix == 'VE') return t.racSection;
    return section.isEmpty ? null : t.section;
  }

  Future<void> _editCallsign() async {
    final result = await editOneFieldDialog(
      context,
      title: context.t.common.callsign,
      fieldLabel: context.t.common.callsign,
      fieldInitial: widget.services.settings.activeProfile.operatorCall,
      fieldCapitalization: TextCapitalization.characters,
    );
    if (result == null) return;
    await widget.services.setOperatorCall(result);
    await _resolveEntityPrefix();
  }

  /// One dialog for the whole group, whichever row was tapped — these are four
  /// facets of one answer ("who is submitting this log"), and an operator
  /// filling them in for the first time would otherwise open and dismiss four
  /// dialogs. The rows stay separate so each value is readable at a glance;
  /// [focusKey] opens on the one that was tapped.
  Future<void> _editPersonalInfo(String focusKey, String? sectionLabel) async {
    final profile = widget.services.settings.activeProfile;
    final result = await showHaloDialog<Map<String, String>>(
      context: context,
      builder: (context) => _PersonalInfoDialog(
        initial: {
          for (final key in _personalInfoKeys) key: (profile.data[key] as String?) ?? '',
        },
        sectionLabel: sectionLabel,
        focusKey: focusKey,
      ),
    );
    if (result == null) return;
    await widget.services.settings.setProfileFields(SettingsService.defaultProfileId, result);
  }

  Widget _fieldTile(String key, String label, String value, IconData icon, String? sectionLabel) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(value.isEmpty ? context.t.settings.profiles.notSet : value),
    onTap: () => _editPersonalInfo(key, sectionLabel),
    mouseCursor: SystemMouseCursors.click,
  );

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final theme = Theme.of(context);
    final t = context.t.settings.profiles;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final profile = settings.activeProfile;
        final call = profile.operatorCall;
        final sectionLabel = _sectionLabel(context, profile.operatorSection);
        return ListView(
          padding: const EdgeInsets.only(bottom: Space.md),
          children: [
            ListTile(
              leading: const Icon(MdiIcons.account),
              title: Text(context.t.common.callsign),
              subtitle: Text(call.isEmpty ? t.notSet : call),
              onTap: _editCallsign,
              mouseCursor: SystemMouseCursors.click,
            ),
            SectionHeader(t.personalInfo),
            Padding(
              // The rows' own inset, off the ambient ListTileTheme — it
              // carries the grab-strip clearance and the pane's centring,
              // neither of which a hand-written inset here would have.
              padding: (ListTileTheme.of(context).contentPadding ?? EdgeInsets.zero)
                  .add(const EdgeInsets.only(bottom: Space.xs)),
              child: Text(
                t.personalInfoNote,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            _fieldTile('operatorName', t.name, profile.operatorName, MdiIcons.cardAccountDetails, sectionLabel),
            _fieldTile('operatorEmail', t.email, profile.operatorEmail, MdiIcons.email, sectionLabel),
            _fieldTile('operatorClub', t.club, profile.operatorClub, MdiIcons.accountGroup, sectionLabel),
            if (sectionLabel != null)
              _fieldTile(
                'operatorSection',
                sectionLabel,
                profile.operatorSection,
                MdiIcons.mapMarkerRadius,
                sectionLabel,
              ),
          ],
        );
      },
    );
  }
}

/// The Personal Info fields, in the order the rows show them. Also the
/// dialog's field order, so the two can't drift apart.
const _personalInfoKeys = ['operatorName', 'operatorEmail', 'operatorClub', 'operatorSection'];

/// Every Personal Info field in one dialog — see [_ProfilesPanelState._editPersonalInfo]
/// for why the rows are separate but the editor is not.
///
/// Returns every field, not just the edited ones: the caller writes them in a
/// single store update, so a partial map would look like "clear the rest".
class _PersonalInfoDialog extends StatefulWidget {
  final Map<String, String> initial;

  /// Null when the callsign's entity has no section (see `_sectionLabel`), in
  /// which case the field is left out of the dialog exactly as it is left out
  /// of the list — and, since it is then absent from the result, its stored
  /// value is carried through untouched rather than blanked.
  final String? sectionLabel;

  final String focusKey;

  const _PersonalInfoDialog({required this.initial, required this.sectionLabel, required this.focusKey});

  @override
  State<_PersonalInfoDialog> createState() => _PersonalInfoDialogState();
}

class _PersonalInfoDialogState extends State<_PersonalInfoDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final key in _visibleKeys) key: TextEditingController(text: widget.initial[key] ?? ''),
  };

  List<String> get _visibleKeys =>
      widget.sectionLabel == null ? _personalInfoKeys.where((k) => k != 'operatorSection').toList() : _personalInfoKeys;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() => Navigator.of(context).pop({
    for (final entry in _controllers.entries)
      // The section is a code, and TextCapitalization is only a keyboard hint
      // that a hardware keyboard ignores — so the uppercasing happens here.
      entry.key: entry.key == 'operatorSection' ? entry.value.text.toUpperCase() : entry.value.text,
  });

  String _labelFor(String key) {
    final t = context.t.settings.profiles;
    return switch (key) {
      'operatorName' => t.name,
      'operatorEmail' => t.email,
      'operatorClub' => t.club,
      _ => widget.sectionLabel ?? t.section,
    };
  }

  @override
  Widget build(BuildContext context) {
    final keys = _visibleKeys;
    return HaloDialog(
      title: Text(context.t.settings.profiles.personalInfo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final key in keys) ...[
            if (key != keys.first) const SizedBox(height: Space.md),
            TextField(
              selectAllOnFocus: false,
              controller: _controllers[key],
              autofocus: key == widget.focusKey,
              keyboardType: key == 'operatorEmail' ? TextInputType.emailAddress : TextInputType.text,
              textCapitalization: switch (key) {
                'operatorEmail' => TextCapitalization.none,
                'operatorSection' => TextCapitalization.characters,
                _ => TextCapitalization.words,
              },
              decoration: poloFieldDecoration(context, _labelFor(key)),
              onSubmitted: (_) => _save(),
            ),
          ],
        ],
      ),
      cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.cancel)),
      actions: [
        FilledButton(onPressed: _save, child: Text(context.t.common.save)),
      ],
    );
  }
}
