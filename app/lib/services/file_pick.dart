// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Picking one file to read — the one way in for every picker in the app.
//
// Android goes to the Storage Access Framework directly (`FilePickChannel.kt`)
// rather than through `file_selector`, which every other platform still uses:
// `file_selector_android` answers a file whose provider reports no size —
// Drive and other remote files, routinely — with null, exactly as it answers a
// cancel, so the operator's pick silently does nothing.

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

const _androidChannel = MethodChannel('ham2k/file_pick');

/// A pick that failed, in the words the platform gave for it — what callers
/// show the operator, so never the channel's envelope around them.
class FilePickException implements Exception {
  const FilePickException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The file the operator picks, or null when they cancel. A pick that fails
/// THROWS — never null, which every caller reads as the operator's choice.
///
/// On Android the picker offers every file, whatever [acceptedTypeGroups]
/// asks for: the extensions this app reads map to no MIME type the platform
/// knows, and it greys out what it cannot match. The caller checks what it
/// was handed. The file is a copy in the app's cache, named as the provider
/// names it.
Future<XFile?> pickFile({List<XTypeGroup> acceptedTypeGroups = const []}) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final String? path;
    try {
      path = await _androidChannel.invokeMethod<String>('pickFile');
    } on PlatformException catch (e, stack) {
      Error.throwWithStackTrace(FilePickException(e.message ?? e.code), stack);
    }
    return path == null ? null : XFile(path);
  }
  return openFile(acceptedTypeGroups: acceptedTypeGroups);
}
