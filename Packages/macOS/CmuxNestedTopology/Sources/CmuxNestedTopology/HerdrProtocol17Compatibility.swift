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
