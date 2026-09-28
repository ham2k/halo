// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move to catalog extensions, offered at start until it is taken
// (services/extensions/extension_catalog_migration.dart).
//
// Deferrable by design, which is only honest because nothing is withdrawn
// until the upgrade succeeds: saying Later leaves every extension working and
// the offer comes back next launch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/navigation.dart';
import '../../services/extensions/extension_catalog_migration.dart';
import '../../services/extensions/installed_extensions.dart';
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
    unawaited(_offer());
  }

  Future<void> _offer() async {
    final settings = widget.services.settings;
    // Nowhere to put the replacements: web has no extension store, so every
    // step of the upgrade no-ops and it ends in the failure dialog — asked
    // again on every launch, and never able to answer differently.
    if (!InstalledExtensions.isSupported) return;
    // A fresh install starts upgraded (seedExtensionsMigratedDefault), so
    // this is only ever asked of one that has extensions of its own.
    if (settings.extensionsMigrated) return;
    // Asked BEFORE the dialog, so nobody is shown a button that cannot work.
    // Unreachable is silent: this runs at a boot nobody was watching, and the
    // offer is retried next launch.
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
    final accepted =
        await showDialog<bool>(
          context: navigator,
          barrierDismissible: false,
          builder: (context) => HoldSizeWhileCovered(
            child: HaloDialog(
              title: Text(t.upgradeTitle),
              content: Text(t.upgradeBody),
              cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.upgradeLater)),
              actions: [FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.upgradeAction))],
            ),
          ),
        ) ??
        false;
    if (!accepted || !mounted) return;

    final outcome = await migrateToCatalogExtensions(widget.services.extensions);
    final done = outcome == UpgradeOutcome.done;
    // Said either way: the operator agreed to an operation that withdraws the
    // extensions they had, so leaving them to guess whether it happened is
    // the one thing this must not do. A built-in with no catalog twin finishes
    // the upgrade rather than failing it, so this is also where its withdrawal
    // is said.
    final unserved = done ? unservedBuiltInNames(widget.services.extensions) : const <String>[];
    // Whatever the outcome: a bundle put aside stays out of the runtime even
    // when the upgrade reverted around it, so the operator is told which
    // extension that was on the dialog they are actually reading.
    final refused = refusedExtensionNames(widget.services.extensions);
    // What they lost is the one line they have to carry out of this dialog —
    // everything around it is reassurance — so it is the one line in bold.
    // The two losses get their own sentences: nothing replaces a built-in the
    // catalog does not serve, while a refused one is installed and an update
    // away, and telling them to go looking for a substitute sends them
    // nowhere.
    final refusedSpans = <InlineSpan>[
      if (refused.isNotEmpty) ...[
        const TextSpan(text: '\n\n'),
        TextSpan(
          text: t.upgradeDoneRefused(names: refused.join(', ')),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: ' ${t.upgradeDoneRefusedHint}'),
      ],
    ];
    final doneBody = TextSpan(
      children: [
        TextSpan(text: t.upgradeDoneBody),
        if (unserved.isNotEmpty) ...[
          const TextSpan(text: '\n\n'),
          TextSpan(
            text: t.upgradeDoneUnserved(names: unserved.join(', ')),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: ' ${t.upgradeDoneUnservedHint}'),
        ],
        ...refusedSpans,
      ],
    );
    final (title, body) = switch (outcome) {
      UpgradeOutcome.done => (t.upgradeDoneTitle, doneBody.toPlainText()),
      // Nothing failed and nothing changed: the boot's own catch-up held the
      // flag, and the offer comes back on its own.
      UpgradeOutcome.busy => (t.upgradeBusyTitle, t.upgradeBusyBody),
      // The twins installed, the runtime would not come back with them, and
      // the revert DID boot — so this reads as the reassurance it is.
      UpgradeOutcome.runtimeReverted => (t.upgradeRevertedTitle, t.upgradeRevertedBody),
      // Neither set would start. The one message here that must not promise
      // working extensions, because there are none.
      UpgradeOutcome.runtimeDead => (t.upgradeRuntimeDeadTitle, t.upgradeRuntimeDeadBody),
      // Named causes only where the cause is known: a download that did not
      // arrive is worth "try again when you are online", and everything else
      // would be sending the operator to fix a connection that was never the
      // problem.
      UpgradeOutcome.incomplete => (t.upgradeFailedTitle, t.upgradeIncompleteBody),
      UpgradeOutcome.failed => (t.upgradeFailedTitle, t.upgradeFailedBody),
      // A wiring defect is reported, never explained — there is nothing the
      // operator could do with the difference, and nothing of theirs moved.
      UpgradeOutcome.notWired => (t.upgradeFailedTitle, t.upgradeUnavailableBody),
    };
    // One text for both places it can be shown, so a notice never says less
    // than the dialog it stands in for — the names of what stayed out are
    // the one line the operator has to carry away.
    final shown = done
        ? doneBody
        : TextSpan(
            children: [
              TextSpan(text: body),
              ...refusedSpans,
            ],
          );
    if (!mounted || !navigator.mounted) {
      // The screen the dialog would have used is gone — a rebuild, a hot
      // reload, the operator navigating — and they agreed to an operation
      // that withdraws their extensions. The status bar outlives this widget,
      // and a notice stays in Recent Notices, so what happened is still
      // findable rather than dropped on the floor.
      widget.services.statusBar.showNotice(key: 'extensions:upgradeResult', title: title, text: shown.toPlainText());
      return;
    }
    await showDialog<void>(
      context: navigator,
      builder: (context) => HoldSizeWhileCovered(
        child: HaloDialog(
          title: Text(title),
          content: Text.rich(shown),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
