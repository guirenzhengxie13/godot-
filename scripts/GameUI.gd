class_name GameUI
extends CanvasLayer

const START_MENU_HERO_PATH := "res://assets/ui/start_menu_hero.png"

signal restart_requested
signal end_turn_requested
signal test_layout_requested
signal save_camera_view_requested(view_name: String)
signal create_online_room_requested(signaling_url: String)
signal join_online_room_requested(room_code: String, signaling_url: String)
signal local_mode_requested
signal ai_takeover_toggled(enabled: bool)
signal save_match_record_requested
signal load_match_record_requested
signal replay_start_requested
signal replay_stop_requested
signal replay_play_toggled(playing: bool)
signal replay_step_requested(step_index: int)
signal replay_previous_requested
signal replay_next_requested
signal undo_turn_requested
signal restart_with_seed_requested(seed_text: String)
signal analysis_mode_toggled(enabled: bool)
signal material_selected(target: String, material_id: String)
signal lighting_preset_selected(preset_id: String)
signal render_cost_profile_selected(profile_id: String)
signal time_of_day_selected(hour: float)
signal auto_time_cycle_toggled(enabled: bool)
signal lighting_value_changed(parameter: String, value: float)
signal save_lighting_requested
signal reset_lighting_requested

@export var current_player_label_path: NodePath = ^"MarginContainer/VBoxContainer/CurrentPlayerLabel"
@export var turn_prompt_label_path: NodePath = ^"MarginContainer/VBoxContainer/TurnPromptLabel"
@export var end_turn_button_path: NodePath = ^"MarginContainer/VBoxContainer/EndTurnButton"
@export var test_layout_button_path: NodePath = ^"MarginContainer/VBoxContainer/TestLayoutButton"
@export var restart_button_path: NodePath = ^"MarginContainer/VBoxContainer/RestartButton"
@export var victory_panel_path: NodePath = ^"MarginContainer/VictoryPanel"
@export var victory_label_path: NodePath = ^"MarginContainer/VictoryPanel/VictoryBox/VictoryLabel"
@export var play_again_button_path: NodePath = ^"MarginContainer/VictoryPanel/VictoryBox/PlayAgainButton"

@onready var current_player_label: Label = get_node(current_player_label_path) as Label
@onready var turn_prompt_label: Label = get_node(turn_prompt_label_path) as Label
@onready var end_turn_button: Button = get_node(end_turn_button_path) as Button
@onready var test_layout_button: Button = get_node(test_layout_button_path) as Button
@onready var restart_button: Button = get_node(restart_button_path) as Button
@onready var victory_panel: Control = get_node(victory_panel_path) as Control
@onready var victory_label: Label = get_node(victory_label_path) as Label
@onready var play_again_button: Button = get_node(play_again_button_path) as Button

var _start_menu: Control
var _pause_menu: Control
var _lighting_menu: Control
var _right_end_turn_button: Button
var _pause_button: Button
var _analysis_button: Button
var _analysis_status_label: Label
var _analysis_button_syncing := false
var _signaling_url_input: LineEdit
var _network_room_code_input: LineEdit
var _network_status_label: Label
var _start_status_label: Label
var _room_code_label: Label
var _player_role_label: Label
var _camera_view_name_input: LineEdit
var _camera_view_status_label: Label
var _camera_view_save_count := 1
var _start_ai_takeover_checkbox: CheckBox
var _pause_ai_takeover_checkbox: CheckBox
var _match_record_status_label: Label
var _replay_bar: Control
var _replay_play_button: Button
var _replay_slider: HSlider
var _replay_step_label: Label
var _replay_slider_updating := false
var _turn_step_panel: PanelContainer
var _turn_step_label: Label
var _undo_turn_button: Button
var _selected_skill_label: Label
var _selected_skill_description_label: Label
var _seed_input: LineEdit
var _seed_status_label: Label
var _ai_checkbox_syncing := false
var _material_options: Array[Dictionary] = []
var _material_selection: Dictionary = {}
var _board_material_option: OptionButton
var _player_one_material_option: OptionButton
var _player_two_material_option: OptionButton
var _lighting_preset_options: Array[Dictionary] = []
var _lighting_preset_option: OptionButton
var _render_cost_profile_options: Array[Dictionary] = []
var _render_cost_profile_option: OptionButton
var _render_cost_profile_summary_label: Label
var _time_of_day_options: Array[Dictionary] = []
var _time_of_day_button_row: HBoxContainer
var _auto_time_cycle_checkbox: CheckBox
var _auto_time_cycle_syncing := false
var _lighting_sliders: Dictionary = {}
var _lighting_value_labels: Dictionary = {}
var _lighting_status_label: Label
var _lighting_controls_syncing := false


func _ready() -> void:
	_prepare_legacy_controls()
	_build_hud_controls()
	_build_replay_controls()
	_build_start_menu()
	_build_pause_menu()
	_build_lighting_menu()
	_apply_button_styles(self)
	hide_end_turn()
	hide_victory()
	show_start_menu()


func set_current_player(player_id: int) -> void:
	current_player_label.text = "当前玩家：玩家 %d" % player_id


func show_human_turn() -> void:
	turn_prompt_label.text = "轮到你操作"
	hide_end_turn()


func show_ai_turn() -> void:
	turn_prompt_label.text = "对手正在思考..."
	hide_end_turn()


func show_remote_turn() -> void:
	turn_prompt_label.text = "等待对手操作..."
	hide_end_turn()


func show_continue_jump() -> void:
	turn_prompt_label.text = "可以继续跳跃，也可以结束回合"
	if _right_end_turn_button != null:
		_right_end_turn_button.visible = true


