import CmuxNestedTopology
import SwiftUI

/// Expandable provider-owned nested topology beneath a host terminal surface.
///
/// Snapshot-boundary safe: takes an immutable ``NestedSidebarSubtreeSnapshot``
/// and closure actions only — no store reference. Virtual children never enter
/// Bonsplit / Workspace.panels.
struct NestedSidebarSubtreeView: View, Equatable {
    let snapshot: NestedSidebarSubtreeSnapshot
    let onToggleExpansion: () -> Void

    static func == (lhs: NestedSidebarSubtreeView, rhs: NestedSidebarSubtreeView) -> Bool {
        lhs.snapshot == rhs.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(headerTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(snapshot.isStale ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if snapshot.isStale {
                        Text(staleLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(snapshot.accessibilityLabel))
            .accessibilityIdentifier("NestedTopologySubtreeHeader")

            if snapshot.isExpanded {
                ForEach(snapshot.roots, id: \.node.id) { row in
                    NestedSidebarRowView(row: row, depth: 0)
                }
            }
        }
        .padding(.leading, 8)
        .accessibilityElement(children: .contain)
    }

    private var headerTitle: String {
        let base = String(localized: "sidebar.nestedTopology.header", defaultValue: "Nested")
        return "\(base) (\(snapshot.providerKind.rawValue))"
    }

    private var staleLabel: String {
        switch snapshot.connectionState {
        case .disconnected:
            return String(localized: "sidebar.nestedTopology.state.disconnected", defaultValue: "Disconnected")
        case .stale:
            return String(localized: "sidebar.nestedTopology.state.stale", defaultValue: "Stale")
        case .rejected:
            return String(localized: "sidebar.nestedTopology.state.rejected", defaultValue: "Rejected")
        case .incompatible:
            return String(localized: "sidebar.nestedTopology.state.incompatible", defaultValue: "Incompatible")
        case .connecting:
            return String(localized: "sidebar.nestedTopology.state.connecting", defaultValue: "Connecting")
        case .live:
            return String(localized: "sidebar.nestedTopology.state.live", defaultValue: "Live")
        }
    }
}

/// One nested row (workspace/tab/pane/agent) with optional children.
private struct NestedSidebarRowView: View {
    let row: NestedSidebarRowSnapshot
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(row.node.label.isEmpty ? row.node.id.rawID : row.node.label)
                    .font(.system(size: 11))
                    .foregroundStyle(row.node.stale ? .secondary : .primary)
                    .lineLimit(1)
                if row.node.focused {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                if let status = row.node.agent?.status, row.node.id.kind == .agent || row.node.id.kind == .pane {
                    Text(status.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(12 + depth * 10))
            .accessibilityLabel(Text(row.accessibilityLabel))
            .accessibilityAddTraits(row.node.focused ? .isSelected : [])

            ForEach(row.children, id: \.node.id) { child in
                NestedSidebarRowView(row: child, depth: depth + 1)
            }
        }
    }
}

/// Mount helper: returns a subtree view when the beta is on and a snapshot exists.
struct NestedSidebarSubtreeHost: View {
    let hostStableSurfaceID: UUID
    let snapshot: NestedSidebarSubtreeSnapshot?
    let onToggleExpansion: () -> Void

    var body: some View {
        if NestedTopologyController.isEnabled, let snapshot {
            NestedSidebarSubtreeView(
                snapshot: snapshot,
                onToggleExpansion: onToggleExpansion
            )
            .equatable()
            .accessibilityIdentifier("NestedTopologySubtree.\(hostStableSurfaceID.uuidString)")
        }
    }
}
