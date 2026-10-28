// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Importing a QSON file as a new operation — a Developer Mode tool, the
// counterpart of the Developer Mode QSON export. Two ways in, the Developer
// settings panel and a file dropped on the operations list, and one path out:
// the new operation opens.

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/error_reporting_service.dart';
import '../services/file_pick.dart';
import '../services/halo_services.dart';
import 'home_navigation_rail.dart' show slideInFromRight;
import 'operation_view.dart';

/// The filter handed to the picker. iOS filters by UTI and THROWS for a group
/// carrying none (`file_selector_ios`); `.qson` has none of its own, so the
/// group asks for `public.data` and the import itself decides.
@visibleForTesting
List<XTypeGroup> qsonTypeGroups() => [
  const XTypeGroup(label: 'QSON', extensions: ['qson', 'json'], uniformTypeIdentifiers: ['public.data'], mimeTypes: ['application/json']),
];

/// One import at a time: a second drop while the first is writing would open
/// two operations on top of each other.
bool _qsonImportInFlight = false;

/// Imports [file] — or one the operator picks, when null — as a new operation
/// and opens it.
Future<void> runQsonImport(BuildContext context, HaLoServices services, {XFile? file}) async {
  final t = context.t.qsonImport;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context);
  final XFile? chosen;
  try {
    chosen = file ?? await pickFile(acceptedTypeGroups: qsonTypeGroups());
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'qsonImport:picker', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.pickerFailed(error: ErrorReportingService.messageOf(e))));
    return;
  }
  if (chosen == null) return;
  // Claimed after the pick, not before: a picker whose cancel never answers
  // would otherwise hold it for the rest of the session.
  if (_qsonImportInFlight) {
    messenger?.showSnackBar(haloSnackBar(t.busy));
    return;
  }
  _qsonImportInFlight = true;
  final filename = chosen.name;
  final Operation operation;
  try {
    services.statusBar.setMessage(
      key: 'qsonImport:status',
      text: t.importing(filename: filename),
    );
    operation = await importQsonOperation(db: services.db, operations: services.operations, qsos: services.qsos, bytes: await chosen.readAsBytes());
  } on QsonImportException catch (e) {
    // The file, not the app: nothing to report.
    final message = switch (e.problem) {
      QsonImportProblem.notUtf8 => t.notUtf8(filename: filename),
      QsonImportProblem.notJson => t.notJson(filename: filename),
      QsonImportProblem.notOperation => t.notOperation(filename: filename),
    };
    messenger?.showSnackBar(haloSnackBar(message));
    return;
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'qsonImport', told: messenger != null);
    messenger?.showSnackBar(haloSnackBar(t.failed(filename: filename, error: ErrorReportingService.messageOf(e))));
    return;
  } finally {
    _qsonImportInFlight = false;
    services.statusBar.clear('qsonImport:status');
  }
  services.track('qson_imported');
  if (navigator.mounted) {
    await navigator.push(slideInFromRight<void>((_) => OperationView(services: services, operationUuid: operation.uuid)));
  }
}

/// Takes a QSON file dropped anywhere on its [child] while [enabled]. Inert on
/// iOS and Android, where there is no file drag; those import through the
/// Developer settings panel.
class QsonDropTarget extends StatefulWidget {
  final HaLoServices services;
  final bool enabled;
  final Widget child;

  const QsonDropTarget({super.key, required this.services, required this.enabled, required this.child});

  @override
  State<QsonDropTarget> createState() => _QsonDropTargetState();
}

class _QsonDropTargetState extends State<QsonDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `desktop_drop` reaches every target under the point — routes beneath
    // a dialog, a dock tab behind the one selected, and destinations slid
    // over this one, included — so each says when this one is showing.
    final enable = widget.enabled && DockPaneVisibility.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    // A disabled target hears no exit, so a drag hovering when it turned off
    // would leave the overlay up over the list for good.
    if (!enable) _hovering = false;
    return DropTarget(
      enable: enable,
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) async {
        setState(() => _hovering = false);
        // Each file would open its own operation over the last.
        if (details.files.length > 1) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(haloSnackBar(context.t.qsonImport.oneFileOnly));
          return;
        }
        final file = details.files.firstOrNull;
        if (file != null && mounted) await runQsonImport(context, widget.services, file: file);
      },
      child: Stack(
        children: [
          widget.child,
          if (_hovering)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.lg),
                        child: Text(context.t.qsonImport.dropHint, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
