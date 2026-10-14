// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Importing a sponsor's export into a chasing program (docs/design/claims.md
// §9), from the Chasing sheet's import button or a file dropped on the
// Chasing view. Which program reads a file is decided by its extension,
// before anything runs: each program lists its importers as data.

import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:halo_core/halo_core.dart';
import 'package:halo_i18n/halo_i18n.dart';
import 'package:halo_widgets/halo_widgets.dart';

import '../services/error_reporting_service.dart';
import '../services/halo_services.dart';

/// The filter handed to the picker for [importer].
///
/// iOS filters by UTI and THROWS for a group carrying none
/// (`file_selector_ios`), and a sponsor's export has no UTI of its own, so
/// the group asks for `public.data`. Android greys out anything outside the
/// requested MIME types and maps few extensions to one, so there the group is
/// empty, asking for `*/*`. Either way the program decides what it can read:
/// a file it cannot answers with no claims, and replaces nothing.
@visibleForTesting
List<XTypeGroup> chaseImportTypeGroups(ChasingImporter importer) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return const [];
  return [
    XTypeGroup(label: importer.label, extensions: importer.extensions, uniformTypeIdentifiers: const ['public.data']),
  ];
}

/// [bytes] as the text a program reads. A sponsor's export is text: a stray
/// byte that is not UTF-8 costs that character, not the file, and the byte
/// order mark a spreadsheet writes ahead of the header is not part of it.
@visibleForTesting
String chaseImportText(List<int> bytes) => utf8.decode(bytes, allowMalformed: true).replaceFirst(RegExp('^\uFEFF'), '');

/// Reads [file] — or one the operator picks, when null — through
/// [program]'s [importer] for [station] ([stationOfOperation]), and says how
/// it went. A file that cannot be picked, read or written says so, and is
/// reported: the operator asked for this import and waits to hear how it
/// went.
Future<void> runChaseImport(
  BuildContext context,
  HaLoServices services,
  ChasingProgram program,
  ChasingImporter importer, {
  required Map<String, dynamic> station,
  XFile? file,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = context.t.chase.imports;
  var name = file?.name ?? importer.label;
  final ({int claims, int skipped})? outcome;
  try {
    final chosen = file ?? await openFile(acceptedTypeGroups: chaseImportTypeGroups(importer));
    if (chosen == null) return;
    name = chosen.name;
    outcome = await services.chase.importFile(program, importer, name: chosen.name, text: chaseImportText(await chosen.readAsBytes()), station: station);
  } catch (e, stack) {
    ErrorReportingService.report(e, stack, context: 'chaseImport');
    messenger?.showSnackBar(haloSnackBar(t.failed(program: program.label, file: name)));
    return;
  }
  final message = switch (outcome) {
    null => t.failed(program: program.label, file: name),
    (claims: 0, skipped: 0) => t.nothing(program: program.label, file: name),
    // Every record skipped is the export the program does not understand —
    // a sponsor that changed its format — not one that has nothing in it.
    (claims: 0, skipped: final skipped) => t.unreadable(program: program.label, file: name, skipped: formatNumber(skipped)),
    (claims: final count, skipped: 0) => t.done(count: formatNumber(count), program: program.label, file: name),
    (claims: final count, skipped: final skipped) => t.doneSkipped(
      count: formatNumber(count),
      program: program.label,
      file: name,
      skipped: formatNumber(skipped),
    ),
  };
  messenger?.showSnackBar(haloSnackBar(message));
}

/// A [file] dropped on the Chasing view: read by the one importer that takes
/// its extension, or by the one the operator picks when several do.
Future<void> importDroppedChaseFile(BuildContext context, HaLoServices services, XFile file, {required Map<String, dynamic> station}) async {
  final t = context.t.chase.imports;
  final candidates = [
    for (final program in services.chase.programs.values)
      for (final importer in program.imports)
        if (importer.takes(file.name)) (program: program, importer: importer),
  ];
  if (candidates.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(haloSnackBar(t.noProgram(file: file.name)));
    return;
  }
  final chosen = candidates.length == 1
      ? candidates.single
      : await showHaloDialog<({ChasingProgram program, ChasingImporter importer})>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(t.pickTitle(file: file.name)),
            children: [
              for (final candidate in candidates)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(candidate),
                  child: Text('${candidate.program.label}: ${candidate.importer.label}'),
                ),
            ],
          ),
        );
  if (chosen == null || !context.mounted) return;
  await runChaseImport(context, services, chosen.program, chosen.importer, station: station, file: file);
}

/// Takes a file dropped anywhere on its [child]. Inert on iOS and Android,
/// where there is no file drag; those import through the sheet's button.
class ChaseImportDropTarget extends StatefulWidget {
  final Widget child;
  final Future<void> Function(XFile file) onFile;

  const ChaseImportDropTarget({super.key, required this.child, required this.onFile});

  @override
  State<ChaseImportDropTarget> createState() => _ChaseImportDropTargetState();
}

class _ChaseImportDropTargetState extends State<ChaseImportDropTarget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropTarget(
      // `desktop_drop` reaches every target under the point, routes beneath
      // a dialog included: without this a drop on an open dialog imports
      // behind it.
      enable: ModalRoute.of(context)?.isCurrent ?? true,
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) async {
        setState(() => _hovering = false);
        for (final file in details.files) {
          if (!mounted) return;
          await widget.onFile(file);
        }
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
                        child: Text(context.t.chase.imports.dropHint, style: theme.textTheme.titleMedium),
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
