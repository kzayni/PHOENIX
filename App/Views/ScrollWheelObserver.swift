import AppKit
import SwiftUI

/// Observes scroll-wheel events over its bounds without participating in hit
/// testing, so SwiftUI drag and magnification gestures continue to work.
struct ScrollWheelObserver: NSViewRepresentable {
    let onScroll: (_ scaleFactor: CGFloat, _ location: CGPoint, _ size: CGSize) -> Void

    func makeNSView(context: Context) -> ScrollWheelObservingView {
        let view = ScrollWheelObservingView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelObservingView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelObservingView: NSView {
    var onScroll: ((_ scaleFactor: CGFloat, _ location: CGPoint, _ size: CGSize) -> Void)?

    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateEventMonitor()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    private func updateEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        guard window != nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.window === window else { return }
        let appKitLocation = convert(event.locationInWindow, from: nil)
        guard bounds.contains(appKitLocation) else { return }

        let sensitivity = event.hasPreciseScrollingDeltas ? 0.015 : 0.12
        let limitedDelta = min(max(event.scrollingDeltaY, -40), 40)
        let scaleFactor = exp(limitedDelta * sensitivity)
        let swiftUILocation = CGPoint(
            x: appKitLocation.x,
            y: bounds.height - appKitLocation.y
        )
        onScroll?(scaleFactor, swiftUILocation, bounds.size)
    }
}
