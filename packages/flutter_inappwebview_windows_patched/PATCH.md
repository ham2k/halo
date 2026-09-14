# Vendored `flutter_inappwebview_windows` 0.7.0-beta.3, eight files changed

This is a copy of upstream's package. Every file it carries is byte-identical
to the published one except
`windows/custom_platform_view/custom_platform_view.cc`'s
`CustomPlatformView` destructor and constructor (and the constructor's
declaration in `custom_platform_view.h`), the two `CustomPlatformView`
constructions in `windows/in_app_webview/in_app_webview_manager.cpp`'s
`createInAppWebView` plus one hunk in its keep-alive branch,
`windows/webview_environment/webview_environment.cpp`'s
`WebViewEnvironment` destructor, one method and one constructor argument
added to `windows/flutter_inappwebview_windows_plugin.h`/`.cpp` with the
argument supplied from `windows/flutter_inappwebview_windows_plugin_c_api.cpp`,
and two build-settings lines added to `windows/CMakeLists.txt`.

```diff
   CustomPlatformView::~CustomPlatformView()
   {
     debugLog("dealloc CustomPlatformView");
+    if (event_channel_ && plugin_ && plugin_->isMessengerAvailable()) {
+      event_channel_->SetStreamHandler(nullptr);
+    }
     event_sink_ = nullptr;
     if (texture_bridge_) {
       texture_bridge_->Stop();
       texture_bridge_->SetOnFrameAvailable(nullptr);
     }
-    texture_registrar_->UnregisterTexture(texture_id_, nullptr);
+    auto bridge = std::shared_ptr<TextureBridge>(std::move(texture_bridge_));
+    auto texture = std::shared_ptr<flutter::TextureVariant>(std::move(flutter_texture_));
+    texture_registrar_->UnregisterTexture(texture_id_, [bridge, texture]() {});
   }
```

```diff
     if (keepAliveId.has_value() && map_contains(keepAliveWebViews, keepAliveId.value())) {
-      auto webView = std::move(keepAliveWebViews.at(keepAliveId.value())->view);
-      keepAliveWebViews.erase(keepAliveId.value());
+      auto oldPlatformView = keepAliveWebViews.at(keepAliveId.value()).get();
+      auto webView = std::move(oldPlatformView->view);
+      oldPlatformView->UnregisterMethodCallHandler();
+      keepAliveWebViews.erase(keepAliveId.value());
```

```diff
   WebViewEnvironment::~WebViewEnvironment()
   {
     debugLog("dealloc WebViewEnvironment");
+    if (channelDelegate && plugin && plugin->isMessengerAvailable()) {
+      channelDelegate->UnregisterMethodCallHandler();
+    }
     if (environment_) {
```

```diff
+  bool FlutterInappwebviewWindowsPlugin::isMessengerAvailable() const
+  {
+    return messenger_ref_ != nullptr && FlutterDesktopMessengerIsAvailable(messenger_ref_);
+  }
```

```diff
   flutter_inappwebview_plugin::FlutterInappwebviewWindowsPlugin::RegisterWithRegistrar(
     flutter::PluginRegistrarManager::GetInstance()
-    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
+    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar),
+    FlutterDesktopPluginRegistrarGetMessenger(registrar));
```

with the `FlutterDesktopMessengerRef` threaded through `RegisterWithRegistrar`
and the constructor into a `messenger_ref_` member, and `CustomPlatformView`
taking the plugin as a new first constructor argument (kept as `plugin_`) at
both of `createInAppWebView`'s `std::make_unique<CustomPlatformView>(...)`
sites, so its destructor has something to ask.

```diff
 flutter_inappwebview_windows_apply_standard_settings(${PLUGIN_NAME})

+target_compile_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/Zi>)
+target_link_options(${PLUGIN_NAME} PRIVATE $<$<CONFIG:Release>:/DEBUG>)
+
 target_link_libraries(${PLUGIN_NAME} PRIVATE ${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/build/native/Microsoft.Web.WebView2.targets)
```

