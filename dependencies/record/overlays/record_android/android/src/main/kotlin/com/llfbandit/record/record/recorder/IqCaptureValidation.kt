package com.llfbandit.record.record.recorder

/** Validate the hardware format independently from AudioRecord's client format. */
internal object IqCaptureValidation {
  fun failure(
    selectedDeviceId: String?,
    routedDeviceId: String?,
    hardwareDeviceId: String?,
    hardwareChannels: Int,
    clientChannels: Int,
    hardwareSampleRate: Int,
    clientSampleRate: Int,
    requestedSampleRate: Int,
    hasProcessing: Boolean,
  ): String? = when {
    selectedDeviceId.isNullOrBlank() || routedDeviceId != selectedDeviceId ||
      hardwareDeviceId != selectedDeviceId -> "iq_audio_device_unavailable"
    hardwareChannels != 2 || clientChannels != 2 || hasProcessing -> "iq_audio_invalid_format"
    requestedSampleRate <= 0 || hardwareSampleRate != requestedSampleRate ||
      clientSampleRate != requestedSampleRate -> "iq_audio_sample_rate_mismatch"
    else -> null
  }
}
