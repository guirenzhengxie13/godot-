class_name GameManager
extends Node

signal current_player_changed(player_id: int)
signal game_won(player_id: int)
signal piece_selected(piece)

const MODE_LOCAL_VS_AI := "local_vs_ai"
const MODE_ONLINE_PVP := "online_pvp"
const MatchRecorderScript := preload("res://scripts/gameplay/MatchRecorder.gd")

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var move_validator_path: NodePath = ^"../MoveValidator"
@export var passive_skill_rule_engine_path: NodePath = ^"../PassiveSkillRuleEngine"
@export var audio_manager_path: NodePath = ^"../AudioManager"
@export var background_manager_path: NodePath = ^"../BackgroundManager"
@export var game_ui_path: NodePath = ^"../GameUI"
@export var focus_camera_path: NodePath = ^"../Camera3D"
@export var ai_player_path: NodePath = ^"../AIPlayer"
@export var network_manager_path: NodePath = ^"../NetworkManager"
@export var human_player_id: int = 1
@export var ai_player_id: int = 2
@export var ai_observe_delay: float = 0.9
@export var ai_step_delay: float = 0.32
@export var replay_step_delay: float = 0.45
@export var player_count: int = 2

@onready var board_manager = get_node(board_manager_path)
@onready var move_validator = get_node(move_validator_path)
@onready var skill_rules = get_node(passive_skill_rule_engine_path)
@onready var audio_manager = get_node_or_null(audio_manager_path)
@onready var background_manager = get_node_or_null(background_manager_path)
@onready var game_ui = get_node(game_ui_path)
@onready var focus_camera = get_node_or_null(focus_camera_path)
@onready var ai_player = get_node_or_null(ai_player_path)
@onready var network_manager = get_node_or_null(network_manager_path)

var current_player := 1
var selected_piece
var legal_targets: Array[Vector2i] = []
var _legal_actions: Array[Dictionary] = []
var forced_chain_piece
var game_over := false
var local_player_id := 1
var online_is_host := false
var game_mode := MODE_LOCAL_VS_AI
var player_ai_takeover_enabled := false
var _turn_token := 0
var _match_recorder: Variant = MatchRecorderScript.new()
var _replay_active := false
var _replay_playing := false
var _replay_step_index := 0
var _replay_play_token := 0
var _turn_rollback_stack: Array[Dictionary] = []
var _turn_pending_entries: Array[Dictionary] = []
var _turn_move_count := 0
var _turn_move_kind := ""
var _skills_enabled := true
var _match_seed := 0
var _analysis_mode := false
var _inspected_piece


func _ready() -> void:
	board_manager.cell_clicked.connect(_on_cell_clicked)
	board_manager.piece_clicked.connect(_on_piece_clicked)
	game_ui.restart_requested.connect(restart_game)
	game_ui.end_turn_requested.connect(_on_end_turn_requested)
	game_ui.test_layout_requested.connect(load_victory_test_layout)
	game_ui.save_camera_view_requested.connect(_on_save_camera_view_requested)
	game_ui.create_online_room_requested.connect(_on_create_online_room_requested)
	game_ui.join_online_room_requested.connect(_on_join_online_room_requested)
	game_ui.local_mode_requested.connect(_on_local_mode_requested)
	game_ui.ai_takeover_toggled.connect(_on_ai_takeover_toggled)
	game_ui.save_match_record_requested.connect(_on_save_match_record_requested)
	game_ui.load_match_record_requested.connect(_on_load_match_record_requested)
	game_ui.replay_start_requested.connect(_on_replay_start_requested)
	game_ui.replay_stop_requested.connect(_on_replay_stop_requested)
	game_ui.replay_play_toggled.connect(_on_replay_play_toggled)
	game_ui.replay_step_requested.connect(_on_replay_step_requested)
	game_ui.replay_previous_requested.connect(_on_replay_previous_requested)
	game_ui.replay_next_requested.connect(_on_replay_next_requested)
	game_ui.undo_turn_requested.connect(_on_undo_turn_requested)
	game_ui.restart_with_seed_requested.connect(_on_restart_with_seed_requested)
	game_ui.analysis_mode_toggled.connect(_on_analysis_mode_toggled)
	game_ui.material_selected.connect(_on_material_selected)
	game_ui.lighting_preset_selected.connect(_on_lighting_preset_selected)
	game_ui.render_cost_profile_selected.connect(_on_render_cost_profile_selected)
	game_ui.time_of_day_selected.connect(_on_time_of_day_selected)
	game_ui.auto_time_cycle_toggled.connect(_on_auto_time_cycle_toggled)
	game_ui.lighting_value_changed.connect(_on_lighting_value_changed)
	game_ui.save_lighting_requested.connect(_on_save_lighting_requested)
	game_ui.reset_lighting_requested.connect(_on_reset_lighting_requested)
	game_ui.set_material_options(board_manager.get_material_options())
	game_ui.set_material_selection(board_manager.get_material_selection())
	if background_manager != null:
		background_manager.lighting_settings_changed.connect(game_ui.set_lighting_settings)
		background_manager.render_cost_profile_changed.connect(game_ui.set_render_cost_profile)
		game_ui.set_lighting_presets(background_manager.get_lighting_presets())
		game_ui.set_render_cost_profiles(background_manager.get_render_cost_profiles())
		game_ui.set_render_cost_profile(background_manager.get_render_cost_profile())
		game_ui.set_time_of_day_presets(background_manager.get_time_of_day_presets())
		game_ui.set_auto_time_cycle_enabled(background_manager.auto_time_cycle_enabled)
		game_ui.set_lighting_settings(background_manager.get_lighting_settings())
	current_player_changed.connect(game_ui.set_current_player)
	game_won.connect(game_ui.show_victory)
	if focus_camera != null:
		piece_selected.connect(focus_camera.focus_selected_piece)
	if network_manager != null:
		network_manager.status_changed.connect(game_ui.set_network_status)
		network_manager.room_code_changed.connect(game_ui.set_online_room_code)
		network_manager.online_session_started.connect(_on_online_session_started)
		network_manager.game_message_received.connect(_on_game_message_received)
	call_deferred("restart_game")


