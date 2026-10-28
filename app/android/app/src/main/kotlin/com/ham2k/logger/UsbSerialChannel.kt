package com.ham2k.logger

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.hoho.android.usbserial.driver.CdcAcmSerialDriver
import com.hoho.android.usbserial.driver.Ch34xSerialDriver
import com.hoho.android.usbserial.driver.Cp21xxSerialDriver
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.ProlificSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

// USB-serial CAT ports, over usb-serial-for-android (docs/design/cat.md,
// "Android"). The chip protocols live in that library; this is only the
// permission flow, the open sequence, and a byte pipe to Dart.
//
// Error codes are SerialFailure's names on the Dart side, plus "unsupported"
// for a device no driver claims — the one an operator fixes by picking a
// USB chip driver rather than by checking a cable.
class UsbSerialChannel(private val context: Context, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

  companion object {
    const val CHANNEL = "ham2k/usb_serial"
    const val EVENTS = "ham2k/usb_serial/events"
    private const val ACTION_PERMISSION = "com.ham2k.logger.USB_PERMISSION"
  }

  private class OpenPort(val deviceName: String, val portNumber: Int, val port: UsbSerialPort, val io: SerialInputOutputManager)

  private val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
  private val events = EventChannel(messenger, EVENTS).also { it.setStreamHandler(this) }
  private val main = Handler(Looper.getMainLooper())

  // One thread for every open and close: both are runs of blocking control
  // transfers, and serialising them means a reconnect's open never interleaves
  // with the teardown of the port it replaces.
  private val worker = Executors.newSingleThreadExecutor()
  private val ports = ConcurrentHashMap<Int, OpenPort>()
  private val nextHandle = AtomicInteger(1)
  private var sink: EventChannel.EventSink? = null

  // Read by an open still on the worker when the engine goes: that port is
  // closed rather than registered, or it stays claimed for the life of the
  // process and the next engine's open reports it busy.
  @Volatile private var disposed = false

  fun dispose() {
    disposed = true
    channel.setMethodCallHandler(null)
    events.setStreamHandler(null)
    for (handle in ports.keys.toList()) closePort(handle)
    worker.shutdown()
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    val manager = usbManager
    if (manager == null) {
      result.error("missing", "This device has no USB host service", null)
      return
    }
    when (call.method) {
      "list" -> result.success(manager.deviceList.values.map { describe(it) })
      "open" -> open(manager, call, result)
      "write" -> write(call, result)
      "close" -> {
        val handle = call.argument<Int>("handle") ?: return result.error("bad_args", "Expected a handle", null)
        worker.execute {
          closePort(handle)
          main.post { result.success(null) }
        }
      }
      else -> result.notImplemented()
    }
  }

  private fun describe(device: UsbDevice): Map<String, Any?> = mapOf(
    "deviceName" to device.deviceName,
    "vendorId" to device.vendorId,
    "productId" to device.productId,
    "manufacturer" to device.manufacturerName,
    "product" to device.productName,
    // Unreadable without the USB permission from Android 10 on.
    "serial" to try { device.serialNumber } catch (e: SecurityException) { null },
    "driver" to driverKey(UsbSerialProber.getDefaultProber().probeDevice(device)),
  )

  // The operator's USB chip driver setting, or the library's own match by
  // USB ids and, failing that, by a CDC-ACM interface pair.
  private fun driverFor(device: UsbDevice, override: String?): UsbSerialDriver? = when (override) {
    "cdc" -> CdcAcmSerialDriver(device)
    "ftdi" -> FtdiSerialDriver(device)
    "cp210x" -> Cp21xxSerialDriver(device)
    "ch34x" -> Ch34xSerialDriver(device)
    "pl2303" -> ProlificSerialDriver(device)
    else -> UsbSerialProber.getDefaultProber().probeDevice(device)
  }

  private fun driverKey(driver: UsbSerialDriver?): String? = when (driver) {
    null -> null
    is CdcAcmSerialDriver -> "cdc"
    is FtdiSerialDriver -> "ftdi"
    is Cp21xxSerialDriver -> "cp210x"
    is Ch34xSerialDriver -> "ch34x"
    is ProlificSerialDriver -> "pl2303"
    else -> "other"
  }

  private fun open(manager: UsbManager, call: MethodCall, result: MethodChannel.Result) {
    val deviceName = call.argument<String>("deviceName")
    val device = deviceName?.let { manager.deviceList[it] }
    if (device == null) {
      result.error("missing", "No USB device named $deviceName", null)
      return
    }
    // Before the permission request: descriptors are readable without it, and
    // a device nothing can drive must not put a dialog up on every retry.
    val driver = driverFor(device, call.argument<String>("driver"))
    if (driver == null) {
      result.error("unsupported", "No serial driver for USB device %04x:%04x".format(device.vendorId, device.productId), null)
      return
    }
    val port = driver.ports.getOrNull(call.argument<Int>("port") ?: 0)
    if (port == null) {
      result.error("missing", "This device has no serial port ${call.argument<Int>("port")}", null)
      return
    }
    val proceed = {
      worker.execute {
        try {
          openOnWorker(manager, device, driver, port, call, result)
        } catch (e: Throwable) {
          // Escaping an executor task kills the process, and leaves Dart's
          // open unanswered besides.
          closeQuietly(port)
          main.post { result.error("other", e.message ?: "$e", null) }
        }
      }
    }
    if (manager.hasPermission(device)) {
      proceed()
    } else {
      requestPermission(manager, device) { granted ->
        if (granted) proceed() else result.error("denied", "USB permission was not granted", null)
      }
    }
  }

  private fun openOnWorker(
    manager: UsbManager,
    device: UsbDevice,
    driver: UsbSerialDriver,
    port: UsbSerialPort,
    call: MethodCall,
    result: MethodChannel.Result,
  ) {
    val reply = { code: String?, value: Any?, message: String? ->
      main.post { if (code == null) result.success(value) else result.error(code, message, null) }
    }
    // One owner per port. An open Dart has already given up on is closed only
    // once its handle reaches Dart, which is after any open queued behind it
    // here: left to that, the newer open finds the interface claimed, or has
    // the bridge's UART disabled under it by the late close.
    for ((handle, open) in ports) {
      if (open.deviceName == device.deviceName && open.portNumber == port.portNumber) {
        closePort(handle)
        main.post { sink?.success(mapOf("handle" to handle, "error" to "replaced by a newer open of the same port")) }
      }
    }
    val connection = manager.openDevice(device)
    if (connection == null) {
      reply("denied", null, "Android would not open the USB device")
      return
    }
    try {
      port.open(connection)
    } catch (e: Exception) {
      // Only a refused claim means another app holds the port. The rest are
      // the chip refusing its setup, which is what a wrong USB chip driver
      // looks like, and "in use" would send the operator after other apps.
      val claim = e is IOException && e.message?.contains("claim", ignoreCase = true) == true
      reply(if (claim) "busy" else "other", null, e.message ?: "$e")
      return
    }
    try {
      try {
        port.setParameters(
          call.argument<Int>("baudRate") ?: 4800,
          UsbSerialPort.DATABITS_8,
          if (call.argument<Int>("stopBits") == 2) UsbSerialPort.STOPBITS_2 else UsbSerialPort.STOPBITS_1,
          UsbSerialPort.PARITY_NONE,
        )
      } catch (e: IOException) {
        // A radio's own CDC port is a virtual UART with no baud rate, and
        // some refuse the request outright. Failing them here would refuse a
        // port that works; a real UART behind CDC accepts it.
        if (driver !is CdcAcmSerialDriver) throw e
        android.util.Log.w("ham2k", "CDC device refused line coding: ${e.message}")
      }
      // Null leaves a line alone: a link with no control-line wire behind it.
      // Every bridge driver writes both lines low as it opens, and a CDC open
      // leaves them where the device put them, so a line asked low that the
      // device refuses has not been raised by anything here.
      setLine("DTR", call.argument<Boolean>("dtr")) { port.setDTR(it) }
      setLine("RTS", call.argument<Boolean>("rts")) { port.setRTS(it) }
    } catch (e: LineRefused) {
      closeQuietly(port)
      reply("lines", null, e.message)
      return
    } catch (e: Exception) {
      closeQuietly(port)
      reply("other", null, e.message)
      return
    }

    val handle = nextHandle.getAndIncrement()
    val io = SerialInputOutputManager(port, object : SerialInputOutputManager.Listener {
      override fun onNewData(data: ByteArray) {
        main.post { sink?.success(mapOf("handle" to handle, "data" to data)) }
      }

      // An unplugged adapter surfaces here, as a failed read.
      override fun onRunError(e: Exception) {
        worker.execute { closePort(handle) }
        main.post { sink?.success(mapOf("handle" to handle, "error" to (e.message ?: "$e"))) }
      }
    })
    if (disposed) {
      closeQuietly(port)
      return
    }
    ports[handle] = OpenPort(device.deviceName, port.portNumber, port, io)
    // The handle first: reads post to the main thread behind it, so Dart is
    // listening for this handle before its first bytes arrive. A Yaesu with
    // CAT RTS on answers only at the open, and that burst is its one reply.
    reply(null, handle, null)
    io.start()
  }

  private class LineRefused(message: String) : IOException(message)

  private fun setLine(name: String, high: Boolean?, set: (Boolean) -> Unit) {
    if (high == null) return
    try {
      set(high)
    } catch (e: IOException) {
      if (high) throw LineRefused("$name could not be raised: ${e.message}")
      android.util.Log.w("ham2k", "$name low refused: ${e.message}")
    }
  }

  private fun write(call: MethodCall, result: MethodChannel.Result) {
    val open = call.argument<Int>("handle")?.let { ports[it] }
    val bytes = call.argument<ByteArray>("bytes")
    if (open == null || bytes == null) {
      result.error("missing", "Port is not open", null)
      return
    }
    try {
      open.io.writeAsync(bytes)
      result.success(null)
    } catch (e: Exception) {
      // The write buffer is full: the port has stopped draining.
      result.error("other", e.message ?: "$e", null)
    }
  }

  private fun closePort(handle: Int) {
    val open = ports.remove(handle) ?: return
    open.io.stop()
    // Also unblocks the read thread, which stop() alone leaves waiting.
    closeQuietly(open.port)
  }

  private fun closeQuietly(port: UsbSerialPort) {
    try {
      port.close()
    } catch (e: IOException) {
      // Already closed, or gone with the device.
    }
  }

  private fun requestPermission(manager: UsbManager, device: UsbDevice, done: (Boolean) -> Unit) {
    val receiver = object : BroadcastReceiver() {
      override fun onReceive(ctx: Context, intent: Intent) {
        // The typed getter from 34 only: on 33 it can return null for an
        // extra that is there (AndroidX IntentCompat makes the same cut).
        val answered = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
          intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
          @Suppress("DEPRECATION") intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }
        // Each request has its own receiver; another device's answer is not ours.
        if (answered?.deviceName != device.deviceName) {
          android.util.Log.d("ham2k", "USB permission answer for ${answered?.deviceName} is not for ${device.deviceName}")
          return
        }
        context.unregisterReceiver(this)
        done(intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
      }
    }
    val filter = IntentFilter(ACTION_PERMISSION)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      context.registerReceiver(receiver, filter)
    }
    // Mutable because the system adds the device and the answer as extras;
    // explicit (setPackage) because Android 14 refuses a mutable implicit one.
    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
    val intent = Intent(ACTION_PERMISSION).setPackage(context.packageName)
    manager.requestPermission(device, PendingIntent.getBroadcast(context, device.deviceId, intent, flags))
  }
}
