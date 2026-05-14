class_name Cell
extends Area3D

signal cell_clicked(coord: Vector2i)

@export var coord: Vector2i = Vector2i.ZERO
@export var base_color: Color = Color(0.72, 0.76, 0.68)
@export var hover_color: Color = Color(0.88, 0.9, 0.8)
@export var legal_color: Color = Color(0.38, 0.75, 0.45)
@export var selected_color: Color = Color(0.95, 0.78, 0.35)
@export var radius: float = 0.48
@export var height: float = 0.08

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _is_legal_target := false
var _is_selected := false


func _ready() -> void:
	input_ray_pickable = true
	_ensure_visuals()
	_update_color()


func setup(new_coord: Vector2i) -> void:
	coord = new_coord
	name = "Cell_%d_%d" % [coord.x, coord.y]


func set_legal_target(value: bool) -> void:
	_is_legal_target = value
	_update_color()


func set_selected(value: bool) -> void:
	_is_selected = value
	_update_color()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			cell_clicked.emit(coord)


func _mouse_enter() -> void:
	if not _is_legal_target and not _is_selected:
		_set_color(hover_color)


func _mouse_exit() -> void:
	_update_color()


func _ensure_visuals() -> void:
	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	_mesh_instance.mesh = mesh

	_material = StandardMaterial3D.new()
	_material.roughness = 0.75
	_mesh_instance.material_override = _material

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height + 0.04
	collision_shape.shape = shape


func _update_color() -> void:
	if _is_selected:
		_set_color(selected_color)
	elif _is_legal_target:
		_set_color(legal_color)
	else:
		_set_color(base_color)


func _set_color(color: Color) -> void:
	if _material != null:
		_material.albedo_color = color
