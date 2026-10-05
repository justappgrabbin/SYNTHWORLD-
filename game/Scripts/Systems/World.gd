extends Node3D
const AGENT_SCENE:=preload("res://Scenes/Agents/Agent.tscn")
const TREE_SCENE:=preload("res://Scenes/Props/Tree.tscn")
const DUMMY_DAMAGE_INTERVAL:=3.0
@onready var props_root:=$Props
var _timer:=0.0
var world_state:={"mood.harmony":0.7}
func _ready()->void:
    var agent:=AGENT_SCENE.instantiate();agent.name="Generator";add_child(agent);agent.global_position=Vector3(-3,0,0)
    place_tree(Vector3(5,0,5));call_deferred("_execute_seed_sentences")
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
