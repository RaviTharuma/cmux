public import Foundation

/// Capability-gated pane I/O used by ``RemoteHerdrWindowMirror`` (tmux send-keys /
/// split-window / resize-pane / kill-pane / %output).
///
/// Implementations speak the provider socket only — never the `herdr` CLI.
public protocol RemoteHerdrPaneIO: Sendable {
    /// Forwards typed bytes to a Herdr pane (`pane.send` / `pane.send_keys`).
    func sendKeys(paneID: String, data: Data) async throws
    /// Splits a pane (`pane.split`).
    func splitPane(paneID: String, direction: RemoteHerdrSplitDirection) async throws
    /// Resizes a pane grid (`pane.resize`).
    func resizePane(paneID: String, cols: Int, rows: Int) async throws
    /// Closes a pane (`pane.close`). Host close still detaches without this.
    func closePane(paneID: String) async throws
    /// Reads current pane output (`pane.read`).
    func readPane(paneID: String, lines: Int) async throws -> Data
}

extension HerdrNestedTopologyClient: RemoteHerdrPaneIO {
    public func sendKeys(paneID: String, data: Data) async throws {
        let text = String(decoding: data, as: UTF8.self)
        _ = try await performRequest(
            method: "pane.send",
            params: ["pane_id": paneID, "text": text]
        )
    }

    public func splitPane(paneID: String, direction: RemoteHerdrSplitDirection) async throws {
        _ = try await performRequest(
            method: "pane.split",
            params: [
                "pane_id": paneID,
                "direction": direction.rawValue,
            ]
        )
    }

    public func resizePane(paneID: String, cols: Int, rows: Int) async throws {
        _ = try await performRequest(
            method: "pane.resize",
            params: [
                "pane_id": paneID,
                "cols": cols,
                "rows": rows,
            ]
        )
    }

    public func closePane(paneID: String) async throws {
        _ = try await performRequest(
            method: "pane.close",
            params: ["pane_id": paneID]
        )
    }

    public func readPane(paneID: String, lines: Int) async throws -> Data {
        let response = try await performRequest(
            method: "pane.read",
            params: [
                "pane_id": paneID,
                "lines": max(1, lines),
            ]
        )
        return Self.paneReadData(from: response.result)
    }

    /// Extracts UTF-8 pane text from a protocol-17 success payload.
    static func paneReadData(from result: HerdrWireResult?) -> Data {
        guard case let .other(_, object) = result else {
            return Data()
        }
        for key in ["text", "output", "content", "body", "data"] {
            if case let .string(text)? = object[key] {
                return Data(text.utf8)
            }
        }
        if case let .array(lines)? = object["lines"] {
            let joined = lines.compactMap { item -> String? in
                if case let .string(text) = item { return text }
                return nil
            }.joined(separator: "\n")
            return Data(joined.utf8)
        }
        return Data()
    }
}
