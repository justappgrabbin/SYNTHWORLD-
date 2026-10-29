extends Node

const SAVE_PATH := "user://synthworld-save.json"
const CATEGORIES := ["identity", "purpose", "connection", "strength", "dream"]
var state: Dictionary = {"note": "", "place": 0, "time": 0, "situation": 0, "fragments": [], "gnomes": [], "friends": [], "journal": [], "theme": {}, "theme_wish": ""}
var world: Node3D
var panel: PanelContainer
var notes: TextEdit
var reflection: TextEdit
var place: OptionButton
var time_choice: OptionButton
var situation: OptionButton
var category: OptionButton
var status: Label
var inventory: Label
var journal: RichTextLabel
var agent_status: Label
var resident: Node
var ai_wish: TextEdit
var ai_status: Label
var ai_button: Button
var root_ui: Control
var save_error := ""
var tick := 0.0

func _ready() -> void:
    world = get_parent()
    if FileAccess.file_exists(SAVE_PATH):
        var loaded = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
        if loaded is Dictionary:
            for key in state:
                if not loaded.has(key): continue
                if typeof(state[key]) == TYPE_INT and (loaded[key] is int or loaded[key] is float):
                    state[key] = int(loaded[key])
                elif typeof(loaded[key]) == typeof(state[key]):
                    state[key] = loaded[key]
    resident = Node.new()
    resident.set_script(preload("res://Scripts/Systems/ResidentThemeAI.gd"))
    add_child(resident)
    _ui()
    resident.status_changed.connect(_ai_status_changed)
    resident.theme_ready.connect(_theme_from_ai)
    _apply_scene(false, false)
    if preload("res://Scripts/Systems/ResidentThemeAI.gd").valid_settings(state.theme):
        _apply_palette(state.theme.palette)
    for friend in state.friends:
        _spawn_friend(str(friend.name))
    _refresh()

func _process(delta: float) -> void:
    tick += delta
    if tick > 1.0:
        tick = 0.0
        var lines: Array[String] = []
        for actor in world.get_children():
            if actor is CharacterBody3D:
                lines.append("%s · %s" % [actor.name, actor.get("current_action") if actor.get("current_action") != null else "Building / caring for the world"])
        agent_status.text = "\n".join(lines)

