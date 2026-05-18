import Foundation
import KiriFriendsCore
import SwiftUI

#if os(watchOS) && canImport(CoreMotion)
import CoreMotion
#endif

public struct PendingWatchActionOption: Hashable, Identifiable, Sendable {
    public var action: WatchActionKind
    public var title: String
    public var isDestructive: Bool
    public var accessibilityHint: String

    public var id: String { action.rawValue }

    public init(
        action: WatchActionKind,
        title: String,
        isDestructive: Bool = false,
        accessibilityHint: String
    ) {
        self.action = action
        self.title = title
        self.isDestructive = isDestructive
        self.accessibilityHint = accessibilityHint
    }

    public static func options(
        for snapshot: StateSnapshot,
        targetSession: CLISessionSummary? = nil
    ) -> [PendingWatchActionOption] {
        let session = targetSession ?? snapshot.session
        switch session?.state {
        case .waitingForApproval:
            return [
                PendingWatchActionOption(
                    action: .approvalAllow,
                    title: "Approve",
                    accessibilityHint: "Approves the current CLI action."
                ),
                PendingWatchActionOption(
                    action: .approvalDeny,
                    title: "Deny",
                    isDestructive: true,
                    accessibilityHint: "Denies the current CLI action."
                ),
            ]
        case .waitingForInput:
            return [
                PendingWatchActionOption(
                    action: .promptSendQuick,
                    title: "Reply",
                    accessibilityHint: "Sends a quick reply to the active session."
                ),
            ]
        case .running, .idle, .failed, .completed, .unknown, .none:
            return []
        }
    }
}

public enum WristTurnDirection: Hashable, Sendable {
    case previous
    case next
}

public struct WristTurnClassifier: Sendable {
    public var triggerThreshold: Double
    public var neutralThreshold: Double
    public var cooldown: TimeInterval

    private var isArmed = true
    private var lastTriggerAt: Date?

    public init(
        triggerThreshold: Double = 0.35,
        neutralThreshold: Double = 0.12,
        cooldown: TimeInterval = 0.55
    ) {
        self.triggerThreshold = triggerThreshold
        self.neutralThreshold = neutralThreshold
        self.cooldown = cooldown
    }

    public mutating func reset() {
        isArmed = true
        lastTriggerAt = nil
    }

    public mutating func update(rollDelta: Double, at date: Date) -> WristTurnDirection? {
        if abs(rollDelta) <= neutralThreshold {
            isArmed = true
            return nil
        }

        guard isArmed, abs(rollDelta) >= triggerThreshold else { return nil }

        if let lastTriggerAt, date.timeIntervalSince(lastTriggerAt) < cooldown {
            return nil
        }

        isArmed = false
        lastTriggerAt = date
        return rollDelta > 0 ? .next : .previous
    }
}

@MainActor
public final class WristOptionSelector {
    private var classifier: WristTurnClassifier
    private var baselineRoll: Double?
    private var onTurn: ((WristTurnDirection) -> Void)?

    #if os(watchOS) && canImport(CoreMotion)
    private let motionManager = CMMotionManager()
    private var timer: Timer?
    #endif

    public init(classifier: WristTurnClassifier = WristTurnClassifier()) {
        self.classifier = classifier
    }

    public func start(optionsCount: Int, onTurn: @escaping (WristTurnDirection) -> Void) {
        stop()
        guard optionsCount > 1 else { return }

        self.onTurn = onTurn
        baselineRoll = nil
        classifier.reset()

        #if os(watchOS) && canImport(CoreMotion)
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
        motionManager.startDeviceMotionUpdates()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.consumeMotionSample()
            }
        }
        #endif
    }

    public func stop() {
        onTurn = nil
        baselineRoll = nil
        classifier.reset()

        #if os(watchOS) && canImport(CoreMotion)
        timer?.invalidate()
        timer = nil
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        #endif
    }

    #if os(watchOS) && canImport(CoreMotion)
    private func consumeMotionSample() {
        guard let roll = motionManager.deviceMotion?.attitude.roll else { return }

        if baselineRoll == nil {
            baselineRoll = roll
            return
        }

        guard let baselineRoll else { return }
        if let direction = classifier.update(rollDelta: roll - baselineRoll, at: Date()) {
            onTurn?(direction)
        }
    }
    #endif
}

public struct PendingActionStrip: View {
    private let options: [PendingWatchActionOption]
    private let sendAction: (WatchActionKind) -> Void

    @State private var selectedActionID: WatchActionKind?
    @State private var wristSelector = WristOptionSelector()

    public init(
        options: [PendingWatchActionOption],
        sendAction: @escaping (WatchActionKind) -> Void
    ) {
        self.options = options
        self.sendAction = sendAction
    }

    public var body: some View {
        if !options.isEmpty {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    actionButton(for: option)
                }
            }
            .onAppear(perform: refreshSelectionAndMotion)
            .onDisappear { wristSelector.stop() }
            .onChange(of: options) { _, _ in
                refreshSelectionAndMotion()
            }
        }
    }

    @ViewBuilder
    private func actionButton(for option: PendingWatchActionOption) -> some View {
        if option.action == currentSelection {
            baseButton(for: option)
                .buttonStyle(.borderedProminent)
                .accessibilityValue("Highlighted")
        } else {
            baseButton(for: option)
                .buttonStyle(.bordered)
                .opacity(0.72)
        }
    }

    private func baseButton(for option: PendingWatchActionOption) -> some View {
        Button(role: option.isDestructive ? .destructive : nil) {
            submit(option)
        } label: {
            Text(option.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .tint(option.isDestructive ? .red : nil)
        .primaryHandGesture(isEnabled: option.action == currentSelection)
        .accessibilityHint("\(option.accessibilityHint) Turn your wrist to change the highlighted option. Double tap to choose it.")
    }

    private var currentSelection: WatchActionKind? {
        if let selectedActionID, options.contains(where: { $0.action == selectedActionID }) {
            return selectedActionID
        }
        return options.first?.action
    }

    private func submit(_ option: PendingWatchActionOption) {
        selectedActionID = option.action
        sendAction(option.action)
    }

    private func refreshSelectionAndMotion() {
        if !options.contains(where: { $0.action == selectedActionID }) {
            selectedActionID = options.first?.action
        }

        wristSelector.start(optionsCount: options.count) { direction in
            moveSelection(direction)
        }
    }

    private func moveSelection(_ direction: WristTurnDirection) {
        guard options.count > 1 else { return }
        let index = options.firstIndex { $0.action == currentSelection } ?? 0
        let nextIndex: Int
        switch direction {
        case .previous:
            nextIndex = (index + options.count - 1) % options.count
        case .next:
            nextIndex = (index + 1) % options.count
        }
        selectedActionID = options[nextIndex].action
        KiriHaptics.selectionChanged()
    }
}

private extension View {
    @ViewBuilder
    func primaryHandGesture(isEnabled: Bool) -> some View {
        #if os(watchOS)
        if #available(watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction, isEnabled: isEnabled)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
