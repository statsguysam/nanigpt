# 🌸 NaniGPT

**A private, on-device AI companion for adult children caring for aging parents with dementia.**

NaniGPT runs entirely on a phone. No cloud. No data leaves the device. Built on [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) (Google DeepMind), released under Apache License 2.0 so it can be distributed at NGO scale.

> Submitted to [The Gemma 4 Good Hackathon](https://www.kaggle.com/competitions/gemma-4-good-hackathon) (Kaggle × Google DeepMind, May 2026).

---

## What it does

There are about 60 million people in the world living with dementia. About 70% of their care happens at home, mostly performed by their adult children. The technology that's supposed to help is fragmented across ten different cloud apps, none designed for someone exhausted at 11 PM, all uploading family medical history to servers the caregiver does not control.

NaniGPT is the one app on her phone that does what she actually needs:

- 📷 **Pill check.** Photograph the weekly pill organizer each morning. The model compares to yesterday's photo and tells her what changed — taken, refilled, or missed.
- 💬 **Incident log.** Talk or type about what happened. The model decomposes the input into structured observations (sleep, behavior, appetite, falls, bruises) at the right severity, and queues the urgent items for the next doctor visit.
- 🎙️ **Voice journal.** When she's too tired to type, she just speaks. The model transcribes on-device and dispatches the same structured tools.
- 🩺 **Doctor visit prep.** One tap generates the printable report for the next appointment — observations grouped by severity, queued questions, medication adherence summary.
- 📨 **Family circle.** Quiet weekly digest to siblings; immediate alerts only when the caregiver chooses.

All four flows run on a single Gemma 4 E4B model, on-device, with no internet required.

---

## Technical highlights

- **Four distinct uses of Gemma 4** — multimodal vision (pill organizer), text reasoning (incident classification), audio understanding (voice journal), native function calling (5-tool agent).
- **LoRA fine-tuning lifts pill detection accuracy 78 % → 99.5 %** on a held-out 30-image evaluation set (418 / 420 slots correct), with 28 / 28 slots correct on out-of-distribution validation. Trained with [Unsloth](https://github.com/unslothai/unsloth) on a free Colab T4 in roughly 20 minutes. LoRA adapter (~80 MB) ships with the repo.
- **Differential pipeline** for pill detection — instead of trusting single-photo absolute classification, NaniGPT computes day-over-day diffs in pure Python from two single-photo classifications. Robust to lighting and angle variation.
- **Privacy-first storage architecture** designed for SQLCipher AES-256 + Android Keystore on production deployment. Nothing in the demo or production architecture writes patient data off-device.
- **Apache 2.0** so partner organizations (Alzheimer's Association, AARP, HelpAge International, ARDSI, Dementia Australia, etc.) can white-label and distribute without per-call API fees.

---

## Demo

A live Gradio share URL was published with the hackathon submission. To run the demo locally:

```bash
git clone https://github.com/statsguysam/nanigpt.git
cd nanigpt
pip install -r requirements.txt
jupyter notebook notebooks/03_gradio_demo.ipynb
```

The full notebook sequence (run in order):

| Notebook | Purpose |
|---|---|
| `01_setup_and_inference.ipynb` | Load Gemma 4 E4B with Unsloth, run text + multimodal inference |
| `02_function_calling.ipynb` | Wire 5 tools (log_pill_change, log_incident, add_to_doctor_visit, notify_sibling, generate_doctor_pdf) and validate the agent end-to-end |
| `03_gradio_demo.ipynb` | Launch the caregiver-facing UI |
| `04_voice_journal.ipynb` | Add audio input — Gemma 4 transcribes, then dispatches the agent |
| `05_finetune_pill_detection.ipynb` | Reproduce the 78 % → 99.5 % LoRA fine-tuning result |

---

## Repository contents

```
nanigpt/
├── README.md              ← you are here
├── WRITEUP.md             ← full technical writeup (the hackathon submission text)
├── LICENSE                ← Apache License 2.0
├── requirements.txt
├── app/
│   ├── tools.py           ← the 5 function-calling tools
│   ├── storage.py         ← caregiver log store (in-memory; swap for SQLCipher in prod)
│   └── __init__.py
├── notebooks/
│   ├── 01_setup_and_inference.ipynb
│   ├── 02_function_calling.ipynb
│   ├── 03_gradio_demo.ipynb
│   ├── 04_voice_journal.ipynb
│   └── 05_finetune_pill_detection.ipynb
├── data/
│   ├── training/          ← 200 synthetic pill organizer photos + ground-truth labels
│   ├── eval/              ← 30 held-out evaluation photos
│   ├── test_inputs/       ← Day 1 hand-tested OOD images
│   └── training_set.zip   ← bundled training+eval, easy Colab upload
├── assets/
│   └── finetune_result.png
└── adapter/
    └── nanigpt_pill_lora.zip  ← trained LoRA adapter (~80 MB)
```

---

## Setup (local)

Tested on Python 3.10+ with CUDA 12.x. Free Colab T4 (16 GB VRAM) is sufficient for both inference and fine-tuning.

```bash
# Clone
git clone https://github.com/statsguysam/nanigpt.git
cd nanigpt

# Install (use a virtual environment)
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Optional — re-run fine-tuning to reproduce the 99.5 % result
jupyter notebook notebooks/05_finetune_pill_detection.ipynb
```

---

## Production deployment

The reference deployment target is **MediaPipe LLM Inference on Android** with Gemma 4 E4B in 4-bit quantization. The Gradio interface in this repo is for evaluator interactivity and reproducible demonstration; it is not the production form factor.

Pre-validated on-device using the official Google AI Edge Gallery Android app. Full Android packaging is on the post-submission roadmap — see §9 of [WRITEUP.md](WRITEUP.md).

---

## Roadmap

- Pilot deployment with one Indian NGO partner (ARDSI Pune chapter pending).
- Collect 200+ real caregiver-captured pill organizer photos for second-round fine-tuning.
- Multilingual prompt and tool-output coverage validated for Hindi, Marathi, Telugu, Bengali, Urdu.
- FHIR export integration for Electronic Health Record systems.
- Schedule learning — model infers the medication schedule from observed photos rather than requiring explicit setup.

---

## Acknowledgments

Built on [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) (Google DeepMind) and [Unsloth](https://github.com/unslothai/unsloth) (Daniel Han et al.). Demo interface: [Gradio](https://gradio.app/). Privacy architecture follows the pattern established by SafeVoice and the prior winners of the Gemma 3n Impact Challenge.

---

## License

Released under the [Apache License 2.0](LICENSE). You may use, modify, and distribute this code (including for commercial purposes) provided you preserve the copyright and license notice. NGO redistribution and white-labeling are explicitly intended use cases.

---

## Contact

Built for The Gemma 4 Good Hackathon · May 2026 · [github.com/statsguysam](https://github.com/statsguysam)
