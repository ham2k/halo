package com.ham2k.logger

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.util.concurrent.Executors

// An image on the clipboard (image_clipboard_io.dart), which Flutter's own
// Clipboard cannot do.
//
// Android's clipboard holds no image bytes, only a content URI the pasting app
// reads. The PNG is written to one file in the cache, replaced by every copy,
// and served by ClipboardImageProvider below; the clipboard grants the app
// that pastes it read access to that URI for as long as it holds the clip.
class ImageClipboardChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/image_clipboard"
  }

  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
  private val worker = Executors.newSingleThreadExecutor()

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "copyImage") {
      result.notImplemented()
      return
    }
    val png = call.argument<ByteArray>("png")
    if (png == null) {
      result.error("bad_args", "Expected png bytes", null)
      return
    }
    worker.execute {
      try {
        ClipboardImageProvider.fileIn(activity).apply { parentFile?.mkdirs() }.writeBytes(png)
        activity.runOnUiThread {
          try {
            val uri = ClipboardImageProvider.uriFor(activity)
            val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newUri(activity.contentResolver, ClipboardImageProvider.DISPLAY_NAME, uri))
            result.success(null)
          } catch (e: Exception) {
            result.error("copy_failed", e.message ?: e.toString(), null)
          }
        }
      } catch (e: Exception) {
        activity.runOnUiThread { result.error("copy_failed", e.message ?: e.toString(), null) }
      }
    }
  }
}

// Serves the one image ImageClipboardChannel last copied, read-only. Ours
// rather than androidx's FileProvider, which the app does not otherwise depend
// on — and a second FileProvider entry beside the one share_plus merges in
// would clash on the class name.
class ClipboardImageProvider : ContentProvider() {
  companion object {
    const val DISPLAY_NAME = "postcard.png"

    fun authority(context: Context) = "${context.packageName}.clipboard_image"

    fun uriFor(context: Context): Uri = Uri.parse("content://${authority(context)}/$DISPLAY_NAME")

    fun fileIn(context: Context) = File(File(context.cacheDir, "clipboard"), DISPLAY_NAME)
  }

  override fun onCreate() = true

  override fun getType(uri: Uri) = "image/png"

  override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
    if (mode != "r") throw SecurityException("read-only")
    val file = fileIn(context ?: throw FileNotFoundException(uri.toString()))
    if (!file.exists()) throw FileNotFoundException(uri.toString())
    return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
  }

  // Name and size, which is all a pasting app asks of an openable document.
  override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
    val file = context?.let { fileIn(it) }
    val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
    return MatrixCursor(columns).apply {
      addRow(columns.map { column ->
        when (column) {
          OpenableColumns.DISPLAY_NAME -> DISPLAY_NAME
          OpenableColumns.SIZE -> file?.length()
          else -> null
        }
      })
    }
  }

  override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException("read-only")

  override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException("read-only")

  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = throw UnsupportedOperationException("read-only")
}
