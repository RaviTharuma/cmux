import AppKit

extension GhosttyNSView {
    func deliverUploadResultText(_ text: String) {
        guard let surface = terminalSurface else { return }
        let handledByMirror = MainActor.assumeIsolated {
            AppDelegate.shared?.remoteTmuxController.pasteIntoMirror(
                surfaceId: surface.id,
                text: text
            ) ?? false
        }
        if handledByMirror { return }
        let isHerdrMirrorPane = MainActor.assumeIsolated {
            AppDelegate.shared?.remoteHerdrController.isMirrorPaneSurface(surface.id) == true
        }
        if isHerdrMirrorPane {
            Task { @MainActor in
                let handledByHerdr = await AppDelegate.shared?.remoteHerdrController.pasteIntoMirror(
                    surfaceId: surface.id,
                    text: text
                ) ?? false
                if !handledByHerdr {
                    surface.sendText(text)
                }
            }
            return
        }
        surface.sendText(text)
    }

    @discardableResult
    func handleCustomDropUploadIfMatched(
        plan: TerminalImageTransferPlan,
        operation: TerminalImageTransferOperation
    ) -> Bool {
        TerminalCustomUploadRunner().handleIfMatched(
            plan: plan,
            operation: operation,
            cleanup: { GhosttyApp.terminalPasteboard.cleanupTransferredTemporaryImageFiles($0) },
            completion: { [weak self] result in
                self?.terminalSurface?.hostedView.endImageTransferIndicator(for: operation)
                switch result {
                case .success(let text):
                    self?.deliverUploadResultText(text)
                case .failure:
                    NSSound.beep()
#if DEBUG
                    cmuxDebugLog("terminal.remoteDropUpload.customFailed surface=\(self?.terminalSurface?.id.uuidString.prefix(5) ?? "nil")")
#endif
                }
            }
        )
    }
}
