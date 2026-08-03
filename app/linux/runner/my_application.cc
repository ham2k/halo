#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // Remembered window geometry (persisted across launches, see the
  // save/restore helpers below): the last NON-maximized size/position plus
  // whether the window was maximized, so un-maximizing returns to a sane size.
  // width/height <= 0 and x/y < 0 mean "nothing tracked yet".
  gint window_width;
  gint window_height;
  gint window_x;
  gint window_y;
  gboolean window_maximized;
  // The window-chrome method channel (see window_chrome_method_call_cb and
  // ham2k/window_chrome.dart-side WindowChromeService) — kept on the
  // instance so my_application_on_window_state can push maximize
  // transitions to it.
  FlMethodChannel* window_chrome_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// ── Remember the window's geometry across launches ──────────────────────────
// Window geometry isn't part of the ham2k/window_chrome channel (below) —
// it's persisted here in the runner instead: a small key file under the
// user's config dir, written on shutdown and restored (size + position +
// maximized) in activate before the window is shown, so there's no launch
// flash.

static gchar* my_application_window_state_path() {
  return g_build_filename(g_get_user_config_dir(), APPLICATION_ID, "window.ini",
                          nullptr);
}

// Track the window's NORMAL (non-maximized) size/position, so it can be both
// restored and returned to after un-maximizing. Skipped while maximized, where
// the reported geometry is the full-screen size, not the restore size.
static gboolean my_application_on_configure(GtkWidget* widget,
                                            GdkEventConfigure* event,
                                            gpointer user_data) {
  (void)event;
  MyApplication* self = MY_APPLICATION(user_data);
  GtkWindow* window = GTK_WINDOW(widget);
  if (!gtk_window_is_maximized(window)) {
    gtk_window_get_size(window, &self->window_width, &self->window_height);
    gtk_window_get_position(window, &self->window_x, &self->window_y);
  }
  return FALSE;  // propagate — this is a passive observer
}