func _unhandled_input(event: InputEvent) -> void:
	if _is_text_input_focused():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_SPACE:
			_on_end_turn_requested()
			get_viewport().set_input_as_handled()
		elif key_event.keycode == KEY_BACKSPACE or key_event.keycode == KEY_Z:
			_on_undo_turn_requested()
			get_viewport().set_input_as_handled()


func restart_game() -> void:
	if _is_online_mode():
		if online_is_host:
			_reset_match_state()
			_send_game_message({
				"type": "game_reset",
			})
		else:
			_send_game_message({
				"type": "reset_request",
			})
			game_ui.set_network_status("已请求房主重新开始")
		return

	_reset_match_state()


func load_victory_test_layout() -> void:
	if _is_online_mode():
		game_ui.set_network_status("在线模式暂不支持测试布局")
		return

	_disable_analysis_mode()
	_turn_token += 1
	current_player = human_player_id
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	game_over = false
	_clear_turn_transaction()
	board_manager.setup_victory_test_layout()
	_set_skills_enabled(false)
	board_manager.clear_passive_skills()
	board_manager.refresh_piece_skill_status(skill_rules)
	_match_seed = 0
	game_ui.set_skill_seed(_match_seed, false)
	game_ui.clear_selected_piece_skill()
	_begin_match_record("victory_test")
	game_ui.hide_victory()
	game_ui.show_test_layout_ready()
	current_player_changed.emit(current_player)
	if focus_camera != null:
		focus_camera.focus_board_overview(human_player_id)


func _on_piece_clicked(piece) -> void:
	if _replay_active:
		return
	if game_over:
		return
	if _analysis_mode:
		_inspect_piece(piece)
		return
	if piece.player_id != current_player or not _can_local_control_player(piece.player_id):
		_inspect_piece(piece)
		return
	if forced_chain_piece != null and piece != forced_chain_piece:
		return
	if _turn_move_count > 0 and forced_chain_piece == null:
		return
	if _turn_move_kind == "step":
		return
	_select_piece(piece, forced_chain_piece != null)


func _on_cell_clicked(coord: Vector2i) -> void:
	if _replay_active:
		return
	if _analysis_mode:
		return
	if game_over or selected_piece == null:
		return
	if not legal_targets.has(coord):
		return

	if _is_manual_rollback_target(selected_piece, coord):
		_on_undo_turn_requested()
		return

	var from_coord: Vector2i = selected_piece.coord

	if _is_online_mode():
		if online_is_host:
			_online_authority_try_move(local_player_id, from_coord, coord, true)
		else:
			_send_game_message({
				"type": "move_request",
				"from": _coord_to_array(from_coord),
				"to": _coord_to_array(coord),
			})
			_restore_camera_after_selected_action()
		return

	var action: Dictionary = skill_rules.get_action_by_input_target(_legal_actions, coord)
	if action.is_empty():
		return
	_apply_local_action(action)


func _apply_local_action(action: Dictionary) -> void:
	var from_coord: Vector2i = action.get("from", selected_piece.coord)
	var was_jump := String(action.get("move_kind", "")) == "jump"
	if _turn_move_count > 0 and _turn_move_kind == "step":
		return
	if _turn_move_count > 0 and _turn_move_kind == "jump" and not was_jump:
		return

	_push_turn_rollback_state()
	skill_rules.apply_action_to_board(action)
	var skill_status: Dictionary = board_manager.refresh_piece_skill_status(skill_rules)
	if audio_manager != null:
		audio_manager.play_action(action, skill_status, selected_piece.passive_skill_id)
	_turn_move_count += 1
	if _turn_move_kind.is_empty():
		_turn_move_kind = "jump" if was_jump else "step"
	_turn_pending_entries.append(_build_pending_action_entry(current_player, action, "human"))
	_update_turn_step_ui()

	if was_jump and skill_rules.has_jump_action_from(selected_piece, board_manager.get_occupied_cells(), _turn_move_count):
		forced_chain_piece = selected_piece
		_select_piece(selected_piece, true)
		game_ui.show_continue_jump()
		return

	forced_chain_piece = null
	legal_targets.clear()
	_add_manual_rollback_target(selected_piece)
	board_manager.highlight_selection(selected_piece, legal_targets)
	board_manager.highlight_skill_aura(skill_rules.get_aura_coords(selected_piece))
	if game_ui.has_method("show_turn_pending_end"):
		game_ui.show_turn_pending_end()
	else:
		game_ui.show_continue_jump()


func _select_piece(piece, only_jumps := false) -> void:
	_inspected_piece = null
	board_manager.clear_analysis_overlay()
	selected_piece = piece
	_legal_actions = skill_rules.get_legal_actions(piece, board_manager.get_occupied_cells(), only_jumps, _turn_move_count if only_jumps else 0)
	legal_targets.clear()
	for action in _legal_actions:
		legal_targets.append(action.get("input_target", piece.coord))
	_add_manual_rollback_target(piece)
	board_manager.highlight_selection(piece, legal_targets)
	board_manager.highlight_skill_aura(skill_rules.get_aura_coords(piece))
	board_manager.refresh_piece_skill_status(skill_rules)
	game_ui.set_selected_piece_skill(
		skill_rules.get_skill_name(piece.passive_skill_id),
		skill_rules.get_skill_description(piece.passive_skill_id),
		skill_rules.is_piece_immobilized(piece, board_manager.get_occupied_cells())
	)
	piece_selected.emit(piece)


