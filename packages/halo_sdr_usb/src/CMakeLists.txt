# Builds the plugin library: our shim, and on a build that has libusb, the
# Airspy libraries compiled in beside it. libusb stays a library of its own —
# it is LGPL-2.1 — and SDRplay's API is loaded at runtime, never linked.
cmake_minimum_required(VERSION 3.10)

project(halo_sdr_usb_library VERSION 0.0.1 LANGUAGES C)

set(HSU_AIRSPY_SOURCES
  "airspy/airspy.c"
  "airspy/iqconverter_float.c"
  "airspy/iqconverter_int16.c"
  "airspyhf/airspyhf.c"
  "airspyhf/iqbalancer.c"
)

add_library(halo_sdr_usb SHARED "halo_sdr_usb.c" "sdrplay.c")

set_target_properties(halo_sdr_usb PROPERTIES
  PUBLIC_HEADER halo_sdr_usb.h
  OUTPUT_NAME "halo_sdr_usb"
  C_VISIBILITY_PRESET hidden
  # The Airspy sources declare `typedef int bool;`, which C23 forbids.
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

target_include_directories(halo_sdr_usb PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_definitions(halo_sdr_usb PUBLIC DART_SHARED_LIB)
target_compile_definitions(halo_sdr_usb PRIVATE NDEBUG)

if (WIN32)
  # libusb's own release build (../windows/libusb), for the architecture
  # being built; Flutter copies the DLL next to the app.
  if (CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64" OR CMAKE_SYSTEM_PROCESSOR STREQUAL "ARM64")
    set(HSU_LIBUSB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../windows/libusb/arm64")
  else()
    set(HSU_LIBUSB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../windows/libusb/x64")
  endif()
  add_library(hsu_libusb SHARED IMPORTED)
  set_target_properties(hsu_libusb PROPERTIES
    IMPORTED_LOCATION "${HSU_LIBUSB_DIR}/libusb-1.0.dll"
    IMPORTED_IMPLIB "${HSU_LIBUSB_DIR}/libusb-1.0.lib"
  )
  set(HSU_LIBUSB_DLL "${HSU_LIBUSB_DIR}/libusb-1.0.dll" PARENT_SCOPE)

  target_sources(halo_sdr_usb PRIVATE ${HSU_AIRSPY_SOURCES})
  # win32/ holds the pthread.h MSVC lacks.
  target_include_directories(halo_sdr_usb PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/win32"
    "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/libusb/libusb"
  )
  # STATIC_AIRSPYHFPLUS: compiled in, not imported from a DLL of its own.
  target_compile_definitions(halo_sdr_usb PRIVATE _CRT_SECURE_NO_WARNINGS STATIC_AIRSPYHFPLUS)
  # advapi32: the registry, where SDRplay's installer says where its API is.
  target_link_libraries(halo_sdr_usb PRIVATE hsu_libusb advapi32)
  if (MSVC)
    # A PDB for the Release build, as halo_audio's, so a native crash here
    # can be symbolicated.
    target_compile_options(halo_sdr_usb PRIVATE $<$<CONFIG:Release>:/Zi>)
    target_link_options(halo_sdr_usb PRIVATE $<$<CONFIG:Release>:/DEBUG>)
  endif()
elseif (UNIX)
  # The system's libusb, which every desktop Linux ships. Without its
  # development files the build goes on without USB receivers, which then
  # say so, rather than failing.
  find_package(PkgConfig QUIET)
  if (PKG_CONFIG_FOUND)
    pkg_check_modules(HSU_LIBUSB IMPORTED_TARGET libusb-1.0)
  endif()
  if (HSU_LIBUSB_FOUND)
    target_sources(halo_sdr_usb PRIVATE ${HSU_AIRSPY_SOURCES})
    target_link_libraries(halo_sdr_usb PRIVATE PkgConfig::HSU_LIBUSB)
  else()
    message(WARNING "halo_sdr_usb: libusb-1.0 not found (install libusb-1.0-0-dev); building without USB receivers")
    target_compile_definitions(halo_sdr_usb PRIVATE HALO_SDR_USB_NO_USB)
  endif()
  target_link_libraries(halo_sdr_usb PRIVATE pthread m dl)
endif()
