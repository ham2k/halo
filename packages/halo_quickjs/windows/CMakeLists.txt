cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "halo_quickjs")
project(${PROJECT_NAME} LANGUAGES CXX)

# quickjs + the shim are compiled into this one library (see ../src).
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(halo_quickjs_bundled_libraries
  $<TARGET_FILE:halo_quickjs>
  PARENT_SCOPE
)
