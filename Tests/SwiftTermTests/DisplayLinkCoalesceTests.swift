// DisplayLinkCoalesceTests.swift
// Tests for the M4 L1.1 CVDisplayLink-driven repaint coalescer in MacTerminalView.

import XCTest
@testable import SwiftTerm

#if os(macOS)
import AppKit
import CoreVideo

final class DisplayLinkCoalesceTests: XCTestCase {

    /// scheduleRepaint unions accumulated rects correctly.
    func testScheduleRepaintAccumulatesUnion() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        view.repaintCoalescing = true

        view.scheduleRepaint(NSRect(x: 0, y: 0, width: 100, height: 100))
        view.scheduleRepaint(NSRect(x: 200, y: 0, width: 100, height: 100))

        let accum = view.coalescedDirtyRectForTesting
        XCTAssertNotNil(accum, "Accumulated rect should be non-nil after two scheduleRepaint calls")
        XCTAssertEqual(accum?.minX, 0, "Union minX should be 0")
        XCTAssertEqual(accum?.maxX, 300, "Union maxX should be 300 (200+100)")
        XCTAssertEqual(accum?.minY, 0)
        XCTAssertEqual(accum?.maxY, 100)
    }

    /// With coalescing disabled, scheduleRepaint falls through immediately
    /// (nothing accumulates in the internal buffer).
    func testCoalescingDisabledIsFallThrough() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        view.repaintCoalescing = false

        view.scheduleRepaint(NSRect(x: 0, y: 0, width: 100, height: 100))

        let accum = view.coalescedDirtyRectForTesting
        XCTAssertNil(accum, "With coalescing off, nothing should accumulate")
    }

    /// flushCoalescedRepaint clears the accumulator.
    func testFlushResetsAccumulator() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        view.repaintCoalescing = true

        view.scheduleRepaint(NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNotNil(view.coalescedDirtyRectForTesting, "Should have an accumulated rect before flush")

        view.flushCoalescedRepaintForTesting()
        XCTAssertNil(view.coalescedDirtyRectForTesting, "Accumulator should be nil after flush")
    }

    /// Multiple calls to scheduleRepaint produce a single union rect spanning all regions.
    func testMultipleRectsAreUnioned() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        view.repaintCoalescing = true

        view.scheduleRepaint(NSRect(x: 10, y: 10, width: 50, height: 50))
        view.scheduleRepaint(NSRect(x: 100, y: 200, width: 80, height: 30))
        view.scheduleRepaint(NSRect(x: 5, y: 5, width: 20, height: 20))

        let accum = view.coalescedDirtyRectForTesting
        XCTAssertNotNil(accum)
        // Union of (10,10,50,50), (100,200,80,30), (5,5,20,20):
        // minX=5, minY=5, maxX=180, maxY=230
        XCTAssertEqual(accum?.minX, 5)
        XCTAssertEqual(accum?.minY, 5)
        XCTAssertEqual(accum?.maxX, 180)
        XCTAssertEqual(accum?.maxY, 230)
    }

    /// Toggling repaintCoalescing mid-session: re-enabling should accumulate again.
    func testTogglingCoalescingMidSession() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        view.repaintCoalescing = false
        view.scheduleRepaint(NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertNil(view.coalescedDirtyRectForTesting, "Should not accumulate when disabled")

        view.repaintCoalescing = true
        view.scheduleRepaint(NSRect(x: 50, y: 50, width: 100, height: 100))
        XCTAssertNotNil(view.coalescedDirtyRectForTesting, "Should accumulate after re-enabling")
    }
}
#endif
