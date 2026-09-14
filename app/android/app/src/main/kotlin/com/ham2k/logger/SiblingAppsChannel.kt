package com.ham2k.logger

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// Which other Ham2K loggers are installed, and handing one a deep link
// (the Dart side is SiblingAppsService).
//
// Detection is by PACKAGE ID, which is exact: an app either resolves or it
// does not, whatever schemes it claims. Android 11+ hides other packages
// from getPackageInfo unless the manifest's <queries> block names them —
// every id Dart asks about is listed there, and an id that is not would read
// as "not installed" while sitting on the device.
//
// The link goes out as an EXPLICIT intent (setPackage), so the URL can keep
// the public com.ham2k scheme every Ham2K app claims: no chooser, and no
// chance of the running app answering its own link.
class SiblingAppsChannel(private val activity: Activity, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/sibling_apps"
  }

  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "list" -> {
        val ids = call.argument<List<String>>("ids") ?: emptyList()
        result.success(ids.filter { isInstalled(it) })
      }
      "open" -> {
        val id = call.argument<String>("id")
        val url = call.argument<String>("url")
        if (id == null || url == null) {
          result.error("bad-args", "open needs id and url", null)
          return
        }
        result.success(open(id, url))
      }
      else -> result.notImplemented()
    }
  }

  private fun isInstalled(packageId: String): Boolean =
    try {
      activity.packageManager.getPackageInfo(packageId, 0)
      true
    } catch (e: PackageManager.NameNotFoundException) {
      false
    }

  private fun open(packageId: String, url: String): Boolean {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
      setPackage(packageId)
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    return try {
      activity.startActivity(intent)
      true
    } catch (e: ActivityNotFoundException) {
      // Uninstalled since the list was taken, or a build that does not claim
      // the scheme — the operator sees "could not open", not a crash.
      false
    }
  }
}
