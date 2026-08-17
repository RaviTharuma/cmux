import AppKit
import Bonsplit
import CmuxNestedTopology
import CmuxTerminal
import Foundation

/// AppKit host for one Herdr tab (tmux ``RemoteTmuxWindowMirror``).
///
/// Owns the nested ``BonsplitController`` and one ``TerminalPanel`` per
/// Herdr pane id (string, not tmux ``Int``). The package
/// ``RemoteHerdrLiveWindow`` is the apply machine; this type is the
/// Ghostty/Bonsplit swap. Lane B owns this file — do not fold it into
/// Workspace.swift while lane A owns that file.
@MainActor
final class RemoteHerdrSurfaceMirror {
    let tabID: String
    let panelID: UUID
    var bonsplitController: BonsplitController
    let makePanel: (_ paneID: String) -> TerminalPanel?
    var onTerminalPanelAdded: ((TerminalPanel) -> Void)?
    var onTerminalPanelRemoved: ((TerminalPanel) -> Void)?
    var onInput: ((String, TerminalManualInput) -> Void)?
    var onResize: ((String, Int, Int) -> Void)?
    var onCwd: ((String, String) -> Void)?

    private(set) var live = RemoteHerdrLiveWindow(tabID: "", title: "")
    private(set) var panelsByPaneID: [String: TerminalPanel] = [:]
    private(set) var paneIDByBonsplitPane: [PaneID: String] = [:]
    private(set) var bonsplitPaneByPaneID: [String: PaneID] = [:]
    var isApplyingFocus = false
    var isApplyingLayout = false
    var isTornDown = false
    var isVisibleForSizing = true

    init(
        tabID: String,
        title: String,
        panelID: UUID,
        bonsplitController: BonsplitController,
        makePanel: @escaping (_ paneID: String) -> TerminalPanel?
    ) {
        self.tabID = tabID
        self.panelID = panelID
        self.bonsplitController = bonsplitController
        self.makePanel = makePanel
        self.live = RemoteHerdrLiveWindow(tabID: tabID, title: title)
    }

    /// Create the Ghostty panel *before* the Bonsplit rebuild.
    @discardableResult
    func ensurePanel(paneID: String) -> TerminalPanel? {
        if let existing = panelsByPaneID[paneID] { return existing }
        guard let panel = makePanel(paneID) else { return nil }
        panelsByPaneID[paneID] = panel
        _ = live.makePanel(paneID: paneID)
        onTerminalPanelAdded?(panel)
        return panel
    }

    func closePanel(paneID: String) {
        live.closePanel(paneID: paneID)
        if let panel = panelsByPaneID.removeValue(forKey: paneID) {
            panel.surface.onManualSizeApplied = nil
            panel.close()
            onTerminalPanelRemoved?(panel)
        }
        if let bonsplitPane = bonsplitPaneByPaneID.removeValue(forKey: paneID) {
            paneIDByBonsplitPane.removeValue(forKey: bonsplitPane)
        }
    }

    /// Package apply, then mount created panels and impose the tree.
    func apply(window: RemoteHerdrWindow) {
        guard !isTornDown else { return }
        isApplyingLayout = true
        defer { isApplyingLayout = false }
        let ops = live.apply(window: window)
        for op in ops where op.hasPrefix("make_panel:") {
            let paneID = String(op.dropFirst("make_panel:".count))
            _ = ensurePanel(paneID: paneID)
        }
        for op in ops where op.hasPrefix("close_panel:") {
            let paneID = String(op.dropFirst("close_panel:".count))
            closePanel(paneID: paneID)
        }
        reconcileBonsplitTree()
        if let focus = window.activePaneID {
            applyProviderFocus(paneID: focus)
        }
        if isVisibleForSizing {
            _ = updateClientSize()
        }
    }

    /// ``%output`` → exactly one Ghostty surface.
    func routeOutput(paneID: String, data: Data) {
        _ = live.routeOutput(paneID: paneID, data: Array(data))
        panelsByPaneID[paneID]?.surface.processRemoteOutput(data)
    }

    func routeCwd(paneID: String, path: String) {
        guard let update = live.routeCwd(paneID: paneID, path: path), update.applyToTab else {
            return
        }
        onCwd?(paneID, update.path)
    }

    func handleManualInput(paneID: String, input: TerminalManualInput) {
        switch input {
        case let .bytes(data):
            if let text = String(data: data, encoding: .utf8) {
                _ = live.sendText(paneID: paneID, text: text)
            }
        case let .namedKey(name):
            _ = live.sendNamedKey(paneID: paneID, name: name)
        }
        onInput?(paneID, input)
    }

    func applyProviderFocus(paneID: String) {
        isApplyingFocus = true
        defer { isApplyingFocus = false }
        live.applyProviderFocus(paneID: paneID)
        focusBonsplitPane(forHerdrPane: paneID)
    }

    func userFocus(paneID: String) {
        guard !isApplyingFocus else { return }
        _ = live.userFocus(paneID: paneID)
        focusBonsplitPane(forHerdrPane: paneID)
        panelsByPaneID[paneID]?.hostedView.moveFocus()
    }

    func updateClientSize() -> (Int, Int)? {
        live.isVisibleForSizing = isVisibleForSizing
        return live.updateClientSize()
    }

    func teardown() {
        isTornDown = true
        live.teardown()
        for paneID in Array(panelsByPaneID.keys) {
            closePanel(paneID: paneID)
        }
    }
}
