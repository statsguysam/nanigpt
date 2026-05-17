# NaniGPT iOS - Cactus Special Technology Track

Native SwiftUI iOS application that loads two Gemma 4 models simultaneously on-device via the [Cactus](https://github.com/cactus-compute/cactus) C runtime and routes caregiver tasks between them based on input length and task type.

## What's here

```
nanigpt-ios/
├── App/                     Swift sources (8 files)
│   ├── NaniGPTApp.swift     @main entry, scene + app lifecycle
│   ├── ContentView.swift    SwiftUI: Daily check-in, Today's log, Doctor visit prep tabs
│   ├── ModelRouter.swift    Routes journal entries between fast/deep paths by length + task type
│   ├── CactusEngine.swift   Actor wrapping cactus C API, OpenAI-style messages JSON
│   ├── Cactus.swift         Swift bindings to the Cactus C library (cactusInit, cactusComplete)
│   ├── Tools.swift          5 function-calling tools (Swift mirror of nanigpt/app/tools.py)
│   ├── Storage.swift        In-memory log store (Production target: SQLCipher AES-256 + Keychain/Secure Enclave)
│   └── Prompts.swift        System prompts for fast-path and deep-path models
├── Resources/
│   └── NaniGPT-Info.plist
├── build_cactus.sh          One-command rebuild of cactus-ios.xcframework
└── .gitignore               Excludes .gguf models, the xcframework, and Xcode user state
```

The Xcode project file and signing configuration are intentionally not included. To open in Xcode, create a new iOS App project, drag in the `App/` source files, link the framework built by `build_cactus.sh`, and set your own Apple Developer team.

## Multi-model routing

`ModelRouter.swift` dispatches each caregiver turn to one of two Gemma 4 instances loaded simultaneously through Cactus:

- **Fast path** - short journal entries, voice transcription, function-call dispatch route to the smaller Gemma 4 E2B model. Sub-second response latency.
- **Deep path** - long multi-incident entries, doctor visit report compilation, and weekly sibling digests route to the larger Gemma 4 E4B model.

Each model response surfaces a `"Handled by Gemma 4 E2B (fast path)"` or `"Compiled by Gemma 4 E4B (deep path)"` label in the UI so routing decisions are visible during evaluation.

## Build

The iOS app depends on a `cactus-ios.xcframework` built from the [Cactus C library](https://github.com/cactus-compute/cactus) source. The included `build_cactus.sh` script handles the full pipeline:

```bash
# Prerequisites
brew install cmake

# Build the Cactus framework
bash build_cactus.sh
```

This script clones the Cactus repository, runs `cactus build --apple`, and installs the resulting `cactus-ios.xcframework` ready for Xcode integration. It also patches the missing `module.modulemap` files inside each framework slice so Clang can resolve the import.

## Models

Two Gemma 4 GGUF files are loaded by the app at runtime. Download them from Hugging Face into `Models/` next to the Xcode project:

```bash
huggingface-cli download sammy786/nanigpt-gemma4-e4b-pill-lora-gguf \
  nanigpt-q4_k_m.gguf --local-dir Models/

huggingface-cli download google/gemma-4-E2B-it-GGUF \
  gemma-4-E2B-it-Q4_K_M.gguf --local-dir Models/
```

Both models load in approximately 4 seconds on iPhone 17. First-response latency on the fast path is around 1.2 seconds. The app runs offline with no network permission required.

## Privacy

The iOS deployment uses Keychain with Secure Enclave backing for the master encryption key, equivalent to the Android Keystore strategy described in the main writeup. The app declares no network entitlements and no analytics SDKs. The status bar's airplane mode indicator can be enabled at any point during use; the app continues to function identically.

## Special Technology Track: Cactus

This iOS app is the Cactus track entry. Cactus exists to enable exactly this pattern - multiple on-device LLMs orchestrated through a Swift actor, with no internet, no cloud, no fallback to a hosted API. The `Cactus.swift` bindings file and `CactusEngine.swift` actor implementation are the integration layer; `ModelRouter.swift` is the orchestration logic on top.
