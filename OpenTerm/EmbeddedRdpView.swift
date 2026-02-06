import SwiftUI
import AppKit

struct EmbeddedRdpView: NSViewRepresentable {
    let session: RdpSession

    func makeNSView(context: Context) -> RdpHostView {
        let host = RdpHostView()
        host.attach(view: session.view) { size in
            session.updateViewport(size: size)
        }
        return host
    }

    func updateNSView(_ nsView: RdpHostView, context: Context) {
        nsView.attach(view: session.view) { size in
            session.updateViewport(size: size)
        }
    }
}

final class RdpHostView: NSView {
    private weak var hostedView: NSView?
    private var onResize: ((NSSize) -> Void)?
    private var lastReportedSize: NSSize = .zero

    func attach(view: NSView, onResize: @escaping (NSSize) -> Void) {
        if hostedView !== view {
            subviews.forEach { $0.removeFromSuperview() }
            hostedView = view
            view.translatesAutoresizingMaskIntoConstraints = true
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        self.onResize = onResize
        layout()
    }

    override func layout() {
        super.layout()
        hostedView?.frame = bounds
        let size = bounds.size
        let rounded = NSSize(
            width: max(1, floor(size.width)),
            height: max(1, floor(size.height))
        )
        if rounded != lastReportedSize {
            lastReportedSize = rounded
            onResize?(rounded)
        }
    }
}
