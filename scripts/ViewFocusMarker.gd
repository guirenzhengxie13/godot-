class_name ViewFocusMarker
extends Area3D

signal marker_clicked(view_index: int)

@export var view_index := 0
@export var base_color := Color(0.2, 0.68, 0.95)
@export var hover_color := Color(0.95, 0.78, 0.25)
@export var model_path := "res://assets/environment/kenney_nature/statue_obelisk.obj"
@export var model_scale := 1.35

var _visual_meshes: Array[MeshInstance3D] = []
var _material: StandardMaterial3D
var _base_material: StandardMaterial3D
var _glow_light: OmniLight3D
var _material_profile: Dictionary = {}
var _is_hovered := false
var _glow_energy := 0.72


func _ready() -> void:
	input_ray_pickable = true
	add_to_group("view_focus_markers")
	_build_visuals()
	_apply_material_profile()


func set_material_profile(profile: Dictionary, fallback_color: Color) -> void:
	_material_profile = profile.duplicate(true)
	base_color = fallback_color
	_apply_material_profile()


func set_marker_glow(energy: float) -> void:
	_glow_energy = clampf(energy, 0.0, 1.6)
	_update_material_state()


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			marker_clicked.emit(view_index)
			get_viewport().set_input_as_handled()


func _mouse_enter() -> void:
	_is_hovered = true
	_update_material_state()


func _mouse_exit() -> void:
	_is_hovered = false
	_update_material_state()


func _build_visuals() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.58
	_material.metallic = 0.0
	_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

	if not _build_model_visual():
		_build_fallback_visual()
	_build_stable_base()
	_build_glow_light()

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := SphereShape3D.new()
	shape.radius = 0.62
	collision.shape = shape
	collision.position.y = 0.38
	add_child(collision)


func _build_glow_light() -> void:
	_glow_light = OmniLight3D.new()
	_glow_light.name = "MarkerGlowLight"
	_glow_light.position = Vector3(0.0, 0.95, 0.0)
	_glow_light.light_color = base_color.lightened(0.45)
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 7.4
	_glow_light.shadow_enabled = false
	_set_property_if_available(_glow_light, "light_specular", 0.02)
	add_child(_glow_light)


func _build_model_visual() -> bool:
	if model_path.is_empty():
		return false

	var model_resource := load(model_path)
	if model_resource == null:
		return false

	if model_resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MarkerStatue"
		mesh_instance.mesh = model_resource
		mesh_instance.scale = Vector3.ONE * model_scale
		mesh_instance.material_override = _material
		add_child(mesh_instance)
		_visual_meshes.append(mesh_instance)
		return true

	if model_resource is PackedScene:
		var scene_instance := (model_resource as PackedScene).instantiate()
		scene_instance.name = "MarkerStatue"
		scene_instance.scale = Vector3.ONE * model_scale
		add_child(scene_instance)
		_collect_meshes(scene_instance)
		return not _visual_meshes.is_empty()

	return false


func _build_fallback_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MarkerMesh"
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.32
	mesh_instance.material_override = _material
	add_child(mesh_instance)
	_visual_meshes.append(mesh_instance)


func _build_stable_base() -> void:
	var base := MeshInstance3D.new()
	base.name = "MarkerBase"
	base.position.y = 0.07
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.42
	base_mesh.bottom_radius = 0.5
	base_mesh.height = 0.14
	base_mesh.radial_segments = 32
	base.mesh = base_mesh

	_base_material = StandardMaterial3D.new()
	_base_material.roughness = 0.84
	_base_material.metallic = 0.0
	_base_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	base.material_override = _base_material
	add_child(base)


func _collect_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		mesh_instance.material_override = _material
		_visual_meshes.append(mesh_instance)

	for child in root.get_children():
		_collect_meshes(child)


func _apply_material_profile() -> void:
	if _material == null:
		return

	var color_path := String(_material_profile.get("color_path", ""))
	var normal_path := String(_material_profile.get("normal_path", ""))
	var roughness_path := String(_material_profile.get("roughness_path", ""))

	_material.albedo_texture = load(color_path) if not color_path.is_empty() else null
	_material.normal_enabled = not normal_path.is_empty()
	_material.normal_texture = load(normal_path) if not normal_path.is_empty() else null
	_material.normal_scale = 0.18
	_material.roughness_texture = load(roughness_path) if not roughness_path.is_empty() else null
	_material.roughness = float(_material_profile.get("roughness", 0.58))
	_material.metallic = 0.0
	_apply_base_material_profile()
	_update_material_state()


func _apply_base_material_profile() -> void:
	if _base_material == null:
		return
	_base_material.albedo_texture = null
	_base_material.albedo_color = base_color
	_base_material.normal_enabled = false
	_base_material.normal_texture = null
	_base_material.roughness_texture = null
	_base_material.roughness = 0.84
	_base_material.emission_enabled = true
	_base_material.emission = base_color
	_base_material.emission_energy_multiplier = _glow_energy * 0.35


func _update_material_state() -> void:
	if _material == null:
		return

	if _material.albedo_texture == null:
		_material.albedo_color = hover_color if _is_hovered else base_color
	else:
		_material.albedo_color = Color(1.08, 1.08, 1.08) if _is_hovered else Color.WHITE

	var glow_color := hover_color if _is_hovered else base_color.lightened(0.3)
	var glow_energy := maxf(_glow_energy, 0.7) if _is_hovered else _glow_energy
	_material.emission_enabled = glow_energy > 0.01
	_material.emission = glow_color
	_material.emission_energy_multiplier = glow_energy * 0.42
	if _base_material != null:
		_base_material.emission_enabled = glow_energy > 0.01
		_base_material.emission = base_color.lightened(0.2)
		_base_material.emission_energy_multiplier = glow_energy * 0.28
	if _glow_light != null:
		_glow_light.light_color = glow_color
		_glow_light.light_energy = glow_energy * 0.34


func _set_property_if_available(object: Object, property_name: String, value) -> void:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			object.set(property_name, value)
			return