func show_turn_pending_end() -> void:
	turn_prompt_label.text = "空格结束回合，也可以撤回上一步"
	if _right_end_turn_button != null:
		_right_end_turn_button.visible = true


func show_test_layout_ready() -> void:
	turn_prompt_label.text = "测试布局：连续跳跃进营即可获胜"
	hide_end_turn()


func hide_end_turn() -> void:
	end_turn_button.visible = false
	if _right_end_turn_button != null:
		_right_end_turn_button.visible = false


func show_victory(player_id: int) -> void:
	victory_label.text = "玩家 %d 获胜" % player_id
	victory_panel.visible = true


func hide_victory() -> void:
	victory_panel.visible = false


func set_network_status(status: String) -> void:
	var text := "联机状态：%s" % status
	if _network_status_label != null:
		_network_status_label.text = text
	if _start_status_label != null:
		_start_status_label.text = text


func set_online_room_code(room_code: String) -> void:
	if _room_code_label == null:
		return
	if room_code.is_empty():
		_room_code_label.text = "房间码：-"
	else:
		_room_code_label.text = "房间码：%s" % room_code


func set_online_player_role(player_id: int, is_host: bool) -> void:
	if _player_role_label == null:
		return
	var host_text := "房主" if is_host else "加入者"
	_player_role_label.text = "在线身份：玩家 %d（%s）" % [player_id, host_text]


func show_local_mode() -> void:
	set_network_status("本地 AI 模式")
	set_online_room_code("")
	if _player_role_label != null:
		_player_role_label.text = "在线身份：-"


func show_camera_view_saved(_view_name: String, summary: String) -> void:
	if _camera_view_status_label == null:
		return
	_camera_view_status_label.text = "Saved: %s" % summary


func show_camera_view_error(message: String) -> void:
	if _camera_view_status_label == null:
		return
	_camera_view_status_label.text = message


func set_ai_takeover_enabled(enabled: bool) -> void:
	_ai_checkbox_syncing = true
	if _start_ai_takeover_checkbox != null:
		_start_ai_takeover_checkbox.button_pressed = enabled
	if _pause_ai_takeover_checkbox != null:
		_pause_ai_takeover_checkbox.button_pressed = enabled
	_ai_checkbox_syncing = false


func set_match_record_status(status: String) -> void:
	if _match_record_status_label != null:
		_match_record_status_label.text = status


func show_replay_controls(visible: bool) -> void:
	if _replay_bar != null:
		_replay_bar.visible = visible


func set_replay_state(active: bool, playing: bool, current_step: int, total_steps: int) -> void:
	show_replay_controls(active)
	if _replay_play_button != null:
		_replay_play_button.text = "暂停" if playing else "播放"
	if _replay_step_label != null:
		_replay_step_label.text = "%d / %d" % [current_step, total_steps]
	if _replay_slider != null:
		_replay_slider_updating = true
		_replay_slider.max_value = max(0, total_steps)
		_replay_slider.value = clampi(current_step, 0, total_steps)
		_replay_slider_updating = false


func set_turn_step_count(step_count: int, can_undo: bool) -> void:
	if _turn_step_label != null:
		_turn_step_label.text = "本回合步数：%d" % step_count
	if _undo_turn_button != null:
		_undo_turn_button.disabled = not can_undo


func set_selected_piece_skill(skill_name: String, description: String, immobilized: bool) -> void:
	if _selected_skill_label != null:
		_selected_skill_label.text = "技能：%s%s" % [skill_name, "（已定身）" if immobilized else ""]
	if _selected_skill_description_label != null:
		_selected_skill_description_label.text = description


func clear_selected_piece_skill() -> void:
	if _selected_skill_label != null:
		_selected_skill_label.text = "技能：未选择棋子"
	if _selected_skill_description_label != null:
		_selected_skill_description_label.text = ""


func set_skill_seed(seed_value: int, enabled: bool) -> void:
	if _seed_status_label != null:
		_seed_status_label.text = "技能种子：%s" % (str(seed_value) if enabled else "标准规则")
	if _seed_input != null and enabled:
		_seed_input.text = str(seed_value)


func set_analysis_mode(enabled: bool) -> void:
	if _analysis_button == null:
		return
	_analysis_button_syncing = true
	_analysis_button.button_pressed = enabled
	_analysis_button.modulate = Color(0.5, 0.88, 1.0) if enabled else Color.WHITE
	_analysis_button_syncing = false
	if _analysis_status_label != null:
		_analysis_status_label.visible = enabled
		if enabled:
			_analysis_status_label.text = "观察模式：选择任意棋子查看技能规则可达区域"


func set_analysis_status(status: String) -> void:
	if _analysis_status_label != null:
		_analysis_status_label.text = status


func set_material_options(options: Array[Dictionary]) -> void:
	_material_options = options.duplicate(true)
	_populate_material_option(_board_material_option, "board", String(_material_selection.get("board", "default")))
	_populate_material_option(_player_one_material_option, "player", String(_material_selection.get("player_1", "default")))
	_populate_material_option(_player_two_material_option, "player", String(_material_selection.get("player_2", "default")))


func set_material_selection(selection: Dictionary) -> void:
	_material_selection = selection.duplicate(true)
	_select_material_option(_board_material_option, String(_material_selection.get("board", "default")))
	_select_material_option(_player_one_material_option, String(_material_selection.get("player_1", "default")))
	_select_material_option(_player_two_material_option, String(_material_selection.get("player_2", "default")))


func set_lighting_presets(options: Array[Dictionary]) -> void:
	_lighting_preset_options = options.duplicate(true)
	_populate_lighting_preset_option()


func set_render_cost_profiles(options: Array[Dictionary]) -> void:
	_render_cost_profile_options = options.duplicate(true)
	_populate_render_cost_profile_option()


