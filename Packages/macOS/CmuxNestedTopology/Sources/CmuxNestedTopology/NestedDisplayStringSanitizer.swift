import Foundation

/// Sanitizes untrusted nested-provider / proposal strings before publication.
///
/// Strips ASCII control characters (including DEL), truncates to a UTF-8 byte
/// bound, and never treats the result as a path/URL to open automatically.
public enum NestedDisplayStringSanitizer: Sendable {
    /// Default maximum UTF-8 byte length for sanitized display strings.
    public static let defaultMaxUTF8ByteCount = 512

    /// Returns a sanitized copy of `value`.
    ///
    /// - Parameters:
    ///   - value: Untrusted input.
    ///   - maxUTF8ByteCount: Maximum UTF-8 bytes retained after sanitization.
    /// - Returns: Control-character-free, truncated string (may be empty).
    public static func sanitize(
        _ value: String,
        maxUTF8ByteCount: Int = defaultMaxUTF8ByteCount
    ) -> String {
        precondition(maxUTF8ByteCount >= 0)
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(min(value.unicodeScalars.count, maxUTF8ByteCount))
        for scalar in value.unicodeScalars {
            if scalar.value < 0x20 || scalar.value == 0x7F {
                continue
            }
            scalars.append(scalar)
        }
        var cleaned = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.utf8.count > maxUTF8ByteCount {
            cleaned = truncateToUTF8ByteCount(cleaned, maxUTF8ByteCount: maxUTF8ByteCount)
        }
        return cleaned
    }

    private static func truncateToUTF8ByteCount(_ value: String, maxUTF8ByteCount: Int) -> String {
        var byteCount = 0
        var end = value.startIndex
        for (index, character) in zip(value.indices, value) {
            let characterBytes = String(character).utf8.count
            if byteCount + characterBytes > maxUTF8ByteCount {
                break
            }
            byteCount += characterBytes
            end = value.index(after: index)
        }
        return String(value[..<end])
    }
}
