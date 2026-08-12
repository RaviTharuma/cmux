/// Semantic capabilities that cmux advertises to control-socket clients for
/// nested topology (cmux → clients/UI), distinct from provider-negotiated
/// ``NestedProviderCapability`` tokens.
///
/// These are advertised through `system.capabilities` (additive `capabilities`
/// array) and gate method availability alongside beta flags and authorization.
public enum NestedTopologyPublicCapability: String, Codable, Sendable, Hashable, CaseIterable {
    /// Read-only nested topology projection (`nested.topology.list`, optional
    /// `system.tree` `include_nested`).
    case readV1 = "nested_topology.read.v1"
}
