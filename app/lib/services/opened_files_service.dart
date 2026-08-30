// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Files the OS handed the app to open — a double-clicked `.h2kext`, a drop on
// the Dock icon, `open thing.h2kext` (HALO-422).
//
// Separate from `DeepLinkService` because it is a different mechanism, not a
// different URL: `app_links` listens for `kAEGetURL` on macOS, which is custom
// URL schemes only. Opening a document is another Apple Event entirely, so
// declaring the type in Info.plist without this produces an app Finder offers
// and that then ignores the file.

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// The channel `AppDelegate.openFileChannel` invokes.
const _channelName = 'ham2k/open_file';

class OpenedFilesService {
  OpenedFilesService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(_channelName) {
    // Web has no such thing, and no channel behind the name either.
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openFiles') return null;
      // One call carrying every path: the platform side batches, because the
      // channel buffer holds a single message until this handler exists and a
      // cold launch is exactly when several can arrive.
      final paths = (call.arguments as Map?)?['paths'];
      if (paths is List) {
        for (final path in paths) {
          if (path is String && path.isNotEmpty) _paths.add(path);
        }
      }
      return null;
    });
  }

  final MethodChannel _channel;

  /// Broadcast, and deliberately NOT replaying: the native side holds anything
  /// that arrived before Flutter was listening and flushes it when the channel
  /// is set, so the queue lives on the side that knows when the engine exists.
  final _paths = StreamController<String>.broadcast();

  /// Paths of files the OS asked this app to open.
  Stream<String> get openedFiles => _paths.stream;

  void dispose() => unawaited(_paths.close());
}
