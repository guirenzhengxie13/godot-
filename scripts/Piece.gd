class_name Piece
extends Area3D

signal piece_clicked(piece)

@export var player_id: int = 1
@export var coord: Vector2i = Vector2i.ZERO
@export var piece_id := ""
@export var passive_skill_id := ""
@export var player_one_color: Color = Color(0.9, 0.16, 0.18)
@export var player_two_color: Color = Color(0.1, 0.35, 0.9)
@export var selected_color: Color = Color(1.0, 0.88, 0.28)
@export var inspected_color: Color = Color(0.42, 0.9, 1.0)
@export var radius: float = 0.34

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D
var _is_selected := false
var _is_inspected := false
var _is_immobilized := false
var _material_profile: Dictionary = {}
var _skill_label: Label3D
var _lock_label: Label3D
var _skill_visual_root: Node3D


func _ready() -> void:
	input_ray_pickable = true
	_ensure_visuals()
	_update_color()


func setup(new_player_id: int, new_coord: Vector2i, world_position: Vector3, new_piece_id := "", new_passive_skill_id := "") -> void:
	player_id = new_player_id
	coord = new_coord
	piece_id = new_piece_id
	passive_skill_id = new_passive_skill_id
	position = world_position + Vector3.UP * radius
	name = "Piece_P%d_%d_%d" % [player_id, coord.x, coord.y]
	_update_color()
	_update_status_labels()
	_update_skill_visuals()


func set_coord(new_coord: Vector2i, world_position: Vector3) -> void:
	coord = new_coord
	position = world_position + Vector3.UP * radius
	name = "Piece_P%d_%d_%d" % [player_id, coord.x, coord.y]


func set_selected(value: bool) -> void:
	_is_selected = value
	_update_color()


func set_inspected(value: bool) -> void:
	_is_inspected = value
	_update_color()


func set_passive_skill(skill_id: String) -> void:
	passive_skill_id = skill_id
	_update_skill_visuals()
	_update_status_labels()


func set_immobilized(value: bool) -> void:
	_is_immobilized = value
	_update_status_labels()


func is_immobilized() -> bool:
	return _is_immobilized


func set_material_profile(profile: Dictionary) -> void:
	_material_profile = profile.duplicate(true)
	_apply_material_profile()
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

	_mesh_instance.mesh = _create_piece_variant_mesh()

	_material = StandardMaterial3D.new()
	_material.roughness = 0.56
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mesh_instance.material_override = _material
	_apply_material_profile()

	var collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	var shape := SphereShape3D.new()
	shape.radius = radius
	collision_shape.shape = shape
	_ensure_status_labels()
	_ensure_skill_visual_root()
	_update_skill_visuals()


func _update_color() -> void:
	if _material == null:
		return

	if _is_selected:
		_material.albedo_color = selected_color
	elif _is_inspected:
		_material.albedo_color = inspected_color
	elif player_id == 1:
		_material.albedo_color = Color.WHITE if _material_profile.has("color_path") else player_one_color
	else:
		_material.albedo_color = Color.WHITE if _material_profile.has("color_path") else player_two_color


func _apply_material_profile() -> void:
	if _material == null:
		return

	var color_path := String(_material_profile.get("color_path", ""))
	var normal_path := String(_material_profile.get("normal_path", ""))

	_material.albedo_texture = load(color_path) if not color_path.is_empty() else null
	_material.normal_enabled = not normal_path.is_empty()
	_material.normal_texture = load(normal_path) if not normal_path.is_empty() else null
	_material.normal_scale = 0.12
	_material.roughness_texture = null
	_material.roughness = clampf(float(_material_profile.get("roughness", 0.56)), 0.42, 0.68)
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_material.clearcoat_enabled = true
	_material.clearcoat_roughness = 0.36
	_material.emission_enabled = false
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _ensure_status_labels() -> void:
	_skill_label = Label3D.new()
	_skill_label.name = "SkillLabel"
	_skill_label.position = Vector3(0.0, radius + 0.62, 0.0)
	_skill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_skill_label.font_size = 58
	_skill_label.outline_size = 12
	_skill_label.modulate = Color(1.0, 0.92, 0.4)
	_skill_label.no_depth_test = true
	add_child(_skill_label)

	_lock_label = Label3D.new()
	_lock_label.name = "LockLabel"
	_lock_label.position = Vector3(0.0, radius + 1.04, 0.0)
	_lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_label.font_size = 52
	_lock_label.outline_size = 12
	_lock_label.modulate = Color(0.45, 0.82, 1.0)
	_lock_label.no_depth_test = true
	add_child(_lock_label)
	_update_status_labels()


func _ensure_skill_visual_root() -> void:
	_skill_visual_root = get_node_or_null("SkillVisuals") as Node3D
	if _skill_visual_root == null:
		_skill_visual_root = Node3D.new()
		_skill_visual_root.name = "SkillVisuals"
		add_child(_skill_visual_root)


