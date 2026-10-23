import Foundation

/// The route, hardware stream and converter input must describe the same
/// pair of measurements. A stereo client format alone can be an upmix.
enum IqCaptureValidation {
  static func failure(
    selectedDeviceId: String?,
    routedDeviceId: String?,
    physicalChannels: Int?,
    sessionChannels: Int,
    sourceChannels: UInt32,
    sessionSampleRate: Double,
    sourceSampleRate: Double,
    requestedSampleRate: Int,
    voiceProcessing: Bool
  ) -> String? {
    guard let selectedDeviceId, !selectedDeviceId.isEmpty,
          routedDeviceId == selectedDeviceId else {
      return "iq_audio_device_unavailable"
    }
    guard physicalChannels == 2, sessionChannels == 2,
          sourceChannels == 2, !voiceProcessing else {
      return "iq_audio_invalid_format"
    }
    guard sessionSampleRate.isFinite, sourceSampleRate.isFinite,
          requestedSampleRate > 0,
          abs(sessionSampleRate - Double(requestedSampleRate)) < 1,
          abs(sourceSampleRate - Double(requestedSampleRate)) < 1 else {
      return "iq_audio_sample_rate_mismatch"
    }
    return nil
  }
}
