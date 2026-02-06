import SwiftUI
import SwiftTerm
import AppKit

struct EmbeddedTerminalView: NSViewRepresentable {
    let terminalView: LocalProcessTerminalView

    func makeNSView(context: Context) -> TerminalHostView {
        let host = TerminalHostView()
        host.setTerminalView(terminalView)
        return host
    }

    func updateNSView(_ nsView: TerminalHostView, context: Context) {
        nsView.setTerminalView(terminalView)
    }
}

final class TerminalHostView: NSView {
    private weak var hostedView: NSView?

    func setTerminalView(_ view: NSView) {
        if hostedView === view { return }

        subviews.forEach { $0.removeFromSuperview() }
        hostedView = view

        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
