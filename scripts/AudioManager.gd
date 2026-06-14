class_name AudioManager
extends Node

@export var music_volume_db := -28.0
@export var effect_volume_db := -12.0

const MUSIC_PATH := "res://assets/audio/puzzle_menu_loop.ogg"
const PIECE_LAND_PATH := "res://assets/audio/piece_land.ogg"
const JUMP_LAND_PATH := "res://assets/audio/jump_land.ogg"
const DASH_LAND_PATH := "res://assets/audio/dash_land.ogg"
const FREEZE_PATH := "res://assets/audio/freeze_soft.ogg"
const ICE_SHATTER_PATH := "res://assets/audio/thaw_soft.ogg"

var _music_player: AudioStreamPlayer
var _effect_players: Array[AudioStreamPlayer] = []
var _next_effect_player := 0
var _last_effect_time_ms: Dictionary = {}


func _ready() -> void:
	_music_player = _create_player("MusicPlayer", music_volume_db)
	for index in range(6):
		_effect_players.append(_create_player("EffectPlayer%d" % (index + 1), effect_volume_db))
	call_deferred("_start_music")


func _exit_tree() -> void:
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null
	for player in _effect_players:
		player.stop()
		player.stream = null


func play_action(action: Dictionary, skill_status := {}, moving_skill_id := "") -> void:
	var effects: Array = action.get("effects", [])
	var is_dash := false
	for effect in effects:
		if effect is Dictionary and String(effect.get("type", "")) in ["dash_advance", "dash_long_jump"]:
			is_dash = true
			break

	if is_dash:
		_play_effect(DASH_LAND_PATH, 0.86, -8.0, "move", 85)
	elif String(action.get("move_kind", "")) == "jump":
		_play_effect(JUMP_LAND_PATH, 0.9, -10.0, "move", 85)
	else:
		_play_effect(PIECE_LAND_PATH, 0.94, -12.0, "move", 85)

	if int(skill_status.get("frozen", 0)) > 0:
		_play_effect(FREEZE_PATH, 0.86, -12.0, "freeze", 140)
	if int(skill_status.get("thawed", 0)) > 0 or moving_skill_id == "freeze_immune":
		_play_effect(ICE_SHATTER_PATH, 0.92, -13.0, "thaw", 140)


func _start_music() -> void:
	var stream = load(MUSIC_PATH)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	if DisplayServer.get_name() == "headless":
		return
	_music_player.stream = stream
	_music_player.play()


func _play_effect(path: String, pitch_scale := 1.0, volume_offset_db := 0.0, category := "", cooldown_ms := 0) -> void:
	if _effect_players.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	if not category.is_empty() and now_ms - int(_last_effect_time_ms.get(category, -cooldown_ms)) < cooldown_ms:
		return
	var stream = load(path)
	if stream == null:
		return
	if DisplayServer.get_name() == "headless":
		return
	var player := _effect_players[_next_effect_player]
	_next_effect_player = (_next_effect_player + 1) % _effect_players.size()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = effect_volume_db + volume_offset_db
	player.play()
	if not category.is_empty():
		_last_effect_time_ms[category] = now_ms


func _create_player(player_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.volume_db = volume_db
	add_child(player)
	return player
