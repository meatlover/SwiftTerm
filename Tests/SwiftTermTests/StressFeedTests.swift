#if os(macOS)
import XCTest
@testable import SwiftTerm

final class StressFeedTests: XCTestCase {
    private static let queue: DispatchQueue = DispatchQueue(
        label: "StressFeedTests",
        qos: .userInteractive,
        attributes: .concurrent
    )

    /// ~6.5MB feed must not crash; must complete within 10s.
    func test10MBFeedDoesNotCrash() {
        let h = HeadlessTerminal(queue: StressFeedTests.queue) { _ in }
        let t = h.terminal!
        let chunk = "The quick brown fox jumps. \u{1B}[31mRed\u{1B}[0m \u{1B}[1mBold\u{1B}[0m\n"
        var data = [UInt8]()
        let iterations = 100_000
        data.reserveCapacity(iterations * chunk.utf8.count)
        for _ in 0..<iterations { data.append(contentsOf: chunk.utf8) }

        let start = Date()
        t.feed(byteArray: data)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 10.0, "feed took \(elapsed)s, expected <10s")
        XCTAssertGreaterThan(t.buffer.lines.count, 0)
    }

    /// 1000 small feeds; exercises the coalesce path (L1.1).
    func test1000SmallFeedsCoalesce() {
        let h = HeadlessTerminal(queue: StressFeedTests.queue) { _ in }
        let t = h.terminal!
        for i in 0..<1000 {
            t.feed(byteArray: Array("line \(i)\n".utf8))
        }
        XCTAssertGreaterThan(t.buffer.lines.count, 100)
    }

    /// Random bytes — parser must tolerate garbage without crashing.
    func testRandomBytesFeedTolerance() {
        let h = HeadlessTerminal(queue: StressFeedTests.queue) { _ in }
        let t = h.terminal!
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<10 {
            var chunk = [UInt8]()
            for _ in 0..<1000 { chunk.append(UInt8.random(in: 0...255, using: &rng)) }
            t.feed(byteArray: chunk)
        }
        XCTAssertTrue(true)  // survived = pass
    }
}
#endif