func set_render_cost_profile(profile: Dictionary) -> void:
	_lighting_controls_syncing = true
	_select_render_cost_profile(String(profile.get("id", "high")))
	_update_render_cost_profile_summary(String(profile.get("summary", "")))
	_lighting_controls_syncing = false


func set_time_of_day_presets(options: Array[Dictionary]) -> void:
	_time_of_day_options = options.duplicate(true)
	_populate_time_of_day_buttons()


func set_auto_time_cycle_enabled(enabled: bool) -> void:
	_auto_time_cycle_syncing = true
	if _auto_time_cycle_checkbox != null:
		_auto_time_cycle_checkbox.button_pressed = enabled
	_auto_time_cycle_syncing = false


func set_lighting_settings(settings: Dictionary) -> void:
	_lighting_controls_syncing = true
	_select_lighting_preset(String(settings.get("preset_id", "custom")))
	_select_render_cost_profile(String(settings.get("render_cost_profile_id", "high")))
	for parameter in _lighting_sliders.keys():
		var slider: HSlider = _lighting_sliders[parameter]
		slider.value = float(settings.get(parameter, slider.value))
		_update_lighting_value_label(parameter, slider.value)
	_lighting_controls_syncing = false


func show_lighting_status(status: String) -> void:
	if _lighting_status_label != null:
		_lighting_status_label.text = status


func show_start_menu() -> void:
	hide_end_turn()
	if _start_menu != null:
		_start_menu.visible = true
	if _pause_menu != null:
		_pause_menu.visible = false
	if _lighting_menu != null:
		_lighting_menu.visible = false
	if _pause_button != null:
		_pause_button.visible = false
	if _analysis_button != null:
		_analysis_button.visible = false


func hide_start_menu() -> void:
	if _start_menu != null:
		_start_menu.visible = false
	if _pause_button != null:
		_pause_button.visible = true
	if _analysis_button != null:
		_analysis_button.visible = true


func _prepare_legacy_controls() -> void:
	end_turn_button.visible = false
	test_layout_button.visible = false
	restart_button.visible = false
	play_again_button.text = "再来一局"
	play_again_button.pressed.connect(_on_restart_pressed)
	current_player_label.text = "当前玩家：玩家 1"
	turn_prompt_label.text = "请选择模式"


func _build_hud_controls() -> void:
	var controls_box := current_player_label.get_parent() as VBoxContainer
	if controls_box != null:
		controls_box.custom_minimum_size = Vector2(220.0, 0.0)
		_network_status_label = Label.new()
		_network_status_label.text = "联机状态：本地 AI 模式"
		_network_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		controls_box.add_child(_network_status_label)

		_room_code_label = Label.new()
		_room_code_label.text = "房间码：-"
		controls_box.add_child(_room_code_label)

		_player_role_label = Label.new()
		_player_role_label.text = "在线身份：-"
		controls_box.add_child(_player_role_label)

		_analysis_status_label = Label.new()
		_analysis_status_label.visible = false
		_analysis_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_analysis_status_label.custom_minimum_size = Vector2(300.0, 0.0)
		controls_box.add_child(_analysis_status_label)

	_pause_button = Button.new()
	_pause_button.text = "暂停"
	_pause_button.custom_minimum_size = Vector2(72.0, 36.0)
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_right = 1.0
	_pause_button.offset_left = -96.0
	_pause_button.offset_top = 16.0
	_pause_button.offset_right = -16.0
	_pause_button.offset_bottom = 52.0
	_pause_button.pressed.connect(_on_pause_pressed)
	add_child(_pause_button)

	_analysis_button = Button.new()
	_analysis_button.text = "◉"
	_analysis_button.tooltip_text = "观察盘面冻结情况与棋子可达区域"
	_analysis_button.toggle_mode = true
	_analysis_button.custom_minimum_size = Vector2(76.0, 68.0)
	_analysis_button.add_theme_font_size_override("font_size", 38)
	_analysis_button.anchor_left = 1.0
	_analysis_button.anchor_top = 0.5
	_analysis_button.anchor_right = 1.0
	_analysis_button.anchor_bottom = 0.5
	_analysis_button.offset_left = -100.0
	_analysis_button.offset_top = -126.0
	_analysis_button.offset_right = -18.0
	_analysis_button.offset_bottom = -52.0
	_analysis_button.toggled.connect(_on_analysis_button_toggled)
	add_child(_analysis_button)

	_right_end_turn_button = Button.new()
	_right_end_turn_button.text = "结束\n回合"
	_right_end_turn_button.custom_minimum_size = Vector2(82.0, 58.0)
	_right_end_turn_button.anchor_left = 1.0
	_right_end_turn_button.anchor_top = 0.5
	_right_end_turn_button.anchor_right = 1.0
	_right_end_turn_button.anchor_bottom = 0.5
	_right_end_turn_button.offset_left = -104.0
	_right_end_turn_button.offset_top = -29.0
	_right_end_turn_button.offset_right = -16.0
	_right_end_turn_button.offset_bottom = 29.0
	_right_end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(_right_end_turn_button)

	_turn_step_panel = PanelContainer.new()
	_turn_step_panel.anchor_left = 0.0
	_turn_step_panel.anchor_top = 1.0
	_turn_step_panel.anchor_right = 0.0
	_turn_step_panel.anchor_bottom = 1.0
	_turn_step_panel.offset_left = 16.0
	_turn_step_panel.offset_top = -128.0
	_turn_step_panel.offset_right = 360.0
	_turn_step_panel.offset_bottom = -16.0
	_style_panel(_turn_step_panel, Color(0.04, 0.06, 0.055, 0.82), Color(0.38, 0.48, 0.43, 0.54))
	add_child(_turn_step_panel)

	var step_margin := MarginContainer.new()
	step_margin.add_theme_constant_override("margin_left", 10)
	step_margin.add_theme_constant_override("margin_top", 8)
	step_margin.add_theme_constant_override("margin_right", 10)
	step_margin.add_theme_constant_override("margin_bottom", 8)
	_turn_step_panel.add_child(step_margin)

	var step_box := VBoxContainer.new()
	step_box.add_theme_constant_override("separation", 3)
	step_margin.add_child(step_box)

	var step_row := HBoxContainer.new()
	step_row.add_theme_constant_override("separation", 8)
	step_box.add_child(step_row)

	_turn_step_label = Label.new()
	_turn_step_label.text = "本回合步数：0"
	_turn_step_label.custom_minimum_size = Vector2(120.0, 0.0)
	step_row.add_child(_turn_step_label)

	_undo_turn_button = Button.new()
	_undo_turn_button.text = "撤回一步"
	_undo_turn_button.disabled = true
	_undo_turn_button.pressed.connect(func(): undo_turn_requested.emit())
	step_row.add_child(_undo_turn_button)

	_selected_skill_label = Label.new()
	_selected_skill_label.text = "技能：未选择棋子"
	step_box.add_child(_selected_skill_label)

	_selected_skill_description_label = Label.new()
	_selected_skill_description_label.text = ""
	_selected_skill_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_skill_description_label.custom_minimum_size = Vector2(320.0, 0.0)
	step_box.add_child(_selected_skill_description_label)


