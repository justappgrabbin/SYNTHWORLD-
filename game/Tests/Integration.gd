extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene = load("res://Scenes/World.tscn").instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var director = scene.get_node("SceneDirector")
    assert(director != null, "Scene controls mounted")
    director.notes.text = "I need quiet time with my friend."
    director.time_choice.selected = 2
    director.place.selected = 1
    director._apply_scene(true)
    assert(scene.world_state["scene.priority"] == "Rest")
    assert(scene.get_node("Cynthia").scene_note == director.notes.text)
    assert(scene.get_node("Generator").scene_priority == "Rest")
    assert(scene.has_node("Furnishings"))
    for i in 39:
        director.reflection.text = "My own discovery %d" % i
        director._collect()
        if (i + 1) % 13 == 0: director._synthesize()
    assert(director.state.gnomes.size() == 3)
    assert(director.state.gnomes[0].fragments[0].fragment == "My own discovery 0")
    director._awaken()
    assert(director.state.friends.size() == 1)
    assert(scene.has_node("Field Friend 1"))
    director._awaken()
    assert(director.state.friends.size() == 1, "Cannot spend same gnomes twice")
    var saved = JSON.parse_string(FileAccess.get_file_as_string(director.SAVE_PATH))
    assert(saved.note == director.notes.text)
    assert(saved.friends.size() == 1)
    scene.queue_free()
    await process_frame
    var restored = load("res://Scenes/World.tscn").instantiate()
    root.add_child(restored)
    current_scene = restored
    await process_frame
    await process_frame
    assert(restored.has_node("Field Friend 1"), "Friend restored after restart")
    assert(restored.get_node("SceneDirector").state.gnomes.size() == 3)
    print("PASS: notes, priorities, lighting/place, 39 reflections, synthesis, friend, double-spend guard and restart persistence")
    quit(0)
