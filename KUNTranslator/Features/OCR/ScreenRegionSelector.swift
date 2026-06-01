import AppKit

@MainActor
final class ScreenRegionSelector {
    private var continuation: CheckedContinuation<CGRect, Error>?
    private var panels: [NSPanel] = []

    func selectRegion() async throws -> CGRect {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            showPanels()
        }
    }

    private func showPanels() {
        panels = NSScreen.screens.map { screen in
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = RegionSelectionView(frame: screen.frame)
            view.onFinish = { [weak self] rect in
                self?.finish(rect)
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }
            panel.contentView = view
            panel.makeKeyAndOrderFront(nil)
            return panel
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(_ rect: CGRect) {
        cleanup()
        continuation?.resume(returning: rect)
        continuation = nil
    }

    private func cancel() {
        cleanup()
        continuation?.resume(throwing: KUNError.screenshotCancelled)
        continuation = nil
    }

    private func cleanup() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }
}

private final class RegionSelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        window?.makeFirstResponder(self)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectedRect(), rect.width > 8, rect.height > 8 else {
            onCancel?()
            return
        }
        let globalOrigin = window?.convertPoint(toScreen: rect.origin) ?? rect.origin
        onFinish?(CGRect(origin: globalOrigin, size: rect.size))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard let rect = selectedRect() else { return }
        NSColor.clear.setFill()
        rect.fill(using: .clear)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }

    private func selectedRect() -> CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }
}
