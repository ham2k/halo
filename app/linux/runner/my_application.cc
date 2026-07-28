#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

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
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// ── Remember the window's geometry across launches ──────────────────────────
// Linux keeps native chrome and has no window-chrome channel, so window state
// is persisted here in the runner: a small key file under the user's config
// dir, written on shutdown and restored (size + position + maximized) in
// activate before the window is shown, so there's no launch flash.

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

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, HALO_PRODUCT_NAME);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, HALO_PRODUCT_NAME);
  }

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
