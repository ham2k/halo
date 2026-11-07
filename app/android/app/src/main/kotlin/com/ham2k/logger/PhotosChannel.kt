package com.ham2k.logger

import android.app.Activity
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// The postcard's Save to Gallery (operation_postcard.dart): an image into the
// shared Pictures collection, where every gallery app finds it. The same
// channel and answers as iOS's Photos half in AppDelegate.swift.
//
// Android 10 and later only: there MediaStore takes an app's own images with
// no permission at all. Earlier it needs WRITE_EXTERNAL_STORAGE and a prompt,
// which this app does not ask for — the postcard offers Save to Files alone
// there, and a call anyway answers `unsupported`.
class PhotosChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/photos"

    // A folder of its own under Pictures, which gallery apps show as an album.
    val FOLDER = "${Environment.DIRECTORY_PICTURES}/Ham2K"
  }

  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
  private val worker = Executors.newSingleThreadExecutor()

  fun dispose() {
    channel.setMethodCallHandler(null)
    worker.shutdown()
  }

  // Answers null once the image is in, or why not: `unsupported` (before
  // Android 10), `full`, or `failed` with the platform's own words.
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "addImage") {
      result.notImplemented()
      return
    }
    val png = call.argument<ByteArray>("png")
    if (png == null) {
      result.error("bad_args", "Expected png bytes", null)
      return
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      result.error("unsupported", "Saving to the gallery needs Android 10", null)
      return
    }
    val name = call.argument<String>("name") ?: "postcard.png"
    worker.execute {
      // Throwable, not Exception: an Error left to this thread's handler
      // would kill the app with the call unanswered.
      val error = try {
        add(png, name)
        null
      } catch (e: Throwable) {
        val said = e.message ?: e.toString()
        val full = generateSequence<Throwable>(e) { it.cause }.any { "ENOSPC" in (it.message ?: "") }
        Pair(if (full) "full" else "failed", said)
      }
      activity.runOnUiThread {
        if (error == null) result.success(null) else result.error(error.first, error.second, null)
      }
    }
  }

  // Pending while written, so no gallery shows a half-written image; removed
  // again if the write fails, so none shows an empty one.
  private fun add(png: ByteArray, name: String) {
    val resolver = activity.contentResolver
    val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    val uri = resolver.insert(
      collection,
      ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, name)
        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
        put(MediaStore.Images.Media.RELATIVE_PATH, FOLDER)
        put(MediaStore.Images.Media.IS_PENDING, 1)
      },
    ) ?: throw IllegalStateException("The gallery did not take the image")
    try {
      (resolver.openOutputStream(uri) ?: throw IllegalStateException("Could not open $uri for writing")).use { it.write(png) }
      val published = resolver.update(uri, ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }, null, null)
      if (published != 1) throw IllegalStateException("The gallery did not publish $uri")
    } catch (e: Exception) {
      // The write's failure is the one to answer with, not the cleanup's.
      try {
        resolver.delete(uri, null, null)
      } catch (cleanup: Exception) {
        e.addSuppressed(cleanup)
      }
      throw e
    }
  }
}
