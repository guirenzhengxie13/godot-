class_name BoardManager
extends Node3D

signal cell_clicked(coord: Vector2i)
signal piece_clicked(piece)
signal player_material_changed(player_id: int, profile: Dictionary)

@export var cell_scene: PackedScene = preload("res://scenes/Cell.tscn")
@export var piece_scene: PackedScene = preload("res://scenes/Piece.tscn")
@export var center_radius: int = 4
@export var arm_size: int = 4
@export var cell_spacing: float = 1.15
@export var piece_y_offset: float = 0.08
@export var material_root := "res://assets/materials"
@export var board_texture_edge_padding: float = 0.58

const COVER_MEADOW_STONE_ID := "cover_meadow_stone"
const FIXED_BOARD_MARBLE_ID := "大理石/Travertine003"
const FIXED_BOARD_MARBLE_SUFFIX := "003"

var cells: Dictionary = {}
var pieces: Dictionary = {}
var player_starts: Dictionary = {}
var player_targets: Dictionary = {}
var material_options: Array[Dictionary] = []

var _cells_root: Node3D
var _pieces_root: Node3D
var _skill_seed := 0
var _board_material_id := "default"
var _board_texture_origin := Vector2.ZERO
var _board_texture_span := 1.0
var _player_material_ids := {
	1: "default",
	2: "default",
}


func _ready() -> void:
	_scan_material_options()
	_choose_initial_materials()
	build_board()
	reset_pieces()


func build_board() -> void:
	_clear_board()
	_cells_root = Node3D.new()
	_cells_root.name = "Cells"
	add_child(_cells_root)

	_pieces_root = Node3D.new()
	_pieces_root.name = "Pieces"
	add_child(_pieces_root)

	var coords := _generate_board_coords()
	_configure_board_texture_mapping(coords)
	for coord in coords:
		var cell = cell_scene.instantiate()
		_cells_root.add_child(cell)
		cell.setup(coord)
		cell.position = coord_to_world(coord)
		cell.cell_clicked.connect(_on_cell_clicked)
		cell.set_board_texture_mapping(_board_texture_origin, _board_texture_span)
		cell.set_material_profile(_get_material_profile(_board_material_id))
		cells[coord] = cell

	_build_player_regions()


func reset_pieces() -> void:
	clear_pieces()

	var player_ids := player_starts.keys()
	player_ids.sort()
	for player_id in player_ids:
		var coords: Array = player_starts[player_id]
		for index in range(coords.size()):
			spawn_piece(player_id, coords[index], "P%d_%02d" % [player_id, index + 1])

	clear_highlights()


func setup_victory_test_layout() -> void:
	clear_pieces()
	var target_region := get_target_region(1)
	for coord in target_region:
		if coord != Vector2i(4, -5):
			spawn_piece(1, coord)

	spawn_piece(1, Vector2i(4, 3))
	spawn_piece(2, Vector2i(4, 2))
	spawn_piece(2, Vector2i(4, 0))
	spawn_piece(2, Vector2i(4, -2))
	spawn_piece(2, Vector2i(4, -4))
	clear_highlights()


func get_pieces_snapshot() -> Array:
	var snapshot: Array = []
	var coords := pieces.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	for coord in coords:
		var piece = pieces.get(coord)
		if piece == null:
			continue
		snapshot.append({
			"player_id": piece.player_id,
			"coord": _coord_to_array(coord),
			"piece_id": piece.piece_id,
			"passive_skill_id": piece.passive_skill_id,
		})
	return snapshot


func load_pieces_snapshot(snapshot: Array) -> void:
	clear_pieces()
	for entry in snapshot:
		if not entry is Dictionary:
			continue
		spawn_piece(
			int(entry.get("player_id", 0)),
			_array_to_coord(entry.get("coord", [])),
			String(entry.get("piece_id", "")),
			String(entry.get("passive_skill_id", ""))
		)
	clear_highlights()


func clear_pieces() -> void:
	for child in _pieces_root.get_children():
		child.queue_free()
	pieces.clear()


