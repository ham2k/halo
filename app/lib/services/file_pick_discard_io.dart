// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Removes the copy a mobile picker made of the file at [path]:
///
/// - Android: the directory the picker channel copied it into,
///   `<cache>/picked/<stamp>/<name>` (FilePickChannel.kt).
/// - iOS: the file itself, `<container>/tmp/<bundle>-Inbox/<name>`, where the
///   document picker's import mode copies it. `<cache>` there is
///   `<container>/Library/Caches`; the Inbox is shared, so only the file goes.
///
/// `<cache>` is the app's temporary directory, or [cacheDir] when given.
///
/// Only a path in exactly one of those places is touched. Anywhere else
/// [path] is the operator's own file, or no file at all: an in-memory pick
/// has an empty or relative path, and the directory "holding" it is wherever
/// the app runs, which a recursive delete would empty.
///
/// Best-effort: on Android a copy that stays is swept by the channel on a
/// later pick, and on iOS by the system.
Future<void> discardPickedCopy(String path, {String? cacheDir}) async {
  if (path.isEmpty || !p.isAbsolute(path)) return;
  final String cache;
  try {
    cache = cacheDir ?? (await getTemporaryDirectory()).path;
  } catch (e) {
    debugPrint('[file-pick] no cache directory to remove the picked copy of $path from: $e');
    return;
  }
  final dir = p.dirname(path);
  final FileSystemEntity copy;
  if (p.equals(p.dirname(dir), p.join(cache, 'picked'))) {
    copy = Directory(dir);
  } else if (p.basename(dir).endsWith('-Inbox') && p.equals(p.dirname(dir), p.join(p.dirname(p.dirname(cache)), 'tmp'))) {
    copy = File(path);
  } else {
    // Every mobile pick lands in one of those, so this is the picker and this
    // side disagreeing on where — and every copy staying, unremarked.
    debugPrint('[file-pick] $path is not a picked copy under $cache; left in place');
    return;
  }
  try {
    await copy.delete(recursive: copy is Directory);
  } catch (e) {
    debugPrint('[file-pick] could not remove the picked copy at $path: $e');
  }
}