func _end_turn() -> void:
	_restore_camera_after_selected_action()
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	_clear_turn_transaction()
	board_manager.clear_highlights()
	game_ui.clear_selected_piece_skill()
	game_ui.hide_end_turn()
	current_player += 1
	if current_player > player_count:
		current_player = 1
	current_player_changed.emit(current_player)
	_start_turn_flow()


func _finish_local_human_turn() -> void:
	var outcome := "win" if _did_current_player_win() else ""
	_commit_turn_pending_entries(outcome)

	if outcome == "win":
		_restore_camera_after_selected_action()
		game_over = true
		selected_piece = null
		forced_chain_piece = null
		legal_targets.clear()
		_legal_actions.clear()
		board_manager.clear_highlights()
		game_ui.clear_selected_piece_skill()
		game_ui.hide_end_turn()
		_clear_turn_transaction()
		game_won.emit(current_player)
		return

	_end_turn()


func create_state_snapshot(extra_context := {}) -> Dictionary:
	var selected_coord = null
	if selected_piece != null:
		selected_coord = _coord_to_array(selected_piece.coord)

	var forced_coord = null
	if forced_chain_piece != null:
		forced_coord = _coord_to_array(forced_chain_piece.coord)

	var snapshot := {
		"version": 2,
		"pieces": board_manager.get_pieces_snapshot(),
		"random_seed": _match_seed,
		"skills_enabled": _skills_enabled,
		"current_player": current_player,
		"selected_coord": selected_coord,
		"forced_coord": forced_coord,
		"turn_move_count": _turn_move_count,
		"turn_move_kind": _turn_move_kind,
		"turn_pending_entries": _turn_pending_entries.duplicate(true),
		"future_effects": [],
		"context": extra_context.duplicate(true) if extra_context is Dictionary else {},
	}
	return snapshot


func restore_state_snapshot(snapshot: Dictionary) -> void:
	_disable_analysis_mode()
	board_manager.load_pieces_snapshot(snapshot.get("pieces", []))
	_match_seed = int(snapshot.get("random_seed", _match_seed))
	_set_skills_enabled(bool(snapshot.get("skills_enabled", _skills_enabled)))
	board_manager.refresh_piece_skill_status(skill_rules)
	current_player = int(snapshot.get("current_player", current_player))
	current_player_changed.emit(current_player)
	_turn_move_count = int(snapshot.get("turn_move_count", 0))
	_turn_move_kind = String(snapshot.get("turn_move_kind", ""))
	_turn_pending_entries = (snapshot.get("turn_pending_entries", []) as Array).duplicate(true)

	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	board_manager.clear_highlights()

	var forced_value = snapshot.get("forced_coord", null)
	if forced_value is Array:
		forced_chain_piece = board_manager.get_piece_at(_array_to_coord(forced_value))

	var selected_value = snapshot.get("selected_coord", null)
	if selected_value is Array:
		selected_piece = board_manager.get_piece_at(_array_to_coord(selected_value))

	if forced_chain_piece != null:
		_select_piece(forced_chain_piece, true)
		game_ui.show_continue_jump()
	elif selected_piece != null:
		_select_piece(selected_piece, false)
		if _turn_move_count > 0:
			if game_ui.has_method("show_turn_pending_end"):
				game_ui.show_turn_pending_end()
	else:
		board_manager.clear_highlights()
		game_ui.clear_selected_piece_skill()
		if _turn_move_count > 0 and game_ui.has_method("show_turn_pending_end"):
			game_ui.show_turn_pending_end()
		else:
			game_ui.hide_end_turn()


func _push_turn_rollback_state() -> void:
	_turn_rollback_stack.append(create_state_snapshot({
		"reason": "before_move",
	}))


func _add_manual_rollback_target(piece) -> void:
	var rollback_coord = _get_manual_rollback_coord(piece)
	if rollback_coord == null:
		return
	if not legal_targets.has(rollback_coord):
		legal_targets.append(rollback_coord)


func _is_manual_rollback_target(piece, coord: Vector2i) -> bool:
	var rollback_coord = _get_manual_rollback_coord(piece)
	return rollback_coord != null and rollback_coord == coord


func _get_manual_rollback_coord(piece):
	if piece == null or _turn_rollback_stack.is_empty():
		return null

	var snapshot: Dictionary = _turn_rollback_stack[_turn_rollback_stack.size() - 1]
	var rollback_value = snapshot.get("selected_coord", null)
	if not rollback_value is Array:
		rollback_value = snapshot.get("forced_coord", null)
	if not rollback_value is Array:
		return null

	var rollback_coord := _array_to_coord(rollback_value)
	if rollback_coord == piece.coord:
		return null
	if board_manager.get_piece_at(rollback_coord) != null:
		return null
	return rollback_coord


func _build_pending_action_entry(player_id: int, action: Dictionary, actor: String) -> Dictionary:
	var from_coord: Vector2i = action.get("from", Vector2i.ZERO)
	var final_coord: Vector2i = action.get("final_coord", from_coord)
	return {
		"type": "move",
		"player_id": player_id,
		"actor": actor,
		"from": _coord_to_array(from_coord),
		"to": _coord_to_array(final_coord),
		"input_target": _coord_to_array(action.get("input_target", final_coord)),
		"base_landing": _coord_to_array(action.get("base_landing", final_coord)),
		"final_coord": _coord_to_array(final_coord),
		"move_kind": String(action.get("move_kind", "step")),
		"effects": _serialize_action_effects(action.get("effects", [])),
		"turn_ended": false,
		"outcome": "",
		"future_effects": [],
	}


func _commit_turn_pending_entries(outcome := "") -> void:
	for index in range(_turn_pending_entries.size()):
		var entry := (_turn_pending_entries[index] as Dictionary).duplicate(true)
		entry["index"] = _get_record_entries().size() + 1
		entry["turn_ended"] = index == _turn_pending_entries.size() - 1
		if index == _turn_pending_entries.size() - 1:
			entry["outcome"] = outcome
		_append_record_entry(entry)
	if not outcome.is_empty():
		_persist_match_record(false)


