#if os(macOS)
import AppKit
import CoreText

/// Cache key for the glyph cache. Stable across ObjectIdentifier of the
/// font (SwiftTerm reuses a single primary font instance).
struct GlyphCacheKey: Hashable {
    let scalar: UInt32
    let fontId: ObjectIdentifier
    let styleBits: UInt8   // 0=plain, bit 0=bold, bit 1=italic

    static let plain: UInt8     = 0
    static let bold: UInt8      = 1 << 0
    static let italic: UInt8    = 1 << 1
    static let underline: UInt8 = 1 << 2
}

/// One cached glyph plus the layout info the draw path needs.
struct CachedGlyph {
    let ctFont: CTFont
    let glyph: CGGlyph
    let advance: CGSize
    let bounds: CGRect
    let isColored: Bool
}

/// LRU-bounded glyph cache. Keyed by Unicode scalar + font + style.
/// Default capacity 4096 entries; tuned for typical terminal ASCII hit rates.
final class GlyphCache {
    private var entries: [GlyphCacheKey: CachedGlyph] = [:]
    /// Access order: head = LRU, tail = MRU.
    private var order: [GlyphCacheKey] = []
    private let capacity: Int

    // MARK: - Hit/miss counters (for future perf verification)
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0

    init(capacity: Int = 4096) {
        self.capacity = capacity
        entries.reserveCapacity(capacity)
        order.reserveCapacity(capacity)
    }

    /// Look up a glyph. Returns nil if not cached; otherwise moves the
    /// entry to MRU and returns the cached layout.
    func lookup(_ key: GlyphCacheKey) -> CachedGlyph? {
        guard let hit = entries[key] else { return nil }
        // Move to tail (MRU).
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
            order.append(key)
        }
        return hit
    }

    /// Insert. Evicts LRU if at capacity.
    func insert(_ key: GlyphCacheKey, _ value: CachedGlyph) {
        if entries[key] != nil {
            // Replace in place, bump to MRU.
            entries[key] = value
            if let idx = order.firstIndex(of: key) {
                order.remove(at: idx)
                order.append(key)
            }
            return
        }
        if order.count >= capacity {
            let evicted = order.removeFirst()
            entries.removeValue(forKey: evicted)
        }
        entries[key] = value
        order.append(key)
    }

    /// Compute the glyph for a scalar + font + style. Caches the result.
    /// Returns nil if the font lacks a glyph for this scalar (shouldn't
    /// happen for ASCII).
    func glyph(for scalar: Unicode.Scalar, font: NSFont, styleBits: UInt8) -> CachedGlyph? {
        let key = GlyphCacheKey(scalar: scalar.value,
                                fontId: ObjectIdentifier(font),
                                styleBits: styleBits)
        if let hit = lookup(key) {
            hits += 1
            return hit
        }
        misses += 1

        // Apply bold/italic trait via NSFontManager.
        var displayFont = font
        if styleBits & GlyphCacheKey.bold != 0 {
            displayFont = NSFontManager.shared.convert(displayFont, toHaveTrait: .boldFontMask)
        }
        if styleBits & GlyphCacheKey.italic != 0 {
            displayFont = NSFontManager.shared.convert(displayFont, toHaveTrait: .italicFontMask)
        }

        let ctFont = displayFont as CTFont
        var unichars: [UniChar]
        if scalar.value < 0x10000 {
            unichars = [UniChar(scalar.value)]
        } else {
            // Surrogate pair for scalars >= 0x10000.
            let v = scalar.value - 0x10000
            unichars = [UniChar(0xD800 | (v >> 10)), UniChar(0xDC00 | (v & 0x3FF))]
        }
        var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
        guard CTFontGetGlyphsForCharacters(ctFont, unichars, &glyphs, unichars.count),
              let firstGlyph = glyphs.first, firstGlyph != 0 else {
            return nil
        }

        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, &advances, glyphs.count)
        let advance = advances.reduce(.zero) { CGSize(width: $0.width + $1.width, height: max($0.height, $1.height)) }

        var rects = [CGRect](repeating: .zero, count: glyphs.count)
        CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, glyphs, &rects, glyphs.count)
        let bounds = rects.reduce(CGRect.null) { $0.union($1) }

        let isColored = CTFontGetSymbolicTraits(ctFont).contains(.traitColorGlyphs)

        let cached = CachedGlyph(ctFont: ctFont, glyph: firstGlyph,
                                 advance: advance, bounds: bounds,
                                 isColored: isColored)
        insert(key, cached)
        return cached
    }

    /// Pre-populate cache for the given string using the given font at plain style.
    /// Call from setup() with ASCII 32-126 to warm the hot path before first paint.
    func warm(string: String, font: NSFont) {
        for scalar in string.unicodeScalars {
            _ = glyph(for: scalar, font: font, styleBits: GlyphCacheKey.plain)
        }
    }

    // MARK: - Test introspection

    var count: Int { order.count }
    var capacityForTesting: Int { capacity }

    /// Reset hit/miss counters. Useful in tests to isolate measurement windows.
    func resetCounters() {
        hits = 0
        misses = 0
    }
}
#endif
