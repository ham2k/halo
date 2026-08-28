// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Android's half of the export save flow (`FileSaveChannel.kt`).
//
// `file_selector_android` implements only openFile/openFiles/getDirectoryPath:
// `getSaveLocation` throws `UnimplementedError` there, and the raw path its
// directory picker hands back is not writable under scoped storage. So saving
// on Android goes to the Storage Access Framework directly rather than through
// `file_selector`, which every other platform still uses.

import 'package:flutter/services.dart';

class AndroidFileSave {
  const AndroidFileSave();

  static const _channel = MethodChannel('ham2k/file_save');

  /// Saves ONE file through the system's "create document" dialog, where the
  /// operator picks its name and folder. Saving several is a loop over this in
  /// [ExportService.saveToDisk], the shape app-polo's Save has.
  ///
  /// Returns the name it was saved under — the platform's to choose, not ours,
  /// since it renames around a collision — or null if the operator cancelled.
  Future<String?> saveFile({required String filename, required String content}) =>
      _channel.invokeMethod<String>('saveFile', {'filename': filename, 'content': content});
}
