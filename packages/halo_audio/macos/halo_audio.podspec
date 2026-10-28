#
# Compiles miniaudio + the shim directly into the app binary, like
# halo_quickjs: no separate dylib to sign or notarize.
#
Pod::Spec.new do |s|
  s.name             = 'halo_audio'
  s.version          = '0.0.1'
  s.summary          = 'Direct dart:ffi binding to a statically-linked miniaudio.'
  s.description      = <<-DESC
Sound devices, playback and recording for the Ham2K Logger's voice keyer:
miniaudio compiled into the app, bound through a flat C shim.
                       DESC
  s.homepage         = 'https://ham2k.com'
  s.license          = { :file => '../src/miniaudio/LICENSE' }
  s.author           = { 'Sebastian Delmont' => 'sd@ham2k.com' }

  # Classes/ holds a forwarder that relatively includes ../src — podspec
  # cannot reference paths outside the pod directory.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  # MA_NO_RUNTIME_LINKING (halo_audio.c): linked, not dlopened.
  s.frameworks       = 'CoreFoundation', 'CoreAudio', 'AudioToolbox'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NDEBUG=1',
    # miniaudio is third-party C; its warnings are not ours to fix.
    'WARNING_CFLAGS' => '-Wno-everything',
  }
  s.swift_version = '5.0'
end