static gboolean my_application_on_window_state(GtkWidget* widget,
                                               GdkEventWindowState* event,
                                               gpointer user_data) {
  (void)widget;
  MyApplication* self = MY_APPLICATION(user_data);
  if (event->changed_mask & GDK_WINDOW_STATE_MAXIMIZED) {
    self->window_maximized =
        (event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
    // Push the transition to the Flutter-drawn caption buttons
    // (WindowsCaptionButtons/windowsWindowIsMaximized in platform_chrome.dart)
    // the same way flutter_window.cpp does on WM_SIZE.
    if (self->window_chrome_channel) {
      g_autoptr(FlValue) maximized_value = fl_value_new_bool(self->window_maximized);
      fl_method_channel_invoke_method(self->window_chrome_channel, "maximizedChanged",
                                      maximized_value, nullptr, nullptr, nullptr);
    }
  }
  return FALSE;
}

// Apply the remembered geometry to a freshly-created, not-yet-shown window.
static void my_application_restore_window_state(MyApplication* self,
                                                GtkWindow* window) {
  g_autofree gchar* path = my_application_window_state_path();
  g_autoptr(GKeyFile) key_file = g_key_file_new();
  if (!g_key_file_load_from_file(key_file, path, G_KEY_FILE_NONE, nullptr)) {
    return;  // first launch, or unreadable — keep the default size
  }
  gint width = g_key_file_get_integer(key_file, "window", "width", nullptr);
  gint height = g_key_file_get_integer(key_file, "window", "height", nullptr);
  if (width <= 0 || height <= 0) {
    return;
  }
  gtk_window_set_default_size(window, width, height);
  self->window_width = width;
  self->window_height = height;

  gint x = g_key_file_get_integer(key_file, "window", "x", nullptr);
  gint y = g_key_file_get_integer(key_file, "window", "y", nullptr);
  if (x >= 0 && y >= 0) {
    // Best effort: X11 honors this; Wayland ignores app-side positioning (the
    // compositor owns window placement), so there size + maximized restore but
    // position may not.
    gtk_window_move(window, x, y);
    self->window_x = x;
    self->window_y = y;
  }

  if (g_key_file_get_boolean(key_file, "window", "maximized", nullptr)) {
    self->window_maximized = TRUE;
    gtk_window_maximize(window);
  }
}

static void my_application_save_window_state(MyApplication* self) {
  if (self->window_width <= 0 || self->window_height <= 0) {
    return;  // never tracked a real geometry — leave any prior file alone
  }
  g_autoptr(GKeyFile) key_file = g_key_file_new();
  g_key_file_set_integer(key_file, "window", "width", self->window_width);
  g_key_file_set_integer(key_file, "window", "height", self->window_height);
  g_key_file_set_integer(key_file, "window", "x", self->window_x);
  g_key_file_set_integer(key_file, "window", "y", self->window_y);
  g_key_file_set_boolean(key_file, "window", "maximized",
                         self->window_maximized);

  g_autofree gchar* path = my_application_window_state_path();
  g_autofree gchar* dir = g_path_get_dirname(path);
  g_mkdir_with_parents(dir, 0755);
  g_key_file_save_to_file(key_file, path, nullptr);
}

// ── Window-chrome channel ────────────────────────────────────────────────
// Handles the same "ham2k/window_chrome" method calls the Windows runner's
// SetUpWindowChromeChannel (flutter_window.cpp) does, for the Flutter-drawn
// header controls (WindowsCaptionButtons / windowHeaderGestureArea in
// platform_chrome.dart). user_data is the GtkWindow directly — this handler
// has no other use for the MyApplication instance.
static void window_chrome_method_call_cb(FlMethodChannel* channel,
                                         FlMethodCall* method_call,
                                         gpointer user_data) {
  (void)channel;
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(method, "performHeaderDoubleClickAction") == 0 ||
      g_strcmp0(method, "toggleMaximizeWindow") == 0) {
    // Windows title-bar double-click convention: toggle maximize.
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "minimizeWindow") == 0) {
    gtk_window_iconify(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "closeWindow") == 0) {
    gtk_window_close(window);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "startWindowDrag") == 0) {
    // Unlike the Windows runner (which replays WM_NCLBUTTONDOWN from the
    // still-down mouse button), there's no native mouse-down event here to
    // hand off — this fires from Dart's onPanStart, after the fact. Re-derive
    // the pointer's current root position instead and hand the whole drag to
    // the window manager, the same delegation GtkHeaderBar itself uses.
    GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
    GdkSeat* seat = gdk_display_get_default_seat(display);
    GdkDevice* pointer = gdk_seat_get_pointer(seat);
    gint root_x = 0;
    gint root_y = 0;
    gdk_device_get_position(pointer, nullptr, &root_x, &root_y);
    gtk_window_begin_move_drag(window, /* left button */ 1, root_x, root_y, GDK_CURRENT_TIME);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(method, "getIsMaximized") == 0) {
    // Dart pulls this at startup: the maximize push above only fires on
    // transitions, so a fresh Dart side (launch, hot restart) would
    // otherwise assume "not maximized" forever.
    g_autoptr(FlValue) result = fl_value_new_bool(gtk_window_is_maximized(window));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (g_strcmp0(method, "setMinimumSize") == 0) {
    // The resize floor (layouts.md's minWindowSize), already multiplied by
    // the UI scale on the Flutter side — same contract as the macOS/Windows
    // runners' setMinimumSize handlers.
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* width_value = args ? fl_value_lookup_string(args, "width") : nullptr;
    FlValue* height_value = args ? fl_value_lookup_string(args, "height") : nullptr;
    if (width_value && height_value) {
      gtk_widget_set_size_request(GTK_WIDGET(window), static_cast<gint>(fl_value_get_float(width_value)),
                                  static_cast<gint>(fl_value_get_float(height_value)));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      response = FL_METHOD_RESPONSE(
          fl_method_error_response_new("bad_args", "Expected width and height doubles", nullptr));
    }
  } else {
    // showSystemMenu and setTitleBarHeight are Windows/macOS-only concerns.
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send window_chrome response: %s", error->message);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  gtk_window_set_title(window, HALO_PRODUCT_NAME);

  // Chromeless window: replace the native title bar with an effectively
  // invisible custom one, mirroring the macOS/Windows runners' "the app's
  // own header reaches the window's top edge" treatment
  // (window_chrome_service.dart). Installing ANY widget via
  // gtk_window_set_titlebar keeps GTK on its normal client-side-decoration
  // path — so the window manager still supplies the drag/resize/shadow
  // handling CSD windows get for free — it just has nothing visible left to
  // draw. Kept as a real GtkHeaderBar (rather than a plain container) since
  // that's the widget GTK's CSD/resize negotiation is designed around; CSS
  // forces its usual themed background and padding down to nothing.
  GtkWidget* titlebar = gtk_header_bar_new();
  gtk_header_bar_set_show_close_button(GTK_HEADER_BAR(titlebar), FALSE);
  gtk_header_bar_set_title(GTK_HEADER_BAR(titlebar), nullptr);
  gtk_widget_set_size_request(titlebar, -1, 1);
  GtkStyleContext* titlebar_style = gtk_widget_get_style_context(titlebar);
  gtk_style_context_add_class(titlebar_style, "ham2k-invisible-titlebar");
  g_autoptr(GtkCssProvider) titlebar_css = gtk_css_provider_new();
  gtk_css_provider_load_from_data(titlebar_css,
                                  ".ham2k-invisible-titlebar { background: transparent; "
                                  "background-image: none; border: none; box-shadow: none; "
                                  "padding: 0; margin: 0; min-height: 0; }",
                                  -1, nullptr);
  gtk_style_context_add_provider(titlebar_style, GTK_STYLE_PROVIDER(titlebar_css),
                                 GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  gtk_widget_show(titlebar);
  gtk_window_set_titlebar(window, titlebar);

  // Ties every window to the themed icon named after APPLICATION_ID — the
  // per-edition icon the CMake install lays down as
  // hicolor/512x512/apps/<APPLICATION_ID>.png (docs/releases.md §2.6). Findable
  // because startup() registered the bundle's own share/icons as a search path.
  gtk_window_set_default_icon_name(APPLICATION_ID);

  gtk_window_set_default_size(window, 1280, 720);
  // Restore remembered geometry over that default (no-op on first launch), and
  // start tracking changes so the next shutdown persists them.
  my_application_restore_window_state(self, window);
  g_signal_connect(window, "configure-event",
                   G_CALLBACK(my_application_on_configure), self);
  g_signal_connect(window, "window-state-event",
                   G_CALLBACK(my_application_on_window_state), self);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Chrome channel: minimize/maximize/close and window-drag for the
  // Flutter-drawn header controls, mirroring the Windows runner's
  // SetUpWindowChromeChannel (flutter_window.cpp).
  g_autoptr(FlStandardMethodCodec) window_chrome_codec = fl_standard_method_codec_new();
  self->window_chrome_channel =
      fl_method_channel_new(fl_engine_get_binary_messenger(fl_view_get_engine(view)),
                            "ham2k/window_chrome", FL_METHOD_CODEC(window_chrome_codec));
  fl_method_channel_set_method_call_handler(self->window_chrome_channel, window_chrome_method_call_cb,
                                            window, nullptr);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// The bundle is self-contained and relocatable (linux/CMakeLists.txt installs
// the app icon under its own share/icons/hicolor/…, not into a system icon
// theme dir), so gtk_window_set_default_icon_name below can't find it by name
// unless the icon theme is told where to look. Without this, a portable run
// or an AppImage launches with no window/taskbar icon at all — the theme
// lookup just fails silently.
static void my_application_register_bundled_icon_theme() {
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path == nullptr) {
    return;
  }
  g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
  g_autofree gchar* icon_dir =
      g_build_filename(exe_dir, "share", "icons", nullptr);
  gtk_icon_theme_append_search_path(gtk_icon_theme_get_default(), icon_dir);
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.
  my_application_register_bundled_icon_theme();

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Persist the last-known window geometry so the next launch restores it.
  my_application_save_window_state(self);

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_chrome_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  // Sentinels for "nothing tracked yet" (0,0 is a valid position, so x/y use
  // -1); the save helper skips writing until a real size is observed.
  self->window_width = -1;
  self->window_height = -1;
  self->window_x = -1;
  self->window_y = -1;
  self->window_maximized = FALSE;
  self->window_chrome_channel = nullptr;
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
