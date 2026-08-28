package com.ham2k.logger

import android.content.Context
import android.content.Intent
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
    super.cleanUpFlutterEngine(flutterEngine)
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
