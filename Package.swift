// swift-tools-version: 5.9
import PackageDescription

let cTranslate2HeadersPath: String
let ctranslate2Path = "../../Frameworks/CTranslate2.xcframework"
#if os(macOS)
cTranslate2HeadersPath = ctranslate2Path + "/macos-arm64/CTranslate2.framework/Headers"
#else
cTranslate2HeadersPath = ctranslate2Path + "/ios-arm64/CTranslate2.framework/Headers"
#endif

let package = Package(
    name: "SwiftFasterWhisper",
    platforms: [
        .macOS(.v13),
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
                .headerSearchPath(cTranslate2HeadersPath)
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z")
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
            exclude: [
                "Models",
                "test-log.txt"
            ],
            resources: [
                .copy("jfk.wav"),
                .copy("05-speech.wav"),
                .copy("06-speech.wav"),
                .copy("12-speech.wav")
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
