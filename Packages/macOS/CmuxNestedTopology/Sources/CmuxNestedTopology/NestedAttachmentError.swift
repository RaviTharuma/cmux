public import Foundation

/// Errors raised by ``NestedTopologyAttachmentCoordinator``.
public enum NestedAttachmentError: Error, Hashable, Sendable, LocalizedError {
    /// Attachment was requested without explicit opt-in authorization.
    case optInRequired
    /// An attachment already exists for the host stable surface.
    case duplicateAttachment(hostStableSurfaceID: UUID)
    /// The coordinator already holds the maximum number of attachments.
    case attachmentLimitExceeded(limit: Int)
    /// Endpoint security validation failed.
    case endpointRejected(NestedEndpointSecurityError)
    /// Provider handshake reported an unsupported protocol/capability set.
    case incompatibleProvider(detail: String)
    /// Provider client failed while connecting or negotiating.
    case providerFailed(detail: String)
    /// The attachment operation was cancelled (detach/teardown/reconnect cancel).
    case cancelled
    /// No attachment exists for the requested host surface.
    case attachmentNotFound(hostStableSurfaceID: UUID)
    /// Attachment exists but is not in a state that accepts the operation.
    case invalidState(NestedConnectionState)
    /// A caller-supplied string exceeded configured bounds after sanitization.
    case oversizedField(String)
    /// Provider (or cmux∩provider intersection) lacks the required capability.
    case capabilityAbsent(NestedProviderCapability)
    /// Expected provider instance / generation does not match the live binding.
    case providerInstanceMismatch
    /// Target node is not present in the attachment's latest snapshot.
    case nodeNotFound(NestedNodeID)
    /// Target node / attachment is bound to a different host stable surface.
    case wrongHostSurface

    public var errorDescription: String? {
        switch self {
        case .optInRequired:
            return "Nested provider attachment requires explicit opt-in authorization."
        case .duplicateAttachment:
            return "A nested provider attachment already exists for this host surface."
        case .attachmentLimitExceeded(let limit):
            return "Nested provider attachment limit (\(limit)) exceeded."
        case .endpointRejected(let error):
            return error.errorDescription
        case .incompatibleProvider(let detail):
            return "Nested provider is incompatible: \(detail)"
        case .providerFailed(let detail):
            return "Nested provider connection failed: \(detail)"
        case .cancelled:
            return "Nested provider attachment cancelled."
        case .attachmentNotFound:
            return "No nested provider attachment exists for this host surface."
        case .invalidState(let state):
            return "Nested provider attachment is in invalid state \(state.rawValue)."
        case .oversizedField(let field):
            return "Nested provider attachment field '\(field)' exceeds configured bounds."
        case .capabilityAbsent(let capability):
            return "Nested provider lacks capability \(capability.rawValue)."
        case .providerInstanceMismatch:
            return "Nested provider instance / generation does not match the live attachment."
        case .nodeNotFound:
            return "Nested topology node was not found on the live attachment."
        case .wrongHostSurface:
            return "Nested topology target is bound to a different host surface."
        }
    }

    /// Coarse error class for redacted telemetry (never includes socket paths).
    public var telemetryErrorClass: String {
        switch self {
        case .optInRequired: return "opt_in_required"
        case .duplicateAttachment: return "duplicate_attachment"
        case .attachmentLimitExceeded: return "attachment_limit_exceeded"
        case .endpointRejected(let error): return "endpoint_rejected.\(error.telemetryErrorClass)"
        case .incompatibleProvider: return "incompatible_provider"
        case .providerFailed: return "provider_failed"
        case .cancelled: return "cancelled"
        case .attachmentNotFound: return "attachment_not_found"
        case .invalidState: return "invalid_state"
        case .oversizedField: return "oversized_field"
        case .capabilityAbsent: return "capability_absent"
        case .providerInstanceMismatch: return "provider_instance_mismatch"
        case .nodeNotFound: return "node_not_found"
        case .wrongHostSurface: return "wrong_host_surface"
        }
    }

    /// Control-socket error code for mutation handlers.
    public var socketErrorCode: String {
        switch self {
        case .optInRequired:
            return "unauthorized"
        case .capabilityAbsent:
            return "capability_absent"
        case .providerInstanceMismatch, .invalidState(.stale), .invalidState(.disconnected):
            return "stale_instance"
        case .invalidState:
            return "invalid_state"
        case .attachmentNotFound, .nodeNotFound, .wrongHostSurface:
            return "not_found"
        case .cancelled:
            return "cancelled"
        case .providerFailed:
            return "provider_error"
        case .duplicateAttachment, .attachmentLimitExceeded, .endpointRejected,
             .incompatibleProvider, .oversizedField:
            return "invalid_params"
        }
    }
}

/// Why an attachment was detached.
public enum NestedDetachReason: String, Hashable, Codable, Sendable {
    /// Explicit user or control-socket detach.
    case userRequested
    /// Host terminal surface closed.
    case hostSurfaceClosed
    /// App/window coordinator teardown.
    case hostWindowTeardown
    /// In-flight attach/reconnect was cancelled.
    case cancelled
}
