import Foundation
import KiriFriendsCore

#if canImport(UserNotifications)
import UserNotifications

public enum KiriNotificationCategory: String, CaseIterable, Sendable {
    case approvalRequired = "KIRI_APPROVAL_REQUIRED"
    case taskCompleted = "KIRI_TASK_COMPLETED"
    case taskFailed = "KIRI_TASK_FAILED"
    case connectionChanged = "KIRI_CONNECTION_CHANGED"
}

public enum KiriNotificationAction: String, Sendable {
    case approve = "KIRI_APPROVE"
    case deny = "KIRI_DENY"
    case openDetails = "KIRI_OPEN_DETAILS"
    case dismiss = "KIRI_DISMISS"
    case openConnections = "KIRI_OPEN_CONNECTIONS"
}

public enum NotificationCatalog {
    public static func register(center: UNUserNotificationCenter = .current()) {
        center.setNotificationCategories(Set(KiriNotificationCategory.allCases.map(category)))
    }

    private static func category(_ category: KiriNotificationCategory) -> UNNotificationCategory {
        switch category {
        case .approvalRequired:
            return UNNotificationCategory(
                identifier: category.rawValue,
                actions: [
                    action(.approve, title: "Approve", options: [.authenticationRequired]),
                    action(.deny, title: "Deny", options: [.destructive, .authenticationRequired]),
                    action(.openDetails, title: "Details", options: [.foreground])
                ],
                intentIdentifiers: []
            )
        case .taskCompleted:
            return UNNotificationCategory(
                identifier: category.rawValue,
                actions: [
                    action(.openDetails, title: "Details", options: [.foreground]),
                    action(.dismiss, title: "Dismiss", options: [])
                ],
                intentIdentifiers: []
            )
        case .taskFailed:
            return UNNotificationCategory(
                identifier: category.rawValue,
                actions: [
                    action(.openDetails, title: "Details", options: [.foreground]),
                    action(.dismiss, title: "Dismiss", options: [])
                ],
                intentIdentifiers: []
            )
        case .connectionChanged:
            return UNNotificationCategory(
                identifier: category.rawValue,
                actions: [
                    action(.openConnections, title: "Connections", options: [.foreground]),
                    action(.dismiss, title: "Dismiss", options: [])
                ],
                intentIdentifiers: []
            )
        }
    }

    private static func action(
        _ action: KiriNotificationAction,
        title: String,
        options: UNNotificationActionOptions
    ) -> UNNotificationAction {
        UNNotificationAction(identifier: action.rawValue, title: title, options: options)
    }
}
#endif
