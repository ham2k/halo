#pragma once

#include <windows.h>

#include <flutter/plugin_registrar_windows.h>

#include "ham2k_ble_mode.h"

#include <algorithm>
#include <atomic>
#include <functional>
#include <list>
#include <mutex>
#include <optional>

// Hops work from a WinRT thread-pool thread onto the UI thread, by queueing it
// and poking the top-level window proc.
//
// Patched for HALO-290 (see PATCH.md): a shutdown gate, ported from upstream
// `main`, and an atomic `hwnd_`, which upstream still has not fixed.
class UniversalBleUiThreadHandler
{
public:
    explicit UniversalBleUiThreadHandler(flutter::PluginRegistrarWindows *registrar)
        : registrar_(registrar)
    {
        // Members initialize in declaration order and this is the plugin's
        // first non-trivial one, so this line and "06" bracket the whole of
        // member construction -- the one stretch no arm could ever reach.
        ham2k::Ham2kBleTrace(L"[ham2k] 05 UiThreadHandler ctor entered\n");
        // HALO-290 `nodelegate`: the one arm that subtracts. Everything else
        // about the plugin is built; only the top-level window proc hook is
        // absent. `mtx_do_lock` is reached through a window message, so this
        // is the direct test of whether that path is the crash.
        if (ham2k::Ham2kBleMode() == ham2k::BleMode::kNoDelegate)
        {
            return;
        }
        windowProcId_ = registrar_->RegisterTopLevelWindowProcDelegate(
            [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
            {
                return HandleWindowMessage(hwnd, message, wparam, lparam);
            });
        registered_ = true;
        ham2k::Ham2kBleTrace(L"[ham2k] 05b delegate registered\n");
    }

    ~UniversalBleUiThreadHandler() { Shutdown(); }

    UniversalBleUiThreadHandler(const UniversalBleUiThreadHandler &) = delete;
    UniversalBleUiThreadHandler &operator=(const UniversalBleUiThreadHandler &) = delete;

    void Post(std::function<void()> &&func)
    {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            // Dropping the work is the point: a callback queued after shutdown
            // has begun would run against members already being torn down.
            if (!accepting_)
            {
                return;
            }
            queuedFuncs_.emplace_back(std::move(func));
        }
        // Outside the lock. The UI thread takes this same mutex to drain the
        // queue, so poking it while still holding the mutex invites it to wake
        // straight into contention with the thread that woke it.
        Notify();
    }

    // Stops accepting work, drops what is still queued, and unhooks the window
    // proc delegate. Idempotent, and called from the destructor.
    //
    // Unregistering LAST is deliberate: `accepting_` is what makes a message
    // already sitting in the queue harmless, so it has to be false before the
    // delegate can stop being called, not after.
    void Shutdown()
    {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!accepting_)
            {
                return;
            }
            accepting_ = false;
            queuedFuncs_.clear();
        }
        // Unregistering an id that was never handed out is not a no-op in the
        // engine's delegate map -- the `nodelegate` arm must not do it.
        if (registered_)
        {
            registrar_->UnregisterTopLevelWindowProcDelegate(windowProcId_);
            registered_ = false;
        }
    }

private:
    static const UINT kWmCallQueuedFunctions = WM_APP + 0x1d7;

    void Notify()
    {
        const HWND hwnd = hwnd_.load();
        if (hwnd != nullptr)
        {
            PostMessage(hwnd, kWmCallQueuedFunctions, 0, reinterpret_cast<LPARAM>(this));
        }
    }

    std::optional<LRESULT> HandleWindowMessage(
        HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
    {
        // Written by the UI thread on the first message and read by whichever
        // thread calls Post(); atomic because those are different threads.
        if (hwnd_.load() == nullptr)
        {
            hwnd_.store(hwnd);
            Notify(); // Make sure queued functions are processed
        }
        if (message == kWmCallQueuedFunctions && lparam == reinterpret_cast<LPARAM>(this))
        {
            std::list<std::function<void()>> queuedFuncs;
            {
                std::lock_guard<std::mutex> lock(mutex_);
                if (!accepting_)
                {
                    return std::nullopt;
                }
                std::swap(queuedFuncs_, queuedFuncs);
            }
            for (auto &func : queuedFuncs)
            {
                func();
            }
        }
        return std::nullopt;
    }

    flutter::PluginRegistrarWindows *registrar_;
    int windowProcId_ = 0;
    bool registered_ = false;
    std::atomic<HWND> hwnd_ = nullptr;
    std::list<std::function<void()>> queuedFuncs_;
    std::mutex mutex_;
    bool accepting_ = true;
};
