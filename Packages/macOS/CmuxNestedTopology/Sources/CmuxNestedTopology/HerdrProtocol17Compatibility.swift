public import Foundation

/// Protocol-17 adaptation for Herdr's newline-delimited JSON socket API.
///
/// Checked against Herdr's published schema shapes for `ping`, `session.snapshot`,
/// and `events.subscribe` (see `herdr api schema --json`). Unknown JSON fields are
/// tolerated; missing required fields are errors.
///
/// ## Provider instance identity gap
///
/// Protocol 17 `ping` does **not** return a durable server-lifetime `instance_id`.
/// Until Herdr advertises one, cmux assigns a fresh
/// ``NestedProviderInstanceID/randomConnectionGeneration()`` per successful
/// connection and must not treat reconnects as the same mutation authority.
public struct HerdrProtocol17Compatibility: Sendable {
    /// Tested Herdr protocol number for this adapter profile.
    public static let supportedProtocolNumber = 17

    /// Semantic capabilities advertised for a validated protocol-17 server.
    ///
    /// Protocol 17 exposes typed `*.focus` methods (`workspace.focus`,
    /// `tab.focus`, `pane.focus`, `agent.focus`), so ``topologyFocusV1`` is
    /// included. Rename / input / split remain deferred until later PRs.
    public static let readCapabilities = NestedCapabilitySet(
        capabilities: [
            .topologySnapshotV1,
            .topologyEventsV1,
            .topologyFocusV1,
        ]
    )

    /// Capabilities required to copy ``RemoteTmuxWindowMirror`` for Herdr (PR7).
    public static let mirrorCapabilities = NestedCapabilitySet(
        capabilities: [
            .topologySnapshotV1,
            .topologyEventsV1,
            .topologyFocusV1,
            .paneInputV1,
            .paneSplitV1,
            .paneResizeV1,
            .paneCloseV1,
            .paneReadV1,
        ]
    )

    /// Default topology event subscriptions for the read-only adapter.
    public static let defaultSubscriptions: [[String: String]] = [
        ["type": "workspace.created"],
        ["type": "workspace.updated"],
        ["type": "workspace.renamed"],
        ["type": "workspace.moved"],
        ["type": "workspace.reordered"],
        ["type": "workspace.closed"],
        ["type": "workspace.focused"],
        ["type": "tab.created"],
        ["type": "tab.closed"],
        ["type": "tab.focused"],
        ["type": "tab.renamed"],
        ["type": "tab.moved"],
        ["type": "pane.created"],
        ["type": "pane.closed"],
        ["type": "pane.updated"],
        ["type": "pane.focused"],
        ["type": "pane.moved"],
        ["type": "pane.exited"],
        ["type": "pane.agent_detected"],
    ]

    /// Default subscriptions plus parameterized `pane.agent_status_changed` for each pane.
    public static func subscriptions(forPaneIDs paneIDs: [String]) -> [[String: String]] {
        var subscriptions = defaultSubscriptions
        var seen = Set<String>()
        for paneID in paneIDs {
            let trimmed = paneID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            subscriptions.append([
                "type": "pane.agent_status_changed",
                "pane_id": trimmed,
            ])
        }
        return subscriptions
    }

    public init() {}

    /// Validates a decoded `ping` / `pong` result and builds handshake metadata.
    public func makeHandshake(
        from pong: HerdrWirePong,
        providerInstanceID: NestedProviderInstanceID,
        instanceIdentityIsDurable: Bool
    ) throws -> NestedProviderHandshake {
        guard pong.protocolNumber == Self.supportedProtocolNumber else {
            throw NestedTopologyProviderError.unsupportedProtocol(pong.protocolNumber)
        }
        let version = pong.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else {
            throw NestedTopologyProviderError.missingRequiredField("result.version")
        }
        return NestedProviderHandshake(
            providerKind: .herdr,
            providerInstanceID: providerInstanceID,
            version: version,
            protocolNumber: pong.protocolNumber,
            capabilities: Self.readCapabilities,
            instanceIdentityIsDurable: instanceIdentityIsDurable
        )
    }