func _clear_turn_transaction() -> void:
	_turn_rollback_stack.clear()
	_turn_pending_entries.clear()
	_turn_move_count = 0
	_turn_move_kind = ""
	_update_turn_step_ui()


func _update_turn_step_ui() -> void:
	if game_ui != null and game_ui.has_method("set_turn_step_count"):
		game_ui.set_turn_step_count(_turn_move_count, not _turn_rollback_stack.is_empty())


func _did_current_player_win() -> bool:
	var target_region: Array = board_manager.get_target_region(current_player)
	if target_region.is_empty():
		return false

	for coord in target_region:
		var piece = board_manager.get_piece_at(coord)
		if piece == null or piece.player_id != current_player:
			return false
	return true


func _on_end_turn_requested() -> void:
	if _replay_active:
		return
	if game_over:
		return

	if _is_online_mode():
		if forced_chain_piece == null:
			return
		if not _can_local_control_player(current_player):
			return
		if online_is_host:
			_online_authority_end_turn(true)
		else:
			_send_game_message({
				"type": "end_turn_request",
			})
			_record_turn_end(current_player, "human")
			_restore_camera_after_selected_action()
		return

	if _is_ai_turn():
		return
	if _turn_move_count <= 0:
		return
	_finish_local_human_turn()


func _on_save_camera_view_requested(view_name: String) -> void:
	if focus_camera == null:
		game_ui.show_camera_view_error("No camera is available.")
		return

	var result: Dictionary = focus_camera.save_named_view(view_name)
	if result.get("ok", false):
		game_ui.show_camera_view_saved(result.get("name", view_name), result.get("summary", ""))
	else:
		game_ui.show_camera_view_error(result.get("summary", "Failed to save camera view."))


func _on_create_online_room_requested(signaling_url: String) -> void:
	if network_manager == null:
		game_ui.set_network_status("没有 NetworkManager 节点")
		return
	network_manager.signaling_url = signaling_url
	network_manager.create_room()


func _on_join_online_room_requested(room_code: String, signaling_url: String) -> void:
	if network_manager == null:
		game_ui.set_network_status("没有 NetworkManager 节点")
		return
	if room_code.strip_edges().is_empty():
		game_ui.set_network_status("请输入房间码")
		return
	network_manager.signaling_url = signaling_url
	network_manager.join_room(room_code)


func _on_local_mode_requested() -> void:
	if network_manager != null:
		network_manager.leave_online_session()
	game_mode = MODE_LOCAL_VS_AI
	local_player_id = human_player_id
	online_is_host = false
	game_ui.show_local_mode()
	_reset_match_state()


func _on_online_session_started(is_host: bool, player_id: int) -> void:
	game_mode = MODE_ONLINE_PVP
	online_is_host = is_host
	local_player_id = player_id
	player_ai_takeover_enabled = false
	game_ui.set_ai_takeover_enabled(false)
	game_ui.set_online_player_role(local_player_id, online_is_host)
	_reset_match_state()


func _on_ai_takeover_toggled(enabled: bool) -> void:
	player_ai_takeover_enabled = enabled and not _is_online_mode()
	game_ui.set_ai_takeover_enabled(player_ai_takeover_enabled)
	game_ui.set_match_record_status("玩家 AI 托管：%s" % ("开启" if player_ai_takeover_enabled else "关闭"))
	if _is_online_mode() or _replay_active:
		return

	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	board_manager.clear_highlights()
	game_ui.clear_selected_piece_skill()
	game_ui.hide_end_turn()
	_turn_token += 1
	_start_turn_flow()


func _on_restart_with_seed_requested(seed_text: String) -> void:
	if _is_online_mode():
		game_ui.set_match_record_status("在线模式不启用技能种子")
		return
	var normalized := seed_text.strip_edges()
	if not normalized.is_valid_int():
		game_ui.set_match_record_status("种子必须是整数")
		return
	_reset_match_state(int(normalized))


func _on_analysis_mode_toggled(enabled: bool) -> void:
	if _replay_active:
		game_ui.set_analysis_mode(false)
		return
	_analysis_mode = enabled
	_inspected_piece = selected_piece if enabled and selected_piece != null and is_instance_valid(selected_piece) else null
	game_ui.set_analysis_mode(enabled)
	if enabled:
		board_manager.clear_highlights()
		_refresh_analysis_overlay()
	else:
		board_manager.clear_analysis_overlay()
		_restore_selection_highlights()


func _restore_selection_highlights() -> void:
	if selected_piece == null or not is_instance_valid(selected_piece):
		board_manager.clear_highlights()
		return
	board_manager.highlight_selection(selected_piece, legal_targets)
	board_manager.highlight_skill_aura(skill_rules.get_aura_coords(selected_piece))


func _inspect_piece(piece) -> void:
	if piece == null:
		return
	_inspected_piece = piece
	game_ui.set_selected_piece_skill(
		skill_rules.get_skill_name(piece.passive_skill_id),
		skill_rules.get_skill_description(piece.passive_skill_id),
		skill_rules.is_piece_immobilized(piece, board_manager.get_occupied_cells())
	)
	if _analysis_mode:
		_refresh_analysis_overlay()
	else:
		var empty_coords: Array[Vector2i] = []
		board_manager.show_analysis_overlay(piece, empty_coords, empty_coords)


