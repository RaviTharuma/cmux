import Foundation
import CmuxNestedTopology
import CmuxSettings
import OSLog
import Observation

/// App-scoped host for nested topology attachment, read projection, and
/// capability-gated focus (PR4/PR5).
///
/// Owns the ``NestedTopologyAttachmentCoordinator`` (actor) and a MainActor
/// read cache used by the sidebar. Provider descendants remain virtual under a
/// host terminal surface — never mirrored into Bonsplit / `Workspace.panels`.
@MainActor
@Observable
final class NestedTopologyController {
    nonisolated static let logger = Logger(subsystem: "com.cmuxterm.app", category: "NestedTopology")

    /// Attachment coordinator (provider I/O off the main actor).
    let coordinator: NestedTopologyAttachmentCoordinator

    /// Expanded host surfaces for the sidebar subtree (container-owned).
    private(set) var expandedHostSurfaceIDs: Set<UUID> = []

    /// Last projected sidebar subtrees keyed by host stable surface ID.
    private(set) var sidebarSubtreesByHostSurfaceID: [UUID: NestedSidebarSubtreeSnapshot] = [:]

    /// Host surface IDs per host workspace ID string (from last refresh).
    private var hostSurfacesByWorkspaceID: [String: Set<UUID>] = [:]

    private var readService = NestedTopologyReadService()
    private var refreshTask: Task<Void, Never>?
    private let refreshBridge = NestedTopologyRefreshBridge()

    /// Synchronous read of the nested-topology beta flag (socket/AppKit paths).
    nonisolated static var isEnabled: Bool {
        let key = SettingCatalog().betaFeatures.nestedTopology
        return Bool.decodeFromUserDefaults(UserDefaults.standard.object(forKey: key.userDefaultsKey))
            ?? key.defaultValue
    }

    init(coordinator: NestedTopologyAttachmentCoordinator? = nil) {
        let handoffDirectory = Self.defaultHandoffDirectory()
        if let coordinator {
            self.coordinator = coordinator
        } else {
            let bridge = refreshBridge
            self.coordinator = NestedTopologyAttachmentCoordinator(
                handoff: NestedPluginWriterHandoff(directoryURL: handoffDirectory),
                telemetrySink: { _ in bridge.schedule() }
            )
        }
        refreshBridge.handler = { [weak self] in
            self?.scheduleSidebarRefresh()
        }
    }

    /// Lists attachments for the control-socket read API.
    func listAttachments(
        hostStableSurfaceID: UUID? = nil,
        hostWorkspaceID: String? = nil
    ) async -> NestedTopologyReadListResult {
        let attachments = await coordinator.allAttachments()
        let result = readService.list(
            attachments: attachments,
            hostStableSurfaceID: hostStableSurfaceID,
            hostWorkspaceID: hostWorkspaceID
        )
        rebuildSidebarCache(from: attachments)
        return result
    }

    /// Refreshes MainActor sidebar snapshots from the coordinator.
    func refreshSidebarSnapshots() async {
        guard Self.isEnabled else {
            sidebarSubtreesByHostSurfaceID = [:]
            hostSurfacesByWorkspaceID = [:]
            return
        }
        let attachments = await coordinator.allAttachments()
        rebuildSidebarCache(from: attachments)
    }

