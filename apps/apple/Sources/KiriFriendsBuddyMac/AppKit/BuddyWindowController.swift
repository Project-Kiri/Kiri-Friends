// BuddyWindowController.swift
// Transparent, borderless, always-on-top NSWindow that hosts the buddy
// animation view. Mirrors Clawd-on-Desk's pet window in
// `.workspace/reference/clawd-on-desk/src/main.js`. Phase 2 keeps it
// minimal: float window with the WKWebView pet. Phase 3 layers drag /
// click reactions on top.

import AppKit
import KiriFriendsMacBuddyKit

@MainActor
public final class BuddyWindowController: NSWindowController {
    private let animationView: BuddyAnimationView
    private var mouseTrackingTimer: Timer?
    private let windowStateStore = BuddyWindowStateStore()
    private var clickTracker = BuddyClickReactionTracker()
    private var reactionResetTask: Task<Void, Never>?
    private weak var stateStore: MacBuddyStateStore?

    public init(stateStore: MacBuddyStateStore? = nil) {
        self.stateStore = stateStore
        let size = BuddyAnimationView.defaultSize
        let initialOrigin = BuddyWindowController.defaultOrigin(for: size)
        let window = BuddyWindow(
            contentRect: NSRect(origin: initialOrigin, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false

        animationView = BuddyAnimationView()
        window.contentView = animationView
        super.init(window: window)

        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func attach() {
        Task { [weak self] in
            await self?.restoreSavedPosition()
            await MainActor.run {
                self?.showWindow(nil)
                self?.animationView.setState(.idle)
                self?.startMouseTracking()
                self?.installClickMonitor()
            }
        }
    }

    public func detach() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
        reactionResetTask?.cancel()
        reactionResetTask = nil
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        persistCurrentPosition()
        close()
    }

    public func applySnapshot(_ snapshot: MacBuddyDisplaySnapshot) {
        animationView.setState(snapshot.displayState)
    }

    // MARK: - Position persistence

    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: 100, y: 100)
        }
        let frame = screen.visibleFrame
        let inset: CGFloat = 24
        return NSPoint(
            x: frame.maxX - size.width - inset,
            y: frame.minY + inset
        )
    }

    private func restoreSavedPosition() async {
        guard let saved = await windowStateStore.load() else { return }
        let workAreas = BuddyWindowController.workAreas()
        let origin = CGPoint(x: saved.originX, y: saved.originY)
        let clamped = BuddyWorkAreaResolver
            .nearest(origin: origin, in: workAreas)?
            .clamped(origin: origin, size: BuddyAnimationView.defaultSize) ?? origin
        await MainActor.run {
            self.window?.setFrameOrigin(clamped)
        }
    }

    private func persistCurrentPosition() {
        guard let window else { return }
        let frame = window.frame
        let displayID = window.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
        let state = BuddyWindowState(
            originX: Double(frame.origin.x),
            originY: Double(frame.origin.y),
            displayIdentifier: displayID
        )
        Task { [windowStateStore] in
            await windowStateStore.save(state)
        }
    }

    // MARK: - Eye tracking

    private func startMouseTracking() {
        mouseTrackingTimer?.invalidate()
        // Poll the cursor at 30 Hz; the upstream Electron renderer uses a
        // similar interval through Electron's screen.getCursorScreenPoint
        // (see `src/tick.js`).
        let timer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 30.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateEyeTarget()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTrackingTimer = timer
    }

    private func updateEyeTarget() {
        guard let window else { return }
        let cursor = NSEvent.mouseLocation
        let windowOrigin = window.frame.origin
        let local = CGPoint(
            x: cursor.x - windowOrigin.x,
            y: cursor.y - windowOrigin.y
        )
        animationView.setEyeTarget(localCursor: local)
    }

    // MARK: - Click reactions

    private var clickMonitor: Any?

    private func installClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard event.window === self.window else { return event }
            self.handleClick()
            return event
        }
    }

    private func handleClick() {
        let reaction = clickTracker.registerClick()
        let state: MacBuddyState?
        switch reaction.kind {
        case .single:
            state = nil
        case .poke:
            state = .attention
        case .flail:
            state = .notification
        }
        guard let state else { return }
        animationView.setState(state)
        scheduleReactionRestore(after: .milliseconds(2_500))

        // Also drive the shared state store when wired so the relay sees
        // the interaction and downstream surfaces can react too.
        guard let stateStore else { return }
        Task { [stateStore] in
            await stateStore.apply(event: MacBuddyStateEvent(
                agent: .claudeCode,
                sessionId: "macbuddy-local",
                event: reaction.kind == .flail ? "BuddyFlail" : "BuddyPoke",
                resolvedState: state
            ))
        }
    }

    private func scheduleReactionRestore(after duration: Duration) {
        reactionResetTask?.cancel()
        reactionResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.clickTracker.reset()
            self?.animationView.setState(.idle)
        }
    }

    // MARK: - Multi-display work area

    private static func workAreas() -> [BuddyWorkArea] {
        NSScreen.screens.map { screen in
            let frame = screen.visibleFrame
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
            return BuddyWorkArea(
                minX: frame.minX,
                minY: frame.minY,
                maxX: frame.maxX,
                maxY: frame.maxY,
                displayIdentifier: displayID
            )
        }
    }
}

extension BuddyWindowController: NSWindowDelegate {
    public func windowDidMove(_ notification: Notification) {
        persistCurrentPosition()
    }

    public func windowDidChangeScreen(_ notification: Notification) {
        persistCurrentPosition()
    }
}

/// NSWindow subclass that returns true for `canBecomeKey` so the
/// borderless window can still receive keyboard events when the user
/// drags or clicks the buddy. Mirrors upstream's input-window trick.
private final class BuddyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
