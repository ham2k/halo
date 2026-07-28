# Builds the plugin library with quickjs-ng compiled STATICALLY into it.
#
# There is deliberately no separate quickjs shared object. Every problem we
# had with flutter_js — the hand re-bundling in app/linux/CMakeLists.txt, the
# LD_LIBRARY_PATH hack in scripts/test.sh, the CI safety-net copy, and the
# x86-64-only prebuilt that blocked ARM64 entirely — came from quickjs
# arriving as a separate, prebuilt, dlopen'd library. Compiling it in means
# there is nothing to locate, ship, sign, or get out of sync, and the
# architecture is whatever the platform toolchain is already targeting.
#
# Build cost is ~5 CPU-seconds for the four quickjs translation units, and
# CMake caches objects, so this is noise against a Flutter build. See
# docs/design/js-engine.md §2.
cmake_minimum_required(VERSION 3.10)

project(halo_quickjs_library VERSION 0.0.1 LANGUAGES C)

add_library(halo_quickjs SHARED
  "halo_qjs.c"
  "quickjs/quickjs.c"
  "quickjs/libregexp.c"
  "quickjs/libunicode.c"
  "quickjs/dtoa.c"
)

target_include_directories(halo_quickjs PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/quickjs")

set_target_properties(halo_quickjs PROPERTIES
  PUBLIC_HEADER halo_qjs.h
  OUTPUT_NAME "halo_quickjs"
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(halo_quickjs PUBLIC DART_SHARED_LIB)

# quickjs-ng needs these; _GNU_SOURCE is what its own CMakeLists sets.
if (NOT WIN32)
  target_compile_definitions(halo_quickjs PRIVATE _GNU_SOURCE)
endif()

if (MSVC)
  # quickjs.c gates C11 atomics on `!__STDC_NO_ATOMICS__` — note the missing
  # defined(), so an UNDEFINED macro reads as 0 and the branch is taken. MSVC
  # only defines __STDC_NO_ATOMICS__ in C11/C17 mode, so without /std:c11 the
  # default C mode pulls in <stdatomic.h> and the _Atomic keyword it does not
  # support, and the build fails outright. Upstream's own MSVC CI passes only
  # because their CMakeLists sets a C standard; ours has to say so too.
  #
  # /std:c11 alone is the whole fix: it makes MSVC define __STDC_NO_ATOMICS__,
  # CONFIG_ATOMICS preprocesses away, and we lose nothing — the extension
  # sandbox is single-threaded with no SharedArrayBuffer. Deliberately NOT
  # using /experimental:c11atomics, which would keep the atomics we don't want
  # and narrow us to VS2022 17.5+.
  #
  # Spelled as a raw flag rather than C_STANDARD 11: CMake only learned to map
  # C_STANDARD onto MSVC in 3.20, and this file targets 3.10.
  target_compile_options(halo_quickjs PRIVATE /std:c11)
  target_compile_definitions(halo_quickjs PRIVATE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_DEPRECATE)
endif()

# Release builds only; a debug-assert build of quickjs is far slower and we
# never want it in a shipped app.
# Makes C_VISIBILITY_PRESET above actually bite: quickjs marks its whole API
# visibility("default"), which overrides the preset, so without this the library
# exported 248 JS_* symbols despite asking for hidden. See the HALO LOCAL PATCH
# in src/quickjs/quickjs.h.
target_compile_definitions(halo_quickjs PRIVATE HALO_QJS_HIDE_INTERNALS)

target_compile_definitions(halo_quickjs PRIVATE NDEBUG)

if (ANDROID)
  # Android 15 16k page size
  target_link_options(halo_quickjs PRIVATE "-Wl,-z,max-page-size=16384")
  # quickjs uses libm
  target_link_libraries(halo_quickjs m)
elseif (UNIX)
  target_link_libraries(halo_quickjs m)
endif()
