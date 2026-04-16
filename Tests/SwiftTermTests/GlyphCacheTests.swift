#if os(macOS)
import XCTest
import AppKit
import CoreText
@testable import SwiftTerm

final class GlyphCacheTests: XCTestCase {
    func testInsertAndLookup() {
        let cache = GlyphCache()
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        let g = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: 0)
        XCTAssertNotNil(g)
        XCTAssertGreaterThan(g!.advance.width, 0)
        XCTAssertEqual(cache.count, 1)
    }

    func testSecondLookupIsHit() {
        let cache = GlyphCache()
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        _ = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: 0)
        let hit = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: 0)
        XCTAssertNotNil(hit)
        XCTAssertEqual(cache.count, 1, "hit should not grow cache")
    }

    func testLruEviction() {
        let cache = GlyphCache(capacity: 3)
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        for ch in "ABCD" {
            _ = cache.glyph(for: Unicode.Scalar(String(ch))!, font: font, styleBits: 0)
        }
        XCTAssertEqual(cache.count, 3)
        // "A" should have been evicted (oldest).
        let keyA = GlyphCacheKey(scalar: UInt32("A".unicodeScalars.first!.value),
                                 fontId: ObjectIdentifier(font),
                                 styleBits: 0)
        XCTAssertNil(cache.lookup(keyA))
    }

    func testBoldStyleIsSeparateKey() {
        let cache = GlyphCache()
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        _ = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: 0)
        _ = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: GlyphCacheKey.bold)
        XCTAssertEqual(cache.count, 2, "bold A should be a distinct cache entry")
    }

    func testCapacityIsFixed() {
        let cache = GlyphCache(capacity: 10)
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        for ch in "!\"#$%&'()*+,-./0123456789" {
            _ = cache.glyph(for: Unicode.Scalar(String(ch))!, font: font, styleBits: 0)
        }
        XCTAssertLessThanOrEqual(cache.count, 10)
    }

    func testMruOrderAfterHit() {
        let cache = GlyphCache(capacity: 3)
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        for ch in "ABC" {
            _ = cache.glyph(for: Unicode.Scalar(String(ch))!, font: font, styleBits: 0)
        }
        // Touch A to make it MRU.
        _ = cache.glyph(for: Unicode.Scalar("A"), font: font, styleBits: 0)
        // Insert D, evicts B (now LRU).
        _ = cache.glyph(for: Unicode.Scalar("D"), font: font, styleBits: 0)
        let keyB = GlyphCacheKey(scalar: UInt32("B".unicodeScalars.first!.value),
                                 fontId: ObjectIdentifier(font), styleBits: 0)
        XCTAssertNil(cache.lookup(keyB), "B should be evicted")
        let keyA = GlyphCacheKey(scalar: UInt32("A".unicodeScalars.first!.value),
                                 fontId: ObjectIdentifier(font), styleBits: 0)
        XCTAssertNotNil(cache.lookup(keyA), "A should survive")
    }

    func testWarmPopulatesCache() {
        let cache = GlyphCache()
        let font = NSFont.userFixedPitchFont(ofSize: 13)!
        let ascii = String((32...126).compactMap { Unicode.Scalar($0).map { Character($0) } })
        cache.warm(string: ascii, font: font)
        XCTAssertGreaterThan(cache.count, 90, "ASCII warm should populate most printable characters")
    }
}
#endif
