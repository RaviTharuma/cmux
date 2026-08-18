import Foundation
import Testing
@testable import CmuxNestedTopology

@Suite struct RemoteHerdrSerialWorkQueueTests {
    actor AppliedBox {
        var value = ""
        func set(_ next: String) { value = next }
        func get() -> String { value }
    }

    @Test func laterSnapshotRemainsApplied() async {
        let queue = RemoteHerdrSerialWorkQueue()
        let box = AppliedBox()
        async let first = queue.enqueue(.snapshot) {
            try? await Task.sleep(for: .milliseconds(40))
            await box.set("old")
            return "old"
        }
        async let second = queue.enqueue(.snapshot) {
            await box.set("new")
            return "new"
        }
        let results = await (first, second)
        #expect(results.0 == "old")
        #expect(results.1 == "new")
        #expect(await box.get() == "new")
    }

    @Test func laterSendOnSamePaneRemainsApplied() async {
        let queue = RemoteHerdrSerialWorkQueue()
        let box = AppliedBox()
        async let first = queue.enqueue(.send(paneID: "p1")) {
            try? await Task.sleep(for: .milliseconds(40))
            await box.set("old-keys")
            return "old-keys"
        }
        async let second = queue.enqueue(.send(paneID: "p1")) {
            await box.set("new-keys")
            return "new-keys"
        }
        _ = await (first, second)
        #expect(await box.get() == "new-keys")
    }
}
