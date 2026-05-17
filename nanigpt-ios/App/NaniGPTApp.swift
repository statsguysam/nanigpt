// NaniGPTApp.swift
// App entry point. Loads both Gemma 4 model engines on launch via Cactus,
// then hands control to ContentView.

import SwiftUI

@main
struct NaniGPTApp: App {
    @StateObject private var router = ModelRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .task {
                    await router.bootstrap()
                }
        }
    }
}