func _build_replay_controls() -> void:
	_replay_bar = PanelContainer.new()
	_replay_bar.visible = false
	_replay_bar.anchor_left = 0.5
	_replay_bar.anchor_top = 1.0
	_replay_bar.anchor_right = 0.5
	_replay_bar.anchor_bottom = 1.0
	_replay_bar.offset_left = -310.0
	_replay_bar.offset_top = -74.0
	_replay_bar.offset_right = 310.0
	_replay_bar.offset_bottom = -16.0
	_style_panel(_replay_bar, Color(0.04, 0.06, 0.055, 0.88), Color(0.38, 0.48, 0.43, 0.58))
	add_child(_replay_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_replay_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var prev_button := Button.new()
	prev_button.text = "<"
	prev_button.custom_minimum_size = Vector2(36.0, 36.0)
	prev_button.pressed.connect(func(): replay_previous_requested.emit())
	row.add_child(prev_button)

	_replay_play_button = Button.new()
	_replay_play_button.text = "播放"
	_replay_play_button.custom_minimum_size = Vector2(64.0, 36.0)
	_replay_play_button.pressed.connect(_on_replay_play_pressed)
	row.add_child(_replay_play_button)

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size = Vector2(36.0, 36.0)
	next_button.pressed.connect(func(): replay_next_requested.emit())
	row.add_child(next_button)

	_replay_slider = HSlider.new()
	_replay_slider.min_value = 0.0
	_replay_slider.max_value = 0.0
	_replay_slider.step = 1.0
	_replay_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_slider.value_changed.connect(_on_replay_slider_changed)
	row.add_child(_replay_slider)

	_replay_step_label = Label.new()
	_replay_step_label.text = "0 / 0"
	_replay_step_label.custom_minimum_size = Vector2(72.0, 0.0)
	row.add_child(_replay_step_label)

	var stop_button := Button.new()
	stop_button.text = "退出"
	stop_button.custom_minimum_size = Vector2(58.0, 36.0)
	stop_button.pressed.connect(func(): replay_stop_requested.emit())
	row.add_child(stop_button)


func _build_start_menu() -> void:
	_start_menu = _build_overlay_root("StartMenu", 0.22)
	var hero := TextureRect.new()
	hero.name = "StartMenuHero"
	hero.texture = load(START_MENU_HERO_PATH)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	hero.anchor_right = 1.0
	hero.anchor_bottom = 1.0
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_menu.add_child(hero)
	_start_menu.move_child(hero, 0)

	var outer := MarginContainer.new()
	outer.anchor_right = 1.0
	outer.anchor_bottom = 1.0
	outer.add_theme_constant_override("margin_left", 56)
	outer.add_theme_constant_override("margin_top", 44)
	outer.add_theme_constant_override("margin_right", 56)
	outer.add_theme_constant_override("margin_bottom", 44)
	_start_menu.add_child(outer)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 38)
	outer.add_child(layout)

	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(hero_copy)
	var hero_spacer := Control.new()
	hero_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero_copy.add_child(hero_spacer)
	var eyebrow := Label.new()
	eyebrow.text = "MEADOW BOARD"
	eyebrow.add_theme_font_size_override("font_size", 16)
	eyebrow.add_theme_color_override("font_color", Color(0.88, 0.76, 0.43))
	hero_copy.add_child(eyebrow)
	var hero_title := Label.new()
	hero_title.text = "跳棋 3D"
	hero_title.add_theme_font_size_override("font_size", 48)
	hero_title.add_theme_color_override("font_color", Color(0.98, 0.97, 0.91))
	hero_copy.add_child(hero_title)
	var hero_subtitle := Label.new()
	hero_subtitle.text = "在草地庭院中规划每一次落点"
	hero_subtitle.add_theme_font_size_override("font_size", 18)
	hero_subtitle.add_theme_color_override("font_color", Color(0.86, 0.88, 0.82))
	hero_copy.add_child(hero_subtitle)

	var panel := PanelContainer.new()
	panel.name = "StartMenuPanel"
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	_style_panel(panel, Color(0.035, 0.055, 0.05, 0.9), Color(0.48, 0.58, 0.48, 0.5))
	layout.add_child(panel)
	var box := _build_menu_box(panel)
	box.add_theme_constant_override("separation", 12)

	var title := Label.new()
	title.text = "选择游戏模式"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "从一个模式开始，其他设置可以在游戏内继续调整。"
	subtitle.add_theme_color_override("font_color", Color(0.74, 0.8, 0.76))
	box.add_child(subtitle)

	var mode_grid := GridContainer.new()
	mode_grid.name = "ModeGrid"
	mode_grid.columns = 2
	mode_grid.add_theme_constant_override("h_separation", 12)
	mode_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(mode_grid)
	_build_start_mode_card(mode_grid, "本地 AI 对战", "开始标准对局，随机分配被动技能。", "开始对战", _on_start_local_pressed, Color(0.26, 0.54, 0.42))
	_build_start_mode_card(mode_grid, "跳跃训练", "载入测试布局，快速练习连续跳跃。", "进入训练", _on_start_test_layout_pressed, Color(0.54, 0.43, 0.22))

	_start_ai_takeover_checkbox = CheckBox.new()
	_start_ai_takeover_checkbox.text = "玩家 1 交给 AI 托管"
	_start_ai_takeover_checkbox.toggled.connect(_on_ai_takeover_checkbox_toggled)
	box.add_child(_start_ai_takeover_checkbox)

	var online_card := PanelContainer.new()
	online_card.name = "OnlineCard"
	_style_panel(online_card, Color(0.08, 0.11, 0.1, 0.88), Color(0.34, 0.42, 0.38, 0.62))
	box.add_child(online_card)
	var online_box := _build_menu_box(online_card)
	var online_title := Label.new()
	online_title.text = "联机对战"
	online_title.add_theme_font_size_override("font_size", 18)
	online_box.add_child(online_title)

	_signaling_url_input = LineEdit.new()
	_signaling_url_input.placeholder_text = "Server URL"
	_signaling_url_input.text = "ws://127.0.0.1:8787"
	online_box.add_child(_signaling_url_input)

	var room_row := HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 10)
	online_box.add_child(room_row)
	_network_room_code_input = LineEdit.new()
	_network_room_code_input.placeholder_text = "输入房间码"
	_network_room_code_input.max_length = 6
	_network_room_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_network_room_code_input.text_submitted.connect(_on_room_code_submitted)
	room_row.add_child(_network_room_code_input)
	var join_button := Button.new()
	join_button.text = "加入房间"
	join_button.set_meta("ui_variant", "primary")
	join_button.pressed.connect(_on_join_online_room_pressed)
	room_row.add_child(join_button)
	var create_button := Button.new()
	create_button.text = "创建新房间"
	create_button.pressed.connect(_on_create_online_room_pressed)
	online_box.add_child(create_button)

	_start_status_label = Label.new()
	_start_status_label.text = "联机状态：本地 AI 模式"
	_start_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_start_status_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.73))
	box.add_child(_start_status_label)


