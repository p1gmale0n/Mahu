import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testInstallUsesInjectedStatusIconProviderImage() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let expectedImage = NSImage(size: NSSize(width: 23, height: 17))
        var providerCallCount = 0
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: {
                providerCallCount += 1
                return expectedImage
            }
        )

        controller.install()

        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(statusItem.button?.image?.size, expectedImage.size)
        XCTAssertTrue(statusItem.button?.image?.isTemplate == true)
    }

    func testInstallConfiguresIconOnlyStatusItemWithQuitMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.install()

        XCTAssertEqual(statusItem.button?.title, "")
        XCTAssertEqual(statusItem.button?.imagePosition, .imageOnly)
        XCTAssertNotNil(statusItem.button?.image)
        XCTAssertEqual(statusItem.length, NSStatusItem.squareLength)
        XCTAssertNotNil(statusItem.menu)
        XCTAssertEqual(statusItem.menu?.items.last?.keyEquivalent, "q")
    }

    func testInstallDisablesReminderToggleUntilActionsAreConfigured() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.install()

        let pauseResumeItem = try pauseResumeMenuItem(in: statusItem.menu, named: "Pause Reminders")
        XCTAssertFalse(pauseResumeItem.isEnabled)
    }

    func testInstallStartsWithNormalStatusButtonOpacity() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )

        controller.install()

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertTrue(button.isEnabled)
    }

    func testSetRemindersPausedDimsExistingStatusItemIconWithoutChangingMenuContract() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()

        controller.setRemindersPaused(true)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertLessThan(button.alphaValue, 1.0)
        XCTAssertTrue(button.alphaValue >= 0.45)
        XCTAssertTrue(button.alphaValue <= 0.60)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Resume Reminders", "Quit"])
    }

    func testSetRemindersPausedFalseRestoresNormalStatusButtonOpacity() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { NSImage(size: NSSize(width: 18, height: 18)) }
        )
        controller.configureReminderActions(onPause: {}, onResume: {})
        controller.install()
        controller.setRemindersPaused(true)

        controller.setRemindersPaused(false)

        let button = try XCTUnwrap(statusItem.button)
        XCTAssertEqual(button.alphaValue, 1.0, accuracy: 0.001)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Pause Reminders", "Quit"])
    }

    func testTrayTemplateStatusIconProviderLoadsBundledAsset() throws {
        let image = try XCTUnwrap(StatusItemController.makeTrayTemplateStatusIcon())

        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }

    func testTrayTemplateStatusIconProviderLoadsImageFromProvidedBundle() throws {
        let bundleURL = try makeBundleWithTrayTemplateImage()
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let image = try XCTUnwrap(StatusItemController.makeTrayTemplateStatusIcon(bundle: bundle))

        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }

    func testTrayTemplateStatusIconProviderReturnsNilWhenProvidedBundleLacksImage() throws {
        let bundleURL = try makeBundle()
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        XCTAssertNil(StatusItemController.makeTrayTemplateStatusIcon(bundle: bundle))
    }

    func testDefaultStatusIconPrefersTrayTemplateProviderOverAppIconFallback() throws {
        let trayImage = NSImage(size: NSSize(width: 128, height: 128))
        var appIconProviderCallCount = 0

        let image = try XCTUnwrap(
            StatusItemController.makeDefaultStatusIcon(
                trayIconProvider: { trayImage },
                appIconProvider: {
                    appIconProviderCallCount += 1
                    return NSImage(size: NSSize(width: 256, height: 256))
                }
            )
        )

        XCTAssertEqual(appIconProviderCallCount, 0)
        XCTAssertFalse(image === trayImage)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }

    func testDefaultStatusIconFallsBackToAppIconWhenTrayIconUnavailable() throws {
        let appIcon = NSImage(size: NSSize(width: 256, height: 256))
        var appIconProviderCallCount = 0

        let image = try XCTUnwrap(
            StatusItemController.makeDefaultStatusIcon(
                trayIconProvider: { nil },
                appIconProvider: {
                    appIconProviderCallCount += 1
                    return appIcon
                }
            )
        )

        XCTAssertEqual(appIconProviderCallCount, 1)
        XCTAssertFalse(image === appIcon)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }

    func testQuitMenuItemInvokesApplicationTerminator() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        var didTerminate = false
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {
                didTerminate = true
            }
        )

        controller.install()

        let menuItem = try pauseResumeMenuItem(in: statusItem.menu, named: "Quit")
        let target = try XCTUnwrap(menuItem.target as AnyObject?)
        let action = try XCTUnwrap(menuItem.action)
        _ = target.perform(action, with: menuItem)

        XCTAssertTrue(didTerminate)
    }
    func testInfoPlistKeepsMenuBarOnlyApplicationContract() throws {
        let infoPlistURL = try XCTUnwrap(infoPlistURL())
        let plistData = try Data(contentsOf: infoPlistURL)
        let rawPropertyList = try PropertyListSerialization.propertyList(from: plistData, format: nil)
        let infoDictionary = try XCTUnwrap(rawPropertyList as? [String: Any])

        XCTAssertEqual(infoDictionary["LSUIElement"] as? Bool, true)
    }

    private func trayTemplateAssetURL(named fileName: String) -> URL? {
        trayTemplateImageSetURL()?.appendingPathComponent(fileName)
    }

    private func pauseResumeMenuItem(in menu: NSMenu?, named title: String) throws -> NSMenuItem {
        let menu = try XCTUnwrap(menu)
        return try XCTUnwrap(menu.items.first { $0.title == title })
    }

    private func trayTemplateImageSetURL() -> URL? {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return repositoryRoot
            .appendingPathComponent("Mahu")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("TrayIconTemplate.imageset")
    }

    private func infoPlistURL() -> URL? {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return repositoryRoot
            .appendingPathComponent("Mahu")
            .appendingPathComponent("Info.plist")
    }

    private func makeBundleWithTrayTemplateImage() throws -> URL {
        let trayTemplateAssetURL = try XCTUnwrap(trayTemplateAssetURL(named: trayTemplateAssetFileName(scale: "1x")))
        let trayTemplateData = try Data(contentsOf: trayTemplateAssetURL)
        return try makeBundle(resources: ["TrayIconTemplate.png": trayTemplateData])
    }

    private func trayTemplateAssetFileName(scale: String) throws -> String {
        let imageSetURL = try XCTUnwrap(trayTemplateImageSetURL())
        let contentsURL = imageSetURL.appendingPathComponent("Contents.json")
        let data = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(TrayTemplateContents.self, from: data)

        return try XCTUnwrap(
            contents.images.first { $0.scale == scale }?.filename,
            "Expected TrayIconTemplate.imageset to declare a \(scale) filename"
        )
    }

    private func makeBundle(resources: [String: Data] = [:]) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "com.mahu.tests.StatusItemBundle",
            "CFBundleName": "StatusItemBundle",
            "CFBundlePackageType": "BNDL",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
        ]

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlistURL)

        for (fileName, data) in resources {
            try data.write(to: resourcesURL.appendingPathComponent(fileName))
        }

        return bundleURL
    }
}

private struct TrayTemplateContents: Decodable {
    struct Image: Decodable {
        let filename: String?
        let scale: String
    }

    let images: [Image]
}
