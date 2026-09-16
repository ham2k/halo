# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(ham2k_logger LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "ham2k_logger")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE -D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
  target_compile_definitions(${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# A Release crash inside a plugin resolves in Sentry to the nearest exported
# symbol unless that plugin ships a PDB, and MSVC emits the linked PDB only
# when the LINKER gets /DEBUG -- /Zi alone leaves compiler-side PDBs that the
# Windows release pipeline never finds. Without both, a frame in a plugin DLL
# reads as <unknown>, and a native crash there can only be attributed by
# elimination.
#
# Applied here rather than per plugin because most of them are pub-cache
# packages we do not vendor, and generated_plugins.cmake is regenerated on
# every build. FLUTTER_PLUGIN_LIST is what that file defines, so this covers
# whatever the current plugin set happens to be.
#
# The release pipeline uploads symbols from build/windows/x64/runner/Release
# and build/windows/x64/plugins only, and refuses to ship a *_plugin.dll whose
# *_plugin.pdb it cannot find under the latter. A plugin whose PDB lands
# anywhere else is outside the sweep, and the build says so.
#
# A plugin that ships no native code of its own registers <name>_plugin as an
# ALIAS to another target (sentry_flutter aliases sentry-native's `sentry`),
# and CMake hard-errors on any target_* call against an alias. Those carry no
# plugin DLL to symbolize, so skip them.
foreach(plugin ${FLUTTER_PLUGIN_LIST})
  get_target_property(plugin_alias_target ${plugin}_plugin ALIASED_TARGET)
  if(NOT plugin_alias_target)
    target_compile_options(${plugin}_plugin PRIVATE $<$<CONFIG:Release>:/Zi>)
    target_link_options(${plugin}_plugin PRIVATE $<$<CONFIG:Release>:/DEBUG>)
  endif()
endforeach(plugin)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# The Visual C++ runtime, deployed app-local (HALO-568).
#
# A Flutter Windows build links the MSVC runtime DYNAMICALLY, so a machine
# without the "Visual C++ 2015-2022 Redistributable" cannot start the app at
# all: the loader fails before a single line of our code runs, with a system
# dialog naming a missing VCRUNTIME140_1.dll and suggesting the one remedy that
# cannot work ("reinstalling the program"). Nothing the app itself could do
# runs early enough to catch that, so the runtime has to be in the bundle.
#
# App-local -- the DLLs sit beside the exe, where the loader looks first --
# rather than a VC_redist.exe bootstrapper, because the Windows installer is
# deliberately per-user and never elevates (that is what lets an update install
# without a UAC prompt), and because the portable ZIP has no installer to run
# one from. Microsoft's redistributable licence covers this deployment mode.
#
# UCRT is excluded: ucrtbase and the api-ms-win-crt-* set are part of Windows
# itself from Windows 10 on, which is already the floor.
#
# _SKIP so the module contributes no install rule of its own -- its default
# lands the DLLs in a `bin/` subdirectory, where app-local resolution never
# looks. Redirecting that rule with CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION
# would be one line, but it takes no CONFIGURATIONS, so a Debug build would
# carry release CRT DLLs its exe cannot use.
set(CMAKE_INSTALL_UCRT_LIBRARIES FALSE)
set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
include(InstallRequiredSystemLibraries)

# A warning rather than a hard error, because the list comes up empty only when
# this machine's Visual Studio carries no redistributable directory, and a
# developer building locally already HAS the runtime installed system-wide:
# failing here would break their build over a file they do not need.
#
# Know what that costs: `flutter build windows` streams the CONFIGURE step at
# trace level, so this message is invisible without `flutter --verbose`. A
# release built outside the release pipeline is therefore unguarded -- and a
# non-empty list is not a complete one either. The pipeline is where both are
# caught, by checking the packaged output for the DLLs the loader demands;
# a shipped bundle missing them is the whole bug this block exists to prevent.
if(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS)
  install(FILES ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    CONFIGURATIONS Profile;Release
    COMPONENT Runtime)
else()
  message(WARNING "No Visual C++ redistributable found to bundle: a Release build from this machine will not run on a machine without the runtime installed.")
endif()
