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
  /// Whether the experiment was on the last time settings changed, so the
  /// offer follows the moment it is switched ON rather than every write.
  late bool _experimentWasOn;

  /// An offer already on screen, or its catalog check in flight.
  bool _offering = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.services.settings;
    _experimentWasOn = settings.experimentEnabled(kCatalogExperiment);
    settings.addListener(_settingsChanged);
    unawaited(_offerUpgrade(operatorAsked: false));
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  /// Switching the experiment on is the operator asking for catalog
  /// extensions, and the offer is how they get them. Made from `initState`
  /// alone it arrived a whole session late: they turned the experiment on,
  /// nothing happened, and the app had to be relaunched to ask.
  ///
  /// Nothing is withdrawn by that switch — `isBuiltInOffered` needs the
  /// migration too, deliberately — so this is a convenience, not a repair.
  void _settingsChanged() {
    final isOn = widget.services.settings.experimentEnabled(kCatalogExperiment);
    final switchedOn = isOn && !_experimentWasOn;
    _experimentWasOn = isOn;
    // The transition only. Settings notify on every write, and this offer
    // asks the catalog whether it can be reached.
    if (switchedOn) unawaited(_offerUpgrade(operatorAsked: true));
  }

  Future<void> _offerUpgrade({required bool operatorAsked}) async {
    // A second pass cannot run beside the first: they would ask the same
    // question twice, and the second dialog would stand over a migration the
    // first is already running.
    if (_offering) return;
    _offering = true;
    try {
      await _offer(operatorAsked: operatorAsked);
    } finally {
      _offering = false;
    }
  }

  /// Its own method so the global translations are in scope: `_offer` binds a
  /// local `t` to the panel's strings, which shadows them for the whole body.
  void _sayCatalogUnreachable() => widget.services.statusBar
      .setMessage(key: 'extensions:upgradeOffer', text: t.extensionsPanel.upgradeUnreachable);

  Future<void> _offer({required bool operatorAsked}) async {
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
    if (!await canReachCatalog(widget.services.extensions)) {
      // Silence is right at a boot nobody was watching, and wrong when the
      // operator has just switched the experiment on and is looking at the
      // screen: "nothing happened" is exactly the complaint this gate's own
      // listener exists to answer. Offline, unwired, empty channel — the
      // operator can act on none of them, so they read the one sentence that
      // matters and it is retried next launch.
      if (operatorAsked) _sayCatalogUnreachable();
      return;
    }
    if (!mounted) return;
    // Re-read after that round trip: it is a forced fetch, seconds of it on a
    // slow link, and the screen is live throughout. An operator who switched
    // the experiment back off in the meantime would otherwise be asked
    // anyway — and accepting would migrate under a flag that is now off,
    // which `extensionsMigrated` then reports as done forever.
    if (!settings.experimentEnabled(kCatalogExperiment)) return;

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
    // What they lost is the one line they have to carry out of this dialog —
    // everything around it is reassurance — so it is the one line in bold.
    final doneBody = TextSpan(children: [
      TextSpan(text: t.upgradeDoneBody),
      if (unserved.isNotEmpty) ...[
        const TextSpan(text: '\n\n'),
        TextSpan(
          text: t.upgradeDoneUnserved(names: unserved.join(', ')),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: ' ${t.upgradeDoneUnservedHint}'),
      ],
    ]);
    await showDialog<void>(
      context: navigator,
      builder: (context) => HaloDialog(
        title: Text(done ? t.upgradeDoneTitle : t.upgradeFailedTitle),
        content: done ? Text.rich(doneBody) : Text(t.upgradeFailedBody),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
