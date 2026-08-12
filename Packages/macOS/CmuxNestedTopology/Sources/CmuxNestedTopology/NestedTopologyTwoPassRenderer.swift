public import Foundation

/// Two-pass nested topology projector for control-socket and sidebar reads.
///
/// Pass 1 installs the authoritative ``NestedParentMap`` from the snapshot.
/// Pass 2 resolves labels through ``NestedAssociationStore`` title locks and
/// only publishes a new label when it differs from the last published value
/// (no thrash when the provider echoes the same title).
///
/// Heuristic association runs at most once per association key.
public struct NestedTopologyTwoPassRenderer: Sendable {
    /// Stable parent edges used instead of re-inferring parents every tick.
    public private(set) var parentMap: NestedParentMap
    /// Association / title-lock store for this attachment generation.
    public private(set) var associations: NestedAssociationStore
    /// Last labels published per node (diff gate).
    private var lastPublishedLabels: [NestedNodeID: String]
    /// Provider instance generation last installed; used to invalidate associations.
    private var installedProviderInstanceID: NestedProviderInstanceID?

    /// Creates an empty two-pass renderer.
    public init() {
        self.parentMap = NestedParentMap()
        self.associations = NestedAssociationStore()
        self.lastPublishedLabels = [:]
        self.installedProviderInstanceID = nil
    }

    /// Projects one attachment into a public read summary.
    ///
    /// - Parameter attachment: Current attachment record (may be stale/disconnected).
    /// - Returns: Public attachment projection; nodes are empty when there is no snapshot.
    public mutating func project(attachment: NestedAttachmentRecord) -> NestedTopologyReadAttachment {
        let stale = attachment.state == .stale
            || attachment.state == .disconnected
            || attachment.state == .rejected
            || attachment.state == .incompatible

        guard let snapshot = attachment.latestSnapshot else {
            parentMap = NestedParentMap()
            lastPublishedLabels = [:]
            return NestedTopologyReadAttachment(
                attachmentID: attachment.attachmentID,
                hostWorkspaceID: attachment.hostWorkspaceID,
                hostStableSurfaceID: attachment.hostStableSurfaceID,
                providerKind: attachment.providerKind,
                providerInstanceID: attachment.providerInstanceID,
                state: attachment.state,
                providerCapabilities: attachment.capabilities.sortedRawValues,
                pluginWriterHandoffActive: attachment.pluginWriterHandoffActive,
                lastErrorClass: attachment.lastErrorClass,
                nodes: []
            )
        }

        if let instance = attachment.providerInstanceID,
           installedProviderInstanceID != instance {
            associations.invalidate(providerInstanceGeneration: instance)
            installedProviderInstanceID = instance
            lastPublishedLabels = [:]
        }

        // Pass 1: authoritative parent map from snapshot (never re-infer from titles).
        parentMap.replace(with: snapshot)

        // Pass 2: resolve labels with title locks; publish only when changed.
        let nodes = buildNodes(attachment: attachment, snapshot: snapshot, stale: stale)
        return NestedTopologyReadAttachment(
            attachmentID: attachment.attachmentID,
            hostWorkspaceID: attachment.hostWorkspaceID,
            hostStableSurfaceID: attachment.hostStableSurfaceID,
            providerKind: attachment.providerKind,
            providerInstanceID: attachment.providerInstanceID ?? snapshot.provider.providerInstanceID,
            state: attachment.state,
            providerCapabilities: attachment.capabilities.sortedRawValues,
            pluginWriterHandoffActive: attachment.pluginWriterHandoffActive,
            lastErrorClass: attachment.lastErrorClass,
            nodes: nodes
        )
    }

    /// Projects many attachments into a list result (deterministic order).
    public mutating func projectList(
        attachments: [NestedAttachmentRecord]
    ) -> NestedTopologyReadListResult {
        let projected = attachments.map { project(attachment: $0) }
        return NestedTopologyReadListResult(attachments: projected)
    }

    /// Applies an ordered event batch to the parent map without retitling.
    public mutating func applyParentMapEvents(_ events: [NestedTopologyEvent]) {
        parentMap.apply(events: events)
    }

    /// Locks a native title so subsequent projections cannot overwrite it.
    public mutating func lockTitle(
        for key: NestedAssociationKey,
        title: String,
        authority: NestedTitleAuthority
    ) {
        associations.lockTitle(for: key, title: title, authority: authority)
    }

    /// Marks heuristic association satisfied for a key (heuristic-once rule).
    public mutating func markHeuristicSatisfied(
        for key: NestedAssociationKey,
        parentID: NestedNodeID?
    ) {
        associations.markHeuristicSatisfied(for: key, parentID: parentID)
    }

    /// Whether heuristic association may still run for a key.
    public func shouldRunHeuristic(for key: NestedAssociationKey) -> Bool {
        associations.shouldRunHeuristic(for: key)
    }

