package com.ham2k.logger

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns

/// The provider's own name for [uri], which is the only reliable one: a
/// content:// URI's last path segment is a row or document id ("msf:1234"),
/// not a filename. Null when the provider will not say.
fun queryDisplayName(resolver: ContentResolver, uri: Uri): String? {
  if (uri.scheme == "file") return uri.lastPathSegment
  return try {
    resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
      ?.use { cursor -> if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null }
  } catch (e: Exception) {
    null
  }
}
