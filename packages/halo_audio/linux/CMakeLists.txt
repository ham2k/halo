cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "halo_audio")
project(${PROJECT_NAME} LANGUAGES CXX)

# miniaudio + the shim are compiled into this one library (see ../src).
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(halo_audio_bundled_libraries
  $<TARGET_FILE:halo_audio>
  PARENT_SCOPE
)