This last hunk is instrumentation, not a bugfix: MSVC's default Release flags
carry no debug info, so without it a crash whose actual site is inside this
plugin's own code resolves in Sentry the same way a crash inside the Flutter
engine does — nearest-export only, no line, no non-exported frames. Mirrors
`app/windows/runner/CMakeLists.txt`'s identical two lines, added for the same
reason (HALO-290). `app_dist/ci/build-windows.ps1`'s debug-symbol upload step
scans the whole `build/windows/x64` tree, not just `runner/Release`, because
this is exactly why: the PDB this hunk produces lands in this plugin's own
CMake build subdirectory, not copied alongside the DLL into `Release/` by the
bundling step.

Upstream's `example/` is left out, same as the macOS copy — a whole Flutter
app nothing here reads. Only `lib/` and `windows/` are consumed by the
`dependency_overrides` entries that point here (`pubspec.yaml`, `LICENSE`,
`README.md`, `CHANGELOG.md`, `analysis_options.yaml` travel along because
`flutter pub get` expects a complete package, not because anything reads
them).

`dependency_overrides` bind only in the package resolved as root, so this
directory is named twice: once in `app/pubspec.yaml` and once in
`app_dist/pubspec.yaml`, exactly like the macOS entry — see
`app/pubspec.yaml`'s comment above `dependency_overrides` and
`app_dist/test/webview_override_parity_test.dart`.

## Why

`flutter::TextureRegistrar::UnregisterTexture(texture_id, callback)` is
documented as asynchronous: on Windows it posts the actual removal to the
**raster thread** (`FlutterWindowsTextureRegistrar::UnregisterTexture`,
`shell/platform/windows/flutter_windows_texture_registrar.cc`), and the
optional `callback` fires only once that task runs — specifically to let
the caller know when it is safe to free anything the texture's callback
still references.

