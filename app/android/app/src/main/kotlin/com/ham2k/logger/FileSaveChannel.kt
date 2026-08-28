package com.ham2k.logger

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// Saving one export file where the operator chooses, on Android.
//
// `file_selector_android` implements only openFile/openFiles/getDirectoryPath,
// so `getSaveLocation` throws UnimplementedError there, and the raw path its
// directory picker returns is not writable under scoped storage. Saving
// therefore goes to the Storage Access Framework directly.
//
// ONE file per call. Saving several is a Dart-side loop over this
// (`ExportService.saveToDisk`), the shape app-polo's Save has
// (`OperationDataScreen.jsx` loops `saveDocuments`): the operator can leave a
// dialog open for minutes, and a call carrying every file would pin all of
// their content here for the whole sequence — a whole-log backup is tens of
// megabytes. It also leaves the caller holding what was saved before a failure,
// which is what it has to report.
class FileSaveChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/file_save"
    const val REQUEST_CREATE_DOCUMENT = 0x4A01

    // The mime type a document provider must be given for it to leave the
    // filename alone. `FileUtils.splitFileName` keeps the name only when the
    // requested type matches the one the extension maps to, and appends the
    // type's own extension otherwise — an ADIF asked for as `text/plain`
    // lands as `log.adi.txt`, which no uploader accepts. An extension the
    // platform doesn't know maps to `application/octet-stream`, which is then
    // the matching type rather than a fallback.
    fun documentMimeType(filename: String): String {
      val ext = filename.substringAfterLast('.', "")
      if (ext.isEmpty()) return "application/octet-stream"
      return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
        ?: "application/octet-stream"
    }
  }

  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
  private val worker = Executors.newSingleThreadExecutor()

  private var pendingResult: MethodChannel.Result? = null
  private var pendingFilename: String? = null
  private var pendingContent: String? = null

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdown()
    // A dialog outliving the engine would answer into a dead channel.
    finish(null, null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "saveFile") {
      result.notImplemented()
      return
    }
    val filename = call.argument<String>("filename")
    val content = call.argument<String>("content")
    if (filename.isNullOrEmpty() || content == null) {
      result.error("bad_args", "Expected a filename and content", null)
      return
    }
    // One dialog at a time: the request code is the only thing routing the
    // activity result back, so a second request would steal the first's reply.
    if (pendingResult != null) {
      result.error("busy", "Another save is already in progress", null)
      return
    }

    pendingResult = result
    pendingFilename = filename
    pendingContent = content

    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
      .addCategory(Intent.CATEGORY_OPENABLE)
      .setType(documentMimeType(filename))
      .putExtra(Intent.EXTRA_TITLE, filename)
    try {
      activity.startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
    } catch (e: Exception) {
      finish(null, e.message ?: e.toString())
    }
  }

  /** Returns true when this result was ours to handle. */
  fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != REQUEST_CREATE_DOCUMENT) return false
    // Ours, but nobody is waiting: the engine was torn down while the dialog
    // was up, and the worker it would hand the write to is already shut down.
    if (pendingResult == null) return true

    val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
    // A cancelled dialog is the operator's choice, reported as a null answer
    // rather than as a failure the panel would announce.
    if (uri == null) {
      finish(null, null)
      return true
    }

    val filename = pendingFilename ?: ""
    val content = pendingContent ?: ""
    worker.execute {
      try {
        write(uri, content)
        val name = displayNameOf(uri) ?: filename
        activity.runOnUiThread { finish(name, null) }
      } catch (e: Exception) {
        activity.runOnUiThread { finish(null, e.message ?: e.toString()) }
      }
    }
    return true
  }

  private fun write(uri: Uri, content: String) {
    // "wt" truncates: picking an existing file in the dialog otherwise leaves
    // the tail of the longer previous export behind ours. A provider that
    // rejects the mode does so in its own way — FileNotFoundException,
    // UnsupportedOperationException, IllegalArgumentException have all been
    // seen — so anything at all falls back to plain "w".
    val stream = (
      try {
        activity.contentResolver.openOutputStream(uri, "wt")
      } catch (e: Exception) {
        activity.contentResolver.openOutputStream(uri, "w")
      }
      ) ?: throw IllegalStateException("Could not open $uri for writing")
    stream.use { it.write(content.toByteArray(Charsets.UTF_8)) }
  }

  private fun displayNameOf(uri: Uri): String? =
    try {
      activity.contentResolver.query(
        uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
      )?.use { cursor -> if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null }
    } catch (e: Exception) {
      null
    }

  private fun finish(name: String?, errorMessage: String?) {
    val result = pendingResult ?: return
    pendingResult = null
    pendingFilename = null
    pendingContent = null
    if (errorMessage != null) result.error("save_failed", errorMessage, null)
    else result.success(name)
  }
}
