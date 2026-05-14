class_name GameManager
extends Node

signal current_player_changed(player_id: int)
signal game_won(player_id: int)
signal piece_selected(piece)

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var move_validator_path: NodePath = ^"../MoveValidator"
@export var game_ui_path: NodePath = ^"../GameUI"
@export var focus_camera_path: NodePath = ^"../Camera3D"
@export var ai_player_path: NodePath = ^"../AIPlayer"
@export var human_player_id: int = 1
@export var ai_player_id: int = 2
@export var ai_observe_delay: float = 0.9
@export var ai_step_delay: float = 0.32
@export var player_count: int = 2

@onready var board_manager = get_node(board_manager_path)
@onready var move_validator = get_node(move_validator_path)
@onready var game_ui = get_node(game_ui_path)
@onready var focus_camera = get_node_or_null(focus_camera_path)
@onready var ai_player = get_node_or_null(ai_player_path)

var current_player := 1
var selected_piece
var legal_targets: Array[Vector2i] = []
var forced_chain_piece
var game_over := false
var _turn_token := 0


func _ready() -> void:
	board_manager.cell_clicked.connect(_on_cell_clicked)
	board_manager.piece_clicked.connect(_on_piece_clicked)
	game_ui.restart_requested.connect(restart_game)
	game_ui.end_turn_requested.connect(_on_end_turn_requested)
	game_ui.test_layout_requested.connect(load_victory_test_layout)
	current_player_changed.connect(game_ui.set_current_player)
	game_won.connect(game_ui.show_victory)
	if focus_camera != null:
		piece_selected.connect(focus_camera.focus_selected_piece)
	call_deferred("restart_game")


func restart_game() -> void:
	current_player = 1
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	game_over = false
	board_manager.reset_pieces()
	game_ui.hide_victory()
	game_ui.hide_end_turn()
	current_player_changed.emit(current_player)
	_start_turn_flow()


func load_victory_test_layout() -> void:
	_turn_token += 1
	current_player = human_player_id
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	game_over = false
	board_manager.setup_victory_test_layout()
	game_ui.hide_victory()
	game_ui.show_test_layout_ready()
	current_player_changed.emit(current_player)
	if focus_camera != null:
		focus_camera.focus_board_overview(human_player_id)


func _on_piece_clicked(piece) -> void:
	if game_over or _is_ai_turn():
		return
	if forced_chain_piece != null and piece != forced_chain_piece:
		return
	if piece.player_id != current_player:
		return

	_select_piece(piece, forced_chain_piece != null)


func _on_cell_clicked(coord: Vector2i) -> void:
	if game_over or _is_ai_turn() or selected_piece == null:
		return
	if not legal_targets.has(coord):
		return

	var from_coord: Vector2i = selected_piece.coord
	var was_jump: bool = move_validator.is_jump_move(from_coord, coord)
	board_manager.move_piece(selected_piece, coord)

	if _did_current_player_win():
		game_over = true
		board_manager.clear_highlights()
		game_won.emit(current_player)
		return

	if was_jump and move_validator.has_jump_from(coord, board_manager.get_occupied_cells(), board_manager.get_valid_cells()):
		forced_chain_piece = selected_piece
		_select_piece(selected_piece, true)
		game_ui.show_continue_jump()
		return

	_end_turn()


func _select_piece(piece, only_jumps := false) -> void:
	selected_piece = piece
	legal_targets = move_validator.get_legal_moves(
		piece.coord,
		board_manager.get_occupied_cells(),
		board_manager.get_valid_cells(),
		only_jumps
	)
	board_manager.highlight_selection(piece, legal_targets)
	piece_selected.emit(piece)


func _end_turn() -> void:
	selected_piece = null
	forced_chain_piece = null
	legal_targets.clear()
	board_manager.clear_highlights()
	game_ui.hide_end_turn()
	current_player += 1
	if current_player > player_count:
		current_player = 1
	current_player_changed.emit(current_player)
	_start_turn_flow()


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
	if game_over or _is_ai_turn() or forced_chain_piece == null:
		return
	_end_turn()


func _start_turn_flow() -> void:
	_turn_token += 1
	var token := _turn_token

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

	for coord in path:
		if token != _turn_token or game_over or not _is_ai_turn():
			return
		board_manager.move_piece(piece, coord)
		if focus_camera != null:
			focus_camera.focus_board_overview(human_player_id)
		await get_tree().create_timer(ai_step_delay).timeout

	if _did_current_player_win():
		game_over = true
		board_manager.clear_highlights()
		game_won.emit(current_player)
		return

	_end_turn()


func _is_ai_turn() -> bool:
	return current_player == ai_player_id
