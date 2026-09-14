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
import '../../services/extension_catalog_migration.dart';
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
    if (settings.extensionsMigrated) return;
    // Not while onboarding still owns the screen: a fresh install has no
    // extensions set up to carry, and stacking this behind the callsign
    // question asks for a decision about something they have not met.
    if (!settings.defaultProfileCallsignDefined) return;
    // Asked BEFORE the dialog, so nobody is shown a button that cannot work.
    // An unreachable catalog says nothing at all and tries again next launch.
    if (!await canReachCatalog(widget.services.extensions)) return;
    if (!mounted) return;

    final t = context.t.extensionsPanel;
    final accepted = await showDialog<bool>(
          context: context,
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
    if (done || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => HaloDialog(
        title: Text(t.upgradeFailedTitle),
        content: Text(t.upgradeFailedBody),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
