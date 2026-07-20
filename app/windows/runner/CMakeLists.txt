cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Build edition (docs/releases.md §2.6): dev | next | prod, read from the
# HALO_EDITION environment variable (CI sets it; defaults to dev) — the Windows
# counterpart of the macOS/iOS HALO_EDITION seam. Drives the product name
# (window title + VERSIONINFO) and the app icon, via the generated
# halo_edition.h that both main.cpp and Runner.rc include.
if(DEFINED ENV{HALO_EDITION} AND NOT "$ENV{HALO_EDITION}" STREQUAL "")
  set(HALO_EDITION "$ENV{HALO_EDITION}")
else()
  set(HALO_EDITION "dev")
endif()
if(HALO_EDITION STREQUAL "prod")
  set(HALO_PRODUCT_NAME "Windows Logger")
elseif(HALO_EDITION STREQUAL "next")
  set(HALO_PRODUCT_NAME "Windows Logger Next")
else()
  set(HALO_EDITION "dev")
  set(HALO_PRODUCT_NAME "Windows Logger (Dev)")
endif()
set(HALO_APP_ICON_FILE "app_icon-${HALO_EDITION}.ico")
configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/halo_edition.h.in"
  "${CMAKE_CURRENT_BINARY_DIR}/halo_edition.h"
  @ONLY)
# So both main.cpp (C++) and Runner.rc (RC) can #include the generated header.
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
# SetWindowSubclass/DefSubclassProc (win32_window.cpp's chromeless top-edge
# resize forwarding).
target_link_libraries(${BINARY_NAME} PRIVATE "comctl32.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
