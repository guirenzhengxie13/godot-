class_name Cell
extends Area3D

signal cell_clicked(coord: Vector2i)

@export var coord: Vector2i = Vector2i.ZERO
@export var base_color: Color = Color(0.72, 0.76, 0.68)
@export var hover_color: Color = Color(0.88, 0.9, 0.8)
@export var legal_color: Color = Color(0.38, 0.75, 0.45)
@export var selected_color: Color = Color(0.95, 0.78, 0.35)
@export var aura_color: Color = Color(0.35, 0.72, 0.95)
@export var reachable_color: Color = Color(0.24, 0.92, 0.42)
@export var frozen_color: Color = Color(0.12, 0.56, 1.0)
@export var radius: float = 0.64
@export var height: float = 0.1

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _side_material: StandardMaterial3D
var _is_legal_target := false
var _is_selected := false
var _is_aura_target := false
var _is_analysis_reachable := false
var _is_analysis_frozen := false
var _material_profile: Dictionary = {}
var _board_texture_origin := Vector2.ZERO
var _board_texture_span := 1.0


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


func set_aura_target(value: bool) -> void:
	_is_aura_target = value
	_update_color()


func set_analysis_reachable(value: bool) -> void:
	_is_analysis_reachable = value
	_update_color()


func set_analysis_frozen(value: bool) -> void:
	_is_analysis_frozen = value
	_update_color()


func set_material_profile(profile: Dictionary) -> void:
	_material_profile = profile.duplicate(true)
	_apply_material_profile()
	_update_color()


func set_board_texture_mapping(texture_origin: Vector2, texture_span: float) -> void:
	_board_texture_origin = texture_origin
	_board_texture_span = maxf(texture_span, 0.001)
	_rebuild_cell_mesh()
	_apply_board_texture_mapping()


func get_board_uv_at_local(local_position: Vector3) -> Vector2:
	var flat_position := Vector2(position.x + local_position.x, position.z + local_position.z)
	return (flat_position - _board_texture_origin) / _board_texture_span


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			cell_clicked.emit(coord)


func _mouse_enter() -> void:
	if not _is_legal_target and not _is_selected:
		_set_color(hover_color, true)


func _mouse_exit() -> void:
	_update_color()


func _ensure_visuals() -> void:
	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	_material = StandardMaterial3D.new()
	_material.roughness = 0.48
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_material.clearcoat_enabled = true
	_material.clearcoat_roughness = 0.34
	_apply_texture_filter(_material)
	_side_material = StandardMaterial3D.new()
	_side_material.roughness = 0.9
	_side_material.metallic = 0.0
	_side_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_side_material.clearcoat_enabled = false
	_apply_texture_filter(_side_material)
	_rebuild_cell_mesh()
	_apply_board_texture_mapping()
	_apply_material_profile()

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height + 0.04
	collision_shape.shape = shape


func _apply_board_texture_mapping() -> void:
	if _material == null:
		return
	_material.uv1_scale = Vector3.ONE
	_material.uv1_offset = Vector3.ZERO


func _apply_texture_filter(material: BaseMaterial3D) -> void:
	if material == null:
		return
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _rebuild_cell_mesh() -> void:
	if _mesh_instance == null or _material == null or _side_material == null:
		return

	var mesh := ArrayMesh.new()
	var top_surface := SurfaceTool.new()
	top_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	top_surface.set_material(_material)
	var top_center := Vector3(0.0, height * 0.5, 0.0)
	for index in range(6):
		_add_top_vertex(top_surface, top_center)
		_add_top_vertex(top_surface, _get_hex_corner((index + 1) % 6, height * 0.5))
		_add_top_vertex(top_surface, _get_hex_corner(index, height * 0.5))
	top_surface.generate_tangents()
	top_surface.commit(mesh)

	var side_surface := SurfaceTool.new()
	side_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	side_surface.set_material(_side_material)
	for index in range(6):
		var top_a := _get_hex_corner(index, height * 0.5)
		var top_b := _get_hex_corner((index + 1) % 6, height * 0.5)
		var bottom_a := _get_hex_corner(index, -height * 0.5)
		var bottom_b := _get_hex_corner((index + 1) % 6, -height * 0.5)
		var side_normal := Vector3(top_a.x, 0.0, top_a.z).normalized()
		_add_side_vertex(side_surface, top_a, side_normal, Vector2(0.0, 0.0))
		_add_side_vertex(side_surface, bottom_b, side_normal, Vector2(1.0, 1.0))
		_add_side_vertex(side_surface, bottom_a, side_normal, Vector2(0.0, 1.0))
		_add_side_vertex(side_surface, top_a, side_normal, Vector2(0.0, 0.0))
		_add_side_vertex(side_surface, top_b, side_normal, Vector2(1.0, 0.0))
		_add_side_vertex(side_surface, bottom_b, side_normal, Vector2(1.0, 1.0))
	side_surface.commit(mesh)
	mesh.surface_set_material(0, _material)
	mesh.surface_set_material(1, _side_material)
	_mesh_instance.mesh = mesh


func _add_top_vertex(surface: SurfaceTool, vertex: Vector3) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(get_board_uv_at_local(vertex))
	surface.add_vertex(vertex)


func _add_side_vertex(surface: SurfaceTool, vertex: Vector3, normal: Vector3, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


func _get_hex_corner(index: int, y_position: float) -> Vector3:
	var angle := deg_to_rad(30.0 - float(index) * 60.0)
	return Vector3(cos(angle) * radius, y_position, sin(angle) * radius)


func _update_color() -> void:
	if _is_selected:
		_set_color(selected_color, true)
	elif _is_legal_target:
		_set_color(legal_color, true)
	elif _is_analysis_frozen:
		_set_color(frozen_color, true)
	elif _is_analysis_reachable:
		_set_color(reachable_color, true)
	elif _is_aura_target:
		_set_color(aura_color, true)
	else:
		_set_color(base_color)


func _set_color(color: Color, force_tint := false) -> void:
	if _material == null:
		return
	var color_path := String(_material_profile.get("color_path", ""))
	if force_tint:
		_material.albedo_texture = null
		_material.albedo_color = color
		_material.emission_enabled = true
		_material.emission = color
		_material.emission_energy_multiplier = 0.85
		_side_material.albedo_color = color.darkened(0.28)
		return

	_material.albedo_texture = load(color_path) if not color_path.is_empty() else null
	_material.albedo_color = Color.WHITE if not color_path.is_empty() else color
	_material.emission_enabled = false
	_side_material.albedo_color = color.darkened(0.34)


func _apply_material_profile() -> void:
	if _material == null:
		return

	var color_path := String(_material_profile.get("color_path", ""))
	var normal_path := String(_material_profile.get("normal_path", ""))

	_material.albedo_texture = load(color_path) if not color_path.is_empty() else null
	_material.albedo_color = Color.WHITE if not color_path.is_empty() else base_color
	_material.normal_enabled = not normal_path.is_empty()
	_material.normal_texture = load(normal_path) if not normal_path.is_empty() else null
	_material.normal_scale = 0.1
	_material.roughness_texture = null
	_material.roughness = clampf(float(_material_profile.get("roughness", 0.5)), 0.42, 0.68)
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_material.clearcoat_enabled = true
	_material.clearcoat_roughness = 0.34
	_apply_texture_filter(_material)
	_apply_board_texture_mapping()
