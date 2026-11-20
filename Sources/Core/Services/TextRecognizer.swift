import Foundation
import ImageIO
import Vision

/// On-device text recognition (Apple Vision). The language list comes from the system at runtime, so a language
/// Apple adds later (Hebrew is missing on macOS 26) becomes available without an update.
enum TextRecognizer {
    static let languagesKey = "ocrLanguages"

    static func supportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
    }

    /// The saved choice where the system still supports it; otherwise the user's own languages that are supported,
    /// then English.
    static func languages(saved: [String], preferred: [String], supported: [String]) -> [String] {
        let kept = saved.filter(supported.contains)
        if !kept.isEmpty { return kept }
        func code(_ identifier: String) -> String { String(identifier.prefix { $0 != "-" && $0 != "_" }).lowercased() }
        var result: [String] = []
        for language in preferred {
            if let match = supported.first(where: { code($0) == code(language) }), !result.contains(match) { result.append(match) }
        }
        if let english = supported.first(where: { code($0) == "en" }), !result.contains(english) { result.append(english) }
        return result
    }

    static func currentLanguages(defaults: UserDefaults = .standard) -> [String] {
        let saved = (defaults.string(forKey: languagesKey) ?? "").split(separator: ",").map(String.init)
        return languages(saved: saved, preferred: Locale.preferredLanguages, supported: supportedLanguages())
    }

    /// The text in a PNG, TIFF or JPEG image, one line per recognized line; nil when the data is not an image.
    static func recognize(imageData: Data, languages: [String]) async -> String? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !languages.isEmpty { request.recognitionLanguages = languages }
            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                return ""
            }
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }
}
