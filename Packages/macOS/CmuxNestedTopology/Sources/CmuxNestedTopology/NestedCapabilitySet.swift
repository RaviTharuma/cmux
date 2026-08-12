/// Set of negotiated nested-provider capabilities.
public struct NestedCapabilitySet: Hashable, Codable, Sendable {
    /// Contained capability tokens.
    public var capabilities: Set<NestedProviderCapability>

    /// Creates a capability set.
    ///
    /// - Parameter capabilities: Negotiated capabilities.
    public init(capabilities: Set<NestedProviderCapability> = []) {
        self.capabilities = capabilities
    }

    /// Whether the set contains the given capability.
    public func contains(_ capability: NestedProviderCapability) -> Bool {
        capabilities.contains(capability)
    }

    /// Inserts a capability.
    public mutating func insert(_ capability: NestedProviderCapability) {
        capabilities.insert(capability)
    }

    /// Intersection used when authorizing an action against both cmux support and provider ads.
    public func intersection(_ other: NestedCapabilitySet) -> NestedCapabilitySet {
        NestedCapabilitySet(capabilities: capabilities.intersection(other.capabilities))
    }

    /// Sorted capability raw values for deterministic encoding/tests.
    public var sortedRawValues: [String] {
        capabilities.map(\.rawValue).sorted()
    }
}