func spawn_piece(player_id: int, coord: Vector2i, piece_id := "", passive_skill_id := ""):
	var piece = piece_scene.instantiate()
	_pieces_root.add_child(piece)
	piece.setup(player_id, coord, coord_to_world(coord) + Vector3.UP * piece_y_offset, piece_id, passive_skill_id)
	piece.set_material_profile(_get_material_profile(_player_material_ids.get(player_id, "default")))
	piece.piece_clicked.connect(_on_piece_clicked)
	pieces[coord] = piece
	return piece


func move_piece(piece, target_coord: Vector2i) -> void:
	if pieces.get(piece.coord) == piece:
		pieces.erase(piece.coord)
	piece.set_coord(target_coord, coord_to_world(target_coord) + Vector3.UP * piece_y_offset)
	pieces[target_coord] = piece


func get_piece_at(coord: Vector2i):
	return pieces.get(coord)


func has_cell(coord: Vector2i) -> bool:
	return cells.has(coord)


func is_occupied(coord: Vector2i) -> bool:
	return pieces.has(coord)


func get_valid_cells() -> Dictionary:
	return cells


func get_occupied_cells() -> Dictionary:
	return pieces


func get_rules_state() -> Dictionary:
	var state: Dictionary = {}
	for coord in pieces:
		var piece = pieces[coord]
		state[coord] = {
			"coord": coord,
			"piece_id": piece.piece_id,
			"player_id": piece.player_id,
			"passive_skill_id": piece.passive_skill_id,
		}
	return state


func coord_to_world(coord: Vector2i) -> Vector3:
	var x := cell_spacing * (float(coord.x) + float(coord.y) * 0.5)
	var z := cell_spacing * (float(coord.y) * sqrt(3.0) * 0.5)
	return Vector3(x, 0.0, z)


func _configure_board_texture_mapping(coords: Array[Vector2i]) -> void:
	if coords.is_empty():
		_board_texture_origin = Vector2.ZERO
		_board_texture_span = 1.0
		return

	var min_position := Vector2(INF, INF)
	var max_position := Vector2(-INF, -INF)
	for coord in coords:
		var world_position := coord_to_world(coord)
		var flat_position := Vector2(world_position.x, world_position.z)
		min_position = min_position.min(flat_position)
		max_position = max_position.max(flat_position)

	var board_size := max_position - min_position + Vector2.ONE * board_texture_edge_padding * 2.0
	_board_texture_span = maxf(maxf(board_size.x, board_size.y), 0.001)
	var board_center := (min_position + max_position) * 0.5
	_board_texture_origin = board_center - Vector2.ONE * _board_texture_span * 0.5


func clear_highlights() -> void:
	for cell in cells.values():
		cell.set_legal_target(false)
		cell.set_selected(false)
		cell.set_aura_target(false)
	for piece in pieces.values():
		piece.set_selected(false)


func clear_analysis_overlay() -> void:
	for cell in cells.values():
		cell.set_analysis_reachable(false)
		cell.set_analysis_frozen(false)
	for piece in pieces.values():
		piece.set_inspected(false)


func show_analysis_overlay(piece, reachable_coords: Array[Vector2i], frozen_coords: Array[Vector2i]) -> void:
	clear_analysis_overlay()
	for coord in frozen_coords:
		var frozen_cell = cells.get(coord)
		if frozen_cell != null:
			frozen_cell.set_analysis_frozen(true)
	for coord in reachable_coords:
		var reachable_cell = cells.get(coord)
		if reachable_cell != null:
			reachable_cell.set_analysis_reachable(true)
	if piece != null:
		piece.set_inspected(true)


func get_all_aura_coverage(skill_rules) -> Array[Vector2i]:
	var unique_coords: Dictionary = {}
	for piece in pieces.values():
		for coord in skill_rules.get_aura_coords(piece):
			unique_coords[coord] = true
	var result: Array[Vector2i] = []
	for coord in unique_coords.keys():
		result.append(coord)
	return result


