import AppKit

final class StatusItemController: NSObject {
    private static let menuBarIconSize = NSSize(width: 18, height: 18)

    private let statusItem: NSStatusItem
    private let applicationTerminator: () -> Void
    private let statusIconProvider: () -> NSImage?

    init(
        statusItem: NSStatusItem? = nil,
        statusBar: NSStatusBar = .system,
        applicationTerminator: @escaping () -> Void = { NSApp.terminate(nil) },
        statusIconProvider: @escaping () -> NSImage? = StatusItemController.makeProductionStatusIcon
    ) {
        self.statusItem = statusItem ?? statusBar.statusItem(withLength: NSStatusItem.squareLength)
        self.applicationTerminator = applicationTerminator
        self.statusIconProvider = statusIconProvider
        super.init()
    }

    func install() {
        if let button = statusItem.button {
            button.title = ""
            button.image = statusIconProvider()
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

    static func makeTrayTemplateStatusIcon(bundle: Bundle = .main) -> NSImage? {
        guard let image = bundle.image(forResource: NSImage.Name("TrayIconTemplate")) else {
            return nil
        }

        return makeMenuBarStatusIconCopy(from: image)
    }

    static func makeDefaultStatusIcon(
        trayIconProvider: () -> NSImage? = { makeTrayTemplateStatusIcon(bundle: .main) },
        appIconProvider: () -> NSImage? = {
            let namedAppIcon = NSImage(named: NSImage.applicationIconName)
            return namedAppIcon ?? NSApp.applicationIconImage
        }
    ) -> NSImage? {
        if let trayIcon = trayIconProvider() {
            return makeMenuBarStatusIconCopy(from: trayIcon)
        }

        guard let appIcon = appIconProvider() else {
            return nil
        }

        return makeMenuBarStatusIconCopy(from: appIcon)
    }

    private static func makeProductionStatusIcon() -> NSImage? {
        makeDefaultStatusIcon()
    }

    private static func makeMenuBarStatusIconCopy(from image: NSImage) -> NSImage? {
        guard let copiedImage = image.copy() as? NSImage else {
            return nil
        }

        copiedImage.size = menuBarIconSize
        copiedImage.isTemplate = true
        return copiedImage
    }
}
