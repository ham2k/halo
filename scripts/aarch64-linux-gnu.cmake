# CMake toolchain for cross-compiling to aarch64 against a Debian MULTIARCH
# sysroot (dpkg --add-architecture arm64), as opposed to a self-contained
# sysroot from debootstrap.
#
# The distinction is the whole reason this file exists. With multiarch there is
# no single directory holding the target system:
#
#   target libraries  -> /usr/lib/aarch64-linux-gnu/        (per-arch)
#   target headers    -> /usr/include/                      (SHARED with host)
#   toolchain sysroot -> /usr/aarch64-linux-gnu/            (libc and little else)
#
# Pointing CMAKE_FIND_ROOT_PATH at the toolchain sysroot alone - the obvious
# reading of "where is the target system" - puts /usr/include outside the
# search root, so every find_package that needs a header fails while its
# library sits happily in place. That is exactly how this first failed:
#
#   Could NOT find CURL (missing: CURL_LIBRARY CURL_INCLUDE_DIR)
#
# with libcurl4-openssl-dev:arm64 installed the whole time.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

# Makes CMake search /usr/lib/<triplet> FIRST, which is what keeps it from
# picking up the host's x86-64 libraries out of the shared /usr tree.
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)

# clang, NOT aarch64-linux-gnu-gcc, and the reason is Flutter rather than taste.
#
# `flutter assemble`'s dart_build step builds a C compiler config for the code
# assets/build-hooks pipeline, and it does it unconditionally for a native app
# build - no package needs to HAVE a hook. It reads CMAKE_CXX_COMPILER out of
# our CMakeCache.txt, resolves symlinks, and then requires a sibling file
# literally named `clang`:
#
#   final File clangFile = clangPpFile.parent.childFile('clang');
#   if (!clangFile.existsSync()) throwToolExit('Expected to find clang next to ...')
#     - flutter_tools/lib/src/isolated/native_assets/linux/native_assets.dart:89
#
# With gcc that lookup either fails outright or - worse - finds the HOST's
# /usr/bin/clang and hands the hook pipeline an x86-64 compiler for an arm64
# build. clang is a cross compiler by construction, so `clang`/`clang++` sit
# side by side. Native build hooks must also set --target explicitly: Flutter
# forwards the compiler paths, but not CMake's compiler target/toolchain flags.
#
# find_program, NOT set(): a plain set() in a toolchain file creates a NORMAL
# variable. CMake then records the compiler in CMakeFiles/*/CMakeCXXCompiler.cmake
# and writes NO CMakeCache.txt entry, which is exactly the failure this replaces:
#
#   Target dart_build failed: Error: Expected .../CMakeCache.txt to contain an
#   entry for CMAKE_CXX_COMPILER
#
# find_program caches, and caches the ABSOLUTE path - which matters twice over,
# because Flutter also does existsSync() on whatever it reads. Verified against
# cmake directly: set() leaves no entry, find_program yields
# `CMAKE_CXX_COMPILER:STRING=/usr/bin/clang++`.
find_program(CMAKE_C_COMPILER NAMES clang REQUIRED)
find_program(CMAKE_CXX_COMPILER NAMES clang++ REQUIRED)

# Cross-compilation is a flag to clang, not a separate binary. CMake turns these
# into --target=, and CMAKE_*_COMPILER_EXTERNAL_TOOLCHAIN into --gcc-toolchain=,
# which is what points clang at the aarch64 crt files, libgcc and libstdc++ that
# gcc-aarch64-linux-gnu installs. Without the latter clang finds the host's and
# fails at link time, long after everything has configured cleanly.
set(CMAKE_C_COMPILER_TARGET aarch64-linux-gnu)
set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-gnu)
set(CMAKE_C_COMPILER_EXTERNAL_TOOLCHAIN /usr)
set(CMAKE_CXX_COMPILER_EXTERNAL_TOOLCHAIN /usr)

# ASM is a THIRD language, and CMAKE_ASM_COMPILER_TARGET does not work.
#
# sentry-native vendors libunwind, which enables ASM and ships per-arch .S
# files. With C and CXX targeted but ASM not, CMake ran plain `/usr/bin/clang`
# on aarch64 assembly with no --target at all, so clang assembled it as x86-64:
#
#   getcontext.S:42:14: error: expected ']' in brackets expression
#    str x29, [x0, #(0xb0 + 0x0f0)]
#
# The obvious repair - set(CMAKE_ASM_COMPILER_TARGET ...) - is silently ignored:
# CMake's ASM rules do not expand a target flag the way the C and CXX ones do.
# Verified by inspecting compile_commands.json: with only the _TARGET variable
# the .S command carries no --target, and with CMAKE_ASM_FLAGS_INIT it does.
# Hence the flags spelled out, and no _TARGET line that would imply otherwise.
set(CMAKE_ASM_FLAGS_INIT "--target=aarch64-linux-gnu --gcc-toolchain=/usr")

set(CMAKE_FIND_ROOT_PATH /usr/aarch64-linux-gnu /usr)

# Programs must come from the HOST - these are build tools (pkg-config, python,
# the Flutter tool), and an aarch64 one could not run here.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Libraries must come from the target tree only. Combined with
# CMAKE_LIBRARY_ARCHITECTURE above, the triplet directory wins.
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
# Headers are BOTH, deliberately: under multiarch the arch-independent headers
# every package actually includes live in the shared /usr/include.
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# pkg-config has to answer for the target too. Without this it reports the
# host's flags, everything configures cleanly, and the mismatch only appears at
# link time after a full compile.
set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "/")
