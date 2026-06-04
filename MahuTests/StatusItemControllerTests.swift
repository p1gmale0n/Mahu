import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testInstallUsesInjectedStatusIconProviderImage() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let expectedImage = NSImage(size: NSSize(width: 18, height: 18))
        let controller = StatusItemController(
            statusItem: statusItem,
            applicationTerminator: {},
            statusIconProvider: { expectedImage }
        )

        controller.install()

        XCTAssertTrue(statusItem.button?.image === expectedImage)
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
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Quit"])
        XCTAssertEqual(statusItem.menu?.items.first?.keyEquivalent, "q")
    }

    func testTrayTemplateStatusIconProviderLoadsBundledAsset() throws {
        let image = try XCTUnwrap(StatusItemController.makeTrayTemplateStatusIcon())

        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
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
        let controller = StatusItemController(statusItem: statusItem) {
            didTerminate = true
        }

        controller.install()

        let menuItem = try XCTUnwrap(statusItem.menu?.items.first)
        let target = try XCTUnwrap(menuItem.target as AnyObject?)
        let action = try XCTUnwrap(menuItem.action)
        _ = target.perform(action, with: menuItem)

        XCTAssertTrue(didTerminate)
    }
}
