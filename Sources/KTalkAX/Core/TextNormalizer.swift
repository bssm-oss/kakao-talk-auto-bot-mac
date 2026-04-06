import Foundation

struct TextNormalizer {
    static func normalize(_ text: String, stripSeparators: Bool = false) -> String {
        let compatibility = text.precomposedStringWithCompatibilityMapping.lowercased()
        let filteredScalars = compatibility.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !zeroWidthScalars.contains(scalar.value)
        }
        var value = String(String.UnicodeScalarView(filteredScalars))
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        if stripSeparators {
            value = value.unicodeScalars.filter { scalar in
                scalar.properties.isAlphabetic || CharacterSet.decimalDigits.contains(scalar) || CharacterSet.whitespaces.contains(scalar)
            }.map(String.init).joined()
        }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func likelyHumanReadable(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return false }
        if normalized.range(of: "^[0-9:]+$", options: .regularExpression) != nil { return false }
        return normalized.count >= 1
    }

    private static let zeroWidthScalars: Set<UInt32> = [0x200B, 0x200C, 0x200D, 0xFEFF]
}
