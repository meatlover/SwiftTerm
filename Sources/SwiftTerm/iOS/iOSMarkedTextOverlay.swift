//
//  iOSMarkedTextOverlay.swift
//
// Shows the text an input method is composing (the UITextInput "marked text", such as the
// pinyin letters typed before a candidate is chosen) at the caret. The iPad pinyin keyboard's
// candidate bar shows only the candidates, so without this the letters being typed are seen
// nowhere.
//
// The overlay is display only: the marked text never enters the terminal buffer and is never
// sent. What the input method finally commits goes through `insertText` as before.
//
// Placement: the caret cell. When the text does not fit between the caret and the right edge
// of the view, it moves left until it fits; text wider than the view starts at x = 0 and is
// clipped at the right.
//
// For UI tests and VoiceOver the overlay is the accessibility element
// `MarkedTextOverlay.accessibilityID`, its value the marked text. While there is no marked text
// it is out of the view hierarchy: a hidden view that has an accessibility identifier was still
// listed by XCUITest (iOS 27.0 simulator).
//

#if os(iOS) || os(visionOS)
import Foundation
import UIKit

final class MarkedTextOverlay: UILabel {
    static let accessibilityID = "terminal.marked"

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        isAccessibilityElement = false
        accessibilityIdentifier = MarkedTextOverlay.accessibilityID
        numberOfLines = 1
        lineBreakMode = .byClipping
        clipsToBounds = true
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The overlay's x and width for text `textWidth` wide whose caret is at `caretX`, in a view
    /// `viewWidth` wide: at the caret when it fits, moved left until it fits otherwise, and from
    /// 0 clipped to the view's width when it is wider than the view.
    static func placement(textWidth: CGFloat, caretX: CGFloat, viewWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let viewWidth = max(0, viewWidth)
        guard textWidth < viewWidth else {
            return (0, viewWidth)
        }
        return (max(0, min(caretX, viewWidth - textWidth)), textWidth)
    }

    func show(_ text: String, font: UIFont, foreground: UIColor, background: UIColor) {
        attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: foreground,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: foreground
        ])
        backgroundColor = background
        accessibilityValue = text
        isAccessibilityElement = true
        isHidden = false
    }

    func hide() {
        guard superview != nil else { return }
        isHidden = true
        isAccessibilityElement = false
        accessibilityValue = nil
        attributedText = nil
        removeFromSuperview()
    }
}

extension TerminalView {
    /// The text the input method is composing, or nil when there is none.
    var currentMarkedText: String? {
        guard let range = _markedTextRange, !range.isEmpty else { return nil }
        let count = textInputStorage.count
        guard range.startPosition.offset >= 0, range.endPosition.offset <= count else { return nil }
        return String(textInputStorage[range.fullRange(in: textInputStorage)])
    }

    /// An opaque color for the overlay's background: the terminal's background as it is drawn.
    private var markedTextBackground: UIColor {
        for color in [nativeBackgroundColor, backgroundColor] {
            if let color, color.cgColor.alpha > 0 {
                return color
            }
        }
        if let layerColor = layer.backgroundColor, layerColor.alpha > 0 {
            return UIColor(cgColor: layerColor)
        }
        return .systemBackground
    }

    /// Shows, moves or hides the marked-text overlay to match the current marked text and caret.
    /// Called after every text input edit and whenever the caret moves.
    func updateMarkedTextOverlay() {
        guard let text = currentMarkedText, !text.isEmpty else {
            markedTextOverlay?.hide()
            return
        }
        let overlay: MarkedTextOverlay
        if let existing = markedTextOverlay {
            overlay = existing
        } else {
            overlay = MarkedTextOverlay(frame: .zero)
            markedTextOverlay = overlay
        }
        if overlay.superview !== self {
            addSubview(overlay)
        }
        overlay.show(text, font: fontSet.normal, foreground: nativeForegroundColor, background: markedTextBackground)

        let buffer = terminal.displayBuffer
        let caretX = cellDimension.width * CGFloat(buffer.x)
        let caretY = cellDimension.height * CGFloat(buffer.y + buffer.yBase)
        let textSize = overlay.intrinsicContentSize
        let place = MarkedTextOverlay.placement(textWidth: ceil(textSize.width), caretX: caretX,
                                                viewWidth: bounds.width)
        overlay.frame = CGRect(x: place.x, y: caretY, width: place.width,
                               height: max(cellDimension.height, ceil(textSize.height)))
        bringSubviewToFront(overlay)
    }
}
#endif
