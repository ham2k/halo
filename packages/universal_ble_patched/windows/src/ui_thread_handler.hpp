#pragma once

#include <windows.h>

#include <flutter/plugin_registrar_windows.h>

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
        windowProcId_ = registrar_->RegisterTopLevelWindowProcDelegate(
            [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam)
            {
                return HandleWindowMessage(hwnd, message, wparam, lparam);
            });
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
        // Unconditional because the constructor always registers, so
        // `windowProcId_` is always an id the engine issued. Handing it one it
        // never issued is not a no-op in its delegate map -- so an early
        // return added to that constructor has to set a flag this reads.
        registrar_->UnregisterTopLevelWindowProcDelegate(windowProcId_);
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
    std::atomic<HWND> hwnd_ = nullptr;
    std::list<std::function<void()>> queuedFuncs_;
    std::mutex mutex_;
    bool accepting_ = true;
};
