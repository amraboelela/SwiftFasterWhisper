//
// WhisperModelSize.swift
// SwiftFasterWhisper
//
// Created by Amr Aboelela on 1/22/2026.
//

import Foundation

/// Model registry for different Whisper model sizes
public enum WhisperModelSize: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case largeV2 = "large-v2"
    case largeV2Int8 = "large-v2-int8"

    var huggingFaceRepo: String {
        switch self {
        case .largeV2Int8:
            return "Systran/faster-whisper-large-v2"
        default:
            return "Systran/faster-whisper-\(rawValue)"
        }
    }

    var directoryName: String {
        switch self {
        case .largeV2Int8:
            return "whisper-large-v2-ct2-int8"
        default:
            return "whisper-\(rawValue)-ct2"
        }
    }

    var approximateSize: String {
        switch self {
        case .tiny: return "~75 MB"
        case .base: return "~140 MB"
        case .small: return "~460 MB"
        case .medium: return "~1.5 GB"
        case .largeV2: return "~3 GB"
        case .largeV2Int8: return "~1.5 GB"
        }
    }

    var needsQuantization: Bool {
        return self == .largeV2Int8
    }
}
