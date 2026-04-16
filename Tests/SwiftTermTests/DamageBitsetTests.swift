//
//  DamageBitsetTests.swift
//
//  Tests for the M4 L1.4 per-line damage bitset in Buffer.
//

import XCTest
@testable import SwiftTerm

final class DamageBitsetTests: XCTestCase {

    private func makeTerminal(cols: Int = 80, rows: Int = 24) -> Terminal {
        let (terminal, _) = TerminalTestHarness.makeTerminal(cols: cols, rows: rows)
        return terminal
    }

    func testInitialDamageIsEmpty() {
        let t = makeTerminal()
        let damage = t.buffer.takeDamage()
        XCTAssertTrue(damage.lines.isEmpty)
        XCTAssertFalse(damage.all)
    }

    func testMarkDamagedLine() {
        let t = makeTerminal()
        t.buffer.markDamaged(line: 5)
        let damage = t.buffer.takeDamage()
        XCTAssertEqual(damage.lines, [5])
    }

    func testMarkDamagedRange() {
        let t = makeTerminal()
        t.buffer.markDamaged(lines: 2..<5)
        let damage = t.buffer.takeDamage()
        XCTAssertEqual(damage.lines, [2, 3, 4])
    }

    func testMarkAllDamagedFlag() {
        let t = makeTerminal()
        t.buffer.markAllDamaged()
        let damage = t.buffer.takeDamage()
        XCTAssertTrue(damage.all)
    }

    func testTakeDamageClears() {
        let t = makeTerminal()
        t.buffer.markDamaged(line: 3)
        _ = t.buffer.takeDamage()
        let second = t.buffer.takeDamage()
        XCTAssertTrue(second.lines.isEmpty)
        XCTAssertFalse(second.all)
    }

    func testDedupesDuplicateLines() {
        let t = makeTerminal()
        t.buffer.markDamaged(line: 3)
        t.buffer.markDamaged(line: 3)
        t.buffer.markDamaged(line: 3)
        let damage = t.buffer.takeDamage()
        XCTAssertEqual(damage.lines, [3])
    }

    /// Feeding a character should damage the cursor line.
    func testFeedDamagesCurrentLine() {
        let t = makeTerminal()
        _ = t.buffer.takeDamage() // clear any initial damage
        t.feed(text: "x")
        let damage = t.buffer.takeDamage()
        XCTAssertFalse(damage.lines.isEmpty || damage.all,
                       "feeding a char should damage something")
    }
}
