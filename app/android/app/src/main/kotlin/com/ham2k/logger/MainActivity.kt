package com.ham2k.logger

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.hardware.input.InputManager
import android.view.InputDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  // Physical-keyboard presence for the logging fields' focus rules
  // (docs/design/logging-fields.md): Flutter has no keyboard-presence API, so
  // the Dart side (HardwareKeyboardService) asks here.
  private var hardwareKeyboardChannel: MethodChannel? = null
  private var inputDeviceListener: InputManager.InputDeviceListener? = null

  // The Storage Access Framework save flow the export panel needs
  // (FileSaveChannel): file_selector has no working save on Android.
  private var fileSaveChannel: FileSaveChannel? = null

  // Which interfaces of a USB device are serial ports (UsbInterfacesChannel):
  // the CAT port picker needs it for radios that present more than one.
  private var usbInterfacesChannel: UsbInterfacesChannel? = null

  // The other Ham2K loggers on this device, for the link-across offer
  // (SiblingAppsChannel).
  private var siblingAppsChannel: SiblingAppsChannel? = null

  // An image on the clipboard (ImageClipboardChannel), for the Operation
  // Postcard.
  private var imageClipboardChannel: ImageClipboardChannel? = null

  // Extension bundles opened from Files, a browser download, or a share
  // (HALO-422). The intent carries a content:// URI, which Dart cannot read —
  // only a ContentResolver can — so the bytes are copied into our cache and
  // the copy's path is what crosses the channel.
  private var openFileChannel: MethodChannel? = null

  // Anything that arrived before the engine existed. onCreate runs before
  // configureFlutterEngine, so a cold launch by opening a document always
  // lands here first.
  private val pendingOpenFiles = mutableListOf<String>()

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    hardwareKeyboardChannel =
      MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ham2k/hardware_keyboard")
    hardwareKeyboardChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "isAttached" -> result.success(isHardwareKeyboardAttached())
        else -> result.notImplemented()
      }
    }
    fileSaveChannel = FileSaveChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    usbInterfacesChannel = UsbInterfacesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    siblingAppsChannel = SiblingAppsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    imageClipboardChannel = ImageClipboardChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    openFileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ham2k/open_file")
    flushPendingOpenFiles()
    val inputManager = getSystemService(Context.INPUT_SERVICE) as InputManager
    inputDeviceListener = object : InputManager.InputDeviceListener {
      override fun onInputDeviceAdded(deviceId: Int) = push()
      override fun onInputDeviceRemoved(deviceId: Int) = push()
      override fun onInputDeviceChanged(deviceId: Int) = push()
      private fun push() {
        hardwareKeyboardChannel?.invokeMethod("changed", isHardwareKeyboardAttached())
      }
    }
    inputManager.registerInputDeviceListener(inputDeviceListener, null)
  }

  override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    inputDeviceListener?.let {
      (getSystemService(Context.INPUT_SERVICE) as InputManager).unregisterInputDeviceListener(it)
    }
    inputDeviceListener = null
    hardwareKeyboardChannel = null
    fileSaveChannel?.dispose()
    fileSaveChannel = null
    usbInterfacesChannel?.dispose()
    usbInterfacesChannel = null
    siblingAppsChannel?.dispose()
    siblingAppsChannel = null
    imageClipboardChannel?.dispose()
    imageClipboardChannel = null
    openFileChannel = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    // Only a genuine launch. The ACTION_VIEW intent stays attached across a
    // rotation or a process-death restore, so handling it unconditionally
    // re-copies the file and puts the consent dialog up again every time the
    // activity is recreated.
    if (savedInstanceState == null) handleOpenIntent(intent)
  }

  // The activity is singleTop-ish in practice: opening a second document while
  // the app is up delivers here rather than through onCreate.
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    handleOpenIntent(intent)
  }

  private fun handleOpenIntent(intent: Intent?) {
    if (intent?.action != Intent.ACTION_VIEW) return
    val uri = intent.data ?: return
    val path = copyToCache(uri) ?: return
    pendingOpenFiles.add(path)
    flushPendingOpenFiles()
  }

  /// Copies [uri]'s bytes into the cache, returning the path, or null if it
  /// could not be read.
  ///
  /// A content:// URI is a handle the granting app can revoke, and it is not
  /// a filesystem path at any point — reading it here is the only way its
  /// bytes reach Dart at all.
  private fun copyToCache(uri: Uri): String? {
    // ALWAYS suffixed .h2kext. A Downloads or MediaStore URI's last path
    // segment is a row id ("msf:1234"), not a filename — a copy named after it
    // carries no extension, and the Dart side drops anything that does not end
    // in one. That is the browser-download path, which is the likeliest way a
    // bundle arrives at all.
    val name = queryDisplayName(uri) ?: "extension"
    val stem = if (name.endsWith(".h2kext", ignoreCase = true)) name else "$name.h2kext"
    sweepOldCopies()
    val target = java.io.File(cacheDir, "opened-" + System.currentTimeMillis() + "-" + stem)
    return try {
      contentResolver.openInputStream(uri).use { input ->
        if (input == null) return null
        target.outputStream().use { output -> input.copyTo(output) }
      }
      target.absolutePath
    } catch (e: Exception) {
      // Logged rather than thrown: the operator asked to open a file and the
      // provider would not hand it over, which is a bad day, not a crash.
      android.util.Log.w("ham2k", "could not read opened file: " + e.message)
      null
    }
  }

  /// The provider's own name for [uri], which is the only reliable one.
  private fun queryDisplayName(uri: Uri): String? {
    if (uri.scheme == "file") return uri.lastPathSegment
    return try {
      contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
    } catch (e: Exception) {
      null
    }
  }

  /// Drops copies from previous opens. One file per open, kept forever,
  /// is a cache that only grows — and each one is a whole extension bundle.
  private fun sweepOldCopies() {
    try {
      cacheDir.listFiles { f -> f.name.startsWith("opened-") }?.forEach { it.delete() }
    } catch (e: Exception) {
      // A cache we could not tidy is not a reason to refuse the install.
      android.util.Log.w("ham2k", "could not sweep opened-file cache: " + e.message)
    }
  }

  private fun flushPendingOpenFiles() {
    val channel = openFileChannel ?: return
    val paths = pendingOpenFiles.toList()
    pendingOpenFiles.clear()
    // One message carrying every path — see the note in the macOS delegate:
    // the channel buffer holds a single message until Dart is listening.
    channel.invokeMethod("openFiles", mapOf("paths" to paths))
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    // Ours first: the picker results belong to no plugin, and forwarding them
    // on would have every registered plugin inspect a request code it doesn't
    // own.
    if (fileSaveChannel?.onActivityResult(requestCode, resultCode, data) == true) return
    super.onActivityResult(requestCode, resultCode, data)
  }

  // Alphabetic + non-virtual + keyboard-sourced: phones routinely carry
  // virtual devices and button-only "keyboards" (gpio-keys, volume rockers)
  // that must not count as a typing keyboard.
  private fun isHardwareKeyboardAttached(): Boolean =
    InputDevice.getDeviceIds().any { id ->
      val device = InputDevice.getDevice(id)
      device != null &&
        !device.isVirtual &&
        device.supportsSource(InputDevice.SOURCE_KEYBOARD) &&
        device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC
    }
}
