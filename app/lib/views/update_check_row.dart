// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The About panel's "Check for Updates" row. Purely a status display and
// trigger — all it knows is HaLoServices.updateCheck (see
// services/update_check_service.dart), the pluggable extension point that
// actually decides what to check (Shorebird/Sparkle for a distribution
// build, a web build-SHA freshness check for the OSS default). Checks
// automatically on first show, and again whenever the row itself is tapped.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_widgets/halo_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.g.dart';
import '../main.dart' show HaLoServices;
import '../services/auto_update_service.dart';
import '../services/error_reporting_service.dart';
import '../services/update_check_service.dart';

/// Whether [UpdateCheckRow] will show anything at all for this build —
/// public so the About panel can decide, ahead of building the row itself,
/// whether to show the divider that separates it from the version row above
/// (see settings_view.dart's _AboutPanel). That divider has to live outside
/// this widget's own `centered()`-wrapped content to span the pane's full
/// width like every other divider in the panel — if it were nested inside
/// here instead, it would get capped to idealPaneWidth along with the row
/// itself, visibly narrower than its neighbors.
bool updateCheckAppliesTo(HaLoServices services) =>
    services.updateCheck.isApplicable(updates: services.updates);

class UpdateCheckRow extends StatefulWidget {
  final HaLoServices services;

  const UpdateCheckRow({super.key, required this.services});

  @override
  State<UpdateCheckRow> createState() => _UpdateCheckRowState();
}

class _UpdateCheckRowState extends State<UpdateCheckRow> {
  bool _checking = false;
  UpdateCheckOutcome _outcome = UpdateCheckOutcome.upToDate;

  /// Where the last check says to go, when it says to go anywhere — the store
  /// page on mobile. Null on desktop, where Sparkle/WinSparkle run their own
  /// install UI and a second link would compete with it.
  Uri? _destination;

  bool get _applicable => updateCheckAppliesTo(widget.services);

  @override
  void initState() {
    super.initState();
    if (_applicable) _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);

    var outcome = _outcome;
    Uri? destination;
    try {
      outcome = await widget.services.updateCheck.check(
        updates: widget.services.updates,
        statusBar: widget.services.statusBar,
      );
      // Inside the same try, not after it: this reaches the same
      // distribution-specific APIs (a store lookup runs a platform channel),
      // and a throw out here would strand the row on the spinner just as
      // surely — the very thing the catch below exists to prevent.
      if (outcome == UpdateCheckOutcome.updateAvailable) {
        destination = await widget.services.updateCheck.updateDestination();
      }
    } catch (e, st) {
      // The injected UpdateCheckService may reach into distribution-specific
      // APIs (Shorebird/Sparkle) this row knows nothing about; an unexpected
      // failure there must not leave the row stuck on "Checking…" forever
      // with the tap disabled.
      debugPrint('[update-check] a check failed unexpectedly: $e');
      ErrorReportingService.report(e, st, context: 'update-check-row');
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _outcome = outcome;
      _destination = destination;
    });
  }

  /// Deliberately not openExternalUrl (services/link_opener.dart): its scheme
  /// allowlist exists to fence URLs authored OUTSIDE the app — extensions,
  /// community call notes — and `market:` / `itms-beta:` are exactly the
  /// schemes it is right to refuse there. This URL is built by the update
  /// check itself, so it needs no fence, and widening that one would weaken
  /// every extension-authored link along with it.
  Future<void> _openDestination(Uri destination) async {
    // The row's only action, so a silent no-op is the worst available
    // outcome: launchUrl RETURNS false when nothing handles the scheme and
    // THROWS when the platform refuses, and neither is visible to an operator
    // watching a tap do nothing.
    try {
      if (await launchUrl(destination, mode: LaunchMode.externalApplication)) return;
    } catch (e, st) {
      ErrorReportingService.report(e, st, context: 'update-check-row-launch');
    }
    debugPrint('[update-check] nothing handled $destination');
  }

  @override
  Widget build(BuildContext context) {
    if (!_applicable) return const SizedBox.shrink();

    final subtitle = _checking
        ? context.t.updates.checkingForUpdates
        : switch (_outcome) {
            UpdateCheckOutcome.upToDate => context.t.updates.upToDate,
            UpdateCheckOutcome.updateAvailable => context.t.updates.updateAvailable,
            UpdateCheckOutcome.restartToApply => context.t.updates.restartToApply,
            UpdateCheckOutcome.reloadToUpdate => context.t.updates.reloadToUpdate,
          };

    final destination = _destination;

    return ListTile(
      leading: const Icon(MdiIcons.cellphoneArrowDown),
      title: Text(context.t.updates.checkForUpdates),
      subtitle: Text(subtitle),
      trailing: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          // Once there is somewhere to go, going there IS the action —
          // re-checking would only confirm what the row already says.
          : Icon(destination == null ? MdiIcons.refresh : MdiIcons.openInNew),
      onTap: _checking ? null : (destination == null ? _check : () => unawaited(_openDestination(destination))),
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

/// Whether [AutomaticUpdateCheckRow] shows anything — public for the same
/// reason as [updateCheckAppliesTo]: the About panel decides on its dividers
/// before it builds the row.
bool get automaticUpdateCheckApplies => const AutoUpdateService().ownsAutomaticCheckSetting;

/// The operator's "check automatically" preference.
///
/// Only shown where honouring it is actually ours (Windows). WinSparkle asks
/// about this once, at first run, and offers no way back — so without this
/// switch an operator who declined has no way to change their mind, and one
/// who accepted has no way to stop.
///
/// The new value reaches the native updater at the next launch, not now: every
/// setting it governs is applied before `win_sparkle_init()`, and a running
/// scheduler cannot be re-armed. Storing it is therefore the whole job here.
class AutomaticUpdateCheckRow extends StatelessWidget {
  final HaLoServices services;

  const AutomaticUpdateCheckRow({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    if (!automaticUpdateCheckApplies) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: services.settings,
      builder: (context, _) => SwitchListTile(
        secondary: const Icon(MdiIcons.autorenew),
        title: Text(context.t.updates.automaticChecks),
        subtitle: Text(context.t.updates.automaticChecksDescription),
        value: services.settings.automaticUpdateChecks,
        onChanged: (value) => unawaited(services.settings.setAutomaticUpdateChecks(value)),
      ),
    );
  }
}
