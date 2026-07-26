// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Export flow: the extension runtime generates each file's content (export
// hooks are extension territory, one `suggestExportOptions` call lists what's
// available, one `generateExport` call per selection produces it), the core
// owns file I/O and the save dialog/share sheet. One coarse bridge call per
// hook carries the whole operation.

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:halo_core/halo_core.dart';

import 'extension_service.dart';
import 'settings_service.dart';

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}

class ExportService {
  final ExtensionService extensions;
  final QsosRepository qsos;
  final SettingsService settings;

  ExportService({required this.extensions, required this.qsos, required this.settings});

  /// Raw QSON dump (the same payload every hook receives), offered only in
  /// developer mode — same as app-polo's devMode extension. Generated here in
  /// Dart, no extension involved.
  static const _qsonHookKey = 'core-devmode';
  static const _qsonExportType = 'devmode-qson';

  bool _isQsonOption(Map<String, dynamic> option) =>
      option['hookKey'] == _qsonHookKey && option['exportType'] == _qsonExportType;

  Map<String, dynamic> _qsonOptionFor(Operation operation) {
    final date = (operation.startAtMax ?? DateTime.now().toUtc()).toIso8601String().substring(0, 10);
    final call = operation.stationCall.replaceAll('/', '-');
    final shortUuid = operation.uuid.split('-').first;
    return {
      'hookKey': _qsonHookKey,
      'exportType': _qsonExportType,
      'label': 'Developer Mode: QSON Export',
      'filename': '$date.$call.$shortUuid.qson',
      'icon': 'briefcase-upload',
      'priority': -100,
      'selectedByDefault': false,
    };
  }

  /// The operation's contacts, and its segments.
  ///
  /// The segments are resolved from the FULL list, because the `break`/`start`
  /// event rows carrying the overrides are exactly what the contact list
  /// filters out (docs/design/contests.md §5.1.3) — the same trap
  /// `ScoringService.rescoreOperation` documents.
  Future<({List<Qso> qsos, SegmentedOperation segmented})> _logFor(Operation operation) async {
    final all = await qsos.watchForOperation(operation.uuid).first;
    final qsoList = all.where((q) => !q.isEvent).toList();
    if (qsoList.isEmpty) {
      throw ExportException('Nothing to export: this operation has no QSOs.');
    }
    return (qsos: qsoList, segmented: SegmentedOperation.from(operation: operation.data, qsos: all));
  }

  /// The QSOs one export is responsible for.
  ///
  /// An option naming a `refType` covers only the stretches where that activity
  /// was actually running — the segments carrying a ref of that type (§5.1.4).
  /// A contest that started at a break would otherwise put the whole operation
  /// into its Cabrillo, including the contacts made before it began: a false
  /// claim in a submitted file, and the same mistake the scorer made before
  /// §5.1.3 gated it.
  ///
  /// An option with no `refType` — the full ADIF — takes the whole log. So does
  /// an unsegmented operation, where every QSO is in the one segment and this
  /// is identity.
  ///
  /// Several refs of one type (two parks) union rather than picking one: until
  /// a per-REFERENCE export exists (§5.1.4's other half, which nothing yet
  /// needs), one export covers the type, and quietly dropping half the log
  /// would be worse than covering both.
  List<Qso> _qsosForOption(
    Map<String, dynamic> option,
    List<Qso> qsoList,
    SegmentedOperation segmented,
  ) {
    final refType = option['refType'];
    if (refType is! String || refType.isEmpty) return qsoList;

    final refs = segmented.allRefs.where((ref) => ref['type'] == refType).toList();
    // Offered for an operation that doesn't carry the ref at all: leave the log
    // alone rather than writing an empty file over a hook's own judgement.
    if (refs.isEmpty) return qsoList;

    final keep = <String>{
      for (final ref in refs)
        for (final qso in segmented.qsosFor(qsoList, ref)) qso.uuid,
    };
    final scoped = [
      for (final qso in qsoList)
        if (keep.contains(qso.uuid)) qso,
    ];

    // Same promise as the bail-out above, and it has to be made here too: a ref
    // can be on the operation while every segment override omits it, and then
    // the slice comes back EMPTY rather than absent.
    //
    // That state means the segments and the operation disagree, and today it
    // comes from HaLo itself — the Activities view writes `operation.refs` with
    // no segment bookkeeping, because there is no segment UI yet (§5.1.3), so
    // turning an activity on for a polo-synced log produces exactly it. An
    // empty submission file is the worse failure of the two: the operator gets
    // a Cabrillo with no QSOs in it and no indication why, while an over-broad
    // one is visible in the file and can be pruned. So the whole log wins until
    // segments are something the app maintains rather than only imports.
    return scoped.isEmpty ? qsoList : scoped;
  }