func _ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var root := Control.new()
    root_ui = root
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(root)
    var top := VBoxContainer.new()
    top.position = Vector2(16, 16)
    root.add_child(top)
    var title := Label.new()
    title.text = "SYNTHWORLD  /  Living with your agents"
    title.add_theme_font_size_override("font_size", 23)
    top.add_child(title)
    agent_status = Label.new()
    top.add_child(agent_status)
    var open := Button.new()
    open.text = "Scene notes + Self-discovery"
    open.custom_minimum_size.y = 54
    open.pressed.connect(func(): panel.visible = not panel.visible)
    top.add_child(open)
    var camera_bar := HBoxContainer.new()
    top.add_child(camera_bar)
    for direction in [-1, 1]:
        var button := Button.new()
        button.text = "◀ View" if direction == -1 else "View ▶"
        button.custom_minimum_size = Vector2(120, 48)
        button.pressed.connect(func(): _rotate_camera(direction))
        camera_bar.add_child(button)
    panel = PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 12
    panel.offset_top = 175
    panel.offset_right = -12
    panel.offset_bottom = -16
    root.add_child(panel)
    var outer := VBoxContainer.new()
    panel.add_child(outer)
    var close := Button.new()
    close.text = "Return to the world"
    close.custom_minimum_size.y = 48
    close.pressed.connect(func(): panel.hide())
    outer.add_child(close)
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(tabs)
    var ai_box := _tab(tabs, "Resident AI")
    _label(ai_box, "Cynthia · local theme designer")
    _label(ai_box, "Tell Cynthia how you want this world to look and feel. She can choose colors, clothing, place, lighting and what everyone does. Works offline.")
    ai_wish = TextEdit.new()
    ai_wish.custom_minimum_size.y = 140
    ai_wish.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    ai_wish.placeholder_text = "A pink and teal magical grove at night where we can rest together…"
    ai_wish.text = state.theme_wish
    ai_box.add_child(ai_wish)
    ai_button = Button.new()
    ai_button.text = "Let Cynthia set up the theme"
    ai_button.custom_minimum_size.y = 56
    ai_button.pressed.connect(func():
        resident.request_theme(ai_wish.text, notes.text)
        ai_button.disabled = resident.busy)
    ai_box.add_child(ai_button)
    _button(ai_box, "Cancel theme generation", func(): resident.cancel())
    ai_status = _label(ai_box, "Local AI ready. First use prepares its model; the game stays usable while it works.")
    _label(ai_box, "Available palettes: pink + teal, forest, ocean, sunset, violet and monochrome. You can also change place/time/activity directly in Scene notes.")
    var scene_box := _tab(tabs, "Scene notes")
    _label(scene_box, "Tell your agent what is happening. Your exact words stay in its scene context.")
    notes = TextEdit.new()
    notes.custom_minimum_size.y = 125
    notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    notes.placeholder_text = "Who is here? What happened? What should Cynthia help with?"
    notes.text = state.note
    scene_box.add_child(notes)
    place = _choice(scene_box, "Place", ["Grove", "Home", "Gathering"])
    time_choice = _choice(scene_box, "Time", ["Day", "Evening", "Night"])
    situation = _choice(scene_box, "Situation", ["Explore together", "Quiet / rest", "Connect / socialize", "Build / repair"])
    place.selected = clampi(int(state.place), 0, 2)
    time_choice.selected = clampi(int(state.time), 0, 2)
    situation.selected = clampi(int(state.situation), 0, 3)
    _label(scene_box, "Scene choices set place, light and agent priorities. Notes also recognize: rest, quiet, socialize, connect, explore, repair, build. Other words remain context; they are not silently turned into commands.")
    _button(scene_box, "Give scene to agents", func(): _apply_scene(true))
    status = _label(scene_box, "")
    var discovery := _tab(tabs, "Discover")
    _label(discovery, "Collect your own fragments of self-knowledge, as datababies. Thirteen fragments form a Gene Gnome; three Gene Gnomes awaken a human-form Field Friend.")
    category = _choice(discovery, "Explore", ["Identity · What feels like me?", "Purpose · What matters to me?", "Connection · Where do I feel understood?", "Strength · What helped me through?", "Dream · What do I want to create?"])
    reflection = TextEdit.new()
    reflection.custom_minimum_size.y = 120
    reflection.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    reflection.placeholder_text = "Write one thing you discovered about yourself…"
    discovery.add_child(reflection)
    _button(discovery, "Keep this datababy", _collect)
    _button(discovery, "Synthesize 13 fragments", _synthesize)
    _button(discovery, "Awaken Field Friend · 3 Gene Gnomes", _awaken)
    inventory = _label(discovery, "")
    var memory := _tab(tabs, "Memory")
    _label(memory, "Your scene notes, discoveries and agent experiences are saved on this device.")
    journal = RichTextLabel.new()
    journal.custom_minimum_size.y = 420
    journal.fit_content = true
    journal.bbcode_enabled = false
    memory.add_child(journal)
    panel.hide()

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = title
    tabs.add_child(scroll)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 12)
    scroll.add_child(box)
    return box

func _label(box: Node, value: String) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(label)
    return label

