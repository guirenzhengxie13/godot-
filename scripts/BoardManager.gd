class_name BoardManager
extends Node3D

signal cell_clicked(coord: Vector2i)
signal piece_clicked(piece)

@export var cell_scene: PackedScene = preload("res://scenes/Cell.tscn")
@export var piece_scene: PackedScene = preload("res://scenes/Piece.tscn")
@export var center_radius: int = 4
@export var arm_size: int = 4
@export var cell_spacing: float = 1.15
@export var piece_y_offset: float = 0.08

var cells: Dictionary = {}
var pieces: Dictionary = {}
var player_starts: Dictionary = {}
var player_targets: Dictionary = {}

var _cells_root: Node3D
var _pieces_root: Node3D


func _ready() -> void:
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
	for coord in coords:
		var cell = cell_scene.instantiate()
		_cells_root.add_child(cell)
		cell.setup(coord)
		cell.position = coord_to_world(coord)
		cell.cell_clicked.connect(_on_cell_clicked)
		cells[coord] = cell

	_build_player_regions()


func reset_pieces() -> void:
	clear_pieces()

	for player_id in player_starts.keys():
		for coord in player_starts[player_id]:
			spawn_piece(player_id, coord)

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


func clear_pieces() -> void:
	for child in _pieces_root.get_children():
		child.queue_free()
	pieces.clear()


func spawn_piece(player_id: int, coord: Vector2i):
	var piece = piece_scene.instantiate()
	_pieces_root.add_child(piece)
	piece.setup(player_id, coord, coord_to_world(coord) + Vector3.UP * piece_y_offset)
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


func coord_to_world(coord: Vector2i) -> Vector3:
	var x := cell_spacing * (float(coord.x) + float(coord.y) * 0.5)
	var z := cell_spacing * (float(coord.y) * sqrt(3.0) * 0.5)
	return Vector3(x, 0.0, z)


func clear_highlights() -> void:
	for cell in cells.values():
		cell.set_legal_target(false)
		cell.set_selected(false)
	for piece in pieces.values():
		piece.set_selected(false)


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


func _on_cell_clicked(coord: Vector2i) -> void:
	cell_clicked.emit(coord)


func _on_piece_clicked(piece) -> void:
	piece_clicked.emit(piece)