func _refresh_analysis_overlay() -> void:
	if not _analysis_mode:
		return
	var frozen_coords: Array[Vector2i] = board_manager.get_all_aura_coverage(skill_rules)
	var reachable_coords: Array[Vector2i] = []
	if _inspected_piece != null and is_instance_valid(_inspected_piece):
		var state: Dictionary = board_manager.get_rules_state()
		reachable_coords = skill_rules.get_turn_reachable_coords(state.get(_inspected_piece.coord), state)
	board_manager.show_analysis_overlay(_inspected_piece, reachable_coords, frozen_coords)
	if _inspected_piece == null:
		game_ui.set_analysis_status("观察模式：蓝色区域为光环冻结范围，选择棋子查看技能规则可达区域")
	else:
		game_ui.set_analysis_status("观察模式：%s 可达 %d 格；蓝色区域为光环冻结范围" % [
			_inspected_piece.piece_id,
			reachable_coords.size(),
		])


func _disable_analysis_mode() -> void:
	_analysis_mode = false
	_inspected_piece = null
	board_manager.clear_analysis_overlay()
	game_ui.set_analysis_mode(false)


func _on_save_match_record_requested() -> void:
	_persist_match_record(true)


func _on_load_match_record_requested() -> void:
	var loaded := _load_latest_match_record()
	if loaded:
		game_ui.set_match_record_status("已载入最近记录：%d 步" % _get_record_entries().size())
		_start_replay()


func _on_replay_start_requested() -> void:
	_start_replay()


func _on_replay_stop_requested() -> void:
	_stop_replay()


func _on_replay_play_toggled(playing: bool) -> void:
	if not _replay_active:
		_start_replay()
	if not _replay_active:
		return
	_replay_playing = playing
	_replay_play_token += 1
	_update_replay_ui()
	if _replay_playing:
		_play_replay(_replay_play_token)


func _on_replay_step_requested(step_index: int) -> void:
	if not _replay_active:
		_start_replay()
	if not _replay_active:
		return
	_replay_playing = false
	_replay_play_token += 1
	_apply_replay_step(step_index)


func _on_replay_previous_requested() -> void:
	_on_replay_step_requested(_replay_step_index - 1)


func _on_replay_next_requested() -> void:
	_on_replay_step_requested(_replay_step_index + 1)


func _on_undo_turn_requested() -> void:
	if _replay_active or game_over or _is_online_mode() or _is_ai_turn():
		return
	if _turn_rollback_stack.is_empty():
		return

	var snapshot: Dictionary = _turn_rollback_stack.pop_back()
	restore_state_snapshot(snapshot)
	_update_turn_step_ui()


func _on_material_selected(target: String, material_id: String) -> void:
	match target:
		"board":
			board_manager.apply_board_material(material_id)
		"player_1":
			board_manager.apply_player_material(1, material_id)
		"player_2":
			board_manager.apply_player_material(2, material_id)
	game_ui.set_material_selection(board_manager.get_material_selection())


func _on_lighting_preset_selected(preset_id: String) -> void:
	if background_manager == null or preset_id == "custom":
		return
	background_manager.apply_lighting_preset(preset_id)
	game_ui.show_lighting_status("已应用预设：%s" % preset_id)


func _on_render_cost_profile_selected(profile_id: String) -> void:
	if background_manager == null:
		return
	background_manager.apply_render_cost_profile(profile_id)
	var profile: Dictionary = background_manager.get_render_cost_profile()
	game_ui.set_render_cost_profile(profile)
	game_ui.show_lighting_status("已应用 Forward+ 开销档位：%s" % String(profile.get("label", profile_id)))


func _on_time_of_day_selected(hour: float) -> void:
	if background_manager == null or not background_manager.has_method("set_time_of_day"):
		return
	background_manager.set_time_of_day(hour)
	game_ui.show_lighting_status("已切换时间光照：%.1f 点" % hour)


func _on_auto_time_cycle_toggled(enabled: bool) -> void:
	if background_manager == null:
		return
	if background_manager.has_method("set_auto_time_cycle_enabled"):
		background_manager.set_auto_time_cycle_enabled(enabled)
	else:
		background_manager.auto_time_cycle_enabled = enabled
	game_ui.set_auto_time_cycle_enabled(enabled)
	game_ui.show_lighting_status("自动昼夜：%s" % ("开启" if enabled else "关闭"))


func _on_lighting_value_changed(parameter: String, value: float) -> void:
	if background_manager != null:
		background_manager.set_lighting_value(parameter, value)


func _on_save_lighting_requested() -> void:
	if background_manager == null:
		game_ui.show_lighting_status("没有可用的场景光影管理器")
		return
	var result: Dictionary = background_manager.save_lighting_settings()
	game_ui.show_lighting_status(String(result.get("summary", "光影保存完成")))


func _on_reset_lighting_requested() -> void:
	if background_manager == null:
		return
	background_manager.apply_lighting_preset("soft_day")
	background_manager.apply_render_cost_profile("high")
	game_ui.show_lighting_status("已恢复柔和日光预设与高渲染档")


func _on_game_message_received(message: Dictionary) -> void:
	var message_type := String(message.get("type", ""))

	match message_type:
		"move_request":
			if online_is_host:
				_online_authority_try_move(2, _array_to_coord(message.get("from", [])), _array_to_coord(message.get("to", [])), true)
		"end_turn_request":
			if online_is_host and current_player == 2:
				_online_authority_end_turn(true)
		"reset_request":
			if online_is_host:
				_reset_match_state()
				_send_game_message({
					"type": "game_reset",
				})
		"move_applied":
			if not online_is_host:
				_apply_remote_move(message)
		"turn_changed":
			if not online_is_host:
				_apply_remote_turn(message)
		"game_reset":
			if not online_is_host:
				_reset_match_state()
		_:
			game_ui.set_network_status("未知棋局消息：%s" % message_type)


