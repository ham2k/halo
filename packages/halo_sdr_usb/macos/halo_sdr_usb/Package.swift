// swift-tools-version: 5.9
//
// Swift Package Manager support, which is how the app resolves its Apple
// plugins; the podspec stays for CocoaPods consumers. Sources/ holds
// forwarders that relatively include ../../../../src — SPM requires a
// target's files inside the package directory, as for halo_audio.
//
// libusb is a framework of its own (tool/build_libusb_macos.sh), linked
// dynamically because it is LGPL-2.1; the Airspy libraries and our shim are
// compiled into the plugin.

import PackageDescription

let package = Package(
    name: "halo_sdr_usb",
    platforms: [.macOS("12.0")],
    products: [
        .library(name: "halo-sdr-usb", type: .static, targets: ["halo_sdr_usb"])
    ],
    targets: [
        .binaryTarget(name: "libusb", path: "Frameworks/libusb.xcframework"),
        .target(
            name: "halo_sdr_usb",
            dependencies: ["libusb"],
            cSettings: [
                .headerSearchPath("libusb_include"),
                .define("NDEBUG", to: "1"),
                // The Airspy sources are third-party C; their warnings are not
                // ours to fix. Hidden by default: halo_sdr_usb.h marks its own
                // entry points visible and `used`, so they survive dead-stripping.
                .unsafeFlags(["-Wno-everything", "-fvisibility=hidden"])
            ]
        )
    ],
    // The Airspy sources declare `typedef int bool;`, which C23 forbids.
    cLanguageStandard: .gnu11
)
