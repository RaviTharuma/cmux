/// Handshake metadata captured after a successful provider ping/negotiate.
public struct NestedProviderHandshake: Hashable, Codable, Sendable {
    /// Provider kind.
    public var providerKind: NestedProviderKind
    /// Live provider instance identity for this connection generation.
    public var providerInstanceID: NestedProviderInstanceID
    /// Provider-reported version string (bounded elsewhere).
    public var version: String
    /// Provider protocol number when known.
    public var protocolNumber: Int?
    /// Negotiated semantic capabilities.
    public var capabilities: NestedCapabilitySet

    enum CodingKeys: String, CodingKey {
        case providerKind = "provider_kind"
        case providerInstanceID = "provider_instance_id"
        case version
        case protocolNumber = "protocol_number"
        case capabilities
    }

    /// Creates handshake metadata.
    public init(
        providerKind: NestedProviderKind,
        providerInstanceID: NestedProviderInstanceID,
        version: String,
        protocolNumber: Int? = nil,
        capabilities: NestedCapabilitySet = NestedCapabilitySet()
    ) {
        self.providerKind = providerKind
        self.providerInstanceID = providerInstanceID
        self.version = version
        self.protocolNumber = protocolNumber
        self.capabilities = capabilities
    }
}
