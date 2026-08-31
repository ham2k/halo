// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:convert' show Encoding, utf8;
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_linux/shared_preferences_linux.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

import 'error_reporting_service.dart';

/// Makes shared_preferences write `shared_preferences.json` into [directory]
/// instead of the app-support directory it would pick for itself.
///
/// The plugin builds that path from a `PathProviderWindows` it constructs
/// internally, so overriding `PathProviderPlatform.instance` — the seam that
/// works for everything else — doesn't reach it, and the only public knob its
/// options expose is the file's *name*. Substituting the store's own provider
/// is what's left, and it keeps the plugin's read/write logic intact rather
/// than reimplementing preference storage. Must run before anything awaits
/// `SharedPreferences.getInstance()`: the store caches what it first read.
///
/// Windows only — every other platform already writes its preferences into
/// the directory [appDataDirectory] resolves to.
Future<void> redirectPreferencesDirectory(String directory) async {
  final store = SharedPreferencesStorePlatform.instance;
  if (store is! SharedPreferencesWindows) {
    // Not a crash: preferences keep working from wherever the plugin decides.
    // Reported because it silently splits settings from the rest of the
    // app's files, which is exactly what this is here to prevent.
    ErrorReportingService.report(
      StateError('shared_preferences store is ${store.runtimeType}, not SharedPreferencesWindows'),
      StackTrace.current,
      context: 'app-storage:redirect-preferences',
    );
    return;
  }
  // ignore: invalid_use_of_visible_for_testing_member
  store.pathProvider = _FixedPathProviderWindows(directory);
}

/// A [PathProviderWindows] that answers with one fixed support directory and
/// otherwise behaves normally.
class _FixedPathProviderWindows extends PathProviderWindows {
  _FixedPathProviderWindows(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// Makes the desktop preferences stores replace their file rather than
/// overwrite it in place.
///
/// Both Dart stores write with a plain `writeAsStringSync` onto the live file
/// (`shared_preferences_windows` 2.4.1 `_writePreferences`, and its Linux
/// twin), so a process that dies mid-write — a force-quit after a wedged CAT
/// shutdown blows its five-second budget, say — leaves a truncated file that
/// their equally plain `json.decode` then throws on for every launch after.
/// Writing a temporary and renaming it over the target closes that window:
/// the rename is a single atomic replace, so the file on disk is always one
/// whole version or the other.
///
/// Reached through the same `fs` seam the plugins expose for their own tests,
/// for the same reason [redirectPreferencesDirectory] uses `pathProvider`:
/// it keeps the plugin's read/write logic intact rather than reimplementing
/// preference storage. Must run before anything awaits
/// `SharedPreferences.getInstance()`.
Future<void> installAtomicPreferenceWrites() async {
  final store = SharedPreferencesStorePlatform.instance;
  switch (store) {
    case SharedPreferencesWindows():
      // ignore: invalid_use_of_visible_for_testing_member
      store.fs = _AtomicWriteFileSystem(store.fs);
    case SharedPreferencesLinux():
      // ignore: invalid_use_of_visible_for_testing_member
      store.fs = _AtomicWriteFileSystem(store.fs);
    default:
      // macOS, iOS and Android hand preferences to a platform store that
      // writes atomically already, so there is nothing here to fix. On the
      // two platforms that DO need it, the same arm means the seam is gone —
      // a plugin upgrade that re-shaped the store, a migration to
      // SharedPreferencesAsync, a store not registered yet — and silence
      // there would leave the truncation window wide open with nothing
      // saying so until the next report months later.
      if (io.Platform.isWindows || io.Platform.isLinux) {
        ErrorReportingService.report(
          StateError('atomic preference writes not installed: store is ${store.runtimeType}'),
          StackTrace.current,
          context: 'app-storage:atomic-writes-unavailable',
        );
      }
      return;
  }
}

/// A file system whose files are replaced rather than overwritten in place.
///
/// Only `writeAsStringSync` is intercepted, which is the sole way either
/// preference store writes its file. The other write paths are untouched, so
/// this is not a general-purpose atomic file system.
class _AtomicWriteFileSystem extends ForwardingFileSystem {
  _AtomicWriteFileSystem(super.delegate);

  @override
  File file(dynamic path) => _AtomicWriteFile(delegate.file(path), this, delegate);
}

class _AtomicWriteFile extends ForwardingFileSystemEntity<File, io.File> with ForwardingFile {
  _AtomicWriteFile(this.delegate, this.fileSystem, this._plain);

  @override
  final io.File delegate;

  @override
  final FileSystem fileSystem;

  /// The unwrapped file system the temporary is created through. Going back
  /// through [fileSystem] would hand us another [_AtomicWriteFile], and the
  /// write below would recurse building `.tmp.tmp` forever.
  final FileSystem _plain;

  @override
  Directory wrapDirectory(io.Directory delegate) => fileSystem.directory(delegate.path);

  @override
  File wrapFile(io.File delegate) => _AtomicWriteFile(delegate, fileSystem, _plain);

  @override
  Link wrapLink(io.Link delegate) => fileSystem.link(delegate.path);

  @override
  void writeAsStringSync(
    String contents, {
    io.FileMode mode = io.FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    // An append has nothing to replace and no half-written state to avoid.
    if (mode != io.FileMode.write) {
      return delegate.writeAsStringSync(contents, mode: mode, encoding: encoding, flush: flush);
    }
    final temp = _plain.file('${delegate.path}.tmp');
    // Flushed unconditionally: a rename that beats its own contents to disk
    // is the same truncated file by another route.
    temp.writeAsStringSync(contents, encoding: encoding, flush: true);
    temp.renameSync(delegate.path);
  }
}
