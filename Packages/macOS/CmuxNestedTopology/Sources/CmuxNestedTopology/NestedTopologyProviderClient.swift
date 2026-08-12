/// Provider-neutral read client for nested topology providers.
///
/// Implementations speak only their provider transport (for Herdr: newline-delimited
/// JSON over a local Unix socket). They must not shell out to CLIs and must not
/// mutate cmux workspace / Bonsplit state.
public protocol NestedTopologyProviderClient: Sendable {
    /// Negotiates compatibility and returns handshake metadata for this connection generation.
    func handshake() async throws -> NestedProviderHandshake

    /// Fetches a full topology snapshot for the configured host attachment.
    func snapshot() async throws -> NestedTopologySnapshot

    /// Streams provider topology events, reconnecting with a full resnapshot on recoverable gaps.
    func events() -> AsyncThrowingStream<NestedTopologyEvent, any Error>
}
