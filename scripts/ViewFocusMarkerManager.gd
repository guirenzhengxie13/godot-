class_name ViewFocusMarkerManager
extends Node3D

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var focus_camera_path: NodePath = ^"../Camera3D"
@export var marker_radius_offset := 1.05
@export var decor_inner_corner_offset := 0.24
@export var marker_height := 0.06

@onready var board_manager = get_node(board_manager_path)
@onready var focus_camera = get_node_or_null(focus_camera_path)

const VIEW_FOCUS_MARKER_SCRIPT := preload("res://scripts/ViewFocusMarker.gd")
const INNER_CORNER_PROP_ROOT := "res://assets/environment/kenney_nature"

var _markers_by_player := {
	1: [],
	2: [],
}
var _decor_materials: Dictionary = {}


func _ready() -> void:
	if board_manager.has_signal("player_material_changed"):
		board_manager.player_material_changed.connect(_on_player_material_changed)
	call_deferred("_build_markers")


func _build_markers() -> void:
	var center: Vector3 = board_manager.get_board_center()
	var marker_radius := _get_board_radius(center) + marker_radius_offset
	var decor_radius: float = (board_manager.center_radius + 1) * board_manager.cell_spacing + decor_inner_corner_offset
	var decor_root := Node3D.new()
	decor_root.name = "InnerCornerDecor"
	add_child(decor_root)

	for index in range(6):
		var marker_angle := -PI * 0.5 + TAU * float(index) / 6.0
		var marker_direction := Vector3(cos(marker_angle), 0.0, sin(marker_angle))
		var marker: Area3D = VIEW_FOCUS_MARKER_SCRIPT.new()
		marker.name = "ViewFocus_%d" % index
		marker.view_index = index
		marker.position = center + marker_direction * marker_radius + Vector3.UP * marker_height
		marker.rotation_degrees = Vector3(0.0, rad_to_deg(-marker_angle) + 90.0, 0.0)
		var player_id := _get_marker_player(index)
		if marker.has_method("set_material_profile"):
			marker.set_material_profile(board_manager.get_player_material_profile(player_id), _get_player_fallback_color(player_id))
		marker.marker_clicked.connect(_on_marker_clicked)
		add_child(marker)
		_markers_by_player[player_id].append(marker)
		var decor_angle := TAU * float(index) / 6.0
		var decor_direction := Vector3(cos(decor_angle), 0.0, sin(decor_angle))
		_build_inner_corner_decor(decor_root, center, decor_direction, decor_radius, index)


func _build_inner_corner_decor(parent: Node3D, center: Vector3, direction: Vector3, radius: float, index: int) -> void:
	var tangent := Vector3(-direction.z, 0.0, direction.x)
	var corner_center := center + direction * radius
	_spawn_inner_corner_prop(parent, "rock_smallA.obj", corner_center - tangent * 0.72 + direction * 0.12, float(index) * 23.0, 0.78, Color(0.48, 0.5, 0.47), "stone")
	_spawn_inner_corner_prop(parent, "plant_bush.obj", corner_center + tangent * 0.72 + direction * 0.08, float(index) * -19.0, 0.92, Color(0.26, 0.54, 0.25), "leaf")
	_spawn_inner_corner_prop(parent, "grass_large.obj", corner_center - direction * 0.34 + tangent * 0.12, float(index) * 31.0, 0.74, Color(0.22, 0.7, 0.2), "grass")


func _spawn_inner_corner_prop(parent: Node3D, asset_name: String, world_position: Vector3, rotation_y: float, scale_value: float, color: Color, material_kind: String) -> void:
	var resource = load("%s/%s" % [INNER_CORNER_PROP_ROOT, asset_name])
	if not resource is Mesh:
		return
	var prop := MeshInstance3D.new()
	prop.name = asset_name.get_basename()
	prop.mesh = resource
	prop.position = world_position
	prop.rotation_degrees.y = rotation_y
	prop.scale = Vector3.ONE * scale_value
	prop.material_override = _get_decor_material(material_kind, color)
	parent.add_child(prop)


func _get_decor_material(material_kind: String, color: Color) -> StandardMaterial3D:
	if _decor_materials.has(material_kind):
		return _decor_materials[material_kind]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9 if material_kind in ["leaf", "grass"] else 0.78
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_decor_materials[material_kind] = material
	return material


func _get_board_radius(center: Vector3) -> float:
	var radius := 0.0
	for cell in board_manager.cells.values():
		if cell == null:
			continue
		var flat := Vector2(cell.global_position.x - center.x, cell.global_position.z - center.z)
		radius = maxf(radius, flat.length())
	return radius


func _on_marker_clicked(view_index: int) -> void:
	if focus_camera != null and focus_camera.has_method("focus_board_side"):
		focus_camera.focus_board_side(view_index)


func _on_player_material_changed(player_id: int, profile: Dictionary) -> void:
	for marker in _markers_by_player.get(player_id, []):
		if marker != null and marker.has_method("set_material_profile"):
			marker.set_material_profile(profile, _get_player_fallback_color(player_id))


func _get_marker_player(view_index: int) -> int:
	return 1 if view_index % 2 == 0 else 2


func _get_player_fallback_color(player_id: int) -> Color:
	if player_id == 1:
		return Color(0.9, 0.16, 0.18)
	return Color(0.1, 0.35, 0.9)
