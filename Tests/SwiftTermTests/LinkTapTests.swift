//
//  LinkTapTests.swift
//
// A touch tap opens the link under it without a hover first (meaterm-ios). The lookup lives in
// AppleTerminalView, shared by both platforms, so it is tested here through the macOS view; the
// iOS `singleTap` calls `linkForTap`.
//

#if os(macOS)
import Foundation
import Testing

@testable import SwiftTerm

@MainActor
struct LinkTapTests {
    private func view(_ text: String, mode: LinkHighlightMode) -> TerminalView {
        let view = TerminalView(frame: CGRect(origin: .zero, size: .init(width: 400, height: 100)))
        view.linkHighlightMode = mode
        view.terminal.feed(text: text)
        return view
    }

    @Test func testTapOpensImplicitLinkWithoutHover() {
        let view = view("see https://example.com/x tail", mode: .hover)
        // A click needs the hover highlight first, which a finger never makes.
        #expect(view.linkForClick(at: Position(col: 8, row: 0), hasCommandModifier: false) == nil)
        #expect(view.linkForTap(at: Position(col: 8, row: 0), hasCommandModifier: false)?.link == "https://example.com/x")
    }

    @Test func testTapOpensExplicitLinkWithoutHover() {
        let view = view("\u{1b}]8;id=a;https://example.com/osc\u{1b}\\shown\u{1b}]8;;\u{1b}\\ rest", mode: .hover)
        let result = view.linkForTap(at: Position(col: 2, row: 0), hasCommandModifier: false)
        #expect(result?.link == "https://example.com/osc")
        #expect(result?.params == ["id": "a"])
    }

    @Test func testTapOnPlainTextOpensNothing() {
        let view = view("see https://example.com/x tail", mode: .hover)
        #expect(view.linkForTap(at: Position(col: 1, row: 0), hasCommandModifier: false) == nil)
        #expect(view.linkForTap(at: Position(col: 27, row: 0), hasCommandModifier: false) == nil)
    }

    @Test func testAlwaysModeOpensImplicitLinksOnTap() {
        let view = view("https://example.com/x", mode: .always)
        #expect(view.linkForTap(at: Position(col: 3, row: 0), hasCommandModifier: false)?.link == "https://example.com/x")
    }

    @Test func testModifierModesStillWantTheCommandKey() {
        for mode in [LinkHighlightMode.hoverWithModifier, .alwaysWithModifier] {
            let view = view("https://example.com/x", mode: mode)
            #expect(view.linkForTap(at: Position(col: 3, row: 0), hasCommandModifier: false) == nil)
            #expect(view.linkForTap(at: Position(col: 3, row: 0), hasCommandModifier: true)?.link == "https://example.com/x")
        }
    }
    @Test func testRefusedLinkIsLeftToTheTerminal() {
        let view = view("cat /tmp/meaterm-x", mode: .hover)
        let at = Position(col: 8, row: 0)
        // Positive control: the path is found as an implicit link.
        #expect(view.linkForTap(at: at, hasCommandModifier: false)?.link == "/tmp/meaterm-x")
        let refused = view.touchTapLink(at: at, hasCommandModifier: false, dismissesFirst: false,
                                        opens: { $0.hasPrefix("https://") })
        #expect(refused == nil)
        let unfiltered = view.touchTapLink(at: at, hasCommandModifier: false, dismissesFirst: false, opens: nil)
        #expect(unfiltered?.link == "/tmp/meaterm-x")
    }

    @Test func testAcceptedLinkOpens() {
        let view = view("see https://example.com/x tail", mode: .hover)
        let result = view.touchTapLink(at: Position(col: 8, row: 0), hasCommandModifier: false,
                                       dismissesFirst: false, opens: { $0.hasPrefix("https://") })
        #expect(result?.link == "https://example.com/x")
    }

    @Test func testOpenSelectionOrMenuTakesTheTap() {
        let view = view("see https://example.com/x tail", mode: .hover)
        let result = view.touchTapLink(at: Position(col: 8, row: 0), hasCommandModifier: false,
                                       dismissesFirst: true, opens: nil)
        #expect(result == nil)
    }
}
#endif
