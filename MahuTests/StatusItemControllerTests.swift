import AppKit
import XCTest
@testable import Mahu

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testInstallConfiguresIconOnlyStatusItemWithQuitMenu() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }

        let controller = StatusItemController(statusItem: statusItem, applicationTerminator: {})

        controller.install()

        XCTAssertEqual(statusItem.button?.title, "")
        XCTAssertEqual(statusItem.button?.imagePosition, .imageOnly)
        XCTAssertNotNil(statusItem.button?.image)
        XCTAssertEqual(statusItem.menu?.items.map(\.title), ["Quit"])
        XCTAssertEqual(statusItem.menu?.items.first?.keyEquivalent, "q")
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
