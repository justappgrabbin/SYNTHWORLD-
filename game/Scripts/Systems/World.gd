extends Node3D
const AGENT_SCENE:=preload("res://Scenes/Agents/Agent.tscn")
const TREE_SCENE:=preload("res://Scenes/Props/Tree.tscn")
const DUMMY_DAMAGE_INTERVAL:=3.0
@onready var props_root:=$Props
var _timer:=0.0
var world_state:={"mood.harmony":0.7}
func _ready()->void:
    $Camera3D.position = Vector3(9, 13, 17)
    $Camera3D.look_at(Vector3(0, 0.7, 0))
    $Camera3D.projection = Camera3D.PROJECTION_ORTHOGONAL
    $Camera3D.size = 18.0
    $Sun.rotation_degrees = Vector3(-55, -25, 0)
    for i in 10:
        var angle := i * TAU / 10.0
        place_tree(Vector3(cos(angle) * 9, 0, sin(angle) * 9))
    var agent:=AGENT_SCENE.instantiate();agent.name="Generator";add_child(agent);agent.global_position=Vector3(-3,0,0)
    place_tree(Vector3(5,0,5));call_deferred("_execute_seed_sentences")
    var director := Node.new()
    director.name = "SceneDirector"
    director.set_script(preload("res://Scripts/Systems/SceneDirector.gd"))
    call_deferred("add_child", director)
func _process(delta:float)->void:
    _timer+=delta
    if _timer>=DUMMY_DAMAGE_INTERVAL:
        _timer=0.0;var damaged=_get_random_prop()
        if damaged and damaged.has_method("damage"):damaged.damage(5)
func _execute_seed_sentences()->void:SentenceService.execute_all(self)
func place_tree(pos:Vector3)->Node3D:
    var tree:=TREE_SCENE.instantiate();props_root.add_child(tree);tree.global_position=pos;return tree
func repair_props_near(pos:Vector3,radius:float)->int:
    var count:=0
    for prop in props_root.get_children():
        if prop.has_method("is_damaged") and prop.is_damaged() and prop.global_position.distance_to(pos)<=radius:prop.repair(10);count+=1
    return count
func has_damaged_props()->bool:
    for prop in props_root.get_children():
        if prop.has_method("is_damaged") and prop.is_damaged():return true
    return false
func set_world_state(key:String,value)->void:world_state[key]=value
func _get_random_prop():
    var c:=props_root.get_child_count()
    if c==0:return null
    return props_root.get_child(randi()%c)

func configure_place(place: int) -> void:
    var old = get_node_or_null("Furnishings")
    if old:
        remove_child(old)
        old.queue_free()
    var root := Node3D.new()
    root.name = "Furnishings"
    add_child(root)
    if place == 0: return
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.31, 0.18, 0.29)
    var items := [[Vector3(0, 0.5, -2), Vector3(3, 1, 0.8)], [Vector3(0, 0.4, 1), Vector3(2, 0.8, 1.2)]]
    if place == 2:
        items = [[Vector3(-3, 0.4, -2), Vector3(2, 0.8, 0.8)], [Vector3(3, 0.4, -2), Vector3(2, 0.8, 0.8)], [Vector3(0, 0.5, 0), Vector3(1, 1, 1)]]
    for item in items:
        var body := StaticBody3D.new()
        body.position = item[0]
        root.add_child(body)
        var mesh := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = item[1]
        mesh.mesh = box
        mesh.material_override = mat
        body.add_child(mesh)
        var collider := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = item[1]
        collider.shape = shape
        body.add_child(collider)
