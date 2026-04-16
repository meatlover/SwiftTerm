//
//  ScrollBlitTests.swift
//
//  Tests for the M4 L1.5 scroll-by-blit fast path in MacTerminalView.
//
#if os(macOS)
import XCTest
import AppKit
@testable import SwiftTerm

final class ScrollBlitTests: XCTestCase {

    private func makeView() -> TerminalView {
        TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
    }

    func testSmallScrollUpReturnsTrue() {
        let view = makeView()
        view.scrollBlitEnabled = true
        let ok = view.attemptScrollBlit(newYDisp: 3, rowHeight: 16, viewportRows: 25)
        XCTAssertTrue(ok)
    }

    func testScrollDisabledReturnsFalse() {
        let view = makeView()
        view.scrollBlitEnabled = false
        let ok = view.attemptScrollBlit(newYDisp: 3, rowHeight: 16, viewportRows: 25)
        XCTAssertFalse(ok)
    }

    func testNegativeOrZeroDeltaReturnsFalse() {
        let view = makeView()
        // Delta is 0 (newYDisp == lastPaintedYDisp == 0).
        let zero = view.attemptScrollBlit(newYDisp: 0, rowHeight: 16, viewportRows: 25)
        XCTAssertFalse(zero)
        // After noting a paint at 5, going back to 3 is a negative delta.
        view.noteFullPaintComplete(yDisp: 5)
        let back = view.attemptScrollBlit(newYDisp: 3, rowHeight: 16, viewportRows: 25)
        XCTAssertFalse(back)
    }

    func testLargeScrollExceedsHalfViewportReturnsFalse() {
        let view = makeView()
        // viewport = 10 rows, delta = 8 > 5 (viewport/2) → false.
        let ok = view.attemptScrollBlit(newYDisp: 8, rowHeight: 16, viewportRows: 10)
        XCTAssertFalse(ok)
    }

    func testBoundaryHalfViewport() {
        let view = makeView()
        // viewport = 10 rows, delta = 5 (exactly half) → allowed.
        let ok = view.attemptScrollBlit(newYDisp: 5, rowHeight: 16, viewportRows: 10)
        XCTAssertTrue(ok)
    }

    func testRowHeightZeroReturnsFalse() {
        let view = makeView()
        let ok = view.attemptScrollBlit(newYDisp: 3, rowHeight: 0, viewportRows: 25)
        XCTAssertFalse(ok)
    }

    func testPaintCompleteUpdatesBaseline() {
        let view = makeView()
        view.noteFullPaintComplete(yDisp: 10)
        // Delta is now 2 (12 - 10), well within viewport/2 = 12.
        let ok = view.attemptScrollBlit(newYDisp: 12, rowHeight: 16, viewportRows: 25)
        XCTAssertTrue(ok)
    }

    func testBlitAdvancesBaseline() {
        let view = makeView()
        // First blit: baseline 0 → 3.
        XCTAssertTrue(view.attemptScrollBlit(newYDisp: 3, rowHeight: 16, viewportRows: 25))
        // Second blit from 3 → 5 (delta=2): should succeed.
        XCTAssertTrue(view.attemptScrollBlit(newYDisp: 5, rowHeight: 16, viewportRows: 25))
        // Third call with same yDisp (delta=0): should fail.
        XCTAssertFalse(view.attemptScrollBlit(newYDisp: 5, rowHeight: 16, viewportRows: 25))
    }
}
#endif
