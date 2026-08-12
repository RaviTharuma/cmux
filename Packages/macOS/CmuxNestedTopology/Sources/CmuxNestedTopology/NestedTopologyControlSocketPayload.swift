public import Foundation

/// Encodes nested topology read results into Foundation JSON objects suitable
/// for cmux control-socket replies (`JSONSerialization` / `JSONValue`).
///
/// Uses snake_case Codable keys from the public read types. Callers bridge via
/// `JSONValue(foundationObject:)` on the app/control-socket side.
public enum NestedTopologyControlSocketPayload: Sendable {
    /// Encodes a list result as a Foundation dictionary.
    ///
    /// - Parameter result: Projected list result.
    /// - Returns: JSON object dictionary, or `nil` if encoding fails.
    public static func foundationObject(for result: NestedTopologyReadListResult) -> [String: Any]? {
        encodeToDictionary(result)
    }

    /// Encodes attachments for an additive `system.tree` `nested` field.
    ///
    /// Default `system.tree` responses must omit this field entirely so the
    /// payload stays byte-compatible with prior clients.
    public static func foundationNestedTreeObject(
        attachments: [NestedTopologyReadAttachment]
    ) -> [String: Any]? {
        let envelope = NestedTopologyReadListResult(attachments: attachments)
        return encodeToDictionary(envelope)
    }

    /// Whether `include_nested` was requested in control-socket params.
    public static func includeNestedRequested(_ params: [String: Any]) -> Bool {
        if let bool = params["include_nested"] as? Bool {
            return bool
        }
        if let number = params["include_nested"] as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private static func encodeToDictionary<T: Encodable>(_ value: T) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        guard let data = try? encoder.encode(value) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }
}
