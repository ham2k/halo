import Foundation

// Standalone host test: compile with IqCaptureValidation.swift. The rule
// exercised here is the one the device and stream startup both consult.
@main
enum IqCaptureValidationTest {
  static func failure(
    selected: String? = "usb-input",
    routed: String? = "usb-input",
    physicalChannels: Int? = 2,
    sessionChannels: Int = 2,
    sourceChannels: UInt32 = 2,
    sessionRate: Double = 48000,
    sourceRate: Double = 48000,
    requestedRate: Int = 48000,
    processing: Bool = false
  ) -> String? {
    IqCaptureValidation.failure(
      selectedDeviceId: selected, routedDeviceId: routed,
      physicalChannels: physicalChannels, sessionChannels: sessionChannels,
      sourceChannels: sourceChannels, sessionSampleRate: sessionRate,
      sourceSampleRate: sourceRate, requestedSampleRate: requestedRate,
      voiceProcessing: processing
    )
  }

  static func main() {
    for rate in [48000, 96000, 192000] {
      precondition(failure(sessionRate: Double(rate), sourceRate: Double(rate), requestedRate: rate) == nil)
    }
    // Upmixed mono and downmixed multichannel input still look stereo to
    // an output converter, but cannot represent the requested physical pair.
    for channels in [nil, 0, 1, 6] as [Int?] {
      precondition(failure(physicalChannels: channels) == "iq_audio_invalid_format")
    }
    precondition(failure(sessionChannels: 1) == "iq_audio_invalid_format")
    precondition(failure(sourceChannels: 1) == "iq_audio_invalid_format")
    precondition(failure(processing: true) == "iq_audio_invalid_format")
    precondition(failure(sessionRate: 48000, sourceRate: 96000, requestedRate: 96000) == "iq_audio_sample_rate_mismatch")
    precondition(failure(sourceRate: 44100) == "iq_audio_sample_rate_mismatch")
    precondition(failure(sourceRate: .nan) == "iq_audio_sample_rate_mismatch")
    precondition(failure(sessionRate: .infinity) == "iq_audio_sample_rate_mismatch")
    precondition(failure(selected: nil) == "iq_audio_device_unavailable")
    precondition(failure(routed: nil) == "iq_audio_device_unavailable")
    precondition(failure(routed: "built-in-mic") == "iq_audio_device_unavailable")
    print("I/Q route and format validation passed")
  }
}
