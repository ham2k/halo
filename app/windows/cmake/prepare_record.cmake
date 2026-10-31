# Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
# SPDX-License-Identifier: MPL-2.0

get_filename_component(_halo_record_root "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(_halo_record_packages "${_halo_record_root}/app/.dart_tool/package_config.json")
set(_halo_record_dart "${FLUTTER_ROOT}/bin/cache/dart-sdk/bin/dart")
if(CMAKE_HOST_WIN32)
  string(APPEND _halo_record_dart ".exe")
endif()

if(NOT EXISTS "${_halo_record_dart}" OR NOT EXISTS "${_halo_record_packages}")
  message(FATAL_ERROR "Recorder preparation requires Flutter's SDK and app package configuration. Run flutter pub get before configuring Windows directly.")
endif()

message(STATUS "Preparing pinned recorder sources")
execute_process(
  COMMAND "${_halo_record_dart}" "--packages=${_halo_record_packages}"
    "${_halo_record_root}/packages/halo_build_tools/bin/prepare_record.dart"
  WORKING_DIRECTORY "${_halo_record_root}/packages/halo_build_tools"
  RESULT_VARIABLE _halo_record_result
  OUTPUT_VARIABLE _halo_record_output
  ERROR_VARIABLE _halo_record_error
)
if(NOT "${_halo_record_result}" STREQUAL "0")
  message(FATAL_ERROR "Recorder preparation failed (${_halo_record_result}):\n${_halo_record_output}\n${_halo_record_error}")
endif()

# A changed recipe must reconfigure even when the caller reuses a build tree.
if(NOT CMAKE_SCRIPT_MODE_FILE)
  file(GLOB_RECURSE _halo_record_inputs CONFIGURE_DEPENDS
    "${_halo_record_root}/dependencies/record/*")
  file(GLOB _halo_record_manifests CONFIGURE_DEPENDS
    "${_halo_record_root}/packages/record_*_patched/pubspec.yaml")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    ${_halo_record_inputs}
    ${_halo_record_manifests}
    "${_halo_record_root}/packages/record_android_patched/android/src/main/kotlin/com/ham2k/halo/record/HaloRecordPlugin.kt"
    "${_halo_record_root}/packages/halo_build_tools/bin/prepare_record.dart"
    "${_halo_record_root}/packages/halo_build_tools/lib/src/record_dependencies.dart"
    "${_halo_record_root}/packages/halo_build_tools/pubspec.yaml"
  )
endif()
