// swift-tools-version: 5.9
//
// Swift Package Manager support: the app resolves all of its Apple plugins
// through SPM. The podspec stays for CocoaPods consumers. Sources/ holds
// forwarders that relatively include ../../../../src — SPM requires a
// target's files inside the package directory (docs/design/js-engine.md
// § 7, the same arrangement as halo_quickjs).

import PackageDescription

let package = Package(
    name: "halo_audio",
    platforms: [.macOS("10.15")],
    products: [
        .library(name: "halo-audio", type: .static, targets: ["halo_audio"])
    ],
    targets: [
        .target(
            name: "halo_audio",
            cSettings: [
                .define("NDEBUG", to: "1"),
                // miniaudio is third-party C; its warnings are not ours to fix.
                // Hidden by default: halo_audio.h marks its own entry points
                // visible and `used`, so they survive dead-stripping.
                .unsafeFlags(["-Wno-everything", "-fvisibility=hidden"])
            ],
            linkerSettings: [
                // MA_NO_RUNTIME_LINKING (halo_audio.c): linked, not dlopened.
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
            ]
        )
    ]
)
