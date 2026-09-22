// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// The desktop preferences stores write their whole file on every single
// `setBool`, straight onto the live file, and read it back with a bare
// `json.decode`. A process that dies mid-write therefore leaves a truncated
// file that ends every launch after it at the boot error screen, with deleting
// the file by hand the only way back and every setting in it gone.
//
// So this is not a test that the value round-trips. It is a test that the
// live file is never the one being written to.

import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ham2k_logger/services/app_storage_prefs.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

void main() {
  test('a preference write replaces the file rather than overwriting it', () async {
    final fs = MemoryFileSystem();
    await fs.directory('/prefs').create(recursive: true);
    final log = <String>[];

    final previous = SharedPreferencesStorePlatform.instance;
    addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
    final store = SharedPreferencesWindows()
      // ignore: invalid_use_of_visible_for_testing_member
      ..fs = _RecordingFileSystem(fs, log)
      // ignore: invalid_use_of_visible_for_testing_member
      ..pathProvider = _FixedPathProvider();
    SharedPreferencesStorePlatform.instance = store;

    await installAtomicPreferenceWrites();
    await store.setValue('String', 'flutter.call', 'N0DEV');

    // A `write shared_preferences.json` here — instead of the temporary and
    // the rename — is the truncation window back, whatever the value below
    // says: the file is only ever whole because it is replaced in one step.
    expect(log, ['write shared_preferences.json.tmp', 'rename shared_preferences.json.tmp -> shared_preferences.json']);
    expect(fs.file('/prefs/shared_preferences.json').readAsStringSync(), contains('N0DEV'));
  });
}

class _FixedPathProvider extends PathProviderWindows {
  @override
  Future<String?> getApplicationSupportPath() async => '/prefs';
}

/// Notes every write and rename, so a test can assert which file each one
/// landed on.
class _RecordingFileSystem extends ForwardingFileSystem {
  _RecordingFileSystem(super.delegate, this.log);

  final List<String> log;

  @override
  File file(dynamic path) => _RecordingFile(delegate.file(path), this, log);
}

class _RecordingFile extends ForwardingFileSystemEntity<File, io.File> with ForwardingFile {
  _RecordingFile(this.delegate, this.fileSystem, this.log);

  @override
  final io.File delegate;

  @override
  final FileSystem fileSystem;

  final List<String> log;

  @override
  Directory wrapDirectory(io.Directory delegate) => fileSystem.directory(delegate.path);

  @override
  File wrapFile(io.File delegate) => _RecordingFile(delegate, fileSystem, log);

  @override
  Link wrapLink(io.Link delegate) => fileSystem.link(delegate.path);

  @override
  void writeAsStringSync(String contents, {io.FileMode mode = io.FileMode.write, Encoding encoding = utf8, bool flush = false}) {
    log.add('write ${p.basename(delegate.path)}');
    delegate.writeAsStringSync(contents, mode: mode, encoding: encoding, flush: flush);
  }

  @override
  File renameSync(String newPath) {
    log.add('rename ${p.basename(delegate.path)} -> ${p.basename(newPath)}');
    return wrap(delegate.renameSync(newPath));
  }
}
