package com.ham2k.logger

import android.content.Context
import android.hardware.usb.UsbManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The interface descriptors of one USB device, for the CAT serial port picker.
//
// A stored port names its interface by index, and a composite device with two
// serial ports — the Xiegu X6100 puts CI-V on the second — is reachable only
// if the Dart side knows which interface indexes are serial at all; it turns
// that index into the port number UsbSerialChannel opens. Descriptors are readable without the
// USB permission, so this never puts a dialog up.
class UsbInterfacesChannel(context: Context, messenger: BinaryMessenger) :
  MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL = "ham2k/usb_interfaces"
  }

  private val usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
  private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }

  fun dispose() {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    if (call.method != "list") {
      result.notImplemented()
      return
    }
    val deviceName = call.argument<String>("deviceName")
    if (deviceName.isNullOrEmpty()) {
      result.error("bad_args", "Expected a deviceName", null)
      return
    }
    if (usbManager == null) {
      result.error("no_usb_service", "This device has no USB host service", null)
      return
    }
    // Keyed by the same name UsbSerialChannel reports as deviceName.
    val device = usbManager.deviceList[deviceName]
    if (device == null) {
      result.error("no_device", "No USB device named $deviceName", null)
      return
    }
    // `index` is what a stored port name carries after its '#'.
    result.success(
      (0 until device.interfaceCount).map { i ->
        val iface = device.getInterface(i)
        mapOf(
          "index" to i,
          "interfaceClass" to iface.interfaceClass,
          "interfaceSubclass" to iface.interfaceSubclass,
          "interfaceProtocol" to iface.interfaceProtocol,
        )
      }
    )
  }
}
