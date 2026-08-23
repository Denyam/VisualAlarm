import Foundation
import Testing

@testable import VisualAlarm

@Suite(.serialized)
struct FlickerEffectControllerTests {

    @Test func startsOnAndAlternatesPhasesOnEachTick() async throws {
        let clock = VirtualClock()
        let counter = EffectCounterBox()
        let controller = FlickerEffectController(interval: .seconds(1))

        let task = controller.start(
            clock: clock,
            onPhase: { counter.incrementOn() },
            offPhase: { counter.incrementOff() },
            restore: { counter.incrementRestore() }
        )
        defer { task.cancel() }

        try await waitFor(counter.on == 1 && counter.off == 0)

        clock.tick()
        try await waitFor(counter.off == 1 && counter.on == 1)

        clock.tick()
        try await waitFor(counter.on == 2 && counter.off == 1)

        #expect(counter.restore == 0)
    }

    @Test func cancelInvokesRestoreExactlyOnce() async throws {
        let clock = VirtualClock()
        let counter = EffectCounterBox()

        let task = FlickerEffectController(interval: .seconds(1)).start(
            clock: clock,
            onPhase: { counter.incrementOn() },
            offPhase: { counter.incrementOff() },
            restore: { counter.incrementRestore() }
        )

        try await waitFor(counter.on == 1)

        task.cancel()
        clock.tick()

        try await waitFor(counter.restore == 1)
        _ = await task.result

        clock.tick()
        try await Task.sleep(for: .milliseconds(50))

        #expect(counter.restore == 1)
        #expect(counter.off == 0)
    }
}

final class EffectCounterBox: @unchecked Sendable {
    private let lock = NSLock()

    private var onCount = 0
    private var offCount = 0
    private var restoreCount = 0

    var on: Int {
        lock.lock()
        defer { lock.unlock() }
        return onCount
    }

    var off: Int {
        lock.lock()
        defer { lock.unlock() }
        return offCount
    }

    var restore: Int {
        lock.lock()
        defer { lock.unlock() }
        return restoreCount
    }

    func incrementOn() {
        lock.lock()
        onCount += 1
        lock.unlock()
    }

    func incrementOff() {
        lock.lock()
        offCount += 1
        lock.unlock()
    }

    func incrementRestore() {
        lock.lock()
        restoreCount += 1
        lock.unlock()
    }
}

private func waitFor(
    _ condition: @autoclosure () -> Bool,
    timeout seconds: TimeInterval = 5
) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(condition())
}
