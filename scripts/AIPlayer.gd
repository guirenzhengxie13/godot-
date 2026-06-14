class_name AIPlayer
extends Node

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var passive_skill_rule_engine_path: NodePath = ^"../PassiveSkillRuleEngine"
@export var max_jump_depth: int = 8
@export var jump_bonus: float = 1.7
@export var target_region_bonus: float = 6.0
@export var back_piece_priority: float = 0.22
@export var randomness: float = 0.15

@onready var board_manager = get_node(board_manager_path)
@onready var skill_rules = get_node(passive_skill_rule_engine_path)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func configure_seed(seed_value: int) -> void:
	_rng.seed = seed_value + 7919


func choose_move(player_id: int) -> Dictionary:
	var state: Dictionary = board_manager.get_rules_state()
	var best_move: Dictionary = {}
	var best_score := -INF

	for piece in board_manager.get_player_pieces(player_id):
		var piece_state = state.get(piece.coord)
		if piece_state == null:
			continue
		var candidates := _get_piece_turn_actions(piece_state, state)
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


func _get_piece_turn_actions(piece_state: Dictionary, state: Dictionary) -> Array:
	var paths: Array = []
	for action in skill_rules.get_legal_actions(piece_state, state, false):
		if String(action.get("move_kind", "")) == "step":
			paths.append([action])

	var visited := {
		piece_state.get("coord"): true,
	}
	paths.append_array(_collect_jump_paths(piece_state, state, [], visited, 0))
	return paths


func _collect_jump_paths(piece_state: Dictionary, state: Dictionary, path: Array, visited: Dictionary, depth: int) -> Array:
	var paths: Array = []
	if depth >= max_jump_depth:
		return paths

	for action in skill_rules.get_legal_actions(piece_state, state, true, depth):
		var final_coord: Vector2i = action.get("final_coord", Vector2i(999999, 999999))
		if visited.has(final_coord):
			continue

		var next_path := path.duplicate(true)
		next_path.append(action)
		paths.append(next_path)

		var next_visited := visited.duplicate()
		next_visited[final_coord] = true
		var next_state: Dictionary = skill_rules.apply_action_to_state(action, state)
		var next_piece_state: Dictionary = next_state.get(final_coord, {})
		paths.append_array(_collect_jump_paths(next_piece_state, next_state, next_path, next_visited, depth + 1))

	return paths


func _score_path(piece, path: Array, player_id: int) -> float:
	var start: Vector3 = board_manager.coord_to_world(piece.coord)
	var final_action: Dictionary = path[path.size() - 1]
	var target_coord: Vector2i = final_action.get("final_coord", piece.coord)
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
