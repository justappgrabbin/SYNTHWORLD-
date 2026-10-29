extends Node

signal status_changed(message: String)
signal theme_ready(settings: Dictionary)

const MODEL_NAME := "SmolLM2-360M-Instruct-Q4_K_M.gguf"
const MODEL_SOURCE := "res://models/" + MODEL_NAME
const MODEL_LOCAL := "user://" + MODEL_NAME
const SCHEMA := {
    "type": "object",
    "properties": {
        "palette": {"enum": ["pink_teal", "forest", "ocean", "sunset", "violet", "monochrome"]},
        "place": {"enum": ["grove", "home", "gathering"]},
        "time": {"enum": ["day", "evening", "night"]},
        "activity": {"enum": ["explore", "rest", "socialize", "build"]}
    },
    "required": ["palette", "place", "time", "activity"],
    "additionalProperties": false
}
var worker := Thread.new()
var llm: Node
var busy := false
var cancelled := false
var shutting_down := false

func _ready() -> void:
    if ClassDB.class_exists("GDLlama"):
        llm = ClassDB.instantiate("GDLlama")
        add_child(llm)
        llm.n_predict = 100
        llm.context_size = 1024
        llm.n_threads = 2
        llm.n_batch = 128
        llm.n_ubatch = 128
        llm.n_gpu_layer = 0
        llm.temperature = 0.0
        llm.should_output_prompt = false
        llm.should_output_special = false

func request_theme(wish: String, scene_note: String) -> void:
    if busy: return
    if wish.strip_edges().is_empty():
        status_changed.emit("Describe the theme you want first.")
        return
    if not is_instance_valid(llm):
        status_changed.emit("Local AI runtime is unavailable in this build. Your current world stays usable.")
        return
    if worker.is_started(): worker.wait_to_finish()
    busy = true
    cancelled = false
    status_changed.emit("Local AI is preparing your theme…")
    var prompt := "<|im_start|>system\nChoose SynthWorld settings and return JSON. Palette is determined by requested COLORS, not the place: pink or teal=pink_teal, green=forest, blue=ocean, orange=sunset, purple=violet, black and white=monochrome. Place: grove, home, gathering. Time: day, evening, night. Activity: explore, rest, socialize, build. Follow the latest user's request.\n<|im_end|>\n<|im_start|>user\nA pink and teal forest at night where we rest quietly.\n<|im_end|>\n<|im_start|>assistant\n{\"palette\":\"pink_teal\",\"place\":\"grove\",\"time\":\"night\",\"activity\":\"rest\"}<|im_end|>\n<|im_start|>user\nA blue ocean-themed home in the daytime for building.\n<|im_end|>\n<|im_start|>assistant\n{\"palette\":\"ocean\",\"place\":\"home\",\"time\":\"day\",\"activity\":\"build\"}<|im_end|>\n<|im_start|>user\nTheme wish: %s\nScene context: %s\n<|im_end|>\n<|im_start|>assistant\n" % [wish.left(600), scene_note.left(600)]
    var error := worker.start(_infer.bind(prompt))
    if error != OK:
        busy = false
        status_changed.emit("Could not start local AI. Please try again.")

func cancel() -> void:
    if not busy: return
    cancelled = true
    llm.stop_generate_text()
    status_changed.emit("Stopping local AI…")

func _infer(prompt: String) -> void:
    var native_path := ProjectSettings.globalize_path(MODEL_SOURCE)
    if OS.has_feature("android"):
        # APK resources are not native file paths. Copy once in bounded chunks.
        if not _prepare_model():
            call_deferred("_finished", "", "Could not prepare the bundled model. Check device storage and retry.")
            return
        native_path = ProjectSettings.globalize_path(MODEL_LOCAL)
    llm.model_path = native_path
    if cancelled:
        call_deferred("_finished", "", "Cancelled.")
        return
    var output: String = llm.generate_text_json(prompt, JSON.stringify(SCHEMA))
    call_deferred("_finished", output, "")

func _prepare_model() -> bool:
    var source := FileAccess.open(MODEL_SOURCE, FileAccess.READ)
    if not source: return false
    if FileAccess.file_exists(MODEL_LOCAL):
        var saved := FileAccess.open(MODEL_LOCAL, FileAccess.READ)
        if saved and saved.get_length() == source.get_length(): return true
    var temp_path := MODEL_LOCAL + ".partial"
    var dest := FileAccess.open(temp_path, FileAccess.WRITE)
    if not dest: return false
    while source.get_position() < source.get_length():
        if cancelled: return false
        dest.store_buffer(source.get_buffer(4 * 1024 * 1024))
        if dest.get_error() != OK: return false
    dest.close()
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(MODEL_LOCAL)) == OK

func _finished(output: String, failure: String) -> void:
    if worker.is_started(): worker.wait_to_finish()
    busy = false
    if shutting_down: return
    if cancelled:
        status_changed.emit("Cancelled. Your previous theme is unchanged.")
        return
    if not failure.is_empty():
        status_changed.emit(failure)
        return
    var json := JSON.new()
    if json.parse(output.strip_edges()) != OK or not valid_settings(json.data):
        status_changed.emit("The local AI could not finish valid theme settings. Try a shorter description; your previous theme is unchanged.")
        return
    theme_ready.emit(json.data)
    status_changed.emit("Theme set by local AI · SmolLM2 360M Q4_K_M · runs on this device")

static func valid_settings(value: Variant) -> bool:
    if not value is Dictionary: return false
    for key in SCHEMA.required:
        if not value.has(key) or not value[key] in SCHEMA.properties[key].enum: return false
    return true

func _exit_tree() -> void:
    shutting_down = true
    cancelled = true
    if busy and is_instance_valid(llm): llm.stop_generate_text()
    if worker.is_started(): worker.wait_to_finish()
