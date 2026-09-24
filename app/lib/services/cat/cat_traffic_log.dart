// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// DEVLOGCAT: every byte the app sends to and hears from its equipment, with
// the moment it happened, in a file an operator can send us. Written for the
// field reports nobody here can reproduce — a rig that answers for a minute
// and then goes quiet is a question about what crossed the wire, and only
// the wire can answer it.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:halo_core/halo_core.dart';

import '../../config/version.dart';
import 'cat_traffic_file.dart';

export 'cat_traffic_file.dart' show CatTrafficFile, openCatTrafficFile, readCatTrafficFile;

/// Where a recording stops growing. A forgotten recording on a chatty rig
/// must not fill a disk, and the upload has to fit a Sentry attachment.
/// About an hour of an IC-7300 polled at its defaults.
const catTrafficMaxBytes = 8 * 1024 * 1024;

/// One line of the log: when, which radio, which way, the bytes in hex, and
/// the same bytes as ASCII — CI-V reads in the hex, the Yaesu and Kenwood
/// text protocols read in the ASCII.
///
/// `>` is app to equipment, `<` is equipment to app. A receive line is one
/// chunk as the transport delivered it, NOT one frame: where a frame splits
/// across reads is part of what the log is for.
String formatCatTraffic(DateTime at, String node, String direction, List<int> bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  final ascii = String.fromCharCodes(bytes.map((b) => b >= 0x20 && b < 0x7F ? b : 0x2E));
  return '${at.toIso8601String()} $node $direction $hex |$ascii|';
}

/// The recording itself. Silent and cheap while off: [CatService] calls
/// [sent] and [received] on every chunk whether or not anything is recording.
class CatTrafficLog {
  final Future<CatTrafficFile?> Function({String? resumePath}) _open;
  final Future<Uint8List?> Function(String path) _read;

  /// Real time, never the app clock (docs/design/time.md): these stamps are
  /// read against an operator's account of when the rig went quiet, which
  /// happened in the real world whatever DEVTT says.
  final DateTime Function() now;

  final int maxBytes;

  /// Which build is recording, stated on every start and resume: a recording
  /// that spans a restart can span an update, and the upload is labelled
  /// with the build that SENDS it, not the ones that wrote it.
  final String build;

  CatTrafficLog({this._open = openCatTrafficFile, this._read = readCatTrafficFile, this.now = realNowUtc, this.maxBytes = catTrafficMaxBytes, String? build})
    : build = build ?? '$kPublicVersion+$kBuildNumber ${kEdition.name}${kGitSha.isEmpty ? '' : ' $kGitSha'}';

  CatTrafficFile? _file;
  Future<String?>? _starting;
  int _written = 0;
  bool _full = false;

  bool get active => _file != null;

  String? get path => _file?.path;

  /// Starts recording, appending to [resumePath] when that file is still
  /// there. Null where there is nowhere to write — the web build.
  ///
  /// A second call while the first is still opening shares its file: two
  /// quick DEVLOGCATs would otherwise open two, and leak one.
  Future<String?> start({String? resumePath}) async {
    if (_file != null) return _file!.path;
    return _starting ??= _begin(resumePath);
  }

  /// Clears [_starting] however the open ends: kept after a failure, it would
  /// hand the same error to every later start for the rest of the session.
  Future<String?> _begin(String? resumePath) async {
    try {
      final file = await _open(resumePath: resumePath);
      if (file == null) return null;
      _file = file;
      _written = file.length;
      _full = false;
      // "Resumed" only when the earlier half is really there to resume.
      note('log', '${file.path == resumePath ? 'recording resumed after a restart' : 'recording started'} by $build');
      return file.path;
    } finally {
      _starting = null;
    }
  }

  void sent(String node, List<int> bytes) {
    if (_file != null) _line(formatCatTraffic(now(), node, '>', bytes));
  }

  void received(String node, List<int> bytes) {
    if (_file != null) _line(formatCatTraffic(now(), node, '<', bytes));
  }

  /// Something that is not traffic but explains it: a connect, a close, the
  /// app deciding the radio has gone quiet.
  void note(String node, String text) {
    if (_file != null) _line('${now().toIso8601String()} $node -- $text');
  }

  /// Never throws: this runs inside every send and receive, and a full disk
  /// must cost the recording, never the radio.
  void _line(String line) {
    if (_full) return;
    try {
      final size = utf8.encode(line).length + 1;
      if (_written + size > maxBytes) {
        _full = true;
        _file!.write('${now().toIso8601String()} log -- size limit reached, recording stopped\n');
        return;
      }
      _file!.write('$line\n');
      _written += size;
    } catch (e) {
      _full = true;
      debugPrint('[cat] traffic log write failed, recording stopped: $e');
    }
  }

  /// A finished recording left by an earlier launch, or null when its file
  /// is gone.
  Future<Uint8List?> collect(String path) => _read(path);

  /// Stops recording and hands back what was recorded, or null when nothing
  /// was.
  Future<({String path, Uint8List bytes})?> stop() async {
    final file = _file;
    if (file == null) return null;
    note('log', 'recording stopped');
    _file = null;
    return (path: file.path, bytes: await file.close());
  }
}