func _update_skill_visuals() -> void:
	if _mesh_instance == null:
		return
	_ensure_skill_visual_root()
	for child in _skill_visual_root.get_children():
		child.queue_free()

	match passive_skill_id:
		"immobilize_aura":
			_mesh_instance.mesh = _create_default_mesh()
			_add_aura_visuals()
		"dash_jump":
			_mesh_instance.mesh = _create_dash_mesh()
			_add_dash_visuals()
		"freeze_immune":
			_mesh_instance.mesh = _create_immune_mesh()
			_add_immune_visuals()
		_:
			_mesh_instance.mesh = _create_piece_variant_mesh()


func _create_piece_variant_mesh() -> PrimitiveMesh:
	match _get_piece_visual_variant():
		1:
			return _create_low_dome_mesh()
		2:
			return _create_tall_bead_mesh()
		3:
			return _create_faceted_gem_mesh()
		_:
			return _create_default_mesh()


func _get_piece_visual_variant() -> int:
	var key := piece_id
	if key.is_empty():
		key = "%d_%d_%d" % [player_id, coord.x, coord.y]
	return absi(hash(key)) % 4


func _create_default_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	return mesh


func _create_low_dome_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius * 1.08
	mesh.height = radius * 1.58
	mesh.radial_segments = 32
	mesh.rings = 12
	return mesh


func _create_tall_bead_mesh() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius * 0.78
	mesh.height = radius * 2.25
	mesh.radial_segments = 24
	mesh.rings = 10
	return mesh


func _create_faceted_gem_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.58
	mesh.bottom_radius = radius * 0.96
	mesh.height = radius * 1.65
	mesh.radial_segments = 8
	return mesh


func _create_dash_mesh() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius * 0.78
	mesh.height = radius * 2.8
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func _create_immune_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius * 1.08
	mesh.height = radius * 1.7
	mesh.radial_segments = 6
	return mesh


func _add_aura_visuals() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 1.72
	ring.outer_radius = radius * 2.08
	ring.rings = 48
	ring.ring_segments = 12
	var ring_instance := _add_skill_mesh("AuraRing", ring, _create_glow_material(Color(0.2, 0.72, 1.0, 0.86)))
	ring_instance.position.y = -radius + 0.05

	var particles := GPUParticles3D.new()
	particles.name = "FrostParticles"
	particles.amount = 38
	particles.lifetime = 1.9
	particles.randomness = 0.55
	particles.visibility_aabb = AABB(Vector3(-1.2, -0.5, -1.2), Vector3(2.4, 2.0, 2.4))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = radius * 2.25
	process_material.direction = Vector3.UP
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.08
	process_material.initial_velocity_max = 0.28
	process_material.gravity = Vector3(0.0, 0.1, 0.0)
	process_material.scale_min = 0.35
	process_material.scale_max = 0.82
	process_material.color = Color(0.55, 0.9, 1.0, 0.78)
	particles.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.19, 0.19)
	quad.material = _create_glow_material(Color(0.64, 0.94, 1.0, 0.82), true)
	particles.draw_pass_1 = quad
	_skill_visual_root.add_child(particles)


func _add_dash_visuals() -> void:
	var arrow := CylinderMesh.new()
	arrow.top_radius = 0.0
	arrow.bottom_radius = radius * 0.72
	arrow.height = radius * 0.94
	arrow.radial_segments = 6
	var arrow_instance := _add_skill_mesh("DashArrow", arrow, _create_glow_material(Color(1.0, 0.56, 0.12, 0.95)))
	arrow_instance.position.y = radius * 1.68

	for height_offset in [-0.34, 0.18]:
		var ring := TorusMesh.new()
		ring.inner_radius = radius * 1.08
		ring.outer_radius = radius * 1.34
		ring.rings = 32
		ring.ring_segments = 8
		var ring_instance := _add_skill_mesh("DashRing", ring, _create_glow_material(Color(1.0, 0.66, 0.2, 0.78)))
		ring_instance.position.y = height_offset


func _add_immune_visuals() -> void:
	var guard := CylinderMesh.new()
	guard.top_radius = radius * 1.46
	guard.bottom_radius = radius * 1.46
	guard.height = 0.11
	guard.radial_segments = 6
	var guard_instance := _add_skill_mesh("ImmuneGuard", guard, _create_glow_material(Color(0.62, 0.92, 1.0, 0.88)))
	guard_instance.position.y = -radius + 0.07


func _add_skill_mesh(node_name: String, mesh: PrimitiveMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh.material = material
	mesh_instance.mesh = mesh
	_skill_visual_root.add_child(mesh_instance)
	return mesh_instance


func _create_glow_material(color: Color, billboard := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.8
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material


func _update_status_labels() -> void:
	if _skill_label != null:
		match passive_skill_id:
			"immobilize_aura":
				_skill_label.text = "AURA"
				_skill_label.modulate = Color(0.45, 0.88, 1.0)
			"dash_jump":
				_skill_label.text = "JUMP"
				_skill_label.modulate = Color(1.0, 0.68, 0.22)
			"freeze_immune":
				_skill_label.text = "ICE"
				_skill_label.modulate = Color(0.7, 0.96, 1.0)
			_:
				_skill_label.text = ""
	if _lock_label != null:
		_lock_label.text = "×" if _is_immobilized else ""