func get_material_options() -> Array[Dictionary]:
	if material_options.is_empty():
		_scan_material_options()
	return [_get_material_option_by_id(_resolve_fixed_board_material_id())]


func get_material_selection() -> Dictionary:
	return {
		"board": _board_material_id,
		"player_1": _player_material_ids.get(1, "default"),
		"player_2": _player_material_ids.get(2, "default"),
	}


func apply_board_material(material_id: String) -> void:
	_board_material_id = _resolve_fixed_board_material_id()
	var profile := _get_material_profile(_board_material_id)
	for cell in cells.values():
		if cell != null and cell.has_method("set_material_profile"):
			cell.set_material_profile(profile)


func apply_player_material(player_id: int, material_id: String) -> void:
	_player_material_ids[player_id] = material_id
	var profile := _get_material_profile(material_id)
	for piece in pieces.values():
		if piece != null and piece.player_id == player_id and piece.has_method("set_material_profile"):
			piece.set_material_profile(profile)
	player_material_changed.emit(player_id, profile.duplicate(true))


func get_player_material_profile(player_id: int) -> Dictionary:
	return _get_material_profile(_player_material_ids.get(player_id, "default"))


func highlight_selection(piece, legal_targets: Array[Vector2i]) -> void:
	clear_highlights()
	piece.set_selected(true)
	var selected_cell = cells.get(piece.coord)
	if selected_cell != null:
		selected_cell.set_selected(true)
	for coord in legal_targets:
		var target_cell = cells.get(coord)
		if target_cell != null:
			target_cell.set_legal_target(true)


func highlight_skill_aura(coords: Array[Vector2i]) -> void:
	for coord in coords:
		var cell = cells.get(coord)
		if cell != null:
			cell.set_aura_target(true)