func _build_pause_menu() -> void:
	_pause_menu = _build_overlay_root("PauseMenu")
	_pause_menu.visible = false
	var panel := _build_menu_panel(Vector2(420.0, 720.0))
	_pause_menu.add_child(panel)

	var box := _build_menu_box(panel)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "继续"
	resume_button.pressed.connect(_on_resume_pressed)
	box.add_child(resume_button)

	var restart_game_button := Button.new()
	restart_game_button.text = "重新开始当前模式"
	restart_game_button.pressed.connect(_on_pause_restart_pressed)
	box.add_child(restart_game_button)

	var main_menu_button := Button.new()
	main_menu_button.text = "返回开始菜单"
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	box.add_child(main_menu_button)

	var local_button := Button.new()
	local_button.text = "切回本地 AI 模式"
	local_button.pressed.connect(_on_pause_local_mode_pressed)
	box.add_child(local_button)

	_pause_ai_takeover_checkbox = CheckBox.new()
	_pause_ai_takeover_checkbox.text = "玩家 1 AI 托管"
	_pause_ai_takeover_checkbox.toggled.connect(_on_ai_takeover_checkbox_toggled)
	box.add_child(_pause_ai_takeover_checkbox)

	var seed_separator := HSeparator.new()
	box.add_child(seed_separator)

	_seed_status_label = Label.new()
	_seed_status_label.text = "技能种子：-"
	box.add_child(_seed_status_label)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	box.add_child(seed_row)

	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "输入整数种子"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(_seed_input)

	var seed_restart_button := Button.new()
	seed_restart_button.text = "按种子重开"
	seed_restart_button.pressed.connect(_on_seed_restart_pressed)
	seed_row.add_child(seed_restart_button)

	var material_separator := HSeparator.new()
	box.add_child(material_separator)

	var material_title := Label.new()
	material_title.text = "材质"
	box.add_child(material_title)

	_board_material_option = _build_material_option_row(box, "棋盘", "board")
	_player_one_material_option = _build_material_option_row(box, "玩家 1 棋子", "player_1")
	_player_two_material_option = _build_material_option_row(box, "玩家 2 棋子", "player_2")
	_populate_material_option(_board_material_option, "board", String(_material_selection.get("board", "default")))
	_populate_material_option(_player_one_material_option, "player", String(_material_selection.get("player_1", "default")))
	_populate_material_option(_player_two_material_option, "player", String(_material_selection.get("player_2", "default")))

	var lighting_button := Button.new()
	lighting_button.text = "光影设置"
	lighting_button.pressed.connect(_on_lighting_settings_pressed)
	box.add_child(lighting_button)

	var record_separator := HSeparator.new()
	box.add_child(record_separator)

	var record_title := Label.new()
	record_title.text = "对局记录 / 回放"
	box.add_child(record_title)

	var record_row := HBoxContainer.new()
	record_row.add_theme_constant_override("separation", 8)
	box.add_child(record_row)

	var save_record_button := Button.new()
	save_record_button.text = "保存记录"
	save_record_button.pressed.connect(func(): save_match_record_requested.emit())
	record_row.add_child(save_record_button)

	var load_record_button := Button.new()
	load_record_button.text = "载入最近"
	load_record_button.pressed.connect(func(): load_match_record_requested.emit())
	record_row.add_child(load_record_button)

	var replay_button := Button.new()
	replay_button.text = "开始回放"
	replay_button.pressed.connect(func(): replay_start_requested.emit())
	record_row.add_child(replay_button)

	_match_record_status_label = Label.new()
	_match_record_status_label.text = "已记录 0 步"
	_match_record_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_match_record_status_label)

	var camera_separator := HSeparator.new()
	box.add_child(camera_separator)

	var camera_title := Label.new()
	camera_title.text = "视角记录"
	box.add_child(camera_title)

	var camera_row := HBoxContainer.new()
	camera_row.add_theme_constant_override("separation", 8)
	box.add_child(camera_row)

	_camera_view_name_input = LineEdit.new()
	_camera_view_name_input.placeholder_text = "视角名称"
	_camera_view_name_input.text = "view_1"
	_camera_view_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camera_view_name_input.text_submitted.connect(_on_camera_view_name_submitted)
	camera_row.add_child(_camera_view_name_input)

	var save_button := Button.new()
	save_button.text = "保存视角"
	save_button.pressed.connect(_on_save_camera_view_pressed)
	camera_row.add_child(save_button)

	_camera_view_status_label = Label.new()
	_camera_view_status_label.text = ""
	_camera_view_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_camera_view_status_label)


