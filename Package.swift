// swift-tools-version: 5.9
import PackageDescription

// CTranslate2 framework path
let ctranslate2Path = "Frameworks/CTranslate2.xcframework"

let package = Package(
    name: "SwiftFasterWhisper",
    platforms: [
        .macOS(.v15),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftFasterWhisper",
            targets: ["SwiftFasterWhisper"]
        ),
        .library(
            name: "faster_whisper",
            targets: ["faster_whisper"]
        )
    ],
    targets: [
        // Swift wrapper
        .target(
            name: "SwiftFasterWhisper",
            dependencies: ["faster_whisper"]
        ),
        // C++ bridge
        .target(
            name: "faster_whisper",
            dependencies: ["CTranslate2"],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("whisper"),
                .headerSearchPath("headers"),
                .headerSearchPath("../../Frameworks/CTranslate2.xcframework/macos-arm64/CTranslate2.framework/Headers"),
                .unsafeFlags(["-I/opt/homebrew/include"])
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
                .linkedLibrary("sentencepiece"),
                .unsafeFlags(["-L/opt/homebrew/lib"])
            ]
        ),
        // Binary framework
        .binaryTarget(
            name: "CTranslate2",
            path: "Frameworks/CTranslate2.xcframework"
        ),
        // Tests
        .testTarget(
            name: "SwiftFasterWhisperTests",
            dependencies: ["SwiftFasterWhisper"],
            resources: [
                .copy("jfk.wav"),
                .copy("05-speech.wav"),
                .copy("06-speech.wav"),
                .copy("12-speech.wav"),
                .copy("turkish_segments/")
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
