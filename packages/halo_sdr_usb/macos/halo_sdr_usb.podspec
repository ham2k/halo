#
# The Airspy libraries and the shim compiled into the plugin, with libusb as
# a framework of its own — see halo_sdr_usb/Package.swift, which is what the
# app builds with.
#
Pod::Spec.new do |s|
  s.name             = 'halo_sdr_usb'
  s.version          = '0.0.1'
  s.summary          = 'USB SDR receivers through dart:ffi.'
  s.description      = <<-DESC
Airspy R2, Mini and HF+ receivers, and SDRplay's through its installed API,
read into a ring the Ham2K Logger draws its spectrum from.
                       DESC
  s.homepage         = 'https://ham2k.com'
  s.license          = { :file => '../third_party/libusb/COPYING' }
  s.author           = { 'Sebastian Delmont' => 'sd@ham2k.com' }

  # Classes/ holds forwarders that relatively include ../src — podspec
  # cannot reference paths outside the pod directory.
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_frameworks = 'halo_sdr_usb/Frameworks/libusb.xcframework'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '12.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) NDEBUG=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/../third_party/libusb/libusb"',
    # The Airspy sources are third-party C; their warnings are not ours to fix.
    'WARNING_CFLAGS' => '-Wno-everything',
  }
  s.swift_version = '5.0'
end
