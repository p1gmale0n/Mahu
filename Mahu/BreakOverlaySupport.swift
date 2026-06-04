import AppKit
import Foundation
import SwiftUI

struct DisplayDescriptor: Equatable, Hashable {
    let id: String
    let frame: CGRect

    init(frame: CGRect, id: String? = nil) {
        self.id = id ?? "\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
        self.frame = frame
    }

    static func liveFallbackIdentifier(for screen: NSScreen, ordinal: Int) -> String {
        let frame = screen.frame
        return "screen-\(ordinal)-\(frame.origin.x),\(frame.origin.y),\(frame.size.width),\(frame.size.height)"
    }
}

struct PreviousFrontmostApplication {
    let reactivate: () -> Void
}

@MainActor
protocol BreakOverlayWindowing: AnyObject {
    func show()
    func close()
}

@MainActor
protocol BreakOverlayWindowBuilding {
    func makeWindow(for display: DisplayDescriptor, viewModel: BreakOverlayViewModel) -> BreakOverlayWindowing
}

struct ActiveOverlay {
    let display: DisplayDescriptor
    let window: BreakOverlayWindowing
}

struct BreakOverlayReconciliation {
    let activeOverlays: [ActiveOverlay]
    let didChangeWindows: Bool
}

@MainActor
enum BreakOverlayReconciler {
    static func reconcile(
        activeOverlays: [ActiveOverlay],
        displays: [DisplayDescriptor],
        viewModel: BreakOverlayViewModel,
        windowBuilder: BreakOverlayWindowBuilding
    ) -> BreakOverlayReconciliation {
        var overlaysByDisplayID = activeOverlaysByDisplayID(activeOverlays)
        var nextActiveOverlays: [ActiveOverlay] = []
        var didChangeWindows = false

        for display in displays {
            guard let existingOverlay = takeActiveOverlay(for: display, from: &overlaysByDisplayID) else {
                let window = windowBuilder.makeWindow(for: display, viewModel: viewModel)
                window.show()
                nextActiveOverlays.append(ActiveOverlay(display: display, window: window))
                didChangeWindows = true
                continue
            }

            guard existingOverlay.display == display else {
                existingOverlay.window.close()
                let replacementWindow = windowBuilder.makeWindow(for: display, viewModel: viewModel)
                replacementWindow.show()
                nextActiveOverlays.append(ActiveOverlay(display: display, window: replacementWindow))
                didChangeWindows = true
                continue
            }

            nextActiveOverlays.append(existingOverlay)
        }

        if overlaysByDisplayID.isEmpty == false {
            overlaysByDisplayID.values.flatMap { $0 }.forEach { $0.window.close() }
            didChangeWindows = true
        }

        return BreakOverlayReconciliation(
            activeOverlays: nextActiveOverlays,
            didChangeWindows: didChangeWindows
        )
    }

    private static func activeOverlaysByDisplayID(_ activeOverlays: [ActiveOverlay]) -> [String: [ActiveOverlay]] {
        activeOverlays.reduce(into: [:]) { partialResult, overlay in
            partialResult[overlay.display.id, default: []].append(overlay)
        }
    }

    private static func takeActiveOverlay(
        for display: DisplayDescriptor,
        from overlaysByDisplayID: inout [String: [ActiveOverlay]]
    ) -> ActiveOverlay? {
        guard var overlays = overlaysByDisplayID[display.id], overlays.isEmpty == false else {
            return nil
        }

        let matchingIndex = overlays.firstIndex { $0.display == display } ?? overlays.startIndex
        let overlay = overlays.remove(at: matchingIndex)

        if overlays.isEmpty {
            overlaysByDisplayID.removeValue(forKey: display.id)
        } else {
            overlaysByDisplayID[display.id] = overlays
        }

        return overlay
    }
}

enum LiveScreenProvider {
    static func activeDisplays() -> [DisplayDescriptor] {
        NSScreen.screens.enumerated().map { ordinal, screen in
            let screenNumber = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
            let displayID = screenNumber ?? DisplayDescriptor.liveFallbackIdentifier(for: screen, ordinal: ordinal)
            return DisplayDescriptor(frame: screen.frame, id: displayID)
        }
    }
}

@MainActor
final class LiveBreakOverlayWindowBuilder: BreakOverlayWindowBuilding {
    func makeWindow(for display: DisplayDescriptor, viewModel: BreakOverlayViewModel) -> BreakOverlayWindowing {
        LiveBreakOverlayWindow(display: display, viewModel: viewModel)
    }
}

final class BreakOverlayWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

@MainActor
final class LiveBreakOverlayWindow: BreakOverlayWindowing {
    let window: NSWindow

    init(display: DisplayDescriptor, viewModel: BreakOverlayViewModel) {
        let window = BreakOverlayWindow(
            contentRect: display.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovable = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BreakOverlayView(viewModel: viewModel))

        self.window = window
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}
