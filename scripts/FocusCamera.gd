class_name FocusCamera
extends Camera3D

signal camera_view_saved(view_name: String, summary: String)

@export var board_manager_path: NodePath = ^"../BoardManager"
@export var view_side: float = 1.0
@export var focus_height: float = 10.8
@export var player_focus_distance: float = 9.8
@export var selected_focus_distance: float = 9.2
@export var overview_height: float = 11.0
@export var overview_distance: float = 10.0
@export var selected_piece_weight: float = 0.06
@export var selected_piece_center_y_offset: float = 0.35
@export var selected_piece_pull_in: float = 0.12
@export var focus_duration: float = 0.9
@export var selected_focus_duration: float = 0.65
@export var selected_restore_duration: float = 0.45
@export var overview_focus_duration: float = 1.0
@export var side_focus_distance: float = 15.5
@export var side_focus_height: float = 11.0
@export var side_focus_duration: float = 1.8
@export var default_fov: float = 62.0
@export var selected_fov: float = 60.0
@export var overview_fov: float = 64.0
@export var keyboard_pan_speed: float = 8.0
@export var keyboard_pan_enabled := false
@export var orbit_sensitivity: float = 0.006
@export var zoom_step: float = 1.2
@export var zoom_smoothness: float = 7.5
@export var min_zoom_distance: float = 10.8
@export var max_zoom_distance: float = 16.5
@export var min_pitch_degrees: float = 48.0
@export var max_pitch_degrees: float = 88.0
@export var near_min_pitch_degrees: float = 80.0
@export var near_max_pitch_degrees: float = 86.0
@export var far_min_pitch_degrees: float = 60.0
@export var far_max_pitch_degrees: float = 66.0
@export var near_zoom_pitch_degrees: float = 84.0
@export var far_zoom_pitch_degrees: float = 62.0
@export var zoom_pitch_follow_strength: float = 0.42
@export var top_down_lock_zoom_ratio: float = 0.18
@export var near_zoom_fov: float = 70.0
@export var far_zoom_fov: float = 62.0
@export var zoom_fov_smoothness: float = 10.0
@export var focus_bounds_radius: float = 4.6
@export var camera_bounds_radius: float = 15.5
@export var min_camera_height: float = 7.4
@export var preserve_manual_view: bool = true

@onready var board_manager = get_node(board_manager_path)

const CAMERA_VIEW_CONFIG_PATH := "user://camera_views.cfg"

var _active_tween: Tween
var _current_player := 1
var _focus_point := Vector3.ZERO
var _manual_view_active := false
var _target_zoom_distance := 0.0
var _selection_focus_active := false
var _saved_selection_transform := Transform3D.IDENTITY
var _saved_selection_fov := 0.0
var _saved_selection_focus_point := Vector3.ZERO
var _saved_selection_zoom_distance := 0.0
var _saved_selection_manual_view_active := false
var _selection_focus_piece_id := 0


func _ready() -> void:
	focus_board_overview(_current_player)


func _process(delta: float) -> void:
	_update_keyboard_pan(delta)
	_update_smooth_zoom(delta)


func focus_player(player_id: int) -> void:
	_current_player = player_id
	if _should_keep_manual_view():
		return
	var focus_point: Vector3 = board_manager.get_player_piece_center(player_id)
	_move_to_focus(focus_point, view_side, player_focus_distance, default_fov, focus_duration)


func focus_player_ready(player_id: int) -> void:
	_current_player = player_id
	if _should_keep_manual_view():
		return
	focus_board_overview(player_id)


func focus_board_overview(_view_player_id: int) -> void:
	if _should_keep_manual_view():
		return
	var focus_point: Vector3 = board_manager.get_board_center()
	_move_to_focus(focus_point, view_side, overview_distance, overview_fov, overview_focus_duration, overview_height)


