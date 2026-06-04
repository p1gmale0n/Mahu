import AppKit

final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let applicationTerminator: () -> Void

    init(
        statusItem: NSStatusItem? = nil,
        statusBar: NSStatusBar = .system,
        applicationTerminator: @escaping () -> Void = { NSApp.terminate(nil) }
    ) {
        self.statusItem = statusItem ?? statusBar.statusItem(withLength: NSStatusItem.squareLength)
        self.applicationTerminator = applicationTerminator
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.title = ""
            button.image = NSImage(systemSymbolName: "figure.walk.circle", accessibilityDescription: "Mahu")
            button.image?.isTemplate = true
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc private func quit() {
        applicationTerminator()
    }
}
