import Foundation

/// A single alert (EKAlarm) attached to a calendar event.
public struct AlertItem: Encodable, Sendable {
    public let index: Int           // Position in the event's alarms array (0-based)
    public let type: String         // "relative" | "absolute"
    public let offset: String?      // e.g. "15m", "1h", "2h30m" (relative alerts)
    public let absoluteDate: String? // e.g. "2026-04-19 08:30" (absolute alerts)
}
