class_name GameUI
extends CanvasLayer

signal restart_requested
signal end_turn_requested
signal test_layout_requested

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


func _ready() -> void:
	end_turn_button.text = "结束回合"
	test_layout_button.text = "测试布局"
	restart_button.text = "重新开始"
	play_again_button.text = "再来一局"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	test_layout_button.pressed.connect(_on_test_layout_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	play_again_button.pressed.connect(_on_restart_pressed)
	hide_end_turn()
	hide_victory()


func set_current_player(player_id: int) -> void:
	current_player_label.text = "当前玩家：玩家 %d" % player_id


func show_human_turn() -> void:
	turn_prompt_label.text = "轮到你操作"
	hide_end_turn()


func show_ai_turn() -> void:
	turn_prompt_label.text = "对手正在思考..."
	hide_end_turn()


func show_continue_jump() -> void:
	turn_prompt_label.text = "可以继续跳跃，也可以结束回合"
	end_turn_button.visible = true


func show_test_layout_ready() -> void:
	turn_prompt_label.text = "测试布局：连续跳跃进营即可获胜"
	hide_end_turn()


func hide_end_turn() -> void:
	end_turn_button.visible = false


func show_victory(player_id: int) -> void:
	victory_label.text = "玩家 %d 获胜" % player_id
	victory_panel.visible = true


func hide_victory() -> void:
	victory_panel.visible = false


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_end_turn_pressed() -> void:
	end_turn_requested.emit()


func _on_test_layout_pressed() -> void:
	test_layout_requested.emit()
