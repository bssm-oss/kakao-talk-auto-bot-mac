import AppKit
import Foundation

struct MenuBarStatusItemAppearance {
    let symbolName: String
    let tintColor: NSColor
    let tooltip: String

    static let idle = MenuBarStatusItemAppearance(
        symbolName: "ellipsis.message",
        tintColor: .labelColor,
        tooltip: "katalk-ax menu bar"
    )
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    var onRefreshRequested: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuitRequested: (() -> Void)?

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let contentController: MainPopoverViewController
    private var outsideClickMonitor: Any?

    private lazy var utilityMenu: NSMenu = {
        let menu = NSMenu()
        let refreshItem = NSMenuItem(title: "Refresh Status", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(handleOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit katalk-ax", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }()

    init(contentController: MainPopoverViewController) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.contentController = contentController
        super.init()
        configurePopover()
        configureStatusItemButton()
        apply(appearance: .idle)
    }

    func apply(appearance: MenuBarStatusItemAppearance) {
        guard let button = statusItem.button else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let image = NSImage(systemSymbolName: appearance.symbolName, accessibilityDescription: "katalk-ax menu bar")?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.contentTintColor = appearance.tintColor
        button.toolTip = appearance.tooltip
        button.setAccessibilityLabel(appearance.tooltip)
    }

    private func configurePopover() {
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentController
    }

    private func configureStatusItemButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let eventType = NSApp.currentEvent?.type
        switch eventType {
        case .rightMouseUp:
            showUtilityMenu(from: sender)
        default:
            togglePopover(from: sender)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            closePopover(nil)
            return
        }
        showPopover(from: button)
    }

    private func showPopover(from button: NSStatusBarButton) {
        contentController.popoverWillShow()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startOutsideClickMonitor()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closePopover(_ sender: Any?) {
        popover.performClose(sender)
        stopOutsideClickMonitor()
    }

    private func showUtilityMenu(from button: NSStatusBarButton) {
        closePopover(nil)
        utilityMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 6), in: button)
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePopover(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
    }

    @objc private func handleRefresh() {
        onRefreshRequested?()
    }

    @objc private func handleOpenSettings() {
        onOpenSettings?()
    }

    @objc private func handleQuit() {
        onQuitRequested?()
    }
}