func _online_authority_try_move(player_id: int, from_coord: Vector2i, to_coord: Vector2i, broadcast: bool) -> void:
	if game_over or current_player != player_id:
		return

	var piece = board_manager.get_piece_at(from_coord)
	if piece == null or piece.player_id != player_id:
		return
	if forced_chain_piece != null and piece != forced_chain_piece:
		return

	var only_jumps := forced_chain_piece != null
	var available_moves: Array[Vector2i] = move_validator.get_legal_moves(
		from_coord,
		board_manager.get_occupied_cells(),
		board_manager.get_valid_cells(),
		only_jumps
	)
	if not available_moves.has(to_coord):
		return

	selected_piece = piece
	var was_jump: bool = move_validator.is_jump_move(from_coord, to_coord)
	board_manager.move_piece(piece, to_coord)
	var skill_status: Dictionary = board_manager.refresh_piece_skill_status(skill_rules)
	if audio_manager != null:
		audio_manager.play_action(_build_standard_action(from_coord, to_coord), skill_status, piece.passive_skill_id)
	_refresh_analysis_overlay()

	var next_player := current_player
	var forced_coord = null
	var winner := 0

	if _did_current_player_win():
		_record_move(current_player, from_coord, to_coord, _get_local_actor_label(player_id), true, "win")
		_restore_camera_after_selected_action()
		game_over = true
		winner = current_player
		selected_piece = null
		forced_chain_piece = null
		legal_targets.clear()
		board_manager.clear_highlights()
		game_won.emit(current_player)
	elif was_jump and move_validator.has_jump_from(to_coord, board_manager.get_occupied_cells(), board_manager.get_valid_cells()):
		_record_move(current_player, from_coord, to_coord, _get_local_actor_label(player_id), false)
		forced_chain_piece = piece
		selected_piece = piece
		forced_coord = _coord_to_array(to_coord)
		if _can_local_control_player(current_player):
			_select_piece(piece, true)
			game_ui.show_continue_jump()
		else:
			board_manager.clear_highlights()
			game_ui.show_remote_turn()
	else:
		_record_move(current_player, from_coord, to_coord, _get_local_actor_label(player_id), true)
		_online_advance_turn_locally()
		next_player = current_player

	if broadcast:
		_send_game_message({
			"type": "move_applied",
			"from": _coord_to_array(from_coord),
			"to": _coord_to_array(to_coord),
			"current_player": next_player,
			"forced_coord": forced_coord,
			"game_over": game_over,
			"winner": winner,
		})

	if not game_over:
		_start_turn_flow()


func _online_authority_end_turn(broadcast: bool) -> void:
	if forced_chain_piece == null:
		return
	_online_advance_turn_locally()
	if broadcast:
		_send_game_message({
			"type": "turn_changed",
			"current_player": current_player,
		})
	_start_turn_flow()


func _online_advance_turn_locally() -> void:
	_restore_camera_after_selected_action()
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	board_manager.clear_highlights()
	game_ui.clear_selected_piece_skill()
	game_ui.hide_end_turn()
	current_player += 1
	if current_player > player_count:
		current_player = 1
	current_player_changed.emit(current_player)


func _apply_remote_move(message: Dictionary) -> void:
	var from_coord := _array_to_coord(message.get("from", []))
	var to_coord := _array_to_coord(message.get("to", []))
	var piece = board_manager.get_piece_at(from_coord)
	if piece != null:
		var move_player_id: int = piece.player_id
		board_manager.move_piece(piece, to_coord)
		var skill_status: Dictionary = board_manager.refresh_piece_skill_status(skill_rules)
		if audio_manager != null:
			audio_manager.play_action(_build_standard_action(from_coord, to_coord), skill_status, piece.passive_skill_id)
		_refresh_analysis_overlay()
		_record_move(
			move_player_id,
			from_coord,
			to_coord,
			"online_remote",
			message.get("forced_coord", null) == null,
			"win" if bool(message.get("game_over", false)) else ""
		)

	game_over = bool(message.get("game_over", false))
	current_player = int(message.get("current_player", current_player))
	current_player_changed.emit(current_player)
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	board_manager.clear_highlights()
	game_ui.clear_selected_piece_skill()

	var forced_value = message.get("forced_coord", null)
	if forced_value is Array:
		var forced_coord := _array_to_coord(forced_value)
		forced_chain_piece = board_manager.get_piece_at(forced_coord)

	if game_over:
		var winner := int(message.get("winner", 0))
		if winner > 0:
			game_won.emit(winner)
		return

	if forced_chain_piece != null and current_player == local_player_id:
		_select_piece(forced_chain_piece, true)
		game_ui.show_continue_jump()
	else:
		_start_turn_flow()


func _apply_remote_turn(message: Dictionary) -> void:
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	board_manager.clear_highlights()
	game_ui.clear_selected_piece_skill()
	game_ui.hide_end_turn()
	current_player = int(message.get("current_player", current_player))
	current_player_changed.emit(current_player)
	_start_turn_flow()


func _reset_match_state(seed_override = null) -> void:
	_restore_camera_after_selected_action()
	_disable_analysis_mode()
	_turn_token += 1
	current_player = 1
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	game_over = false
	_clear_turn_transaction()
	board_manager.reset_pieces()
	_set_skills_enabled(not _is_online_mode())
	if _skills_enabled:
		_match_seed = int(seed_override) if seed_override != null else _generate_match_seed()
		board_manager.assign_random_passive_skills(_match_seed)
	else:
		_match_seed = 0
		board_manager.clear_passive_skills()
	board_manager.refresh_piece_skill_status(skill_rules)
	if ai_player != null and ai_player.has_method("configure_seed"):
		ai_player.configure_seed(_match_seed)
	game_ui.set_skill_seed(_match_seed, _skills_enabled)
	game_ui.clear_selected_piece_skill()
	_begin_match_record("standard")
	game_ui.hide_victory()
	game_ui.hide_end_turn()
	current_player_changed.emit(current_player)
	_start_turn_flow()


