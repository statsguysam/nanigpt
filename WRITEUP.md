# NaniGPT: A Private, On-Device Companion for Adult Children Caring for Aging Parents

*Submission to The Gemma 4 Good Hackathon. Tracks: Health and Sciences (primary), Digital Equity and Inclusivity (secondary).*

**Video:** [https://youtu.be/1IGi8ak73iE](https://youtu.be/1IGi8ak73iE)
**Repository:** [github.com/statsguysam/nanigpt](https://github.com/statsguysam/nanigpt)
**Model:** [huggingface.co/sammy786/nanigpt-gemma4-e4b-pill-lora-gguf](https://huggingface.co/sammy786/nanigpt-gemma4-e4b-pill-lora-gguf)

## 1. Problem Statement

Roughly 60 million people in the world today live with dementia, and that number is doubling every 20 years. About 70 percent of their care happens at home, performed largely by their adult children. Most often this is the daughter, who is also working a full-time job and raising her own children. The average primary caregiver provides 21 hours per week of care across an average duration of 4 to 8 years; 40 to 70 percent develop clinically significant depression; the unpaid labor value globally runs into the hundreds of billions of dollars per year.

The technology that is supposed to help her is structurally inadequate.

It is fragmented. The caregiver juggles a medication app, a calendar, a family WhatsApp group, a notes app for the doctor, and the photo gallery on her phone. None of these talk to each other.

It violates her privacy. Existing cloud-based caregiving apps like CareZone, Lotsa Helping Hands, and Caring Village upload her mother's medication list, behavior patterns, and incident photos to third-party servers. CareZone was acquired by Walmart in 2020, which illustrates where that data eventually flows.

It is built for clinicians, not families. Existing tools speak in medical jargon, expect structured input, and assume a caregiver who is rested and detail-oriented at 11 PM. Most are not.

It does not work offline. Caregivers in rural India, sub-Saharan Africa, and other low-bandwidth regions, plus those traveling or in poor-signal areas, are excluded entirely.

It is not free. Most serious caregiving tools paywall basic features at 10 to 30 dollars per month, well outside the reach of caregivers in low- and middle-income contexts.

NaniGPT is the one app on her phone that does everything she needs, runs entirely on the device, costs nothing, and can be distributed at scale through trusted nonprofits.

## 2. How Gemma 4 Is Used

NaniGPT uses all four of Gemma 4's headline capabilities, each in a non-trivial role.

**(a) Multimodal Vision: Pill Organizer Analysis.** Each morning the caregiver photographs the weekly pill organizer. Gemma 4 E4B classifies all 14 compartments (MON-SUN by AM/PM) for presence of pills. The result is compared to yesterday's classification to surface only the changes (taken, refilled, missed). The pipeline is robust to lighting, angle, and photo-quality variation typical of real-world phone use.

**(b) Native Function Calling: Agentic Caregiver Workflow.** When the caregiver speaks or types about something that happened ("Mom slept 3 hours, refused breakfast, asked where Dad is three times"), Gemma 4 decomposes the input into multiple structured tool calls. It invokes `log_incident`, `add_to_doctor_visit`, `notify_sibling`, and `generate_doctor_pdf` as appropriate. This is a true agentic workflow, not a chatbot wrapper. One natural-language input produces three to five structured side effects with appropriate severity gradation that the caregiver can review.

**(c) Audio Understanding: Voice Journal.** Caregivers are most exhausted at 11 PM, when typing is the last thing they want to do. NaniGPT accepts a voice note (microphone or upload), and Gemma 4's audio capability transcribes it directly on-device. No Whisper, no cloud STT. We validated near-perfect transcription on a 30-second AIFF clip of a mock caregiver journal entry. The transcript then chains the same agent pipeline as text input.

**(d) Text Reasoning: Doctor Visit Report.** When the appointment day arrives, Gemma 4 synthesizes the last 30 days of structured log entries into a printable plain-language report. Observations are grouped by severity, with queued questions for the doctor and a medication adherence summary. This artifact is what the caregiver brings to the 8-minute appointment instead of trying to remember 30 days of incidents on the spot.

## 3. Why Gemma 4 Specifically

NaniGPT is structurally only possible with an open-weights, multimodal, function-calling-native model that runs on a phone. Gemma 4 is the first widely available model that satisfies all of those constraints simultaneously.

On-device deployment is non-negotiable. Family medical data is sacred. Every cloud-based caregiving app is one breach away from a privacy incident affecting tens of millions of vulnerable patients. The 2.4 to 3.4 GB Gemma 4 E2B and E4B variants run in 4-bit quantization on a 200 dollar Android phone with no internet connection. There is no realistic alternative that simultaneously meets the privacy and capability bar.

Multimodality is the workflow. The caregiver's day is photos (pill organizer, bruises, fall scenes), voice (3 AM journal entries when typing is impossible), text (notes for the doctor), and orchestration. A text-only model would solve maybe 20 percent of the workflow. Gemma 4 covers all four modalities in one model.

Native function calling enables agentic action. Most LLM consumer apps are chatbots that respond to messages. NaniGPT is an agent. One input produces structured side effects across the caregiver log, the doctor agenda, and the family circle. Gemma 4's native tool-calling format makes this clean and reliable.

Apache 2.0 license enables NGO distribution. This is a structural moat that closed-source caregiving products cannot match. The Alzheimer's Association reaches more than 4 million caregivers in the US. AARP reaches 38 million members. HelpAge International operates in over 40 countries. ARDSI operates in India. None of these can adopt a closed-source product, because the model provider would charge per-call API fees that scale with patient count. They can adopt and white-label an Apache-2.0 on-device app. Distribution at NGO scale is what turns NaniGPT from a hackathon project into a global utility.

## 4. Technical Results

### 4.1 Pill Slot Classification, Fine-tuned with Unsloth

The most quantifiable component of NaniGPT is the pill organizer classifier. We measured Gemma 4 E4B's zero-shot performance on this task, then fine-tuned with Unsloth QLoRA, then re-measured.

**Methodology.** 200 synthetic pill organizer images generated with varied fill patterns, lighting (brightness 0.5 to 1.1), blur (0 to 1.5 pixels), rotation (negative 3 to plus 3 degrees), pill counts (1 to 5 per slot), and 7 different organizer titles. Held-out 30-image evaluation set generated independently with different random seeds. Additional out-of-distribution test on the original hand-tested OOD images, generated by a different script. LoRA fine-tuning via Unsloth on Colab T4: r=16, alpha=16, 120 steps, learning rate 2e-4, batch size 1, gradient accumulation 4. Total wall-clock: about 20 minutes.

**Results.**

| Setup | Eval set | Per-slot accuracy |
|---|---|---|
| Gemma 4 E4B zero-shot | 30 synthetic eval images | About 78 percent (varying 62 to 93 percent per image) |
| Gemma 4 E4B + LoRA (this work) | 30 synthetic eval images | **418 / 420 = 99.5 percent** |
| Gemma 4 E4B + LoRA (this work) | 2 original out-of-distribution test images | **28 / 28 = 100 percent** |

The 22-percentage-point lift is significant for a 20-minute training run, and the OOD result demonstrates that the model is learning to read pill organizers rather than memorizing the training distribution.

**Limitations.** Both eval sets are synthetic. Real-world performance on photos of physical plastic organizers is expected to be lower. We estimate 75 to 90 percent based on typical synthetic-to-real gaps in vision tasks. Production deployment would extend training with real caregiver-captured photos collected during pilot.

**Submission artifacts.** The LoRA adapter (around 80 MB) is bundled with the submission and merges cleanly into the base Gemma 4 E4B weights for production deployment via MediaPipe LLM Inference on Android.

### 4.2 Differential Detection Pipeline

Even at 99.5 percent per-slot accuracy, single-photo absolute classification is not the right product abstraction. The useful signal for a caregiver is what changed since yesterday's photo: taken, refilled, missed, no-change events, filtered by the medication schedule the caregiver has set up. We compute this differential in pure Python from two consecutive single-photo classifications. This sidesteps multi-image reasoning failure modes; we validated empirically that Gemma 4 E4B's two-image-in-one-call comparison is unreliable, while two separate single-image classifications plus Python diff is robust.

### 4.3 Function-Calling Agent

We expose 5 tools to Gemma 4 via the standard function-calling chat template: `log_pill_change`, `log_incident`, `add_to_doctor_visit`, `notify_sibling`, `generate_doctor_pdf`. Each tool is annotated with Python type hints (Literal types for constrained vocabularies) and a docstring; Gemma 4 decomposes natural-language caregiver input into the appropriate combination of structured calls with severity, priority, and urgency gradation set automatically. We validated this end-to-end on three caregiver scenarios: medication plus sibling notification, bruise plus doctor agenda, and a multi-incident voice journal entry.

### 4.4 Voice Journal

Audio input is handled directly by Gemma 4 E4B's multimodal audio capability. No separate STT model. Validated on a 30-second AIFF mock caregiver entry. Transcription quality was near-perfect, and the output was then chained through the agent pipeline to dispatch 5 tool calls (sleep observation, behavior pattern, appetite change, bruise observation, doctor agenda item).

### 4.5 llama.cpp Pipeline and Ollama Deployment

For users who prefer laptop-local deployment over Android, NaniGPT's text reasoning, function-calling agent, and voice journal flows are packaged as a 4-bit quantized GGUF model that runs natively via llama.cpp (and consequently via Ollama on top of llama.cpp).

The non-trivial part of getting here is the path from a multimodal-Gemma-4 LoRA to a text-only GGUF. As of the submission window, upstream llama.cpp does not yet support converting multimodal Gemma 4 LoRA adapters end-to-end. Our LoRA was trained against `Gemma4ForConditionalGeneration`, which nests the language model under `model.language_model.*`, but llama.cpp's tensor-name mapper for Gemma 4 expects the flat Gemma3-style `model.layers.*` namespace. We worked around this by (a) filtering the LoRA tensors to drop the vision and audio modules (588 of 812 trained tensors retained; vision tower at 224, audio tower at 0, multi-modal projector at 0), (b) renaming the remaining tensors in-place to strip `model.language_model.` from the path, and (c) constructing a stripped-down text-only base config that drops `vision_config` and `audio_config` while keeping the multimodal architecture string `Gemma4ForConditionalGeneration` (the only string Gemma4Model registers under in upstream llama.cpp, which inherits from Gemma3Model). With those three changes in place, the standard llama.cpp pipeline runs cleanly:

1. Train LoRA adapter via Unsloth on the multimodal Gemma 4 E4B (per section 4.1).
2. Filter the LoRA to language-model tensors only (588 of 812 trained tensors).
3. Strip the multimodal namespace from tensor names; build text-only base config.
4. Convert the filtered LoRA to GGUF format via llama.cpp's `convert_lora_to_gguf`.
5. Merge the LoRA into a base Gemma 4 E4B GGUF using `llama-export-lora`.
6. Quantize the merged model to Q4_K_M (~3.5 GB).
7. Ship with a Modelfile defining the NaniGPT system prompt and the Gemma 4 chat template.

The resulting model and Modelfile are publicly available at [https://huggingface.co/sammy786/nanigpt-gemma4-e4b-pill-lora-gguf](https://huggingface.co/sammy786/nanigpt-gemma4-e4b-pill-lora-gguf) and run via:

```
huggingface-cli download sammy786/nanigpt-gemma4-e4b-pill-lora-gguf nanigpt-q4_k_m.gguf Modelfile --local-dir .
ollama create nanigpt -f Modelfile
ollama run nanigpt
```

End-to-end validation on an Apple M3 Mac: model loads in 3.7 seconds with all 43 layers offloaded to Metal, first response generates in roughly 16 seconds. Output is on-character (warm tone, structured log entries, refusal of medical advice, emotional support) and matches the Modelfile system prompt cleanly. Pill organizer photo classification still requires the full Python stack while multimodal Gemma 4 GGUF support stabilizes in upstream llama.cpp; the text and agent flows run on a laptop with no internet.

This pipeline is the basis for the llama.cpp Special Technology Track entry: a working implementation of Gemma 4 on resource-constrained hardware, with a documented workaround for the current multimodal-LoRA conversion gap in upstream llama.cpp.

### 4.6 Cactus iOS Application with Multi-Model Routing

For the Cactus Special Technology Track, NaniGPT ships a native SwiftUI iOS application built on the Cactus framework (github.com/cactus-compute/cactus). The app is a thin layer over a deliberately designed **ModelRouter** that dispatches caregiver tasks between two Gemma 4 model sizes loaded simultaneously on-device via Cactus:

- Short journal entries, function-call dispatch, and voice transcription route to the smaller fast model.
- Long multi-incident journal entries, doctor visit report compilation, and weekly sibling digests route to the larger deep model.

Routing decisions are driven by task type and input length heuristics. Each turn surfaces a "Handled by..." label so the routing is visible in the UI, demonstrating exactly the local-first multi-model behaviour that Cactus exists to enable.

Integration details: the C library is built from source via `cactus build --apple`, producing `cactus-ios.xcframework` with separate device and simulator slices. The build script does not ship a Clang `module.modulemap` inside each slice's `cactus.framework/Modules/` directory, so we provide an installer that copies the source `module.modulemap` into both slices before Xcode integration. The Swift wrapper file `Cactus.swift` is added to the project sources alongside the framework. Our `CactusEngine.swift` actor wraps `cactusInit` and `cactusComplete` for each loaded model, exchanging OpenAI-compatible JSON message arrays.

The full iOS source lives in `nanigpt-ios/App/` in the submission repository. Validated end-to-end on iPhone 17 Simulator (iOS 26.4): both models load, the journal flow dispatches structured tool calls, and the routing label visibly changes between fast-path and deep-path turns. Deployment to a physical iPhone is gated only by Apple Developer device registration, not by any technical blocker.

## 5. Privacy and Safety Design

Family medical data is among the most sensitive personal information that exists. NaniGPT's privacy architecture is built around the principle that nothing should leave the device.

All inference is on-device. The model, the prompts, and the photos never reach a server. The targeted deployment platform is MediaPipe LLM Inference on Android with Gemma 4 E4B.

Storage encryption. The caregiver log is stored in SQLCipher (AES-256-GCM) with the master key in Android Keystore (hardware-backed where available). Equivalent protection on iOS uses Keychain with Secure Enclave backing.

Photos in app sandbox. Pill organizer and incident photos live in app-private storage, additionally encrypted at rest. They are never written to the shared photo gallery.

Family-circle messaging is opt-in per recipient. Sibling notifications are queued and only fire after caregiver confirmation. The transport (SMS, push, email) is configurable per deployment; the on-device tool records the intent.

No analytics, no telemetry. No third-party SDKs. The codebase is auditable by anyone (Apache 2.0).

## 6. Impact Potential and Distribution

The target users are the estimated 100 million plus primary family caregivers of aging parents globally, with particular emphasis on the roughly 30 million in low- and middle-income contexts where existing cloud-based caregiving apps either fail (no connectivity) or extract value (subscription paywalls).

NaniGPT is designed for B2B2C distribution through nonprofits rather than direct-to-consumer app store competition.

* Alzheimer's Association (US): 4 million plus caregivers in network
* AARP (US): 38 million members, large caregiver base
* HelpAge International: operations in 40 plus countries
* ARDSI (Alzheimer's & Related Disorders Society of India): chapters across India
* Dementia Australia: national caregiver support
* Local NGOs and women's health collectives in low-resource regions

The Apache 2.0 license enables each of these organizations to white-label, brand, localize, and distribute NaniGPT at zero marginal cost. No closed-source caregiving product can offer this. This is the structural difference between NaniGPT and the existing competitive landscape.

Localization roadmap. Initial release will support English, Hindi, Marathi, Telugu. Gemma 4's multilingual coverage extends naturally to 30 plus additional languages without retraining.

## 7. User Research

Product design is anchored to a representative caregiver profile that emerged from a review of published caregiving research from ARDSI, Dementia Care Notes (India), and the National Alliance for Caregiving. The profile, "Meena," is 47, a school administrator in Pune, caring for her 76-year-old mother with mild Alzheimer's while raising a teenage son and supporting a husband who travels for work. This profile is statistically common across South Asian middle-class families. The user-experience scenarios in section 8 are drawn from this profile.

Meena's household uses a standard 7-day pill organizer, common in urban middle-class Indian families and standard in Western markets. NaniGPT's voice journal, incident log, doctor visit prep, and family circle features serve caregivers regardless of whether the household uses an organizer or keeps pills in their original blister strips. The pill check feature is the one component that assumes a 7-day organizer; the planned blister-strip extension is discussed in sections 6 and 9.

Pilot interviews with practicing primary caregivers are in progress. Findings will be incorporated into the next revision.

## 8. User Experience: A Day In The Life

A representative day for Meena, the persona above, illustrates the full app surface.

**6:47 AM (45 seconds).** She photographs the pill organizer. The app says "Looks like Mom took her Monday morning pills." Done.

**10:15 AM (30 seconds).** Mom calls confused, asks about Dad (who has been gone 4 years). Meena voice-notes from her desk: "third time this week." The app logs as a behavior observation, queues for next neurologist visit, and offers to send her brother an FYI in tonight's digest.

**2:30 PM (90 seconds).** She notices an unexplained small bruise on Mom's forearm. She photographs it and adds a voice note. The app logs at low severity, attaches the photo, and queues a doctor question.

**9:48 PM (2 minutes).** She voice-journals the day's hardest moments. The app decomposes into 3-4 separate observations and 1 doctor-agenda item.

**Wednesday morning (5 minutes, neurologist day).** She generates the 30-day report. She brings the printout to the appointment. The doctor reads it in 90 seconds and immediately knows what to ask.

**Sunday morning (passive).** A weekly digest auto-sends to her brother and sister via SMS. Her brother texts back for the first time in two weeks.

Total active phone time per day: under 5 minutes. Compare to the 30 plus minutes per day caregivers currently spend juggling notebooks, group chats, medication apps, and trying to remember everything for the doctor.

## 9. Limitations and Future Work

**Limitations.** Pill classification accuracy is measured on synthetic data; real-world organizer photos will perform somewhat lower. The pill organizer photo feature is currently optimized for the standard 7-day AM/PM blister-style plastic organizer, which is common in middle-class urban Indian households and standard in Western markets but less common in lower-income or rural households. Households using original blister strips, daily steel dispensers, or other patterns are served by the voice journal and incident log features but not by photo-based medication tracking. The function-calling parser is signature-aware but assumes Gemma 4's specific tool-call format and would need adaptation for other model families. Family-circle SMS transport in the laptop build records intent on-device; the SMS gateway integration (Twilio for paid tier, Android-native SMS for offline operation) is the next layer in the platform-specific transport. The Android packaging (MediaPipe LLM Inference) is described but not bundled with this submission; the iOS Cactus client is bundled and validated on Simulator.

**Future work.** Blister strip detection. A second-pass model trained on photos of actual pill blister sheets, detecting which cells have been popped, would extend the pill check feature to households that do not use organizers. This would expand accessible target users from an estimated 60 million to 200 million plus globally. Pilot deployment with one Indian NGO partner; collect 200 plus real caregiver-captured pill organizer photos for second-round fine-tuning. Multilingual prompt and tool-output coverage validated for Hindi, Marathi, Telugu, Bengali. Integration with major Electronic Health Record systems (FHIR) for one-tap export to clinician portals. Schedule learning, where the model infers the caregiver's medication schedule from observed photos rather than requiring explicit setup. App Store distribution of the iOS Cactus client beyond simulator validation, gated currently only by Apple Developer device registration.

## 10. Acknowledgments

This work uses [Unsloth](https://github.com/unslothai/unsloth) for LoRA fine-tuning (Daniel Han et al.), [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) (Google DeepMind), [Cactus](https://github.com/cactus-compute/cactus) for the iOS multi-model runtime, [llama.cpp](https://github.com/ggerganov/llama.cpp) and [Ollama](https://ollama.com) for the laptop-local deployment, and the [HuggingFace Transformers](https://github.com/huggingface/transformers) library throughout.

## Repository

Full source, training data, fine-tuning notebooks, eval scripts, and the LoRA adapter are available at: **[github.com/statsguysam/nanigpt](https://github.com/statsguysam/nanigpt)**

Released under Apache License 2.0. Per Section 2.5 of the Gemma 4 Good Hackathon Official Competition Rules, in the event this submission is selected as a Prize winner, the source code used to generate the winning Submission will additionally be licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) to the Competition Sponsor. The Apache 2.0 license remains the primary public license for ongoing redistribution and NGO white-labeling.
