#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  // Smallest client size (logical pixels; converted per-monitor via the
  // window DPI) the user may resize the window to. Enforced through
  // WM_GETMINMAXINFO; pushed from Flutter over the window-chrome channel
  // (see flutter_window.cpp), mirroring the macOS contentMinSize floor.
  void SetMinimumContentSize(double width, double height);

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  // Persist the window's placement (position, size, and maximized state) to
  // the registry on close, and restore it during Create()/Show() so the
  // window comes back where it was with no launch flash. (Remember window
  // geometry across launches.)
  void SaveWindowPlacement();
  void RestoreWindowPlacement();

  // Shows the Flutter child view and moves it back over the client area if
  // something else hid or moved it, logging what it found. |moment| names
  // the caller in that log line.
  void PutChildContentBack(const char* moment);

  // Subclass proc installed on the Flutter child view (SetChildContent): the
  // child covers the whole client area of the chromeless window, so it must
  // return HTTRANSPARENT in the top resize band for the parent to receive
  // the hit-test and offer the top resize grip (see MessageHandler's
  // WM_NCHITTEST). It also holds the child visible and at the client rect
  // against placements from other processes.
  static LRESULT CALLBACK ChildContentProc(HWND hwnd,
                                           UINT message,
                                           WPARAM wparam,
                                           LPARAM lparam,
                                           UINT_PTR subclass_id,
                                           DWORD_PTR ref_data);

  bool quit_on_close_ = false;

  // Resize floor in logical pixels; 0 means "not set" (no floor).
  double min_content_width_ = 0;
  double min_content_height_ = 0;

  // Set from a restored placement so Show() re-maximizes the window instead of
  // revealing it at the smaller restore-rect size.
  bool restore_maximized_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
