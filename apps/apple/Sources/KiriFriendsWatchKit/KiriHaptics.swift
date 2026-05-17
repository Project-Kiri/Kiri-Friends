import Foundation

#if canImport(WatchKit)
import WatchKit

public enum KiriHaptics {
    public static func approvalRequired() {
        WKInterfaceDevice.current().play(.notification)
    }

    public static func approvalAccepted() {
        WKInterfaceDevice.current().play(.success)
    }

    public static func approvalDenied() {
        WKInterfaceDevice.current().play(.directionDown)
    }

    public static func taskFailed() {
        WKInterfaceDevice.current().play(.failure)
    }

    public static func selectionChanged() {
        WKInterfaceDevice.current().play(.click)
    }
}
#else
public enum KiriHaptics {
    public static func approvalRequired() {}
    public static func approvalAccepted() {}
    public static func approvalDenied() {}
    public static func taskFailed() {}
    public static func selectionChanged() {}
}
#endif
