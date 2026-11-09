// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// What kind of file arrived from outside the app — opened from the OS or
// dropped on a window — so the file router can offer the places it can go.
//
// The extensions here are the ones the platforms register the app for
// (ios/macos Info.plist, AndroidManifest.xml, the Windows installer, the
// Linux mime package): a kind the OS hands over that this cannot name is a
// file the app offers to open and then cannot.

import 'package:file_selector/file_selector.dart';

import '../dock_layouts/layout_menu.dart' show layoutFileExtension;
import '../operation/adif_import_flow.dart' show bytesLookLikeAdif, looksLikeAdif, readAdifHead;
import '../../services/key_bindings_file.dart' show keyBindingsFileExtension;
import '../../services/sets/cw_message_set_category.dart' show CwMessageSetCategory;
import '../../services/sets/voice_message_set_category.dart' show VoiceMessageSetCategory;

enum HaloFileKind { extension, keyBindings, layout, cwMessages, voiceMessages, adif, qson }

/// The kind [filename]'s extension names, or null for one no kind owns.
///
/// Plain `.yaml`, `.zip` and `.json` name no kind: a set, a layout and a key
/// set are all YAML, and only the importer that reads one can say which it
/// is. Their own pickers still accept them.
HaloFileKind? fileKindOfName(String filename) {
  final lower = filename.toLowerCase();
  final dot = lower.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (lower.substring(dot + 1)) {
    'h2kext' => HaloFileKind.extension,
    keyBindingsFileExtension => HaloFileKind.keyBindings,
    layoutFileExtension => HaloFileKind.layout,
    CwMessageSetCategory.fileExtension => HaloFileKind.cwMessages,
    VoiceMessageSetCategory.fileExtension => HaloFileKind.voiceMessages,
    'qson' => HaloFileKind.qson,
    _ => looksLikeAdif(lower) ? HaloFileKind.adif : null,
  };
}

/// [file]'s kind: by name, then — for a name that says nothing — by its
/// first bytes, which is how an ADIF file saved as `.txt` or with no
/// extension at all is still recognised.
///
/// Throws when the file cannot be read: "not a kind HaLo reads" would
/// misname a file that is gone, or not the operator's to read.
Future<HaloFileKind?> classifyFile(XFile file) async {
  final byName = fileKindOfName(file.name);
  if (byName != null) return byName;
  return bytesLookLikeAdif(await readAdifHead(file)) ? HaloFileKind.adif : null;
}
