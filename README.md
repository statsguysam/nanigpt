# NaniGPT

A private, on-device companion for adult children caring for aging parents with dementia.

NaniGPT runs entirely on a phone. No cloud. No data leaves the device. Built on [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) and released under Apache License 2.0 so it can be distributed at NGO scale.

> Submitted to [The Gemma 4 Good Hackathon](https://www.kaggle.com/competitions/gemma-4-good-hackathon) (Kaggle, Google DeepMind, May 2026).

## What it does

About 60 million people globally live with dementia. Roughly 70 percent of their care happens at home, mostly performed by their adult children. The technology that's supposed to help is fragmented across ten different cloud apps, none designed for someone exhausted at 11 PM, all uploading family medical history to servers the caregiver doesn't control.

NaniGPT is the one app on her phone that does what she actually needs.

The pill check. She photographs the weekly pill organizer each morning. The model compares against yesterday's photo and tells her what changed: taken, refilled, or missed.

The incident log. She talks or types about what happened. The model decomposes the input into structured observations (sleep, behavior, appetite, falls, bruises) at the right severity, and queues the urgent items for the next doctor visit.

The voice journal. When she's too tired to type, she just speaks. The model transcribes on-device and dispatches the same structured tools.

The doctor visit prep. One tap generates a printable report for the next appointment. Observations grouped by severity, queued questions, medication adherence summary.

The family circle. Quiet weekly digest to siblings; immediate alerts only when the caregiver chooses.

All four flows run on a single Gemma 4 E4B model, on-device, with no internet required.

## Technical highlights

Four distinct uses of Gemma 4 in one product. Multimodal vision for the pill organizer photos. Text reasoning for incident classification. Audio understanding for voice journal entries. Native function calling for a five-tool agent that orchestrates the actions.

LoRA fine-tuning lifted pill detection from 78 percent to 99.5 percent per-slot accuracy on a held-out 30-image evaluation set (418 of 420 slots correct), with 28 of 28 slots correct on out-of-distribution validation. Trained with [Unsloth](https://github.com/unslothai/unsloth) on a free Colab T4 in roughly 20 minutes. The trained adapter (around 80 MB) is bundled with the repo.

A differential pipeline backs the pill detection. Rather than trusting single-photo absolute classification, NaniGPT computes day-over-day diffs in pure Python from two single-photo classifications. This is robust to lighting and angle variation in real-world phone use.

The privacy architecture is built around the principle that nothing should leave the device. Storage uses SQLCipher AES-256 with the master key in Android Keystore, following the pattern established by previous Gemma 3n hackathon winners. No analytics, no telemetry, no third-party SDKs.

Released under Apache 2.0 so partner organizations (Alzheimer's Association, AARP, HelpAge International, ARDSI, Dementia Australia) can white-label and distribute without per-call API fees.

## Demo

A live Gradio share URL was published with the hackathon submission. To run the demo locally:

```bash
git clone https://github.com/statsguysam/nanigpt.git
cd nanigpt
pip install -r requirements.txt
jupyter notebook notebooks/nanigpt_pipeline.ipynb
```

`notebooks/nanigpt_pipeline.ipynb` reproduces the full training and deployment pipeline end-to-end on a free Colab T4: load Gemma 4 E4B with Unsloth, build the training dataset, run the LoRA fine-tune, save the adapter, push to Hugging Face, convert to GGUF via `llama.cpp`, publish the GGUF, and evaluate per-slot accuracy on the held-out test set. Total wall-clock is about 20 minutes. The output cells preserved in the notebook show the actual training loss curve, evaluation accuracy (418 of 420 slots correct), and Hugging Face upload confirmations from the original run.

The five function-calling tools and the local storage layer used at inference time live in `app/tools.py` and `app/storage.py` and are not duplicated in the notebook.

## Repository contents

```
nanigpt/
  README.md
  WRITEUP.md             full technical writeup (the hackathon submission text)
  LICENSE                Apache License 2.0
  requirements.txt
  app/
    tools.py             the 5 function-calling tools
    storage.py           caregiver log store (in-memory; swap for SQLCipher in prod)
    __init__.py
  notebooks/
    nanigpt_pipeline.ipynb   full reproducible pipeline with preserved run outputs
  data/
    training/            200 synthetic pill organizer photos with ground-truth labels
    eval/                30 held-out evaluation photos
    test_inputs/         original out-of-distribution images
    training_set.zip     bundled training and eval, easy Colab upload
  assets/
    finetune_result.png
  adapter/
    nanigpt_pill_lora.zip   trained LoRA adapter (~80 MB)
```

## Setup

Tested on Python 3.10 and CUDA 12.x. Free Colab T4 (16 GB VRAM) is sufficient for both inference and fine-tuning.

```bash
git clone https://github.com/statsguysam/nanigpt.git
cd nanigpt

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Optional: re-run fine-tuning to reproduce the 99.5 percent result
jupyter notebook notebooks/nanigpt_pipeline.ipynb
```

## Production deployment

The reference deployment target is MediaPipe LLM Inference on Android with Gemma 4 E4B in 4-bit quantization. The Gradio interface in this repo is for evaluator interactivity and reproducible demonstration. It is not the production form factor.

Pre-validated on-device using Google's on-device runtime preview app for Android. Full Android packaging is on the post-submission roadmap. See section 9 of [WRITEUP.md](WRITEUP.md).

## Run via Ollama (laptop-local)

For laptop-local use, the text and agent flows of NaniGPT are also published as a 4-bit quantized GGUF along with an Ollama Modelfile. The model and Modelfile are hosted on Hugging Face: [sammy786/nanigpt-gemma4-e4b-pill-lora-gguf](https://huggingface.co/sammy786/nanigpt-gemma4-e4b-pill-lora-gguf).

```bash
# Download the GGUF and Modelfile
huggingface-cli download sammy786/nanigpt-gemma4-e4b-pill-lora-gguf \
  nanigpt-q4_k_m.gguf Modelfile --local-dir .

# Create and run via Ollama
ollama create nanigpt -f Modelfile
ollama run nanigpt
```

The pill organizer photo classification still requires the full Python stack while multimodal Gemma 4 GGUF support continues to mature in upstream llama.cpp. The text reasoning, function-calling agent, and voice journal flows all run cleanly via Ollama on a laptop with no internet.

## Roadmap

Pilot deployment with one Indian NGO partner (ARDSI Pune chapter pending).

Collect 200 plus real caregiver-captured pill organizer photos for second-round fine-tuning.

Multilingual prompt and tool-output coverage validated for Hindi, Marathi, Telugu, Bengali, Urdu.

FHIR export integration for Electronic Health Record systems.

Schedule learning. The model would infer the medication schedule from observed photos rather than requiring explicit setup.

## Acknowledgments

Built on [Gemma 4](https://blog.google/innovation-and-ai/technology/developers-tools/gemma-4/) (Google DeepMind) and [Unsloth](https://github.com/unslothai/unsloth) (Daniel Han et al.). Demo interface: [Gradio](https://gradio.app/). The privacy architecture follows the pattern established by SafeVoice and the prior winners of the Gemma 3n Impact Challenge.

## License

Released under the [Apache License 2.0](LICENSE). You may use, modify, and distribute this code, including for commercial purposes, provided you preserve the copyright and license notice. NGO redistribution and white-labeling are explicitly intended use cases.

Per Section 2.5 of the Gemma 4 Good Hackathon Official Competition Rules, in the event this submission is selected as a Prize winner, the source code used to generate the winning Submission will additionally be licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) to the Competition Sponsor. The Apache 2.0 license remains the primary public license for ongoing redistribution.

## Contact

Built for The Gemma 4 Good Hackathon, May 2026. [github.com/statsguysam](https://github.com/statsguysam)
