import CmuxNestedTopology
import Foundation

@MainActor
extension RemoteHerdrSurfaceMirror {
    /// Divider-drag begin (tmux ``splitTabBarDividerDragDidBegin``).
    func beginDividerDrag(splitKey: String, axis: RemoteHerdrSplitOrientation, assignedCells: Int) {
        live.beginDrag(splitKey: splitKey, axis: axis, assignedCells: assignedCells)
    }

    /// Divider-drag end → cells + whether to send ``pane.resize``.
    ///
    /// A no-op (same cells) must not send — Herdr never replies to a no-op.
    func endDividerDrag(
        draggedExtent: Double,
        axisSpan: Double,
        totalCells: Int,
        assignedCells: Int
    ) -> (cells: Int, shouldSend: Bool) {
        live.endDrag(
            draggedExtent: draggedExtent,
            axisSpan: axisSpan,
            totalCells: totalCells,
            assignedCells: assignedCells
        )
    }

    func noteResizeReply(assignedCells: Int, splitExists: Bool = true) {
        live.noteResizeReply(assignedCells: assignedCells, splitExists: splitExists)
        if live.dragHold == nil {
            imposeDividerPlan()
        }
    }
}