    /// Schedules a coalesced sidebar refresh (diff-friendly; no per-frame thrash).
    func scheduleSidebarRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            await self.refreshSidebarSnapshots()
        }
    }

    /// Toggles expansion for one host surface's nested subtree.
    func toggleExpanded(hostStableSurfaceID: UUID) {
        if expandedHostSurfaceIDs.contains(hostStableSurfaceID) {
            expandedHostSurfaceIDs.remove(hostStableSurfaceID)
        } else {
            expandedHostSurfaceIDs.insert(hostStableSurfaceID)
        }
        if let snapshot = sidebarSubtreesByHostSurfaceID[hostStableSurfaceID] {
            sidebarSubtreesByHostSurfaceID[hostStableSurfaceID] = NestedSidebarSubtreeSnapshot(
                hostStableSurfaceID: snapshot.hostStableSurfaceID,
                attachmentID: snapshot.attachmentID,
                providerKind: snapshot.providerKind,
                connectionState: snapshot.connectionState,
                isStale: snapshot.isStale,
                isExpanded: expandedHostSurfaceIDs.contains(hostStableSurfaceID),
                roots: snapshot.roots
            )
        } else {
            scheduleSidebarRefresh()
        }
    }

    /// Focuses a nested node via the capability-gated coordinator path.
    ///
    /// Used by sidebar row selection and `nested.node.focus`. Does not mutate
    /// Bonsplit / Ghostty state; topology updates come from provider events.
    @discardableResult
    func focusNode(_ request: NestedNodeFocusRequest) async throws -> NestedNodeFocusResult {
        let result = try await coordinator.focusNode(request)
        scheduleSidebarRefresh()
        return result
    }

    /// Sidebar convenience: focus a node under a known host surface (user confirmed).
    func focusSidebarNode(hostStableSurfaceID: UUID, nodeID: NestedNodeID) {
        guard Self.isEnabled else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.focusNode(
                    NestedNodeFocusRequest(
                        hostStableSurfaceID: hostStableSurfaceID,
                        nodeID: nodeID,
                        expectedAttachmentID: self.sidebarSubtreesByHostSurfaceID[hostStableSurfaceID]?.attachmentID,
                        expectedProviderInstanceID: nodeID.providerInstanceID,
                        authorization: .userConfirmed
                    )
                )
            } catch {
                Self.logger.error("nested focus failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Sidebar snapshot for a host surface, if any attachment exists.
    func sidebarSubtree(for hostStableSurfaceID: UUID) -> NestedSidebarSubtreeSnapshot? {
        guard Self.isEnabled else { return nil }
        return sidebarSubtreesByHostSurfaceID[hostStableSurfaceID]
    }

    /// Nested subtrees bound to a workspace (by host workspace ID string).
    func sidebarSubtrees(forWorkspaceID workspaceID: UUID) -> [NestedSidebarSubtreeSnapshot] {
        guard Self.isEnabled else { return [] }
        let keys = [
            workspaceID.uuidString,
            workspaceID.uuidString.lowercased(),
            workspaceID.uuidString.uppercased(),
        ]
        var hostIDs = Set<UUID>()
        for key in keys {
            if let ids = hostSurfacesByWorkspaceID[key] {
                hostIDs.formUnion(ids)
            }
        }
        return hostIDs
            .compactMap { sidebarSubtreesByHostSurfaceID[$0] }
            .sorted { $0.hostStableSurfaceID.uuidString < $1.hostStableSurfaceID.uuidString }
    }

    /// Notifies that a host surface moved workspaces (preserves attachment).
    func hostSurfaceMoved(hostStableSurfaceID: UUID, toWorkspaceID: String) async {
        await coordinator.noteHostSurfaceMoved(
            hostStableSurfaceID: hostStableSurfaceID,
            toWorkspaceID: toWorkspaceID
        )
        scheduleSidebarRefresh()
    }

    /// Detaches when the host surface closes (no provider stop / child closes).
    func hostSurfaceClosed(hostStableSurfaceID: UUID) async {
        await coordinator.noteHostSurfaceClosed(hostStableSurfaceID: hostStableSurfaceID)
        expandedHostSurfaceIDs.remove(hostStableSurfaceID)
        sidebarSubtreesByHostSurfaceID.removeValue(forKey: hostStableSurfaceID)
        scheduleSidebarRefresh()
    }

    /// Tears down all attachments (app/window teardown).
    func teardown() async {
        await coordinator.teardown()
        expandedHostSurfaceIDs = []
        sidebarSubtreesByHostSurfaceID = [:]
        hostSurfacesByWorkspaceID = [:]
    }

    private func rebuildSidebarCache(from attachments: [NestedAttachmentRecord]) {
        var next: [UUID: NestedSidebarSubtreeSnapshot] = [:]
        var byWorkspace: [String: Set<UUID>] = [:]
        for attachment in attachments {
            let expanded = expandedHostSurfaceIDs.contains(attachment.hostStableSurfaceID)
            next[attachment.hostStableSurfaceID] = readService.sidebarSubtree(
                for: attachment,
                isExpanded: expanded
            )
            byWorkspace[attachment.hostWorkspaceID, default: []].insert(attachment.hostStableSurfaceID)
        }
        sidebarSubtreesByHostSurfaceID = next
        hostSurfacesByWorkspaceID = byWorkspace
    }

    private static func defaultHandoffDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("cmux", isDirectory: true)
            .appendingPathComponent("nested-topology", isDirectory: true)
    }
}

/// Bridges actor telemetry callbacks to MainActor refresh without retaining cycles.
private final class NestedTopologyRefreshBridge: @unchecked Sendable {
    @MainActor var handler: (() -> Void)?

    nonisolated func schedule() {
        Task { @MainActor in
            self.handler?()
        }
    }
}
