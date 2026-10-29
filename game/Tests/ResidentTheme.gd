extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world = load("res://Scenes/World.tscn").instantiate()
    root.add_child(world)
    current_scene = world
    await process_frame
    await process_frame
    var director = world.get_node("SceneDirector")
    var brain = director.resident
    _check(brain.llm != null, "Real native local model runtime registered")
    _check(not brain.valid_settings({"palette":"arbitrary"}))
    _check(not brain.valid_settings({"palette":"forest", "place":"castle", "time":"day", "activity":"rest"}))
    director.ai_wish.text = "A pink and teal forest at night where we rest quietly."
    brain.request_theme(director.ai_wish.text, "")
    _check(brain.busy)
    var deadline := Time.get_ticks_msec() + 180000
    while brain.busy and Time.get_ticks_msec() < deadline:
        await process_frame
    _check(not brain.busy, "Inference finished within deadline")
    _check(brain.valid_settings(director.state.theme), "Real quantized model returned all four supported settings")
    _check(director.state.theme.palette == "pink_teal", "Model followed requested colors")
    _check(director.state.theme.time == "night", "Model followed requested lighting")
    _check(director.state.theme.activity == "rest", "Model followed requested situation")
    _check(world.world_state["theme.palette"] == "pink_teal")
    _check(world.get_node("Cynthia").scene_priority == "Rest")
    var original: Dictionary = director.state.theme.duplicate(true)
    brain._finished("not JSON", "")
    _check(director.state.theme == original, "Malformed output preserves existing theme")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(director.SAVE_PATH))
    _check(saved.theme == original)
    print("PASS: real local quantized-model inference, requested palette/night/rest, world application, malformed-output guard and saved theme")
    world.queue_free()
    await process_frame
    var restored = load("res://Scenes/World.tscn").instantiate()
    root.add_child(restored)
    current_scene = restored
    await process_frame
    await process_frame
    _check(restored.get_node("SceneDirector").state.theme == original)
    _check(restored.world_state["theme.palette"] == "pink_teal")
    _check(restored.get_node("Cynthia").scene_priority == "Rest")
    print("PASS: AI-selected theme and agent priorities restored after restart")
    quit()

func _check(condition: bool, message: String = "Resident AI regression") -> void:
    if not condition:
        push_error(message)
        quit(1)
