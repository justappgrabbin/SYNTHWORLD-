# SynthWorld

Phone-first Godot SynthWorld build. Active runtime source lives in `game/`; preserved donor lineage remains in the full source archive.

## Living agents and scene notes (0.2.0)

Cynthia and the utility-driven Generator now have articulated human-form bodies with walking animation. Their existing behavior systems remain in use. Open **Scene notes + Self-discovery** to give the agents a situation, exact user note, place and time. Notes persist verbatim. Full-word cues `rest`, `quiet`, `socialize`, `connect`, `explore`, `repair`, and `build` select supported priorities; ambiguous notes defer to the explicit situation choice. This is an offline rule/utility agent, not an LLM or unrestricted natural-language scene generator.

- Rest pauses movement; connecting gathers agents; build queues Cynthia's existing tree-building function and lets other agents help repair; exploration retains utility-driven activity.
- Grove, Home and Gathering configure furnishings; Day, Evening and Night change light. Camera controls rotate the view.
- The Discover tab ports the Self-Discovery.zip application's five self-knowledge categories and datababies → Gene Gnomes → Field Friends progression into the Godot runtime. It preserves the player's own words instead of generating random fragments.
- Thirteen datababies form a Gene Gnome. Three unused Gene Gnomes awaken a Field Friend, represented by an additional autonomous human-form agent. The donor overview says 3–5 Gene Gnomes; its web schema separately contains a 78-Gnome threshold. This port uses the overview's three-Gnome minimum and documents that choice.
- The Memory tab records exact reflections and scene history locally in `user://synthworld-save.json`. Synthesized fragments remain preserved. Existing friends and discoveries reload after restarting.

### Validation and Android

Use Godot **4.3 stable** with Android export templates, JDK 17 and Android SDK/build-tools 34. Export preset **Android** produces a signed debug APK for ARMv7 and ARM64. It is a sideload development build, not a Play Store release. The signing key is environment-local and not included in source.

```
godot --headless --path game --editor --quit
XDG_DATA_HOME=/tmp/synthworld-clean-test godot --headless --path game --script res://Tests/Integration.gd
godot --headless --path game --export-debug Android ../build/SynthWorld.apk
```

Run the test with a fresh XDG_DATA_HOME to isolate its generated discoveries from real saves. It exercises notes, scene priorities, furnishing, 39 discoveries, synthesis, awakening, double-spend protection and restart persistence. Godot 4.3's dummy headless renderer may log null-mesh warnings during procedural mesh cleanup; rendered verification is separate.

Sources: this repository's active Godot runtime and Drive's `SynthWorld-321-source.zip`; self-discovery behavior grounded in Drive's `Self-Discovery.zip`, specifically `replit.md`, `shared/schema.ts`, and `client/src/lib/gameContext.tsx`.

## Resident local AI theme designer (0.3.0)

The **Resident AI** tab runs bundled **SmolLM2-360M-Instruct Q4_K_M** through a CPU llama.cpp GDExtension. Write a theme wish and press **Let Cynthia set up the theme**. Real local model inference chooses a constrained JSON plan: palette, place, time and activity. The game applies it to ground color, UI, human clothing, lighting, furnishings and agent priorities; the selection and exact wish persist across restart.

Six rendered palettes are available: pink/teal, forest, ocean, sunset, violet and monochrome. The model configures the existing world; it does not generate arbitrary meshes, textures or executable game code. This implements theme reskinning for the current human bodies. It does not claim to integrate the separate legacy Morph deployment/MCP service.

- Bundled model and native ARM64 runtime; no cloud service, API key or runtime network download.
- Generation and first-use model extraction run in a worker thread. Manual scene and discovery controls continue to work.
- Invalid or incomplete output leaves the previous theme in place, with an explicit retry message. A cancellation control stops generation. No guessed AI response is substituted.
- Approximately 270 MB model weights plus runtime; Android prepares an additional private model copy on first use. ARM64 Android 6+ build. Initial inference can take time on phone CPUs.
- The previous offline utility and builder agents remain active without invoking the model.

### Reproduce the resident AI build

Install CMake, Ninja, Python 3, Git, JDK 17, Android SDK/build-tools 34 and NDK 26.3.11579264. Run:

```
python3 tools/prepare_resident_ai.py --target both --ndk /path/to/android-ndk --jobs 4
godot --headless --path game --editor --quit
XDG_DATA_HOME=/tmp/synthworld-fresh-game godot --headless --path game --script res://Tests/Integration.gd
XDG_DATA_HOME=/tmp/synthworld-fresh-ai godot --headless --path game --script res://Tests/ResidentTheme.gd
godot --headless --path game --export-debug Android ../build/SynthWorld.apk
```

The preparation script pins the extension and its llama.cpp/godot-cpp submodules and verifies the exact GGUF SHA-256. It adds the `smollm` pretokenizer identifier to the existing equivalent StarCoder regex implementation, matching current upstream llama.cpp's shared regex branch. The Godot binding compilation is limited to the dependency closure used by this extension; generated headers stay intact. Model weights and compiled libraries are excluded from Git and prepared by the APK workflow.

Native inference is tested on Linux with the actual bundled quantized model, including requested pink/teal color, night lighting, rest activity, malformed-output preservation and restart persistence. Android native code is cross-compiled and packaged; installation, model extraction speed, RAM usage and inference on a physical phone still require device testing.
