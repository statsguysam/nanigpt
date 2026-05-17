// CactusEngine.swift
// Wraps the Cactus C-style Swift bindings (apple/Cactus.swift from
// github.com/cactus-compute/cactus) into an actor-isolated engine
// per loaded model. Cactus is integrated as an xcframework, not a
// Swift Package, so there is no `import Cactus`. The top-level
// cactus* functions are made available by adding Cactus.swift to
// the project sources alongside the cactus-ios.xcframework binary.

import Foundation

enum EngineError: Error {
    case modelFileNotFound(String)
    case loadFailed(String)
    case generationFailed(String)
}

struct SendableModelHandle: @unchecked Sendable {
    let pointer: CactusModelT
}

actor CactusEngine {
    private let model: SendableModelHandle
    private let systemPrompt: String

    private init(model: SendableModelHandle, systemPrompt: String) {
        self.model = model
        self.systemPrompt = systemPrompt
    }

    private static let cactusWeightsDirs: [String] = {
        var dirs: [String] = []
        // Homebrew Intel
        dirs.append("/usr/local/opt/cactus/libexec/weights")
        // Homebrew Apple Silicon
        dirs.append("/opt/homebrew/opt/cactus/libexec/weights")
        // Homebrew Cellar (versioned)
        let cellarPaths = ["/opt/homebrew/Cellar/cactus", "/usr/local/Cellar/cactus"]
        for cellar in cellarPaths {
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: cellar),
               let latest = versions.sorted().last {
                dirs.append("\(cellar)/\(latest)/libexec/weights")
            }
        }
        return dirs
    }()

    private static func runOnBackground<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try work()
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    static func load(modelName: String, systemPrompt: String, contextLength: Int) async throws -> CactusEngine {
        let modelPath = try resolveModelPath(modelName)
        do {
            let ptr = try await runOnBackground { try cactusInit(modelPath, nil, false) }
            return CactusEngine(model: SendableModelHandle(pointer: ptr), systemPrompt: systemPrompt)
        } catch {
            throw EngineError.loadFailed("\(modelName): \(error.localizedDescription)")
        }
    }

    private static func resolveModelPath(_ modelName: String) throws -> String {
        let fm = FileManager.default

        // 1. Check app bundle (for bundled Cactus model directories)
        if let url = Bundle.main.url(forResource: modelName, withExtension: nil),
           fm.fileExists(atPath: url.path + "/config.txt") {
            return url.path
        }

        // 2. Check cactus CLI weights directories
        for dir in cactusWeightsDirs {
            let candidate = "\(dir)/\(modelName)"
            if fm.fileExists(atPath: candidate + "/config.txt") {
                return candidate
            }
        }

        // 3. Check home directory .cactus/weights
        let home = NSHomeDirectory()
        let homeCandidate = "\(home)/.cactus/weights/\(modelName)"
        if fm.fileExists(atPath: homeCandidate + "/config.txt") {
            return homeCandidate
        }

        throw EngineError.modelFileNotFound(
            "\(modelName): No Cactus model directory found. Run 'cactus download' to get models."
        )
    }

    deinit {
        let handle = model.pointer
        Task.detached { cactusDestroy(handle) }
    }

    func generate(prompt: String, imageBase64: String? = nil, maxTokens: Int = 512, temperature: Double = 0.3, topP: Double = 0.9) async -> String {
        let userContent: Any
        if let imageBase64 {
            userContent = [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]],
            ] as [[String: Any]]
        } else {
            userContent = prompt
        }
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContent],
        ]
        let options: [String: Any] = [
            "max_tokens": maxTokens,
            "temperature": temperature,
            "top_p": topP,
        ]

        guard let messagesData = try? JSONSerialization.data(withJSONObject: messages),
              let messagesJson = String(data: messagesData, encoding: .utf8) else {
            return "[encoding error: messages]"
        }
        guard let optionsData = try? JSONSerialization.data(withJSONObject: options),
              let optionsJson = String(data: optionsData, encoding: .utf8) else {
            return "[encoding error: options]"
        }

        do {
            let m = model.pointer
            let resultJson = try await Self.runOnBackground {
                try cactusComplete(m, messagesJson, optionsJson, nil, nil, nil)
            }
            return Self.extractContent(from: resultJson) ?? resultJson
        } catch {
            return "[generation error: \(error.localizedDescription)]"
        }
    }

    func generateReport(prompt: String, maxTokens: Int = 800, temperature: Double = 0.3, topP: Double = 0.9) async -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": Prompts.doctorReportSystemPrompt],
            ["role": "user", "content": prompt],
        ]
        let options: [String: Any] = [
            "max_tokens": maxTokens,
            "temperature": temperature,
            "top_p": topP,
        ]

        guard let messagesData = try? JSONSerialization.data(withJSONObject: messages),
              let messagesJson = String(data: messagesData, encoding: .utf8) else {
            return "[encoding error: messages]"
        }
        guard let optionsData = try? JSONSerialization.data(withJSONObject: options),
              let optionsJson = String(data: optionsData, encoding: .utf8) else {
            return "[encoding error: options]"
        }

        do {
            let m = model.pointer
            let resultJson = try await Self.runOnBackground {
                try cactusComplete(m, messagesJson, optionsJson, nil, nil, nil)
            }
            return Self.extractContent(from: resultJson) ?? resultJson
        } catch {
            return "[generation error: \(error.localizedDescription)]"
        }
    }

    private static func extractContent(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let response = obj["response"] as? String { return response }
        if let content = obj["content"] as? String { return content }
        if let choices = obj["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        return nil
    }
}