func _build_lighting_menu() -> void:
	_lighting_menu = _build_overlay_root("LightingMenu")
	_lighting_menu.visible = false
	var panel := _build_menu_panel(Vector2(520.0, 735.0))
	_lighting_menu.add_child(panel)
	var box := _build_menu_box(panel)

	var title := Label.new()
	title.text = "光影设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "切换预设后可继续微调；保存后下次启动自动加载。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	box.add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "预设"
	preset_label.custom_minimum_size = Vector2(116.0, 0.0)
	preset_row.add_child(preset_label)
	_lighting_preset_option = OptionButton.new()
	_lighting_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lighting_preset_option.item_selected.connect(_on_lighting_preset_option_selected)
	preset_row.add_child(_lighting_preset_option)
	_populate_lighting_preset_option()

	var render_cost_row := HBoxContainer.new()
	render_cost_row.add_theme_constant_override("separation", 8)
	box.add_child(render_cost_row)
	var render_cost_label := Label.new()
	render_cost_label.text = "渲染开销"
	render_cost_label.custom_minimum_size = Vector2(116.0, 0.0)
	render_cost_row.add_child(render_cost_label)
	_render_cost_profile_option = OptionButton.new()
	_render_cost_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_render_cost_profile_option.item_selected.connect(_on_render_cost_profile_option_selected)
	render_cost_row.add_child(_render_cost_profile_option)
	_populate_render_cost_profile_option()

	_render_cost_profile_summary_label = Label.new()
	_render_cost_profile_summary_label.text = ""
	_render_cost_profile_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_render_cost_profile_summary_label.add_theme_color_override("font_color", Color(0.72, 0.8, 0.74))
	box.add_child(_render_cost_profile_summary_label)

	var time_title := Label.new()
	time_title.text = "时间光照"
	box.add_child(time_title)

	_time_of_day_button_row = HBoxContainer.new()
	_time_of_day_button_row.add_theme_constant_override("separation", 6)
	box.add_child(_time_of_day_button_row)
	_populate_time_of_day_buttons()

	_auto_time_cycle_checkbox = CheckBox.new()
	_auto_time_cycle_checkbox.text = "自动昼夜"
	_auto_time_cycle_checkbox.toggled.connect(_on_auto_time_cycle_checkbox_toggled)
	box.add_child(_auto_time_cycle_checkbox)

	_build_lighting_slider(box, "环境光", "ambient_energy", 0.2, 1.2, 0.01)
	_build_lighting_slider(box, "主光", "sun_energy", 0.0, 0.6, 0.01)
	_build_lighting_slider(box, "四角补光", "fill_energy", 0.0, 0.2, 0.005)
	_build_lighting_slider(box, "反射", "reflection_intensity", 0.0, 0.35, 0.01)
	_build_lighting_slider(box, "曝光", "exposure", 0.6, 1.05, 0.01)
	_build_lighting_slider(box, "接触阴影", "ssao_intensity", 0.0, 2.4, 0.02)
	_build_lighting_slider(box, "棋盘光点", "board_glow_energy", 0.0, 0.5, 0.01)
	_build_lighting_slider(box, "石柱发光", "marker_glow_energy", 0.0, 1.6, 0.01)

	_build_lighting_slider(box, "渲染精度", "render_scale", 0.6, 1.4, 0.05)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	box.add_child(button_row)
	var save_button := Button.new()
	save_button.text = "保存当前光影"
	save_button.pressed.connect(func(): save_lighting_requested.emit())
	button_row.add_child(save_button)
	var reset_button := Button.new()
	reset_button.text = "恢复柔和日光"
	reset_button.pressed.connect(func(): reset_lighting_requested.emit())
	button_row.add_child(reset_button)
	var back_button := Button.new()
	back_button.text = "返回"
	back_button.pressed.connect(_on_lighting_back_pressed)
	button_row.add_child(back_button)

	_lighting_status_label = Label.new()
	_lighting_status_label.text = ""
	_lighting_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_lighting_status_label)


