// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ChatSpm",
    platforms: [
            .iOS(.v13),
            .macOS(.v12)
        ],
    products: [
        .library(
            name: "ChatSpm",
            targets: ["ChatSpm"])
    ],
    
    dependencies: [
            .package(url: "https://github.com/tonymillion/Reachability", from: "3.2.0")
        ],
    targets: [
               .target(
                   name: "LibSignalClient",
                   dependencies: ["SignalFfi"], // SignalFfi bağımlılığı
                   path: "LibSignalClient",
                   publicHeadersPath: "include", // Objective-C header dosyalarının yolu
                   cSettings: [
                       .headerSearchPath("include") // Header arama yolu
                   ]
               ),
        .systemLibrary(
                    name: "SignalFfi",
                    path: "SignalFfi"
                ),
          .systemLibrary(
                    name: "ChatClient",
                    path: "ChatClient"
                ),
                .target(
                    name: "ChatSpm",
                    dependencies: [
                        "Reachability",
                        "SignalFfi",
                        "ChatClient",
                        "LibSignalClient"
                    ],
                    path: "Sources/ChatSpm",
                    exclude: [],
                    sources: nil,
                    publicHeadersPath: nil
                ),
        .testTarget(
            name: "ChatSpmTests",
            dependencies: ["ChatSpm"]
        ),
    ]
)
