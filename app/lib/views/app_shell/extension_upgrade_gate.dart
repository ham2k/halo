// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move to catalog extensions, offered at start until it is taken
// (services/extension_catalog_migration.dart).
//
// Deferrable by design, which is only honest because nothing is withdrawn
// until the upgrade succeeds: saying Later leaves every extension working and
// the offer comes back next launch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/experiments.dart';
import '../../config/navigation.dart';
import '../../services/extension_catalog_migration.dart';
import '../../services/installed_extensions.dart';
import '../../services/halo_services.dart';

class ExtensionUpgradeGate extends StatefulWidget {
  final HaLoServices services;
  final Widget child;

  const ExtensionUpgradeGate({super.key, required this.services, required this.child});

  @override
  State<ExtensionUpgradeGate> createState() => _ExtensionUpgradeGateState();
}

class _ExtensionUpgradeGateState extends State<ExtensionUpgradeGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_offerUpgrade());
  }

  Future<void> _offerUpgrade() async {
    final settings = widget.services.settings;
    // Behind the experiment until this goes to everybody, at which point this
    // one condition is what changes.
    if (!settings.experimentEnabled(kCatalogExperiment)) return;
    // Nowhere to put the replacements: web has no extension store, so every
    // step of the upgrade no-ops and it ends in the failure dialog — asked
    // again on every launch, and never able to answer differently.
    if (!InstalledExtensions.isSupported) return;
    if (settings.extensionsMigrated) return;
    // Not while onboarding still owns the screen: a fresh install has no
    // extensions set up to carry, and stacking this behind the callsign
    // question asks for a decision about something they have not met.
    if (!settings.defaultProfileCallsignDefined) return;
    // Asked BEFORE the dialog, so nobody is shown a button that cannot work.
    // An unreachable catalog says nothing at all and tries again next launch.
    if (!await canReachCatalog(widget.services.extensions)) return;
    if (!mounted) return;

    // This gate sits in MaterialApp.builder, ABOVE the Navigator, so its own
    // context cannot push a dialog: showDialog would throw into this
    // unawaited future and the offer would silently never appear. The app's
    // navigator key is the route in.
    final navigator = navigatorKey.currentContext;
    if (navigator == null || !navigator.mounted) return;
    final t = navigator.t.extensionsPanel;
    // A launch with fresh release notes paints them over this dialog. Left
    // dismissible, an Esc aimed at the notes would pop the offer unseen as
    // "Later"; the operator answers it on the buttons, once they can see it.
    final accepted = await showDialog<bool>(
          context: navigator,
          barrierDismissible: false,
          builder: (context) => HaloDialog(
            title: Text(t.upgradeTitle),
            content: Text(t.upgradeBody),
            cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.upgradeLater)),
            actions: [
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.upgradeAction)),
            ],
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;

    final done = await migrateToCatalogExtensions(widget.services.extensions);
    if (!mounted || !navigator.mounted) return;
    // Said either way: the operator agreed to an operation that withdraws the
    // extensions they had, so leaving them to guess whether it happened is
    // the one thing this must not do. A built-in with no catalog twin finishes
    // the upgrade rather than failing it, so this is also where its withdrawal
    // is said.
    final unserved = done ? unservedBuiltInNames(widget.services.extensions) : const <String>[];
    final doneBody = [
      t.upgradeDoneBody,
      if (unserved.isNotEmpty) t.upgradeDoneUnserved(names: unserved.join(', ')),
    ].join('\n\n');
    await showDialog<void>(
      context: navigator,
      builder: (context) => HaloDialog(
        title: Text(done ? t.upgradeDoneTitle : t.upgradeFailedTitle),
        content: Text(done ? doneBody : t.upgradeFailedBody),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