func focus_board_side(view_index: int) -> void:
	_stop_active_tween()
	_cancel_selection_focus()
	_manual_view_active = true

	var focus_point: Vector3 = _clamp_ground_point(board_manager.get_board_center(), focus_bounds_radius)
	_focus_point = focus_point

	var angle := -PI * 0.5 + TAU * float(posmod(view_index, 6)) / 6.0
	var direction := Vector3(cos(angle), 0.0, sin(angle)).normalized()
	var target_yaw := atan2(direction.x, direction.z)
	var target_distance := maxf(side_focus_distance, _get_floor_limited_min_zoom_distance_for_focus(focus_point))
	var target_pitch := _get_preferred_pitch_for_distance(target_distance)
	_target_zoom_distance = target_distance

	var start_focus := _focus_point
	if start_focus == Vector3.ZERO:
		start_focus = focus_point
	var start_offset := global_position - start_focus
	var start_distance := start_offset.length()
	if start_distance <= 0.001:
		start_distance = target_distance
		start_offset = _get_orbit_position(start_focus, target_yaw, target_pitch, start_distance) - start_focus
	var start_yaw := atan2(start_offset.x, start_offset.z)
	var start_pitch := asin(clampf(start_offset.y / start_distance, -1.0, 1.0))
	start_pitch = clampf(start_pitch, _get_pitch_range_for_distance(start_distance).x, _get_pitch_range_for_distance(start_distance).y)

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(
		Callable(self, "_tween_orbit_view").bind(
			start_focus,
			focus_point,
			start_yaw,
			target_yaw,
			start_pitch,
			target_pitch,
			start_distance,
			target_distance
		),
		0.0,
		1.0,
		side_focus_duration
	)
	_active_tween.tween_property(self, "fov", overview_fov, side_focus_duration)


func focus_selected_piece(piece) -> void:
	if piece == null:
		restore_selected_piece_view()
		return

	_start_selected_piece_focus(piece)


func restore_selected_piece_view() -> void:
	if not _selection_focus_active:
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_focus_point = _saved_selection_focus_point
	_target_zoom_distance = _saved_selection_zoom_distance
	_manual_view_active = _saved_selection_manual_view_active

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_property(self, "global_transform", _saved_selection_transform, selected_restore_duration)
	_active_tween.parallel().tween_property(self, "fov", _saved_selection_fov, selected_restore_duration)
	_active_tween.chain().tween_callback(_finish_selected_piece_restore)


