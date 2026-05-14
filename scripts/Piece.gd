class_name Piece
extends Area3D

signal piece_clicked(piece)

@export var player_id: int = 1
@export var coord: Vector2i = Vector2i.ZERO
@export var player_one_color: Color = Color(0.9, 0.16, 0.18)
@export var player_two_color: Color = Color(0.1, 0.35, 0.9)
@export var selected_color: Color = Color(1.0, 0.88, 0.28)
@export var radius: float = 0.34

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _is_selected := false


func _ready() -> void:
	input_ray_pickable = true
	_ensure_visuals()
	_update_color()


func setup(new_player_id: int, new_coord: Vector2i, world_position: Vector3) -> void:
	player_id = new_player_id
	coord = new_coord
	position = world_position + Vector3.UP * radius
	name = "Piece_P%d_%d_%d" % [player_id, coord.x, coord.y]
	_update_color()


func set_coord(new_coord: Vector2i, world_position: Vector3) -> void:
	coord = new_coord
	position = world_position + Vector3.UP * radius
	name = "Piece_P%d_%d_%d" % [player_id, coord.x, coord.y]


func set_selected(value: bool) -> void:
	_is_selected = value
	_update_color()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			piece_clicked.emit(self)


func _ensure_visuals() -> void:
	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	_mesh_instance.mesh = mesh

	_material = StandardMaterial3D.new()
	_material.roughness = 0.45
	_material.metallic = 0.05
	_mesh_instance.material_override = _material

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	var shape := SphereShape3D.new()
	shape.radius = radius
	collision_shape.shape = shape


func _update_color() -> void:
	if _material == null:
		return

	if _is_selected:
		_material.albedo_color = selected_color
	elif player_id == 1:
		_material.albedo_color = player_one_color
	else:
		_material.albedo_color = player_two_color
