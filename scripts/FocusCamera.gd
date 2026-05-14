class_name FocusCamera
extends Camera3D

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var view_side: float = 1.0
@export var focus_height: float = 12.4
@export var player_focus_distance: float = 10.8
@export var selected_focus_distance: float = 10.0
@export var overview_height: float = 13.4
@export var overview_distance: float = 12.2
@export var selected_piece_weight: float = 0.18
@export var focus_duration: float = 0.9
@export var selected_focus_duration: float = 0.65
@export var overview_focus_duration: float = 1.0
@export var default_fov: float = 49.0
@export var selected_fov: float = 47.0
@export var overview_fov: float = 53.0

@onready var board_manager = get_node(board_manager_path)

var _active_tween: Tween
var _current_player := 1


func focus_player(player_id: int) -> void:
	_current_player = player_id
	var focus_point: Vector3 = board_manager.get_player_piece_center(player_id)
	_move_to_focus(focus_point, view_side, player_focus_distance, default_fov, focus_duration)


func focus_player_ready(player_id: int) -> void:
	_current_player = player_id
	var focus_point: Vector3 = board_manager.get_player_piece_center(player_id)
	_move_to_focus(focus_point, view_side, player_focus_distance, default_fov, focus_duration)


func focus_board_overview(view_player_id: int) -> void:
	var focus_point: Vector3 = board_manager.get_board_center()
	_move_to_focus(focus_point, view_side, overview_distance, overview_fov, overview_focus_duration, overview_height)


func focus_selected_piece(piece) -> void:
	if piece == null:
		focus_player(_current_player)
		return

	var player_center: Vector3 = board_manager.get_player_piece_center(piece.player_id)
	var piece_focus: Vector3 = piece.global_position
	var focus_point: Vector3 = player_center.lerp(piece_focus, selected_piece_weight)
	_move_to_focus(focus_point, view_side, selected_focus_distance, selected_fov, selected_focus_duration, focus_height)


func _move_to_focus(focus_point: Vector3, side: float, distance: float, target_fov: float, duration: float, height := focus_height) -> void:
	var target_position := Vector3(focus_point.x, height, focus_point.z + side * distance)
	var target_transform := global_transform.looking_at(focus_point, Vector3.UP)
	target_transform.origin = target_position
	target_transform = target_transform.looking_at(focus_point, Vector3.UP)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "global_transform", target_transform, duration)
	_active_tween.tween_property(self, "fov", target_fov, duration)
