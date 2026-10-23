// Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
// SPDX-License-Identifier: MPL-2.0

#pragma once

#include <windows.h>
#include <atomic>
#include <cstdint>
#include <functional>
#include <future>
#include <memory>
#include <thread>
#include <vector>

#include "record_config.h"
#include "recorder_dispatcher.h"

namespace record_windows {

// The capture worker owns all WASAPI COM objects. Stop joins it before a new
// capture can claim the same endpoint, and disarms already queued samples.
class IqCapture {
 public:
  using Chunk = std::function<void(std::vector<uint8_t>)>;
  IqCapture(std::shared_ptr<RecorderDispatcher> dispatcher, Chunk chunk, std::function<void()> stopped);
  ~IqCapture();
  HRESULT Start(RecordConfig config);
  void Stop();

 private:
  void Run(RecordConfig config, std::shared_ptr<std::promise<HRESULT>> ready);
  std::shared_ptr<RecorderDispatcher> dispatcher_;
  Chunk chunk_;
  std::function<void()> stopped_;
  std::shared_ptr<std::atomic<bool>> active_ = std::make_shared<std::atomic<bool>>(false);
  std::shared_ptr<std::atomic<bool>> pending_ = std::make_shared<std::atomic<bool>>(false);
  HANDLE stop_ = nullptr;
  std::thread worker_;
};

}  // namespace record_windows
