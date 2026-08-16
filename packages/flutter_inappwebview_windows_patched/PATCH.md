# Vendored `flutter_inappwebview_windows` 0.7.0-beta.3, one destructor changed

This is a copy of upstream's package. Every file it carries is byte-identical
to the published one except
`windows/custom_platform_view/custom_platform_view.cc`'s
`CustomPlatformView` destructor.

```diff
   CustomPlatformView::~CustomPlatformView()
   {
     debugLog("dealloc CustomPlatformView");
     event_sink_ = nullptr;
+    if (texture_bridge_) {
+      texture_bridge_->Stop();
+      texture_bridge_->SetOnFrameAvailable(nullptr);
+    }
-    texture_registrar_->UnregisterTexture(texture_id_, nullptr);
+    auto bridge = std::shared_ptr<TextureBridge>(std::move(texture_bridge_));
+    auto texture = std::shared_ptr<flutter::TextureVariant>(std::move(flutter_texture_));
+    texture_registrar_->UnregisterTexture(texture_id_, [bridge, texture]() {});
   }
```

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

## Verifying this copy

Everything except the hunk above must match the published package. Diff
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

A clean run prints only the destructor hunk above.

## No local verification

Nothing in `./scripts/test.sh` compiles C++ or runs on Windows — this repo
has no Windows build environment at all outside Codemagic. This copy is
verified only by a tag-triggered Windows release and Sentry staying quiet
on the `EXCEPTION_STACK_BUFFER_OVERRUN`/`FAST_FAIL_FATAL_APP_EXIT` signature
afterward. There was never a local repro for the crash this fixes either
(HALO-290's prior passes), so this is consistent with how that card has
been verified throughout.

## Re-vendoring a newer version

Copy the new package over this directory, drop its `example/`, re-apply the
destructor change if upstream hasn't fixed the underlying race itself
(check the destructor first — a fix might land under a different shape),
update the version above and in the archive URL, and re-run the diff. Do
not hand-merge — this directory is a copy, not a maintained fork.

**If the clock-discipline check flags a file in here, do not fix the
file.** Same exemption rule as `flutter_inappwebview_macos_patched` — add
this package's name to `check_clock_discipline`'s exemption list rather
than editing a vendored copy.

## Deleting this

Drop the directory once an upstream release fixes the same race (check the
destructor, not just the version number — a bump alone proves nothing) —
along with **both** `flutter_inappwebview_windows` override entries, the one
in `app/pubspec.yaml` and the one in `app_dist/pubspec.yaml`.
