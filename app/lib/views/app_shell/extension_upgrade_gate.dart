// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Once the boot has put back what it can on its own, the extensions the
// operator installed that the store no longer holds: offered at start until
// each is back or forgotten (docs/design/extension-install.md, "When the store
// is lost").

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
    unawaited(_offerRestore());
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
        await showHaloDialog<bool>(
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

              return HaloDialog(
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
      showHaloDialog<void>(
        context: navigator,
        barrierDismissible: false,
        builder: (context) => Builder(
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
    await showHaloDialog<void>(
      context: navigator,
      builder: (context) => HaloDialog(
        title: Text(title),
        content: Text.rich(body),
        cancel: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.done)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
