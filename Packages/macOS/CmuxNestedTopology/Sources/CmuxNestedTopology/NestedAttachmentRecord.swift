public import Foundation

/// One nested-provider attachment bound to a host cmux terminal surface.
///
/// Attachments are owned by an app/window-scoped coordinator, never by a SwiftUI
/// row. Closing the host surface detaches this record without invoking
/// `server.stop` or closing provider child panes.
public struct NestedAttachmentRecord: Hashable, Codable, Sendable {
    /// Stable identifier for this attachment binding.
    public var attachmentID: UUID
    /// Host cmux workspace ID (updated when the surface moves).
    public var hostWorkspaceID: String
    /// Host cmux stable surface identity (attachment key; preserved across moves).
    public var hostStableSurfaceID: UUID
    /// Provider kind.
    public var providerKind: NestedProviderKind
    /// Validated endpoint (path + pre-connect file identity). Cleared when detached.
    public var endpoint: NestedAttachmentEndpoint?
    /// Provider instance ID / connection generation after a successful handshake.
    public var providerInstanceID: NestedProviderInstanceID?
    /// Negotiated capabilities after a successful handshake.
    public var capabilities: NestedCapabilitySet
    /// Lifecycle state.
    public var state: NestedConnectionState
    /// Whether the plugin single-writer handoff is currently held for this attachment.
    public var pluginWriterHandoffActive: Bool
    /// Redacted last error class (never a socket path or payload).
    public var lastErrorClass: String?
    /// Latest topology snapshot while live/stale, if any.
    public var latestSnapshot: NestedTopologySnapshot?

    enum CodingKeys: String, CodingKey {
        case attachmentID = "attachment_id"
        case hostWorkspaceID = "host_workspace_id"
        case hostStableSurfaceID = "host_stable_surface_id"
        case providerKind = "provider_kind"
        case endpoint
        case providerInstanceID = "provider_instance_id"
        case capabilities
        case state
        case pluginWriterHandoffActive = "plugin_writer_handoff_active"
        case lastErrorClass = "last_error_class"
        case latestSnapshot = "latest_snapshot"
    }

    /// Creates an attachment record.
    public init(
        attachmentID: UUID = UUID(),
        hostWorkspaceID: String,
        hostStableSurfaceID: UUID,
        providerKind: NestedProviderKind,
        endpoint: NestedAttachmentEndpoint? = nil,
        providerInstanceID: NestedProviderInstanceID? = nil,
        capabilities: NestedCapabilitySet = NestedCapabilitySet(),
        state: NestedConnectionState = .disconnected,
        pluginWriterHandoffActive: Bool = false,
        lastErrorClass: String? = nil,
        latestSnapshot: NestedTopologySnapshot? = nil
    ) {
        self.attachmentID = attachmentID
        self.hostWorkspaceID = NestedDisplayStringSanitizer.sanitize(
            hostWorkspaceID,
            maxUTF8ByteCount: NestedAttachmentLimits.default.maxHostWorkspaceIDUTF8ByteCount
        )
        self.hostStableSurfaceID = hostStableSurfaceID
        self.providerKind = providerKind
        self.endpoint = endpoint
        self.providerInstanceID = providerInstanceID
        self.capabilities = capabilities
        self.state = state
        self.pluginWriterHandoffActive = pluginWriterHandoffActive
        self.lastErrorClass = lastErrorClass
        self.latestSnapshot = latestSnapshot
    }

    /// Whether the attachment currently suppresses competing plugin writers.
    public var suppressesPluginWriters: Bool {
        pluginWriterHandoffActive && state == .live
    }
}
