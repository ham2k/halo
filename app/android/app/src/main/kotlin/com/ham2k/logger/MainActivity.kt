package com.ham2k.logger

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.hardware.input.InputManager
import android.view.InputDevice
import android.view.View
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// The extensions the manifest's VIEW filters claim — the same list
/// views/file_open/file_kind.dart reads a kind from.
private val openedExtensions = listOf("h2kext", "h2kkey", "h2klyt", "h2kset", "h2kvoice", "qson", "adi", "adif")

class MainActivity : FlutterActivity() {
  // Physical-keyboard presence for the logging fields' focus rules
  // (docs/design/logging-fields.md): Flutter has no keyboard-presence API, so
  // the Dart side (HardwareKeyboardService) asks here.
  private var hardwareKeyboardChannel: MethodChannel? = null
  private var inputDeviceListener: InputManager.InputDeviceListener? = null

  // The Storage Access Framework save flow the export panel needs
  // (FileSaveChannel): file_selector has no working save on Android.
  private var fileSaveChannel: FileSaveChannel? = null

  // Its open half (FilePickChannel): file_selector's Android pick drops a file
  // whose provider reports no size, as if the operator had cancelled.
  private var filePickChannel: FilePickChannel? = null

  // Which interfaces of a USB device are serial ports (UsbInterfacesChannel):
  // the CAT port picker needs it for radios that present more than one.
  private var usbInterfacesChannel: UsbInterfacesChannel? = null

  // USB-serial CAT ports themselves (UsbSerialChannel).
  private var usbSerialChannel: UsbSerialChannel? = null

  // The other Ham2K loggers on this device, for the link-across offer
  // (SiblingAppsChannel).
  private var siblingAppsChannel: SiblingAppsChannel? = null

  // An image on the clipboard (ImageClipboardChannel), for the Operation
  // Postcard.
  private var imageClipboardChannel: ImageClipboardChannel? = null

  // The postcard's Save to Gallery (PhotosChannel).
  private var photosChannel: PhotosChannel? = null

  // Extension bundles opened from Files, a browser download, or a share
  // (HALO-422). The intent carries a content:// URI, which Dart cannot read —
  // only a ContentResolver can — so the bytes are copied into our cache and
  // the copy's path is what crosses the channel.
  private var openFileChannel: MethodChannel? = null

