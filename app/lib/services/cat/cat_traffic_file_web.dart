// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:typed_data';

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

Future<CatTrafficFile?> openCatTrafficFile({String? resumePath}) async => null;

Future<Uint8List?> readCatTrafficFile(String path) async => null;
