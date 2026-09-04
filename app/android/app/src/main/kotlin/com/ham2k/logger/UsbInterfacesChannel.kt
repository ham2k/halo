package com.ham2k.logger

import android.content.Context
import android.hardware.usb.UsbManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The interface descriptors of one USB device, for the CAT serial port picker.
//
// usb_serial's device listing carries only an interface COUNT, and the library
// under it (felHR85/UsbSerial) opens the FIRST CDC data interface unless told
// which one. A composite device with two serial ports — the Xiegu X6100 puts
// CI-V on the second — is unreachable unless the Dart side knows which
// interface indexes are serial at all. Descriptors are readable without the
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
    // Keyed by the same name usb_serial reports as deviceName.
    val device = usbManager.deviceList[deviceName]
    if (device == null) {
      result.error("no_device", "No USB device named $deviceName", null)
      return
    }
    // `index` is the argument usb_serial's create() takes as its interface.
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
