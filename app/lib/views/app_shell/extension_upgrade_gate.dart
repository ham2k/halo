// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The one-time move to catalog extensions, offered at start until it is taken
// (services/extensions/extension_catalog_migration.dart).
//
// Deferrable by design, which is only honest because nothing is withdrawn
// until the upgrade succeeds: saying Later leaves every extension working and
// the offer comes back next launch.
//
// Then, once the boot has put back what it can on its own, the extensions the
// operator installed that the store no longer holds: offered at start until
// each is back or forgotten (docs/extensions/distribution.md, "When the store
// is lost"). One gate for both, so the two offers never stand over each other.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../../config/navigation.dart';
import '../../services/error_reporting_service.dart';
import '../../services/extensions/extension_catalog_migration.dart';
import '../../services/extensions/preloaded_extensions.dart';
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
    unawaited(_offerAll());
  }

  Future<void> _offerAll() async {
    await _offer();
    await _offerRestore();
  }

  Future<void> _offer() async {
    final settings = widget.services.settings;
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

  /// Offers back what the operator installed and the store no longer holds.
  ///
  /// Later keeps every one of them for the next launch; Forget is the only
  /// way one leaves the list short of coming back, since a file install has
  /// nowhere else to come from. Each install stands alone, and the result
  /// names whatever did not make it.
  Future<void> _offerRestore() async {
    final extensions = widget.services.extensions;
    await extensions.firstCatchUp;
    if (!mounted) return;
    var missing = extensions.missingExtensions();
    if (missing.isEmpty) return;
    final navigator = navigatorKey.currentContext;
    if (navigator == null || !navigator.mounted) return;

    final accepted =
        await showDialog<bool>(
          context: navigator,
          barrierDismissible: false,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final t = context.t.extensionsPanel;
              final fetchable = [
                for (final m in missing)
                  if (m.fetchable) m,
              ];
              final fromFile = [
                for (final m in missing)
                  if (m.from == MissingFrom.file) m,
              ];
              final elsewhere = [
                for (final m in missing)
                  if (m.from == MissingFrom.otherCatalog) m,
              ];
              Future<void> forget(MissingExtension m) async {
                try {
                  await extensions.forgetMissingExtension(m.key);
                } catch (e, stack) {
                  // Left on the list: it is still recorded, and the next
                  // launch offers it again.
                  ErrorReportingService.report(e, stack, context: 'extensions:restore-forget');
                  return;
                }
                // The operator may have answered Later meanwhile.
                if (!context.mounted) return;
                setDialogState(
                  () => missing = [
                    for (final other in missing)
                      if (other.key != m.key) other,
                  ],
                );
                if (missing.isEmpty) Navigator.of(context).pop(false);
              }

              Widget forgettable(MissingExtension m) => Row(
                children: [
                  Expanded(child: Text('• ${m.name}')),
                  TextButton(key: ValueKey('restore-forget-${m.key}'), onPressed: () => forget(m), child: Text(t.restoreForget)),
                ],
              );

              return HoldSizeWhileCovered(
                child: HaloDialog(
                  title: Text(t.restoreTitle),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Forget on every row: one the catalog stopped
                        // serving would otherwise come back every launch.
                        if (fetchable.isNotEmpty) ...[Text(t.restoreBody), for (final m in fetchable) forgettable(m)],
                        if (fromFile.isNotEmpty) ...[
                          if (fetchable.isNotEmpty) const SizedBox(height: Space.md),
                          Text(t.restoreFromFile),
                          for (final m in fromFile) forgettable(m),
                        ],
                        if (elsewhere.isNotEmpty) ...[
                          if (fetchable.isNotEmpty || fromFile.isNotEmpty) const SizedBox(height: Space.md),
                          Text(t.restoreOtherCatalog),
                          for (final m in elsewhere) forgettable(m),
                        ],
                      ],
                    ),
                  ),
                  cancel: TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.restoreLater)),
                  actions: [if (fetchable.isNotEmpty) FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.restoreInstall))],
                ),
              );
            },
          ),
        ) ??
        false;
    if (!accepted || !mounted || !navigator.mounted) return;

    final t = navigator.t.extensionsPanel;
    // Not awaited: it stays up until the restore is done. Taken down by its
    // own route, not a bare pop: anything pushed over it meanwhile — the
    // command palette, a pairing prompt — would be popped instead, and this
    // left standing with no way out.
    ModalRoute<Object?>? spinner;
    unawaited(
      showDialog<void>(
        context: navigator,
        barrierDismissible: false,
        builder: (context) => HoldSizeWhileCovered(
          child: Builder(
            builder: (context) {
              spinner ??= ModalRoute.of(context);
              return HaloDialog(
                content: Row(
                  children: [
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                    const SizedBox(width: Space.lg),
                    Expanded(child: Text(t.restoreInstalling)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    RestoreResult result;
    try {
      result = await restoreMissingExtensions(extensions, missing);
    } catch (e, stack) {
      // Everything is still recorded, so the next launch offers it all again;
      // what matters here is not leaving the operator behind a spinner.
      ErrorReportingService.report(e, stack, context: 'extensions:restore');
      // Judged afresh: some may have landed before the throw.
      final still = {for (final m in extensions.missingExtensions()) m.key};
      result = RestoreResult(
        installed: [
          for (final m in missing)
            if (m.fetchable && !still.contains(m.key)) m.name,
        ],
        failed: [
          for (final m in missing)
            if (m.fetchable && still.contains(m.key)) m.name,
        ],
      );
    }
    // A restore quick enough to finish before the spinner's first frame
    // leaves nothing built to name its route by.
    if (spinner == null) await WidgetsBinding.instance.endOfFrame;
    final route = spinner;
    if (navigator.mounted && route != null && route.isActive) {
      if (route.isCurrent) {
        Navigator.of(navigator).pop();
      } else {
        Navigator.of(navigator).removeRoute(route);
      }
    }

    final ok = !result.busy && !result.runtimeDead && result.failed.isEmpty && result.wouldNotRun.isEmpty;
    final body = TextSpan(
      children: [
        if (result.busy) TextSpan(text: t.restoreBusyBody),
        if (result.runtimeDead) ...[
          TextSpan(
            text: t.restoreRuntimeDeadBody,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: '\n\n'),
        ],
        if (result.installed.isNotEmpty) TextSpan(text: t.restoreDoneBody(names: result.installed.join(', '))),
        if (result.failed.isNotEmpty) ...[
          if (result.installed.isNotEmpty) const TextSpan(text: '\n\n'),
          TextSpan(
            text: t.restoreFailed(names: result.failed.join(', ')),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
        if (result.wouldNotRun.isNotEmpty) ...[
          const TextSpan(text: '\n\n'),
          TextSpan(
            text: t.upgradeDoneRefused(names: result.wouldNotRun.join(', ')),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: ' ${t.upgradeDoneRefusedHint}'),
        ],
      ],
    );
    final title = switch (result) {
      RestoreResult(busy: true) => t.upgradeBusyTitle,
      RestoreResult(runtimeDead: true) => t.upgradeRuntimeDeadTitle,
      _ when ok => t.restoreDoneTitle,
      _ => t.restorePartialTitle,
    };
    if (!mounted || !navigator.mounted) {
      widget.services.statusBar.showNotice(key: 'extensions:restoreResult', title: title, text: body.toPlainText());
      return;
    }
    await showDialog<void>(
      context: navigator,
      builder: (context) => HoldSizeWhileCovered(
        child: HaloDialog(
          title: Text(title),
          content: Text.rich(body),
          cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
