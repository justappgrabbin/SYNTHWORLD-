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
