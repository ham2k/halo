package com.llfbandit.record.record.recorder

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class IqCaptureValidationTest {
  private fun failure(
    selected: String? = "17",
    routed: String? = "17",
    hardware: String? = "17",
    hardwareChannels: Int = 2,
    clientChannels: Int = 2,
    hardwareRate: Int = 48000,
    clientRate: Int = 48000,
    requestedRate: Int = 48000,
    processing: Boolean = false,
  ) = IqCaptureValidation.failure(
    selected, routed, hardware, hardwareChannels, clientChannels,
    hardwareRate, clientRate, requestedRate, processing,
  )

  @Test fun `native stereo rates preserve the requested spectrum width`() {
    for (rate in listOf(48000, 96000, 192000)) {
      assertNull(failure(hardwareRate = rate, clientRate = rate, requestedRate = rate))
    }
  }

  @Test fun `stereo requested from mono or multichannel hardware is not quadrature audio`() {
    for (channels in listOf(0, 1, 6)) {
      assertEquals("iq_audio_invalid_format", failure(hardwareChannels = channels))
    }
    assertEquals("iq_audio_invalid_format", failure(clientChannels = 1))
  }

  @Test fun `client resampling cannot manufacture a wider RF capture`() {
    assertEquals("iq_audio_sample_rate_mismatch", failure(hardwareRate = 48000, clientRate = 96000, requestedRate = 96000))
    assertEquals("iq_audio_sample_rate_mismatch", failure(hardwareRate = 44100))
    assertEquals("iq_audio_sample_rate_mismatch", failure(clientRate = 44100))
    assertEquals("iq_audio_sample_rate_mismatch", failure(hardwareRate = 0))
  }

  @Test fun `an unplug or fallback route never adopts another microphone`() {
    assertEquals("iq_audio_device_unavailable", failure(selected = null))
    assertEquals("iq_audio_device_unavailable", failure(selected = ""))
    assertEquals("iq_audio_device_unavailable", failure(routed = null))
    assertEquals("iq_audio_device_unavailable", failure(routed = "18"))
    assertEquals("iq_audio_device_unavailable", failure(hardware = "18"))
    assertEquals("iq_audio_device_unavailable", failure(hardware = null))
  }

  @Test fun `active processing or capture silencing invalidates an otherwise correct format`() {
    assertEquals("iq_audio_invalid_format", failure(processing = true))
  }
}
