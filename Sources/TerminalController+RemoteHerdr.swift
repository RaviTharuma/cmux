import Foundation
import CmuxNestedTopology

/// Socket/CLI handlers for ``remote.herdr.*`` (tmux ``TerminalController+RemoteTmux``).
///
/// New file. ``TerminalController.swift`` still needs the switch cases
/// registered (one-line additions). Every method gates on
/// ``RemoteHerdrController.isEnabled``.
extension TerminalController {
    /// `remote.herdr.sessions`
    nonisolated func v2RemoteHerdrSessions(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        let dispatched = RemoteHerdrAttachPlanner.dispatch(
            method: "remote.herdr.sessions",
            params: params,
            enabled: true
        )
        return v2Result(id: id, dispatched)
    }

    /// `remote.herdr.attach`
    nonisolated func v2RemoteHerdrAttach(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2Result(
            id: id,
            RemoteHerdrAttachPlanner.dispatch(method: "remote.herdr.attach", params: params, enabled: true)
        )
    }

    /// `remote.herdr.mirror`
    nonisolated func v2RemoteHerdrMirror(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2Result(
            id: id,
            RemoteHerdrAttachPlanner.dispatch(method: "remote.herdr.mirror", params: params, enabled: true)
        )
    }

    /// `remote.herdr.window`
    nonisolated func v2RemoteHerdrWindow(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2Result(
            id: id,
            RemoteHerdrAttachPlanner.dispatch(method: "remote.herdr.window", params: params, enabled: true)
        )
    }

    /// `remote.herdr.detach` — leaves the Herdr session alive.
    nonisolated func v2RemoteHerdrDetach(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2VmCall(id: id, timeoutSeconds: 10) {
            await MainActor.run { RemoteHerdrController.shared.detach() }
            return ["detached": true, "server_stopped": false]
        }
    }

    /// `remote.herdr.state`
    nonisolated func v2RemoteHerdrState(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2Result(
            id: id,
            RemoteHerdrAttachPlanner.dispatch(method: "remote.herdr.state", params: params, enabled: true)
        )
    }

    /// `remote.herdr.pane_surfaces`
    nonisolated func v2RemoteHerdrPaneSurfaces(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2VmCall(id: id, timeoutSeconds: 10) {
            await MainActor.run {
                RemoteHerdrController.shared.host.observe(
                    method: "remote.herdr.pane_surfaces",
                    params: params
                )
            }
        }
    }

    /// `remote.herdr.pane_grids`
    nonisolated func v2RemoteHerdrPaneGrids(id: Any?, params: [String: Any]) -> String {
        guard RemoteHerdrController.isEnabled else {
            return v2Error(id: id, code: "disabled", message: "remote Herdr mirror beta is disabled")
        }
        return v2VmCall(id: id, timeoutSeconds: 10) {
            await MainActor.run {
                RemoteHerdrController.shared.host.observe(
                    method: "remote.herdr.pane_grids",
                    params: params
                )
            }
        }
    }
}
