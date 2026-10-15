package com.ham2k.logger

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// Picking one file to read, on Android — the open half of FileSaveChannel.
//
// `file_selector_android` answers null, which every caller reads as a cancel,
// for a file whose provider reports no OpenableColumns.SIZE (remote files —
// Drive and the like — routinely do not) and for one whose read fails. It also
// reads the whole file into a byte array before Dart sees it, and names its
// copy after the provider's MIME type rather than the file. So picking goes to
// the Storage Access Framework directly: the bytes are STREAMED into the
// cache, under the provider's own display name, and only the copy's path
// crosses the channel.
//
// Three answers, and only three: a path, null for a pick the operator walked
// away from, or an error. Walking away is backing out of the picker, or
// picking again while this pick's copy still runs; nothing else answers null.
// A failure answering null is what this channel exists to prevent: callers
// read it as the operator's choice and do nothing at all.
//
// Always `*/*`. `.adi`, `.h2kext` and a sponsor's export map to no MIME type
// the platform knows, and a picker asked for specific types greys them out;
// each caller checks what it was handed.
class FilePickChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/file_pick"
    const val REQUEST_OPEN_DOCUMENT = 0x4A02
    private const val CACHE_DIR = "picked"

    // Copies older than this are swept by the next pick. Long enough that no
    // caller is still reading one; a copy is read straight after its pick.
    private const val KEEP_COPIES_MS = 60 * 60 * 1000L

    // Under the 255-byte filename limit with room to spare, in UTF-8 bytes.
    private const val MAX_NAME_BYTES = 200

    // A display name is the provider's free text, not a path: a separator in
    // it would put the copy outside its directory, and one past the
    // filesystem's length limit could not be created at all. The extension is
    // kept whole, since that is what the callers read.
    fun safeFileName(displayName: String?): String {
      val name = displayName?.replace('/', '_')?.replace('\u0000', '_')?.trim().orEmpty()
      if (name.isEmpty() || name == "." || name == "..") return "file"
      if (name.toByteArray().size <= MAX_NAME_BYTES) return name
      val dot = name.lastIndexOf('.')
      val ext = if (dot > 0 && name.length - dot <= 16) name.substring(dot) else ""
      var stem = name.substring(0, name.length - ext.length)
      // By code point, so a character outside the BMP is never split in half.
      while (stem.isNotEmpty() && (stem + ext).toByteArray().size > MAX_NAME_BYTES) {
        stem = stem.substring(0, stem.offsetByCodePoints(stem.length, -1))
      }
      return stem + ext
    }
  }

  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }

  // A thread per copy, not one shared worker: a copy whose provider stalls
  // never returns, and on a single worker every later copy would queue behind
  // it forever.
  private val workers = Executors.newCachedThreadPool()

  private var pendingResult: MethodChannel.Result? = null
  private var copying = false

  // Which pick a copy belongs to, so that one abandoned for a newer pick
  // cannot answer the newer pick's caller when it finally finishes.
  private var generation = 0

  fun dispose() {
    channel.setMethodCallHandler(null)
    workers.shutdownNow()
    // An error, not null: the operator did not cancel anything.
    finish(null, "The app closed before the file could be read")
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "pickFile") {
      result.notImplemented()
      return
    }
    if (pendingResult != null) {
      // While the picker is up the app is behind it, so a second request can
      // only come from code, and the request code routing the reply back is
      // single-use.
      if (!copying) {
        result.error("busy", "Another pick is already in progress", null)
        return
      }
      // A copy still running when the operator picks again is one they gave
      // up waiting on, answered as the cancel it is. Reading from a provider
      // cannot be timed out, so without this a stalled stream holds every
      // later pick at "busy" until the app restarts.
      finish(null, null)
    }
    generation++
    pendingResult = result

    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
      .addCategory(Intent.CATEGORY_OPENABLE)
      .setType("*/*")
    try {
      activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
    } catch (e: Exception) {
      finish(null, e.message ?: e.toString())
    }
  }

  /** Returns true when this result was ours to handle. */
  fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != REQUEST_OPEN_DOCUMENT) return false
    // Ours, but nobody is waiting: the engine was torn down while the picker
    // was up. The pick cannot reach anyone, so the log is all that says it
    // happened.
    if (pendingResult == null) {
      android.util.Log.w("ham2k", "file pick answered with nobody waiting for it")
      return true
    }

    if (resultCode != Activity.RESULT_OK) {
      finish(null, null)
      return true
    }
    // OK with no document is the picker failing, not the operator cancelling.
    val uri = data?.data
    if (uri == null) {
      finish(null, "The picker returned no file")
      return true
    }

    val pick = generation
    copying = true
    try {
      workers.execute {
        val outcome = runCatching { copyToCache(uri) }
        activity.runOnUiThread {
          if (pick != generation) return@runOnUiThread
          outcome.fold({ finish(it, null) }, { finish(null, it.message ?: it.toString()) })
        }
      }
    } catch (e: Exception) {
      finish(null, e.message ?: e.toString())
    }
    return true
  }

  // The copy lives in a directory of its own so that its NAME can be the
  // provider's display name, collisions and all.
  private fun copyToCache(uri: Uri): String {
    val root = File(activity.cacheDir, CACHE_DIR)
    sweepOldCopies(root)
    val dir = File(root, System.nanoTime().toString())
    if (!dir.mkdirs()) throw IllegalStateException("Could not create ${dir.path}")
    val target = File(dir, safeFileName(queryDisplayName(activity.contentResolver, uri)))
    val input = activity.contentResolver.openInputStream(uri)
      ?: throw IllegalStateException("The provider returned no stream for this file")
    input.use { source -> target.outputStream().use { source.copyTo(it) } }
    return target.absolutePath
  }

  // A cache kept forever only grows. Only OLD copies go: a recent one may be
  // another import's, still being read.
  private fun sweepOldCopies(root: File) {
    val cutoff = System.currentTimeMillis() - KEEP_COPIES_MS
    try {
      root.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.deleteRecursively() }
    } catch (e: Exception) {
      // A cache we could not tidy is not a reason to refuse the pick.
      android.util.Log.w("ham2k", "could not sweep picked-file cache: " + e.message)
    }
  }

  private fun finish(path: String?, errorMessage: String?) {
    val result = pendingResult ?: return
    pendingResult = null
    copying = false
    if (errorMessage != null) result.error("pick_failed", errorMessage, null)
    else result.success(path)
  }
}
