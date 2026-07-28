// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Downloads one generated export through a synthetic anchor click.
///
/// A Blob URL rather than a `data:` URI (which is what share_plus's web
/// fallback uses): a full season's ADIF runs to megabytes, and browsers cap
/// `data:` navigations well below that — the download would simply not
/// happen, with no error to report.
void downloadFile({required String filename, required String content, String? mimeType}) {
  final blob = web.Blob(
    <JSAny>[content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';
  // Firefox only honours a click on an anchor that is in the document.
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Not revoked inline: Chrome cancels a download whose Blob URL is revoked
  // before it has been read, and the read happens after this turn of the
  // event loop.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
