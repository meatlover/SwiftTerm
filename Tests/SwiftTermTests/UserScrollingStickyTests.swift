//
//  UserScrollingStickyTests.swift
//
//  Verifies that once the user scrolls up (yDisp < yBase), incoming
//  output keeps yDisp pinned where the user left it, and that
//  scrolling back to the bottom resumes auto-follow.
//
import XCTest
@testable import SwiftTerm

final class UserScrollingStickyTests: XCTestCase {

    /// Build a Terminal with a generous scrollback and a small viewport
    /// so we can scroll up easily.
    private func makeTerminal() -> Terminal {
        final class NopDelegate: TerminalDelegate {
            func send(source: Terminal, data: ArraySlice<UInt8>) {}
        }
        var opts = TerminalOptions()
        opts.cols = 20
        opts.rows = 5
        opts.scrollback = 1000
        return Terminal(delegate: NopDelegate(), options: opts)
    }

    /// Feed `n` newline-separated short lines into the terminal so
    /// `yBase` advances by `n` (after the initial 5-row viewport fills).
    private func feedLines(_ term: Terminal, count: Int, prefix: String = "L") {
        var bytes: [UInt8] = []
        for i in 0..<count {
            let line = "\(prefix)\(i)\r\n"
            bytes.append(contentsOf: Array(line.utf8))
        }
        term.feed(buffer: bytes[...])
    }

    func testScrolledUpHoldsThroughStreamingOutput() {
        let t = makeTerminal()

        // Fill enough lines to push yBase well past the viewport so we
        // have meaningful scrollback. Exact value depends on \r\n
        // accounting in feed; we capture it after the fact rather than
        // hard-coding.
        feedLines(t, count: 50)
        XCTAssertGreaterThanOrEqual(t.buffer.yBase, 40, "precondition: enough scrollback")
        XCTAssertEqual(t.buffer.yDisp, t.buffer.yBase, "precondition: yDisp tracks yBase before scroll")

        // User scrolls up to row 10 (deep in scrollback).
        t.setViewYDisp(10)
        XCTAssertEqual(t.buffer.yDisp, 10, "precondition: scrollTo took effect")

        let yBaseBeforeStreaming = t.buffer.yBase

        // Stream 30 more lines.
        feedLines(t, count: 30, prefix: "M")

        XCTAssertGreaterThan(t.buffer.yBase, yBaseBeforeStreaming, "yBase advances with new output")
        XCTAssertEqual(t.buffer.yDisp, 10,
            "FAIL: viewport snapped back to bottom while user was scrolled up — this is the bug")
    }

    func testScrollingBackToBottomResumesAutoFollow() {
        let t = makeTerminal()
        feedLines(t, count: 50)              // yBase advances past viewport
        t.setViewYDisp(10)                   // user scrolls up
        feedLines(t, count: 5, prefix: "M")  // streaming, yDisp must stay at 10
        XCTAssertEqual(t.buffer.yDisp, 10)

        // User scrolls back to the bottom.
        t.setViewYDisp(t.buffer.yBase)       // yDisp = yBase
        let yBaseAfterReturn = t.buffer.yBase

        feedLines(t, count: 5, prefix: "N")  // yBase advances by ~5
        XCTAssertGreaterThan(t.buffer.yBase, yBaseAfterReturn, "yBase advances with new output")
        XCTAssertEqual(t.buffer.yDisp, t.buffer.yBase,
            "after returning to bottom, auto-follow resumes (yDisp tracks yBase)")
    }

    func testAltBufferIsUnaffected() {
        // Alt buffer (vim/htop) has no scrollback; userScrolling must
        // never lock the alt-buffer viewport.
        let t = makeTerminal()
        // Switch to alt buffer (DECSET 1049 — typical entry).
        let altOn: [UInt8] = Array("\u{1B}[?1049h".utf8)
        t.feed(buffer: altOn[...])

        feedLines(t, count: 10)
        XCTAssertTrue(t.isCurrentBufferAlternate, "precondition: alt buffer active")
        // yDisp/yBase semantics still apply (no scrollback → both 0).
        XCTAssertEqual(t.buffer.yDisp, t.buffer.yBase,
            "alt buffer must always keep yDisp == yBase regardless of userScrolling")
    }
}