func save_named_view(view_name: String) -> Dictionary:
	var clean_name := _sanitize_view_name(view_name)
	var config := ConfigFile.new()
	var load_result := config.load(CAMERA_VIEW_CONFIG_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		return {
			"ok": false,
			"name": clean_name,
			"summary": "Failed to load camera view config: %d" % load_result,
		}

	config.set_value(clean_name, "position", global_position)
	config.set_value(clean_name, "rotation_degrees", rotation_degrees)
	config.set_value(clean_name, "fov", fov)
	config.set_value(clean_name, "focus_point", _focus_point)
	config.set_value(clean_name, "distance", global_position.distance_to(_focus_point))
	config.set_value(clean_name, "saved_at", Time.get_datetime_string_from_system(false, true))

	var save_result := config.save(CAMERA_VIEW_CONFIG_PATH)
	if save_result != OK:
		return {
			"ok": false,
			"name": clean_name,
			"summary": "Failed to save camera view config: %d" % save_result,
		}

	var summary := _format_view_summary(clean_name)
	camera_view_saved.emit(clean_name, summary)
	return {
		"ok": true,
		"name": clean_name,
		"summary": summary,
	}


func get_current_view_summary() -> String:
	return _format_view_summary("current")


func _format_view_summary(view_name: String) -> String:
	return "%s | pos=(%.2f, %.2f, %.2f) rot=(%.1f, %.1f, %.1f) fov=%.1f focus=(%.2f, %.2f, %.2f) dist=%.2f" % [
		view_name,
		global_position.x,
		global_position.y,
		global_position.z,
		rotation_degrees.x,
		rotation_degrees.y,
		rotation_degrees.z,
		fov,
		_focus_point.x,
		_focus_point.y,
		_focus_point.z,
		global_position.distance_to(_focus_point),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_set_zoom_target(-zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_set_zoom_target(zoom_step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if motion_event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_orbit_view(motion_event.relative)
			get_viewport().set_input_as_handled()


func _move_to_focus(focus_point: Vector3, side: float, distance: float, target_fov: float, duration: float, height := focus_height) -> void:
	focus_point = _clamp_ground_point(focus_point, focus_bounds_radius)
	_focus_point = focus_point
	var target_position := Vector3(focus_point.x, height, focus_point.z + side * distance)
	target_position = _clamp_camera_position(target_position, focus_point)
	_target_zoom_distance = target_position.distance_to(focus_point)
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


func _start_selected_piece_focus(piece) -> void:
	var piece_id := int(piece.get_instance_id())
	if _selection_focus_active and piece_id == _selection_focus_piece_id:
		return

	if not _selection_focus_active:
		_saved_selection_transform = global_transform
		_saved_selection_fov = fov
		_saved_selection_focus_point = _focus_point
		_saved_selection_zoom_distance = global_position.distance_to(_focus_point)
		_saved_selection_manual_view_active = _manual_view_active
		_selection_focus_active = true

	_selection_focus_piece_id = piece_id
	var board_focus := _get_board_focus_point()
	var piece_focus := _clamp_ground_point(piece.global_position, focus_bounds_radius)
	var focus_point: Vector3 = board_focus.lerp(piece_focus, selected_piece_weight) + Vector3.UP * selected_piece_center_y_offset
	_focus_point = focus_point
	_manual_view_active = false

	var offset := global_position - focus_point
	var current_distance := offset.length()
	if current_distance <= 0.001:
		current_distance = _get_floor_limited_min_zoom_distance_for_focus(focus_point)
		offset = global_position - board_focus
	var yaw := atan2(offset.x, offset.z)
	var current_pitch := asin(clampf(offset.y / current_distance, -1.0, 1.0))
	var target_distance := clampf(
		current_distance - selected_piece_pull_in,
		_get_floor_limited_min_zoom_distance_for_focus(focus_point),
		max_zoom_distance
	)
	var pitch_range := _get_pitch_range_for_distance(target_distance)
	var target_pitch := clampf(current_pitch, pitch_range.x, pitch_range.y)
	var target_position := _get_orbit_position(focus_point, yaw, target_pitch, target_distance)
	target_position = _clamp_camera_position(target_position, focus_point)
	_target_zoom_distance = target_position.distance_to(focus_point)

	var target_transform := global_transform
	target_transform.origin = target_position
	target_transform = target_transform.looking_at(focus_point, Vector3.UP)
	var target_fov := lerpf(fov, _get_preferred_fov_for_distance(_target_zoom_distance), 0.25)

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_property(self, "global_transform", target_transform, selected_focus_duration)
	_active_tween.parallel().tween_property(self, "fov", target_fov, selected_focus_duration)


func _update_keyboard_pan(delta: float) -> void:
	if not keyboard_pan_enabled:
		return
	if _is_text_input_focused():
		return

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0

	if input_vector == Vector2.ZERO:
		return

	_cancel_selection_focus()
	_stop_active_tween()
	_manual_view_active = true

	var camera_right := global_transform.basis.x.normalized()
	var camera_forward := -global_transform.basis.z.normalized()
	var ground_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
	if ground_forward.length_squared() < 0.0001:
		ground_forward = Vector3.FORWARD
	else:
		ground_forward = ground_forward.normalized()

	var ground_right := Vector3(camera_right.x, 0.0, camera_right.z)
	if ground_right.length_squared() < 0.0001:
		ground_right = Vector3.RIGHT
	else:
		ground_right = ground_right.normalized()

	var requested_offset := (ground_right * input_vector.x + ground_forward * input_vector.y) * keyboard_pan_speed * delta
	var next_focus := _clamp_ground_point(_focus_point + requested_offset, focus_bounds_radius)
	var actual_offset := next_focus - _focus_point
	global_position = _clamp_camera_position(global_position + actual_offset, next_focus)
	_focus_point = next_focus


func _orbit_view(mouse_delta: Vector2) -> void:
	_release_selection_focus_to_board_orbit()
	_cancel_selection_focus()
	_stop_active_tween()
	_manual_view_active = true

	var offset := global_position - _focus_point
	var current_distance := offset.length()
	if current_distance <= 0.001:
		return

	var yaw := atan2(offset.x, offset.z) - mouse_delta.x * orbit_sensitivity
	var pitch := asin(clampf(offset.y / current_distance, -1.0, 1.0)) - mouse_delta.y * orbit_sensitivity
	var pitch_range := _get_pitch_range_for_distance(current_distance)
	pitch = clampf(pitch, pitch_range.x, pitch_range.y)

	var horizontal_distance := cos(pitch) * current_distance
	var rotated_offset := Vector3(
		sin(yaw) * horizontal_distance,
		sin(pitch) * current_distance,
		cos(yaw) * horizontal_distance
	)
	global_position = _clamp_camera_position(_focus_point + rotated_offset, _focus_point)
	_target_zoom_distance = current_distance
	look_at(_focus_point, Vector3.UP)


func _set_zoom_target(distance_delta: float) -> void:
	_release_selection_focus_to_board_orbit()
	_cancel_selection_focus()
	_stop_active_tween()
	_manual_view_active = true

	if _target_zoom_distance <= 0.001:
		_target_zoom_distance = global_position.distance_to(_focus_point)

	var floor_limited_min_distance := _get_floor_limited_min_zoom_distance()
	_target_zoom_distance = clampf(_target_zoom_distance + distance_delta, floor_limited_min_distance, max_zoom_distance)


func _update_smooth_zoom(delta: float) -> void:
	if _selection_focus_active:
		return
	if not _manual_view_active or _target_zoom_distance <= 0.001:
		return

	var offset := global_position - _focus_point
	var current_distance := offset.length()
	if current_distance <= 0.001:
		return
	if absf(current_distance - _target_zoom_distance) <= 0.001:
		return

	var blend := 1.0 - exp(-zoom_smoothness * delta)
	var next_distance := lerpf(current_distance, _target_zoom_distance, blend)
	var top_down_weight := _get_top_down_lock_weight(next_distance)
	var board_focus := _get_board_focus_point()
	var next_focus := _focus_point.lerp(board_focus, top_down_weight * blend)
	var yaw := atan2(offset.x, offset.z)
	var current_pitch := asin(clampf(offset.y / current_distance, -1.0, 1.0))
	var target_pitch := _get_preferred_pitch_for_distance(next_distance)
	var pitch_blend := clampf(blend * zoom_pitch_follow_strength, 0.0, 1.0)
	var next_pitch := lerp_angle(current_pitch, target_pitch, pitch_blend)
	next_pitch = clampf(next_pitch, _get_pitch_range_for_distance(next_distance).x, _get_pitch_range_for_distance(next_distance).y)
	var next_position := _get_orbit_position(next_focus, yaw, next_pitch, next_distance)
	_focus_point = next_focus
	global_position = _clamp_camera_position(next_position, _focus_point)
	var target_fov := _get_preferred_fov_for_distance(next_distance)
	var fov_blend := 1.0 - exp(-zoom_fov_smoothness * delta)
	fov = lerpf(fov, target_fov, fov_blend)
	look_at(_focus_point, Vector3.UP)


func _stop_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()


func _cancel_selection_focus() -> void:
	_selection_focus_active = false
	_selection_focus_piece_id = 0


func _release_selection_focus_to_board_orbit() -> void:
	if not _selection_focus_active:
		return

	var board_focus := _get_board_focus_point()
	var offset := global_position - board_focus
	var distance := maxf(offset.length(), _get_floor_limited_min_zoom_distance_for_focus(board_focus))
	if distance <= 0.001:
		distance = _get_floor_limited_min_zoom_distance_for_focus(board_focus)

	var yaw := atan2(offset.x, offset.z)
	var pitch := _get_preferred_pitch_for_distance(distance)
	if offset.length() > 0.001:
		pitch = asin(clampf(offset.y / offset.length(), -1.0, 1.0))
	var pitch_range := _get_pitch_range_for_distance(distance)
	pitch = clampf(pitch, pitch_range.x, pitch_range.y)

	_focus_point = board_focus
	_target_zoom_distance = distance
	global_position = _clamp_camera_position(_get_orbit_position(_focus_point, yaw, pitch, distance), _focus_point)
	look_at(_focus_point, Vector3.UP)


func _finish_selected_piece_restore() -> void:
	_selection_focus_active = false
	_selection_focus_piece_id = 0
	_target_zoom_distance = global_position.distance_to(_focus_point)


func _should_keep_manual_view() -> bool:
	return preserve_manual_view and _manual_view_active


func _clamp_ground_point(point: Vector3, radius: float) -> Vector3:
	var flat := Vector2(point.x, point.z)
	if flat.length() > radius:
		flat = flat.normalized() * radius
	return Vector3(flat.x, point.y, flat.y)


func _get_board_focus_point() -> Vector3:
	return _clamp_ground_point(board_manager.get_board_center(), focus_bounds_radius)


func _get_orbit_position(focus_point: Vector3, yaw: float, pitch: float, distance: float) -> Vector3:
	var horizontal_distance := cos(pitch) * distance
	return focus_point + Vector3(
		sin(yaw) * horizontal_distance,
		sin(pitch) * distance,
		cos(yaw) * horizontal_distance
	)


func _tween_orbit_view(
	progress: float,
	start_focus: Vector3,
	target_focus: Vector3,
	start_yaw: float,
	target_yaw: float,
	start_pitch: float,
	target_pitch: float,
	start_distance: float,
	target_distance: float
) -> void:
	var curve_t := smoothstep(0.0, 1.0, progress)
	_focus_point = start_focus.lerp(target_focus, curve_t)
	var distance := lerpf(start_distance, target_distance, curve_t)
	var yaw := lerp_angle(start_yaw, target_yaw, curve_t)
	var pitch := lerp_angle(start_pitch, target_pitch, curve_t)
	var pitch_range := _get_pitch_range_for_distance(distance)
	pitch = clampf(pitch, pitch_range.x, pitch_range.y)
	global_position = _clamp_camera_position(_get_orbit_position(_focus_point, yaw, pitch, distance), _focus_point)
	look_at(_focus_point, Vector3.UP)


func _clamp_camera_position(position: Vector3, focus_point: Vector3) -> Vector3:
	position = _clamp_camera_orbit_angle(position, focus_point)

	var flat := Vector2(position.x, position.z)
	if flat.length() > camera_bounds_radius:
		flat = flat.normalized() * camera_bounds_radius
		position.x = flat.x
		position.z = flat.y
	return position


func _clamp_camera_orbit_angle(position: Vector3, focus_point: Vector3) -> Vector3:
	var offset := position - focus_point
	var distance := offset.length()
	if distance <= 0.001:
		return position

	var horizontal := Vector2(offset.x, offset.z)
	var yaw := atan2(offset.x, offset.z)
	if horizontal.length_squared() <= 0.0001:
		var current_offset := global_position - focus_point
		yaw = atan2(current_offset.x, current_offset.z)

	var pitch := asin(clampf(offset.y / distance, -1.0, 1.0))
	var pitch_range := _get_pitch_range_for_distance(distance)
	var min_pitch := pitch_range.x
	var max_pitch := pitch_range.y
	pitch = clampf(pitch, min_pitch, max_pitch)

	var min_height_offset := maxf(min_camera_height - focus_point.y, 0.0)
	if min_height_offset > 0.0 and sin(pitch) * distance < min_height_offset:
		var required_pitch := asin(clampf(min_height_offset / maxf(distance, 0.001), -1.0, 1.0))
		if required_pitch <= max_pitch:
			pitch = maxf(pitch, required_pitch)
		else:
			pitch = max_pitch
			distance = maxf(distance, min_height_offset / maxf(sin(max_pitch), 0.001))

	var horizontal_distance := cos(pitch) * distance
	return focus_point + Vector3(
		sin(yaw) * horizontal_distance,
		sin(pitch) * distance,
		cos(yaw) * horizontal_distance
	)


func _get_floor_limited_min_zoom_distance() -> float:
	return _get_floor_limited_min_zoom_distance_for_focus(_focus_point)


func _get_floor_limited_min_zoom_distance_for_focus(focus_point: Vector3) -> float:
	var min_height_offset := maxf(min_camera_height - focus_point.y, 0.0)
	var result := min_zoom_distance

	if min_height_offset > 0.0:
		var max_pitch := deg_to_rad(max_pitch_degrees)
		var height_limited_distance := min_height_offset / maxf(sin(max_pitch), 0.001)
		result = maxf(result, height_limited_distance)

	return maxf(result, _get_board_fit_min_zoom_distance_for_focus(focus_point))


func _get_board_fit_min_zoom_distance_for_focus(focus_point: Vector3) -> float:
	if board_manager == null or board_manager.cells.is_empty():
		return min_zoom_distance

	var max_board_radius := 0.0
	for cell in board_manager.cells.values():
		if cell == null:
			continue
		var flat := Vector2(cell.global_position.x - focus_point.x, cell.global_position.z - focus_point.z)
		max_board_radius = maxf(max_board_radius, flat.length())

	var fit_fov := deg_to_rad(maxf(near_zoom_fov, overview_fov))
	var fit_distance := max_board_radius / maxf(tan(fit_fov * 0.5), 0.001)
	return fit_distance * 1.04


func _get_pitch_range_for_distance(distance: float) -> Vector2:
	var zoom_t := _get_zoom_ratio(distance)
	var curve_t := smoothstep(0.0, 1.0, zoom_t)
	var min_pitch := deg_to_rad(lerpf(near_min_pitch_degrees, far_min_pitch_degrees, curve_t))
	var max_pitch := deg_to_rad(lerpf(near_max_pitch_degrees, far_max_pitch_degrees, curve_t))
	var hard_min := deg_to_rad(min_pitch_degrees)
	var hard_max := deg_to_rad(max_pitch_degrees)
	min_pitch = clampf(min_pitch, hard_min, hard_max)
	max_pitch = clampf(max_pitch, min_pitch, hard_max)
	return Vector2(min_pitch, max_pitch)


func _get_preferred_pitch_for_distance(distance: float) -> float:
	var zoom_t := _get_zoom_ratio(distance)
	var curve_t := smoothstep(0.0, 1.0, zoom_t)
	var preferred_pitch := deg_to_rad(lerpf(near_zoom_pitch_degrees, far_zoom_pitch_degrees, curve_t))
	var pitch_range := _get_pitch_range_for_distance(distance)
	return clampf(preferred_pitch, pitch_range.x, pitch_range.y)


func _get_preferred_fov_for_distance(distance: float) -> float:
	var zoom_t := _get_zoom_ratio(distance)
	var curve_t := smoothstep(0.0, 1.0, zoom_t)
	return lerpf(near_zoom_fov, far_zoom_fov, curve_t)


func _get_top_down_lock_weight(distance: float) -> float:
	var lock_ratio := clampf(top_down_lock_zoom_ratio, 0.001, 1.0)
	var zoom_t := _get_zoom_ratio(distance)
	return 1.0 - smoothstep(0.0, lock_ratio, zoom_t)


func _get_zoom_ratio(distance: float) -> float:
	var zoom_range := maxf(max_zoom_distance - min_zoom_distance, 0.001)
	return clampf((distance - min_zoom_distance) / zoom_range, 0.0, 1.0)


func _sanitize_view_name(view_name: String) -> String:
	var clean_name := view_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "camera_view"
	return clean_name.replace("/", "_").replace("\\", "_").replace("[", "(").replace("]", ")")


func _is_text_input_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit
