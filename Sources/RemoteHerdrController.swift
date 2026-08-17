import CmuxNestedTopology
import Foundation

/// App-owned Herdr mirror controller (tmux ``RemoteTmuxController``).
///
/// Held as ``RemoteHerdrController.shared`` so AppDelegate.swift does
/// not need a stored property while lane A owns that file. Attach,
/// detach, restore, ``remote.herdr.*``, and the live apply host all
/// go through here. Surface mirrors are keyed by tab id so
/// Workspace.swift does not grow a stored property.
@MainActor
final class RemoteHerdrController {
    static let shared = RemoteHerdrController()

    /// Twin of tmux ``betaFeatures.remoteTmux``.
    nonisolated static var isEnabled: Bool {
        RemoteHerdrLifecycle.decodeBeta(
            UserDefaults.standard.object(forKey: RemoteHerdrLifecycle.settingKey)
                ?? UserDefaults.standard.object(forKey: "remoteHerdr.mirror.beta.enabled")
                ?? UserDefaults.standard.object(forKey: "betaFeatures.remoteHerdrMirror"),
            default: false
        )
    }

    private(set) var host = RemoteHerdrLiveHost(enabled: true)
    private(set) var mirrors: [String: RemoteHerdrSurfaceMirror] = [:]
    private var nativeLiveMarkerURL: URL?

    private init() {}

    /// Attach discovered sessions and claim the single-writer lock.
    func attach(windows: [RemoteHerdrWindow], sessions: [RemoteHerdrDiscoveredSession] = []) {
        guard Self.isEnabled else { return }
        host.enabled = true
        _ = host.applySession(windows)
        if !sessions.isEmpty {
            _ = host.attach(sessions: sessions)
        }
        host.setNativeLive()
        writeNativeLiveMarker()
    }

    func apply(windows: [RemoteHerdrWindow]) {
        guard Self.isEnabled else { return }
        _ = host.applySession(windows)
    }

    /// Host close / quit: detach, never ``server.stop``.
    func detach() {
        for mirror in mirrors.values {
            mirror.teardown()
        }
        mirrors.removeAll()
        _ = host.detach()
        clearNativeLiveMarker()
    }

    /// Restore after cmux restart: reattach, never replay a stale tree.
    func restore(windows: [RemoteHerdrWindow], sessions: [RemoteHerdrDiscoveredSession]) {
        host.detach()
        for mirror in mirrors.values {
            mirror.teardown()
        }
        mirrors.removeAll()
        _ = host.restore(sessions: sessions, windows: windows)
        writeNativeLiveMarker()
    }

    func routeOutput(paneID: String, data: Data) -> Bool {
        if let mirror = mirrors.values.first(where: { $0.live.surfaces[paneID] != nil }) {
            mirror.routeOutput(paneID: paneID, data: data)
            return true
        }
        return host.routeOutput(paneID: paneID, data: Array(data))
    }

    func routeCwd(paneID: String, path: String) {
        if let mirror = mirrors.values.first(where: { $0.live.surfaces[paneID] != nil }) {
            mirror.routeCwd(paneID: paneID, path: path)
            return
        }
        _ = host.routeCwd(paneID: paneID, path: path)
    }

    func register(_ mirror: RemoteHerdrSurfaceMirror) {
        mirrors[mirror.tabID] = mirror
    }

    private func writeNativeLiveMarker() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = (root ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("cmux-herdr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("native-live")
        try? Data("1\n".utf8).write(to: url)
        nativeLiveMarkerURL = url
    }

    private func clearNativeLiveMarker() {
        if let url = nativeLiveMarkerURL {
            try? FileManager.default.removeItem(at: url)
        }
        nativeLiveMarkerURL = nil
    }
}