func _build_lighting_slider(parent: VBoxContainer, label_text: String, parameter: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(116.0, 0.0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float): _on_lighting_slider_changed(parameter, value))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52.0, 0.0)
	row.add_child(value_label)
	_lighting_sliders[parameter] = slider
	_lighting_value_labels[parameter] = value_label
	_update_lighting_value_label(parameter, slider.value)


func _populate_lighting_preset_option() -> void:
	if _lighting_preset_option == null:
		return
	_lighting_preset_option.clear()
	for option in _lighting_preset_options:
		_lighting_preset_option.add_item(String(option.get("label", "光影预设")))
		_lighting_preset_option.set_item_metadata(_lighting_preset_option.item_count - 1, String(option.get("id", "custom")))


func _populate_render_cost_profile_option() -> void:
	if _render_cost_profile_option == null:
		return
	_render_cost_profile_option.clear()
	for option in _render_cost_profile_options:
		_render_cost_profile_option.add_item(String(option.get("label", "开销档位")))
		_render_cost_profile_option.set_item_metadata(_render_cost_profile_option.item_count - 1, String(option.get("id", "high")))


func _populate_time_of_day_buttons() -> void:
	if _time_of_day_button_row == null:
		return
	for child in _time_of_day_button_row.get_children():
		child.queue_free()
	for option in _time_of_day_options:
		var button := Button.new()
		button.text = String(option.get("label", "时间"))
		button.custom_minimum_size = Vector2(64.0, 36.0)
		var hour := float(option.get("hour", 12.0))
		button.pressed.connect(_on_time_of_day_button_pressed.bind(hour))
		_time_of_day_button_row.add_child(button)
		_style_button(button)


func _select_lighting_preset(preset_id: String) -> void:
	if _lighting_preset_option == null:
		return
	for index in range(_lighting_preset_option.item_count):
		if String(_lighting_preset_option.get_item_metadata(index)) == preset_id:
			_lighting_preset_option.select(index)
			return


func _select_render_cost_profile(profile_id: String) -> void:
	if _render_cost_profile_option == null:
		return
	for index in range(_render_cost_profile_option.item_count):
		if String(_render_cost_profile_option.get_item_metadata(index)) == profile_id:
			_render_cost_profile_option.select(index)
			_update_render_cost_profile_summary_by_id(profile_id)
			return


func _update_render_cost_profile_summary_by_id(profile_id: String) -> void:
	for option in _render_cost_profile_options:
		if String(option.get("id", "high")) == profile_id:
			_update_render_cost_profile_summary(String(option.get("summary", "")))
			return


func _update_render_cost_profile_summary(summary: String) -> void:
	if _render_cost_profile_summary_label != null:
		_render_cost_profile_summary_label.text = summary


func _update_lighting_value_label(parameter: String, value: float) -> void:
	var label: Label = _lighting_value_labels.get(parameter)
	if label != null:
		if parameter == "render_scale":
			label.text = "%d%%" % roundi(value * 100.0)
		else:
			label.text = "%.2f" % value


func _build_overlay_root(node_name: String, shade_alpha := 0.48) -> Control:
	var root := Control.new()
	root.name = node_name
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, shade_alpha)
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	return root


func _build_menu_panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	_style_panel(panel)
	panel.custom_minimum_size = min_size
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var half_height := 220.0 if min_size.y <= 0.0 else min_size.y * 0.5
	panel.offset_left = -min_size.x * 0.5
	panel.offset_top = -half_height
	panel.offset_right = min_size.x * 0.5
	panel.offset_bottom = half_height
	return panel


func _build_menu_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	return box


func _build_start_mode_card(parent: GridContainer, title_text: String, description: String, button_text: String, callback: Callable, accent: Color) -> void:
	var card := PanelContainer.new()
	card.name = "ModeCard_%d" % parent.get_child_count()
	card.custom_minimum_size = Vector2(252.0, 146.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_panel(card, Color(0.08, 0.115, 0.1, 0.92), Color(accent.r, accent.g, accent.b, 0.9))
	parent.add_child(card)
	var box := _build_menu_box(card)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.9))
	box.add_child(title)
	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_color_override("font_color", Color(0.73, 0.79, 0.74))
	box.add_child(detail)
	var button := Button.new()
	button.text = button_text
	button.set_meta("ui_variant", "primary")
	button.pressed.connect(callback)
	box.add_child(button)


func _style_panel(panel: PanelContainer, background := Color(0.045, 0.06, 0.058, 0.94), border := Color(0.38, 0.48, 0.43, 0.58)) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)


func _apply_button_styles(node: Node) -> void:
	for child in node.get_children():
		if child is Button and not child is OptionButton and not child is CheckBox:
			_style_button(child, String(child.get_meta("ui_variant", "secondary")))
		_apply_button_styles(child)


func _style_button(button: Button, variant := "secondary") -> void:
	var normal_color := Color(0.12, 0.17, 0.155, 0.98)
	var hover_color := Color(0.18, 0.27, 0.235, 1.0)
	var pressed_color := Color(0.08, 0.13, 0.115, 1.0)
	var border_color := Color(0.42, 0.54, 0.48, 0.72)
	if variant == "primary":
		normal_color = Color(0.19, 0.39, 0.315, 1.0)
		hover_color = Color(0.26, 0.52, 0.405, 1.0)
		pressed_color = Color(0.14, 0.3, 0.245, 1.0)
		border_color = Color(0.58, 0.76, 0.64, 0.88)
	var minimum_size := button.custom_minimum_size
	minimum_size.y = maxf(minimum_size.y, 40.0)
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _make_button_style(normal_color, border_color))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_color, border_color))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_color, border_color))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_color, Color(0.82, 0.9, 0.75, 0.95), 2))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.09, 0.11, 0.105, 0.72), Color(0.28, 0.32, 0.3, 0.44)))


