// StatusBarController.swift
// NSStatusItem menu that exposes the buddy's most common controls:
// Do-Not-Disturb toggle, "Show Sessions Dashboard", and Quit. Ports
// `.workspace/reference/clawd-on-desk/src/menu.js` selectively.

import AppKit
import KiriFriendsMacBuddyKit

@MainActor
public final class StatusBarController {
    private let statusItem: NSStatusItem
    private let dndState: DoNotDisturbState
    private let openDashboard: @MainActor @Sendable () -> Void
    private var dndObserverTask: Task<Void, Never>?

    public init(dndState: DoNotDisturbState, openDashboard: @escaping @MainActor @Sendable () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.dndState = dndState
        self.openDashboard = openDashboard
        configureButton()
        configureMenu()
        observeDND()
    }

    deinit {
        dndObserverTask?.cancel()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Kiri Buddy")
    }

    private func configureMenu() {
        let menu = NSMenu()

        let dndItem = NSMenuItem(
            title: "Do Not Disturb",
            action: #selector(toggleDND),
            keyEquivalent: ""
        )
        dndItem.target = self
        menu.addItem(dndItem)
        menu.addItem(.separator())

        let dashboardItem = NSMenuItem(
            title: "Open Sessions Dashboard…",
            action: #selector(showDashboard),
            keyEquivalent: ""
        )
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Kiri Buddy",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func observeDND() {
        dndObserverTask?.cancel()
        dndObserverTask = Task { @MainActor [weak self, dndState] in
            for await isOn in await dndState.updates() {
                self?.refreshDNDState(isOn: isOn)
            }
        }
    }

    private func refreshDNDState(isOn: Bool) {
        guard let menu = statusItem.menu, let item = menu.items.first(where: { $0.action == #selector(toggleDND) }) else {
            return
        }
        item.state = isOn ? .on : .off
        statusItem.button?.image = NSImage(
            systemSymbolName: isOn ? "moon.zzz" : "sparkle",
            accessibilityDescription: "Kiri Buddy"
        )
    }

    @objc
    private func toggleDND() {
        Task { [dndState] in
            _ = await dndState.toggle()
        }
    }

    @objc
    private func showDashboard() {
        openDashboard()
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