func _button(box: Node, title: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = title
    button.custom_minimum_size.y = 52
    button.pressed.connect(callback)
    box.add_child(button)

func _choice(box: Node, title: String, options: Array) -> OptionButton:
    _label(box, title)
    var choice := OptionButton.new()
    choice.custom_minimum_size.y = 48
    for option in options:
        choice.add_item(option)
    box.add_child(choice)
    return choice

func _apply_scene(record: bool, interpret_note: bool = true) -> void:
    state.note = notes.text.strip_edges().left(8000)
    state.place = place.selected
    state.time = time_choice.selected
    state.situation = situation.selected
    var priority: String = ["Wander", "Rest", "Socialize", "Build"][situation.selected]
    var lower: String = state.note.to_lower()
    var matched: Array[String] = []
    # Match full words. Explicit situation wins if several intentions are present.
    var words := RegEx.new()
    words.compile("\\b(rest|quiet|socialize|connect|explore|repair|build)\\b")
    var intents: Array[String] = []
    for result in words.search_all(lower):
        var word := result.get_string()
        matched.append(word)
        var intent: String = {"rest":"Rest", "quiet":"Rest", "socialize":"Socialize", "connect":"Socialize", "explore":"Wander", "repair":"Build", "build":"Build"}[word]
        if not intents.has(intent): intents.append(intent)
    if interpret_note and intents.size() == 1:
        priority = intents[0]
    world.set_world_state("scene.note", state.note)
    world.set_world_state("scene.priority", priority)
    world.set_world_state("scene.place", place.get_item_text(place.selected))
    world.set_world_state("scene.time", time_choice.get_item_text(time_choice.selected))
    world.get_node("Sun").light_energy = [1.1, 0.55, 0.16][time_choice.selected]
    world.get_node("Sun").light_color = [Color.WHITE, Color(1, 0.65, 0.48), Color(0.45, 0.6, 1)][time_choice.selected]
    world.configure_place(place.selected)
    for actor in world.get_children():
        if actor.has_method("receive_scene"):
            actor.receive_scene(state.note, priority, record)
    status.text = "Active: %s · %s · %s\n%s" % [place.get_item_text(place.selected), time_choice.get_item_text(time_choice.selected), priority, "Multiple note intentions: using the situation choice." if intents.size() > 1 else "Note cues: " + (", ".join(matched) if not matched.is_empty() else "context only")]
    if record:
        _record("Scene: %s / %s / %s\n%s" % [place.get_item_text(place.selected), time_choice.get_item_text(time_choice.selected), priority, state.note])
        _save()
        _refresh()

func _collect() -> void:
    var value := reflection.text.strip_edges().left(2000)
    if value.is_empty():
        inventory.text = "Write a discovery first so the fragment contains your own words."
        return
    state.fragments.append({"category": CATEGORIES[category.selected], "fragment": value})
    _record("Datababy · %s: %s" % [CATEGORIES[category.selected], value])
    reflection.text = ""
    _save()
    _refresh()

func _synthesize() -> void:
    if state.fragments.size() < 13:
        inventory.text = "Keep %d more fragments to synthesize a Gene Gnome." % (13 - state.fragments.size())
        return
    var pieces: Array = []
    for i in 13:
        pieces.append(state.fragments.pop_front())
    state.gnomes.append({"fragments": pieces, "used": false})
    _record("Gene Gnome formed from 13 of your discoveries. All original words preserved.")
    _save()
    _refresh()

func _awaken() -> void:
    var available: Array = []
    for gnome in state.gnomes:
        if not gnome.used: available.append(gnome)
    if available.size() < 3:
        inventory.text = "Synthesize %d more Gene Gnomes to awaken a Field Friend." % (3 - available.size())
        return
    for i in 3: available[i].used = true
    var friend_name := "Field Friend %d" % (state.friends.size() + 1)
    state.friends.append({"name": friend_name, "gnomes": available.slice(0, 3)})
    _spawn_friend(friend_name)
    _record("%s awakened from your discoveries and joined this world." % friend_name)
    _save()
    _refresh()

func _spawn_friend(friend_name: String) -> void:
    var actor := preload("res://Scenes/Agents/Agent.tscn").instantiate()
    actor.name = friend_name
    world.add_child(actor)
    actor.position = Vector3(2 + state.friends.size(), 0, 2)
    actor.receive_scene(state.note, world.world_state.get("scene.priority", "Wander"))
    if state.theme.has("palette"):
        _reskin_actor(actor, state.theme.palette)

func _record(value: String) -> void:
    state.journal.append({"at": Time.get_datetime_string_from_system(), "text": value})

func _save() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    save_error = ""
    if file:
        file.store_string(JSON.stringify(state))
    else:
        save_error = "Could not save on this device. Your current session is still open."
        status.text = save_error

func _refresh() -> void:
    inventory.text = "%d datababies · %d Gene Gnomes · %d Field Friends\n%s" % [state.fragments.size(), state.gnomes.size(), state.friends.size(), save_error]
    var entries: Array[String] = []
    for item in state.journal:
        entries.append("%s\n%s" % [item.at, item.text])
    journal.text = "\n\n".join(entries)

func _rotate_camera(direction: int) -> void:
    var camera: Camera3D = world.get_node("Camera3D")
    camera.position = camera.position.rotated(Vector3.UP, direction * PI / 6)
    camera.look_at(Vector3(0, 0.8, 0))

func _ai_status_changed(message: String) -> void:
    ai_status.text = message
    ai_button.disabled = resident.busy

func _theme_from_ai(settings: Dictionary) -> void:
    state.theme = settings.duplicate(true)
    state.theme_wish = ai_wish.text.strip_edges().left(600)
    place.selected = ["grove", "home", "gathering"].find(settings.place)
    time_choice.selected = ["day", "evening", "night"].find(settings.time)
    situation.selected = ["explore", "rest", "socialize", "build"].find(settings.activity)
    _apply_scene(true, false)
    _apply_palette(settings.palette)
    _record("Resident AI theme: %s\nRequested: %s" % [JSON.stringify(settings), state.theme_wish])
    _save()
    _refresh()

func _palette(palette: String) -> Array:
    return {
        "pink_teal": [Color("203c42"), Color("f175bd"), Color("31d4bf")],
        "forest": [Color("183b2c"), Color("dfb672"), Color("78c886")],
        "ocean": [Color("123653"), Color("71c9ed"), Color("54e0ce")],
        "sunset": [Color("483342"), Color("f99b68"), Color("dc6eab")],
        "violet": [Color("29223f"), Color("b499ed"), Color("ef9acb")],
        "monochrome": [Color("25272b"), Color("eeeeee"), Color("9fa6b2")]
    }.get(palette, [Color("203c42"), Color("f175bd"), Color("31d4bf")])

func _apply_palette(palette: String) -> void:
    var colors := _palette(palette)
    var material: StandardMaterial3D = world.get_node("Ground").material_override
    world.create_tween().tween_property(material, "albedo_color", colors[0], 0.7)
    var ui_theme := Theme.new()
    ui_theme.default_font_size = 20
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = colors[0].darkened(0.45)
    panel_style.content_margin_left = 14
    panel_style.content_margin_right = 14
    panel_style.content_margin_top = 12
    panel_style.content_margin_bottom = 12
    ui_theme.set_stylebox("panel", "PanelContainer", panel_style)
    var button_style := StyleBoxFlat.new()
    button_style.bg_color = colors[0].lightened(0.12)
    button_style.corner_radius_top_left = 8
    button_style.corner_radius_top_right = 8
    button_style.corner_radius_bottom_left = 8
    button_style.corner_radius_bottom_right = 8
    for type_name in ["Button", "OptionButton"]:
        ui_theme.set_stylebox("normal", type_name, button_style)
        var active := button_style.duplicate()
        active.bg_color = colors[2].darkened(0.5)
        ui_theme.set_stylebox("hover", type_name, active)
        ui_theme.set_stylebox("pressed", type_name, active)
    root_ui.theme = ui_theme
    for actor in world.get_children():
        _reskin_actor(actor, palette)
    world.set_world_state("theme.palette", palette)

func _reskin_actor(actor: Node, palette: String) -> void:
    var body := actor.get_node_or_null("HumanBody")
    if body and body.has_method("reskin"):
        var colors := _palette(palette)
        body.reskin(colors[1] if actor.name == "Cynthia" else colors[2])
