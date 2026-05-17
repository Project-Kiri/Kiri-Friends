// BuddyAppDelegate.swift
// NSApplicationDelegate that owns the desktop buddy window and ties it
// to the bridge service. SwiftUI installs this via
// `NSApplicationDelegateAdaptor` in `KiriFriendsBuddyMacApp`.

import AppKit
import Combine
import KiriFriendsMacBuddyKit
import Observation

@MainActor
public final class BuddyAppDelegate: NSObject, NSApplicationDelegate {
    public let model: BridgeAppModel
    private var windowController: BuddyWindowController?
    private var permissionManager: PermissionBubbleManager?
    private var sessionHUDController: SessionHUDController?
    private var statusBarController: StatusBarController?
    private var snapshotTask: Task<Void, Never>?

    public override init() {
        self.model = BridgeAppModel()
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // LSUIElement keeps us off the Dock; explicitly become an
        // accessory so we still receive keyboard events while running
        // headless.
        NSApp.setActivationPolicy(.accessory)

        let controller = BuddyWindowController(stateStore: model.bridge.store)
        controller.attach()
        self.windowController = controller

        let permissionManager = PermissionBubbleManager(service: model.bridge.permissions)
        permissionManager.start()
        self.permissionManager = permissionManager

        let hud = SessionHUDController()
        hud.attach()
        self.sessionHUDController = hud

        statusBarController = StatusBarController(dndState: model.bridge.dnd) {
            Self.openSessionsDashboard()
        }

        Task { [model] in
            await model.start()
        }

        snapshotTask?.cancel()
        snapshotTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let snapshot = self.model.snapshot
                self.windowController?.applySnapshot(snapshot)
                self.sessionHUDController?.applySnapshot(snapshot)
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        snapshotTask?.cancel()
        snapshotTask = nil
        sessionHUDController?.detach()
        sessionHUDController = nil
        permissionManager?.stop()
        permissionManager = nil
        windowController?.detach()
        windowController = nil
        statusBarController = nil
        Task { [model] in
            await model.stop()
        }
    }

    /// Opens the SwiftUI dashboard scene via the openWindow URL scheme.
    /// SwiftUI registers a `kiri-buddy://` style id, but to avoid the
    /// EnvironmentValues plumbing we activate the app and call into the
    /// runtime scene API through the public window identifier.
    static func openSessionsDashboard() {
        NSApp.activate(ignoringOtherApps: true)
        if let url = URL(string: "kiri-buddy://sessions-dashboard") {
            NSWorkspace.shared.open(url)
        }
    }
}
