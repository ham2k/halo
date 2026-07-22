#include "win32_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <shellapi.h>
#include <windowsx.h>

#include "halo_edition.h"
#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

/// Registry location where the window's placement (position, size, and
/// maximized state) is remembered between launches, stored as the raw
/// WINDOWPLACEMENT struct. Keyed per edition (HALO_PRODUCT_NAME_W) so separate
/// editions don't share — and clobber — each other's window geometry, matching
/// the per-bundle-id (macOS) and per-APPLICATION_ID (Linux) stores.
constexpr const wchar_t kWindowPlacementRegKey[] =
  L"Software\\Ham2K\\Halo\\" HALO_PRODUCT_NAME_W;
constexpr const wchar_t kWindowPlacementRegValue[] = L"WindowPlacement";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Thickness (physical pixels) of the invisible resize band along the top
// edge of the chromeless window — the same metric the standard frame uses
// for its grips.
int TopResizeBandThickness(HWND hwnd) {
  UINT dpi = GetDpiForWindow(hwnd);
  return GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

// Whether a screen point falls in the chromeless window's top resize band.
// The ONE definition both hit-test halves share: the child subclass forwards
// (HTTRANSPARENT) exactly the points the top-level handler classifies as top
// grips — if these tests ever disagreed, top-edge resizing would silently
// break.
bool InTopResizeBand(HWND top_level, POINT screen_point) {
  if (IsZoomed(top_level)) {
    return false;
  }
  RECT window_rect;
  GetWindowRect(top_level, &window_rect);
  return screen_point.y < window_rect.top + TopResizeBandThickness(top_level);
}

// The extra outer size the window frame adds around the client area, so
// client-size floors can be converted to the outer sizes the tracking
// APIs work in.
SIZE FrameOutsets(HWND hwnd) {
  RECT window_rect;
  RECT client_rect;
  GetWindowRect(hwnd, &window_rect);
  GetClientRect(hwnd, &client_rect);
  return SIZE{
      (window_rect.right - window_rect.left) - client_rect.right,
      (window_rect.bottom - window_rect.top) - client_rect.bottom,
  };
}

// Identifier for the subclass installed on the Flutter child view.
constexpr UINT_PTR kChildHitTestSubclassId = 1;

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  // The chromeless frame (WM_NCCALCSIZE above) only applies when Windows
  // recalculates the frame; the initial frame from CreateWindow used the
  // default calculation, so without this kick the standard title bar and
  // borders stay until the first user resize. Done before OnCreate so the
  // Flutter view is created at the enlarged (caption-free) client size.
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);

  // Restore the remembered position/size/maximized state over the default
  // origin/size, while the window is still hidden (it isn't shown until the
  // first Flutter frame calls Show()) — so there's no launch flash.
  RestoreWindowPlacement();

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_,
                    restore_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    // Chromeless window: no title bar, no visible border — the app's own
    // header reaches the very top, mirroring the macOS runner's transparent
    // titlebar (MainFlutterWindow.swift). Keeping WS_OVERLAPPEDWINDOW and
    // reshaping the frame here (instead of WS_POPUP) preserves the native
    // resize grips, minimize/maximize animations, Aero Snap, and the DWM
    // shadow.
    case WM_NCCALCSIZE: {
      if (!wparam) {
        break;
      }
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const LONG original_top = params->rgrc[0].top;
      // Let the default frame compute its insets, then restore the top so
      // the caption disappears while the side/bottom resize borders (which
      // live in the invisible band OUTSIDE the visible edge) stay intact.
      const LRESULT def_result =
          DefWindowProc(hwnd, WM_NCCALCSIZE, wparam, lparam);
      if (def_result != 0) {
        return def_result;
      }
      params->rgrc[0].top = original_top;
      // A maximized window hangs past the monitor edge by the frame width;
      // without re-adding that inset at the top, the header's top band would
      // sit offscreen.
      if (IsZoomed(hwnd)) {
        params->rgrc[0].top += TopResizeBandThickness(hwnd);
        // Leave one pixel for a top-docked auto-hide taskbar, or hovering
        // the top edge could never summon it while we're maximized (the
        // same shave Windows Terminal and Chromium apply).
        MONITORINFO monitor_info = {sizeof(MONITORINFO)};
        if (GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST),
                           &monitor_info)) {
          APPBARDATA autohide = {sizeof(APPBARDATA)};
          autohide.uEdge = ABE_TOP;
          autohide.rc = monitor_info.rcMonitor;
          if (SHAppBarMessage(ABM_GETAUTOHIDEBAREX, &autohide)) {
            params->rgrc[0].top += 1;
          }
        }
      }
      return 0;
    }

    case WM_NCHITTEST: {
      // With the caption removed, the client area reaches the window top,
      // so the default proc reports HTCLIENT there. Points in the top band
      // only arrive here after the Flutter child returns HTTRANSPARENT for
      // them (ChildHitTestProc) — translate them to the resize grips the
      // standard frame would have offered.
      const LRESULT hit = DefWindowProc(hwnd, WM_NCHITTEST, wparam, lparam);
      if (hit == HTCLIENT) {
        const POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        if (InTopResizeBand(hwnd, point)) {
          RECT window_rect;
          GetWindowRect(hwnd, &window_rect);
          const int band = TopResizeBandThickness(hwnd);
          if (point.x < window_rect.left + 2 * band) {
            return HTTOPLEFT;
          }
          if (point.x >= window_rect.right - 2 * band) {
            return HTTOPRIGHT;
          }
          return HTTOP;
        }
      }
      return hit;
    }

    case WM_GETMINMAXINFO: {
      if (min_content_width_ > 0 && min_content_height_ > 0) {
        UINT dpi = GetDpiForWindow(hwnd);
        double scale_factor = dpi / 96.0;
        // ptMinTrackSize constrains the OUTER rect; the floor is a CLIENT
        // size, so add the frame's outsets (the invisible side/bottom
        // resize borders the custom WM_NCCALCSIZE keeps) or the client
        // could be dragged below the layouts.md minimum.
        const SIZE frame = FrameOutsets(hwnd);
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize.x =
            Scale(static_cast<int>(min_content_width_), scale_factor) + frame.cx;
        info->ptMinTrackSize.y =
            Scale(static_cast<int>(min_content_height_), scale_factor) + frame.cy;
        return 0;
      }
      break;
    }

    case WM_DESTROY:
      // Remember where the window was before it goes away (the handle is still
      // valid here). Covers the normal close path.
      SaveWindowPlacement();
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  // The child covers the entire client area, which in the chromeless window
  // includes the top resize band; without this subclass every hit-test up
  // there would stop at the child and the top edge couldn't be resized.
  SetWindowSubclass(content, ChildHitTestProc, kChildHitTestSubclassId,
                    reinterpret_cast<DWORD_PTR>(this));
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

