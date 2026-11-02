cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "halo_sdr_usb")
project(${PROJECT_NAME} LANGUAGES C CXX)

# The shim and the Airspy libraries are compiled into one library (see
# ../src); libusb is a DLL of its own, shipped beside it.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

set(halo_sdr_usb_bundled_libraries
  $<TARGET_FILE:halo_sdr_usb>
  "${HSU_LIBUSB_DLL}"
  PARENT_SCOPE
)