    /// Maps a protocol-17 `session.snapshot` payload into the provider-neutral model.
    public func makeSnapshot(
        from wire: HerdrWireSessionSnapshot,
        handshake: NestedProviderHandshake,
        attachmentID: UUID,
        hostStableSurfaceID: UUID,
        limits: NestedTopologyLimits
    ) throws -> NestedTopologySnapshot {
        let instance = handshake.providerInstanceID
        var workspaces: [NestedWorkspaceNode] = []
        workspaces.reserveCapacity(wire.workspaces.count)
        for (index, workspace) in wire.workspaces.enumerated() {
            let rawID = workspace.workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("workspaces[].workspace_id")
            }
            workspaces.append(
                NestedWorkspaceNode(
                    id: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .workspace,
                        rawID: rawID
                    ),
                    displayTitle: Self.displayTitle(workspace.label, fallback: rawID),
                    orderIndex: max(0, max(workspace.number - 1, index))
                )
            )
        }

        var tabs: [NestedTabNode] = []
        tabs.reserveCapacity(wire.tabs.count)
        for (index, tab) in wire.tabs.enumerated() {
            let rawID = tab.tabID.trimmingCharacters(in: .whitespacesAndNewlines)
            let workspaceRawID = tab.workspaceID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("tabs[].tab_id")
            }
            guard !workspaceRawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("tabs[].workspace_id")
            }
            tabs.append(
                NestedTabNode(
                    id: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .tab,
                        rawID: rawID
                    ),
                    workspaceID: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .workspace,
                        rawID: workspaceRawID
                    ),
                    displayTitle: Self.displayTitle(tab.label, fallback: rawID),
                    orderIndex: max(0, max(tab.number - 1, index))
                )
            )
        }

        var panes: [NestedPaneNode] = []
        panes.reserveCapacity(wire.panes.count)
        var paneOrderByTab: [String: Int] = [:]
        for pane in wire.panes {
            let rawID = pane.paneID.trimmingCharacters(in: .whitespacesAndNewlines)
            let tabRawID = pane.tabID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("panes[].pane_id")
            }
            guard !tabRawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("panes[].tab_id")
            }
            let order = paneOrderByTab[tabRawID, default: 0]
            paneOrderByTab[tabRawID] = order + 1
            panes.append(
                NestedPaneNode(
                    id: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .pane,
                        rawID: rawID
                    ),
                    tabID: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .tab,
                        rawID: tabRawID
                    ),
                    displayTitle: Self.paneDisplayTitle(pane),
                    orderIndex: order
                )
            )
        }

        var agents: [NestedAgentNode] = []
        agents.reserveCapacity(wire.agents.count)
        var agentOrderByPane: [String: Int] = [:]
        for agent in wire.agents {
            let paneRawID = agent.paneID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paneRawID.isEmpty else {
                throw NestedTopologyProviderError.missingRequiredField("agents[].pane_id")
            }
            // Herdr agents are addressed by pane id; use the pane id as the opaque agent raw id.
            let order = agentOrderByPane[paneRawID, default: 0]
            agentOrderByPane[paneRawID] = order + 1
            let rawStatus = agent.agentStatus.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let status = NestedAgentStatus.normalized(from: rawStatus) else {
                throw NestedTopologyProviderError.missingRequiredField("agents[].agent_status")
            }
            agents.append(
                NestedAgentNode(
                    id: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .agent,
                        rawID: paneRawID
                    ),
                    paneID: NestedNodeID(
                        providerKind: .herdr,
                        providerInstanceID: instance,
                        kind: .pane,
                        rawID: paneRawID
                    ),
                    displayTitle: Self.agentDisplayTitle(agent, fallback: paneRawID),
                    status: status,
                    providerRawStatus: rawStatus,
                    orderIndex: order
                )
            )
        }

        let focus = NestedFocus(
            workspaceID: wire.focusedWorkspaceID.flatMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return NestedNodeID(
                    providerKind: .herdr,
                    providerInstanceID: instance,
                    kind: .workspace,
                    rawID: trimmed
                )
            },
            tabID: wire.focusedTabID.flatMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return NestedNodeID(
                    providerKind: .herdr,
                    providerInstanceID: instance,
                    kind: .tab,
                    rawID: trimmed
                )
            },
            paneID: wire.focusedPaneID.flatMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return NestedNodeID(
                    providerKind: .herdr,
                    providerInstanceID: instance,
                    kind: .pane,
                    rawID: trimmed
                )
            },
            agentID: nil
        )

        let snapshot = NestedTopologySnapshot(
            attachmentID: attachmentID,
            hostStableSurfaceID: hostStableSurfaceID,
            provider: handshake,
            workspaces: workspaces,
            tabs: tabs,
            panes: panes,
            agents: agents,
            focus: focus
        )
        var reducer = NestedTopologyReducer(
            providerKind: .herdr,
            providerInstanceID: instance,
            limits: limits
        )
        _ = try reducer.apply(.replaceSnapshot(snapshot))
        guard let validated = reducer.snapshot else {
            throw NestedTopologyProviderError.missingRequiredField("snapshot")
        }
        return validated
    }
