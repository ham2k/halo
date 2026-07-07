// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Export flow: the extension runtime generates the file content (export hooks
// are extension territory), the core owns file I/O and the save dialog. One
// coarse bridge call carries the whole operation.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
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

  /// Generates an export via the given export hook and prompts the user for
  /// a save location. Returns the saved path, or null if they cancelled.
  Future<String?> exportOperation(Operation operation, {String format = 'adif'}) async {
    final host = extensions.host;
    if (host == null) {
      throw ExportException('Extension runtime is not ready yet — try again in a moment.');
    }

    final qsoList = await qsos.watchForOperation(operation.uuid).first;
    if (qsoList.isEmpty) {
      throw ExportException('Nothing to export: this operation has no QSOs.');
    }

    final result = await host.invokeHook(
      'export',
      key: format,
      method: 'generateExport',
      args: {
        'operation': {...operation.data, 'uuid': operation.uuid},
        'qsos': [for (final qso in qsoList) qso.data],
      },
      timeout: const Duration(seconds: 30),
    ) as Map;

    final location = await getSaveLocation(
      suggestedName: result['filename'] as String? ?? 'export.adi',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ADIF log', extensions: ['adi', 'adif']),
      ],
    );
    if (location == null) return null;

    await File(location.path).writeAsString(result['content'] as String);
    return location.path;
  }
}
