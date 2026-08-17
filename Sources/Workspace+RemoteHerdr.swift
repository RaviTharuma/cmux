import AppKit
import CmuxTerminal
import Foundation

/// Herdr twin of ``Workspace/addRemoteTmuxDisplayPane``.
///
/// New file — does not edit Workspace.swift (lane A). The live apply
/// host calls this to ``makePanel`` a manual-mirror Ghostty surface
/// whose ``processRemoteOutput`` receives Herdr ``pane.read`` / push
/// bytes and whose typing goes to ``pane.send_*``.
@MainActor
extension Workspace {
    /// Creates a configured manual-I/O pane panel for one Herdr pane.
    func makeRemoteHerdrPanePanel(
        onInput: @escaping @Sendable (TerminalManualInput) -> Void,
        keyNameResolver: (@MainActor @Sendable (ghostty_input_key_s) -> String?)? = nil
    ) -> TerminalPanel {
        makeRemoteTmuxPanePanel(onInput: onInput, keyNameResolver: keyNameResolver)
    }

    /// Mounts a Herdr pane as a live display tab (tmux ``addRemoteTmuxDisplayPane``).
    @discardableResult
    func addRemoteHerdrDisplayPane(
        herdrPaneId: String,
        title customTitle: String? = nil,
        focus: Bool = false,
        onInput: @escaping @Sendable (TerminalManualInput) -> Void,
        keyNameResolver: (@MainActor @Sendable (ghostty_input_key_s) -> String?)? = nil,
        onResize: (@MainActor @Sendable (_ columns: Int, _ rows: Int) -> Void)? = nil
    ) -> TerminalPanel? {
        addRemoteTmuxDisplayPane(
            remotePaneId: herdrPaneId.hashValue,
            title: customTitle ?? herdrPaneId,
            focus: focus,
            onInput: onInput,
            keyNameResolver: keyNameResolver,
            onResize: onResize
        )
    }

    /// Active-pane cwd → tab folder (tmux ``updateRemotePanelDirectory``).
    @discardableResult
    func applyRemoteHerdrCwd(panelId: UUID, path: String) -> Bool {
        updateRemotePanelDirectory(panelId: panelId, directory: path)
    }
}