The unpatched destructor passes `nullptr` for that callback and returns
immediately, so `texture_bridge_` and `flutter_texture_` (both plain member
`unique_ptr`s) are freed as this object finishes destructing — while the
raster thread may still be mid-flight calling into the
`GpuSurfaceTexture`/`PixelBufferTexture` callback captured in
`flutter_texture_`, which reaches into `texture_bridge_` via a raw pointer
(`custom_platform_view.cc`'s constructor: `bridge =
static_cast<TextureBridgeGpu*>(texture_bridge_.get())`). That is a
use-after-free racing the engine's own compositor thread, and it does not
need an unlucky user action to trigger — only that the window (and with it
the whole platform view) closes while the webview is still delivering
frames, which is the common case for a user simply quitting the app.

Sentry evidence (`HALO-290` / `HALO-NEXT-3` / `HALO-NEXT-58`): every
Windows-only, otherwise-unexplained
`EXCEPTION_STACK_BUFFER_OVERRUN`/`FAST_FAIL_FATAL_APP_EXIT` crash captured
since the MapLibre webview work landed shows the same shape once a PDB and a
retained minidump exist to read it — `Win32Window::Destroy` →
`FlutterWindow::OnDestroy` → `FlutterDesktopViewControllerDestroy` →
`FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable` /
`InternalFlutterGpu_Texture_AsImage` frames on a thread that is mid
window-teardown, with the actual crashing thread itself unresolvable (a
stack the fastfail already corrupted). No `msedgewebview2.exe`/`.dll` module
appears in the retained minidump, ruling out a WebView2-runtime cause.

The fix keeps `texture_bridge_` and `flutter_texture_` alive — via
`shared_ptr`s captured in the completion callback — until the engine
confirms it holds no more references, instead of freeing them on the
calling (UI) thread the instant `CustomPlatformView` is destroyed. It does
not block: the callback the raster thread invokes owns the last reference
and simply lets it go, so shutdown is never delayed waiting for a task that
Flutter's own comment on `UnregisterTexture` documents as not guaranteed to
run before the engine itself finishes tearing down (in that case the copies
are released whenever the empty lambda gets destroyed, which is still no
worse than the original code — and does not use-after-free either way).

Keeping `texture_bridge_` alive past `CustomPlatformView` opens a second,
narrower race that the first version of this patch missed: its
`SetOnFrameAvailable` callback (set in the constructor) captures `this` —
`[this]() { texture_registrar_->MarkTextureFrameAvailable(texture_id_); }`
— and `TextureBridge`'s own WGC capture thread keeps calling it for as long
as the bridge is running, which is now longer than `CustomPlatformView`
itself lives. The `Stop()` call added above closes this: `Stop()` and
`OnFrameArrived` share `texture_bridge_`'s own mutex, so once `Stop()`
returns no call into the `[this]` capture is in flight and `is_running_`
being false stops any future one before it reaches `frame_available_()`.
`SetOnFrameAvailable(nullptr)` on top is redundant given that guard, kept
only so nothing reachable from `texture_bridge_` still names a
`CustomPlatformView` that may no longer exist.

`Stop()` also runs the WGC/D3D teardown (`remove_FrameArrived`,
`IClosable::Close()` on `capture_session_`) synchronously, on the UI thread,
before the deferred destruction is even scheduled — so what the raster
thread's completion callback actually releases later is inert by the time
it runs: a closed capture session and COM references dropping ref counts,
not a live capture pipeline. `TextureBridgeGpu`'s `graphics_context_` member
is a raw pointer into `InAppWebViewManager`'s static `GraphicsContext`
(`in_app_webview_manager.h`), which nothing in this destructor path
dereferences — the deferred destructor releases COM references only.

## The messenger callback race (event channel + keep-alive reuse)

The texture-destructor fix above stopped the raster thread from touching a
freed `CustomPlatformView`, but it left two paths where the plugin's own
`FlutterBinaryMessenger` registrations (`SetMethodCallHandler`,
`SetStreamHandler` — every `[this]`-capturing callback the constructor
installs) could still reference a destroyed `CustomPlatformView`:

1. **The event channel was never unregistered.** `UnregisterMethodCallHandler()`
   (called explicitly by the `dispose`/`disposeKeepAlive` method handlers in
   `in_app_webview_manager.cpp`, before erasing the platform view) only
   clears `method_channel_`. Nothing — not that method, not the destructor —
   ever called `event_channel_->SetStreamHandler(nullptr)`. Every dispose of
   a webview-backed pane left a dangling `[this]` capture registered in the
   messenger's internal callback map.
2. **The keep-alive reuse path skipped unregistration entirely.**
   `createInAppWebView`'s keep-alive branch destroys the previous
   `CustomPlatformView` for a reused `keepAliveId` via
   `keepAliveWebViews.erase(...)` directly, without calling
   `UnregisterMethodCallHandler()` first — unlike every other teardown path
   in this file. The new `CustomPlatformView` constructed right after
   registers its own method/event channels while the old one's are, per (1),
   never cleared either.
3. **`WebViewEnvironment` had the same gap as (1), for its own channel.**
   `~WebViewEnvironment()` never unregistered its `channelDelegate`'s method
   channel — same missing-safety-net shape as the event channel above, just
   on a different owner. `ChannelDelegate` (`types/channel_delegate.cpp`) is
   the shared base every delegate type in this plugin uses, and its own
   destructor only resets a `shared_ptr<MethodChannel>`, never calling
   `SetMethodCallHandler(nullptr)` — so the bug class is systemic across
   every subclass unless each owner explicitly unregisters before tearing
   one down. `InAppWebView`'s own teardown already does this correctly for
   every delegate it owns (`webMessageChannels_`, `webMessageListeners_`,
   `printJobManager`, `webNotificationControllers_`,
   `findInteractionController`, plus its own `WebViewChannelDelegate` via (1)
   and this file's other unregister call sites) — `WebViewEnvironment` was
   the one owner that didn't. Not reachable on HaLo's current map/webview
   hot path (HaLo builds exactly one static `WebViewEnvironment` for the
   whole app lifetime and never disposes/recreates it), but real: this
   plugin's own `"dispose"` method handler
   (`webview_environment_channel_delegate.cpp`) erases the environment live,
   with the handler still registered.

Sentry evidence (`HALO-290` / `HALO-NEXT-59`): `FlutterDesktopMessengerSetCallback`
→ `free_base` → `base::internal::flat_tree<T>::erase<T>`,
`EXCEPTION_ACCESS_VIOLATION_READ`, still recurring on the build that shipped
the texture-destructor fix. The messenger's channel-name → callback registry
is a `flat_tree` (sorted vector), not built for a dangling entry to survive a
later insert/erase that reallocates its backing storage — exactly what a
leaked `SetStreamHandler` registration, plus a keep-alive reuse that never
even attempts to clear the old one, sets up.

The fix makes the destructor unregister the event channel unconditionally —
a safety net, not dependent on any caller remembering to do it. (Not the
same fix as `ChannelDelegate`'s destructor in `types/channel_delegate.cpp`:
that one only resets its `shared_ptr<MethodChannel>`, which doesn't
unregister from the messenger either — the same leak class this patch
exists to fix, not a precedent it follows.) The keep-alive reuse path now
also calls `UnregisterMethodCallHandler()` before erasing the old
`CustomPlatformView` — but only after moving its `view` out first, so the
method-channel clear it triggers happens while `view` is already null. That
ordering matters: `UnregisterMethodCallHandler()` reaches into
`view->channelDelegate` only when `view` is still held, and the reused
`InAppWebView` needs to keep its delegate's handler intact (no
`initChannel` runs on this branch) — so this clears only the old
`CustomPlatformView`'s own method channel, not the delegate `disposeKeepAlive`
also clears when it destroys the webview outright. `WebViewEnvironment`'s
destructor gets the same unconditional-safety-net treatment as the event
channel — `channelDelegate->UnregisterMethodCallHandler()`, not left to a
caller — since (unlike `CustomPlatformView`'s `view`) nothing about
`WebViewEnvironment`'s teardown needs its delegate's handler to survive.

## The teardown guard (engine gone before plugins)

The two unregister-in-destructor hunks above are exactly right while the
engine is alive and a null dereference once it is not. On Windows the
engine's destructor runs `messenger_->SetEngine(nullptr)` FIRST and only then
`Stop()`, which is what destroys every plugin
(`shell/platform/windows/flutter_windows_engine.cc`). So by the time
`~FlutterInappwebviewWindowsPlugin` tears down its managers — and with them
every `WebViewEnvironment` and `CustomPlatformView` — the messenger no longer
reaches an engine, and `FlutterDesktopMessengerSetCallback` reads through
that null pointer: it only `FML_DCHECK`s `FlutterDesktopMessengerIsAvailable`,
which is compiled out of Release (`flutter_windows.cc`). The read lands at
offset `0x1e8` — `message_dispatcher_`'s slot in `FlutterWindowsEngine` — on
every quit of a session that ever hosted a webview.

Sentry evidence (`HALO-394` / `HALO-NEXT-71`, `72`, `76`, earlier grouped as
`HALO-NEXT-5S`/`5W`/`59` before engine symbols resolved):
`FlutterDesktopMessengerSetCallback (flutter_windows.cc:407)` →
`FlutterWindowsEngine::message_dispatcher` → `std::unique_ptr<T>::get`,
`EXCEPTION_ACCESS_VIOLATION_READ / 0x1e8`, under
`FlutterDesktopViewControllerDestroy` → `~FlutterWindowsEngine` → `Stop`,
first seen on the build that shipped the `~WebViewEnvironment` hunk. No
published plugin in this app unregisters a channel from a destructor; these
two hunks were the only callers.

The guard asks the engine rather than keeping a flag of its own:
`FlutterDesktopMessengerIsAvailable` is the engine's own record of whether
`SetEngine(nullptr)` has run. The raw `FlutterDesktopMessengerRef` it needs
is in hand only at the C entry point — the C++ wrapper keeps
`PluginRegistrar::registrar()` protected, so a plugin cannot reach it later —
which is why `flutter_inappwebview_windows_plugin_c_api.cpp` takes
`FlutterDesktopPluginRegistrarGetMessenger(registrar)` there and hands it
in. The ref is not AddRef'd: the engine holds its own reference until after
`Stop()` has destroyed the plugin, so it outlives every use here. A flag set
at the top of the plugin destructor would be true at the same moments today
and would be one more thing to keep in step with the engine's teardown
order. Skipping the unregister is safe in that state: the callback map it
would have been removed from dies with the engine an instant later, and
nothing can dispatch into it in between.

## Verifying this copy

Everything except the hunks above must match the published package. Diff
against a freshly extracted archive, **never against `~/.pub-cache`** — a
build writes generated files into the cached copy too, so contamination on
both sides cancels out. Run from the repo root:

```sh
upstream=$(mktemp -d)
curl -sSL https://pub.dev/api/archives/flutter_inappwebview_windows-0.7.0-beta.3.tar.gz \
  | tar xz -C "$upstream"
diff -r -x example -x PATCH.md \
     "$upstream" packages/flutter_inappwebview_windows_patched
```

A clean run prints only the hunks above.

## No local verification

Nothing in `./scripts/test.sh` compiles C++ or runs on Windows — this repo
has no Windows build environment at all outside Codemagic. This copy is
verified only by a tag-triggered Windows release and Sentry staying quiet
on the `EXCEPTION_STACK_BUFFER_OVERRUN`/`FAST_FAIL_FATAL_APP_EXIT` and
`EXCEPTION_ACCESS_VIOLATION`/`FlutterDesktopMessengerSetCallback` signatures
afterward. There was never a local repro for either crash this fixes
(HALO-290's prior passes), so this is consistent with how that card has
been verified throughout.

## Re-vendoring a newer version

Copy the new package over this directory, drop its `example/`, re-apply the
CMakeLists.txt PDB hunk unconditionally (it's instrumentation, not a bugfix —
keep it regardless of what upstream has changed), and re-apply the race-fix
hunks if upstream hasn't fixed the underlying races itself (check
`CustomPlatformView`'s destructor, the keep-alive branch of
`createInAppWebView`, and `WebViewEnvironment`'s destructor first — a fix
might land under a different shape, and check whether `ChannelDelegate`
itself finally unregisters in its own destructor, which would obsolete all
three at once). Whatever shape they take, any unregister that can run from a
destructor keeps the `isMessengerAvailable()` guard, or the quit crash comes
back with the engine teardown order unchanged. Update the version above and
in the archive URL, and re-run the diff. Do not hand-merge — this directory
is a copy, not a maintained fork.

**If the clock-discipline check flags a file in here, do not fix the
file.** Same exemption rule as `flutter_inappwebview_macos_patched` — add
this package's name to `check_clock_discipline`'s exemption list rather
than editing a vendored copy.

## Deleting this

Drop the directory once an upstream release fixes the same races and guards
its own teardown against a messenger whose engine is gone (check the hunks,
not just the version number — a bump alone proves nothing) — along with
**both** `flutter_inappwebview_windows` override
entries, the one in `app/pubspec.yaml` and the one in `app_dist/pubspec.yaml`.
The PDB hunk isn't a reason to keep this directory on its own: if the other
three are ever gone, drop the vendored copy and get the same debug info by
adding the same two `target_compile_options`/`target_link_options` lines as a
patch on the *published* package instead (or upstream them).
