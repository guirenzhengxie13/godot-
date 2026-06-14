class_name PassiveSkillRuleEngine
extends Node

const SKILL_NONE := ""
const SKILL_IMMOBILIZE_AURA := "immobilize_aura"
const SKILL_DASH_JUMP := "dash_jump"
const SKILL_FREEZE_IMMUNE := "freeze_immune"
const DASH_JUMP_MAX_HOPS := 2
const MOVE_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var move_validator_path: NodePath = ^"../MoveValidator"

@onready var board_manager = get_node(board_manager_path)
@onready var move_validator = get_node(move_validator_path)

var skills_enabled := true


func set_skills_enabled(enabled: bool) -> void:
	skills_enabled = enabled


func get_legal_actions(piece, state: Dictionary, only_jumps := false, jump_count := 0) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if piece == null or is_piece_immobilized(piece, state):
		return actions

	var from_coord := _get_piece_coord(piece)
	if not only_jumps:
		for target in move_validator.get_normal_moves(from_coord, state, board_manager.get_valid_cells()):
			actions.append(_make_action(from_coord, target, target, "step", []))

	if _can_jump(piece, jump_count):
		for base_landing in move_validator.get_jump_moves(from_coord, state, board_manager.get_valid_cells()):
			actions.append(_make_jump_action(from_coord, base_landing))
		actions.append_array(_get_dash_long_jump_actions(piece, state, from_coord))
	return actions


func get_action_by_input_target(actions: Array[Dictionary], target: Vector2i) -> Dictionary:
	for action in actions:
		if action.get("input_target", Vector2i(999999, 999999)) == target:
			return action
	return {}


func has_jump_action_from(piece, state: Dictionary, jump_count := 0) -> bool:
	return not get_legal_actions(piece, state, true, jump_count).is_empty()


func get_turn_reachable_coords(piece, state: Dictionary) -> Array[Vector2i]:
	var reachable: Dictionary = {}
	if piece == null:
		return []

	for action in get_legal_actions(piece, state, false):
		var final_coord: Vector2i = action.get("final_coord", Vector2i(999999, 999999))
		reachable[final_coord] = true
		if String(action.get("move_kind", "")) != "jump":
			continue
		var next_state := apply_action_to_state(action, state)
		var next_piece = next_state.get(final_coord)
		var visited := {
			_get_piece_coord(piece): true,
			final_coord: true,
		}
		_collect_jump_reachable(next_piece, next_state, visited, reachable, 1)

	var result: Array[Vector2i] = []
	for coord in reachable.keys():
		result.append(coord)
	return result


func _collect_jump_reachable(piece, state: Dictionary, visited: Dictionary, reachable: Dictionary, jump_count: int) -> void:
	if piece == null:
		return
	for action in get_legal_actions(piece, state, true, jump_count):
		var final_coord: Vector2i = action.get("final_coord", Vector2i(999999, 999999))
		if visited.has(final_coord):
			continue
		reachable[final_coord] = true
		var next_state := apply_action_to_state(action, state)
		var next_visited := visited.duplicate()
		next_visited[final_coord] = true
		_collect_jump_reachable(next_state.get(final_coord), next_state, next_visited, reachable, jump_count + 1)


func is_piece_immobilized(piece, state: Dictionary) -> bool:
	if not skills_enabled or piece == null:
		return false

	var skill_id := _get_piece_skill(piece)
	if skill_id == SKILL_IMMOBILIZE_AURA or skill_id == SKILL_FREEZE_IMMUNE:
		return false

	var coord := _get_piece_coord(piece)
	for direction in MOVE_DIRECTIONS:
		var neighbor = state.get(coord + direction)
		if neighbor != null and _get_piece_skill(neighbor) == SKILL_IMMOBILIZE_AURA:
			return true
	return false


func apply_action_to_board(action: Dictionary):
	var piece = board_manager.get_piece_at(action.get("from", Vector2i(999999, 999999)))
	if piece == null:
		return null
	board_manager.move_piece(piece, action.get("final_coord", piece.coord))
	return piece


func apply_action_to_state(action: Dictionary, state: Dictionary) -> Dictionary:
	var next_state := state.duplicate(true)
	var from_coord: Vector2i = action.get("from", Vector2i(999999, 999999))
	var final_coord: Vector2i = action.get("final_coord", from_coord)
	var piece = next_state.get(from_coord)
	if piece == null:
		return next_state

	next_state.erase(from_coord)
	if piece is Dictionary:
		piece["coord"] = final_coord
	next_state[final_coord] = piece
	return next_state


func get_aura_coords(piece) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if piece == null or _get_piece_skill(piece) != SKILL_IMMOBILIZE_AURA:
		return coords

	var center := _get_piece_coord(piece)
	for direction in MOVE_DIRECTIONS:
		var coord := center + direction
		if board_manager.has_cell(coord):
			coords.append(coord)
	return coords


func get_skill_name(skill_id: String) -> String:
	match skill_id:
		SKILL_IMMOBILIZE_AURA:
			return "定身光环"
		SKILL_DASH_JUMP:
			return "冲刺跳"
		SKILL_FREEZE_IMMUNE:
			return "破冰"
		_:
			return "普通棋子"


func get_skill_description(skill_id: String) -> String:
	match skill_id:
		SKILL_IMMOBILIZE_AURA:
			return "周围六格中的其他棋子不能主动移动。"
		SKILL_DASH_JUMP:
			return "可跳过一枚棋子落到两格外；若前方连续有两枚棋子，也可直接落到三格外。每回合最多跳跃两次。"
		SKILL_FREEZE_IMMUNE:
			return "不受定身光环影响。"
		_:
			return "没有被动技能。"


func _make_jump_action(from_coord: Vector2i, landing: Vector2i) -> Dictionary:
	return _make_action(from_coord, landing, landing, "jump", [])


func _get_dash_long_jump_actions(piece, state: Dictionary, from_coord: Vector2i) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not skills_enabled or _get_piece_skill(piece) != SKILL_DASH_JUMP:
		return actions

	for direction in MOVE_DIRECTIONS:
		var first_middle := from_coord + direction
		var second_middle := from_coord + direction * 2
		var landing := from_coord + direction * 3
		if not state.has(first_middle) or not state.has(second_middle):
			continue
		if not board_manager.has_cell(landing) or state.has(landing):
			continue
		actions.append(_make_action(from_coord, landing, landing, "jump", [{
			"type": "dash_long_jump",
			"jumped": [first_middle, second_middle],
		}]))
	return actions


func _can_jump(piece, jump_count: int) -> bool:
	return not (
		skills_enabled
		and _get_piece_skill(piece) == SKILL_DASH_JUMP
		and jump_count >= DASH_JUMP_MAX_HOPS
	)


func _make_action(from_coord: Vector2i, input_target: Vector2i, base_landing: Vector2i, move_kind: String, effects: Array) -> Dictionary:
	return {
		"from": from_coord,
		"input_target": input_target,
		"base_landing": base_landing,
		"final_coord": input_target,
		"move_kind": move_kind,
		"effects": effects.duplicate(true),
	}


func _get_piece_coord(piece) -> Vector2i:
	if piece is Dictionary:
		return piece.get("coord", Vector2i(999999, 999999))
	return piece.coord


func _get_piece_skill(piece) -> String:
	if piece is Dictionary:
		return String(piece.get("passive_skill_id", SKILL_NONE))
	return String(piece.passive_skill_id)