func _start_turn_flow() -> void:
	_turn_token += 1
	var token := _turn_token

	if _replay_active:
		return

	if _is_online_mode():
		if current_player == local_player_id:
			game_ui.show_human_turn()
		else:
			game_ui.show_remote_turn()
		if focus_camera != null:
			focus_camera.focus_player_ready(current_player)
		return

	if _is_ai_turn():
		game_ui.show_ai_turn()
		if focus_camera != null:
			focus_camera.focus_board_overview(human_player_id)
		await get_tree().create_timer(ai_observe_delay).timeout
		if token != _turn_token or game_over or not _is_ai_turn():
			return
		await _perform_ai_turn(token)
	else:
		game_ui.show_human_turn()
		if focus_camera != null:
			focus_camera.focus_player_ready(current_player)


func _perform_ai_turn(token: int) -> void:
	if ai_player == null:
		_end_turn()
		return

	var ai_move: Dictionary = ai_player.choose_move(current_player)
	if ai_move.is_empty():
		_end_turn()
		return

	var piece = ai_move.get("piece")
	var path: Array = ai_move.get("path", [])
	if piece == null or path.is_empty():
		_end_turn()
		return

	for index in range(path.size()):
		var action: Dictionary = path[index]
		if token != _turn_token or game_over or not _is_ai_turn():
			return
		skill_rules.apply_action_to_board(action)
		var skill_status: Dictionary = board_manager.refresh_piece_skill_status(skill_rules)
		if audio_manager != null:
			audio_manager.play_action(action, skill_status, piece.passive_skill_id)
		_refresh_analysis_overlay()
		_record_action(current_player, action, _get_local_actor_label(current_player), index == path.size() - 1)
		if focus_camera != null:
			focus_camera.focus_board_overview(human_player_id)
		await get_tree().create_timer(ai_step_delay).timeout

	if _did_current_player_win():
		_mark_last_record_outcome("win")
		game_over = true
		board_manager.clear_highlights()
		game_won.emit(current_player)
		return

	_end_turn()


func _begin_match_record(layout_name: String) -> void:
	if _replay_active:
		return
	_match_recorder.reset(layout_name, game_mode, player_count, _match_seed, _skills_enabled, board_manager.get_pieces_snapshot())
	_update_recording_ui()


func _record_move(player_id: int, from_coord: Vector2i, to_coord: Vector2i, actor: String, turn_ended: bool, outcome := "") -> void:
	_record_action(player_id, _build_standard_action(from_coord, to_coord), actor, turn_ended, outcome)


func _build_standard_action(from_coord: Vector2i, to_coord: Vector2i) -> Dictionary:
	return {
		"from": from_coord,
		"input_target": to_coord,
		"base_landing": to_coord,
		"final_coord": to_coord,
		"move_kind": "jump" if move_validator.is_jump_move(from_coord, to_coord) else "step",
		"effects": [],
	}


func _record_action(player_id: int, action: Dictionary, actor: String, turn_ended: bool, outcome := "") -> void:
	if _replay_active or not _match_recorder.has_record():
		return

	var entry := _build_pending_action_entry(player_id, action, actor)
	entry["index"] = _get_record_entries().size() + 1
	entry["turn_ended"] = turn_ended
	entry["outcome"] = outcome
	_append_record_entry(entry)


func _record_turn_end(player_id: int, actor: String) -> void:
	if _replay_active or not _match_recorder.has_record():
		return

	_append_record_entry({
		"type": "end_turn",
		"index": _get_record_entries().size() + 1,
		"player_id": player_id,
		"actor": actor,
	})


func _append_record_entry(entry: Dictionary) -> void:
	_match_recorder.append_entry(entry)
	_update_recording_ui()
	_persist_match_record(false)


func _mark_last_record_outcome(outcome: String) -> void:
	if _match_recorder.mark_last_outcome(outcome):
		_update_recording_ui()
		_persist_match_record(false)


func _persist_match_record(show_status: bool) -> bool:
	if not _match_recorder.has_record():
		if show_status:
			game_ui.set_match_record_status("没有可保存的对局记录")
		return false

	var save_result: int = _match_recorder.save_latest()
	if save_result != OK:
		if show_status:
			if String(_match_recorder.last_error_context) == "dir":
				game_ui.set_match_record_status("保存失败：无法创建记录目录 %d" % save_result)
			else:
				game_ui.set_match_record_status("保存失败：%d" % save_result)
		return false

	if show_status:
		game_ui.set_match_record_status("已保存最近记录：%d 步" % _get_record_entries().size())
	return true


func _load_latest_match_record() -> bool:
	var load_result: int = _match_recorder.load_latest()
	if load_result == ERR_FILE_NOT_FOUND:
		game_ui.set_match_record_status("没有找到最近记录")
		return false
	if load_result == ERR_PARSE_ERROR:
		game_ui.set_match_record_status("读取失败：记录 JSON 无效")
		return false
	if load_result != OK:
		game_ui.set_match_record_status("读取失败：%d" % load_result)
		return false
	_update_recording_ui()
	return true


func _start_replay() -> void:
	var record: Dictionary = _match_recorder.record
	if record.is_empty() or not record.has("initial_pieces"):
		game_ui.set_match_record_status("没有可回放的对局记录")
		return

	_disable_analysis_mode()
	_turn_token += 1
	_replay_play_token += 1
	_replay_active = true
	_replay_playing = false
	_replay_step_index = 0
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	_legal_actions.clear()
	_clear_turn_transaction()
	game_ui.clear_selected_piece_skill()
	game_ui.hide_end_turn()
	game_ui.hide_victory()
	_apply_replay_step(0)


func _stop_replay() -> void:
	if not _replay_active:
		return
	_replay_play_token += 1
	_replay_active = false
	_replay_playing = false
	game_ui.show_replay_controls(false)
	game_ui.set_match_record_status("已退出回放")
	_reset_match_state()


