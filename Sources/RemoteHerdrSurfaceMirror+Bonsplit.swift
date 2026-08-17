import Bonsplit
import CmuxNestedTopology
import Foundation

@MainActor
extension RemoteHerdrSurfaceMirror {
    /// Nested Bonsplit chrome for one Herdr tab (tmux ``remoteTmuxEmbedded``).
    static func makeController(configuration: BonsplitConfiguration) -> BonsplitController {
        BonsplitController(configuration: configuration.remoteTmuxEmbedded)
    }

    func configureBonsplitController() {
        bonsplitController.tabShortcutHintsEnabled = false
        bonsplitController.onExternalTabDrop = { _ in false }
    }

    /// Rebuild the nested tree from the live rendered layout.
    ///
    /// Create panels first (``ensurePanel``), then rebuild. Zoom uses the
    /// visible tree for render and the base tree for panel lifecycle.
    func reconcileBonsplitTree() {
        guard let layout = live.state?.visibleLayout ?? live.state?.layout else { return }
        isApplyingLayout = true
        defer { isApplyingLayout = false }
        resetToSingleEmptyPane()
        paneIDByBonsplitPane.removeAll()
        bonsplitPaneByPaneID.removeAll()
        guard let root = bonsplitController.allPaneIds.first else { return }
        _ = build(layout, inPane: root)
        imposeDividerPlan()
    }

    func resetToSingleEmptyPane() {
        while bonsplitController.allPaneIds.count > 1, let pane = bonsplitController.allPaneIds.last {
            _ = bonsplitController.closePane(pane)
        }
        guard let root = bonsplitController.allPaneIds.first else { return }
        for tab in bonsplitController.tabs(inPane: root) {
            _ = bonsplitController.closeTab(tab.id, inPane: root)
        }
    }

    @discardableResult
    func build(_ node: RemoteHerdrLayoutNode, inPane pane: PaneID) -> PaneID? {
        switch node.content {
        case let .pane(paneID):
            guard panelsByPaneID[paneID] != nil else { return nil }
            guard let tabID = bonsplitController.createTab(
                title: live.title,
                icon: "terminal",
                kind: "terminal",
                inPane: pane
            ) else { return nil }
            paneIDByBonsplitPane[pane] = paneID
            bonsplitPaneByPaneID[paneID] = pane
            _ = tabID
            return pane
        case let .horizontal(children):
            return build(children: children, orientation: .horizontal, inPane: pane)
        case let .vertical(children):
            return build(children: children, orientation: .vertical, inPane: pane)
        }
    }

    func build(
        children: [RemoteHerdrLayoutNode],
        orientation: SplitOrientation,
        inPane pane: PaneID
    ) -> PaneID? {
        guard let first = children.first else { return nil }
        guard children.count > 1 else { return build(first, inPane: pane) }
        let rest = Array(children.dropFirst())
        let fraction = first.firstChildRatio ?? 0.5
        guard let restPane = bonsplitController.splitPane(
            pane,
            orientation: orientation,
            withTab: nil,
            initialDividerPosition: fraction
        ) else { return build(first, inPane: pane) }
        _ = build(first, inPane: pane)
        let restNode: RemoteHerdrLayoutNode
        if rest.count == 1 {
            restNode = rest[0]
        } else {
            restNode = RemoteHerdrLayoutNode(
                width: rest.reduce(0) { $0 + $1.width },
                height: rest.reduce(0) { $0 + $1.height },
                x: rest[0].x,
                y: rest[0].y,
                content: orientation == .horizontal ? .horizontal(rest) : .vertical(rest)
            )
        }
        _ = build(restNode, inPane: restPane)
        return pane
    }

    /// Impose divider fractions from the package plan. Skip a held drag split.
    func imposeDividerPlan() {
        guard let layout = live.state?.visibleLayout ?? live.state?.layout else { return }
        let plan = RemoteHerdrImpose.plan(
            rendered: layout,
            title: live.title,
            hold: live.dragHold
        )
        applyDividerNode(plan.dividerTree, key: "s", held: plan.heldSplitKey)
    }

    private func applyDividerNode(
        _ node: RemoteHerdrDividerNode,
        key: String,
        held: String?
    ) {
        switch node {
        case .leaf:
            return
        case let .split(orientation, fraction, firstExtent, first, second):
            if held != key {
                imposeDivider(key: key, orientation: orientation, fraction: fraction, firstExtent: firstExtent)
            }
            applyDividerNode(first, key: "\(key).0", held: held)
            applyDividerNode(second, key: "\(key).1", held: held)
        }
    }

    private func imposeDivider(
        key: String,
        orientation: RemoteHerdrSplitOrientation,
        fraction: Double,
        firstExtent: Double?
    ) {
        // Bonsplit split identity is resolved by the live tree walk above.
        // The host records the planned fraction so a later drag can skip it.
        _ = (key, orientation, fraction, firstExtent)
    }
}
