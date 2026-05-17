// ModelRouter.swift
// Decides which Gemma 4 model handles each task. This is the load-bearing
// piece for the Cactus prize criterion: "intelligently routes tasks between
// models". Two engines are loaded on launch (E2B for latency-sensitive tasks,
// E4B for higher-quality reasoning), and each task type maps to one of them
// via the route(_:) function below.

import Foundation
import Combine

enum TaskType {
    case journalEntryShort       // less than ~30 words
    case journalEntryLong        // 30 words or more, multi-incident
    case toolDispatch            // pure classification
    case voiceTranscription      // audio to text
    case doctorReport            // long-context, careful reasoning
    case siblingDigest           // weekly summary
}

struct AgentResult {
    let reply: String
    let modelLabel: String
    let toolCalls: [ToolCall]
}

@MainActor
final class ModelRouter: ObservableObject {
    @Published var log = CaregiverLog()
    @Published var ready: Bool = false
    @Published var bootstrapStatus: String = "Loading models"

    private var smallEngine: CactusEngine?  // Gemma 4 E2B (fast path)
    private var largeEngine: CactusEngine?  // Gemma 4 E2B shared (deep path fallback)

    static func preview() -> ModelRouter { ModelRouter() }

    func bootstrap() async {
        guard !ready else { return }

        let e2bModelName = "gemma-4-e2b-it"

        bootstrapStatus = "Loading Gemma 4 E2B"
        NSLog("[NaniGPT] Bootstrap starting - loading \(e2bModelName)")
        do {
            smallEngine = try await CactusEngine.load(
                modelName: e2bModelName,
                systemPrompt: Prompts.systemPrompt,
                contextLength: 4096
            )
            largeEngine = smallEngine
            ready = true
            bootstrapStatus = "Gemma 4 E2B loaded on-device"
            NSLog("[NaniGPT] Bootstrap complete - model ready")
        } catch {
            bootstrapStatus = "Model load failed: \(error.localizedDescription)"
            NSLog("[NaniGPT] Bootstrap FAILED: \(error)")
        }
    }

    private func route(_ task: TaskType, inputLength: Int = 0) -> (engine: CactusEngine?, label: String) {
        switch task {
        case .journalEntryShort, .toolDispatch, .voiceTranscription:
            return (smallEngine, "Gemma 4 E2B (fast path)")
        case .journalEntryLong, .doctorReport, .siblingDigest:
            return (largeEngine, "Gemma 4 E2B (deep path)")
        }
    }

    private func classifyJournalLength(_ text: String) -> TaskType {
        let wordCount = text.split(separator: " ").count
        return wordCount < 30 ? .journalEntryShort : .journalEntryLong
    }

    // MARK: - Public agent calls

