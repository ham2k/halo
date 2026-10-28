# Builds the plugin library with miniaudio compiled into it — one
# translation unit, halo_audio.c, so there is nothing separate to locate,
# ship or sign.
cmake_minimum_required(VERSION 3.10)

project(halo_audio_library VERSION 0.0.1 LANGUAGES C)

add_library(halo_audio SHARED "halo_audio.c")

set_target_properties(halo_audio PROPERTIES
  PUBLIC_HEADER halo_audio.h
  OUTPUT_NAME "halo_audio"
  C_VISIBILITY_PRESET hidden
)

target_compile_definitions(halo_audio PUBLIC DART_SHARED_LIB)
target_compile_definitions(halo_audio PRIVATE NDEBUG)

if (MSVC)
  target_compile_definitions(halo_audio PRIVATE _CRT_SECURE_NO_WARNINGS)
  # A PDB for the Release build, so a native crash in the audio layer can be
  # symbolicated (see halo_quickjs's src/CMakeLists.txt for why the flags
  # live here and not in app/windows/CMakeLists.txt).
  target_compile_options(halo_audio PRIVATE $<$<CONFIG:Release>:/Zi>)
  target_link_options(halo_audio PRIVATE $<$<CONFIG:Release>:/DEBUG>)
elseif (UNIX)
  # miniaudio dlopens ALSA, PulseAudio and JACK at runtime: no build-time
  # dependency on any of them.
  target_link_libraries(halo_audio pthread m dl)
endif()