func assign_random_passive_skills(seed_value: int) -> void:
	_skill_seed = seed_value
	for piece in pieces.values():
		piece.set_passive_skill("")

	for player_id in player_starts.keys():
		var player_pieces := get_player_pieces(player_id)
		if player_pieces.size() < 3:
			continue
		player_pieces.sort_custom(func(a, b) -> bool: return String(a.piece_id) < String(b.piece_id))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + int(player_id) * 1009
		for index in range(player_pieces.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var swap_piece = player_pieces[index]
			player_pieces[index] = player_pieces[swap_index]
			player_pieces[swap_index] = swap_piece
		player_pieces[0].set_passive_skill("immobilize_aura")
		player_pieces[1].set_passive_skill("dash_jump")
		player_pieces[2].set_passive_skill("freeze_immune")


func clear_passive_skills() -> void:
	_skill_seed = 0
	for piece in pieces.values():
		piece.set_passive_skill("")
		piece.set_immobilized(false)


func refresh_piece_skill_status(skill_rules) -> Dictionary:
	var frozen_count := 0
	var thawed_count := 0
	for piece in pieces.values():
		var was_immobilized: bool = piece.is_immobilized()
		var is_immobilized: bool = skill_rules != null and skill_rules.is_piece_immobilized(piece, pieces)
		if is_immobilized and not was_immobilized:
			frozen_count += 1
		elif was_immobilized and not is_immobilized:
			thawed_count += 1
		piece.set_immobilized(is_immobilized)
	return {
		"frozen": frozen_count,
		"thawed": thawed_count,
	}


func get_target_region(player_id: int) -> Array:
	return player_targets.get(player_id, [])


func get_player_pieces(player_id: int) -> Array:
	var result: Array = []
	for piece in pieces.values():
		if piece.player_id == player_id:
			result.append(piece)
	return result


func get_player_piece_count(player_id: int) -> int:
	return get_player_pieces(player_id).size()


func get_player_piece_center(player_id: int) -> Vector3:
	var total := Vector3.ZERO
	var count := 0

	for piece in pieces.values():
		if piece.player_id == player_id:
			total += piece.global_position
			count += 1

	if count == 0:
		return Vector3.ZERO
	return total / float(count)


func get_target_region_center(player_id: int) -> Vector3:
	var target_region := get_target_region(player_id)
	if target_region.is_empty():
		return Vector3.ZERO
	return _get_coord_region_center(target_region)


func get_board_center() -> Vector3:
	if cells.is_empty():
		return Vector3.ZERO
	return _get_coord_region_center(cells.keys())


func _get_coord_region_center(coords: Array) -> Vector3:
	var total := Vector3.ZERO
	for coord in coords:
		total += coord_to_world(coord)
	return total / float(coords.size())


func _clear_board() -> void:
	for child in get_children():
		child.queue_free()
	cells.clear()
	pieces.clear()


func _generate_board_coords() -> Array[Vector2i]:
	var result: Dictionary = {}

	for q in range(-center_radius, center_radius + 1):
		for r in range(-center_radius, center_radius + 1):
			var s := -q - r
			if abs(q) <= center_radius and abs(r) <= center_radius and abs(s) <= center_radius:
				result[Vector2i(q, r)] = true

	for axis in range(3):
		_add_arm_coords(result, axis, 1)
		_add_arm_coords(result, axis, -1)

	var coords: Array[Vector2i] = []
	for coord in result.keys():
		coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return coords


func _add_arm_coords(result: Dictionary, axis: int, sign_value: int) -> void:
	for depth in range(1, arm_size + 1):
		var fixed_value := sign_value * (center_radius + depth)
		var row_count := arm_size - depth + 1
		for index in range(row_count):
			var other_a := -sign_value * (center_radius - index)
			var other_b := -fixed_value - other_a
			var cube := _cube_from_axis(axis, fixed_value, other_a, other_b)
			result[Vector2i(cube.x, cube.z)] = true


func _build_player_regions() -> void:
	var player_one_start := _get_arm_region(2, 1)
	var player_two_start := _get_arm_region(2, -1)
	player_starts = {
		1: player_one_start,
		2: player_two_start,
	}
	player_targets = {
		1: player_two_start,
		2: player_one_start,
	}


func _get_arm_region(axis: int, sign_value: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for depth in range(1, arm_size + 1):
		var fixed_value := sign_value * (center_radius + depth)
		var row_count := arm_size - depth + 1
		for index in range(row_count):
			var other_a := -sign_value * (center_radius - index)
			var other_b := -fixed_value - other_a
			var cube := _cube_from_axis(axis, fixed_value, other_a, other_b)
			coords.append(Vector2i(cube.x, cube.z))
	return coords


func _cube_from_axis(axis: int, fixed_value: int, other_a: int, other_b: int) -> Vector3i:
	match axis:
		0:
			return Vector3i(fixed_value, other_a, other_b)
		1:
			return Vector3i(other_a, fixed_value, other_b)
		_:
			return Vector3i(other_a, other_b, fixed_value)


func _scan_material_options() -> void:
	material_options.clear()
	material_options.append({
		"id": "default",
		"label": "默认颜色",
		"category": "内置",
		"profile": {},
	})
	material_options.append({
		"id": COVER_MEADOW_STONE_ID,
		"label": "封面浅石板",
		"category": "内置",
		"profile": {
			"base_color": Color(0.80, 0.78, 0.66),
			"side_color": Color(0.45, 0.50, 0.34),
			"roughness": 0.58,
			"normal_scale": 0.025,
			"clearcoat": 0.18,
			"clearcoat_roughness": 0.42,
		},
	})

	var root_dir := DirAccess.open(material_root)
	if root_dir == null:
		return

	root_dir.list_dir_begin()
	var category := root_dir.get_next()
	while not category.is_empty():
		if root_dir.current_is_dir() and not category.begins_with("."):
			_scan_material_category(category)
		category = root_dir.get_next()
	root_dir.list_dir_end()


func _choose_initial_materials() -> void:
	_board_material_id = _resolve_fixed_board_material_id()
	_player_material_ids[1] = _first_existing_material_id([
		"大理石/Onyx014",
		"大理石/Marble023",
		"大理石/Travertine003",
	], _first_material_id_by_category("大理石"))
	_player_material_ids[2] = _first_existing_material_id([
		"大理石/Travertine003",
		"大理石/Onyx014",
		"大理石/Marble023",
	], _first_non_default_material_id())


func _scan_material_category(category: String) -> void:
	var category_path := "%s/%s" % [material_root, category]
	var category_dir := DirAccess.open(category_path)
	if category_dir == null:
		return

	category_dir.list_dir_begin()
	var material_name := category_dir.get_next()
	while not material_name.is_empty():
		if category_dir.current_is_dir() and not material_name.begins_with("."):
			var material_path := "%s/%s" % [category_path, material_name]
			var profile := _build_material_profile(material_path)
			if not profile.is_empty():
				material_options.append({
					"id": "%s/%s" % [category, material_name],
					"label": "%s / %s" % [category, material_name],
					"category": category,
					"profile": profile,
				})
		material_name = category_dir.get_next()
	category_dir.list_dir_end()


func _build_material_profile(material_path: String) -> Dictionary:
	var material_dir := DirAccess.open(material_path)
	if material_dir == null:
		return {}

	var profile := {
		"roughness": 0.66,
		"metallic": 0.03,
	}

	material_dir.list_dir_begin()
	var file_name := material_dir.get_next()
	while not file_name.is_empty():
		if not material_dir.current_is_dir():
			var lower_name := file_name.to_lower()
			var resource_path := "%s/%s" % [material_path, file_name]
			if lower_name.ends_with("_color.jpg"):
				profile["color_path"] = resource_path
			elif lower_name.ends_with("_normalgl.jpg"):
				profile["normal_path"] = resource_path
			elif lower_name.ends_with("_roughness.jpg"):
				profile["roughness_path"] = resource_path
			elif lower_name.ends_with(".png"):
				profile["preview_path"] = resource_path
		file_name = material_dir.get_next()
	material_dir.list_dir_end()

	if not profile.has("color_path"):
		return {}
	return profile


func _get_material_profile(material_id: String) -> Dictionary:
	for option in material_options:
		if String(option.get("id", "")) == material_id:
			return (option.get("profile", {}) as Dictionary).duplicate(true)
	return {}


func _get_material_option_by_id(material_id: String) -> Dictionary:
	for option in material_options:
		if String(option.get("id", "")) == material_id:
			return (option as Dictionary).duplicate(true)
	return {
		"id": COVER_MEADOW_STONE_ID,
		"label": "封面浅石板",
		"category": "内置",
		"profile": _get_material_profile(COVER_MEADOW_STONE_ID),
	}


func _resolve_fixed_board_material_id() -> String:
	if _has_material_id(FIXED_BOARD_MARBLE_ID):
		return FIXED_BOARD_MARBLE_ID
	for option in material_options:
		var id := String(option.get("id", ""))
		var category := String(option.get("category", ""))
		if category == "大理石" and id.get_file().ends_with(FIXED_BOARD_MARBLE_SUFFIX):
			return id
	push_warning("Fixed 003 marble board material was not found; using cover meadow stone fallback.")
	return COVER_MEADOW_STONE_ID


func _first_existing_material_id(preferred_ids: Array, fallback_id: String) -> String:
	for preferred_id in preferred_ids:
		if _has_material_id(String(preferred_id)):
			return String(preferred_id)
	return fallback_id


func _first_material_id_by_category(category: String) -> String:
	for option in material_options:
		if String(option.get("category", "")) == category:
			return String(option.get("id", "default"))
	return _first_non_default_material_id()


func _first_non_default_material_id() -> String:
	for option in material_options:
		var id := String(option.get("id", "default"))
		if id != "default":
			return id
	return "default"


func _has_material_id(material_id: String) -> bool:
	for option in material_options:
		if String(option.get("id", "")) == material_id:
			return true
	return false


func _coord_to_array(coord: Vector2i) -> Array:
	return [coord.x, coord.y]


func _array_to_coord(value) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(999999, 999999)


func _on_cell_clicked(coord: Vector2i) -> void:
	cell_clicked.emit(coord)


func _on_piece_clicked(piece) -> void:
	piece_clicked.emit(piece)
