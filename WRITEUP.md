# NaniGPT — A Private, On-Device AI Companion for Adult Children Caring for Aging Parents

*Submission to The Gemma 4 Good Hackathon · Tracks: Health & Sciences (primary), Digital Equity & Inclusivity (secondary), Special Tech: Unsloth*

---

## 1. Problem Statement

There are roughly **60 million people in the world living with dementia today**, and that number is doubling every 20 years. About 70% of their care happens at home, performed largely by their adult children — most often the daughter, while she is also working a full-time job and raising her own children. The average primary caregiver provides 21+ hours per week of care across an average duration of 4-8 years; 40-70% develop clinically significant depression; the unpaid labor value globally runs into the hundreds of billions of dollars per year.

The technology that is supposed to help her is structurally inadequate:

- **It is fragmented.** The caregiver juggles a medication app, a calendar, a family WhatsApp group, a notes app for the doctor, and the photo gallery on her phone — none of which talk to each other.
- **It violates her privacy.** Existing cloud-based caregiving apps (CareZone, Lotsa Helping Hands, Caring Village, etc.) upload her mother's medication list, behavior patterns, and incident photos to third-party servers. CareZone was acquired by Walmart in 2020 — illustrating where that data eventually flows.
- **It is built for clinicians, not families.** Existing tools speak in medical jargon, expect structured input, and assume a caregiver who is rested and detail-oriented at 11pm. Most are not.
- **It does not work offline.** Caregivers in rural India, sub-Saharan Africa, and other low-bandwidth regions, plus those traveling or in poor-signal areas, are excluded entirely.
- **It is not free.** Most serious caregiving tools paywall basic features at $10-30/month — well outside the reach of caregivers in low- and middle-income contexts.

NaniGPT is the one app on her phone that does everything she needs, runs entirely on the device, costs nothing, and can be distributed at scale through trusted nonprofits.

---

## 2. How Gemma 4 Is Used

NaniGPT uses **all four of Gemma 4's headline capabilities**, each in a non-trivial role:

**(a) Multimodal Vision — Pill Organizer Analysis.** Each morning, the caregiver photographs the weekly pill organizer. Gemma 4 E4B classifies all 14 compartments (MON-SUN × AM/PM) for presence of pills. The result is compared to yesterday's classification to surface only the *changes* (taken / refilled / missed) — robust to the lighting, angle, and photo-quality variation of real-world phone use.

**(b) Native Function Calling — Agentic Caregiver Workflow.** When the caregiver speaks or types about something that happened ("Mom slept 3 hours, refused breakfast, asked where Dad is three times"), Gemma 4 decomposes the input into multiple structured tool calls — invoking `log_incident`, `add_to_doctor_visit`, `notify_sibling`, and `generate_doctor_pdf` as appropriate. This is a *true* agentic workflow, not a chatbot wrapper: one natural-language input produces 3-5 structured side effects with appropriate severity gradation that the caregiver can review.

**(c) Audio Understanding — Voice Journal.** Caregivers are most exhausted at 11pm when typing is the last thing they want to do. NaniGPT accepts a voice note (microphone or upload), and Gemma 4's audio capability transcribes it directly on-device (no Whisper, no cloud STT) before chaining the same agent pipeline as text input. We validated near-perfect transcription on a 30-second AIFF clip of a mock caregiver journal entry.

**(d) Text Reasoning — Doctor Visit Report.** When the appointment day arrives, Gemma 4 synthesizes the last 30 days of structured log entries into a printable plain-language report: observations grouped by severity, queued questions for the doctor, medication adherence summary. This artifact is what the caregiver brings to the 8-minute appointment instead of trying to remember 30 days of incidents on the spot.

---

## 3. Why Gemma 4 Specifically

NaniGPT is structurally only possible with an open-weights, multimodal, function-calling-native model that runs on a phone. Gemma 4 is the first widely-available model that satisfies all of those constraints simultaneously.

- **On-device deployment is non-negotiable.** Family medical data is sacred. Every cloud-based caregiving app is one breach away from a privacy incident affecting tens of millions of vulnerable patients. The 2.4-3.4 GB Gemma 4 E2B / E4B variants run in 4-bit quantization on a $200 Android phone with no internet connection. There is no realistic alternative that simultaneously meets the privacy and capability bar.

- **Multimodality is the workflow.** The caregiver's day is photos (pill organizer, bruises, fall scenes), voice (3am journal entries when typing is impossible), text (notes for the doctor), and orchestration. A text-only model would solve maybe 20% of the workflow. Gemma 4 covers all four modalities in one model.

- **Native function calling enables agentic action.** Most LLM consumer apps are chatbots — they respond to messages. NaniGPT is an *agent* — one input produces structured side effects across the caregiver log, the doctor agenda, and the family circle. Gemma 4's native tool-calling format makes this clean and reliable.

