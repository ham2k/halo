// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

/// An AudioWorklet runs on the browser's audio thread, outside the Dart isolate.
/// Its input uses channelCountMode=max and discrete interpretation: requesting
/// explicit stereo here would disguise a mono source by upmixing it.
const iqAudioWorkletSource = r'''
class HaloIqCapture extends AudioWorkletProcessor {
  constructor() {
    super();
    this.bytes = new ArrayBuffer(4096);
    this.data = new DataView(this.bytes);
    this.frames = 0;
    this.received = false;
    this.failed = false;
    this.inFlight = 0;
    this.port.onmessage = ({data}) => {
      if (data === 'ack' && this.inFlight > 0) this.inFlight--;
    };
  }

  fail(reason) {
    this.failed = true;
    this.port.postMessage(reason);
    return false;
  }

  process(inputs) {
    if (this.failed) return false;
    const channels = inputs[0];
    if (!channels || channels.length === 0) {
      return this.received ? this.fail('deviceUnavailable') : true;
    }
    if (channels.length !== 2 || channels[0].length !== channels[1].length) {
      return this.fail('invalidFormat');
    }
    this.received = true;
    for (let frame = 0; frame < channels[0].length; frame++) {
      for (let channel = 0; channel < 2; channel++) {
        const value = channels[channel][frame];
        if (!Number.isFinite(value)) return this.fail('invalidFormat');
        const clipped = Math.max(-1, Math.min(1, value));
        const sample = Math.round(clipped * (clipped < 0 ? 32768 : 32767));
        this.data.setInt16(this.frames * 4 + channel * 2, sample, true);
      }
      this.frames++;
      if (this.frames === 1024) {
        // Bound queued audio to 128 KiB: 171 ms at 192 kHz, 683 ms at 48 kHz.
        // A stalled receiver ends this capture; skipping samples would splice
        // a discontinuity into the FFT while keeping plausible frequency labels.
        if (this.inFlight >= 32) return this.fail('overrun');
        this.inFlight++;
        this.port.postMessage(this.bytes, [this.bytes]);
        this.bytes = new ArrayBuffer(4096);
        this.data = new DataView(this.bytes);
        this.frames = 0;
      }
    }
    // The output is intentionally silent; only the message port carries I/Q.
    return true;
  }
}
registerProcessor('halo-iq-capture', HaloIqCapture);
''';