    private mutating func buildNodes(
        attachment: NestedAttachmentRecord,
        snapshot: NestedTopologySnapshot,
        stale: Bool
    ) -> [NestedTopologyReadNode] {
        var nodes: [NestedTopologyReadNode] = []
        nodes.reserveCapacity(
            snapshot.workspaces.count
                + snapshot.tabs.count
                + snapshot.panes.count
                + snapshot.agents.count
        )

        let providerInstanceID =
            attachment.providerInstanceID ?? snapshot.provider.providerInstanceID
        let focus = snapshot.focus

        for workspace in NestedTopologyOrdering.sortedWorkspaces(snapshot.workspaces) {
            let label = resolveLabel(
                nodeID: workspace.id,
                proposed: workspace.displayTitle,
                providerInstanceID: providerInstanceID,
                sessionRawID: workspace.id.rawID
            )
            nodes.append(
                NestedTopologyReadNode(
                    id: workspace.id,
                    parentID: nil,
                    hostStableSurfaceID: attachment.hostStableSurfaceID,
                    attachmentID: attachment.attachmentID,
                    providerKind: attachment.providerKind,
                    providerInstanceID: providerInstanceID,
                    connectionState: attachment.state,
                    label: label,
                    focused: focus.workspaceID == workspace.id,
                    stale: stale,
                    agent: nil,
                    orderIndex: workspace.orderIndex,
                    metadata: ["node_kind": NestedNodeKind.workspace.rawValue]
                )
            )
        }

        for tab in NestedTopologyOrdering.sortedTabs(snapshot.tabs) {
            let parentID = parentMap.parent(of: tab.id) ?? tab.workspaceID
            let label = resolveLabel(
                nodeID: tab.id,
                proposed: tab.displayTitle,
                providerInstanceID: providerInstanceID,
                sessionRawID: tab.id.rawID
            )
            nodes.append(
                NestedTopologyReadNode(
                    id: tab.id,
                    parentID: parentID,
                    hostStableSurfaceID: attachment.hostStableSurfaceID,
                    attachmentID: attachment.attachmentID,
                    providerKind: attachment.providerKind,
                    providerInstanceID: providerInstanceID,
                    connectionState: attachment.state,
                    label: label,
                    focused: focus.tabID == tab.id,
                    stale: stale,
                    agent: nil,
                    orderIndex: tab.orderIndex,
                    metadata: ["node_kind": NestedNodeKind.tab.rawValue]
                )
            )
        }

        let agentsByPane = Dictionary(grouping: snapshot.agents, by: \.paneID)
        for pane in NestedTopologyOrdering.sortedPanes(snapshot.panes) {
            let parentID = parentMap.parent(of: pane.id) ?? pane.tabID
            let label = resolveLabel(
                nodeID: pane.id,
                proposed: pane.displayTitle,
                providerInstanceID: providerInstanceID,
                sessionRawID: pane.id.rawID
            )
            let primaryAgent = NestedTopologyOrdering.sortedAgents(agentsByPane[pane.id] ?? []).first
            let agentMetadata = primaryAgent.map {
                NestedTopologyReadAgentMetadata(
                    id: $0.id,
                    label: $0.displayTitle,
                    status: $0.status,
                    providerRawStatus: $0.providerRawStatus
                )
            }
            nodes.append(
                NestedTopologyReadNode(
                    id: pane.id,
                    parentID: parentID,
                    hostStableSurfaceID: attachment.hostStableSurfaceID,
                    attachmentID: attachment.attachmentID,
                    providerKind: attachment.providerKind,
                    providerInstanceID: providerInstanceID,
                    connectionState: attachment.state,
                    label: label,
                    focused: focus.paneID == pane.id,
                    stale: stale,
                    agent: agentMetadata,
                    orderIndex: pane.orderIndex,
                    metadata: ["node_kind": NestedNodeKind.pane.rawValue]
                )
            )
        }

        for agent in NestedTopologyOrdering.sortedAgents(snapshot.agents) {
            let parentID = parentMap.parent(of: agent.id) ?? agent.paneID
            let label = resolveLabel(
                nodeID: agent.id,
                proposed: agent.displayTitle,
                providerInstanceID: providerInstanceID,
                sessionRawID: agent.id.rawID
            )
            nodes.append(
                NestedTopologyReadNode(
                    id: agent.id,
                    parentID: parentID,
                    hostStableSurfaceID: attachment.hostStableSurfaceID,
                    attachmentID: attachment.attachmentID,
                    providerKind: attachment.providerKind,
                    providerInstanceID: providerInstanceID,
                    connectionState: attachment.state,
                    label: label,
                    focused: focus.agentID == agent.id,
                    stale: stale,
                    agent: NestedTopologyReadAgentMetadata(
                        id: agent.id,
                        label: agent.displayTitle,
                        status: agent.status,
                        providerRawStatus: agent.providerRawStatus
                    ),
                    orderIndex: agent.orderIndex,
                    metadata: [
                        "node_kind": NestedNodeKind.agent.rawValue,
                        "agent_status": agent.status.rawValue,
                    ]
                )
            )
        }

        return nodes
    }

    private mutating func resolveLabel(
        nodeID: NestedNodeID,
        proposed: String,
        providerInstanceID: NestedProviderInstanceID,
        sessionRawID: String
    ) -> String {
        let key = NestedAssociationKey(
            nodeID: nodeID,
            sessionRawID: sessionRawID,
            providerInstanceGeneration: providerInstanceID
        )
        let proposal = associations.proposeTitle(for: key, proposed: proposed)
        let resolved = NestedDisplayStringSanitizer.sanitize(
            proposal.title,
            maxUTF8ByteCount: NestedTopologyLimits.default.maxDisplayTitleUTF8ByteCount
        )
        if let previous = lastPublishedLabels[nodeID], previous == resolved {
            return previous
        }
        lastPublishedLabels[nodeID] = resolved
        return resolved
    }
}
