#
# Compiles quickjs-ng + the shim directly into the app binary. There is no
# vendored_library and no separate dylib to sign or notarize — see
# docs/design/js-engine.md §2.1.
#
Pod::Spec.new do |s|
  s.name             = 'halo_quickjs'
  s.version          = '0.0.1'
  s.summary          = 'Direct dart:ffi binding to a statically-linked QuickJS-NG.'
  s.description      = <<-DESC
The JS engine behind the Ham2K Logger extension host: quickjs-ng compiled
into the app, bound through a flat C shim that keeps JSValue off the FFI
boundary.
                       DESC
  s.homepage         = 'https://ham2k.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sebastian Delmont' => 'sd@ham2k.com' }

  # Classes/ holds forwarders that relatively include ../src — podspec cannot
  # reference paths outside the pod directory.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'

  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # quickjs's own sources include each other by bare name.
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src" "$(PODS_TARGET_SRCROOT)/../src/quickjs"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) _GNU_SOURCE=1 NDEBUG=1',
    # quickjs is third-party C; its warnings are not ours to fix.
    'WARNING_CFLAGS' => '-Wno-everything',
  }
  s.swift_version = '5.0'
end