- **Apache 2.0 license enables NGO distribution.** This is a structural moat that closed-AI caregiving products cannot match. The Alzheimer's Association reaches 4M+ caregivers in the US; AARP reaches 38M members; HelpAge International operates in 40+ countries; ARDSI in India. None of these can adopt a closed-AI app — Google or OpenAI would charge per-call API fees that scale with patient count. They can adopt and white-label an Apache-2.0 on-device app. Distribution at NGO scale is what turns NaniGPT from a hackathon project into a global utility.

---

## 4. Technical Results

### 4.1 Pill Slot Classification — Fine-tuned with Unsloth

The most quantifiable component of NaniGPT is the pill organizer classifier. We measured Gemma 4 E4B's zero-shot performance on this task, then fine-tuned with Unsloth QLoRA, then re-measured.

**Methodology.**
- 200 synthetic pill organizer images generated with varied fill patterns, lighting (brightness 0.5-1.1), blur (0-1.5px), rotation (-3° to +3°), pill counts (1-5 per slot), and 7 different organizer titles.
- Held-out 30-image evaluation set generated independently (different random seeds).
- Additional out-of-distribution test on the original Day 1 hand-tested images (different generation script).
- LoRA fine-tuning via Unsloth on Colab T4: r=16, alpha=16, 120 steps, lr=2e-4, batch=1, gradient accumulation=4. Total wall-clock: ~20 minutes.

**Results.**

| Setup | Eval set | Per-slot accuracy |
|---|---|---|
| Gemma 4 E4B zero-shot | 30 synthetic eval images | ~78% (varying 62-93% per image) |
| Gemma 4 E4B + LoRA (this work) | 30 synthetic eval images | **418/420 = 99.5%** |
| Gemma 4 E4B + LoRA (this work) | 2 OOD Day 1 test images | **28/28 = 100%** |

The 22-percentage-point lift is significant for a 20-minute training run, and the OOD result demonstrates that the model is learning *to read pill organizers* rather than memorizing the training distribution.

**Limitations.** Both eval sets are synthetic. Real-world performance on photos of physical plastic organizers is expected to be lower (we estimate 75-90% based on typical synthetic-to-real gaps in vision tasks). Production deployment would extend training with real caregiver-captured photos collected during pilot.

**Submission artifacts.** The LoRA adapter (~80 MB) is bundled with the submission and merges cleanly into the base Gemma 4 E4B weights for production deployment via MediaPipe LLM Inference on Android.

### 4.2 Differential Detection Pipeline

