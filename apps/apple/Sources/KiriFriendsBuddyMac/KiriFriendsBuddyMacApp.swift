// KiriFriendsBuddyMacApp.swift
// Entry point for the macOS desktop buddy. Phase 2 hands lifecycle and
// the transparent overlay window to BuddyAppDelegate. A SwiftUI Settings
// scene exposes the bridge status panel for developers running
// `make dev-mac`.

import KiriFriendsCore
import KiriFriendsMacBuddyKit
import SwiftUI

@main
struct KiriFriendsBuddyMacApp: App {
    @NSApplicationDelegateAdaptor(BuddyAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            BuddyRootView(model: appDelegate.model)
        }

        Window("Kiri Buddy Sessions", id: "sessions-dashboard") {
            SessionsDashboardView(snapshot: appDelegate.model.snapshot)
                .frame(minWidth: 720, minHeight: 360)
        }
        .commandsRemoved()
    }
}
