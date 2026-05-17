// Storage.swift
// In-memory caregiver log. Production deployment would back this with
// SQLCipher AES-256 keyed via the iOS Keychain (using the Secure Enclave
// where available). For the hackathon submission we keep the data in memory
// to remove all third-party storage dependencies; nothing leaves the device.

import Foundation
import Combine

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let icon: String
    let title: String
    let body: String

    var timeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: timestamp)
    }
}

@MainActor
final class CaregiverLog: ObservableObject {
    @Published var entries: [LogEntry] = []

    func apply(_ call: ToolCall) {
        let now = Date()
        switch call.toolName {
        case "log_pill_change":
            let day = call.arguments["day"] ?? "?"
            let ampm = call.arguments["ampm"] ?? "AM"
            let change = call.arguments["change"] ?? "logged"
            entries.insert(LogEntry(
                timestamp: now,
                category: "medication",
                icon: "pill",
                title: "\(day) \(ampm) pills",
                body: change.capitalized
            ), at: 0)
        case "log_incident":
            let cat = call.arguments["category"] ?? "observation"
            let detail = call.arguments["detail"] ?? ""
            let sev = call.arguments["severity"] ?? "low"
            let icon: String = {
                switch sev {
                case "high": return "exclamationmark.triangle.fill"
                case "medium": return "exclamationmark.circle"
                default: return "circle"
                }
            }()
            entries.insert(LogEntry(
                timestamp: now,
                category: "incident",
                icon: icon,
                title: cat.capitalized,
                body: detail
            ), at: 0)
        case "add_to_doctor_visit":
            entries.insert(LogEntry(
                timestamp: now,
                category: "doctor",
                icon: "stethoscope",
                title: "Queued for the doctor",
                body: call.arguments["item"] ?? ""
            ), at: 0)
        case "notify_sibling":
            entries.insert(LogEntry(
                timestamp: now,
                category: "sibling",
                icon: "person.2",
                title: "Sibling notification queued",
                body: call.arguments["message"] ?? ""
            ), at: 0)
        default:
            break
        }
    }

    /// Render the log as a Markdown summary suitable for compiling into a
    /// doctor visit report by the larger model.
    func markdown(forLastDays days: Int) -> String {
        let cutoff = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        let recent = entries.filter { $0.timestamp >= cutoff }
        if recent.isEmpty { return "(no entries in the last \(days) days)" }
        var lines: [String] = []
        for e in recent {
            lines.append("- [\(e.timeLabel)] \(e.title): \(e.body)")
        }
        return lines.joined(separator: "\n")
    }
}