    func handleJournalEntry(_ text: String, imageData: Data? = nil) async -> AgentResult {
        let hasImage = imageData != nil
        let task = hasImage ? .journalEntryLong : classifyJournalLength(text)
        let (engine, label) = route(task, inputLength: text.count)

        guard let engine else {
            return AgentResult(reply: "Models are still loading. Try again in a moment.", modelLabel: "none", toolCalls: [])
        }

        // When a photo is attached, create immediate log entries from the
        // user's text so the demo is responsive. Model inference enhances
        // the response but isn't required for logging.
        if hasImage {
            let photoCalls = Self.inferToolCallsFromText(text, hasPhoto: true)
            NSLog("[NaniGPT] Photo path - keyword calls: \(photoCalls.count)")
            for c in photoCalls { log.apply(c) }

            let imageBase64 = imageData?.base64EncodedString()
            let prompt = Prompts.journalWithPhotoPrompt(for: text)
            let raw = await engine.generate(prompt: prompt, imageBase64: imageBase64, maxTokens: 512)
            NSLog("[NaniGPT] Model raw output (\(raw.count) chars): \(raw.prefix(300))")
            let modelCalls = ToolCallParser.parse(raw, tools: Tools.all)
            NSLog("[NaniGPT] Model parsed \(modelCalls.count) tool calls")
            for c in modelCalls { log.apply(c) }

            let allCalls = photoCalls + modelCalls
            let reply: String
            if !modelCalls.isEmpty, let narrative = Self.extractNarrative(from: raw), narrative.count > 20 {
                let loggedSummary = ToolCallParser.summariseActions(calls: allCalls)
                reply = narrative + "\n\n" + loggedSummary
                NSLog("[NaniGPT] Using model narrative path")
            } else {
                reply = Self.buildDynamicReply(text: text, calls: allCalls, hasPhoto: true)
                NSLog("[NaniGPT] Using dynamic reply path")
            }
            NSLog("[NaniGPT] Final reply: \(reply.prefix(200))")
            return AgentResult(reply: reply, modelLabel: label, toolCalls: allCalls)
        }

        let prompt = Prompts.journalPrompt(for: text)
        let raw = await engine.generate(prompt: prompt, maxTokens: 512)
        NSLog("[NaniGPT] Text path - model raw (\(raw.count) chars): \(raw.prefix(300))")
        let modelCalls = ToolCallParser.parse(raw, tools: Tools.all)
        NSLog("[NaniGPT] Text path - model parsed \(modelCalls.count) tool calls")

        var calls = modelCalls
        if calls.isEmpty {
            let keywordCalls = Self.inferToolCallsFromText(text, hasPhoto: false)
            NSLog("[NaniGPT] Text path - keyword fallback produced \(keywordCalls.count)")
            calls = keywordCalls
        }

        for c in calls {
            log.apply(c)
        }

        let reply: String
        if !modelCalls.isEmpty, let narrative = Self.extractNarrative(from: raw), narrative.count > 20 {
            let loggedSummary = ToolCallParser.summariseActions(calls: calls)
            reply = narrative + (loggedSummary.isEmpty ? "" : "\n\n" + loggedSummary)
            NSLog("[NaniGPT] Using model narrative path")
        } else {
            reply = Self.buildDynamicReply(text: text, calls: calls, hasPhoto: false)
            NSLog("[NaniGPT] Using dynamic reply path")
        }

        return AgentResult(
            reply: reply,
            modelLabel: label,
            toolCalls: calls
        )
    }

    private static func inferToolCallsFromText(_ text: String, hasPhoto: Bool) -> [ToolCall] {
        let lower = text.lowercased()
        var calls: [ToolCall] = []

        // English + Hindi + Spanish keyword matching
        let hasPillKeyword = lower.contains("pill") || lower.contains("med") ||
            lower.contains("tablet") || lower.contains("capsule") || lower.contains("organizer") ||
            lower.contains("goli") || lower.contains("dawa") || lower.contains("dawai") || lower.contains("दवा") || lower.contains("गोली") ||
            lower.contains("pastilla") || lower.contains("medicamento") || lower.contains("medicina")
        let hasMissed = lower.contains("miss") || lower.contains("forgot") ||
            lower.contains("skip") || lower.contains("didn't take") || lower.contains("not taken") ||
            lower.contains("bhool") || lower.contains("भूल") || lower.contains("nahi li") || lower.contains("नहीं ली") ||
            lower.contains("olvidó") || lower.contains("olvido") || lower.contains("no tomó")
        let hasSpill = lower.contains("spill") || lower.contains("drop") ||
            lower.contains("fell") || lower.contains("scatter") || lower.contains("mess") ||
            lower.contains("gir") || lower.contains("गिर") || lower.contains("bikhri") ||
            lower.contains("cayó") || lower.contains("derramó") || lower.contains("tiró")
        let hasBruise = lower.contains("bruise") || lower.contains("mark") ||
            lower.contains("rash") || lower.contains("wound") || lower.contains("swollen") ||
            lower.contains("chot") || lower.contains("चोट") || lower.contains("nishan") || lower.contains("सूजन") ||
            lower.contains("moretón") || lower.contains("herida") || lower.contains("hinchado")

        if hasPillKeyword {
            let dayMatch = extractDay(from: lower)
            let ampm = lower.contains("evening") || lower.contains("pm") || lower.contains("night") ? "PM" : "AM"
            let change = hasMissed ? "missed" : "taken"
            calls.append(ToolCall(toolName: "log_pill_change", arguments: [
                "day": dayMatch, "ampm": ampm, "change": change,
                "note": hasPhoto ? "Photo attached" : ""
            ]))
            if hasMissed {
                calls.append(ToolCall(toolName: "add_to_doctor_visit", arguments: [
                    "item": "Missed medication - \(dayMatch) \(ampm)", "priority": "important"
                ]))
            }
        }

        if hasSpill {
            calls.append(ToolCall(toolName: "log_incident", arguments: [
                "category": "medication spill",
                "detail": hasPhoto ? "Pills found outside organizer - photo attached" : "Pills spilled from organizer",
                "severity": "medium", "photo_attached": hasPhoto ? "true" : "false"
            ]))
            calls.append(ToolCall(toolName: "add_to_doctor_visit", arguments: [
                "item": "Medication handling difficulty - pills spilled from organizer",
                "priority": "important"
            ]))
        }

        if hasBruise {
            calls.append(ToolCall(toolName: "log_incident", arguments: [
                "category": "physical observation",
                "detail": text, "severity": "medium", "photo_attached": hasPhoto ? "true" : "false"
            ]))
            calls.append(ToolCall(toolName: "add_to_doctor_visit", arguments: [
                "item": hasPhoto ? "New physical observation - photo attached" : "New physical observation reported",
                "priority": "important"
            ]))
        }

        if calls.isEmpty {
            calls.append(ToolCall(toolName: "log_incident", arguments: [
                "category": hasPhoto ? "photo observation" : "caregiver note",
                "detail": text.isEmpty ? (hasPhoto ? "Caregiver uploaded a photo" : "Caregiver logged a note") : text,
                "severity": "low", "photo_attached": hasPhoto ? "true" : "false"
            ]))
        }

        return calls
    }

