import Foundation
import CmuxControlSocket
import CmuxNestedTopology
import CmuxSettings

/// Control-socket handlers for nested topology read APIs (PR4).
///
/// Runs on the socket worker (`nested.topology.list`). Mutations/focus are
/// deferred to PR5. Nested nodes are never injected into Bonsplit / Workspace.
extension TerminalController {
    /// `nested.topology.list` — project attached nested topologies.
    ///
    /// Optional params: `host_surface_id` (UUID), `host_workspace_id` (string).
    /// Default tree (`system.tree` without `include_nested`) is unchanged.
    nonisolated func v2NestedTopologyList(id: Any?, params: [String: Any]) -> String {
        guard NestedTopologyController.isEnabled else {
            return v2Error(
                id: id,
                code: "disabled",
                message: String(
                    localized: "socket.nestedTopology.disabled",
                    defaultValue: "nested topology beta is disabled"
                )
            )
        }

        let hostSurfaceID = Self.nestedTopologyUUID(params["host_surface_id"])
        if params["host_surface_id"] != nil && hostSurfaceID == nil {
            return v2Error(
                id: id,
                code: "invalid_params",
                message: String(
                    localized: "socket.nestedTopology.invalidHostSurfaceID",
                    defaultValue: "Missing or invalid host_surface_id"
                )
            )
        }
        let hostWorkspaceID = (params["host_workspace_id"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let workspaceFilter = (hostWorkspaceID?.isEmpty == false) ? hostWorkspaceID : nil

        return v2VmCall(id: id, timeoutSeconds: 15) {
            guard let controller = await MainActor.run(body: { AppDelegate.shared?.nestedTopologyController })
            else {
                throw NestedTopologySocketError.appNotReady
            }
            let result = await controller.listAttachments(
                hostStableSurfaceID: hostSurfaceID,
                hostWorkspaceID: workspaceFilter
            )
            guard let payload = NestedTopologyControlSocketPayload.foundationObject(for: result) else {
                throw NestedTopologySocketError.encodeFailed
            }
            return payload
        }
    }

    /// Whether `system.tree` requested nested descendants.
    nonisolated static func nestedTopologyIncludeNestedRequested(_ params: [String: Any]) -> Bool {
        NestedTopologyControlSocketPayload.includeNestedRequested(params)
    }

    private nonisolated static func nestedTopologyUUID(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String {
            return UUID(uuidString: string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}

/// Errors surfaced through `v2VmCall` for nested topology reads.
enum NestedTopologySocketError: Error, CustomStringConvertible {
    case appNotReady
    case encodeFailed

    var description: String {
        switch self {
        case .appNotReady:
            return "app not ready"
        case .encodeFailed:
            return "failed to encode nested topology"
        }
    }
}