  /// Every export option offered by every extension for this operation, for
  /// the Exports Panel's checkbox list.
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    final log = await _logFor(operation);
    final payload = qsonPayloadFor(operation: operation, qsos: log.qsos);

    // Hooks are asked about every ref ANY segment carries, not just the base's.
    // Each contest's `suggestExportOptions` opens with
    // `if (!refOfType(args.operation, TYPE)) return []`, so a contest that
    // ended at a break — its ref living on in the segments while the operation
    // has moved on — would otherwise be offered no Cabrillo at all, for a log
    // that is half contest QSOs.
    //
    // The same asymmetry `ScoringService` fixed for scorers by handing
    // `scorersFor` the segments (§5.1.3): an operation is scored as a contest
    // it can no longer be exported as, which is worse than either alone.
    if (log.segmented.isSegmented) {
      (payload['operation'] as Map<String, dynamic>)['refs'] = log.segmented.allRefs;
    }

    final options = await extensions.getExportOptions(payload);
    if (settings.developerMode) {
      return [...options, _qsonOptionFor(operation)];
    }
    return options;
  }

  /// Generates file content for the given (previously listed) options.
  /// Returns one `{filename, mimeType, content}` map per option, in the same
  /// order.
  Future<List<Map<String, dynamic>>> generateExports(
    Operation operation,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    final host = extensions.host;
    if (host == null && selectedOptions.any((o) => !_isQsonOption(o))) {
      throw ExportException('Extension runtime is not ready yet — try again in a moment.');
    }
    final log = await _logFor(operation);
    // The developer QSON dump is the raw log, deliberately unsliced — it exists
    // to show what the hooks were given for the operation as a whole.
    final payload = qsonPayloadFor(operation: operation, qsos: log.qsos);

    // Independent per-option calls (each produces its own file) — no
    // ordering dependency, so run them concurrently rather than paying for
    // N sequential bridge round-trips.
    final results = await Future.wait(selectedOptions.map((option) async {
      if (_isQsonOption(option)) {
        return {
          'filename': _qsonOptionFor(operation)['filename'],
          'mimeType': 'application/json',
          'content': jsonEncode(payload),
        };
      }
      final scoped = _qsosForOption(option, log.qsos, log.segmented);
      final result = await host!.invokeHook(
        'export',
        key: option['hookKey'] as String?,
        method: 'generateExport',
        args: {
          ...qsonPayloadFor(operation: operation, qsos: scoped),
          'exportType': option['exportType'],
        },
        timeout: const Duration(seconds: 30),
      ) as Map;
      return result.cast<String, dynamic>();
    }));
    return results;
  }

  /// Disambiguates filenames that collide (two selected results sharing a
  /// name, or both missing one) before writing — a later hook's export
  /// would otherwise silently overwrite an earlier one on disk.
  List<String> _uniqueFilenames(List<Map<String, dynamic>> files) {
    final seen = <String, int>{};
    return [
      for (final file in files)
        () {
          final base = (file['filename'] as String?)?.isNotEmpty == true ? file['filename'] as String : 'export.txt';
          final count = seen.update(base, (n) => n + 1, ifAbsent: () => 1);
          if (count == 1) return base;
          final ext = p.extension(base);
          final stem = base.substring(0, base.length - ext.length);
          return '$stem-$count$ext';
        }(),
    ];
  }

  /// Desktop save flow: a single file opens a save dialog for that file;
  /// multiple files opens a directory picker and writes them all there.
  /// Returns the saved path (single file) or directory path (multiple), or
  /// null if the user cancelled.
  Future<String?> saveToDisk(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return null;

    if (files.length == 1) {
      final file = files.first;
      final filename = file['filename'] as String? ?? 'export.txt';
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [
          XTypeGroup(label: filename, extensions: [p.extension(filename).replaceFirst('.', '')]),
        ],
      );
      if (location == null) return null;
      await File(location.path).writeAsString(file['content'] as String);
      return location.path;
    }

    final directory = await getDirectoryPath();
    if (directory == null) return null;
    final filenames = _uniqueFilenames(files);
    for (var i = 0; i < files.length; i++) {
      await File(p.join(directory, filenames[i])).writeAsString(files[i]['content'] as String);
    }
    return directory;
  }

  /// Mobile share flow: writes every file to a temp directory, then opens
  /// the native share sheet with all of them at once.
  Future<void> shareFiles(List<Map<String, dynamic>> files) async {
    if (files.isEmpty) return;
    final tempDir = await getTemporaryDirectory();
    final filenames = _uniqueFilenames(files);
    final paths = <XFile>[];
    for (var i = 0; i < files.length; i++) {
      final path = p.join(tempDir.path, filenames[i]);
      await File(path).writeAsString(files[i]['content'] as String);
      paths.add(XFile(path, mimeType: files[i]['mimeType'] as String?));
    }
    await SharePlus.instance.share(ShareParams(files: paths));
  }
}