func _make_button_style(background: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(9)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _build_material_option_row(parent: VBoxContainer, label_text: String, target: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(92.0, 0.0)
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(func(index: int): _on_material_option_selected(option, target, index))
	row.add_child(option)
	return option


func _populate_material_option(option: OptionButton, target_usage := "", selected_id := "default") -> void:
	if option == null:
		return

	option.clear()
	for index in range(_material_options.size()):
		var material_option := _material_options[index]
		if not _material_option_matches_usage(material_option, target_usage):
			continue
		option.add_item(String(material_option.get("label", "材质 %d" % index)))
		option.set_item_metadata(option.item_count - 1, String(material_option.get("id", "default")))
	if option.item_count == 0:
		option.add_item("默认颜色")
		option.set_item_metadata(0, "default")
	_select_material_option(option, selected_id)


func _material_option_matches_usage(option: Dictionary, target_usage: String) -> bool:
	var usage := String(option.get("usage", ""))
	if usage.is_empty() or target_usage.is_empty():
		return true
	if target_usage == "player":
		return usage == "piece"
	return usage == target_usage


func _select_material_option(option: OptionButton, material_id: String) -> void:
	if option == null:
		return

	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == material_id:
			option.select(index)
			return
	option.select(0)


func _on_start_local_pressed() -> void:
	hide_start_menu()
	local_mode_requested.emit()


func _on_start_test_layout_pressed() -> void:
	hide_start_menu()
	test_layout_requested.emit()


func _on_pause_pressed() -> void:
	if _pause_menu != null:
		_pause_menu.visible = true


func _on_lighting_settings_pressed() -> void:
	if _pause_menu != null:
		_pause_menu.visible = false
	if _lighting_menu != null:
		_lighting_menu.visible = true


func _on_lighting_back_pressed() -> void:
	if _lighting_menu != null:
		_lighting_menu.visible = false
	if _pause_menu != null:
		_pause_menu.visible = true


func _on_resume_pressed() -> void:
	if _pause_menu != null:
		_pause_menu.visible = false


func _on_pause_restart_pressed() -> void:
	_on_resume_pressed()
	restart_requested.emit()


func _on_main_menu_pressed() -> void:
	if _pause_menu != null:
		_pause_menu.visible = false
	local_mode_requested.emit()
	show_start_menu()


func _on_pause_local_mode_pressed() -> void:
	_on_resume_pressed()
	local_mode_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_test_layout_pressed() -> void:
	test_layout_requested.emit()


func _on_save_camera_view_pressed() -> void:
	var view_name := _camera_view_name_input.text.strip_edges()
	if view_name.is_empty():
		view_name = "view_%d" % _camera_view_save_count
	save_camera_view_requested.emit(view_name)
	_camera_view_save_count += 1
	_camera_view_name_input.text = "view_%d" % _camera_view_save_count


func _on_camera_view_name_submitted(_new_text: String) -> void:
	_on_save_camera_view_pressed()


func _on_create_online_room_pressed() -> void:
	hide_start_menu()
	create_online_room_requested.emit(_get_signaling_url())


func _on_join_online_room_pressed() -> void:
	hide_start_menu()
	join_online_room_requested.emit(_network_room_code_input.text.strip_edges().to_upper(), _get_signaling_url())


func _on_room_code_submitted(_new_text: String) -> void:
	_on_join_online_room_pressed()


func _on_ai_takeover_checkbox_toggled(enabled: bool) -> void:
	if _ai_checkbox_syncing:
		return
	ai_takeover_toggled.emit(enabled)


func _on_seed_restart_pressed() -> void:
	if _seed_input == null:
		return
	_on_resume_pressed()
	restart_with_seed_requested.emit(_seed_input.text)


func _on_seed_submitted(_new_text: String) -> void:
	_on_seed_restart_pressed()


func _on_analysis_button_toggled(enabled: bool) -> void:
	if _analysis_button_syncing:
		return
	analysis_mode_toggled.emit(enabled)


func _on_replay_play_pressed() -> void:
	replay_play_toggled.emit(_replay_play_button == null or _replay_play_button.text == "播放")


func _on_replay_slider_changed(value: float) -> void:
	if _replay_slider_updating:
		return
	replay_step_requested.emit(int(value))


func _on_material_option_selected(option: OptionButton, target: String, index: int) -> void:
	if option == null or index < 0:
		return
	material_selected.emit(target, String(option.get_item_metadata(index)))


func _on_lighting_preset_option_selected(index: int) -> void:
	if _lighting_controls_syncing or _lighting_preset_option == null or index < 0:
		return
	lighting_preset_selected.emit(String(_lighting_preset_option.get_item_metadata(index)))


func _on_render_cost_profile_option_selected(index: int) -> void:
	if _lighting_controls_syncing or _render_cost_profile_option == null or index < 0:
		return
	var profile_id := String(_render_cost_profile_option.get_item_metadata(index))
	_update_render_cost_profile_summary_by_id(profile_id)
	render_cost_profile_selected.emit(profile_id)


func _on_auto_time_cycle_checkbox_toggled(enabled: bool) -> void:
	if _auto_time_cycle_syncing:
		return
	auto_time_cycle_toggled.emit(enabled)


func _on_time_of_day_button_pressed(hour: float) -> void:
	time_of_day_selected.emit(hour)


func _on_lighting_slider_changed(parameter: String, value: float) -> void:
	_update_lighting_value_label(parameter, value)
	if _lighting_controls_syncing:
		return
	lighting_value_changed.emit(parameter, value)


func _get_signaling_url() -> String:
	if _signaling_url_input == null:
		return "ws://127.0.0.1:8787"
	var url := _signaling_url_input.text.strip_edges()
	if url.is_empty():
		return "ws://127.0.0.1:8787"
	return url
