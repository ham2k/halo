// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';
import 'dart:typed_data';

import 'package:halo_core/halo_core.dart';
import 'package:path/path.dart' as p;

import '../app_storage.dart';

/// An open DEVLOGCAT file.
abstract interface class CatTrafficFile {
  String get path;

  /// Bytes already in the file when it was opened — what an earlier launch
  /// recorded, which counts against the same size limit.
  int get length;

  /// Written through to the file before it returns: the lines that matter
  /// most are the last ones before a quit or a crash, and a buffer would
  /// lose exactly those.
  void write(String text);

  /// Closes, and returns everything the file holds — including what an
  /// earlier launch wrote to it before a restart.
  Future<Uint8List> close();
}

/// A new file under the app's data folder, or [resumePath] appended to when
/// it still exists — a log that outlives a restart must stay one file, or
/// the upload carries only the half after it.
Future<CatTrafficFile?> openCatTrafficFile({String? resumePath}) async {
  File file;
  if (resumePath != null && File(resumePath).existsSync()) {
    file = File(resumePath);
  } else {
    final directory = Directory(p.join((await appDataDirectory()).path, 'logs'));
    await directory.create(recursive: true);
    // Real time, and a name that sorts: an operator sending "the latest one"
    // picks it by eye.
    // To the millisecond: a recording started right after one was sent must
    // not append to the file that was just uploaded.
    final stamp = realNowUtc().toIso8601String().replaceAll(RegExp(r'[-:.]'), '');
    file = File(p.join(directory.path, 'cat-traffic-$stamp.log'));
  }
  final length = file.existsSync() ? file.lengthSync() : 0;
  return _IoCatTrafficFile(file, file.openSync(mode: FileMode.append), length);
}

/// A finished recording's contents, or null when the file is gone.
Future<Uint8List?> readCatTrafficFile(String path) async {
  final file = File(path);
  return file.existsSync() ? file.readAsBytes() : null;
}

class _IoCatTrafficFile implements CatTrafficFile {
  final File _file;
  final RandomAccessFile _handle;

  @override
  final int length;

  _IoCatTrafficFile(this._file, this._handle, this.length);

  @override
  String get path => _file.path;

  @override
  void write(String text) => _handle.writeStringSync(text);

  @override
  Future<Uint8List> close() async {
    await _handle.close();
    return _file.readAsBytes();
  }
}
