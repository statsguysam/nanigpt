// Tools.swift
// Structured tool definitions and a parser for Gemma 4's tool-call format
// (call:tool_name{key:value,key:value}). Mirrors the Python tools.py from the
// main repo so behaviour is consistent across deployments.

import Foundation

struct ToolDefinition {
    let name: String
    let parameterNames: [String]
}

struct ToolCall: Identifiable {
    let id = UUID()
    let toolName: String
    let arguments: [String: String]
}

enum Tools {
    static let logPillChange = ToolDefinition(
        name: "log_pill_change",
        parameterNames: ["day", "ampm", "change", "note"]
    )
    static let logIncident = ToolDefinition(
        name: "log_incident",
        parameterNames: ["category", "detail", "severity", "photo_attached"]
    )
    static let addToDoctorVisit = ToolDefinition(
        name: "add_to_doctor_visit",
        parameterNames: ["item", "priority"]
    )
    static let notifySibling = ToolDefinition(
        name: "notify_sibling",
        parameterNames: ["message", "urgency"]
    )
    static let generateDoctorPdf = ToolDefinition(
        name: "generate_doctor_pdf",
        parameterNames: ["patient_name", "days"]
    )

    static let all: [ToolDefinition] = [
        logPillChange, logIncident, addToDoctorVisit, notifySibling, generateDoctorPdf
    ]

    static let byName: [String: ToolDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
}

enum ToolCallParser {
    /// Extracts all `call:NAME{...}` patterns from raw model output and
    /// dispatches their argument blocks based on each tool's known parameter
    /// names. The signature-aware approach makes the parser robust to commas
    /// inside string values (e.g. "where Dad is, who has been gone for years").
    static func parse(_ raw: String, tools: [ToolDefinition]) -> [ToolCall] {
        var results: [ToolCall] = []
        let pattern = #"call:(\w+)\s*\{([^}]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsRaw = raw as NSString
        let matches = regex.matches(in: raw, options: [], range: NSRange(location: 0, length: nsRaw.length))

        for m in matches {
            guard m.numberOfRanges == 3 else { continue }
            let toolName = nsRaw.substring(with: m.range(at: 1))
            let body = nsRaw.substring(with: m.range(at: 2))
            guard let def = Tools.byName[toolName] else { continue }
            let args = parseArguments(body, knownKeys: def.parameterNames)
            results.append(ToolCall(toolName: toolName, arguments: args))
        }
        return results
    }

    private static func parseArguments(_ body: String, knownKeys: [String]) -> [String: String] {
        var args: [String: String] = [:]

        // Find the byte index of every "key:" occurrence
        var positions: [(start: Int, key: String, valStart: Int)] = []
        for k in knownKeys {
            let needle = k + ":"
            var searchRange = body.startIndex..<body.endIndex
            while let range = body.range(of: needle, range: searchRange) {
                let start = body.distance(from: body.startIndex, to: range.lowerBound)
                let valStart = body.distance(from: body.startIndex, to: range.upperBound)
                positions.append((start: start, key: k, valStart: valStart))
                searchRange = range.upperBound..<body.endIndex
            }
        }
        positions.sort { $0.start < $1.start }

        let chars = Array(body)
        for (i, p) in positions.enumerated() {
            let valEnd = (i + 1 < positions.count) ? positions[i + 1].start : chars.count
            var slice = String(chars[p.valStart..<valEnd])
            slice = slice.trimmingCharacters(in: .whitespacesAndNewlines)
            if slice.hasSuffix(",") { slice.removeLast() }
            args[p.key] = slice.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return args
    }

    /// Turn a list of parsed tool calls into a warm one-paragraph reply for
    /// the caregiver to read in the UI.
    static func summariseHumanly(calls: [ToolCall]) -> String {
        if calls.isEmpty {
            return "I heard you, but I did not log anything specific. Try mentioning what happened in a bit more detail."
        }
        if calls.count == 1 {
            return "Got it. " + describe(calls[0]) + "."
        }
        let bullets = calls.map { "- " + describe($0) }.joined(separator: "\n")
        return "Got it. I logged \(calls.count) things from your message:\n\n" + bullets
    }

    static func summariseActions(calls: [ToolCall]) -> String {
        if calls.isEmpty { return "" }
        let items = calls.map { describe($0) }
        if items.count == 1 { return "Logged: " + items[0] + "." }
        return "Logged \(items.count) items:\n" + items.map { "• " + $0 }.joined(separator: "\n")
    }

    private static func describe(_ c: ToolCall) -> String {
        switch c.toolName {
        case "log_pill_change":
            let day = c.arguments["day"] ?? "?"
            let ampm = (c.arguments["ampm"] ?? "AM") == "AM" ? "morning" : "evening"
            let change = c.arguments["change"] ?? "logged"
            return "Logged \(day) \(ampm) pills as \(change)"
        case "log_incident":
            let cat = c.arguments["category"] ?? "observation"
            let sev = c.arguments["severity"] ?? "low"
            return "Noted a \(cat) observation (\(sev) priority)"
        case "add_to_doctor_visit":
            let item = c.arguments["item"] ?? "an item"
            return "Queued for the doctor: \(item)"
        case "notify_sibling":
            return "Queued a sibling notification"
        case "generate_doctor_pdf":
            return "Started the doctor visit report"
        default:
            return "Called \(c.toolName)"
        }
    }
}