func _apply_replay_step(step_index: int) -> void:
	var record: Dictionary = _match_recorder.record
	if record.is_empty():
		return

	var entries := _get_record_entries()
	_replay_step_index = clampi(step_index, 0, entries.size())
	_match_seed = int(record.get("random_seed", 0))
	_set_skills_enabled(bool(record.get("skills_enabled", false)))
	game_ui.set_skill_seed(_match_seed, _skills_enabled)
	board_manager.load_pieces_snapshot(record.get("initial_pieces", []))
	board_manager.refresh_piece_skill_status(skill_rules)
	board_manager.clear_highlights()

	for index in range(_replay_step_index):
		var entry = entries[index]
		if not entry is Dictionary:
			continue
		if String(entry.get("type", "")) != "move":
			continue
		skill_rules.apply_action_to_board(_action_from_record_entry(entry))
	board_manager.refresh_piece_skill_status(skill_rules)

	var label := "回放：%d / %d 步" % [_replay_step_index, entries.size()]
	if _replay_step_index > 0:
		var current_entry = entries[_replay_step_index - 1]
		if current_entry is Dictionary:
			current_player = int(current_entry.get("player_id", current_player))
			current_player_changed.emit(current_player)
			label = _format_replay_entry_label(current_entry, _replay_step_index, entries.size())
	game_ui.set_match_record_status(label)
	_update_replay_ui()


func _play_replay(token: int) -> void:
	while _replay_active and _replay_playing and token == _replay_play_token:
		if _replay_step_index >= _get_record_entries().size():
			_replay_playing = false
			_update_replay_ui()
			return
		await get_tree().create_timer(replay_step_delay).timeout
		if not _replay_active or not _replay_playing or token != _replay_play_token:
			return
		_apply_replay_step(_replay_step_index + 1)


func _update_replay_ui() -> void:
	game_ui.set_replay_state(_replay_active, _replay_playing, _replay_step_index, _get_record_entries().size())


func _update_recording_ui() -> void:
	game_ui.set_match_record_status("已记录 %d 步" % _get_record_entries().size())


func _get_record_entries() -> Array:
	return _match_recorder.get_entries()


func _format_replay_entry_label(entry: Dictionary, step_index: int, total_steps: int) -> String:
	var entry_type := String(entry.get("type", ""))
	if entry_type == "move":
		return "回放：%d / %d，玩家 %d %s -> %s" % [
			step_index,
			total_steps,
			int(entry.get("player_id", 0)),
			_format_coord(_array_to_coord(entry.get("from", []))),
			_format_coord(_array_to_coord(entry.get("to", []))),
		]
	if entry_type == "end_turn":
		return "回放：%d / %d，玩家 %d 结束回合" % [step_index, total_steps, int(entry.get("player_id", 0))]
	return "回放：%d / %d" % [step_index, total_steps]


func _get_local_actor_label(player_id: int) -> String:
	if player_ai_takeover_enabled or player_id == ai_player_id:
		return "ai"
	return "human"


func _can_local_control_player(player_id: int) -> bool:
	if _is_online_mode():
		return player_id == local_player_id and player_id == current_player
	if player_ai_takeover_enabled:
		return false
	return player_id == human_player_id and not _is_ai_turn()


func _is_ai_turn() -> bool:
	return not _is_online_mode() and (current_player == ai_player_id or player_ai_takeover_enabled)


func _is_online_mode() -> bool:
	return game_mode == MODE_ONLINE_PVP


func _send_game_message(message: Dictionary) -> void:
	if network_manager == null:
		return
	network_manager.send_game_message(message)


func _set_skills_enabled(enabled: bool) -> void:
	_skills_enabled = enabled
	skill_rules.set_skills_enabled(enabled)


func _generate_match_seed() -> int:
	return absi(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec())


func _serialize_action_effects(effects: Array) -> Array:
	var serialized: Array = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var entry := (effect as Dictionary).duplicate(true)
		if entry.get("from") is Vector2i:
			entry["from"] = _coord_to_array(entry["from"])
		if entry.get("to") is Vector2i:
			entry["to"] = _coord_to_array(entry["to"])
		if entry.get("jumped") is Array:
			var jumped_coords: Array = []
			for coord in entry["jumped"]:
				jumped_coords.append(_coord_to_array(coord) if coord is Vector2i else coord)
			entry["jumped"] = jumped_coords
		serialized.append(entry)
	return serialized


func _deserialize_action_effects(effects: Array) -> Array:
	var deserialized: Array = []
	for effect in effects:
		if not effect is Dictionary:
			continue
		var entry := (effect as Dictionary).duplicate(true)
		if entry.get("from") is Array:
			entry["from"] = _array_to_coord(entry["from"])
		if entry.get("to") is Array:
			entry["to"] = _array_to_coord(entry["to"])
		if entry.get("jumped") is Array:
			var jumped_coords: Array = []
			for coord in entry["jumped"]:
				jumped_coords.append(_array_to_coord(coord) if coord is Array else coord)
			entry["jumped"] = jumped_coords
		deserialized.append(entry)
	return deserialized


func _action_from_record_entry(entry: Dictionary) -> Dictionary:
	var from_coord := _array_to_coord(entry.get("from", []))
	var final_coord := _array_to_coord(entry.get("final_coord", entry.get("to", [])))
	return {
		"from": from_coord,
		"input_target": _array_to_coord(entry.get("input_target", entry.get("to", []))),
		"base_landing": _array_to_coord(entry.get("base_landing", entry.get("to", []))),
		"final_coord": final_coord,
		"move_kind": String(entry.get("move_kind", "step")),
		"effects": _deserialize_action_effects(entry.get("effects", [])),
	}


func _restore_camera_after_selected_action() -> void:
	if focus_camera != null and focus_camera.has_method("restore_selected_piece_view"):
		focus_camera.restore_selected_piece_view()


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit


func _coord_to_array(coord: Vector2i) -> Array:
	return [coord.x, coord.y]


func _format_coord(coord: Vector2i) -> String:
	return "(%d,%d)" % [coord.x, coord.y]


func _array_to_coord(value) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(999999, 999999)
