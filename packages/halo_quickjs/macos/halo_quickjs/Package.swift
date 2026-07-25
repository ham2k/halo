// swift-tools-version: 5.9
//
// Swift Package Manager support. The app resolves ALL of its Apple plugins
// through SPM, and Flutter refuses a plugin that only ships a podspec with
// "does not support Swift Package Manager ... will become an error in a
// future version of Flutter". The podspec stays for CocoaPods consumers.
//
// Sources/ holds forwarders that relatively include ../../../../src, the same
// trick the podspec's Classes/ uses: SPM requires a target's files to live
// inside the package directory, but `#include "..."` resolves relative to the
// INCLUDING FILE, so quickjs's bare-name includes of each other still resolve
// against src/quickjs with no header search path escaping the package.

import PackageDescription

let package = Package(
    name: "halo_quickjs",
    platforms: [.macOS("10.15")],
    products: [
        .library(name: "halo-quickjs", type: .static, targets: ["halo_quickjs"])
    ],
    targets: [
        .target(
            name: "halo_quickjs",
            cSettings: [
                .define("NDEBUG", to: "1"),
                .define("_GNU_SOURCE", to: "1"),
                // quickjs is third-party C; its warnings are not ours to fix.
                .unsafeFlags(["-Wno-everything"])
            ]
        )
    ]
)
