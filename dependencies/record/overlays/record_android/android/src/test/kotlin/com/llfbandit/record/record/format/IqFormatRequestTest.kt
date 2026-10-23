package com.llfbandit.record.record.format

import android.content.Context
import android.media.AudioManager
import androidx.test.core.app.ApplicationProvider
import io.flutter.plugin.common.MethodCall
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.MediaFormat
import com.llfbandit.record.record.encoder.EncoderListener
import com.llfbandit.record.record.model.RecordConfig
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AudioDeviceInfoBuilder
import org.robolectric.util.ReflectionHelpers

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class IqFormatRequestTest {
  @Test
  fun `mono device cannot rewrite the stereo request and disable I-Q validation`() {
    val device = AudioDeviceInfoBuilder.newBuilder().setType(AudioDeviceInfo.TYPE_USB_DEVICE).build()
    val port = ReflectionHelpers.getField<Any>(device, "mPort")
    ReflectionHelpers.setField(port.javaClass.superclass, port, "mRole", 1)
    ReflectionHelpers.setField(port.javaClass.superclass, port, "mChannelMasks", intArrayOf(AudioFormat.CHANNEL_IN_MONO))
    ReflectionHelpers.setField(port.javaClass.superclass, port, "mChannelIndexMasks", intArrayOf())
    assertArrayEquals(intArrayOf(1), device.channelCounts)
    val config = RecordConfig(
      path = null, encoder = "pcm16bits", bitRate = 0, sampleRate = 96000,
      numChannels = 2, device = device, audioInterruption = 1,
      streamBufferSize = null, requestedDeviceId = device.id.toString(),
    )
    val listener = object : EncoderListener {
      override fun onEncoderFailure(ex: Exception) { throw ex }
      override fun onEncoderStream(bytes: ByteArray) {}
    }

    val (_, format) = Format.createEncoder(config, listener)

    assertTrue(config.isIqStream)
    assertEquals(2, config.numChannels)
    assertEquals(2, format.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
    assertEquals(96000, config.sampleRate)
    assertEquals(96000, format.getInteger(MediaFormat.KEY_SAMPLE_RATE))
  }

  @Test
  fun `missing selected input fails before default input preparation`() {
    val context: Context = ApplicationProvider.getApplicationContext()
    val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    shadowOf(manager).setInputDevices(emptyList())
    for (device in listOf(null, mapOf("id" to "disconnected-usb"))) {
      val call = MethodCall("startStream", mapOf(
        "encoder" to "pcm16bits", "numChannels" to 2,
        "sampleRate" to 48000, "device" to device,
      ))
      val failure = assertThrows(Exception::class.java) { RecordConfig.fromMap(call, context) }
      assertEquals("iq_audio_device_unavailable", failure.message)
    }
  }

}
