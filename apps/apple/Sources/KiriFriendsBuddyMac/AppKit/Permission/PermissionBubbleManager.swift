// PermissionBubbleManager.swift
// Bridges the actor-isolated `PermissionBubbleService` to the main-actor
// AppKit windows that show the bubble UI. Listens for service events and
// keeps the floating bubble stack in sync with pending requests.

import AppKit
import KiriFriendsMacBuddyKit

@MainActor
public final class PermissionBubbleManager {
    private let service: PermissionBubbleService
    private var controllers: [UUID: PermissionBubbleWindowController] = [:]
    private var eventTask: Task<Void, Never>?

    public init(service: PermissionBubbleService) {
        self.service = service
    }

    public func start() {
        eventTask?.cancel()
        eventTask = Task { [weak self, service] in
            let stream = await service.events()
            for await event in stream {
                guard let self else { break }
                self.handle(event: event)
            }
        }
    }

    public func stop() {
        eventTask?.cancel()
        eventTask = nil
        for controller in controllers.values {
            controller.dismiss()
        }
        controllers.removeAll()
    }

    private func handle(event: PermissionBubbleEvent) {
        switch event {
        case .added(let request):
            present(request: request)
        case .dismissed(let id):
            dismiss(id: id)
        }
    }

    private func present(request: PermissionBubbleRequest) {
        let service = self.service
        let controller = PermissionBubbleWindowController(request: request) { @MainActor [request] response in
            Task { @MainActor in
                await service.decide(id: request.id, response: response)
            }
        }
        controllers[request.id] = controller
        controller.reveal()
        restack()
    }

    private func dismiss(id: UUID) {
        guard let controller = controllers.removeValue(forKey: id) else { return }
        controller.dismiss()
        restack()
    }

    private func restack() {
        let ordered = controllers.values.sorted { lhs, rhs in
            lhs.request.createdAt < rhs.request.createdAt
        }
        for (index, controller) in ordered.enumerated() {
            controller.place(atStackIndex: index)
        }
    }
}
