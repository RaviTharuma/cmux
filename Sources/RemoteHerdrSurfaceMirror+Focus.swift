import Bonsplit
import Foundation

@MainActor
extension RemoteHerdrSurfaceMirror {
    /// User navigation inside the nested tree. Provider focus must not
    /// call this — it would steal the first responder.
    @discardableResult
    func navigateFocus(direction: NavigationDirection) -> Bool {
        let name: String
        switch direction {
        case .left: name = "left"
        case .right: name = "right"
        case .up: name = "up"
        case .down: name = "down"
        default: return false
        }
        guard let neighbor = live.navigateFocus(direction: name) else { return false }
        userFocus(paneID: neighbor)
        return true
    }

    /// Project Bonsplit focus without stealing the keyboard (provider path).
    func focusBonsplitPane(forHerdrPane paneID: String) {
        guard let bonsplitPane = bonsplitPaneByPaneID[paneID],
              bonsplitController.focusedPaneId != bonsplitPane else { return }
        let wasApplying = isApplyingFocus
        isApplyingFocus = true
        bonsplitController.focusPane(bonsplitPane)
        isApplyingFocus = wasApplying
    }
}
