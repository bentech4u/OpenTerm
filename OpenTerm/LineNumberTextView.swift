import SwiftUI
import AppKit

struct LineNumberTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: CursorPosition
    var font: NSFont
    var isEditable: Bool
    var wordWrap: Bool
    var onTextChange: ((String) -> Void)?

    struct CursorPosition: Equatable {
        var line: Int = 1
        var column: Int = 1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = LineNumberScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wordWrap
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = LineNumberNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = font

        // Use explicit white color for dark mode visibility
        let textColor = NSColor.white
        textView.textColor = textColor
        textView.backgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        textView.insertionPointColor = textColor
        textView.drawsBackground = true
        textView.isRichText = false
        textView.usesFindPanel = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Set typing attributes to ensure text is visible
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]

        if wordWrap {
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        } else {
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.autoresizingMask = [.width]
        textView.textContainer?.lineFragmentPadding = 5

        scrollView.documentView = textView
        scrollView.setupLineNumberView(for: textView)

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.updateCursorPosition()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        textView.font = font
        textView.isEditable = isEditable

        let textColor = NSColor.white
        textView.textColor = textColor
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]

        // Re-apply color to existing text
        if let textStorage = textView.textStorage {
            textStorage.addAttribute(.foregroundColor, value: textColor, range: NSRange(location: 0, length: textStorage.length))
        }

        if wordWrap {
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
        } else {
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
        }

        if let lineNumberScrollView = scrollView as? LineNumberScrollView {
            lineNumberScrollView.lineNumberView?.needsDisplay = true
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LineNumberTextView
        weak var textView: NSTextView?

        init(_ parent: LineNumberTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let newText = textView.string
            if parent.text != newText {
                parent.text = newText
                parent.onTextChange?(newText)
            }
            updateLineNumbers()
            updateCursorPosition()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateCursorPosition()
        }

        func updateCursorPosition() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString

            var lineNumber = 1
            var charCount = 0
            let lines = text.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                let lineLength = line.count + 1 // +1 for newline
                if charCount + lineLength > selectedRange.location {
                    lineNumber = index + 1
                    let column = selectedRange.location - charCount + 1
                    DispatchQueue.main.async {
                        self.parent.cursorPosition = CursorPosition(line: lineNumber, column: column)
                    }
                    return
                }
                charCount += lineLength
            }

            DispatchQueue.main.async {
                self.parent.cursorPosition = CursorPosition(line: lines.count, column: 1)
            }
        }

        func updateLineNumbers() {
            guard let textView = textView,
                  let scrollView = textView.enclosingScrollView as? LineNumberScrollView else { return }
            scrollView.lineNumberView?.needsDisplay = true
        }
    }
}

final class LineNumberScrollView: NSScrollView {
    var lineNumberView: LineNumberRulerView?

    func setupLineNumberView(for textView: NSTextView) {
        let rulerView = LineNumberRulerView(textView: textView)
        rulerView.clientView = textView
        lineNumberView = rulerView

        hasVerticalRuler = true
        verticalRulerView = rulerView
        rulersVisible = true
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let gutterWidth: CGFloat = 40

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        ruleThickness = gutterWidth

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func boundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let backgroundColor = NSColor.controlBackgroundColor
        backgroundColor.setFill()
        rect.fill()

        let separatorColor = NSColor.separatorColor
        separatorColor.setStroke()
        let separatorPath = NSBezierPath()
        separatorPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: rect.minY))
        separatorPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: rect.maxY))
        separatorPath.lineWidth = 1
        separatorPath.stroke()

        let content = textView.string as NSString
        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let textFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let lineNumberFont = NSFont.monospacedDigitSystemFont(ofSize: textFont.pointSize * 0.85, weight: .regular)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        var lineNumber = 1
        var glyphIndex = 0
        let numberOfGlyphs = layoutManager.numberOfGlyphs

        while glyphIndex < numberOfGlyphs {
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)

            let lineY = lineRect.minY - visibleRect.origin.y
            let lineBottom = lineRect.maxY - visibleRect.origin.y

            if lineBottom >= rect.minY && lineY <= rect.maxY {
                let lineNumberString = "\(lineNumber)"
                let size = lineNumberString.size(withAttributes: attrs)
                let x = gutterWidth - size.width - 8
                let y = lineY + (lineRect.height - size.height) / 2

                lineNumberString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }

            glyphIndex = NSMaxRange(lineRange)

            // Check if this is a hard line break
            if glyphIndex < numberOfGlyphs {
                let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex - 1)
                if charIndex < content.length {
                    let char = content.character(at: charIndex)
                    if char == 10 || char == 13 { // \n or \r
                        lineNumber += 1
                    }
                }
            }
        }

        // Handle empty document or last line
        if content.length == 0 || content.hasSuffix("\n") {
            let lastRect = layoutManager.extraLineFragmentRect
            if !lastRect.isEmpty {
                let lineY = lastRect.minY - visibleRect.origin.y
                let lineNumberString = "\(lineNumber)"
                let size = lineNumberString.size(withAttributes: attrs)
                let x = gutterWidth - size.width - 8
                let y = lineY + (lastRect.height - size.height) / 2
                lineNumberString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
        }
    }
}

final class LineNumberNSTextView: NSTextView {
    override func performFindPanelAction(_ sender: Any?) {
        super.performFindPanelAction(sender)
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return super.validateMenuItem(menuItem)
    }
}
