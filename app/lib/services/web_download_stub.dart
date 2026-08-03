// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Non-web fallback: every other platform has a filesystem and a save dialog
// or a share sheet, so ExportService never routes here. It throws rather
// than no-opping — reaching it means the platform branch is wrong, and a
// silent no-op would hide exactly that.

void downloadFile({required String filename, required String content, String? mimeType}) {
  throw UnsupportedError('downloadFile is web-only; use saveToDisk or shareFiles instead.');
}
