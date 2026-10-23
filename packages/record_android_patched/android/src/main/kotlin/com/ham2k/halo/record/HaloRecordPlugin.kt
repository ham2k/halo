// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

package com.ham2k.halo.record

import com.llfbandit.record.RecordPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

// Flutter discovers this entry point before build preparation downloads the backend.
class HaloRecordPlugin : FlutterPlugin, ActivityAware {
  private val backend = RecordPlugin()

  override fun onAttachedToEngine(binding: FlutterPluginBinding) {
    backend.onAttachedToEngine(binding)
  }

  override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
    backend.onDetachedFromEngine(binding)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    backend.onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    backend.onDetachedFromActivityForConfigChanges()
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    backend.onReattachedToActivityForConfigChanges(binding)
  }

  override fun onDetachedFromActivity() {
    backend.onDetachedFromActivity()
  }
}
