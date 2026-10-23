// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#include "iq_capture.h"

#include <audioclient.h>
#include <mfapi.h>
#include <new>
#include <system_error>
#include <utility>
#include <mmdeviceapi.h>
#include <mmreg.h>
#include <wrl/client.h>

#include "audio_device/record_audio_device.h"
#include "iq_source_validation.h"
#include "utils.h"

namespace record_windows {
using Microsoft::WRL::ComPtr;

IqCapture::IqCapture(std::shared_ptr<RecorderDispatcher> dispatcher, Chunk chunk, std::function<void()> stopped)
    : dispatcher_(std::move(dispatcher)), chunk_(std::move(chunk)), stopped_(std::move(stopped)) {}

IqCapture::~IqCapture() { Stop(); }

HRESULT IqCapture::Start(RecordConfig config) {
  if (config.deviceId.empty()) return kIqDeviceUnavailable;
  if (config.numChannels != 2 || config.autoGain || config.echoCancel || config.noiseSuppress) return kIqInvalidFormat;
  stop_ = CreateEvent(nullptr, TRUE, FALSE, nullptr);
  if (!stop_) return HRESULT_FROM_WIN32(GetLastError());
  active_->store(true);
  auto ready = std::make_shared<std::promise<HRESULT>>();
  auto result = ready->get_future();
  try {
    worker_ = std::thread([this, config, ready] { Run(config, ready); });
  } catch (const std::system_error&) {
    Stop();
    return E_FAIL;
  }
  const auto hr = result.get();
  if (FAILED(hr)) Stop();
  return hr;
}

void IqCapture::Stop() {
  active_->store(false);
  if (stop_) SetEvent(stop_);
  if (worker_.joinable()) worker_.join();
  if (stop_) CloseHandle(stop_);
  stop_ = nullptr;
}

void IqCapture::Run(RecordConfig config, std::shared_ptr<std::promise<HRESULT>> ready) {
  const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(com)) {
    ready->set_value(com);
    return;
  }
  bool readySent = false;
  HRESULT hr = S_OK;
  {
    ComPtr<IMMDeviceEnumerator> enumerator;
    ComPtr<IMMDevice> device;
    ComPtr<IAudioClient> client;
    ComPtr<IAudioCaptureClient> capture;
    bool started = false;
    try {
      // The configured endpoint's native format must already match the RF span.
      // Exclusive format negotiation then proves the device can supply it
      // without the shared audio engine, APOs, upmixing or resampling.
      hr = AudioDevice::ValidateIqDevice(config);
      if (SUCCEEDED(hr)) hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
      const auto id = Utf16FromUtf8(config.deviceId);
      if (SUCCEEDED(hr) && id.empty()) hr = kIqDeviceUnavailable;
      if (SUCCEEDED(hr)) hr = enumerator->GetDevice(id.c_str(), &device);
      if (SUCCEEDED(hr)) hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, reinterpret_cast<void**>(client.GetAddressOf()));

      WAVEFORMATEXTENSIBLE format = {};
      format.Format.wFormatTag = WAVE_FORMAT_EXTENSIBLE;
      format.Format.nChannels = 2;
      format.Format.nSamplesPerSec = static_cast<DWORD>(config.sampleRate);
      format.Format.cbSize = static_cast<WORD>(sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX));
      format.dwChannelMask = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
      format.SubFormat = MFAudioFormat_PCM;
      if (SUCCEEDED(hr)) {
        hr = kIqInvalidFormat;
        // PCM-only conversion changes precision, never rate or channel count.
        for (const auto bits : {16u, 24u, 32u}) {
          format.Format.wBitsPerSample = static_cast<WORD>(bits);
          format.Format.nBlockAlign = static_cast<WORD>(2 * bits / 8);
          format.Format.nAvgBytesPerSec = format.Format.nSamplesPerSec * format.Format.nBlockAlign;
          for (const auto validBits : {bits, 24u}) {
            if (validBits > bits) continue;
            format.Samples.wValidBitsPerSample = static_cast<WORD>(validBits);
            for (const bool extensible : {true, false}) {
              if (!extensible && validBits != bits) continue;
              // Some WDM drivers accept stereo PCM only through WAVEFORMATEX.
              // Both descriptions still request the same native I/Q format.
              format.Format.wFormatTag = static_cast<WORD>(extensible ? WAVE_FORMAT_EXTENSIBLE : WAVE_FORMAT_PCM);
              format.Format.cbSize = extensible ? static_cast<WORD>(sizeof(WAVEFORMATEXTENSIBLE) - sizeof(WAVEFORMATEX)) : 0;
              const auto supported = client->IsFormatSupported(AUDCLNT_SHAREMODE_EXCLUSIVE, &format.Format, nullptr);
              if (supported == S_OK) { hr = S_OK; break; }
              if (supported != AUDCLNT_E_UNSUPPORTED_FORMAT && supported != S_FALSE && supported != E_INVALIDARG) {
                hr = supported;
                break;
              }
            }
            if (hr != kIqInvalidFormat) break;
          }
          if (hr != kIqInvalidFormat) break;
        }
      }
      if (SUCCEEDED(hr)) {
        // A generous hardware buffer tolerates normal desktop scheduling. Any
        // actual discontinuity still terminates the FFT stream immediately.
        REFERENCE_TIME duration = 1000000; // 100 ms, in 100 ns units.
        hr = client->Initialize(AUDCLNT_SHAREMODE_EXCLUSIVE, 0, duration, 0, &format.Format, nullptr);
        if (hr == AUDCLNT_E_BUFFER_SIZE_NOT_ALIGNED) {
          UINT32 frames = 0;
          hr = client->GetBufferSize(&frames);
          if (SUCCEEDED(hr)) {
            duration = (10000000LL * frames + config.sampleRate / 2) / config.sampleRate;
            client.Reset();
            hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr, reinterpret_cast<void**>(client.GetAddressOf()));
          }
          if (SUCCEEDED(hr)) hr = client->Initialize(AUDCLNT_SHAREMODE_EXCLUSIVE, 0, duration, 0, &format.Format, nullptr);
        }
      }
      UINT32 bufferFrames = 0;
      if (SUCCEEDED(hr)) hr = client->GetBufferSize(&bufferFrames);
      if (SUCCEEDED(hr) && bufferFrames == 0) hr = kIqInvalidFormat;
      if (SUCCEEDED(hr)) hr = client->GetService(IID_PPV_ARGS(&capture));
      if (SUCCEEDED(hr)) hr = client->Start();
      started = SUCCEEDED(hr);
      ready->set_value(hr);
      readySent = true;
      bool first = true;
      unsigned int emptyPasses = 0;
      while (SUCCEEDED(hr)) {
        const auto wait = WaitForSingleObject(stop_, 5);
        if (wait == WAIT_OBJECT_0) break;
        if (wait == WAIT_FAILED) { hr = HRESULT_FROM_WIN32(GetLastError()); break; }
        if (wait != WAIT_TIMEOUT) { hr = E_FAIL; break; }
        // Keep at most one dispatch packet queued. A stalled consumer produces
        // a visible hardware overrun instead of unbounded sample buffering.
        if (pending_->load()) continue;
        std::vector<uint8_t> batch;
        size_t batchFrames = 0;
        // Drain small packets instead of imposing one packet per timer tick.
        // Stop after a buffer's worth; the last whole packet can extend the
        // batch to at most two endpoint buffers. Each packet is released first.
        while (active_->load() && batchFrames < bufferFrames) {
          BYTE* data = nullptr;
          UINT32 frames = 0;
          DWORD flags = 0;
          // GetNextPacketSize is shared-mode-only. Exclusive capture polls
          // GetBuffer directly; BUFFER_ERROR can mean no packet this pass.
          hr = capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr);
          if (hr == AUDCLNT_S_BUFFER_EMPTY || hr == AUDCLNT_E_BUFFER_ERROR || (SUCCEEDED(hr) && frames == 0)) {
            hr = S_OK;
            break;
          }
          if (FAILED(hr)) break;
          std::vector<uint8_t> pcm;
          const bool discontinuity = !first && (flags & AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY);
          try {
            if (frames > bufferFrames || discontinuity || (flags & AUDCLNT_BUFFERFLAGS_TIMESTAMP_ERROR) ||
                !IqPcm16(data, static_cast<size_t>(frames) * format.Format.nBlockAlign,
                         static_cast<unsigned int>(format.Format.wBitsPerSample / 8),
                         (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0, pcm)) {
              hr = kIqInvalidFormat;
            }
          } catch (...) {
            capture->ReleaseBuffer(frames);
            throw;
          }
          const auto released = capture->ReleaseBuffer(frames);
          if (SUCCEEDED(hr)) hr = released;
          first = false;
          if (FAILED(hr)) break;
          batch.insert(batch.end(), pcm.begin(), pcm.end());
          batchFrames += frames;
        }
        if (FAILED(hr) || !active_->load()) break;
        if (batch.empty()) {
          if (++emptyPasses >= 200) { hr = kIqDeviceUnavailable; break; }
          continue;
        }
        emptyPasses = 0;
        pending_->store(true);
        const auto active = active_;
        const auto pending = pending_;
        const auto callback = chunk_;
        if (!dispatcher_->Post([active, pending, callback, batch = std::move(batch)]() mutable {
          if (active->load()) callback(std::move(batch));
          pending->store(false);
        })) break;
      }
    } catch (const std::bad_alloc&) {
      hr = E_OUTOFMEMORY;
    } catch (...) {
      hr = E_FAIL;
    }
    if (started) client->Stop();
    // COM pointers release on their owning worker before shutdown or exit.
  }
  CoUninitialize();
  if (!readySent) ready->set_value(hr);
  if (FAILED(hr) && readySent) {
    const auto active = active_;
    const auto callback = stopped_;
    dispatcher_->Post([active, callback] { if (active->load()) callback(); });
  }
}

}  // namespace record_windows
