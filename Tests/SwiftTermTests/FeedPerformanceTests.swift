#if os(macOS)
import XCTest
@testable import SwiftTerm

final class FeedPerformanceTests: XCTestCase {
    private static let queue: DispatchQueue = DispatchQueue(
        label: "FeedPerformanceTests",
        qos: .userInteractive,
        attributes: .concurrent
    )

    /// Measures feed+parse cost for ASCII workload. Records baseline;
    /// XCTest flags significant regressions from saved baseline.
    func testFeedThroughputASCII() {
        let h = HeadlessTerminal(queue: FeedPerformanceTests.queue) { _ in }
        let t = h.terminal!
        let payload = String(repeating: "Hello, world!\n", count: 1000)
        let bytes = Array(payload.utf8)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            t.feed(byteArray: bytes)
        }
    }

    /// Mixed SGR workload.
    func testFeedThroughputWithSGR() {
        let h = HeadlessTerminal(queue: FeedPerformanceTests.queue) { _ in }
        let t = h.terminal!
        let payload = (0..<500).map { _ in
            "\u{1B}[31mred\u{1B}[32mgreen\u{1B}[1mbold\u{1B}[0m\n"
        }.joined()
        let bytes = Array(payload.utf8)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            t.feed(byteArray: bytes)
        }
    }

    /// Scroll-heavy — exercises L1.5 scroll-blit path.
    func testFeedScrollHeavy() {
        let h = HeadlessTerminal(queue: FeedPerformanceTests.queue) { _ in }
        let t = h.terminal!
        let payload = String(repeating: "\n", count: 1000)
        let bytes = Array(payload.utf8)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            t.feed(byteArray: bytes)
        }
    }
}
#endif