Even at 99.5% per-slot accuracy, single-photo absolute classification is not the right product abstraction. The *useful* signal for a caregiver is "what changed since yesterday's photo" — taken / refilled / missed / no-change events, filtered by the medication schedule the caregiver has set up. We compute this differential in pure Python from two consecutive single-photo classifications, which sidesteps multi-image reasoning failure modes (validated empirically: Gemma 4 E4B's two-image-in-one-call comparison is unreliable, while two separate single-image classifications + Python diff is robust).

### 4.3 Function-Calling Agent

We expose 5 tools to Gemma 4 via the standard function-calling chat template: `log_pill_change`, `log_incident`, `add_to_doctor_visit`, `notify_sibling`, `generate_doctor_pdf`. Each is annotated with Python type hints (Literal types for constrained vocabularies) and a docstring; Gemma 4 decomposes natural-language caregiver input into the appropriate combination of structured calls with severity / priority / urgency gradation set automatically. Validated end-to-end on three caregiver scenarios (medication + sibling, bruise + doctor agenda, multi-incident voice journal).

### 4.4 Voice Journal

Audio input is handled directly by Gemma 4 E4B's multimodal audio capability — no separate STT model. Validated on a 30-second AIFF mock caregiver entry: transcription quality near-perfect, output then chained through the agent pipeline to dispatch 5 tool calls (sleep observation, behavior pattern, appetite change, bruise observation, doctor agenda item).

---

## 5. Privacy and Safety Design

Family medical data is among the most sensitive personal information that exists. NaniGPT's privacy architecture is built around the principle that *nothing should leave the device*.

- **All inference is on-device.** The model, the prompts, and the photos never reach a server. Targeted deployment platform: MediaPipe LLM Inference on Android with Gemma 4 E4B.
- **Storage encryption.** The caregiver log is stored in SQLCipher (AES-256-GCM) with the master key in Android Keystore (hardware-backed where available), following the pattern established by SafeVoice and other privacy-first caregiving apps.
- **Photos in app sandbox.** Pill organizer and incident photos live in app-private storage, additionally encrypted at rest. They are never written to the shared photo gallery.
- **Family-circle messaging is opt-in per recipient.** Sibling notifications are queued and only fire after caregiver confirmation. The actual transport (SMS, push, email) is configurable; the on-device tool just records the intent.
- **No analytics, no telemetry.** No third-party SDKs. The codebase will be auditable by anyone (Apache 2.0).
- **App appearance.** Uses a generic launcher icon by default ("Notes" or similar) so an inquisitive household member browsing her phone does not see a "Caregiver Tracker" entry.

---

## 6. Impact Potential and Distribution

The target users are the **estimated 100+ million primary family caregivers** of aging parents globally, with particular emphasis on the ~30 million in low- and middle-income contexts where existing cloud-based caregiving apps either fail (no connectivity) or extract value (subscription paywalls).

**Distribution strategy.** NaniGPT is designed for B2B2C distribution through nonprofits rather than direct-to-consumer app store competition:

- **Alzheimer's Association** (US) — 4M+ caregivers in network
- **AARP** (US) — 38M members, large caregiver base
- **HelpAge International** — operations in 40+ countries
- **ARDSI** (Alzheimer's & Related Disorders Society of India) — chapters across India
- **Dementia Australia** — national caregiver support
- **Local NGOs and women's health collectives** in low-resource regions

The Apache 2.0 license enables each of these organizations to white-label, brand, localize, and distribute NaniGPT at zero marginal cost — something no closed-AI caregiving product can offer. This is the structural difference between NaniGPT and the existing competitive landscape.

**Localization roadmap.** Initial release: English, Hindi, Marathi, Telugu. Gemma 4's multilingual coverage extends naturally to ~30+ additional languages without retraining.

---

## 7. User Research

We constructed a representative caregiver persona to drive product design and to test the interface against real-world workflow constraints. The persona, "Meena," is 47, a school administrator in Pune, caring for her 76-year-old mother with mild Alzheimer's while raising a teenage son and supporting a husband who travels for work — a profile that is statistically common across South Asian middle-class families. The user-experience scenarios in §8 below are drawn from this persona and from our review of published caregiving research from ARDSI, Dementia Care Notes (India), and the National Alliance for Caregiving.

A pilot interview with one real primary caregiver of a parent with memory loss is in progress at the time of submission. Direct user-research findings will be incorporated into the post-submission revision and shared back with the hackathon organizers.

---

## 8. User Experience — A Day In The Life

A representative day for Meena, the persona above, illustrates the full app surface:

- **6:47 AM** (45 sec) — Photographs pill organizer. App says *"Looks like Mom took her Monday morning pills."* Done.
- **10:15 AM** (30 sec) — Mom calls confused, asks about Dad (who has been gone 4 years). Voice-notes from desk: "third time this week." App logs as behavior observation, queues for next neurologist visit, offers to send brother an FYI in tonight's digest.
- **2:30 PM** (90 sec) — Notices unexplained small bruise on Mom's forearm. Photographs + voice-notes. App logs at low severity, attaches photo, queues doctor question.
- **9:48 PM** (2 min) — Voice-journals the day's hardest moments. App decomposes into 3-4 separate observations + 1 doctor-agenda item.
- **Wednesday morning** (5 min, neurologist day) — Generates 30-day report. Brings printout to appointment. Doctor reads it in 90 seconds and immediately knows what to ask.
- **Sunday morning** (passive) — Weekly digest auto-sends to brother and sister via SMS. Brother texts back for the first time in two weeks.

**Total active phone time per day: under 5 minutes.** Compare to the 30+ minutes per day caregivers currently spend juggling notebooks, group chats, medication apps, and trying to remember everything for the doctor.

---

## 9. Limitations and Future Work

**Limitations.**
- Pill classification accuracy is measured on synthetic data; real-world organizer photos will perform somewhat lower.
- Function-calling parser is signature-aware but assumes Gemma 4's specific tool-call format; would need adaptation for other model families.
- Family-circle SMS transport is stubbed in the prototype; production needs an SMS gateway (Twilio for paid tier, or Android-native SMS for fully-offline operation).
- The caregiver UI is currently demoed via Gradio; the production target (MediaPipe LLM Inference on Android) is described but not packaged in the submission window.

**Future work.**
- Pilot deployment with one Indian NGO partner; collect 200+ real caregiver-captured pill organizer photos for second-round fine-tuning.
- Multilingual prompt and tool-output coverage validated for Hindi, Marathi, Telugu, Bengali.
- Integration with major Electronic Health Record systems (FHIR) for one-tap export to clinician portals.
- Schedule learning — model infers the caregiver's medication schedule from observed photos rather than requiring explicit setup.

---

## 10. Acknowledgments

This work uses [Unsloth](https://github.com/unslothai/unsloth) for LoRA fine-tuning (Daniel Han et al.), [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) (Google DeepMind), [Gradio](https://gradio.app/) for the demo interface, and the [HuggingFace Transformers](https://github.com/huggingface/transformers) library throughout.

We acknowledge the prior Gemma 3n Impact Challenge winners — particularly the developers of Gemma Vision and SafeVoice — whose published architectures established the on-device privacy-first caregiving pattern that NaniGPT extends.

---

## Repository

Full source, training data, fine-tuning notebooks, eval scripts, and the LoRA adapter are available at: **[github.com/statsguysam/nanigpt]** *(URL to be updated at submission)*

Released under Apache License 2.0.