// static
LRESULT CALLBACK Win32Window::ChildHitTestProc(HWND hwnd,
                                               UINT message,
                                               WPARAM wparam,
                                               LPARAM lparam,
                                               UINT_PTR /* subclass_id */,
                                               DWORD_PTR ref_data) {
  if (message == WM_NCHITTEST) {
    auto* that = reinterpret_cast<Win32Window*>(ref_data);
    HWND top_level = that->window_handle_;
    const POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    if (top_level && InTopResizeBand(top_level, point)) {
      // Fall through to the top-level window, whose WM_NCHITTEST turns
      // this band into the top resize grips.
      return HTTRANSPARENT;
    }
  }
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

void Win32Window::SetMinimumContentSize(double width, double height) {
  min_content_width_ = width;
  min_content_height_ = height;
  // Never resize a maximized window in place — that leaves WS_MAXIMIZE set
  // on bounds that no longer match (stale restore rect, wrong caption
  // glyph). The floor re-applies through WM_GETMINMAXINFO on the next
  // user-driven track anyway.
  if (IsZoomed(window_handle_)) {
    return;
  }
  // WM_GETMINMAXINFO only constrains FUTURE resizes; a floor that grew must
  // also lift the current window (same reasoning as the macOS runner's
  // setMinimumSize handler).
  RECT client = GetClientArea();
  UINT dpi = GetDpiForWindow(window_handle_);
  double scale_factor = dpi / 96.0;
  LONG min_w = Scale(static_cast<int>(width), scale_factor);
  LONG min_h = Scale(static_cast<int>(height), scale_factor);
  LONG current_w = client.right - client.left;
  LONG current_h = client.bottom - client.top;
  if (current_w < min_w || current_h < min_h) {
    RECT window_rect;
    GetWindowRect(window_handle_, &window_rect);
    LONG frame_w = (window_rect.right - window_rect.left) - current_w;
    LONG frame_h = (window_rect.bottom - window_rect.top) - current_h;
    SetWindowPos(window_handle_, nullptr, 0, 0,
                 (current_w < min_w ? min_w : current_w) + frame_w,
                 (current_h < min_h ? min_h : current_h) + frame_h,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}

void Win32Window::SaveWindowPlacement() {
  if (!window_handle_) {
    return;
  }
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window_handle_, &placement)) {
    return;
  }
  HKEY key = nullptr;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kWindowPlacementRegKey, 0, nullptr,
                     REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &key,
                     nullptr) == ERROR_SUCCESS) {
    RegSetValueEx(key, kWindowPlacementRegValue, 0, REG_BINARY,
                  reinterpret_cast<const BYTE*>(&placement),
                  sizeof(placement));
    RegCloseKey(key);
  }
}

void Win32Window::RestoreWindowPlacement() {
  WINDOWPLACEMENT placement{};
  DWORD size = sizeof(placement);
  if (RegGetValue(HKEY_CURRENT_USER, kWindowPlacementRegKey,
                  kWindowPlacementRegValue, RRF_RT_REG_BINARY, nullptr,
                  &placement, &size) != ERROR_SUCCESS ||
      size != sizeof(placement) || placement.length != sizeof(placement)) {
    return;
  }
  // Drop a saved rect that no longer intersects any connected monitor (e.g. an
  // external display that's been unplugged) rather than stranding the window
  // offscreen — fall back to the default origin/size Create() started with.
  if (MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONULL) ==
      nullptr) {
    return;
  }
  restore_maximized_ =
      placement.showCmd == SW_SHOWMAXIMIZED ||
      (placement.showCmd == SW_SHOWMINIMIZED &&
       (placement.flags & WPF_RESTORETOMAXIMIZED) != 0);
  // Apply the restore rect while still hidden; Show() reveals it (maximized or
  // normal) once the first Flutter frame has rendered. Never launch minimized.
  placement.showCmd = SW_HIDE;
  SetWindowPlacement(window_handle_, &placement);
}