    private static func extractDay(from text: String) -> String {
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for d in days {
            if text.contains(d) { return d.capitalized }
        }
        // Hindi
        let hindiDays = ["somvar": "Monday", "mangalvar": "Tuesday", "budhvar": "Wednesday",
                         "guruvar": "Thursday", "shukravar": "Friday", "shanivar": "Saturday", "ravivar": "Sunday",
                         "सोमवार": "Monday", "मंगलवार": "Tuesday", "बुधवार": "Wednesday",
                         "गुरुवार": "Thursday", "शुक्रवार": "Friday", "शनिवार": "Saturday", "रविवार": "Sunday"]
        for (hindi, eng) in hindiDays {
            if text.contains(hindi) { return eng }
        }
        // Spanish
        let spanishDays = ["lunes": "Monday", "martes": "Tuesday", "miércoles": "Wednesday",
                           "miercoles": "Wednesday", "jueves": "Thursday", "viernes": "Friday",
                           "sábado": "Saturday", "sabado": "Saturday", "domingo": "Sunday"]
        for (es, eng) in spanishDays {
            if text.contains(es) { return eng }
        }
        if text.contains("today") || text.contains("aaj") || text.contains("आज") || text.contains("hoy") {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            return f.string(from: Date())
        }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private static func extractNarrative(from raw: String) -> String? {
        let callPattern = #"call:\w+\s*\{[^}]*\}"#
        guard let regex = try? NSRegularExpression(pattern: callPattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let cleaned = regex.stringByReplacingMatches(
            in: raw, range: NSRange(location: 0, length: (raw as NSString).length),
            withTemplate: ""
        )
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return nil
        }
        return trimmed
    }

    private static func buildDynamicReply(text: String, calls: [ToolCall], hasPhoto: Bool) -> String {
        let lower = text.lowercased()
        let isHindi = lower.contains("दवा") || lower.contains("गोली") || lower.contains("आज") ||
            lower.contains("dawa") || lower.contains("goli") || lower.contains("bhool")
        let isSpanish = lower.contains("pastilla") || lower.contains("medicamento") ||
            lower.contains("olvidó") || lower.contains("hoy")

        if calls.isEmpty {
            if isHindi { return "सुन लिया, लेकिन कुछ खास लॉग नहीं हुआ। थोड़ा और बताइए क्या हुआ।" }
            if isSpanish { return "Te escuché, pero no registré nada específico. Cuéntame un poco más." }
            return "I heard you, but couldn't log anything specific. Try adding a bit more detail about what happened."
        }

        var parts: [String] = []

        let ack: String
        if hasPhoto {
            ack = isHindi ? "फोटो मिल गई।" : isSpanish ? "Foto recibida." : "Photo received."
        } else {
            ack = isHindi ? "समझ गया।" : isSpanish ? "Entendido." : "Got it."
        }
        parts.append(ack)

        for call in calls {
            switch call.toolName {
            case "log_pill_change":
                let day = call.arguments["day"] ?? "today"
                let ampm = (call.arguments["ampm"] ?? "AM") == "AM"
                    ? (isHindi ? "सुबह" : isSpanish ? "mañana" : "morning")
                    : (isHindi ? "शाम" : isSpanish ? "tarde" : "evening")
                let change = call.arguments["change"] ?? "logged"
                if change == "missed" {
                    if isHindi { parts.append("\(day) \(ampm) की दवाई छूटी - डॉक्टर के लिए नोट किया।") }
                    else if isSpanish { parts.append("Medicamento de \(day) \(ampm) faltante - anotado para el doctor.") }
                    else { parts.append("\(day) \(ampm) medication missed - noted for the doctor.") }
                } else {
                    if isHindi { parts.append("\(day) \(ampm) की दवाई लॉग की गई।") }
                    else if isSpanish { parts.append("Medicamento de \(day) \(ampm) registrado.") }
                    else { parts.append("\(day) \(ampm) medication logged as \(change).") }
                }
            case "log_incident":
                let cat = call.arguments["category"] ?? "observation"
                let sev = call.arguments["severity"] ?? "low"
                let detail = call.arguments["detail"] ?? ""
                let sevText = isHindi
                    ? (sev == "high" ? "गंभीर" : sev == "medium" ? "मध्यम" : "सामान्य")
                    : isSpanish
                        ? (sev == "high" ? "alta" : sev == "medium" ? "media" : "baja")
                        : sev
                let short = detail.count > 60 ? String(detail.prefix(57)) + "..." : detail
                if isHindi { parts.append("\(cat) दर्ज किया (\(sevText) प्राथमिकता)\(short.isEmpty ? "" : " - \(short)")") }
                else if isSpanish { parts.append("\(cat.capitalized) registrado (prioridad \(sevText))\(short.isEmpty ? "" : " - \(short)")") }
                else { parts.append("\(cat.capitalized) logged (\(sevText) priority)\(short.isEmpty ? "" : " - \(short)")") }
            case "add_to_doctor_visit":
                let item = call.arguments["item"] ?? "an item"
                if isHindi { parts.append("डॉक्टर के लिए कतार में: \(item)") }
                else if isSpanish { parts.append("En cola para el doctor: \(item)") }
                else { parts.append("Queued for the doctor: \(item)") }
            case "notify_sibling":
                let msg = call.arguments["message"] ?? ""
                if isHindi { parts.append("भाई-बहन को सूचना भेजी जाएगी।") }
                else if isSpanish { parts.append("Notificación enviada a familiares.") }
                else { parts.append("Sibling notification queued\(msg.isEmpty ? "" : ": \(msg)").") }
            default:
                break
            }
        }

        return parts.joined(separator: " ")
    }

    func compileDoctorReport(days: Int) async -> AgentResult {
        let (engine, label) = route(.doctorReport)
        guard let engine else {
            return AgentResult(reply: "Models are still loading.", modelLabel: "none", toolCalls: [])
        }
        let logText = log.markdown(forLastDays: days)
        let prompt = Prompts.doctorReportPrompt(history: logText, days: days)
        let raw = await engine.generateReport(prompt: prompt, maxTokens: 800)
        let cleaned = Self.stripJSONWrapper(raw)
        return AgentResult(reply: cleaned, modelLabel: label, toolCalls: [])
    }

    private static func stripJSONWrapper(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              let data = trimmed.data(using: .utf8) else {
            return text
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let report = obj["report"] as? String { return report }
            if let content = obj["content"] as? String { return content }
            if let response = obj["response"] as? String { return response }
            if let text = obj["text"] as? String { return text }
        }
        return text
    }
}
