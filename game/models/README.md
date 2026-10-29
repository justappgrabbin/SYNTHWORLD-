# Bundled resident model

SmolLM2-360M-Instruct, Q4_K_M GGUF quantization by Unsloth, based on HuggingFaceTB/SmolLM2-360M-Instruct (Apache-2.0).

- Model: https://huggingface.co/unsloth/SmolLM2-360M-Instruct-GGUF
- Original: https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct
- SHA-256: `16c7f1667fea34bacad196a57b548effcb37614db4ab5677a20c8c7b823b9e63`

Run `python tools/prepare_resident_ai.py` with the Android NDK path to prepare the model and CPU native extension. Model weights and built libraries are excluded from Git, then bundled in the APK. The game never downloads them at runtime. On Android first use, the model is copied from the APK to app-private storage using bounded buffers, because llama.cpp requires a native filesystem path.
