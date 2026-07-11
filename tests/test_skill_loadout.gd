extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var rules = main.get_node("PassiveSkillRuleEngine")
	var board = main.get_node("BoardManager")
	var game = main.get_node("GameManager")
	var game_ui = main.get_node("GameUI")

	_assert(rules.get_skill_catalog().size() == 7, "skill catalog includes normal plus six skills")
	var valid: Dictionary = rules.validate_loadout(["immobilize_aura", "dash_jump", "freeze_immune", "swift_step"], 10)
	_assert(bool(valid.get("valid", false)), "recommended loadout fits the point budget")
	_assert(int(valid.get("points_used", 0)) == 8, "recommended loadout uses eight points")
	var invalid: Dictionary = rules.validate_loadout(["immobilize_aura", "immobilize_aura", "immobilize_aura"], 10)
	_assert(not bool(invalid.get("valid", true)), "over-budget loadout is rejected")
	game_ui._on_start_local_pressed()
	game_ui._on_skill_loadout_start_pressed()
	await process_frame
	_assert((game._player_skill_loadouts.get(1, []) as Array).slice(0, 4) == ["immobilize_aura", "dash_jump", "freeze_immune", "swift_step"], "start menu submits the visible loadout")

	var selected := ["swift_step", "vault_jump", "guardian_aura", "freeze_immune", "", "", "", "", "", ""]
	game._player_skill_loadouts = {1: selected}
	game._reset_match_state(24680)
	var player_pieces: Array = board.get_player_pieces(1)
	player_pieces.sort_custom(func(a, b) -> bool: return String(a.piece_id) < String(b.piece_id))
	for index in range(selected.size()):
		_assert(player_pieces[index].passive_skill_id == selected[index], "piece %d keeps its configured skill" % (index + 1))

	var swift_piece := {"coord": Vector2i.ZERO, "player_id": 1, "passive_skill_id": "swift_step"}
	var swift_actions: Array[Dictionary] = rules.get_legal_actions(swift_piece, {Vector2i.ZERO: swift_piece})
	_assert(_has_action(swift_actions, Vector2i(2, 0), "step"), "swift step reaches two empty cells away")
	var swift_effects: Array = []
	for action in swift_actions:
		if action.get("final_coord") == Vector2i(2, 0):
			swift_effects = action.get("effects", [])
			break
	var serialized_effects: Array = game._serialize_action_effects(swift_effects)
	_assert(not serialized_effects.is_empty() and serialized_effects[0].get("crossed") is Array, "new action coordinates remain JSON serializable")

	var vault_piece := {"coord": Vector2i.ZERO, "player_id": 1, "passive_skill_id": "vault_jump"}
	var blocker := {"coord": Vector2i(1, 0), "player_id": 2, "passive_skill_id": ""}
	var vault_actions: Array[Dictionary] = rules.get_legal_actions(vault_piece, {Vector2i.ZERO: vault_piece, Vector2i(1, 0): blocker})
	_assert(_has_action(vault_actions, Vector2i(3, 0), "jump"), "vault jump lands three cells away")

	var protected_piece := {"coord": Vector2i.ZERO, "player_id": 1, "passive_skill_id": ""}
	var hostile_aura := {"coord": Vector2i(1, 0), "player_id": 2, "passive_skill_id": "immobilize_aura"}
	var guardian := {"coord": Vector2i(-1, 0), "player_id": 1, "passive_skill_id": "guardian_aura"}
	_assert(rules.is_piece_immobilized(protected_piece, {Vector2i.ZERO: protected_piece, Vector2i(1, 0): hostile_aura}), "hostile aura immobilizes an unprotected piece")
	_assert(not rules.is_piece_immobilized(protected_piece, {Vector2i.ZERO: protected_piece, Vector2i(1, 0): hostile_aura, Vector2i(-1, 0): guardian}), "guardian aura protects an adjacent ally")

	print("Skill loadout tests passed.")
	quit(0)


func _has_action(actions: Array[Dictionary], target: Vector2i, move_kind: String) -> bool:
	for action in actions:
		if action.get("final_coord") == target and String(action.get("move_kind", "")) == move_kind:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("Skill loadout test failed: %s" % message)
	quit(1)
