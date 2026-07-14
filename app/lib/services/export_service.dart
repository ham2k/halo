// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Export flow: the extension runtime generates each file's content (export
// hooks are extension territory, one `suggestExportOptions` call lists what's
// available, one `generateExport` call per selection produces it), the core
// owns file I/O and the save dialog/share sheet. One coarse bridge call per
// hook carries the whole operation.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:halo_core/halo_core.dart';

import 'extension_service.dart';

class ExportException implements Exception {
  final String message;
  ExportException(this.message);

  @override
  String toString() => message;
}

class ExportService {
  final ExtensionService extensions;
  final QsosRepository qsos;

  ExportService({required this.extensions, required this.qsos});

  Future<List<Qso>> _qsoListFor(Operation operation) async {
    final qsoList = (await qsos.watchForOperation(operation.uuid).first).where((q) => !q.isEvent).toList();
    if (qsoList.isEmpty) {
      throw ExportException('Nothing to export: this operation has no QSOs.');
    }
    return qsoList;
  }

  /// Every export option offered by every extension for this operation, for
  /// the Exports Panel's checkbox list.
  Future<List<Map<String, dynamic>>> getExportOptions(Operation operation) async {
    final qsoList = await _qsoListFor(operation);
    return extensions.getExportOptions(qsonPayloadFor(operation: operation, qsos: qsoList));
  }

  /// Generates file content for the given (previously listed) options.
  /// Returns one `{filename, mimeType, content}` map per option, in the same
  /// order.
  Future<List<Map<String, dynamic>>> generateExports(
    Operation operation,
    List<Map<String, dynamic>> selectedOptions,
  ) async {
    final host = extensions.host;
    if (host == null) {
      throw ExportException('Extension runtime is not ready yet — try again in a moment.');
    }
    final qsoList = await _qsoListFor(operation);
    final payload = qsonPayloadFor(operation: operation, qsos: qsoList);

    // Independent per-option calls (each produces its own file) — no
    // ordering dependency, so run them concurrently rather than paying for
    // N sequential bridge round-trips.
    final results = await Future.wait(selectedOptions.map((option) async {
      final result = await host.invokeHook(
        'export',
        key: option['hookKey'] as String?,
        method: 'generateExport',
        args: {...payload, 'exportType': option['exportType']},
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
