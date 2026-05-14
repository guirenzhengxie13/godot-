class_name AIPlayer
extends Node

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var move_validator_path: NodePath = ^"../MoveValidator"
@export var max_jump_depth: int = 8
@export var jump_bonus: float = 1.7
@export var target_region_bonus: float = 6.0
@export var back_piece_priority: float = 0.22
@export var randomness: float = 0.15

@onready var board_manager = get_node(board_manager_path)
@onready var move_validator = get_node(move_validator_path)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func choose_move(player_id: int) -> Dictionary:
	var valid_cells: Dictionary = board_manager.get_valid_cells()
	var occupied: Dictionary = board_manager.get_occupied_cells()
	var best_move: Dictionary = {}
	var best_score := -INF

	for piece in board_manager.get_player_pieces(player_id):
		var candidates := _get_piece_turn_moves(piece, occupied, valid_cells)
		for path in candidates:
			if path.is_empty():
				continue
			var score := _score_path(piece, path, player_id)
			if score > best_score:
				best_score = score
				best_move = {
					"piece": piece,
					"path": path,
					"score": score,
				}

	return best_move


func _get_piece_turn_moves(piece, occupied: Dictionary, valid_cells: Dictionary) -> Array:
	var moves: Array = []

	for coord in move_validator.get_normal_moves(piece.coord, occupied, valid_cells):
		moves.append([coord])

	var visited := {
		piece.coord: true,
	}
	var jump_paths := _collect_jump_paths(piece.coord, occupied, valid_cells, [], visited, 0)
	moves.append_array(jump_paths)
	return moves


func _collect_jump_paths(from_coord: Vector2i, occupied: Dictionary, valid_cells: Dictionary, path: Array, visited: Dictionary, depth: int) -> Array:
	var paths: Array = []
	if depth >= max_jump_depth:
		return paths

	for target in move_validator.get_jump_moves(from_coord, occupied, valid_cells):
		if visited.has(target):
			continue

		var next_path := path.duplicate()
		next_path.append(target)
		paths.append(next_path)

		var next_visited := visited.duplicate()
		next_visited[target] = true

		var next_occupied := occupied.duplicate()
		next_occupied.erase(from_coord)
		next_occupied[target] = true
		paths.append_array(_collect_jump_paths(target, next_occupied, valid_cells, next_path, next_visited, depth + 1))

	return paths


func _score_path(piece, path: Array, player_id: int) -> float:
	var start: Vector3 = board_manager.coord_to_world(piece.coord)
	var target_coord: Vector2i = path[path.size() - 1]
	var target: Vector3 = board_manager.coord_to_world(target_coord)
	var goal_center: Vector3 = board_manager.get_target_region_center(player_id)
	var start_distance := start.distance_to(goal_center)
	var target_distance := target.distance_to(goal_center)
	var score := (start_distance - target_distance) * 10.0

	score += max(0, path.size() - 1) * jump_bonus
	score += start_distance * back_piece_priority
	score += _rng.randf_range(-randomness, randomness)

	if board_manager.get_target_region(player_id).has(target_coord):
		score += target_region_bonus

	return score
