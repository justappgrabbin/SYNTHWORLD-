extends Node3D

var limbs: Array[Node3D] = []
var phase := 0.0
var clothing_color := Color.WHITE
var clothing_materials: Array[StandardMaterial3D] = []
var actor: CharacterBody3D

func _ready() -> void:
    actor = get_parent() as CharacterBody3D
    var skin := Color(0.48, 0.27, 0.18) if actor.name == "Cynthia" else Color(0.72, 0.48, 0.32)
    var outfit := Color(0.68, 0.17, 0.48) if actor.name == "Cynthia" else Color(0.08, 0.55, 0.55)
    clothing_color = outfit
    _part(self, Vector3(0, 1.05, 0), Vector3(0.48, 0.57, 0.26), outfit)
    _part(self, Vector3(0, 0.73, 0), Vector3(0.43, 0.2, 0.25), outfit.darkened(0.25))
    _part(self, Vector3(0, 1.43, 0), Vector3(0.14, 0.17, 0.14), skin)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.48
    head.mesh = sphere
    head.position.y = 1.69
    head.material_override = _material(skin)
    add_child(head)
    _part(self, Vector3(0, 1.89, 0.03), Vector3(0.42, 0.13, 0.35), Color(0.09, 0.045, 0.035))
    for side in [-1.0, 1.0]:
        _part(self, Vector3(side * 0.083, 1.73, -0.202), Vector3(0.045, 0.04, 0.026), Color(0.04, 0.025, 0.025))
        var arm := Node3D.new()
        arm.position = Vector3(side * 0.32, 1.28, 0)
        add_child(arm)
        _part(arm, Vector3(0, -0.2, 0), Vector3(0.14, 0.4, 0.16), outfit)
        _part(arm, Vector3(0, -0.48, 0), Vector3(0.12, 0.24, 0.13), skin)
        limbs.append(arm)
        var leg := Node3D.new()
        leg.position = Vector3(side * 0.13, 0.68, 0)
        add_child(leg)
        _part(leg, Vector3(0, -0.29, 0), Vector3(0.18, 0.58, 0.2), Color(0.12, 0.13, 0.22))
        _part(leg, Vector3(0, -0.61, -0.05), Vector3(0.2, 0.13, 0.31), Color(0.06, 0.06, 0.09))
        limbs.append(leg)
    var label := Label3D.new()
    label.text = str(actor.name)
    label.position.y = 2.2
    label.font_size = 38
    label.pixel_size = 0.006
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

func _process(delta: float) -> void:
    var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
    phase += delta * 7.0
    if speed > 0.1:
        rotation.y = lerp_angle(rotation.y, atan2(-actor.velocity.x, -actor.velocity.z), delta * 8.0)
    for i in limbs.size():
        limbs[i].rotation.x = sin(phase + (PI if i < 2 else 0.0)) * minf(speed * 0.2, 0.5)

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    return mat

func _part(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = pos
    var material := _material(color)
    part.material_override = material
    if color == clothing_color or color == clothing_color.darkened(0.25):
        material.set_meta("shade", 0.25 if color != clothing_color else 0.0)
        clothing_materials.append(material)
    parent.add_child(part)

func reskin(color: Color) -> void:
    for material in clothing_materials:
        var target := color.darkened(float(material.get_meta("shade", 0.0)))
        create_tween().tween_property(material, "albedo_color", target, 0.7)