  // Who sent each recent com.ham2k link, for the question a /vfo, /qso or
  // /operation link asks before it acts (views/deep_link_approval.dart).
  // app_links hands Dart the URI alone, so Dart asks here for the recent
  // ones and finds its link among them: Dart rewrites a URI as it parses it
  // (%2f as %2F, a space as %20), so the raw string is no key to look up.
  private var linkSenderChannel: MethodChannel? = null
  private val linkSenders = LinkedHashMap<String, Map<String, String>>()

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
    filePickChannel = FilePickChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    usbInterfacesChannel = UsbInterfacesChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    usbSerialChannel = UsbSerialChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    siblingAppsChannel = SiblingAppsChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    imageClipboardChannel = ImageClipboardChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    photosChannel = PhotosChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    openFileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ham2k/open_file")
    flushPendingOpenFiles()
    linkSenderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ham2k/link_sender")
    linkSenderChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "recentSenders" -> result.success(linkSenders.map { (uri, sender) -> sender + ("uri" to uri) })
        else -> result.notImplemented()
      }
    }
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
    filePickChannel?.dispose()
    filePickChannel = null
    usbInterfacesChannel?.dispose()
    usbInterfacesChannel = null
    usbSerialChannel?.dispose()
    usbSerialChannel = null
    siblingAppsChannel?.dispose()
    siblingAppsChannel = null
    imageClipboardChannel?.dispose()
    imageClipboardChannel = null
    photosChannel?.dispose()
    photosChannel = null
    openFileChannel = null
    linkSenderChannel?.setMethodCallHandler(null)
    linkSenderChannel = null
    super.cleanUpFlutterEngine(flutterEngine)
  }

  override fun onCreate(savedInstanceState: android.os.Bundle?) {
    super.onCreate(savedInstanceState)
    // Only a genuine launch. The ACTION_VIEW intent stays attached across a
    // rotation or a process-death restore, so handling it unconditionally
    // re-copies the file and puts the consent dialog up again every time the
    // activity is recreated.
    if (savedInstanceState == null) {
      recordLinkSender(intent)
      // At launch and never per open: a file opened while the app runs waits
      // its turn in Dart, and a sweep then would delete it before it is read.
      sweepOldCopies()
      handleOpenIntent(intent)
    }
  }

  // The activity is singleTop-ish in practice: opening a second document while
  // the app is up delivers here rather than through onCreate.
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    recordLinkSender(intent)
    handleOpenIntent(intent)
  }

  /// Notes who sent a com.ham2k link, by the URI Dart will ask about. Done
  /// on the main thread before the link's own delivery to Dart has been
  /// handled, so the answer is here by the time Dart asks.
  ///
  /// The sender is the calling app's package as Android recorded it, never
  /// what the intent says: getReferrer() prefers an EXTRA_REFERRER or
  /// EXTRA_REFERRER_NAME the sender put in, so any app could name one the
  /// operator allowed. It reads them from getIntent(), which is pointed for
  /// the call at a copy without them; Android keeps the calling package for
  /// the intent being delivered, onNewIntent's included.
  private fun recordLinkSender(intent: Intent?) {
    if (intent?.action != Intent.ACTION_VIEW) return
    val uri = intent.dataString ?: return
    if (intent.data?.scheme?.startsWith("com.ham2k") != true) return
    // Forgotten first: the same link sent again by someone unnamed is not
    // the earlier sender's.
    linkSenders.remove(uri)
    val delivered = getIntent()
    setIntent(Intent(intent).apply {
      removeExtra(Intent.EXTRA_REFERRER)
      removeExtra(Intent.EXTRA_REFERRER_NAME)
    })
    val caller = try {
      referrer?.takeIf { it.scheme == "android-app" }?.authority
    } finally {
      setIntent(delivered)
    }
    if (caller.isNullOrEmpty()) return
    val id = "android-app://$caller"
    val label = appLabel(caller) ?: caller
    linkSenders[uri] = mapOf("id" to id, "label" to label)
    while (linkSenders.size > 16) linkSenders.remove(linkSenders.keys.first())
  }

  /// The app's own name for [packageName], or null when package visibility
  /// hides it from this app.
  private fun appLabel(packageName: String): String? = try {
    packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
  } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
    null
  }

  private fun handleOpenIntent(intent: Intent?) {
    if (intent?.action != Intent.ACTION_VIEW) return
    val uri = intent.data ?: return
    if (!isOpenableDocument(uri)) return
    val path = copyToCache(uri, intent.type) ?: return
    pendingOpenFiles.add(path)
    flushPendingOpenFiles()
  }

  /// Whether [uri] names a document another app is handing over: a content://
  /// URI, or a file:// path outside this app's own data. Any installed app can
  /// send this activity a VIEW intent, and a file:// path into our private
  /// storage would have the app read its own database or settings as if the
  /// operator had opened them. Older file managers still send file:// for a
  /// file in shared storage, which is why that scheme is kept at all.
  ///
  /// A content:// URI from one of this app's own providers is refused too:
  /// the app reads those without a grant, so they would serve whatever they
  /// expose as an opened file.
  private fun isOpenableDocument(uri: Uri): Boolean = when (uri.scheme) {
    "content" -> {
      val owner = uri.authority?.let { packageManager.resolveContentProvider(it, 0)?.packageName }
      (owner != packageName).also { if (!it) android.util.Log.w("ham2k", "refused opened file from this app's own provider: $uri") }
    }
    "file" -> {
      val path = uri.path
      val outside = path != null && try {
        val target = java.io.File(path).canonicalPath
        listOf(applicationInfo.dataDir, applicationInfo.deviceProtectedDataDir).none { root ->
          val own = java.io.File(root).canonicalPath
          target == own || target.startsWith(own + java.io.File.separator)
        }
      } catch (e: java.io.IOException) {
        false
      }
      outside.also { if (!it) android.util.Log.w("ham2k", "refused opened file inside this app's data or unreadable: $uri") }
    }
    else -> false
  }

  /// Copies [uri]'s bytes into the cache, returning the path, or null if it
  /// could not be read.
  ///
  /// A content:// URI is a handle the granting app can revoke, and it is not
  /// a filesystem path at any point — reading it here is the only way its
  /// bytes reach Dart at all.
  private fun copyToCache(uri: Uri, type: String?): String? {
    // Named after the file, because the name is what the Dart side reads the
    // kind from (views/file_open/file_kind.dart). A Downloads or MediaStore
    // URI's last path segment is a row id ("msf:1234"), not a filename, so
    // the provider's display name comes first; a name that still carries no
    // extension the app reads takes one from the extension's MIME type, or
    // from the path the intent filter matched. Anything else keeps its name,
    // and the Dart side looks at its bytes.
    val name = queryDisplayName(contentResolver, uri) ?: uri.lastPathSegment ?: "opened"
    val path = uri.path ?: ""
    val suffix = when {
      openedExtensions.any { name.endsWith(".$it", ignoreCase = true) } -> ""
      type == "application/vnd.ham2k.extension" -> ".h2kext"
      else -> openedExtensions.firstOrNull { path.endsWith(".$it", ignoreCase = true) }?.let { ".$it" } ?: ""
    }
    val stem = name + suffix
    // A folder of its own, so the copy keeps the file's own name: the Dart
    // side shows it to the operator.
    val folder = java.io.File(cacheDir, "opened-" + System.currentTimeMillis())
    val target = java.io.File(folder, stem.replace('/', '_'))
    return try {
      folder.mkdirs()
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

  /// Drops copies from previous opens. One file per open, kept forever,
  /// is a cache that only grows.
  private fun sweepOldCopies() {
    try {
      cacheDir.listFiles { f -> f.name.startsWith("opened-") }?.forEach { it.deleteRecursively() }
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

  // The engine's IME-inset deferral (ImeSyncDeferringInsetsCallback) holds
  // every inset that arrives while a keyboard animation runs and, when the
  // animation ends, re-applies the one it saved as that animation began. On
  // Samsung's One UI 9 the keyboard comes back for an instant when the app
  // regains focus and goes away again; a hide that lands inside that show
  // animation has its insets swallowed, the saved "shown" ones win, and
  // Flutter keeps a keyboard-tall inset with no keyboard — a blank band the
  // status bar overlay holds open. So once the keyboard has had time to settle
  // after a refocus, insets that say it is gone go to the FlutterView
  // directly, past the deferral — the path the engine's own onProgress takes.
  // Where the inset is already right this re-sends identical metrics.
  //
  // Android 15 and later only: the root insets equal the ones the FlutterView
  // is dispatched only under enforced edge-to-edge. This app does not opt into
  // edge-to-edge, so on 11–14 the DecorView consumes the navigation bar before
  // the FlutterView sees the insets, and sending the root insets there would
  // add a navigation-bar-tall gap of its own.
  private val imeInsetsResync = Runnable { resyncHiddenImeInsets() }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
    val view = findViewById<View>(FlutterActivity.FLUTTER_VIEW_ID) ?: return
    view.removeCallbacks(imeInsetsResync)
    if (hasFocus) view.postDelayed(imeInsetsResync, IME_SETTLE_MILLIS)
  }

  private fun resyncHiddenImeInsets() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) return
    val found = findViewById<View>(FlutterActivity.FLUTTER_VIEW_ID) ?: return
    // A plain View under that id would take the insets and never pass them to
    // Flutter, so the workaround would stop working with nothing to show it.
    val view = found as? FlutterView ?: run {
      android.util.Log.w("ham2k", "IME inset resync: view is not a FlutterView")
      return
    }
    val insets = view.rootWindowInsets ?: return
    if (insets.isVisible(WindowInsets.Type.ime())) return
    view.onApplyWindowInsets(insets)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    // Ours first: the picker results belong to no plugin, and forwarding them
    // on would have every registered plugin inspect a request code it doesn't
    // own.
    if (fileSaveChannel?.onActivityResult(requestCode, resultCode, data) == true) return
    if (filePickChannel?.onActivityResult(requestCode, resultCode, data) == true) return
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

  private companion object {
    // Longer than a keyboard show plus hide, so the resync lands after the
    // deferral has re-applied its stale insets rather than before.
    const val IME_SETTLE_MILLIS = 1000L
  }
}
