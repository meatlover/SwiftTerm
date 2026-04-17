#if os(macOS)
import XCTest
import AppKit
@testable import SwiftTerm

final class GlyphCacheDrawPathTests: XCTestCase {

    // MARK: - Fast-path eligibility matrix

    /// Verify the ASCII fast path is eligible only for single-scalar ASCII cells.
    func testFastPathEligibilityMatrix() {
        // Plain ASCII 'A' — eligible
        XCTAssertTrue(TerminalView.isFastPathEligible(cellString: "A", hasSelection: false, hasLink: false))

        // Entire printable ASCII range is eligible (space through tilde)
        XCTAssertTrue(TerminalView.isFastPathEligible(cellString: " ", hasSelection: false, hasLink: false))
        XCTAssertTrue(TerminalView.isFastPathEligible(cellString: "~", hasSelection: false, hasLink: false))

        // Non-ASCII: emoji with skin tone — ineligible (multiple scalars)
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "👍🏽", hasSelection: false, hasLink: false))

        // CJK — ineligible (scalar outside 0x20..0x7E)
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "中", hasSelection: false, hasLink: false))

        // DEL (0x7F) — ineligible (above 0x7E)
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "\u{7F}", hasSelection: false, hasLink: false))

        // ASCII but selected — ineligible
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "A", hasSelection: true, hasLink: false))

        // ASCII but has link — ineligible
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "A", hasSelection: false, hasLink: true))

        // Empty string — ineligible
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "", hasSelection: false, hasLink: false))

        // Multi-scalar ASCII sequence — ineligible (count > 1)
        XCTAssertFalse(TerminalView.isFastPathEligible(cellString: "AB", hasSelection: false, hasLink: false))
    }

    // MARK: - GlyphCache population

    /// After `warmGlyphCache` runs in `setup()`, the cache should hold ~95 entries
    /// (ASCII 32-126 = 95 printable characters, plain style).
    func testGlyphCacheHitRateAfterAsciiFeed() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        XCTAssertGreaterThanOrEqual(view.glyphCacheForTesting.count, 80,
            "ASCII warm should have populated at least 80 entries (expected ~95 for U+0020–U+007E)")
    }

    // MARK: - Hit/miss counters

    /// Hit counter increments on repeated lookups; miss counter increments on cold lookups.
    func testHitMissCounters() {
        let cache = GlyphCache(capacity: 16)
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let scalar = Unicode.Scalar("A")

        // Cold lookup — miss
        cache.resetCounters()
        _ = cache.glyph(for: scalar, font: font, styleBits: GlyphCacheKey.plain)
        XCTAssertEqual(cache.misses, 1)
        XCTAssertEqual(cache.hits, 0)

        // Warm lookup — hit
        _ = cache.glyph(for: scalar, font: font, styleBits: GlyphCacheKey.plain)
        XCTAssertEqual(cache.misses, 1)
        XCTAssertEqual(cache.hits, 1)

        // resetCounters clears both
        cache.resetCounters()
        XCTAssertEqual(cache.hits, 0)
        XCTAssertEqual(cache.misses, 0)
    }

    // MARK: - fastCellDraw flag

    /// `fastCellDraw` defaults to true and toggles cleanly.
    func testFastCellDrawFlagToggle() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        XCTAssertTrue(view.fastCellDraw, "fastCellDraw should default to true")
        view.fastCellDraw = false
        XCTAssertFalse(view.fastCellDraw)
        view.fastCellDraw = true
        XCTAssertTrue(view.fastCellDraw)
    }

    // MARK: - glyphCacheForTesting accessor

    /// The internal accessor returns the same cache instance that `warmGlyphCache` populates.
    func testGlyphCacheForTestingAccessor() {
        let view = TerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        let cache = view.glyphCacheForTesting
        // Cache should have been pre-warmed in setup()
        XCTAssertGreaterThan(cache.count, 0, "glyphCacheForTesting should return the live, pre-warmed cache")
    }
}
#endif
