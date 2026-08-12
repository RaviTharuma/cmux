/// Deterministic ordering helpers for nested topology collections.
public struct NestedTopologyOrdering: Sendable {
    /// Sorts workspaces by order index, then compound ID.
    public static func sortedWorkspaces(_ workspaces: [NestedWorkspaceNode]) -> [NestedWorkspaceNode] {
        workspaces.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id < $1.id
        }
    }

    /// Sorts tabs by order index, then compound ID.
    public static func sortedTabs(_ tabs: [NestedTabNode]) -> [NestedTabNode] {
        tabs.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id < $1.id
        }
    }

    /// Sorts panes by order index, then compound ID.
    public static func sortedPanes(_ panes: [NestedPaneNode]) -> [NestedPaneNode] {
        panes.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id < $1.id
        }
    }

    /// Sorts agents by order index, then compound ID.
    public static func sortedAgents(_ agents: [NestedAgentNode]) -> [NestedAgentNode] {
        agents.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id < $1.id
        }
    }
}
